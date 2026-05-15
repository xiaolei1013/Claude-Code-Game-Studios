# Interaction Pattern Library: Lantern Guild

> **Status**: Draft (v0.2 — expanded with 11 new patterns from Sprint 20 UI/HUD design pass)
> **Author**: ux-designer + user
> **Last Updated**: 2026-05-15 (Sprint 20 S20-M4)
> **Version**: 0.2
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
| Guild-Ledger-Entry | Layout | Parchment sub-panel register: single ledger row with thin Slate Ink border, used inside a larger parchment panel. | Guild Hall HeroCards | Draft (added 2026-05-15) |
| Conditional Strip | Layout | Strip that occupies 0px when inactive and expands to a fixed height when activated, with no layout gap when hidden. | Guild Hall synergy strip; Recruit Screen empty-state | Draft (added 2026-05-15) |
| Slot Button | Input | Large square button (~120×120) used as a content container — not just a label-on-color. Carries a hero portrait + name + level OR a placeholder "Empty Slot". | Formation Assignment slot buttons | Draft (added 2026-05-15) |
| Two-Tap Assignment Flow | Input | Tap-target-then-tap-source assignment pattern: tap a destination slot, then tap a source item, source moves to slot. Replaces drag-and-drop for touch parity. | Formation Assignment formation editing | Draft (added 2026-05-15) |
| Affordability Gating | Input / Feedback | Cost shown + action gated by resource + deficit tooltip on disabled-tap. The "show what they'd need to save up" cozy pattern. | Guild Hall Recruit gate; Recruit Screen rows; Hero Detail Level Up button | Draft (added 2026-05-15) |
| Pool Entry Card | Layout | Ledger-row variant with portrait (~96px) + multi-line details (name/cost/owned) + action button (right-aligned). | Recruit Screen pool entries; future inventory / equip screens | Draft (added 2026-05-15) |
| Hot-Path Display | Feedback | Read-only screen pattern where high-frequency state changes drive label updates without animation. Respects zero-allocation budget. | Dungeon Run View tick + kill display | Draft (added 2026-05-15) |
| Reward Summary Panel | Feedback / Layout | Large headline number + supporting stats + level-up list + single CTA. The cozy welcome-back / payoff register. | Return-to-App; Victory Moment | Draft (added 2026-05-15) |
| Tap-Anywhere Continue | Input | Full-screen receive-mode pattern where the entire surface is the affordance + a hint label tells the player. | Victory Moment; future splash / lore moments | Draft (added 2026-05-15) |
| Inspection Modal with Single Action | Layout / Input | Modal overlay with read-only inspection fields + one primary action (gated by resource) + tap-outside-dismiss. | Hero Detail Modal; future item / building detail | Draft (added 2026-05-15) |
| Browseable Locked Frontier | Layout / Feedback | List pattern showing both unlocked AND locked items with explicit text explaining the unlock gate. The "world is bigger than you've seen" cozy-frontier pattern. | Matchup Assignment biome browser; future content unlock screens | Draft (added 2026-05-15) |

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

## 10. Guild-Ledger-Entry

**Category**: Layout
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: A row inside a larger parchment panel that represents a single record — a hero in the roster, a recruit in the pool, an item in a ledger. The visual register is "this is one line in a guild ledger book."

**When NOT to Use**: For standalone cards floating in negative space — use a full `panel-default` variant instead. The ledger-entry pattern requires a containing parchment panel above it (the ledger page).

**Visual Treatment**:
- PanelContainer with `radius-chip` (2px) corners — more rigid than full panels
- 1px Slate Ink border at 50% alpha (subtle separator, not a full panel border)
- Parchment Cream fill (same as containing panel; the row reads as a "line on the page" rather than a separate card)
- Inner padding: `sm` (8px) — compact ledger feel
- Content layout: HBoxContainer with leading icon/portrait → flex middle content → trailing action/stat

**Input Behavior**:
- Default: non-interactive (display only). When tappable (e.g., HeroCard in V1.0+), follows Primary Button mouse/touch behavior with the row as the tap target.
- `mouse_filter = PASS` when non-interactive; `STOP` when tappable.

**Accessibility Notes**:
- Tap target: row height ≥56px (8px padding + 24px content + 8px padding + 16px breathing) — meets 44×44 minimum
- Contrast: Slate Ink 50% alpha border still readable on Parchment Cream
- Screen reader: when tappable, exposes accessible name = primary content text

**Example Screens**: Guild Hall HeroCards (`design/ux/guild-hall.md` §Layout Specification).

**Implementation Notes (Godot 4.6)**:
- Sub-resource: StyleBoxFlat with `bg_color = Color(0.929, 0.878, 0.769, 1)` (Parchment Cream), `border_color = Color(0.173, 0.157, 0.220, 0.5)` (Slate Ink 50%), `corner_radius_* = 2`, `content_margin_* = 8`
- Register as Theme variation `LedgerRow` so subpanels reference by `theme_type_variation = "LedgerRow"`

---

## 11. Conditional Strip

**Category**: Layout
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: A horizontal strip that needs to appear/disappear inline with the layout WITHOUT leaving a gap when hidden. Example: synergy badge that only shows when a formation has a synergy active.

**When NOT to Use**: Floating notifications or transient overlays — use Toast Notification (pattern #4) instead. Conditional Strip is for inline layout-affecting content.

**Visual Treatment**:
- Hidden state: `custom_minimum_size.y = 0`; visible = false; no layout space consumed
- Active state: `custom_minimum_size.y = 48` (or pattern-defined); visible = true; content renders centered
- Background: optional — typically transparent to inherit parent panel's parchment cream
- Border: top + bottom hairline 1px Slate Ink at 30% alpha to separate from surrounding content

**Input Behavior**:
- Default non-interactive (display only)
- Show/hide transition: 150ms fade-in + 150ms slide-from-below combined; reduce-motion: instant
- State change source: signal-driven (e.g., `formation_synergy_changed` from FormationAssignment)

**Accessibility Notes**:
- Reduce-motion: instant appear/disappear at full alpha; no slide animation
- Screen reader: when visible, announces content; when hidden, removed from accessibility tree (`AccessibilityIgnore`)
- No tap interaction — informational only

**Example Screens**: Guild Hall synergy strip (`design/ux/guild-hall.md`); Recruit Screen empty-state strip (`design/ux/recruit-screen.md`).

**Implementation Notes (Godot 4.6)**:
- Use `Control.visible` + `custom_minimum_size` toggle on a Container (not a fixed-size Panel)
- For animation: Tween `modulate.a` + `position.y` simultaneously; pair with `Tween.kill()` on screen exit per per-screen tween cleanup convention
- Reduce-motion branch: check `SceneManager.reduce_motion` before animating

---

## 12. Slot Button

**Category**: Input
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: A large square button (~120×120) that acts as a CONTENT CONTAINER, not just a label-on-color. Used when the button represents a destination/slot that may be empty OR filled with content (icon + name + level for filled; "Empty Slot" placeholder for empty).

**When NOT to Use**: For text-label actions (Dispatch, Recruit, Cancel) — use Primary Button (pattern #1) or Secondary Button (pattern #2). Slot Button is for visualizing assigned content, not for plain action affordances.

**Visual Treatment**:
- Square dimensions: ~120×120 logical pixels (3 slots fit comfortably in a Steam Deck portrait NavBar)
- Border: 2px Slate Ink (default); 4px Guild Amber when selected (the selected-slot pattern)
- Corner radius: `radius-panel` (6px) — softer than Primary Button's `radius-button` (4px), reads as "panel-like content holder"
- Fill: Parchment Cream by default; tinted Guild Amber at 20% opacity when selected
- Content (when filled): VBox with icon (40×40) + name label (Lora SemiBold 14px) + level label (Lora SemiBold 12px Lantern Gold)
- Content (when empty): centered "Empty Slot" placeholder text in Lora Italic 14px Slate Ink at 60% alpha

**Input Behavior**:
- Tap: per Primary Button mouse/touch behavior; tap toggles "selected" state if not currently selected, OR clears the slot if already selected (the two-tap clear pattern)
- Selected state: border color shifts to Guild Amber + border weight 2→4px over 80ms; reduce-motion: instant

**Accessibility Notes**:
- Tap target: 120×120 well above 44×44 minimum
- Selected vs default state communicated by border WEIGHT change (2→4px), not just color — colorblind backup cue per Art Bible §4
- Screen reader: announces filled state ("Slot 1, Theron, Warrior, Level 7") or empty ("Slot 1, empty")

**Example Screens**: Formation Assignment slot buttons (`design/ux/formation-assignment.md` §Layout Specification).

**Implementation Notes (Godot 4.6)**:
- Extend Button; use a custom theme variation `SlotButton` with the larger size + 6px radius
- For dynamic content, use a child VBoxContainer that can be populated/cleared based on slot state
- Selected state: tween `theme_override_styles/normal:border_width_*` from 2→4 over 80ms

---

## 13. Two-Tap Assignment Flow

**Category**: Input
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: Assignment interactions where the player needs to choose a destination + a source. Touch-parity-compliant alternative to drag-and-drop.

**When NOT to Use**: Single-action commits (recruit, level-up) — those are one tap. Two-Tap requires that source AND destination are both visible simultaneously.

**Visual Treatment**:
- Step 1: Player taps a destination (e.g., a Slot Button). Destination's selected state activates (border weight increase + color shift per Slot Button pattern).
- Step 2: Player taps a source (e.g., a Guild-Ledger-Entry row). Source highlights briefly (50ms color flash).
- Commit: source content moves to destination; destination deselects; brief Toast Notification "Hero added to slot N"

**Input Behavior**:
- Step 1 tap: destination becomes selected (state held)
- Step 2 tap: source content commits to destination; selected state clears
- If player taps a different destination before tapping a source: new destination becomes selected; previous destination deselects (no commit)
- If player taps an already-selected destination twice: destination clears (the "clear slot" path)
- Toast on commit per Toast Notification pattern (#4)

**Accessibility Notes**:
- Two-tap parity with single-tap commit screens — slight cognitive overhead but accessibility-friendly (no drag precision, no hover requirement)
- Selected state announced via screen reader on step 1
- Step 2 tap announces the commit result

**Example Screens**: Formation Assignment formation editing (`design/ux/formation-assignment.md` §Interaction Map).

**Implementation Notes (Godot 4.6)**:
- State machine: `IDLE → SLOT_SELECTED → COMMIT` with the source tap triggering COMMIT
- Use a `_selected_slot_index: int` on the screen script (-1 = none); update on slot taps + reset on commit/cancel
- Source rows check `_selected_slot_index >= 0` on tap; route accordingly

---

## 14. Affordability Gating

**Category**: Input / Feedback
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: Any action gated by a resource (gold, time, prerequisite item). The action's cost is always visible; the action is enabled if the player can afford it; tapping the disabled version shows a deficit tooltip ("Need N more gold"). The "show what they'd need to save up" cozy pattern.

**When NOT to Use**: Hidden costs (no — every cost in Lantern Guild is visible per cozy register). Action-not-available-due-to-state (use Browseable Locked Frontier instead — that's progression gating, not resource gating).

**Visual Treatment**:
- Affordable: Primary Button (pattern #1) with cost embedded in label — "Recruit — 150 gold" or "Level Up — 450 gold"
- Unaffordable: same Primary Button but at 40% opacity + `disabled = true`. Cost still visible in label.
- Tooltip (PC hover / touch long-press): "Need N more gold" with locale-formatted deficit

**Input Behavior**:
- Affordable: standard Primary Button tap fires the action
- Unaffordable: tap produces no feedback (button is `disabled`). Hover (PC) or long-press (touch) shows the tooltip with deficit.
- Re-evaluation: signal-driven (e.g., `Economy.gold_changed` re-evaluates affordability on every gold change within one frame)

**Accessibility Notes**:
- Disabled state communicated by THREE signals: opacity (40%) + `disabled` property + tooltip text — not color alone
- Screen reader: announces "Recruit Warrior, 150 gold, dimmed, need 50 more gold" — full context
- Tooltip locale-aware (deficit formatted per locale number rules)

**Example Screens**: Guild Hall Recruit nav button (gated on cheapest pool entry cost — `design/ux/guild-hall.md`); Recruit Screen rows (per-entry gating — `design/ux/recruit-screen.md`); Hero Detail Modal Level Up button (`design/ux/hero-detail-modal.md`).

**Implementation Notes (Godot 4.6)**:
- Wrap Primary Button in a refresh function: `_refresh_affordability(cost: int)` reads gold balance, sets `disabled` + `modulate.a`, updates tooltip text
- Subscribe to `Economy.gold_changed` in `on_enter`; call `_refresh_affordability` in the handler
- Tooltip text: `tr("affordability_deficit_format", [cost - gold_balance])` — locale-aware deficit number

---

## 15. Pool Entry Card

**Category**: Layout
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: List of purchasable / selectable items, each shown with a portrait + multi-line details + action button. Recruit Screen pool entries are the canonical use; reusable for future inventory, shop, or equip screens.

**When NOT to Use**: For non-actionable list items — use Guild-Ledger-Entry (pattern #10) instead. Pool Entry Card is specifically when each row has a primary action button.

**Visual Treatment**:
- Container: Guild-Ledger-Entry (pattern #10) styling
- Layout: HBoxContainer with leading portrait (96×96) + middle VBoxContainer (3 lines: name/cost/owned) + trailing action button (right-aligned)
- Inner padding: `md` (16px) — more breathing room than basic ledger row because each card carries more visual weight
- Portrait: parchment-cream square with class first-letter inset per OQ-RS-01 placeholder strategy (until real art lands)
- Action button: Affordability Gating (pattern #14) variant — cost in label, opacity-gated when unaffordable

**Input Behavior**:
- Portrait + name/cost/owned labels: display only (`mouse_filter = PASS`)
- Action button: Affordability Gating behavior

**Accessibility Notes**:
- Tap target on action button ≥44×44
- Multi-line details announce sequentially via screen reader
- Cost visibility per cozy register: even on unaffordable cards, cost is readable

**Example Screens**: Recruit Screen pool entries (`design/ux/recruit-screen.md` §Layout Specification).

**Implementation Notes (Godot 4.6)**:
- Reusable PackedScene: `pool_entry_card.tscn` with exported properties (portrait_texture, name_text, cost_text, owned_text, action_callback) — instantiate N times per pool size
- Action callback signature: `func(card: Control, action: String)` so the parent screen handles the commit

---

## 16. Hot-Path Display

**Category**: Feedback
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: A read-only screen pattern where high-frequency state changes (20 Hz+) drive label updates without animation. The labels themselves provide the visual feedback — the rapid number-ticking IS the feel.

**When NOT to Use**: Anywhere with allocation budget — this pattern explicitly forbids `tr()`, `String.format`, or any per-call allocation in the update handler. Use for value displays only; never for layout changes.

**Visual Treatment**:
- Plain Label control; no animation; no tween
- Pre-cached static prefix labels ("Tick:", "Kills:") set once at screen enter via `tr()` — never re-formatted in the hot path
- Value labels updated via `label.text = str(int)` — single allocation-free string conversion

**Input Behavior**:
- Non-interactive (display only)
- `mouse_filter = PASS`

**Accessibility Notes**:
- Screen reader: announces value changes when significant (e.g., on each new kill count milestone, not every tick) — handled at AccessKit layer
- Reduce-motion: no impact (this pattern is already animation-free)
- Tap target: n/a

**Example Screens**: Dungeon Run View tick + kill display (`design/ux/dungeon-run-view.md` §Layout Specification).

**Implementation Notes (Godot 4.6)**:
- Subscribe to source signal (e.g., `TickSystem.tick_fired`) in `on_enter`; unsubscribe in `on_exit`
- Handler MUST be allocation-free: `_tick_label.text = str(snap.current_tick)` — only one assignment per label
- NEVER call `tr()` or `String.format()` inside the handler — both allocate
- NEVER use `"%d" % int` — allocates a format-temp string
- Performance gate per `.claude/rules/engine-code.md`: <0.5ms per call on dev hardware; profile and lock

---

## 17. Reward Summary Panel

**Category**: Feedback / Layout
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: Post-action or post-session summary screens with a large headline number + supporting stats + optional list (e.g., level-ups) + single CTA. The cozy welcome-back / payoff register.

**When NOT to Use**: Active gameplay HUD (use Hot-Path Display) or detail inspection (use Inspection Modal with Single Action). Reward Summary Panel is specifically for closure beats.

**Visual Treatment**:
- Panel container: `panel-default` variant with generous padding (`xl` = 32px)
- Headline: oversized `stat-value` (32px Lantern Gold for gold figures) — the primary number renders within 100ms per Art Bible §7 reward-moment exception
- Supporting stats: `body-emphasis` (Lora SemiBold 18px) below the headline; icons or symbols accompany each stat
- Level-up list (conditional): VBoxContainer with one row per leveled hero; section header "Heroes leveled up:" + `body` rows
- CTA: single `primary` Button at panel bottom, full-width — typically "Continue"

**Input Behavior**:
- Most content is display-only
- Single CTA tap routes back to the hub screen
- Optional: tap-anywhere-to-continue overlay variant (see pattern #18 Tap-Anywhere Continue)

**Accessibility Notes**:
- Reward-moment exception: headline number always visible at final value within 100ms (per Art Bible §7); count-up animation is enhancement, not required
- Reduce-motion: instant headline rendering; level-up rows appear all at once (no stagger)
- Screen reader: announces in reading order — headline first, then supporting stats, then level-ups, then CTA

**Example Screens**: Return-to-App welcome-back summary (`design/ux/return-to-app.md`); Victory Moment post-run celebration (`design/ux/victory-moment.md`).

**Implementation Notes (Godot 4.6)**:
- Headline count-up: optional `Tween` on `Label.text` via `String` conversion at each step (allocates per frame — acceptable for the 400-800ms ceremony budget, NOT for hot-path)
- Render-on-screen-enter: set all values at final state immediately; THEN start the count-up animation. Player can see the final value within 100ms regardless of animation completion.
- Reduce-motion branch: skip the tween entirely; set values once

---

## 18. Tap-Anywhere Continue

**Category**: Input
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: Full-screen receive-mode pattern where the entire surface is the affordance. No specific button; player taps anywhere to advance. Reserved for ceremony beats, lore moments, splash screens.

**When NOT to Use**: Screens with multiple competing actions, or any screen where the player needs to make a choice between options. Tap-Anywhere is a single-decision pattern: "I'm done looking; continue."

**Visual Treatment**:
- No explicit button visible
- A subtle hint label near the bottom: "Tap anywhere to continue" in `secondary` (Lora 14px Slate Ink 60% alpha)
- The hint pulses subtly (3s cycle alpha 60% → 80% → 60%) after a delay (~700ms after ceremony reveal completes)
- Reduce-motion: hint is static at 60% alpha; no pulse

**Input Behavior**:
- Tap anywhere on the screen root → routes to the destination (typically Guild Hall via CROSS_FADE)
- Auto-advance timer (typically 4000ms after content reveal completes) routes automatically if no tap occurs
- Tap or auto-advance commits idempotently (multiple rapid taps + auto-advance produce one route)

**Accessibility Notes**:
- Massive tap target (full screen) — easiest possible for motor accessibility
- Hint label readable by screen reader
- Auto-advance timing is generous (4000ms) — accommodates reading speed; reduce-motion does NOT shorten this (it's a time-based hold, not motion)
- No focus management needed (no specific button)

**Example Screens**: Victory Moment celebration (`design/ux/victory-moment.md`).

**Implementation Notes (Godot 4.6)**:
- Root Control with `mouse_filter = STOP` to catch all taps
- Connect `gui_input` signal on the root; filter to InputEventMouseButton.pressed or InputEventScreenTouch.pressed
- Auto-advance: `await get_tree().create_timer(VICTORY_AUTO_ADVANCE_MS / 1000.0).timeout` — cancelable via `_routed` flag
- Idempotency: `if _routed: return; _routed = true` before calling `request_screen`

---

## 19. Inspection Modal with Single Action

**Category**: Layout / Input
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: Modal overlay showing read-only details about a single subject (a hero, an item, a building) + one primary action (gated by a resource). Tap-outside-dismiss + close button + Escape (PC) all dismiss.

**When NOT to Use**: Full-screen detail views (use a screen, not a modal). Multi-action surfaces (the pattern is specifically ONE action; more actions risk modal scope creep).

**Visual Treatment**:
- Backdrop: Modal Dim Overlay (pattern #8) at 70% Slate Ink
- Panel: `panel-modal` variant — 480×640 logical centered (responsive to viewport)
- Layout: VBoxContainer with: close button row (top-right) → portrait/identity area (top ~40%) → details (middle ~30%) → action button area (bottom ~20%)
- Primary action: Affordability Gating (pattern #14)

**Input Behavior**:
- Tap inside ModalPanel (but not on a button) → no-op (consumed)
- Tap on ModalDimBackdrop (outside ModalPanel) → dismiss
- Tap CloseButton (top-right "×") → dismiss
- Press Escape (PC) → dismiss
- Tap action button (when enabled) → commits action; modal updates in place (does NOT dismiss); player can keep taking the action repeatedly

**Accessibility Notes**:
- Multiple dismissal paths (close button + outside-tap + Escape) — accommodates different user preferences
- Tap target on close button ≥44×44
- Action button gating per Affordability Gating pattern
- Modal pauses underlying screen via ADR-0007 push_overlay

**Example Screens**: Hero Detail Modal (`design/ux/hero-detail-modal.md`).

**Implementation Notes (Godot 4.6)**:
- Use `SceneManager.show_modal(modal_scene)` per ADR-0007 push_overlay path
- ModalPanel intercepts taps inside via `mouse_filter = STOP`; ModalDimBackdrop intercepts taps outside (consumes them and dismisses)
- Escape handling: `_unhandled_input` on the modal root catches `ui_cancel` action
- Action button: standard Primary Button with Affordability Gating refresh on relevant signals (e.g., `Economy.gold_changed`)

---

## 20. Browseable Locked Frontier

**Category**: Layout / Feedback
**Status**: Draft (added 2026-05-15, Sprint 20 S20-M4)

**When to Use**: List pattern showing both unlocked AND locked items with explicit text explaining the unlock gate. The "world is bigger than you've seen" cozy-frontier pattern. Distinct from Affordability Gating (which is about resource cost) — this is about progression gating.

**When NOT to Use**: When you want locked content hidden as a surprise reveal. Lantern Guild's cozy register favors transparency over surprise — locked content visible with explanation builds anticipation, not anxiety.

**Visual Treatment**:
- List of items (rows or cards), each either unlocked or locked
- Unlocked: full opacity; action affordances visible (Select button, etc.)
- Locked: full row visible (NOT dimmed-to-nothingness); item name + a Dusk Purple italic label explaining the gate ("Locked — clear Floor 3 first")
- No SelectButton or action affordance on locked rows — the affordance is structurally absent so the player knows there's no action to discover

**Input Behavior**:
- Unlocked row: standard action (per row type — Slot Button, Pool Entry Card, etc.)
- Locked row: no interaction; tap produces no feedback. The unlock-requirement text IS the affordance gap.

**Accessibility Notes**:
- Locked vs unlocked communicated by TEXT (the requirement label), not just color — colorblind-safe
- Screen reader announces "Floor 4, locked, clear Floor 3 first" — full context without requiring visual scan
- No interactive trap (locked rows don't appear focusable)

**Example Screens**: Matchup Assignment biome browser (`design/ux/matchup-assignment.md`).

**Implementation Notes (Godot 4.6)**:
- Each row reads its unlock state from the gating system (e.g., `FloorUnlock.is_floor_unlocked(biome_id, floor_index)`)
- Subscribe to unlock signal (e.g., `FloorUnlock.floor_unlocked`) in `on_enter`; re-render affected rows on signal
- Lock-state UI: hide SelectButton + show FloorLockBadge Label with italic Dusk Purple `secondary` style
- Cross-fade transition on unlock: 400ms unlock animation (Dusk Purple tint fades to Parchment Cream) when the signal fires while screen is open

---

## Status Definitions

- **Draft**: Pattern is specified but not yet validated in a shipped screen.
- **Stable**: Pattern has been implemented and validated in at least one screen.
- **Deprecated**: Being phased out; do not use in new screens.

All 20 patterns above are **Draft** as of 2026-05-15:
- Patterns 1-6 (original from Sprint 1): Primary Button, Secondary Button, Confirm-Dismiss Modal, Toast Notification, Matchup Indicator, Currency Counter
- Patterns 7-9 (Sprint 4 pre-flight, added 2026-04-25): Lantern-Glow Backdrop, Modal Dim Overlay, Compact Status Strip
- Patterns 10-20 (Sprint 20 S20-M4 UI/HUD design pass, added 2026-05-15): Guild-Ledger-Entry, Conditional Strip, Slot Button, Two-Tap Assignment Flow, Affordability Gating, Pool Entry Card, Hot-Path Display, Reward Summary Panel, Tap-Anywhere Continue, Inspection Modal with Single Action, Browseable Locked Frontier

Patterns will be promoted to **Stable** after they are implemented in shipping screens and survive QA sign-off.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Godot 4.6 AccessKit — does it fire update events for dynamically-shown modal overlays? (Affects Confirm-Dismiss Modal screen-reader accessibility.) | ux-designer | Before first HUD implementation story | Unresolved |
| Is the 400ms currency counter tween too slow on rapid gold drip from offline results? Alternative: tween duration scales with delta size, capped at 400ms. | ux-designer + game-designer | Before HUD v1.0 | Unresolved |
| Do we need a distinct "Destructive" button pattern (e.g., for a future "Dismiss hero from roster" flow)? If yes, wrap in Confirm-Dismiss Modal; if no, the modal + Secondary button combination is sufficient. | ux-designer | When the first destructive flow is specced | Unresolved |

---

*End of document.*
