# ADR-0008: UI Framework — Dual-Focus Parity, Tap-Target Enforcement, and Parchment Theme

> **Amendment 2026-06-03 (font system) — playtest legibility fix.** The "two-font
> system" decision below (custom Information + Identity faces, wired as Lora + IM
> Fell English in Sprint 20) is **suspended**. Playtest found the faces "not clear";
> per user decision the theme now ships **no custom font face** — every Control falls
> back to Godot's built-in default sans-serif. Sizes, colors, the 16px/24px
> legibility floors, and all other ADR-0008 decisions are unchanged, and the
> two-font-MAX invariant still holds (zero ≤ two). This deviates from Art Bible §7's
> illuminated-manuscript typography aspiration — that direction is deferred to a
> future polish pass, not retired (the TTFs remain on disk). See DESIGN.md
> §Typography and the `parchment_theme.tres` header note.

## Status

Accepted (font system amended 2026-06-03 — see top note)

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — engine pattern validation (pending Step 4.5)
- technical-director — solo mode skip (review-mode.txt = solo; gate TD-ADR not invoked)
- Source of truth: `design/art/art-bible.md` Section 7 UI/HUD Visual Direction; `.claude/docs/technical-preferences.md` Input & Platform; `docs/engine-reference/godot/modules/ui.md`

## Summary

Codifies the UI Framework as a **non-autoload module** consisting of (a) a single canonical `Theme` resource at `assets/ui/parchment_theme.tres`, (b) a static helper script `ui_framework.gd` (no Node, no autoload — pure static functions), and (c) a binding contract with every `Control` subclass in the project. Locks the **mouse/touch-only input model** (gamepad explicitly out of scope per technical-preferences.md); the **single-focus-mode strategy** that sidesteps Godot 4.6's dual-focus complexity by simply not implementing keyboard/gamepad navigation in MVP; the **44×44 logical-pixel tap-target floor** (enforced via `assert_tap_target_min(control)` debug-only helper); the **Steam Deck 1280×800 theme scaling strategy**; the **two-font system** (Information + Identity); and the **parchment-with-warm-vignette UI background rule**. Surfaces but does not resolve the V1.0 keyboard/gamepad navigation question (deferred via OQ-9 to Settings/Accessibility GDD #30).

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Rendering (Theme, Control, mouse_filter, focus_mode, font import, viewport scaling) |
| **Knowledge Risk** | MEDIUM — Godot 4.6 dual-focus UI system is post-cutoff (not in LLM training data); Recursive Control disable (4.5) is post-cutoff; FoldableContainer (4.5) is post-cutoff. Stable: Theme resource, mouse_filter, font import, viewport scaling. |
| **References Consulted** | `docs/engine-reference/godot/modules/ui.md`; `docs/engine-reference/godot/breaking-changes.md` (4.6 dual-focus, 4.5 FoldableContainer + Recursive disable, 4.5 AccessKit screen reader); `docs/engine-reference/godot/current-best-practices.md`; `design/art/art-bible.md` §7; `.claude/docs/technical-preferences.md` Input & Platform; `docs/architecture/ADR-0007-scene-transition-and-persist-coupling.md` (Note 3 — dual-focus coordination flagged for this ADR) |
| **Post-Cutoff APIs Used** | Godot 4.6 dual-focus system (acknowledged; SIDESTEPPED by not implementing keyboard nav in MVP); Godot 4.5 Recursive Control disable (used for `OverlayLayer` background dimming); Godot 4.5 AccessKit screen reader hooks (deferred to V1.0 Accessibility GDD) |
| **Verification Required** | Steam Deck 1280×800 viewport + parchment theme rendering — needs actual hardware test before MVP ship (no Steam Deck in dev loop currently per architecture.md OQ-5). Theme color contrast against parchment ground for Slate Ink body text — colorblind safety per Art Bible §4 must be verified end-to-end with Section 4 palette pairs flagged at risk. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0007 (Scene Transition + Persist Coupling, Accepted) — `OverlayLayer` background dimming uses 4.5 Recursive Control disable; `Screen` base class extends `Control` so theme application cascades. ADR-0006 (Data Loading) — UI Framework is loaded at boot but does NOT depend on `DataRegistry.registry_ready` (theme resource loads inline during scene tree init, not via DataRegistry's content scan). |
| **Enables** | All 7 MVP UI screens (each binds to the Parchment theme via inheritance); the Settings overlay implementation (uses `FoldableContainer` for collapsible category sections); future Accessibility GDD #30 (screen reader hooks land on top of the theme + tap-target framework codified here). |
| **Blocks** | UIFramework theme authoring epic; all 7 Presentation-layer screen implementations (each needs the Parchment theme + tap-target helper available); Settings overlay implementation. |
| **Ordering Note** | Final Foundation ADR. After this ADR is Accepted, all 6 Foundation ADRs (F01-F06 → ADR-0003 through ADR-0008) are complete; in a fresh session run `/architecture-review` to populate `tr-registry.yaml`, then `/create-control-manifest`, then re-attempt `/create-epics`. |

## Context

### Problem Statement

Architecture.md identified ADR-F06 with these decisions to lock:
1. **Godot 4.6 dual-focus visuals** — mouse/touch focus is now separate from keyboard/gamepad focus (post-cutoff change). What does the project do with this?
2. **Tap-target enforcement** — Art Bible mandates ≥44×44 logical px on all interactive elements; how is this enforced (compile-time / runtime / convention)?
3. **Steam Deck 1280×800 theme scaling** — Steam Deck is a first-class target (per technical-preferences.md); the Parchment theme must render correctly at this resolution.
4. **Parchment theme structure** — Art Bible §7 specifies a comprehensive visual direction (parchment ground, ink borders, slate ink + lantern gold + guild amber palette, two-font system); how is this encoded as a Godot `Theme` resource?

ADR-0007 also flagged a follow-up coordination point (Note 3): the 4.6 dual-focus system means keyboard/gamepad focus is NOT blocked by the TransitionLayer's `MOUSE_FILTER_STOP` input-blocker. If the project ever adds keyboard navigation, a complementary focus-disabling step during TRANSITIONING is needed.

### Current State

- `.claude/docs/technical-preferences.md` Input & Platform section explicitly says: **"Gamepad Support: None"** (rationale: idle game UX is click/tap-driven; Steam Deck users use trackpad/touchscreen). **"Keyboard (shortcuts only)"** — keyboard is for shortcuts (e.g., Esc for Settings), NOT navigation.
- `design/art/art-bible.md` §7 UI/HUD Visual Direction is complete: tap targets ≥44×44, two-font system, parchment palette, animation timing budgets, semi-diegetic framing philosophy, "warm miniature feel inside menus" (parchment + ink ornaments + lantern-underlit background + warm-on-warm typography).
- `docs/engine-reference/godot/modules/ui.md` documents the 4.6 dual-focus change with Common Mistakes including: "Assuming `grab_focus()` affects mouse focus (keyboard/gamepad only in 4.6)" and "Not testing UI with both mouse and gamepad after upgrading to 4.6".
- ADR-0007 §Risks documents that 4.6 dual-focus is a known V1.0 risk only (since gamepad is out of scope for MVP).
- Architecture.md §Module Ownership / UIFramework currently says "(theme resource + helpers, not autoload)" — confirmed: this ADR locks that pattern.
- No UI Framework code exists yet. No `parchment_theme.tres` exists. No `ui_framework.gd` exists. This ADR + the implementation epic create them from scratch.

### Constraints

- **Mouse + Touch parity is non-negotiable from MVP**. Per Pillar 1 + the technical-preferences mobile-port plan, every interaction must work with a single finger tap. No hover-only state reveals. No right-click-only actions. No drag precision under 24 logical pixels.
- **Tap targets ≥44×44 logical pixels** is from Art Bible §7 + technical-preferences.md. Apple HIG and Material Design both converge on this floor; mobile-port readiness depends on it.
- **Steam Deck 1280×800 native, 60fps stable** is the Steam Deck target per technical-preferences.md. Portrait-capable layouts keep mobile port cheap.
- **Two fonts maximum** per Art Bible §7 Typography Direction. One Information font + one Identity font. Using a third font is an explicit Art Bible violation.
- **Body text minimum 16px logical**, identity font minimum 24px logical. Font legibility floor per Art Bible §UX Constraints.
- **Animation budget: ≤150ms standard / ≤800ms ceremony** per Art Bible §UX Constraints — this is enforced at the SceneManager level (ADR-0007), not the UI Framework level. UI Framework's job is to support the timing, not enforce it.
- **No idle animation demands attention** — pulses, glows, ambient motion must be subtle. Per Art Bible §UX Constraints.
- **Colorblind safety** — Art Bible §4 mandates icon/shape backup cues for color-coded states (matchup effectiveness, biome identity). UI Framework must support the icon-shape pattern at the theme level.
- **Localization-ready** — all UI text via `tr()`; labels use `AUTOWRAP_WORD_SMART` for variable-length translations. Per ui.md best practices.
- Godot 4.6 dual-focus system is a known constraint that the project sidesteps by not implementing keyboard/gamepad nav.

### Requirements

- UIFramework MUST be a **non-autoload module** — Theme resource + static helper script. No Node, no `_ready()`, no signals from the framework itself.
- The Parchment theme MUST be a single canonical `Theme` resource at `assets/ui/parchment_theme.tres`. All Control nodes inherit from it via `MainRoot.theme = preload(...)`.
- Tap-target enforcement MUST be **debug-build-only assertion** (runtime cost in production is unacceptable for Pillar 1 perf budget); convention + code review enforce in production.
- Steam Deck 1280×800 MUST render the Parchment theme correctly without per-resolution theme variants. One theme; viewport scaling via Godot's `content_scale_mode`.
- The theme MUST encode the Art Bible §4 palette as named theme constants (no hardcoded `Color()` calls in UI code).
- The two-font system MUST be enforced via theme `default_font` and per-class font overrides; using a third font requires editing the theme (visible in code review).
- `mouse_filter` MUST default to `MOUSE_FILTER_STOP` on interactive Controls (so they consume tap events); `MOUSE_FILTER_PASS` on decorative Controls (parchment background, ink ornaments).
- Keyboard focus visuals MUST be SUPPRESSED by default (since keyboard nav is out of scope); the 4.6 dual-focus system's keyboard/gamepad focus indicator MUST NOT render.
- The framework MUST NOT block future addition of keyboard/gamepad nav — V1.0 Accessibility GDD will revisit.
- AccessKit screen reader hooks (4.5+) are deferred to V1.0 Accessibility GDD; MVP does not implement them but does NOT actively prevent them either.

## Decision

### Module structure (NOT an autoload)

```
assets/ui/
  parchment_theme.tres         # canonical Theme resource — single source of truth
  fonts/
    info_font.ttf              # Information font (humanist sans-serif/semi-serif, hand-lettered tradition)
    identity_font.ttf          # Identity font (illuminated manuscript display, used sparingly ≥24px)
  textures/
    parchment_bg.png           # tileable parchment texture
    ink_ornament_corner_*.png  # 1-4 px ornaments per corner per panel
    advantage_arrow_up.png     # icon-shape cue (matchup advantage)
    disadvantage_arrow_down.png
    neutral_circle.png

src/ui/
  ui_framework.gd              # static helper module — NO Node, NO autoload
                               # Functions: assert_tap_target_min(control) — debug only
                               #            apply_parchment_panel(control) — convenience binder
                               #            wire_touch_feedback(control) — 1.05× scale 80ms tween helper
```

`ui_framework.gd` is loaded as a `class_name` script (`class_name UIFramework`); accessed via static-method calls (`UIFramework.assert_tap_target_min(button)`). NOT autoloaded. NOT registered in ADR-0003 rank table. Pure stateless utility.

### Single-focus-mode strategy (sidesteps 4.6 dual-focus complexity)

The project explicitly does NOT implement keyboard/gamepad navigation in MVP per technical-preferences.md. This makes the 4.6 dual-focus system a non-issue for MVP: only mouse/touch focus matters; keyboard/gamepad focus is suppressed at the theme level.

```gdscript
# IMPORTANT (godot-specialist Step 4.5 Note 1): focus_mode is NOT a Theme-settable property.
# Godot's Theme stores colors / font sizes / styleboxes / constants only — NOT focus_mode.
# focus_mode must be set per Control instance, either:
#   (a) in the .tscn Inspector for each interactive Control, OR
#   (b) via UIFramework.suppress_keyboard_focus(root) walking the tree at _ready time
#
# Example UIFramework helper:
#   static func suppress_keyboard_focus(root: Control) -> void:
#       for node in root.find_children("*", "Control", true, false):
#           if node is Button or node is TextureButton or node is BaseButton:
#               (node as Control).focus_mode = Control.FOCUS_NONE
#
# Mouse hover state is independent of focus_mode — driven by the mouse-focus path
# in 4.6's dual-focus system. Hover stylebox + hover font_color in the theme still apply.
```

**Rationale**:
- Setting `focus_mode = FOCUS_NONE` at the theme level prevents the 4.6 dual-focus visual fragmentation issue (mouse focus and keyboard focus rendering simultaneously on different controls).
- Keyboard shortcuts (Esc for Settings, hypothetical) trigger actions via `_unhandled_input` action mapping — NOT via focus + activation. So suppressing focus doesn't break shortcut handling.
- V1.0 Accessibility GDD #30 may re-introduce keyboard nav. At that point, this ADR is superseded by an Accessibility-extension ADR that re-enables `FOCUS_ALL` on interactive controls + adds the keyboard focus visual + adds a SceneManager focus-disable step during TRANSITIONING (per ADR-0007 §Risks Note 3).

### Tap-target enforcement: 44×44 logical pixels

```gdscript
# In src/ui/ui_framework.gd
class_name UIFramework

const MIN_TAP_TARGET_LOGICAL_PX: int = 44

# Debug-only assertion — runtime cost in production is unacceptable for Pillar 1 perf
# Production builds: convention + code review enforce
static func assert_tap_target_min(control: Control) -> void:
    if not OS.is_debug_build():
        return
    var size := control.get_combined_minimum_size()
    if size.x < MIN_TAP_TARGET_LOGICAL_PX or size.y < MIN_TAP_TARGET_LOGICAL_PX:
        push_error("[UIFramework] Tap target below 44px floor: %s (size=%s)" %
            [control.name, size])
        # Note: push_error in debug, NOT assert(false) — designers iterating layouts
        # may temporarily break this; we want to flag it loudly without crashing the editor

# Convenience binder — applies the parchment-panel sub-theme to a Control + its children
# (uses 4.5 Recursive Control behavior to cascade mouse_filter on children if pattern == DECORATIVE)
static func apply_parchment_panel(panel: Control, pattern: PanelPattern = PanelPattern.STANDARD) -> void:
    panel.theme_type_variation = "ParchmentPanel"   # named theme variation in parchment_theme.tres
    if pattern == PanelPattern.DECORATIVE:
        panel.mouse_filter = Control.MOUSE_FILTER_PASS  # decorative panels don't intercept taps
    # else STANDARD — mouse_filter inherited from theme variation default (STOP for interactive)
```

**Enforcement strategy**:
- Every interactive Control (`Button`, `TextureButton`, `ItemList` items, hero card panels, formation slot drop targets) calls `UIFramework.assert_tap_target_min(self)` in its `_ready()`.
- Code review checklist item: every interactive Control must have the assertion call.
- CI grep enforces presence of the call in `extends Control` or `extends Button`/`TextureButton` files.

### Steam Deck 1280×800 + viewport scaling

```gdscript
# In project.godot via Project Settings → Display → Window:
[display]
window/size/viewport_width = 1920
window/size/viewport_height = 1080
window/stretch/mode = "canvas_items"           # canvas_items mode preserves crisp pixel art at non-native res
window/stretch/aspect = "expand"                # 1280×800 has aspect 1.6 vs 1920×1080 1.78 — expand fills horizontally and vertically; UI margins absorb the difference
window/stretch/scale_mode = "fractional"       # fractional scaling for non-integer ratios
```

**Steam Deck rendering target**:
- Native 1280×800 = aspect 1.6
- Reference design 1920×1080 = aspect 1.78
- `expand` aspect mode means the canvas extends to fill the actual viewport without letterboxing; UI elements anchored to the edges adapt naturally; central content remains centered.
- Tap targets at 44 logical px render at 44 actual px on Steam Deck (viewport scale ratio ~0.667; 44 logical → 29 actual px would be too small, but `canvas_items` stretch mode treats logical pixels as a unit that scales WITH the viewport — 44 logical at 1920×1080 reference becomes 29 actual at 1280×800, which is below the 44 actual px floor for fingertip-touch).

**Important — the 44-px floor is a LOGICAL pixel target for mobile-port readiness, NOT an actual-device-pixel target on Steam Deck** (godot-specialist Step 4.5 Note 2 + user decision Option A 2026-04-22). Per technical-preferences.md: "Steam Deck users use the trackpad/touchscreen" — the trackpad is mouse-precise (no 44-px floor needed); the touchscreen is the secondary path on Steam Deck. The 44-px floor is primarily a MOBILE port concern where the logical-pixel-to-device-pixel mapping (handled by the platform's DPI scaling) produces finger-friendly output. Steam Deck's touchscreen accepts 33 actual px because trackpad is the primary input on that device.

**Decision**: use `canvas_items` stretch mode + `keep` aspect mode (preserves pixel-perfect rendering of pixel art — Art Bible §UX Constraints "no soft edges on pixel art"). The 44-logical-px floor is a MOBILE port guarantee; Steam Deck inherits it via the design resolution but its touchscreen renders at the smaller actual pixel size.

```gdscript
# Project Settings → Display → Window:
window/size/viewport_width = 1920
window/size/viewport_height = 1080
window/stretch/mode = "canvas_items"           # preserves crisp pixel art (no scale-down pass on the rendered buffer)
window/stretch/aspect = "keep"                 # preserve aspect ratio; letterbox or pillarbox as needed
                                                # 1280×800 (1.6) vs 1920×1080 (1.78): horizontal letterbox bands appear
                                                # alternative: "expand" extends the canvas to fill (edge-anchored UI adapts)
```

**Per-platform tap-target tuning is deferred to V1.0** (OQ-10): if Steam Deck hardware testing reveals 33 actual px is too small for the touchscreen path, raise `MIN_TAP_TARGET_LOGICAL_PX` to 60 in a Steam-Deck-specific build OR document the trackpad-primary expectation in onboarding. Not a blocker for MVP because:
- Trackpad is the primary Steam Deck input per technical-preferences.md
- Mobile port (when authored) gets 44 actual px via the platform's logical-pixel mapping
- Desktop PC at 1920×1080 reference renders 44 actual px exactly

**MVP implementation note**: Project Settings configuration is a one-time write. Story acceptance criterion verifies: a 44 logical px button at 1920×1080 reference resolution renders correctly via `canvas_items` stretch mode; Steam Deck touchscreen tap-target validation deferred until hardware available (architecture.md OQ-5).

### Parchment theme structure

```gdscript
# parchment_theme.tres Theme resource (encoded via Inspector or ResourceSaver):
#
# Default font:                  info_font.ttf @ 16px
# Default font color:            Slate Ink (Art Bible §4)
# Background pattern:            parchment_bg.png tileable (per panel via theme_type_variation)
#
# Per-Control-class overrides:
#   Button:
#     font: info_font @ 18px
#     color (normal):    Slate Ink on Parchment Cream
#     color (hover):     Lantern Gold on Parchment Cream         # mouse hover state — 4.6 mouse-focus path
#     color (pressed):   Parchment Cream on Guild Amber          # touch/tap state
#     focus_mode:        FOCUS_NONE                              # suppresses keyboard/gamepad focus visual
#     stylebox (normal): parchment panel with ink-flourish corners (custom 9-slice)
#     mouse_filter:      MOUSE_FILTER_STOP                       # consumes tap events (default for interactive)
#   Label:
#     font: info_font @ 16px (body) — overridable per use site
#     color: Slate Ink
#     autowrap_mode: AUTOWRAP_WORD_SMART                          # localization-ready
#   RichTextLabel:
#     font: info_font @ 16px
#     bbcode_enabled: true
#   PanelContainer (theme_type_variation: ParchmentPanel):
#     stylebox: parchment_bg.png 9-slice + ink ornament corners + warm vignette
#     mouse_filter: MOUSE_FILTER_STOP   # default; override to PASS for decorative-only panels
#   FoldableContainer (4.5+, used for Settings categories):
#     header stylebox: parchment with ink-drawn chevron icon
#     content_padding: 8px
#
# Identity font (use sparingly, ≥24px):
#   theme_type_variation "IdentityHeader":
#     font: identity_font.ttf @ 32px
#     color: Lantern Gold on Slate Ink ground (Victory banners, biome titles)
```

The theme is **the single source of truth for UI visuals**. Hardcoded `Color()` calls or per-control style overrides in code are FORBIDDEN — see Forbidden Patterns below.

### Mouse hover state preserved (mouse-focus path of dual-focus)

Per ui.md: in 4.6, mouse hover is the mouse-focus path (separate from keyboard-focus). Setting `focus_mode = FOCUS_NONE` suppresses ONLY the keyboard/gamepad focus visual — mouse hover continues to work via the theme's `:hover` pseudo-state on Controls (e.g., Button has hover stylebox + hover font color).

```gdscript
# Example: Button in parchment_theme.tres:
# State "normal":  font_color = Slate Ink,  stylebox = parchment_panel_normal
# State "hover":   font_color = Lantern Gold, stylebox = parchment_panel_hover (subtle warm border)
# State "pressed": font_color = Parchment Cream, stylebox = guild_amber_solid
# State "focus":   (suppressed by focus_mode = FOCUS_NONE)
# State "disabled": font_color = Slate Ink @ 50% alpha, stylebox = parchment_panel_disabled
```

Hover state communicates interactivity on PC (mouse). Tap state (pressed) provides immediate touch feedback. Focus state is intentionally absent.

### Touch feedback (1.05× scale, 80ms) — owned by individual screens, not theme

Per Art Bible §7 Animation Feel + scene-screen-manager GDD §C.6 RECOMMEND: touch feedback (1.05× scale pulse, 80ms duration, return to 1.0× in 1 frame) is owned by individual screen nodes via per-button `Tween` invocations, NOT encoded in the theme.

```gdscript
# In src/ui/ui_framework.gd
static func wire_touch_feedback(control: Control) -> void:
    control.gui_input.connect(func(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed:
            _play_touch_pulse(control)
        elif event is InputEventScreenTouch and event.pressed:
            _play_touch_pulse(control)
    )

static func _play_touch_pulse(control: Control) -> void:
    var tween := control.create_tween()
    tween.tween_property(control, "scale", Vector2(1.05, 1.05), 0.08)
    tween.tween_property(control, "scale", Vector2.ONE, 0.016)  # 1 frame return
```

Screens call `UIFramework.wire_touch_feedback(button)` in their `_ready()` for any interactive control needing the pulse. This keeps the theme resource focused on visuals (not animation orchestration) and lets individual screens opt out for performance-critical screens (Dungeon Run View has many on-screen elements; touch feedback per-element would explode tween count).

### `mouse_filter` default policy

```gdscript
# Theme-encoded defaults per Control subclass:
# Button, TextureButton:         MOUSE_FILTER_STOP    (consumes tap events)
# Panel, PanelContainer:         MOUSE_FILTER_STOP    (default; override to PASS for decorative-only panels)
# Label, RichTextLabel:          MOUSE_FILTER_PASS    (text doesn't intercept taps)
# Container subclasses:          MOUSE_FILTER_PASS    (containers shouldn't block; their interactive children do)
# TextureRect (decorative):      MOUSE_FILTER_IGNORE  (parchment background, ink ornaments — never intercept)
```

The 4.5 Recursive Control disable feature is used selectively, BUT (godot-specialist Step 4.5 Note 3): only `MOUSE_FILTER_IGNORE` cascades recursively in 4.5+; `MOUSE_FILTER_STOP` does NOT cascade. The TransitionLayer input-blocker uses `MOUSE_FILTER_STOP` on a single full-screen Control to consume taps directly (no cascade needed — the Control captures input at its level). The `OverlayLayer` background dimming Control uses `MOUSE_FILTER_STOP` on the dim Control itself + `MOUSE_FILTER_IGNORE` (which DOES cascade) on its decorative children. Implementation must keep the two filter values straight: STOP captures + blocks at one level; IGNORE cascades to disable a whole subtree.

### Architecture diagram

```
                         ┌──────────────────────────────────────┐
                         │ assets/ui/                           │
                         │   parchment_theme.tres ◄─────────────┤ Single canonical Theme resource
                         │   fonts/info_font.ttf                │
                         │   fonts/identity_font.ttf            │
                         │   textures/parchment_bg.png          │
                         │   textures/ink_ornament_*.png        │
                         │   textures/advantage_arrow_*.png     │
                         └──────────────────┬───────────────────┘
                                            │ preload at MainRoot.theme
                                            ▼
                         ┌──────────────────────────────────────┐
                         │ MainRoot.tscn (per ADR-0007)         │
                         │   theme = parchment_theme.tres       │
                         │     ↓ inherits to all Control descendants
                         │   PersistentHUDLayer / Screen /      │
                         │   TransitionLayer / OverlayLayer     │
                         └──────────────────┬───────────────────┘
                                            │
                                            │ UIFramework static helpers (NOT autoload)
                                            ▼
                         ┌──────────────────────────────────────┐
                         │ src/ui/ui_framework.gd               │
                         │ ─────────────────────────────────── │
                         │ class_name UIFramework               │
                         │ const MIN_TAP_TARGET_LOGICAL_PX = 44 │
                         │ static assert_tap_target_min(c)      │
                         │ static apply_parchment_panel(c, p)   │
                         │ static wire_touch_feedback(c)        │
                         └──────────────────────────────────────┘
                                            ▲
                                            │ called from individual screens' _ready()
                                            │
                         ┌──────────────────────────────────────┐
                         │ All 7 MVP UI screens (extend Screen) │
                         │  - inherit theme via tree            │
                         │  - call assert_tap_target_min on     │
                         │    every interactive Control         │
                         │  - call wire_touch_feedback on       │
                         │    interactive Controls needing pulse│
                         └──────────────────────────────────────┘

Project Settings → Display → Window:
  stretch/mode = "viewport"      (render at 1920x1080 reference)
  stretch/aspect = "keep_height" (preserve vertical resolution; horizontal letterbox on Steam Deck 1280x800)
  → Tap targets stay at 44 actual px on Steam Deck (viewport scale ratio 0.741 vertical)
```

### Key interfaces

```gdscript
# src/ui/ui_framework.gd
class_name UIFramework

const MIN_TAP_TARGET_LOGICAL_PX: int = 44

enum PanelPattern { STANDARD, DECORATIVE }

# Debug-only tap-target assertion (production no-op via OS.is_debug_build() guard)
static func assert_tap_target_min(control: Control) -> void

# Convenience binder for parchment panels (theme variation + mouse_filter policy)
static func apply_parchment_panel(panel: Control, pattern: PanelPattern = PanelPattern.STANDARD) -> void

# Touch feedback pulse (1.05× scale, 80ms, return in 1 frame) — opt-in per Control
static func wire_touch_feedback(control: Control) -> void
```

```gdscript
# In every screen's _ready() or per-interactive-control init:
func _ready() -> void:
    UIFramework.assert_tap_target_min(%RecruitButton)
    UIFramework.wire_touch_feedback(%RecruitButton)
    # ... per interactive control
```

```gdscript
# parchment_theme.tres is loaded once at MainRoot:
# In MainRoot.tscn or its root script:
@onready var _theme: Theme = preload("res://assets/ui/parchment_theme.tres")
func _ready() -> void:
    theme = _theme  # cascades to all Control descendants via Godot's theme inheritance
```

## Alternatives Considered

### Alternative 1: Implement full keyboard/gamepad nav in MVP (engage with 4.6 dual-focus complexity)

- **Description**: Set `focus_mode = FOCUS_ALL` on all interactive Controls; design keyboard navigation paths via `focus_neighbor_*`; add a complementary focus-disable step in SceneManager during TRANSITIONING (per ADR-0007 Note 3); add separate visual treatments for mouse-focus (hover) vs keyboard-focus (focus ring) per the 4.6 dual-focus system.
- **Pros**: Full accessibility from MVP; gamepad players can navigate without trackpad; keyboard navigation is a desktop convenience; matches AAA UX expectations.
- **Cons**: technical-preferences.md explicitly says "Gamepad Support: None" (rationale: idle game UX is click/tap-driven). Adding keyboard nav requires designing `focus_neighbor_*` graphs for every screen (significant per-screen authoring overhead). Dual-focus visuals (mouse hover ring + keyboard focus ring rendering simultaneously) require theme work to coordinate. ADR-0007 Note 3 (focus-disable during TRANSITIONING) becomes a hard requirement instead of a deferred V1.0 risk. MVP timeline pressure (4-6 weeks) makes this scope creep significant.
- **Estimated Effort**: ~2 stories of theme work + ~0.5 story per screen × 7 screens + 1 story of SceneManager focus-disable integration.
- **Rejection Reason**: Out of scope per technical-preferences.md. The single-focus-mode strategy sidesteps the entire dual-focus complexity for zero MVP cost; V1.0 Accessibility GDD revisits when accessibility becomes a first-class scope item.

### Alternative 2: Per-screen Theme resources (one Theme per screen)

- **Description**: Each of the 7 MVP screens has its own Theme resource (`assets/ui/themes/guild_hall_theme.tres`, etc.). Screens load their theme on `on_enter`. Allows per-screen visual variation (e.g., Victory Moment uses a more saturated palette).
- **Pros**: Maximum visual flexibility per screen; designers can A/B different theme variants per screen.
- **Cons**: Theme inconsistency across screens defeats Art Bible's "warm room never empties" framing. Per-screen themes fragment the visual identity. Color palette drift becomes a real risk (each theme can independently use a slightly-off Slate Ink). Asset overhead: 7 themes × overlapping content = duplication.
- **Estimated Effort**: ~2-3x of chosen approach.
- **Rejection Reason**: The Art Bible §UI Palette mandates "the UI palette does not shift by biome — the interface remains consistently warm and parchment-grounded regardless of which dungeon floor is visible behind it." Per-screen themes would fragment this consistency. Single canonical theme with `theme_type_variation` for occasional per-screen accents is the right scope.

### Alternative 3: Programmatic theme construction at boot (no `.tres` file)

- **Description**: Build the Theme resource in code at boot via `Theme.new() + theme.set_color() + theme.set_font_size() + theme.set_stylebox()`. Eliminates the `.tres` file; theme lives in `ui_framework.gd` as a constructor function.
- **Pros**: Theme values are diff-friendly in code review (no opaque `.tres` binary blob). Theme is generated, not authored — so it's harder for designers to drift it from the Art Bible spec accidentally.
- **Cons**: Loses Godot's Theme editor (designers lose the visual preview tool). Hot-reload of theme changes requires app restart (vs `.tres` edit + reimport). Asset pipeline integration (font import, texture atlas packing) still requires external `.tres`/import files anyway, so the "no file" claim is a partial truth.
- **Estimated Effort**: Comparable.
- **Rejection Reason**: `.tres` is the engine-native theme authoring path. Designers iterating on visual feel benefit from the Theme editor's preview. Diff-friendliness concern is real but addressable: `.tres` files ARE text-format Godot resources, diffable in Git. The chosen approach preserves designer workflow + diffability.

## Consequences

### Positive

- **Sidesteps 4.6 dual-focus complexity at zero MVP cost**. By not implementing keyboard/gamepad nav, the project avoids the dual-focus visual fragmentation issue entirely. V1.0 Accessibility GDD #30 revisits when scope warrants.
- **Single canonical theme = visual consistency by construction**. Art Bible's "warm parchment never shifts by biome" is enforced at the engine level — there's no second theme to drift from.
- **Tap-target enforcement is debug-only-cost**. Production builds pay zero runtime cost; debug builds catch violations loudly via `push_error`.
- **Steam Deck rendering is correct by design**. `viewport` stretch mode + `keep_height` aspect = tap targets stay at 44 actual px on the smaller display; pixel art accepts one viewport-scale-down pass (acceptable quality loss).
- **Localization-ready from MVP**. AUTOWRAP_WORD_SMART on Labels + tr() for all strings + theme-encoded font sizing accommodates variable text length.
- **Resolves architecture.md OQ-5 partial**. Steam Deck testing access is still a production risk (no hardware in dev loop), but the rendering strategy is now codified — when hardware arrives, the test surface is clear.
- **Coordinates with ADR-0007 Note 3**. The dual-focus / keyboard-nav coordination point is now explicitly deferred to V1.0 Accessibility, with the path documented.

### Negative

- **No keyboard/gamepad nav in MVP**. Players who prefer keyboard or gamepad input have no navigation path. Mouse + touch + keyboard shortcuts (Esc, etc.) only.
- **Steam Deck touchscreen tap targets render at 33 actual px** (44 logical × 800/1080 vertical scale). Acceptable per the trackpad-primary expectation; if hardware testing reveals this is uncomfortable, OQ-10 is the V1.0 fallback (per-platform tap-target override). The 44-px floor remains a mobile-port guarantee, not a Steam Deck guarantee.
- **Tap-target enforcement is convention-dependent in production**. Debug build catches violations; release builds rely on code review + the assert having fired during dev. A regression that ships an under-44-logical-px button won't be caught at runtime in production.
- **Steam Deck letterbox/pillarbox**. With `canvas_items` + `keep` aspect, players see horizontal letterbox bands on Steam Deck (1.6 aspect vs 1.78 reference). Acceptable per Art Bible's "warm document framed by darkness" framing.
- **Touch feedback pulse opt-in (not theme-encoded)**. Per-screen `wire_touch_feedback()` calls are easy to forget. Mitigation: code review + AC verification per screen.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A future ADR or story attempts to add keyboard nav without revisiting `focus_mode = FOCUS_NONE` | Medium | Medium (keyboard focus would render on dual-focus visual; mouse hover + keyboard focus simultaneously) | This ADR documents the single-focus-mode strategy; V1.0 Accessibility GDD must explicitly supersede the FOCUS_NONE default before re-enabling keyboard nav |
| Steam Deck native testing reveals tap targets are still too small (44 actual px feels small at arm's length on the Steam Deck's 7" display) | Medium | Low-Medium (UX issue; not crash) | Architecture.md OQ-5 already flags Steam Deck testing as a production risk; mitigation is per-platform tap-target override (e.g., 48 actual px floor on Steam Deck) once hardware testing happens |
| Designer hardcodes a `Color()` call in screen code instead of using a themed color | Medium | Low (visual drift) | Forbidden pattern: `hardcoded_color_in_ui_code` (registered below); CI grep enforces |
| Designer uses a third font in a screen (violates "two fonts max" Art Bible rule) | Medium | Low (visual drift) | Forbidden pattern: `third_font_in_ui` (registered below); CI grep enforces |
| `viewport` stretch mode causes blurry text on the Steam Deck because subpixel rendering doesn't survive the scale-down | Low | Medium (text legibility) | Use Godot's TextServer subpixel positioning; verify legibility on Steam Deck hardware before MVP ship |
| `wire_touch_feedback` opt-in is forgotten on a key interactive button | Medium | Low (perceived responsiveness drops on that button) | Code review checklist; UI playtest catches per-button feedback gaps |
| Future story adds an interactive Control without calling `assert_tap_target_min` | Medium | Low-Medium (under-44px button ships) | CI grep for files extending `Control` / `Button` / `TextureButton` checks for the assertion call presence |
| AccessKit screen reader hooks (4.5+) become a player demand post-launch | Low | Medium (accessibility regression vs competitors) | V1.0 Accessibility GDD #30 explicitly inherits this ADR's framework; AccessKit hooks layer on top of theme without superseding it |
| `focus_mode` is set per-instance, not via Theme — implementer reads "theme-level default" and looks for a non-existent Theme inspector field | Medium | Low (one-iteration confusion; corrected by reading the helper) | The Decision section now explicitly notes focus_mode is per-instance + provides the `UIFramework.suppress_keyboard_focus(root)` helper pattern. (godot-specialist Step 4.5 Note 1) |
| Implementer confuses `MOUSE_FILTER_STOP` with `MOUSE_FILTER_IGNORE` for the recursive-cascade feature; only IGNORE cascades in 4.5+ | Medium | Medium (overlay dimming may not block underlying input correctly OR transition input-blocker may unexpectedly cascade where not intended) | Decision section corrected to specify: STOP captures + blocks at one level; IGNORE cascades to disable a subtree. OverlayLayer pattern: STOP on dim Control + IGNORE on decorative children. (godot-specialist Step 4.5 Note 3) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU per UI render | N/A | Theme lookup is cached per-Control; negligible per-frame cost | 16.6ms per frame |
| CPU per `assert_tap_target_min` call | N/A | Single `get_combined_minimum_size()` call + comparison; debug-only, ~10μs | Debug-only; not in production budget |
| CPU per `wire_touch_feedback` Tween | N/A | One Tween allocation per tap (~80μs) + per-frame interpolation (~5μs/frame for 80ms = 5 frames) | Tween creation rate is bounded by tap rate (≤10/s realistic) |
| Memory (Theme + assets) | N/A | parchment_theme.tres ~50KB + 2 fonts ~500KB each + textures ~200KB total = ~1.3MB persistent | 256MB mobile ceiling; 0.5% of budget |
| Memory (per-Control theme inheritance) | N/A | Godot caches theme lookups per-Control; zero per-instance memory cost beyond Control's own size | Negligible |
| Save file size impact | N/A | `reduce_motion` is the only theme-related field that persists (per ADR-0007); ~1 byte | Within ADR-0004 budget |

## Migration Plan

**No migration required for MVP** — no UI Framework code exists yet; this ADR codifies the contracts the first MVP UI implementation will follow.

**Steam Deck stretch mode change** is a one-time `project.godot` Display section update; no code migration required.

**Future post-MVP changes**:
- **V1.0 Accessibility GDD #30 supersedes the single-focus-mode strategy**: when keyboard/gamepad nav is added, this ADR is partially superseded by an Accessibility ADR that re-enables `FOCUS_ALL` + adds dual-focus visual coordination + adds the SceneManager focus-disable during TRANSITIONING (per ADR-0007 Note 3).
- **AccessKit screen reader hooks** are added on top of the theme + framework codified here without superseding either; layered enhancement.
- **Theme variants** (e.g., a "high contrast" mode for accessibility) extend `parchment_theme.tres` via `theme_type_variation`s, NOT separate Theme resources — preserves the single-canonical-theme principle.

**Rollback plan**: If the single-focus-mode strategy proves problematic in playtesting (e.g., a tester complains they can't navigate without a mouse), supersede with Alternative 1 (full keyboard nav). Theme adjustment + per-screen `focus_neighbor_*` graphs + SceneManager focus-disable. Significant work but localized to the UI layer.

## Validation Criteria

- [ ] `parchment_theme.tres` exists at `assets/ui/parchment_theme.tres`; encodes Art Bible §4 palette as theme constants; encodes Art Bible §7 typography (info_font + identity_font); encodes per-Control-class hover/pressed/disabled states; suppresses focus_mode at the theme default level.
- [ ] `src/ui/ui_framework.gd` exists with `class_name UIFramework`; exposes `MIN_TAP_TARGET_LOGICAL_PX = 44`, `assert_tap_target_min`, `apply_parchment_panel`, `wire_touch_feedback`.
- [ ] Every interactive Control in every MVP screen has `UIFramework.assert_tap_target_min(self)` called in its `_ready()`; CI grep verifies.
- [ ] No hardcoded `Color(...)` calls in UI screen code (CI grep for `Color(` outside `assets/ui/` and theme-author files; flag as ERROR).
- [ ] No third-font import in `assets/ui/fonts/` (CI grep verifies only `info_font.ttf` and `identity_font.ttf` are committed).
- [ ] `project.godot` Display section uses `stretch/mode = "viewport"` + `stretch/aspect = "keep_height"`.
- [ ] Steam Deck 1280×800 native test: 44 logical px button measures ≥44 actual px on the device (deferred until hardware available; tracked in OQ-5 production risk).
- [ ] AUTOWRAP_WORD_SMART set on all Label theme defaults; tr() used for all UI strings (CI grep for hardcoded UI strings).
- [ ] All UI screens render correctly at 1280×800 via editor preview (one-time validation pre-MVP-ship).
- [ ] Colorblind safety: matchup effectiveness icons use Lantern Gold upward triangle (advantage) + Parchment Cream circle (neutral) + Dusk Purple downward triangle (disadvantage) — shape-coded per Art Bible §4.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/art/art-bible.md` §7 UX Constraints | UI Framework | "Tap targets ≥44×44 logical pixels on all interactive elements" | Codifies `MIN_TAP_TARGET_LOGICAL_PX = 44` constant + debug-only `assert_tap_target_min` helper + code review enforcement. |
| `design/art/art-bible.md` §7 UX Constraints | UI Framework | "Touch/mouse parity from MVP — no hover-only, no right-click-only, no drag <24px precision" | Mouse hover state preserved via 4.6 mouse-focus path (theme :hover state); tap state via :pressed state; focus_mode FOCUS_NONE suppresses keyboard-only paths. |
| `design/art/art-bible.md` §7 UX Constraints | UI Framework | "Font legibility floor: body min 16px logical; identity font min 24px logical" | Theme encodes default body font @ 16px; identity font theme variation @ 32px (≥24px floor). |
| `design/art/art-bible.md` §7 Typography Direction | UI Framework | "Two fonts maximum: Information + Identity; identity font used sparingly ≥24px" | Theme encodes exactly two fonts (info_font, identity_font); third font is a forbidden pattern. |
| `design/art/art-bible.md` §7 Animation Feel | UI Framework + Screens | "Touch feedback: 1.05× scale, 80ms, return in 1 frame" | `UIFramework.wire_touch_feedback(control)` helper; opt-in per interactive Control; Art Bible-spec'd values. |
| `design/art/art-bible.md` §7 Preserving Warm Miniature | UI Framework | "Parchment texture with warm vignette; ink flourish corners; lantern-underlit background; warm-on-warm typography" | Encoded as theme StyleBoxes for PanelContainer + theme_type_variation "ParchmentPanel"; ornament textures committed to assets/ui/textures/. |
| `design/art/art-bible.md` §UI Palette | UI Framework | "UI palette does not shift by biome — single warm parchment theme" | Single canonical Theme resource; per-screen themes are FORBIDDEN per Alternative 2 rejection. |
| `.claude/docs/technical-preferences.md` Input & Platform | UI Framework | "Mouse (primary), Touch (mobile parity), Keyboard (shortcuts only); Gamepad: None; Steam Deck 1280×800 60fps" | Single-focus-mode strategy (FOCUS_NONE default) — sidesteps dual-focus; Steam Deck via viewport stretch + keep_height aspect; tap targets ≥44 actual px on device. |
| `docs/architecture/ADR-0007` §Risks Note 3 | (cross-cutting) | "4.6 dual-focus: keyboard/gamepad focus is NOT blocked by MOUSE_FILTER_STOP on TransitionLayer" | Resolved at the source: keyboard focus is suppressed by FOCUS_NONE default at the theme level; ADR-0007 Note 3 is moot for MVP (no keyboard nav exists). V1.0 Accessibility GDD revisits. |
| `docs/architecture/architecture.md` §Module Ownership / UIFramework | (cross-cutting) | "(theme resource + helpers, not autoload)" | Locks the non-autoload pattern; theme + static helper script structure codified. |
| `docs/architecture/architecture.md` Open Question OQ-5 | (cross-cutting) | "Steam Deck 1280×800 testing access" | Partially addressed: rendering strategy codified (viewport + keep_height); hardware testing remains a production risk. Tracked in §Risks. |

## Related Decisions

- ADR-0003 (Autoload Rank Table, Accepted; amended) — UIFramework is NOT in the rank table (non-autoload); confirmed pattern.
- ADR-0007 (Scene Transition + Persist Coupling, Accepted) — `Screen` base class extends `Control`; theme cascades via tree; OverlayLayer dimming uses Recursive Control disable; Note 3 keyboard-focus coordination resolved by single-focus-mode strategy in this ADR.
- Future V1.0 Accessibility GDD #30 — supersedes parts of this ADR when keyboard/gamepad nav + AccessKit screen reader hooks are added.
- `design/art/art-bible.md` §7 — full UI/HUD visual direction (this ADR's source of truth).
- `.claude/docs/technical-preferences.md` Input & Platform — gamepad-out-of-scope rationale.
- `docs/engine-reference/godot/modules/ui.md` — 4.6 dual-focus, 4.5 FoldableContainer + Recursive disable, 4.5 AccessKit notes.

## Open Questions Created by This ADR

- **OQ-9 (V1.0 keyboard/gamepad navigation strategy)**: When V1.0 Accessibility GDD #30 lands, decide whether to (a) re-enable FOCUS_ALL + design focus_neighbor graphs per screen, (b) implement an alternate input mode (e.g., D-pad emulation of mouse cursor on gamepad), or (c) rely on Steam Deck's trackpad-as-mouse fallback for accessibility. Decision is part of GDD #30 + a follow-up Accessibility ADR.

- **OQ-10 (Steam Deck per-platform tap-target override — RESCOPED 2026-04-22 per user decision Option A)**: With `canvas_items` stretch mode + 44 logical px floor, Steam Deck touchscreen tap targets render at 33 actual px (44 × 800/1080). Acceptable per trackpad-primary expectation. If hardware testing reveals 33 actual px is uncomfortable on the Steam Deck touchscreen, raise `MIN_TAP_TARGET_LOGICAL_PX` to 60 in a Steam-Deck-specific build (60 × 0.741 ≈ 44 actual px) OR document trackpad-primary expectation in onboarding. Resolution: defer to Steam Deck hardware testing.
