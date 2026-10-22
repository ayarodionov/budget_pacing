# Plot the multi-center runs written by scripts/multi_run.jl.
#   julia --project=plots plots/plot_multi.jl        → out/multi.png

using Plots

const OUT = joinpath(@__DIR__, "..", "out")
const CENTERS = [("A", "#2a78d6"), ("B", "#eb6834"), ("C", "#1baf7a"), ("D", "#eda100")]
const LOAD_TRUE = [0.3, 0.3, 0.2, 0.2]   # match scripts/multi_run.jl
const C_GRAY = "#8a8984"
const B = 1.0e6                          # match Config() defaults

function read_ts(path)
    lines = readlines(path)
    header = Symbol.(split(lines[1], ','))
    data = [parse.(Float64, split(l, ',')) for l in lines[2:end] if !isempty(l)]
    Dict(h => [row[j] for row in data] for (j, h) in enumerate(header))
end

none = read_ts(joinpath(OUT, "multi_run_none.csv"))
both = read_ts(joinpath(OUT, "multi_run_both.csv"))
days(ts) = ts[:t] ./ 1440
col(ts, f, c) = ts[Symbol(f, "_", c)]

default(fontfamily = "Helvetica", linewidth = 2, grid = true, gridalpha = 0.15, framestyle = :axes,
        legend = :topright, foreground_color_legend = nothing, background_color_legend = nothing,
        tickfontsize = 8, guidefontsize = 9, legendfontsize = 8, titlefontsize = 10, titlelocation = :left,
        left_margin = 4Plots.mm, bottom_margin = 3Plots.mm, right_margin = 8Plots.mm)

"Direct label at the right end of a line (identity is not color-only)."
endlabel!(p, x, y, txt, c) = annotate!(p, x[end] + 0.06, y[end], text(txt, 8, :left, c))

p1 = plot(title = "a) Budget share B_k / B with rebalancing (dashed: true load share)", ylabel = "share of B",
          xlabel = "day", xlims = (0, 7), xticks = 0:7, ylims = (0, 0.55), yticks = (0:0.1:0.5, ["0", "0.1", "0.2", "0.3", "0.4", "0.5"]),
          legend = :topright)
for (k, (c, color)) in enumerate(CENTERS)
    hline!(p1, [LOAD_TRUE[k]]; color = color, linestyle = :dash, linewidth = 1, label = nothing)
    y = col(both, :budget, c) ./ B
    plot!(p1, days(both), y; color = color, label = c)
end

"Cumulative fraction of demand served per center."
function served!(p, ts)
    for (c, color) in CENTERS
        sp, dm = cumsum(col(ts, :spend, c)), cumsum(col(ts, :demand, c))
        y = sp ./ max.(dm, eps())
        plot!(p, days(ts), y; color = color, label = c)
        endlabel!(p, days(ts), y, c, color)
    end
    p
end
p2 = served!(plot(title = "b) Demand served so far, static split", ylabel = "spend / demand", xlabel = "day",
                  xlims = (0, 7.3), xticks = 0:7, ylims = (0.3, 1.05), legend = :right), none)
p3 = served!(plot(title = "c) Demand served so far, rebalancing", ylabel = "spend / demand", xlabel = "day",
                  xlims = (0, 7.3), xticks = 0:7, ylims = (0.3, 1.05), legend = :bottomright), both)

p4 = plot(title = "d) Total spend S / B, last two days", ylabel = "S / B", xlabel = "day",
          xlims = (5, 7), xticks = 5:0.5:7, ylims = (0.7, 1.005), legend = :bottomright)
hline!(p4, [1.0]; color = C_GRAY, linestyle = :dash, linewidth = 1, label = "B (hard cap)")
plot!(p4, days(none), none[:S] ./ B; color = C_GRAY, label = "static split")
plot!(p4, days(both), both[:S] ./ B; color = CENTERS[1][2], label = "rebalancing")

fig = plot(p1, p2, p3, p4; layout = (4, 1), size = (1000, 1250), dpi = 120)
savefig(fig, joinpath(OUT, "multi.png"))
println("plot → ", normpath(joinpath(OUT, "multi.png")))

# ---- outage: B down for the last 2 days (scripts/multi_run.jl) ----
frozen = read_ts(joinpath(OUT, "multi_outage_frozen.csv"))
takeover = read_ts(joinpath(OUT, "multi_outage_takeover.csv"))

q1 = plot(title = "a) Budget share B_k / B, B down for the last 2 days (shaded), takeover", ylabel = "share of B",
          xlabel = "day", xlims = (4, 7), xticks = 4:0.5:7, ylims = (0, 0.6),
          yticks = (0:0.1:0.6, ["0", "0.1", "0.2", "0.3", "0.4", "0.5", "0.6"]), legend = :right)
vspan!(q1, [5, 7]; color = C_GRAY, alpha = 0.12, label = nothing)
for (c, color) in CENTERS
    plot!(q1, days(takeover), col(takeover, :budget, c) ./ B; color = color, label = c)
end

q2 = plot(title = "b) Total spend S / B", ylabel = "S / B", xlabel = "day", xlims = (4, 7), xticks = 4:0.5:7,
          ylims = (0.5, 1.005), legend = :bottomright)
vspan!(q2, [5, 7]; color = C_GRAY, alpha = 0.12, label = "B down")
hline!(q2, [1.0]; color = C_GRAY, linestyle = :dash, linewidth = 1, label = "B (hard cap)")
plot!(q2, days(frozen), frozen[:S] ./ B; color = C_GRAY, label = "frozen")
plot!(q2, days(takeover), takeover[:S] ./ B; color = CENTERS[1][2], label = "takeover")

fig2 = plot(q1, q2; layout = (2, 1), size = (1000, 650), dpi = 120)
savefig(fig2, joinpath(OUT, "multi_outage.png"))
println("plot → ", normpath(joinpath(OUT, "multi_outage.png")))
