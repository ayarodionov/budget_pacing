# Plot the portfolio runs written by scripts/budgets_run.jl.
#   julia --project=plots plots/plot_budgets.jl        → out/budgets.png

using Plots

const OUT = joinpath(@__DIR__, "..", "out")
const C_BLUE, C_ORANGE, C_GRAY = "#2a78d6", "#eb6834", "#8a8984"

function read_ts(path)
    lines = readlines(path)
    header = Symbol.(split(lines[1], ','))
    data = [parse.(Float64, split(l, ',')) for l in lines[2:end] if !isempty(l)]
    Dict(h => [row[j] for row in data] for (j, h) in enumerate(header))
end

default(fontfamily = "Helvetica", linewidth = 1.5, grid = true, gridalpha = 0.15, framestyle = :axes,
        legend = :topright, foreground_color_legend = nothing, background_color_legend = nothing,
        tickfontsize = 8, guidefontsize = 9, legendfontsize = 8, titlefontsize = 10, titlelocation = :left,
        left_margin = 4Plots.mm, bottom_margin = 3Plots.mm)

"Budgets as horizontal bars (start → end) at y = budget number; underspent ones in orange."
function gantt(ts, title)
    p = plot(; title, xlabel = "day", ylabel = "budget", xlims = (0, 14), xticks = 0:14, yflip = true,
             legend = :topleft)
    plot!(p, [NaN], [NaN]; color = C_GRAY, linewidth = 6, label = "spent ≥ 99.9 %")
    plot!(p, [NaN], [NaN]; color = C_ORANGE, linewidth = 6, label = "spent < 99.9 % of what it could")
    for m in sort(unique(Int.(ts[:budget])))
        idx = findall(==(m), ts[:budget])
        t0, t1 = (ts[:t][first(idx)] - 10) / 1440, ts[:t][last(idx)] / 1440
        under = ts[:achieved][first(idx)] < 0.999
        plot!(p, [t0, t1], [m, m]; color = under ? C_ORANGE : C_GRAY, linewidth = 6, label = nothing)
    end
    p
end

"Cumulative spend / B of every budget against its own elapsed share of time."
function curves(ts, title)
    p = plot(; title, xlabel = "elapsed share of the budget's period", ylabel = "spent / B",
             xlims = (0, 1), ylims = (0, 1.02), legend = :topleft)
    plot!(p, [0, 1], [0, 1]; color = C_GRAY, linestyle = :dash, linewidth = 1, label = "even pace")
    plot!(p, [NaN], [NaN]; color = C_BLUE, alpha = 0.35, label = "spent ≥ 99.9 %")
    plot!(p, [NaN], [NaN]; color = C_ORANGE, label = "spent < 99.9 % of what it could")
    for m in sort(unique(Int.(ts[:budget])))
        idx = findall(==(m), ts[:budget])
        t = ts[:t][idx]
        x = (t .- (t[1] - 10)) ./ (t[end] - (t[1] - 10))
        under = ts[:achieved][idx[1]] < 0.999
        plot!(p, x, ts[:S][idx] ./ ts[:B][idx]; color = under ? C_ORANGE : C_BLUE, alpha = under ? 1.0 : 0.35,
              label = nothing)
    end
    p
end

iso = read_ts(joinpath(OUT, "budgets_isolated.csv"))
sha = read_ts(joinpath(OUT, "budgets_shared.csv"))
fig = plot(gantt(iso, "a) Budgets over time, isolated profiles"), gantt(sha, "b) Budgets over time, shared profile"),
           curves(iso, "c) Spend over each budget's period, isolated"), curves(sha, "d) Spend over each budget's period, shared");
           layout = (2, 2), size = (1200, 850), dpi = 120)
savefig(fig, joinpath(OUT, "budgets.png"))
println("plot → ", normpath(joinpath(OUT, "budgets.png")))
