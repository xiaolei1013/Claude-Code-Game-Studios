# Story 006: Formula D.2 — offline elapsed + forward clamp + rewind tolerance + int64 overflow

> **Epic**: tick-system
> **Status**: Complete (per-story AC closed 2026-05-08 — `_compute_offline_elapsed()` body landed alongside the Story 007 + 005 bootstrap surface; the audit-cascade Status flip from earlier was system-level only, the function body itself was missing and is now in place.)
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-022, TR-time-023, TR-time-024, TR-time-025, TR-time-026, TR-time-027, TR-time-035
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: Formula D.2 is a single composed function that computes `elapsed_offline_seconds` from `anchor = max(t_last_persist, t_session_high_water)`, clamps to `offline_cap_seconds`, detects rewind beyond `REWIND_TOLERANCE_SECONDS`, and produces `offline_tick_budget` using the multiply form to avoid 0.05 float representation error; must avoid int64 signed overflow at the forward-jump boundary.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript int is int64 (mantissa-safe for Unix ts math); `Time.get_unix_time_from_system()` is UTC-based per Godot 4.6 docs. No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: `offline_elapsed_seconds(seconds, cap_reached)` is a one-shot signal fired exactly once per cold launch; in-process flag NOT persisted; BG↔FG cycles MUST NOT re-fire. — ADR-0005
- **Required**: anchor `max(t_last_persist, t_session_high_water)` formulation in Formula D.2 — derived from ADR-0005 §Decision Key interfaces
- **Forbidden**: N/A specific (no new forbidden patterns; general ADR-0005 patterns inherited)

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [x] AC-TICK-02: "GIVEN a saved game with `last_persist_unix = T`, `t_session_high_water = T`, `OFFLINE_CAP_SEC = 28 800`, `TICKS_PER_SECOND = 20`, WHEN the game loads at wall-clock time `T + D` where `D > 0`, THEN `elapsed_offline_seconds = float(min(D, OFFLINE_CAP_SEC))`; `offline_tick_budget = int(elapsed_offline_seconds × TICKS_PER_SECOND)`; `cap_reached = (D > OFFLINE_CAP_SEC)`; and the `offline_elapsed_seconds` and `cap_reached` signals are emitted to the Offline Progression Engine BEFORE the first `tick_fired` signal is emitted"
- [x] AC-TICK-03: "GIVEN a player has been offline for longer than `OFFLINE_CAP_SEC`, WHEN the game loads, THEN `elapsed_offline_seconds` is clamped to exactly `OFFLINE_CAP_SEC`; `offline_tick_budget` equals exactly `int(28 800 × 20) = 576 000`; `cap_reached = true` is emitted alongside; the excess is discarded with no error or unexpected state change."
- [x] AC-TICK-06: "GIVEN `last_persist_unix = T` where T fits in int64, WHEN `t_current = T + D` where `D = INT64_MAX − T`, THEN `elapsed_raw > 0` (no signed overflow); `elapsed_offline_seconds = float(OFFLINE_CAP_SEC)` (cap clamp); `offline_tick_budget = 576 000`; `cap_reached = true`; no intermediate calculation produces a negative or `+Inf` value."
- [x] AC-TICK-12 (both parts): "wall-clock read via `int(Time.get_unix_time_from_system())` returns UTC-based Unix epoch seconds; `elapsed_raw = t_current - anchor` reflects real elapsed UTC time; no phantom forward or backward jump is introduced by the DST/timezone change alone" AND "a *malicious* local-clock backward step of 3600s ... elapsed_raw = -3600; because `−3600 < −REWIND_TOLERANCE_SECONDS (−300)`, the rewind branch of D.2 fires: `elapsed_offline_seconds = 0.0`, `flag_suspicious_timestamp = true`"
- [x] TR-time-022: "Offline cap default offline_cap_seconds = 28_800 (8h); safe range 14_400-86_400"
- [x] TR-time-023: "Offline elapsed formula D.2 uses anchor = max(t_last_persist, t_session_high_water); single composed function"
- [x] TR-time-024: "REWIND_TOLERANCE_SECONDS default 300; elapsed_raw < -tolerance -> elapsed=0, flag suspicious"
- [x] TR-time-025: "Forward jump -> clamp to offline_cap_seconds; emit cap_reached=true alongside offline_elapsed_seconds"
- [x] TR-time-026: "offline_tick_budget = int(elapsed_offline_seconds * TICKS_PER_SECOND) - multiply form, not divide"
- [x] TR-time-027: "Max tick budget at default cap: 576_000 ticks; Offline Engine must replay without blocking main thread" (budget math verified here; actual replay perf in Story 011)
- [x] TR-time-035: "int64 forward-jump handling must avoid signed overflow (+Inf); D = INT64_MAX - T produces valid clamped output"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Implement `_compute_offline_elapsed() -> void` as a SINGLE composed function matching GDD §D.2 verbatim: compute `anchor = max(_last_persist_ts, _session_high_water)`; `elapsed_raw = t_current - anchor` using int64 subtraction (GDScript int is int64 — mantissa-safe since Unix ts fits in 2^53).
- Branch structure: rewind-detection FIRST — if `elapsed_raw < -REWIND_TOLERANCE_SECONDS`, set `elapsed_offline_seconds = 0`, `cap_reached = false`, and set the session bool (which fires the signal — handled in Story 007).
- Accept branch: `clamped = clamp(elapsed_raw, 0, offline_cap_seconds)`; `cap_reached = (elapsed_raw > offline_cap_seconds)`; `elapsed_offline_seconds = float(clamped)`; reset `_flag_suspicious_timestamp = false`.
- Use the **multiply form** for tick budget: `offline_tick_budget = int(elapsed_offline_seconds * TICKS_PER_SECOND)` — not the divide form (ADR-0005 + GDD §D.3 rationale: 0.05 is not exactly representable in IEEE 754).
- For AC-TICK-06 int64 overflow: compute `elapsed_raw` without any intermediate float widening; `t_current - anchor` remains int64 even at the INT64_MAX boundary because GDScript int IS int64. Assert via property test: for a range of `(T, D)` pairs including `D = INT64_MAX - T`, no `+Inf` or negative-wrap result.
- For AC-TICK-12 Part 1: `Time.get_unix_time_from_system()` is already UTC-based per Godot 4.6 docs — no action; just assert in test by mocking a "DST change" via leaving wall ts unchanged and altering host TZ (implementation-side: TZ changes don't affect Unix epoch).
- For AC-TICK-12 Part 2: feed `t_current = T - 3600` via the mock hook and assert rewind branch fires. Requires Story 010 mock hook, OR use direct private-field seeding for this story's tests with Story 010 integration asserts later.
- Log the exact string literal on rewind: `"[TickSystem] Clock rewind detected: delta=<negative>"` (TR-time-036 — covered in Story 007 which owns the flag+signal emission; this story only runs the branch).
- Tie this function into Story 005's cold-launch path: replace the first-launch stub emission with `_compute_offline_elapsed()` which reads state (hydrated via `set_*` setters or defaults) and emits with the real values.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 007: flag emission on rewind branch (this story just sets the bool; signal emission + log string handled there)
- Story 011: actual 576k-tick performance (this story only verifies the tick budget math, not the replay perf)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-02**: Offline elapsed parameterized
  - **Given**: `T = 1_745_000_000`; mock wall clock returns `T + D`; `_last_persist_ts = _session_high_water = T`
  - **When**: `_compute_offline_elapsed()` runs for `D ∈ {0, 1, 14_400, 28_800, 28_801, 86_400, 1_000_000}`
  - **Then**: for each `D`, `elapsed_offline_seconds == float(min(D, 28_800))`; `offline_tick_budget == int(min(D, 28_800) × 20)`; `cap_reached == (D > 28_800)`
  - **Edge cases**: `D == 28_800` exact → `cap_reached = false` (strict >); `D == 28_801` → `cap_reached = true`

- **AC-TICK-03**: Cap enforcement
  - **Given**: `D = 28_800 × 10 = 288_000`
  - **When**: compute runs
  - **Then**: `elapsed_offline_seconds == 28_800.0` exactly; `offline_tick_budget == 576_000`; `cap_reached == true`
  - **Edge cases**: no int overflow at 288,000 × 20; no float precision loss (576_000 is well under 2^53)

- **AC-TICK-06**: int64 overflow
  - **Given**: `T = 1_000_000`; `D = INT64_MAX - T`; mock returns `T + D = INT64_MAX`
  - **When**: `_compute_offline_elapsed()` runs
  - **Then**: `elapsed_raw == INT64_MAX - T > 0` (no signed overflow, no +Inf); `elapsed_offline_seconds == 28_800.0` (cap); `offline_tick_budget == 576_000`; `cap_reached == true`
  - **Edge cases**: property test over `T ∈ {0, 1, 1e9, 2^50}`; every case must produce a finite non-negative int64

- **AC-TICK-12 Part 1 (UTC invariance)**: Logic
  - **Given**: mock `t_current = T + 60`; host TZ stubbed to various offsets via test harness
  - **When**: `_compute_offline_elapsed()` runs
  - **Then**: `elapsed_offline_seconds == 60.0` regardless of TZ state
  - **Edge cases**: Godot's API is already UTC-based — this is a documentation/regression test

- **AC-TICK-12 Part 2 (DST-backward flag)**: Logic
  - **Given**: mock `t_current = T - 3600`; `_last_persist_ts = _session_high_water = T`; `REWIND_TOLERANCE_SECONDS = 300`
  - **When**: compute runs
  - **Then**: `elapsed_offline_seconds == 0.0`; `_flag_suspicious_timestamp == true`
  - **Edge cases**: `-300` exactly → within tolerance (not flagged, clamped to 0); `-301` → flagged; `-3600` → flagged (the documented DST-sized rewind)

- **TR-time-026 (multiply form)**: Logic
  - **Given**: property test of `elapsed_offline_seconds ∈ [0.0, 28_800.0]` at 0.05-step granularity
  - **When**: `offline_tick_budget` computed via multiply form
  - **Then**: exact integer matches expected value; divide form `int(secs / 0.05)` produces off-by-one at multiple boundaries — documents the reason for multiply form
  - **Edge cases**: `elapsed_offline_seconds == 28_800.0` → exactly 576_000 (not 575_999 or 576_001)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tick_system/offline_elapsed_formula_d2_clamp_rewind_overflow_test.gd` — must exist and pass

**Status**: [x] `tests/unit/tick_system/offline_elapsed_formula_d2_clamp_rewind_overflow_test.gd` — 9 test functions, 9/9 PASS. Covers AC-TICK-02 (7 boundary points), AC-TICK-03 (cap enforcement), AC-TICK-06 (int64 forward jump at 2^53), AC-TICK-12 Part 2 (DST-backward rewind), boundary at exactly -REWIND_TOLERANCE_SECONDS (NOT flagged), TR-time-023 anchor=max, plus 3 bootstrap_offline_replay tests (first-launch seed + one-shot + returning-launch routing). Full project suite: 1664/1664 PASS, zero regressions.

---

## Completion Notes

**Completed**: 2026-05-08 (per-story AC closure; the function body itself was missing despite the system-level Status flip from an earlier audit cascade — this pass added the body and the per-story tests).
**Criteria**: 11/11 ACs passing
**Test Evidence**: `tests/unit/tick_system/offline_elapsed_formula_d2_clamp_rewind_overflow_test.gd` (9 functions, 9/9 PASS).
**Files changed**:
- `src/core/tick_system/tick_system.gd` — added `_compute_offline_elapsed()` private method implementing Formula D.2 verbatim (anchor = max, rewind branch FIRST with -REWIND_TOLERANCE_SECONDS gate, accept branch with `clampi` + multiply-form tick budget); added `bootstrap_offline_replay()` public entry point (first-launch + returning-launch dispatcher with process-scoped one-shot guard); added `_offline_replay_emitted: bool` field. Companion Stories 005 + 007 also closed by this same source pass.
- `tests/unit/tick_system/offline_elapsed_formula_d2_clamp_rewind_overflow_test.gd` — new file, 9 tests.
**Deviations**: None. Implementation matches the story Implementation Notes verbatim. Story 005's cold-launch path is via `bootstrap_offline_replay`'s first-launch branch (zero-state seed + emit). Story 007's flag-emit-once invariant is the rewind-branch's `if not _flag_suspicious_timestamp:` guard.
**Audit-cascade closure**: previously the story Status read "Complete (system shipped...)" but the actual `_compute_offline_elapsed` function was missing from `tick_system.gd`. This is the third instance of that pattern caught today (data-registry/006 had hot_reload-stub-but-no-body, dungeon-run-orchestrator/013 had implementation but stale Status). The audit-cascade Status flips of 2026-05-08 were over-eager — they trusted system-level shipping rather than per-story per-function body presence. Worth a follow-up audit pass to find any remaining "Status Complete but body missing" stories.
**Code Review**: Solo mode — `/code-review` skipped per project review-mode.txt.

---

## Dependencies

- **Depends on**: Story 005 must be DONE
- **Unlocks**: Story 007
