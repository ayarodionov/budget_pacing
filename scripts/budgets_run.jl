# One portfolio of independent budgets on the same clients, isolated vs shared demand profile.
#   julia scripts/budgets_run.jl
# Prints one line per budget and writes out/budgets_<profile>.csv (plot with plots/plot_budgets.jl).

include(joinpath(@__DIR__, "..", "src", "BudgetPacing.jl"))
using .BudgetPacing
using Printf

pc = PortfolioConfig(ratio_range = (1.0, 1.2), days_range = (0.25, 2.0))   # tight demand, short budgets

for profile in (:isolated, :shared)
    budgets, sites = simulate_budgets(with(pc; profile); record = true)
    println("\n=== profile = $profile, seed = $(pc.base.seed)")
    println("  budget  start (d)  hour  length (d)        B  ratio  spent/B  achieved  over")
    for (m, b) in enumerate(budgets)
        @printf("  %6d  %9.2f  %4.1f  %10.2f  %7.0f  %5.2f  %7.4f  %8.4f  %4g\n", m, b.start / 1440,
                mod(b.start, 1440) / 60, b.days, b.B, b.ratio, b.spend_ratio, b.achieved, b.overspend)
    end
    a = aggregate_budgets([budgets])
    @printf("  weighted achieved %.4f, worst %.4f, budgets ≥ 99.9 %%: %d of %d, over: %d\n",
            a.weighted, a.worst, round(Int, a.full * a.budgets), a.budgets, a.over)

    # long format: one row per (budget, sample)
    cols = (budget = Int[], t = Float64[], S = Float64[], B = Float64[], achieved = Float64[])
    for (m, s) in enumerate(sites), j in eachindex(s.ts.t)
        push!(cols.budget, m); push!(cols.t, s.ts.t[j] + s.t0); push!(cols.S, s.ts.S[j])
        push!(cols.B, s.cfg.B); push!(cols.achieved, budgets[m].achieved)
    end
    println("  time series → ", normpath(write_csv(joinpath(@__DIR__, "..", "out", "budgets_$profile.csv"), cols)))
end
