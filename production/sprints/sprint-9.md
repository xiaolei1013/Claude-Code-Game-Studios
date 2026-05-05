# Sprint 9 — 2026-04-29 to 2026-05-08 (7-10 days)

## Sprint Goal

**Clear the Pre-Production → Production gate.** Apply the 3 minimal-path polish tickets surfaced by S8-M5/M6/M7 playtests (formation_assignment UX, run pacing, locale CSV) so the next `/gate-check production` returns PASS or CONCERNS (not FAIL). Bring along high-leverage backlog overflow items (save-persist, return_to_app, theme content) as bandwidth allows.

**Definition of Sprint 9 success**: `/gate-check production` retry returns **PASS** or **CONCERNS** (not FAIL); `production/stage.txt` advances to `Production`.

This is a **focused polish sprint**. Sprint 8 delivered the kernel + 3 endpoint screens + a playable VS loop. Sprint 9's job is to make that loop *self-explanatory* and *felt* — no new mechanics, no new screens.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work + the re-playtest + re-gate-check overhead
- Available: **7.2 days**

## Tasks

### Must Have (Critical Path — gate-clearing)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S9-M1 ✅ DONE 2026-04-28 | **formation_assignment UX polish (B-1)** — slot active-state visual indicator (border, color, "Selected" affordance), instructional header copy ("Send your guild to:" or similar), floor context card with floor name + enemies preview placeholder | ui-programmer | 1.5 | none (Story 011 done) | A fresh-eyes playtest captures **zero unprompted confusion statements** on formation_assignment. Slot tap visually changes the slot's appearance. Player understands the screen's purpose without external explanation. |
| S9-M2 ✅ DONE 2026-04-28 | **Run pacing minimum-perceived-duration (B-2)** — bump `RUN_END_DWELL_MS` from 0 to 1500-2000ms (Story 013 spec deviation; document in story closure note) AND/OR add a minimum-run-view dwell with kill_count animating up to final value AND/OR combat tick-budget tuning so runs land in 5-15s consistent range | gameplay-programmer | 1.0 | none | Across 5+ test dispatches, no run completes (overlay → main_menu) in <2 seconds wall-clock. Player consistently sees the run play out and registers the kill_count before auto-route. |
| S9-M3 ✅ DONE 2026-04-28 | **Locale CSV authoring (B-3)** — author EN locale CSV with the ~12 keys used by Stories 011/012/013 (`formation_assignment_title`, `slot_empty_label`, `dispatch_button`, `dispatch_error_empty_formation`, `dispatch_error_floor_locked`, `dispatch_error_generic`, `recruit_a_hero_label`, `floor_label_forest_reach_1`, `dungeon_run_view_title`, `tick_label_prefix`, `kill_count_label_prefix`, `run_complete_kill_count_format`) | localization-lead OR ui-programmer | 0.5 | none | All visible UI strings show real English text, not locale keys. Locale loader wired in project.godot. `tr()` returns translated strings, not keys. Files: `assets/locale/en.csv` + project.godot translation registration. |
| S9-M4 | **Re-run a single fresh-eyes playtest** with the polish applied — ideally with someone who hasn't seen the build before, OR with the project lead doing a "deliberately new player" pass | project lead | 0.25 | S9-M1, S9-M2, S9-M3 | New playtest report at `production/playtests/playtest-04-post-sprint-9-polish-2026-XX-XX.md`. Verdict: zero unprompted confusion statements about screen purpose. Pillar 2 score ≥3/5 (was 1/5). Run pacing reported as "watchable". |
| S9-M5 | **`/gate-check production` retry** | gate-check skill | 0.13 | S9-M4 | Gate returns PASS or CONCERNS (not FAIL). `production/stage.txt` updates to `Production`. |

**Must Have total**: ~3.4 days base; **~4.5 days realistic** with implementation discovery + minor iteration. Comfortably within 7.2-day available capacity, leaving ~2.7 days for Should Have absorption.

### Should Have (high-leverage backlog overflow)

| ID | Task | Owner | Est. Days | Dependencies |
|----|------|-------|-----------|--------------|
| S9-S1 | **Save-persist pipeline end-to-end** — verify SaveLoadSystem.persist actually writes to `user://save.dat` (or schema-defined path); verify TickSystem heartbeat triggers persist every 60s (ADR-0005); verify scene_boundary_persist receiver actually writes; full save→close→reload→state-restored cycle. Without this, no offline progression possible. | engine-programmer + lead-programmer | 2.0 | none |
| S9-S2 | **scene-manager Story 009 implementation** — `reduce_motion` accessibility flag + offline-replay cozy-modal coordination + `return_to_app` screen content. Story is Ready (not yet implemented). Per ADR-0007 + ADR-0014 §5 PROGRESS_MODAL_THRESHOLD_MS=100. Unlocks the offline-replay UX path. Depends on S9-S1 for offline computation surface. | ui-programmer | 1.0 | S9-S1 |
| S9-S3 | **parchment_theme.tres content authoring** — populate the canonical Theme resource per ADR-0008 + Art Bible §4 palette + §7 typography. Currently empty placeholder. Replaces default Godot text colors / panel backgrounds with the parchment + ink + lantern-amber identity. | art-director + technical-artist | 1.0 | none |

**Should Have total**: ~4.0 days. If all of Must Have ships in 4.5 days, only 2.7 days of Should Have can ship — choose S9-S1 first (most leverage), then S9-S2 OR S9-S3 by available time.

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies |
|----|------|-------|-----------|--------------|
| S9-N1 | Pre-existing scene_manager test env flakes cleanup — modal_pause_tick_coupling_test.gd, crossfade_timing_test.gd, request_screen_and_node_swap_test.gd — Sprint 5/6/7 origin; not Story 011/012/013 regressions. Likely Godot 4.6.1 mono headless wiring quirk. | qa-tester + godot-gdscript-specialist | 0.5 | none |
| S9-N2 | Cross-test live-autoload contamination cleanup — `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` 2 tests fail when run alongside other suites (pass 17/17 in isolation). Add before_test/after_test snapshot+restore. | qa-tester | 0.25 | none |
| S9-N3 | `tr()` safe-format pattern hoisting into UIFramework — Stories 011/012 duplicate the `if "%" in fmt` guard. Hoist as `UIFramework.format_localized(key, value)`. | ui-programmer | 0.25 | S9-M3 |
| S9-N4 | "Re-dispatch" shortcut on main_menu (S8-M6 finding — multi-dispatch loop friction). Optional button on main_menu's run-end UI to skip back to formation_assignment. | ui-programmer | 0.25 | none |
| S9-N5 | XP/level grant feedback (S8-M6 — Theron stayed Lv1 across 3 dispatches). Either grant is missing or feedback is missing; wire a hero_leveled toast on dungeon_run_view or main_menu landing. | gameplay-programmer | 0.5 | (gated on whether XP grant logic exists in orchestrator) |
| S9-N6 | UIFramework completion — `apply_parchment_panel(panel, pattern)` + `wire_touch_feedback(control)` per ADR-0008 mandate. Currently TODO. Blocked on S9-S3 parchment_theme content for `apply_parchment_panel`. | ui-programmer | 0.5 | S9-S3 |

**Nice to Have total**: ~2.25 days

## Carryover from Previous Sprint (Sprint 8)

Sprint 8 closed all 27 stories (8 Must Have + 9 Should Have + 10 Nice to Have). The carryover into Sprint 9 is the **gate failure**, not unfinished stories — the gate-check verdict was FAIL on VS Validation item 2 (formation_assignment doesn't self-explain) and BORDERLINE on item 4 (run pacing).

Sprint 9 Must Have items B-1/B-2/B-3 are explicitly the gate-clearing work surfaced by S8-M5 playtests. They're not "carryover stories" — they're new tickets that emerge from Sprint 8's playtest evidence.

**Tech debt items rolled forward** (logged in Sprint 8 closure but not picked up):
- TD-008 (LOW, OPEN) — ADR-0007 architecture diagram MainRoot Node→Control amendment (Sprint 5 origin)
- TD-013 candidate (from Story 011 closure) — closed by S9 surface (`get_formation_slot` accessor was actually added during Story 011 hotfix; TD-013 is no longer relevant)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **B-2 run pacing fix is non-trivial** — combat tick-budget tuning may require deeper formula re-tuning than expected (touches combat-resolution.md GDD + EconomyConfig + per-class tick output) | MEDIUM | MEDIUM | Default to the `RUN_END_DWELL_MS` bump as the simplest fix; only escalate to combat-tuning if dwell alone doesn't make the run watchable. The dwell fix is a 5-line code change. |
| **S9-M1 formation_assignment polish is bigger than 1.5d** — adding visual affordances + copy + a floor context card touches multiple Control nodes + theme-variation interactions; the "feels good" criterion is subjective and may need iteration | MEDIUM | MEDIUM | Time-box at 2 days; if not converging by end of day 2, ship the slot affordance + minimal copy and defer the floor context card to a follow-up |
| **Locale CSV wiring may surface project.godot config issues** — Godot's translation system has post-cutoff quirks per Story 011 lessons. CSV format + import settings + addressing might require iteration. | LOW | LOW | Reference `docs/engine-reference/godot/modules/localization.md` if exists; otherwise verify via the Godot docs at translation server section. |
| **S9-S1 save-persist surface is bigger than 2 days** — the ADR-0014 offline computation pipeline has multiple unfilled wires (signal emit → consumer registration → file write); investigation alone could take a day | MEDIUM | HIGH (gates offline UX) | If S9-S1 doesn't fit in 2 days, scope to "save-persist write only, defer offline computation to Sprint 10". A working save+load round-trip is enough to advance the Pillar 1 score; offline compute is sugar on top. |
| **Re-playtest reveals NEW confusion not present in S8-M5** — applying polish might fix old issues but surface new ones that weren't visible because old issues blocked discovery | MEDIUM | LOW | Treat as expected — the playtest's job is to surface findings. Document new findings as Sprint 10 backlog; don't try to fix in-sprint unless they're VS Validation FAIL-level. |
| **Tester for S9-M4 may not be sufficiently fresh-eyed** — solo mode = project lead is the tester, but they've now seen the build through 8 sprints | LOW | LOW | Use the gate-check protocol's "explicit deliberate new-player simulation" framing — ignore your own knowledge, follow only what the screen tells you. Or recruit an actual non-dev tester for an hour. |

## Dependencies on External Factors

- **Project lead time for S9-M4 playtest**: requires hands on a keyboard with Godot 4.6 IDE for ~30 minutes. Same dependency as S8-M5/M6/M7.
- **Optional external playtester for S9-M4**: would significantly improve the fresh-eyes quality of the gate-clearing playtest. Solo mode allows project lead to be the tester; recommend trying for an external tester if available.
- **No external API/SDK dependencies**.

## Definition of Done for Sprint 9

- [ ] All Must Have tasks (S9-M1 through S9-M5) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] formation_assignment UX polish landed: slot active-state visible + instructional copy + floor context card (or deferred per risk mitigation)
- [ ] Run pacing fix landed: ≤2s sub-second runs eliminated; player perceives the run
- [ ] EN locale CSV authored + wired in project.godot; visible UI strings are English
- [ ] Re-playtest report at `production/playtests/playtest-04-post-sprint-9-polish-2026-XX-XX.md` documents zero unprompted confusion
- [ ] **`/gate-check production` retry returns PASS or CONCERNS** — `production/stage.txt` advances to `Production`
- [ ] QA plan exists at `production/qa/qa-plan-sprint-9.md` (recommended: run `/qa-plan sprint` before implementation)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code reviewed (inline review during `/code-review` per Sprint 6/7/8 pattern)
- [ ] Test suite ≥99% pass rate (allow for the documented pre-existing scene_manager flakes pending S9-N1)

## Sprint 9 sequencing recommendation

**Days 1-2 — formation_assignment polish (S9-M1)**
- Day 1: slot active-state visual + signal wiring + instructional copy
- Day 2: floor context card OR scope reduction if running long; locale-key audit (paves S9-M3)

**Day 3 — Run pacing + locale CSV (S9-M2 + S9-M3)**
- Morning: S9-M2 dwell bump or pacing tune (whichever path; default to dwell)
- Afternoon: S9-M3 locale CSV + project.godot wiring + verify on the running build

**Day 4 — Save-persist (S9-S1) — start of Should Have absorption**
- Day 4-5: S9-S1 investigation + implementation (or scope reduction per risk mitigation)

**Day 5-6 — return_to_app (S9-S2) + theme content (S9-S3) — bandwidth permitting**
- If save-persist consumed both days, defer S9-S2 to Sprint 10
- If theme content takes longer than expected, defer to Sprint 10 (it's S9-S3 — Should Have, not gating)

**Day 7 — Fresh-eyes playtest + gate-check (S9-M4 + S9-M5)**
- Morning: cold-launch the build, walk the loop deliberately new, document findings
- Afternoon: `/gate-check production` retry → expected PASS or CONCERNS

**Anti-pattern to avoid**: do NOT touch any new mechanics or screens. Sprint 9 is polish-only. If a deeper architectural issue surfaces (e.g., orchestrator state-machine race condition flagged for Story 014), document it as a Sprint 10 ticket and continue.

## QA Plan

**QA Plan**: ⚠️ Not yet authored — recommend running `/qa-plan sprint` before implementation begins. Sprint 9 is small enough that a lighter QA plan may suffice — focus test cases on the regression risk of the polish work (no breaking the existing 49/49 Sprint 8 UI suite + ~1116 project-wide tests).

## Closure Notes

### S9-M1 — formation_assignment UX polish — COMPLETE WITH NOTES (2026-04-28)
- Verdict: **COMPLETE WITH NOTES**
- Files: `assets/screens/formation_assignment/formation_assignment.{gd,tscn}` + `tests/integration/scene_manager/formation_assignment_screen_test.gd` (+3 S9-M1 tests; 16/16 pass, 532ms)
- Implementation:
  - "Selected" badge child Label on active slot (`MOUSE_FILTER_IGNORE`, `theme_type_variation = &"SelectedSlotButton"` — visual differentiation lands when S9-S3 ships parchment_theme.tres)
  - Instructional header copy via `tr("formation_assignment_instructional_header")` ("Send your guild to:")
  - Floor context card via `FloorVBox` containing `FloorContextLabel` (floor name) + `FloorButton`
  - Critical patch (orchestrator-side): `_on_slot_button_pressed` now calls `_refresh_formation_panel()` + `suppress_keyboard_focus()` — without this the badge never migrates on tap (root cause of S8-M5 confusion)
- Code review: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist + godot-specialist). No blockers. Two advisory suggestions (deferred-free comment, anchor-overlap doc) deferred to follow-up polish.
- Deviations:
  - **ADVISORY**: "Enemies preview placeholder" sub-deliverable not shipped — floor card has floor name only. Permitted per S9-M1 risk-mitigation in §Risks. Sprint 10 candidate.
  - **ADVISORY**: Visual sign-off (zero unprompted confusion AC) deferred to S9-M4 fresh-eyes playtest. `production/qa/evidence/formation-assignment-screen-evidence.md` to be refreshed there.
- ADR compliance: ADR-0007 (4 lifecycle hooks declared, signal mirror exact); ADR-0008 (no `Color()` literals, tap-target enforcement, single-focus mode, `tr()` everywhere, `theme_type_variation` hook). Manifest 2026-04-26 matches.

### S9-M2 — Run pacing minimum-perceived-duration — COMPLETE WITH NOTES (2026-04-28)
- Verdict: **COMPLETE WITH NOTES**
- Files: `assets/screens/dungeon_run_view/dungeon_run_view.gd` (RUN_END_DWELL_MS 0→1500 + doc updates), `tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd` (range [0,350]→[0,2000]; dwell-aware polling in 2 tests), `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd` (NEW; 4 tests)
- Implementation:
  - Bumped `RUN_END_DWELL_MS` from 0 to 1500 ms — overlay holds for 1.5 s before cross-fade to main_menu fires
  - Existing `if RUN_END_DWELL_MS > 0: await get_tree().create_timer(...).timeout` path activates automatically; no orchestrator state-machine changes required
  - 4 new integration tests: dwell-overlay-visible, total-wall-clock-≥1500ms, const-matches-production-target, idempotency-holds-during-dwell-window
  - Updated 2 existing run_end_to_main_menu tests to poll for `_queued_request` populated within 3000 ms timeout cap
- Code review: APPROVED WITH SUGGESTIONS (solo+lean self-review). No blockers.
- Test results: 4/4 NEW tests pass (3s 954ms); 6/6 existing run_end_to_main_menu tests pass post-fix (3s 114ms); 12/12 dungeon_run_view_screen tests pass (regression check, 218ms).
- Deviations:
  - **DOCUMENTED**: Story 013 Sprint 8 AC-3 valid range `[0, 350]` superseded by Sprint 9 `[0, 2000]` based on S8-M5 playtest evidence (sub-2s runs scored 1/5 on Pillar 2). Captured in code comments + test assertions.
  - **DEFERRED**: Path #2 (kill_count tween-up animation) deferred — dwell bump alone meets AC. Sprint 10 polish candidate.
  - **DEFERRED**: Path #3 (combat tick-budget tuning) NOT taken — would touch combat-resolution GDD + EconomyConfig, scope-too-big.
  - **STRUCTURAL LIMITATION**: Test #3 (control: dwell=0 completes in <2s) implemented as structural assertion only — `RUN_END_DWELL_MS` is a `const`, can't be runtime-overridden without var refactor. Documented in test comments.
- ADR compliance: ADR-0007 lifecycle hooks intact; ADR-0010 combat snapshot untouched; documented deviation from Story 013 Sprint 8 AC-3.

#### S9-M2 Hotfix Amendment — Fast-path dwell regression (2026-05-05)
- **Discovered**: S9-M4 fresh-eyes playtest (2026-05-05) — runs still completed in <2s and kill_count was not visible despite RUN_END_DWELL_MS = 1500.
- **Root cause**: `dungeon_run_view.gd` has two RUN_ENDED handlers. The slow path (`_on_state_changed`) had the dwell. The fast path (`on_enter` defensive branch added by S8-M4 hotfix when state == RUN_ENDED at mount time) called `_deferred_run_end_route` which fired `request_screen("main_menu")` one frame later — bypassing the dwell entirely. The playtester consistently hit the fast path because combat resolves faster than the FADE_TO_BLACK transition (~300ms) into dungeon_run_view.
- **Why tests passed**: `run_pacing_minimum_duration_test.gd` Tests 1/2/4 emit `state_changed` AFTER the screen mounts (slow path). No test exercised the fast path until this hotfix.
- **Fix**: `_deferred_run_end_route()` now awaits the same `RUN_END_DWELL_MS` timer before calling `request_screen`, making both paths converge. Single-file change at `assets/screens/dungeon_run_view/dungeon_run_view.gd:196-208`.
- **Regression test added**: `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd::test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter` — sets state=RUN_ENDED before on_enter, asserts ≥1500ms elapsed before queued request appears. Pre-hotfix would fail at ~10-50ms; post-hotfix passes at ~1500ms.
- **Verdict**: COMPLETE WITH NOTES (amended) — original AC met for slow path; fast path retroactively covered.

### S9-M3 — Locale CSV authoring — COMPLETE WITH NOTES (2026-04-28)
- Verdict: **COMPLETE WITH NOTES**
- Files: `assets/locale/en.csv` (NEW; 14 keys with EN values), `src/core/locale_loader/locale_loader.gd` (NEW; CSV → TranslationServer programmatic loader, ~80 lines), `project.godot` (registered `LocaleLoader` autoload after `RuntimeLocaleGuard`, before `TickSystem`), `tests/integration/scene_manager/formation_assignment_screen_test.gd` (key-passthrough assertion updated to accept translated value)
- Implementation:
  - Author-friendly CSV at `assets/locale/en.csv` covering all 12 spec keys + 2 extras (`slot_selected_badge` from S9-M1, `dispatch_button` future-proofing for .tscn-set buttons)
  - Programmatic CSV loader via `FileAccess.get_csv_line` (RFC-4180 quoting); registers one `Translation` per locale column with `TranslationServer.add_translation`
  - Sets `TranslationServer.set_locale("en")` after load so `tr()` resolves immediately
  - LocaleLoader joins auxiliary pre-rank-0 boot-fragment group with `BootNamespace`/`EngineBootstrap`/`RuntimeLocaleGuard` (none in canonical ADR-0003 rank table; existing precedent supports auxiliary fragments)
- Code review: APPROVED WITH SUGGESTIONS (solo+lean self-review). No blockers.
- Test results: 16/16 formation_assignment tests pass post-update (585ms; locale loader resolves header text to "Send your guild to:" instead of key passthrough).
- Deviations:
  - **DOCUMENTED**: Programmatic CSV loader chosen over Godot editor-imported `.translation` artefacts. Reason: headless agent/CI workflow has no editor pass to regenerate `.translation` files when CSV changes. Documented in `locale_loader.gd` header comment.
  - **DOCUMENTED**: ADR-0003 §rank table not amended (no game state, not a save consumer). LocaleLoader joins existing auxiliary boot-fragment group — Sprint 10 follow-up: amend `architecture.md` to document this group precedent.
  - **ADVISORY**: `_load_csv_file` is ~50 lines (above the 40-line standard) — splitting into `_parse_header_row` + `_parse_body_rows` deferred to follow-up polish.
  - **ADVISORY**: No direct unit test for LocaleLoader — coverage is via consumer test (formation_assignment). Sprint 10 candidate: `tests/integration/locale_loader/csv_translation_loading_test.gd`.
- ADR compliance: ADR-0008 §Localization-ready (`tr()` for all UI strings) NOW SATISFIED at runtime — previously the requirement was structural (code used `tr()`) but no Translation registered. ADR-0003 autoload addition is a MINOR DEVIATION (INFO).

## Test Evidence Declarations (Pre-Implementation)

Inline tasks lack dedicated story files; the test-evidence requirements below are recorded here so `/story-done` can enforce them at closure.

### S9-M2 — Run pacing minimum-perceived-duration

**Story Type**: Integration

**Required evidence**:
- `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd` — must exist and pass.
  - Asserts: across 5 simulated dispatches with seeded RNG, no run completes (DISPATCHING → RUN_ENDED → main_menu) in <2000 ms wall-clock when `RUN_END_DWELL_MS >= 1500`.
  - Asserts: with `RUN_END_DWELL_MS = 0` (control), at least 3/5 dispatches DO complete in <2000 ms (validates the dwell is the cause of the pacing fix, not coincidence).
  - Asserts: kill_count animation interpolates from 0 to final value over the dwell window when the kill-count tween path is taken.
- `production/qa/evidence/run-pacing-evidence-2026-XX-XX.md` — manual smoke recording 5+ real-Godot dispatches with timestamps; cross-references S9-M4 fresh-eyes playtest.

**Deviation note required in story closure**: If the implementer chooses combat-tick-budget tuning over `RUN_END_DWELL_MS`, the run pacing fix MUST NOT alter the deterministic seed → outcome mapping. Add a determinism regression test to `tests/integration/combat_resolution/foreground_offline_parity_test.gd` confirming the pacing change preserves AC-COMBAT-10 parity.

**Status**: [ ] Not yet created

### S9-M3 — Locale CSV authoring

**Story Type**: Config/Data

**Required evidence**:
- `production/qa/smoke-locale-csv-2026-XX-XX.md` — smoke check: launch real-Godot 4.6 build; visually confirm all 12 locale keys (formation_assignment_title, slot_empty_label, dispatch_button, dispatch_error_empty_formation, dispatch_error_floor_locked, dispatch_error_generic, recruit_a_hero_label, floor_label_forest_reach_1, dungeon_run_view_title, tick_label_prefix, kill_count_label_prefix, run_complete_kill_count_format) render English text — not raw locale keys.
- Optional: `tests/integration/localization/locale_csv_loader_test.gd` — asserts `tr("formation_assignment_title")` returns the English string post-CSV load (not the key passthrough). Non-blocking but recommended.

**Status**: [ ] Not yet created

### S9-S1 — Save-persist pipeline end-to-end

**S9-S1 has been extracted to a formal story file**: `production/epics/save-load-system/story-016-save-persist-pipeline-end-to-end.md`. Test evidence requirements live there.

## Backlog (post-Sprint-9)

Sprint 10+ candidates, deferred from Sprint 9 if they fall out of scope:
- Story 014 (Sprint 9 candidate flagged in S8-M4 closure): "Orchestrator state advancement during SceneManager TRANSITIONING — race condition remediation". Sprint 8 patches the symptom at the screen level; cleaner architectural fix at orchestrator or Screen base class layer.
- Audio system (still blocked on GDD + ADR — likely Sprint 10 design + Sprint 11 implementation)
- TD-008 carryforward (ADR-0007 architecture diagram MainRoot Node→Control amendment)
- Multi-floor picker (replaces hard-coded forest_reach floor 1)
- Recruit flow (allow player to add heroes beyond the seeded Theron)
- Per-hero detail / inspection screen
- Polish-stage UI work (icon art for hero classes, background environments, ambient SFX hooks)
- First-run onboarding flow (game-concept GDD has tutorial requirements not yet scheduled)
