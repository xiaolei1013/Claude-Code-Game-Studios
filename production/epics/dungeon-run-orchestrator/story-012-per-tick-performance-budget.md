# Story 012: Per-tick performance budget AC

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete (perf bench + evidence shipped 2026-05-08; AC TR-019 met with ~133× headroom on dev hardware; mobile min-spec deferred to playtest per story spec.)
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

- [x] TR-019: `_on_tick_fired` p95 latency ≤ 2ms on dev hardware (mobile min-spec verification deferred to playtest) — **MET** with ~133× headroom (burst 5-kill p95 = 15µs vs 2_000µs budget; steady-state p99 = 2µs). Evidence: `production/qa/evidence/orchestrator-tick-perf-2026-05-08.md`.

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

**Status**: [x] Both evidence artifacts shipped 2026-05-08:
- `tests/perf/orchestrator_per_tick_perf_test.gd` — 4 test functions, 4/4 PASS. (Note: file landed at `tests/perf/orchestrator_per_tick_perf_test.gd` rather than the spec's nested `tests/performance/dungeon_run_orchestrator/per_tick_perf_test.gd` path — `tests/perf/` is the canonical project convention matching existing `combat_resolver_perf_test.gd` + `matchup_resolver_perf_test.gd`. Story spec's outdated nested path was an early-draft assumption.)
- `production/qa/evidence/orchestrator-tick-perf-2026-05-08.md` — full p50/p95/p99/max numbers across 3 tick-shape configurations (steady-state 0-kill, burst 5-kill, mixed alternating) + methodology + min-spec follow-up note.

Numbers summary (Apple Silicon, headless, N=10_000): steady-state p99=2µs, burst-5-kill p95=15µs, mixed-alternating p95=12µs — all ≥ 100× under the 2_000µs budget. Mobile min-spec re-run flagged for playtest but not blocking.

---

## Completion Notes

**Completed**: 2026-05-08
**Criteria**: 1/1 AC met (TR-019 perf budget) with ~133× headroom on dev hardware.
**Test Evidence**: `tests/perf/orchestrator_per_tick_perf_test.gd` (4 functions, 4/4 PASS) + `production/qa/evidence/orchestrator-tick-perf-2026-05-08.md` (numerical evidence + methodology + deferred min-spec note).
**Files added**:
- `tests/perf/orchestrator_per_tick_perf_test.gd` — new perf benchmark with 3 tick-shape configurations + 1 mean check. Uses an inline `_StubResolver` that returns a pre-built `CombatTickEvents` per call to isolate orchestrator-side cost from resolver-side cost (the resolver itself is benchmarked separately by combat-resolution/story-010).
- `production/qa/evidence/orchestrator-tick-perf-2026-05-08.md` — evidence doc with p50/p95/p99/max across all 3 configurations, hardware/methodology disclosure, min-spec follow-up note, and stub-resolver caveat explaining why the resolver-side cost isn't included here.
**Deviations**:
1. Test file path differs from story spec — landed at `tests/perf/orchestrator_per_tick_perf_test.gd` (canonical project convention, matching existing `combat_resolver_perf_test.gd` + `matchup_resolver_perf_test.gd`) rather than the spec's nested `tests/performance/dungeon_run_orchestrator/per_tick_perf_test.gd`. The Test Evidence Status block above documents this; spec was an early-draft assumption that didn't match landed convention.
2. Mobile min-spec verification deferred to playtest per story spec — explicitly anticipated, not a closure gap.
3. The `tests/perf/` directory is not auto-discovered by `gdunit4_runner.gd` (which scans `tests/unit/` + `tests/integration/` only). The new test file runs successfully via direct `--add` invocation but won't show up in CI's full-suite run. This matches the existing perf-test pattern in this project.
**Code Review**: Solo mode — `/code-review` skipped per project review-mode.txt.

---

## Dependencies

- Depends on: Stories 001-009 (full orchestrator surface needed for realistic perf measurement).
- Unlocks: Vertical Slice readiness — orchestrator confirmed within frame budget.
