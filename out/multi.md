
### A. Rebalancing mode

_cell: mean % / min % of B spent; 40 runs per cell_

| mode | loads as assumed | loads 30/30/20/20 | random loads σ=0.3 | D: day-4 shock 20% | A: last-12h 30% | demand ×1.15 |
|---|---|---|---|---|---|---|
| none (static split) | 100.00 / 100.00 | 96.04 / 94.24 | 99.14 / 92.36 | 100.00 / 100.00 | 99.58 / 99.47 | 100.00 / 100.00 |
| periodic (60 min) | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |
| on demand | 100.00 / 100.00 | 100.00 / 100.00 | 99.99 / 99.54 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |
| both | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |

### B. Cost of rebalancing (mode `both`)

_40 runs per row; moved = gross transfers, net = start → end shift of budget shares (% of B)_

| world | runs over B | centers over own budget | served spread none → both (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|
| loads as assumed | 0 | 0 | 2.4 → 4.2 | 165 | 21.1 | 1.0 | 36.9 | 2.0 |
| loads 30/30/20/20 | 0 | 0 | 59.3 → 9.9 | 171 | 41.5 | 17.8 | 39.1 | 1.9 |
| random loads σ=0.3 | 0 | 0 | 40.1 → 6.2 | 164 | 28.4 | 8.0 | 38.1 | 2.0 |
| D: day-4 shock 20% | 0 | 0 | 9.8 → 5.5 | 195 | 27.0 | 2.3 | 36.9 | 2.0 |
| A: last-12h 30% | 0 | 0 | 3.2 → 4.4 | 194 | 21.8 | 0.8 | 35.4 | 1.7 |
| demand ×1.15 | 0 | 0 | 3.1 → 3.0 | 169 | 22.0 | 0.7 | 35.2 | 1.9 |

### C. Rebalancing parameters (world: loads 30/30/20/20, mode `both`)

_40 runs per row_

| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| default (pull, every 60 min, tol 0.02) | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.9 | 171 | 41.5 | 17.8 | 39.1 | 1.9 |
| every 15 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 223 | 42.7 | 17.8 | 100.8 | 1.9 |
| every 240 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 10.3 | 97 | 37.9 | 17.7 | 23.6 | 1.9 |
| periodic only, every 240 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 10.4 | 89 | 37.8 | 17.7 | 5.1 | 1.9 |
| tol 0 | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 419 | 48.0 | 17.8 | 39.1 | 1.9 |
| tol 0.05 | 100.000 | 100.000 | 0 | 0.00 | 0 | 10.2 | 73 | 34.7 | 17.7 | 39.2 | 1.9 |
| tol 0.1 | 100.000 | 100.000 | 0 | 0.00 | 0 | 11.2 | 32 | 27.4 | 17.6 | 39.3 | 1.9 |
| start at t = 0 | 100.000 | 100.000 | 0 | 0.00 | 0 | 2.1 | 237 | 100.7 | 19.9 | 43.2 | 1.9 |
| push, latency 30 ± 30 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 10.7 | 168 | 45.1 | 17.6 | 12.9 | 1.9 |
| push, latency 120 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 11.8 | 154 | 44.4 | 17.4 | 12.9 | 1.9 |
| every 5 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 9.7 | 244 | 42.9 | 17.8 | 265.4 | 1.9 |
| on demand only | 100.000 | 100.000 | 0 | 0.00 | 0 | 50.5 | 14 | 6.0 | 5.5 | 11.2 | 1.6 |

### D. Late local drop (world: A at 30% in the last 12 h)

_40 runs per row_

| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 99.575 | 99.467 | 0 | 0.00 | 0 | 3.2 | 0 | 0.0 | 0.0 | 0.0 | – |
| periodic (60 min) | 100.000 | 100.000 | 0 | 0.00 | 0 | 4.5 | 178 | 21.8 | 0.8 | 20.6 | 1.7 |
| on demand | 100.000 | 100.000 | 0 | 0.00 | 0 | 2.8 | 35 | 1.2 | 0.7 | 14.8 | 1.7 |
| both | 100.000 | 100.000 | 0 | 0.00 | 0 | 4.4 | 194 | 21.8 | 0.8 | 35.4 | 1.7 |
| both, haircut 0.05 | 99.998 | 99.982 | 0 | 0.00 | 0 | 4.4 | 194 | 24.9 | 1.2 | 29.6 | 0.9 |
| both, push, latency 30 min | 100.000 | 100.000 | 0 | 0.00 | 0 | 4.7 | 189 | 22.5 | 0.8 | 12.4 | 1.7 |

### E. Center outages (mode `both`, zero latency)

_cell: mean % / min % of B spent; 40 runs per cell_

| policy | A down 6 h on day 3 | A down the last 12 h | B down the last 2 days | random: MTBF 2 d, MTTR 4 h | random: MTBF 1 d, MTTR 12 h |
|---|---|---|---|---|---|
| frozen (no takeover) | 100.00 / 100.00 | 98.41 / 98.28 | 94.67 / 94.02 | 99.97 / 99.66 | 88.38 / 71.27 |
| takeover once grants settled | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 92.81 / 73.91 |
| takeover, wait 0.1 × time left (default) | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 90.70 / 71.81 |
| takeover, wait 0.3 × time left | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 88.95 / 71.43 |

_Details: taken over % of B / served spread pp / budget stranded in centers down at T, % of B_

| policy | A down 6 h on day 3 | A down the last 12 h | B down the last 2 days | random: MTBF 2 d, MTTR 4 h | random: MTBF 1 d, MTTR 12 h |
|---|---|---|---|---|---|
| frozen (no takeover) | 0.0 / 4.3 / 0.00 | 0.0 / 4.1 / 1.59 | 0.0 / 12.1 / 5.33 | 0.0 / 8.4 / 0.03 | 0.0 / 22.9 / 6.23 |
| takeover once grants settled | 28.9 / 5.6 / 0.00 | 1.6 / 4.7 / 0.00 | 5.3 / 16.7 / 0.00 | 117.1 / 12.4 / 0.00 | 286.3 / 26.5 / 1.02 |
| takeover, wait 0.1 × time left (default) | 0.0 / 4.3 / 0.00 | 1.6 / 4.7 / 0.00 | 5.3 / 16.8 / 0.00 | 16.5 / 8.8 / 0.00 | 135.4 / 25.8 / 1.28 |
| takeover, wait 0.3 × time left | 0.0 / 4.3 / 0.00 | 1.6 / 4.6 / 0.00 | 5.3 / 16.7 / 0.00 | 2.1 / 8.5 / 0.00 | 50.3 / 23.7 / 1.53 |
| _demand of running centers, mean / min % of B_ | 149 / 147 | 150 / 147 | 145 / 143 | 142 / 125 | 105 / 77 |

### F. Safety of takeover (world: random outages MTBF 1 d, MTTR 12 h)

_40 runs per row_

| variant | spend mean % | min % | runs over B | max over (‰ B) | centers over own budget | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| takeover once grants settled (τ_max + D_max) | 92.808 | 73.906 | 0 | 0.00 | 0 | 26.5 | 131 | 248.8 | 8.0 | 11.7 | 1.5 |
| takeover after 10 min (too early!) | 93.369 | 74.947 | 6 | 1.25 | 57 | 26.6 | 132 | 293.0 | 8.0 | 11.9 | 1.9 |

### G. Round mode (mode `both`, zero latency)

_cell: mean % B spent / served spread pp / moved % B / messages per h; 40 runs per cell_

| round mode | loads as assumed | loads 30/30/20/20 | random loads σ=0.3 |
|---|---|---|---|
| sync: all at the same instant (ideal) | 100.00 / 4.2 / 22.1 / 13 | 100.00 / 9.7 / 42.2 / 13 | 100.00 / 6.1 / 29.4 / 13 |
| pull: own timer, pull fresh statuses (default) | 100.00 / 4.2 / 21.1 / 37 | 100.00 / 9.9 / 41.5 / 39 | 100.00 / 6.2 / 28.4 / 38 |
| push: own timer, last-heard statuses | 100.00 / 4.3 / 21.2 / 13 | 100.00 / 10.1 / 43.5 / 13 | 100.00 / 6.3 / 29.6 / 13 |
