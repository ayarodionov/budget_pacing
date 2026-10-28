# Monte Carlo over portfolios of independent budgets on the same clients. Prints markdown tables.
#   julia -t auto scripts/budgets_mc.jl [runs] > out/budgets.md

include(joinpath(@__DIR__, "..", "src", "BudgetPacing.jl"))
using .BudgetPacing
using Printf

const RUNS = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 20
base = PortfolioConfig()
cell(a) = @sprintf("%.2f / %.2f / %.0f", 100a.weighted, 100a.p05, 100a.full)
note = "cell: weighted % achieved / 5th percentile % / share of budgets ≥ 99.9 %; achieved = spend / min(B, all demand)"

worlds = [
    "default: demand 0.6–2×, 1–10 d"   => base,
    "demand 1.0–1.2×, 1–10 d"          => with(base; ratio_range = (1.0, 1.2)),
    "demand 1.0–1.2×, 6 h – 2 d"       => with(base; ratio_range = (1.0, 1.2), days_range = (0.25, 2.0)),
    "demand 0.6–0.95× (cannot fill)"   => with(base; ratio_range = (0.6, 0.95)),
    "50 budgets, demand 1.0–1.2×, 6 h – 2 d" => with(base; n_budgets = 50, ratio_range = (1.0, 1.2), days_range = (0.25, 2.0)),
]
res = Dict{Tuple{String,Symbol},Any}()
println("\n### A. Isolated vs shared demand profile\n\n_$(note); $RUNS portfolios of 20 budgets per cell (50 in the last column)_\n")
println("| profile | ", join(first.(worlds), " | "), " |")
println("|---|", repeat("---|", length(worlds)))
for prof in (:isolated, :shared)
    cells = String[]
    for (wname, w) in worlds
        r = run_mc(with(w; profile = prof); seeds = 1:RUNS)
        res[(wname, prof)] = r
        push!(cells, cell(aggregate_budgets(r)))
    end
    println("| $prof | ", join(cells, " | "), " |")
end
over = sum(aggregate_budgets(r).over for r in values(res))
println("\n_Budgets over their cap, all cells: $(over)_")

wname = "demand 1.0–1.2×, 6 h – 2 d"
classes = [
    "≤ 12 h"                               => b -> b.days <= 0.5,
    "12–24 h"                              => b -> 0.5 < b.days <= 1,
    "1–2 d"                                => b -> b.days > 1,
    "starts before any other budget"       => b -> b.started_after == 0,
    "starts after at least one other"      => b -> b.started_after >= 1,
    "starts 06–18 h"                       => b -> 360 <= mod(b.start, 1440) < 1080,
    "starts 18–06 h"                       => b -> !(360 <= mod(b.start, 1440) < 1080),
]
println("\n### B. Which budgets gain (world: $wname)\n\n_$(note)_\n")
println("| budgets | count | isolated | shared |")
println("|---|---|---|---|")
for (cname, sel) in classes
    ai = aggregate_budgets(res[(wname, :isolated)]; select = sel)
    as = aggregate_budgets(res[(wname, :shared)]; select = sel)
    println("| $cname | $(ai.budgets) | $(cell(ai)) | $(cell(as)) |")
end

function detail(title, world, rows)
    println("\n### $title\n\n_$RUNS portfolios per row_\n")
    println("| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min | messages/min |")
    println("|---|---|---|---|---|---|---|---|---|---|")
    for (name, kw) in rows
        pc = with(world; kw...)
        r = run_mc(pc; seeds = 1:RUNS)
        a = aggregate_budgets(r)
        st(f) = sum(getfield(x.stats, f) for x in r) / length(r)
        @printf("| %s | %.2f | %.2f | %.2f | %.2f | %.0f %% | %d | %.2f | %.1f | %.1f |\n", name, 100a.weighted, 100a.mean,
                100a.p05, 100a.worst, 100a.full, a.over, 1000a.over_max, st(:grants_per_min), st(:messages_per_min))
    end
end

detail("C. Grant granularity (world: default)", base, [
    "min grant scales with the budget (default)" => (;),
    "fixed min grant (1 unit for every budget)"  => (scale_min_grant = false,),
])

detail("D. Safety assumptions (world: default)", base, [
    "assumptions hold (default)"         => (;),
    "β_true = 1.08 > β_max = 1.06"       => (base = with(base.base; beta_true = 1.08),),
    "D = 30 ± 15 min, D_max = 30"        => (base = with(base.base; D_jitter = 15.0, D_max = 30.0),),
])

detail("E. Number of budgets (world: default)", base, [
    "10 budgets" => (n_budgets = 10,),
    "20 budgets" => (;),
    "50 budgets" => (n_budgets = 50,),
])

for (wname, w) in ["default" => base, "50 budgets" => with(base; n_budgets = 50)]
    detail("F. Bundling grant requests per client (world: $wname)", w, [
        "no bundling"               => (bundle_window = 0.0,),
        "bundle within 5 min (default)" => (;),
        "bundle within 10 min"      => (bundle_window = 10.0,),
        "bundle within 30 min"      => (bundle_window = 30.0,),
    ])
end
