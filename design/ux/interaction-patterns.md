# Interaction Pattern Library: Lantern Guild

> **Status**: Draft (v0.1 — seeded)
> **Author**: ux-designer
> **Last Updated**: 2026-04-24
> **Version**: 0.1
> **Engine**: Godot 4.6
> **UI Framework**: Godot Control nodes (parchment theme per ADR-0008)
> **Related Documents**:
> - `design/art/art-bible.md` — color palette (Parchment Cream, Lantern Gold, Dusk Purple, Ember Glow), typography (two-font max: Identity font + Information font)
> - `design/accessibility-requirements.md` — Standard-tier commitments
> - `docs/architecture/ADR-0007-scene-transition-and-persist-coupling.md` — `reduce_motion` flag, modal push/pop
> - `docs/architecture/ADR-0008-ui-framework-dual-focus-parity-and-theme.md` — parchment theme, dual-focus (mouse + touch), 44-px tap target, colorblind-safe matchup icons, two-font-max
> - `design/ux/hud.md` — HUD v0.1

> **Why this document exists**: Every UI screen spec in Lantern Guild should
> say "uses Primary Button pattern" instead of re-specifying hover, tap pulse,
> focus ring, and accessibility hooks from scratch. This is the single source
> of truth for reusable interaction behaviors.
>
> This is a living document. As new screens are designed, add patterns here
> rather than re-inventing them. Patterns cited by more than one screen UX spec
> belong here.

---

## How to Use This Library

- **Designing a screen** — Browse the catalog below before inventing new
  interactions. Reference patterns by name in the screen spec.
- **Implementing a screen** — When a screen spec says "use [Pattern]," find the
  full specification here. Implementation notes contain Godot-specific guidance.
- **Reviewing a screen spec** — Verify every interactive element references a
  pattern from this library or includes its own full specification.

---

## Pattern Catalog Index

| Pattern Name | Category | Description | Used In | Status |
|-------------|----------|-------------|---------|--------|
| Primary Button | Input | Main call-to-action. One per screen zone. | HUD (Dispatch, Claim Offline), Recruit screen | Draft |
| Secondary Button | Input | Alternative / Back / Cancel. Lower visual weight. | All modals, detail views | Draft |
| Confirm-Dismiss Modal | Feedback / Layout | Blocking overlay with explicit player decision. | Mid-run reassign warning, save-failed retry, offline reward reveal | Draft |
| Toast Notification | Feedback | Non-blocking transient message. | Gold drip, hero-leveled, first-clear-awarded | Draft |
| Matchup Indicator | Game-Specific | Colorblind-safe advantage/neutral/disadvantage triple. | HUD, dispatch preview, formation editor | Draft |
| Currency Counter | Game-Specific | Persistent header element showing gold balance with tweened update. | HUD header | Draft |
| Lantern-Glow Backdrop | Decorative | Slow-loop ambient warmth backdrop for menu/intro screens. ≤2 fps cycle, ≤5% screen-area variance. | Main menu | Draft (added 2026-04-25) |
| Modal Dim Overlay | Layout | 40% opacity translucent layer behind any modal — preserves spatial continuity with underlying screen. | Pause menu, settings, confirm-dismiss modals | Draft (added 2026-04-25) |
| Compact Status Strip | Game-Specific | Read-only orientation footer reminding the player of current game state inside a modal context. | Pause menu | Draft (added 2026-04-25) |

> **When this file grows**: As new screens are designed, add patterns here
> rather than re-inventing them. A pattern belongs here if cited by two or
> more screen UX specs, or if it encodes a decision locked by an ADR.

---

## 1. Primary Button

**Category**: Input
**Status**: Draft
**When to Use**: The single most important action on a screen zone — "Recruit
Hero," "Dispatch Formation," "Claim Offline Rewards," "Confirm." At most one
Primary button per logical screen zone (the HUD's action zone may have one;
a modal may have a separate one).

**When NOT to Use**: Back, Cancel, or alternative actions (use Secondary);
destructive actions without confirmation (don't exist in Lantern Guild — all
destructive actions are confirm-dismiss-modal-wrapped).

**Visual Treatment**:

- Default: Parchment Cream fill, Dusk Purple 2px outline, Identity font label centered. Min size: 44 × 44 logical pixels (ADR-0008).
- Mouse hover: Ember Glow overlay at 30% opacity; subtle 1.02× scale; cursor → pointer.
- Touch press: 1.05× scale pulse over 80ms, then return (no hover state on touch).
- Focused (keyboard/screen reader via AccessKit): 2px Ember Glow focus ring, 3px offset.
- Pressed: 0.97× scale, Dusk Purple outline darkens to Purple-shadow.
- Disabled: 40% opacity, no cursor change, no tap response.

**Input Behavior**:

- Mouse: Fires on press-up (not press-down) to allow drag-off cancel.
- Touch: Fires on touch-up over the element; if the touch moves off before release, does not fire.
- Keyboard / AccessKit: Activated on Enter or Space when focused.
- Motion: If `reduce_motion` is set (ADR-0007), all scale animations are disabled; state changes are instant.

**Accessibility Notes**:

- Tap target: 44 × 44 logical px minimum (ADR-0008). `UIFramework.assert_tap_target_min` verifies at debug time.
- Contrast: Parchment Cream on Dusk Purple outline meets 4.5:1 (verify with parchment art bible palette).
- Screen reader: Exposes accessible name = visible label. Role = button. State = "dimmed" when disabled.
- Colorblind: Visual weight (fill + outline) distinguishes from Secondary — does not rely on color alone.

**Example Screens**: HUD "Dispatch" / "Recall" button; HUD "Claim Offline Rewards" modal button; Roster "Recruit Hero" button; Save-failed modal "Try Again" button.

**Implementation Notes (Godot 4.6)**:
- Extend `Button` control; override default theme with parchment theme from ADR-0008.
- `focus_mode = FOCUS_ALL` for AccessKit reachability.
- `mouse_default_cursor_shape = CURSOR_POINTING_HAND`.
- For scale pulse, tween a parent Control's `scale` (scaling the Button itself clips children).
- `mouse_filter = MOUSE_FILTER_STOP` (per ADR-0008 default).

---

## 2. Secondary Button

**Category**: Input
**Status**: Draft
**When to Use**: Alternative or cancel action — "Back," "Cancel," "View
Details," "Stay Here." Visually recedes against a Primary button to establish
the primary intent.

**When NOT to Use**: Main call-to-action on a screen (use Primary); destructive
action without confirmation (wrap in Confirm-Dismiss Modal).

**Visual Treatment**:

- Default: Parchment Cream fill, no outline, Information font label. Min size: 44 × 44 logical px.
- Mouse hover: Dusk Purple 10% tint overlay; no scale change.
- Touch press: 1.03× scale pulse over 80ms (softer than Primary).
- Focused: 2px Ember Glow focus ring, 3px offset (same as Primary).
- Pressed: 0.97× scale; brief Dusk Purple 20% tint.
- Disabled: 40% opacity.

**Input Behavior**: Same as Primary (press-up fire, reduce_motion disables scale).

**Accessibility Notes**:

- Tap target, contrast, screen reader: same requirements as Primary.
- When a Primary and Secondary appear together, Secondary sits to the right (horizontal layout) or below (vertical) — consistency across screens over per-screen preference.
- In Confirm-Dismiss Modals, the Secondary commonly maps to the platform Cancel input (Escape on PC).

**Example Screens**: All modal "Cancel" / "Back" buttons; formation editor "View Details"; settings screen "Back."

**Implementation Notes**: Same base class as Primary; theme variant `SecondaryButton` in the parchment theme resource. `focus_mode = FOCUS_ALL`.

---

## 3. Confirm-Dismiss Modal

**Category**: Feedback / Layout
**Status**: Draft
**When to Use**: Any decision with real weight — "Are you sure you want to
reassign formation mid-run?" (ADR-0001 `MID_RUN_REASSIGN_WARNING_ENABLED`),
"Save failed — try again or stay here?" (ADR-0007), "Offline rewards claimed —
reveal results" (ADR-0014 cozy-reveal at ≥100ms with reward-number
celebration).

**When NOT to Use**: Non-blocking feedback (use Toast); errors that recover
automatically (use Toast with error styling).

**Visual Treatment**:

- Background: screen-dim overlay at 50% Dusk Purple tint (blocks input to underlying UI).
- Modal panel: Parchment Cream fill with Dusk Purple 3px outline; rounded corners 8px. Width 480 logical px on PC, 90% viewport width on mobile.
- Header: Identity font, centered title.
- Body: Information font, centered body text, ≥20px.
- Action zone: Primary button on the right/bottom, Secondary on the left/top.
- Reward reveal variant (offline-return, first-clear): body area shows animated reward number tally (animated unless `reduce_motion` — then static final value).

**Input Behavior**:

- Uses `SceneManager.push_overlay` (ADR-0007) — pauses active gameplay inputs underneath.
- Dismisses only on explicit player action (Primary, Secondary, or Escape key maps to Secondary).
- Tap outside the modal panel → does nothing (prevents accidental dismissal of decision-weighted modals).
- Modal open animation: fade-in + scale 0.9→1.0 over 150ms. `reduce_motion` → instant appear.

**Accessibility Notes**:

- Focus lands on Primary button by default when modal opens (AccessKit). Focus trap within modal until dismissed.
- Screen reader announces modal title on open ("Dialog: Confirm reassign formation").
- Contrast: modal panel text meets WCAG AA 4.5:1 against Parchment Cream.
- Tap target: buttons follow the 44-px rule.
- Open question (see accessibility-requirements.md): confirm Godot 4.6 AccessKit fires update events for dynamically-shown modal overlays.

**Example Screens**:

- **Mid-run reassign warning** — Title "Reassign formation mid-run?" / Body "Your dispatched formation is active. Changes apply on next dispatch, not this run." / Primary "Reassign anyway" / Secondary "Keep current."
- **Save-failed** — Title "Could not save" / Body "Your progress will be lost if you quit now." / Primary "Try Again" / Secondary "Stay Here."
- **Offline reward reveal** — Title "Welcome back" / Body (animated reward tally of gold + clears + level-ups during offline window) / Primary "Claim."

**Implementation Notes (Godot 4.6)**:
- `SceneManager.push_overlay(modal_scene)` per ADR-0007.
- Modal root is a `CanvasLayer` to ensure it renders above HUD.
- Focus trap: on open, call `grab_focus()` on Primary; on Escape input, invoke Secondary's pressed signal.
- `mouse_filter = MOUSE_FILTER_STOP` on the background dim rect to swallow underlying clicks.

---

## 4. Toast Notification

**Category**: Feedback
**Status**: Draft
**When to Use**: Non-blocking positive feedback — "Gold +N" (gold drip),
"Hero leveled up," "First clear awarded," "Formation saved." Communicates
low-stakes state changes without interrupting play.

**When NOT to Use**: Decisions that require a player response (use
Confirm-Dismiss Modal); persistent state that must remain visible (use HUD).

**Visual Treatment**:

- Position: Bottom-right of the HUD by default; stacks vertically with oldest at top.
- Background: Parchment Cream at 90% opacity with Dusk Purple 1px outline, 6px rounded corners. Width 280 logical px; height fits content (≥44px).
- Text: Information font, left-aligned, icon optional on left.
- Appearance animation: slide in from right 200ms + fade in; fade out 300ms at end of display. `reduce_motion` → instant appear / instant disappear.
- Max 3 simultaneous toasts; oldest auto-dismisses if a 4th arrives.

**Input Behavior**:

- No blocking — game input continues.
- Tap/click on a toast → dismisses it immediately.
- Auto-dismisses after **5 seconds minimum** (Standard-tier reading-time floor per accessibility-requirements.md).

**Accessibility Notes**:

- Tap target: full toast area acts as dismiss zone; ≥44px tall.
- Screen reader: AccessKit announces toast text on appear (polite region, does not interrupt current reading).
- Contrast: 4.5:1 against Parchment Cream (same as HUD body text).
- Merge rule: toasts of the same type (e.g., multiple "Gold +N") that fire within 500ms merge into a single toast with summed value.
- In `_is_offline_replay` mode (ADR-0014), toasts are suppressed; offline results are revealed via the Confirm-Dismiss Modal reward reveal instead.

**Example Screens**: Active HUD (Gold +N during gold drip, Hero leveled up, First clear awarded).

**Implementation Notes (Godot 4.6)**:
- Toast container is a `VBoxContainer` in bottom-right of HUD CanvasLayer.
- Queue rules: if a toast's type matches the topmost existing toast within 500ms, merge by updating the existing toast's value; otherwise push a new toast.
- `mouse_filter = MOUSE_FILTER_PASS` on the container so non-toast areas of the screen remain clickable.

---

## 5. Matchup Indicator (Colorblind-Safe Triple)

**Category**: Game-Specific
**Status**: Draft (locked by ADR-0008)
**When to Use**: Any display of class-vs-biome matchup — HUD matchup readout,
dispatch preview, formation editor recommendation panel.

**When NOT to Use**: Non-matchup status (buff/debuff, alert) — use a distinct
icon set.

**Visual Treatment** (locked by ADR-0008):

- **Advantage**: Lantern Gold upward-pointing triangle.
- **Neutral**: Parchment Cream circle.
- **Disadvantage**: Dusk Purple downward-pointing triangle.
- Minimum icon size: 24 logical px at default UI scale.
- Icon always paired with a text label (e.g., "Advantage vs. Mossglen") at ≥20px.

**Input Behavior**: Display-only; the icon itself is non-interactive but may be the focus target of a containing Button (for a "View matchup detail" action).

**Accessibility Notes**:

- **Shape encodes meaning. Color is supplemental.** This is the project's
  canonical non-color-redundancy example, referenced by
  `design/accessibility-requirements.md`.
- Verified safe under Protanopia, Deuteranopia, and Tritanopia (shape is
  invariant).
- Tooltip on hover (mouse) / long-press (touch) reveals the full matchup
  explanation for cognitive-load support.
- Text label is always co-present — the triple is never icon-only.

**Example Screens**: HUD matchup readout ("vs. Mossglen: Advantage" with gold triangle); formation editor sidebar; dispatch confirm preview in modal.

**Implementation Notes (Godot 4.6)**:
- Store as three named textures in the parchment theme resource: `matchup_advantage.svg`, `matchup_neutral.svg`, `matchup_disadvantage.svg`.
- Never tint-recolor at runtime — the pinned color is part of the asset (consistency with art bible §4).
- TextureRect + Label in an HBoxContainer.

---

## 6. Currency Counter (Gold Balance)

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Persistent display of the player's gold balance. Lives in the
HUD header, always visible during active gameplay. May also appear in shop /
recruit screens where the balance is decision-relevant.

**When NOT to Use**: Transient gain feedback (use Toast "Gold +N" instead); the
counter shows the running balance, not the delta.

**Visual Treatment** (two-font-max rule per ADR-0008):

- Gold coin icon (Lantern Gold, 24px) on the left.
- Numeric value in **Information font** (monospaced glyph-width preferred for stability), ≥20px, Dusk Purple text.
- Label "Gold" in **Identity font** (≥18px) to the right of the number, slightly smaller visual weight.
- Layout: `[coin]  12,480  Gold`.
- On `gold_changed` signal: number tweens from old value to new over 400ms via ease-out. `reduce_motion` → instant snap to new value.
- On `_is_offline_replay = true` (ADR-0014): tween is suppressed; value updates silently (offline results reveal via Confirm-Dismiss Modal instead).

**Input Behavior**:

- Display-only in HUD.
- In shop / recruit screens, counter itself is non-interactive; adjacent "can afford" cost comparison may highlight via a secondary visual (not this pattern).

**Accessibility Notes**:

- Icon + text label satisfy the color-as-only-indicator audit (color = meaning is backed by the coin icon shape and the "Gold" text).
- Contrast: Dusk Purple number on Parchment Cream HUD background meets 4.5:1.
- Screen reader: AccessKit exposes the counter with a live-region update on change ("12,480 gold").
- Tap target: N/A (display-only). If made interactive (e.g., tap to open ledger), the full counter region becomes the tap target at ≥44 px.
- Tween animations are the only motion; `reduce_motion` disables them per ADR-0007.

**Example Screens**: HUD header (persistent); recruit screen (persistent during shop view).

**Implementation Notes (Godot 4.6)**:
- Listen for `gold_changed(new_value: int, delta: int)` signal from Economy autoload.
- Tween via `create_tween().tween_property(label, "text_as_number", new_value, 0.4)` with a custom setter that formats with thousands separators.
- If `_is_offline_replay`, skip the tween and set the label directly.
- Two-font-max rule enforced by using distinct theme fonts: `theme_font_information` for the number, `theme_font_identity` for the "Gold" label.

---

## 7. Lantern-Glow Backdrop

**Category**: Decorative
**Status**: Draft

**When to Use**: Ambient warmth zones in menu / intro / hub screens where the
Visual Identity Anchor's "warm miniature you want to pick up" feel must be
delivered passively. The backdrop is a slow-loop animation behind the
foreground UI, NOT a primary attention-grabber.

**When NOT to Use**: Behind any text-dense or input-precision screen
(roster grid, formation editor) — the loop variance, however subtle, can
distract from precise interaction. Also do not use during gameplay
(combat / dungeon run) where attention is on the playing surface.

**Visual Treatment**:

- A static base texture in the warm dusk-amber palette + a layered glow
  texture that breathes in opacity / position over a 4-second loop cycle.
- Loop cadence: ≤ 2 fps update rate (effective; underlying tween is smooth
  but visually it shouldn't feel "animated", it should feel "alive").
- Screen-area variance: ≤ 5% of total screen area changes opacity / position
  per loop. Anything more becomes distracting.
- Color temperature: stays in the amber-to-dusk-purple band per Art Bible
  Section 1. Brightest peak is lantern gold for ≤ 800 ms per cycle.
- Reduced-motion variant: replaces the loop with a single static composite
  matching the loop's median frame. Same warmth, no motion.

**Input Behavior**:

- Non-interactive. Does not consume mouse / touch / keyboard input.
- `mouse_filter = MOUSE_FILTER_IGNORE`.

**Accessibility Notes**:

- Reduced-motion (per ADR-0007) MUST disable the loop and use the static composite.
- No information is conveyed by the backdrop; it is purely atmospheric.
- Does not affect contrast on the foreground UI (verified: foreground text
  contrast ≥ 4.5:1 against the brightest pixel in the backdrop loop).

**Example Screens**: Main menu (the only MVP user; expect more in V1.0
title-screen / unlock-celebration moments).

**Implementation Notes (Godot 4.6)**:

- `TextureRect` for the base + `TextureRect` for the glow layer, with the
  glow layer's `modulate.a` and `position` tweened on a 4-second loop via
  `create_tween().set_loops(0)`.
- If `reduce_motion` is set, do NOT start the tween — set the glow layer's
  modulate / position to its median values and leave it static.
- Z-order: behind everything; first child of the menu's root Control.
- Performance: avoid shaders for MVP; pure tween + texture composite stays
  well under the per-frame budget. Revisit if HD-2D shader pass adopts a
  unified post-processing path that can absorb this.

---

## 8. Modal Dim Overlay

**Category**: Layout
**Status**: Draft

**When to Use**: Behind any modal element that should preserve spatial
continuity with the underlying screen — pause menu, settings, confirm-dismiss
modals, save-corrupted error modal. The dim overlay tells the player "the
game is still here, you're just on top of it."

**When NOT to Use**: Loading screens (where the underlying screen is not
the destination — use a full-opacity loading screen instead). Also do not
use behind toast notifications (toasts are non-blocking by definition).

**Visual Treatment**:

- Full-screen `ColorRect` (or theme-driven equivalent) covering the entire
  viewport.
- Color: dusk-purple (Art Bible Section 1 base) at 40% opacity. NOT pure
  black — pure black breaks the warm-palette rule and signals "menu" rather
  than "modal pause."
- Animation: opacity 0% → 40% over 200 ms when the modal enters; reverses
  on exit. Synchronized with the modal's own enter/exit transition.
- Reduced-motion variant: instant snap to 40% (no fade).

**Input Behavior**:

- Mouse: click anywhere on the dim overlay dismisses the modal (treats
  click-outside as "back"). The modal's own buttons take priority over the
  dim overlay's click handler.
- Touch: tap-anywhere dismissal mirrors mouse behavior — this is the
  touch-friendly equivalent of pressing Esc.
- Keyboard: dim overlay does not receive focus; Esc / Tab navigation are
  owned by the modal itself.

**Accessibility Notes**:

- The dim overlay MUST NOT trap focus — focus management is the modal's
  responsibility (see Confirm-Dismiss Modal pattern). The dim is purely
  visual.
- The dim overlay MUST be announced as a region change to screen readers
  via `AccessKit` "modal opened" event — this signals to assistive tech
  that the underlying screen is no longer interactive.
- Click-outside-to-dismiss is a discoverability concern for keyboard-first
  users. Pair with the Confirm-Dismiss Modal pattern's "tap anywhere
  outside to resume" hint text on first invocations.

**Example Screens**: Pause menu (primary MVP user); settings overlay; any
confirm-dismiss modal.

**Implementation Notes (Godot 4.6)**:

- `ColorRect` filling the viewport with `color.a = 0.4` and `color.rgb` set
  from the dusk-purple theme constant.
- `gui_input` signal handler on the ColorRect treats `InputEventMouseButton`
  press (left button) and `InputEventScreenTouch` press as dismiss triggers.
- `mouse_filter = MOUSE_FILTER_STOP` — but the modal itself sits on top in
  Z-order, so its own buttons receive input first.
- The fade tween: `create_tween().tween_property(rect, "color:a", 0.4, 0.2)`.
- Pair always with Confirm-Dismiss Modal pattern (#3) for the modal element
  itself — this pattern is the BACKDROP, not the modal.

---

## 9. Compact Status Strip

**Category**: Game-Specific
**Status**: Draft

**When to Use**: Read-only orientation footer inside a modal or overlay
context — pause menu, save-corrupted recovery modal, return-from-distraction
prompts. Reminds the player of current game state without re-implementing
the full HUD.

**When NOT to Use**: Inside the active HUD (the HUD itself is the canonical
state display; this pattern is for modal-only contexts where the HUD is
hidden or de-emphasized). Also do not use as a primary information surface —
this is a *reminder*, not a *display*.

**Visual Treatment**:

- Single horizontal strip; ~28 px logical height; centered alignment within
  its parent.
- Typography: `theme_font_information` (smaller / dimmer than the modal's
  primary text); 70% opacity vs the modal's primary text.
- Format: short labels separated by an em-dash or middle-dot. Examples:
  - `Floor 3: Wolf Hollow — 2,400 gold`
  - `Forest Reach — Floor 2 — 312 gold (offline)`
- Numeric values: locale-aware thousands separators per Localization
  Considerations across all UX specs.
- No interactive affordances — purely informational.

**Input Behavior**:

- Non-interactive. Does not consume input.
- `mouse_filter = MOUSE_FILTER_IGNORE`.
- `focus_mode = FOCUS_NONE` — Tab navigation skips it.

**Accessibility Notes**:

- Screen reader exposes the strip's text as a single sentence; punctuation
  is preserved so the reader pauses naturally between fields.
- No information here is unique to the strip — every value is also
  available in the underlying screen's HUD or via the Currency Counter
  pattern. The strip is redundancy in service of orientation, not novel
  information delivery.
- Reduced-motion: not applicable (no animation).

**Example Screens**: Pause menu (primary MVP user); save-corrupted recovery
modal (Sprint 4-5+); return-to-app screen orientation footer (V1.0+).

**Implementation Notes (Godot 4.6)**:

- `Label` (or `RichTextLabel` if rich formatting is needed for the em-dash).
- Pull values via:
  - `BiomeDungeonDatabase.get_biome_by_id(current_biome_id).display_name`
  - `Floor.floor_index` from current Orchestrator state
  - `Economy.get_gold_balance()` formatted via locale-aware integer formatter
- Refresh cadence: re-render on parent modal's enter; do not subscribe to
  `gold_changed` mid-modal (per modal-context pause: gold values are stable
  during a modal session because TickSystem emission is suppressed; see
  Pause Menu UX spec).

---

## Status Definitions

- **Draft**: Pattern is specified but not yet validated in a shipped screen.
- **Stable**: Pattern has been implemented and validated in at least one screen.
- **Deprecated**: Being phased out; do not use in new screens.

All nine patterns above are **Draft** as of 2026-04-25 (six original from
Sprint 1; three added in Sprint 4 pre-flight: `Lantern-Glow Backdrop`,
`Modal Dim Overlay`, `Compact Status Strip`). They will be promoted to
**Stable** after they are implemented in the HUD v1.0 milestone and survive
QA sign-off.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Godot 4.6 AccessKit — does it fire update events for dynamically-shown modal overlays? (Affects Confirm-Dismiss Modal screen-reader accessibility.) | ux-designer | Before first HUD implementation story | Unresolved |
| Is the 400ms currency counter tween too slow on rapid gold drip from offline results? Alternative: tween duration scales with delta size, capped at 400ms. | ux-designer + game-designer | Before HUD v1.0 | Unresolved |
| Do we need a distinct "Destructive" button pattern (e.g., for a future "Dismiss hero from roster" flow)? If yes, wrap in Confirm-Dismiss Modal; if no, the modal + Secondary button combination is sufficient. | ux-designer | When the first destructive flow is specced | Unresolved |

---

*End of document.*
