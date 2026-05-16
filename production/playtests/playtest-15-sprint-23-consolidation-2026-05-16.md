# Playtest 15 — Sprint 23 scene consolidation finish + pause modal + portrait + synergy preview

> **Sprint Mapping**: S23-M3 (`production/sprints/sprint-23.md`).
> **Gate**: Sprint 23 Definition of Done — "Visual playtest PASS on scenes touched by M1+M2 (M3) — using `production/playtests/_template-visual-playtest.md`".
> **Status**: PENDING — fill in after live playtest.
> **Precedent**: Per-check granularity per `_template-visual-playtest.md` (S22-S1).

## Session Info

- **Date**: 2026-05-16
- **Build**: v0.0.0.57 (post-S23-N2 — Dispatch synergy preview)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: Sprint 23 scene consolidation finish + pause modal + Settings additions + class portraits + synergy preview validation.

## Hypothesis Under Test

Sprint 23 finished the scene consolidation work Sprint 22 left open and added pause/settings polish:

- **M1** retired the standalone `hall_of_retired_heroes` screen, folding its content into a Retired tab on Guild Hall's RosterPanel. Registry shrunk 7 → 6.
- **M2** added a Pause Menu modal triggered by Esc on every player-facing screen. Resume / Settings / Quit-to-Guild-Hall actions wired.
- **S2** added the version readout + Quit-to-Desktop button to the existing Settings overlay (which the Pause Menu's Settings button now opens).
- **S3** wired programmatic 96×96 colored-block ClassPortraits to the Recruit Screen pool rows + Hero Detail modal — no more "black void" portrait tiles.
- **N1** AudioRouter MVP wiring verified-in-place (already shipped Sprint 12; closed by an end-to-end contract test).
- **N2** added an always-visible SynergyPreviewLabel above the Dispatch slot row showing the predicted synergy live.

**Question for M3**: does the post-Sprint-23 build read as a coherent product — Guild Hall has Active/Retired tabs (no separate hall screen); Esc opens the Pause Menu anywhere; Settings shows the version and lets you quit to desktop; Recruit + Hero Detail show distinct class portraits; Dispatch shows the predicted synergy as you compose the team?

**Disconfirmation criterion**: if the M1+M2 scene-architecture changes feel rough (broken navigation, modals not closing, tab content invisible) OR S3 portraits feel jarringly placeholder OR the N2 synergy preview confuses players, the playtest is BLOCKED and Sprint 24 starts with polish.

## Per-Check Validation

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | Hall of Retired Heroes accessible as Active/Retired tabs on Guild Hall; standalone screen retired | [PENDING] | Walk Guild Hall → RosterPanel has tab strip → tap "Retired" → see the multiplier badge + retired-hero card list (or empty-state placeholder if no prestiges). Confirm there's no longer a "Hall of Retired Heroes" button on Guild Hall and no way to navigate to a separate hall screen. |
| (b) | Esc on any player-facing screen opens the Pause Menu modal; Resume + Settings + Quit-to-Guild-Hall all work | [PENDING] | Try Esc on: Guild Hall, Recruit, Dispatch (Formation Assignment), Dungeon Run View, Victory Moment, Return-to-App. Pause modal should appear consistently. Resume dismisses. Settings opens the Settings overlay (chained, stacked above pause). Quit-to-Guild-Hall pops + navigates to Guild Hall. Confirm Esc does NOT re-stack a second pause modal if one is already open. |
| (c) | Settings overlay shows version string + Quit-to-Desktop button | [PENDING] | Open Settings (via Pause Menu OR gear icon on Guild Hall). Verify the VersionLabel reads "Version 0.0.0.57" (or current build). Verify the Quit-to-Desktop button is present in the ButtonRow alongside Reset/Close. Tap Quit-to-Desktop: app should exit cleanly with no pause-counter warnings in the debug console. |
| (d) | ClassPortraits render distinct 96×96 colored blocks on Recruit Screen pool rows + Hero Detail modal | [PENDING] | Open Recruit Screen — each pool entry's ClassPortrait shows a distinct colored block (warrior vs mage vs rogue should be visually different). Open Hero Detail modal for any hero — ClassPortrait slot shows the same per-class color. No "black void" placeholder tiles. |
| (e) | Dispatch synergy preview label updates live as slots change | [PENDING] | Open Dispatch (formation_assignment). Above the slot row, SynergyPreviewLabel reads "Synergy: None" with empty slots. Add 3 warriors to slots → label flips to "Synergy: Steel Wall" (or similar). Remove one → flips back to "Synergy: None". Confirm the label updates IMMEDIATELY on slot change, not after Dispatch is pressed. |

**Per-check protocol**: each row is PASS / PARTIAL / FAIL. A PARTIAL with notes is preferable to a meta-PASS that hides specific gaps. Aggregate verdict at the bottom is advisory only — the rows are the load-bearing data.

## Findings

[TO FILL IN POST-PLAYTEST]

**Tester report**: *"[verbatim quote from playtest]"*

[Free-form observations: what worked, what fell short, what surprised, what didn't ship that you expected to see, what shipped that you didn't expect. Comparison to playtest-14 (post-Sprint-22) baseline — has the consolidation finish made the game feel more cohesive, or did the M1 tab refactor introduce any new "where did the hall go?" confusion?]

## Test Suite Impact

- Cumulative tests at v0.0.0.57: 2250+ across unit + integration (Sprint 23 added retired_tab_render (13), pause_menu_render (5), settings_overlay/version_and_quit (4), class_portrait_factory (7), audio_router/n1_mvp_contract (4), formation_assignment/synergy_preview_label (3) = +36 net new tests).
- 0 regressions across the full suite during Sprint 23.
- Scene registry shrunk 7 → 6 (M1 retire). Overlay registry grew by 1 (pause_menu).

## Files Touched This Session

- This file (new playtest report only — implementation already shipped in PRs).

## Verdict

[TO FILL IN POST-PLAYTEST — one of:]

- **S23-M3: CLOSED — PASS** on all 5 checks. Sprint 23 Definition of Done satisfied. Proceed to S23 retro committal (also folded into this M3 PR or follow-up).
- **S23-M3: CONDITIONAL PASS** — N/5 checks pass. Specific gaps surfaced for Sprint 24 iteration. Sprint 23 ships the consolidation finish + pause/settings polish; remaining gaps are advisory.
- **S23-M3: BLOCKED — REVISION NEEDED** — specific issue surfaced: [...]. Sprint 24 starts with M3 fix-up before any new feature work.

## Notes

- Per-check verdict template (S22-S1 baseline) — second sprint using the template.
- Sprint 23 is the lightest Must-Have-load sprint since S16 (2.0d MH vs S22's 4.75d). Should + Nice landed comfortably.
- Sprint 23's scene consolidation goal (7 → 6) is the final step of the 10 → 6 reduction begun in Sprint 22. PR #126 (S22-M1) merged 7 → 6 is now achieved.
- Class Synergy V2 tier ladder (None/Bronze/Silver/Gold/Platinum) is deferred from N2 — the V2 design hasn't been authored yet. N2 ships the always-visible preview label using V1 synergy names.
