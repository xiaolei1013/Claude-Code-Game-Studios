# Matchup Assignment Screen — GDD #23

> **Status: First-pass DRAFT 2026-05-07** by post-Roster-Hero-Detail-GDD autonomous-execution session, continuing the Sprint-14-prep design-coverage push (Settings/Hero Leveling/Onboarding/UI Framework/Return-to-App/Guild Hall/Recruit/Roster-Hero-Detail). All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. Run `/design-review` before APPROVED. Closes the systems-index #23 "Not Started" gap.

---

## A. Overview

**Matchup Assignment Screen** is the biome + floor selection browser that opens when the player taps the FloorButton on `formation_assignment.gd` (currently hard-coded to `forest_reach` floor 1 per Sprint 8 S8-M4 VS placeholder; the comment at `assets/screens/formation_assignment/formation_assignment.gd:36` documents the intent: "future multi-biome picker can replace"). The screen displays all biomes the player can browse, lists each biome's floors with their unlock state, and surfaces the per-floor enemy archetype distribution so the player can plan their formation against the matchup table.

The screen is the **strategic planning surface** of the cozy fantasy idle-clicker — it's where "tactical foresight" Pillar 1 fully materializes. The player can see which biome favors warriors vs mages vs rogues and pick the floor that best matches their current roster's strengths.

This GDD pairs with `biome-dungeon-database.md` (the data source), `formation-assignment-system.md` (the consumer that receives the selection), and `floor-unlock-system.md` (the gate on which floors are tappable).

---

## B. Player Fantasy

> *"I tap on the floor selector. The screen swaps to a biome browser — there's Forest Reach, Cinder Keep (locked, requires Floor 5 of Forest Reach), and a hint of more biomes beyond. Forest Reach's first three floors show with little enemy icons under them: Floor 1 has a hint 'Bruisers — favors Warrior'. Floor 4 shows 'Locked — clear Floor 3 first'. I tap Floor 3, see the matchup distribution (1 bruiser, 2 casters, 2 armored — favors mixed Warrior + Mage), tap 'Select'. Back to the formation screen, my floor is now F3 with the Mage I just recruited highlighted as a strong fit."*

The cozy register applies:
- **Information not anxiety.** Per-floor enemy distribution is shown without the player needing to memorize the entire database.
- **Locked floors visible but inactive.** The player sees what's beyond their current cleared frontier ("Locked — clear Floor 3 first") rather than having those floors hidden — this is part of the frontier fantasy per `biome-dungeon-database.md` §A.
- **Matchup hints make planning legible.** Per ADR-0009 (matchup-resolver), the screen displays each biome's `dominant_archetypes` so the player can match their formation to the biome's tilt without manually reading every enemy.
- **Tap-to-select, parchment-back-button.** Standard cozy navigation; nothing destructive; back-out preserves the prior selection.

---

## C. Detailed Rules

### C.1 Layout

The Control hierarchy follows the Recruit Screen layout pattern (per Recruit Screen GDD #21 §C.1):

```
matchup_assignment_screen.tscn (Control, anchors_preset = 15)
├── HeaderBar (PanelContainer, parchment-themed)
│   ├── BackButton (Button, "← Cancel", parchment-themed)
│   ├── Spacer
│   └── ScreenTitleLabel (Label, "Choose Your Run", IdentityHeader theme variation)
├── BiomePanel (PanelContainer, parchment-themed; horizontal-scroll on mobile if biomes overflow)
│   ├── BiomeTab[0] (HBoxContainer of FloorButton[0..N])
│   │   ├── BiomeHeaderRow (HBoxContainer)
│   │   │   ├── BiomeIcon (TextureRect, 64×64)
│   │   │   ├── BiomeNameLabel (Label, "Forest Reach")
│   │   │   └── BiomeMatchupHintLabel (Label, "Bruisers + Casters favor Warrior+Mage")
│   │   ├── FloorRow (HBoxContainer of FloorButton[0..4])
│   │   │   ├── FloorButton[0] — Floor 1 (Button, "F1", unlocked-state visual)
│   │   │   ├── FloorButton[1] — Floor 2 (Button or padlock indicator)
│   │   │   ├── … (5 floors per biome MVP)
│   │   └── FloorDetailPanel (PanelContainer, shown when a floor is selected)
│   │       ├── FloorNameLabel (Label, "Forest Reach — Floor 3")
│   │       ├── EnemyDistributionList (VBoxContainer of EnemyRows)
│   │       │   ├── EnemyRow[0] (HBoxContainer: archetype icon + count + name)
│   │       │   └── … (one row per unique enemy in floor.enemy_list)
│   │       └── MatchupHintLabel (Label, "Favors Warrior+Rogue formation")
│   └── BiomeTab[1] — repeats per biome (locked tabs render as dimmed)
└── FooterBar (PanelContainer)
    └── SelectButton (Button, "Select Floor 3 — Forest Reach", parchment-themed; SelectedSlotButton variation when a valid unlocked floor is selected; disabled when no selection or locked floor)
```

Sizing/spacing notes (anchored to UIFramework + Art Bible §4):
- HeaderBar height: 60–80 logical px (consistent with Guild Hall + Recruit Screen).
- BiomeTab height: ≥240 logical px (BiomeHeader 80 + FloorRow 60 + FloorDetailPanel 100).
- FloorButton size: ≥60×60 logical px (tap target ≥44×44 with parchment border padding).
- FloorDetailPanel min height: 100 logical px to accommodate up to 5 EnemyRows on a single floor.
- FooterBar height: 60–80 logical px.

### C.2 Lifecycle hooks

`matchup_assignment_screen.gd` extends `Screen` (per `src/core/scene_manager/screen.gd`). Callable as a sub-screen of formation_assignment OR as a top-level transition target — MVP path is sub-screen.

The screen receives the current selection via setters BEFORE on_enter:

```gdscript
# Caller (formation_assignment.gd):
matchup_screen.set_initial_selection(_selected_biome_id, _selected_floor)
SceneManager.request_screen("matchup_assignment", CROSS_FADE)
```

**on_enter:**
- Resolve all biomes via `DataRegistry.list_category("biomes")` — returns Array[String] of biome ids, ordered alphabetically (deterministic)
- For each biome: resolve full Biome resource via `DataRegistry.resolve("biomes", id)` (gives dominant_archetypes + display_name + icon)
- For each biome: list floors via `DataRegistry.list_category("dungeons")` filtered by `dungeon.biome_id == biome.id` (each Dungeon record per `biome-dungeon-database.md` §C is a single floor)
- Initial render: `_render_biome_tabs()` (one tab per biome), `_select_floor(_initial_biome_id, _initial_floor)`
- Wire BackButton.pressed → `_on_back_pressed`
- Wire SelectButton.pressed → `_on_select_pressed`
- Wire each FloorButton.pressed → `_on_floor_button_pressed.bind(biome_id, floor_index)` (BIND captures both args)
- Touch-feedback wired on all buttons via `UIFrameworkScript.wire_touch_feedback`
- Subscribe to `FloorUnlock.floor_unlocked` → `_on_floor_unlocked` (refresh floor button gating if a clear happens mid-screen — rare but possible during offline replay flush)

**on_exit:**
- Disconnect FloorUnlock signal + 3 button handlers + N FloorButton handlers

**on_pause / on_resume:**
- pass — no per-frame state; screen rebuilds via on_enter on re-entry

### C.3 Biome tab render

`_render_biome_tabs()`:
1. For each biome in DataRegistry's biomes category:
   a. Resolve biome resource → display_name, icon, dominant_archetypes
   b. Render BiomeIcon, BiomeNameLabel
   c. Compute matchup hint string: per biome.dominant_archetypes, look up the canonical class counters per ADR-0009 — e.g., archetype "bruiser" → counter "warrior". Concatenate into a localized string like "Bruisers + Casters favor Warrior+Mage" (locale CSV columns provide the "favors" framing per locale).
   d. Render the 5 FloorButtons per biome (each Dungeon record is one floor):
      - For each floor: render the floor index ("F1", "F2", …)
      - Tooltip / aria-label: localized floor name (e.g., "Forest Reach — Floor 1")
      - Locked-state visual: padlock icon overlay + dimmed parchment per ADR-0008
2. Lock-state per FloorButton:
   - Read `FloorUnlock.is_unlocked(biome_id, floor_index)` (per `floor-unlock-system.md`)
   - If unlocked: button enabled, parchment-themed normal
   - If locked: button shows padlock + dimmed; tap surfaces a toast "Clear Floor %d to unlock." per the floor-unlock GDD
3. Selected-state: the currently-selected FloorButton renders with SelectedSlotButton theme variation (warm parchment glow per ADR-0008).

If `biome.dominant_archetypes` is empty (defensive), the matchup hint label renders the empty placeholder string (no hint surfaced).

### C.4 Floor selection interaction

`_on_floor_button_pressed(biome_id, floor_index)`:
1. If `FloorUnlock.is_unlocked(biome_id, floor_index) == false`:
   - Toast: tr("matchup_floor_locked_format") formatted with floor_index of the prior floor (e.g., "Clear Floor 2 to unlock."). 3.0s linger.
   - Button-state highlight returns to non-selected.
   - Return without updating selection.
2. Update `_selected_biome_id = biome_id`, `_selected_floor = floor_index`.
3. `_select_floor(biome_id, floor_index)`:
   - Render the FloorDetailPanel for the selected floor:
     - FloorNameLabel: tr-keyed name from `dungeon.display_name_key`
     - EnemyDistributionList: for each `{enemy_id, count}` in `floor.enemy_list`:
       - Resolve enemy via DataRegistry → archetype + display_name
       - Render EnemyRow with archetype icon (per Art Bible #archetype color) + count + display_name
     - MatchupHintLabel: derived from the floor's enemy distribution per the matchup-resolver — e.g., "Favors Warrior+Rogue formation" (locale-keyed)
   - Update SelectButton.text = tr("matchup_select_format") formatted with floor_index + biome name
   - Update SelectButton.disabled = false (selected unlocked floor is the gate)
4. Visual: previously-selected FloorButton reverts to normal theme; new one renders SelectedSlotButton variation.

### C.5 Select / Confirm interaction

`_on_select_pressed()`:
1. Defensive: if no selection (initial state with locked floor 1 hypothetically), push_warning + return (visibility gate should prevent).
2. Pass selection back to formation_assignment via SceneManager. MVP pattern uses a global-scope cache OR a setter on a session-scoped autoload (e.g., FormationAssignment.set_target(biome_id, floor_index)). **Resolution path**: extend FormationAssignment autoload (#17) with a `set_target(biome_id, floor_index)` setter that the formation_assignment screen reads on its own on_enter. This avoids cross-screen direct references.
3. Navigate back to formation_assignment via `SceneManager.request_screen("formation_assignment", CROSS_FADE)`.

formation_assignment.gd's on_enter then reads `FormationAssignment.get_target()` (or equivalent accessor) and updates its hard-coded `_selected_biome_id` + `_selected_floor` fields per the existing FloorContextLabel render.

### C.6 Back / Cancel interaction

`_on_back_pressed()`:
- Navigate back to formation_assignment via `SceneManager.request_screen("formation_assignment", CROSS_FADE)`.
- Selection state is NOT pushed back — the caller's prior selection is preserved (formation_assignment retains its `_selected_biome_id` / `_selected_floor` fields).

### C.7 Initial selection on entry

The screen receives the prior selection via `set_initial_selection(biome_id, floor_index)`. On_enter renders that floor as selected (SelectedSlotButton variation) and shows the FloorDetailPanel for it. Player sees their current target highlighted; can tap a different floor or back-cancel.

If no prior selection (first-launch scenario), default to (`forest_reach`, `1`) per the existing formation_assignment hard-coded path. The seeded Theron + Forest Reach Floor 1 is the cold-launch state.

### C.8 Locked-tab handling

V1.0+ may add multi-biome unlock progression where Cinder Keep unlocks after clearing Forest Reach Floor 5. For MVP (single biome — `forest_reach` only — per Sprint 8 S8-M4 VS scope), only Forest Reach is rendered. Locked-tab rendering is V1.0+ scope. The biome browser layout (BiomeTab in §C.1) is forward-compat for the multi-biome case; MVP just shows ONE BiomeTab.

### C.9 Cross-screen state preservation

Per §C.5/§C.6, the screen's selection state is communicated through FormationAssignment autoload, not through SceneManager itself. This decouples screen lifecycle from selection state — the player can dismiss + re-enter formation_assignment without losing the matchup pick.

### C.10 reduce_motion accessibility

Per Settings GDD #30 §C + ADR-0008:
- `Settings.reduce_motion == true`: SelectedSlotButton highlight is instant (no fade); FloorDetailPanel visibility toggle is instant; touch-feedback uses 1.0× scale.
- Default: 200ms cross-fade transitions; 1.05× pulse on tap; SelectedSlotButton highlight has a subtle parchment-warm fade-in.

---

## D. Formulas

### D.1 Floor unlock check (cross-reference)

Per `floor-unlock-system.md`:
```
is_unlocked(biome_id, floor_index) = FloorUnlock.is_unlocked(biome_id, floor_index)
```
Returns bool. The screen uses this to gate FloorButton interactivity per §C.3 step 2.

### D.2 Matchup hint per biome (cross-reference)

Per ADR-0009 + `class-vs-enemy-matchup-resolver.md`:
```
matchup_hint(biome) = locale-format(biome.dominant_archetypes, counter_class_per_archetype())
```
Where `counter_class_per_archetype` is a mapping per ADR-0009 (e.g., bruiser → warrior, caster → mage, swift → rogue). The screen RENDERS the hint string; it does NOT compute combat outcomes.

### D.3 Per-floor enemy distribution (cross-reference)

Per `biome-dungeon-database.md` §C.2:
```
enemy_list(floor) = floor.enemy_list  // Array of {enemy_id, count}
archetype(enemy) = DataRegistry.resolve("enemies", enemy_id).archetype
```
Used in §C.4 step 3 to render EnemyDistributionList.

---

## E. Edge Cases

### E.1 Single-biome MVP layout
MVP has only `forest_reach`. The BiomeTab list shows one tab. Layout is forward-compat for the multi-biome V1.0+ case (BiomePanel scrolls horizontally when biomes exceed visible width). Cozy: empty multi-biome rendering doesn't surface as broken.

### E.2 All floors locked
First-launch state: only Floor 1 unlocked per `floor-unlock-system.md`. Floors 2-5 render with padlock; selection pre-fills Floor 1; SelectButton enabled.

### E.3 Floor unlocks mid-screen via offline replay
Player on the matchup screen during offline replay flush. `floor_unlocked` signal fires (e.g., they returned-from-app and the offline replay cleared a previously-locked floor). `_on_floor_unlocked` re-renders the affected FloorButton (locked → unlocked); cozy live update.

### E.4 Tap a locked floor
Toast "Clear Floor %d to unlock." per §C.4 step 1. Selection does NOT update. SelectButton remains gated on prior valid selection.

### E.5 Locale change
V1.0+ scenario; static labels re-render on next on_enter. MVP locks the locale at boot.

### E.6 Save / load mid-screen
Per ADR-0004 hydration suppression, `FloorUnlock` doesn't fire spurious signals during hydration. Screen rebuilds on next on_enter; mid-screen is stable.

### E.7 Empty biomes category
Defensive — if `DataRegistry.list_category("biomes")` returns empty (content patch removed all biomes; should not happen in production), screen shows placeholder "No biomes available. Update content." with BackButton enabled. push_warning logged.

### E.8 Biome with zero floors
Defensive — if a biome has no associated dungeons, BiomeTab renders header but no FloorRow. Skipped from selection. push_warning logged.

### E.9 Floor with empty enemy_list
Defensive — content drift could leave a Dungeon record without enemy_list. FloorDetailPanel renders "No enemies." placeholder. SelectButton remains enabled (selection still valid for a deterministically empty floor — Combat Resolution handles zero-kill case per `combat-resolution.md` §E).

### E.10 Tap-spam on FloorButton
Each tap re-runs `_on_floor_button_pressed` which is idempotent (writes the same `_selected_biome_id` + `_selected_floor`). UIFramework's wire_touch_feedback debounces visual feedback. No harm; no debounce needed at the logic layer.

### E.11 Tap during `_replay_in_flight`
Per ADR-0014 + Settings GDD #30 precedent, screens MAY gate certain interactions during offline replay. The matchup screen's selection is read-only on FloorUnlock state and doesn't mutate game state — selecting a floor during replay is safe (the dispatch happens later via formation_assignment). No gating needed.

---

## F. Dependencies

### Hard dependencies (Matchup Assignment Screen requires these to function)

| System | Why | Surface used |
|---|---|---|
| `DataRegistry` (#2) | Biome + dungeon + enemy resolution | `list_category("biomes")`, `resolve("biomes", id)`, `list_category("dungeons")`, `resolve("dungeons", id)`, `resolve("enemies", id)` |
| `BiomeDungeonDatabase` (#8) | Resource definitions | per-biome `dominant_archetypes` + `display_name`; per-dungeon `floor_index` + `biome_id` + `enemy_list` |
| `EnemyDatabase` (#7) | Archetype lookup | per-enemy `archetype` + `display_name` |
| `FloorUnlock` (#16) | Per-floor lock-state | `is_unlocked(biome_id, floor_index)`, `floor_unlocked` signal |
| `FormationAssignment` (#17) | Selection sink | `set_target(biome_id, floor_index)` setter (NEW per §C.5) — the screen pushes selection here for formation_assignment.gd to consume |
| `SceneManager` (#4) | Navigation | `request_screen("formation_assignment", CROSS_FADE)` |
| `UIFramework` (#18) | Theme + touch feedback | `apply_parchment_panel`, `wire_touch_feedback`, `format_localized` |
| `TranslationServer` (Godot built-in) | Localization | `translate(StringName)` |

### Reverse dependencies (systems that depend on Matchup Assignment Screen)

- **Formation Assignment Screen** (#17) — the FloorButton on `formation_assignment.gd` opens this screen; on return, formation_assignment reads the selection from FormationAssignment autoload's new `set_target` setter

### Soft dependencies

- **AudioRouter** (#28) — UI tap chime fires via `UIFramework.wire_touch_feedback` hook on FloorButtons; no dedicated matchup chime

---

## G. Tuning Knobs

### Layout knobs (parchment_theme + screen.tscn)
- BiomeTab height: 240 logical px.
- FloorButton size: 60×60 logical px.
- FloorDetailPanel min height: 100 logical px.

### Matchup hint string templates (locale CSV)
- "Bruisers favor Warrior" / "Casters favor Mage" / "Swift favor Rogue" — ADR-0009 canonical mappings.
- Combination strings: "Bruisers + Casters favor Warrior+Mage" — assembled per biome's dominant_archetypes set.

### Animation knobs (UIFramework constants per ADR-0008)
- SelectedSlotButton highlight fade-in: 200ms ease-out. reduce_motion → instant.
- FloorButton tap-feedback: 1.05× pulse / 0.08s expand / 0.016s return.
- FloorDetailPanel slide-in on selection change: 200ms. reduce_motion → instant.

### V1.0+ tuning knob: counter-class hints per archetype
ADR-0009 may evolve counter-class mappings in V1.0+ (e.g., "specialist" archetype counters multiple classes). Tuning lives in the matchup-resolver GDD; the matchup screen passively reads.

### V1.0+ tuning knob: biome ordering
MVP ordering is alphabetical per DataRegistry.list_category. V1.0+ may prefer "unlocked first, locked last" or a curated narrative order. Tuning knob: `BIOME_DISPLAY_ORDER: Array[String]` in BiomeDungeonDatabase config.

---

## H. Acceptance Criteria

**AC-23-01 — Screen renders one BiomeTab per biome in DataRegistry**
On enter, `DataRegistry.list_category("biomes")` returns the biome list; BiomeTab nodes render alphabetically. MVP: one tab (forest_reach).

**AC-23-02 — BiomeNameLabel + BiomeIcon match resolved Biome**
Each BiomeTab's BiomeNameLabel reads from `biome.display_name_key` via tr(); BiomeIcon reads from `biome.icon` (placeholder when null).

**AC-23-03 — BiomeMatchupHintLabel reflects dominant_archetypes**
The hint string is locale-formatted from `biome.dominant_archetypes` per ADR-0009 counter-class mappings.

**AC-23-04 — FloorButton renders 5 floors per biome**
Each BiomeTab's FloorRow renders 5 FloorButtons (F1–F5) corresponding to the 5 Dungeons whose `biome_id` matches.

**AC-23-05 — Locked floors render with padlock + dimmed**
For each FloorButton, `FloorUnlock.is_unlocked(biome_id, floor_index) == false` → padlock icon + dimmed parchment.

**AC-23-06 — Tap on locked floor surfaces toast**
Tapping a locked FloorButton triggers a toast ("Clear Floor %d to unlock.") for 3.0s; selection does NOT update.

**AC-23-07 — Tap on unlocked floor selects the floor**
Tapping an unlocked FloorButton sets `_selected_biome_id` + `_selected_floor`; previously-selected button reverts; new button renders SelectedSlotButton variation; FloorDetailPanel updates.

**AC-23-08 — FloorDetailPanel shows EnemyDistributionList per floor.enemy_list**
Each unique `{enemy_id, count}` in the floor's enemy_list renders as one EnemyRow with archetype icon + count + display_name.

**AC-23-09 — FloorDetailPanel shows MatchupHintLabel per floor distribution**
The hint reflects the floor's enemy archetype distribution per the matchup-resolver mappings.

**AC-23-10 — SelectButton text reflects current selection**
SelectButton.text = tr-formatted "Select Floor %d — %s" with floor_index + biome name.

**AC-23-11 — SelectButton disabled when no valid selection**
On entry without prior selection AND locked floor 1: SelectButton disabled. After valid floor tap: enabled.

**AC-23-12 — Select press routes back with selection in FormationAssignment**
Tap SelectButton → calls `FormationAssignment.set_target(biome_id, floor_index)` → `SceneManager.request_screen("formation_assignment", CROSS_FADE)`.

**AC-23-13 — Back press routes back without changing selection**
Tap BackButton → `SceneManager.request_screen("formation_assignment", CROSS_FADE)` without calling FormationAssignment.set_target. The prior selection on formation_assignment is preserved.

**AC-23-14 — Initial selection rendered on enter**
`set_initial_selection(biome_id, floor_index)` called pre-show → on_enter renders that floor as selected (SelectedSlotButton variation) and shows the FloorDetailPanel for it.

**AC-23-15 — floor_unlocked signal triggers re-render**
External `FloorUnlock.floor_unlocked(biome_id, floor_index)` → the affected FloorButton transitions from locked to unlocked visual.

**AC-23-16 — Touch-feedback on all buttons**
BackButton, SelectButton, every FloorButton uses `UIFramework.wire_touch_feedback`. reduce_motion → 1.0× scale.

**AC-23-17 — reduce_motion suppresses fades**
SelectedSlotButton highlight + FloorDetailPanel visibility transitions are instant when `reduce_motion == true`.

**AC-23-18 — Locale-aware labels**
ScreenTitleLabel, BiomeNameLabel, BiomeMatchupHintLabel, FloorNameLabel, MatchupHintLabel, SelectButton text, BackButton text, toast strings all use locale-keyed tr() calls.

---

## I. Open Questions & ADR Candidates

**OQ-23-1 — Multi-biome MVP scope**
MVP ships with one biome (`forest_reach`). The matchup screen's BiomeTab loop renders one tab. Locked-biome rendering (e.g., Cinder Keep dimmed until F5 cleared) is V1.0+ scope. Should MVP show locked future biomes as "Coming soon" placeholder cards to surface the frontier fantasy, OR show only the unlocked biome to keep the MVP screen visually clean? Cozy register suggests the latter (don't tease unimplemented content); resolution path: show only unlocked biomes in MVP.

**OQ-23-2 — Counter-class hint precision**
The matchup hint surfaces dominant archetypes. Should it ALSO show per-floor specifics (e.g., "F3: 2 bruisers + 2 casters + 1 armored — favors mixed Warrior+Mage")? MVP shows biome-level hint AND per-floor distribution (via EnemyDistributionList) — both surface the data. The locale-formatted summary string is biome-level only; per-floor details live in the EnemyDistributionList rows.

**OQ-23-3 — Sort order within biome floors**
MVP sorts floors by floor_index ascending (F1, F2, …, F5). V1.0+ could sort by recommended-difficulty or by-enemy-archetype-match. MVP locks the floor_index ordering — it matches the canonical progression.

**OQ-23-4 — FormationAssignment.set_target API design**
The screen pushes the selection back via FormationAssignment.set_target(biome_id, floor_index). FormationAssignment doesn't currently have this API — Sprint 14+ implementation must add it (small extension; pairs with this screen). ADR-candidate if the API needs validation logic; defer until impl reveals it.

**OQ-23-5 — Visualization of matchup advantage**
Could a bar chart or color-coded matchup score visualize "this floor favors your roster"? MVP shows hint label only (text-based, scaleable). V1.0+ may add a per-row "matched: 3/5" counter using the player's current formation as the comparison anchor. Out of MVP scope.

**OQ-23-6 — Enemy preview on tap**
Should tapping an EnemyRow open a sub-modal with enemy details (HP/DPS/archetype lore)? MVP says NO — one tap to select the floor; enemy details are V1.0+ "Bestiary" feature.

**OQ-23-7 — Cancel returns to which prior screen?**
The Back button hard-codes return to formation_assignment. If the screen is ever opened from somewhere else (e.g., direct from main_menu or from a tutorial overlay), the Back path needs to be parameterized. MVP locks the formation_assignment return; revisit when a new caller emerges.

**OQ-23-8 — Locked floor toast vs always-show-detail**
When tapping a locked floor, MVP shows a toast and does NOT update the FloorDetailPanel. Alternative: show the locked floor's enemy distribution anyway (so the player can see what they're saving up for). Cozy register favors the alternative — frontier fantasy + planning visibility. Resolution path: revisit during /design-review; MVP currently goes with the toast-only path for simplicity.

---

## J. Implementation Sequencing (Sprint 15+ candidate)

This GDD is design-first; implementation is Sprint 15+ candidate scope (~1.0d). Pre-sequenced as 5 stories:

1. **Story 1 (~0.2d)** — `matchup_assignment_screen.tscn` authoring per §C.1 layout. Anchor preset 15 + parchment-themed PanelContainers + BiomeTab (single MVP) + 5 FloorButtons + FloorDetailPanel + FooterBar. Editor work; no .gd changes required.
2. **Story 2 (~0.25d)** — `matchup_assignment_screen.gd` lifecycle hooks per §C.2. on_enter / on_exit signal subscriptions; set_initial_selection setter; FloorUnlock subscription; touch_feedback on all buttons. Tests for ACs 23-01 (biome render), 23-04 (floor count).
3. **Story 3 (~0.25d)** — Biome + floor render per §C.3. BiomeNameLabel + BiomeMatchupHintLabel + FloorButton lock-state visuals. Tests for ACs 23-02, 23-03, 23-05, 23-15.
4. **Story 4 (~0.2d)** — Floor selection + detail panel per §C.4. EnemyDistributionList + MatchupHintLabel + SelectedSlotButton variation. Tests for ACs 23-07, 23-08, 23-09, 23-14.
5. **Story 5 (~0.1d)** — Select / Back interaction per §C.5/§C.6; FormationAssignment.set_target API extension. Tests for ACs 23-12, 23-13.

Plus formation_assignment.gd integration (~0.05d): replace the hard-coded `_selected_biome_id` / `_selected_floor` with a read from FormationAssignment.get_target() on on_enter; add the FloorButton tap handler that opens this screen with set_initial_selection.

Total Sprint 15+ scope: ~1.05d. Best landed alongside FormationAssignment.set_target API extension (small, pairs naturally).

---

## Notes

- Authored 2026-05-07 by post-Roster-Hero-Detail-GDD autonomous-execution session, continuing the Sprint-14-prep design-coverage push (8th first-pass GDD). systems-index.md row 23 status flips from "Not Started" to "DRAFT 2026-05-07".
- All ACs are testable via patterns documented in `tests/PATTERNS.md`.
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED.
- The screen is the strategic-planning surface of the cozy fantasy — Pillar 1 (Tactical Foresight) materializes here. Per `game-concept.md` Pillar 1: "Each floor clear teaches the player something about the biome's matchup tilt; the matchup screen makes that learning legible."
- This GDD pairs with `biome-dungeon-database.md` (data source), `formation-assignment-system.md` (selection sink + return target), `floor-unlock-system.md` (lock-state gate), `class-vs-enemy-matchup-resolver.md` (hint string mappings).
- formation_assignment.gd's hard-coded `_selected_biome_id = "forest_reach"` + `_selected_floor = 1` (lines 38–41) becomes the fallback initial state when FormationAssignment.get_target returns null/empty. The matchup screen's set_target setter is the canonical mutation path.
