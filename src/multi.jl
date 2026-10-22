"""
    MultiConfig(; kwargs...)

Several centers share the total budget `base.B`. Each center runs the single-center design
(`Site`) on its own clients and its own share of the budget; all read their own spend from
the one central DB (delay `base.D`), and they talk to each other with delay `net_latency`.

Hard cap: each center keeps `Y_k + E_k ≤ B_k(1−δ)` and Σ B_k + (transfers in flight) = B,
so total DB spend never exceeds B. A donor takes budget off its own B_k *before* sending it,
and gives only what its own invariant allows (`headroom`).
"""
Base.@kwdef struct MultiConfig
    base::Config = Config()                        # world, assumptions and policy shared by all centers; base.B = total
    names::Vector{String} = ["A", "B", "C", "D"]
    load::Vector{Float64} = [1/2, 1/4, 1/8, 1/8]   # assumed load shares → initial budget split
    load_true::Vector{Float64} = load              # true mean demand shares (unknown to the centers)
    load_sigma::Float64 = 0.0                      # per-run lognormal noise on load_true (renormalized)
    tz::Vector{Float64} = [0.0, -120.0, 360.0, 780.0]  # local time − A's local time [min]
    overrides::Vector{Any} = fill((;), length(names))  # per-center Config changes (NamedTuple), e.g. a local shock

    # ---------------- rebalancing ----------------
    rebalance::Symbol = :both              # :none | :periodic | :on_demand | :both
    rebalance_every::Float64 = 60.0        # periodic round: every center broadcasts its status [min]
    rebalance_start::Float64 = 1440.0      # no rebalancing before (centers learn their profiles) [min]
    rebalance_tol::Float64 = 0.02          # donor gives only when surplus > tol × its target
    min_transfer::Float64 = 1e-4           # smaller transfers are not sent, fraction of B
    urgent_cooldown::Float64 = 15.0        # min time between urgent requests of one center [min]
    net_latency::Float64 = 2.0             # center ↔ center message delay [min]
    net_jitter::Float64 = 0.0              # extra delay, uniform in [0, net_jitter] [min]
end

function validate(mc::MultiConfig)
    K = length(mc.names)
    all(length(v) == K for v in (mc.load, mc.load_true, mc.tz, mc.overrides)) ||
        error("names, load, load_true, tz and overrides must have the same length")
    isapprox(sum(mc.load), 1; atol = 1e-9) || error("load must sum to 1")
    mc.rebalance in (:none, :periodic, :on_demand, :both) ||
        error("rebalance must be :none, :periodic, :on_demand or :both")
    nothing
end

"Per-center Config: share of B by assumed load, demand and client count by true load."
function site_configs(mc::MultiConfig, lt)
    b = mc.base
    map(eachindex(mc.names)) do k
        own = (B = b.B * mc.load[k], n_clients = max(2, round(Int, b.n_clients * lt[k])),
               demand_ratio = b.demand_ratio * lt[k] / mc.load[k], seed = 1000 * b.seed + k)
        with(b; merge(own, mc.overrides[k])...)
    end
end

struct Msg
    deliver::Int           # step at whose start the message arrives
    from::Int
    to::Int
    kind::Symbol           # :status | :urgent (status + "please donate now") | :transfer
    R::Float64             # sender's remaining budget B_k − Ŝ_k
    need::Float64          # sender's forecast spendable demand to T (DB units)
    sent::Vector{Float64}  # sender's cumulative transfers to each center
    recv::Vector{Float64}  # sender's cumulative transfers received from each center
    amount::Float64        # transfer amount
end

"""
What each center knows about the others, the messages in flight, and rebalancing metrics.
The cumulative `sent`/`recv` counters travel with every status, so a center can tell which
transfers have not arrived yet and does not pay the same deficit twice.
"""
mutable struct Net
    queue::Vector{Msg}
    known::BitMatrix           # known[k, j]: k has a status from j
    R::Matrix{Float64}         # R[k, j]: j's B_j − Ŝ_j as last reported to k
    need::Matrix{Float64}      # need[k, j]: j's forecast spendable demand as last reported to k
    sent::Matrix{Float64}      # sent[i, j]: cumulative transfers i → j (row i known to i)
    recv::Matrix{Float64}      # recv[j, i]: cumulative received by j from i (row j known to j)
    vsent::Array{Float64,3}    # vsent[k, i, j]: sent[i, j] as last reported to k
    vrecv::Array{Float64,3}    # vrecv[k, j, i]: recv[j, i] as last reported to k
    rng::Xoshiro               # network jitter
    transfers::Int
    moved::Float64
    messages::Int
    urgent::Int
    log::Vector{Tuple{Int,Int,Int,Float64}}   # (step, from, to, amount) of every transfer
end

Net(K, rng) = Net(Msg[], falses(K, K), zeros(K, K), zeros(K, K), zeros(K, K), zeros(K, K),
                  zeros(K, K, K), zeros(K, K, K), rng, 0, 0.0, 0, 0, Tuple{Int,Int,Int,Float64}[])

delay(mc::MultiConfig, rng) =
    max(1, round(Int, (mc.net_latency + (mc.net_jitter > 0 ? mc.net_jitter * rand(rng) : 0.0)) / mc.base.dt))

function send_status!(net::Net, k, n, kind, sites, mc)
    s = sites[k]
    for j in eachindex(sites)
        j == k && continue
        push!(net.queue, Msg(n + delay(mc, net.rng), k, j, kind, s.budget - s.Shat, s.need,
                             net.sent[k, :], net.recv[k, :], 0.0))
        net.messages += 1
    end
end

function deliver!(net::Net, m::Msg, n, sites, mc)
    if m.kind == :transfer
        sites[m.to].budget += m.amount
        net.recv[m.to, m.from] += m.amount
    else
        k, j = m.to, m.from
        net.R[k, j], net.need[k, j], net.known[k, j] = m.R, m.need, true
        net.vsent[k, j, :] .= m.sent
        net.vrecv[k, j, :] .= m.recv
        m.kind == :urgent && donate!(net, k, n, sites, mc)
    end
end

"""
Center `k` gives its surplus to the centers in deficit. Allocation target: total remaining
budget in proportion to forecast remaining demand, which gives every center the same pacing
ratio. Remaining budgets include transfers still in flight, as far as `k` can tell.
"""
function donate!(net::Net, k, n, sites, mc)
    K = length(sites)
    s = sites[k]
    js = [j for j in 1:K if j == k || net.known[k, j]]
    length(js) > 1 || return
    sentv(i, j) = i == k ? net.sent[k, j] : net.vsent[k, i, j]
    recvv(j, i) = j == k ? net.recv[k, i] : net.vrecv[k, j, i]
    incoming(j) = sum(max(sentv(i, j) - recvv(j, i), 0.0) for i in 1:K if i != j)
    R = [(j == k ? s.budget - s.Shat : net.R[k, j]) + incoming(j) for j in js]
    need = [j == k ? s.need : net.need[k, j] for j in js]
    Ntot = sum(need)
    Ntot > 0 || return
    target = sum(R) .* need ./ Ntot
    me = findfirst(==(k), js)
    surplus = R[me] - target[me]
    surplus > mc.rebalance_tol * max(target[me], 0.0) || return
    deficit = max.(target .- R, 0.0)
    deficit[me] = 0.0
    Dsum = sum(deficit)
    Dsum > 0 || return
    x = min(surplus, Dsum, headroom(s))
    for (a, j) in enumerate(js)
        xj = x * deficit[a] / Dsum
        xj < mc.min_transfer * mc.base.B && continue
        s.budget -= xj                    # off the donor's budget before it leaves
        net.sent[k, j] += xj
        push!(net.queue, Msg(n + delay(mc, net.rng), k, j, :transfer, 0.0, 0.0, Float64[], Float64[], xj))
        net.transfers += 1
        net.moved += xj
        push!(net.log, (n, k, j, xj))
    end
    nothing
end

"""
    simulate_multi(mc; record=true) -> (summary, ts, site_summaries)

`summary` has the fields of the single-center summary for the whole system (so `aggregate`
works on it) plus rebalancing metrics; `ts` has total spend and per-center series.
"""
function simulate_multi(mc::MultiConfig; record::Bool = true)
    validate(mc)
    K = length(mc.names)
    b = mc.base
    rng = Xoshiro(b.seed)                 # load noise, network jitter
    lt = mc.load_true .* exp.(mc.load_sigma .* randn(rng, K))
    lt ./= sum(lt)
    sites = [Site(c; tz = mc.tz[k], record) for (k, c) in enumerate(site_configs(mc, lt))]
    dt, N, B = b.dt, sites[1].N, b.B

    every = max(1, round(Int, mc.rebalance_every / dt))
    start = round(Int, mc.rebalance_start / dt)
    cooldown = round(Int, mc.urgent_cooldown / dt)
    periodic = mc.rebalance in (:periodic, :both)
    on_demand = mc.rebalance in (:on_demand, :both)
    collect_wait = ceil(Int, (mc.net_latency + mc.net_jitter) / dt)   # until a round's statuses arrived

    net = Net(K, rng)
    rounds = Int[]                        # steps at which a periodic round's statuses have arrived
    last_urgent = fill(-cooldown, K)
    max_commit = err_hat = err_naive = 0.0
    alert_first, alert_minutes, finish_time = NaN, 0.0, NaN

    for n in 1:N
        now = n + 1
        # ---- deliver messages due by the start of this step ----
        if !isempty(net.queue)
            due = [m for m in net.queue if m.deliver <= n]
            filter!(m -> m.deliver > n, net.queue)
            for m in sort!(due; by = m -> m.deliver)
                deliver!(net, m, n, sites, mc)
            end
        end

        for s in sites
            step!(s, n)
        end

        # ---- whole-system metrics ----
        S = sum(s.Sdb[now] for s in sites)
        isnan(finish_time) && S >= 0.999 * B && (finish_time = n * dt)
        max_commit = max(max_commit, sum(s.Y + s.E for s in sites) / B)
        err_hat += abs(sum(s.Shat for s in sites) - S)
        err_naive += abs(sum(s.Y for s in sites) - S)
        R = sum(max(s.budget * (1 - b.delta) - s.Shat, 0.0) for s in sites)
        if n * dt > DAY && R > b.alert_tol * B && sum(s.demand_rem for s in sites) < R
            isnan(alert_first) && (alert_first = n * dt)
            alert_minutes += dt
        end

        # ---- rebalancing ----
        n >= start || continue
        while !isempty(rounds) && rounds[1] <= n
            popfirst!(rounds)
            foreach(k -> donate!(net, k, n, sites, mc), 1:K)
        end
        if periodic && n % every == 0
            foreach(k -> send_status!(net, k, n, :status, sites, mc), 1:K)
            push!(rounds, n + collect_wait)
        end
        for k in 1:K
            if on_demand && sites[k].denied_now > 0 && n - last_urgent[k] >= cooldown
                send_status!(net, k, n, :urgent, sites, mc)
                last_urgent[k] = n
                net.urgent += 1
            end
        end
    end

    in_flight = sum((m.amount for m in net.queue if m.kind == :transfer); init = 0.0)
    isapprox(sum(s.budget for s in sites) + in_flight, B; rtol = 1e-9) || error("budget not conserved")

    subs = [summarize(s) for s in sites]
    S_final = sum(s.Sdb[N + 1] for s in sites)
    summary = (
        spend_ratio = S_final / B,
        overspend = S_final - B > 1e-9 * B ? S_final - B : 0.0,
        underspend = max(B - S_final, 0.0),
        possible_ratio = sum(s.m.total_possible for s in sites) / B,
        max_commit = max_commit,
        grants = sum(s.m.issued for s in sites),
        grants_per_min = sum(s.m.issued for s in sites) / b.T,
        denied = sum(s.m.denied for s in sites),
        utilization = sum(s.Ctot[N + 1] for s in sites) / max(sum(s.m.issued_amount for s in sites), eps()),
        est_err = err_hat / N / B,
        naive_err = err_naive / N / B,
        finish_early = b.T - finish_time,
        alert_first = alert_first,
        alert_minutes = alert_minutes,
        transfers = net.transfers,
        moved = net.moved / B,                      # total transferred, fraction of B
        net_moved = sum(abs(s.budget / B - mc.load[k]) for (k, s) in enumerate(sites)) / 2,   # start → end shift
        messages_per_h = net.messages / (b.T / 60),
        urgent = net.urgent,
        load_true = lt,
        budget_final = [s.budget / B for s in sites],
        spend_final = [s.Sdb[N + 1] / B for s in sites],
        transfer_log = record ? net.log : Tuple{Int,Int,Int,Float64}[],
        # fraction of demand served per center; equal pacing → equal fractions
        served = [s.Sdb[N + 1] / max(s.m.total_possible, eps()) for s in sites],
        site_over = count(s.Sdb[N + 1] > s.budget * (1 + 1e-9) for s in sites),   # must be 0
    )

    ts = (;)
    if record
        cols = Pair{Symbol,Vector{Float64}}[:t => sites[1].ts.t, :S => sum(s.ts.S for s in sites)]
        for (k, s) in enumerate(sites), f in (:S, :budget, :spend, :demand, :p)
            push!(cols, Symbol(f, "_", mc.names[k]) => Float64.(s.ts[f]))
        end
        ts = (; cols...)
    end
    summary, ts, subs
end

"""
    run_mc(mc::MultiConfig; seeds=1:50) -> Vector of summaries
"""
function run_mc(mc::MultiConfig; seeds = 1:50)
    results = Vector{Any}(undef, length(seeds))
    Threads.@threads for j in eachindex(seeds)
        results[j] = first(simulate_multi(with(mc; base = with(mc.base; seed = seeds[j])); record = false))
    end
    results
end

"`aggregate` plus rebalancing metrics."
aggregate_multi(results) = merge(aggregate(results), (
    site_over = sum(r.site_over for r in results),
    transfers = mean(r.transfers for r in results),
    moved = mean(r.moved for r in results),
    net_moved = mean(r.net_moved for r in results),
    served_spread = mean(maximum(r.served) - minimum(r.served) for r in results),
    messages_per_h = mean(r.messages_per_h for r in results),
))
