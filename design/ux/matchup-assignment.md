# UX Spec: Matchup Assignment Screen

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-15
> **Journey Phase(s)**: Pre-dispatch strategic planning / Biome + floor browse
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/matchup-assignment-screen.md` (#23)
> **Template**: UX Spec

---

## Purpose & Player Need

Matchup Assignment Screen is the **biome + floor selection browser** — where the player picks which biome + floor to dispatch against, with strategic context (enemy archetype distribution + matchup hints). It opens from Formation Assignment when the player taps the FloorButton.

**Player goal on arrival**: *"Show me where I can go. Show me what's there. Help me pick the right floor for my current formation."*

The screen is the **strategic planning surface** of the cozy fantasy idle-clicker. Pillar 1 "tactical foresight" fully materializes here:
- Player sees ALL biomes they can browse (unlocked + locked)
- For each biome: floor list with unlock state + dominant enemy archetype hint
- Player picks → returns to Formation Assignment with the new floor selected

Per the cozy register:
- **Information not anxiety.** Per-floor enemy distribution shown without requiring memorization
- **Locked floors visible but inactive.** Frontier fantasy per `biome-dungeon-database.md` §A — player sees what's beyond their cleared edge
- **Matchup hints make planning legible.** Per ADR-0009, biome `dominant_archetypes` surfaces so the player matches formation to biome tilt without manual database reading
- **Tap-to-select.** Standard cozy navigation; back-out preserves prior selection

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **Tap Change Floor on Formation Assignment** | Considering formation, wants to switch floor | Planning / strategic | Show all browseable biomes + floors; highlight current selection |
| **Save-up evaluation** | Player wants to see what a future floor would face | Patient — exploring without intent to dispatch yet | Locked floors visible with unlock-requirement text; matchup hints still shown |
| **Back nav after recruit** (V1.0+ flow) | Player just recruited a new class; wants to check which biome favors it | Curious — testing new options | Same layout; new hero's class matchup affinity ideally highlighted |

The screen is **planning, not action** — the player browses, considers, picks, returns. No dispatch happens here.

---

## Navigation Position

Matchup Assignment Screen is a **child of Formation Assignment** — entered via the FloorButton; back nav returns to Formation Assignment with the selected floor applied.

```
Formation Assignment
  └── Matchup Assignment Screen  ← THIS SCREEN
        └── Select biome + floor → Formation Assignment (with new floor selected)
        └── Back (no change) → Formation Assignment (prior floor preserved)
```

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|--------------------|
| Tap Change Floor | Formation Assignment's FloorButton | Current biome+floor selection (highlighted on arrival) |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Select floor → return | Tap a SelectButton on an unlocked floor row | Routes to Formation Assignment via CROSS_FADE; new floor selected; FormationAssignment's FloorContextLabel updates |
| Back (no change) | Tap BackButton | Routes to Formation Assignment via CROSS_FADE; prior floor preserved |
| App close | OS home / force-quit | Selection state is on FormationAssignment autoload; persists |

---

## Layout Specification

### Information Hierarchy

1. **Biome list (rows)** — each row shows biome name + status (unlocked/locked) + dominant archetype hint
2. **Per-biome floor breakdown** — when a biome is expanded/selected, shows floors 1-5 with per-floor matchup hints
3. **Current selection highlight** — the floor currently selected on Formation Assignment is visually marked
4. **Locked floor explanations** — "Locked — clear Floor 3 first" text on each locked row
5. **Back navigation** — secondary; always available

### Layout Zones

| Zone | Height | Contents |
|------|--------|----------|
| Header | ~80px (~10%) | Back button + "Choose a Floor" title |
| Biome browser | flex (~85%) | Scrollable list of BiomeBlock (one per biome) |
| Footer (optional) | ~40px (~5%) | "Tap a floor to select" hint (cozy guidance) |

### Component Inventory

**Header zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| HeaderBar | PanelContainer | Container | No | `panel` variant `parchment-default` |
| BackButton | Button | `tr("matchup_assignment_back_button")` ("← Formation") | Yes | `button` variant `secondary`, 44×44 min |
| HeaderTitle | Label | `tr("matchup_assignment_title")` ("Choose a Floor") | No | `title-section` IM Fell English 24px |

**Biome browser zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| BiomeListScroll | ScrollContainer | Scrollable container | Touch-scrollable | n/a |
| BiomeListVBox | VBoxContainer | Layout | No | `lg` (24px) gap between BiomeBlocks |
| BiomeBlock (×N) | PanelContainer | One per biome (forest_reach, whispering_crags, sunken_ruins, hollow_stair, ember_wastes, frostmire) | No (rows inside are interactive) | `panel` variant `parchment-default` |
| BiomeBlock → BiomeHeader | HBoxContainer | Biome name + locked/unlocked badge | No | n/a |
| BiomeNameLabel | Label | `tr("biome_<id>_display_name")` ("Forest Reach") | No | `title-section` IM Fell English 24px |
| BiomeUnlockBadge | Label (conditional) | If biome locked: `tr("matchup_assignment_biome_locked_format", [unlock_req])` ("Locked — clear Frostmire Floor 5") | No | `secondary` Lora Italic 14px Dusk Purple |
| BiomeDominantHint | Label | `tr("matchup_assignment_biome_hint_format", [dominant_archetypes_text])` ("Favors Warriors + Mages") | No | `body` Lora Regular 16px Slate Ink |
| FloorRow (×5 per biome) | HBoxContainer | One per floor 1-5 | Per-row interactive (if unlocked) | `panel` variant `ledger-row` |
| FloorRow → FloorIndexLabel | Label | `tr("matchup_assignment_floor_index_format", [N])` ("Floor 1") | No | `body-emphasis` Lora SemiBold 18px |
| FloorRow → FloorMatchupHint | Label | per-floor archetype distribution e.g. "3 Bruisers, 2 Casters" | No | `secondary` Lora Regular 14px |
| FloorRow → FloorBossIndicator | Label/Icon (conditional) | "★ Boss Floor" if is_boss_floor | No | Lantern Gold accent |
| FloorRow → FloorLockBadge | Label (conditional) | If locked: `tr("matchup_assignment_floor_locked_format", [prereq_floor])` ("Locked — clear Floor 3 first") | No | `secondary` Lora Italic 14px Dusk Purple |
| FloorRow → SelectButton | Button (conditional) | "Select" if unlocked + not already selected; "Selected" if already this floor | Yes (if not already selected) | `button` variant `primary` when unlocked + not current; disabled with "Selected" text if current |

**Footer zone (optional)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| FooterHint | Label | `tr("matchup_assignment_footer_hint")` ("Tap a floor to select") | No | `caption` Lora Regular 12px Slate Ink at 70% alpha |

### ASCII Wireframe

```
┌─────────────────────────────────────────────────────────┐
│ [← Formation]      Choose a Floor                       │  ← Header
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Forest Reach                                        │ │  ← BiomeBlock
│ │ Favors Warriors + Mages                             │ │     (unlocked)
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ Floor 1   3 Bruisers, 2 Casters     [Selected] │ │ │  ← FloorRow
│ │ ├─────────────────────────────────────────────────┤ │ │     (current)
│ │ │ Floor 2   2 Bruisers, 1 Armored     [ Select ] │ │ │
│ │ ├─────────────────────────────────────────────────┤ │ │
│ │ │ Floor 3   Mixed                     [ Select ] │ │ │
│ │ ├─────────────────────────────────────────────────┤ │ │
│ │ │ Floor 4   Locked — clear Floor 3 first         │ │ │
│ │ ├─────────────────────────────────────────────────┤ │ │
│ │ │ Floor 5 ★ Boss — clear Floor 4 first           │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Whispering Crags                                    │ │  ← BiomeBlock
│ │ Locked — clear Forest Reach Floor 5                 │ │     (locked)
│ │                                                     │ │
│ │ (floor rows hidden when biome locked)               │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ...                                                     │  ← (scrollable)
├─────────────────────────────────────────────────────────┤
│           Tap a floor to select                         │  ← Footer hint
└─────────────────────────────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **Default — first launch** | Only Forest Reach unlocked | Forest Reach BiomeBlock shows unlocked rows (F1 unlocked, F2-5 locked-by-prereq); other biomes show locked header without floor rows |
| **Mid-progression** | Multiple biomes unlocked, varying floor depth | Each unlocked biome shows unlocked + locked floor rows per FloorUnlock state |
| **All MVP biomes unlocked** | All 6 biomes have at least F1 unlocked | All 6 BiomeBlocks fully rendered |
| **Currently-selected floor** | Player's current FloorButton selection on Formation Assignment | That FloorRow's SelectButton shows "Selected" disabled state; remaining rows show normal "Select" buttons |
| **Boss floor** | floor.is_boss_floor == true | FloorRow shows ★ Boss icon + boss flavor; no special interaction (still a regular floor select) |
| **Floor with custom hint text** | Specific floor with notable enemy composition (e.g., "Cleric showcase" per biome database planned_v1 entries) | FloorMatchupHint shows the curated distribution text instead of just archetype counts |
| **No floors unlocked anywhere** | Defensive edge case (should never happen — Theron + F1 always seeded) | Empty-state label "Clear your starting floor to unlock more" |
| **Biome with empty floor list** | Defensive edge case (data drift) | BiomeBlock shows biome header + empty-state label "No floors available"; `push_warning` logged |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Feedback | Outcome |
|-----------|--------|-------|----------|---------|
| BackButton | Tap | Mouse LMB / touch | `sfx_ui_tap` + button press | `SceneManager.request_screen("formation_assignment", CROSS_FADE)`; prior floor preserved |
| FloorRow SelectButton (unlocked, not current) | Tap | Mouse LMB / touch | `sfx_ui_tap` + button flash | FormationAssignment.set_floor(biome_id, floor_index); routes back to Formation Assignment via CROSS_FADE |
| FloorRow SelectButton (current) | Tap | Mouse LMB / touch | No feedback (disabled "Selected" state) | No-op |
| FloorRow (locked) | Tap | Mouse LMB / touch | No feedback (no SelectButton present) | No-op; FloorLockBadge text already explains the gate |
| BiomeBlock (locked) | Tap | Mouse LMB / touch | No feedback | No-op; BiomeUnlockBadge text explains the gate |
| Any other element | Tap | Mouse LMB / touch | No feedback (`mouse_filter = PASS`) | No-op |

**Tap-target-clarity**: only unlocked-and-not-current FloorRow SelectButtons are tappable. Locked rows have NO SelectButton (the affordance is structurally absent), making it clear they aren't actionable. Cozy register: never grayed-out-without-explanation; the FloorLockBadge text fills the affordance gap.

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Screen open | `ui_matchup_assignment_opened` | `{ source: "formation_assignment", current_biome_id, current_floor_index }` |
| Select unlocked floor | `ui_floor_selected` | `{ biome_id, floor_index, prior_biome_id, prior_floor_index }` |
| Back tapped (no selection change) | `ui_back_tapped` | `{ screen: "matchup_assignment" }` |
| Locked floor tap (no-op) | None (no feedback to log) | — |

**Persistent state writes**:
- `FormationAssignment._selected_biome_id` + `_selected_floor_index` via the FormationAssignment autoload's `set_floor(biome_id, floor_index)` method

The autoload mediates the write so the dispatch path reads from a single source (formation-assignment-system.md §C.6 contract).

---

## Transitions & Animations

**Screen enter**: 150ms cross-fade from Formation Assignment.

**Screen exit**: 150ms cross-fade to Formation Assignment.

**SelectButton press**: 80ms scale pulse (1.05× → 1.0×) per `UIFramework.wire_touch_feedback`. Reduce-motion: visual press state only.

**Floor selection commit**: when player taps an unlocked SelectButton, a brief 100ms color flash (Guild Amber → Lantern Gold → Guild Amber) on the FloorRow signals selection commit. Then cross-fade to Formation Assignment starts. Reduce-motion: no flash; cross-fade still applies.

**Biome list scroll**: standard ScrollContainer behavior; touch-drag and mouse-wheel both work. No special animations.

**Biome unlock animation** (when player just first-cleared the prereq floor) — V1.0+ polish: locked biome's BiomeBlock fades from Dusk Purple tint to Parchment Cream over 400ms with subtle Lantern Gold sweep. Currently MVP: no animation; biome simply renders unlocked next time the screen opens.

---

## Data Requirements

| Data | Source | Read / Write | Live-updating? | Notes |
|------|--------|--------------|----------------|-------|
| All biomes | `DataRegistry.resolve_all("biomes")` | Read | Static during screen open | Drives BiomeBlock list |
| Biome metadata (display_name, dominant_archetypes, primary_palette_key) | `Biome` resource fields | Read | Static | Drives BiomeNameLabel + BiomeDominantHint |
| Biome unlock state | `FloorUnlock.is_biome_unlocked(biome_id)` | Read | Yes — `biome_unlocked` signal | Drives BiomeUnlockBadge visibility |
| Biome unlock requirement | `FloorUnlock.get_biome_unlock_requirement(biome_id)` | Read | Static | Drives BiomeUnlockBadge text format |
| Floor metadata per biome | `Biome.dungeons[0].floors` (Array) | Read | Static | Drives FloorRow content |
| Floor unlock state | `FloorUnlock.is_floor_unlocked(biome_id, floor_index)` | Read | Yes — `floor_unlocked` signal | Drives FloorLockBadge visibility + SelectButton presence |
| Floor enemy distribution | `Floor.enemy_list` (post-materialization per Sprint 18 fix) | Read | Static | Drives FloorMatchupHint text (count by archetype) |
| Current selection | `FormationAssignment._selected_biome_id` + `_selected_floor_index` | Read | Yes — set by this screen's selection action | Drives "Selected" disabled state on current FloorRow |
| Boss floor flag | `Floor.is_boss_floor` | Read | Static | Drives FloorBossIndicator visibility |

**Write paths**: `FormationAssignment.set_floor(biome_id, floor_index)` via the autoload — single writer per `formation-assignment-system.md` §C.6.

---

## Accessibility

**Committed tier**: Standard.

| Requirement | Implementation |
|-------------|---------------|
| Tap targets | BackButton: ≥44×44. SelectButton: 44×44 min (wider with label). FloorRow: ≥56px tall for visual breathing |
| No color-only indicators | Locked rows have explicit text "Locked — clear Floor 3 first"; not just gray. SelectedButton has "Selected" text label, not just visual state. |
| Reduce-motion | SelectButton press scale pulse disabled (visual press only); selection flash disabled; cross-fade still applies |
| Colorblind backup cues | Boss indicator uses ★ icon, not just Lantern Gold color. Biome locked vs unlocked: text label + Dusk Purple tint on locked-biome header (backup: text explicit). |
| Text contrast | All text per DESIGN.md ratios. BiomeUnlockBadge italic 14px Dusk Purple — must verify ≥4.5:1 on Parchment Cream |
| Font size floor | All ≥14px; titles 24px; floor names 18px |
| Mouse + touch parity | All interactions single-tap; scroll works on both |
| Information density | Many rows visible; user scans rather than reads sequentially. Per `accessibility-requirements.md` cognitive load row: ≤4 simultaneous tracked items per screen — this screen exceeds that but the items are PARALLEL (same shape, different data), so cognitive load is BROWSING, not TRACKING. Acceptable. |
| Locked-floor screen-reader announcement | FloorLockBadge text explicit ("Locked — clear Floor 3 first") readable by AccessKit |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| HeaderTitle (`matchup_assignment_title`) | ~20 chars ("Choose a Floor" = 14) | LOW | Wraps |
| BackButton (`matchup_assignment_back_button`) | ~16 chars ("← Formation" = 11) | LOW | German "Formation" identical |
| BiomeNameLabel (`biome_<id>_display_name`) | ~20 chars | MEDIUM | "Whispering Crags" / "Flüsternde Klippen" — German may expand 40% |
| BiomeUnlockBadge (`matchup_assignment_biome_locked_format`) | ~40 chars ("Locked — clear Frostmire Floor 5" = 30) | MEDIUM | Biome name + ordinal; tight on small screens |
| BiomeDominantHint (`matchup_assignment_biome_hint_format`) | ~40 chars ("Favors Warriors + Mages") | MEDIUM | German "Bevorzugt Krieger + Magier" = 27; comfortable |
| FloorIndexLabel (`matchup_assignment_floor_index_format`) | ~10 chars ("Floor 1" = 7) | LOW | German "Stockwerk 1" = 11; tight in narrow column |
| FloorMatchupHint (numeric distribution) | ~30 chars ("3 Bruisers, 2 Casters") | MEDIUM | Plural-aware archetype names + count |
| FloorLockBadge (`matchup_assignment_floor_locked_format`) | ~40 chars ("Locked — clear Floor 3 first" = 28) | LOW-MEDIUM | Wraps if needed |
| SelectButton labels | ~12 chars ("Select" / "Selected") | LOW | German "Wählen" / "Gewählt" — comfortable |
| BossIndicator (`matchup_assignment_boss_floor_indicator`) | ~16 chars ("★ Boss Floor") | LOW | Uses icon + text |
| FooterHint (`matchup_assignment_footer_hint`) | ~30 chars ("Tap a floor to select") | LOW | Wraps |

**HIGH PRIORITY for loc review**:
- Floor index format — German "Stockwerk" (11 chars) is longer than "Floor" (5); may need narrower layout or abbreviation
- Plural-aware archetype counts for FloorMatchupHint — Slavic languages need locale-aware plural forms

---

## Acceptance Criteria

- [ ] **UX-MA-01 (layout)**: Header / Biome browser / Footer render at 1280×800 Steam Deck native; BiomeListScroll vertical-scrolls when content exceeds viewport
- [ ] **UX-MA-02 (all biomes listed)**: Each of the 6 MVP biomes (forest_reach, whispering_crags, sunken_ruins, hollow_stair, ember_wastes, frostmire) appears as a BiomeBlock in canonical order
- [ ] **UX-MA-03 (locked biome render)**: When `FloorUnlock.is_biome_unlocked == false`, the BiomeBlock shows BiomeUnlockBadge with the unlock requirement text; floor rows hidden
- [ ] **UX-MA-04 (unlocked biome render)**: When biome unlocked, BiomeBlock shows BiomeNameLabel + BiomeDominantHint + all 5 FloorRows
- [ ] **UX-MA-05 (floor unlock state)**: Each FloorRow renders with SelectButton (if floor unlocked AND not current) OR "Selected" disabled state (if current) OR FloorLockBadge text (if locked)
- [ ] **UX-MA-06 (per-floor matchup hint)**: FloorMatchupHint displays the localized archetype distribution from `Floor.enemy_list` (e.g., "3 Bruisers, 2 Casters")
- [ ] **UX-MA-07 (boss floor indicator)**: FloorRows with `is_boss_floor == true` show the ★ Boss icon + boss text alongside FloorIndexLabel
- [ ] **UX-MA-08 (select floor)**: Tapping SelectButton on an unlocked non-current FloorRow calls `FormationAssignment.set_floor(biome_id, floor_index)` then routes to Formation Assignment via CROSS_FADE
- [ ] **UX-MA-09 (current selection highlight)**: The currently-selected biome+floor (per FormationAssignment state) renders with "Selected" disabled button instead of "Select"
- [ ] **UX-MA-10 (back navigation)**: Tapping BackButton routes to Formation Assignment via CROSS_FADE without changing the selection
- [ ] **UX-MA-11 (locked-floor no interaction)**: Locked FloorRows have NO SelectButton; tapping the row produces no feedback; FloorLockBadge text explains the prereq
- [ ] **UX-MA-12 (live unlock signal)**: When `FloorUnlock.floor_unlocked` fires while screen is open (e.g., from offline replay), the corresponding FloorRow re-renders with the new state within one frame
- [ ] **UX-MA-13 (live biome unlock signal)**: When `FloorUnlock.biome_unlocked` fires while screen is open, the corresponding BiomeBlock cross-fades from locked to unlocked state
- [ ] **UX-MA-14 (tap targets)**: All interactive elements (BackButton + SelectButton ×N) have touch tap targets ≥44×44 logical pixels
- [ ] **UX-MA-15 (empty pool / data drift)**: If a biome has empty floor list (data drift), BiomeBlock shows empty-state label "No floors available" + push_warning logged
- [ ] **UX-MA-16 (event fired)**: `ui_floor_selected` event fires on SelectButton tap with payload `{ biome_id, floor_index, prior_biome_id, prior_floor_index }`
- [ ] **UX-MA-17 (cozy register — explicit gates)**: Every locked floor / biome has explicit text explaining the gate. No grayed-out-without-reason elements.
- [ ] **UX-MA-18 (DESIGN.md compliance)**: BiomeNameLabel uses `title-section` IM Fell English 24px; FloorIndexLabel uses `body-emphasis` Lora SemiBold 18px; FloorLockBadge uses `secondary` italic 14px Dusk Purple; SelectButton uses `primary` variant

---

## Open Questions

- **OQ-MA-01**: Biome layout — currently vertical-stacked BiomeBlocks scroll. Alternative: horizontal tabs at top with one biome's floors visible at a time. Recommend vertical stack for MVP (mobile-portrait-friendly + matches the Recruit Screen pool-list pattern). Revisit if playtest signals "I forgot biomes exist beyond Forest Reach."
- **OQ-MA-02**: Per-floor enemy preview — should FloorMatchupHint show enemy SILHOUETTES (icons) instead of just text counts? V1.0+ when enemy art lands. Currently text only.
- **OQ-MA-03**: Per-class affinity highlight — when player has a Mage in roster, should Mage-favored biomes/floors be visually highlighted? Subtle Guild Amber pulse on dominant_archetypes that match the roster? Risk: feels too prescriptive. Recommend OFF for MVP, evaluate in playtest.
- **OQ-MA-04**: Locked biome — should the biome name be VISIBLE (player knows what's coming) or HIDDEN ("???") as a discovery beat? Currently visible per cozy-frontier-fantasy. Visible reinforces the "world is bigger than you've seen" feel.
- **OQ-MA-05**: Synergy hint integration — Sprint 18 class synergies could inform per-biome hints. E.g., "Steel Wall synergy → +25% gold here" when 3-Warrior formation faces a bruiser-heavy biome. Sprint 21+ polish.
- **OQ-MA-06**: Floor difficulty preview — beyond enemy count, should hints include difficulty/danger indicator (low/medium/high)? Risk: derivable from enemy distribution; redundant. Recommend NO additional indicator; trust the distribution text.
- **OQ-MA-07**: Currently the spec calls `set_floor(biome_id, floor_index)` on FormationAssignment — verify this method exists per `formation-assignment-system.md` §C; if not, this is a contract gap to flag with `formation-assignment-system.md` author. Sprint 20 implementation work should verify before relying on this API.
- **OQ-MA-08**: 1 new pattern for `interaction-patterns.md`: **Browseable Locked Frontier** — list pattern showing both unlocked + locked items with explicit text explaining the unlock gate. Distinct from Affordability Gating (which is about resource cost) — this is about progression gating. Reusable for biome browser, future content unlock screens.
