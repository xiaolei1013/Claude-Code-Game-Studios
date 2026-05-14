# UX Spec: Guild Hall

> **Status**: APPROVED 2026-05-14 (post-/ux-review advisory fixes — 17 ACs, all 14 required sections complete)
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-14
> **Journey Phase(s)**: Session Start / Idle Core Loop / Post-Run return
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/guild-hall-screen.md` (#19)
> **Template**: UX Spec

---

## Purpose & Player Need

The Guild Hall is the game's home. The player arrives here after every run, every launch, and every navigation away from the sub-screens. Its purpose is singular: let the player assess their guild's state in under 3 seconds and either dispatch, recruit, or do nothing. There is no hidden information on this screen — everything the player needs to decide their next action is visible immediately on arrival.

The player arrives wanting to know: "How much gold do I have? Are my heroes ready? Should I dispatch or recruit first?" The screen must answer all three questions before the player has to scroll or tap anything.

**Three arrival contexts** (design must serve all three equally):
1. **Cold launch** — player wants to see what accumulated overnight; wants to dispatch immediately
2. **Post-run return** — auto-routed back from Dungeon Run View after RUN_ENDED; player is in outcome-acknowledgment mode before the next intent
3. **Deliberate visit** — player navigated back from Formation Assignment, Recruit Screen, or Settings; they have specific intent (usually back to dispatch)

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| Cold launch | Was away (sleep, work, life) | Curiosity + mild anticipation — "what did my guild earn?" | Gold counter must be prominent and immediately readable; it answers the key question |
| Post-run return | Just watched kill count + auto-routed | Satisfied/neutral — outcome acknowledged, ready for next loop | Dispatch button should feel naturally available; no cooldown anxiety |
| Deliberate visit | Was in Formation Assignment, Recruit, or Settings | Purposeful, directed — specific intent | Navigation must be frictionless; nothing should interrupt their path |

The screen should never feel urgent or stressful. The player is in the guild hall — warm, safe, familiar. The Victory Moment screen (if any) owns the run-complete celebration; by the time the player arrives here, the emotional beat has resolved.

No tutorial arrows, no "tap to begin" overlays, no welcome banners. The seeded state (Theron at level 1, 100 gold) IS the tutorial per GDD #19 §C.9.

---

## Navigation Position

Guild Hall is the game's **root hub screen** — every other screen branches from it or returns to it. It has no parent; it is the top of the navigation hierarchy.

```
Main Menu
    └── Guild Hall  ← root hub
          ├── Formation Assignment → Dungeon Run View → Guild Hall  (dispatch loop)
          ├── Recruit Screen → Guild Hall
          └── Settings  (modal overlay — does not replace Guild Hall)
```

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|-------------------|
| Game launch | Main Menu | Fresh session; offline accumulation already applied |
| Auto-route on RUN_ENDED | Dungeon Run View | Run just completed; snapshot reset; post-run emotional beat resolved |
| Back navigation | Formation Assignment | May have changed formation; back button or dispatch-cancelled |
| Back navigation | Recruit Screen | May have just recruited a hero (roster updated) |
| Modal dismiss | Settings overlay | Settings may have changed (reduce_motion, etc.); on_resume fires |

**Exit destinations:**

| Exit | Destination | Trigger | Notes |
|------|------------|---------|-------|
| Dispatch | Formation Assignment | Tap DispatchNavButton | Always available (button enabled by default) |
| Recruit | Recruit Screen | Tap RecruitNavButton | Gated: disabled + dimmed if gold < cheapest recruit cost |
| Settings | Settings overlay (modal) | Tap SettingsGearButton | Gated: disabled during offline replay (OE is_replay_in_flight) |
| App close | n/a | OS home / force-quit | No save action needed — state is in autoloads |

---

## Layout Specification

### Information Hierarchy

Ranked by player decision importance — elements higher in the list command more visual weight and placement priority:

1. **Gold balance** (answers "can I recruit? how well did my last run go?") — must be visible without scrolling, immediately on arrival
2. **Dispatch button** (primary action; 90% of sessions end with a dispatch) — largest interactive element, bottom of screen for thumb reach
3. **Hero roster** (informational — confirms who's available, class composition, level progress) — occupies the most vertical space, scrollable
4. **Formation synergy** (conditional signal — tells player if their current formation has a bonus active) — appears only when relevant; lives between roster and nav
5. **Recruit button** (secondary action, gated by gold) — secondary prominence, right of dispatch
6. **Settings gear** (maintenance-only, rarely needed) — minimal visual weight, corner placement

### Layout Zones

Four vertical zones stacked top-to-bottom:

| Zone | Height | Contents |
|------|--------|----------|
| Header bar | ~80px (~10%) | Title + Gold counter + Settings gear |
| Roster scroll | flex (~65%) | HeroCard list, vertically scrollable |
| Synergy strip | 0px (hidden) or ~48px (when active) | Active synergy name + effect |
| NavBar | ~120px (~20%) | Dispatch (primary, 2/3 width) + Recruit (secondary, 1/3 width) |

**Why synergy strip is conditional**: it occupies zero height when no synergy is active, and expands to ~48px when an active synergy exists. This keeps the screen uncluttered for most players while surfacing the formation bonus cleanly when it matters.

### Component Inventory

**Zone 1 — Header bar**

| Component | Type | Content | Interactive | Notes |
|-----------|------|---------|-------------|-------|
| Title label | Label | `tr("guild_hall_title")` = "Lantern Guild" | No | Left-aligned; Slate Ink; identity font |
| Gold counter | Label + coin icon | Coin icon + `tr("guild_hall_gold_format", [balance])` | No | Right of title; Lantern Gold on number; live-updating |
| Settings gear button | IconButton | Gear icon | Yes (gated) | Far right; muted when OE replay in flight |

**Zone 2 — Roster scroll**

| Component | Type | Content | Interactive | Notes |
|-----------|------|---------|-------------|-------|
| HeroCard (×N) | PanelContainer | display_name + `" • "` + class_id + level label + XP progress bar | No (MVP) | Parchment sub-panel; guild-ledger-entry visual register |
| HeroCard name/class | Label | `"display_name • class_id"` | No | Slate Ink; body font |
| HeroCard level | Label | `"Lv N"` | No | Right-aligned; Slate Ink small; secondary prominence |
| HeroCard XP bar | ProgressBar | `hero.xp / xp_threshold(hero.current_level)` | No | Slim (6px); Guild Amber fill; Parchment Cream track |
| Empty state label | Label | "No heroes yet — recruit one to begin." | No | Shown if `HeroRoster._heroes.size() == 0`; centered, secondary style |

**Zone 3 — Synergy strip (conditional)**

| Component | Type | Content | Interactive | Notes |
|-----------|------|---------|-------------|-------|
| Synergy badge | Label + icon | Active synergy name + effect e.g., "Steel Wall: +25% gold vs bruisers" | No | Only visible when `detect_active_synergy() != ""`; uses class_synergy_badge_active theme variant; reduce-motion awareness per Sprint 18 badge pattern |

**Zone 4 — NavBar**

| Component | Type | Content | Interactive | Notes |
|-----------|------|---------|-------------|-------|
| Dispatch button | Button (primary) | `tr("guild_hall_dispatch_button")` = "Dispatch" | Yes | 2/3 NavBar width; largest button on screen; Guild Amber fill; primary CTA |
| Recruit button | Button (secondary, gated) | `tr("guild_hall_recruit_button")` = "Recruit" | Yes (gated) | 1/3 NavBar width; full opacity when affordable, 40% opacity + disabled when not |

### ASCII Wireframe

Portrait orientation (1280×800 Steam Deck; portrait-capable for mobile port):

```
┌─────────────────────────────────────────────┐
│  Lantern Guild            ⬡ 450 gold    ⚙  │  ← Header (80px)
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐   │
│  │  Theron             Warrior  Lv 7  │   │
│  │  ████████░░░░░░░░░░  XP 240/350    │   │  ← HeroCard
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │  Bram               Warrior  Lv 3  │   │
│  │  ██░░░░░░░░░░░░░░░░  XP 40/120     │   │  ← Roster scroll
│  └─────────────────────────────────────┘   │     (65%, scrollable)
│  ┌─────────────────────────────────────┐   │
│  │  Yara                 Mage  Lv 2   │   │
│  │  ░░░░░░░░░░░░░░░░░░░  XP 10/80     │   │
│  └─────────────────────────────────────┘   │
│  ...                                        │
├·············································┤
│  ✦ Steel Wall — +25% gold vs bruisers       │  ← Synergy strip
│  (hidden when no synergy active)            │    (conditional 48px)
├─────────────────────────────────────────────┤
│  [          Dispatch          ]  [ Recruit ]│  ← NavBar (120px)
└─────────────────────────────────────────────┘
```

Notes:
- `⬡` = coin icon; Lantern Gold coloring on the number
- `⚙` = settings gear; small, far right
- HeroCards use parchment sub-panel (elevated from the parchment background by a slim Slate Ink border)
- Dispatch button spans ~2/3 of NavBar width; Recruit spans ~1/3
- Synergy strip uses the same visual register as the Sprint 18 Formation Assignment synergy badge (class_synergy_badge_active theme variant)
- WarmLanternOverlay + TiltShiftDof composites over the biome background BEHIND this entire UI; the parchment panels sit at z=0, visually sharp

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **Default** | Normal arrival (returning player with heroes + gold) | All zones visible; synergy strip conditional per formation; Recruit gating reflects current gold |
| **First-launch** | New game, Theron seeded, 100 starting gold | 1 HeroCard (Theron Lv1); gold shows 100; Recruit dimmed (need 50 more gold) |
| **Empty roster** | Corruption recovery edge case (should never happen in production) | RosterPanel shows empty state label: "No heroes yet — recruit one to begin." |
| **Recruit available** | `Economy._gold_balance >= cheapest_recruit_cost` | Recruit button enabled, full opacity, Lantern Gold interactive style |
| **Recruit unavailable** | `Economy._gold_balance < cheapest_recruit_cost` | Recruit button disabled, 40% opacity; tooltip shows "Need N more gold" |
| **Offline replay in flight** | `OfflineProgressionEngine.is_replay_in_flight() == true` | Settings gear disabled + dimmed; gold counter updates rapidly per replay events; rest of screen fully interactive. **No loading spinner** — the rapid counter updates ARE the replay visual feedback. Deliberate design choice per GDD #19 §C.3. |
| **Synergy active** | `FormationAssignment.detect_active_synergy() != ""` on current formation | Synergy strip expands to 48px; displays synergy display name + effect text |
| **Synergy inactive** | No formation synergy detected | Synergy strip hidden (0px height, no layout gap) |
| **Hall of Retired Heroes unlock** _(V1.0)_ | First prestige complete: `HeroRoster._retired_hero_records.size() > 0` | Hall of Retired Heroes button appears in NavBar (third button, secondary style); not visible in MVP fresh saves |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Immediate feedback | Outcome |
|-----------|--------|-------|--------------------|---------|
| Dispatch button | Tap/click | Mouse LMB or touch tap | Button press visual + `sfx_ui_tap` chime | `SceneManager.request_screen("formation_assignment", CROSS_FADE)` |
| Recruit button (enabled) | Tap/click | Mouse LMB or touch tap | Button press + `sfx_ui_tap` | `SceneManager.request_screen("recruit_screen", CROSS_FADE)` |
| Recruit button (disabled) | Tap/click | Mouse LMB or touch tap | No feedback (disabled; tooltip shows deficit on PC hover) | No-op |
| Settings gear (enabled) | Tap/click | Mouse LMB or touch tap | Icon press visual + `sfx_ui_tap` | Instantiate SettingsOverlay → `SceneManager.show_modal(overlay)` |
| Settings gear (disabled) | Tap/click | Mouse LMB or touch tap | No feedback | No-op |
| HeroCard (MVP) | — | Display only | — | No action — note: Hero Detail modal tap-through is a V1.0 addition per GDD #19 §I OQ-19-2 |
| Gold counter | — | Display only | — | No action |
| Synergy strip | — | Display only | — | No action |

**Unspecced navigation targets** (spec dependencies):
- `design/ux/formation-assignment.md` — does not exist; needed before Formation Assignment implementation
- `design/ux/recruit-screen.md` — does not exist; needed before Recruit Screen implementation

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Tap Dispatch | `ui_dispatch_tapped` | `{ screen: "guild_hall" }` |
| Tap Recruit (enabled) | `ui_recruit_tapped` | `{ screen: "guild_hall", gold_balance: int }` |
| Tap Settings gear (enabled) | `ui_settings_opened` | `{ screen: "guild_hall" }` |
| Recruit button disabled (no tap fired) | None | — |
| Settings gear disabled (no tap fired) | None | — |

**Persistent state writes on this screen**: None — Guild Hall is read-only. All navigation actions delegate state changes to destination screens.

---

## Transitions & Animations

**Screen enter**: 150ms cross-fade from the source screen (Main Menu, Dungeon Run View, or back-navigation). No special entry animation beyond the standard cross-fade per ADR-0007 transition contract. No "welcome back" fanfare — the cozy register sets the tone through content, not ceremony.

**Screen exit**: 150ms cross-fade to Dispatch destination (Formation Assignment) or Recruit Screen. Settings uses show_modal (no screen-level transition; the overlay fades in over the Guild Hall).

**Gold counter update**: Counter updates on every `gold_changed` signal during offline replay. Rapid number-ticking is the feedback that the replay is running. No special animation needed — the numbers moving fast IS the visual. No throttle on the visual update.

**Synergy strip appear/disappear**: When synergy becomes active (formation changes while player is on-screen — unlikely from Guild Hall itself, but possible via on_resume after returning from Formation Assignment), the synergy strip slides in from below with a 150ms ease. When it disappears, 150ms fade out. Per Art Bible §7 animation budget ≤150ms for UI transitions. Reduce-motion: instant show/hide at full alpha.

**HeroCard XP bar fill**: Updates instantly on `hero_leveled` signal. No animated fill (not a reward moment — reward moment is Victory Moment screen).

---

## Data Requirements

| Data | Source system | Read / Write | Live-updating? | Notes |
|------|--------------|--------------|----------------|-------|
| Gold balance | Economy autoload | Read | Yes — `gold_changed` signal | Counter updates per event during replay |
| Hero roster | HeroRoster autoload | Read | Yes — `hero_recruited`, `hero_removed`, `hero_leveled` signals | Roster re-renders on each signal |
| Hero XP + level | HeroRoster per-hero fields | Read | Yes — `hero_leveled` | XP bar fill updates immediately |
| Cheapest recruit cost | Recruitment autoload | Read | Yes — `pool_refreshed` signal | Drives Recruit button gating |
| Active formation synergy | FormationAssignment autoload | Read | No (static on arrival; may update on on_resume) | Drives synergy strip visibility |
| Replay in-flight state | OfflineProgressionEngine | Read | Signal (not yet declared — OQ-19-1) | Drives Settings gear gating |

**No write paths on this screen.** Guild Hall is display-only. All mutations happen in destination screens.

---

## Accessibility

**Committed tier**: WCAG-AA per Art Bible §4 colorblind backup cues.

| Requirement | Implementation |
|-------------|---------------|
| Touch tap targets ≥44×44 logical pixels | Dispatch button: full-width × ~80px. Recruit button: ~1/3 width × ~80px. Settings gear: minimum 44×44. All meet the requirement per technical-preferences.md. |
| No information conveyed by color alone | Recruit button disabled state: 40% opacity + `disabled = true` + tooltip showing deficit (three independent signals — not just color dimming). Settings gear disabled: opacity + tooltip. Synergy strip: text label carries the synergy name, not just a colored badge. |
| Colorblind backup cues (Art Bible §4) | Guild Amber (interactive) vs Parchment Cream (inactive): uses the 1px Slate Ink outline backup cue. Synergy badge: displays text name + effect, not just a colored flash. |
| Reduce-motion | Synergy strip show/hide: instant at full alpha (no slide animation). Gold counter rapid-tick: no special animation anyway. Screen transitions: cross-fade is preserved (it is not motion-sickness-inducing at 150ms); no change under reduce-motion. |
| Font size floor | Body text (HeroCard labels, gold counter, button labels): minimum 16px logical per Art Bible §7. Gold counter number: Lantern Gold, ≥20px. Title: ≥24px (identity font per art bible floor). |
| No hover-only interactions | Recruit button disabled tooltip: available via long-press on touch. No information is exclusively hover-gated. |
| Keyboard navigation | No keyboard navigation required (game is mouse/touch primary; keyboard is shortcuts-only per technical-preferences.md). `suppress_keyboard_focus` called on all Controls per UIFramework pattern. |
| Input remapping (Standard tier commit) | Handled at Steam platform layer via Steam Input — no in-game remap UI needed. Steam Input covers all mouse button bindings. Per accessibility-requirements.md §Motor Accessibility. |
| Text contrast verification | Slate Ink on Parchment Cream must verify ≥4.5:1 WCAG AA before visual design handoff. Not yet measured (accessibility-requirements.md §Visual Accessibility row: Not Started). Flag for visual-design phase. |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| Dispatch button label (`guild_hall_dispatch_button`) | ~12 chars ("Dispatch" = 8) | LOW | Button is 2/3 NavBar width; up to ~18 chars before needing font-size reduction |
| Recruit button label (`guild_hall_recruit_button`) | ~10 chars ("Recruit" = 7) | LOW | 1/3 NavBar; German "Rekrutieren" = 11 chars, marginally tight |
| Gold format (`guild_hall_gold_format`) | ~15 chars | LOW | Numeric; "450 gold" = 8 chars including formatting; number length is the variable |
| Recruit tooltip (`guild_hall_recruit_tooltip_insufficient_format`) | ~40 chars | MEDIUM | "Need 50 more gold" = 18 chars English; German/French may expand 50-70%. Tooltip is overflow-safe (Label autowrap). |
| HeroCard name | Variable (player-set display_name) | LOW | Name is player-authored; no locale dependency |
| Synergy display name (`class_synergy_badge_*` locale keys) | ~20 chars | LOW | "Steel Wall" = 10 chars; effect "→ +25% gold vs bruisers" = 24 chars. Single line; badge can accept 2 lines if needed. |

**HIGH PRIORITY for loc review**: The Recruit button label in languages with long verbs (German, Hungarian) — test at 140% text expansion in the 1/3 NavBar slot before loc ship.

---

## Acceptance Criteria

- [ ] **UX-GH-01 (layout)**: All four zones are visible without scrolling on 1280×800 (Steam Deck native). Header, roster (first 2 cards), synergy strip (when active), and NavBar all render within the visible viewport.
- [ ] **UX-GH-02 (gold)**: The gold counter displays the correct value from `Economy._gold_balance` within one frame of arriving on screen. Format: coin icon + number + "gold" per locale key.
- [ ] **UX-GH-03 (live gold)**: When `Economy.gold_changed` fires during offline replay, the gold counter visually updates to the new value within one frame. Rapid-fire updates (replay) do not crash or stutter the counter display.
- [ ] **UX-GH-04 (roster)**: The roster panel shows one HeroCard per hero in `HeroRoster._heroes`. Each card displays display_name, class_id, current_level, and a correctly-filled XP progress bar (`xp / xp_threshold(level)`).
- [ ] **UX-GH-05 (dispatch)**: Tapping the Dispatch button navigates to Formation Assignment via cross-fade in ≤200ms wall-clock time. The button is always enabled (never gated in MVP).
- [ ] **UX-GH-06 (recruit gating)**: The Recruit button is enabled (full opacity, tappable) when `gold >= cheapest_recruit_cost` and disabled (40% opacity, no-op on tap) when not. The gating updates within one frame of any `gold_changed` or `pool_refreshed` event.
- [ ] **UX-GH-07 (recruit nav)**: Tapping the Recruit button while enabled navigates to Recruit Screen via cross-fade in ≤200ms.
- [ ] **UX-GH-08 (settings gear gating)**: The Settings gear is disabled (dimmed, no-op on tap) during `OfflineProgressionEngine.is_replay_in_flight() == true`. It re-enables immediately when replay ends.
- [ ] **UX-GH-09 (synergy strip)**: When the current formation has an active synergy, the synergy strip is visible (48px) and displays the correct synergy display name + effect text. When no synergy is active, the strip is hidden (0px, no layout gap).
- [ ] **UX-GH-10 (tap targets)**: All interactive elements (Dispatch, Recruit, Settings gear) have touch tap targets ≥44×44 logical pixels, verified by UIFramework tap-target assertion.
- [ ] **UX-GH-11 (empty roster)**: If `HeroRoster._heroes.size() == 0`, the roster zone displays the empty-state label "No heroes yet — recruit one to begin." instead of HeroCards.
- [ ] **UX-GH-12 (first-launch state)**: On a fresh save (Theron seeded, 100 gold), the screen shows exactly 1 HeroCard (Theron, Warrior, Lv1), gold counter shows 100, and the Recruit button is disabled (need 50 more gold).
- [ ] **UX-GH-13 (accessibility — colorblind)**: No information on this screen is conveyed by color alone. Disabled states use opacity AND `disabled=true` property AND tooltip text. Synergy strip uses text label, not color only.
- [ ] **UX-GH-14 (signal cleanup)**: After `on_exit`, all signals connected in `on_enter` (`gold_changed`, `hero_recruited`, `hero_removed`, `hero_leveled`, `pool_refreshed`) report `is_connected == false`.
- [ ] **UX-GH-15 (settings modal open)**: Tapping the Settings gear while enabled instantiates the SettingsOverlay and calls `SceneManager.show_modal(overlay)`. The Guild Hall remains visible underneath the modal (no scene unload). Covers GDD #19 AC-19-11.
- [ ] **UX-GH-16 (locale keys complete)**: All 8 Guild Hall locale keys exist in `assets/locale/en.csv` with non-empty values: `guild_hall_title`, `guild_hall_gold_format`, `guild_hall_dispatch_button`, `guild_hall_recruit_button`, `guild_hall_recruit_tooltip_insufficient_format`, `guild_hall_settings_tooltip_replay_in_flight`, `guild_hall_hero_card_format`, `guild_hall_hero_card_xp_format`. Covers GDD #19 AC-19-15.
- [ ] **UX-GH-17 (tap feedback)**: Tapping Dispatch, Recruit (enabled), or Settings gear (enabled) fires the `sfx_ui_tap` audio chime AND produces a visual press animation within 16ms (1 frame at 60fps) of the input event. Covers GDD #19 AC-19-14.

---

## Open Questions

- **OQ-GH-01**: No player journey map exists at `design/player-journey.md`. The arrival-context table in §B is based on reasoning from the game concept + GDD; a formal journey map may surface additional arrival contexts or refine the emotional state descriptions. Low priority for MVP.
- **OQ-GH-02**: HeroCard interactivity — GDD #19 OQ-19-2 flags Hero Detail modal tap-through as a V1.0 addition. When this lands, the HeroCard component needs an interaction-map entry + `ui_hero_card_tapped` event + the hero_detail_modal UX spec as a navigation dependency.
- **OQ-GH-03**: Gold abbreviation for late-game values (OQ-19-3 from GDD) — 9-digit balances will overflow the header counter. Sprint 15+ candidate for K/M/B shortening.
- **OQ-GH-04**: `OfflineProgressionEngine.replay_in_flight_changed` signal not yet declared (GDD OQ-19-1) — Settings gear gating currently relies on polling via `is_replay_in_flight()` rather than a reactive signal. The spec assumes the signal exists; if it doesn't land before Guild Hall implementation, the gear gating must use a polling approach (e.g., re-check on every `gold_changed`).
- **OQ-GH-05**: No visual design system (DESIGN.md) authored yet — typography scale, spacing system, and component vocabulary for parchment panels, button radii, and icon sizes are informally derived from the art bible here. A DESIGN.md authoring pass would lock these values precisely and ensure consistency across all 8 screens. Recommend `/design-consultation` before full Guild Hall implementation begins.
- **OQ-GH-06**: Formation Assignment + Recruit Screen UX specs do not exist. These are spec dependencies for the exit navigation. Run `/ux-design formation-assignment` and `/ux-design recruit-screen` before or concurrently with Guild Hall implementation.
- **OQ-GH-07**: Two visual patterns are introduced by description in this spec but are not yet entries in `design/ux/interaction-patterns.md`: (a) **Guild-ledger-entry** — the parchment sub-panel register used by HeroCards (slate-ink border on parchment cream ground, ledger-row layout); (b) **Conditional Strip** — the synergy strip's "zero height when inactive, 48px when active" appearance pattern (also applies to other future conditional reveal strips). Add both to the pattern library after this spec is approved so subsequent screens can reference them by name.
