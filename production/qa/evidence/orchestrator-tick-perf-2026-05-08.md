# Orchestrator `_on_tick_fired` perf evidence — 2026-05-08

**Story**: `production/epics/dungeon-run-orchestrator/story-012-per-tick-performance-budget.md`
**AC**: TR-orchestrator-019 — `_on_tick_fired` p95 latency ≤ 2 ms on dev hardware (mobile min-spec verification deferred to playtest).
**Test file**: `tests/perf/orchestrator_per_tick_perf_test.gd`

## Hardware / runtime

- **Engine**: Godot 4.6.1.stable.mono.official.14d19694e
- **Mode**: `--headless`, GdUnit4 CmdTool harness
- **Host**: macOS, Apple Silicon (Darwin 25.4.0). NOT minimum-spec mobile hardware — see "Min-spec follow-up" section.

## Methodology

10_000 sequential `_on_tick_fired(n)` calls per benchmark configuration against
a fully-armed orchestrator (run_snapshot + combat_snapshot + _StubResolver
stub injected via `set_combat_resolver`). Per-call timing via
`Time.get_ticks_usec()` start/end deltas. Samples sorted ascending; p50/p95/p99
computed via nearest-rank percentile. The stub resolver returns a single
pre-built `CombatTickEvents` object per call — keeps resolver overhead
near-zero so the benchmark isolates orchestrator-side cost (cache lookups,
signal dispatch, state updates, gold attribution path).

Three primary configurations + one mean check:

1. **Steady-state**: 0-kill ticks (most common case in production)
2. **Burst**: 5-kill ticks per call (TR-019 edge case for heavy combat)
3. **Mixed**: alternating 0-kill / 5-kill (realistic shape)
4. **Mean**: steady-state mean ≤ 1ms (story QA secondary AC)

## Results

| Config | p50 | p95 | p99 | max | Budget (p95) | Status |
|---|---|---|---|---|---|---|
| Steady-state 0-kill | 2 µs | 2 µs | 2 µs | 20 µs | 2_000 µs | ✅ **1000× headroom** |
| Burst 5-kill | 11 µs | 15 µs | 21 µs | 247 µs | 2_000 µs | ✅ **133× headroom** |
| Mixed alternating | 11 µs | 12 µs | 18 µs | 34 µs | 2_000 µs | ✅ ~166× headroom |
| Steady-state mean | — | — | — | — | 1_000 µs | ✅ measured 1 µs |

**Headroom**: at minimum 133× under budget (burst case); at most 1000× (steady
state). The orchestrator's per-tick hot path is well within budget on dev
hardware by orders of magnitude.

## Hot-path analysis

Steady-state cost is essentially the cost of:
- 3 guard checks (state, run_snapshot null, tick monotonicity)
- 1 resolver call (stubbed near-zero)
- 2 field assignments (current_tick, last_emitted_tick)
- 1 _process_kill_events call (early-returns on null/non-events)

Burst-5-kill cost adds:
- Iteration over 5 KillEvent entries
- 5× Economy.add_gold calls (which trigger AudioRouter.play_sfx via the
  gold_changed signal — visible in the test log as MISSING REF warnings
  for `reward_gold_collected` SFX, expected since test env has no SFX
  fixtures registered)
- 5× per-kill signal emissions (enemy_killed)

Even with this combined work, p99 stays under 25 µs — well below the 2000 µs
budget. The burst case's max=247µs is a one-off outlier (likely GC pause or
process scheduling); p99 is the meaningful AC bound and stays under 25 µs.

## Min-spec follow-up

This benchmark runs on Apple Silicon, NOT min-spec mobile (see
`production/qa/minimum-spec.md`). Given the 100×+ headroom on dev hardware
and the bounded hot-path operations (no allocations in steady state, no tree
queries, O(1) Dictionary lookups), the budget should hold on min-spec mobile
by a comfortable margin even at 10-20× slower per-instruction throughput.

**Re-run on actual min-spec hardware before MVP ship is recommended but not
blocking** — story explicitly says "mobile min-spec verification deferred to
playtest" and the dev-hardware headroom is too large to plausibly close on
mobile.

## Suite-wide test results at evidence-write time

The 4 perf functions added by this story pass standalone via the
`tests/perf/` runner invocation. The main project suite (`tests/unit/` +
`tests/integration/`) continues to report **1678/1678 PASS** unchanged.

The `tests/perf/` directory is not auto-discovered by the standard
`gdunit4_runner.gd` (which scans `tests/unit/` + `tests/integration/`
only — same scope as `.github/workflows/tests.yml`). Perf tests are run
manually or via a dedicated perf-CI workflow. This matches the existing
`tests/perf/combat_resolver_perf_test.gd` and `tests/perf/matchup_resolver_perf_test.gd`
pattern.

## Stub resolver caveat

The `_StubResolver` returns a fixed pre-built `CombatTickEvents` per call
to isolate orchestrator-side cost from resolver-side cost. The
`DefaultCombatResolver` is benchmarked separately under
`combat-resolution/story-010` (`tests/perf/combat_resolver_perf_test.gd`).
Real production calls may have higher per-tick latency if the resolver's
cost dominates — but TR-019 specifically scopes to the orchestrator's
overhead, and the resolver's budget is bounded separately by ADR-0010.
