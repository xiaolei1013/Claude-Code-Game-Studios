# Combat Resolution System GDD — Lantern Guild

> **GDD #11 in design order** (System #11 in systems index)
> **Status**: In Design — Pass 1 revision applied 2026-04-19
> **Created**: 2026-04-19
> **Last Updated**: 2026-04-22 (**Pass-INIT-PROBE-SYNC — DI injection seam corrected from `_init(combat_resolver)` / "injected at construction" to the lazy-default-with-public-setters pattern locked by `dungeon-run-orchestrator.md` §J.1 Option A** per autoload.md Claim 4 [VERIFIED] finding that Godot's autoload system calls `_init()` with zero arguments. Test-injection uses `DungeonRunOrchestrator.set_combat_resolver(spy)` BEFORE `_ready()` fires; production uses lazy-default construction inside `_ready()` with null-check short-circuit. C.4 DefaultCombatResolver paragraph + §F Downstream Dependents row corrected in lockstep with ADR-0009 + ADR-0003 Amendment #3. Pass 3D structural decisions (`class_name CombatResolver extends RefCounted`, `DefaultCombatResolver` production subclass, instance-methods-not-static, spy-subclass test pattern) are UNCHANGED — only the injection MECHANISM is corrected (from imagined `_init(args)` to the already-locked §J.1 Option A pattern).) Previously: 2026-04-19 (Pass 1 mechanical revision — 9 BLOCKING items from 2026-04-19 design-review addressed)
> **Authors**: systems-designer + game-designer + qa-lead + main session
> **Depends on**: `design/gdd/hero-roster.md` (#9), `design/gdd/class-vs-enemy-matchup-resolver.md` (#10) — both Approved
> **Indirect upstreams**: Hero Class DB (#5), Enemy DB (#6), Biome/Dungeon DB (#7), Economy (#4), Game Time & Tick (#1)
> **Referenced by**: Offline Progression Engine (#12), Dungeon Run Orchestrator (#13)
> **Implements Pillar**: Pillar 1 (deterministic offline math) + Pillar 3 (matchup-driven kill cadence is the load-bearing economic hook). **Pillar 2 (Warrior HP as identity)** is *structurally present* via the `hp_bonus_factor` formula (Rule 9 / D.6) but is **MVP-invisible by design** — the factor saturates at 1.0 for every naturally-constructable MVP formation (lowest natural ratio is solo L1 Rogue on F4 = 55/96 = 0.573, well above the 0.5 LOSING trigger). Pillar 2's mechanical payoff is **V1.0-deferred** (hard-mode floors and Cleric synergy multipliers will be tuned to push some constructable formations into the 0.5–1.0 band where the factor varies). The MVP retains the formula as (a) a deterministic safety net against floor-authoring bugs that would otherwise leave players un-defended on broken inputs, and (b) the engine surface that V1.0 content can drive without a Combat schema change. **Pass 3C 2026-04-20** committed to this path explicitly (locked decision; supersedes Pass 2B Open Q5).
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

**Revision history:**
- 2026-04-19 — Initial authoring, 18 ACs, review returned MAJOR REVISION NEEDED (14 BLOCKING items).
- 2026-04-19 — **Pass 1 (mechanical)**: Rule 3 SPEED_BASE narrative corrected (800 → 2400); D.1 `speed <= 0` pre-guard added; D.7 calibration table recomputed from `stat_at_level` (Class DB D.1) — all 5 floor rows now exact integer weighted sums; D.2/D.4 output ranges corrected (5.0 → 2.31 MVP theoretical max); D.6 `formation_total_hp` bounds corrected (175–735 → 55–1074) to match registry; `ceil()`/`floor()` notation replaced with `ceili()`/`floori()` throughout (GDScript 4.6 integer-returning variants); new C.4 Type Contracts section added defining `CombatResolver extends RefCounted` and explicit `equals()` methods on `KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot` (unblocks AC-01 field-equality test); AC-02 lossless assertion rewritten (integer weighted-sum primary, float is_equal_approx secondary); AC-07 and AC-09 split into Combat-side (BLOCKING) + Orchestrator-side (DEFERRED #13); AC-14 BASELINES.md reference replaced with inline CI-runner spec; Rule 7 / E.1 / E.2 reconciled with stateless contract (log-per-call, not log-once; idempotency moved to Orchestrator). **Pass 2 (design judgment — Warrior HP vacuousness, Pillar 3 audibility, F5 HP cascade, Rule 7/Economy C.2.3 reconciliation) remains pending.**

---

## A. Overview

The Combat Resolution System turns a dispatched formation into a stream of enemy-kill events at a predictable cadence. It is the engine that produces the "+22g" pop the player hears every few seconds during an active dungeon run, and the deterministic kill-and-damage math that the Offline Progression Engine replays after the player has been away. From the player's seat it is invisible — there is no combat input, no targeting, no mid-fight intervention (per the anti-pillar against reactive combat). What the player feels is the *tempo*: how fast enemies fall, how predictably the formation chews through a floor, and how the rhythm visibly accelerates when their roster grows. That tempo is this system's only output.

Architecturally, Combat Resolution is a stateless / pure-function layer that exposes two execution paths to its consumers. The **foreground path** subscribes to `tick_fired` (20 Hz) and produces `enemy_killed(enemy_tier, enemy_archetype)` events to the Dungeon Run Orchestrator (#13) for live spectator runs. The **offline-batch path** exposes `compute_offline_batch(formation_snapshot, floor_data, tick_budget) -> CombatBatchResult` for the Offline Progression Engine (#12) — same inputs produce identical outputs (Pillar 1 deterministic-replay invariant). Inputs are read-only: a frozen `Array[HeroInstance]` snapshot from Hero Roster (#9) and a `Floor` resource from Biome/Dungeon DB (#7). Outputs are kill counts (per archetype, per tier) and floor-completion status. Combat **calls `MatchupResolver` at dispatch** (per-enemy, inside `_kill_schedule_for_loop`) to derive a per-enemy `matchup_throughput_factor` that routes into the kill schedule. Pillar 3 is thus *mechanically audible* — an advantaged formation literally clears faster, not only earns more gold. The Orchestrator still owns gold attribution via the per-kill `is_matchup_advantaged` signal (that path is unchanged).

This GDD locks three contracts that upstream GDDs explicitly deferred to it: (1) **speed semantics** (Class DB Open Question 4 — what `base_speed` actually does), (2) **round-to-tick cadence** (Enemy DB Open Question — whether 1 round = 200 ticks / 10 seconds is correct, recalibrating HP if not), and (3) **kill-frequency model** (Economy D.6 placeholder — replacing the heuristic "1 kill / 10 sec" with a derivable formula). It also resolves the Biome DB F3/F4 `expected_clear_time_seconds` tension (60s/90s targets vs 120s/176s HP-model predictions). All four resolutions cascade back into upstream GDDs as registry updates and section errata.

## B. Player Fantasy

The player dispatched a mid-game Warrior + Mage + Warrior formation at L13 into Floor 4 — three Thorn Guardians, all bruisers — about a minute ago. They glance back at the dungeon panel. The `+120g` gold pops are arriving roughly every 22 seconds — not a barrage, but a clear, steady beat: one pop, enough breath to register it, another pop, and another. Back on Floor 1 with the same formation the same pops arrive every few seconds; that pace feels "frantic," and they don't remember the last time Floor 1 felt worth watching. F4 is slower, but the *cadence itself* is cleaner than it was the last time they ran their old L11 W+M+R generalist here — back then the pops came roughly every 30 seconds for the same floor, and the run felt like it was limping. The difference is Pillar 3 becoming audible *layered on top of* a level investment: the W+M+W stack is advantaged (two warriors cross the matchup majority for bruiser → `matchup_throughput_factor = 1.5`), so effective throughput on every Thorn Guardian rises by 50%, and `ticks_per_loop` on F4 drops from ~1800 ticks (L11 W+M+R neutral, derived in D.5/D.7) to ~1300 ticks (L13 W+M+W advantaged). They didn't *do* anything in the last sixty seconds — they didn't tap, didn't react, didn't intervene. The tempo itself is the receipt that the formation choice they made at the assignment layer — specialize into bruiser coverage, accept that glowmoths die slow — was the right call.

> *Cadence derivation (audit anchor for D.7 / D.5)*: L13 W+M+W weighted_sum = `2 × (36×18) + (56×22) = 2528`; raw `dps = 2528 / 2400 = 1.0533`; `effective_dps = 1.0533 × 1.5 (advantaged on bruiser) × 1.0 (hp_bonus_factor saturated) = 1.580`; per-thorn_guardian `ticks_to_kill = ceili(680 / 1.580) = 431` ≈ 21.55 s/pop ≈ "every 22 seconds"; `ticks_per_loop = 3 × 431 = 1293` ≈ "~1300". The "last week" contrast L11 W+M+R neutral: weighted_sum = `(32×16) + (50×20) + (34×36) = 2736`; raw `dps = 2736 / 2400 = 1.140`; neutral `effective_dps = 1.140`; `ticks_to_kill = ceili(680 / 1.140) = 597` ≈ 29.85 s/pop ≈ "every 30 seconds"; `ticks_per_loop = 3 × 597 = 1791` ≈ "~1800". Both numbers derive from D.7's authoritative L11 / L13 weighted sums; player journey assumes a level-up plus a specialization between sessions.

The emotional target is **vindicated foresight** — the quiet, hearth-warm satisfaction of a good call paying off. Not the burst-y triumph of a critical hit; not the rush of a combo connecting. *A steady beat*, *a clean run*, *a good call* — the language of small confident nouns, never "crushing" or "dominating." The cozy register of the broader game lives or dies in this system's word choice and feedback timing. A player who came back from a coffee break and sees their Forest Reach Floor 3 clearing in a slower but visibly tighter rhythm than last week's generalist formation should feel the way you feel when a slow-cooked meal turns out exactly the way you planned. The word *brisk* is reserved for Floor 1 onboarding (~10s between pops on a fresh L2 formation); deeper floors run at a *measured* or *tight* cadence. This language discipline matters because overselling tempo as "brisk" at F4+ produces a gap between promise and delivery — the cozy register doesn't survive that gap.

This fantasy must work in both player modes Combat Resolution serves. The **live spectator** path (foreground, 20 Hz) delivers the rhythm in real time — that's the diorama-tilt-shift moment. The **return-from-offline** path (`compute_offline_batch`) delivers the same tempo as a compressed kill summary on the Return-to-App screen, where "+22g × 18 kills, F3 cleared" is the same vindicated-foresight payoff condensed into one screen. Combat Resolution is the *only* system in the game whose output is identical across foreground and offline runs (Pillar 1's deterministic-replay invariant). That symmetry is what lets the same fantasy land in both session shapes without two separate emotional registers competing.

## C. Detailed Design

### C.1 Core Rules

#### Architecture

**Rule 1.** Combat Resolution is a **stateless injectable instance class** (`class_name CombatResolver extends RefCounted`, Pass 3D — see C.4 for DI rationale; pre-Pass-3D shape was `@abstract extends Object` static-only). It has no instance variables, no class-level mutable state, no caches, no RNG; the instance is a dependency container, not a state container. All public methods are pure functions of `(formation_snapshot, floor_data, time_inputs)`. This satisfies Pillar 1's offline-replay-fairness invariant by construction — same input → same output, no special seeding required. Run state (current loop counter, emitted kill events, elapsed ticks) is owned by the Dungeon Run Orchestrator (#13), not by CombatResolver. Production wiring uses `DefaultCombatResolver.new()` (the concrete impl extending `CombatResolver`); tests extend `CombatResolver` to create spy/stub subclasses.

**Rule 2.** CombatResolver exposes **two execution paths** that share their underlying formulas (Pass 3D — instance methods on an injected `combat_resolver: CombatResolver` field; pre-Pass-3D these were `static func`):

```
# Foreground (signal-driven, called from Orchestrator's _on_tick):
func emit_events_in_range(
    formation: Array[HeroInstance],
    floor: Floor,
    range_start_tick: int,   # exclusive
    range_end_tick: int       # inclusive
) -> CombatTickEvents

# Offline (batch, called by Offline Engine #12):
func compute_offline_batch(
    formation: Array[HeroInstance],
    floor: Floor,
    tick_budget: int
) -> CombatBatchResult
```

The offline-batch path's output **is the canonical truth**. The foreground path computes the same events the offline path would have produced for ticks `(range_start, range_end]` — it is a windowed view onto the same closed-form schedule. Foreground does not "simulate forward" any differently from offline; both call the same private helpers (`_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop`). This eliminates foreground-vs-offline drift by construction (Economy AC H-09 determinism contract automatically satisfied).

#### Combat Model — Speed-Weighted Action Queue with Closed-Form Throughput

**Rule 3.** Speed is a **cooldown divisor** (resolves Class DB GDD #5 Open Question 4). Each combatant — hero or enemy — has an action cooldown derived from their `speed` stat:

```
action_cooldown_ticks(combatant):
    if combatant.speed <= 0: return 1            # pre-guard
    return maxi(1, floori(SPEED_BASE / combatant.speed))
```

A Rogue (base speed 16) acts every `floori(2400/16) = 150` ticks (7.5 s); a Warrior (base speed 6) every `floori(2400/6) = 400` ticks (20 s); a Hollow Brute (speed 3) every `floori(2400/3) = 800` ticks (40 s). **Higher speed = more frequent actions. Equal-attack-speed-product heroes contribute equal output per unit time** — this is the key invariant that makes the closed-form throughput formula (Rule 4) correct. `SPEED_BASE` is the single tuning knob that recalibrates all clear times simultaneously (default `2400`; see Section G for full calibration table).

**Rule 4.** Formation **raw** throughput is the **closed-form sum of per-hero damage rates** over the SPEED_BASE window:

```
formation_dps_per_tick = sum(hero.attack * hero.speed for hero in formation) / SPEED_BASE
```

This formula is the heart of the system. It collapses the per-combatant action queue into one scalar that drives every downstream calculation (kill cadence, loop time, throughput). Per-hero contribution = `hero.attack × hero.speed / SPEED_BASE` — the Rogue's identity (high speed) and Mage's identity (high attack) are **mechanically distinct** per Pillar 2: at the default `SPEED_BASE = 2400`, a max-level Mage contributes `62×24/2400 = 0.62` damage/tick; a max-level Rogue contributes `42×44/2400 = 0.77` damage/tick; a max-level Warrior contributes `40×20/2400 = 0.333` damage/tick. The Rogue is the highest-DPS class at L15 *because of speed*, not despite it (44 SPD vs Mage 24 vs Warrior 20).

**Pillar 2 + Pillar 3 routing**: `formation_dps_per_tick` is the *raw* rate. The **effective** per-enemy rate applied inside the kill schedule (Rule 10, D.5) is:

```
effective_dps = formation_dps_per_tick × matchup_throughput_factor(enemy.archetype) × hp_bonus_factor
```

- `matchup_throughput_factor` — `MATCHUP_THROUGHPUT_FACTOR_ADV` (default `1.5`) if formation crosses Resolver's majority threshold for that enemy's archetype, else `MATCHUP_THROUGHPUT_FACTOR_DIS` (default `1.0`). **Pillar 3 audibility.**
- `hp_bonus_factor` — `mini(formation_total_hp / floor_total_enemy_attack, 1.0)` (Rule 9, D.6). Constant across all enemies in a floor (floor-level signal). **Pillar 2 audibility** — weaker formations literally clear slower.

Both factors multiply raw throughput; neither punishes below 1.0 (disadvantaged = baseline; under-HP continuously reduces toward 0 but saturates at 1.0 when formation is adequately resourced).

**Rule 5.** Hero targeting: front-of-queue. The formation collectively damages `floor.enemy_list[next_alive]` until that enemy reaches 0 HP, then advances to the next entry. Targeting is implicit in the closed-form — no per-hero target-selection logic. This abstraction is intentional: per Pillar 3 anti-pillar, there is no targeting decision exposed to the player.

**Rule 6.** Enemy "attacks" are pooled into formation damage taken (informational only in MVP; see Rule 9):

```
enemy_dps_per_tick(floor) = sum(enemy.base_attack * enemy.base_speed * count for enemy in floor.enemy_list) / SPEED_BASE
```

No per-enemy-target selection; enemies "all attack the formation." This satisfies the cozy register without requiring per-tick target arbitration.

#### Continuous Loop & First-Clear

**Rule 7.** When the last enemy in `floor.enemy_list` dies (`floor_clear_tick`), the floor **immediately respawns** the same enemy list in the same order. The loop counter increments. Kill bonuses fire on every kill (every loop). The floor-clear bonus must fire **exactly once per dispatch** — the first time the loop counter increments from 0 to 1 — regardless of how many subsequent loops complete in the same offline batch or foreground session. **Because CombatResolver is stateless (Rule 1), Combat itself cannot track "exactly once per dispatch" across calls.** Combat's contract is narrower: on every call, it returns loop-boundary markers and (for batch) `first_clear_tick`; on foreground, it sets `CombatTickEvents.first_clear_in_range = true` whenever the 0→1 transition falls in the tick range of that specific call. The **Orchestrator (#13)** holds the "already-fired" flag on the run snapshot and is responsible for emitting `floor_cleared_first_time(floor_index)` to Economy at most once per dispatch.

**Formal invariant for Orchestrator GDD #13** (recorded here as a breadcrumb so the future Orchestrator author has a normative reference): the Orchestrator MUST emit `floor_cleared_first_time(floor_index)` on the first call where `CombatTickEvents.first_clear_in_range == true` (foreground) or `CombatBatchResult.first_clear_tick > 0` (offline) within a given dispatch, AND MUST NOT emit it again for the same dispatch regardless of subsequent calls returning truthy first-clear markers. This per-dispatch invariant is tested at the Orchestrator boundary (AC-COMBAT-09b, deferred). The per-save-lifetime idempotency layer above this is owned by Economy (`floors_cleared_bonus_awarded: Array[bool]` per Economy C.2.3 + AC H-03), which guards against duplicate signals reaching Economy. The three-layer split (Combat: stateless markers / Orchestrator: per-dispatch dedup / Economy: per-lifetime dedup) is coherent and intentional — no single layer carries the full burden.

**Rule 8.** Loop cadence is deterministic but no longer a single closed-form division — the per-enemy `matchup_throughput_factor` (Rule 4, D.5) breaks the `sum(HP) / constant_dps` simplification. `ticks_per_loop` is instead derived as the last entry of the kill schedule:

```
floor_total_hp   = sum(enemy.base_hp * count for enemy in floor.enemy_list)   # informational — used by registry + D.7 pacing table
ticks_per_loop   = _kill_schedule_for_loop(formation, floor).back().kill_tick
```

A run that lasts `tick_budget` produces `floori(tick_budget / ticks_per_loop)` complete loops plus a partial loop. Kills within a loop fire at the deterministic ticks computed by `_kill_schedule_for_loop` (Rule 10 and D.5). The `+1` first-clear bonus is a single event at `ticks_per_loop` (the first complete loop's clear). Per-enemy integer ceiling (D.5) is **not numerically identical** to Pass 2A's single cumulative-HP ceiling even under uniform `matchup_throughput_factor` — `ceili(a/c) + ceili(b/c) ≥ ceili((a+b)/c)`, with a 0-1 tick drift per enemy. Under Pass 2B the **per-enemy path is canonical** for both implementation and AC expected values (AC-04, AC-05, AC-08, AC-17 updated accordingly); the single-division shape survives only as the informational "cumulative-HP approximation" used by the D.7 pacing table to stay within ~1% of first-playtest targets.

#### HP-Efficiency (Continuous Pillar 2 Hook)

**Rule 9.** Hero HP is modeled at the **formation level**, not per-hero. At dispatch time, a single deterministic computation produces a continuous `hp_bonus_factor` that modulates throughput (per-enemy, inside `_kill_schedule_for_loop`) AND — as a soft safety net — triggers `LOSING_RUN_LOOT_FACTOR` when the formation is grossly underlevelled:

```
formation_total_hp       = sum(stat_at_level("hp", hero.class_data, hero.current_level) for hero in formation)
floor_total_enemy_attack = sum(enemy.base_attack * count for enemy in floor.enemy_list)
hp_bonus_factor          = mini(formation_total_hp / floor_total_enemy_attack, 1.0)   # continuous, [0, 1]
losing_run               = (hp_bonus_factor < 0.5)                                   # boolean trigger
```

`hp_bonus_factor` is a **throughput multiplier** applied alongside `matchup_throughput_factor` inside the kill schedule: `effective_dps = formation_dps_per_tick × matchup_throughput_factor × hp_bonus_factor` (Rule 10 / D.5). A weaker formation clears **slower**, not via a binary penalty. This is the **engine surface for the Pillar 2 (Warrior HP as identity) hook**, but the formula is **MVP-invisible by design** — the factor saturates at 1.0 for every constructable MVP formation (header pillar disclaimer). The structural slot exists so V1.0 hard content + Cleric synergy can light it up without a Combat schema change; on MVP F1–F5 the factor is `1.0` for every realistic dispatch and contributes nothing to tempo. **Heroes never "die"** during a run; they cannot be incapacitated; the roster is unchanged after any combat.

`losing_run == true` (i.e., `hp_bonus_factor < 0.5`) additionally triggers `LOSING_RUN_LOOT_FACTOR` (default `0.5`) applied to **per-kill bonuses and `FLOOR_CLEAR_BONUS[floor_index]` only** — see Economy C.2.3 + C.2.3a for the explicit handoff contract. **Pass 2B locked decision 4 originally scoped the halving to "all gold from the run" (drip + kills + floor-clear); this was superseded by Pass 4B-Economy 2026-04-20**: drip is now run-outcome-independent by architecture — Economy subscribes to `tick_fired` independently and has no access to RunSnapshot, so the Orchestrator has no architectural home for communicating `losing_run` to Economy's drip path without introducing a cross-system coupling. The Orchestrator owns `losing_run` state and applies `LOSING_RUN_LOOT_FACTOR` to kill gold (via `attribute_kill_gold`) and floor-clear bonus (via `attribute_floor_clear_bonus`) before calling `Economy.add_gold()` / `Economy.try_award_floor_clear()`; Economy receives the post-factor amount and does NOT apply the factor independently. Drip per-tick output is unchanged by `losing_run`. See Economy review log Pass 4B-Economy entry for A2 rationale. First-clear milestones are NOT exempt — a grossly-underlevelled run that happens to first-clear a floor marks `floors_cleared_bonus_awarded[floor_index] = true` but awards the diminished (0.5×) bonus. The floor cannot be "re-cleared" later to reclaim the full bonus (idempotency contract per Economy AC H-03). Rationale: the pop still fires, but the economy-level punctuation reflects the thin margin of success — Pillar 1 stays intact (no fail state), while Pillar 2 keeps its teeth. In MVP floors (F1-F5, `floor_total_enemy_attack` ∈ [35, 96]), `losing_run` is near-unreachable: the lowest naturally-constructable formation is L1 solo Rogue (HP 55), which against F4 (attack 96) gives `hp_bonus_factor = 55/96 = 0.573 ≥ 0.5` — `losing_run = false`. The knob survives as a safety net for V1.0 hard content and authoring-bug defense.

**Pass 2B migration note**: Pass 2A's boolean `survived = formation_total_hp >= (1.0 - SURVIVAL_MARGIN) × floor_total_enemy_attack` with `SURVIVAL_MARGIN = 0.2` is deprecated. `survived: bool` remains on the output contract (Orchestrator code path unchanged) but is **redefined** as `survived := !losing_run` (i.e., `hp_bonus_factor >= 0.5`). The output now ALSO carries the raw `hp_bonus_factor: float` for the throughput coupling. `SURVIVAL_MARGIN` is marked deprecated in G.1 and entities.yaml.

Cleric (V1.0) will plug into Pillar 2 by raising `formation_total_hp` via a synergy multiplier upstream of the snapshot — no Combat schema change.

**Rule 10.** The full kill schedule for one loop is deterministic and computed once, with per-enemy `matchup_throughput_factor` and floor-level `hp_bonus_factor` applied in-loop:

```
_kill_schedule_for_loop(formation, floor) -> Array[KillEvent]
# Pseudocode:
dps        = formation_dps_per_tick(formation)     # raw throughput (Rule 4)
hp_factor  = hp_bonus_factor(formation, floor)     # Pillar 2 (Rule 9, D.6) — floor-level
schedule   = []
kill_tick  = 0
for entry in floor.enemy_list:
    enemy      = DataRegistry.resolve("enemies", entry.enemy_id)
    advantaged = MatchupResolver.resolve_formation_matchup(
                     formation, enemy.archetype).is_advantaged
    mu_factor  = MATCHUP_THROUGHPUT_FACTOR_ADV if advantaged else MATCHUP_THROUGHPUT_FACTOR_DIS
    effective_dps = dps * mu_factor * hp_factor    # Pillar 3 × Pillar 2
    for _ in range(entry.count):
        ticks_to_kill = ceili(enemy.base_hp / effective_dps)
        kill_tick    += ticks_to_kill
        schedule.append({
            enemy_id:  enemy.id,
            archetype: enemy.archetype,
            tier:      enemy.tier,
            is_boss:   enemy.is_boss,
            kill_tick: kill_tick,
        })
return schedule
```

The schedule is loop-relative (tick 0 = loop start). The Orchestrator (or Offline Engine) adds `loop_index * ticks_per_loop` to absolute-time the events. `MatchupResolver.resolve_formation_matchup` is stateless (Resolver GDD #10 Rule 11) — calling it once per distinct enemy entry (N≤5 per MVP floor) is well under Combat's AC-14 performance budget. No RNG, no branches beyond the matchup lookup — integer arithmetic throughout.

**Why per-enemy (not per-floor)**: F3 is the only MVP floor with mixed archetypes (bruiser + caster + armored). Per-floor majority would collapse that mix into one factor and lie about what the formation actually counters. Per-enemy preserves the Resolver's per-kill semantic (Rule 6 majority threshold `n > N/2`) — the same boolean already flowing through the gold path.

---

### C.2 States and Transitions

Because CombatResolver is a stateless static class, it has **no runtime state of its own**. The "states" relevant to Combat live on the run snapshot owned by the Dungeon Run Orchestrator (#13):

| Run state (Orchestrator-owned) | CombatResolver behavior |
|---|---|
| `NO_RUN` | CombatResolver is not called. |
| `DISPATCHING` | Orchestrator calls `compute_offline_batch(formation, floor, 0)` once to derive `survived`, `formation_dps_per_tick`, `ticks_per_loop`, and the first-loop kill schedule. These are cached on the run snapshot. |
| `ACTIVE_FOREGROUND` | Orchestrator calls `emit_events_in_range(formation, floor, last_n, current_n)` per `tick_fired`. Returned events are forwarded to Economy (kill bonuses, drip continues unchanged, first-clear bonus on the loop boundary). |
| `ACTIVE_OFFLINE_REPLAY` | Orchestrator (via Offline Engine) calls `compute_offline_batch(formation, floor, tick_budget)` once. Returned `CombatBatchResult` is folded into Economy via `compute_offline_batch` chain. |
| `RUN_ENDED` | Player reassigns or removes formation; CombatResolver no longer called for this run. Re-dispatching restarts at `DISPATCHING` (fresh survivability check + fresh schedule). |

Combat itself has no transitions to manage. The only invariant Combat enforces: for any `(formation, floor, tick_budget)` tuple, repeated calls to `compute_offline_batch` return field-equal `CombatBatchResult` objects (Rule 1 determinism).

---

### C.3 Interactions with Other Systems

| Consumer / Provider | Direction | Data Interface | What flows |
|---|---|---|---|
| **Hero Roster (#9)** | Combat reads | `roster.get_formation_heroes() -> Array[HeroInstance]` (called by Orchestrator at dispatch, NOT by Combat per tick) | Frozen formation snapshot for the run; Combat resolves each hero's class via `DataRegistry.resolve("classes", hero.class_id)` and computes live stats via `stat_at_level(stat, class_data, hero.current_level)` (Class DB D.1). No re-walk of Roster during the run. |
| **Hero Class DB (#5)** | Combat reads | `DataRegistry.resolve("classes", id) -> HeroClass`; `stat_at_level("attack"/"hp"/"speed", class_data, level)` | Per-hero live stats. Resolved at dispatch only; cached on the run snapshot. |
| **Enemy Database (#6)** | Combat reads | `DataRegistry.resolve("enemies", id) -> EnemyData` | Per-enemy `base_hp`, `base_attack`, `base_speed`, `archetype`, `tier`, `is_boss`. Resolved at dispatch from `floor.enemy_list`; no re-resolution during the run. |
| **Biome/Dungeon DB (#7)** | Combat reads | `Floor` resource | `floor.enemy_list` (the kill schedule's substrate), `floor.floor_index` (passed through to Economy for `BASE_DRIP[floor_index]` and `FLOOR_CLEAR_BONUS[floor_index]`), `floor.is_boss_floor` (forwarded to Orchestrator for boss-death fanfare). |
| **Game Time & Tick (#1)** | Combat does NOT subscribe directly | — | Combat is invoked by the Orchestrator on `tick_fired`; it does not subscribe to the signal itself. The instance pattern (Pass 3D) does not change this — signals still require a Node host; the injected `CombatResolver` instance is a `RefCounted`, not a Node. |
| **Dungeon Run Orchestrator (#13, undesigned)** | Combat is called by | `combat_resolver.emit_events_in_range(formation, floor, range_start, range_end) -> CombatTickEvents` per foreground tick; `combat_resolver.compute_offline_batch(formation, floor, tick_budget) -> CombatBatchResult` once per offline replay (Pass 3D: instance method calls on Orchestrator's injected `combat_resolver: CombatResolver` field) | Returns kill events, loop completions, first-clear marker. Orchestrator owns all signal emissions to Economy; Combat itself emits no signals. |
| **Offline Progression Engine (#12, undesigned)** | Combat is called by (via Orchestrator) | `compute_offline_batch` chain | Single batch call per dispatched floor in the offline budget. |
| **Economy System (#4)** | Combat does NOT call directly | — | All gold attribution flows: Orchestrator receives Combat's kill events, calls `economy.try_credit(BASE_KILL[tier] × matchup_multiplier)` per kill (with `matchup_multiplier` from MatchupResolver). Combat is unaware of gold. |
| **Matchup Resolver (#10)** | Combat calls at dispatch (per-enemy) | `MatchupResolver.resolve_formation_matchup(formation_snapshot, enemy.archetype) -> MatchupResult` | Called once per distinct enemy entry inside `_kill_schedule_for_loop` (Rule 10 / D.5). Consumes `result.is_advantaged` to select `MATCHUP_THROUGHPUT_FACTOR_ADV` vs `MATCHUP_THROUGHPUT_FACTOR_DIS`. Pass 2B promoted Combat from V1.0-reserved to MVP consumer; Resolver C.3 + F.2 Combat rows updated in lockstep. Orchestrator still owns the per-kill `is_matchup_advantaged` → gold path independently. |
| **Dungeon Run View (#24)** | Indirect | — | The Orchestrator forwards Combat's kill events to UI; Combat has no UI awareness. |

**Bidirectional consistency guarantees**:

1. **Foreground/offline parity (Pillar 1)**: For any `(formation, floor, T)`, the union of events from foreground `emit_events_in_range(0, T)` (across all tick boundaries) is field-equal to `compute_offline_batch(formation, floor, T).kills`. Asserted by an integration test (Section H).
2. **Resolver contract**: Combat calls `MatchupResolver.resolve_formation_matchup` per distinct enemy entry during `_kill_schedule_for_loop` at dispatch time (Pass 2B). No caching on Combat's side (stateless per Rule 1); Resolver itself is stateless (Resolver Rule 11). The call count is bounded by the number of distinct `enemy_list` entries per floor (≤5 in MVP). V1.0 Class Synergy may add further hooks but requires no schema change.
3. **Orchestrator owns all signal emission** to Economy/UI. Combat is a pure pull-model returning data structures. This keeps the static-class invariant clean and makes Combat trivially unit-testable in isolation.

---

### C.4 Type Contracts (GDScript 4.6 — RefCounted Value Types)

Combat's determinism pillar (Rule 1) and AC-COMBAT-01 ("field-equal across two calls") require explicit type contracts for every object that crosses the Combat/Orchestrator boundary. All value types extend `RefCounted` (lifecycle-managed; no manual `free()`), expose `@export`-typed fields for engine-visibility, and implement a deep `equals(other) -> bool` method so tests can assert field-equality without relying on `==` identity.

**`CombatResolver`** — the instance-based entry point. Declared as `class_name CombatResolver extends RefCounted` (Pass 3D — converted from static-only to instance methods to enable GdUnit4 test mocking; see Pass 3D note below). The Orchestrator holds one `_combat_resolver: CombatResolver` field populated via the lazy-default-with-public-setter pattern locked in `design/gdd/dungeon-run-orchestrator.md` §J.1 Option A (Pass-INIT-PROBE-SYNC 2026-04-22: the prior "injected at `_init`" phrasing was mechanically impossible on Godot 4.6 autoloads per autoload.md Claim 4 [VERIFIED]). Production wiring: `DungeonRunOrchestrator._ready()` null-checks `_combat_resolver` and calls `DefaultCombatResolver.new()` (zero-arg, non-autoload RefCounted) IF still null — zero-config boot. Test wiring: test body calls `orchestrator.set_combat_resolver(spy)` BEFORE `add_child(orchestrator)` (or before direct `orchestrator._ready()` call); the null-check in `_ready()` short-circuits so the spy is preserved. Matches `dungeon-run-orchestrator.md` §J.3 Mode 1.

**Pass 3D DI shape (injectable instance interface — option a)**: Prior to Pass 3D, `CombatResolver` was declared `@abstract class_name CombatResolver extends Object` with static methods only. That shape prevents GdUnit4 from mocking the class (GdUnit4 cannot mock static methods on `@abstract` classes), making AC-ORC-03 and AC-ORC-05 architecturally unwriteable. Pass 3D converts public methods to **instance methods** on a concrete base class. Subclasses override them for tests. The `@abstract` annotation is removed from the base implementation — it would prevent instantiation, which is now required. A concrete production implementation (`DefaultCombatResolver`) `extends CombatResolver` and provides the real logic; tests extend `CombatResolver` directly to create spies/stubs.

**Statelessness preserved**: `CombatResolver` instances carry no per-run state. Every call to `emit_events_in_range` or `compute_offline_batch` is a pure function of its arguments; the instance is a dependency, not a state container. Injecting the same `CombatResolver` instance across multiple Orchestrator dispatches is safe — there is nothing to reset between runs.

```gdscript
class_name CombatResolver extends RefCounted
# Injectable instance — never holds per-run mutable state. The Orchestrator
# injects one instance at construction; production wiring uses DefaultCombatResolver;
# tests inject a spy subclass. Pass 3D: converted from @abstract static-only to
# instance methods to enable GdUnit4 mocking of AC-ORC-03 and AC-ORC-05.

# AC-COMBAT-11 dependency-injection contract: optional error_logger Callable lets tests
# capture push_error-class messages deterministically. Production callers omit it; the
# default invalid Callable falls through to `push_error(msg)`. Stateless — never stored.

func emit_events_in_range(
    formation: Array[HeroInstance],
    floor: Floor,
    range_start_tick: int,             # exclusive
    range_end_tick: int,               # inclusive
    error_logger: Callable = Callable()
) -> CombatTickEvents: ...

func compute_offline_batch(
    formation: Array[HeroInstance],
    floor: Floor,
    tick_budget: int,
    error_logger: Callable = Callable()
) -> CombatBatchResult: ...
```

**`DefaultCombatResolver`** — the concrete production implementation. Extends `CombatResolver`, provides the real `emit_events_in_range` and `compute_offline_batch` logic. Created once at game boot **lazily inside `DungeonRunOrchestrator._ready()`** via `DefaultCombatResolver.new()` (zero-arg; non-autoload RefCounted — autoload.md Claim 4 [VERIFIED] exempts non-autoload `.new()` from the autoload system's zero-arg constraint) IF the Orchestrator's `_combat_resolver` field is still null at `_ready()` time (i.e., no test pre-injected a spy via `set_combat_resolver`). No consumer ever calls `CombatResolver.new()` directly in production — always `DefaultCombatResolver.new()`. The prior phrasing `DungeonRunOrchestrator._init(combat_resolver)` was corrected Pass-INIT-PROBE-SYNC 2026-04-22 per the already-locked `dungeon-run-orchestrator.md` §J.1 Option A pattern; see ADR-0009 + ADR-0003 Amendment #3.

**`KillEvent`** — one enemy defeated at a known tick. Immutable value type. Plain `var` (not `@export var`) — these are transient per-call objects, never serialized as resources, never inspected in the editor; `@export` would add reflection overhead and falsely signal save-worthy intent.

```gdscript
class_name KillEvent extends RefCounted

var enemy_id:  StringName   # matches Enemy DB id
var archetype: StringName   # bruiser | caster | armored | beast | elemental
var tier:      int          # 1-3
var is_boss:   bool
var kill_tick: int          # absolute tick (foreground) or loop-relative (schedule)

func equals(other: KillEvent) -> bool:
    return (other != null
        and enemy_id  == other.enemy_id
        and archetype == other.archetype
        and tier      == other.tier
        and is_boss   == other.is_boss
        and kill_tick == other.kill_tick)
```

**`CombatTickEvents`** — foreground per-tick-range output from `emit_events_in_range`. Per-event list (UI needs individual `enemy_killed` pops), plus loop-boundary markers for the Orchestrator.

```gdscript
class_name CombatTickEvents extends RefCounted

var kills:                 Array[KillEvent]  # per-event, in kill_tick order
var loop_completed_ticks:  Array[int]        # ticks at which a loop ended within this range
var first_clear_in_range:  bool              # true iff loop_counter crossed 0→1 inside (range_start, range_end]

func equals(other: CombatTickEvents) -> bool:
    if other == null: return false
    if kills.size() != other.kills.size(): return false
    for i in kills.size():
        if not kills[i].equals(other.kills[i]): return false
    # Typed Array[int] != is element-wise in Godot 4.6 (not identity).
    if loop_completed_ticks != other.loop_completed_ticks: return false
    return first_clear_in_range == other.first_clear_in_range
```

**`CombatBatchResult`** — offline-batch output from `compute_offline_batch`. Aggregate counts only (not per-event — see E.5) because offline batches can produce 15 k+ kills in a single call and per-event enumeration would bloat the call-chain without benefit.

```gdscript
class_name CombatBatchResult extends RefCounted

# Typed dictionaries (Godot 4.4+) — engine type-checks at assignment.
var kills_by_archetype: Dictionary[StringName, int]   # archetype -> kill count
var kills_by_tier:      Dictionary[int, int]          # tier (1-3) -> kill count
var loops_completed:    int
var first_clear_tick:   int          # -1 if no loop completed
var hp_bonus_factor:    float        # D.6 Pillar 2 continuous throughput factor, [0.0, 1.0]
var survived:           bool         # D.6 derived: hp_bonus_factor >= 0.5 (Pass 2B)
var final_tick:         int          # always == tick_budget on success

# Static helper — key-by-key walk. Used for ALL dictionary equality checks.
# PUBLIC name (no leading underscore) because AC-COMBAT-01 and AC-COMBAT-10 call
# it from test code as the determinism gate; underscore prefix would falsely
# signal "private — do not use externally" and contradict the AC contract.
# Hash-based equality is unsound (hash collisions are real and would silently
# pass determinism tests on non-deterministic results — Pillar 1 regression).
# The walk is trivial for the small dicts here (≤5 keys each).
static func dict_equals(a: Dictionary, b: Dictionary) -> bool:
    if a.size() != b.size(): return false
    for key in a:
        if not b.has(key): return false
        if a[key] != b[key]: return false
    return true

func equals(other: CombatBatchResult) -> bool:
    if other == null: return false
    # hp_bonus_factor is a float — use is_equal_approx (Pass 2B)
    if not is_equal_approx(hp_bonus_factor, other.hp_bonus_factor): return false
    return (dict_equals(kills_by_archetype, other.kills_by_archetype)
        and dict_equals(kills_by_tier,      other.kills_by_tier)
        and loops_completed  == other.loops_completed
        and first_clear_tick == other.first_clear_tick
        and survived         == other.survived
        and final_tick       == other.final_tick)
```

Dictionary comparison uses an explicit key-by-key walk. **Do NOT use `Dictionary.hash()` for correctness comparisons** — `hash()` returns a 32-bit int and collisions are possible even for flat primitive dictionaries. A test-correctness tool (`equals()` is consumed by AC-COMBAT-01 and AC-COMBAT-10 to assert determinism) requires injectivity, not just determinism: two distinct dictionaries must NEVER compare equal. The key-walk is trivially cheap at the scale here (≤5 archetype keys, 3 tier keys).

**`CombatRunSnapshot`** — cached dispatch-time values owned by the Orchestrator (not Combat). Surfaced here because Combat is responsible for producing it once during `DISPATCHING`:

```gdscript
class_name CombatRunSnapshot extends RefCounted

var formation_dps_per_tick: float             # raw (Rule 4)
var hp_bonus_factor:        float             # Pillar 2 continuous, D.6 (Pass 2B)
var ticks_per_loop:         int
var survived:               bool              # derived: hp_bonus_factor >= 0.5
var kill_schedule:          Array[KillEvent]  # loop-relative ticks

func equals(other: CombatRunSnapshot) -> bool:
    if other == null: return false
    # Float fields use is_equal_approx, NOT == (IEEE 754 precision).
    # Default tolerance CMP_EPSILON (1e-5) is appropriate for DPS values
    # bounded in [0.0, 2.31] and hp_bonus_factor ∈ [0.0, 1.0].
    if not is_equal_approx(formation_dps_per_tick, other.formation_dps_per_tick):
        return false
    if not is_equal_approx(hp_bonus_factor, other.hp_bonus_factor):
        return false
    if ticks_per_loop != other.ticks_per_loop: return false
    if survived != other.survived: return false
    if kill_schedule.size() != other.kill_schedule.size(): return false
    for i in kill_schedule.size():
        if not kill_schedule[i].equals(other.kill_schedule[i]): return false
    return true
```

**Contract summary**:

- `CombatResolver` is `class_name CombatResolver extends RefCounted` (Pass 3D) — injectable instance class with instance methods. The Orchestrator holds one injected `combat_resolver: CombatResolver` field; tests inject a spy subclass. Production wiring creates `DefaultCombatResolver.new()` at game boot. The prior `@abstract class_name CombatResolver extends Object` (static-only, Pass 3 shape) is superseded; static dispatch is no longer used. **Rationale**: GdUnit4 cannot mock static methods on `@abstract` classes — AC-ORC-03 and AC-ORC-05 require injection to be writeable.
- `DefaultCombatResolver` extends `CombatResolver` and implements the real logic. Only ever instantiated once in production.
- `CombatResolver` instances are **stateless** — they accumulate no per-run state between calls. The instance is a dependency, not a state container (Combat Rule 1 preserved).
- Every Combat return value type (`KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot`) `extends RefCounted` → automatic lifecycle, no manual `free()`.
- Every value type uses plain `var` (not `@export var`) — these objects are transient per-call, never serialized as resources.
- Every return type exposes an `equals(other) -> bool` deep-equality method → AC-COMBAT-01 / AC-COMBAT-10 test the contract directly.
- Dictionary equality uses an explicit key-by-key walk (`dict_equals` static helper on `CombatBatchResult`). **Hash-based equality is forbidden** for correctness comparisons.
- Float fields use `is_equal_approx`, never `==`.
- Typed dictionaries (`Dictionary[StringName, int]`, `Dictionary[int, int]`) — Godot 4.4+ syntax; engine type-checks at assignment.
- The `==` operator on these objects tests identity, **not** field equality; tests MUST call `a.equals(b)`.

---

## D. Formulas

All formulas use **integer-valued outputs** even where intermediate values are float. In GDScript 4.6, use the integer-returning variants:

- `floori(x)` — floor, returns `int` (NOT `floor()`, which returns `float`)
- `ceili(x)`  — ceiling, returns `int` (NOT `ceil()`, which returns `float`)
- `maxi(a, b)` / `mini(a, b)` — integer max/min (NOT `max()`/`min()`, which return floats when given mixed args)

Persisted and emitted values are always `int`. Float intermediates are permitted (`formation_dps_per_tick` is deliberately `float`) but any value that reaches a `tick` counter, a `kills_by_*` count, or any `@export var ... : int` field MUST go through `floori`/`ceili` first. Determinism is by construction — no RNG, no time-dependent reads, no float accumulation across calls.

Where older notation `floor()` / `ceil()` / `max()` appears in this document, treat it as a synonym for the integer variant above; the implementation MUST use the `*i` form.

---

### D.1 Action Cooldown

The `action_cooldown_ticks` formula is defined as:

```
action_cooldown_ticks(combatant):
    if combatant.speed <= 0:
        return 1          # pre-guard — division-by-zero / negative speed defensively clamped
    return maxi(1, floori(SPEED_BASE / combatant.speed))
```

The pre-guard **must** be evaluated before the division; otherwise `speed = 0` would raise at the `floori(SPEED_BASE / 0)` step (GDScript integer division traps on zero divisor). The `maxi(1, ...)` clamp also catches the case where `combatant.speed > SPEED_BASE` (floored division returns `0`).

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| combatant speed | `combatant.speed` | int | 1 – 100 | `hero.speed` (computed via `stat_at_level`) or `enemy.base_speed` |
| tuning constant | `SPEED_BASE` | int | 800 – 6000 | Single tuning knob (Section G); default `2400` |
| output | `action_cooldown_ticks` | int | 1 – 6000 | Ticks between this combatant's actions |

**Output Range:** 1 (combatant with `speed ≤ 0` via pre-guard, or `speed > SPEED_BASE` via `maxi` clamp) to `SPEED_BASE` (combatant with speed = 1). Lower bound clamped to 1 to prevent zero-cooldown infinite-action exploits.

**Note:** This formula is **not directly invoked** in the closed-form throughput path (D.2). It is the *conceptual* cooldown that the closed-form approximation collapses into a rate; surfacing it here makes the speed semantics legible to anyone reading the code or the GDD.

**Worked example — Rogue at L15, SPEED_BASE = 2400:**
```
rogue.speed at L15 = 16 + 2 × (15 - 1) = 44
action_cooldown_ticks = maxi(1, floori(2400 / 44)) = maxi(1, 54) = 54 ticks (= 2.7 seconds)
```

---

### D.2 Formation DPS Per Tick (Closed-Form Throughput) — CANONICAL

The `formation_dps_per_tick` formula is defined as:

`formation_dps_per_tick(formation) = sum(hero.attack × hero.speed for hero in formation) / SPEED_BASE`

This formula is the heart of Combat Resolution. Every kill cadence, loop time, and offline batch result derives from it.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| hero attack at level | `hero.attack` | int | 12 – 62 | `stat_at_level("attack", hero.class_data, hero.current_level)` |
| hero speed at level | `hero.speed` | int | 6 – 44 | `stat_at_level("speed", hero.class_data, hero.current_level)` |
| formation size | `len(formation)` | int | 0 – 3 | `FORMATION_SIZE = 3` (active slots, skips empty) |
| tuning constant | `SPEED_BASE` | int | 800 – 6000 | Default `2400` |
| output | `formation_dps_per_tick` | float | 0.0 – 2.31 | Damage applied to front-of-queue enemy per 50ms tick |

**Output Range:** `0.0` (empty formation — guard returns 0; no run dispatched) to `2.31` (theoretical MVP max = 3× Rogue L15 formation: `3 × (42 × 44) / 2400 = 5544/2400 = 2.31`). Practical MVP band: `0.207` (L1 W+M+R = 496/2400) through `1.417` (L13 W+M+R = 3400/2400) up to `1.723` (L15 W+M+R = 4136/2400). Single-class edge reference: 3× Warrior L15 = `(3×40×20)/2400 = 1.0`; 3× Mage L15 = `(3×62×24)/2400 = 1.86`.

**Empty-formation guard**: if `len(formation) == 0`, returns `0.0` directly (no run can be dispatched; Orchestrator is responsible for not dispatching empty formations, but Combat must not divide-by-zero or produce negative outputs).

**Worked example — L1 Warrior + Mage + Rogue, SPEED_BASE = 2400:**
```
Warrior:  ATK 12, SPD 6   →  12 × 6  = 72
Mage:     ATK 20, SPD 10  →  20 × 10 = 200
Rogue:    ATK 14, SPD 16  →  14 × 16 = 224
sum = 496
formation_dps_per_tick = 496 / 2400 = 0.207
formation_dps_per_second = 0.207 × 20 = 4.13 dmg/sec
```

**Worked example — L13 Warrior + Mage + Rogue, SPEED_BASE = 2400:**
```
Warrior L13:  ATK 36, SPD 18  →  648
Mage L13:     ATK 56, SPD 22  →  1232
Rogue L13:    ATK 38, SPD 40  →  1520
sum = 3400
formation_dps_per_tick = 3400 / 2400 = 1.417
formation_dps_per_second = 1.417 × 20 = 28.3 dmg/sec
```

---

### D.3 Enemy DPS Pool (Informational — for Survivability Check Cross-Reference)

`enemy_dps_per_tick(floor) = sum(enemy.base_attack × enemy.base_speed × count for enemy in floor.enemy_list) / SPEED_BASE`

Same shape as D.2 but for enemy side. Used to populate Foreground UI's "incoming pressure" indicator (Dungeon Run View #24's responsibility) and to validate the soft-survivability check (D.6) against expected enemy throughput. Not consumed by gold attribution; not persisted.

---

### D.4 Loop Cadence (Ticks Per Floor-Clear)

`floor_total_hp(floor) = sum(enemy.base_hp × count for enemy in floor.enemy_list)`   ← informational (registry, pacing table D.7)

`ticks_per_loop(formation, floor) = _kill_schedule_for_loop(formation, floor).back().kill_tick`   ← derived (per-enemy Pillar 3 routing breaks single-division simplification)

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| floor total HP | int | 216 – 4818 | Sum across MVP floors. F1=216, F2=308, F3=985, F4=2040, F5=**4818** (Pass 2B: ancient_rootking HP 2200 → 4818 to hit the 170 s clear-time target under SPEED_BASE=2400, L13 W+M+R raw DPS 1.417, neutral matchup — `ceili(170 × 20 × 1.417) = 4818`). Informational only since Pass 2B — `ticks_per_loop` is now derived from the kill schedule, not computed directly from this aggregate. |
| formation throughput | float | > 0.0 | From D.2. Empty-formation guard ensures > 0 before this call. |
| matchup_throughput_factor (per enemy) | float | 1.0 or 1.5 | `MATCHUP_THROUGHPUT_FACTOR_DIS` (1.0) baseline, `MATCHUP_THROUGHPUT_FACTOR_ADV` (1.5) when formation crosses majority threshold for that enemy's archetype. Applied per-enemy inside D.5, not aggregated to a single floor value. |
| hp_bonus_factor (floor-level) | float | [0.0, 1.0] | `mini(formation_total_hp / floor_total_enemy_attack, 1.0)` per Rule 9 / D.6. Constant across all enemies in a single floor (one call per dispatch). Applied alongside matchup factor in D.5 `effective_dps`. |
| output | int | ≥ 1 | `kill_tick` of the schedule's last entry (Rule 8, D.5). `ceili(...)` inside D.5 guarantees each per-enemy `ticks_to_kill` is `int`, and the accumulator `kill_tick` stays `int`. |

**Output Range:** Lower bound: theoretical 3× Rogue L15 on F1 with full matchup advantage on every enemy — raw dps `2.31`, effective against bruiser enemies `2.31 × 1.5 = 3.465`, against caster enemies neutral (3× Rogue counters armored, not caster) = `2.31`. Computed: `3 × ceili(52/3.465) + ceili(60/2.31) = 3×16 + 27 = 75 ticks (~3.75 s)`. Upper bound (neutral matchup across the floor, Pass 2B F5 HP 4818): `ceili(4818 / 0.207) ≈ 23276 ticks (~1164 s ≈ 19.4 min)` for L1 formation on F5 — a player wouldn't dispatch this (Floor Unlock System #16 prevents it), but the formula must remain bounded. Pillar 3 compresses the lower end; the upper end is unchanged in shape because disadvantaged is baseline (1.0×), not punished — the absolute ceiling doubled because F5 boss HP doubled (2200 → 4818) in Pass 2B to make the boss a 170 s fight at the target formation.

---

### D.5 Per-Loop Kill Schedule

`_kill_schedule_for_loop(formation, floor) -> Array[KillEvent]`

Computed once per dispatch (cached on run snapshot). Pseudocode (per Rule 10 — both Pillar 2 `hp_factor` AND Pillar 3 `mu_factor` MUST appear in `effective_dps`):

```
schedule  = []
dps       = formation_dps_per_tick(formation)            # raw throughput (Rule 4)
hp_factor = hp_bonus_factor(formation, floor)            # Pillar 2 (Rule 9 / D.6) — floor-level constant
kill_tick = 0
for entry in floor.enemy_list:
    enemy      = DataRegistry.resolve("enemies", entry.enemy_id)
    advantaged = MatchupResolver.resolve_formation_matchup(
                     formation, enemy.archetype).is_advantaged
    mu_factor  = MATCHUP_THROUGHPUT_FACTOR_ADV if advantaged else MATCHUP_THROUGHPUT_FACTOR_DIS
    effective_dps = dps * mu_factor * hp_factor          # Pillar 3 × Pillar 2 — both factors required
    for _ in range(entry.count):
        ticks_to_kill = ceili(enemy.base_hp / effective_dps)  # per-enemy, int-return
        kill_tick    += ticks_to_kill
        schedule.append({
            enemy_id:  enemy.id,
            archetype: enemy.archetype,
            tier:      enemy.tier,
            is_boss:   enemy.is_boss,
            kill_tick: kill_tick,
        })
return schedule
```

The schedule's last entry's `kill_tick` equals `ticks_per_loop` (D.4) — the floor-clear marker. `MatchupResolver.resolve_formation_matchup` is called once per `enemy_list` entry, not once per enemy copy — the majority threshold depends only on the formation and archetype (Rule 6), so inner-loop copies reuse the same `mu_factor`. `hp_factor` is computed once per dispatch (floor-level) and reused across every enemy. **Worked examples below collapse `hp_factor = 1.0` because every naturally-constructable MVP formation saturates the cap (D.6); the worked-example arithmetic is the special case where `effective_dps = dps × mu_factor × 1.0 = dps × mu_factor`, NOT a license to drop `hp_factor` from the reference implementation.**

**Worked example — L4 W+M+R on F1 (3× hollow_brute @ 52 HP bruiser, 1× glowmoth @ 60 HP caster per Biome DB GDD #7 C.2)**:

`dps = (18×9 + 29×13 + 20×22) / 2400 = 979/2400 = 0.408`

Matchup lookup: L4 W+M+R against bruiser → `n=1` (Warrior only), `1 > 3/2` is **false** → `is_advantaged = false` → `factor = 1.0`. Against caster → `n=1` (Mage only) → `factor = 1.0`. All effective_dps = `0.408`. Kill-tick walk:

| Index | Enemy | archetype | factor | effective_dps | ticks_to_kill | kill_tick |
|---|---|---|---|---|---|---|
| 0 | hollow_brute | bruiser | 1.0 | 0.408 | `ceili(52/0.408) = 128` | 128 |
| 1 | hollow_brute | bruiser | 1.0 | 0.408 | 128 | 256 |
| 2 | hollow_brute | bruiser | 1.0 | 0.408 | 128 | 384 |
| 3 | glowmoth    | caster  | 1.0 | 0.408 | `ceili(60/0.408) = 148` | 532 |

Floor cleared at tick 532 (~26.6 s). Note: per-enemy ceiling sums to 532 vs the Pass 2A single-cumulative-HP ceiling of 530 — a 2-tick (100 ms) rounding drift that is the honest cost of per-enemy integer arithmetic under neutral matchup. The per-enemy path is canonical under Pass 2B because it's the only formulation that stays correct when matchup factor varies within a loop.

**Worked example — L4 W+W+R (specialist against bruiser) on F1**:

Warrior L4 `ATK 18 SPD 9`, Rogue L4 `ATK 20 SPD 22`. `dps = (18×9 + 18×9 + 20×22) / 2400 = (162+162+440)/2400 = 764/2400 = 0.3183`.

Matchup against bruiser → `n=2` (both Warriors), `2 > 3/2` is **true** → `is_advantaged = true` → `factor = 1.5` → effective_dps against bruisers = `0.4775`. Against caster → `n=0` (neither W nor R counters caster) → `factor = 1.0` → effective_dps = `0.3183`.

| Index | Enemy | archetype | factor | effective_dps | ticks_to_kill | kill_tick |
|---|---|---|---|---|---|---|
| 0 | hollow_brute | bruiser | 1.5 | 0.4775 | `ceili(52/0.4775) = 109` | 109 |
| 1 | hollow_brute | bruiser | 1.5 | 0.4775 | 109 | 218 |
| 2 | hollow_brute | bruiser | 1.5 | 0.4775 | 109 | 327 |
| 3 | glowmoth    | caster  | 1.0 | 0.3183 | `ceili(60/0.3183) = 189` | 516 |

W+W+R clears F1 in 516 ticks (~25.8 s) vs W+M+R's 532 ticks (~26.6 s) — specialist is slightly faster despite lower raw DPS because the 3 bruisers resolve at 1.5× throughput. **This is Pillar 3's mechanical payoff**: the glowmoth's 189 ticks dominates the total because it's the only unmatched kill, which correctly hints at the Rogue-vs-caster tradeoff the player is making when they stack for bruiser coverage.

---

### D.6 HP-Efficiency (Continuous — Pass 2B)

`formation_total_hp(formation) = sum(stat_at_level("hp", hero.class_data, hero.current_level) for hero in formation)`

`floor_total_enemy_attack(floor) = sum(enemy.base_attack × count for enemy in floor.enemy_list)`

`hp_bonus_factor(formation, floor) = mini(formation_total_hp / floor_total_enemy_attack, 1.0)`    ← continuous [0, 1]

`survived(formation, floor) = (hp_bonus_factor >= 0.5)`    ← derived; `losing_run = !survived`

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| formation HP | int | 55 – 1074 | Bounds from Class DB `stat_at_level("hp", ...)` across practical formations. Solo L1 Rogue = 55 (theoretical min, single-hero formation). L1 W+M+R = 120+70+55 = **245**. L13 W+M+R = 324+190+151 = **665**. L15 W+M+R (max practical mixed formation) = 358+210+167 = **735**. 3× Warrior L15 = `3 × 358` = **1074** (theoretical max). |
| floor enemy attack | int | 35 – 96 | F1=35, F2=53, F3=86, F4=96, F5=45. (Note F5 is one boss; lower than F4 elite cluster.) |
| `hp_bonus_factor` (output A) | float | [0.0, 1.0] | Throughput multiplier applied inside `_kill_schedule_for_loop` (Rule 10 / D.5) alongside `matchup_throughput_factor`. Capped at 1.0 via `mini`. |
| `survived` (output B, derived) | bool | true / false | `hp_bonus_factor >= 0.5`. Consumed by Orchestrator to gate `LOSING_RUN_LOOT_FACTOR`. |

**Output Range:** `hp_bonus_factor ∈ [0.0, 1.0]`; `survived ∈ {true, false}`.

**Worked example — L1 W+M+R formation (HP 245) on Floor 3 (enemy_attack 86)**:
```
hp_bonus_factor = mini(245 / 86, 1.0) = mini(2.849, 1.0) = 1.0
survived = (1.0 >= 0.5) = TRUE → no LOSING_RUN multiplier
Effective throughput penalty from Pillar 2: NONE (factor 1.0 = no tempo change)
```

Even an L1 formation comfortably saturates `hp_bonus_factor` at 1.0 on Floor 3 — the coupling is intentionally lenient in MVP (formation_total_hp vastly exceeds floor enemy attack). **The continuous multiplier is `1.0` for every naturally-constructable MVP formation across F1–F5** — Pillar 2 is **structurally encoded but mechanically invisible at MVP**. The header pillar disclaimer (Section A) and Pass 3C decision lock this as intentional: Pillar 2's payoff lives in V1.0 hard content + Cleric synergy. AC-06 verifies the formula's correctness at the boundary using a synthetic fixture; MVP gameplay never hits the band.

**Worked example — solo L1 Mage (HP 70) on Floor 4 (enemy_attack 96)**:
```
hp_bonus_factor = mini(70 / 96, 1.0) = mini(0.729, 1.0) = 0.729
survived = (0.729 >= 0.5) = TRUE → no LOSING_RUN multiplier
Effective throughput: formation_dps_per_tick × matchup_factor × 0.729   — run clears ~37% slower
```

Under Pass 2A this fixture triggered `survived = false` and `LOSING_RUN_LOOT_FACTOR = 0.5` (halved loot). Under Pass 2B it instead shows up as a continuous ~27% tempo slowdown — the player feels the underlevelled state as "runs take noticeably longer" rather than "I got punished with half gold." Pillar 1 posture strengthened.

**Worked example — synthetic extreme: solo L1 Rogue (HP 55) on a hypothetical high-attack floor (enemy_attack 120)**:
```
hp_bonus_factor = mini(55 / 120, 1.0) = 0.458
survived = (0.458 >= 0.5) = FALSE → LOSING_RUN_LOOT_FACTOR (0.5) applies to all gold
Effective throughput: raw × matchup_factor × 0.458 — very slow clears
```

This scenario is not reachable on MVP floors (max enemy_attack = 96 on F4; solo L1 Rogue on F4 = 0.573, above threshold). The LOSING_RUN path is retained as a safety net for V1.0 hard-mode content and as a defence against floor-authoring bugs (e.g., a future floor author pushes enemy_attack past what existing formations can handle). **Pass 2A's SURVIVAL_MARGIN = 0.2 is deprecated** (see G.1 + entities.yaml); the 0.5 threshold on `hp_bonus_factor` is the new single-knob trigger.

---

### D.7 Pacing Validation Table (Replaces Economy D.6 Placeholder + Resolves Biome F3/F4 Tension)

Computed at `SPEED_BASE = 2400` under **neutral matchup** (`matchup_throughput_factor = 1.0` for every enemy) using the **cumulative-HP approximation** `ticks_per_loop ≈ ceili(floor_total_hp / formation_dps_per_tick)`. This approximation is informational — canonical per-enemy values diverge by 0-5 ticks (<1%, economically trivial). Reason to keep the cumulative form in this table: SPEED_BASE calibration readability. The exact per-enemy values per AC-04/AC-05/AC-08 are the test-authoritative reference.

All rows derived from `stat_at_level` (Class DB D.1) with `per_level` values: Warrior `ATK+2 HP+17 SPD+1`; Mage `ATK+3 HP+10 SPD+1`; Rogue `ATK+2 HP+8 SPD+2`. Time = `ticks_per_loop / 20` (20 Hz). Each `sum(atk×spd)` column is the exact integer weighted sum at that level; DPS/tick = sum/2400.

| Floor | Total HP | Realistic formation | `sum(atk×spd)` | DPS/tick | DPS/s | `ticks_per_loop` | Computed clear time | Biome target | Delta |
|---|---|---|---|---|---|---|---|---|---|
| F1 | 216 | L2 W+M+R: `(14×7)+(23×11)+(16×18)` | 639 | 0.266 | 5.33 | `ceili(216/0.266)=812` | **40.6 s** | 40 s | ✓ +1.5% |
| F2 | 308 | L3 W+M+R: `(16×8)+(26×12)+(18×20)` | 800 | 0.333 | 6.67 | `ceili(308/0.333)=924` | **46.2 s** | 55 s | ✓ −16.0% |
| F3 | 985 | L6 W+M+R: `(22×11)+(35×15)+(24×26)` | 1391 | 0.580 | 11.59 | `ceili(985/0.580)=1700` | **85.0 s** | 85 s | ✓ +0.0% (Pass 2B Biome target revised 60 → 85 s; I.Q1 CLOSED) |
| F4 | 2040 | L11 W+M+R: `(32×16)+(50×20)+(34×36)` | 2736 | 1.140 | 22.80 | `ceili(2040/1.140)=1790` | **89.5 s** | 90 s | ✓ −0.6% |
| F5 | **4818** (Pass 2B) | L13 W+M+R: `(36×18)+(56×22)+(38×40)` | 3400 | 1.417 | 28.33 | `ceili(4818/1.417)=3401` | **170.05 s** | 170 s | ✓ +0.03% (Pass 2B locked 4818 via `ceili(170×20×1.417) = 4818`) |

**Calibration items resolved in Pass 2B** (originally Section I open questions):
1. **F3 expected_clear_time** — RESOLVED: Biome DB F3 target revised 60 s → **85 s** (Pass 2B chunk 5). Matches computed cumulative-HP model at SPEED_BASE=2400.
2. **F5 Ancient Rootking HP** — RESOLVED: `ancient_rootking.base_hp` 2200 → **4818** (Pass 2B chunk 3). Precise: `ceili(170 × 20 × 1.417) = ceili(4817.8) = 4818`. F5 now clears at 170.05 s under L13 W+M+R neutral matchup, within the 170 s target. Cascade: Enemy DB `ancient_rootking.base_hp` updated, Biome DB F5 HP registry check updated, entities.yaml PROVISIONAL annotation removed, entities.yaml `floor_total_hp` upper bound recomputed 2200 → 4818.

The **kill-frequency assumption** in Economy D.6 ("1 kill per 10 sec active") is replaced by the per-floor numbers above. At F3 (target floor for Tier-2 milestone), the average kill cadence under the L6 formation is `85.0 s / 5 enemies = 17.0 s/kill`, slower than the placeholder. Economy's pacing model needs re-validation against this — flagged in Section I as a cascade item.

## E. Edge Cases

Format: each edge case names the exact condition and the exact resolution. Vague entries (e.g. "handle gracefully") are forbidden.

### E.1 Empty Formation Passed to `compute_offline_batch` or `emit_events_in_range`

**Scenario**: Orchestrator (in error) or a unit test calls Combat with `len(formation) == 0`.

**Behavior**: `compute_offline_batch` returns an empty `CombatBatchResult` immediately: `{kills_by_archetype={}, kills_by_tier={}, loops_completed=0, first_clear_tick=-1, hp_bonus_factor=0.0, survived=false, final_tick=tick_budget}` with no exceptions. `emit_events_in_range` returns an empty `CombatTickEvents`. The empty-formation guard in D.2 (`formation_dps_per_tick → 0.0`) prevents division-by-zero in D.4. Logs `push_warning("CombatResolver called with empty formation; returning empty result")` — one log per call (Combat is stateless and cannot dedup across calls; the Orchestrator is responsible for not dispatching empty formations in the first place, so repeated calls here indicate an upstream bug worth seeing in the log). Per Pillar 1, the player is never penalized for this — but this scenario is also not reachable from normal play (Orchestrator does not dispatch empty formations).

### E.2 HeroInstance Has `class_id` That Does Not Resolve

**Scenario**: A formation contains a `HeroInstance` with `class_id = "necromancer"` (not in the registry — corrupt save survived Roster boot validation, or a unit test).

**Behavior**: At dispatch, `DataRegistry.resolve("classes", "necromancer")` returns `null`. Combat skips this hero in the formation aggregation: it contributes `0` to `formation_dps_per_tick` and `0` to `formation_total_hp`. The run continues with the remaining heroes (1 or 2 valid heroes carry the formation). Logs `push_error("CombatResolver: hero instance_id=X has unresolvable class_id='necromancer'; skipping")` — one log per unresolvable hero per call (stateless resolver cannot dedup across dispatches; see Rule 1). The Orchestrator or a higher layer may rate-limit if log volume becomes an issue. If all 3 formation heroes have unresolvable classes, `formation_dps_per_tick = 0`, which falls into E.1 — empty-formation guard triggers, run returns empty result.

### E.3 Floor `enemy_list` Is Empty

**Scenario**: A floor with `enemy_list = []` reaches Combat (would normally be rejected at Biome DB load per Biome E.5, but defensive depth).

**Behavior**: `floor_total_hp = 0`, `floor_total_enemy_attack = 0`. `hp_bonus_factor` uses a floor-attack-zero pre-guard returning `0.0` directly (no divide-by-zero via the `mini()` formulation). `ticks_per_loop = 0`. The kill schedule is empty. Combat returns `{kills=[], loops_completed=0, first_clear_tick=-1, hp_bonus_factor=0.0, survived=false, final_tick=tick_budget}` — `survived=false` is the Pass 2B contract (`0.0 < 0.5`). No loot accrues because no kills fire regardless of `survived`. The Orchestrator must NOT award `FLOOR_CLEAR_BONUS` for an empty floor (would be free gold via authoring bug exploit). Logs `push_error("CombatResolver: floor [floor.id] has empty enemy_list; aborting run")`.

### E.4 Floor with One Enemy Whose HP < `formation_dps_per_tick` (Sub-Tick Kill)

**Scenario**: An L13 W+M+R formation (DPS 1.42/tick) faces a floor with one Hollow Brute (52 HP). `kill_tick = ceili(52 / 1.42) = 37` ticks. But what if a future event-only enemy has 1 HP? `kill_tick = ceili(1 / 1.42) = 1` (the integer ceiling guarantees ≥1 tick).

**Behavior**: `ceili()` ensures `kill_tick >= 1` always. No "instantaneous kill at tick 0" can fire — every kill consumes at least one tick of game time. This preserves the "tempo" feel and prevents 576,000 kills firing in tick 0 for a hypothetical 1-HP enemy floor.

### E.5 Continuous Loop During Long Offline Replay (Hundreds of Loops)

**Scenario**: An L13 formation dispatched on F1 (DPS 1.417, ticks_per_loop = `ceili(216/1.417) = 153`) runs for the full 8h offline cap (576,000 ticks). That's `floori(576000 / 153) = 3764` complete loops.

**Behavior**: `compute_offline_batch` returns: `loops_completed = 3764`, `first_clear_tick = 153` (the first time the loop counter went from 0 → 1), `kills = [...]` enumerated as `loops_completed × kills_per_loop = 3764 × 4 = 15,056 kill events`. **The kill array does NOT enumerate every event individually** — the offline replay returns aggregate counts: `kills_by_archetype = {bruiser: 11292, caster: 3764}`, `kills_by_tier = {1: 15056}`. Per-event enumeration would be a 15k-entry array passed up the call chain unnecessarily; aggregate counts are sufficient for Economy's gold attribution and Return-to-App's display. Foreground `emit_events_in_range` does enumerate per-event because the UI/Orchestrator wants individual `enemy_killed` signal fires for the kill-pop animation.

### E.6 Player Reassigns Formation Mid-Foreground-Run

**Scenario**: Player has an active L8 formation on Floor 3, then opens Roster screen and swaps a Mage for a Rogue. The cached run snapshot is now stale.

**Behavior**: This is the **Orchestrator's responsibility**, not Combat's. Per C.2, Combat is stateless; the Orchestrator owns the run snapshot. When the player reassigns, the Orchestrator either: **(a)** ends the current run (RUN_ENDED), refreshes the snapshot, and re-enters DISPATCHING with the new formation (preferred — matches "respect the player's intent"); or **(b)** rejects the reassignment until the player explicitly recalls the formation. The Orchestrator GDD (#13) decides; Combat just consumes whatever snapshot is passed. **No mid-run formation mutation is supported by Combat** — passing different formation arrays in successive `emit_events_in_range` calls within the same dispatch produces undefined behavior (the kill schedule would shift mid-loop). This is a pre-condition contract on the caller.

### E.7 Foreground Tick Skipped (Frame Drop / Pause)

**Scenario**: `tick_fired` fires for tick 100, then again for tick 105 (5-tick gap because frames dropped or `_process` was suspended).

**Behavior**: Orchestrator calls `emit_events_in_range(formation, floor, 100, 105)`. Combat returns all kill events whose `kill_tick` falls in `(100, 105]` — possibly zero, one, or several events depending on dps. **Foreground correctly recovers** because the closed-form schedule is time-anchored, not tick-incremented. No state is lost. This is the same property that lets foreground and offline produce identical event sequences (Rule 2 invariant).

### E.8 LOSING_RUN Threshold at Exactly the hp_bonus_factor = 0.5 Boundary

**Scenario**: `formation_total_hp / floor_total_enemy_attack == 0.5` exactly (e.g., `formation_total_hp = 60`, `floor_total_enemy_attack = 120` → `hp_bonus_factor = 0.5`).

**Behavior**: `survived = (hp_bonus_factor >= 0.5)` — `>=` is inclusive. The formation is NOT in `losing_run` at the exact boundary (factor is exactly 0.5 → survived=true → no LOSING_RUN multiplier). Rounding caveat: the comparison is `float >= 0.5`; if IEEE-754 drift produces `0.49999999999` from a ratio that analytically equals `0.5`, the boundary falls on the losing side. Combat's C.4 float-equality convention uses `is_equal_approx` elsewhere; for the LOSING trigger specifically, the raw `>=` is intentional (the economy-facing signal should treat near-zero-drift below-threshold as a LOSING trigger, not snap-up to survived). Designers should keep the 0.5 threshold away from natural MVP fixture ratios; Combat AC-06 asserts exact-boundary behavior with a fixture that produces `0.5` cleanly (`60/120`).

### E.9 `SPEED_BASE` Tuned to a Value That Makes a Floor Unclearable in 8h Cap

**Scenario**: Designer pushes `SPEED_BASE` to 6000 to slow combat. L1 W+M+R on F5 has DPS = 496/6000 = 0.0827 → `ticks_per_loop = ceili(4818 × 6000 / 496) = ceili(58282.26) = 58283 ticks (2914 s ≈ 48.6 min)` (Pass 2B HP=4818, integer reference path per D.5). Within 8h cap (576,000 ticks), `floori(576000/58283) = 9 complete loops`. No edge-case behavior — the loop simply runs slower. But if SPEED_BASE were absurd (say 1,000,000), one loop would exceed `tick_budget` and `loops_completed = 0`, `first_clear_tick = -1`. The schedule's incomplete kills are partial-loop events: Combat returns kills that fired within the budget, plus `final_tick = tick_budget`. The `survived` field is still set per D.6 (depends on HP, not on whether the loop completed). Player gets partial loot from the kills that did happen plus zero floor-clear bonus.

### E.10 Boss Floor — `is_boss=true` Enemy in Mid-of-Loop Position (Authoring Error)

**Scenario**: A future floor has `enemy_list = [{trash_mob, 5}, {ancient_rootking, 1}]` — boss is the last entry. Or worse, `[{boss, 1}, {trash_mob, 3}]` — boss is first.

**Behavior**: Combat's kill schedule processes enemies in `enemy_list` order. The `is_boss` flag is propagated per-event in the kill schedule; the Orchestrator triggers the boss-death fanfare when an `is_boss=true` event fires, regardless of position in the list. Combat does not enforce the "boss is last enemy" convention — that's the Biome DB's authoring guideline (Biome E.5) plus QA-catch (Biome H-05). Combat just reports facts.

### E.11 Empty Loop (`ticks_per_loop == 0` Due to Calibration Bug)

**Scenario**: A misconfigured floor (HP 0) or extreme `formation_dps_per_tick` makes `ticks_per_loop = 0`. Continuous loop with zero-tick loops would infinite-loop the foreground/offline schedule walker.

**Behavior**: `ceili(0 / dps) = 0`, but Combat asserts `ticks_per_loop >= 1` before entering the loop walker. If the assertion fails (HP = 0 path), returns an empty result and logs `push_error`. The integer ceiling on positive HP (≥1) and clamped DPS (≤ Float.MAX, > 0) means `ticks_per_loop` is always ≥ 1 in well-formed input. The assertion is a defensive belt-and-suspenders check.

### E.12 Class Synergy Hook Reaches Combat Before Combat Knows About It (V1.0+ Forward Compatibility)

**Scenario**: V1.0 Class Synergy System (#32) wants to apply a "Tactician boosts adjacent hero attack by 20%" buff. The buff must affect `formation_dps_per_tick` calculation.

**Behavior**: V1.0 will introduce a **synergy resolver** layer that produces a modified formation snapshot (heroes' effective stats inflated by synergy multipliers) before passing to Combat. Combat itself does NOT have synergy-awareness — it still treats `hero.attack` and `hero.speed` as opaque values. This isolation keeps Combat's MVP contract clean: synergy is a pre-step, not a Combat feature. **MVP Combat is forward-compatible** — no schema or method-signature changes required when synergy lands.

## F. Dependencies

### Upstream Dependencies (systems Combat reads from)

| Upstream | Hard/Soft | Interface | Locked contract |
|---|---|---|---|
| **Hero Roster** (`design/gdd/hero-roster.md`) | Hard (transitive — via Orchestrator) | `roster.get_formation_heroes() -> Array[HeroInstance]` returns the dispatch snapshot. Combat reads `hero.class_id`, `hero.current_level`, `hero.instance_id`. | Snapshot is frozen at dispatch by Orchestrator; Combat must NEVER call this method per-tick. |
| **Hero Class Database** (`design/gdd/hero-class-database.md`) | Hard | `DataRegistry.resolve("classes", id) -> HeroClass`; `stat_at_level("attack"/"hp"/"speed", class_data, level)` (Class DB D.1) | Resolved once per dispatch; cached on run snapshot. Resolves Class DB Open Question 4 (speed = cooldown divisor — see C.1 Rule 3). |
| **Enemy Database** (`design/gdd/enemy-database.md`) | Hard | `DataRegistry.resolve("enemies", id) -> EnemyData`; reads `base_hp`, `base_attack`, `base_speed`, `archetype`, `tier`, `is_boss` | Resolved once per dispatch from `floor.enemy_list`. Calibration assumption: `SPEED_BASE = 2400` hits Biome targets across F1–F5 within ±~5% (Pass 2B closed F3 60→85 s and F5 boss HP 2200→4818; Combat I.Q1 + I.Q2 CLOSED — see D.7 + I). |
| **Biome & Dungeon Database** (`design/gdd/biome-dungeon-database.md`) | Hard | `Floor` resource: `enemy_list`, `floor_index`, `is_boss_floor` | `enemy_list` is the substrate of the kill schedule (D.5). Determinism depends on this list never changing during a dispatch. Resolves Biome DB F3/F4 Open Question (D.7 recommendations). |
| **Game Time & Tick** (`design/gdd/game-time-and-tick.md`) | Hard (transitive — via Orchestrator) | `tick_fired(n)` is consumed by Orchestrator, which forwards a tick range to Combat's `emit_events_in_range`. Combat does NOT subscribe to the signal directly. | Combat is invoked synchronously within the Orchestrator's `_on_tick`; no `call_deferred`. |

### Downstream Dependents (systems that depend on Combat)

| Consumer | Hard/Soft | Interface | What they consume |
|---|---|---|---|
| **Dungeon Run Orchestrator** (#13, undesigned) | Hard | `combat_resolver.emit_events_in_range(formation, floor, range_start, range_end) -> CombatTickEvents` per foreground tick; `combat_resolver.compute_offline_batch(formation, floor, tick_budget) -> CombatBatchResult` per offline replay (Pass 3D: instance method calls; Orchestrator holds `_combat_resolver: CombatResolver` populated via lazy-default in `_ready()` OR pre-injected via `orchestrator.set_combat_resolver(spy)` BEFORE `_ready()` fires — per `dungeon-run-orchestrator.md` §J.1 Option A, codified at ADR level by ADR-0009; Pass-INIT-PROBE-SYNC 2026-04-22 correction) | Kill events, loop completions, first-clear marker, survivability flag, final tick. Orchestrator owns all signal emission to Economy (and translates kill events into `enemy_killed(tier, archetype)` signals). |
| **Offline Progression Engine** (#12, undesigned) | Hard (transitive — via Orchestrator) | `compute_offline_batch` chain | A single batch call per dispatched floor in the offline budget. Result feeds Economy's `compute_offline_batch` and the Return-to-App screen's events_log. |
| **Economy System** (`design/gdd/economy-system.md`) | Hard (read-through — Combat does not call Economy) | None direct | All Combat output flows through Orchestrator to Economy. Economy's D.6 placeholder ("1 kill / 10 sec") is **replaced** by Combat's per-floor calibration (D.7). |
| **Matchup Resolver** (`design/gdd/class-vs-enemy-matchup-resolver.md`) | Hard (MVP — Pass 2B) | `MatchupResolver.resolve_formation_matchup(formation_snapshot, enemy.archetype) -> MatchupResult` | Called once per distinct `enemy_list` entry inside `_kill_schedule_for_loop` (Rule 10 / D.5). Consumes `result.is_advantaged` to select `MATCHUP_THROUGHPUT_FACTOR_ADV` or `MATCHUP_THROUGHPUT_FACTOR_DIS`. Resolver C.3 + F.2 Combat rows updated in lockstep (was V1.0-reserved). Orchestrator still owns the per-kill `is_matchup_advantaged → gold` path independently. |
| **Dungeon Run View** (#24, undesigned) | Soft (transitive — via Orchestrator) | None direct | Receives `enemy_killed` and `floor_cleared_first_time` signals from Orchestrator (which Orchestrator translated from Combat's events). Used for kill-pop animation, boss-fanfare trigger, floor-clear UI moment. |

### Bidirectional Consistency

- `design/gdd/hero-roster.md` Dependencies section: ✅ declares "Combat Resolution (#11, undesigned) — Hard read-only — `roster.get_formation_heroes() -> Array[HeroInstance]`". This GDD locks the consumption pattern (snapshot at dispatch, no per-tick re-read).
- `design/gdd/hero-class-database.md` Dependencies section: ✅ declares "Combat Resolution (#11, undesigned) — Hard — Reads live stats via Hero Roster (not Class DB directly)". This GDD's actual usage: Combat resolves `HeroClass` directly via `DataRegistry` and computes stats via Class DB's `stat_at_level()` formula — both per Class DB's contract.
- `design/gdd/enemy-database.md` Dependencies section: ✅ declares "Combat Resolution (#11) — Hard — Reads live stats directly from `EnemyData` resource (enemies do not level)". Confirmed.
- `design/gdd/biome-dungeon-database.md` Dependencies section: ✅ does not list Combat directly (Combat reads Biome via the Orchestrator's run dispatch). The transitive contract is documented above.
- `design/gdd/economy-system.md` Open Questions: contains a placeholder pending Combat Resolution; this GDD's D.7 supersedes the placeholder. Section I lists this as a cascade item for next Economy revision.
- `design/gdd/class-vs-enemy-matchup-resolver.md` C.3 **previously** marked Combat as V1.0-reserved; Pass 2B promoted Combat to MVP consumer (per-enemy call inside `_kill_schedule_for_loop`). Resolver C.3 + F.2 Combat rows updated to "Hard (MVP — Pass 2B)". Bidirectional consistency preserved.
- `design/gdd/game-time-and-tick.md` Dependencies section: lists "Dungeon Run Orchestrator (Hard, `tick_fired` foreground only)" but does not list Combat directly because Combat is transitively wired through Orchestrator. Confirmed alignment.

### New Contracts This GDD Introduces (will be locked at registry update — Phase 5)

1. `CombatResolver` injectable instance class (`extends RefCounted`, Pass 3D) with two public instance methods: `emit_events_in_range`, `compute_offline_batch`; concrete production impl is `DefaultCombatResolver extends CombatResolver`
2. `CombatTickEvents` and `CombatBatchResult` value types
3. `formation_dps_per_tick` (raw), `ticks_per_loop` (per-enemy derived), `formation_total_hp`, `floor_total_enemy_attack`, `survived` formulas
4. `SPEED_BASE`, `SURVIVAL_MARGIN`, `LOSING_RUN_LOOT_FACTOR`, **`MATCHUP_THROUGHPUT_FACTOR_ADV`** (default `1.5`), **`MATCHUP_THROUGHPUT_FACTOR_DIS`** (default `1.0`) constants

## G. Tuning Knobs

All knobs live in `assets/data/combat_config.tres` (loaded at startup via Data Loading System). No combat value is hardcoded in GDScript.

### G.1 Primary Knobs

| Knob | Default | Safe range | Category | What it affects | Risk if pushed high | Risk if pushed low |
|---|---|---|---|---|---|---|
| `SPEED_BASE` | **2400** | 800 – 6000 | Curve | Single-knob recalibration of all combat throughput. Cooldown divisor (D.1) and DPS denominator (D.2). | All floors take longer; F1 stops being a quick onboarding loop. Offline batch results shrink (less gold per 8h). | All floors clear too fast; the "tempo" feel becomes frantic; Pillar 3 matchup payoff window shrinks because runs end before the 1.5× multiplier matters. |
| `SURVIVAL_MARGIN` | ~~0.2~~ **DEPRECATED (Pass 2B)** | — | — | Replaced by `hp_bonus_factor >= 0.5` threshold in D.6. Retained as an inert registry entry (marked `status: deprecated`) so save-migration / save-data forward-compat is clean; new code paths MUST NOT read it. | — | — |
| `LOSING_RUN_TRIGGER_THRESHOLD` | **0.5** | 0.0 – 1.0 | Feel | Threshold on `hp_bonus_factor` below which `LOSING_RUN_LOOT_FACTOR` applies (D.6 / Rule 9). Single-knob replacement for Pass 2A's SURVIVAL_MARGIN. Hard-coded inline as `0.5` in D.6 rather than a separate registry constant in MVP — elevate to a registry constant only if first-playtest reveals the threshold needs floor-specific tuning. | Many runs flagged LOSING; cozy register damaged; Pillar 1 threatened if pushed above 0.7. | Almost no runs ever flagged LOSING; the safety net is inert (default MVP behavior; fine — Pass 2B design intent). |
| `LOSING_RUN_LOOT_FACTOR` | **0.5** | 0.0 – 0.95 | Feel | Loot multiplier when survivability check fails. | Failing the check feels like a slap on the wrist; no incentive to upgrade. | Failing feels like a fail state (Pillar 1 violation if pushed below ~0.3). |
| `MATCHUP_THROUGHPUT_FACTOR_ADV` | **1.5** | 1.0 – 2.5 | Feel | Multiplier applied to `formation_dps_per_tick` per enemy where the formation crosses the Resolver majority threshold (Rule 10 / D.5). Pillar 3's mechanical audibility knob. Mirrors `MATCHUP_GOLD_MULTIPLIER` (intentionally equal defaults so tempo and gold payoff land on the same cadence). | Advantaged runs clear dramatically faster; players ignore disadvantaged content; matchup choice feels like a solved puzzle. | Tempo difference between advantaged and neutral becomes imperceptible; Pillar 3 reverts to a gold-only signal. |
| `MATCHUP_THROUGHPUT_FACTOR_DIS` | **1.0** | 0.5 – 1.0 | Feel | Multiplier applied to `formation_dps_per_tick` per enemy when the formation does NOT cross the Resolver majority threshold. Default `1.0` = baseline (never punished); Pillar 1 posture. | N/A — default ceiling. | Disadvantaged runs feel punitive — violates "never introduce a fail state" (Pillar 1). Keep at 1.0 unless playtest evidence strongly justifies a dip. |

### G.2 SPEED_BASE Calibration Table

The single most consequential knob in the system. Values below show **clear time per floor at appropriate progression formation**.

Clear time scales linearly with `SPEED_BASE` (since DPS = sum/SPEED_BASE and ticks = HP·SPEED_BASE/sum). All rows below use the D.7 weighted sums (639/800/1391/2736/3400) and per-floor HP (216/308/985/2040/**4818** Pass 2B) divided by SPEED_BASE; time = ticks/20. Cumulative-HP approximation per D.7 (per-enemy canonical drift <1%).

| SPEED_BASE | F1 (L2 form, HP 216) | F2 (L3 form, HP 308) | F3 (L6 form, HP 985) | F4 (L11 form, HP 2040) | F5 (L13 form, HP 4818) | Best matches Biome targets |
|---|---|---|---|---|---|---|
| 800 | 14 s | 15 s | 28 s | 30 s | 57 s | None — too fast everywhere |
| 1600 | 27 s | 31 s | 57 s | 60 s | 113 s | F4 close to 60 s (but target is 90); rest too fast |
| **2400 (default)** | **41 s** | **46 s** | **85 s** | **90 s** | **170 s** | F1, F2, F4, F5 ✓; F3 revised target 85 s ✓ |
| 3200 | 54 s | 62 s | 113 s | 119 s | 227 s | F3/F4/F5 all over; not viable |
| 5300 | 90 s | 102 s | 188 s | 198 s | 376 s | F1 close to ~90s only; deeper floors collapse |

**Tuning recommendation order** (when first-playtest data arrives):
1. `SPEED_BASE` first — tune to make F1 feel right (~30–45 s with a fresh L2 formation). All other floors scale together.
2. Then assess F5 (boss) separately — if it feels too short relative to its build-up, raise `ancient_rootking.base_hp` (Enemy DB knob) rather than altering SPEED_BASE.
3. `LOSING_RUN_TRIGGER_THRESHOLD` (inline `0.5` in D.6) last — only tune if first-playtest reveals the `hp_bonus_factor` curve needs to fire LOSING more/less often. Default expectation for MVP: **never fires** on naturally constructable formations (safety net only).

### G.3 Why No Combat-Owned Per-Hero / Per-Enemy Knobs

Combat does not own any per-class or per-enemy stat knobs. Per-hero attack/HP/speed are owned by Class DB (`assets/data/classes/*.tres`). Per-enemy stats are owned by Enemy DB (`assets/data/enemies/*.tres`). Combat's only knobs are the **interpretation rules** — how those stats compose into throughput. This separation lets the game-designer tune class identity (Class DB) and enemy difficulty (Enemy DB) without touching Combat, and lets Combat be tuned without touching content.

### G.4 First-Playtest Pacing Targets (for QA validation)

| Floor | Acceptable clear-time band (with progression-appropriate formation) | Source |
|---|---|---|
| F1 | 30 – 50 s | Biome target 40 ± 25% |
| F2 | 40 – 70 s | Biome target 55 ± 25% |
| F3 | 65 – 105 s (revised from Biome target 60 s — see D.7 calibration item 1) | This GDD D.7 |
| F4 | 70 – 110 s | Biome target 90 ± 25% |
| F5 | 60 – 100 s OR 150 – 200 s (depends on D.7 calibration item 2 resolution) | This GDD D.7 |

## H. Acceptance Criteria

All criteria use Given-When-Then format. **20 criteria total: 16 Combat-side BLOCKING + 2 Combat-side ADVISORY + 2 Orchestrator-side DEFERRED (#13).** Orchestrator-side ACs are flagged as such and will move to the Orchestrator GDD when authored. Hardware baseline for performance ACs is specified inline on AC-COMBAT-14 (no separate baseline document in MVP scope).

### AC-COMBAT-01 — Stateless Purity (Logic, BLOCKING)

**GIVEN** two `combat_resolver.compute_offline_batch(formation, floor, tick_budget)` calls on the same injected `combat_resolver: CombatResolver` instance (Pass 3D) with identical input arguments,
**WHEN** both calls complete,
**THEN** the two returned `CombatBatchResult` objects are field-equal across all fields: `loops_completed`, `first_clear_tick`, `survived`, `final_tick`, `kills_by_archetype` (dictionary equality), `kills_by_tier` (dictionary equality); no observable mutation of input formation array between calls.

*Verification*: unit test calling `compute_offline_batch` twice with identical args. **Primary assertion (BLOCKING gate)**: `assert result_a.equals(result_b) == true` — exercises the `CombatBatchResult.equals()` method from C.4 that production code relies on. **Secondary belt-and-suspenders assertions**: `result_a.loops_completed == result_b.loops_completed`, `result_a.first_clear_tick == result_b.first_clear_tick`, `result_a.survived == result_b.survived`, `result_a.final_tick == result_b.final_tick`, and `dict_equals(result_a.kills_by_archetype, result_b.kills_by_archetype)` (use the same key-walk helper from C.4 to avoid hash-collision false positives). Also assert the input formation array is unchanged after both calls (no mutations leaked back via reference).

### AC-COMBAT-02 — formation_dps_per_tick Math (Logic, BLOCKING)

**GIVEN** a formation `[Warrior L1 (ATK 12, SPD 6), Mage L1 (ATK 20, SPD 10), Rogue L1 (ATK 14, SPD 16)]` and `SPEED_BASE = 2400`,
**WHEN** `formation_dps_per_tick(formation)` is computed,
**THEN** both of the following assertions hold:
- **Integer weighted-sum assertion** (primary, lossless): compute `weighted_sum: int = sum(hero.attack × hero.speed for hero in formation)` as pure `int` arithmetic; assert `weighted_sum == 12×6 + 20×10 + 14×16 == 496`. This is the lossless gate because all three multiplications and the sum are `int`-closed.
- **Float output approximation** (secondary): assert `is_equal_approx(result, 496.0 / 2400.0)` — in practice `is_equal_approx(result, 0.20667, 0.00001)`. Do NOT assert `result * SPEED_BASE == 496` as integer equality; the intermediate float division reintroduces IEEE 754 rounding (`(496.0/2400.0) * 2400.0 != 496.0` exactly on typical FPUs).

Repeat both assertions for L13 W+M+R: `weighted_sum == 36×18 + 56×22 + 38×40 == 3400`; `is_equal_approx(result, 3400.0/2400.0, 0.00001)`.

*Verification*: parameterized unit test for L1 and L13 cases; integer weighted-sum is the BLOCKING gate (tests Combat's addition logic losslessly); float approximation is the ADVISORY secondary check (catches float-precision regressions but does not fail the gate).

### AC-COMBAT-03 — Empty Formation Guard (Logic, BLOCKING)

**GIVEN** an empty formation array `[]`,
**WHEN** `compute_offline_batch([], floor_f1, 1000)` is called,
**THEN** returns `CombatBatchResult { kills_by_archetype: {}, kills_by_tier: {}, loops_completed: 0, first_clear_tick: -1, survived: false, final_tick: 1000 }`; no `push_error`; one `push_warning` containing the substring "empty formation"; no division-by-zero.

### AC-COMBAT-04 — ticks_per_loop Correctness (Logic, BLOCKING)

**GIVEN** F1 with `enemy_list = [hollow_brute×3 (52 HP, bruiser), glowmoth×1 (60 HP, caster)]` per Biome DB GDD #7 C.2, L1 W+M+R formation with `weighted_sum = 12×6 + 20×10 + 14×16 = 496` (per AC-02 integer-gate computation), and `SPEED_BASE = 2400`,
**WHEN** `ticks_per_loop(formation, floor_f1)` is computed,
**THEN** result equals **1047** ticks (`= 52.35 s`); value is of type `int` (not `float`).

*Verification — lossless integer reference path (mandatory, Pass 2B per-enemy canonical)*: Under Pass 2B the per-enemy kill-schedule (Rule 10 / D.5) replaces Pass 2A's single cumulative-HP ceiling. For L1 W+M+R no archetype crosses the Resolver majority threshold (`n=1` per archetype, needs `n≥2`), so `matchup_throughput_factor = 1.0` (`MATCHUP_THROUGHPUT_FACTOR_DIS`) for every enemy and `effective_dps = formation_dps_per_tick`. Per-enemy integer reference:

- `ticks_to_kill(hollow_brute) = ceili(enemy.base_hp × SPEED_BASE / weighted_sum) = ceili(52 × 2400 / 496) = ceili(124800 / 496) = ceili(251.61…) = 252`
- `ticks_to_kill(glowmoth)     = ceili(60 × 2400 / 496) = ceili(144000 / 496) = ceili(290.32…) = 291`
- `ticks_per_loop = 3 × 252 + 1 × 291 = 756 + 291 = 1047`

The test MUST assert against `1047` derived via the per-enemy integer reference, NOT against the old cumulative-HP result `1046` (Pass 2A: `ceili(216 × 2400 / 496)`) and NOT against a literal float DPS like `0.207`. The per-enemy integer path eliminates IEEE-754 precision drift across CI runners AND is the only formulation that remains correct when `matchup_throughput_factor` varies per-enemy (it happens to collapse to a sum of uniform ceilings here because this formation is neutral, but the test-expected arithmetic is still the per-enemy sum).

**Matchup verification (BLOCKING sub-assertion)**: The test MUST additionally assert `MatchupResolver.resolve_formation_matchup(formation, "bruiser").is_advantaged == false` AND `... "caster").is_advantaged == false` — proving the Pillar 3 lookup ran and returned neutral. This catches a regression where Combat forgets to call Resolver (silently defaulting to 1.0 would still yield 1047 on this fixture).

*Note for QA fixtures*: AC values use the exact F1 enemy_list as authored in Biome DB. If the enemy_list changes upstream, this AC must be updated in lockstep.

*Note on D.2 worked-example precision*: D.2 displays `formation_dps_per_tick = 0.207` (3-sig-fig rounded). The exact float is `496.0/2400.0 ≈ 0.20667`. Neither display value is canonical for tests — the per-enemy integer reference (`52×2400/496` and `60×2400/496`) is canonical.

*Pass 2B migration note*: The Pass 2A expected value `1046` is intentionally superseded. The 1-tick drift (`1047 - 1046 = 1`) is the arithmetic cost of per-enemy integer ceiling and is the honest load-bearing cadence under Pillar 3 routing. `_kill_schedule_for_loop` and `ticks_per_loop` share the same per-enemy accumulator — AC-04 and AC-05 verify the same code path from two angles.

### AC-COMBAT-05 — Kill Schedule Determinism (Logic, BLOCKING)

**GIVEN** L4 W+M+R formation (Warrior ATK 18 SPD 9, Mage ATK 29 SPD 13, Rogue ATK 20 SPD 22) → weighted sum = `18×9 + 29×13 + 20×22 = 979` → raw DPS = `979 / 2400 = 0.408` per tick, F1 enemy_list `[hollow_brute(52, bruiser)×3, glowmoth(60, caster)×1]` (Biome DB authoritative: 3 Hollow Brutes + 1 Glowmoth), `MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5`, `MATCHUP_THROUGHPUT_FACTOR_DIS = 1.0`,
**WHEN** `_kill_schedule_for_loop(formation, floor_f1)` is computed (per Rule 10 / D.5),
**THEN** the schedule is exactly:

| Index | Enemy | archetype | `is_advantaged` | factor | `ticks_to_kill` | `kill_tick` (cumulative) |
|---|---|---|---|---|---|---|
| 0 | hollow_brute | bruiser | false (n=1 < 2) | 1.0 | `ceili(52×2400/979) = ceili(127.48) = 128` | 128 |
| 1 | hollow_brute | bruiser | false            | 1.0 | 128 | 256 |
| 2 | hollow_brute | bruiser | false            | 1.0 | 128 | 384 |
| 3 | glowmoth     | caster  | false (n=1 < 2) | 1.0 | `ceili(60×2400/979) = ceili(147.09) = 148` | 532 |

Each entry's `enemy_id`, `archetype`, `tier`, `is_boss` matches Enemy DB resource. Targeting order = enemy_list order (Rule 5).

**Per-enemy integer-reference path (mandatory)**: each row's `ticks_to_kill` is asserted via `ceili(enemy.base_hp × SPEED_BASE / (weighted_sum × factor_numerator_scale))` where `factor_numerator_scale` is the integer representation of `1.0` (neutral) or `1.5` (advantaged) lifted into the integer path (e.g., `ceili(enemy.base_hp × SPEED_BASE × 2 / (weighted_sum × 3))` for the `×1.5` branch — both 2 and 3 are integers, no float in the gate). For the all-neutral L4 W+M+R on F1, the factor scale is 1, so the gate simplifies to `ceili(enemy.base_hp × SPEED_BASE / weighted_sum)`.

**Pass 2B migration note**: Pass 2A values `(128, 255, 383, 530)` are superseded by `(128, 256, 384, 532)` for this fixture. The drift (`+1, +1, +1, +2`) is the arithmetic cost of per-enemy ceiling vs cumulative-HP ceiling and matches D.5's worked example. `ticks_per_loop` via AC-04 path on this L4 fixture = 532 (the last entry here, as contract with Rule 8).

**Secondary fixture — advantaged L4 W+W+R on F1 (Pillar 3 positive case, BLOCKING sub-assertion)**: Warrior L4 (18,120→187,9)×2 + Rogue L4 (20,55→79,22). Weighted sum = `18×9 + 18×9 + 20×22 = 764`. Bruiser matchup: n=2 (both Warriors counter bruiser), `2 > 1.5` → `is_advantaged = true` → factor = 1.5. Caster matchup: n=0 → factor = 1.0. Per-enemy integer-reference:

| Index | Enemy | archetype | factor | `ticks_to_kill` | `kill_tick` |
|---|---|---|---|---|---|
| 0 | hollow_brute | bruiser | 1.5 | `ceili(52×2400×2 / (764×3)) = ceili(249600/2292) = ceili(108.90) = 109` | 109 |
| 1 | hollow_brute | bruiser | 1.5 | 109 | 218 |
| 2 | hollow_brute | bruiser | 1.5 | 109 | 327 |
| 3 | glowmoth     | caster  | 1.0 | `ceili(60×2400 / 764) = ceili(144000/764) = ceili(188.48) = 189` | 516 |

`ticks_per_loop` (W+W+R, F1) = **516** — 16 ticks (~800 ms) faster than neutral W+M+R (532) despite lower raw DPS (764 < 979). This asymmetry IS Pillar 3's mechanical payoff; AC-05 asserts it directly.

### AC-COMBAT-06 — hp_bonus_factor & LOSING Threshold Boundary (Logic, BLOCKING)

**Three sub-assertions on a synthetic fixture** (MVP floors naturally cap `hp_bonus_factor = 1.0`, so the boundary check requires a designed input):

**Sub-AC 06-cap** — **GIVEN** `formation_total_hp = 245` (L1 W+M+R), `floor_total_enemy_attack = 86` (F3), **WHEN** `hp_bonus_factor(formation, floor)` is computed, **THEN** `is_equal_approx(result, 1.0)` (saturation via `mini`); `survived == true`.

**Sub-AC 06-boundary** — **GIVEN** a synthetic floor with `floor_total_enemy_attack = 120` and `formation_total_hp = 60` (e.g., an invented `test_floor_synthetic` fixture), **WHEN** `hp_bonus_factor` is computed, **THEN** `is_equal_approx(result, 0.5)`; `survived == true` (inclusive `>=`).

**Sub-AC 06-losing** — **GIVEN** the same synthetic floor and `formation_total_hp = 59`, **WHEN** `hp_bonus_factor` is computed, **THEN** `is_equal_approx(result, 0.4917, 0.0001)`; `survived == false`.

*Verification*: parameterized unit test with the three fixtures. Float comparisons use `is_equal_approx`; boundary `survived` derivation uses raw `>=` (per E.8).

*Pass 2B migration note*: Pass 2A's threshold `formation_total_hp >= (1 - SURVIVAL_MARGIN) × floor_total_enemy_attack` is superseded by `hp_bonus_factor >= 0.5`. The new form is arithmetically equivalent to `formation_total_hp >= 0.5 × floor_total_enemy_attack` (single knob, no SURVIVAL_MARGIN). Previous boundary fixture (100/125) is archived.

### AC-COMBAT-07a — hp_bonus_factor Output & LOSING Trigger (Logic, BLOCKING — Combat-side)

**Two fixtures: realistic (MVP, no LOSING) + synthetic (LOSING triggered).**

**Sub-AC 07a-continuous** — **GIVEN** solo L1 Mage (formation `[mage_l1]`, `formation_total_hp = 70`) on F4 (`floor_total_enemy_attack = 96`), **WHEN** `compute_offline_batch(formation, floor_f4, 60000)` is called, **THEN** `is_equal_approx(result.hp_bonus_factor, 70.0/96.0, 0.0001) == true` (≈ `0.729`); `result.survived == true` (0.729 ≥ 0.5 → no LOSING); `result.kills_by_archetype` and `result.kills_by_tier` are populated from the full kill schedule with `effective_dps = raw_dps × matchup_factor × 0.729` applied (Combat does NOT pre-multiply counts by `LOSING_RUN_LOOT_FACTOR` — loot factor is Orchestrator-downstream via AC-07b).

**Sub-AC 07a-losing** — **GIVEN** solo L1 Rogue (formation `[rogue_l1]`, `formation_total_hp = 55`) on a synthetic `test_floor_high_attack` fixture with `floor_total_enemy_attack = 120`, **WHEN** `compute_offline_batch(formation, test_floor_high_attack, 60000)` is called, **THEN** `is_equal_approx(result.hp_bonus_factor, 55.0/120.0, 0.0001) == true` (≈ `0.458`); `result.survived == false` (0.458 < 0.5 → LOSING triggered at the Combat boundary); kill counts are the un-multiplied schedule output (per contract — multiplier is AC-07b's Orchestrator-side responsibility).

*Verification*: two-fixture unit test at the Combat boundary; asserts `hp_bonus_factor` numeric value + `survived` boolean derivation. Synthetic fixture required because MVP floor set (F1-F5, attacks 35-96) never triggers LOSING against naturally constructable formations. Test fixture lives in `tests/fixtures/synthetic_floors.tres` and is flagged NOT-MVP-content.

*Pass 2B migration note*: Pass 2A fixture (solo L1 Mage on F4) triggered `survived=false` and LOSING. Under Pass 2B that same fixture is `survived=true` with continuous 27% tempo slowdown — the "losing run" concept moved from boolean cliff to continuous factor. The synthetic fixture preserves explicit LOSING-path coverage.

### AC-COMBAT-07b — Losing-Run Loot Multiplier End-to-End (Integration, DEFERRED → Orchestrator #13)

**GIVEN** the same inputs as AC-07a and an Orchestrator implementation that consumes `CombatBatchResult.survived`,
**WHEN** the Orchestrator attributes gold to Economy for this run,
**THEN** total gold attributed equals `expected_gold_at_full_loot × LOSING_RUN_LOOT_FACTOR (0.5)`.

*Status*: DEFERRED until Dungeon Run Orchestrator GDD #13 is authored. Combat's contribution to this AC (the `survived = false` flag) is verified in AC-07a; the multiplier application belongs to the Orchestrator's test surface, not Combat's.

### AC-COMBAT-08 — Continuous Loop Aggregate (Integration, BLOCKING)

**GIVEN** L13 W+M+R formation (weighted_sum = 3400, raw DPS = 1.417 per AC-02) on F1 (`enemy_list = [hollow_brute×3, glowmoth×1]`), tick_budget = 576000, L13 W+M+R neutral matchup (`n=1 < 2` per archetype on F1 — same logic as AC-04),
**WHEN** `compute_offline_batch(formation, floor_f1, 576000)` is called,
**THEN**:
- `ticks_per_loop = 3 × ceili(52×2400/3400) + ceili(60×2400/3400) = 3×37 + 43 = 154` ticks (7.70 s) — per-enemy integer-reference path, `matchup_throughput_factor = 1.0` for every enemy
- `loops_completed = floori(576000 / 154) = 3740` complete loops
- `first_clear_tick = 154` (the first time loop counter went 0→1)
- `final_tick = 576000`
- `kills_by_archetype["bruiser"] = 3740 × 3 = 11220` (3 Hollow Brutes per loop × loops)
- `kills_by_archetype["caster"] = 3740 × 1 = 3740` (1 Glowmoth per loop × loops)
- `kills_by_tier[1] = 3740 × 4 = 14960`

**Pass 2B migration note**: Pass 2A expected values (`ticks_per_loop=153`, `loops=3764`, bruiser=11292, caster=3764, tier[1]=15056) are superseded by the per-enemy path above. The 1-tick shift at `ticks_per_loop` propagates as ~24 fewer complete loops across the 8h budget — economically trivial (<1% gold delta) but numerically exact for the AC gate.

### AC-COMBAT-09a — First-Clear Tick Value (Logic, BLOCKING — Combat-side)

**GIVEN** any `compute_offline_batch` result with `loops_completed >= 1`,
**WHEN** the `CombatBatchResult` is inspected,
**THEN** three independent assertions all pass:
- (a) `typeof(result.first_clear_tick) == TYPE_INT` (not float, not null, not Array)
- (b) `result.first_clear_tick > 0`
- (c) `result.first_clear_tick == ticks_per_loop(formation, floor)` — the first-clear tick MUST equal the known loop length, not some smaller value

For `loops_completed == 0`: `result.first_clear_tick == -1` (sentinel for "no loop completed").

(Note: cross-call determinism of `first_clear_tick` is already covered by AC-01's `equals()` field-equality test — not retested here to avoid redundancy.)

### AC-COMBAT-09b — Floor-Clear Signal Once Per Dispatch (Integration, DEFERRED → Orchestrator #13)

**GIVEN** a single dispatch that produces any number of loop completions (foreground or offline),
**WHEN** the Orchestrator processes Combat's loop-boundary markers across the dispatch lifetime,
**THEN** the Orchestrator emits `floor_cleared_first_time(floor_index)` **exactly once per dispatch** — on the first 0→1 loop-counter transition only, regardless of how many subsequent loops complete or whether foreground and offline replay both occur within the dispatch.

*Status*: DEFERRED until Dungeon Run Orchestrator GDD #13 is authored. Combat exposes `first_clear_tick` (09a) and `loop_completed_ticks` / `first_clear_in_range` on `CombatTickEvents`; "exactly once per dispatch" idempotency is a state invariant that belongs to the Orchestrator (Combat is stateless per Rule 1 and cannot track "once per dispatch" unaided).

### AC-COMBAT-10 — Foreground/Offline Parity (Integration, BLOCKING)

**GIVEN** identical formation, floor, and tick range `[0, T]`,
**WHEN** the union of all kill events emitted by `emit_events_in_range(formation, floor, k×CHUNK, (k+1)×CHUNK)` for `k = 0, 1, ..., T/CHUNK` (any chunk size including CHUNK=1) is collected and `compute_offline_batch(formation, floor, T)` is called separately,
**THEN** the two collections are equivalent on these specific fields (compared as deep dictionary equality):
- `kills_by_archetype` (sum of foreground events grouped by archetype) == offline batch's `kills_by_archetype`
- `kills_by_tier` (sum of foreground events grouped by tier) == offline batch's `kills_by_tier`
- foreground's `first_clear_tick` (the first emit_events_in_range tick where loop counter increments to 1) == offline batch's `first_clear_tick`

*Verification*: parameterized integration test with CHUNK ∈ {1, 50, 200, 1000}; assert all four chunkings produce identical aggregates that match offline batch.

### AC-COMBAT-11 — Unresolvable class_id Skipped (Logic, BLOCKING)

**Resolved Pass 3 (option c — dependency injection)**: `CombatResolver` accepts an optional injected `error_logger: Callable` parameter on both public entry points:

```gdscript
# Pass 3D: instance methods (was static func pre-Pass-3D); inject a spy subclass to assert the error_logger Callable is invoked with the expected hero instance_id + reason.
func compute_offline_batch(
    formation: Array[HeroInstance],
    floor: Floor,
    tick_budget: int,
    error_logger: Callable = Callable()      # default: invalid Callable → fall through to push_error
) -> CombatBatchResult: ...

func emit_events_in_range(
    formation: Array[HeroInstance],
    floor: Floor,
    range_start_tick: int,
    range_end_tick: int,
    error_logger: Callable = Callable()
) -> CombatTickEvents: ...
```

Production callers omit the parameter; the implementation falls through to `push_error(message)` when `not error_logger.is_valid()`. Tests pass a recorder Callable (`var log: Array[String]; func record(msg): log.append(msg)`) to capture errors deterministically without touching Godot's error stream. This is consistent with the project's "dependency injection over singletons" standard (CLAUDE.md coding-standards.md). `CombatResolver` remains stateless — the `error_logger` is per-call, not stored. C.4 contract summary updated to reflect the optional parameter; AC-COMBAT-01 determinism gate is unaffected (default Callable is value-equal across calls).

**GIVEN** a formation `[warrior_l5, hero_with_bad_class_id, rogue_l3]` where `bad_class_id` does NOT resolve via `DataRegistry.resolve("classes", id)` and a test-injected `error_logger` Callable bound to an in-memory recorder,
**WHEN** `compute_offline_batch(formation, floor, tick_budget, recorder)` is called,
**THEN** all four assertions hold:
- the bad-class hero contributes `0` to `formation_dps_per_tick` AND `0` to `formation_total_hp` (verifiable from `result.kills_by_archetype` aggregate timing and `result.hp_bonus_factor` value);
- the run completes using only Warrior + Rogue contributions; `result.survived` and `result.kills_by_*` reflect the 2-hero formation;
- the recorder captured **exactly one** logged message containing the substring `"unresolvable class_id"` (assertion: `recorder.log.size() == 1 and "unresolvable class_id" in recorder.log[0]`);
- a control run with `error_logger = Callable()` (production default) MUST NOT raise — the fallback `push_error` path is exercised in a separate smoke test that asserts no GdUnit4 fatal occurred (the message itself is uncapturable in that mode and is not asserted).

*Verification*: parameterized unit test against `tests/unit/combat/test_unresolvable_class_logging.gd`; recorder fixture lives in `tests/fixtures/combat_recorders.gd`. No GdUnit4 stream-capture API is required — the test owns the logger.

### AC-COMBAT-12 — ceili Guarantees kill_tick >= 1 (Logic, BLOCKING)

**GIVEN** a hypothetical 1-HP enemy and an L13 Rogue-only formation (DPS far exceeding 1 per tick),
**WHEN** `_kill_schedule_for_loop` computes the entry,
**THEN** `kill_tick = ceili(1 / dps) = 1`, never `0`; returned value is of type `int`. No "instantaneous kill at tick 0" event is emitted.

### AC-COMBAT-13 — Boss Flag Propagation in Mid-Queue Position (Logic, BLOCKING)

**GIVEN** a hypothetical floor with `enemy_list = [hollow_brute×3, ancient_rootking×1, glowmoth×1]` (boss in position 4 of 5),
**WHEN** `_kill_schedule_for_loop(formation, floor)` is computed,
**THEN** the schedule contains 5 entries; entry index 3 has `is_boss == true` AND `enemy_id == "ancient_rootking"`; entries 0–2 and 4 have `is_boss == false`. The boss flag's queue position matches the enemy_list authoring position regardless of being mid-queue or final.

### AC-COMBAT-14 — Offline Batch Performance (Performance, BLOCKING)

**GIVEN** an L13 W+M+R formation, F1 floor, `tick_budget = 576000` (8h cap),
**WHEN** `compute_offline_batch` is invoked on the **CI runner** (currently `ubuntu-latest` GitHub Actions, 2-core x86_64) and timed via `Time.get_ticks_msec()` before and after the call,
**THEN** wall-clock elapsed time ≤ **100 ms at p95** across 10 consecutive invocations (Combat is one of several callers contributing to Economy's 500 ms total budget per Economy AC H-10). On the min-spec mobile profile (currently defined as: iPhone 11 / Pixel 5 equivalent, single performance core, Godot headless `--disable-render-loop`), the budget relaxes to **200 ms at p95** — acceptable because offline replay runs at app-resume only and is not on the hot path.

*Verification*: performance integration test (`tests/performance/combat_offline_batch_perf_test.gd`); logs p50/p95/p99 and device signature to `production/qa/evidence/combat-perf-[date].md`. Test FAILS if p95 exceeds the per-target budget; WARNS if p99 exceeds 1.5× the budget.

*Baseline document*: A CI-runner hardware spec document (`tests/performance/BASELINES.md`) will be authored during the first performance sprint (Phase 5 of implementation). Until then, the baseline is "current `ubuntu-latest` GitHub Actions runner" as defined inline above — the test records the actual runner signature on each run, so historical comparison remains possible.

### AC-COMBAT-15 — action_cooldown_ticks Guard (Logic, BLOCKING)

**GIVEN** `SPEED_BASE = 2400`,
**WHEN** `action_cooldown_ticks(combatant)` is called for combatants with `speed ∈ {0, 1, 16, 44, 2400, 2401, 100000}`,
**THEN**:
- speed=0 → returns 1 (max guard fires; division-by-zero prevented)
- speed=1 → returns 2400
- speed=16 → returns 150 (= `floori(2400/16)`)
- speed=44 → returns 54 (= `floori(2400/44)`)
- speed=2400 → returns 1
- speed=2401 → returns 1 (`maxi` guard fires; `floori(2400/2401)` = 0 → clamped to 1)
- speed=100000 → returns 1

### AC-COMBAT-16 — enemy_dps_per_tick Aggregation (Logic, ADVISORY)

**GIVEN** F4 with `enemy_list = [thorn_guardian × 3]` (each: base_attack 32, base_speed 5) and `SPEED_BASE = 2400`,
**WHEN** `enemy_dps_per_tick(floor_f4)` is computed,
**THEN** result = `(32 × 5 × 3) / 2400 = 480/2400 = 0.2`. Lossless integer assertion: `result × SPEED_BASE == 480`.

*Gate = ADVISORY*: D.3 is informational only; UI consumes it but no economic state depends on it.

### AC-COMBAT-17 — Long-Run Aggregate Counts No Drift (Logic, BLOCKING)

**GIVEN** L13 W+M+R formation on F1 (4 enemies per loop, neutral matchup per AC-04/08), tick_budget = 60000 (≥10 complete loops at ticks_per_loop=154 plus partial),
**WHEN** `compute_offline_batch` is called,
**THEN** `loops_completed = floori(60000 / 154) = 389`; `kills_by_archetype["bruiser"] + kills_by_archetype["caster"] == 389 × 4 == 1556`; the sum of `kills_by_tier.values()` equals `1556`; no integer overflow at int64 boundary; no off-by-one in the loops_completed/partial-loop boundary.

**Pass 2B migration note**: Pass 2A used `ticks_per_loop = 153 → loops = 392 → kills = 1568`. Per-enemy path yields the values above.

### AC-COMBAT-18 — Formation Immutability During Batch (Logic, ADVISORY)

**GIVEN** a formation array passed to `compute_offline_batch`, the result returned, then the caller mutates the formation array (e.g., appends a hero, modifies hero.current_level),
**WHEN** the same `compute_offline_batch` call's result is re-inspected,
**THEN** the result fields are unchanged. Combat captured all needed values at call-time; the result object holds no live references back to the formation. (Stateless purity at the call boundary.)

*Gate = ADVISORY*: documents the contract; not a critical path failure if violated, but a regression indicator.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| AC-COMBAT-01 | Stateless purity (field-equal results via `equals()`) | Logic | BLOCKING |
| AC-COMBAT-02 | formation_dps_per_tick math (integer + float) | Logic | BLOCKING |
| AC-COMBAT-03 | Empty formation guard | Logic | BLOCKING |
| AC-COMBAT-04 | ticks_per_loop correctness | Logic | BLOCKING |
| AC-COMBAT-05 | Kill schedule determinism | Logic | BLOCKING |
| AC-COMBAT-06 | Survivability check boundary | Logic | BLOCKING |
| AC-COMBAT-07a | Failed-survival trigger flag (Combat-side) | Logic | BLOCKING |
| AC-COMBAT-07b | Losing-run loot multiplier end-to-end | Integration | DEFERRED (Orchestrator #13) |
| AC-COMBAT-08 | Continuous loop aggregate | Integration | BLOCKING |
| AC-COMBAT-09a | First-clear tick value (Combat-side) | Logic | BLOCKING |
| AC-COMBAT-09b | Floor-clear signal once per dispatch | Integration | DEFERRED (Orchestrator #13) |
| AC-COMBAT-10 | Foreground/offline parity | Integration | BLOCKING |
| AC-COMBAT-11 | Unresolvable class_id skipped | Logic | BLOCKING |
| AC-COMBAT-12 | ceili guarantees kill_tick ≥ 1 | Logic | BLOCKING |
| AC-COMBAT-13 | Boss flag mid-queue propagation | Logic | BLOCKING |
| AC-COMBAT-14 | Offline batch performance ≤100ms | Performance | BLOCKING |
| AC-COMBAT-15 | action_cooldown_ticks guard | Logic | BLOCKING |
| AC-COMBAT-16 | enemy_dps_per_tick aggregation | Logic | ADVISORY |
| AC-COMBAT-17 | Long-run aggregate count integrity | Logic | BLOCKING |
| AC-COMBAT-18 | Formation immutability | Logic | ADVISORY |

**Total: 20 (16 Combat BLOCKING + 2 Combat ADVISORY + 2 DEFERRED to Orchestrator #13).**

## I. Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| 1 | **F3 `expected_clear_time_seconds` revision** — ~~Biome DB current target 60 s is unreachable under SPEED_BASE = 2400 (computed 85 s).~~ **RESOLVED 2026-04-20 Pass 2B**: Biome DB F3 target revised 60 s → **85 s**. Cascades applied to `design/gdd/biome-dungeon-database.md` C.2 + C.7 + G.2 (chunk 5). | ~~game-designer + Biome DB owner~~ | ~~Before first MVP playtest~~ — **CLOSED** |
| 2 | **F5 Ancient Rootking calibration** — ~~at SPEED_BASE = 2400 with L13 formation, boss falls in 78 s vs 170 s Biome target.~~ **RESOLVED 2026-04-20 Pass 2B**: `ancient_rootking.base_hp` raised 2200 → **4818** (precise: `ceili(170 × 20 × 1.417) = 4818`). Cascade applied to Enemy DB `ancient_rootking` entry, Biome DB F5 HP registry check, entities.yaml `floor_total_hp` + `ancient_rootking` entries, and D.7 pacing table. | ~~game-designer + economy-designer~~ | ~~Before first MVP playtest~~ — **CLOSED** |
| 3 | **Economy D.6 pacing model re-validation + Pass 3B drip curve rebalance** — Combat's per-floor kill cadence (D.7) replaces Economy's "1 kill / 10 sec active" placeholder. Economy's Day 3-4 Tier-2 milestone (8,000 g) was tuned against the placeholder; needs re-validation against the actual cadence (slower on F3 — 17.3 s/kill vs 10 s/kill placeholder). **Pass 3B 2026-04-20**: Combat surfaced a critical F5 overnight drip overshoot (~11.5M/8h at factor 1.0 vs ~147K to max Tier-1 — 78×, broke the "10–14 days to max" pillar). Interim fix landed: `BASE_DRIP[5]` reduced 20 → 8 in Economy GDD #4 D.1 + G knobs table; full F1–F5 drip curve revalidation flagged as new Economy Open Question (Economy I new entry, gates Combat GDD #11 final approval). **Status remains OPEN until the holistic Economy revision pass lands.** | economy-designer | Before first MVP playtest — gates Combat GDD #11 approval |
| 4 | **SPEED_BASE first-playtest tuning** — default 2400 is a derived calibration target, not a playtest-validated value. First playtest determines whether F1 onboarding (~42 s computed) feels right; if off, tune SPEED_BASE first (single-knob recalibration of all floors). | systems-designer + game-designer | First MVP playtest |
| 5 | ~~**Pillar 2 hp_bonus_factor feel validation** — does Warrior HP feel meaningful despite saturation? Pick (a) tighten denominator with `HP_THRESHOLD[floor_index]` vector for MVP visibility, OR (b) accept MVP invisibility intentional.~~ **RESOLVED 2026-04-20 Pass 3C — Path (b) chosen.** Pillar 2 is committed as V1.0-deferred (header disclaimer added; Rule 9 and D.6 prose updated to make the MVP invisibility explicit). The `hp_bonus_factor` formula is retained as (i) a deterministic safety-net against floor-authoring bugs and (ii) the engine surface that V1.0 content / Cleric synergy will drive. **Warrior identity in MVP is "the safety slot whose HP investment pays off in V1.0 hard content"** — narrative copy and onboarding (Hero Roster / UI screens, future) should frame the L1 Warrior as a deliberate present-day investment for future-content payoff, not a stat that's silently doing nothing. *No further design action on Pillar 2 in MVP scope*; playtest data may inform V1.0 HP_THRESHOLD calibration but does not reopen this question. | ~~game-designer + economy-designer~~ ✅ resolved | ~~First MVP playtest~~ — **CLOSED 2026-04-20 Pass 3C** |
| 6 | **Class Synergy V1.0 hook contract** — V1.0 Class Synergy System (#32) will pre-modify the formation snapshot before passing to Combat (per E.12). The exact synergy resolver interface is V1.0 scope — Combat needs no schema change, but the upstream layer's API must be designed when Class Synergy is authored. | game-designer + systems-designer | V1.0 design pass |
| 7 | **Mid-run formation reassignment policy** — per E.6, Combat does NOT support mid-dispatch formation mutation; the Orchestrator (#13) owns the reassignment-vs-end-run decision. Orchestrator GDD must lock either: (a) reassignment ends the current run and starts a new dispatch, or (b) reassignment is rejected until player explicitly recalls the formation. | game-designer + Orchestrator GDD owner | During Orchestrator GDD (#13) authoring |
| 8 | **Boss-fanfare trigger placement** — per E.10, Combat propagates `is_boss=true` per-event regardless of queue position. Orchestrator (#13) listens for `is_boss=true` events and triggers the fanfare. Convention: only the LAST enemy of a floor should be the boss (Biome DB authoring guideline), but Combat does not enforce this. Orchestrator GDD should document its handling for the (currently impossible but future-possible) mid-queue boss case. | Orchestrator GDD owner | During Orchestrator GDD (#13) authoring |
| 9 | **Per-hero damage tracking V1.0** — MVP intentionally pools enemy damage at the formation level (Rule 6, Rule 9). If V1.0 wants richer combat feel (per-hero HP bars, individual hero "down for the run" states), this needs a Combat schema extension (heroes' current_hp tracked per loop). Defer until V1.0 scope is locked. | game-designer + systems-designer | V1.0 scope planning |
| 10 | **GDScript performance verification** — AC-COMBAT-14's 100 ms budget for 576,000-tick batch is theoretical (no per-tick loop, just O(loops × enemies_per_loop) closed-form arithmetic — should be far under). First impl pass on min-spec hardware validates. If exceeded, the closed-form path can collapse loops further (loops × 5 ≤ 20k iterations even on F1 longest run). | systems-designer + performance-analyst | First impl sprint |
| 11 | **E.3 empty-floor `floor_was_valid: bool` contract (RECOMMENDED, not BLOCKING)** — Per Pass 1 re-review: Combat's E.3 response to empty `floor.enemy_list` currently returns `survived=false, kills=[]` and logs `push_error`. A richer downstream contract — surfacing a `floor_was_valid: bool` field on `CombatBatchResult` so the Orchestrator can distinguish "formation lost badly" from "floor authoring bug" without pattern-matching on empty kills arrays — was considered and **deferred** to Orchestrator GDD #13 author judgment. Combat's current contract is sufficient for MVP; the richer field is a nice-to-have only if the Orchestrator's error-handling surface benefits from it. | Orchestrator GDD owner | During Orchestrator GDD (#13) authoring — treat as RECOMMENDED not BLOCKING |

---

*This GDD introduces the following candidates for `design/registry/entities.yaml` (Phase 5 update):*

**Constants:**
- `SPEED_BASE = 2400` (default; tuning knob 800–6000)
- `LOSING_RUN_LOOT_FACTOR = 0.5` (default; tuning knob 0.0–0.95)
- `MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5` (default; tuning knob 1.0–2.5; Pass 2B Pillar 3)
- `MATCHUP_THROUGHPUT_FACTOR_DIS = 1.0` (default; tuning knob 0.5–1.0; Pass 2B Pillar 3)
- `SURVIVAL_MARGIN` — **DEPRECATED Pass 2B**; entity retained as `status: deprecated` in registry for save-data forward-compat only. Replaced by inline `0.5` LOSING threshold on `hp_bonus_factor`.

**Formulas:**
- `formation_dps_per_tick` (variables: `hero.attack`, `hero.speed`, `SPEED_BASE`; output [0.0, 2.31] — theoretical MVP max is 3× Rogue L15 = 5544/2400)
- `ticks_per_loop` (variables: derived from `_kill_schedule_for_loop(...).back().kill_tick` per Pass 2B; per-enemy integer ceiling, see D.4 / D.5; output ≥ 1)
- `formation_total_hp` (variables: `hero.hp` per `stat_at_level`)
- `floor_total_enemy_attack` (variables: `enemy.base_attack × count`)
- `hp_bonus_factor` (variables: `formation_total_hp`, `floor_total_enemy_attack`; output [0.0, 1.0]; Pass 2B continuous Pillar 2)
- `survived` (variables: `hp_bonus_factor`; output bool — derived as `hp_bonus_factor >= 0.5` per Pass 2B)
- `action_cooldown_ticks` (variables: `combatant.speed`, `SPEED_BASE`; output [1, SPEED_BASE])

**Class:**
- `CombatResolver` (injectable instance class, `extends RefCounted`, with instance methods `emit_events_in_range`, `compute_offline_batch`; Pass 3D — converted from static-only; concrete production impl `DefaultCombatResolver extends CombatResolver`)

**Value types:**
- `CombatTickEvents` (foreground per-tick output)
- `CombatBatchResult` (offline batch output)
