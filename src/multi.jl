"""
    MultiConfig(; kwargs...)

Several centers share the total budget `base.B`. Each center runs the single-center design
(`Site`) on its own clients and its own share of the budget; all read their own spend from
the one central DB (delay `base.D`), and they talk to each other with delay `net_latency`
(0: a message arrives at once, and a sender knows at once when the other center is down).

A center can be down (`outages`, or random with `outage_mtbf`/`outage_mttr`): it issues no
grants and sends or receives nothing, its clients keep spending their open grants until expiry,
and it resumes with its state intact. With `takeover`, the centers that are up take over its
free budget once all its grants have surely settled.

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
    rebalance_every::Float64 = 60.0        # each center's rebalancing timer [min]
    round_mode::Symbol = :pull             # :pull  own timer, pull fresh statuses, then donate (no clock sync)
                                           # :push  own timer, broadcast own status, donate from last-heard statuses
                                           # :sync  all centers report and decide at the same instant (ideal; needs synced clocks)
    timer_jitter::Float64 = 0.1            # each timer period is rebalance_every × (1 ± jitter); random phase
    rebalance_start::Float64 = 1440.0      # no rebalancing before (centers learn their profiles) [min]
    rebalance_tol::Float64 = 0.02          # donor gives only when surplus > tol × its target
    objective::Symbol = :fair              # :fair  target = remaining budget split by need (equal throttle)
                                           # :spend target = own need (move only what a center cannot spend)
    min_transfer::Float64 = 1e-4           # smaller transfers are not sent, fraction of B
    urgent_cooldown::Float64 = 15.0        # min time between urgent requests of one center [min]
    net_latency::Float64 = 0.0             # center ↔ center message delay [min]
    net_jitter::Float64 = 0.0              # extra delay, uniform in [0, net_jitter] [min]

    # ---------------- outages ----------------
    outages::Vector{Vector{Tuple{Float64,Float64}}} = [Tuple{Float64,Float64}[] for _ in names]
                                           # per center: (start, length) of each outage [min]
    outage_mtbf::Float64 = Inf             # random outages: mean time between outages, per center [min]
    outage_mttr::Float64 = 240.0           # random outages: mean length (exponential) [min]
    takeover::Bool = true                  # centers that are up take over a down center's free budget
    takeover_after::Float64 = NaN          # never before: grants settled (NaN → τ_max + D_max + 2·dt) [min]
    takeover_frac::Float64 = 0.1           # and not before down ≥ frac × (time left in the period)
end

function validate(mc::MultiConfig)
    K = length(mc.names)
    all(length(v) == K for v in (mc.load, mc.load_true, mc.tz, mc.overrides, mc.outages)) ||
        error("names, load, load_true, tz, overrides and outages must have the same length")
    isapprox(sum(mc.load), 1; atol = 1e-9) || error("load must sum to 1")
    settle = mc.base.tau_max + d_max(mc.base)
    isnan(mc.takeover_after) || mc.takeover_after >= settle ||
        @warn "takeover_after < τ_max + D_max: a down center's grants may not have settled, hard cap is not guaranteed"
    mc.rebalance in (:none, :periodic, :on_demand, :both) ||
        error("rebalance must be :none, :periodic, :on_demand or :both")
    mc.round_mode in (:pull, :push, :sync) || error("round_mode must be :pull, :push or :sync")
    mc.objective in (:fair, :spend) || error("objective must be :fair or :spend")
    mc.round_mode != :pull || (mc.net_latency == 0 && mc.net_jitter == 0) ||
        error("round_mode = :pull reads peers' current status instantly: needs zero latency (use :push)")
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
    up::BitVector              # up[k]: center k is running (peers know at once with zero latency)
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
    takeovers::Int
    taken::Float64             # budget taken over from down centers
end

Net(K, rng) = Net(Msg[], trues(K), falses(K, K), zeros(K, K), zeros(K, K), zeros(K, K), zeros(K, K),
                  zeros(K, K, K), zeros(K, K, K), rng, 0, 0.0, 0, 0, Tuple{Int,Int,Int,Float64}[], 0, 0.0)

delay(mc::MultiConfig, rng) =
    round(Int, (mc.net_latency + (mc.net_jitter > 0 ? mc.net_jitter * rand(rng) : 0.0)) / mc.base.dt)

"Deliver now when the delay is zero, otherwise queue."
function post!(net::Net, m::Msg, n, sites, mc)
    m.deliver <= n ? deliver!(net, m, n, sites, mc) : push!(net.queue, m)
    nothing
end

"Status to every center that is up (a send to a down center fails at once)."
function send_status!(net::Net, k, n, kind, sites, mc)
    s = sites[k]
    for j in eachindex(sites)
        (j == k || !net.up[j]) && continue
        net.messages += 1
        post!(net, Msg(n + delay(mc, net.rng), k, j, kind, s.budget - s.Shat, s.need,
                       net.sent[k, :], net.recv[k, :], 0.0), n, sites, mc)
    end
end

"Center `k` asks every running peer for its current status (instant with zero latency)."
function pull_status!(net::Net, k, sites)
    for j in eachindex(sites)
        (j == k || !net.up[j]) && continue
        s = sites[j]
        net.R[k, j], net.need[k, j], net.known[k, j] = s.budget - s.Shat, s.need, true
        net.vsent[k, j, :] .= view(net.sent, j, :)
        net.vrecv[k, j, :] .= view(net.recv, j, :)
        net.messages += 2                 # request + reply
    end
end

function deliver!(net::Net, m::Msg, n, sites, mc)
    if !net.up[m.to]                      # recipient went down while the message travelled
        if m.kind == :transfer            # the transfer fails and goes back to the sender
            sites[m.from].budget += m.amount
            net.sent[m.from, m.to] -= m.amount
        end
        return
    end
    if m.kind == :transfer
        sites[m.to].budget += m.amount
        net.recv[m.to, m.from] += m.amount
    else
        k, j = m.to, m.from
        net.R[k, j], net.need[k, j], net.known[k, j] = m.R, m.need, true
        net.vsent[k, j, :] .= m.sent
        net.vrecv[k, j, :] .= m.recv
        if m.kind == :urgent
            mc.round_mode == :pull && pull_status!(net, k, sites)
            donate!(net, k, n, sites, mc)
        end
    end
end

"""
Center `k` gives its surplus to the centers in deficit. Allocation target (`objective`):
- `:fair`: total remaining budget in proportion to forecast remaining demand, which gives every
  center the same pacing ratio;
- `:spend`: each center's own need, so budget moves only from a center that cannot spend it to
  one that can.
Remaining budgets include transfers still in flight, as far as `k` can tell.
"""
function donate!(net::Net, k, n, sites, mc)
    K = length(sites)
    s = sites[k]
    js = [j for j in 1:K if net.up[j] && (j == k || net.known[k, j])]
    length(js) > 1 || return
    sentv(i, j) = i == k ? net.sent[k, j] : net.vsent[k, i, j]
    recvv(j, i) = j == k ? net.recv[k, i] : net.vrecv[k, j, i]
    incoming(j) = sum(max(sentv(i, j) - recvv(j, i), 0.0) for i in 1:K if i != j)
    R = [(j == k ? s.budget - s.Shat : net.R[k, j]) + incoming(j) for j in js]
    need = [j == k ? s.need : net.need[k, j] for j in js]
    if mc.objective == :fair
        Ntot = sum(need)
        Ntot > 0 || return
        target = sum(R) .* need ./ Ntot
    else
        target = max.(need, 0.0)
    end
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
        net.transfers += 1
        net.moved += xj
        push!(net.log, (n, k, j, xj))
        post!(net, Msg(n + delay(mc, net.rng), k, j, :transfer, 0.0, 0.0, Float64[], Float64[], xj), n, sites, mc)
    end
    nothing
end

"""
The centers that are up take over the free budget of center `j`, which has been down long
enough for all its grants to expire and their spend to reach the DB. Its DB value `Y_j` is
then exactly what it has spent, so `j` keeps `Y_j/(1−δ)` (its invariant holds with `E_j = 0`)
and the rest goes to the centers that are up, in proportion to their need. On recovery `j`
starts with no headroom and gets budget back through rebalancing.
"""
function takeover!(net::Net, j, n, sites, mc)
    s = sites[j]
    keep = s.Sdb[s.asof] / (1 - s.cfg.delta)
    free = s.budget - keep
    ups = [k for k in eachindex(sites) if net.up[k]]
    isempty(ups) && return false          # nobody to take it: try again later
    free > mc.min_transfer * mc.base.B || return true
    need = [max(sites[k].need, 0.0) for k in ups]
    w = sum(need) > 0 ? need ./ sum(need) : fill(1 / length(ups), length(ups))
    s.budget = keep
    for (a, k) in enumerate(ups)
        sites[k].budget += free * w[a]
    end
    net.takeovers += 1
    net.taken += free
    true
end

"down[k, n]: center k is down during step n."
function outage_schedule(mc::MultiConfig, N)
    K, dt = length(mc.names), mc.base.dt
    down = falses(K, N)
    mark!(k, t0, len) = for n in 1:N
        t0 <= (n - 1) * dt < t0 + len && (down[k, n] = true)
    end
    for k in 1:K, (t0, len) in mc.outages[k]
        mark!(k, t0, len)
    end
    if isfinite(mc.outage_mtbf)
        orng = Xoshiro(mc.base.seed + 104729)
        for k in 1:K
            t = mc.outage_mtbf * randexp(orng)
            while t < mc.base.T
                len = mc.outage_mttr * randexp(orng)
                mark!(k, t, len)
                t += len + mc.outage_mtbf * randexp(orng)
            end
        end
    end
    down
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
    settle = isnan(mc.takeover_after) ? b.tau_max + d_max(b) + 2dt : mc.takeover_after
    takeover_st = ceil(Int, settle / dt)
    down = outage_schedule(mc, N)
    down_since = zeros(Int, K)
    taken = falses(K)
    possible_up = 0.0                     # demand of centers while they are up, DB units

    net = Net(K, rng)
    rounds = Int[]                        # :sync: steps at which a round's statuses have arrived
    trng = Xoshiro(b.seed + 7919)         # timers: random phase and jitter (centers' clocks are not synced)
    tick() = max(1, round(Int, every * (1 + mc.timer_jitter * (2rand(trng) - 1))))
    next_tick = [start + rand(trng, 0:every - 1) for _ in 1:K]
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

        for k in 1:K
            if down[k, n] == net.up[k]        # goes down or comes back
                net.up[k] = !down[k, n]
                net.up[k] || (down_since[k] = n; taken[k] = false)
            end
        end

        for (k, s) in enumerate(sites)
            p0 = s.m.total_possible
            step!(s, n; up = net.up[k])
            net.up[k] && (possible_up += s.m.total_possible - p0)
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

        # ---- takeover of down centers' free budget ----
        if mc.takeover
            for j in 1:K
                wait = max(takeover_st, mc.takeover_frac * (b.T - n * dt) / dt)
                if !net.up[j] && !taken[j] && n - down_since[j] >= wait
                    taken[j] = takeover!(net, j, n, sites, mc)
                end
            end
        end

        # ---- rebalancing ----
        n >= start || continue
        if periodic && mc.round_mode == :sync
            if n % every == 0
                foreach(k -> net.up[k] && send_status!(net, k, n, :status, sites, mc), 1:K)
                push!(rounds, n + collect_wait)
            end
            while !isempty(rounds) && rounds[1] <= n
                popfirst!(rounds)
                foreach(k -> net.up[k] && donate!(net, k, n, sites, mc), 1:K)
            end
        elseif periodic
            for k in 1:K                      # each center on its own timer
                n >= next_tick[k] || continue
                next_tick[k] = n + tick()
                net.up[k] || continue
                if mc.round_mode == :pull
                    pull_status!(net, k, sites)
                else
                    send_status!(net, k, n, :status, sites, mc)
                end
                donate!(net, k, n, sites, mc)
            end
        end
        for k in 1:K
            if on_demand && net.up[k] && sites[k].denied_now > 0 && n - last_urgent[k] >= cooldown
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
        down_hours = count(down) * dt / 60,       # summed over centers
        possible_up = possible_up / B,            # all demand of running centers served, fraction of B
        takeovers = net.takeovers,
        taken = net.taken / B,
        # budget left unspent by centers that are down at T
        stranded = sum(max(s.budget - s.Sdb[N + 1], 0.0) for (k, s) in enumerate(sites) if !net.up[k]; init = 0.0) / B,
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
    down_hours = mean(r.down_hours for r in results),
    possible_up = mean(r.possible_up for r in results),
    possible_up_min = minimum(r.possible_up for r in results),
    taken = mean(r.taken for r in results),
    stranded = mean(r.stranded for r in results),
))
