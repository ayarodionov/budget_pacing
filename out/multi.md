
### A. Rebalancing mode

_cell: mean % / min % of B spent; 40 runs per cell_

| mode | loads as assumed | loads 30/30/20/20 | random loads σ=0.3 | D: day-4 shock 20% | A: last-12h 30% | demand ×1.15 |
|---|---|---|---|---|---|---|
| none (static split) | 100.00 / 100.00 | 96.04 / 94.24 | 99.14 / 92.36 | 100.00 / 100.00 | 99.58 / 99.47 | 100.00 / 100.00 |
| periodic (60 min) | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |
| on demand | 100.00 / 100.00 | 99.89 / 98.54 | 99.92 / 96.62 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |
| both | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 | 100.00 / 100.00 |

### B. Cost of rebalancing (mode `both`)

_40 runs per row; moved = gross transfers, net = start → end shift of budget shares (% of B)_

| world | runs over B | centers over own budget | served spread none → both (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|
| loads as assumed | 0 | 0 | 2.4 → 4.2 | 166 | 22.3 | 1.0 | 12.7 | 2.0 |
| loads 30/30/20/20 | 0 | 0 | 59.3 → 9.7 | 172 | 42.5 | 17.8 | 13.0 | 1.9 |
| random loads σ=0.3 | 0 | 0 | 40.1 → 6.1 | 166 | 29.5 | 8.0 | 12.9 | 2.0 |
| D: day-4 shock 20% | 0 | 0 | 9.8 → 5.6 | 195 | 28.3 | 2.3 | 12.7 | 2.0 |
| A: last-12h 30% | 0 | 0 | 3.2 → 4.5 | 193 | 23.1 | 0.8 | 12.5 | 1.7 |
| demand ×1.15 | 0 | 0 | 3.1 → 3.0 | 170 | 23.3 | 0.7 | 12.5 | 1.9 |

### C. Rebalancing parameters (world: loads 30/30/20/20, mode `both`)

_40 runs per row_

| variant | spend mean % | min % | runs over B | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|
| default (every 60 min, tol 0.02, latency 2 min) | 100.000 | 100.000 | 0 | 9.7 | 172 | 42.5 | 17.8 | 13.0 | 1.9 |
| every 15 min | 100.000 | 100.000 | 0 | 9.7 | 225 | 43.0 | 17.8 | 43.9 | 1.9 |
| every 240 min | 100.000 | 100.000 | 0 | 9.7 | 90 | 38.1 | 17.8 | 5.3 | 1.9 |
| periodic only, every 240 min | 100.000 | 100.000 | 0 | 9.7 | 87 | 38.1 | 17.8 | 2.6 | 1.9 |
| tol 0 | 100.000 | 100.000 | 0 | 9.6 | 390 | 48.9 | 17.9 | 13.0 | 1.9 |
| tol 0.05 | 100.000 | 100.000 | 0 | 10.2 | 74 | 35.3 | 17.8 | 13.0 | 1.9 |
| tol 0.1 | 100.000 | 100.000 | 0 | 11.0 | 32 | 27.4 | 17.7 | 13.0 | 1.9 |
| start at t = 0 | 100.000 | 100.000 | 0 | 2.3 | 236 | 109.7 | 19.8 | 14.7 | 1.9 |
| latency 30 ± 30 min | 100.000 | 100.000 | 0 | 10.5 | 192 | 44.8 | 17.7 | 13.0 | 1.9 |
| latency 120 min | 100.000 | 100.000 | 0 | 11.4 | 177 | 45.7 | 17.5 | 12.9 | 1.9 |
| near-ideal: every 5 min, latency 1 min | 100.000 | 100.000 | 0 | 9.7 | 244 | 42.9 | 17.8 | 126.1 | 1.9 |
| on demand only | 99.886 | 98.541 | 0 | 55.2 | 14 | 7.4 | 4.6 | 1.1 | 1.3 |

### D. Late local drop (world: A at 30% in the last 12 h)

_40 runs per row_

| variant | spend mean % | min % | runs over B | served spread (pp) | transfers | moved % | net % | messages/h | done before T (h) |
|---|---|---|---|---|---|---|---|---|---|
| none | 99.575 | 99.467 | 0 | 3.2 | 0 | 0.0 | 0.0 | 0.0 | – |
| periodic (60 min) | 100.000 | 100.000 | 0 | 4.5 | 181 | 23.0 | 0.8 | 10.4 | 1.7 |
| on demand | 100.000 | 99.999 | 0 | 3.7 | 19 | 1.1 | 0.7 | 2.0 | 1.6 |
| both | 100.000 | 100.000 | 0 | 4.5 | 193 | 23.1 | 0.8 | 12.5 | 1.7 |
| both, haircut 0.05 | 99.998 | 99.988 | 0 | 4.4 | 198 | 26.2 | 1.2 | 11.6 | 0.9 |
| both, latency 30 min | 100.000 | 100.000 | 0 | 4.7 | 194 | 22.8 | 0.8 | 12.5 | 1.7 |
