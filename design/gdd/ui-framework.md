# UI Framework / Theme — GDD #18

> **Status: First-pass DRAFT 2026-05-06** by autonomous-execution session. All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. **Reverse-documentation:** the UI Framework has been shipped + iteratively-evolved across Sprints 5–13; this GDD formalizes the contract that's already in source. Run `/design-review` to surface contract drift between this GDD and the live implementation.

---

## A. Overview

**UI Framework** is the **foundational presentation layer** every screen and Control depends on. It owns:

1. **The parchment Theme** (`assets/ui/parchment_theme.tres`) — canonical Theme Resource shipped in S10-M1 per ADR-0008. Defines fonts, panel/overlay/button StyleBoxFlats, theme-type-variations.
2. **The Screen base class** (`src/core/scene_manager/screen.gd`) — every screen extends this; declares `on_enter` / `on_exit` / `on_pause` / `on_resume` lifecycle hooks per ADR-0007.
3. **Static helper functions in `UIFramework`** (`src/ui/ui_framework.gd`) — non-autoload utility functions wrapping recurring UI patterns: tap-target enforcement, parchment-panel application, touch-pulse feedback wiring, suppress-keyboard-focus, locale-format-safe wrapper.
4. **Touch + tap-target invariants** — every interactive Control must satisfy MIN_TAP_TARGET_LOGICAL_PX (44px Steam Deck baseline). Touch-pulse animation on press (1.05× scale, 80ms expand, ~16ms return) per Art Bible §7.

The framework is **stateless** (no autoload, no singleton state); helpers are static functions. UIFramework consumers (screens) hold their own state; the framework provides the canonical patterns + theme.

---

## B. Player Fantasy

> *"The interface looks like the world: warm parchment, hand-set type, soft buttons that respond when I press them. Nothing harsh, nothing flat, nothing modal-overlay-grey. Every tap feels intentional."*

The UI is the visual half of the cozy register. Players spend most of their session looking at UI — guild_hall, formation_assignment, recruit screen — so consistency + craft here drive the felt experience more than gameplay surface area does.

Design pillars (locked by Art Bible §3 + §7):
- **Parchment palette only** — no pure white, no black-on-white. Warm parchment background; ink-brown text; terracotta + sage accent colors.
- **Touch feedback on every press** — every interactive Control gets the 1.05× scale pulse on press. Press = "the parchment flexes". This is the canonical "I tapped something" moment.
- **No hover-only affordances** — desktop and Steam Deck and mobile all access the same surface. Hover effects are decorative, not informational.
- **Tap targets ≥44 logical pixels** — Steam Deck native + mobile parity. Smaller is invisible to fingers.

---

## C. Detailed Rules

### C.1 The parchment Theme

`assets/ui/parchment_theme.tres` is the canonical Theme Resource shipped per ADR-0008. Used by:
- Every screen's root Control (via project's UI theme set in project.godot)
- Every PanelContainer that opts into ParchmentPanel theme variation
- The Settings overlay (per Settings GDD #30 §C.1)

Theme content (per S10-M1 closure):
- 2 SystemFonts (info_font, identity_font) with OS fallback chains
- 4 panel/overlay StyleBoxFlats (PanelContainer base, ParchmentPanel variation, OverlayDimPlate, IdentityHeader)
- 4 button-state StyleBoxFlats (Normal, Hover, Pressed, Disabled)
- Default-style overrides for Label / RichTextLabel / Button / PanelContainer / LineEdit
- Theme variations: ParchmentPanel, OverlayDimPlate, IdentityHeader, SelectedSlotButton

Asset deferrals (open per S10-M1): TTF font sourcing for `info_font.ttf` + `identity_font.ttf` (Sprint 14+ polish); parchment + ink ornament PNG textures (Sprint 14+ polish). Until the .ttf / .png assets land, the Theme uses Godot's default fonts + flat StyleBoxFlat colors. Functionally complete; visually placeholder.

### C.2 The Screen base class

`src/core/scene_manager/screen.gd` defines:

```gdscript
class_name Screen extends Control

@export var transition_override_ms: int = 0

func on_enter() -> void: pass
func on_exit() -> void: pass
func on_pause() -> void: pass
func on_resume() -> void: pass
```

Every screen MUST extend `Screen` and MUST declare all 4 lifecycle hooks (empty bodies acceptable; silently omitting any is FORBIDDEN per `.claude/rules/check_screen_hooks.sh`).

Lifecycle contract (ADR-0007):
- `on_enter`: connect signals, initialize UI from data model
- `on_exit`: disconnect signals, flush in-flight work; node will be queue_freed after this returns
- `on_pause`: modal overlay opened on top; pause animations/timers/tooltips
- `on_resume`: modal closed; restore animations/timers/tooltips

`transition_override_ms` allows per-screen entrance-transition duration override; 0 means use SceneManager default. Negative values clamp to 0 with push_warning.

Process-mode warning: children of a Screen subclass inherit `PROCESS_MODE_PAUSABLE` from ScreenContainer. Children that need to run during modal pause must explicitly set `PROCESS_MODE_ALWAYS` on themselves. Tweens created inside Screen children inherit `Tween.TWEEN_PAUSE_BOUND`; freeze during modal pause unless explicitly set to `TWEEN_PAUSE_PROCESS`.

### C.3 Static helper functions

#### C.3.a `apply_parchment_panel(panel, pattern = PanelPattern.STANDARD)`

Applies the ParchmentPanel theme variation (decorative parchment-textured panel) to a Control. PanelPattern enum:
- STANDARD: full parchment styling (StyleBoxFlat with parchment color + texture)
- DECORATIVE: parchment background + ink ornament (mouse_filter PASS so taps fall through to children)

Per ADR-0008 §apply_parchment_panel: opt-in per Control rather than encoded in the theme, because:
- Theme cannot tween animations (the touch-pulse needs runtime control)
- Performance-dense screens (DungeonRunView) may opt out per-element to keep tween count bounded

Idempotent via `_PARCHMENT_META` sentinel — calling twice doesn't double-apply.

#### C.3.b `wire_touch_feedback(control)`

Wires a 1.05× scale pulse on `gui_input` mouse-button-down OR screen-touch-down events. Per Art Bible §7 Animation Feel: "stately with warm snappiness". Pulse expands over 80ms, returns over ~16ms (1 frame at 60Hz).

S12-M6 AC-AS-14/15 amendment: the same `gui_input` event also fires `sfx_ui_tap` via AudioRouter. Visual pulse + audio chime fire together on every interactive Control press.

Idempotent via `_TOUCH_FEEDBACK_META` sentinel.

Pulse constants (locked by AC-29-14 + Art Bible):
- `TOUCH_PULSE_SCALE: Vector2 = Vector2(1.05, 1.05)`
- `TOUCH_PULSE_EXPAND_SEC: float = 0.08`
- `TOUCH_PULSE_RETURN_SEC: float = 0.016`

A future tuning pass that violates these without a corresponding Art Bible update fails the test at `tests/unit/ui_framework/ui_framework_helpers_test.gd:test_ui_framework_wire_touch_feedback_pulse_constants_match_art_bible`.

#### C.3.c `suppress_keyboard_focus(root)`

Recursively sets `focus_mode = Control.FOCUS_NONE` on every interactive Control under `root`. Used by screens that don't want keyboard / gamepad navigation (the project's primary input is mouse/touch per `.claude/docs/technical-preferences.md`).

#### C.3.d `assert_tap_target_min(control)`

Debug-build helper that asserts `control.size.x >= MIN_TAP_TARGET_LOGICAL_PX AND control.size.y >= MIN_TAP_TARGET_LOGICAL_PX`. Used in screen `_ready` to catch tap-target regressions in development. Release builds skip the assert.

`MIN_TAP_TARGET_LOGICAL_PX = 44` per Steam Deck native (1280×800) + mobile parity per `.claude/docs/technical-preferences.md`.

#### C.3.e `format_localized(key, args)`

Safe-format wrapper around `tr()` that handles the headless-test path. In headless, `TranslationServer.translate(StringName(key))` returns the raw key when locale isn't loaded; `key % args` would then raise "not all arguments converted" if the key has no `%` specifier.

Implementation: check for `%` in the format string; if present, apply `format % args`; otherwise return `format` with args appended as space-separated suffix (so headless test output is still human-readable).

S10-N1 closure: Object's `tr()` is an instance method, NOT callable from a static helper — so this helper uses `TranslationServer.translate(StringName)` (the singleton) instead of `tr()`.

### C.4 Tap-target invariant enforcement

Every interactive Control in the project (Button, CheckButton, OptionButton, HSlider, custom Control with `gui_input` connection) MUST satisfy:
- `size.x >= 44 AND size.y >= 44` at the smallest supported resolution (Steam Deck 1280×800)

Enforcement options (debug-build only):
- Per-screen `assert_tap_target_min(control)` calls in `_ready`
- Future CI grep: scan .tscn files for Button nodes with explicit size < 44 (Sprint 15+ candidate)

V1.0+ accessibility: increase MIN_TAP_TARGET_LOGICAL_PX to 56 for an "Accessibility Mode" toggle (NOT in MVP scope).

### C.5 Theme application discipline

**Project.godot's `gui/theme/custom = "res://assets/ui/parchment_theme.tres"`** is the global default. Every Control inherits unless explicitly overridden.

ScreenContainer (the SceneManager's mounting parent) inherits the global theme. Screen subclasses inherit from ScreenContainer. PanelContainers within screens that opt into ParchmentPanel via `UIFramework.apply_parchment_panel` get the parchment styling; others get the default Panel style.

The Settings overlay (Settings GDD #30) + Return-to-App Screen + future modals all apply ParchmentPanel for the cozy-register visual cohesion.

### C.6 Locale + i18n hooks

Every player-facing string MUST go through `tr()` (or `UIFramework.format_localized` for `%`-formatted strings) per `.claude/rules/ui-code.md`. Hardcoded user-facing strings are forbidden.

`assets/locale/en.csv` is the canonical English translation file (Godot's CSV translation format). Strings are added incrementally per feature (audio cues, formation labels, run-end overlay, etc.).

V1.0+ multi-locale: TranslationServer.set_locale switches at runtime; `format_localized` continues to work without changes.

---

## D. Formulas

### D.1 No formulas — pure presentation layer

UI Framework has no gameplay math. The touch-pulse animation curve is `Tween.TRANS_LINEAR + EASE_IN_OUT` per ADR-0008 §Touch feedback; not a math knob.

---

## E. Edge Cases

### E.1 Headless / no display
Every static helper must be safe to call in headless Godot mode. `apply_parchment_panel` writes theme_type_variation (works without renderer). `wire_touch_feedback` connects gui_input (no events fire in headless; safe). `suppress_keyboard_focus` walks the tree (safe). `format_localized` works headless (the canonical use case).

### E.2 Theme resource missing
If `assets/ui/parchment_theme.tres` fails to load (corrupt file, missing on disk), Godot falls back to the engine default theme. UI renders flat-grey instead of parchment; functional but visually broken. push_warning + manual recovery (re-import the theme).

### E.3 Calling `apply_parchment_panel` on a non-Container Control
`apply_parchment_panel` sets `theme_type_variation = "ParchmentPanel"` on the passed Control. If the Control is not a PanelContainer / Panel, the theme variation has no visual effect (the StyleBoxFlat is keyed to the PanelContainer node type). Defensive: push_warning if `not (panel is PanelContainer or panel is Panel)`.

### E.4 `wire_touch_feedback` on a Control with existing gui_input subscribers
Idempotent via meta sentinel. Subsequent calls are no-ops (don't re-connect, don't double-fire pulse). The first connection wires; subsequent calls skip.

### E.5 Tap target violation in production build
The `assert_tap_target_min` debug-build assert is bypassed in release. Tap targets that shrink below 44px in production are visually still the wrong size but don't crash. Mitigation: visual QA + manual screenshot review per `production/qa/visual-checklist.md`.

### E.6 Mouse + touch input on the same Control
gui_input fires for both `InputEventMouseButton` AND `InputEventScreenTouch`. `_on_touch_feedback_input` handles both. No special platform handling needed; the same Control works on Steam Deck's trackpad + touchscreen + mobile.

### E.7 Tween already running on a Control during `wire_touch_feedback` press
A `_play_touch_pulse(control)` call creates a new Tween targeting `control.scale`. If a prior pulse's tween is still mid-animation, the new tween co-exists with the old one — both Tweens write to `scale`, producing a glitch. Mitigation: each pulse cancels the previous tween via the per-Control `_active_pulse_tween` meta. Documented in ui_framework.gd.

### E.8 Null Control passed to any static helper
Every static helper checks for null and push_errors + returns without mutation. Tested per `tests/unit/ui_framework/ui_framework_helpers_test.gd:test_ui_framework_wire_touch_feedback_null_control_does_not_crash`.

---

## F. Dependencies

### Hard dependencies (UI Framework requires these)

| System | Why | Surface used |
|---|---|---|
| Godot 4.6 Theme system | Parchment theme is a Theme Resource | `Control.theme_type_variation`, `theme.set_*`, project.godot global theme |
| Godot 4.6 Tween system | Touch-pulse animation | `create_tween()`, `tween_property` |
| `TranslationServer` | Locale-format-safe wrapper | `TranslationServer.translate(StringName)` |
| `AudioRouter` (#28) — soft | UI tap chime per S12-M6 AC-AS-14/15 | `play_sfx(&"sfx_ui_tap")` (lookup via Engine.get_main_loop().root.get_node_or_null) |

### Reverse dependencies (systems that depend on UI Framework)

EVERY UI screen + overlay:
- Guild Hall (#19), Recruit Screen (#21), Roster Screen (#22), Matchup Assignment Screen (#23), Dungeon Run View (#24), Unlock / Victory Moment (#25), Return-to-App Screen (#20), formation_assignment, main_menu, Settings overlay (#30)

Plus systems that need the Screen base class:
- SceneManager (#4) — instantiates Screen subclasses + manages their lifecycle

---

## G. Tuning Knobs

### MIN_TAP_TARGET_LOGICAL_PX (int = 44)
- Range: 32–80. Below 32: Steam Deck unreachable. Above 80: cramped on mobile-portrait layouts.
- V1.0 accessibility may bump to 56 via a settings toggle.

### TOUCH_PULSE_SCALE (Vector2 = Vector2(1.05, 1.05))
- Range: (1.02, 1.02) to (1.10, 1.10). Below 1.02 imperceptible; above 1.10 cartoonish.
- Locked by Art Bible §7; changes require Art Bible update.

### TOUCH_PULSE_EXPAND_SEC (float = 0.08)
- Range: 0.05–0.15. Below 0.05 jittery; above 0.15 sluggish.

### TOUCH_PULSE_RETURN_SEC (float = 0.016)
- Range: 0.008–0.040 (1 frame at 120Hz to ~2.5 frames at 60Hz).

### Parchment Theme palette
- Locked by Art Bible §3 (parchment hex codes). NOT runtime tunable.

---

## H. Acceptance Criteria

**AC-18-01 — parchment_theme.tres loads at boot**
Project.godot's `gui/theme/custom` points at `res://assets/ui/parchment_theme.tres`; Godot loads the resource without error. Theme has ≥4 PanelContainer variations + ≥4 Button states.

**AC-18-02 — Screen base class declares 4 lifecycle hooks**
`Screen` extends Control; declares `on_enter` / `on_exit` / `on_pause` / `on_resume` as `func` (no abstract). Tested per `tests/unit/scene_manager/screen_base_class_test.gd`.

**AC-18-03 — `apply_parchment_panel` sets ParchmentPanel theme_type_variation**
Calling on a PanelContainer: `panel.theme_type_variation == "ParchmentPanel"`. Idempotent: meta sentinel prevents double-application. Tested per `ui_framework_helpers_test.gd`.

**AC-18-04 — `wire_touch_feedback` connects exactly one gui_input handler**
Calling on a Button: `button.gui_input.get_connections().size()` increases by exactly 1. Subsequent calls do not increase further. Tested.

**AC-18-05 — Touch pulse constants match Art Bible**
`TOUCH_PULSE_SCALE == Vector2(1.05, 1.05)`, `TOUCH_PULSE_EXPAND_SEC ≈ 0.08`, `TOUCH_PULSE_RETURN_SEC ≈ 0.016`. Tested per `test_ui_framework_wire_touch_feedback_pulse_constants_match_art_bible`.

**AC-18-06 — `wire_touch_feedback` fires UI tap chime per S12-M6**
Mouse-button-down on a wired Control: `AudioRouter._test_play_sfx_log` contains an entry with `sfx_id == &"sfx_ui_tap"`. Touch press: same. Release: NO chime. Tested per `tests/unit/ui_framework/ui_framework_helpers_test.gd` Group D.

**AC-18-07 — `format_localized` returns sensible output in headless test mode**
With locale not loaded: `format_localized("known_key", [42])` returns either the substituted text or the raw key + space-separated args. Never crashes on missing key + format mismatch. Tested.

**AC-18-08 — `suppress_keyboard_focus` zeroes focus on all descendants**
After call, every Control under root has `focus_mode == FOCUS_NONE`. Includes nested Containers + dynamically-added children if called after structure stable.

**AC-18-09 — Null-safe**
Passing null to any static helper produces push_error + early return. No crash. Tested per existing helpers.

**AC-18-10 — `MIN_TAP_TARGET_LOGICAL_PX` is 44**
Constant value 44 per Steam Deck native + mobile parity per `.claude/docs/technical-preferences.md`. Static value, no test needed beyond grep.

---

## I. Open Questions & ADR Candidates

**OQ-18-1 — TTF font sourcing**
`info_font.ttf` + `identity_font.ttf` are deferred per S10-M1 closure. The Theme currently uses Godot's default fonts (likely Noto Sans Regular). Sprint 14+ polish: source 2 free-license fonts that match the parchment register (e.g., a serif body face + a slightly-decorative display face). Out of MVP scope; visual polish.

**OQ-18-2 — Parchment + ink ornament PNG textures**
StyleBoxFlat currently uses flat colors. Sprint 14+ polish: source/author parchment + ink ornament PNG textures referenced in StyleBoxTexture. Out of MVP scope.

**OQ-18-3 — Tap-target CI grep**
A pre-implementation script that scans .tscn files for Button nodes with explicit min_size < 44 would catch regressions at content-author time, not test time. Sprint 15+ candidate.

**OQ-18-4 — Reduce-motion interaction with touch-pulse**
S12-S2 reduce_motion clamps standard transitions to 50ms; does it apply to the 80ms touch-pulse? MVP says NO — the touch-pulse is per-Control feedback, not a screen transition. Per S12-S2 §AC: "touch feedback (1.05× scale, 80ms) stays per-button, not transition". Documented; not a knob.

**OQ-18-5 — Opt-out per Control for touch chime**
Some Controls (sliders, scroll bars) drag through many press events; the chime would over-fire. Audio-system.md §F.2 throttles `sfx_ui_tap` via the gold-chime-style throttle? Currently NO — only `sfx_reward_gold_collected` is throttled (250ms window). UI tap chime fires per gui_input event. If playtest reveals slider-drag is too noisy, add throttle in AudioRouter (Sprint 15+).

---

## J. Implementation Sequencing (already done — reverse-documentation)

This GDD is reverse-documentation: the implementation has shipped across:
- Sprint 5–8: initial Screen base class + SceneManager wiring
- Sprint 10 S10-M1: parchment_theme.tres canonical content
- Sprint 10 S10-M2: `apply_parchment_panel` + `wire_touch_feedback` static helpers
- Sprint 10 S10-N1: `format_localized` static helper
- Sprint 12 S12-M6 AC-AS-14/15: UI tap chime hook in `wire_touch_feedback`

No Sprint 14+ implementation work needed for the framework itself. Outstanding asset-sourcing items:
1. **Sprint 14+ asset sourcing** (~0.5d) — TTF fonts (OQ-18-1).
2. **Sprint 14+ asset sourcing** (~0.5d) — parchment + ink ornament PNG textures (OQ-18-2).
3. **Sprint 15+** (~0.25d) — Tap-target CI grep script (OQ-18-3).
4. **Sprint 15+** (~0.25d) — UI tap chime throttle if playtest needs (OQ-18-5).

Total post-GDD asset/polish work: ~1.5d. None of this gates MVP shipping.

---

## Notes

- Authored 2026-05-06 by autonomous-execution session as REVERSE-DOCUMENTATION of an already-shipped framework. The GDD's purpose is to formalize the contract that 7+ UI screens (and Settings overlay #30) depend on.
- Run `/design-review` to surface contract drift between this GDD and live source. Expected verdict: CONCERNS rather than NEEDS REVISION (the implementation is correct; the documentation is the artifact).
- Closes the design-coverage gap that's existed since project inception. systems-index.md row 18 ("Not Started" since Sprint 1) flips to DRAFT.
