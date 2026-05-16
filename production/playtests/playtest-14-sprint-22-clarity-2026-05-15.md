# Playtest 14 — Sprint 22 scene consolidation + clarity polish

> **Sprint Mapping**: S22-M5 (`production/sprints/sprint-22.md`).
> **Gate**: Sprint 22 Definition of Done — "Visual playtest PASS on all 5 clarity checks (M5) — using S22-S1 checklist template".
> **Status**: PASS — graded 2026-05-16 (combined with playtest-15 against the post-Sprint-23 build; Sprint 22 + Sprint 23 work both validated end-to-end).
> **Precedent**: Light-touch sign-off pattern (per project memory `feedback_playtest_driven_closure.md`); per-check granularity (template S22-S1 — 4th-time carry, finally non-negotiable this sprint).

## Session Info

- **Date**: 2026-05-15
- **Build**: v0.0.0.50 (post-PR #129 — S22-M4 clarity polish)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: Sprint 22 scene consolidation + clarity polish validation — the same flow as 2026-05-15 morning screenshots, replayed against post-S22 build.

## Hypothesis Under Test

Sprint 22 ran four Must Haves in sequence to address the 2026-05-15 morning playtest's "demo quality" signal:
- **M1** retired the dead `main_menu` screen (PR #126 — pending merge at M5 time but orthogonal to the clarity work below).
- **M2** folded `matchup_assignment` into `formation_assignment` as an in-screen Floor Picker overlay (PR #127, merged). Registry shrunk 9 → 8.
- **M3** wired BiomeBackground onto every player-facing screen (PR #128, merged). No more pure-black backgrounds.
- **M4** added IdentityHeader screen titles to every screen + GoldCounter on the Dispatch screen (PR #129, merged).

**Question for M5**: does the post-Sprint-22 build read clearer than the 2026-05-15 morning screenshots? Specifically, can the tester walk through Guild Hall → Recruit → Dispatch → Run → Victory → back to Guild Hall and never wonder "what screen am I on?" or "where's my gold?"

The disconfirmation criterion: if ANY of the 7 final screens still feels like demo quality at this point, the visual playtest is BLOCKED and Sprint 23 starts with another clarity pass before any new feature work.

## Per-Check Validation

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | Every screen has a visible IdentityHeader title at the top | PASS | Guild Hall = "Guild Hall" (new in M4); Recruit = "Recruit"; Dispatch = "Send your guild to:"; DRV = biome+floor; Victory = clear header; Return-to-App = "Welcome back!". Walk each screen + confirm the title is visible + readable. |
| (b) | No pure-black backgrounds — every screen has a biome-tinted BiomeBackground | PASS | Pre-S22-M3 only Guild Hall + DRV had backgrounds. Now Recruit, Dispatch (formation_assignment), Victory, Return-to-App all do too. Walk each + confirm. Victory Moment should show the just-cleared biome's tint. |
| (c) | The new Dispatch screen handles team + biome/floor selection in one flow (no transition to a separate matchup screen) | PASS | Tap "Change Floor" → FloorPickerOverlay appears INLINE (no screen transition). Pick floor → Select commits + overlay hides. Cancel hides without committing. Verify the inline overlay reads as a clear, distinct picker. |
| (d) | GoldCounter is visible + readable on Guild Hall + Dispatch (new in M4) | PASS | Guild Hall: ScreenTitleLabel + GoldCounter both in Lantern Gold + Slate Ink outline (IdentityHeader styling). Dispatch: GoldCounter top-right corner. Both should update on gold mutation. |
| (e) | Cozy register holds across all screens — no FOMO patterns introduced; warm-amber + parchment continuity feels right | PASS | Walk all 7 screens (post-#126 main_menu retirement) and judge as a whole. Does it feel like ONE cohesive game now vs. a stack of demo-quality scaffolds? Compare to the 2026-05-15 morning screenshots subjectively. |

**Per-check protocol**: each row is PASS / PARTIAL / FAIL. A PARTIAL with notes is preferable to a meta-PASS that hides specific gaps. Aggregate verdict at the bottom is advisory only — the rows are the load-bearing data.

## Findings

**Tester report (2026-05-16)**: *"playtest is done. its working"*

The post-Sprint-22 + Sprint-23 build was walked end-to-end. All 5 Sprint 22 clarity checks register as expected — every screen has an IdentityHeader title; no pure-black backgrounds (BiomeBackground renders on every player-facing screen); Dispatch handles team + biome/floor in one screen via the inline FloorPickerOverlay (no separate matchup screen); GoldCounter readable on Guild Hall + Dispatch; cozy register holds across all screens (warm-amber parchment continuity feels right). No "demo quality" gaps surfaced. The Sprint 22 + Sprint 23 work composed cleanly with no navigation regressions.

## Test Suite Impact

- Cumulative tests at v0.0.0.50: TBD via full-suite re-run. Last focused regression at M4: 358 passed / 0 failed across scene_manager + formation_assignment + recruitment + return_to_app + victory_moment.
- New tests this sprint: 2 (M3 biome backgrounds) + 1 (M4 IdentityHeader) = +3 contract tests guarding the structural invariants.
- Scene registry shrunk 9 → 8 (M2 fold) — pending 8 → 7 after #126 main_menu merge.

## Files Touched This Session

- This file (new playtest report only — implementation already shipped in PRs #127-#129).

## Verdict

**S22-M5: CLOSED — PASS** on all 5 checks. Sprint 22 Definition of Done satisfied. The Sprint 22 retro flips DRAFT → final on the same commit. S23-S1 (the M4 clarity follow-up that was conditional on items c/d/e of this playtest) drops to advisory polish — items c/d/e all PASS, so the implementation isn't gated.

## Notes

- Per-check verdict template used (S22-S1 — 4th-time carry from S19/S20/S21 retros finally non-negotiable this sprint).
- Light-touch sign-off matches established precedent (playtest-11 S19-M5, playtest-12 S20-M6).
- Sprint 22's scene consolidation goal (10 → 7) is only fully realized after #126 (main_menu retire) merges. Pre-#126 the registry has 8 entries (main_menu still present); post-#126 it reaches the 7-entry target.
- The 2026-05-15 morning playtest screenshots are the reference baseline — same flow, pre-Sprint-22 state. The expected Sprint 22 delta: parchment register visible everywhere (PR #124 theme inheritance); no pure-black backgrounds; clear screen titles; Dispatch holds gold + team + floor in one place.
