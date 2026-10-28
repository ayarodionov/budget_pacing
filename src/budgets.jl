"""
    PortfolioConfig(; kwargs...)

Many independent budgets spent through the same clients. Budget `m` has its own size `B_m`,
start, length and demand ratio (demand / (B_m / length)). Each must never spend more than its
`B_m` and should spend as much of it as its demand allows; budgets never share money.

What the budgets share is the world: every client serves every budget, so the clients' sizes,
daily phases and slow drift are common to all of them. With `profile = :shared` the center also
learns one daily demand shape from all active budgets, so a budget that starts late can pace with
it from its first minute; with `:isolated` every budget learns its own, as a single center does.
"""
Base.@kwdef struct PortfolioConfig
    base::Config = Config()          # world, assumptions and policy shared by all budgets
                                     # (base.B, base.T and base.demand_ratio are set per budget)
    horizon::Float64 = 14 * 1440.0   # simulated time [min]; it starts Monday 00:00
    n_budgets::Int = 20
    B_range::Tuple{Float64,Float64} = (1.0e4, 1.0e6)    # budget size, log-uniform
    days_range::Tuple{Float64,Float64} = (1.0, 10.0)    # budget length [days], log-uniform
    ratio_range::Tuple{Float64,Float64} = (0.6, 2.0)    # demand ratio, uniform
    budgets::Vector{Any} = []        # explicit (B, start, length, ratio) [min]; replaces the random draw
    profile::Symbol = :shared        # :shared | :isolated
    scale_min_grant::Bool = true     # min_grant scales with the budget (base.min_grant × B_m / base.B)
    bundle_window::Float64 = 5.0     # a client that sends a request also renews its other grants that would
                                     # need renewal within this window, in the same message [min] (0 = no bundling)
end

function validate(pc::PortfolioConfig)
    pc.profile in (:shared, :isolated) || error("profile must be :shared or :isolated")
    for (B, start, len, ratio) in draw_budgets(pc, Xoshiro(0))
        start >= 0 && start + len <= pc.horizon + 1e-9 || error("budget outside the horizon")
    end
    nothing
end

"Budgets as (B, start, length, ratio); starts and lengths are whole minutes."
function draw_budgets(pc::PortfolioConfig, rng)
    isempty(pc.budgets) || return [Tuple(Float64.(b)) for b in pc.budgets]
    logu(lo, hi) = exp(log(lo) + (log(hi) - log(lo)) * rand(rng))
    map(1:pc.n_budgets) do _
        B = logu(pc.B_range...)
        len = round(min(logu(pc.days_range...) * DAY, pc.horizon))
        start = round((pc.horizon - len) * rand(rng))
        ratio = pc.ratio_range[1] + (pc.ratio_range[2] - pc.ratio_range[1]) * rand(rng)
        (B, start, len, ratio)
    end
end

"Client `c` of site `s` would need a new grant within `window` minutes (index `now`)."
function due_within(s::Site, c::Client, now, window)
    c.grant == 0 && return true
    g = s.center.grants[c.grant]
    (g.expiry_idx - now) * s.cfg.dt <= window || g.amount - c.used <= g.rate * window
end

"""
    simulate_budgets(pc; record=false) -> (budgets, sites, stats)

`budgets` is a vector of NamedTuples, one per budget: its parameters and the single-center
summary of how it was spent (`spend_ratio` = spend / B_m, `achieved` = spend / min(B_m, all
its demand)). `stats` counts the clients' grant requests and the messages that carry them: one
per request without bundling, one per client and minute with bundling.
"""
function simulate_budgets(pc::PortfolioConfig; record::Bool = false)
    validate(pc)
    b = pc.base
    rng = Xoshiro(b.seed)
    specs = draw_budgets(pc, rng)
    dt, nc = b.dt, b.n_clients
    w = exp.(b.size_spread .* randn(rng, nc))
    world = World(w ./ sum(w), b.daily_phase_jitter .* randn(rng, nc), b.drift_sigma .* randn(rng, nc))
    shared = pc.profile == :shared ? SharedProfile(b) : nothing
    sites = map(enumerate(specs)) do (m, (B, start, len, ratio))
        mg = pc.scale_min_grant ? b.min_grant * B / b.B : b.min_grant
        cfg = with(b; B = B, T = len, demand_ratio = ratio, min_grant = mg, seed = 1000 * b.seed + m)
        Site(cfg; t0 = start, world, shared, record)
    end
    first_step = [round(Int, start / dt) for (_, start, _, _) in specs]
    requests = messages = early = 0

    for a in 1:round(Int, pc.horizon / dt)
        active = Int[]
        for (m, s) in enumerate(sites)
            n = a - first_step[m]
            1 <= n <= s.N || continue
            step!(s, n)
            push!(active, m)
        end
        # requests sent this step, per client; with bundling, add the grants due soon to the same message
        for i in 1:nc
            reqs = 0
            for m in active
                s = sites[m]
                s.clients[i].request_idx == a - first_step[m] + 1 && (reqs += 1)
            end
            if reqs > 0 && pc.bundle_window > 0
                for m in active
                    s, now = sites[m], a - first_step[m] + 1
                    c = s.clients[i]
                    if c.request_idx == 0 && now <= s.N && due_within(s, c, now, pc.bundle_window)
                        c.request_idx = now       # renew early, in the same message
                        reqs += 1
                        early += 1
                    end
                end
            end
            requests += reqs
            messages += pc.bundle_window > 0 ? (reqs > 0) : reqs
        end
        @. world.logdrift += -world.logdrift * dt / b.drift_tau + b.drift_sigma * sqrt(2dt / b.drift_tau) * randn(rng)
    end

    budgets = map(enumerate(sites)) do (m, s)
        B, start, len, ratio = specs[m]
        r = summarize(s)
        (B = B, start = start, days = len / DAY, ratio = ratio, spend_ratio = r.spend_ratio,
         overspend = r.overspend, possible = r.possible_ratio,
         achieved = r.spend_ratio / min(1.0, r.possible_ratio),   # what it spent of what it could
         finish_early = r.finish_early, grants = r.grants, est_err = r.est_err,
         # how many other budgets were already running when it started (they taught the shared profile)
         started_after = count(k -> k != m && specs[k][2] < start, eachindex(specs)))
    end
    stats = (requests_per_min = requests / pc.horizon, messages_per_min = messages / pc.horizon,
             early_per_min = early / pc.horizon,
             grants_per_min = sum(s.m.issued for s in sites) / pc.horizon)
    budgets, sites, stats
end

"""
    run_mc(pc::PortfolioConfig; seeds=1:20) -> Vector of (budgets, stats), one per run
"""
function run_mc(pc::PortfolioConfig; seeds = 1:20)
    results = Vector{Any}(undef, length(seeds))
    Threads.@threads for j in eachindex(seeds)
        budgets, _, stats = simulate_budgets(with(pc; base = with(pc.base; seed = seeds[j])))
        results[j] = (; budgets, stats)
    end
    results
end

"""
    aggregate_budgets(results; select = b -> true)

Statistics over all budgets of all runs that pass `select`. `achieved` is what a budget spent
of what it could spend, min(B_m, all its demand); `weighted` weights budgets by that amount.
"""
function aggregate_budgets(results; select = b -> true)
    bs = [b for r in results for b in (r isa NamedTuple ? r.budgets : r) if select(b)]
    isempty(bs) && return nothing
    ach = sort([b.achieved for b in bs])
    cap = [b.B * min(1.0, b.possible) for b in bs]
    (
        budgets = length(bs),
        weighted = sum(b.achieved * c for (b, c) in zip(bs, cap)) / sum(cap),
        mean = mean(ach),
        p05 = quantile_sorted(ach, 0.05),
        worst = first(ach),
        full = count(>=(0.999), ach) / length(ach),          # share of budgets spent to ≥ 99.9 %
        over = count(b -> b.overspend > 0, bs),              # must be 0
        over_max = maximum(b.overspend / b.B for b in bs),
    )
end
