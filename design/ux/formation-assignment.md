# UX Spec: Formation Assignment

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-14
> **Journey Phase(s)**: Pre-dispatch decision / Mid-run reassignment (rare, gated)
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/formation-assignment-system.md` (controller); existing scene already shipped per Sprint 8 Story 011
> **Template**: UX Spec

---

## Purpose & Player Need

Formation Assignment is the tactical decision screen — where the player chooses **which three heroes go on a dungeon run, against which floor**. The player taps Dispatch from Guild Hall, lands here, considers the lineup, optionally swaps heroes, and either dispatches or cancels back.

**Player goal on arrival**: *"Show me my heroes, show me where I'm dispatching, let me confirm or change my mind, get me back to the game."*

The screen serves two distinct intents:

1. **Pre-dispatch (primary)** — Player arrived from Guild Hall with intent to send a run. The current formation may need adjustment based on the floor's enemy composition. Friction here costs almost nothing because the player is here on purpose.
2. **Mid-run reassignment (rare, gated)** — Player is in an active dispatched run and opens this screen to change the formation. Per ADR-0001 option (a), committing a new formation **ends the current run and restarts with the new lineup**. A confirmation dialog prevents accidental restarts. The cozy-register guardrail per Pillar 1.

The screen must answer: *"Who is in my formation right now? Which heroes are available to swap in? What floor am I dispatching to? Are these heroes a good matchup? Is there a synergy active?"* — all before any tap.

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **Pre-dispatch (Guild Hall → Dispatch tap)** | Just tapped Dispatch from Guild Hall | Decision-mode, mildly anticipatory ("let's go") | Formation should already be loaded with last-used lineup; Dispatch button immediately available |
| **Pre-dispatch (Recruit → back nav)** | Just recruited a hero; wants to add them to formation | Curious / experimental — wants to try the new hero | Roster list highlights newly-recruited hero subtly (visual freshness signal) |
| **Mid-run reassignment (Pause overlay → Formation)** | Active run in progress; opened formation deliberately to change lineup | Considered / cautious — they know commit ends the run | Mid-run confirmation modal MUST gate the commit; cancellation must feel safe |
| **Browse-only (deliberate inspection)** | Just wants to look at the formation; no commit intent | Curious / non-committal | Browse signal fires automatically; no UI penalty for not committing |

The screen should never make the player feel like they're being graded. Formation choice is not a numeric-optimization puzzle (per Formation System GDD §B.3). The player should feel: "these are my heroes; this is where I'm sending them; that feels right."

---

## Navigation Position

Formation Assignment is a **first-level child** of Guild Hall — one tap away from the hub, primarily reached via the Dispatch CTA. It also has a back-nav from the in-run pause overlay for mid-run reassignment.

```
Guild Hall (root hub)
  └── Formation Assignment  ← THIS SCREEN
        ├── (commit) → Dungeon Run View (or run-restart loop)
        └── (back) → Guild Hall (no commit, browse signal fired)

In-run pause overlay
  └── Formation Assignment (mid-run reassignment, ADR-0001 gated path)
```

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings | Mid-run? |
|-------|--------|--------------------|----------|
| Pre-dispatch nav | Guild Hall (Dispatch button) | Last-used formation; current biome+floor unlock state | No |
| Mid-run nav | In-run pause overlay (Formation option) | Active run snapshot; current floor (locked); active formation | Yes — ADR-0001 confirm gate applies |
| Back nav (no change) | Implicit — player taps Back without committing | Browse signal fired; no state change | n/a |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Dispatch (commit) | Tap Dispatch button → confirm flow if mid-run | Pre-dispatch: routes to Dungeon Run View. Mid-run: ends current run + restarts. |
| Back (no commit) | Tap Back button | Routes to source (Guild Hall in 99% of cases). No formation write. `formation_browse_opened` fired on entry — that's the only signal this path produced. |
| Cancel mid-run confirm | Tap Cancel in confirmation modal | Stays on Formation Assignment; modal dismisses; no commit. |

---

## Layout Specification

### Information Hierarchy

Ranked by player decision importance:

1. **Current formation (3 slots)** — what the player is about to dispatch with; the most touched zone on screen
2. **Floor selector context** — where the dispatch is going (biome + floor); drives matchup decisions
3. **Dispatch button** — the primary CTA; commits the lineup
4. **Hero roster (available pool)** — heroes the player can swap into slots
5. **Synergy badge** — informational; tells the player their formation has a bonus active
6. **Back button** — secondary navigation; never the primary action
7. **Confirmation modal** — only appears mid-run; gates the commit

### Layout Zones

Six conceptual zones; the existing scene tree (shipped per Sprint 8 Story 011) already matches:

| Zone | Role | Approximate area |
|------|------|------------------|
| Header bar | Title + Back button | Top ~8% / ~64px |
| Roster panel | Scrollable list of available heroes | Left or upper-center, ~40% area |
| Formation panel | 3 slot buttons in a horizontal row | Center, ~25% area, anchored prominently |
| Floor selector | Current biome+floor context + advance button | Right of formation or below, ~12% area |
| Action bar | Dispatch button (primary CTA) | Bottom, ~12% / ~96px tall |
| Modal layer | Mid-run reassignment confirmation (conditional) | Full-screen overlay when active |

Below: ASCII wireframe shows the canonical Steam Deck portrait composition.

### Component Inventory

**Zone 1 — Header bar**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| BackButton | Button | `tr("formation_assignment_back_button")` ("←" + "Back") | Yes | `button` variant `secondary`, 44×44 min |
| HeaderLabel | Label | `tr("formation_assignment_title")` ("Choose Your Formation") | No | `title-section` — IM Fell English 24px |

**Zone 2 — Roster panel**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| RosterPanel | PanelContainer | Scrollable list container | No | `panel` variant `parchment-default` |
| RosterScroll | ScrollContainer | Vertical scroll wrapper | Touch-scrollable | n/a |
| RosterList | VBoxContainer | Layout for HeroSlotRow cells | No | `sm` (8px) gap |
| HeroSlotRow (×N) | PanelContainer | display_name + class icon + level + "in formation" badge if assigned | Yes — tap to assign to selected slot | `panel` variant `ledger-row` |

**Zone 3 — Formation panel**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| FormationPanel | PanelContainer | Container with 3 slot buttons | No | `panel` variant `parchment-default` |
| SlotsHBox | HBoxContainer | 3 horizontal slot containers | No | `md` (16px) gap between slots |
| Slot0Button / Slot1Button / Slot2Button | Button | Each shows: hero portrait/icon + name + level OR "Empty Slot" placeholder | Yes — tap to select (slot becomes target for next HeroSlotRow tap) | Special button variant: `slot` — large square (~120×120), `radius-panel` (6px), parchment fill, slate ink border |

**Zone 4 — Floor selector**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| FloorSelectorPanel | PanelContainer | Container | No | `panel` variant `parchment-default` |
| FloorContextLabel | Label | `tr("formation_assignment_floor_context_format", [biome_display_name, floor_index])` ("Forest Reach · Floor 3") | No | `body-emphasis` — Lora SemiBold 16px |
| FloorButton | Button | `tr("formation_assignment_change_floor_button")` ("Change Floor") | Yes (gated to unlocked floors) | `button` variant `secondary` |

**Zone 5 — Action bar**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| DispatchButton | Button | `tr("formation_assignment_dispatch_button")` ("Dispatch") | Yes (gated: needs ≥1 hero in formation) | `button` variant `primary` — Guild Amber fill, 80px tall, Lora SemiBold 18px label |
| ToastLabel | Label | Transient feedback ("Hero added to slot 1", etc.); auto-dismiss | No | `body` — auto-hides after 1.5s |
| SynergyBadge | Label | "Steel Wall · +25% gold vs bruisers" — only visible when synergy active | No | `chip` style: small panel with `radius-chip` (2px), Guild Amber accent on Parchment Cream |

**Zone 6 — Modal layer (conditional)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| MidRunReassignConfirmation | Control | Container; visible only when mid-run + commit attempted | No (the modal layer itself) | n/a |
| ConfirmDimBackdrop | ColorRect | 70% opacity Slate Ink overlay | No (consumes taps outside ConfirmPanel) | `Color(Slate Ink, alpha=0.7)` |
| ConfirmPanel | PanelContainer | The actual dialog | No | `panel` variant `modal` |
| ConfirmBodyLabel | Label | "Changing your formation will end this run and restart with the new lineup. Continue?" | No | `body` — Lora Regular 16px |
| CancelButton | Button | "Keep Current Run" | Yes | `button` variant `secondary` |
| ConfirmButton | Button | "Restart with New Formation" | Yes | `button` variant `primary` (but with `ember-rust` accent to signal consequence — not just gold) |

### ASCII Wireframe

Portrait orientation (1280×800 Steam Deck reference; portrait-capable for mobile port):

```
┌─────────────────────────────────────────────┐
│ [← Back]   Choose Your Formation            │  ← Header (64px)
├─────────────────────────────────────────────┤
│ ┌──────────────┐  ┌─────────────────────┐  │
│ │              │  │  ┌─────┐┌─────┐┌──┐ │  │
│ │  Theron      │  │  │     ││     ││  │ │  │
│ │  Warrior Lv7 │  │  │Ther.││ Bram││Y.│ │  │
│ │  ✓ in slot 0 │  │  │ Lv7 ││ Lv3 ││L2│ │  │
│ │              │  │  └─────┘└─────┘└──┘ │  │
│ │  Bram        │  │   slot0  slot1 slot2│  │  ← Formation
│ │  Warrior Lv3 │  │                     │  │     panel
│ │  ✓ in slot 1 │  │  Formation Panel    │  │
│ │              │  └─────────────────────┘  │
│ │  Yara        │                            │
│ │  Mage Lv2    │  ┌─────────────────────┐  │
│ │              │  │ Forest Reach · F3   │  │  ← Floor
│ │  TestHero    │  │ [ Change Floor ]    │  │     selector
│ │  Mage Lv1    │  └─────────────────────┘  │
│ │              │                            │
│ │  ...         │  ✦ Steel Wall · +25% gold  │  ← Synergy
│ │              │     vs bruisers            │     (cond.)
│ │  Roster scroll                            │
│ └──────────────┘                            │
├─────────────────────────────────────────────┤
│           [      DISPATCH      ]            │  ← Action bar
└─────────────────────────────────────────────┘
                                                  (96px)
```

Notes:
- Roster list spans roughly left ~40%, formation+context+synergy spans right ~60%
- Slot buttons in `SlotsHBox` are equal-width squares (~110-130px) with `md` (16px) gap
- Synergy badge sits BELOW the floor selector, ABOVE the action bar — visible only when active
- ToastLabel overlays the formation panel at small font; auto-dismisses
- Mid-run confirmation modal overlays everything when active (Zone 6 only visible mid-run)

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **Default — pre-dispatch** | Normal arrival from Guild Hall | All zones visible; formation pre-filled with last-used lineup; Dispatch button enabled if ≥1 hero in formation |
| **Empty formation (rare)** | Player explicitly removed all heroes from slots OR fresh save with no heroes assigned | All 3 slots show "Empty Slot" placeholder; Dispatch button **disabled** with tooltip "Add at least one hero" |
| **Mid-run state** | Arrived from pause overlay during active run | Header subtitle adds " · Reassignment will end current run"; floor selector locked to current floor (cannot change mid-run); synergy badge respects mid-run formation |
| **Slot selected** | Player tapped a slot button (no hero yet OR existing hero) | Selected slot border highlighted (Guild Amber accent); subsequent HeroSlotRow tap fills the selected slot |
| **Hero selected from roster** | Player tapped a HeroSlotRow | Brief visual feedback; if a slot is already selected, hero moves to that slot; if not, the hero's current slot (if any) is highlighted |
| **Hero swap** | Player taps a hero in a slot, then taps a hero in roster | Roster hero moves to slot; previous slot hero returns to roster (or to its prior slot if duplicate) |
| **Synergy active** | `FormationAssignment.detect_active_synergy()` returns non-empty | SynergyBadge visible with synergy name + effect text per Sprint 18 spec |
| **Synergy inactive** | No synergy detected | SynergyBadge hidden (0px height, no layout gap) |
| **Recruit-fresh roster row** | Just-recruited hero in roster panel | HeroSlotRow has a subtle visual freshness signal (e.g., 1px Lantern Gold border for first 5 seconds OR until first interaction) |
| **Floor selector locked (mid-run)** | Mid-run state | FloorButton disabled, dimmed; tooltip "Floor locked during active run" |
| **Confirmation modal — mid-run** | Player tapped Dispatch during mid-run, formation has changed from active | ConfirmDimBackdrop + ConfirmPanel visible; backdrop consumes outside-taps; modal stays until Cancel/Confirm |
| **Toast feedback** | Slot fill / swap / removal action | ToastLabel appears with action confirmation; auto-dismisses after 1500ms with fade-out |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Immediate feedback | Outcome |
|-----------|--------|-------|--------------------|---------|
| BackButton | Tap | Mouse LMB / touch | `sfx_ui_tap` + press visual | `SceneManager.request_screen("guild_hall", CROSS_FADE)`; `FormationAssignment.browse(formation)` fires (informational) |
| SlotN Button (empty) | Tap | Mouse LMB / touch | `sfx_ui_tap` + slot border highlight (Guild Amber) | Slot becomes selected target for next HeroSlotRow tap |
| SlotN Button (occupied) | Tap | Mouse LMB / touch | `sfx_ui_tap` + slot border highlight | Slot selected; tap a HeroSlotRow to swap; tap the same slot again to clear it |
| HeroSlotRow (in formation) | Tap | Mouse LMB / touch | `sfx_ui_tap` + brief row highlight | If a slot is selected: row's hero moves to selected slot. If not: prompts "Select a slot first" toast OR highlights the hero's current slot. |
| HeroSlotRow (not in formation) | Tap | Mouse LMB / touch | `sfx_ui_tap` + brief row highlight | If a slot is selected: hero fills that slot. If not: prompts user to select a slot. |
| FloorButton | Tap | Mouse LMB / touch | `sfx_ui_tap` + press | Opens floor-select sub-flow (TBD — separate UX spec or inline expansion) |
| DispatchButton (pre-dispatch) | Tap | Mouse LMB / touch | `sfx_ui_tap` + button-fill brighten | `FormationAssignment.commit(formation)` fires; routes to DungeonRunView |
| DispatchButton (mid-run, formation changed) | Tap | Mouse LMB / touch | `sfx_ui_tap` | Shows mid-run confirmation modal (no commit yet) |
| DispatchButton (mid-run, formation unchanged) | Tap | Mouse LMB / touch | `sfx_ui_tap` | Cancels reassignment path; routes back to active run view; no commit signal fired |
| CancelButton (in modal) | Tap | Mouse LMB / touch | `sfx_ui_tap` | Modal dismisses; player stays on Formation Assignment with current edits intact |
| ConfirmButton (in modal) | Tap | Mouse LMB / touch | `sfx_ui_tap` + brief modal exit animation | `FormationAssignment.commit()` fires; Orchestrator ends current run + restarts with new formation per ADR-0001 |
| ConfirmDimBackdrop | Tap | Mouse LMB / touch | No feedback (intentional — dim consumes taps to prevent accidental modal-bypass) | Toast: "Use the buttons to confirm or cancel" |
| SynergyBadge | — | Display only | — | No action |
| ToastLabel | — | Display only | — | No action |

**Single-finger tap design** (no drag-and-drop): formation editing uses a two-tap pattern — tap a slot, then tap a hero — rather than dragging. This keeps the interaction touch-parity-compliant and avoids drag-precision issues per ADR-0008. The tap-tap flow is also accessibility-friendly.

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Screen open | `formation_browse_opened` | `{ formation: Array[HeroInstance] }` |
| Hero assigned to slot | `ui_formation_slot_assigned` | `{ slot_index, instance_id }` |
| Hero removed from slot | `ui_formation_slot_cleared` | `{ slot_index, instance_id }` |
| Floor changed | `ui_floor_selector_changed` | `{ biome_id, floor_index_old, floor_index_new }` |
| Dispatch tapped (pre-dispatch) | `ui_dispatch_committed` | `{ formation: Array[HeroInstance], biome_id, floor_index }` |
| Dispatch tapped (mid-run, modal shown) | `ui_mid_run_reassign_prompted` | `{ formation: Array[HeroInstance] }` |
| Mid-run modal Confirm | `formation_reassignment_committed` (from FormationAssignment autoload) | `{ new_formation: Array[HeroInstance] }` |
| Mid-run modal Cancel | `ui_mid_run_reassign_cancelled` | `{ }` |
| Back tapped | None (browse_opened already fired on entry) | — |

**Persistent state writes** during this screen:
- `HeroRoster._formation_slots` via `FormationAssignment.commit()` — only on confirm button press
- No other persistent state writes; all formation editing UI is local until commit

---

## Transitions & Animations

**Screen enter**: 150ms cross-fade from Guild Hall or pause overlay. No special entrance.

**Screen exit**: 150ms cross-fade to destination (Dungeon Run View on dispatch, Guild Hall on back, pause overlay on mid-run cancel).

**Slot selection highlight**: when a slot is tapped, its border animates from Slate Ink (default) to Guild Amber over 80ms. Deselects on any other slot tap, any HeroSlotRow tap (that fills the slot), or Dispatch press.

**Hero-to-slot fill animation**: when a hero fills a slot, the slot's content (icon + name + level) appears via 150ms fade-in + 50ms `bounce` overshoot (per DESIGN.md motion easing — "book settling on table" feel).

**Slot clear animation**: when a slot empties, content fades out over 150ms; placeholder text appears via 50ms cross-fade.

**Toast appear/dismiss**: 150ms slide-up from below the action bar + 1500ms hold + 150ms fade-out. Reduce-motion: instant appear at full alpha, instant disappear.

**Synergy badge appear/disappear**: same pattern as Guild Hall — 150ms slide-in from below, 150ms fade-out. Reduce-motion: instant.

**Mid-run modal appear**: ConfirmDimBackdrop fades from 0 → 70% opacity over 200ms. ConfirmPanel scales from 0.95× → 1.0× over 200ms `enter` easing simultaneously. Reduce-motion: both at full opacity/scale immediately.

**Mid-run modal dismiss (cancel)**: backdrop fades out over 150ms; panel scales to 0.95× over 150ms with `exit` easing.

**Mid-run modal dismiss (confirm)**: 150ms fade-out, then 150ms cross-fade to Dungeon Run View as the run restarts.

---

## Data Requirements

| Data | Source system | Read / Write | Live-updating? | Notes |
|------|--------------|--------------|----------------|-------|
| Hero roster (full list) | HeroRoster autoload | Read | Yes — `hero_recruited`, `hero_removed`, `hero_leveled` signals | Re-renders RosterList on each signal |
| Current formation slots | HeroRoster.get_formation_heroes() | Read | Yes — internal scratch state during editing; commit writes back | Local working copy during editing; flush on commit |
| Hero details (display_name, class_id, current_level, xp) | HeroRoster per-hero | Read | Yes — `hero_leveled` | Each HeroSlotRow re-renders on hero_leveled |
| Active biome | FloorUnlock.get_active_biome_id() | Read | Yes — `current_biome_changed` | Drives FloorContextLabel |
| Current floor | FloorUnlock.get_active_floor_index() OR run_snapshot during mid-run | Read | Yes — `floor_unlocked` signal | Drives FloorContextLabel + Dispatch destination |
| Unlocked floors | FloorUnlock.get_unlocked_floors(biome_id) | Read | Yes — `floor_unlocked` | Gates FloorButton selection |
| Active synergy | FormationAssignment.detect_active_synergy(formation) | Read | Computed; re-evaluated on every slot change | Drives SynergyBadge visibility |
| Orchestrator state | DungeonRunOrchestrator.get_state() | Read | Yes — `state_changed` | Determines pre-dispatch vs mid-run UI variant + gates floor selector |

**Write paths** (only on user confirm):
- `HeroRoster._formation_slots` via `FormationAssignment.commit()` — single writer per Hero Roster Rule 10

---

## Accessibility

**Committed tier**: Standard per `design/accessibility-requirements.md`.

| Requirement | Implementation |
|-------------|---------------|
| Touch tap targets ≥44×44 logical pixels | Slot buttons: 120×120. BackButton, FloorButton, DispatchButton, CancelButton, ConfirmButton: ≥44 minimum. HeroSlotRow: ≥56px tall (16px padding + 24px content + 16px padding) |
| No color-only indicators | Slot "selected" state: border color change + border weight increase (2px → 4px). HeroSlotRow "in formation" badge: text "in slot N" label, not just an icon color. Dispatch button disabled: 40% opacity + `disabled = true` + tooltip explaining why |
| Reduce-motion | All highlight transitions, fade-ins, scale animations skip to end-state at full alpha. Toast: instant appear and dismiss. Mid-run modal: instant appear/dismiss at full alpha. Slot selection highlight: color swap is instant. |
| Colorblind backup cues | Guild Amber slot border (selected) vs Slate Ink (default): backup is the border-weight change (2px → 4px). No color-only matchup signals on this screen — matchup info lives in Matchup Assignment screen, not here. |
| Text contrast | Lora 16px Slate Ink on Parchment Cream: must verify ≥4.5:1 WCAG AA before visual handoff (flagged in accessibility-requirements.md as Not Started). |
| Mid-run reassignment guardrail | Confirmation modal is non-skippable (no "don't show again" option in MVP). The cozy register requires that a mid-run action with consequences must be explicit every time. |
| Mouse + touch parity | All actions work via single-tap. No drag, no hover, no right-click. Two-tap formation edit pattern works identically with mouse and touch. |
| Input remapping (Standard tier) | Handled at Steam platform layer via Steam Input. No in-game remap UI. |
| Font size floor | All Lora body text ≥16px; identity font ≥24px. Per Art Bible §7 + DESIGN.md type scale. |
| Keyboard navigation | Not required (game is mouse/touch primary). `suppress_keyboard_focus` called on all Controls per UIFramework pattern. |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| BackButton label (`formation_assignment_back_button`) | ~10 chars ("Back" = 4) | LOW | Most languages fit easily |
| HeaderLabel (`formation_assignment_title`) | ~30 chars ("Choose Your Formation" = 21) | LOW | Header is wide; tolerates 40% expansion |
| FloorContext (`formation_assignment_floor_context_format`) | ~30 chars ("Forest Reach · Floor 3" = 22) | MEDIUM | Biome names + ordinals; German "Schlüsselwald · Stockwerk 3" = 28; tight |
| DispatchButton label (`formation_assignment_dispatch_button`) | ~12 chars ("Dispatch" = 8) | LOW | Wide CTA button (`primary` variant ~80px tall, full-width); accommodates 14+ chars |
| Slot placeholder (`formation_assignment_empty_slot_label`) | ~12 chars ("Empty Slot" = 10) | LOW | Slot button is 120px wide |
| Synergy badge text (`class_synergy_badge_*_format`) | ~30 chars | MEDIUM | Synergy name + effect; risk on long-display-name languages — flag tight layouts |
| Confirm body (`formation_assignment_mid_run_confirm_body`) | ~80 chars (mid-run warning sentence) | LOW | Modal panel wraps to 2 lines comfortably |
| Confirm button labels | ~25 chars each | MEDIUM | "Restart with New Formation" = 26 chars; German equivalent could hit 35 — button width or 2-line allowance |

**HIGH PRIORITY for loc review**:
- FloorContext format string — biome names + "Floor N" ordinal can swell in German/Hungarian; test at 140% before loc ship
- ConfirmButton labels — keep these as short as possible without losing meaning ("Restart" + " New Formation" implicit?)

---

## Acceptance Criteria

- [ ] **UX-FA-01 (layout)**: All zones visible without scrolling on 1280×800 (Steam Deck native) in default state. Roster panel is scrollable for rosters >5 heroes.
- [ ] **UX-FA-02 (formation pre-fill)**: On screen open, the 3 slot buttons display the player's current `HeroRoster.get_formation_heroes()` content with hero portrait/icon + name + level.
- [ ] **UX-FA-03 (browse signal)**: On screen open, `FormationAssignment.browse(formation)` is called; the autoload emits `formation_browse_opened` with the current formation as payload.
- [ ] **UX-FA-04 (browse no-op)**: Opening the screen and tapping Back without changing slots produces zero writes to `HeroRoster._formation_slots`. Orchestrator state (if active) is unaffected. Cozy register Pillar 1 commitment.
- [ ] **UX-FA-05 (slot select)**: Tapping a slot button highlights its border (color change + width increase) within one frame. Tapping a different slot moves the highlight.
- [ ] **UX-FA-06 (hero assign)**: With slot N selected, tapping a HeroSlotRow assigns that hero to slot N. The slot now displays the hero's icon + name + level. If the hero was previously in slot M, slot M empties.
- [ ] **UX-FA-07 (slot clear)**: Tapping an occupied slot twice (select then re-tap same slot) clears it; the hero returns to the roster list.
- [ ] **UX-FA-08 (dispatch — happy path)**: With ≥1 hero in formation and pre-dispatch state, tapping Dispatch calls `FormationAssignment.commit(formation)` and routes to Dungeon Run View via cross-fade in ≤200ms.
- [ ] **UX-FA-09 (dispatch — empty formation)**: With 0 heroes in formation, Dispatch button is disabled (40% opacity + tooltip "Add at least one hero").
- [ ] **UX-FA-10 (mid-run confirm — appears)**: When state is `ACTIVE_FOREGROUND` and formation has changed from active, tapping Dispatch shows the confirmation modal (ConfirmDimBackdrop visible at 70% alpha; ConfirmPanel visible).
- [ ] **UX-FA-11 (mid-run confirm — cancel)**: Tapping CancelButton dismisses the modal; player remains on Formation Assignment with their edits intact; no commit signal fired.
- [ ] **UX-FA-12 (mid-run confirm — confirm)**: Tapping ConfirmButton calls `FormationAssignment.commit(formation)`; Orchestrator ends current run + restarts with new formation per ADR-0001 option (a).
- [ ] **UX-FA-13 (mid-run dim consumes taps)**: Tapping ConfirmDimBackdrop (outside the ConfirmPanel) does NOT dismiss the modal. Optional: shows toast "Use the buttons to confirm or cancel."
- [ ] **UX-FA-14 (synergy badge — visible)**: When the current edited formation has an active synergy (`detect_active_synergy` returns non-empty), SynergyBadge displays the synergy name + effect text.
- [ ] **UX-FA-15 (synergy badge — re-evaluates on edit)**: When the player adds/removes a hero from a slot, SynergyBadge re-evaluates and updates within one frame.
- [ ] **UX-FA-16 (floor context)**: FloorContextLabel displays the current biome + floor in the format "Forest Reach · Floor 3" per locale key.
- [ ] **UX-FA-17 (floor locked mid-run)**: When state is mid-run, FloorButton is disabled with tooltip "Floor locked during active run."
- [ ] **UX-FA-18 (tap targets)**: All interactive elements (BackButton, slot buttons, HeroSlotRow, FloorButton, DispatchButton, CancelButton, ConfirmButton) have touch tap targets ≥44×44 logical pixels.
- [ ] **UX-FA-19 (toast feedback)**: Slot assign / clear / floor change actions produce a brief ToastLabel feedback that auto-dismisses after 1500ms. Toast text is localized.
- [ ] **UX-FA-20 (signal cleanup)**: After `on_exit`, all signals connected in `on_enter` (`hero_recruited`, `hero_removed`, `hero_leveled`, `current_biome_changed`, `floor_unlocked`, `state_changed`) report `is_connected == false`.
- [ ] **UX-FA-21 (locale keys complete)**: All Formation Assignment locale keys exist in `assets/locale/en.csv` with non-empty values (minimum: `formation_assignment_title`, `formation_assignment_back_button`, `formation_assignment_dispatch_button`, `formation_assignment_empty_slot_label`, `formation_assignment_floor_context_format`, `formation_assignment_change_floor_button`, `formation_assignment_mid_run_confirm_body`, `formation_assignment_mid_run_cancel_button`, `formation_assignment_mid_run_confirm_button`).

---

## Open Questions

- **OQ-FA-01**: Floor selector sub-flow — tapping FloorButton needs to expand into a floor-picker UI (list of unlocked floors per biome, with biome switcher). Does this become a dropdown, a sub-screen, or an inline expansion within FloorSelectorPanel? Recommend a separate small UX spec (`design/ux/floor-selector.md`) or fold into this spec as an inline section after first MVP playtest signals if/how richer floor selection is needed.
- **OQ-FA-02**: HeroSlotRow tap-without-slot-selected behavior — should the row show its current slot OR prompt "select a slot first" OR auto-select the first empty slot? The two-tap pattern is the spec's choice for clarity, but the fallback behavior needs a small playtest. Recommend: auto-select first empty slot for fewer taps; if all slots full, prompt.
- **OQ-FA-03**: Recruit-fresh visual signal — what's the exact visual treatment for a just-recruited hero in the roster (1px Lantern Gold border? subtle pulse? badge?) and how long does it persist (5s? until first interaction?)? Suggest the badge approach (small "NEW" chip on the row, persists until first interaction) — defer the visual detail to S20-M3 implementation playtest.
- **OQ-FA-04**: Drag-and-drop variant — is there ever a case where drag-from-roster-to-slot is preferable to tap-tap? For mouse users, drag feels natural. The current design is tap-tap for touch parity per ADR-0008. Possible Sprint 21+ enhancement: mouse-only drag pattern that doesn't break touch parity.
- **OQ-FA-05**: Dispatch button color when synergy active — should the Dispatch button pick up a Lantern Gold inner glow when a synergy is active, as a subtle "go now while it's good" signal? Cozy-register-safe but worth playtest. Risk: contradicts the cozy register if it feels FOMO-like.
- **OQ-FA-06**: 2 new visual patterns introduced — `Slot Button` (large square button as a content container, distinct from regular buttons) and `Two-Tap Assignment Flow` (the tap-slot-then-tap-row interaction pattern). Both should be added to `interaction-patterns.md` after this spec is approved.
- **OQ-FA-07**: No player journey map exists at `design/player-journey.md` — same gap as Guild Hall spec. Arrival contexts in §B are reasoned from GDDs; a formal journey map may surface additional contexts.
