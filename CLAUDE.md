# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Julia simulator for budget pacing with delayed spend data. A center must spend budget `B` over
period `T` without ever exceeding it. It issues grants (amount + rate + expiry) to clients whose
demand is noisy, and it sees authoritative spend only from a DB that lags by `D` and differs from
client-counted spend by a ratio β. The goal is research: compare pacing and safety strategies
across Monte Carlo scenarios. The write-ups are in `MODEL.md` (model, strategies, results) and
`PACING.md` (how clients and the center behave under each strategy), and `BUDGETS.md` (many
independent budgets with their own sizes, periods and demand, spent through the same clients).

## Commands

There is no test suite, build step, or linter. The core (`src/`) uses the stdlib only and has no
`Project.toml`. Scripts load it with `include("src/BudgetPacing.jl"); using .BudgetPacing`. Only
`plots/` has an environment (Plots.jl); the first time, run `julia --project=plots -e 'using Pkg; Pkg.instantiate()'`.

```sh
julia scripts/run.jl                                         # one run → out/run.csv + summary
julia --project=plots plots/plot.jl                          # out/run.csv → out/run.png
julia -t auto scripts/sweep.jl 40                            # scenario table (out/sweep.txt)
julia -t auto scripts/strategies.jl 40 > out/strategies.md   # MODEL.md §6 tables A–G (~1 min)
julia -t auto scripts/beta_sensitivity.jl 40 > out/beta_sensitivity.md   # MODEL.md §6.H
julia scripts/compare_pacing.jl                              # strategies on one world → out/pacing_*.csv
julia --project=plots plots/plot_pacing.jl                   # → out/pacing.png
julia scripts/budgets_run.jl                                 # one portfolio → out/budgets_{isolated,shared}.csv
julia --project=plots plots/plot_budgets.jl                  # → out/budgets.png
julia -t auto scripts/budgets_mc.jl 20 > out/budgets.md      # BUDGETS.md tables A–E (~1 min)
```

The trailing number is the count of seeds per scenario. Use `-t auto`, because `run_mc` uses
`Threads.@threads`. To check a change quickly, run `julia scripts/run.jl` and look at
`spend_ratio`, `overspend` (must be 0) and `max_commit` (must be ≤ 1−δ).

Results quoted in `MODEL.md`, `PACING.md`, `BUDGETS.md` and `README.md` come from the committed files under
`out/` (`*.md`, `sweep.txt`, `*.png`). `out/*.csv` is gitignored. If a change to `src/` changes
behaviour, rerun the matching script and update the numbers in the docs.

## Architecture

- `src/config.jl`: `Config` is a `@kwdef` struct that holds **every** parameter, grouped as world
  (unknown to the center), center assumptions (safety bounds), and policy. Each field's comment is
  its documentation. `validate` rejects bad symbols and only *warns* when the true world breaks an
  assumption (`D + D_jitter > D_max`, β above `beta_max`). Those scenarios are run on purpose to
  show overspend. `NaN` defaults for `D_assumed` and `D_max` are resolved by `d_assumed` and `d_max`.
- `src/model.jl`: the `Grant`, `Client` and `Center` structs, the hidden world shape
  (`base_pattern`, `shock`), the hard-cap `exposure` bound, and the center's estimators
  (`update_demand!` for per-client EWMA, the daily profile and the level factor; `update_beta!`
  for β̂; `remaining_demand`).
- `src/simulate.jl`: a `Site` is one budget with its center state, its clients, its slice of the DB
  and its `budget`. `t0` is its absolute start time: its own clock runs from 0 to `cfg.T`, but the
  demand pattern and the profile bins use `t + t0`. `step!(site, n)` runs one time step, in order: clients (demand, token-bucket spending,
  partial return, renewal or re-grant requests) → center observes (delayed `Y`) → estimates
  (nowcast `Ŝ`) → paces (`p`) → recomputes exposure `E` → serves grant requests under the
  `Y + E + β_max·g ≤ budget(1−δ)` invariant → records. `simulate(cfg)` is just one `Site` stepped
  to `T`, and returns `(summary::NamedTuple, ts::NamedTuple)`. Each site owns its RNG, and the
  number of draws per step does not depend on policy, so policy variants see the same demand.
- `src/budgets.jl`: `PortfolioConfig` and `simulate_budgets`. They draw the budgets (or take an
  explicit list), build one shared `World` (client sizes, phases, drift; the drift is advanced
  once per step for all budgets) and one `Site` per budget, and step each site only between its
  start and end. With `profile = :shared`, all centers point to one `SharedProfile`
  (`update_shared!` in `model.jl`): a common daily shape, each budget with its own `level`.
  `aggregate_budgets` pools budgets over runs; "achieved" = spend / min(B_m, all demand).
- `src/analysis.jl`: `run_mc` (threaded over seeds; `budgets.jl` adds a `PortfolioConfig` method),
  `with(cfg; field=value)` (copy with overrides for `Config` or `PortfolioConfig`, errors on an
  unknown field), `aggregate`, the table printers, and a dependency-free `write_csv`.

Conventions to keep in mind:
- Time is in minutes and money is in arbitrary units. The period starts Monday 00:00, so days 5–6
  are the weekend.
- Index convention: cumulative arrays (`Ccli`, `Ctot`, `Sdb`) have `N+1` entries. Index `k` is the
  value at time `(k-1)·dt`, and step `n` moves from index `n` to `n+1` (`now = n + 1`).
- Units: `R` and `rstar` are DB units, while demand and grants are client units. Convert with β̂
  (for pacing) or `beta_max` (for the cap).
- Strict separation: the center must only use what it could really observe (delayed `Sdb`,
  client reports lagged by `report_lag`, `Config` assumptions). Never let it read true demand,
  `beta_true` or `base_pattern`.
- Budgets are independent: each has its own invariant, and money never moves between them. The
  shared profile may only feed pacing, never the cap.
- The hard cap must not depend on estimates. Only the nowcast and pacing use β̂ and the profile.
  The invariant uses only `Y`, `beta_max` and `D_max`.
- To add a parameter: add a commented field to `Config` and use it in the loop. Scenarios are
  expressed in scripts as `with(base; ...)` pairs.
