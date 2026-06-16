# Design System — Lantern Guild

> **Status**: Locked 2026-05-14 (Sprint 20, S20-pre-plan via `/design-consultation`)
> **Authoritative source for**: typography, color, spacing, component vocabulary, motion
> **Pairs with**: `design/art/art-bible.md` (visual direction), `design/ux/*.md` (per-screen specs), `design/ux/interaction-patterns.md` (pattern library)
> **Engine target**: Godot 4.6 — values map to Godot `Theme` / `StyleBox` / `FontFile` / `Color` resources, not CSS variables

> **The memorable thing**: *"Every scene must feel like a warm miniature you want to pick up."* (per Art Bible §1 Visual Identity Anchor). Every decision below serves this.

---

## Product Context

- **What this is**: Lantern Guild — a cozy fantasy idle-clicker for PC (Steam) + Steam Deck primary; iOS/Android post-launch
- **Who it's for**: players who want a warm, contemplative idle game that respects their time; the cozy-tier audience, not the FOMO-driven gacha audience
- **Genre register**: cozy fantasy management — not action, not roguelike-tense, not gacha-loud
- **Project type**: Godot 4.6 game (canvas_item UI, mouse+touch input, no gamepad)
- **Visual reference**: Octopath Traveler's diorama register (DoF + warm-lantern) + Pentiment's ink-and-parchment register (typography + UI framing)

---

## Aesthetic Direction

| Dimension | Decision |
|-----------|----------|
| Named direction | **Lantern-Lit Pixel Diorama** (Art Bible §1) |
| Decoration level | **Intentional** — subtle parchment texture + ink ornament; never flat color, never expressive maximalism |
| Mood | Warm, contemplative, literate. A guild ledger placed on a tavern table by lantern-light. |
| Anti-references | Generic mobile gacha (loud, FOMO-coded), stark indie minimalism (cold, no warmth), AAA-fantasy register (too serious, too saturated), purple-gradient SaaS slop |
| Diegetic framing | Semi-diegetic — UI is "documentation the guildmaster would produce." Panels are physical documents placed in the world, not floating windows. |

---

## Typography

### Font choices

> **Reverted 2026-06-03 (playtest legibility fix).** The Sprint 20 Lora + IM Fell
> English serif treatment read as "not clear" in playtest. The game now uses
> Godot's built-in default font everywhere.

| Role | Font | Why |
|------|------|-----|
| **All text (body, display, numbers)** | **Godot built-in default** (sans-serif) | Maximum legibility at every size. The theme specifies font *sizes* only and lets every Control fall back to the engine default face. |

**No custom font.** The theme (`assets/ui/parchment_theme.tres`) sets sizes and
colors but no font face. ADR-0008's two-font-max still holds (zero custom fonts ≤ two).

### Asset path

The Lora and IM Fell English TTFs remain on disk (now **unreferenced** by the theme)
in case a future polish pass wants a custom face:

- `res://assets/fonts/Lora/Lora.ttf`, `Lora-Italic.ttf`
- `res://assets/fonts/IM_Fell_English/IMFellEnglish-Regular.ttf`, `IMFellEnglish-Italic.ttf`

Both ship under SIL Open Font License (LICENSE files alongside each family). To
re-adopt a custom face: wire `FontFile` ext_resources + a `default_font` in the
theme — see the `parchment_theme.tres` header note.

### Type scale

Logical pixels at 1280×800 reference resolution (Steam Deck native). Each step is ~1.25× the prior — modular scale.

| Token | Size | Use |
|-------|------|-----|
| `xs` | 12px | Chip labels, captions, fine-print only; **never primary body** |
| `sm` | 14px | Secondary labels (e.g., "Lv 7" stat); supplementary info |
| `base` | **16px** | Body copy, hero card labels, button labels, all read-text (the art bible floor) |
| `md` | 18px | Emphasized body, large interactive buttons (Dispatch CTA) |
| `lg` | 20px | In-panel section headings; gold counter number |
| `xl` | **24px** | Identity font floor; screen titles, biome names (the art bible identity floor) |
| `2xl` | 32px | Screen-level identity (e.g., "Lantern Guild" in the Guild Hall header) |
| `3xl` | 40px | Unlock-moment announcement titles |
| `display` | 56px | Victory Moment reward numbers, major reveal ceremonies |

### Hierarchy + color pairing

All surfaces use the **Godot built-in default font**. Hierarchy now comes from
**size + color** (and the theme's `IdentityHeader`/`SelectedSlotButton` variations),
not typeface or weight — there is no SemiBold face wired for the default font.

| Surface | Font | Size | Color |
|---------|------|------|-------|
| Screen title (identity) | Default | 32px (`2xl`) | Slate Ink |
| Section/biome title | Default | 24px (`xl`) | Slate Ink |
| Unlock title (reward ceremony) | Default | 40px (`3xl`) | Lantern Gold on Slate Ink ground |
| Body copy | Default | 16px (`base`) | Slate Ink |
| Stat label (e.g., "Gold:") | Default | 16px (`base`) | Slate Ink |
| Stat value (e.g., "450") | Default | 20px (`lg`) | Lantern Gold |
| Secondary label (e.g., "Lv 7") | Default | 14px (`sm`) | Slate Ink |
| Button label (primary CTA) | Default | 18px (`md`) | Slate Ink |
| Button label (secondary) | Default | 16px (`base`) | Slate Ink |
| Tooltip text | Default | 14px (`sm`) | Slate Ink |

---

## Color

Authoritative palette (Art Bible §4 — locked here for code/Theme reference):

| Name | Hex | Godot Color | Role |
|------|-----|-------------|------|
| Guild Amber | `#C8872A` | `Color(0.784, 0.529, 0.165)` | Player-controlled territory; primary interactive state |
| Lantern Gold | `#F2B83B` | `Color(0.949, 0.722, 0.231)` | Reward and progression highlight; the game's highest-attention color |
| Parchment Cream | `#EDE0C4` | `Color(0.929, 0.878, 0.769)` | UI ground, panel backgrounds |
| Dusk Purple | `#5B4A72` | `Color(0.357, 0.290, 0.447)` | Enemy territory, dungeon ambient, locked content |
| Moss Sage | `#7A8C5E` | `Color(0.478, 0.549, 0.369)` | Forest biome, environmental nature accent |
| Ember Rust | `#A84C2F` | `Color(0.659, 0.298, 0.184)` | Danger indicator, enemy power tier, warning register |
| Slate Ink | `#2C2838` | `Color(0.173, 0.157, 0.220)` | Typography, sprite outlines, deep shadow (never pure black) |

### Color usage rules

1. **Slate Ink replaces black everywhere.** No `Color.BLACK` literal anywhere in code.
2. **No pure-saturated color.** Every color is from the palette above or a value-shifted variant. No `Color(1, 0, 0)` red anywhere.
3. **Lantern Gold is the player's reward signal.** Never on enemy elements, never on neutral information.
4. **Guild Amber grounds player-controlled UI.** Hero sprites, the player's matchup side, interactive button fills.
5. **Dusk Purple communicates "not yours yet."** Locked content, enemy badges, dungeon ambient.

### Dark mode

**Not in MVP.** The parchment-warm register IS the visual identity — there is no alternate dark mode planned. If post-launch playtest reveals battery / readability concerns on mobile, evaluate a "lantern dim" mode (Slate Ink ground + Lantern Gold accent), but this is a Sprint 21+ topic.

### Colorblind backup cues (ADR-0008)

Locked. Matchup triple uses **shape + color**: Lantern Gold ▲ (advantage) / Parchment Cream ● (neutral) / Dusk Purple ▼ (disadvantage). Shape encodes meaning; color reinforces. Per Art Bible §4.

---

## Spacing

8px base unit, comfortable density.

| Token | Value | Use |
|-------|-------|-----|
| `2xs` | 2px | Hairline borders, divider lines |
| `xs` | 4px | Inline icon-to-text gap, tight inset on chips |
| `sm` | 8px | Default gap between sibling labels, inner panel padding (compact) |
| `md` | **16px** | Default panel padding, paragraph spacing, default gap between major elements |
| `lg` | 24px | Section-to-section spacing within a panel |
| `xl` | 32px | Screen-edge margins, header-to-content spacing |
| `2xl` | 48px | Full-screen modal padding, major-section breaks |
| `3xl` | 64px | Hero/ceremony padding, reward-moment screen-edge breathing |

**Touch target minimum**: 44 logical pixels per ADR-0008. Buttons should be ≥44px tall regardless of label length.

---

## Layout

| Aspect | Decision |
|--------|----------|
| Approach | **Hybrid** — grid-disciplined for app screens (Guild Hall, Formation Assignment, Recruit); creative for reward ceremonies (Victory Moment, Unlock reveals) |
| Reference resolution | 1280×800 (Steam Deck native, also serves as portrait-rotation target for mobile) |
| Aspect ratio targets | 16:10 (Steam Deck), 16:9 (PC), 9:16 (portrait mobile post-launch) |
| Safe zones | 5% margin inset from all screen edges; UI never sits at the bleed |
| Max content width | 800px logical on ultra-wide displays (game letterboxes; biome background fills the bleed) |
| Header height | ~80px (10% at 800px tall) |
| NavBar height | ~120px (15% at 800px tall) for thumb-reach on Steam Deck handheld grip |

### Border radii

| Token | Value | Use |
|-------|-------|-----|
| `radius-chip` | 2px | Synergy badges, small inline indicators |
| `radius-button` | 4px | Standard buttons, input fields |
| `radius-panel` | 6px | HeroCards, RosterPanel, dialog content panels |
| `radius-modal` | 8px | Settings overlay, modal containers |
| `radius-circle` | 9999px (full) | Settings gear icon button, hero portrait frames |

### Panel style (StyleBoxFlat → StyleBoxTexture, ADR-0023)

> **Implementation note (ADR-0023, OQ-DS-02 resolved):** `panel_default` and `panel_parchment`
> are now `StyleBoxTexture` 9-patch (a painterly parchment PNG: `assets/art/ui/ui_panel_parchment.png`,
> `texture_margin_* = 14`), not `StyleBoxFlat`. The tokens below still hold — Slate Ink border + 6px
> radius — but are **baked into the texture** (the ink frame is painted at 2px to retain edge
> definition since `StyleBoxTexture` cannot render the vector **drop shadow** below). Read this section
> with ADR-0023.

Default parchment panel:
- Background: Parchment Cream (`#EDE0C4`)
- Border: 1px Slate Ink (`#2C2838`)
- Corner radius: `radius-panel` (6px)
- Shadow: 1px Slate Ink at 10% alpha, 2px Y offset (subtle ink-drop)
- Inner padding: `md` (16px) on all sides

HeroCard sub-panel (variant):
- Same as default panel but `radius-chip` (2px) corners (more rigid/ledger-row feel)
- Inner padding: `sm` (8px) on all sides

---

## Iconography

| Aspect | Decision |
|--------|----------|
| Style | Pixel-outlined with fill (Art Bible §7) |
| Canvas sizes | 16×16 (inline), 24×24 (button), 32×32 (panel header), 48×48 (hero portrait MVP) |
| Stroke | Slate Ink outline at 1px minimum at native canvas; never anti-aliased |
| Fill | Single solid palette color appropriate to semantic role |
| Format | PNG with transparent background; one file per icon at 1× then upscaled at runtime |

**Required MVP icon set**:
- `coin` (16/24px) — Lantern Gold fill, Slate Ink G-rune
- `settings_gear` (24/32px) — Slate Ink outline only
- `dispatch_arrow` (24px) — Guild Amber fill
- `class_warrior` (16/24px) — shield silhouette
- `class_mage` (16/24px) — staff finial
- `class_rogue` (16/24px) — reverse-grip dagger
- `matchup_advantage` (16/24px) — ▲ Lantern Gold
- `matchup_neutral` (16/24px) — ● Parchment Cream + Slate Ink outline
- `matchup_disadvantage` (16/24px) — ▼ Dusk Purple
- `xp_bar` (16px height) — Guild Amber fill on Parchment Cream track

---

## Motion

Animation budget per Art Bible §7: ≤150ms for UI transitions; ≤800ms for reward ceremonies; primary reward number rendered within 100ms.

### Durations

| Token | Value | Use |
|-------|-------|-----|
| `micro` | 80ms | Touch feedback scale pulse, button press response |
| `short` | 150ms | Standard UI transition (panel show/hide, screen cross-fade) |
| `medium` | 300ms | Modal overlay open/close, large-state-change reveals |
| `long` | 800ms | Reward ceremony max (Victory Moment, Unlock reveal) — primary number renders ≤100ms |

### Easing curves (Godot `Tween.EaseType` + `TransitionType`)

| Curve | Godot mapping | Use |
|-------|---------------|-----|
| `enter` | `EASE_OUT`, `TRANS_QUAD` | Things settling into place (panels appearing, content loading in) |
| `exit` | `EASE_IN`, `TRANS_QUAD` | Things leaving (panels dismissing, screens exiting) |
| `move` | `EASE_IN_OUT`, `TRANS_QUAD` | Between-state transitions (gold counter tween, button state changes) |
| `bounce` | `EASE_OUT`, `TRANS_BACK` | Panel-into-place "book settling on table" feel — slight overshoot |

### Touch feedback (locked)

Every tap produces a 1.05× scale pulse over 80ms, returning to 1.0× over another 80ms (160ms total). Per Art Bible §7 and ADR-0008. `UIFramework.wire_touch_feedback` is the canonical helper.

### Reduce motion mode (`reduce_motion` flag, ADR-0007)

When enabled:
- All UI transitions clamp to 50ms (instant-feeling)
- Reward ceremonies replaced with instant reveal + still primary-number render
- Idle pulses (Lantern Gold on interactive elements) disabled
- Touch feedback scale pulse disabled (visual press only)

---

## Component vocabulary

### Button

| Variant | Use | Height | Padding | Radius | Fill | Text |
|---------|-----|--------|---------|--------|------|------|
| `primary` | Major CTA (Dispatch) | 80px | 24px horizontal | 6px | Guild Amber | Slate Ink, 18px SemiBold |
| `secondary` | Supporting action (Recruit, Settings cancel) | 44px | 16px horizontal | 4px | Parchment Cream + 1px Slate Ink border | Slate Ink, 16px Regular |
| `icon` | Settings gear, close X | 44×44 | 8px | 9999px (circle) | Transparent (Slate Ink outline only on hover/active) | Icon only |
| `disabled` | Any state | varies | varies | varies | 40% opacity overlay; `disabled=true` | Slate Ink at 40% opacity |

### Panel

| Variant | Use | Padding | Radius | Border |
|---------|-----|---------|--------|--------|
| `parchment-default` | Standard ledger panels (RosterPanel, dialog content) | 16px | 6px | 1px Slate Ink |
| `ledger-row` | HeroCard, list items inside a parchment-default | 8px | 2px | 1px Slate Ink at 50% alpha |
| `modal` | Settings overlay, confirmation dialogs | 32px | 8px | 1px Slate Ink + drop shadow |
| `ceremony` | Victory Moment, Unlock reveal | 48px | 8px | None — full-bleed parchment with edge vignette |

### Label / text element

| Variant | Font + size | Color |
|---------|-------------|-------|
| `body` | Lora Regular 16px | Slate Ink |
| `body-emphasis` | Lora SemiBold 16px | Slate Ink |
| `stat-label` | Lora SemiBold 16px | Slate Ink |
| `stat-value` | Lora SemiBold 20px | Lantern Gold (rewards) or Slate Ink (neutral) |
| `secondary` | Lora Regular 14px | Slate Ink |
| `caption` | Lora Regular 12px | Slate Ink at 70% alpha |
| `title-screen` | IM Fell English 32px | Slate Ink |
| `title-section` | IM Fell English 24px | Slate Ink |
| `title-reward` | IM Fell English 40px | Lantern Gold on Slate Ink ground |

---

## Godot Theme implementation (translation guide)

This design system translates to Godot via the existing parchment theme (S10-M1 + S10-M2, locked by ADR-0008). Each design token maps to a Theme override:

| Design token | Godot Theme override |
|--------------|----------------------|
| Color palette | `Color` constants in `src/ui/ui_framework.gd` (`GUILD_AMBER`, `LANTERN_GOLD`, etc.); referenced via Theme overrides on Control nodes |
| Typography | `FontFile` resources at `res://assets/fonts/`; Theme's default font family per `Theme.set_font("font", "Label", lora_regular)` |
| Spacing | `Theme.set_constant("margin_left", "PanelContainer", 16)` etc. |
| Border radii | `StyleBoxFlat.corner_radius_top_left` (and 3 siblings) on theme variant per panel type |
| Border style | `StyleBoxFlat.border_width_*` + `StyleBoxFlat.border_color` |
| Touch feedback | `UIFramework.wire_touch_feedback(control)` — locked helper, applies the 1.05× scale pulse |

The parchment theme (`assets/ui/parchment_theme.tres`) is the canonical Theme resource. All Control nodes inherit from it via the SceneTree root's theme cascade per ADR-0008. Per-screen theme variants are stored in the theme's `type_variation` mechanism, not as separate resources.

---

## Localization considerations

- All fonts ship Latin Extended; Cyrillic supported on Lora (IM Fell English is Latin-only — biome titles / display text in non-Latin locales fall back to Lora at the same size).
- Type scale tested for 140% expansion (German, Hungarian) — body fonts have margin; identity fonts may need size reduction for those locales at fixed-width slots.
- No icon should rely on text-language signals; every icon's meaning must be readable cross-locale.

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-14 | Initial DESIGN.md authored via `/design-consultation` | Codifies art-bible-locked values + closes typography (Lora + IM Fell English), spacing (8px comfortable), component vocabulary, and motion gaps |
| 2026-05-14 | Lora chosen as information font | Calligraphic-tradition serif; legible at 16px; commercial OFL license; matches "writerly hand-shaped without sacrificing readability" |
| 2026-05-14 | IM Fell English chosen as identity font | Historical 17th-century manuscript revival — the ink-drawn calligraphic-tool register the art bible asks for, literally |
| 2026-05-14 | 8px comfortable density picked over compact/spacious | Matches "set down a piece of paper" framing; standard mobile-first density; preserves cozy register |
| 2026-05-14 | Dark mode deferred to Sprint 21+ | Parchment-warm IS the identity; alternate dark mode would dilute. Revisit if mobile playtest reveals battery/readability concerns. |

---

## Open Questions

- **OQ-DS-01**: Tabular-nums feature in Lora — verify Godot 4.6 supports OpenType feature toggles on FontFile resources via `font_features = {"tnum": 1}`. Pending engine-reference doc check before stat-table implementation.
- **OQ-DS-02**: ~~Parchment texture — is the panel background a solid color (`#EDE0C4`), a procedural noise overlay, or a static PNG texture?~~ **RESOLVED → static PNG 9-patch texture (ADR-0023).** Composed from a Gemini-painted parchment fill + a deterministic PIL-drawn Slate Ink frame, wired as `StyleBoxTexture` on `panel_default` + `panel_parchment`. See §"Panel style" note below.
- **OQ-DS-03**: Reduce-motion idle-pulse disable — confirm via tests that the Lantern Gold idle pulse on interactive buttons respects `reduce_motion` flag. Likely a Sprint 20 implementation story.

---

*Authored 2026-05-14 by `/design-consultation` for the Sprint 20 UI/HUD theme. Pairs with `design/art/art-bible.md` (visual direction). All subsequent UX specs (`design/ux/*.md`) and Godot Theme work must reference this document for typography, color, spacing, and motion values.*
