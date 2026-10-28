# Many independent budgets on the same clients

## 1. Problem

The single-center problem ([MODEL.md](MODEL.md)) had one budget $B$ over one period $T$. Now the
center runs **many budgets** $m = 1 \ldots M$ at the same time:

- Each budget has its **own size** $B_m$, its **own start** and **own end**, and its **own demand rate**: some have more demand than they need, some less.
- **Every client serves every budget.** A client's traffic drives the demand of all budgets it serves, so all budgets share the clients' sizes, daily pattern and slow drift.
- Budgets are **independent**: money never moves between them.
- For **each** budget: spend as much as its demand allows, and **never** more than $B_m$.

Spend is counted per budget in the central DB, with delay $D$ as before.

## 2. Model

| | per budget $m$ | shared by all budgets |
|---|---|---|
| size, period | $B_m$ (log-uniform 10⁴ – 10⁶), start, length (log-uniform 1–10 days) | the horizon: 14 days, starting Monday 00:00 |
| demand | demand ratio $r_m$ = demand / $(B_m/\text{length})$, uniform 0.6–2.0; per-minute noise | client sizes, daily phases, slow drift, weekend dip |
| DB | its own spend $S_m$, seen as $Y_m = S_m(t - D)$ | delay $D$, ratio β |
| center | its own grants, nowcast, pacing and hard-cap invariant | optionally one learned demand shape (§3.2) |

So the demand of budget $m$ at client $i$ is $r_m \cdot (B_m / \text{length}_m) \cdot w_i \cdot \text{pattern}_i(t) \cdot \text{drift}_i(t)$
plus noise, where only the first two factors depend on the budget. "Achieved" is what a budget spent
of what it could spend:

```math
\text{achieved}_m = \frac{S_m(\text{end})}{\min\big(B_m,\ \text{all demand of } m \text{ during its period}\big)}
```

## 3. Design

### 3.1 Every budget is a single-center problem

Each budget runs the single-center design unchanged (MODEL.md §4), with its own grants on every
client, its own nowcast $\hat S_m$, its own adaptive pacing, and its own hard-cap invariant

```math
Y_m + E_m \le B_m\,(1-\delta)
```

Because the budgets never share money, this invariant alone guarantees that no budget ever spends
more than its $B_m$. Nothing about the other budgets is needed for safety.

Two things had to change for budgets that start at different times:
- **absolute time for the demand pattern.** A budget's own clock runs from 0 to its length, but its demand pattern and its profile bins use absolute time, so that "10:00" means the same for every budget.
- **grant granularity scales with the budget.** The minimum grant is $\text{min\_grant} \cdot B_m / B$, not a fixed amount (table C).

### 3.2 Shared demand profile

The single-center design learns its own daily demand profile and has none on its first day
(MODEL.md §8). For one long budget this costs little. For a budget that lasts only hours, it is
the whole problem: the budget ends before it has seen a day. Without a profile it extrapolates
its current demand rate, which is wrong when it starts during the day: it expects the daytime peak
to last, paces too slowly for the night that follows, and ends with budget left.

But all budgets run through the same clients, so their demand has the same daily **shape**, only
a different **scale**. The center can therefore learn one shape from all active budgets and give
it to a new budget from its first minute. For each 15-minute bin $b$ of the day:

```math
\text{profile}_b \leftarrow \text{EWMA over days of } \frac{\sum_m d_m}{\sum_m s_m}
```

where $d_m$ is budget $m$'s current demand rate and $s_m$ its scale. Each budget keeps its own
scale, the level of its demand against the shared shape:

```math
s_m = \text{level}_m \leftarrow \text{EWMA}_{4\,\text{h}}\Big(\frac{d_m}{\text{profile}_b}\Big),
\qquad
\hat\Lambda_m(t, T_m) = \sum_{\text{bins from } t \text{ to } T_m} \text{level}_m \cdot \text{profile}_b \cdot \Delta t
```

A new budget sets its level from its first minute of demand, and from then on forecasts its
remaining demand with the shared shape. Until a bin of the shape has been seen once (the very first
budgets), a budget falls back to its 1-day average rate, as in the single-center design.

The shared shape is only used for **pacing**. It does not affect the hard cap, so a wrong shape can
cost spend but never cause overspend.

## 4. Results

`out/budgets.md`; 20 portfolios of 20 budgets per cell. No budget exceeded its cap in any cell of
tables A, B, C and E.

### A. Isolated vs shared demand profile

_cell: weighted % achieved / 5th percentile % / share of budgets ≥ 99.9 %; "weighted" weights budgets by what they could spend_

| profile | default: demand 0.6–2×, 1–10 d | demand 1.0–1.2×, 1–10 d | demand 1.0–1.2×, 6 h – 2 d | demand 0.6–0.95× (cannot fill) | 50 budgets, demand 1.0–1.2×, 6 h – 2 d |
|---|---|---|---|---|---|
| isolated | 99.85 / 99.41 / 82 | 99.80 / 99.90 / 95 | 98.69 / 89.11 / 74 | 99.54 / 98.66 / 42 | 98.46 / 88.73 / 71 |
| **shared** | 99.91 / 99.46 / 80 | 99.98 / 100.00 / 98 | 99.81 / 99.57 / 90 | 99.75 / 99.17 / 39 | 99.92 / 99.80 / 91 |

- **With plenty of demand and long budgets** (default), the forecast hardly matters: both reach 99.9 %.
- **Short budgets with tight demand** are where the shared profile matters. Isolated, the worst 5 % of budgets spend less than 89 % of what they could; shared, more than 99.6 %. The share of budgets spent to 99.9 % rises from 74 % to 90 %.
- **More budgets** make the shared profile better (50 budgets: 99.92 %), because more budgets teach it; isolated budgets gain nothing from each other.
- **Budgets that cannot be filled** (demand below $B_m$) serve 99.5–99.8 % of their demand. The rest is lost to per-client pacing: a client can never spend faster than 1.5 × its estimated demand, and noisy demand above that is lost.

### B. Which budgets gain (world: demand 1.0–1.2×, 6 h – 2 d)

| budgets | count | isolated | shared |
|---|---|---|---|
| ≤ 12 h | 135 | 99.08 / 89.70 / 66 | 99.76 / 99.24 / 81 |
| 12–24 h | 131 | 97.55 / 84.94 / 66 | 99.78 / 99.09 / 92 |
| 1–2 d | 134 | 99.57 / 98.26 / 90 | 99.89 / 99.98 / 96 |
| starts before any other budget | 20 | 98.93 / 89.14 / 75 | 98.93 / 89.14 / 75 |
| starts after at least one other | 380 | 98.68 / 89.11 / 74 | 99.86 / 99.64 / 91 |
| starts 06–18 h | 210 | 97.77 / 86.17 / 60 | 99.74 / 98.83 / 90 |
| starts 18–06 h | 190 | 99.96 / 99.70 / 89 | 99.90 / 99.70 / 90 |

- **The mechanism is the daytime start.** Isolated budgets that start between 06:00 and 18:00 extrapolate the daytime peak and spend 97.8 %; those that start at night spend 99.96 %. With the shared profile both are at 99.7–99.9 %.
- **12–24 h budgets suffer most**: long enough to run into the night after a daytime start, too short to learn a full day.
- **The first budget gains nothing**: nobody has taught the shape yet. That is the remaining weakness, and a warm start from earlier history would remove it (§6).

![portfolio run](out/budgets.png)

_One portfolio, demand 1.0–1.2×, 6 h – 2 d (`scripts/budgets_run.jl`). (a, b) Each bar is one
budget from its start to its end; orange ones spent less than 99.9 % of what they could:
7 of 20 with isolated profiles, 1 with the shared one. (c, d) Spend of each budget over its own
period: isolated budgets fall behind in the second half and do not catch up._

### C. Grant granularity (world: default)

| variant | weighted % | mean % | 5th pct % | worst % | ≥ 99.9 % | grants/min |
|---|---|---|---|---|---|---|
| min grant scales with the budget (default) | 99.91 | 99.89 | 99.46 | 94.30 | 80 % | 20.8 |
| fixed min grant (1 unit for every budget) | 99.62 | 96.92 | 82.39 | 53.92 | 55 % | 14.7 |

A small budget spread over 50 clients has small grants. With a fixed minimum grant, many of them
fall below it and are not issued, and the smallest budgets spend as little as 54 %. The minimum
grant must scale with the budget (or with its rate per client).

### D. Safety assumptions (world: default)

| variant | weighted % | budgets over cap (of 400) | max over (‰ of $B_m$) |
|---|---|---|---|
| assumptions hold (default) | 99.91 | 0 | 0.00 |
| β_true = 1.08 > β_max = 1.06 | 99.92 | 308 | 0.53 |
| D = 30 ± 15 min, D_max = 30 | 99.98 | 287 | 6.38 |

As for a single budget (MODEL.md §6.G): the cap holds exactly as long as the true delay and DB/client
ratio stay within the bounds the center assumes. When they do not, most budgets overspend a little,
because each one runs into its cap at its end.

### E. Number of budgets (world: default)

| variant | weighted % | worst % | grants/min |
|---|---|---|---|
| 10 budgets | 99.93 | 97.46 | 10.4 |
| 20 budgets | 99.91 | 94.30 | 20.8 |
| 50 budgets | 99.90 | 95.04 | 51.9 |

Quality does not depend on the number of budgets, but the grant traffic grows linearly with it:
every client holds a grant for every active budget. Bundling all of a client's grants into one
message per renewal would keep the message rate per client constant.

## 5. Recommended policy

1. **One hard-cap invariant per budget**, exactly as for a single budget. Independence makes this both necessary and sufficient.
2. **One shared daily demand shape**, learned from all budgets on the same clients, with a per-budget level. New and short budgets pace with it from their first minute.
3. **Grant granularity relative to the budget**, not a fixed amount.
4. **Bundle grants per client** when many budgets are active.

## 6. Limitations and next steps

- **Cold start.** The first budgets still have no shape. A warm start from previous weeks (the shape is a property of the clients, not of a budget) would remove the last gap in table B.
- **Weekly pattern.** The shape is daily; weekends are caught only through each budget's level. A weekly shape, also shared, would help budgets that span a weekend.
- **Budgets with different client mixes.** Here every budget runs on every client with the same weights. If budgets targeted different subsets of clients, each would need the shape of its own subset, or a per-client shape combined by the budget's weights.
- **Competing budgets.** Budgets do not compete for the same demand here: each has its own. If one unit of demand could be paid by several budgets, the center would also have to choose which budget pays.
- **Grant traffic** is counted, not limited (table E).

## 7. Reproduce

```sh
julia scripts/budgets_run.jl                                 # one portfolio, isolated vs shared → out/budgets_*.csv
julia --project=plots plots/plot_budgets.jl                  # → out/budgets.png
julia -t auto scripts/budgets_mc.jl 20 > out/budgets.md      # tables A–E (~1 min on 10 threads)
```
