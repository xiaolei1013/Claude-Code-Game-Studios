# Defeat & Injury System — GDD #34

> **Status: FIRST-PASS DRAFT 2026-06-08** — authored after a playtest pivot decision
> by the project owner (creative-director authority): the game adds a **real defeat
> state**. This **supersedes the "no fail state" pillar** (game-concept.md Pillar/
> Submission row + §Recovery-from-failure) and **Combat Rule 9** ("heroes never die /
> roster unchanged after combat"). The owner's rationale: "even for a cozy game we
> need a defeat state, otherwise players lose interest — they need to build the army
> and re-explore the dungeons." Owner-selected harshness: **lose the run + injury**
> (zero loot on defeat; defeated heroes are temporarily *injured*, not permanently
> lost). Pending `/design-review` + the pillar/ADR updates listed in §F.

---

## A. Overview

The **Defeat & Injury System** turns a dungeon run from a guaranteed-win throttle into
a **real-time two-sided race**: the dispatched party has an HP pool that enemy attacks
deplete each tick while the party kills enemies each tick. **Win** = the floor's enemies
are cleared before party HP reaches 0. **Defeat** = party HP reaches 0 first → the party
is *driven back*. A defeat yields **zero loot** for that run and leaves the defeated
heroes **injured** (unable to be re-dispatched until they recover over real time). The
floor is **not** cleared on a defeat, so it remains the player's frontier to retry once
they have leveled, recruited, or fixed the matchup. This creates the core
**lose → strengthen/recover → retry → win** progression loop.

This replaces the MVP model where combat was a one-sided closed-form calculation
(`hp_bonus_factor` only *throttled* a squishy party's DPS; the party always cleared).
The race reuses the existing combat stats (`formation_total_hp`, `formation_dps_per_tick`,
per-enemy HP, enemy attack + speed) — it adds an enemy→party damage channel and a
defeat branch; it does not invent new hero stats.

---

## B. Player Fantasy

**Intended feeling**: "Floor 4 wrecked my party — the rootlings hit harder than I could
clear them, and Theron came home on a stretcher. I need to get the Cleric to 8 and swap
in a tankier front line before I try again." Stakes make the *build* matter: recruiting,
leveling, and matchup choices are now the difference between clearing and getting driven
back, not just clear *speed*. The cozy register survives the pivot because **failure is
recoverable, never permanent** — heroes are injured, not killed; you wait/strengthen and
try again. The dungeon you couldn't beat last session becomes the satisfying win this
session.

This is still **strategic, not reactive** (Pillar 3 preserved): the player never inputs
mid-combat; the outcome is decided by the formation + levels chosen at dispatch. The
battle is *watched*, and now it can be *lost* — which is what gives watching it tension.

---

## C. Detailed Rules

### C.1 — The combat race (two-sided)

A run resolves as a race between two depleting pools, evaluated over combat ticks:

- **Party HP pool** `party_hp = formation_total_hp` (Σ `stat_at_level(HP, level)` across
  the dispatched formation — the existing helper). Full at dispatch; depletes during the
  run; **resets to full on the next run** (HP is a per-run race resource, NOT persisted —
  the persistent consequence of damage is *injury on defeat*, see C.3).
- **Enemy HP pool** = Σ enemy HP across the floor's `enemy_list` (existing).
- **Party damage/tick** = `formation_dps_per_tick × matchup_throughput_factor` (existing
  `effective_dps`, but the `hp_bonus_factor` saturation term is **removed** from the DPS
  path — survival is now the real HP race, not a DPS throttle; see C.5).
- **Enemy damage/tick to party** = `Σ over still-alive enemies (enemy.attack × enemy.speed) / SPEED_BASE`,
  optionally `× matchup_party_disadvantage` — the **symmetric** mirror of the party DPS
  formula. As enemies die (front-to-back per the existing kill schedule), the surviving-
  enemy attack sum shrinks, so the party bleeds slower as the fight progresses.

**Outcome:**
- **WIN** — the last enemy dies on tick `T_clear` and `party_hp > 0` at every tick `t ≤ T_clear`.
- **DEFEAT** — `party_hp ≤ 0` at some tick `T_defeat < T_clear` (the party falls before clearing).

### C.2 — Foreground vs offline (parity)

- **Foreground** (`DungeonRunOrchestrator._on_tick_fired`): per-tick simulation — each tick,
  enemies take party DPS and the party takes alive-enemy DPS. This drives the watchable
  battle (HP bar, lineup depleting) and emits the WIN/DEFEAT outcome. Naturally produces
  the race.
- **Offline** (`compute_offline_batch` / the offline combat path): **closed-form**, O(enemies)
  not O(ticks) — compute each enemy's death tick from the kill schedule, integrate
  cumulative party damage `= Σ_j enemy[j].attack·speed/SPEED_BASE × ticks_enemy_j_alive`,
  and find whether cumulative damage reaches `party_hp` before `T_clear`. Must produce the
  **same WIN/DEFEAT verdict and same loot** as the foreground sim for identical inputs
  (the project's parity invariant — see [[project-drip-offline-parity-segment-count]]).

### C.3 — Defeat consequences (owner-selected: harsh + injury)

On **DEFEAT**:
1. **Zero loot.** The run forfeits ALL gold it would have produced — drip earned this run,
   kill gold, and the floor-clear bonus are all **lost** (not credited). The floor is NOT
   marked cleared (`floor_clear_bonus_credited` untouched; FloorUnlock does not advance).
2. **Injury.** Every hero in the defeated formation becomes **injured**: `hero.injured_until`
   is set to `now + INJURY_RECOVERY_TICKS`. An injured hero **cannot be assigned to a
   formation / dispatched** until recovered. Recovery counts down in real time, **including
   offline** (it is wall-clock based, like offline progression).
3. **No permadeath.** Heroes are never removed from the roster. Injury is fully temporary.

On **WIN**: loot is credited as today (drip + kills + first-clear bonus); party HP is
irrelevant after the win; no injury. (The legacy `losing_run`/`LOSING_RUN_LOOT_FACTOR`
"thin-margin half-loot" concept is **retired** — superseded by the binary win/defeat race.)

### C.4 — Injury & recovery

- `hero.injured_until: int` (tick timestamp; `0` = healthy). A hero is injured iff
  `injured_until > TickSystem.now()`.
- **Dispatch gate**: `FormationAssignment` / the orchestrator rejects a dispatch whose
  formation contains any injured hero (validation_failed reason `"hero_injured"`), and the
  roster/formation UI marks injured heroes (greyed + a recovery countdown).
- **Recovery**: purely time-based for the first pass (no gold-cost heal in v1 — that is a
  documented future knob). When `TickSystem.now() ≥ injured_until`, the hero is healthy
  again automatically; the roster surfaces "Recovered" on next view.
- **All-injured edge**: if every roster hero is injured, the player cannot dispatch until
  one recovers — the offline drip stops (no active run). The guild_hall surfaces "Your
  guild is recovering — back at <time>." (See E.4.)

### C.5 — Relationship to the legacy `hp_bonus_factor`

The legacy `hp_bonus_factor = min(formation_total_hp / floor_total_enemy_attack, 1.0)`
DPS-saturation term is **removed from the effective-DPS path** (it was the old
survival proxy). Survival is now the real HP race (C.1). `formation_total_hp` is retained
(it is the party HP pool). The `survived`/`losing_run` booleans are replaced by the
race's WIN/DEFEAT outcome. This is the single largest combat-formula change and the
primary balance-revalidation surface (§G, Phase 2).

---

## D. Formulas

| Quantity | Formula |
|---|---|
| `party_hp` | `Σ stat_at_level(HP, hero.level)` over formation |
| `enemy_total_hp` | `Σ enemy.hp` over floor.enemy_list |
| `party_dps_tick` | `Σ(hero.attack × hero.speed)/SPEED_BASE × matchup_throughput_factor` |
| `enemy_dps_tick(t)` | `Σ over alive-at-t enemies (enemy.attack × enemy.speed)/SPEED_BASE × matchup_party_disadvantage` |
| `T_clear` | `Σ over enemies ticks_to_kill(enemy)` (existing kill schedule) |
| `party_damage_by(T)` | `Σ_j enemy[j].attack·speed/SPEED_BASE × min(T, death_tick[j])` |
| **Outcome** | `DEFEAT` if `∃ T < T_clear: party_damage_by(T) ≥ party_hp`, else `WIN` |
| `injured_until` | `TickSystem.now() + INJURY_RECOVERY_TICKS` (set on defeat) |

**Worked sanity check** (post-SPEED_BASE-reconciliation, Phase 2 calibrates the exact
numbers): an appropriately-leveled, matchup-correct party clears with HP to spare (WIN);
an under-leveled or mismatched party's `party_damage_by(T_clear) ≥ party_hp` (DEFEAT).
Phase 2 produces the per-floor calibration table (the analogue of combat-resolution.md D.7)
proving the intended floors are winnable by the intended formation tier and losable below it.

---

## E. Edge Cases

- **E.1 Empty formation** — cannot dispatch (existing validation). No race.
- **E.2 Party HP and enemy HP reach 0 on the same tick** — **WIN** (party clears on the
  tick it would have fallen; ties go to the player — cozy-leaning, deterministic).
- **E.3 Offline defeat** — a too-weak party left on a hard floor defeats on its first loop;
  it does NOT retry offline (the heroes are injured). Offline yields zero gold from that
  floor for the elapsed window; return-to-app shows "driven back at Floor X — recovering."
  A *winning* offline party keeps looping as today (HP resets each loop; no injury).
- **E.4 All heroes injured** — no dispatch possible; no active run; drip stops. Surfaced in
  guild_hall + a soonest-recovery timer. Not a soft-lock: recovery is automatic over time.
- **E.5 Hero injured mid-offline then recovers mid-window** — recovery is wall-clock; a hero
  whose `injured_until` falls within the offline window is healthy for the remainder (but the
  defeated run that injured them already ended the active dispatch — they don't auto-redispatch).
- **E.6 Save/load** — `injured_until` persists per hero (save schema additive field; forward-
  compat: missing → `0`/healthy). Recovery is computed from persisted timestamp vs now on load.
- **E.7 Matchup disadvantage** — a mismatched formation both deals less (throughput) and may
  take more (party_disadvantage knob) — this is the dial that makes *wrong* dispatches lose.

---

## F. Dependencies

| System | Why | Surface |
|---|---|---|
| **Combat Resolver** (#11) | Owns the race math | New: enemy→party damage channel, WIN/DEFEAT outcome; removes hp_bonus_factor DPS term. **Rule 9 superseded.** |
| **Dungeon Run Orchestrator** (#13) | Drives foreground per-tick race + emits outcome | New `run_defeated` signal; defeat → no loot calls; injury application. |
| **Hero Roster** (#9) | Owns `injured_until` + dispatch gate | New field + `is_injured()` + recovery; save schema additive. |
| **Economy** (#5) | Loot on win, zero on defeat | Defeat path credits nothing; the drip I shipped (S28-G1) must be defeat-aware (drip earned in a defeated run is forfeit). |
| **Offline Progression** (#OE) | Defeat-aware closed-form | Per-loop WIN/DEFEAT; stops on defeat; parity with foreground. |
| **Formation Assignment** (#screen) | Block injured-hero dispatch + show recovery | validation_failed `"hero_injured"`; UI marks. |
| **Return-to-App / Guild Hall** | Surface defeat + recovery | "Driven back at Floor X — recovering" + timers. |
| **Save/Load** (#SL) | Persist injury | `injured_until` per hero; additive migration. |
| **VFX (#27) / Dungeon Run View** | Watchable battle + defeat moment | Party HP bar, lineup depletion, kill-pops (VfxKit), defeat sting. |
| **game-concept.md pillars** | The pivot | "No fail state" → "stakes with recovery"; new ADR. |

---

## G. Tuning Knobs

| Knob | Default (Phase 2 calibrates) | Affects |
|---|---|---|
| `SPEED_BASE` | reconcile shipped 10 vs GDD 2400 | run duration + the whole race timescale (highest-leverage) |
| per-floor enemy `attack`/`speed`/`hp` | existing, retuned | which formation tier wins vs loses each floor |
| `matchup_party_disadvantage` | e.g. 1.25 (mismatch takes 25% more) | how punishing a wrong matchup is |
| `INJURY_RECOVERY_TICKS` | e.g. 30 min wall-clock | how long a defeat sets you back |
| `loops_per_run` | currently 1 (hardcoded) | whether a run is one rotation or many |

---

## H. Acceptance Criteria

- AC-34-01 — A sufficiently-leveled, matchup-correct party **WINS** floor F (party_hp > 0 at clear); loot credited.
- AC-34-02 — An under-leveled OR mismatched party **DEFEATS** on floor F (party_hp ≤ 0 before clear); **zero** gold credited; floor NOT cleared.
- AC-34-03 — Foreground per-tick race and offline closed-form produce the **same WIN/DEFEAT verdict and same loot** for identical inputs (parity).
- AC-34-04 — On defeat, every formation hero has `injured_until > now`; an injured hero **cannot be dispatched** (validation_failed `"hero_injured"`).
- AC-34-05 — Injury **recovers** automatically when `now ≥ injured_until`, including across an offline gap; the hero is then dispatchable.
- AC-34-06 — `injured_until` round-trips through save/load; missing field loads as healthy.
- AC-34-07 — Per-floor calibration table proves each MVP floor is winnable by its intended formation tier and losable below it (Phase 2 evidence).
- AC-34-08 — Drip (S28-G1) earned within a defeated run is forfeit (not credited); a defeated run's net gold delta is 0.

---

## I. Phased Implementation Plan (each phase = its own PR, re-playtestable)

- **Phase 0 — Design lock (this doc) + pillar/ADR update.** Update game-concept.md Pillar
  ("no fail state" → "stakes with recovery"); add ADR-0021 (defeat-state pivot); mark
  Combat Rule 9 superseded. *(No code.)*
- **Phase 1 — Combat race + defeat outcome** in the resolver + orchestrator (foreground
  per-tick + offline closed-form, parity-tested). Emits WIN/DEFEAT; defeat → zero loot.
  Removes the hp_bonus_factor DPS term. TDD; update the ~17 combat tests.
- **Phase 2 — Balance.** Reconcile `SPEED_BASE`; retune per-floor enemy stats; produce the
  calibration table (AC-34-07); **re-verify the S28-G1 drip + offline economy** under the
  new run cadence.
- **Phase 3 — Injury system.** `injured_until` on HeroRoster + recovery + dispatch gate +
  save migration + formation/roster UI marks. TDD.
- **Phase 4 — Watchable battle + defeat UX.** Dungeon-run-view party HP bar, enemy lineup
  depletion, kill-pops (VfxKit), defeat moment; return-to-app/guild-hall recovery surfaces.
- **Phase 5 — Offline-defeat polish + retry loop.** Offline summary ("driven back at Floor
  X"), all-injured handling, retry framing.

---

## J. Notes

- Pillar pivot authority: project owner, 2026-06-08 (playtest-driven). Two binding choices
  recorded: (1) add a real defeat state; (2) harshness = lose-the-run + injury (no permadeath).
- This is a multi-system change; the offline/economy interaction is the highest-risk surface
  (it touches the S28-G1 drip + offline parity shipped the same day — Phase 2 re-verifies it).
- Future knobs (documented, not in v1): gold-cost instant-heal; reduced-stats-while-injured
  (instead of dispatch-block); per-hero injury severity; a "retreat early to save loot" option.
