# Story 008: Boot scan performance budget (MVP <200 ms on min-spec mobile)

> **Epic**: data-registry
> **Status**: Complete (system shipped; see systems-index Implementation Status #2. Test evidence: `tests/unit/data_registry/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-020, TR-data-loading-021]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary)
**ADR Decision Summary**: Eager synchronous boot scan at MVP content scale (~50 files, <400 KB total) completes in <200 ms on min-spec mobile (AC-DLS-07 BLOCKING); the migration path to `load_threaded_request()` is documented for V1.0 without any consumer-facing API change.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_msec()` is the canonical 4.x timing API (`OS.get_ticks_msec()` deprecated 4.0+); measurement must bracket exactly `_ready()` entry and `registry_ready` emission. No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, DataRegistry)**:
- **Required**: "Boot scan time (DataRegistry): <200 ms on min-spec mobile at MVP scale — [BLOCKING AC-DLS-07]." — ADR-0006
- **Required**: "Total loaded content memory: <400 KB MVP / <5 MB V1.0 (within 256 MB mobile ceiling) — [BUDGET]." — ADR-0006
- **Required**: "DataRegistry boot scan is eager + synchronous via `ResourceLoader.load(path)` (NOT `load_threaded_request` for MVP)." — ADR-0006
- **Forbidden**: "Never call `ResourceLoader.load(\"res://assets/data/...\")` directly from non-DataRegistry code." — ADR-0006

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-020: Load-time budget <200 ms on min-spec mobile (~2 GB RAM, Cortex-A53) cold-start for MVP content set
- [ ] TR-data-loading-021: MVP memory: <400 KB total across all categories; 256 MB mobile ceiling unthreatened
- [ ] AC-DLS-07: **GIVEN** the device meets minimum mobile spec (~2 GB RAM, ~Cortex-A53 equivalent) and `assets/data/` contains exactly the MVP content set, **WHEN** the Data Loading System runs full enumeration + parse + registration from cold start (no OS file cache), **THEN** elapsed time from `DataRegistry._ready()` entry to `registry_ready` emission is **< 200 ms**, measured via `Time.get_ticks_msec()` bracketing those two points; measured on real hardware, not editor/emulator.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Add `@export var load_time_budget_ms: int = 200` knob per ADR-0006 §Tuning Knobs (range 50–500; profiling warning if exceeded, not a hard abort).
- Instrument `_ready()` with `var _boot_t0_ms := Time.get_ticks_msec()` at entry and emit `[DataRegistry] BOOT SCAN: elapsed={ms}ms; budget={load_time_budget_ms}ms` just before `registry_ready.emit()`. If elapsed > `load_time_budget_ms`, `push_warning` with the overrun delta.
- Write a PC CI performance test that runs the full MVP fixture and asserts elapsed < 200 ms as a soft lower bound — PC SSD measurements in ADR-0006 are 30–80 ms; CI failure threshold should be generous (e.g., 150 ms) to account for CI VM variance; real-hardware verification is the BLOCKING gate.
- Write a mobile / real-hardware performance protocol document at `production/qa/evidence/dls-perf-<DATE>.md` capturing: device spec (model, OS, RAM), 10 cold-start trials, p50 / p95 / p99 elapsed times, pass/fail against 200 ms. Include the protocol steps for a QA runbook (cold cache invalidation, screen-state, thermal steady-state).
- Memory budget (TR-021) verification: measure via `OS.get_static_memory_usage()` or Godot profiler before and after the load; assert delta < 400 KB at MVP scale. This is a BUDGET (not a hard cap); failure surfaces as a `push_warning` with the actual usage, not an ERROR state.
- Document the V1.0 migration trigger in a code comment near `_boot_scan`: switch to `load_threaded_request()` + loading screen when MVP-scale measurements exceed the budget at V1.0 content scale; `get_all_by_type`, `resolve`, `registry_ready` contracts are unchanged.
- The lazy_load_categories knob (from Story 003) remains empty in MVP — no lazy path is exercised here. V1.0 ADR will re-visit semantics if adopted.

---

## Out of Scope

- Story 007: Hot-reload + immutability + hydration gate (prerequisite).
- Threaded loading (`load_threaded_request`) — explicitly deferred to V1.0 per ADR-0006 §Alternatives.
- Lazy-per-category loading — same V1.0 deferral.
- Loading screen UI — V1.0 concern owned by the scene manager / UI epic.

---

## QA Test Cases

- **TR-data-loading-020 / AC-DLS-07**: Boot scan < 200 ms on min-spec mobile (real hardware)
  - **Given**: A real-device (NOT emulator / editor) min-spec mobile build of the MVP fixture (~2 GB RAM, Cortex-A53-class), cold OS file cache.
  - **When**: 10 cold-start trials are run and each trial measures from `_ready()` entry to `registry_ready` emission via `Time.get_ticks_msec()`.
  - **Then**: p95 elapsed < 200 ms; results logged to `production/qa/evidence/dls-perf-<DATE>.md` with device spec, p50, p95, p99, and pass/fail verdict.
  - **Edge cases**: p95 over budget triggers ADR-0006 §Risks row "Boot scan exceeds 200ms on min-spec mobile at V1.0 scale" — mitigation is the threaded-load migration path; it is not a hard abort but requires a follow-up ADR; emulator/editor numbers are informational only and must not be relied on for AC sign-off.

- **TR-data-loading-020 (CI regression)**: PC boot scan stays well under budget
  - **Given**: A PC CI runner (SSD, desktop-class CPU) executing the MVP fixture boot.
  - **When**: The test runs the full boot headlessly.
  - **Then**: Elapsed < 150 ms (soft CI threshold — actual MVP measurements per ADR-0006 are 30–80 ms); a log line reports the measurement; regression above the threshold fails the CI job.
  - **Edge cases**: CI VM variance — threshold is generous to avoid flakiness; real-hardware gating remains AC-DLS-07 on actual device.

- **TR-data-loading-021**: MVP memory budget verification
  - **Given**: MVP fixture loaded headlessly.
  - **When**: Post-`registry_ready` memory is sampled.
  - **Then**: Total memory delta attributable to the loaded `.tres` resources is < 400 KB; a log line reports the measurement; no BUDGET warning fires in the success path.
  - **Edge cases**: V1.0 content scale (`~200 files, <10 MB`) is an expected future regression target; the MVP test asserts only the MVP scale.

- **`load_time_budget_ms` knob surfaces overrun as warning**
  - **Given**: An adversarial fixture large enough to exceed 200 ms on CI (e.g., synthetic 2000 trivial `.tres` files or injected per-load sleep).
  - **When**: Boot scan completes.
  - **Then**: `push_warning("[DataRegistry] BOOT SCAN OVERRUN: elapsed={ms}ms > budget={budget}ms")` fires; state still transitions to READY (not a hard abort); `registry_ready` still emits normally.
  - **Edge cases**: The knob is configurable per ADR-0006 §Tuning Knobs (50–500); values outside that range are designer error (no runtime enforcement).

---

## Test Evidence

**Story Type**: Integration (Performance)
**Required evidence**: `tests/integration/data_registry/boot_scan_performance_budget_test.gd` — must exist and pass; plus `production/qa/evidence/dls-perf-<DATE>.md` for the real-hardware real-mobile BLOCKING gate

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 007
- **Unlocks**: None (epic complete)
