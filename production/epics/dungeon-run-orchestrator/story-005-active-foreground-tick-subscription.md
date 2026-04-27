# Story 005: ACTIVE_FOREGROUND tick subscription + per-tick combat call + duplicate-tick guard

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-007, TR-orchestrator-008, TR-orchestrator-009

**Governing ADRs**: ADR-0010 (Combat Resolver Snapshot) + ADR-0005 (Time System Dual-Clock)
**Decision Summary**: Orchestrator subscribes to `TickSystem.tick_fired(n)` ONLY in ACTIVE_FOREGROUND; unsubscribes on exit. `_on_tick_fired(current_tick)` calls `combat_resolver.emit_events_in_range(formation, floor, last_emitted, current_tick)`. Clock-rewind guard: if `current_tick <= last_emitted`, early return; warn on strict rewind only (current < last).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (cross-system signal subscription + monotonic invariant)

---

## Acceptance Criteria

- [ ] TR-007: subscribe to `TickSystem.tick_fired` on entering ACTIVE_FOREGROUND; disconnect on exit
- [ ] TR-008: `_on_tick_fired(n)` calls `combat_resolver.emit_events_in_range(formation, floor, last_emitted, n)`
- [ ] TR-009 dup-tick: if `n <= last_emitted`, early return (no combat call); on strict rewind (`n < last_emitted`) emit push_warning

---

## Implementation Notes

```gdscript
func _enter_active_foreground() -> void:
    if not TickSystem.tick_fired.is_connected(_on_tick_fired):
        TickSystem.tick_fired.connect(_on_tick_fired)

func _exit_active_foreground() -> void:
    if TickSystem.tick_fired.is_connected(_on_tick_fired):
        TickSystem.tick_fired.disconnect(_on_tick_fired)

func _on_tick_fired(n: int) -> void:
    if state != State.ACTIVE_FOREGROUND:
        return  # defensive
    if run_snapshot == null:
        return
    if n <= run_snapshot.last_emitted_tick:
        if n < run_snapshot.last_emitted_tick:
            push_warning("[Orchestrator] strict rewind: current=%d < last=%d" % [n, run_snapshot.last_emitted_tick])
        return  # duplicate-tick guard
    var events: Array = _combat_resolver.emit_events_in_range(
        run_snapshot.formation_snapshot,
        _resolve_floor(run_snapshot.floor_id),
        run_snapshot.last_emitted_tick,
        n
    )
    run_snapshot.current_tick = n
    run_snapshot.last_emitted_tick = n
    _process_kill_events(events)  # Story 006 implements
```

Connect/disconnect MUST be matched (no leaked connections after RUN_ENDED). Use `is_connected` guard so re-entry is safe.

---

## QA Test Cases

- **TR-007 subscribe lifecycle**: enter ACTIVE_FOREGROUND → tick_fired.is_connected() true; exit → false
- **TR-008 combat call**: spy combat_resolver counts emit_events_in_range calls; fire 5 ticks → 5 calls (1 per tick)
- **TR-009 dup-tick guard**: tick_fired(5) then tick_fired(5) — second call is no-op (combat call count = 1)
- **TR-009 rewind warn**: tick_fired(5) then tick_fired(3) — push_warning emitted; no combat call

---

## Test Evidence

**Type**: Integration | **Required**: `tests/integration/dungeon_run_orchestrator/foreground_tick_subscription_test.gd`

---

## Dependencies

- Depends on: Story 002 (autoload + resolvers), Story 004 (run_snapshot exists). TickSystem from Sprint 1.
- Unlocks: Story 006 (kill event processing), Story 011 (offline replay parity), Story 008 (mid-run reassignment unsubscribes)
