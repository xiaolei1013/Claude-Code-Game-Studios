# Sprint 23 Retrospective — 2026-05-16

> **Sprint Mapping**: S23-M3 (folded with M3 playtest gate per the Sprint 23 plan).
> **Sprint Window**: 2026-05-29 to 2026-06-11 nominal; actual close 2026-05-16 (eleventh consecutive same-day-compressed sprint).
> **Review Mode**: Solo.
> **Status**: DRAFT — finalize after M3 playtest verdict lands in `playtest-15-sprint-23-consolidation-2026-05-16.md`.

## Sprint Goal — [Pending M3 playtest verdict; preliminary assessment: MET on structural axes]

> **Complete the remaining scene consolidation gap (Hall of Retired Heroes → tab, Pause Menu modal), resolve the deferred M4 clarity items driven by the playtest-14 signal, and scaffold the Settings screen so the Pause Menu has somewhere to go.**

Preliminary status against the 5 success conditions defined in the plan (final verdict pending playtest-15):
- (a) `hall_of_retired_heroes` retired as a standalone screen; Active/Retired tabs on Guild Hall — ✅ S23-M1 shipped (PR S23-M1, v0.0.0.52). Registry shrunk 7 → 6.
- (b) Pause Menu modal exists, wired via Esc key on every player-facing screen; Resume/Settings/Quit-to-Guild-Hall functional — ✅ S23-M2 shipped (v0.0.0.53). Global Esc handler in Screen base class.
- (c) M4 deferred items c/d/e addressed per playtest-14 verdict — ❓ PENDING playtest-14 grading. S23-S1 conditional — non-negotiable if items c/d/e PARTIAL/FAIL on playtest-14; advisory polish if all PASS.
- (d) Settings screen scaffold navigable from Pause Menu — ✅ S23-S2 shipped (v0.0.0.54). Leveraged existing Settings overlay; added version readout + Quit-to-Desktop. The Pause Menu's Settings button opens the overlay (stacked above pause).
- (e) Visual playtest validates M1+M2 additions read clearly — ❓ PENDING playtest-15.

## By the Numbers

- **Commits this sprint (per task branch)**: 7 (1 plan + 6 implementation: M1/M2/S2/S3/N1/N2; playtest+retro skeletons on this branch).
- **Cumulative tests at sprint close**: 2250+ (was ~2210 at start of S23; +36 net new across 6 new test files).
- **Regressions**: 0. Full suite green across the sprint.
- **New ADRs**: 0 (consolidation finish is structural; pause modal is ADR-0007-compliant push_overlay use).
- **GDD status transitions**: 0 (light updates to `prestige-system.md` §C.4 + `guild-hall-screen.md` §F to reflect M1 tab consolidation).
- **New contract tests**: 36 across 6 new test files (retired_tab_render, pause_menu_render, settings/version_and_quit, class_portrait_factory, audio_router/n1_mvp_contract, formation_assignment/synergy_preview_label).
- **Scene registry**: 7 → 6 (M1 retire). Overlay registry: +1 (pause_menu).
- **Version**: 0.0.0.51 → 0.0.0.57 across the sprint (6 implementation PRs).
- **Solo same-day cadence**: 11th consecutive sprint (S14 → S23). Sprint 23 was the lightest Must-Have-load since S16.

## What Worked

[TO FILL IN — preliminary candidates pending playtest-15 confirmation:]

- **Sprint 23 closed all 6 plannable stories in one autonomous session.** M1/M2/M3-skeleton (S2 + S3 + N1 + N2 + playtest-15 prep) all shipped on day 0. The compressed cadence held for the eleventh consecutive sprint (S14 → S23).
- **`_refresh_roster_panel` queue_free → remove_child + queue_free fix surfaced through the M1 structural change.** The latent flake in `test_hero_recruited_signal_refreshes_roster_panel` (deferred frame leaks stale cards into the rebuild) was always there; the M1 TabContainer wrap exposed it. One-line idiom fix matches the pattern already used in `_refresh_retired_card_list`. Future refresh-pattern code in Guild Hall ALL uses the immediate-detach pattern now.
- **N1 verification-only closure pattern.** Instead of reauthoring the already-shipped AudioRouter MVP wiring, the N1 closure added an end-to-end contract test that locks in the signal-routing surfaces (screen_changed → guild_hall_bed, wire_touch_feedback → sfx_ui_tap, Settings slider round-trip). This is the cheapest credible closure for a story that's already implemented but not explicitly contract-tested. Pattern is reusable for any future "verify existing wiring" task.
- **S23-S3 ClassPortraitFactory pattern.** Programmatic 96×96 colored-block portraits avoid the "real art OR placeholder PNG" dichotomy that blocked S20-N1 and S21-S2. Pure deterministic hash-to-color mapping; consumers can prefer `HeroClass.portrait_path` when real art lands, falling back to the factory — API surface won't change.

## What Could Be Better

[TO FILL IN — preliminary candidates pending playtest-15 confirmation:]

- **N2 "Class Synergy V2 tier ladder" shipped only the always-visible preview, not the tier (None/Bronze/Silver/Gold/Platinum) categorization.** The V2 tier design hasn't been authored. The current label uses V1 synergy names. A future Sprint 24+ should either author the V2 tier GDD OR document the deferral explicitly in `class-synergy-system.md` so the next attempt doesn't re-discover the gap.
- **Settings stayed as an OVERLAY rather than becoming a SCREEN.** S23-S2's plan wording was "Settings screen scaffold"; the implementation leveraged the existing settings OVERLAY. The Pause Menu → Settings flow works (overlay-on-overlay stack), but if a future sprint wants a dedicated Settings screen (full-screen replacement, not modal), that work isn't started here.
- **Playtest-14 (Sprint 22) verdict still PENDING at Sprint 23 close.** S23-S1 (the M4 clarity follow-up) is gated on playtest-14 grading items c/d/e. With the Sprint 23 retro signing off ahead of playtest-14, S23-S1 carries to Sprint 24 if those items PARTIAL/FAIL.

## What I'd Do Differently Next Time

[TO FILL IN POST-PLAYTEST-15 — placeholder candidates:]

- **Author Class Synergy V2 tier GDD BEFORE Sprint 24 N-tier work.** Sprint 23 N2 ran out of design surface; the implementation shipped the preview label without tier categorization. A 0.5d GDD session in pre-Sprint-24 planning would unblock a tier-aware label rev.
- **Two-playtest-per-sprint cadence may be unsustainable.** Sprint 23 was prep'd to close while Sprint 22's playtest-14 was still pending. The "playtest before sprint close" gate is starting to drift. If the human-action playtest backlog grows beyond 1 sprint, Sprint 24 plan should land a non-implementation breather sprint to catch up.
- **Test the `_refresh_*_panel` queue_free pattern globally.** The S23-M1 surface bug was in one method; a fast grep for `queue_free()` without immediately-preceding `remove_child()` across all Screen subclasses could find latent timing flakes elsewhere.

## Sprint 24 Recommendations

[TO FILL IN POST-PLAYTEST-15 — placeholder candidates:]

- **Class Synergy V2 tier GDD authorship + tier-aware preview label** (0.5d GDD + 0.5d implementation refresh on the S23-N2 surface).
- **S23-S1 carryforward** if playtest-14 grades items c/d/e PARTIAL or FAIL.
- **Onboarding First-Session Flow** (`design/gdd/onboarding-first-session.md`) — the first-time player sees Tutorial context, not bare Guild Hall.
- **Floor Unlock System** (`design/gdd/floor-unlock-system.md`) — progression gating prerequisite for late-game pacing.
- **Real product art ingestion** if an art workstream lands an ETA. The S23-S3 factory pattern means art-asset swap-in is non-blocking; consumers prefer `HeroClass.portrait_path` when present.

## Files Touched This Session

[Full list to be confirmed post-playtest-15 — preliminary:]

- `assets/screens/guild_hall/guild_hall.tscn` + `.gd` — M1 Retired tab structure
- `assets/screens/hall_of_retired_heroes/` — M1 deletion
- `tests/unit/hall_of_retired_heroes/` — M1 deletion
- `tests/unit/guild_hall/retired_tab_render_test.gd` (NEW) — M1 ported tests
- `tests/unit/guild_hall/hall_button_visibility_test.gd` — M1 deletion (visibility gating removed)
- `src/core/scene_manager/scene_manager.gd` — M1 registry shrink; M2 pause_menu overlay registration
- `tests/integration/scene_manager/request_screen_and_node_swap_test.gd` — M1 count assertion + path update
- `tests/integration/guild_hall/roster_panel_test.gd` — M1 path update + test_hero_card_xp hardening (sort_custom tie-break defensive seeding)
- `tests/unit/guild_hall/guild_hall_theme_application_test.gd` — M1 path update
- `assets/screens/_modals/pause_menu.tscn` + `.gd` (NEW) — M2
- `src/core/scene_manager/screen.gd` — M2 global Esc handler in base class
- `tests/unit/pause_menu/pause_menu_render_test.gd` (NEW) — M2
- `assets/overlays/settings/settings.tscn` + `.gd` — S2 version label + Quit-to-Desktop
- `project.godot` — S2 `config/version` declared
- `tests/unit/settings_overlay/version_and_quit_test.gd` (NEW) — S2
- `src/ui/class_portrait_factory.gd` (NEW) — S3 programmatic portrait factory
- `assets/screens/recruitment/recruitment.gd` — S3 portrait wiring
- `assets/screens/hero_detail/hero_detail_modal.gd` — S3 portrait wiring
- `tests/unit/class_portrait_factory/class_portrait_factory_test.gd` (NEW) — S3
- `tests/integration/audio_router/n1_mvp_contract_test.gd` (NEW) — N1 verification closure
- `assets/screens/formation_assignment/formation_assignment.tscn` + `.gd` — N2 SynergyPreviewLabel
- `tests/unit/formation_assignment/synergy_preview_label_test.gd` (NEW) — N2
- `assets/locale/en.csv` — locale keys for M1, M2, S2, N2
- `design/gdd/prestige-system.md` + `design/gdd/guild-hall-screen.md` — M1 GDD updates
- `production/sprint-status.yaml` — story completion entries for each task
- `CHANGELOG.md` — versions 0.0.0.52 through 0.0.0.57
- `production/playtests/playtest-15-sprint-23-consolidation-2026-05-16.md` (NEW) — M3 playtest skeleton (this branch)
- `production/retrospectives/sprint-23-retrospective-2026-05-16.md` (this file) — M3 retro skeleton

## Verdict

[TO FILL IN POST-PLAYTEST-15 — one of:]

- **Sprint 23: CLOSED — Sprint Goal MET.** All planned Must Haves + 2 Should Haves + 2 Nice to Haves shipped. Sprint 24 starts with Class Synergy V2 tier design + S23-S1 carryforward (if applicable).
- **Sprint 23: CLOSED-WITH-PENDING** — implementation complete, playtest-15 PARTIAL/FAIL surfaced specific gaps. Sprint 24 starts with M3 fix-up before any new feature work.

## Notes

- Per-check verdict template (S22-S1 baseline) is now the standard playtest closure. Sprint 23 is the second sprint using it.
- Eleventh consecutive same-day-compressed sprint (S14 → S23).
- Class Synergy V2 tier ladder is the load-bearing deferral going into Sprint 24 — the N2 implementation is incomplete vs the original plan wording.
- Playtest-14 (Sprint 22 closure) STILL PENDING at Sprint 23 close. S23-S1 carry decision deferred to that grading.
