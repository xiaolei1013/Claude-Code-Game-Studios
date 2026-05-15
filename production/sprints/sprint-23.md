# Sprint 23 — 2026-05-29 to 2026-06-11

> **Status: Day-0 plan authored 2026-05-15**, same-day close of Sprint 22.
> Tenth consecutive same-day-compressed sprint (Sprint 14→15→16→17→18→19→20→21→22→23).
> Solo review mode.

## Sprint Goal

**Complete the remaining scene consolidation gap (Hall of Retired Heroes → tab, Pause Menu modal), resolve the deferred M4 clarity items driven by the playtest-14 signal, and scaffold the Settings screen so the Pause Menu has somewhere to go.**

Sprint 22 closed the structural consolidation (10→8 screens) and ran the first clarity pass. Sprint 23 finishes what Sprint 22's Should Haves couldn't reach: the `hall_of_retired_heroes` standalone screen (→6 entries after PR #126 achieves 7) and the pause modal that makes the game feel like a real product. The M4 deferred items (empty-state copy, tap-target check, unstyled CTA audit) ship or defer based on the playtest-14 verdict — if playtest-14 flags gaps on items c/d/e, S23-S1 is non-negotiable; if all 5 checks PASS, S23-S1 is advisory polish.

**Definition of Sprint 23 success**:
(a) `hall_of_retired_heroes` retired as a standalone screen; its content lives in a Retired tab on Guild Hall's RosterPanel (Active | Retired); registry shrinks 7→6 (PR #126 achieves 8→7 first);
(b) Pause Menu modal exists, wired via Esc key on every player-facing screen; Resume / Settings / Quit-to-Guild-Hall all functional;
(c) M4 deferred items c/d/e addressed per playtest-14 verdict (empty states, tap targets ≥44×44, Primary Button on all primary CTAs);
(d) Settings screen scaffold navigable from Pause Menu — audio sliders + Reduce Motion toggle + version display + Quit-to-Desktop;
(e) Visual playtest validates M1+M2 additions read clearly (one screen is always "Guild Hall" not "Active Heroes Tab on the screen with the tavern"); retro committed.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: Sprint 23 is the lightest sprint since Sprint 16. Must Haves total 2.0d; Must + Should = 4.5d. 3.5d of headroom exists for Nice to Haves if M+S close early. After Sprint 22's structural load (4.75d Must Have), this lighter scope is intentional — it builds in recovery time and ensures the scene consolidation finishes cleanly before new feature weight arrives.

## Pre-Plan Disposition (handle BEFORE Sprint 23 M1 starts)

| PR / Gate | Status | Action |
|-----------|--------|--------|
| **PR #126** (S22-M1 main_menu retire) | OPEN, CI green, orthogonal to S22-M2–M4 | **MERGE FIRST** — takes registry 8→7; S23-M1 then takes it 7→6 (the final consolidated state) |
| **playtest-14** (S22-M5) | PENDING verdict | **Fill in playtest-14 before starting S23-S1** — S23-S1 scope is conditional: PARTIAL/FAIL on items c/d/e → S1 is non-negotiable; all 5 PASS → S1 is advisory polish |
| **sprint-22 retro** | DRAFT (pending playtest verdict) | **Finalize retro once playtest-14 verdict lands** (flip DRAFT → committed; flip S22-M5 sprint-status to done) |

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|--------------|-------------------|
| S23-M1 | **Hall of Retired Heroes → tab on Guild Hall.** Add an Active/Retired tab strip to Guild Hall's RosterPanel. Migrate `hall_of_retired_heroes` content (retired hero list, hero cards) into the Retired tab. Remove `hall_of_retired_heroes` from `SceneManager._screen_registry`. Delete standalone screen files. **Explicit test updates required** (grep won't surface all of these): (1) update `test_screen_registry_has_eight_entries` count assertion from 8→7 (pre-#126) or 7→6 (post-#126); (2) remove `hall_of_retired_heroes` from E-04 `expected_paths` dict; (3) redirect `tests/unit/hall_of_retired_heroes/hall_render_test.gd` to assert the Retired tab content on Guild Hall instead. Grep for `"hall_of_retired_heroes"` BEFORE deletion for any remaining references. | godot-gdscript-specialist | 0.75d | PR #126 merged | Tab strip on Guild Hall; "Active" tab shows current roster; "Retired" tab shows retired heroes; `hall_of_retired_heroes` removed from registry (→6 entries after PR #126 achieves 7); all 3 affected test locations updated; standalone screen files deleted; full test suite passes |
| S23-M2 | **Pause Menu modal scene.** Esc-key (or visible header pause icon) triggers `SceneManager.push_overlay("pause_menu", true)`. Register `pause_menu` in `SceneManager._overlay_registry` (or equivalent — per ADR-0007 §push_overlay contract). Modal contains: Resume (`pop_overlay()`), Settings (navigate to settings screen — disabled/placeholder if S23-S2 not landed), Quit-to-Guild-Hall (auto-save if applicable + `request_screen("guild_hall")`). Wire Esc listener on every player-facing screen. Note: `push_modal` does not exist on SceneManager — use `push_overlay`. Create `assets/screens/_modals/` directory first. | godot-gdscript-specialist | 0.75d | none | `assets/screens/_modals/pause_menu.tscn` + `.gd` exist; `push_overlay("pause_menu", true)` triggers modal on every screen; Resume calls `pop_overlay()`; Quit-to-Guild-Hall navigates; modal stacks cleanly with existing MidRunReassign modal per ADR-0007 |
| S23-M3 | **Sprint 23 visual playtest + retro.** Use `production/playtests/_template-visual-playtest.md` to grade Hall of Retired Heroes tab (M1) + Pause Modal (M2) + any S1/S2 changes. Per-check PASS/PARTIAL/FAIL. Retro doc + sprint-status.yaml closed. | xiaolei (human) + claude-code | 0.5d | M1+M2 | playtest-15 committed with per-check verdict; sprint-23 retro committed; sprint-status.yaml all Must Haves marked done |

**Must Have total**: 2.0 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S23-S1 | **M4 clarity follow-up — empty states, tap-target verification (≥44×44), Primary Button on CTAs.** Scope is driven by playtest-14: if PARTIAL/FAIL on items c/d/e, this is non-negotiable and ships before M3 playtest; if all 5 checks PASS, this is optional polish. Items: (c) descriptive empty-state copy + icon hint on screens with empty collections; (d) tap-target audit at mobile-equivalent resolution (≥44×44 logical px per DESIGN.md); (e) every primary CTA uses Primary Button pattern (pattern #1 in interaction-patterns.md), not an unstyled Button node. | godot-gdscript-specialist | 1.0d | playtest-14 verdict (run before starting S1) | All 7 screens have descriptive empty states; primary CTAs use Primary Button pattern; tap-target audit passed; no unthemed Button nodes on primary actions |
| S23-S2 | **Settings screen scaffold.** Music volume slider (hooked to AudioRouter.music_bus volume — placeholder if AudioRouter not present; shows label "Music Volume [slider]") + SFX volume slider + Reduce Motion toggle (wired to `AccessibilityManager.reduce_motion = true/false` if it exists, otherwise writes to a `ProjectSettings`-level flag) + version string display + Quit-to-Desktop button. Navigable from Pause Menu via the Settings button. Back button returns to Pause Modal (or Guild Hall if accessed via a menu path). | godot-gdscript-specialist | 1.0d | S23-M2 (Pause Menu for navigation) | `assets/screens/settings/settings.tscn` + `.gd` exist; navigable from Pause Modal Settings button; sliders exist (functional or labeled placeholder); Reduce Motion toggle wired; version string shown; Quit-to-Desktop exits the application |
| S23-S3 | **ClassPortrait placeholder art — 96×96 colored-block per class ID.** `HeroClass.portrait_path` field populated with a distinct programmatic texture per class (solid color block with class initials or a simple geometric mark — no real art needed). Used by Recruit Screen pool-entry rows and Hero Detail modal portrait slot. **Third carry** from S20-N1 → S21-S2 → (dropped S22) — promoted to Should Have per "3rd carry → Should Have minimum" process rule. | godot-gdscript-specialist | 0.5d | none | Each hero class renders a visually distinct 96×96 placeholder at `HeroClass.portrait_path`; Recruit Screen pool-entry cards show non-null portrait; Hero Detail modal portrait slot shows non-null portrait; 0 "black void" class portraits |

**Should Have total**: 2.5 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S23-N1 | **Audio MVP bootstrap.** Wire `AudioRouter` autoload (Godot 4.6 Node, singleton) + 1 ambient loop (guild_hall_ambient — silence or placeholder file if no real audio yet) that plays on `SceneManager.screen_changed` to `guild_hall` + 1 UI confirm cue (ui_confirm) emitted on every primary button press. Signal-driven per `design/gdd/audio-system.md`. Mutable via Settings screen S23-S2 audio sliders. | godot-gdscript-specialist | 1.5d | S23-M1, S23-M2, S23-M3, S23-S2 | AudioRouter autoload exists; guild_hall_ambient plays on Guild Hall screen transition; ui_confirm cue plays on primary button presses; both respect Settings volume sliders; no audio-thread errors in test run; 0 regressions on mute |
| S23-N2 | **Class Synergy V2 — passive synergy preview on Dispatch screen.** Pre-commit formation reads `ClassSynergySystem.compute_tier()` for the pending team composition and displays the predicted synergy tier (None / Bronze / Silver / Gold / Platinum) in the Dispatch screen's hero-slots zone, live-updating as heroes are added/removed. No commit required to see the preview — it's informational. | godot-gdscript-specialist | 2.0d | S23-M1, S23-M2, S23-M3, S23-N1 merged | Synergy tier label updates live on slot changes; matches `ClassSynergySystem.compute_tier()` output; no regression to active-roster synergy badge on Guild Hall; 0 new test failures |

**Nice to Have total**: 3.5 days

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S22-S2 Hall of Retired Heroes → tab | Sprint 22 Must Have capacity consumed by M1-M4 (4.75d); S2 didn't get headroom | 0.75d → **S23-M1** (promoted to Must Have per retro action #2) |
| S22-S3 Pause Menu modal | Same reason | 0.75d → **S23-M2** (promoted to Must Have per retro action #3) |
| S22-N1 Settings screen | Didn't land (no Should Have headroom in practice) | 1.0d → **S23-S2** (carried as Should Have) |
| S21-S2/S20-N1 ClassPortrait | Third carry — deferred twice as Nice to Have, dropped from S22 | 0.5d → **S23-S3** (promoted to Should Have per "3rd carry" process rule) |
| S22-M4 items c/d/e | Deferred pending playtest-14 signal | 1.0d → **S23-S1** (conditional: non-negotiable if playtest-14 PARTIAL/FAIL on c/d/e) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S23-M1 retire breaks 3 specific test locations the grep won't surface | MED | HIGH | See M1 explicit test update list in the task description: (1) E-01 count assertion (does NOT contain "hall_of_retired_heroes" as a string — update manually from 8 to 6), (2) E-04 expected_paths dict, (3) hall_render_test.gd preload. Also grep for `"hall_of_retired_heroes"` for any remaining string references. |
| S23-M2 Pause Modal breaks SceneManager stacking with MidRunReassignConfirmation | LOW | MED | Test explicitly: trigger Pause Modal from inside DRV while MidRunReassign is possible. Both modals should push/pop cleanly. If stacking is buggy, ship Pause Modal as a non-stacking single-modal (can't open Pause while a mid-run modal is active) — acceptable for MVP. |
| S23-S1 scope balloons when playtest-14 surfaces new gap categories | MED | MED | S1 is strictly scoped to the 3 deferred M4 items (c/d/e). Any NEW gap discovered in playtest-14 goes to Sprint 24 backlog — do not expand S1 mid-sprint. |
| AudioRouter autoload absent — N1 becomes "author autoload" as well as "wire signals" | LOW | LOW | If AudioRouter doesn't exist, step 1 of N1 is authoring the autoload. Not a blocker, just scope clarification. Grep `AudioRouter` before starting. |
| Sprint 23 scope is light enough that the team pads it with unplanned work | LOW | LOW | Stick to the plan. Lighter sprints recover velocity. N1+N2 (3.5d) are the legitimate expansion path. |

## Dependencies on External Factors

- **PR #126 (main_menu retire)**: must merge BEFORE S23-M1 begins. The hall_of_retired_heroes removal is the second step of the 10→7 consolidation; the main_menu removal (8→7 via #126) is the prerequisite registry claim.
- **playtest-14 verdict**: must be filled before S23-S1 begins. Playtest-14 scope is the 5 checks defined in the S22-M5 template; the S1 conditional is specifically items c/d/e.
- **Real product art**: Sprint 23 does NOT gate on real art. ClassPortrait (S23-S3) uses programmatic colored-block placeholders. Audio MVP (N1) uses placeholder or silence files. Both are swap-in when real assets arrive.

## Definition of Done for this Sprint

- [ ] PR #126 (main_menu retire) merged before M1 starts
- [ ] Hall of Retired Heroes as Active/Retired tabs on Guild Hall (M1) — registry at 6 entries (after PR #126 achieves 7); standalone screen deleted; 3 affected test locations updated
- [ ] Pause Menu modal wired on all player-facing screens via Esc key (M2)
- [ ] Visual playtest PASS on scenes touched by M1+M2 (M3) — using `production/playtests/_template-visual-playtest.md`
- [ ] Sprint 23 retro committed; sprint-status.yaml all Must Haves marked done
- [ ] M4 clarity follow-up (S1) — shipped if playtest-14 returns PARTIAL/FAIL on items c/d/e; deferred if all 5 PASS
- [ ] No S1 or S2 bugs; existing tests stay green; full suite re-run at M3 close
- [ ] Cumulative test count maintained; 0 regressions

## After Sprint 23

Sprint 24 candidates from the planning context:
- **Audio MVP continuation** (S23-N1 carry if not landed — per-biome ambient loop swaps)
- **Class Synergy V2** (S23-N2 carry if not landed — passive preview panel on Dispatch)
- **Onboarding first-session flow** (`design/gdd/onboarding-first-session.md` — first-time player sees Tutorial context, not bare Guild Hall)
- **Floor unlock system** (`design/gdd/floor-unlock-system.md` — progression gating; prerequisite for meaningful late-game pacing)
- **Real product art ingestion** (if art workstream ships an ETA)
