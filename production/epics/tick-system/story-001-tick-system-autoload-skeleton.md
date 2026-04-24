# Story 001: TickSystem autoload skeleton

> **Epic**: tick-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-001, TR-time-017
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract (+ ADR-0003: Autoload Rank Table Canonical for rank + zero-arg `_init`)
**ADR Decision Summary**: TickSystem is the rank-0 autoload that owns the dual-clock contract — integer-accumulator Sim Clock and single-call-site Wall Clock. ADR-0003 Amendment #3 requires autoload script `_init` to have zero required parameters; Amendment #1 establishes that signal subscription across any rank pair at `_ready()` is safe.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: TickSystem autoload identifier = `TickSystem` (rank 0); architecture.md 'GameTimeAndTick' label corrected in lockstep. — ADR-0005
- **Required**: Autoload script `_init` (if declared) MUST have ZERO required parameters (Claim 4 [VERIFIED]); all params must default. — ADR-0003 Amendment #3
- **Required**: Signal SUBSCRIPTION across any rank pair at `_ready()` is safe — signal objects exist on Node instantiation per autoload.md Claim 1 [VERIFIED]. — ADR-0003 Amendment #1
- **Forbidden**: N/A at scaffold stage

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] TR-time-001: "Implemented as Godot autoload singleton named TickSystem (Node-derived script)"
- [ ] TR-time-017: "Signals: tick_fired(int), offline_elapsed_seconds(float, bool), flag_suspicious_timestamp_emitted(int, int)" — declarations only (bodies empty)
- [ ] ADR-0003 Amendment #3: autoload script `_init` has ZERO required parameters (all params defaulted)
- [ ] Registered at rank 0 in `project.godot [autoload]`, matching architecture.md canonical table

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Create `src/core/tick_system/tick_system.gd` with `class_name TickSystem extends Node`; zero-arg `_init()` per ADR-0003 Amendment #3 (Claim 4 [VERIFIED]) because autoload scripts cannot receive constructor args.
- Declare all three public signals verbatim (`tick_fired(tick_number: int)`, `offline_elapsed_seconds(seconds: float, cap_reached: bool)`, `flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)`) so consumers at other ranks can subscribe in their own `_ready()` (ADR-0003 Amendment #1 — signal subscription across any rank pair at `_ready()` is safe).
- Declare constants `TICKS_PER_SECOND: int = 20` and `_TICK_INTERVAL_SECONDS: float = 1.0 / TICKS_PER_SECOND` — architectural, NOT exported as tuning knobs.
- Declare `@export` tuning knobs: `offline_cap_seconds: int = 28_800`, `REWIND_TOLERANCE_SECONDS: int = 300`, `heartbeat_interval_seconds: int = 60`.
- Register in `project.godot [autoload]` as the FIRST entry (rank 0); update lockstep per ADR-0003 (architecture.md rank table + CONSUMER_PATHS unaffected since TickSystem is not a CONSUMER_PATHS entry).
- Add stubs for all public API methods (`now_ms`, `current_tick`, `get_last_persist_ts`, `get_session_high_water`, `set_last_persist_ts`, `set_session_high_water`) returning sensible zero-values — bodies filled in later stories.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 002: accumulator math and `tick_fired` emission
- Story 004: platform notifications
- Story 008: Save/Load setter bodies

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **TR-time-001**: TickSystem autoload presence
  - **Given**: fresh headless Godot 4.6 launch with `project.godot` including the TickSystem autoload
  - **When**: scene tree is inspected via `get_tree().root.get_node_or_null("TickSystem")`
  - **Then**: returns non-null Node, `class_name == "TickSystem"`, sits at index 0 among autoloads
  - **Edge cases**: launch with malformed autoload entry (should hard-fail boot, not silently register under wrong name)

- **TR-time-017**: Signal declarations exist and are connectable
  - **Given**: TickSystem autoload booted
  - **When**: a test connects a dummy Callable to each of `tick_fired`, `offline_elapsed_seconds`, `flag_suspicious_timestamp_emitted`
  - **Then**: all three `connect()` calls return `OK`; signal arity matches (1 int; float+bool; int+int)
  - **Edge cases**: connecting with wrong arity must fail at connect-time (Godot typed-signal contract)

- **ADR-0003 Amendment #3**: zero-arg `_init`
  - **Given**: autoload definition parsed
  - **When**: Godot instantiates the autoload during boot
  - **Then**: no "Too few arguments for _init()" error; instance boots cleanly; `_init` signature in source is `func _init() -> void` (no required params)
  - **Edge cases**: adding a required param would fail autoload construction silently — covered by boot-pass assertion

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tick_system/tick_system_autoload_skeleton_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None
- **Unlocks**: Story 002


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 4/4 passing
**Story Type**: Logic
**Test Evidence**: tests/unit/tick_system/tick_system_autoload_skeleton_test.gd (11/11 pass)
**Deviations**: class_name TickSystem removed (conflicted with autoload singleton of same name). Test-file type annotations use preload pattern.
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
