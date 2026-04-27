# Story 009: Edge cases — empty formation, bad class_id, signal-free invariants

> **Epic**: combat-resolution
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §E.5
**Requirements**: TR-combat-018, 019, 020, 027, 030
**Governing ADR**: ADR-0010
**Decision**: Empty formation returns empty `CombatBatchResult` + `push_warning("empty formation")`; no division by zero. Unresolvable `class_id` (DataRegistry returns null) is silently skipped — contributes 0 to dps and hp; logs via optional `error_logger: Callable` DI dep (Orchestrator owns the logger). Combat emits no signals (TR-030); Orchestrator owns "already-fired" idempotency flag for first_clear (TR-018). No RNG / no time-dependent reads / no float accumulation across calls (TR-027).

**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] TR-018: Combat reports `first_clear_in_range` markers per-call; the once-per-dispatch idempotency flag lives on the Orchestrator (NOT in Combat)
- [ ] TR-019: `compute_offline_batch(empty_formation, ...)` → empty CombatBatchResult; `push_warning("[CombatResolver] empty formation")`; no `0/0` division
- [ ] TR-020: hero with unresolvable class_id (`DataRegistry.resolve("classes", "ghost")` returns null) → contributes 0 to formation_dps, 0 to formation_total_hp; calls injected `error_logger.call(message)` if logger is non-null
- [ ] TR-027: source grep `combat_resolver.gd` + `default_combat_resolver.gd` for `randi()`, `randf()`, `Time.`, `OS.get_ticks` → zero hits
- [ ] TR-030 reaffirmed (also covered by Story 008): zero signal declarations in resolver source

## QA Test Cases

- empty formation → empty result + push_warning logged
- 3-hero formation, all with unresolvable class_ids → behaves as empty (TR-019 path)
- 3-hero formation, 1 unresolvable → other 2 contribute; bad hero contributes 0 dps + 0 hp; error_logger called once with class_id in message
- Spy error_logger Callable receives `[message_string]` per bad class_id
- Source grep for RNG/time APIs → 0 hits

## Test Evidence
**Required**: `tests/unit/combat_resolution/edge_cases_and_invariants_test.gd`

## Dependencies
- Depends on: Stories 001-007 (resolver pipeline)
- Unlocks: pre-launch QA sign-off (defensive paths covered)
