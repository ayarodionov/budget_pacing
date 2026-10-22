# Multi-center rebalancing comparison used in MULTI.md. Prints markdown tables.
#   julia -t auto scripts/multi_strategies.jl [runs] > out/multi.md

include(joinpath(@__DIR__, "..", "src", "BudgetPacing.jl"))
using .BudgetPacing
using Printf

const RUNS = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 40
agg(mc) = aggregate_multi(run_mc(mc; seeds = 1:RUNS))
fmt_h(x) = isnan(x) ? "–" : @sprintf("%.1f", x)
spend_cell(a) = @sprintf("%.2f / %.2f", 100a.spend_mean, 100a.spend_min)

base = MultiConfig()
const mc_B = base.base.B
shock(start, len, f) = (shock_start = start, shock_length = len, shock_factor = f)
only(k, o) = [i == k ? o : (;) for i in 1:4]
worlds = [
    "loads as assumed"     => base,
    "loads 30/30/20/20"    => with(base; load_true = [0.3, 0.3, 0.2, 0.2]),
    "random loads σ=0.3"   => with(base; load_sigma = 0.3),
    "D: day-4 shock 20%"   => with(base; overrides = only(4, shock(3 * 1440.0, 1440.0, 0.2))),
    "A: last-12h 30%"      => with(base; overrides = only(1, shock(6.5 * 1440.0, 720.0, 0.3))),
    "demand ×1.15"         => with(base; base = with(base.base; demand_ratio = 1.15)),
]
modes = [
    "none (static split)" => (rebalance = :none,),
    "periodic (60 min)"   => (rebalance = :periodic,),
    "on demand"           => (rebalance = :on_demand,),
    "both"                => (rebalance = :both,),
]

println("\n### A. Rebalancing mode\n\n_cell: mean % / min % of B spent; $RUNS runs per cell_\n")
println("| mode | ", join(first.(worlds), " | "), " |")
println("|---|", repeat("---|", length(worlds)))
results = Dict{Tuple{String,String},Any}()
for (mname, kw) in modes
    cells = String[]
    for (wname, w) in worlds
        a = agg(with(w; kw...))
        results[(mname, wname)] = a
        push!(cells, spend_cell(a))
    end
    println("| $mname | ", join(cells, " | "), " |")
end

println("\n### B. Cost of rebalancing (mode `both`)\n\n_$RUNS runs per row; moved = gross transfers, net = start → end shift of budget shares (% of B)_\n")
println("| world | runs over B | centers over own budget | served spread none → both (pp) | transfers | moved % | net % | messages/h | done before T (h) |")
println("|---|---|---|---|---|---|---|---|---|")
for (wname, _) in worlds
    a, a0 = results[("both", wname)], results[("none (static split)", wname)]
    @printf("| %s | %d | %d | %.1f → %.1f | %.0f | %.1f | %.1f | %.1f | %s |\n", wname, a.over_runs, a.site_over,
            100a0.served_spread, 100a.served_spread, a.transfers, 100a.moved, 100a.net_moved, a.messages_per_h,
            fmt_h(a.T_minus_finish_h))
end

function detail(title, world, rows)
    println("\n### $title\n\n_$RUNS runs per row_\n")
    println("| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |")
    println("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for (name, kw) in rows
        a = agg(with(world; kw...))
        @printf("| %s | %.3f | %.3f | %d | %.2f | %d | %.1f | %.0f | %.1f | %.1f | %.1f | %s |\n", name, 100a.spend_mean,
                100a.spend_min, a.over_runs, 1000a.over_max / mc_B, a.site_over, 100a.served_spread, a.transfers,
                100a.moved, 100a.net_moved, a.messages_per_h, fmt_h(a.T_minus_finish_h))
    end
end

detail("C. Rebalancing parameters (world: loads 30/30/20/20, mode `both`)",
       with(base; load_true = [0.3, 0.3, 0.2, 0.2]), [
    "default (every 60 min, tol 0.02, zero latency)" => (;),
    "every 15 min"                 => (rebalance_every = 15.0,),
    "every 240 min"                => (rebalance_every = 240.0,),
    "periodic only, every 240 min" => (rebalance = :periodic, rebalance_every = 240.0),
    "tol 0"                        => (rebalance_tol = 0.0,),
    "tol 0.05"                     => (rebalance_tol = 0.05,),
    "tol 0.1"                      => (rebalance_tol = 0.1,),
    "start at t = 0"               => (rebalance_start = 0.0,),
    "latency 30 ± 30 min"          => (net_latency = 30.0, net_jitter = 30.0),
    "latency 120 min"              => (net_latency = 120.0,),
    "near-ideal: every 5 min, latency 1 min" => (rebalance_every = 5.0, net_latency = 1.0),
    "on demand only"               => (rebalance = :on_demand,),
])

detail("D. Late local drop (world: A at 30% in the last 12 h)",
       with(base; overrides = only(1, shock(6.5 * 1440.0, 720.0, 0.3))), [
    "none"                => (rebalance = :none,),
    "periodic (60 min)"   => (rebalance = :periodic,),
    "on demand"           => (rebalance = :on_demand,),
    "both"                => (;),
    "both, haircut 0.05"  => (base = with(base.base; forecast_haircut = 0.05),),
    "both, latency 30 min"=> (net_latency = 30.0,),
])

# ---------------- E. center outages ----------------
down(k, t0, len) = [i == k ? [(t0, len)] : Tuple{Float64,Float64}[] for i in 1:4]
outage_worlds = [
    "A down 6 h on day 3"         => with(base; outages = down(1, 2 * 1440.0 + 600, 360.0)),
    "A down the last 12 h"        => with(base; outages = down(1, 6.5 * 1440.0, 720.0)),
    "B down the last 2 days"      => with(base; outages = down(2, 5 * 1440.0, 2 * 1440.0)),
    "random: MTBF 2 d, MTTR 4 h"  => with(base; outage_mtbf = 2 * 1440.0, outage_mttr = 240.0),
    "random: MTBF 1 d, MTTR 12 h" => with(base; outage_mtbf = 1440.0, outage_mttr = 720.0),
]
policies = [
    "frozen (no takeover)"                 => (takeover = false,),
    "takeover once grants settled"         => (takeover_frac = 0.0,),
    "takeover, wait 0.1 × time left (default)" => (;),
    "takeover, wait 0.3 × time left"       => (takeover_frac = 0.3,),
]

println("\n### E. Center outages (mode `both`, zero latency)\n\n_cell: mean % / min % of B spent; $RUNS runs per cell_\n")
println("| policy | ", join(first.(outage_worlds), " | "), " |")
println("|---|", repeat("---|", length(outage_worlds)))
eres = Dict{Tuple{String,String},Any}()
for (pname, kw) in policies
    cells = String[]
    for (wname, w) in outage_worlds
        a = agg(with(w; kw...))
        eres[(pname, wname)] = a
        push!(cells, spend_cell(a))
    end
    println("| $pname | ", join(cells, " | "), " |")
end

println("\n_Details: taken over % of B / served spread pp / budget stranded in centers down at T, % of B_\n")
println("| policy | ", join(first.(outage_worlds), " | "), " |")
println("|---|", repeat("---|", length(outage_worlds)))
for (pname, _) in policies
    cells = [(a = eres[(pname, w)]; @sprintf("%.1f / %.1f / %.2f", 100a.taken, 100a.served_spread, 100a.stranded))
             for (w, _) in outage_worlds]
    println("| $pname | ", join(cells, " | "), " |")
end
println("| _demand of running centers, mean / min % of B_ | ",
        join([(a = eres[("frozen (no takeover)", w)]; @sprintf("%.0f / %.0f", 100a.possible_up, 100a.possible_up_min))
              for (w, _) in outage_worlds], " | "), " |")

detail("F. Safety of takeover (world: random outages MTBF 1 d, MTTR 12 h)",
       with(base; outage_mtbf = 1440.0, outage_mttr = 720.0), [
    "takeover once grants settled (τ_max + D_max)" => (takeover_frac = 0.0,),
    "takeover after 10 min (too early!)"           => (takeover_frac = 0.0, takeover_after = 10.0),
])
