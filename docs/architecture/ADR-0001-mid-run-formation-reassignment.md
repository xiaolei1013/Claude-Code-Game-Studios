# ADR-0001: Mid-Run Formation Reassignment — Option (a) MVP Lock

## Status

Accepted

## Date

2026-04-20

## Last Verified

2026-04-20

## Decision Makers

- Author (user) — final decision
- creative-director — adjudication (synthesis of Pass 5A inputs)
- game-designer (BLOCKING-1, re-review 2026-04-20)
- systems-designer — FSM + snapshot implications
- godot-gdscript-specialist — signal boundary

## Summary

When the player commits a mid-run hero swap via `formation_reassignment_committed`, the Dungeon Run Orchestrator ends the current run immediately and restarts a new dispatch with the new formation (option (a) per Orchestrator C.7). This ADR locks (a) as the MVP default, documents the known mid-F5-boss progress-loss risk as an accepted trade-off, and names option (c) deferred queue as the V1.1 upgrade path if playtest shows the penalty is unacceptable.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting (signal-driven state machine) |
| **Knowledge Risk** | LOW |
| **References Consulted** | `design/gdd/dungeon-run-orchestrator.md` §C.7, §E.3; `design/gdd/combat-resolution.md` I.Q7 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond Godot signal emission / instance-DI (already covered by AC-ORC-06) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Orchestrator AC-ORC-06 (mid-run reassignment ends run); Formation Assignment #17 signal contract |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before Formation Assignment GDD #17 can ship — #17 embeds the read/write signal split this ADR depends on. |

## Context

### Problem Statement

The Orchestrator's state machine must decide what happens when `formation_reassignment_committed(new_formation: Array[HeroInstance])` fires while a run is active (`ACTIVE_FOREGROUND` or `ACTIVE_OFFLINE_REPLAY`). The decision affects: (1) Combat's stateless contract (no mid-dispatch snapshot mutation allowed), (2) Pillar 1 foreground/offline parity, (3) Pillar 3 cozy feel (progress loss is anti-cozy), and (4) the MVP implementation budget.

### Current State

Orchestrator §C.7 enumerates three options (Pass 4C):

- **(a) End run + restart**: simplest; loses progress on the active loop; Pillar 1 preserved.
- **(b) Reject until recall**: blocks a natural action; least cozy; never selected.
- **(c) Deferred queue**: highest cozy score; requires `queued_formation` field on `RunSnapshot` + dispatch-boundary logic.

The Pass 4C browse/commit signal split (`formation_browse_opened` read-only vs. `formation_reassignment_committed` write) already prevents the *accidental* run-end case. What remains is the *intentional* mid-run reassignment case — most notably the 170s F5 boss fight where a player might legitimately want to swap in a specialist late in the fight.

The independent re-review (2026-04-20, game-designer BLOCKING-1) surfaced that even with the signal split, committing a reassignment 140s into an F5 boss fight destroys ~140s of player progress. This is a real cost, not a theoretical one.

### Constraints

- Combat Resolution (#11) is stateless by contract. No mid-dispatch snapshot mutation.
- Pillar 1 (foreground/offline parity) requires that any run state transition be deterministic from the snapshot + input range alone.
- MVP budget: cannot ship option (c) in the vertical slice — `queued_formation` field + dispatch-boundary branching is ~1 story of additional work plus test coverage.
- Formation Assignment (#17) is undesigned. Signal emission behaviour will be specified in that GDD but must match this ADR's contract.

### Requirements

- The reassignment path must never violate Combat's stateless contract (no mid-loop snapshot mutation).
- The reassignment path must preserve foreground/offline parity (Pillar 1 AC-ORC-09).
- The MVP must be shippable in the vertical slice without waiting on Formation Assignment GDD #17 polish.
- The chosen option's progress-loss risk must be explicit in the GDD (not buried in an options table).

## Decision

**Option (a) "End run + restart dispatch" is the MVP default.**

When `formation_reassignment_committed(new_formation)` fires during `ACTIVE_FOREGROUND` or `ACTIVE_OFFLINE_REPLAY`, the Orchestrator transitions:

```
ACTIVE_FOREGROUND / ACTIVE_OFFLINE_REPLAY
  → RUN_ENDED                       (old dispatch terminated; partial-loop progress discarded)
  → DISPATCHING                     (new formation validated)
  → ACTIVE_FOREGROUND               (new dispatch begins with the new formation)
```

All per-dispatch idempotency flags on the new `RunSnapshot` reset (`floor_clear_emitted = false`; `loop_counter = 0`; `last_emitted_tick = dispatched_at_tick`). Economy's per-lifetime gate (`floors_cleared_bonus_awarded[floor_index]`) still prevents bonus double-payment on re-clears (see §C.6).

The `MID_RUN_REASSIGN_WARNING_ENABLED = true` tuning knob gates a UX confirmation dialog fired *before* the commit signal. Players see "Reassigning will end your current run" and can cancel. The knob exists so the dialog can be silenced once playtest validates the option-(a) semantics are understood.

### Architecture

```
[Formation Assignment Screen #17]
          |
          | formation_reassignment_committed(new_formation)   [write signal — intent-confirmed only]
          v
[DungeonRunOrchestrator]
          |
          | (active run?)
          |    yes -> RUN_ENDED ("reassigned") -> DISPATCHING(new_formation) -> ACTIVE_FOREGROUND
          |    no  -> DISPATCHING(new_formation) -> ACTIVE_FOREGROUND        [no transition from ACTIVE_*]
          v
[RunSnapshot (new)] -- deep-copied formation, flags reset, dispatched_at_tick set
```

### Key Interfaces

```gdscript
# DungeonRunOrchestrator
signal formation_reassignment_committed(new_formation: Array[HeroInstance])
# connected at _ready from Formation Assignment (#17)

func _on_formation_reassignment_committed(new_formation: Array[HeroInstance]) -> void:
    match state:
        State.ACTIVE_FOREGROUND, State.ACTIVE_OFFLINE_REPLAY:
            _transition_to_run_ended("reassigned")          # RUN_ENDED
            _transition_to_dispatching(new_formation)       # DISPATCHING -> ACTIVE_FOREGROUND
        State.NO_RUN, State.RUN_ENDED:
            _transition_to_dispatching(new_formation)
        State.DISPATCHING:
            # Rare; let the in-flight dispatch complete, then re-dispatch.
            # Defensive: queue for next cycle; documented in C.1 matrix.
            push_warning("DungeonRunOrchestrator: reassignment during DISPATCHING; deferred to next cycle")
```

### Implementation Guidelines

- The read/write signal split (`formation_browse_opened` vs `formation_reassignment_committed`) is enforced at the **Formation Assignment Screen boundary**, not the Orchestrator. The Orchestrator only listens to the write signal.
- Partial-loop progress on the old dispatch is **not credited** on reassignment. This is the accepted trade-off (see Risks).
- The `RUN_ENDED` → `DISPATCHING` transition must deep-copy the new formation (`formation.duplicate(true)`), matching the existing DISPATCHING deep-copy invariant (AC-ORC-08).
- A playtest-facing telemetry counter `mid_run_reassignments_during_floor_5_boss` is RECOMMENDED to detect whether option (c) upgrade pressure justifies V1.1.

## Alternatives Considered

### Alternative 1: Option (b) — Reject until player explicitly recalls

- **Description**: Reassignment during an active run is blocked at the Orchestrator boundary; `validation_failed("reassignment_blocked_during_run", {})` fires; the player must press a separate Recall button first.
- **Pros**: Simplest engine correctness — no mid-dispatch snapshot mutation and no progress loss through inadvertent paths.
- **Cons**: Blocks a natural player action; produces a potentially confusing UI dead state; violates Pillar 3 cozy feel; the player needs to learn a "recall first" workflow that serves no gameplay purpose.
- **Estimated Effort**: Lowest (no state transitions needed).
- **Rejection Reason**: Pillar 3 violation. The friction is purely a programming convenience, not a gameplay expression.

### Alternative 2: Option (c) — Deferred queue (V1.1 upgrade path, not MVP)

- **Description**: On commit, the new formation is stored in `RunSnapshot.queued_formation: Array[HeroInstance]` (new nullable field). When the current run ends naturally (floor cleared, recalled, or offline batch completes), the `RUN_ENDED → DISPATCHING` transition picks up the queued formation instead of the Roster's current formation.
- **Pros**: Most cozy — player can plan their next formation during an active run with zero progress penalty. Best Pillar 3 expression.
- **Cons**: Adds a persistent `queued_formation` field to the snapshot (save/load contract change — Save/Load AC-SL-13 would need an addendum). Adds a branch in `RUN_ENDED → DISPATCHING` transition. Requires additional test coverage for "queued formation survives save/load suspend/resume."
- **Estimated Effort**: +1 story vs. option (a) for MVP; test coverage is the bigger cost than the code.
- **Rejection Reason (for MVP only)**: Shippability. Option (a) is sufficient for the vertical slice. Option (c) is the named V1.1 upgrade path — recorded as a named future ADR in the Related section, not a rejected alternative.

## Consequences

### Positive

- Ships in the vertical slice without waiting on Formation Assignment #17 polish.
- Preserves Combat's stateless contract — no code duplication between Combat and Orchestrator for the "snapshot mutated mid-loop" path.
- `AC-ORC-06` is writeable against a single, simple state transition sequence.
- The browse/commit signal split (Pass 4C) already shields the most common accidental-trigger path, so the remaining progress-loss exposure is bounded to intentional reassignment during an active run.

### Negative

- **Intentional mid-F5-boss reassignment destroys progress** on the active loop. This is the game-designer BLOCKING-1 risk that could not be adjudicated away. A player 140s into a 170s boss fight who swaps in a specialist loses the full 140s. The `MID_RUN_REASSIGN_WARNING_ENABLED` dialog mitigates — does not eliminate — this risk.
- The `RUN_ENDED → DISPATCHING` auto-chain is a two-transition path, adding one extra state entry over a simpler "replace formation in place" design. Invisible to the player; adds one extra test-matrix cell per sub-AC.

### Neutral

- The signal boundary is owned by Formation Assignment (#17), not the Orchestrator. Makes Formation Assignment GDD a hard dependency for `AC-ORC-06` end-to-end verification (intermediate: Orchestrator test uses a signal-emit stub).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Player loses 140s+ of F5 boss progress through intentional mid-boss swap | Medium (playtest-dependent) | High (emotional: feels like a punishment) | `MID_RUN_REASSIGN_WARNING_ENABLED` UX dialog + V1.1 option (c) upgrade path named and estimated |
| Player hits the auto-end accidentally through a third-party signal path (bug in Formation Assignment) | Low | High (silent run destruction) | Browse/commit signal split enforced at #17 boundary; Orchestrator does NOT listen to `formation_browse_opened` (confirmed in AC-ORC-06 test + §C.9 Dependencies row) |
| V1.1 option (c) is never upgraded because playtest pain is under-reported | Medium | Medium (slow Pillar 3 erosion) | Telemetry counter `mid_run_reassignments_during_floor_5_boss` tracked; reviewed after first vertical-slice playtest |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A (no mid-run work) | One extra state transition per commit (~sub-millisecond) | 16.6ms |
| Memory | N/A | No new persistent state | 512MB PC / 256MB mobile |
| Load Time | N/A | N/A | N/A |

## Migration Plan

Not applicable — MVP design decision, no existing implementation to migrate from.

**Rollback plan**: If playtest shows option (a) is unplayable on F5 bosses, re-open this ADR, flip status to Superseded, write ADR-0003 adopting option (c) for V1.0 (not V1.1). Add `queued_formation` to `RunSnapshot` with a Save/Load Rule 15 addendum. Reassignment code path collapses to one transition.

## Validation Criteria

- [ ] Orchestrator §C.7 explicitly marks option (a) as "MVP lock" with an inline risk callout (not only a table footnote).
- [ ] Orchestrator §C.7 names option (c) as the V1.1 upgrade path with a one-line implementation note.
- [ ] AC-ORC-06 verifies the full `ACTIVE_* → RUN_ENDED → DISPATCHING → ACTIVE_FOREGROUND` chain within one frame.
- [ ] `MID_RUN_REASSIGN_WARNING_ENABLED` appears in §G.1 Tuning Knobs with a playtest-facing rationale row.
- [ ] Telemetry counter `mid_run_reassignments_during_floor_5_boss` scoped into the vertical-slice analytics list (not blocking for MVP approval, but must appear as a named follow-up).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/dungeon-run-orchestrator.md` §C.7 | Dungeon Run Orchestrator | "Mid-run formation reassignment policy must be explicit and testable" | Locks option (a); specifies state transition chain; names V1.1 upgrade path |
| `design/gdd/dungeon-run-orchestrator.md` §H AC-ORC-06 | Dungeon Run Orchestrator | "Mid-run reassignment ends run + restarts dispatch within one frame" | Defines the transition sequence the AC verifies against |
| `design/gdd/combat-resolution.md` I.Q7 | Combat Resolution | "What happens when formation changes mid-run?" | Resolved: option (a) — end + restart; Combat statelessness preserved |
| `design/gdd/dungeon-run-orchestrator.md` §G.1 | Dungeon Run Orchestrator | "`MID_RUN_REASSIGN_WARNING_ENABLED` tuning knob rationale" | Establishes the UX dialog as a player-facing safety net |

## Related

- `design/gdd/dungeon-run-orchestrator.md` §C.7 — canonical mid-run reassignment policy (this ADR is the authority)
- `design/gdd/dungeon-run-orchestrator.md` §E.3 — edge-case walkthrough
- `design/gdd/dungeon-run-orchestrator.md` §H AC-ORC-06 — verification criterion
- `design/gdd/combat-resolution.md` I.Q7 — originating open question
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — Pass 4C (signal split), independent re-review 2026-04-20 (BLOCKING-1 17a), Pass 5A (this decision)
- ADR-0002 (companion — LOSING first-clear halving policy, Pass 5A decision 17b)
- **Future ADR**: V1.1 option (c) deferred queue — to be written if playtest telemetry shows intentional mid-boss reassignment is a live pain point
