# ADR-0021: Defeat-State Pivot — Real, Recoverable Defeat (supersedes "no fail state")

## Status

**Accepted 2026-06-08** — owner (creative-director authority) decision, playtest-driven.
Supersedes the "no fail-state" framing in `game-concept.md` (Submission pillar +
§Recovery-from-failure) and **Combat Resolution GDD #11 Rule 9** ("heroes never die /
roster unchanged after any combat"). Governs the new GDD #34 (Defeat & Injury System).

## Date

2026-06-08

## Context

A playtest (the S28-M1 obligation, run by the owner) surfaced two findings about dungeon
runs: (1) "the battle scene is not implemented — we just show results immediately," and
(2) "our party always beats the enemies — we want damage taken / risk of defeat /
difficulty." Investigation confirmed: combat is a one-sided closed-form calculation that
the party always wins (the `hp_bonus_factor` only throttles DPS; `losing_run` is
mathematically unreachable on MVP floors and only ever halved loot), and a shipped
`SPEED_BASE = 10` (vs the GDD's `2400`) collapses run duration to a fraction of a second
so nothing is watchable.

The owner was presented with the design tension — a true fail state contradicts the
locked **#1 "Submission/relaxation, no fail-state"** pillar — and **chose to pivot the
pillar**: *"even for a cozy game we need a defeat state, otherwise players lose interest;
they need to build the army and re-explore the dungeons."* When offered three harshness
levels (retreat / lose-the-run+injury / permadeath roguelike), the owner selected
**lose-the-run + injury**.

This is a binding identity change, recorded here per the coordination rule that
identity-level creative decisions are the creative-director's (here, the owner's) call.

## Decision

1. **Combat becomes a two-sided real-time HP race.** The party has an HP pool
   (`formation_total_hp`) that enemy attacks deplete each tick while the party kills
   enemies each tick. **WIN** = floor cleared before party HP reaches 0; **DEFEAT** =
   party HP reaches 0 first. The legacy `hp_bonus_factor` DPS-throttle and the
   `survived`/`losing_run` half-loot proxy are **retired**. Full mechanic: GDD #34.

2. **Defeat consequence = harsh + injury, no permadeath.** A defeated run yields **zero
   loot** (drip earned in that run, kill gold, and floor-clear bonus are all forfeit; the
   floor is not cleared). Every hero in the defeated formation becomes **injured** —
   unable to be re-dispatched until they recover over real (wall-clock, offline-aware)
   time. Heroes are **never** permanently lost.

3. **The loop:** lose → heroes recovering + no loot → level/recruit others or wait →
   retry the floor → win. Difficulty now lives in formation + level investment deciding
   *win/loss*, not just clear *speed*. Play stays **strategic, not reactive** (Pillar 3
   intact — no mid-combat input).

4. **Pillar + Rule supersession.** `game-concept.md`'s "no fail-state" / "no hard walls"
   language is revised to "recoverable defeat" (done in this PR). Combat Rule 9 is marked
   superseded by ADR-0021 + GDD #34.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay logic (combat resolution + roster state + economy) — no new engine API |
| **Knowledge Risk** | LOW (no post-cutoff engine API; uses existing tick/signal/resource patterns) |
| **Verification** | Phase 1 parity tests (foreground sim == offline closed-form WIN/DEFEAT + loot); Phase 2 per-floor calibration table; Phase 7-style re-playtest |

## Consequences

### Positive
- Stakes give the build-army/re-explore loop a reason to exist (the owner's engagement goal).
- Watchable battle becomes meaningful (an HP bar that can actually hit 0).
- Reuses existing combat stats (HP, attack, speed, enemy HP) — no new hero-stat schema.

### Negative / cost
- **Large, multi-system change** (phased — see GDD #34 §I): combat resolver redesign,
  new injury system on HeroRoster, save migration, full floor **rebalance** (incl. the
  `SPEED_BASE` reconciliation), offline-defeat handling, defeat UX, and ~17 combat tests
  to update.
- **Offline/economy ripple is the highest risk:** defeat must be applied identically
  foreground + offline, and a defeated run must forfeit the per-tick drip shipped the same
  day (S28-G1) — Phase 2 re-verifies the drip + offline parity under the new model.
- The aesthetic table's Submission-vs-Challenge weighting is now in tension; a formal
  re-rank is a flagged follow-up (not blocking).

### Neutral
- Cozy register is *retained but redefined* — failure is recoverable (injury, retry),
  never permanent. No permadeath, no real-money pressure, no FOMO timers.

## Alternatives Considered

1. **Keep no-fail; stakes-as-drama only** (visible damage + slower clears + reduced loot,
   party always survives). **Rejected by the owner** — judged insufficient for long-term
   engagement ("players lose interest"); the build/re-explore loop needs real loss.
2. **Permadeath roguelike** (heroes die on defeat). **Rejected by the owner** in favor of
   injury — too harsh a tone shift; injury preserves recoverability while still setting the
   player back. Permadeath remains a documented future option, not adopted.
3. **Closed-form defeat threshold** (no real-time race; defeat = a static
   strength-ratio below a cutoff). Viable for offline but **not watchable**; the two-sided
   per-tick race was chosen because it serves both the defeat condition and the
   watchable-battle requirement (finding #1) with one mechanic.

## GDD Requirements Addressed

- **GDD #34 (Defeat & Injury System)** — this ADR is its governing architectural decision.
- **GDD #11 (Combat Resolution) Rule 9** — superseded (heroes can now be defeated → injured).
- **game-concept.md** Submission pillar + §Recovery-from-failure + §Difficulty-scaling — revised.

## Related

- `design/gdd/defeat-and-injury-system.md` (#34) — the full mechanic + phased plan.
- `design/gdd/combat-resolution.md` (#11) — Rule 9 superseded; the race builds on its formulas.
- `design/gdd/economy-system.md` (#5) + S28-G1 drip — defeat-aware loot is the key ripple.
- `design/gdd/offline-progression-engine.md` — defeat-aware closed-form replay.
- `design/gdd/hero-roster.md` (#9) — new `injured_until` state.

## Sign-Off Trail

- **2026-06-08** — Accepted by the owner via two playtest-driven decisions: (1) add a real
  defeat state; (2) harshness = lose-the-run + injury (no permadeath). Implementation is
  phased per GDD #34 §I; each phase ships as its own reviewable PR.
