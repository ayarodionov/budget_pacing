
### A. Isolated vs shared demand profile

_cell: weighted % achieved / 5th percentile % / share of budgets ≥ 99.9 %; achieved = spend / min(B, all demand); 20 portfolios of 20 budgets per cell (50 in the last column)_

| profile | default: demand 0.6–2×, 1–10 d | demand 1.0–1.2×, 1–10 d | demand 1.0–1.2×, 6 h – 2 d | demand 0.6–0.95× (cannot fill) | 50 budgets, demand 1.0–1.2×, 6 h – 2 d |
|---|---|---|---|---|---|
| isolated | 99.85 / 99.42 / 82 | 99.80 / 99.90 / 95 | 98.69 / 89.10 / 74 | 99.54 / 98.65 / 42 | 98.45 / 88.71 / 71 |
| shared | 99.91 / 99.48 / 80 | 99.98 / 100.00 / 98 | 99.81 / 99.56 / 90 | 99.75 / 99.19 / 38 | 99.92 / 99.80 / 91 |

_Budgets over their cap, all cells: 0_

### B. Which budgets gain (world: demand 1.0–1.2×, 6 h – 2 d)

_cell: weighted % achieved / 5th percentile % / share of budgets ≥ 99.9 %; achieved = spend / min(B, all demand)_

| budgets | count | isolated | shared |
|---|---|---|---|
| ≤ 12 h | 135 | 99.08 / 89.70 / 66 | 99.76 / 99.24 / 81 |
| 12–24 h | 131 | 97.54 / 84.93 / 66 | 99.78 / 99.09 / 92 |
| 1–2 d | 134 | 99.57 / 98.23 / 90 | 99.89 / 99.98 / 96 |
| starts before any other budget | 20 | 98.93 / 89.14 / 75 | 98.93 / 89.14 / 75 |
| starts after at least one other | 380 | 98.68 / 89.10 / 74 | 99.86 / 99.64 / 91 |
| starts 06–18 h | 210 | 97.76 / 86.15 / 60 | 99.74 / 98.82 / 90 |
| starts 18–06 h | 190 | 99.96 / 99.70 / 89 | 99.90 / 99.70 / 90 |

### C. Grant granularity (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min | messages/min |
|---|---|---|---|---|---|---|---|---|---|
| min grant scales with the budget (default) | 99.91 | 99.89 | 99.48 | 94.29 | 80 % | 0 | 0.00 | 22.0 | 10.5 |
| fixed min grant (1 unit for every budget) | 99.62 | 96.92 | 82.39 | 53.93 | 55 % | 0 | 0.00 | 15.4 | 8.5 |

### D. Safety assumptions (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min | messages/min |
|---|---|---|---|---|---|---|---|---|---|
| assumptions hold (default) | 99.91 | 99.89 | 99.48 | 94.29 | 80 % | 0 | 0.00 | 22.0 | 10.5 |
| β_true = 1.08 > β_max = 1.06 | 99.92 | 99.91 | 99.64 | 93.46 | 84 % | 308 | 0.51 | 21.9 | 10.5 |
| D = 30 ± 15 min, D_max = 30 | 99.98 | 99.96 | 99.54 | 94.29 | 80 % | 288 | 6.62 | 22.0 | 10.5 |

### E. Number of budgets (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min | messages/min |
|---|---|---|---|---|---|---|---|---|---|
| 10 budgets | 99.93 | 99.93 | 99.70 | 97.43 | 82 % | 0 | 0.00 | 10.8 | 7.4 |
| 20 budgets | 99.91 | 99.89 | 99.48 | 94.29 | 80 % | 0 | 0.00 | 22.0 | 10.5 |
| 50 budgets | 99.90 | 99.89 | 99.50 | 95.03 | 81 % | 0 | 0.00 | 56.5 | 14.3 |

### F. Bundling grant requests per client (world: default)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min | messages/min |
|---|---|---|---|---|---|---|---|---|---|
| no bundling | 99.91 | 99.89 | 99.46 | 94.30 | 80 % | 0 | 0.00 | 20.8 | 20.9 |
| bundle within 5 min (default) | 99.91 | 99.89 | 99.48 | 94.29 | 80 % | 0 | 0.00 | 22.0 | 10.5 |
| bundle within 10 min | 99.91 | 99.89 | 99.51 | 94.25 | 80 % | 0 | 0.00 | 25.9 | 9.3 |
| bundle within 30 min | 99.92 | 99.90 | 99.52 | 94.17 | 80 % | 0 | 0.00 | 38.9 | 8.9 |

### F. Bundling grant requests per client (world: 50 budgets)

_20 portfolios per row_

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | over cap | max over (‰ of B_m) | grants/min | messages/min |
|---|---|---|---|---|---|---|---|---|---|
| no bundling | 99.90 | 99.89 | 99.49 | 95.04 | 81 % | 0 | 0.00 | 51.9 | 52.0 |
| bundle within 5 min (default) | 99.90 | 99.89 | 99.50 | 95.03 | 81 % | 0 | 0.00 | 56.5 | 14.3 |
| bundle within 10 min | 99.90 | 99.89 | 99.52 | 95.03 | 81 % | 0 | 0.00 | 71.7 | 13.1 |
| bundle within 30 min | 99.91 | 99.90 | 99.60 | 94.97 | 82 % | 0 | 0.00 | 121.6 | 12.9 |
