
### A. Isolated vs shared demand profile

_cell: weighted % achieved / 5th percentile % / share of budgets ≥ 99.9 %; achieved = spend / min(B, all demand); 20 portfolios of 20 budgets per cell (50 in the last column)_

| profile | default: demand 0.6–2×, 1–10 d | demand 1.0–1.2×, 1–10 d | demand 1.0–1.2×, 6 h – 2 d | demand 0.6–0.95× (cannot fill) | 50 budgets, demand 1.0–1.2×, 6 h – 2 d |
|---|---|---|---|---|---|
| isolated | 99.85 / 99.41 / 82 | 99.80 / 99.90 / 95 | 98.69 / 89.11 / 74 | 99.54 / 98.66 / 42 | 98.46 / 88.73 / 71 |
| shared | 99.91 / 99.46 / 80 | 99.98 / 100.00 / 98 | 99.81 / 99.57 / 90 | 99.75 / 99.17 / 39 | 99.92 / 99.80 / 91 |

_Budgets over their cap, all cells: 0_

### B. Which budgets gain (world: demand 1.0–1.2×, 6 h – 2 d)

_cell: weighted % achieved / 5th percentile % / share of budgets ≥ 99.9 %; achieved = spend / min(B, all demand)_

| budgets | count | isolated | shared |
|---|---|---|---|
| ≤ 12 h | 135 | 99.08 / 89.70 / 66 | 99.76 / 99.24 / 81 |
| 12–24 h | 131 | 97.55 / 84.94 / 66 | 99.78 / 99.09 / 92 |
| 1–2 d | 134 | 99.57 / 98.26 / 90 | 99.89 / 99.98 / 96 |
| starts before any other budget | 20 | 98.93 / 89.14 / 75 | 98.93 / 89.14 / 75 |
| starts after at least one other | 380 | 98.68 / 89.11 / 74 | 99.86 / 99.64 / 91 |
| starts 06–18 h | 210 | 97.77 / 86.17 / 60 | 99.74 / 98.83 / 90 |
| starts 18–06 h | 190 | 99.96 / 99.70 / 89 | 99.90 / 99.70 / 90 |

### C. Grant granularity (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min |
|---|---|---|---|---|---|---|---|---|
| min grant scales with the budget (default) | 99.91 | 99.89 | 99.46 | 94.30 | 80 % | 0 | 0.00 | 20.8 |
| fixed min grant (1 unit for every budget) | 99.62 | 96.92 | 82.39 | 53.92 | 55 % | 0 | 0.00 | 14.7 |

### D. Safety assumptions (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min |
|---|---|---|---|---|---|---|---|---|
| assumptions hold (default) | 99.91 | 99.89 | 99.46 | 94.30 | 80 % | 0 | 0.00 | 20.8 |
| β_true = 1.08 > β_max = 1.06 | 99.92 | 99.91 | 99.65 | 93.47 | 84 % | 308 | 0.53 | 20.7 |
| D = 30 ± 15 min, D_max = 30 | 99.98 | 99.96 | 99.53 | 94.31 | 80 % | 287 | 6.38 | 20.8 |

### E. Number of budgets (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min |
|---|---|---|---|---|---|---|---|---|
| 10 budgets | 99.93 | 99.93 | 99.70 | 97.46 | 82 % | 0 | 0.00 | 10.4 |
| 20 budgets | 99.91 | 99.89 | 99.46 | 94.30 | 80 % | 0 | 0.00 | 20.8 |
| 50 budgets | 99.90 | 99.89 | 99.49 | 95.04 | 81 % | 0 | 0.00 | 51.9 |
