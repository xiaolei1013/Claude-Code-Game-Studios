# Story 003: `_process(delta)` forbidden-as-economy-input and wall-clock single call site

> **Epic**: tick-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-002, TR-time-006, TR-time-021
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: All wall-clock reads must route through a single `_read_wall_clock_unix_time()` function inside TickSystem so mock propagation and CI grep invariants hold; `_process(delta)` is forbidden as economy input — frame delta must never feed currency/loot/run-outcome math.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story (`Time.get_unix_time_from_system()` is stable pre-cutoff).

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: Wall Clock = `int(Time.get_unix_time_from_system())` cast to int64 at exactly ONE call site (the TickSystem boundary). — ADR-0005
- **Forbidden**: Never use `_process(delta)` value as input to economy / currency / loot / run-outcome math (`process_delta_as_economy_input`). — ADR-0005
- **Forbidden**: Never call `Time.get_unix_time_from_system()` outside TickSystem (`wall_clock_read_outside_tick_system`) — single-call-site invariant. — ADR-0005

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] TR-time-002: "Wall clock read via Time.get_unix_time_from_system() returned as float; cast to int64 at single call site"
- [ ] TR-time-006: "_process(delta) forbidden as economy input - economy math never reads frame delta"
- [ ] TR-time-021: "All internal wall-clock reads route through _read_wall_clock_unix_time() for mock propagation"
- [ ] CI grep assertion: no `Time.get_unix_time_from_system()` call outside TickSystem

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Implement `_read_wall_clock_unix_time() -> int` as the SINGLE project-wide call site for `int(Time.get_unix_time_from_system())`. Use `int()` not `floori()` (ADR-0005 Decision §"Two clocks" notes `floori()` returns float in GDScript 4.x despite the name).
- Cache the last-read wall ts in a private field `_last_wall_ts: int`; `now_ms() -> int` returns `_last_wall_ts * 1000`, NEVER calls `Time.get_unix_time_from_system()` directly — preserves single-call-site invariant (godot-specialist Step 4.5 Note 2 in ADR-0005).
- Every other internal wall-clock-needing code path (heartbeat, Formula D.2, bootstrap, BG entry timestamp) MUST go through `_read_wall_clock_unix_time()` — direct calls are a regression per ADR-0005 §Debug-Only Test Surface closing paragraph.
- Add a `/architecture-review` or CI grep assertion: `grep -rn "Time.get_unix_time_from_system" src/` returns results ONLY in `src/core/tick_system/`.
- `_process(delta)` must only appear in TickSystem and be used only for the accumulator — add a CI grep assertion that no Economy/Orchestrator/Roster code uses `delta` as formula input. Document this in coding-standards.md as a code-review checkbox.
- This story does NOT implement the mock hook itself (`_debug_mock_unix_time`) — that lands in Story 010. This story establishes the `_read_wall_clock_unix_time()` routing function so Story 010 can splice the mock in without touching other call sites.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 006: Formula D.2 — this story only installs the read-routing function, not the formula that consumes it
- Story 010: debug mock splice into `_read_wall_clock_unix_time()`

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **TR-time-002**: Wall clock single call site
  - **Given**: TickSystem source loaded
  - **When**: CI grep runs `grep -rn "Time.get_unix_time_from_system" src/`
  - **Then**: exactly ONE match, located inside `_read_wall_clock_unix_time()` body in `src/core/tick_system/tick_system.gd`
  - **Edge cases**: match in a `.md` doc is fine; match in a test file under `tests/` is fine (`debug_set_unix_time` is the mock route); match anywhere else in `src/` is BLOCKING

- **TR-time-021**: Internal routing
  - **Given**: TickSystem with Formula D.2 implementation installed (Story 006 lands this, but grep works earlier)
  - **When**: static inspection of TickSystem source
  - **Then**: every internal consumer of "current wall time" calls `_read_wall_clock_unix_time()`; no direct `Time.get_unix_time_from_system()` outside that function
  - **Edge cases**: future refactor must retain this invariant — flagged at code review

- **TR-time-006**: `_process(delta)` as economy input
  - **Given**: full `src/` tree (with Economy, Orchestrator, etc. present or stubbed)
  - **When**: CI grep runs for `func _process` and `delta` usage in those files
  - **Then**: `delta` is never multiplied/passed into a formula that produces gold, loot, or run outcome; appears only in TickSystem's accumulator
  - **Edge cases**: Presentation-layer `_process` uses of `delta` for animation interpolation are fine — only economy/gameplay formulas are forbidden. Reviewer must distinguish rendering from economy.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tick_system/process_delta_forbidden_wall_clock_single_call_site_test.gd` (+ CI static-analysis rule, may live under `tools/ci/`) — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 must be DONE
- **Unlocks**: Story 005
