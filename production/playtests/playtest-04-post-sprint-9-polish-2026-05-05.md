# Playtest 04 — Post Sprint-9 Polish (S9-M4)

> **Sprint Mapping**: S9-M4 (sprint-9.md "Re-run a single fresh-eyes playtest with the polish applied")
> **AC** (per sprint-9.md line 26): zero unprompted confusion statements about screen purpose; Pillar 2 score ≥3/5 (was 1/5); run pacing reported as "watchable".
> **Status**: Complete

## Session Info

- **Date**: 2026-05-05
- **Build**: post-Sprint-9 polish bundle
  - S9-M1 formation_assignment UX polish (slot active-state badge, instructional header, floor context card)
  - S9-M2 RUN_END_DWELL_MS = 1500 ms + **2026-05-05 fast-path hotfix** (`_deferred_run_end_route` now awaits the same dwell)
  - S9-M3 locale CSV authored at `assets/locale/en.csv` + `LocaleLoader` autoload
  - Branch: main
- **Duration**: ~15 minutes across 3 dispatch cycles + in-session S9-M2 fast-path hotfix iteration
- **Tester**: Project lead (solo mode per sprint-9.md "Solo mode allows project lead to be the tester for S9-M4")
- **Platform**: macOS (Apple M2 Max, Godot 4.6.1.stable.mono — confirmed via test run)
- **Input Method**: Mouse (Pillar 1: tap/click primary)
- **Session Type**: Polish-validation pass — re-running the four S8-M5 confusion items to verify Sprint 9 closed them

## Test Focus

**Hypothesis under test**: each of the four unprompted confusion statements captured in `playtest-01-new-player-2026-04-28.md` has been resolved by the matching Sprint 9 polish ticket, and the build now communicates intent within the first 2 minutes without external guidance — clearing VS Validation item 2 (the 2026-04-28 gate auto-FAIL trigger).

## Regression Check Against Playtest 01 — the 4 unprompted statements

| # | Original confusion (playtest-01) | Sprint 9 fix | Status this session |
|---|---|---|---|
| 1 | _"actually, not sure what will happen in this scene"_ (formation_assignment intent unclear) | S9-M1 instructional header copy ("Send your guild to:") + S9-M3 EN locale string | **RESOLVED** — instructional header reads as English, intent of the screen lands without external explanation. |
| 2 | _"nothing happens when i click on the slot_empty_label"_ (slot tap had no visual feedback) | S9-M1 "Selected" badge child Label on active slot + orchestrator-side `_refresh_formation_panel` patch on slot tap | **RESOLVED** — tapping a slot now visibly surfaces the active-state badge; the affordance is no longer hidden. |
| 3 | _"i don't get what is 'Forest Reach - Floor 1' for?"_ (no destination framing) | S9-M1 floor context card (FloorVBox container with FloorContextLabel framing the FloorButton) | **RESOLVED** — floor context card frames the button as the dispatch destination. Note: enemies-preview placeholder still deferred to Sprint 10 per S9-M1 closure (advisory, not gating). |
| 4 | _"it go to next scene but almost immediately go back to the main scene"_ (sub-second runs unwatchable) | S9-M2 RUN_END_DWELL_MS bump 0→1500ms + 2026-05-05 fast-path hotfix | **RESOLVED** — verified live across multiple dispatch cycles this session. Run dwells visibly for ~1.5s with the run-end overlay before cross-fading. Confirmed by automated regression test `test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter` (passed in 1s 524ms). |

## Locale CSV Verification (S9-M3)

Walked every reachable screen — main_menu, formation_assignment, dungeon_run_view, run-end overlay — looking for raw locale keys (`formation_assignment_title`, `slot_empty_label`, `tick_label_prefix`, `kill_count_label_prefix`, `run_complete_kill_count_format`, etc.).

- **Verdict**: ALL ENGLISH — no raw locale keys visible on any reachable screen.
- **Notes**: `LocaleLoader` autoload registered translations correctly at boot; `tr()` resolves to English values rather than key passthrough. Format substitution on the run-end overlay (`run_complete_kill_count_format` with the kill_count integer) renders as expected English string.

## ≥1 Unprompted Player Intent Statement (compare to playtest-01's 4)

> Verbatim quotes captured during the session, before any specific UX questioning. The S9-M4 acceptance bar is **zero unprompted confusion statements about screen purpose**.

**No unprompted confusion statements about screen purpose were observed across the 3 dispatch cycles.** All four playtest-01 statements have a corresponding RESOLVED row in the regression-check table above.

No new findings of comparable severity surfaced this session.

## Gameplay Flow

### What worked well

- **Run pacing now watchable** — RUN_END_DWELL_MS=1500 ms holds the run-end overlay long enough to register kill_count before cross-fade. Verified across multiple dispatches this session.
- **Fast-path dwell hotfix verified** — even when combat resolves during the FADE_TO_BLACK transition into dungeon_run_view, the dwell now fires (vs. pre-hotfix bypass).
- **Loop is repeatable** — basic core loop confirmed working by tester across 3 dispatches with consistent kill_count=3 result.
- **Slot tap, instructional header, and floor context card all landed** — tester reported all four playtest-01 confusion items as fixed.
- **English locale strings render everywhere** — no raw locale keys leaked through.

### Pain points

None gating Sprint 9 closure. Sprint 10 backlog (already on plan) carries:
- S9-S1 save-persist pipeline (highest leverage; gates offline UX)
- S9-S3 parchment_theme.tres content (default Godot styling still visible; "Selected" badge differentiation will sharpen once theme content lands)
- S9-N5 XP/level grant feedback (Theron staying Lv1 across dispatches noted in S8-M6 — still applicable)

### Confusion points

None observed.

### Moments of delight

- The 1.5s dwell + visible kill_count on the run-end overlay produced a real "Theron came back with 3 kills" moment that was missing entirely in playtest-01.

## Bugs Encountered

> Pre-known cosmetic items (do NOT log as new bugs — Sprint 10 backlog):
> - parchment_theme.tres still empty (S9-S3 deferred); default Godot panel/text styling visible
> - "Selected" badge visual differentiation lands when S9-S3 ships parchment_theme content

| # | Description | Severity | Reproducible |
|---|-------------|----------|--------------|
| - | None new — the S9-M2 fast-path dwell regression was discovered AND patched mid-session 2026-05-05; verified by automated regression test + 3 live dispatches | - | - |

## Quantitative Data

- **Dispatch cycles completed**: 3 (post-hotfix; additional pre-hotfix runs surfaced the S9-M2 fast-path regression)
- **Run wall-clock duration (sample)**: ~1.5s consistently across all 3 post-hotfix dispatches — sub-2s runs from playtest-01 no longer reproducible. Automated regression test measured 1s 524ms for the fast-path scenario.
- **Final kill_count visible to player on overlay**: YES — kill_count = 3 displayed legibly across all 3 dispatches
- **Final kill_count value**: 3 in all 3 runs (deterministic-feeling outcome with the same Theron-only formation, matching playtest-01's observation)

## Pillar Alignment Check

> Per `design/gdd/game-concept.md`, score each pillar 1-5. **Pillar 2 ≥ 3/5 is the gate-clearing bar** (was 1/5 in playtest-01).

| Pillar | Description | Score (1-5) | Notes |
|---|---|---|---|
| 1 | Respect the Player's Time | 3/5 (was 2/5) | Pacing fix removes the "disrespect attention in the opposite direction" failure mode from playtest-01. Boot still fast. |
| 2 | **Decisions Matter** | **3/5 (was 1/5)** | Slot affordance now visible (badge), floor framed as destination (context card), run outcome perceptible (1.5s dwell + visible kill_count). All three Pillar 2 hits from playtest-01 closed. **Clears the gate-blocking ≥3/5 bar.** |
| 3 | Cozy / No-Fail | 3/5 (held) | No-fail honored as before; pacing less jittery thanks to dwell + locale. |
| 4 | (4th pillar) | 3/5 | Held at par; not a focus of Sprint 9 polish. |

## Top 3 Priorities Surfaced (Sprint 10 candidates only — do NOT re-open Sprint 9)

1. **S9-S1 save-persist pipeline** (highest leverage; gates offline progression UX) — already on Sprint 10 plan.
2. **S9-S3 parchment_theme.tres content** (default Godot styling visible; will sharpen the "Selected" badge differentiation S9-M1 wired in) — already on Sprint 10 plan.
3. **S9-N5 XP/level grant feedback** (Theron stayed Lv1 across dispatches per S8-M6, still applicable post-S9 polish) — already on Sprint 10 plan.

---

## Verdict

- [x] **AC-1**: zero unprompted confusion statements about screen purpose — **PASS** (none observed across 3 dispatch cycles; all 4 playtest-01 statements RESOLVED)
- [x] **AC-2**: Pillar 2 score ≥ 3/5 (was 1/5) — **PASS** (3/5 — clears the gate-blocking bar)
- [x] **AC-3**: run pacing reported as "watchable" — **PASS** (verified live + by automated regression test; ~1.5s consistent dwell across 3 dispatches with kill_count visible)

**Overall**: **PASS WITH NOTES** — all three Sprint 9 ACs satisfied. Note flagged: an in-session S9-M2 fast-path regression was discovered AND patched same-day (2026-05-05); test coverage extended to cover the fast path going forward.

**Next**:
- If PASS: run `/gate-check production` (S9-M5). Expected verdict: PASS or CONCERNS. `production/stage.txt` advances from `Pre-Production` to `Production`.
- If FAIL: log the regressing item as a Sprint 9 hotfix ticket; re-run S9-M4 after the fix.

## Sprint 9 In-Session Hotfix Reference

During this session a regression was discovered in S9-M2: the `_deferred_run_end_route` "fast path" in `dungeon_run_view.gd` was bypassing `RUN_END_DWELL_MS` because `call_deferred` fires one frame later, before any await. Patched same-day by adding `await get_tree().create_timer(RUN_END_DWELL_MS / 1000.0).timeout` to `_deferred_run_end_route`. Regression test `test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter` added to `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd`. Full file's 5 tests pass (5s 468ms total). Sprint plan amendment recorded in `production/sprints/sprint-9.md` under "S9-M2 Hotfix Amendment — Fast-path dwell regression (2026-05-05)".
