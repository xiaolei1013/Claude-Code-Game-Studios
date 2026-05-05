# Gate Check: Pre-Production → Production

**Date**: 2026-05-05
**Checked by**: gate-check skill
**Review mode**: solo (director panel skipped per skill spec)
**Verdict**: **PASS WITH NOTES**
**Stage transition**: `Pre-Production` → `Production` (`production/stage.txt` updated)

## Context

Prior gate-check history:
- 2026-04-26: FAIL — VS Validation 0/4 (no playtest data, no playable VS); 10/13 artifacts
- 2026-04-27 (sprint7-dryrun): FAIL — same blocker
- 2026-04-28: FAIL (soft) — VS Validation 1/4 explicit FAIL on item #2 ("formation_assignment doesn't self-explain") + item #4 BORDERLINE; **all 13/13 artifacts present**

This attempt: Sprint 9 polish bundle (S9-M1 formation_assignment UX + S9-M2 run pacing + S9-M3 locale CSV) landed; in-session S9-M2 fast-path regression discovered AND patched same-day with regression test added (`run_pacing_minimum_duration_test.gd::test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter`); S9-M4 fresh-eyes playtest verdict PASS WITH NOTES; all 4 playtest-01 confusion statements RESOLVED; Pillar 2 score 1/5 → 3/5.

## Required Artifacts: 13/13 PRESENT ✓

| # | Artifact | Status | Evidence |
|---|---|---|---|
| 1 | Prototype with README | ✅ | `prototypes/idle-matchup-loop/README.md` (sub-project, isolated `project.godot`) |
| 2 | First sprint plan | ✅ | `production/sprints/sprint-1.md` through `sprint-9.md` (9 plans) |
| 3 | Art bible complete + AD-ART-BIBLE sign-off | ✅ | `design/art/art-bible.md` v1.0 + `design/art/ad-art-bible-signoff-2026-04-27.md` (Approved) |
| 4 | Character visual profiles | ✅ | `design/art/character-profiles/{mage,rogue,warrior}.md` |
| 5 | All MVP-tier GDDs present | ✅ | 16 docs in `design/gdd/` covering Foundation + Core + Feature systems |
| 6 | Master architecture document | ✅ | `docs/architecture/architecture.md` |
| 7 | ≥3 ADRs covering Foundation-layer decisions | ✅ | 14 ADRs total; ADR-0003 (autoload rank), 0004 (save envelope), 0005 (time/tick), 0006 (data loading), 0007 (scene/persist) all Foundation |
| 8 | Control manifest | ✅ | `docs/architecture/control-manifest.md` (version 2026-04-24) |
| 9 | Epics for Foundation + Core layers | ✅ | `production/epics/index.md`: Foundation ✅ (4/4) + Core ✅ (4/5; audio-system blocked on GDD, post-MVP) |
| 10 | Vertical Slice playable end-to-end | ✅ | playtest-04 confirms 3 dispatches without dev guidance |
| 11 | ≥3 playtest sessions documented | ✅ | playtest-01 (new player), 02 (mid-game), 03 (offline return), 04 (post-S9 polish) |
| 12 | VS playtest report exists | ✅ | `production/playtests/playtest-04-post-sprint-9-polish-2026-05-05.md` |
| 13 | UX specs for main menu + HUD + pause menu | ✅ | `design/ux/{main-menu,hud,pause-menu,interaction-patterns}.md` |

## Quality Checks: 9/9 PASSING

- ✅ All 14 ADRs have Engine Compatibility sections (verified via grep count: 14/14)
- ✅ All 14 ADRs have ADR Dependencies sections (verified via grep count: 14/14)
- ✅ Architecture review: **PASS** (`architecture-review-2026-04-22g.md` — third consecutive zero-drift review)
- ✅ GDD cross-review: **CONCERNS post-fix** (`gdd-cross-review-2026-04-19.md` — warnings only, not FAIL)
- ✅ Sprint plan references real story files / inline tasks with closure notes
- ✅ Test framework operational — `run_pacing_minimum_duration_test.gd` 5/5 PASS in 5s 468ms (run mid-gate-cycle 2026-05-05)
- ✅ Architecture has no unresolved open questions in Foundation/Core layers
- ✅ Accessibility tier defined and documented (`design/accessibility-requirements.md`, 24KB)
- ✅ Interaction pattern library exists (`design/ux/interaction-patterns.md`)

## Vertical Slice Validation: 4/4 PASS

Per skill protocol: any FAIL on VS Validation triggers auto-FAIL on the gate (per GDC postmortem data from 155 projects).

| # | Item | 2026-04-28 | 2026-05-05 | Evidence |
|---|---|---|---|---|
| 1 | Human played core loop without dev guidance | PARTIAL | **PASS** | playtest-04 §Session Info: 3 dispatch cycles, no external help during the post-hotfix runs |
| 2 | Game communicates what to do in first 2 minutes | ❌ **FAIL (auto-FAIL trigger)** | **PASS** | playtest-04 §Regression Check: all 4 playtest-01 unprompted confusion statements marked RESOLVED — header copy lands, slot badge surfaces, floor card frames destination, locale strings render English |
| 3 | No critical "fun blocker" bugs in VS build | PASS | **PASS** | S9-M2 fast-path regression discovered mid-session AND patched same-day with `test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter` regression test added |
| 4 | Core mechanic feels good | ⚠️ BORDERLINE (Pillar 2 = 1/5) | **PASS** (Pillar 2 = 3/5) | playtest-04 §Pillar Alignment: Pillar 2 jumped from 1/5 → 3/5 (clears the gate-blocking ≥3/5 bar); run pacing now ~1.5s wall-clock with kill_count visible |

## Notes (advisory for Production phase)

1. **Core fantasy evidence is structural, not testimonial** — playtest-04 documents Pillar 2 = 3/5 and the "Theron came back with 3 kills" moment is now perceptible, but the tester did not give a verbatim "I felt like a guildmaster"-type quote. The Pillar 2 score is the proxy. Acceptable for gate clear. **Surface in Polish-phase playtests** — collect verbatim fantasy-match statements from external playtesters.

2. **S9-M2 fast-path regression pattern (Production process flag)** — automated tests passed but the live build failed because tests covered only the "slow path" (`_on_state_changed` signal during screen lifetime), not the "fast path" (`on_enter` defensive branch when state is already RUN_ENDED at mount time). Apply this **dual-path coverage check** to similar code patterns in Production. Closure recorded in `sprint-9.md` under "S9-M2 Hotfix Amendment — Fast-path dwell regression (2026-05-05)".

3. **S9-S1 save-persist pipeline deferred to Sprint 10** — highest-leverage Should Have not landed in Sprint 9 (capacity reserved by the in-session hotfix). Pre-Production → Production gate does not require offline persistence working, but **Polish-phase playtests will surface this gap immediately** (no return-to-app rewards = no idle-game core fantasy beat). Sprint 10 plan should reserve ~2.0 days for S9-S1 carry-forward.

4. **GDD cross-review = CONCERNS (post-fix warnings)** — `gdd-cross-review-2026-04-19.md` was initially FAIL with 3 blocking items; all 3 inline-fixed during the review, leaving warning-level only. Track these for resolution during Polish (especially Offline Engine GDD authoring per the cross-review note).

5. **Audio system epic blocked on GDD** — Core layer 4/5 (audio-system epic missing). Post-MVP per economy/sprint plan; ADR + GDD authoring is Sprint 10–11 candidate. Not gating Production but worth queuing.

## Chain-of-Verification

5 challenge questions checked:

1. **"Which quality checks did I verify by reading vs. inferring?"** — Read playtest-04 (just authored), playtest-01 (regression baseline), gate-check 2026-04-28 (prior FAIL), architecture-review-22g (PASS verdict), gdd-cross-review (CONCERNS post-fix), epics index (Foundation/Core present), art-bible signoff (Approved), accessibility doc (existence + 24KB size). ADR Engine Compatibility + Dependencies sections verified by grep count (14/14 each), not by reading every ADR. Test suite confirmed via direct invocation of `run_pacing_minimum_duration_test.gd`. No items marked PASS purely by inference.

2. **"Are there MANUAL CHECK NEEDED items I marked PASS without user confirmation?"** — "Core mechanic feels good" relied on user-reported Pillar 2 = 3/5 and "the basic core loop is working" — both directly stated by the user this session. ✓ No silent assumptions.

3. **"Did I confirm artifacts have real content?"** — art-bible.md verified via signoff doc (Approved); UX specs verified via head-reads (main-menu In Design, pause-menu In Design, HUD Draft v0.1 — all populated); architecture review verdict read directly. Did NOT re-read every GDD or ADR — relied on architecture-review-22g PASS as indirect evidence. Acceptable for solo-mode artifact-existence check.

4. **"Could any blocker I dismissed as minor actually prevent Production?"** — S9-M2 regression: patched same-day, regression test added, pattern flagged as Note 2. Not blocking. Save-persist deferred: not a Pre-Prod → Production gate item. GDD CONCERNS: warnings only. None of these meet the bar for blocking advance.

5. **"Which single check am I least confident in, and why?"** — "Core fantasy delivered" (Quality Checks last bullet). The structural argument is reasonable (kill_count visible after 1.5s dwell creates the "Theron came back" moment) but the verbatim tester evidence is thin. Captured as Note 1 — surface in Polish playtests. Insufficient to downgrade verdict.

**Chain-of-Verification: 5 questions checked — verdict unchanged (PASS WITH NOTES).**

## Verdict: **PASS WITH NOTES**

The 2026-04-28 auto-FAIL on VS Validation item #2 is cleared. All 13/13 required artifacts present, all 9/9 quality checks passing, all 4/4 VS Validation items PASS. Notes are advisory for the Production phase, not blockers.

**Stage transition approved**: `production/stage.txt` updates from `Pre-Production` → `Production`.

## Sprint 9 closure path

S9-M5 (the gate-check retry) is the final Must Have item. With this PASS WITH NOTES verdict:
- Sprint 9 contractual Must Have work (S9-M1, M2, M3, M4, M5) is COMPLETE.
- All Should Have items (S9-S1 save-persist, S9-S2 reduce-motion, S9-S3 theme content) deferred to Sprint 10 — `production/sprint-status.yaml` will reflect this in Sprint 9 closure.
- Sprint 10 should be planned to absorb deferred Should Have items + audio-system GDD + S9-N5 XP/level feedback.

Run `/sprint-status` for closure verification, then `/sprint-plan new` for Sprint 10 (or `/milestone-review` if a Pre-Production → Production milestone retrospective is desired).
