"Per-center metrics accumulated during a run."
mutable struct Metrics
    total_demand::Float64
    total_possible::Float64   # all demand served, DB units
    issued::Int
    denied::Int
    issued_amount::Float64
    returned::Float64
    regrants::Int
    max_commit::Float64
    err_hat::Float64
    err_naive::Float64
    alert_first::Float64
    alert_minutes::Float64
    finish_time::Float64
end

Metrics() = Metrics(0.0, 0.0, 0, 0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, NaN, 0.0, NaN)

"""
    Site(cfg; tz=0.0)

One center with its own clients, its own slice of the DB and its own share of the budget
(`budget`, initially `cfg.B`). `step!` advances it by one time step; `budget` changes only
through transfers between centers (see `multi.jl`). `tz` is the local time offset [min]:
the demand pattern follows local time `t + tz`, everything else runs on absolute time.
"""
mutable struct Site
    cfg::Config
    tz::Float64
    rng::Xoshiro
    budget::Float64
    clients::Vector{Client}
    center::Center
    N::Int
    D_st::Int
    J_st::Int
    Dass_st::Int
    Dmax_st::Int
    Lr::Int
    Lg::Int
    Ccli::Matrix{Float64}     # client-counted cumulative spend, per client (reported)
    Ctot::Vector{Float64}     # Σ clients
    Dem::Matrix{Float64}      # demand per step, per client (reported)
    Sdb::Vector{Float64}      # true DB cumulative spend
    asof::Int
    # state after the last step (read by rebalancing)
    Y::Float64
    E::Float64
    Shat::Float64
    need::Float64             # β̂ · (1 − haircut) · forecast demand to T: what the center could still spend
    demand_rem::Float64       # β̂ · forecast demand to T (feasibility)
    denied_now::Int           # grant requests denied in the last step
    m::Metrics
    ts::NamedTuple
    rec_demand::Float64
    rec_spend::Float64
end

function Site(cfg::Config; tz::Float64 = 0.0, record::Bool = true)
    validate(cfg)
    rng = Xoshiro(cfg.seed)
    dt = cfg.dt
    N = round(Int, cfg.T / dt)
    nc = cfg.n_clients
    st(x) = round(Int, x / dt)

    # ---- world ----
    norm = mean(base_pattern(cfg, (n - 1) * dt + tz, 0.0) for n in 1:N)
    w = exp.(cfg.size_spread .* randn(rng, nc))
    w ./= sum(w)
    total_mu = cfg.demand_ratio * cfg.B / cfg.T
    clients = [Client(total_mu * w[i] / norm, cfg.daily_phase_jitter * randn(rng),
                      cfg.drift_sigma * randn(rng), 0, 0.0, 0.0, 0.0, 0, 0.0) for i in 1:nc]

    nrec = record ? N ÷ cfg.record_every : 0
    ts = (t = zeros(nrec), S = zeros(nrec), Y = zeros(nrec), Shat = zeros(nrec), E = zeros(nrec),
          demand = zeros(nrec), spend = zeros(nrec), rstar = zeros(nrec), p = zeros(nrec),
          beta_hat = zeros(nrec), active = zeros(Int, nrec), feasibility = zeros(nrec),
          budget = zeros(nrec))

    Site(cfg, tz, rng, cfg.B, clients, Center(cfg), N,
         st(cfg.D), st(cfg.D_jitter), st(d_assumed(cfg)), ceil(Int, d_max(cfg) / dt - 1e-9),
         st(cfg.report_lag), st(cfg.grant_latency),
         zeros(nc, N + 1), zeros(N + 1), zeros(nc, N), zeros(N + 1), 1,
         0.0, 0.0, 0.0, 0.0, 0.0, 0, Metrics(), ts, 0.0, 0.0)
end

"Budget this center can give away now without breaking its hard-cap invariant."
headroom(s::Site) = max(s.budget - (s.Y + s.E) / (1 - s.cfg.delta), 0.0)

"Advance site `s` by step `n` (time `(n-1)·dt` → `n·dt`)."
function step!(s::Site, n::Int)
    cfg, rng, center, clients, m = s.cfg, s.rng, s.center, s.clients, s.m
    Ccli, Ctot, Dem, Sdb = s.Ccli, s.Ctot, s.Dem, s.Sdb
    dt, N, nc = cfg.dt, s.N, cfg.n_clients
    Lr, Lg = s.Lr, s.Lg
    cap = s.budget * (1 - cfg.delta)
    t = (n - 1) * dt
    now = n + 1

    # ================= clients: demand, spending, renewal =================
    sdb_step = 0.0
    dem_step = 0.0
    for (i, c) in enumerate(clients)
        m_rate = c.mu * base_pattern(cfg, t + s.tz, c.phase) * shock(cfg, t) * exp(c.logdrift - cfg.drift_sigma^2 / 2)
        d = max(0.0, m_rate * dt + cfg.noise_cv * m_rate * sqrt(dt) * randn(rng))
        c.logdrift += -c.logdrift * dt / cfg.drift_tau + cfg.drift_sigma * sqrt(2dt / cfg.drift_tau) * randn(rng)
        Dem[i, n] = d
        dem_step += d
        c.lam_own += (n == 1 ? 1.0 : dt / cfg.ewma_minutes) * (d / dt - c.lam_own)

        spend = 0.0
        if c.grant != 0
            g = center.grants[c.grant]
            if now <= g.expiry_idx
                # local pacing: never faster than the grant rate, even if demand is there
                c.tokens = min(c.tokens + g.rate * dt, g.rate * max(cfg.burst_minutes, dt))
                spend = min(d, c.tokens, g.amount - c.used)
                c.tokens -= spend
                c.used += spend
            end
            if now >= g.expiry_idx          # expired: stop using, center frees the rest
                g.switch_idx = now
                g.release_idx = now
                c.grant = 0
            end
        end
        # partial return: give back what the client's own demand cannot use before expiry;
        # the rate stays, only the reserved amount shrinks (client enforces the new limit)
        if c.grant != 0 && cfg.return_unused && cfg.return_keep_factor > 0
            g = center.grants[c.grant]
            keep = cfg.return_keep_factor * min(g.rate, c.lam_own) * (g.expiry_idx - now) * dt
            excess = g.amount - c.used - keep
            if excess > max(cfg.min_grant, 0.1 * g.amount)
                g.amount -= excess
                m.returned += excess
            end
        end
        c.cum_spend += spend
        Ccli[i, now] = c.cum_spend
        factor = cfg.beta_true * (1 + cfg.beta_noise * clamp(randn(rng), -3.0, 3.0))
        sdb_step += spend * factor

        if c.request_idx == 0 && now <= N
            if c.grant == 0
                c.request_idx = now
            else
                g = center.grants[c.grant]
                ratio = c.lam_own / max(g.lam_issue, eps())
                if (g.expiry_idx - now) * dt <= cfg.renew_lead || g.amount - c.used <= g.rate * cfg.renew_lead
                    c.request_idx = now
                elseif ratio > 1 + cfg.regrant_threshold
                    c.request_idx = now           # demand rose: ask for a re-sized grant
                    m.regrants += 1
                end
            end
        end
    end
    Sdb[now] = Sdb[n] + sdb_step
    isnan(m.finish_time) && Sdb[now] >= 0.999 * s.budget && (m.finish_time = n * dt)
    Ctot[now] = sum(view(Ccli, :, now))
    m.total_demand += dem_step
    m.total_possible += dem_step * cfg.beta_true

    # ================= center: observe =================
    s.asof = max(s.asof, now - s.D_st - (s.J_st > 0 ? rand(rng, 0:s.J_st) : 0))
    s.asof = max(s.asof, 1)
    Y = Sdb[s.asof]                    # delayed DB value (the only authoritative number)
    rep = max(1, now - Lr)             # latest index covered by client reports
    a_est = clamp(now - s.Dass_st, 1, rep)
    sidx = clamp(now - s.Dmax_st, 1, rep)   # surely included in Y

    # ================= center: estimate =================
    kd = n - Lr
    kd >= 1 && update_demand!(center, cfg, view(Dem, :, kd), (kd - 1) * dt)
    update_beta!(center, cfg, Y, Ctot[a_est])
    # nowcast: delayed truth + calibrated fast signal over the blind window
    Shat = cfg.nowcast == :none ? Y : Y + center.beta_hat * (Ctot[rep] - Ctot[a_est])
    m.err_hat += abs(Shat - Sdb[now])
    m.err_naive += abs(Y - Sdb[now])

    # ================= center: pace =================
    Trem = cfg.T - n * dt
    T_plan = cfg.T - cfg.finish_buffer        # aim to be done early; the buffer absorbs errors
    R = max(cap - Shat, 0.0)
    lam_tot = sum(center.lam)
    Λrem = remaining_demand(center, cfg, n * dt, cfg.T)
    rstar = if Trem <= 0
        0.0
    elseif n * dt >= T_plan
        Inf                                   # inside the buffer: serve all demand, cap protects
    elseif cfg.strategy == :uniform
        R / ((T_plan - n * dt) * (1 - cfg.forecast_haircut))
    else
        Λplan = (1 - cfg.forecast_haircut) * remaining_demand(center, cfg, n * dt, T_plan)
        Λplan > 0 ? lam_tot * R / Λplan : 0.0
    end
    # r* is in DB units (R is), demand is in client units: convert with β̂
    p = lam_tot > 0 ? rstar / (center.beta_hat * lam_tot) : 0.0
    feasibility = R > 0 ? Λrem * center.beta_hat / R : Inf
    if n * dt > DAY && R > cfg.alert_tol * cfg.B && feasibility < 1.0      # projected demand cannot fill the budget
        isnan(m.alert_first) && (m.alert_first = n * dt)
        m.alert_minutes += dt
    end

    # ================= center: exposure (hard-cap invariant) =================
    E = 0.0
    keep = 0
    for k in center.unsettled
        e = exposure(center.grants[k], Ccli, sidx, now, cfg)
        if e > 0                          # e == 0: nothing more can appear in the DB
            keep += 1
            center.unsettled[keep] = k
            E += e
        end
    end
    resize!(center.unsettled, keep)

    # ================= center: grant requests =================
    τ = clamp(cfg.tau_frac * Trem, cfg.tau_min, cfg.tau_max)
    τst = max(1, round(Int, τ / dt))
    denied_before = m.denied
    for i in randperm(rng, nc)
        c = clients[i]
        (c.request_idx == 0 || now - c.request_idx < Lg || now > N) && continue
        rate = min(p, 1 + cfg.demand_headroom) * center.lam[i]
        expiry = min(now + τst, N + 1)
        amount = rate * (expiry - now) * dt

        old = c.grant
        e_before = e_after = 0.0
        if old != 0                       # tentatively replace the old grant
            go = center.grants[old]
            e_before = exposure(go, Ccli, sidx, now, cfg)
            go.switch_idx = now
            go.release_idx = cfg.return_unused ? now : go.expiry_idx
            e_after = exposure(go, Ccli, sidx, now, cfg)
        end
        hr = (cap - Y - (E - e_before + e_after)) / cfg.beta_max
        g = min(amount, hr)
        if g < cfg.min_grant
            if old != 0                   # keep using the old grant
                go = center.grants[old]
                go.switch_idx = 0
                go.release_idx = 0
            end
            m.denied += 1
            continue
        end
        E += e_after - e_before + cfg.beta_max * g
        push!(center.grants, Grant(i, g, rate, center.lam[i], now, expiry, 0, 0))
        push!(center.unsettled, length(center.grants))
        c.grant = length(center.grants)
        c.tokens = min(c.tokens, rate * max(cfg.burst_minutes, dt))   # carry over local pacing state
        c.used = 0.0
        c.request_idx = 0
        m.issued += 1
        m.issued_amount += g
    end
    m.max_commit = max(m.max_commit, (Y + E) / cfg.B)

    s.Y, s.E, s.Shat = Y, E, Shat
    s.demand_rem = center.beta_hat * Λrem
    s.need = (1 - cfg.forecast_haircut) * s.demand_rem
    s.denied_now = m.denied - denied_before

    # ================= record =================
    if !isempty(s.ts.t)
        s.rec_demand += dem_step * cfg.beta_true
        s.rec_spend += sdb_step
        if n % cfg.record_every == 0
            ts = s.ts
            j = n ÷ cfg.record_every
            span = cfg.record_every * dt
            ts.t[j] = n * dt
            ts.S[j] = Sdb[now]
            ts.Y[j] = Y
            ts.Shat[j] = Shat
            ts.E[j] = E
            ts.demand[j] = s.rec_demand / span
            ts.spend[j] = s.rec_spend / span
            ts.rstar[j] = min(p, 1 + cfg.demand_headroom) * lam_tot * center.beta_hat   # DB units
            ts.p[j] = min(p, 1 + cfg.demand_headroom)   # effective throttle
            ts.beta_hat[j] = center.beta_hat
            ts.active[j] = count(c -> c.grant != 0, clients)
            ts.feasibility[j] = feasibility
            ts.budget[j] = s.budget
            s.rec_demand = s.rec_spend = 0.0
        end
    end
    nothing
end

"Scalar metrics of a finished site."
function summarize(s::Site)
    cfg, m, N = s.cfg, s.m, s.N
    S_final = s.Sdb[N + 1]
    (
        spend_ratio = S_final / cfg.B,
        overspend = S_final - cfg.B > 1e-9 * cfg.B ? S_final - cfg.B : 0.0,   # ignore float rounding
        underspend = max(cfg.B - S_final, 0.0),
        possible_ratio = m.total_possible / cfg.B,        # all demand served, as fraction of B
        max_commit = m.max_commit,                        # max (Y+E)/B, must be ≤ 1-δ
        grants = m.issued,
        grants_per_min = m.issued / cfg.T,
        denied = m.denied,
        utilization = s.Ctot[N + 1] / max(m.issued_amount, eps()),
        regrants = m.regrants,
        returned = m.returned / max(m.issued_amount, eps()),  # fraction of granted amount returned early
        est_err = m.err_hat / N / cfg.B,                  # mean |Ŝ − S| / B
        naive_err = m.err_naive / N / cfg.B,              # mean |Y − S| / B
        beta_hat = s.center.beta_hat,
        finish_early = cfg.T - m.finish_time,             # how long before T spend reached 99.9% of B [min]
        alert_first = m.alert_first,
        alert_minutes = m.alert_minutes,
    )
end

"""
    simulate(cfg; record=true) -> (summary, ts)

Run one simulation. `summary` is a NamedTuple of scalar metrics; `ts` is a NamedTuple of
time series sampled every `cfg.record_every` steps (empty vectors when `record=false`).
"""
function simulate(cfg::Config; record::Bool = true)
    s = Site(cfg; record)
    for n in 1:s.N
        step!(s, n)
    end
    summarize(s), s.ts
end
