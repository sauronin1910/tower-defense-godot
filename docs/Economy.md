# Economy

Gold, base HP, wave payouts, and what the current numbers actually produce.

Implementation: `scripts/Main.gd` — `gold`, `base_health`, `TOWER_COSTS`, `WAVE_CONFIG`.

Related: [[Towers#Tower types]] for what gold buys, [[Enemies#Enemy types]] for what pays it out, [[Architecture#Wave lifecycle]] for the code path, [[TODO]] for the rebalance plan, [[GameDesign#Economy loop]] for the intent these numbers are meant to serve.

---

## Resources

| Resource | Start | Source | Sink |
|---|---:|---|---|
| Gold | **3000** ⚠️ | Enemy kills | Tower builds, upgrades |
| Base HP | 20 | — | Enemies reaching the end |

> ⚠️ **3000 starting gold is a debug value**, committed in `8f66580`'s parent (`44a2432 "Debug helpers: 3000 starting gold, 4x speed level"`). It is set twice — at declaration (`Main.gd:35`) and again in `_ready()` (`Main.gd:111`). A `DEBUG_MODE` constant exists at `Main.gd:34` but is never read. With 3000 gold the player can build 25 spear towers before wave 1 spawns, so the economy is currently untested in practice. Removal is [[TODO#P0 — Blocking|TODO #3]].

Base HP is displayed as `"Base HP: %d/20"` with the 20 hard-coded in the format string as well as in the variable.

---

## Costs

| Tower | Build | Upgrade (L1→L2) | Upgrade (L2→L3) | Total to max |
|---|---:|---:|---:|---:|
| Spear | 50 | 37 | 37 | **124** |
| Arrow | 75 | 56 | 56 | **187** |
| Shells | 120 | 90 | 90 | **300** |

Upgrade cost is `int(tower_cost * 0.75)` and does **not** scale with level (`Tower.get_upgrade_cost:262`). Both upgrades cost the same.

**Sell value** is `int(total_gold_invested * 0.7)` — 70 % of build + all upgrades. Selling a maxed spear returns 86 of 124 gold, a 30 % loss.

> ⚠️ `total_gold_invested` is seeded from `Tower.gd`'s own cost copy, not `Main.TOWER_COSTS` — see [[Towers#Tower types]] and [[Architecture#2. Duplicated sources of truth]]. Changing a price in one place alone silently corrupts refunds.

### Value analysis

Each upgrade buys `1.15× damage × 1.15× rate = 1.3225×` DPS plus 15 % range, for 75 % of the build cost.

| Tower | L1 DPS | L1 DPS/gold | L3 DPS | L3 DPS/gold |
|---|---:|---:|---:|---:|
| Spear | 10.0 | **0.200** | 17.2 | 0.139 |
| Arrow | 12.0 | 0.160 | 19.8 | 0.106 |
| Shells | 15.0 | 0.125 | 25.7 | 0.086 |

Two observations fall out of this:

1. **Building wide beats upgrading.** A second spear tower costs 50 for +10 DPS; upgrading an existing one costs 37 for +3.2 DPS. Upgrades are only worth it when placement space or range coverage is the binding constraint — which on this map, with 3 000 starting gold, it never is.
2. **Spear dominates on raw efficiency** at every level. Arrow buys range (200 vs 180) and shells buy burst per shot (30 vs 10), but neither pays for itself on DPS per gold.

Because the upgrade price is flat, L2→L3 is strictly better value than L1→L2 (same cost, larger absolute gain) — the opposite of the usual escalating-cost design.

---

## Wave payouts

Rewards: slime 5, big slime 15 (+3 from its minis), small goblin 10, fast goblin 15, hobgoblin 30. Per-type stats in [[Enemies#Enemy types]]; the mini-slime surplus is explained in [[Enemies#Splitting]].

| Wave | slime | big | gob_s | gob_f | hob | Spawned | Total kills¹ | Gold | Cumulative |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 8 | 0 | 0 | 0 | 0 | 8 | 8 | 40 | 40 |
| 2 | 12 | 0 | 0 | 0 | 0 | 12 | 12 | 60 | 100 |
| 3 | 8 | 2 | 0 | 0 | 0 | 10 | 16 | 76 | 176 |
| 4 | 10 | 0 | 4 | 0 | 0 | 14 | 14 | 90 | 266 |
| 5 | 6 | 3 | 6 | 0 | 0 | 15 | 24 | 144 | 410 |
| 6 | 0 | 4 | 8 | 2 | 0 | 14 | 26 | 182 | 592 |
| 7 | 5 | 3 | 5 | 5 | 0 | 18 | 27 | 204 | 796 |
| 8 | 0 | 5 | 6 | 6 | 1 | 18 | 33 | 270 | 1066 |
| 9 | 0 | 0 | 8 | 8 | 2 | 18 | 18 | 260 | 1326 |
| 10 | 0 | 6 | 5 | 8 | 3 | 22 | 40 | 368 | 1694 |
| 11 | 0 | 4 | 6 | 10 | 5 | 25 | 37 | 432 | 2126 |
| 12 | 0 | 8 | 4 | 8 | 8 | 28 | 52 | 544 | 2670 |
| 13 | 0 | 0 | 0 | 0 | 15 | 15 | 15 | 450 | **3120** |

¹ Including the 3 mini slimes each big slime splits into.

**Total gold available across all 13 waves: 3 120** — almost exactly the 3 000 the player already starts with.

### Base HP pressure

Damage on arrival: 1 for most, 2 for a big slime, 3 for a hobgoblin. Against 20 base HP:

- Wave 13 alone (15 hobgoblins × 3) can deal **45 damage** — more than twice the total HP pool.
- Wave 12 can deal `8×2 + 4 + 8 + 8×3 = 52`.
- Even wave 1 leaking fully deals 8 of 20.

There are no lives regained, no repair, and no HP scaling. The base HP budget is effectively "leak at most ~19 low-tier enemies across the entire game."

---

## Timing

| Constant | Value | Where |
|---|---|---|
| Spawn interval | 0.8 s | `Main._ready:100` |
| Auto next-wave delay | 15 s | `Main._ready:104` |
| Max wave | 13 | `Main.MAX_WAVE` |

Waves also start early via the **Start Wave** button, which stops `NextWaveTimer` and advances immediately. There is no rush bonus for calling a wave early, so the button costs the player nothing and skipping the 15 s gap is strictly correct play.

A wave advances when `active_enemy_count <= 0 && enemies_spawned >= total_enemies_to_spawn`. Clearing wave 13 triggers `_trigger_level_complete()` instead.

> The comment at `Main.gd:2` says *"7 defined waves, then endless uses last entry"*. That is stale — there are 13 waves and no endless mode. `_get_wave_config` does clamp with `min(wave - 1, MAX_WAVE - 1)`, so the machinery for endless is present but unreachable.

---

## Speed control

The speed button cycles `[1.0, 1.5, 2.0, 4.0]` via `Engine.time_scale`. This does not affect the economy directly, but:

- It is a global multiplier, so it also speeds up UI tweens and the build-pop animation.
- The crowd-separation shove in `Enemy._update_lane` is `delta`-driven, so it degrades at 4× — see [[Enemies#Crowd separation]].
- The 4× entry is a debug addition (commit `44a2432`), like the 3 000 gold.
- It is correctly reset to 1.0 on restart, main-menu return, and level-complete exits.

---

## Balance summary

| Issue | Detail |
|---|---|
| **Starting gold is a debug value** | 3 000 vs a full-game payout of 3 120. Nothing is scarce. |
| **No difficulty ramp in cost** | Tower prices are flat while enemy HP grows 20 → 150. Wave 13 is 2 250 total HP; a maxed spear does 17.2 DPS. |
| **Upgrades are a trap** | Building a second tower is 1.4× more DPS per gold than upgrading at every tier. |
| **Flat upgrade pricing** | L2→L3 is better value than L1→L2, inverting the usual curve. |
| **Spear dominates** | Best DPS/gold at every level; arrow and shells have no compensating role. |
| **Sell is a 30 % haircut** | Discourages repositioning, which is the main tactical lever the placement system offers. |
| **Base HP is a cliff, not a curve** | 20 HP against a 45-damage boss wave means leaks are binary, not attritional. |
| **No wave-clear bonus** | Income is purely per-kill, so leaking an enemy costs HP *and* the gold. Double punishment with no comeback mechanic. |

### Suggested first pass

1. Set starting gold to something like **150–250** and gate it behind `DEBUG_MODE`.
2. Make upgrade cost scale: `tower_cost * (0.75 * level)` or similar.
3. Give each tower a role the numbers support — e.g. shells slow or splash, arrow long-range single-target — rather than three points on the same DPS/gold line.
4. Add a small per-wave completion bonus so income doesn't collapse when the player leaks.
5. Re-tune once the above is in; the current table is not meaningfully playable at 3 000 gold.

Tracked as [[TODO#P2 — Content and polish|TODO #15]] (rebalance) and [[TODO#P2 — Content and polish|TODO #16]] (distinct tower roles). Do [[TODO#P0 — Blocking|TODO #3]] first — balance is meaningless while the debug gold is in.
