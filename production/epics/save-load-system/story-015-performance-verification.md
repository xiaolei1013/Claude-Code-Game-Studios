# Story 015: Performance verification — persist <10ms/<50ms, load <50ms/<100ms, file <20KB

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration (Performance)
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §D Performance Budgets + AC-SL-11 + AC-SL-12
**Requirements**: TR-save-load-047, TR-save-load-048, TR-save-load-049
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — performance budgets table), ADR-0005 (heartbeat ≤512 bytes cap cross-ref)
**ADR Decision Summary**: Persist time <10ms p95 PC / <50ms p95 mobile. Load time <50ms p95 PC / <100ms p95 mobile. Save file size <20KB MVP / <200KB V1.0, hard cap 2MB. AC-SL-11 mobile is BLOCKING; PC is ADVISORY. AC-SL-12 is ADVISORY. Warning thresholds are 50ms/150ms for persist.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (measurement harness must run on representative min-spec mobile to be meaningful; CI typically runs PC — mobile budget verification gated on physical device or cloud-device lab)
**Engine Notes**: `Time.get_ticks_usec()` is the canonical high-resolution timer (ADR-0014); `OS.get_ticks_*` deprecated. Measure wall-clock microseconds around `_atomic_persist` and the load pipeline; aggregate p50/p95/p99 over ≥100 runs per scenario.

**Control Manifest Rules (Foundation Layer, performance)**:
- **Guardrails**:
  - Save persist time: <10 ms p95 PC / <50 ms p95 mobile — [BLOCKING via AC-SL-11 (mobile); ADVISORY (PC)]
  - Save load time: <50 ms PC / <100 ms mobile — [ADVISORY]
  - Save file size: <20 KB MVP / <200 KB V1.0 — [BUDGET]
  - Heartbeat envelope size: ≤512 bytes — [BLOCKING via AC-TICK-11]
- **Required**: Use `Time.get_ticks_usec()` (NOT deprecated `OS.get_ticks_*`).

---

## Acceptance Criteria

*Scoped to this story (per AC-SL-11 + AC-SL-12):*

- [ ] `tests/integration/save_load/performance_test.gd` harness exists with 3 scenarios: full-state persist, full-state load, heartbeat persist
- [ ] Full-state persist scenario: populate 6 consumers with AC-SL-01 baseline fixture (`tests/fixtures/save_load/six_consumer_baseline.gd`); run persist 100 times; record `Time.get_ticks_usec()` delta around `_atomic_persist`
- [ ] Report p50, p95, p99 in microseconds; assert p95 < 10 000 µs on PC (ADVISORY), < 50 000 µs on mobile (BLOCKING — AC-SL-11 mobile)
- [ ] Full-state load scenario: same fixture; run load 100 times; assert p95 < 50 000 µs PC, < 100 000 µs mobile (ADVISORY AC-SL-12)
- [ ] Heartbeat persist scenario: run 100 times; assert p95 <10 ms PC / <50 ms mobile AND assert composed envelope size ≤512 bytes (BLOCKING AC-TICK-11)
- [ ] Save file size scenario: after AC-SL-01 fixture persist, measure `user://save_slot_1.dat` file size; assert <20 KB MVP (BUDGET; warning fires if ≥15 KB — 75% of budget)
- [ ] Mobile measurement: CI job runs on representative min-spec mobile (Steam Deck 1280×800 as proxy if no mobile CI — noted as "mobile-proxy" in the report; real mobile lab verification tracked as a follow-up pre-ship)
- [ ] p99 outlier reporting: a single p99 outlier (e.g., one run at 15ms PC due to GC or OS scheduler) does NOT fail the gate; p95 is the statistical threshold
- [ ] Performance regression alert: CI output shows p50/p95/p99 delta vs previous run; regression >20% on any scenario fires a warning (human review) — NOT auto-fail
- [ ] Size-regression scan: if post-persist `.dat` size grows >10% over last known baseline, warning fires in CI log

---

## Implementation Notes

- Measurement pattern:
  ```gdscript
  var times_usec: Array[int] = []
  for i in 100:
      var t0 := Time.get_ticks_usec()
      save_load_system._atomic_persist(envelope)
      var t1 := Time.get_ticks_usec()
      times_usec.append(t1 - t0)
  times_usec.sort()
  var p50 = times_usec[50]
  var p95 = times_usec[95]
  var p99 = times_usec[99]
  ```
- Warm-up: discard first 5 runs (cache warm-up, filesystem page cache effects)
- Headless mode: `godot --headless --script tests/gdunit4_runner.gd` runs on CI; headless FileAccess behavior is representative for budget purposes
- Mobile proxy: Steam Deck 1280×800 target (per technical-preferences.md) is the MVP mobile proxy; true iOS/Android measurement is a pre-ship manual gate (flagged in AC-SL-11 as a follow-up)
- File size measurement: `FileAccess.get_file_as_bytes(path).size()` (or `FileAccess.get_length()` after open)
- Budget rationale: persist <10ms PC because heartbeat fires every 60s — 10ms is 0.016% overhead, imperceptible. Mobile 50ms tolerates slower flash-write hardware. 20KB file size keeps full-roster persist well under 2MB hard cap.
- Test runs are NON-DETERMINISTIC timing but DETERMINISTIC state; assertion uses p95 (not any single run) to absorb OS scheduler noise
- CI failure policy: AC-SL-11 mobile is BLOCKING — fail the PR; PC budget is ADVISORY — warning only

---

## Out of Scope

- Unit-level crypto micro-benchmarks (Stories 004-005 measure HMAC / SHA-256 throughput informally)
- Memory profiling (out of scope per ADR-0004 "negligible" memory assessment)
- Real-device iOS / Android (gated on device lab availability; this story targets headless CI + Steam Deck proxy)

---

## QA Test Cases

- **AC-SL-11 / TR-save-load-048 (persist p95 PC)**
  - **Given**: AC-SL-01 baseline fixture with 6 consumers populated; 100 persist runs
  - **When**: Test harness measures `Time.get_ticks_usec()` around `_atomic_persist`
  - **Then**: p95 < 10 000 µs on CI PC hardware (ADVISORY)
  - **Edge cases**: A single p99 outlier up to 30 ms acceptable if p95 meets budget

- **AC-SL-11 mobile BLOCKING / TR-save-load-048**
  - **Given**: Same fixture; harness running on Steam Deck proxy (OR true mobile device when available)
  - **When**: 100 persist runs measured
  - **Then**: p95 < 50 000 µs (BLOCKING — fails PR if exceeded)
  - **Edge cases**: Mobile CI unavailable → mark as "mobile-proxy pending device lab" + log estimate from Steam Deck

- **AC-SL-12 / TR-save-load-049 (load p95)**
  - **Given**: Valid persisted save from AC-SL-01 fixture
  - **When**: 100 load runs measured
  - **Then**: p95 < 50 000 µs PC, < 100 000 µs mobile (both ADVISORY)
  - **Edge cases**: First load after cold start may be outlier (page cache); discard first 5 warm-up runs

- **TR-save-load-047 (file size BUDGET)**
  - **Given**: AC-SL-01 baseline fixture persisted
  - **When**: Measure `user://save_slot_1.dat` size
  - **Then**: Size <20 KB (BUDGET); warning if ≥15 KB (75% consumed)
  - **Edge cases**: Payload grows with roster size (30 hero cap); test fixture uses median realistic roster

- **AC-TICK-11 / heartbeat size BLOCKING**
  - **Given**: 3-field heartbeat dict
  - **When**: Envelope composed (Story 011)
  - **Then**: `envelope.size() <= 512` (BLOCKING — fails PR if exceeded)
  - **Edge cases**: `save_sequence_number` at max (19 ASCII chars); `backup_restore_events` with 16 entries (still under 512 because each entry is ~11 ASCII chars × 16 = 176 bytes)

- **Heartbeat persist time**
  - **Given**: 100 heartbeat persist runs
  - **When**: Harness measures
  - **Then**: p95 < 5 ms PC, < 10 ms mobile (heartbeat is ~1/10 the data of full persist; should be proportionally faster)
  - **Edge cases**: ADVISORY (rolls into AC-SL-11)

- **Regression detection**
  - **Given**: CI baseline p95 recorded from previous passing run
  - **When**: Current run p95 exceeds baseline by >20%
  - **Then**: Warning printed to CI log with delta; does NOT fail PR (human review decides)
  - **Edge cases**: Baselining is noisy; use exponential moving average across last 10 CI runs for the baseline

- **Size regression**
  - **Given**: Last-known-good `.dat` size
  - **When**: New persist produces `.dat` >110% of baseline
  - **Then**: Warning printed; does NOT fail PR (may be legitimate field addition + VERSION bump)
  - **Edge cases**: VERSION bump should include an explicit baseline reset in the CI config

---

## Test Evidence

**Story Type**: Integration (Performance)
**Required evidence**: `tests/integration/save_load/performance_test.gd` — must exist and pass on CI

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 007 (full consumer loop), Story 008 (atomic write), Story 011 (heartbeat path), Story 013 (full tamper path — performance must hold even when the tamper/`.bak` path fires, though measured separately). Effectively depends on ALL prior stories completing.
- **Unlocks**: Ship-readiness — AC-SL-11 mobile BLOCKING gate pass
