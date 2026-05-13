# Playtest 07 — Sprint 14 full-loop validation

> **Sprint Mapping**: S14-M5 (`production/sprints/sprint-14.md`).
> **AC**: full cozy register loop — launch → Guild Hall → tap a HeroCard → Hero Detail modal (real data, not placeholders) → close → tap Settings gear → adjust volume / mute / locale → close → "Go to Dispatch" → Formation Assignment → Matchup Assignment → Dungeon Run → Victory Moment → back to Guild Hall. PR #58 visual fixes hold (dim backdrop coverage, HeroCard / Dispatch button non-overlap, modal lifecycle).
> **Status**: PASS — light-touch sign-off. Everything seems working.

## Session Info

- **Date**: 2026-05-13
- **Build**: v0.0.0.18 (post-PR #59 `show_modal` lifecycle hardening merge)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: Sprint 14 closure playtest. Multiple short sessions over one evening.

## Hypothesis Under Test

Sprint 14's 8 shipped PRs (#52–#59) compose into a coherent Guild Hall surface:

- Hero Detail modal opens from HeroCard tap, renders real hero data (M1 + S4 + M6), and closes cleanly via either Close button or DimBackdrop tap (S4 backdrop coverage holds)
- Settings overlay reachable from gear icon (M2), shows dB per slider (S3), mute master toggle works (S2), locale dropdown swaps strings live (S3), Reset to Defaults restores (S3)
- HeroCard XP bar reflects current XP / threshold (S1), touch feedback fires on tap (S2)
- `SceneManager.show_modal` lifecycle hook (M6) ensures `on_enter` always runs — no placeholder labels under any path
- RosterPanel + Dispatch button do not visually collide (S4 layout fix)

**Result**: hypothesis HELD. End-to-end loop is coherent.

## Walkthrough (high level)

- [x] Launch → Guild Hall renders correctly; gold counter, roster, nav buttons all in place
- [x] Tap HeroCard → Hero Detail modal opens with the tapped hero's real name / class / level / XP (no "Hero Name" placeholder regression)
- [x] DimBackdrop fully obscures Guild Hall (PR #58 alpha 0.75 holds across all three modal types)
- [x] Close Hero Detail → Guild Hall resumes; no signal leaks, no double-render
- [x] Tap gear icon → Settings overlay opens
- [x] Drag volume sliders → dB labels update live; mute toggle silences all
- [x] Locale dropdown → string swap on the fly; Reset to Defaults restores
- [x] Close Settings → Guild Hall resumes
- [x] "Go to Dispatch" button is visually clear of the RosterPanel bottom edge (PR #58 layout fix holds even with multiple heroes recruited)
- [x] Formation Assignment → Matchup Assignment → Dungeon Run → Victory Moment all chain correctly; rewards land back in Guild Hall

Also incidental: "Hall of Retired Heroes" button appearing in some sessions clarified during the playtest — it's the Prestige system surface, gated on `prestige_count > 0`. Working as designed.

## Findings

None blocking. Sprint 14's intent — wire Guild Hall to production quality — is met.

## Test Suite Impact

- No code changes. **2097/2097 PASS** baseline from v0.0.0.18 holds.

## Files Touched This Session

- This file (new playtest report only).

## Verdict

**S14-M5: CLOSED.** Sprint 14 Must Haves are functionally validated.

Sprint 14 Must Have ledger after this report:

- S14-M1 Hero Detail wire-up — DONE (PR #52)
- S14-M2 Settings overlay real content — DONE (PR #53)
- S14-M3 Onboarding first-session E2E test — DONE (PR #54)
- **S14-M4 Close-reload smoke playtest** — CLOSED (playtest-06)
- **S14-M5 Sprint 14 full-loop playtest** — CLOSED (this report)
- **S14-M6 show_modal lifecycle hardening** — DONE (PR #59)

## Notes

- Light-touch sign-off per project memory `feedback_playtest_driven_closure.md`.
- Compared to playtest-05 (Sprint 12 closure, 9 issues surfaced in one session): playtest-07 surfaced zero issues, which is the expected curve once integration-wiring debt is paid down. The "9 wiring gaps in one session" event drove the playtest-driven closure rule; this report is what it looks like when the rule is being followed correctly.
- Next step: Sprint 14 retrospective (`S14-S5`) — should now be writable given all Must Haves are closed.
