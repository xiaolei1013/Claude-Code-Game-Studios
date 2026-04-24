# Story 004: `Screen extends Control` base class + four lifecycle hooks + CI grep enforcement

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-005, TR-scene-manager-028
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §`Screen` base class lifecycle contract)
**ADR Decision Summary**: Every screen MUST extend the `Screen extends Control` base class and MUST declare all four lifecycle hooks: `on_enter`, `on_exit`, `on_pause`, `on_resume`. Empty-body declarations are acceptable; silent omission is FORBIDDEN. `on_enter` fires after the screen becomes `current_screen` (post-transition); `on_exit` fires BEFORE `queue_free`; `on_pause` fires when a modal overlay opens on top; `on_resume` fires when the overlay closes. Each Screen subclass may export `transition_override_ms: int` to replace the matching default for its enter transition only.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure GDScript class inheritance; no post-cutoff engine APIs. `class_name` resolution is stable. CI grep enforcement is a tooling concern (ripgrep + a simple AST check). 4.6 dual-focus: the base class sets `focus_mode = FOCUS_NONE` at theme level via `MainRoot.theme` cascade (ADR-0008) — Screen subclasses do not need per-class `focus_mode` overrides in MVP.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: Every screen extends `Screen extends Control` with all four lifecycle hooks declared (empty body OK): `on_enter()`, `on_exit()`, `on_pause()`, `on_resume()`. — ADR-0007
- **Forbidden**: Never silently omit any of the four lifecycle hooks on a Screen subclass — empty body OK; missing FORBIDDEN. — ADR-0007

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-005: "Every screen extends Screen base class with on_enter/on_exit/on_pause/on_resume lifecycle hooks (empty body OK)"
- [ ] TR-scene-manager-028: "Per-screen transition_override_ms export on Screen subclass replaces matching default for that screen's enter"

*Additional from Control Manifest + ADR-0007:*

- [ ] CI grep (or equivalent lint) rejects any `extends Screen` file missing any of the four hook declarations — wired into `tools/ci/` or `tests/gdunit4_runner.gd` lint phase
- [ ] Base class `Screen` doc-comment explicitly warns about `PROCESS_MODE_PAUSABLE` inheritance from `ScreenContainer` (ADR-0007 Risks Note 4) and about `TWEEN_PAUSE_BOUND` default pausing screen-local tweens during modal pause (ADR-0007 Risks Note 1)

---

## Implementation Notes

*Derived from ADR-0007 §`Screen` base class lifecycle contract:*

- Create `src/core/scene_manager/screen.gd`:
  ```gdscript
  # Base class for every managed screen. Declared under SceneManager module ownership
  # rather than assets/screens/_base/ because it is Foundation-layer infrastructure.
  class_name Screen extends Control

  ## Optional per-screen override for enter-transition duration (ms). 0 = use SceneManager default.
  ## Matches GDD §G Tuning Knobs "Per-screen duration overrides".
  @export var transition_override_ms: int = 0

  ## Called by SceneManager after this screen becomes `current_screen`.
  ## Connect signals here; initialize from game data model (do NOT assume state from prior visit).
  func on_enter() -> void:
      pass

  ## Called by SceneManager BEFORE queue_free. Disconnect signals; flush deferred work.
  func on_exit() -> void:
      pass

  ## Called by SceneManager when a modal overlay opens on top of this screen.
  ## The screen is NOT freed; visual continuity is preserved.
  ## Pause animations / hide tooltips that don't make sense above an overlay.
  ##
  ## IMPORTANT (ADR-0007 Risks Note 1): Tweens created inside a Screen child inherit
  ## Tween.TWEEN_PAUSE_BOUND from ScreenContainer (PROCESS_MODE_PAUSABLE), so they
  ## will FREEZE during modal pause automatically — which is usually correct.
  ## If a screen-local idle animation must keep running, create its tween from a
  ## node with `process_mode = Node.PROCESS_MODE_ALWAYS` OR call
  ## `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` explicitly.
  func on_pause() -> void:
      pass

  ## Called by SceneManager when the modal overlay closes and this screen becomes interactive again.
  ## Restore animations / tooltips paused in on_pause.
  func on_resume() -> void:
      pass
  ```
- Add a brief note in the doc-comment header: "Children of a Screen subclass inherit `PROCESS_MODE_PAUSABLE` from `ScreenContainer`; child nodes that need to keep running during a modal overlay (e.g., a looping idle particle, persistent counter animation) MUST explicitly set `PROCESS_MODE_ALWAYS` on the child." (ADR-0007 Risks Note 4.)
- Place the script at `src/core/scene_manager/screen.gd` so the `class_name Screen` registration propagates before any Presentation-layer screen class is parsed.
- CI grep enforcement script at `tools/ci/check_screen_hooks.sh` (or equivalent Python/GDScript test runner) that:
  1. Finds every file under `assets/screens/` or `src/**/screens/` that contains `extends Screen`.
  2. For each, asserts the file contains all four function declarations: `func on_enter(`, `func on_exit(`, `func on_pause(`, `func on_resume(` (regex is sufficient — empty bodies are acceptable).
  3. Missing-hook failures exit non-zero with a clear error message naming the offending file and missing hooks.
- Wire the script into `tests/gdunit4_runner.gd` OR as a pre-commit hook in `.claude/hooks/` if present. The check is a hard gate: CI must fail on missing-hook.
- Add a minimal placeholder `assets/screens/_placeholder/placeholder_screen.gd` extending `Screen` with all four empty-body hooks — used by Story 003's `_screen_registry` during development before real screen GDDs land.

---

## Out of Scope

- Story 003: `request_screen` / `_execute_transition` bodies that CALL these hooks
- Story 007: `push_overlay` / `pop_overlay` — the modal code that triggers `on_pause` / `on_resume`
- Per-screen implementations (Guild Hall, Recruit, etc.) — those live in Presentation-layer epics once their GDDs land

---

## QA Test Cases

- **TR-scene-manager-005**: All four hooks declared on base class
  - **Given**: `Screen` class loaded via `class_name` registry
  - **When**: test instantiates a placeholder `Screen` subclass and inspects its method table via `get_method_list()`
  - **Then**: `on_enter`, `on_exit`, `on_pause`, `on_resume` all present; each accepts zero arguments and returns void
  - **Edge cases**: subclass that overrides with different arity must fail to extend cleanly — test a "bad subclass" fixture with `func on_enter(x: int)` and assert GDScript/class_name resolution errors

- **TR-scene-manager-028**: `transition_override_ms` export
  - **Given**: `Screen` subclass with `@export var transition_override_ms: int = 250`
  - **When**: inspector reads the property
  - **Then**: property is `@export`ed; default is 0 on the base class; override persists on subclass; non-zero value is read by Story 005's transition dispatcher
  - **Edge cases**: negative value should be clamped to 0 with a `push_warning` (documented in Story 005 — for this story just verify the export surface exists)

- **ADR-0007 CI grep enforcement**: Missing-hook is a hard CI failure
  - **Given**: a test fixture file `tests/fixtures/bad_screen_missing_hook.gd.fixture` declaring `extends Screen` but omitting `on_resume`
  - **When**: `tools/ci/check_screen_hooks.sh` (or equivalent) is run with fixture included
  - **Then**: script exits non-zero; error message names the fixture and the missing `on_resume` hook
  - **Edge cases**: comments that contain the string `func on_resume(` must not false-positive (use a stricter AST or at-line-start regex); fixtures with all four declarations in any order must pass

- **ADR-0007 Risks Note 4 + Note 1 documentation**: Doc-comment warnings present
  - **Given**: `screen.gd` source
  - **When**: grep for key strings "PROCESS_MODE_PAUSABLE" and "TWEEN_PAUSE_BOUND" inside doc comments
  - **Then**: both present; both linked to the screen-authoring guidance
  - **Edge cases**: pure code-only file without the warnings must fail documentation review — this is an advisory check but story DoD requires it

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene_manager/screen_base_class_test.gd` — must exist and pass. Additionally `tools/ci/check_screen_hooks.sh` must exist and be wired into CI.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (parallelizable with Story 002; Story 003 calls into the hooks and therefore consumes this story's contract)
- **Unlocks**: Story 003 (calls `on_enter` / `on_exit`), Story 007 (calls `on_pause` / `on_resume`)
