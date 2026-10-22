
### A. Rebalancing mode

_cell: mean % / min % of B spent; 40 runs per cell_

| mode | loads as assumed | loads 30/30/20/20 | random loads σ=0.3 | D: day-4 shock 20% | A: last-12h 30% | demand ×1.15 |
|---|---|---|---|---|---|---|
| none (static split) | 100.00 / 100.00 | 96.04 / 94.24 | 99.14 / 92.36 | 100.00 / 100.00 | 99.58 / 99.47 | 100.00 / 100.00 |
| periodic (60 min) | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |
| on demand | 100.00 / 100.00 | 99.91 / 98.60 | 99.92 / 96.89 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |
| both | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |

### B. Cost of rebalancing (mode `both`)

_40 runs per row; moved = gross transfers, net = start → end shift of budget shares (% of B)_

| world | runs over B | centers over own budget | served spread none → both (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|
| loads as assumed | 0 | 0 | 2.4 → 4.2 | 164 | 22.1 | 1.0 | 12.7 | 2.0 |
| loads 30/30/20/20 | 0 | 0 | 59.3 → 9.7 | 169 | 42.2 | 17.8 | 13.0 | 1.9 |
| random loads σ=0.3 | 0 | 0 | 40.1 → 6.1 | 167 | 29.4 | 8.0 | 12.9 | 2.0 |
| D: day-4 shock 20% | 0 | 0 | 9.8 → 5.5 | 194 | 28.1 | 2.3 | 12.7 | 2.0 |
| A: last-12h 30% | 0 | 0 | 3.2 → 4.5 | 191 | 22.8 | 0.8 | 12.5 | 1.7 |
| demand ×1.15 | 0 | 0 | 3.1 → 3.0 | 168 | 23.0 | 0.7 | 12.5 | 1.9 |

### C. Rebalancing parameters (world: loads 30/30/20/20, mode `both`)

_40 runs per row_

| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| default (every 60 min, tol 0.02, zero latency) | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 169 | 42.2 | 17.8 | 13.0 | 1.9 |
| every 15 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 223 | 42.7 | 17.8 | 43.9 | 1.9 |
| every 240 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 89 | 38.1 | 17.8 | 5.3 | 1.9 |
| periodic only, every 240 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 87 | 38.0 | 17.8 | 2.6 | 1.9 |
| tol 0 | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.5 | 387 | 48.7 | 17.9 | 13.0 | 1.9 |
| tol 0.05 | 100.000 | 100.000 | 0 | 0.00 | 0 | 10.1 | 74 | 35.3 | 17.8 | 13.0 | 1.9 |
| tol 0.1 | 100.000 | 100.000 | 0 | 0.00 | 0 | 11.0 | 32 | 27.2 | 17.7 | 13.0 | 1.9 |
| start at t = 0 | 100.000 | 100.000 | 0 | 0.00 | 0 | 2.3 | 233 | 107.8 | 19.8 | 14.7 | 1.9 |
| latency 30 ± 30 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 10.4 | 170 | 43.8 | 17.7 | 13.0 | 1.9 |
| latency 120 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 11.4 | 158 | 43.6 | 17.5 | 13.0 | 1.9 |
| near-ideal: every 5 min, latency 1 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 244 | 42.9 | 17.8 | 126.1 | 1.9 |
| on demand only | 99.909 | 98.597 | 0 | 0.00 | 0 | 55.3 | 11 | 5.7 | 4.6 | 1.2 | 1.3 |

### D. Late local drop (world: A at 30% in the last 12 h)

_40 runs per row_

| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 99.575 | 99.467 | 0 | 0.00 | 0 | 3.2 | 0 | 0.0 | 0.0 | 0.0 | – |
| periodic (60 min) | 100.000 | 100.000 | 0 | 0.00 | 0 | 4.5 | 178 | 22.8 | 0.8 | 10.4 | 1.7 |
| on demand | 100.000 | 99.999 | 0 | 0.00 | 0 | 3.5 | 19 | 1.1 | 0.6 | 2.0 | 1.6 |
| both | 100.000 | 100.000 | 0 | 0.00 | 0 | 4.5 | 191 | 22.8 | 0.8 | 12.5 | 1.7 |
| both, haircut 0.05 | 99.998 | 99.988 | 0 | 0.00 | 0 | 4.4 | 194 | 25.9 | 1.2 | 11.6 | 0.9 |
| both, latency 30 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 4.7 | 194 | 22.8 | 0.8 | 12.5 | 1.7 |

### E. Center outages (mode `both`, zero latency)

_cell: mean % / min % of B spent; 40 runs per cell_

| policy | A down 6 h on day 3 | A down the last 12 h | B down the last 2 days | random: MTBF 2 d, MTTR 4 h | random: MTBF 1 d, MTTR 12 h |
|---|---|---|---|---|---|
| frozen (no takeover) | 100.00 / 100.00 | 98.42 / 98.32 | 94.66 / 94.04 | 99.97 / 99.67 | 88.40 / 71.34 |
| takeover once grants settled | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 92.76 / 73.87 |
| takeover, wait 0.1 × time left (default) | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 90.66 / 71.79 |
| takeover, wait 0.3 × time left | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 88.96 / 71.43 |

_Details: taken over % of B / served spread pp / budget stranded in centers down at T, % of B_

| policy | A down 6 h on day 3 | A down the last 12 h | B down the last 2 days | random: MTBF 2 d, MTTR 4 h | random: MTBF 1 d, MTTR 12 h |
|---|---|---|---|---|---|
| frozen (no takeover) | 0.0 / 4.3 / 0.00 | 0.0 / 4.1 / 1.58 | 0.0 / 12.1 / 5.34 | 0.0 / 8.4 / 0.03 | 0.0 / 22.9 / 6.07 |
| takeover once grants settled | 28.9 / 5.7 / 0.00 | 1.6 / 4.7 / 0.00 | 5.3 / 16.7 / 0.00 | 117.2 / 12.5 / 0.00 | 286.7 / 26.5 / 1.03 |
| takeover, wait 0.1 × time left (default) | 0.0 / 4.3 / 0.00 | 1.6 / 4.7 / 0.00 | 5.3 / 16.7 / 0.00 | 16.5 / 8.9 / 0.00 | 135.4 / 26.0 / 1.29 |
| takeover, wait 0.3 × time left | 0.0 / 4.3 / 0.00 | 1.6 / 4.6 / 0.00 | 5.3 / 16.6 / 0.00 | 2.1 / 8.5 / 0.00 | 50.1 / 23.8 / 1.54 |
| _demand of running centers, mean / min % of B_ | 149 / 147 | 150 / 147 | 145 / 143 | 142 / 125 | 105 / 77 |

### F. Safety of takeover (world: random outages MTBF 1 d, MTTR 12 h)

_40 runs per row_

| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| takeover once grants settled (τ_max + D_max) | 92.759 | 73.873 | 0 | 0.00 | 0 | 26.5 | 152 | 254.0 | 8.1 | 5.0 | 1.5 |
| takeover after 10 min (too early!) | 93.319 | 74.909 | 6 | 1.24 | 57 | 26.7 | 155 | 297.8 | 8.0 | 5.1 | 1.9 |
