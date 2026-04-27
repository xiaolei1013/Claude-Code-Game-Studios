# Story 002: SceneManager autoload skeleton + four-state machine + DataRegistry gating

> **Epic**: scene-manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-001, TR-scene-manager-009, TR-scene-manager-012
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary) + ADR-0003 (autoload rank ≥6, zero-arg `_init`, forward-only state reads at `_ready()`)
**ADR Decision Summary**: `SceneManager` is a Godot autoload at rank ≥6 (OQ-8; concrete rank assigned during implementation — recommended 6 or 7, must be strictly greater than `DataRegistry` rank 1). Its four-state machine is `UNINITIALIZED | IDLE | TRANSITIONING | PAUSED`. At boot it stays `UNINITIALIZED` and no-ops all `request_screen` calls; on `DataRegistry.registry_ready`, it transitions to `TRANSITIONING` and auto-routes to the first screen. Autoload script `_init` must have zero required parameters (ADR-0003 Amendment #3, Claim 4 [VERIFIED]).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload pattern is stable since 4.0; signal subscription across rank pairs at `_ready()` is VERIFIED safe (ADR-0003 Amendment #1). No post-cutoff APIs in this story.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: SceneManager autoload identifier = `SceneManager`; rank position is implementation-detail (≥6, after DataRegistry); stays `UNINITIALIZED` until `DataRegistry.registry_ready` fires. — ADR-0007
- **Required**: Four-state machine: `UNINITIALIZED | IDLE | TRANSITIONING | PAUSED`. — ADR-0007
- **Required**: Autoload script `_init` (if declared) MUST have ZERO required parameters; all params must default. — ADR-0003 Amendment #3
- **Required**: Signal SUBSCRIPTION across any rank pair at `_ready()` is safe. — ADR-0003 Amendment #1
- **Required**: STATE READS at `_ready()` only allowed if M < N; SceneManager reading `DataRegistry.state` at its own `_ready()` is safe iff SceneManager rank > 1. — ADR-0003
- **Forbidden**: Never declare `func _init(...)` with required parameters on an autoload script. — ADR-0003 Amendment #3

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-001: "SceneManager is Godot autoload singleton; owns MainRoot.tscn persistent scene tree"
- [ ] TR-scene-manager-009: "SceneManager._ready subscribes to DataRegistry.registry_ready; stays UNINITIALIZED until fired"
- [ ] TR-scene-manager-012: "States: UNINITIALIZED, IDLE, TRANSITIONING, PAUSED"
- [ ] Autoload `_init()` signature has zero required parameters (ADR-0003 Amendment #3)
- [ ] Concrete rank assigned in `project.godot [autoload]` (recommended 6 or 7); architecture.md rank table remarked accordingly (OQ-8 resolution)

*Verbatim from GDD §H (AC-scoped to this story — no-op enforcement portion of H-06):*

- [ ] **AC H-06 (BLOCKING, partial)**: Given game just launched and `DataRegistry.registry_ready` has NOT yet fired, when `SceneManager._ready()` runs, then state is `UNINITIALIZED` and any `request_screen` call before `registry_ready` is stored in `_queued_request` (queue slot held; execution deferred to Story 003).

---

## Implementation Notes

*Derived from ADR-0007 §Autoload identifier and registration + §Four-state machine, and ADR-0003 Amendments #1 and #3:*

- Create `src/core/scene_manager/scene_manager.gd`:
  ```gdscript
  class_name SceneManager extends Node

  enum State { UNINITIALIZED, IDLE, TRANSITIONING, PAUSED }

  var state: State = State.UNINITIALIZED   # public read; internal write only
  var current_screen: Control = null
  var current_screen_id: String = ""

  # Placeholder queue slot (filled by Story 003 request_screen body)
  var _queued_request: Dictionary = {}

  func _init() -> void:
      # Zero required params per ADR-0003 Amendment #3 (Claim 4 [VERIFIED]).
      pass

  func _ready() -> void:
      # ADR-0003 Amendment #1: signal subscription across any rank pair at _ready() is safe.
      # ADR-0003 STATE READ rule: SceneManager rank must be > DataRegistry rank (1) — see Story AC.
      DataRegistry.registry_ready.connect(_on_registry_ready)
      if DataRegistry.state == DataRegistry.State.READY:
          # Late-subscription fallback: signal may have fired before SceneManager _ready
          # iff rank order ever regresses. Forward-only invariant prevents this in practice,
          # but defensive check is cheap.
          _on_registry_ready()

  func _on_registry_ready() -> void:
      # Boundary: UNINITIALIZED -> TRANSITIONING (auto-route handled in Story 003).
      # This story only enters IDLE directly if no queued request and no auto-route.
      # For now, set state = IDLE and leave auto-route to Story 003.
      state = State.IDLE
  ```
- Register `SceneManager` in `project.godot [autoload]` at rank ≥ 6 (concrete rank chosen here; recommended 6 or 7 — the slot must come after `BiomeDungeonDatabase` rank 6 if that slot is occupied, i.e. rank 7 or later in the current table. Check `docs/architecture/architecture.md` §Autoload Rank Table at implementation time for the current occupied slots; this story resolves OQ-8 by picking a concrete rank and noting it in architecture.md).
- Declare the three public signals as empty signatures for subscribers (bodies emitted in later stories):
  ```gdscript
  signal scene_boundary_persist(reason: String)                                     # Story 008 emits
  signal screen_changed(new_screen_id: String, old_screen_id: String)               # Story 003 emits
  signal transition_complete(screen_id: String, transition_type: int)               # Story 005 emits
  ```
- Declare `enum TransitionType { CROSS_FADE, SLIDE_UP, SLIDE_LEFT, SLIDE_DOWN, FADE_TO_BLACK, PUSH_MODAL, CEREMONY }` as a skeleton (used by Stories 003/005/006).
- Public API stubs (bodies in later stories):
  ```gdscript
  func request_screen(screen_id: String, transition: int = TransitionType.CROSS_FADE) -> void:
      # Story 003: node-swap + same-screen no-op + queue-on-TRANSITIONING.
      # For this story: if state == UNINITIALIZED, store in _queued_request and return.
      if state == State.UNINITIALIZED:
          _queued_request = {"screen_id": screen_id, "transition": transition}
          return

  func push_overlay(overlay_id: String, pause_on_open: bool = true) -> void:
      pass  # Story 007

  func pop_overlay(overlay_id: String) -> void:
      pass  # Story 007
  ```
- Resolve node paths to `MainRoot` children lazily (stored in `onready` vars) with fallback via `get_tree().root.get_node_or_null("MainRoot/ScreenContainer")` etc. Defensive null-check: a missing `MainRoot` scene must hard-fail with `push_error` + `assert` rather than silently no-op.
- Amend `docs/architecture/ADR-0003-autoload-rank-table-canonical.md` and `docs/architecture/architecture.md` §Autoload Rank Table to list the chosen concrete rank for `SceneManager` — closing OQ-8.

---

## Out of Scope

- Story 003: `request_screen` body (node-swap + same-screen detection + first-launch routing)
- Story 005: Tween transitions + `_active_transition_tween` management
- Story 007: `push_overlay` / `pop_overlay` bodies + pause counter
- Story 008: `scene_boundary_persist` emission

---

## QA Test Cases

- **TR-scene-manager-001** / **TR-scene-manager-009**: Autoload presence and DataRegistry gating
  - **Given**: fresh headless Godot 4.6 launch with SceneManager registered in `project.godot [autoload]`
  - **When**: scene tree inspected via `get_tree().root.get_node_or_null("SceneManager")` immediately after boot; `DataRegistry.registry_ready` has been mocked to NOT yet fire
  - **Then**: node resolves non-null; `SceneManager.state == SceneManager.State.UNINITIALIZED`; `SceneManager.current_screen == null`
  - **Edge cases**: if SceneManager rank is set less than DataRegistry rank (1), the STATE READ in `_ready()` would see `DataRegistry.state == UNLOADED` — the `connect()` path must still succeed (Amendment #1), and the defensive READY check must not false-positive

- **TR-scene-manager-012**: Four-state machine enum
  - **Given**: SceneManager script loaded
  - **When**: `SceneManager.State` enum inspected
  - **Then**: exactly four values — `UNINITIALIZED, IDLE, TRANSITIONING, PAUSED` — in that order
  - **Edge cases**: adding a fifth state would break the contract surface; test asserts `State.size() == 4` (or equivalent enum-length check)

- **ADR-0003 Amendment #3**: Zero-arg `_init`
  - **Given**: autoload definition parsed
  - **When**: Godot instantiates the autoload during boot
  - **Then**: no "Too few arguments for _init()" error; instance boots cleanly; `_init` signature is `func _init() -> void`
  - **Edge cases**: adding a required param would fail autoload construction silently — covered by boot-pass assertion

- **AC H-06 (partial, pre-Story-003)**: `request_screen` queued while UNINITIALIZED
  - **Given**: SceneManager in `UNINITIALIZED` (registry not ready)
  - **When**: `SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)` called
  - **Then**: `state` remains `UNINITIALIZED`; `_queued_request == {"screen_id": "guild_hall", "transition": 0}`; no signals fire; no transition starts
  - **Edge cases**: rapid back-to-back calls in UNINITIALIZED should each overwrite `_queued_request` (last-write-wins) — this partial rule is superseded by Story 003's full queue semantics

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene_manager/scene_manager_autoload_skeleton_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (MainRoot.tscn exists so the autoload can resolve node paths) — ✅ Complete (2026-04-26)
- **Unlocks**: Story 003 (autoload instance + state enum + `_queued_request` slot are prerequisites for `request_screen` body)

---

## Completion Notes

**Completed**: 2026-04-26
**Sprint**: Sprint 5 (S5-M4)
**Criteria**: 5/5 passing (zero deferred)
**Test Evidence**: Unit test at `tests/unit/scene_manager/scene_manager_autoload_skeleton_test.gd` — 13/13 PASS, 0 errors, 0 failures, 0 orphans, 83ms
**Code Review**: Complete — APPROVED verdict (godot-gdscript-specialist + qa-tester reviews; QA-flagged gaps F2/F4/F5 addressed inline before close)
**Gates skipped per solo mode**: QL-TEST-COVERAGE, LP-CODE-REVIEW

**Files created**:
- `src/core/scene_manager/scene_manager.gd` (254 lines) — Foundation autoload, rank 8. `extends Node`, no `class_name` (Sprint 1 lesson — autoload identifier already global). 4-state enum + 7-value TransitionType enum + 3 signal declarations + `_init() -> void: pass` (ADR-0003 Amendment #3) + `_ready()` with DataRegistry gating + late-subscription fallback. Public API stubs for `request_screen` (queues while UNINITIALIZED), `push_overlay`, `pop_overlay`. Private `_get_screen_container()` helper for Stories 003+.
- `tests/unit/scene_manager/scene_manager_autoload_skeleton_test.gd` (294 lines after fixes) — 13 tests across 4 groups (TR-001+TR-009 / TR-012 / Amendment #3 / AC H-06 partial).

**Files modified**:
- `project.godot` — `SceneManager="*res://src/core/scene_manager/scene_manager.gd"` added after BiomeDungeonDatabase
- `docs/architecture/ADR-0003-autoload-rank-table-canonical.md` — **Amendment #4 added (2026-04-26)**: rank 8 reassigned VACANT → SceneManager (Foundation), closing OQ-8. Per §Editing Protocol, claiming a vacant slot is preferred over reordering existing entries (which would have been required to insert at rank 7).
- `docs/architecture/architecture.md` — §Autoload Rank Table row 8 updated; "Ranks 8 and 9 deliberately vacant" footnote rewritten to "Rank 9 is deliberately vacant" only; stale "rank 8 vacant" reference at line 305 corrected.
- `docs/architecture/control-manifest.md` — Manifest Version bumped 2026-04-24 → **2026-04-26**; ADRs Covered list updated to "ADR-0003 (Amendments #1–#4)".

**Critical decision (proactively resolved)**: SceneManager → rank 8. Story recommended "6 or 7" but those slots were occupied (rank 6 = BiomeDungeonDatabase, rank 7 = HeroRoster documented-but-unimplemented). Per ADR-0003 line 374, "leaving slots vacant is preferable to a reorder (which §Editing Protocol forbids without a superseding ADR)". Inserting at rank 7 would have been a forbidden reorder; claiming the vacant rank 8 was the editing-protocol-conformant move. ADR Amendment #4 documents this. **OQ-8 CLOSED.**

**Deviations (advisory, all addressed)**:
1. Story originally embedded Manifest Version 2026-04-24; this story's implementation bumped manifest to 2026-04-26 in lockstep with ADR-0003 Amendment #4. Story file Manifest Version field updated to 2026-04-26 at close.
2. Test file initially had a misleading docstring claiming a `get_queued_request()` accessor — corrected to accurately describe direct-attribute access (GDScript underscore is convention only).
3. Test B-01 originally constructed a 4-element array (would not catch a fifth State value being added). Strengthened with `State.size() == 4` + `State.keys().size() == 4` enum-introspection assertions to catch contract drift.
4. Test A-03 originally only checked `current_screen == null`; added `current_screen_id == ""` companion assertion.

**Regression**: `tests/unit/save_load/` 88/88 PASS post-autoload addition; `tests/integration/scene_manager/` 18/18 PASS (S5-M3 still green).

**Tech debt advisories deferred** (non-blocking, may be addressed in Story 003 or as a tech-debt ticket):
- F1: AC #5 ADR amendment half not auto-tested at runtime (relies on manual grep + `/architecture-review` for drift detection)
- F3: Late-subscription fallback path not isolated from forward-subscription path
- F6: `is_connected("registry_ready", ...)` not directly asserted

**Unlocks**: S5-M5 (SceneManager Story 003 — `request_screen` body) is now implementable. The autoload instance, state enum, TransitionType enum, and `_queued_request` slot are all ready for the body fill.
