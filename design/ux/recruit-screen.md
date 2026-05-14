# UX Spec: Recruit Screen

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-14
> **Journey Phase(s)**: Idle Core Loop (between dispatches); Long-game planning
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/recruit-screen.md` (#21); pairs with `design/gdd/recruitment-system.md` (#14)
> **Template**: UX Spec

---

## Purpose & Player Need

Recruit Screen is the **long-game shop** — where the player spends gold to grow their roster. It's the second player-facing destination after Guild Hall, paired with Dispatch as the two ways the player spends their accumulated currency.

**Player goal on arrival**: *"Show me what I can recruit, show me what costs what, let me spend my gold confidently — or save up — without surprises."*

The screen serves two parallel decisions:
1. **Affordable now**: which heroes can the player recruit with their current gold balance?
2. **Save for next**: which heroes are over budget right now but worth saving for?

The screen must communicate both states equally well. **Dimmed-because-unaffordable rows must still tell the player what they'd need to save up** — never hidden, never ambiguous. Per the cozy register: anticipation, not anxiety. No timers, no FOMO, no limited-time pulls.

Pool refreshes are player-controlled: either passively (first-clear triggers a refresh per `recruitment-system.md`) or actively (paid refresh button). The player decides when to reroll; the game never forces it.

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **Post-run flush** | Just completed a dungeon run; gold balance jumped; pool may have refreshed via first-clear | Excited / wealth-flush — "can I afford anything new?" | Gold counter prominent at top; affordability gating clearly visible at a glance |
| **Save-up check** | Player navigated here deliberately to see what they'd need | Planning / patient — long-game horizon | Costs visible on all rows, including unaffordable; tooltip on dim row explains how much short |
| **First-launch** | Brand new save; 100 gold; pool seeded by `Recruitment.fresh_pool()` | Curious / exploring — first time seeing recruit pool | Pool entries readable; cheapest affordable; Recruit button on at least the cheapest entry |
| **Came from Guild Hall (deliberate)** | Tapped Recruit button on Guild Hall (gate said affordable) | Intent-driven; wants to actually recruit something | Recruit button states are reliable; tap recruits immediately + provides clear feedback |

The screen should feel like browsing a guild ledger of recruitable adventurers — not a gacha pull screen, not a Steam store page. The two reference anti-patterns: never a "Limited Time!" banner; never a "Get N pulls for $X" prompt.

---

## Navigation Position

Recruit Screen is a **first-level child** of Guild Hall — one tap away from the hub via the Recruit nav button.

```
Guild Hall (root hub)
  └── Recruit Screen  ← THIS SCREEN
        └── (back) → Guild Hall  (only exit)
```

No further sub-screens. All interactions (recruit, refresh) happen in-place; no modal navigation.

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|--------------------|
| Recruit nav from Guild Hall | Guild Hall RecruitNavButton (gated on affordability) | Current gold balance, current pool state |
| Direct nav (dev/back-stack) | `SceneManager.request_screen("recruit_screen")` | Same — gold + pool |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Back to Guild Hall | Tap BackButton | Cross-fade 150ms; no commit/save required (all writes are atomic per-recruit) |
| App close | OS home / force-quit | All state already persisted via Recruitment + Economy autoloads |

---

## Layout Specification

### Information Hierarchy

Ranked by player decision importance:

1. **Gold balance** — first thing the player checks; gates every other decision on the screen
2. **Pool entry costs** — what each recruit would cost
3. **Recruit buttons (per entry)** — the primary actions; visible enabled/disabled state tells the affordability story
4. **Owned counts (per entry)** — informational; affects cost progression
5. **Refresh pool button** — secondary action; costs gold; rarely the primary intent
6. **Back button** — navigation; never the primary action

### Layout Zones

Three vertical zones stacked top-to-bottom (matches existing scene tree):

| Zone | Height | Contents |
|------|--------|----------|
| Header bar | ~80px (~10%) | BackButton + ScreenTitleLabel + GoldCounter |
| Pool panel | flex (~70%) | 3 PoolEntry rows in a VBoxContainer |
| Footer bar | ~80px (~10%) | RefreshPoolButton |

### Component Inventory

**Zone 1 — Header bar**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| HeaderBar | PanelContainer | Container | No | `panel` variant `parchment-default`, no border-radius on top edges (sits flush) |
| BackButton | Button | `tr("recruit_screen_back_button")` ("← Guild Hall") | Yes | `button` variant `secondary`, 44×44 min |
| ScreenTitleLabel | Label | `tr("recruit_screen_title")` ("Recruit") | No | `title-section` — IM Fell English 24px |
| GoldCounter | Label | Coin icon + `tr("recruit_screen_gold_format", [balance])` | No | `stat-value` style — Lora SemiBold 20px Lantern Gold |

**Zone 2 — Pool panel (3 PoolEntry rows)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| PoolPanel | PanelContainer | Container, scroll-capable if pool grows beyond 3 | No | `panel` variant `parchment-default` |
| PoolVBox | VBoxContainer | Vertical layout of pool entries | No | `md` (16px) gap between entries |
| PoolEntry (×3) | HBoxContainer | One per pool slot | Per-row interactive | `panel` variant `ledger-row` per row |
| PoolEntry → ClassPortrait | TextureRect | 96×96 logical px class portrait (placeholder allowed in MVP) | No | n/a |
| PoolEntry → EntryDetails | VBoxContainer | Stack: name / cost / owned | No | `xs` (4px) gap between labels |
| PoolEntry → ClassNameLabel | Label | `tr("class_<id>_display_name")` ("Warrior", "Mage", etc.) | No | `title-section` IM Fell English 24px (per row — identity moment for each class) |
| PoolEntry → CostLabel | Label | `tr("recruit_screen_cost_format", [cost])` ("150 gold") | No | `stat-value` — Lora SemiBold 20px Lantern Gold |
| PoolEntry → OwnedLabel | Label | `tr("recruit_screen_owned_format", [count])` ("(owned: 3)") | No | `secondary` — Lora Regular 14px Slate Ink 70% alpha |
| PoolEntry → RecruitButton | Button | `tr("recruit_screen_recruit_button")` ("Recruit") | Yes (gated by gold) | `button` variant `primary` when affordable; 40% opacity + disabled when not |

**Zone 3 — Footer bar**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| FooterBar | PanelContainer | Container | No | `panel` variant `parchment-default`, no border-radius on bottom edges |
| RefreshPoolButton | Button | `tr("recruit_screen_refresh_format", [refresh_cost])` ("Refresh Pool — 100 gold") | Yes (gated by gold) | `button` variant `secondary`; Guild Amber accent on enabled; 40% opacity when not |

### ASCII Wireframe

Portrait orientation (1280×800 Steam Deck reference):

```
┌─────────────────────────────────────────────┐
│ [← Guild Hall]   Recruit         ⬡ 950g   │  ← Header (80px)
├─────────────────────────────────────────────┤
│ ┌──────────────────────────────────────┐   │
│ │ ┌────┐  Warrior                      │   │
│ │ │    │  150 gold                     │   │  ← PoolEntry 0
│ │ │portr.│  (owned: 4)         [Recruit] │   │
│ │ └────┘                                │   │
│ ├──────────────────────────────────────┤   │
│ │ ┌────┐  Rogue                        │   │
│ │ │portr.│  270 gold                     │   │  ← PoolEntry 1
│ │ └────┘  (owned: 2)         [Recruit] │   │
│ ├──────────────────────────────────────┤   │
│ │ ┌────┐  Mage                         │   │
│ │ │portr.│  8000 gold (dim)              │   │  ← PoolEntry 2
│ │ └────┘  (owned: 0)         [Recruit] │   │     (unaffordable)
│ │                            ↑ disabled │   │
│ └──────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│         [ Refresh Pool — 100 gold ]         │  ← Footer (80px)
└─────────────────────────────────────────────┘
```

Notes:
- Each PoolEntry row is ≥120px tall (96 portrait + 24 padding) — meets the 44×44 tap-target floor on RecruitButton + comfortable readability
- ClassNameLabel uses IM Fell English (identity moment per class — the "Warrior" feels like an entry in a guild ledger)
- Unaffordable rows: row at full opacity, but Recruit button at 40% opacity + tooltip on long-press / hover showing deficit
- Gold counter on the right of header mirrors Guild Hall position (consistency across hub-and-spoke screens)
- Refresh button cost text updates as the player refreshes (cost increases per refresh-today per Recruitment GDD §C.5)

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **Default — pool fresh, some affordable** | Normal arrival; some entries affordable, some not | All 3 entries visible at full opacity; Recruit buttons styled per affordability |
| **All affordable** | Player gold ≥ cost on all 3 entries | All 3 Recruit buttons enabled (primary style + Guild Amber) |
| **None affordable** | Player gold < cheapest entry's cost | All 3 Recruit buttons disabled (40% opacity + tooltips); Refresh button affordability depends on its own cost |
| **First-launch** | Fresh save: 100 gold, seeded pool | Pool shows 3 entries (typically: 1 affordable Warrior at 50g, 2 unaffordable); cheapest Recruit button enabled to invite a first recruit |
| **Recruit successful** | Player tapped Recruit on entry N; `Recruitment.try_recruit(N)` succeeded | Gold counter ticks down with brief Guild Amber pulse (≤300ms); entry N's OwnedLabel updates (count+1); entry N's CostLabel updates to next-copy cost; other entries re-evaluate affordability |
| **Recruit failed (gold insufficient)** | Edge case: player tapped Recruit during a race condition where gold dropped between display + tap | Toast "Insufficient gold" appears briefly; no state change |
| **Pool refresh — passive** | First-clear elsewhere triggers `pool_refreshed` signal | All 3 entries re-render with new class IDs; brief 200ms cross-fade per entry |
| **Pool refresh — paid** | Player tapped RefreshPoolButton; gold deducted | Refresh button cost updates per `refresh_cost(refreshes_today)`; brief Lantern Gold pulse on entries as they cross-fade |
| **Refresh button — affordable** | Gold ≥ refresh cost | Full opacity + Guild Amber secondary style |
| **Refresh button — unaffordable** | Gold < refresh cost | 40% opacity + disabled |
| **Empty pool (defensive)** | `Recruitment.get_recruit_pool().size() == 0` | All 3 entries hidden; empty-state label "No recruits available" displayed centered in PoolPanel; RefreshPoolButton remains active (with cost) |
| **Orphan class (defensive)** | Pool entry references a class_id that DataRegistry can't resolve | That row hidden; `push_warning` logged; remaining rows render normally |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Immediate feedback | Outcome |
|-----------|--------|-------|--------------------|---------|
| BackButton | Tap | Mouse LMB / touch | `sfx_ui_tap` + press visual | `SceneManager.request_screen("guild_hall", CROSS_FADE)` |
| RecruitButton (enabled) | Tap | Mouse LMB / touch | `sfx_ui_tap` + Guild Amber → Lantern Gold flash + brief scale pulse (1.05×) | `Recruitment.try_recruit(pool_index)` → Economy deducts gold; HeroRoster.add_hero fires; entry re-renders |
| RecruitButton (disabled) | Tap | Mouse LMB / touch | No feedback (disabled state) | No-op. PC: hover shows tooltip "Need N more gold." Touch: long-press shows same tooltip. |
| RefreshPoolButton (enabled) | Tap | Mouse LMB / touch | `sfx_ui_tap` + button press | `Recruitment.refresh_pool()` → gold deducted; pool rerolls; all 3 entries cross-fade |
| RefreshPoolButton (disabled) | Tap | Mouse LMB / touch | No feedback | No-op. Tooltip on hover/long-press: "Need N more gold to refresh." |
| GoldCounter | — | Display only | — | No action |
| ClassPortrait | — | Display only | — | No action (V1.0 may make this tappable for class detail) |
| ClassNameLabel / CostLabel / OwnedLabel | — | Display only | — | No action |

**Visual flow for "successful recruit"**:
1. Player taps RecruitButton on entry N (e.g., Warrior, 150g)
2. Within 1 frame: button scale pulse (1.05× → 1.0× over 160ms)
3. `Recruitment.try_recruit(N)` fires; atomic write to Economy + HeroRoster
4. `Economy.gold_changed` signal → GoldCounter ticks down with Guild Amber pulse over 300ms (`stat-value` color shift, not a number animation)
5. `HeroRoster.hero_recruited` signal → entry N's OwnedLabel updates (e.g., "owned: 3" → "owned: 4"); CostLabel updates to next-copy cost
6. All other entries re-evaluate Recruit button affordability based on new gold

Total perceived latency: ≤300ms from tap to all-state-updated. Per Art Bible §7 animation budget.

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Screen open | None (no specific screen-open event; gold + pool reads happen via on_enter) | — |
| Tap RecruitButton (enabled) | `ui_recruit_tapped` | `{ screen: "recruit_screen", pool_index, class_id, cost, gold_balance_before }` |
| Tap RecruitButton (disabled) | None (no-op) | — |
| Tap RefreshPoolButton (enabled) | `ui_recruit_pool_refresh_tapped` | `{ screen: "recruit_screen", refresh_cost, refreshes_today }` |
| Tap BackButton | `ui_back_tapped` | `{ screen: "recruit_screen" }` |
| `Recruitment.try_recruit` succeeded | `hero_recruited` (autoload signal) | `{ instance: HeroInstance }` |
| `Recruitment.refresh_pool` succeeded | `pool_refreshed` (autoload signal) | `{ new_pool: Array[String] }` |

**Persistent state writes** on this screen:
- `Economy._gold_balance` — via `Recruitment.try_recruit` or `Recruitment.refresh_pool`
- `HeroRoster._heroes` — via `Recruitment.try_recruit` → `HeroRoster.add_hero`
- `Recruitment._current_pool` + `_refreshes_today` — via `Recruitment.refresh_pool` or first-clear-triggered refresh

All writes are atomic through Recruitment autoload's `try_recruit` and `refresh_pool` methods (per ADR-0015 determinism contract).

---

## Transitions & Animations

**Screen enter**: 150ms cross-fade from Guild Hall.

**Screen exit**: 150ms cross-fade to Guild Hall.

**Recruit success — gold counter pulse**: GoldCounter text color briefly shifts to Guild Amber over 100ms, then back to default over 200ms. Reduce-motion: instant color change (no pulse).

**Pool entry re-render (after recruit)**: OwnedLabel and CostLabel cross-fade old → new value over 150ms. Reduce-motion: instant.

**Pool entry re-render (after refresh)**: each PoolEntry's ClassPortrait + ClassNameLabel + CostLabel + OwnedLabel cross-fade over 200ms with a 50ms stagger between entries (Entry 0 starts at 0ms, Entry 1 at 50ms, Entry 2 at 100ms — feels like "the ledger turning pages"). Reduce-motion: all instant.

**Recruit button press**: 1.05× scale pulse over 80ms + return to 1.0× over 80ms (`UIFramework.wire_touch_feedback` per ADR-0008). Reduce-motion: no scale pulse; only visual press state.

**Affordability re-evaluation**: when gold changes, all Recruit and Refresh buttons re-evaluate. Disabled → enabled transition: 150ms cross-fade from 40% opacity to 100%. Enabled → disabled: 150ms cross-fade in reverse.

---

## Data Requirements

| Data | Source system | Read / Write | Live-updating? | Notes |
|------|--------------|--------------|----------------|-------|
| Gold balance | Economy autoload | Read | Yes — `gold_changed` signal | Drives GoldCounter + all button affordability |
| Recruit pool | Recruitment autoload | Read — `get_recruit_pool() -> Array[String]` (deep copy) | Yes — `pool_refreshed` signal | Drives 3 PoolEntry rows |
| Recruit cost per entry | Recruitment autoload — `get_recruit_cost(pool_index)` | Read | Yes — re-evaluated on each `hero_recruited` (cost increases per copy owned) | Drives CostLabel + RecruitButton gating |
| Owned count per class | HeroRoster — count of heroes with matching class_id | Read | Yes — `hero_recruited`, `hero_removed`, `prestige_completed_signal` | Drives OwnedLabel |
| Class metadata (display name, portrait) | DataRegistry — `resolve("classes", class_id)` | Read | No (static content) | Drives ClassNameLabel + ClassPortrait |
| Refresh cost | Recruitment autoload — `refresh_cost(refreshes_today)` | Read | Yes — re-evaluated after each refresh | Drives RefreshPoolButton label + affordability |

**Write paths** (atomic, autoload-mediated):
- `Recruitment.try_recruit(pool_index)` — Economy gold deduct + HeroRoster.add_hero; single transaction per ADR-0015
- `Recruitment.refresh_pool()` — Economy gold deduct + Recruitment._current_pool reroll; single transaction

---

## Accessibility

**Committed tier**: Standard per `design/accessibility-requirements.md`.

| Requirement | Implementation |
|-------------|---------------|
| Touch tap targets ≥44×44 logical pixels | RecruitButton per row: 80px tall × ~140px wide (more than meets). RefreshPoolButton: 60px tall × full footer width. BackButton: ≥44×44 minimum. |
| No color-only indicators | Recruit button disabled state: 40% opacity + `disabled = true` property + tooltip showing deficit. Three independent signals — not color only. Same for Refresh button. Affordable vs unaffordable rows: button visibility tells the story, not the row's color. |
| Reduce-motion | Recruit success pulse: instant color change. Pool entry cross-fades: instant. Button press scale pulse: disabled (visual press state only). |
| Colorblind backup cues | Recruit/disabled button state uses opacity + disabled property + tooltip — color is reinforcement, not primary signal. Per Art Bible §4 colorblind safety. |
| Text contrast | Slate Ink (`#2C2838`) on Parchment Cream (`#EDE0C4`) at 16px Lora — must verify ≥4.5:1 WCAG AA before visual handoff. Lantern Gold (`#F2B83B`) numeric values on Parchment Cream may need contrast verification (gold-on-cream is the tightest contrast pair on this screen). |
| Input remapping (Standard tier) | Handled at Steam platform layer via Steam Input. No in-game remap UI. |
| Font size floor | Body text ≥16px Lora; ClassNameLabel ≥24px IM Fell English (identity floor); CostLabel ≥20px (stat-value); OwnedLabel ≥14px (secondary, but tightest size on screen — must verify at small UI scale settings). |
| Tooltip readability | Disabled-button tooltip must show deficit in player's locale ("Need 200 more gold") — never just the number. Long-press triggers tooltip on touch. |
| Keyboard navigation | Not required (mouse/touch primary). `suppress_keyboard_focus` called on all Controls per UIFramework pattern. |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| BackButton label (`recruit_screen_back_button`) | ~16 chars ("← Guild Hall" = 12) | LOW | Header button has room |
| ScreenTitleLabel (`recruit_screen_title`) | ~16 chars ("Recruit" = 7) | LOW | German "Rekrutieren" = 11; comfortable fit |
| GoldCounter format (`recruit_screen_gold_format`) | ~12 chars ("950 gold" or "1.2k") | LOW | Numeric primarily; localization affects "gold" word |
| ClassNameLabel (`class_<id>_display_name`) | ~20 chars | MEDIUM | "Warrior" / "Krieger" / "Guerrier" all fit. Longer class names in non-Latin languages may need width budget. |
| CostLabel format (`recruit_screen_cost_format`) | ~16 chars ("150 gold") | LOW | Numeric primarily |
| OwnedLabel format (`recruit_screen_owned_format`) | ~14 chars ("(owned: 99)") | MEDIUM | German "(besessen: 99)" = 16; tight. May need parens-free format ("besessen: 99") for compactness. |
| RecruitButton label (`recruit_screen_recruit_button`) | ~12 chars ("Recruit" = 7) | LOW | German "Anwerben" = 8; comfortable |
| RefreshPoolButton format (`recruit_screen_refresh_format`) | ~28 chars ("Refresh Pool — 100 gold") | MEDIUM-HIGH | German "Pool erneuern — 100 Gold" = 24; tight. Hungarian / Finnish may overflow. Layout-critical. |
| Disabled tooltip format (`recruit_screen_insufficient_tooltip_format`) | ~30 chars ("Need 200 more gold") | LOW | Tooltip wraps; no layout constraint |

**HIGH PRIORITY for loc review**:
- RefreshPoolButton label format — test at 140% expansion; consider line-wrapping the footer button or splitting into "Refresh Pool" + "(100 gold)" stacked layout if width-constrained
- OwnedLabel parentheses convention — German doesn't use parens the same way; consider alternative format string

---

## Acceptance Criteria

- [ ] **UX-RS-01 (layout)**: All three zones (Header / Pool / Footer) visible without scrolling on 1280×800 (Steam Deck native). PoolPanel scrolls if pool grows beyond 3 entries (post-MVP scope).
- [ ] **UX-RS-02 (gold display)**: GoldCounter displays `Economy.get_gold_balance()` correctly on screen open; format: coin icon + value + "gold" per locale key. Updates within one frame of `Economy.gold_changed`.
- [ ] **UX-RS-03 (pool render)**: Three PoolEntry rows display, each showing ClassPortrait + ClassNameLabel + CostLabel + OwnedLabel + RecruitButton. Content correct per `Recruitment.get_recruit_pool()`.
- [ ] **UX-RS-04 (affordability gating — visible)**: Each RecruitButton's enabled state matches `gold >= recruit_cost(pool_index)`. Affordable: full opacity + Guild Amber primary. Unaffordable: 40% opacity + `disabled = true`.
- [ ] **UX-RS-05 (recruit success)**: Tapping enabled RecruitButton on entry N calls `Recruitment.try_recruit(N)`. On success: GoldCounter updates with Guild Amber pulse; entry N's OwnedLabel and CostLabel update to reflect new ownership; other entries re-evaluate affordability.
- [ ] **UX-RS-06 (recruit atomic)**: Tapping RecruitButton results in either both gold deduction AND hero addition, or neither. Never half-completed (per ADR-0015 atomicity).
- [ ] **UX-RS-07 (cost progression)**: After recruiting class X, the same row's CostLabel updates to `recruit_cost(class_id, owned + 1)` — i.e., the next-copy cost.
- [ ] **UX-RS-08 (refresh button — affordable)**: When `gold >= refresh_cost(refreshes_today)`, RefreshPoolButton is enabled (full opacity + Guild Amber secondary style). Label shows current cost.
- [ ] **UX-RS-09 (refresh button — unaffordable)**: When `gold < refresh_cost`, RefreshPoolButton is disabled (40% opacity); tap shows tooltip "Need N more gold to refresh."
- [ ] **UX-RS-10 (refresh action)**: Tapping enabled RefreshPoolButton calls `Recruitment.refresh_pool()`. Gold deducts; all 3 pool entries cross-fade to new content over 200ms with 50ms inter-entry stagger.
- [ ] **UX-RS-11 (passive pool refresh)**: When `Recruitment.pool_refreshed` fires from external trigger (e.g., first-clear), all 3 entries cross-fade to new content with the same stagger pattern as paid refresh.
- [ ] **UX-RS-12 (back navigation)**: Tapping BackButton routes to Guild Hall via 150ms cross-fade. No commit/save required (atomicity per UX-RS-06).
- [ ] **UX-RS-13 (tap targets)**: All interactive elements (BackButton, RecruitButton ×3, RefreshPoolButton) have touch tap targets ≥44×44 logical pixels.
- [ ] **UX-RS-14 (orphan class — defensive)**: If a pool entry references a class_id that `DataRegistry.resolve("classes", id)` can't find, that row is hidden + push_warning logged. Remaining rows render normally; screen does not crash.
- [ ] **UX-RS-15 (empty pool — defensive)**: If `Recruitment.get_recruit_pool().size() == 0`, all 3 entries hidden; empty-state label "No recruits available" displayed in PoolPanel; RefreshPoolButton remains active.
- [ ] **UX-RS-16 (signal cleanup)**: After `on_exit`, all signals connected in `on_enter` (`gold_changed`, `hero_recruited`, `pool_refreshed`) report `is_connected == false`.
- [ ] **UX-RS-17 (locale keys complete)**: All Recruit Screen locale keys exist in `assets/locale/en.csv` with non-empty values: `recruit_screen_title`, `recruit_screen_back_button`, `recruit_screen_gold_format`, `recruit_screen_cost_format`, `recruit_screen_owned_format`, `recruit_screen_recruit_button`, `recruit_screen_refresh_format`, `recruit_screen_insufficient_tooltip_format`, `recruit_screen_empty_pool_label`.
- [ ] **UX-RS-18 (tap feedback)**: Tapping RecruitButton (enabled) or RefreshPoolButton (enabled) fires `sfx_ui_tap` audio chime + visual press animation within 16ms (1 frame at 60fps).
- [ ] **UX-RS-19 (cozy register — no FOMO)**: No timer, countdown, "Limited time!" banner, or similar FOMO-coded visual appears anywhere on the screen. Pool refresh is purely player-controlled. Per Pillar 1 cozy register commitment.
- [ ] **UX-RS-20 (accessibility — colorblind)**: No information conveyed by color alone. Disabled states use opacity + `disabled=true` + tooltip text. Affordable/unaffordable distinction reads via button state (enabled vs disabled), not row color.

---

## Open Questions

- **OQ-RS-01**: ClassPortrait placeholder strategy — what does an MVP recruit row look like before real class portrait art lands? Recommend: parchment-cream square with the class's IM Fell English first letter inset (W, R, M, etc.) in Slate Ink. Falls back gracefully when real art lands.
- **OQ-RS-02**: Gold-on-cream contrast verification — CostLabel uses Lantern Gold (`#F2B83B`) on Parchment Cream (`#EDE0C4`) which is the tightest contrast pair on this screen. Must verify ≥4.5:1 WCAG AA before visual handoff (likely needs a Slate Ink 1px outline on the gold per Art Bible §4 colorblind backup cue).
- **OQ-RS-03**: V1.0 class detail tap — should ClassPortrait or ClassNameLabel become tappable in V1.0 to open a class detail modal (showing class stats, perks, lore)? Sprint 21+ candidate; not needed for MVP.
- **OQ-RS-04**: Refresh pool — confirmation dialog for high-cost refresh? At 100g refresh cost on a 1000g balance, no confirmation needed. At 800g refresh cost on a 1000g balance (10 refreshes in a day), should a confirmation appear? Recommend: no confirmation regardless of cost — pool refresh is reversible (player can dispatch + earn back the gold) and the cozy register favors trust over guardrails. Revisit if playtest signals accidental-spend regret.
- **OQ-RS-05**: Pool refresh — animation feedback for "no new content?" If pool refresh happens to reroll into the exact same 3 classes (low probability but possible), should the cross-fade still play, or should there be a "pool unchanged" toast? Recommend: cross-fade plays regardless (the gold was spent; the feedback should be consistent).
- **OQ-RS-06**: 2 new visual patterns to add to `interaction-patterns.md`: **Affordability Gating** (the universal pattern of "show the cost; gate the action; tell the player the deficit") and **Pool Entry Card** (ledger-row variant with portrait + multi-line details + action button — also applies to future shop screens or any list of purchasable items).
- **OQ-RS-07**: No player journey map exists at `design/player-journey.md` — same gap as Guild Hall and Formation Assignment specs.
