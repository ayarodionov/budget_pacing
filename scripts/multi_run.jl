# Single multi-center run (4 centers A–D, different load and time zones), true loads differ
# from the assumed split; static split vs rebalancing on the same world (same seed).
#   julia scripts/multi_run.jl
# Writes out/multi_run_<mode>.csv (plot them with plots/plot_multi.jl).

include(joinpath(@__DIR__, "..", "src", "BudgetPacing.jl"))
using .BudgetPacing
using Printf

world = MultiConfig(load_true = [0.3, 0.3, 0.2, 0.2])

for mode in (:none, :both)
    mc = with(world; rebalance = mode)
    summary, ts, sites = simulate_multi(mc)
    println("\n=== rebalance = $mode, seed = $(mc.base.seed)")
    @printf("  spend %.4f%% of B, over %g, transfers %d (moved %.1f%% of B), messages/h %.1f\n",
            100summary.spend_ratio, summary.overspend, summary.transfers, 100summary.moved, summary.messages_per_h)
    println("  center  load assumed/true  budget start→end  spent   served  denied")
    for (k, s) in enumerate(sites)
        @printf("  %-6s  %6.3f / %6.3f     %6.3f → %6.3f   %6.3f  %6.3f  %6d\n", mc.names[k], mc.load[k],
                summary.load_true[k], mc.load[k], summary.budget_final[k], summary.spend_final[k],
                summary.served[k], s.denied)
    end
    path = write_csv(joinpath(@__DIR__, "..", "out", "multi_run_$mode.csv"), ts)
    println("  time series → ", normpath(path))
end

# Outage: B is down for the last 2 days; its budget frozen vs taken over by A, C and D.
outage = MultiConfig(outages = [Tuple{Float64,Float64}[], [(5 * 1440.0, 2 * 1440.0)],
                                Tuple{Float64,Float64}[], Tuple{Float64,Float64}[]])
for (name, mc) in ("frozen" => with(outage; takeover = false), "takeover" => outage)
    summary, ts, _ = simulate_multi(mc)
    @printf("\n=== B down for the last 2 days, %s: spend %.4f%% of B, taken over %.2f%% of B, over %g\n",
            name, 100summary.spend_ratio, 100summary.taken, summary.overspend)
    path = write_csv(joinpath(@__DIR__, "..", "out", "multi_outage_$name.csv"), ts)
    println("  time series → ", normpath(path))
end
