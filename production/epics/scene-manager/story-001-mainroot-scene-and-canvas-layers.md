# Story 001: MainRoot.tscn persistent-root scene + four CanvasLayer children

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-002, TR-scene-manager-019
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary) + ADR-0008 (theme preload cascade)
**ADR Decision Summary**: `MainRoot.tscn` is the always-loaded root scene with four children — `PersistentHUDLayer` (CanvasLayer, layer=10, `PROCESS_MODE_ALWAYS`), `ScreenContainer` (Node, `PROCESS_MODE_PAUSABLE`), `TransitionLayer` (CanvasLayer, layer=100, `PROCESS_MODE_ALWAYS`), `OverlayLayer` (CanvasLayer, layer=110, `PROCESS_MODE_ALWAYS`). `MainRoot.theme = preload("res://assets/ui/parchment_theme.tres")` so theme cascades to every `Control` descendant. `SceneTree.change_scene_to_*` is architecturally forbidden — this scene never unloads.

**Engine**: Godot 4.6 | **Risk**: MEDIUM-HIGH
**Engine Notes**: CanvasLayer composition is stable since 4.0 (LOW engine risk on its own), but `PROCESS_MODE_PAUSABLE` on `ScreenContainer` cascades to Screen children by default — per-screen children that need to keep running during modal pause (idle particles, persistent counter tweens) MUST explicitly set `PROCESS_MODE_ALWAYS` on the child (ADR-0007 Risks Note 4). 4.5 `CanvasItem.visible` recursive disable changed in 4.5 — verify lifecycle-hook ordering unaffected when a transition tweens visibility. `MOUSE_FILTER_STOP` does NOT cascade to children in 4.5+ (only `MOUSE_FILTER_IGNORE` does) — relevant for the input-block Control wired in Story 005.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: Persistent root scene = `MainRoot.tscn` with four CanvasLayer children: `PersistentHUDLayer` (layer=10, `PROCESS_MODE_ALWAYS`), `ScreenContainer` (Node, `PROCESS_MODE_PAUSABLE`), `TransitionLayer` (layer=100, `PROCESS_MODE_ALWAYS`), `OverlayLayer` (layer=110, `PROCESS_MODE_ALWAYS`). — ADR-0007
- **Required**: `MainRoot.theme = preload("res://assets/ui/parchment_theme.tres")` cascades to all Control descendants. — ADR-0008
- **Forbidden**: Never call `SceneTree.change_scene_to_packed()` / `change_scene_to_file()` or any equivalent — all changes via `SceneManager.request_screen`. — ADR-0007
- **Forbidden**: Never assume `MOUSE_FILTER_STOP` cascades to children — only `MOUSE_FILTER_IGNORE` cascades in 4.5+. — ADR-0007, ADR-0008

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-002: "Persistent CanvasLayers: PersistentHUDLayer (layer=10), TransitionLayer (layer=100), OverlayLayer (layer=110); ScreenContainer swap target"
- [ ] TR-scene-manager-019: "Node process modes: ScreenContainer/gameplay=PROCESS_MODE_PAUSABLE; HUD/Transition/Overlay=PROCESS_MODE_ALWAYS"
- [ ] `MainRoot.tscn` is set as project main scene in `project.godot` (`run/main_scene`)
- [ ] `MainRoot.theme` preload wiring present per ADR-0008

---

## Implementation Notes

*Derived from ADR-0007 §Persistent root scene architecture + ADR-0008 §Parchment theme structure:*

- Create `src/core/scene_manager/MainRoot.tscn` with a root `Node` named `MainRoot`. Add four children in this order (child index matters for rendering fallback, but CanvasLayer `layer` is the authoritative z-order driver):
  1. `PersistentHUDLayer: CanvasLayer` — `layer = 10`, `process_mode = Node.PROCESS_MODE_ALWAYS`
  2. `ScreenContainer: Node` — `process_mode = Node.PROCESS_MODE_PAUSABLE` (default for the layer; screens added as children will pause on `get_tree().paused = true`)
  3. `TransitionLayer: CanvasLayer` — `layer = 100`, `process_mode = Node.PROCESS_MODE_ALWAYS`; add a child `ColorRect` (anchor full rect, `modulate.a = 0.0`, color = black) for cross-fade / fade-to-black; add a child `Control` (anchor full rect, `mouse_filter = MOUSE_FILTER_IGNORE` by default) reserved for the input-block wired in Story 005.
  4. `OverlayLayer: CanvasLayer` — `layer = 110`, `process_mode = Node.PROCESS_MODE_ALWAYS`
- Attach `src/core/scene_manager/main_root.gd` as the `MainRoot` script (class_name `MainRoot extends Node`) — contains only `theme = preload("res://assets/ui/parchment_theme.tres")` assignment in `_ready()`. No business logic. (If `parchment_theme.tres` has not yet been authored in the UI Framework epic, document the dependency in the story and use a placeholder empty `Theme` resource — the preload path is the load-bearing commitment.)
- Update `project.godot` `[application] run/main_scene = "res://src/core/scene_manager/MainRoot.tscn"`. Remove any prior default scene reference.
- Do NOT add `SceneManager` script to this scene — the autoload skeleton lives in Story 002 and references `MainRoot` by node path after boot.
- Per ADR-0007 Risks Note 4: add a doc-comment in `main_root.gd` stating that Screen children inherit `PROCESS_MODE_PAUSABLE` from `ScreenContainer` and must explicitly override to `PROCESS_MODE_ALWAYS` for animations that continue during modal pause.

---

## Out of Scope

- Story 002: SceneManager autoload skeleton + state machine (this story is pure scene composition; no script logic yet)
- Story 003: `request_screen` API + node-swap (reads `ScreenContainer` path)
- Story 005: TransitionLayer input-block `Control` activation (a placeholder child Control may be declared here, but `mouse_filter` toggling is Story 005)
- Parchment theme authoring (owned by the UI Framework epic)

---

## QA Test Cases

- **TR-scene-manager-002**: CanvasLayer composition and layer values
  - **Given**: headless Godot 4.6 launch with `MainRoot.tscn` as the main scene
  - **When**: test queries `get_tree().root.get_node("MainRoot")` and each named child
  - **Then**: all four children resolve; `PersistentHUDLayer.layer == 10`, `TransitionLayer.layer == 100`, `OverlayLayer.layer == 110`; `ScreenContainer` is a `Node` (not CanvasLayer)
  - **Edge cases**: any child missing or mistyped must hard-fail the test (no silent default). `TransitionLayer.layer > OverlayLayer.layer` would be a regression — assert strict ordering.

- **TR-scene-manager-019**: Process mode assignments
  - **Given**: `MainRoot.tscn` loaded
  - **When**: test reads `process_mode` on each child node
  - **Then**: `PersistentHUDLayer`, `TransitionLayer`, `OverlayLayer` all equal `Node.PROCESS_MODE_ALWAYS`; `ScreenContainer` equals `Node.PROCESS_MODE_PAUSABLE`
  - **Edge cases**: a misconfigured `PROCESS_MODE_INHERIT` on a CanvasLayer would silently behave as ALWAYS on root — assert exact equality, not inherited-equivalent

- **ADR-0008 theme cascade**: Parchment theme preload wiring
  - **Given**: `MainRoot.tscn` loaded and `_ready()` has fired
  - **When**: test reads `MainRoot.theme`
  - **Then**: non-null `Theme` resource; resource path equals `res://assets/ui/parchment_theme.tres` (or the documented placeholder if the UI Framework epic has not yet produced the real theme)
  - **Edge cases**: theme resource load failure must surface as a boot error, not a silent null

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/mainroot_scene_composition_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (foundational scene composition)
- **Unlocks**: Story 002 (SceneManager skeleton references `MainRoot` node paths)
