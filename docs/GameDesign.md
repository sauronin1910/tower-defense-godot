# Game Design

The design intent behind the prototype: what the player is doing, why each turn of the loop
should feel worth taking, and where the current build diverges from that intent.

Companion documents: [[Overview]] (what the game is), [[Towers]] and [[Enemies]] (unit
detail), [[Economy]] (the numbers), [[Architecture]] (how it is wired), [[TODO]] (the work
list).

> Scope note: this document describes design. Every figure quoted here is the **shipped**
> value as documented in [[Economy]] and [[Towers]] — where the shipped value undermines the
> design, that is called out rather than smoothed over.

---

## Core gameplay loop

```
        ┌──────────────────────────────────────────┐
        │                                          │
        ▼                                          │
   Spawn enemy ──▶ Kill enemy ──▶ Get gold ──▶ Upgrade tower ──▶ Survive wave
        ▲                                                              │
        └──────────────────────────────────────────────────────────────┘
```

One turn of the loop, as the player experiences it:

| Step | Player action | System | Detail |
|---|---|---|---|
| **Spawn enemy** | Press **Start Wave**, or wait 15 s | Wave spawner drips units onto the path every 0.8 s | [[Enemies#Enemy types]] |
| **Kill enemy** | Passive — towers auto-fire | Towers target the enemy furthest along the path | [[Towers#Targeting and firing]] |
| **Get gold** | Passive — kills pay out | Gold credited on `enemy_defeated` | [[Economy#Wave payouts]] |
| **Upgrade tower** | Click a tower → **Upgrade**, or place a new one | Spend gold on power | [[Towers#Upgrade system]] |
| **Survive wave** | Passive — leaks cost base HP | Wave clears, next one arms | [[Economy#Base HP pressure]] |

### What the player actually decides

Only two steps in the loop take input, and both are spending decisions. Kill, gold, and
survive are all consequences. That means **the entire game is the answer to one question:
given this much gold, what do I build and where?**

Three sub-decisions hang off it:

1. **Build wide or build tall** — a second tower, or a stronger existing one.
2. **Which type** — spear, arrow, or shells ([[Towers#Tower types]]).
3. **Where** — coverage along a fixed 51-point path, constrained by
   [[Towers#Placement]] validity rules.

The tension the loop is *supposed* to create: gold arrives in discrete lumps per wave, so
each inter-wave gap is a small allocation puzzle under time pressure from the 15 s
auto-advance timer.

---

## Player goals

### Session goal

Clear all 13 waves without base HP reaching zero. Clearing wave 13 triggers the level-complete
screen; that is the entire win condition today.

### Moment-to-moment goals

| Horizon | Goal | Feedback the game gives |
|---|---|---|
| Seconds | Watch the wave get shredded before it reaches the base | HP bars drain, enemies pop |
| One wave | Spend the last payout well enough to survive the next composition | Gold counter, wave label |
| Whole run | Build a layout that scales into the hobgoblin boss wave | Base HP as a run-long resource |

### The implicit mastery curve

A player is improving when they learn to:

- Read a wave composition and pre-empt it (wave 13 is 15 hobgoblins, 2 250 total HP).
- Recognise that **calling waves early is free** — the Start Wave button carries no penalty
  and no rush bonus, so skipping the 15 s gap is strictly correct play.
- Cover the path's slow S-bend, where a tower's radius overlaps the most path length.

> ⚠️ The second item is a design hole, not a skill: an option with no downside isn't a
> decision. A rush bonus would convert it into one. See [[TODO#P2 — Content and polish]].

---

## Main systems involved

Each loop step maps to concrete systems. Implementation wiring is in [[Architecture]].

| System | Owns | Documented in |
|---|---|---|
| **Wave spawner** | `WAVE_CONFIG`, spawn cadence, wave advance, level complete | [[Architecture#Wave lifecycle]] |
| **Enemy** | Path following, crowd separation, HP, splitting, base damage | [[Enemies]] |
| **Tower** | Targeting, firing, upgrade levels, click hitbox | [[Towers]] |
| **Projectile** | Homing flight, distance-based hit | [[Towers#Targeting and firing]] |
| **Placement** | Drag, ghost preview, validity rules | [[Towers#Placement]] |
| **Economy state** | Gold, base HP, costs, payouts | [[Economy]] |
| **Presentation** | Grass, wind, shadows, cloud shadows, depth sorting | [[Architecture#Rendering pipeline]] |

All of these currently live inside one script. The god-object problem and its four proposed
seams are documented in [[Architecture#Structural problems]] and [[TODO#P1 — Structural]].

### System interactions that matter to design

- **Path is singular and fixed.** No branches, no alternate routes, no flying lane
  ([[Enemies#Path]]). Every tower placement is evaluated against the same 51-point curve,
  which makes coverage a solvable problem rather than an adaptive one.
- **Targeting is fixed to furthest-along.** No focus-fire, no last, no strongest. This
  removes a lever most tower defence games use for player expression.
- **Crowd separation, not collision.** Enemies shove each other sideways rather than queue
  ([[Enemies#Crowd separation]]), so a dense wave spreads laterally and briefly widens the
  effective target band.

---

## Economy loop

```
  kill enemy ──▶ +gold ──▶ spend on build or upgrade ──▶ more DPS ──▶ more kills
       ▲                                                                  │
       └──────────────────────────────────────────────────────────────────┘
```

### Sources and sinks

| Direction | Channel | Value |
|---|---|---|
| Source | Enemy kill | 1–30 gold by type; 3 120 total across all 13 waves |
| Source | Starting capital | **3 000** ⚠️ debug value |
| Sink | Tower build | 50 / 75 / 120 |
| Sink | Upgrade | flat `int(cost × 0.75)`, twice per tower |
| Partial refund | Sell | 70 % of everything invested |

Full tables in [[Economy#Costs]] and [[Economy#Wave payouts]].

### The intended pressure

A working economy loop for this game wants **gold scarce early and comfortable late**, so
that the first three waves are tense and the player's mid-game investment decisions compound.
The wave payout curve is shaped correctly for that — income ramps from 40 gold in wave 1 to
544 in wave 12.

### Where it breaks today

Two independent faults sever the loop between *get gold* and *upgrade tower*:

1. **Starting gold is a debug value.** 3 000 starting gold against a 3 120 full-game payout
   means the player can build 25 spear towers before wave 1 spawns. Income is decorative.
   Fix: [[TODO#P0 — Blocking]].
2. **Upgrading is dominated at every tier.** Each upgrade buys `1.15 × 1.15 = 1.3225×` DPS
   for 75 % of the build cost. A second spear tower is 50 gold for +10 DPS; upgrading one is
   37 gold for +3.2 DPS. Building wide wins at every level, for every tower — so the loop's
   fourth step is a trap.

Because the upgrade price is flat rather than escalating, **L2→L3 is strictly better value
than L1→L2** — the inverse of the usual curve. Detail and a proposed first pass in
[[Economy#Balance summary]] and [[Economy#Suggested first pass]].

> The loop diagram at the top of this document is therefore **design intent, not a
> description of the current build**. Making it true is [[TODO#P0 — Blocking]] item 3
> followed by [[TODO#P2 — Content and polish]] item 15.

---

## Progression loop

There are three nested progressions. Only the first is fully implemented.

### 1. Within a wave — tactical (works)

Enemies stream in over ~10–20 s. The player watches, and can place a tower mid-wave if gold
allows. Feedback is immediate: HP bars, deaths, the gold counter ticking.

### 2. Across waves — strategic (works, but flattened by the economy)

| Wave band | Composition | Intended demand on the player |
|---|---|---|
| 1–3 | Slimes, first big slimes | Establish two or three towers; learn the path |
| 4–7 | Goblins join; mixed speeds | Cover the fast lane; spread coverage along the S-bend |
| 8–12 | Hobgoblins appear, counts climb | Concentrate DPS; commit to upgrades |
| 13 | 15 hobgoblins, 2 250 HP | Boss check — does the built layout actually scale? |

Enemy HP grows 20 → 150 across the game while tower prices stay flat, so the intended answer
is *more and better towers*. That ramp is real and correctly shaped — it is simply invisible
while the player starts with 3 000 gold.

### 3. Across runs — meta (does not exist)

No save system, no persistence, no unlocks, no second level. `_on_level_complete_next()` is
an empty placeholder. Every run starts identical and ends identical.

### Tower progression

Three levels per tower, `pow(1.15, level - 1)` applied to damage, fire rate and range
([[Towers#Upgrade system]]). Visual feedback is a 25 % `modulate` darkening per level — there
is no distinct art per tier, so progression reads weakly on screen. A level-3 tower looks like
a dimmer level-1 tower.

---

## Failure conditions

### The only real failure

`base_health` reaches 0 → `GameOverScreen` → restart or main menu. Base HP starts at **20**
and never regenerates. There is no repair, no lives, no HP scaling between waves.

### Damage on arrival

| Enemy | Base damage |
|---|---:|
| Slime, mini slime, small goblin, fast goblin | 1 |
| Big slime | 2 |
| Hobgoblin | 3 |

### Why this is a cliff rather than a curve

- Wave 13 alone (15 hobgoblins × 3) can deal **45 damage** — more than twice the total pool.
- Wave 12 can deal 52.
- Even a fully-leaked wave 1 costs 8 of 20.

The budget across the entire game is "leak at most ~19 low-tier enemies." In practice the
player is either untouched or dead; there is no attritional middle where they feel pressure
and adapt. Compounding it, there is **no wave-clear bonus**, so a leak costs HP *and* the
gold that enemy would have paid — double punishment with no comeback mechanic.

Analysis in [[Economy#Base HP pressure]]; both items appear in [[Economy#Balance summary]].

### Soft failures (no fail state, but the run is lost)

- Spending into three max-level spears early and having no gold for coverage at wave 10.
- Selling to reposition — a flat 30 % haircut discourages the main tactical lever the
  placement system offers ([[Towers#Upgrade system]]).

---

## Future expansion ideas

Ordered by *design leverage per unit of work*, not by size. Nothing here is scheduled;
[[TODO]] is the authority on what is actually planned.

### Would fix the loop as drawn

1. **Escalating upgrade cost** — `tower_cost × 0.75 × level` or similar, so upgrading is a
   real alternative to building wide rather than a strictly worse one.
2. **Wave-clear bonus** — a small flat payout per cleared wave, so leaking costs HP but not
   the whole income stream. Removes the double punishment.
3. **Real starting gold** (150–250) gated behind `DEBUG_MODE`. Nothing else in the economy
   can be evaluated until this lands.
4. **Rush bonus for calling waves early** — converts a free button into a risk/reward
   decision, which is the cheapest new decision available.

### Would deepen the decision space

5. **Distinct tower roles.** Three towers currently sit on one DPS-per-gold line with
   different constants. Splash for shells, slow or pierce for arrow, and *which tower* becomes
   a real question ([[TODO#P2 — Content and polish]]).
6. **Targeting modes** — first / last / strongest / closest, per tower. Standard genre
   vocabulary, and the targeting code already isolates the selection step.
7. **Enemy modifiers** — armoured (flat damage reduction), fast, regenerating. Forces
   composition reading rather than raw DPS stacking.
8. **Branching paths or a second spawn point.** The single fixed curve makes coverage a
   solvable problem; a branch makes it a live one. Structurally the largest change here, since
   the path is a single `Curve2D`.

### Content and shell

9. **Second level.** The hook exists as an empty stub. Needs the decor-placement work in
   [[TODO#P1 — Structural]] first — `Main.tscn` at 3 329 lines with ~230 hand-placed sprites
   is not a template anyone wants to copy.
10. **Endless mode.** `_get_wave_config` already clamps for it; the machinery is present but
    unreachable.
11. **Audio.** None exists — no fire, hit, death, build, or music. The single largest
    perceived-polish gap.
12. **Save/settings.** Persistence, volume, resolution, default speed.

### Design risks worth naming

- **Adding content before fixing the economy** buries the balance problem under more numbers.
  Items 1–3 should precede items 5–8.
- **Branching paths interact badly with crowd separation**, which assumes a single lateral
  axis around one curve ([[Enemies#Crowd separation]]).
- **More enemy types cost five edits each** until the data is resource-driven
  ([[Architecture#3. Adding one enemy type requires five edits]], [[TODO#P1 — Structural]]).
