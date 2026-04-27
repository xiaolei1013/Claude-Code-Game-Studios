# Story 007: Floor-clear bonus + once-per-dispatch first-clear + 3-layer idempotency

> **Epic**: dungeon-run-orchestrator
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-015, TR-orchestrator-016, TR-orchestrator-017, TR-orchestrator-018

**Governing ADRs**: ADR-0002 (Losing-First-Clear Reclaimable on Win) + ADR-0013 (Economy)
**Decision Summary**: `FLOOR_CLEAR_BONUS` is 1-based indexed [1..5]; index 0 is undefined sentinel; assert `floor_index in [1,5]`. Per-dispatch `floor_clear_emitted: bool` gates the `floor_cleared_first_time` emission; reset to `false` on new dispatch. **3-layer idempotency**: Combat stateless markers (Combat layer) + Orchestrator per-dispatch flag (this story) + Economy per-lifetime monotonic-credit (`Economy.try_award_floor_clear`). Orchestrator calls `Economy.add_gold()` on each kill AND `Economy.try_award_floor_clear(floor_index, bonus_amount)` once per first-clear with LOSING factor pre-applied.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (idempotency contract across 3 systems)

---

## Acceptance Criteria

- [ ] TR-015: `FLOOR_CLEAR_BONUS` 1-indexed [1..5]; index 0 undefined; assert raises on out-of-range
- [ ] TR-016: `run_snapshot.floor_clear_emitted` gates first-clear; reset to false on each new dispatch
- [ ] TR-017: 3-layer idempotency: combat markers + orchestrator flag + Economy per-lifetime credit (verify all 3 layers prevent double-credit)
- [ ] TR-018: `Economy.try_award_floor_clear(floor_index, bonus_amount)` invoked once per first-clear with LOSING factor pre-applied

---

## Implementation Notes

```gdscript
const FLOOR_CLEAR_BONUS: Dictionary = {1: 100, 2: 250, 3: 500, 4: 1000, 5: 2500}  # 1-indexed

func _check_floor_clear() -> void:
    if run_snapshot.floor_clear_emitted:
        return  # already emitted this dispatch
    if not _is_floor_complete():
        return
    # First-clear gate passed
    var floor_index: int = _resolve_floor(run_snapshot.floor_id).index
    assert(floor_index >= 1 and floor_index <= 5, "floor_index out of range: %d" % floor_index)
    var bonus: int = FLOOR_CLEAR_BONUS.get(floor_index, 0)
    if run_snapshot.losing_run:
        bonus = floori(float(bonus) * LOSING_RUN_LOOT_FACTOR)
    # Layer 3: Economy.try_award_floor_clear handles per-lifetime monotonic credit
    var awarded: bool = Economy.try_award_floor_clear(floor_index, bonus)
    run_snapshot.floor_clear_emitted = true  # Layer 2: per-dispatch
    if awarded:
        # Genuinely first-ever clear (Economy gate passed)
        floor_cleared_first_time.emit(floor_index, _get_biome_id(), run_snapshot.losing_run)
```

Reset `floor_clear_emitted = false` whenever a new RunSnapshot is built (Story 004).

---

## QA Test Cases

- **TR-015 1-indexed**: assert FLOOR_CLEAR_BONUS[1] is defined; FLOOR_CLEAR_BONUS[0] is missing/undefined
- **TR-015 range assert**: feeding floor_index=0 or floor_index=6 hits assertion in debug
- **TR-016 once per dispatch**: same dispatch with floor cleared twice (re-entry of `_check_floor_clear`) → emit fires only once
- **TR-016 reset on new dispatch**: dispatch A clears floor 1 → dispatch B (new) → floor_clear_emitted reset to false → can fire again
- **TR-017 3-layer**: with combat markers in place AND orchestrator flag set AND Economy already credited — no double-credit; gold delta = 0
- **TR-018 LOSING factor**: losing_run=true on floor 1 → bonus = 50 (100 * 0.5); economy.try_award_floor_clear(1, 50)

---

## Test Evidence

**Type**: Integration | **Required**: `tests/integration/dungeon_run_orchestrator/floor_clear_idempotency_test.gd`

---

## Dependencies

- Depends on: Story 002, 004, 006. Economy from Sprint 2 + S3-M1 (try_award_floor_clear monotonic ledger).
- Unlocks: Story 009 (offline replay reuses _check_floor_clear), Story 011 (parity check between FG and offline first-clear emission)
