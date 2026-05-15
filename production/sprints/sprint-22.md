# Sprint 22 — 2026-05-15 to 2026-05-28 (10 working days)

> **Status: Day-0 plan authored 2026-05-15**, same-day close of Sprint 21.
> Ninth consecutive same-day-compressed sprint (Sprint 14→15→16→17→18→19→20→21→22).
> Solo review mode.

## Sprint Goal

**Reduce 10 scenes to 7 by collapsing the redundant ones, fold the matchup picker into Formation Assignment as a unified "Dispatch" screen, then run a clarity pass on every screen with the now-visible parchment theme.**

Sprint 21 closed under unusual circumstances: the dominant finding wasn't M1 or M2's correctness — it was that the parchment theme **had never reached any screen** since Sprint 10 due to `ScreenContainer` being declared `type="Node"` in `MainRoot.tscn`. Godot 4.6 theme inheritance walks only through `Control` ancestors; a plain `Node` intermediate silently broke the cascade. **5 sprints of accumulated theme work were functionally invisible to players.** PR #124 (the one-line fix) restored theme visibility; PR #123 (S21-M2 Recruit Screen polish) is now meaningful once #124 merges. The new question the user surfaced from the post-fix replay is: **"How many scenes do we need? How does the UI/UX flow work?"** — a strategic step back from per-screen polish to macro structure.

Sprint 22 answers both: consolidate the scene set to 7 (down from 10) by retiring `main_menu` (a Sprint 8 placeholder that became a redundant home), folding `matchup_assignment` into `formation_assignment` as a single "Dispatch" screen, and turning `hall_of_retired_heroes` into a tab on Guild Hall. In parallel, run a per-screen clarity pass: biome backgrounds on every screen (not just Guild Hall), explicit visual hierarchy, empty-state clarity, and label sizing.

**Definition of Sprint 22 success**:
(a) `main_menu` retired; run-end + boot route directly to Guild Hall; `_screen_registry` shrinks from 9 to 8 (then to 7 after matchup fold);
(b) `matchup_assignment` content folded into `formation_assignment` as a Dispatch screen with two zones (Hero Slots + Floor Picker); single screen handles both decisions;
(c) `hall_of_retired_heroes` content moved as a tab/sub-panel on Guild Hall (Active | Retired tabs);
(d) `pause_menu` modal scene exists (currently spec-only at `design/ux/pause-menu.md`);
(e) Biome backgrounds visible on Recruit, Dispatch, DRV, Victory, Return-to-App (currently only Guild Hall + DRV have them);
(f) Per-screen clarity pass: visual hierarchy, empty states, label sizing across all 7 final screens;
(g) Visual playtest validates the consolidated architecture reads clearer than the pre-Sprint-22 10-scene flow;
(h) Sprint 22 retro committed.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: Sprint 22 is the highest-scope sprint since Sprint 18. Mix of structural refactor (M1+M2 — scene tree changes + registry mutations) and per-screen polish (M3+M4 — visual application). The structural work is RISKY because it touches the run-end auto-route + tests that depend on screen IDs. Allow buffer for cascading test fixes. The per-screen polish is LOW risk (cosmetic, additive).

## Sprint 21 Retrospective (inline — Sprint 21 had no separate retro PR)

Sprint 21 was interrupted mid-flight by the theme-inheritance discovery; its formal retro folds into Sprint 22 setup rather than getting its own PR.

### What worked (Sprint 21)

- **S21-M1 ship as code-level success** (PR #122 + #122-fixup) — Formation Assignment SlotButton/SlotButtonSelected + LedgerRow ROW theme variations shipped cleanly. 6 contract tests pass. Code is correct.
- **S21-M2 ship as code-level success** (PR #123 — STILL OPEN) — Recruit Screen Affordability Gating + Cross-Fade Refresh + LedgerRowPanel infrastructure. 7 contract tests pass. Code is correct.
- **The playtest gate caught the silent failure** — visual playtest after S21-M2 was the moment the theme-never-visible bug surfaced. Without playtest, the bug could have shipped to Sprint 25+. Per project memory `feedback_playtest_driven_closure.md` — the gate works as designed.
- **Root cause investigation took 30 minutes** — empirical contract test + scene-tree inspection. The discipline of "test, don't speculate" delivered.
- **One-line fix scoped correctly** (PR #124) — the fix didn't expand into a larger refactor. Ship the unblocker; iterate on what becomes visible.

### What hurt (Sprint 21)

- **5 sprints of theme work were functionally invisible.** Sprint 10's parchment_theme, Sprint 18's tilt-shift, Sprint 19's BiomeBackground, Sprint 20's DESIGN.md + LedgerRow + SynergyBadge, Sprint 21's SlotButton — ALL invisible to players. The bug class is the most expensive scaffolded-but-unwired pattern the project has experienced.
- **No contract test caught the theme inheritance breakage** until 2026-05-15. The S20-M5 Guild Hall theme tests asserted the theme variation EXISTED in parchment_theme.tres, but NOT that the variation actually rendered at runtime on a screen-under-SceneManager. Future contract tests need to assert end-to-end visual property reads, not just resource file structure.
- **The "playtest verdict was a one-liner" gap surfaced AGAIN** (third sprint: S19-M5 → S20-M6 → S21-M3). Each time the verdict was "looks good" or "demo quality" without per-check granularity. The Sprint 21-S1 carry-forward (visual-correctness playtest checklist template) — fourth-time carry now — is the warning sign.
- **PR #123 entered limbo for the entire fix cycle.** When the bug was discovered, #123 was open with code that depended on theme being visible. The decision tree (merge now? close? rebase?) added cognitive overhead during the urgent fix.

### Sprint 22 actions from Sprint 21 retro

| # | Action | Priority | Where |
|---|--------|----------|-------|
| 1 | Theme-inheritance contract test as project-wide regression guard | DONE | PR #124 ships this |
| 2 | Visual-correctness playtest checklist template — FOURTH-time carry (S19→S20→S21→S22) | HIGH | S22-S1 (Sprint 22 Should Have, non-negotiable) |
| 3 | End-to-end visual contract tests: every screen should assert a sample Button reads parchment colors at runtime | MED | Folded into S22 per-screen clarity work (M4) |
| 4 | PR disposition discipline — when a long-running PR sits OPEN during an emergency fix, decide explicitly: merge / rebase / close. Don't leave in limbo | LOW | Process note for Sprint 22+ |

## Pre-Plan Disposition (handle these BEFORE Sprint 22 M1 starts)

| PR | Status | Action |
|----|--------|--------|
| #124 (theme inheritance fix) | OPEN, CI green, **prerequisite for everything below** | **MERGE FIRST** — unblocks all Sprint 22 work |
| #123 (S21-M2 Recruit Screen polish) | OPEN, CI green, code is correct | **MERGE after #124** so Affordability Gating is visible on current Recruit screen until S22-M2 refactors it into Dispatch |

After both merge: Sprint 21 effectively closes with M1+M2 DONE (delayed but in-tree). S21-M3 (visual playtest) gets re-run in Sprint 22 as M5 playtest gate. S21-M4 (retro) is fulfilled by the inline retro section above.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|--------------|-------------------|
| S22-M1 | **Retire main_menu screen.** Reroute `dungeon_run_view` RUN_ENDED auto-route from `main_menu` → `guild_hall`. Migrate the Redispatch shortcut button to Guild Hall. Remove `main_menu` from `SceneManager._screen_registry`. Delete `assets/screens/main_menu/` files. Update any tests referencing `main_menu` screen ID. | godot-gdscript-specialist | 0.75d | (#124 merged) | `request_screen("main_menu")` returns no longer valid; Guild Hall has Redispatch button visible when `last_dispatch_intent` non-empty; all existing tests pass after rewire |
| S22-M2 | **Fold matchup_assignment into formation_assignment as "Dispatch" screen.** Add a Floor Picker zone to `formation_assignment.tscn` (collapsible panel or inline strip with 6 biomes × 5 floors); remove the separate matchup_assignment screen; reroute the "Change Floor" button to expand/scroll within the same screen. Remove `matchup_assignment` from `SceneManager._screen_registry`. Migrate the matchup_assignment.gd logic into formation_assignment.gd. | godot-gdscript-specialist | 1.5d | M1 | Single Dispatch screen handles both team + floor selection; player can dispatch in one screen without nav; existing matchup-assignment tests migrated to assertions on formation_assignment's new Floor Picker zone; UX-MA-* ACs satisfied by formation_assignment |
| S22-M3 | **Wire BiomeBackground onto every screen.** Currently only `guild_hall.tscn` + `dungeon_run_view.tscn` instance the BiomeBackground scene. Add to `recruitment.tscn`, `formation_assignment.tscn` (post-M2 — Dispatch), `victory_moment.tscn`, `return_to_app.tscn`, `hero_detail.tscn` (modal — biome via current run if any). Each screen pulls its biome ID from current run (if active) or "tavern" default. | godot-gdscript-specialist | 0.5d | (#124 merged) | All 7 final screens render with a biome-tinted BiomeBackground; no pure black backgrounds; existing layer-order contract preserved (BG z=-1) |
| S22-M4 | **Per-screen clarity polish — visual hierarchy, empty states, label sizing.** Walk every screen and address: (a) GoldCounter visibility on all screens, not just Guild Hall + Recruit; (b) screen header IdentityHeader Label on every screen (currently inconsistent); (c) clear "Empty" state placeholders with descriptive copy + icon hints; (d) tap target dimensions ≥44×44 verified; (e) primary CTAs use Primary Button pattern, not unstyled Button. | godot-gdscript-specialist | 1.5d | M1+M2+M3 | Each screen has: visible header label using IdentityHeader variation; visible GoldCounter where relevant; descriptive empty states; tap targets verified; primary CTAs use pattern #1 |
| S22-M5 | **Sprint 22 visual playtest + retro.** Use the playtest-checklist template (S22-S1) to grade each of the 7 final screens against clarity criteria: typography reads; palette visible; biome background reinforces context; empty states clear; tap targets adequate; primary CTAs unambiguous; nav from any screen to any other is ≤2 taps. Retro doc + sprint-status.yaml closed. | xiaolei (human) + producer + claude-code | 0.5d | M1+M2+M3+M4 | playtest-14 doc committed with verdict on all 7 screens; sprint-22 retrospective committed; sprint-status.yaml all Must Haves marked done |

**Must Have total**: 4.75 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S22-S1 | **Visual-correctness playtest checklist template** — fourth-time carry from S19 retro #5 → S20 retro #6 → S21 retro action #2. Author `production/playtests/_template-visual-playtest.md` that asks "PASS/FAIL per check" rather than aggregate sign-off. Used by M5 playtest gate. **Non-negotiable this sprint** — fourth-time carry is the warning sign. | claude-code | 0.1d | none | Template committed; references playtest-11 (S19) + playtest-12 (S20) + (failed-to-author) playtest-13 (S21) as prior art; used as the M5 playtest verdict format |
| S22-S2 | **Hall of Retired Heroes → tab on Guild Hall.** Currently a separate screen reachable via a Guild Hall button. Migrate the content as a tab on Guild Hall's RosterPanel: "Active" tab (current roster) + "Retired" tab (Hall of Retired Heroes content). Remove the standalone screen + the Hall of Retired Heroes nav button. | godot-gdscript-specialist | 0.75d | M1 | Tab strip on Guild Hall RosterPanel; "Retired" tab shows retired heroes; `hall_of_retired_heroes` screen removed from registry |
| S22-S3 | **Pause Menu modal scene.** Currently `design/ux/pause-menu.md` exists as spec but no scene. Author the modal: Esc-key trigger; Resume / Settings (placeholder) / Quit-to-Guild-Hall options. SceneManager.push_modal pattern. | godot-gdscript-specialist | 0.75d | none | Modal scene at `assets/screens/_modals/pause_menu.tscn`; UX-PM-* ACs satisfied; Esc-key listener wired on every screen |

**Should Have total**: 1.6 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S22-N1 | **Settings screen scaffold.** Sprint 8 hotfix's main_menu placeholder gestured at a real settings/quit screen. Build a real one: audio sliders + accessibility toggles (reduce motion, etc.) + version display + Quit button. Replaces the function that placeholder main_menu was pretending to serve. Pulls in only if M+S complete with playtest headroom. | godot-gdscript-specialist | 1.0d | M+S done | Settings screen at `assets/screens/settings/`; basic audio + accessibility controls; modal-style with back-to-Guild-Hall |

**Nice to Have total**: 1.0 days

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S21-M1 Formation Assignment theme | DONE (PR #122 merged) — no carryover | n/a |
| S21-M2 Recruit Screen theme | PR #123 OPEN — recommend merge before S22 work begins (pre-plan disposition above) | n/a (handled as pre-plan) |
| S21-M3 Visual playtest | Effectively REPLACED by S22-M5 playtest (against the consolidated architecture) | folded |
| S21-M4 Retro | Inline retro section above | folded |
| S21-S1 Playtest checklist template | Fourth-time carry → S22-S1 (non-negotiable) | 0.1d |
| S21-S2 ClassPortrait placeholder art | Defer to Sprint 23 — visible polish, not clarity-essential | dropped from S22 |
| S21-N1 Proactive pattern application | Defer — Sprint 22's M2 + M4 supersede the need | dropped from S22 |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| M2 (matchup fold into formation) breaks Run dispatch flow | MED | HIGH | Run the full test suite after M2; matchup_assignment integration tests should migrate to formation_assignment assertions — explicit migration not deletion. If a state-machine path breaks, REVERT M2 and ship matchup_assignment as a separate screen still (M2 becomes deferred). Don't merge unsafe. |
| M1 (main_menu retirement) leaves a dangling state for tests that hardcode "main_menu" screen ID | MED | MED | Grep for `"main_menu"` across the codebase BEFORE deletion; update or remove every reference; CI catches what grep misses. |
| Biome backgrounds on every screen (M3) regresses performance | LOW | LOW | BiomeBackground is a programmatic gradient — zero texture cost. Per-frame cost is negligible. Profile before/after only if M3 visibly drops fps. |
| Visual playtest verdict on consolidated architecture is REJECT | LOW-MED | MED | The consolidation is reversible. If playtest signals "this is worse than before," revert M1+M2 in Sprint 23 and pivot to the "minimal consolidation" option. The clarity pass (M3+M4) stays regardless. |
| Sprint 22 scope is genuinely too big (5 Must Haves + 3 Should Haves + 1 Nice = 9 items) | MED | MED | Strict prioritization: Must Haves first; Should Haves only if Must Haves done with headroom; Nice to Have only if S1+S2+S3 done. The "merged. move on" cadence will surface this naturally. |

## Dependencies on External Factors

- **PR #124 (theme inheritance fix)**: must merge BEFORE M3+M4 start because biome backgrounds + clarity polish are only meaningful with theme actually rendering. Recommend merging immediately on Sprint 22 PR approval.
- **PR #123 (S21-M2 Recruit Screen polish)**: should merge BEFORE M2 (Dispatch consolidation) since M2 will refactor the Recruit Screen; the Affordability Gating + Cross-Fade work is preserved as part of the refactor. If not merged, the work needs re-implementation as part of M2 — preventable cost.
- **Real product art**: Sprint 22 does NOT gate on real art. All clarity work uses parchment palette + IM Fell English / Lora fonts; real art swaps in zero-code when it arrives.

## Definition of Done for this Sprint

- [ ] PRs #123 + #124 merged BEFORE M1 starts
- [ ] main_menu retired; run-end + boot route to Guild Hall (M1)
- [ ] matchup_assignment folded into formation_assignment as Dispatch (M2)
- [ ] BiomeBackground visible on every screen (M3)
- [ ] Per-screen clarity polish applied to all 7 final screens (M4)
- [ ] Visual playtest PASS on all 7 final screens (M5) — using S22-S1 checklist template
- [ ] Sprint 22 retro committed; sprint-status.yaml all Must Haves marked done
- [ ] Visual-correctness playtest checklist template committed (S1) — fourth-time carry retired
- [ ] No S1 or S2 bugs; existing tests stay green
- [ ] Cumulative test count maintained (4474+ PASS); 0 regressions

## After Sprint 22

Sprint 23 candidates from the planning context:
- **Settings screen** (S22-N1 carry if not landed)
- **ClassPortrait placeholder art** (S21-S2 carry)
- **Real product art ingestion** (if user's separate workstream lands an ETA)
- **Audio direction pass** (sound design quiet for several sprints; visual side now mature)
- **Class Synergy V2 — passive synergy preview** (Sprint 16+ candidate; broader than current S18 active-synergy badge)
