# ADR-0002: LOSING First-Clear Bonus — Re-claimable on Subsequent WIN

## Status

Accepted

## Date

2026-04-20

## Last Verified

2026-04-20

## Decision Makers

- Author (user) — final decision (chose Option 1 "re-claimable on subsequent WIN" among three vision-level alternatives)
- creative-director — alternative framing + "no fail state" pillar check
- game-designer (BLOCKING-2, re-review 2026-04-20) — surfacing the permanency / pillar conflict
- economy-designer — per-lifetime gate reshape
- systems-designer — Orchestrator integration implications

## Summary

When the player first-clears a floor on a LOSING run (`hp_bonus_factor < 0.5`), the halved `FLOOR_CLEAR_BONUS` is credited immediately, but the remaining half is **not permanently forfeit**: a subsequent non-LOSING clear of the same floor credits the delta. This is implemented by replacing Economy's per-lifetime boolean gate with a monotonic `floor_clear_bonus_credited[floor_index]: int` running-total, so `try_award_floor_clear` becomes a "credit whatever the gap is" call. This reconciles the LOSING_RUN_LOOT_FACTOR penalty with the game's "no fail state — losing run returns partial loot" promise.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting (Economy per-lifetime state + Orchestrator call path) |
| **Knowledge Risk** | LOW |
| **References Consulted** | `design/gdd/dungeon-run-orchestrator.md` §C.6, §E.5, AC-ORC-04; `design/gdd/economy-system.md` §C.2.3, §C.2.3a, AC H-03, AC H-14; `design/gdd/combat-resolution.md` Rule 9 (+ Pass 4B-Economy supersession) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond standard Godot dictionary / int persistence in Save/Load |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (supersedes prior Pass 4B-Economy AC H-14 boolean-gate design — Economy GDD must be updated accordingly in Pass 5B) |
| **Enables** | Orchestrator AC-ORC-04 Sub-AC "LOSING first-clear re-claim" (new); full reconciliation of Pillar 1 "no fail state" with LOSING penalty |
| **Blocks** | Economy revision Pass 5B (must land before Orchestrator re-review gate can close 17b) |
| **Ordering Note** | This ADR defines the contract; Economy GDD Pass 5B is the spec doc that implements it. Save/Load Pass 4B-SaveLoad Rule 11 (Array-element to_dict/from_dict) is unaffected — the field is a `Dictionary[int, int]`, not an array of complex objects. |

## Context

### Problem Statement

After the Pass 4B-Economy A2 supersession of Pass 2B decision 4, the `LOSING_RUN_LOOT_FACTOR = 0.5` applies to kill gold **and** the floor-clear bonus on LOSING runs. The independent re-review (2026-04-20, game-designer BLOCKING-2) surfaced that the interaction between this halving and the per-lifetime idempotency gate is permanent + irrecoverable: a player who happens to be first in line through a dungeon on a LOSING attempt gets 50% of the floor-clear bonus once, and the other 50% is never reachable by any subsequent play. This directly contradicts the game concept's "no fail state — losing run returns partial loot" framing.

Three vision-level options were presented:

1. **First-clear re-claimable on subsequent WIN** (chosen)
2. Exempt first-clear from LOSING halving entirely (simplest; weakens LOSING penalty)
3. Rewrite the "no fail state" pillar (most destructive to the core vision)

Author selected Option 1.

### Current State

Per the current Orchestrator + Economy design (post Pass 4B-Economy):

- Orchestrator calls `Economy.try_award_floor_clear(floor_index, bonus_amount)` at most once per dispatch (gated by `snapshot.floor_clear_emitted`).
- Economy maintains `floors_cleared_bonus_awarded: Dictionary[int, bool]` — if `true`, the call no-ops regardless of `bonus_amount`.
- On a LOSING first-clear: Orchestrator passes `floori(FLOOR_CLEAR_BONUS[floor_index] × 0.5)`. Economy credits it, flips the boolean `true`. All future calls no-op, even with a higher `bonus_amount`.

The boolean gate is the problem. It is binary + sign-only ("has the bonus ever been awarded?"), not quantity-aware ("how much has been credited so far?").

### Constraints

- Combat's stateless contract must be preserved — Combat does not know about per-lifetime state.
- Orchestrator's per-dispatch idempotency (`floor_clear_emitted`) must still fire correctly — this ADR does not remove that layer; it reshapes only the Economy-side gate.
- Save/Load contract: the replacement field must persist through suspend/resume. A `Dictionary[int, int]` satisfies Save/Load Rule 11 (JSON dict serialization) trivially.
- Per-lifetime idempotency must remain anti-exploit: on repeated WIN clears, the total credited must not exceed `FLOOR_CLEAR_BONUS[floor_index]`.

### Requirements

- LOSING first-clear credits exactly `floori(FLOOR_CLEAR_BONUS[floor_index] × 0.5)` immediately.
- Subsequent non-LOSING clear of the same floor credits the remaining delta (`FLOOR_CLEAR_BONUS[floor_index] - already_credited`) exactly once.
- Any further clear (WIN or LOSING) of a floor that is already fully credited is a no-op.
- A player who wins first and later re-enters on a LOSING run receives 0 additional floor-clear bonus (no downside to having won first).
- Economy's API surface must remain a single entry-point call from the Orchestrator's side (`try_award_floor_clear`) — the complexity stays in Economy.
- The decision must be fully backwards-compatible with AC-ORC-05 (first-clear-once-per-dispatch) — the Orchestrator's per-dispatch flag still gates duplicate emissions within a dispatch.

## Decision

### The contract

Economy replaces the boolean gate with a monotonic integer running-total:

```gdscript
# Economy System state (replaces floors_cleared_bonus_awarded: Dictionary[int, bool])
var floor_clear_bonus_credited: Dictionary[int, int] = {}   # key: floor_index; value: total gold credited so far
```

`try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool` becomes a **credit-the-gap** call:

```gdscript
func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool:
    var already_credited: int = floor_clear_bonus_credited.get(floor_index, 0)
    if bonus_amount <= already_credited:
        return false                                              # no-op: nothing to credit
    var delta: int = bonus_amount - already_credited
    add_gold(delta)                                               # credit only the gap
    floor_clear_bonus_credited[floor_index] = bonus_amount        # monotonic ceiling
    return true
```

### Semantic consequences

| Sequence | Call pattern | Total credited per floor |
|---|---|---|
| WIN clear only | `try_award(1, 500)` → credits 500 | 500 |
| LOSING first-clear, no re-entry | `try_award(1, 250)` → credits 250 | 250 |
| LOSING first-clear, then WIN | `try_award(1, 250)` (credits 250) + `try_award(1, 500)` (credits 250) | 500 |
| WIN first-clear, then LOSING re-entry | `try_award(1, 500)` (credits 500) + `try_award(1, 250)` (no-op, 250 < 500) | 500 |
| Two WINs | `try_award(1, 500)` (credits 500) + `try_award(1, 500)` (no-op) | 500 |
| LOSING, then LOSING | `try_award(1, 250)` (credits 250) + `try_award(1, 250)` (no-op, 250 ≤ 250) | 250 (still reclaimable on a later WIN) |

The rightmost column never exceeds `FLOOR_CLEAR_BONUS[floor_index]`. Monotonic credited total preserves anti-exploit.

### Orchestrator-side changes

The Orchestrator's call path does **not** change. The Orchestrator still passes the correct `bonus_amount` for the current dispatch:

- Non-LOSING clear: `attribute_floor_clear_bonus(floor_index, false) = FLOOR_CLEAR_BONUS[floor_index]`
- LOSING clear: `attribute_floor_clear_bonus(floor_index, true) = floori(FLOOR_CLEAR_BONUS[floor_index] × 0.5)`

Economy owns the re-claim logic. The Orchestrator's per-dispatch flag (`floor_clear_emitted`) remains unchanged — it still ensures at most one call per dispatch.

### Architecture

```
[DungeonRunOrchestrator]
  on first-clear transition (foreground or offline):
    if not snapshot.floor_clear_emitted:
        snapshot.floor_clear_emitted = true
        Economy.try_award_floor_clear(
            snapshot.floor.floor_index,
            attribute_floor_clear_bonus(snapshot.floor.floor_index, snapshot.losing_run)
        )

[Economy]
  try_award_floor_clear(floor_index, bonus_amount):
    already = floor_clear_bonus_credited.get(floor_index, 0)
    if bonus_amount <= already: return false
    add_gold(bonus_amount - already)
    floor_clear_bonus_credited[floor_index] = bonus_amount
    return true
```

### Key Interfaces

```gdscript
# Economy — public API (no signature change from Pass 4B-Economy A1)
func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool
```

```gdscript
# Economy — save/load schema (replaces floors_cleared_bonus_awarded)
# to_dict fragment:
{
    ...,
    "floor_clear_bonus_credited": {              # Dictionary[int, int]
        "1": 500,
        "3": 250,                                # F3 LOSING first-clear pending 250 reclaim
        ...
    },
    ...
}
```

### Implementation Guidelines

- Economy GDD #4 must rewrite §C.2.3 / §C.2.3a / AC H-03 / AC H-14 in Pass 5B to reflect the monotonic integer gate.
- Economy's `equals()` implementation (Save/Load Rule 13) compares the dictionary key-set and per-key int values; no float tolerance needed (`SAVE_LOAD_FLOAT_EPSILON` not applicable — int equality).
- A one-time save migration is NOT required: this ADR is authored *before* the first playable vertical slice ships, so there is no production save data to migrate. If a post-MVP migration becomes necessary, the mapping is trivial: `floors_cleared_bonus_awarded[i] == true` → `floor_clear_bonus_credited[i] = FLOOR_CLEAR_BONUS[i]` (assumption: pre-migration bonuses were always full-amount WIN clears; this assumption holds iff LOSING runs are disabled in the pre-migration build, which is the case for MVP).
- Orchestrator AC-ORC-04 and AC-ORC-05 sub-ACs must be extended per Pass 5B (re-claim assertion on a WIN following a LOSING first-clear).
- The telemetry counter `losing_first_clears_reclaimed_on_win` is RECOMMENDED — a clean Pillar-1 health metric.

## Alternatives Considered

### Alternative 1: Exempt first-clear from LOSING halving entirely

- **Description**: `attribute_floor_clear_bonus(floor_index, losing_run)` ignores `losing_run` — always returns `FLOOR_CLEAR_BONUS[floor_index]`. Orchestrator §E.5 simplifies; no Economy contract reshape needed.
- **Pros**: Simplest. Boolean gate stays. Zero new state.
- **Cons**: Weakens the LOSING penalty's intent. The concept was "LOSING runs give partial loot" — if first-clears are fully exempt, a player can reliably farm first-clears on LOSING fixtures knowing the bonus pays in full. This conflicts with the kill-gold halving (kept per Pass 4B-Economy A2) and creates an inconsistent rulebook ("half kill gold, but full clear bonus — why?").
- **Estimated Effort**: Lowest (one-line formula change).
- **Rejection Reason**: Rule-consistency. The "50%" factor applied to kill gold loses its rationale if it does not apply to the single biggest payout event on the floor. The monotonic credit approach preserves the 50% penalty as immediate cost + remaining half as recoverable debt — same total, different temporal shape, better fit for "no fail state."

### Alternative 2: Rewrite the "no fail state" pillar

- **Description**: Accept that LOSING runs can permanently cost content; update game concept + narrative framing to "LOSING runs are a viable path but cost you long-term rewards on floors you haven't yet cleared properly."
- **Pros**: Cleanest engine model (boolean gate stays; no Economy reshape). No additional state persisted.
- **Cons**: Most destructive to the core vision. The "no fail state — losing run returns partial loot" framing is a key part of the cozy pillar (Pillar 3) and of the Lantern Guild concept document. Rewriting it affects the narrative tagline, the first-hour player experience messaging, the Return-to-App screen copy, and community expectations set by the concept doc.
- **Estimated Effort**: Highest in cascade cost (concept doc rewrite, narrative copy, first-playtest messaging, possibly reviewer communications).
- **Rejection Reason**: Vision cost far exceeds the engine cost of Option 1.

## Consequences

### Positive

- **Pillar 3 (cozy) preserved**: A LOSING run never permanently destroys content. "You earn half now; the rest is waiting on a win."
- **Pillar 1 (foreground/offline parity) preserved**: The re-claim is credited by the Orchestrator's normal first-clear emission path on a subsequent clear — nothing asymmetric between foreground and offline. Parity test (AC-ORC-09) is unaffected.
- **Rule consistency**: The 50% factor applies uniformly to both kill gold and floor-clear bonus on LOSING runs, but the *temporal shape* of the floor-clear penalty (immediate cost + recoverable) matches the game's "no fail state" framing.
- **Simple authoring**: Economy's per-lifetime gate becomes more expressive without adding any new call sites. Orchestrator is unchanged.

### Negative

- **One-field contract change in Economy**: `Dictionary[int, bool] → Dictionary[int, int]`. Requires Economy GDD Pass 5B rewrite of §C.2.3 and AC H-03 / AC H-14 (Pass 4B-Economy boolean AC is superseded).
- **Save/Load schema change**: The field rename + type change must appear in Save/Load's serialization table (Rule 10 / 11). Low cost (JSON-native types), but must be explicitly called out to avoid confusion with the Pass 4B-SaveLoad boolean gate.
- **Minor doc surface expansion**: The re-claim semantics need a new Orchestrator edge-case entry (E.15 or similar) and a sub-AC on AC-ORC-04.

### Neutral

- No change to the Orchestrator's call-site code. The "credit the gap" logic is entirely Economy-owned.
- No new telemetry required; existing `gold_credited_by_source` events suffice. Recommended-but-not-required metric: `losing_first_clears_reclaimed_on_win`.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Economy GDD Pass 5B is incorrectly authored — new field defaults to boolean, re-claim breaks | Low | High (silent — player loses the reclaim quietly) | Pass 5B mandates inline worked-example table (the sequence table above); AC H-14 rewritten with re-claim sub-AC; Orchestrator AC-ORC-04 adds Sub-AC "losing-first-clear-then-win-credits-delta" |
| Save migration bug on pre-ADR saves (if MVP ships with the boolean gate first, then this ADR lands later) | Low | Medium (player loses reclaim on pre-existing LOSING clears) | Sequencing: this ADR is Accepted *before* MVP ships, so migration is not triggered in the wild. Noted under Implementation Guidelines. |
| Player confusion: "why did I get 250g this run and 250g next run for the same floor?" | Medium | Low (copy problem, not balance problem) | Return-to-App screen's first-clear line item reads: "F3 first clear (losing run) — 250g, +250g pending on win" for the LOSING case; "F3 first clear completed — 250g" for the reclaim. Narrative team owns the copy. |
| Degenerate case: player farms LOSING first-clears, then single WIN claims all deltas in one session | Medium | None (intended behaviour) | This is by design. A WIN clear *always* pays the remaining delta — this is the "no fail state" guarantee expressed mechanically. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | 1 dict lookup + 1 bool compare per clear | 1 dict lookup + 1 int compare + 0/1 int credit per clear | 16.6ms — ample |
| Memory | `Dictionary[int, bool]` (~40B/entry) | `Dictionary[int, int]` (~48B/entry) | 512MB — negligible delta (≤5 entries for MVP 5 floors) |
| Load Time | N/A | N/A | N/A |
| Network | N/A (offline game) | N/A | N/A |

## Migration Plan

**MVP ships this ADR from day one.** No live saves exist that were authored against the superseded boolean gate.

If a post-MVP retrofit ever becomes necessary (e.g., a hotfix retrofits the reclaim into a v1.0-shipped build that used the boolean gate):

1. On save load, detect if `floors_cleared_bonus_awarded: Dictionary[int, bool]` is present.
2. For each entry with `true`, set `floor_clear_bonus_credited[floor_index] = FLOOR_CLEAR_BONUS[floor_index]` (full bonus — because the shipped MVP never used LOSING halving on clears).
3. Remove the old field on first save-back.
4. Document the migration as a Save/Load addendum and bump the save schema version (Save/Load Rule 10 integration).

**Rollback plan**: If this ADR proves wrong (e.g., first-playtest shows players never return to reclaim, OR feels game-y rather than cozy), revert to Alternative 1 (exempt first-clears from LOSING halving). Rollback is: flip `attribute_floor_clear_bonus` to ignore `losing_run`, migrate any non-full credited entries up to full in-place, mark this ADR Superseded.

## Validation Criteria

- [ ] Economy GDD Pass 5B rewrites §C.2.3 to use `floor_clear_bonus_credited: Dictionary[int, int]`.
- [ ] Economy AC H-03 and AC H-14 rewritten against the monotonic-credit semantics; `try_award_floor_clear` worked-example table (six rows above) embedded verbatim.
- [ ] Orchestrator AC-ORC-04 adds Sub-AC "losing-first-clear-then-win-credits-delta" verifying a LOSING clear followed by a WIN clear credits exactly `FLOOR_CLEAR_BONUS[floor_index]` total (in two installments).
- [ ] Orchestrator AC-ORC-05 Sub-AC "05-losing-first-clear" amended to note the amount credited is the "floor for this call, not for the lifetime."
- [ ] Orchestrator §E.5 (LOSING re-run after first-clear) rewritten — currently says the second call "is no-op." With this ADR, it says: "if the new call's `bonus_amount` exceeds already-credited, the delta is credited; else no-op."
- [ ] A new Orchestrator §E.15 (or similar) walks the full LOSING-then-WIN sequence with numbers.
- [ ] Save/Load §Rule 11 updated to reference the new field shape.
- [ ] `design/registry/entities.yaml` — `FLOOR_CLEAR_BONUS` `referenced_by` list includes this ADR; `LOSING_RUN_LOOT_FACTOR` notes mention the re-claim semantic.
- [ ] Player-facing Return-to-App copy (narrative team) distinguishes "LOSING first clear — 250g, +250g pending on win" from "clear completed — reclaimed 250g."

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/dungeon-run-orchestrator.md` §C.6, §E.5 | Dungeon Run Orchestrator | "Per-lifetime idempotency must not permanently forfeit content on LOSING runs" | Monotonic credit — full bonus is eventually recoverable on a WIN |
| `design/gdd/dungeon-run-orchestrator.md` §H AC-ORC-04 | Dungeon Run Orchestrator | "LOSING_RUN_LOOT_FACTOR end-to-end must reconcile with Economy idempotency" | Sub-AC added: re-claim on WIN credits the delta |
| `design/gdd/economy-system.md` §C.2.3, AC H-03, AC H-14 | Economy | "Per-lifetime first-clear gate must prevent exploit while honouring 'no fail state' pillar" | Integer running-total replaces boolean; anti-exploit preserved (monotonic ceiling), reclaim enabled (delta-credit) |
| Game concept (pillar statement) | Vision | "'No fail state — losing run returns partial loot'" | LOSING first-clear returns half immediately + half pending; no content is permanently destroyed |
| `design/gdd/combat-resolution.md` Rule 9 (+ Pass 4B-Economy supersession) | Combat Resolution | "`LOSING_RUN_LOOT_FACTOR = 0.5` applies to kill gold + floor-clear bonus" | Kill-gold halving unchanged; floor-clear halving now has a reclaim path (does not violate Rule 9 — Rule 9 specifies the multiplier at emission time, not the lifetime credited total) |

## Amendments

### Amendment 1 — Multi-biome ledger widening (Sprint 17, 2026-05-14)

**Trigger**: S17-M6 progression-chain playtest revealed that boss floors in non-Forest-Reach biomes don't advance after kill resolution. Root cause: Economy's `_floor_clear_bonus_credited` ledger was authored against the MVP single-biome assumption — keyed by `floor_index: int` alone (range 1..5). Sprint 16 shipped 5 additional biomes (Whispering Crags, Sunken Ruins, Frostmire, Ember Wastes, Hollow Stair), each with its own F1–F5. The int-keyed ledger collided across biomes: clearing Forest Reach F5 (credited[5] = 2500) silently blocked Frostmire F5's first-clear gate (bonus 2500 ≤ already 2500 → `try_award_floor_clear` returns false → orchestrator's `awarded` stays false → `floor_cleared_first_time` is never emitted → `FloorUnlockSystem._unlock_state[<biome>]` never advances past 0 → the biome-progression chain that depends on F5 clears never fires).

**Decision**: Widen the monotonic-credit predicate from `floor_index → bonus` to `(biome_id, floor_index) → bonus`. The credit-the-gap semantic is preserved per-biome — LOSING-then-WIN reclaim still works inside one biome, and the milestone signal (`first_clear_awarded`) still fires once per genuine first-clear, but now per (biome, floor) pair.

**Scope of change**:
- `Economy._floor_clear_bonus_credited` storage: `Dictionary[int, int]` → `Dictionary[String, int]`, keys are `"<biome_id>_f<floor_index>"` (e.g. `"forest_reach_f1"`, `"frostmire_f5"`).
- `Economy.try_award_floor_clear(floor_index, bonus_amount)` → `try_award_floor_clear(biome_id, floor_index, bonus_amount)` (biome_id as new first param; empty-string biome_id is rejected via `push_error`).
- `Economy.first_clear_awarded(floor_index)` signal payload → `first_clear_awarded(biome_id, floor_index)`.
- `Economy.is_first_clear_awarded(floor_index)` → `is_first_clear_awarded(biome_id, floor_index)`.
- `Economy._offline_pending_first_clears: Array[int]` → `Array[Array]` with `[biome_id, floor_index]` tuples.
- `DungeonRunOrchestrator` call site at `dungeon_run_orchestrator.gd:1067` passes `_dispatched_biome_id` to the new `try_award_floor_clear` signature.

**Save schema migration**: `Economy.SAVE_SCHEMA_VERSION` bumped from 1 → 2. `load_save_data` accepts both v1 and v2 payloads: v1 int keys are prefixed with `"forest_reach_f"` since Sprint 11-era saves predate multi-biome content. The migration is transparent — players returning from v1 saves see their progression intact and their previously-credited Forest Reach floors carry over correctly.

**Anti-exploit invariant preserved**: the monotonic-credit ceiling still applies per `(biome, floor)` pair — clearing Frostmire F5 twice still credits gold once. The Pass-3 "LOSING-grind seam" remains bounded by `FLOOR_CLEAR_BONUS[floor_index]` per biome. No new exploit surface created.

**Regression test**: `tests/integration/economy/multi_biome_floor_clear_ledger_test.gd` (6 tests) covers: same-floor-index credits in different biomes both first-clear-fire (the broken case); ledger keys are namespaced; in-biome monotonic still holds; LOSING-then-WIN reclaim doesn't leak across biomes; save/load round-trip preserves biome-keyed ledger; legacy v1 saves auto-migrate to v2.

**Related**: ADR-0017 (Sprint 15+ deferral list amendment) — this fix lands during the Sprint 17 matchup-hints UI sweep and the S17-M6 progression-chain playtest, which is the load-bearing closure gate for the Sprint 16 multi-biome content drop.

## Related

- ADR-0001 (companion — mid-run reassignment MVP lock, Pass 5A decision 17a)
- `design/gdd/economy-system.md` §C.2.3, §C.2.3a — existing per-lifetime gate design (to be rewritten in Pass 5B per this ADR)
- `design/gdd/dungeon-run-orchestrator.md` §C.6 (three-layer idempotency), §E.5 (LOSING re-run contract), §H AC-ORC-04 / AC-ORC-05
- `design/gdd/combat-resolution.md` Rule 9 + Pass 4B-Economy A2 supersession note
- `design/gdd/save-load-system.md` Rule 10 / Rule 11 (save schema integration)
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — independent re-review 2026-04-20 (BLOCKING-2 17b) + Pass 5A (this decision)
- `design/gdd/reviews/economy-system-review-log.md` — Pass 5B entry will cite this ADR
