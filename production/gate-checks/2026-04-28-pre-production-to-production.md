# Gate Check: Pre-Production → Production

**Date**: 2026-04-28
**Sprint Mapping**: S8-M8 (sprint-8.md "/gate-check production retry")
**Reviewer**: gate-check skill (solo mode)
**Verdict**: **FAIL** (soft — VS Validation item 2 explicit FAIL per playtest evidence; recoverable via Sprint 9 polish)

## Context

Third gate-check attempt for Pre-Production → Production transition. Prior attempts:
- 2026-04-26: FAIL — VS Validation 0/4 (no playtest data, no playable VS); 10/13 artifacts
- 2026-04-25 (implied earlier): same blocker

This attempt: full VS playable end-to-end via S8-M4 manual smoke (5 hotfixes landed), 3 playtest reports authored, all 13 required artifacts present. The blocker is now a single explicit-FAIL on VS Validation item 2 ("Game communicates what to do within first 2 minutes") + 1 BORDERLINE on item 4 ("Core mechanic feels good").

## Required Artifacts: 13/13 PRESENT ✓

- [x] Prototype with README — `prototypes/idle-matchup-loop/`
- [x] Sprint plans — 8 in `production/sprints/`
- [x] Art bible (9 sections) + AD-ART-BIBLE sign-off — `design/art/art-bible.md` (885 lines) + `design/art/ad-art-bible-signoff-2026-04-27.md`
- [x] Character visual profiles — warrior.md, mage.md, rogue.md
- [x] All MVP-tier GDDs — 16 in `design/gdd/`
- [x] Master architecture document — `docs/architecture/architecture.md` (808 lines)
- [x] ≥3 Foundation-layer ADRs — 14 ADRs total in `docs/architecture/`
- [x] Control manifest — `docs/architecture/control-manifest.md` (Manifest Version 2026-04-26)
- [x] Epics with Foundation + Core layers — 13 epics in `production/epics/`
- [x] Vertical Slice playable — verified end-to-end via S8-M4 smoke (Guild Hall → Formation → Dispatch → DungeonRunView → MainMenu)
- [x] VS playtested ≥3 sessions — playtests 01/02/03 in `production/playtests/`
- [x] VS playtest reports — all 3 with PASS WITH NOTES verdicts
- [x] UX specs for key screens — main-menu.md, hud.md, pause-menu.md, interaction-patterns.md, accessibility-requirements.md

## Quality Checks: 8/9 passing

- [x] UX specs cover key screens
- [x] Interaction pattern library exists (`design/ux/interaction-patterns.md`)
- [x] Accessibility tier defined (`design/accessibility-requirements.md`)
- [x] Sprint plan references real story file paths (verified for Sprint 8 stories 011/012/013)
- [x] Architecture doc — Foundation/Core open questions resolved through ADR amendments
- [x] All ADRs have Engine Compatibility sections (verified during Sprint 5/6/7 reviews)
- [x] All ADRs have ADR Dependencies sections
- [x] `/architecture-review` reports exist (7 dated 2026-04-22), `/review-all-gdds` cross-review at 2026-04-19
- [⚠️] **Core fantasy delivered** — playtest-01 verdict: **PARTIAL Match** (structural pieces present; pacing + decision context gaps prevent full match)

## Vertical Slice Validation: 2 PASS / 1 FAIL / 1 BORDERLINE

Per skill protocol: **any FAIL on VS Validation triggers auto-FAIL on the gate** (per GDC postmortem data from 155 projects).

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | A human played through the core loop without developer guidance | ✓ PASS (with caveat) | Tester completed full Guild Hall → Dispatch → Run → Main Menu loop. Caveat: AI provided clarifying explanations during play; without them tester stalled at formation_assignment. Strict reading: PARTIAL. |
| 2 | Game communicates what to do within first 2 minutes | ❌ **FAIL** | playtest-01 captured 4 unprompted confusion statements: (a) "actually, not sure what will happen in this scene", (b) "nothing happens when i click on the slot_empty_label", (c) "i don't get what is 'Forest Reach - Floor 1' for?", (d) "it go to next scene but almost immediately go back to the main scene". Without explanatory copy, the formation_assignment screen does not self-explain. |
| 3 | No critical "fun blocker" bugs | ✓ PASS | 5 hotfixes landed in S8-M4 addressed all critical bugs (layout clipping, click consumption, first-launch seed wiring, Dispatch→DungeonRunView nav gap, run-end-during-transition race). Build runs reliably. |
| 4 | Core mechanic feels good | ⚠️ BORDERLINE | Pillar 1: 2/5; Pillar 2: 1/5; Pillar 3: 3/5 across playtests. Run pacing variance (141 / 338 / ~10 ticks for same formation) makes the mechanic feel inconsistent rather than satisfying. Sub-second runs are unwatchable. |

## Blockers (3 minimal path-to-PASS items)

### B-1 (HIGHEST priority) — formation_assignment UX polish
**What**: Slot active-state visual + instructional copy + floor context card
**Why**: Resolves VS Validation item 2 (the auto-FAIL trigger) by making the screen self-explanatory
**Effort**: 1-2 days
**Sprint 9 candidate ticket**: "Story XXX-formation-assignment-polish — slot affordance + instructional copy"
**Acceptance**: A fresh-eyes playtest captures zero confusion statements about what to do on this screen

### B-2 — Run pacing minimum-perceived-duration
**What**: Either tune combat tick budget OR bump `RUN_END_DWELL_MS` from 0 to 1500-2000ms OR add a minimum-run-view dwell with kill_count animating up
**Why**: Resolves VS Validation item 4 BORDERLINE; addresses the "core fantasy: PARTIAL" finding
**Effort**: 0.5-1 day
**Sprint 9 candidate ticket**: "Story XXX-run-pacing-minimum-duration"
**Acceptance**: Across 5+ test dispatches, no run completes in <2s; player sees and registers the run

### B-3 — Locale CSV authoring
**What**: Author EN locale CSV with the ~12 keys used by Stories 011/012 (formation_assignment_title, slot_empty_label, dispatch_error_*, tick_label_prefix, kill_count_label_prefix, run_complete_kill_count_format, etc.)
**Why**: Locale keys visible everywhere is a cosmetic blocker for any felt-experience playtest. Real strings will dramatically improve the new-player experience and partially address VS Validation item 2.
**Effort**: 0.5 day
**Sprint 9 candidate ticket**: "Story XXX-locale-csv-en"
**Acceptance**: All visible UI strings show real English text, not locale keys

## Sprint 9 backlog (full list — beyond minimal path)

Beyond the 3 minimal-path items, S8-M5/M6/M7 playtests surfaced:

4. **Save-persist pipeline end-to-end wiring** (S8-M7 priority — without this, no offline progression possible; the entire ADR-0014 offline computation pipeline is gated on this)
5. **Implement return_to_app screen content** (covered structurally by scene-manager Story 009, which is Ready but not yet implemented)
6. **Author proper parchment_theme.tres content** (per ADR-0008)
7. **"Re-dispatch" shortcut on main_menu** (S8-M6 finding — multi-dispatch loop friction)
8. **XP/level grant feedback** (S8-M6 — Theron stayed Lv1 across 3 dispatches)
9. **UIFramework completion** — `apply_parchment_panel()` and `wire_touch_feedback()` (deferred per ADR-0008 mandate; Sprint 8 minimum-stub)
10. **Pre-existing scene_manager test environment flakes** (modal_pause_tick_coupling, crossfade_timing, request_screen_and_node_swap) — Sprint 5/6/7 origin
11. **Cross-test live-autoload contamination** in `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd`
12. **`tr()` safe-format pattern hoisting into UIFramework** (Stories 011/012 duplication)

## Recommendations

**Minimal Sprint 9 polish sprint (3-5 days)**:
- Day 1-2: B-1 (formation_assignment polish)
- Day 3: B-2 (run pacing tuning)
- Day 3-4: B-3 (locale CSV)
- Day 4: Re-run a single playtest with fresh-eyes lens
- Day 5: Re-run `/gate-check production`

After Sprint 9 minimal polish, expect gate-check to return **PASS** or **CONCERNS** (not FAIL).

## Tests passing — no regressions

- Sprint 8 UI integration suites: **49/49 PASS** (mainroot 18, formation_assignment 13, dungeon_run_view 12, run_end_to_main_menu 6) — verified during gate-check run
- Cumulative project: ~1116+ tests green project-wide

## Chain-of-Verification

5 challenge questions checked. Verdict revised from initial PASS-WITH-CONCERNS draft to **FAIL** after CoV reasoning identified VS Validation item 2 as a hard NO per strict skill rule.

## Verdict: **FAIL** — minimum path to PASS is 3-5 days of Sprint 9 polish

The kernel works. All 13 artifacts are present. Tests are green. The gap is specifically on player-facing self-explanatory UX + felt-experience tuning, not on architecture or implementation correctness.

**Stage stays at Pre-Production.** `production/stage.txt` not modified.

**Next**: plan Sprint 9 (`/sprint-plan`) targeting the 3 minimal-path items + Sprint 9 backlog overflow as bandwidth allows.
