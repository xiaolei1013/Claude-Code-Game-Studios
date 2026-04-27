# Story 012: Per-tick performance budget AC

> **Epic**: dungeon-run-orchestrator
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic (Performance)
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-019

**Governing ADRs**: ADR-0010 (Combat Resolver Snapshot — performance budget delegation)
**Decision Summary**: Per-tick performance budget: ≤2ms p95 on min-spec mobile. Typical 0-1 kills per tick; cache reads + 1 Economy.add_gold call per kill + signal emissions.

**Engine**: Godot 4.6 | **Risk**: LOW (small hot-path, well-bounded operations)

---

## Acceptance Criteria

- [ ] TR-019: `_on_tick_fired` p95 latency ≤ 2ms on dev hardware (mobile min-spec verification deferred to playtest)

---

## Implementation Notes

This story is pure verification — no new behavior. Add a performance test that:
1. Sets up a wired orchestrator with full run_snapshot (formation, floor with 100-entry kill_schedule)
2. Calls `_on_tick_fired(n)` 10000 times measuring `Time.get_ticks_usec()` deltas
3. Computes p95 latency
4. Asserts p95 ≤ 2000µs (2ms)

If p95 exceeds budget, profile via the engine's built-in profiler and identify hot path:
- Likely candidates: Dictionary lookups in matchup_cache (should be O(1)), signal emit overhead, Economy.add_gold call.
- Mitigations: batch signal emissions, defer Economy.add_gold to end-of-tick aggregate.

For mobile min-spec verification: add a manual playtest step on Steam Deck (1280×800 native) capturing per-tick profiler output. Document the actual measurement in `production/qa/evidence/`.

---

## QA Test Cases

- **TR-019 p95 budget**: 10000 calls of `_on_tick_fired` on dev hardware
  - Given: orchestrator in ACTIVE_FOREGROUND with full run_snapshot
  - When: 10000 ticks fired with varied kill counts
  - Then: p95 ≤ 2ms; mean ≤ 1ms; max documented (no hard cap on max — variance acceptable)
  - Edge cases: high-kill ticks (5+ kills in single tick) — assert still under p95 bound

---

## Test Evidence

**Type**: Logic (Performance) | **Required**: `tests/performance/dungeon_run_orchestrator/per_tick_perf_test.gd` + manual playtest evidence at `production/qa/evidence/orchestrator-tick-perf-[date].md` for mobile min-spec.

---

## Dependencies

- Depends on: Stories 001-009 (full orchestrator surface needed for realistic perf measurement).
- Unlocks: Vertical Slice readiness — orchestrator confirmed within frame budget.
