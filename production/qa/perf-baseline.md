# Performance Baselines

> **Status**: Initial baseline doc (Sprint 8 S8-N1)
> **Owner**: QA Lead + Combat-Resolution epic
> **Update cadence**: per perf-affecting story (combat formula changes,
> resolver refactors, snapshot-build changes)

This document tracks performance baselines + manual benchmark protocols for
hot-path systems whose CI test budgets don't fully verify min-spec hardware
performance. CI runs are typically on ubuntu-latest x86_64 GitHub runners
which are 2–5× faster than the Steam Deck min-spec target. Numbers here are
the **manual mobile/Steam Deck verification** that complements CI's
ceiling-based gating.

---

## Combat Resolver — `compute_offline_batch` (TR-combat-024)

### Spec budget

- **CI ubuntu-latest**: p95 ≤ 100ms over 20 iterations of 576k-tick batch
- **Steam Deck min-spec (1280×800)**: p95 ≤ 200ms over 20 iterations

### Automated CI bench

`tests/perf/combat_resolver_perf_test.gd::test_compute_offline_batch_576k_p95_under_perf_budget`

Configuration:
- Synthetic 3-enemy bruiser snapshot (canonical fixture per S8-S1)
- `loops_per_run = 30000` (schedule end ~630k ticks; 576k budget truncates)
- `tick_budget = 576000`
- 20 timed iterations + 1 untimed warmup
- p95 = sorted index 18 of 20

CI failure threshold: hard ceiling 500ms (5× spec). Soft warn at 100ms via
`push_warning` for early regression signal without flapping the gate.

### Manual Steam Deck protocol

1. Build a debug Godot 4.6 export to Steam Deck via Steam Deck dev kit OR
   sideload via the Linux x86_64 export
2. Open the in-game perf scene (`tools/perf/combat_bench_scene.tscn` —
   to be authored by tools-programmer in a future story)
3. Trigger the bench via the on-screen button; record:
   - Median wall-time across 20 iterations
   - p95 (sorted index 18)
   - Max
4. Compare against the 200ms spec budget; flag if exceeded
5. Capture screen recording + log paste; archive to
   `production/qa/evidence/perf-combat-576k-steamdeck-<date>.md`

**Status**: protocol drafted; tools/perf scene NOT YET BUILT (out of Sprint 8
scope; flagged for Sprint 9+ tooling backlog).

### Latest baseline (autonomous run)

| Hardware | Date | Median | p95 | Max | Status |
|----------|------|--------|-----|-----|--------|
| macOS dev (M-series Apple Silicon) | 2026-04-27 | TBD | TBD | TBD | Awaiting first CI run |
| CI ubuntu-latest | TBD | TBD | TBD | TBD | Awaiting first CI run |
| Steam Deck (1280×800) | TBD | TBD | TBD | TBD | Awaiting manual protocol scene |

The dev-machine measurements are NOT a substitute for CI baseline numbers
because Apple Silicon dev hardware is significantly faster than CI ubuntu
runners. Treat dev numbers as "regression direction" indicators only — the
CI run is the gating measurement.

---

## Matchup Resolver — `resolve_formation_matchup` (TR-matchup-resolver-031)

### Spec budget

- **CI ubuntu-latest**: 10,000 calls < 200ms (covered by automated bench in S8-N3)
- **Steam Deck min-spec**: 10,000 calls < 50ms (manual verification)

### Automated CI bench

`tests/perf/matchup_resolver_perf_test.gd::test_resolve_formation_matchup_10000_calls_under_perf_budget`

Hard ceiling: 1000ms (5× spec). Soft warn at 100ms.

### Manual Steam Deck protocol

Same general pattern as combat resolver — pending tools/perf scene.

---

## Hero Roster — `get_formation_strength` (TR-hero-roster-024 / AC H-14)

### Spec budget

- **CI ubuntu-latest**: 1000 calls, p99 < 50µs (covered by automated bench in S8-N4)
- **Steam Deck min-spec**: 1000 calls, p99 < 50µs (manual verification)

### Automated CI bench

`tests/unit/hero_roster/formation_strength_and_accessors_test.gd::test_get_formation_strength_perf_p99_under_50us_over_1000_calls`

Hard ceiling: 200µs (4× spec). Soft warn at 50µs.

---

## Trend Tracking (future)

JSON record output (per TR-combat-024 acceptance criterion):
`tests/perf/baselines/combat_resolver_576k.json` — median + p95 + p99 + max
trend file. **Not yet implemented** — would require:
1. Test-side JSON write (one entry per CI run, append-only)
2. CI workflow step to publish/diff against the prior run
3. Dashboard / alert tooling

Tracked for future tooling story (Sprint 9+ candidate).

---

## Update protocol

When a perf-affecting story lands:

1. Re-run all perf benches locally; record numbers in this doc's "Latest
   baseline" tables
2. If p95 regressed, trace via Godot profiler to identify the responsible
   commit + open a TD entry
3. If budget needs revision (e.g., new feature genuinely costs more), update
   the spec budget in this doc + the matching TR-registry entry

---

## Open items

- [ ] Build `tools/perf/combat_bench_scene.tscn` for manual mobile/Steam Deck verification
- [ ] Wire JSON baseline writer into the perf test suite
- [ ] Establish Steam Deck baseline numbers (requires hardware access)
