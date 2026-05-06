# Sprint 13 — 2026-06-08 to 2026-06-17 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-06** by post-Sprint-12 close-out session.
> Sprint 13 nominally begins 2026-06-08 after Sprint 12 closes (2026-06-04). This plan synthesizes the candidate list captured in `production/retrospectives/sprint-12-retrospective-2026-05-06.md` and the carry-forward items from Sprint 12's closure notes. **Re-validate via `/sprint-plan` if anything material changes between now and Sprint 13 kickoff** — in particular, the audio asset sourcing decision (M1 below) is gating and may reshape the rest of the plan.

## Sprint Goal

**Close the cozy-loop endcap and decide audio.** Sprint 12 wired the entire MVP gameplay loop end-to-end (recruit → assign → dispatch → clear → reward → offline replay → audio dispatch), but two visible gaps remain:

1. **The Return-to-App Screen** — `OfflineProgressionEngine.offline_rewards_collected` fires correctly but no UI subscribes; the player who returns from offline sees no summary. This is the single biggest remaining player-facing MVP gap.
2. **Silent audio** — `AudioRouter` cue dispatch is verified by spy-based tests, but `DataRegistry.resolve("sfx", id)` returns null because no `.tres` resources exist at `assets/data/sfx/`. The cozy register that game-concept.md promises is silent until binary asset sourcing lands.

**Definition of Sprint 13 success**: a player who closes the app for 30+ minutes and reopens sees a cozy summary modal showing accumulated offline gold + hero level-ups + floors cleared, dismisses with a tap, and hears at least the level-up chime cascade as the toast plays in the foreground. The MVP cozy register is audible (or, if the audio sourcing decision is "ship MVP silent", the silent decision is documented and game-concept.md is updated to match).

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning** (per Sprint 12 retro): Sprint 13 has NO pre-emptive buffer. Sprints 10-12 absorbed most of the ahead-of-time surface area. Plan for actual day-by-day execution at 1.0× plan estimate, NOT the 0.6× ratio Sprints 11-12 averaged.

## Pre-flight checklist (Day 0 — apply Sprint 11 "Honest Dependency Status Check" lesson)

Before starting any Must Have, grep the codebase to confirm:
- [ ] `OfflineProgressionEngine.offline_rewards_collected` has no current UI subscriber (`grep "offline_rewards_collected" assets/screens/`) — should return nothing pre-implementation
- [ ] `assets/data/sfx/` and `assets/data/music/` are empty (only `.gitkeep` per Sprint 12 S12-S5)
- [ ] `tests/` is green at Sprint 12 close (1430/1430 PASS expected)
- [ ] `production/session-state/active.md` reflects Sprint 12 closure
- [ ] `user://settings.cfg` does NOT exist on the dev machine — leftovers from Sprint 12 S12-S2 testing should be cleaned up

If any of the above is unexpectedly already implemented (not impossible — pre-emptive Sprint 12 work bridged into Sprint 13 in several places), re-scope the affected Must Have item.

## Tasks

### Must Have (Critical Path — close the cozy-loop endcap)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S13-M1 | **Audio asset sourcing decision** — author an ADR documenting commission vs. license vs. AI-generated vs. ship-MVP-silent. If non-silent decision: source 11 SFX cues + 2 music beds + 2 stingers (per audio-system.md §C.2 / §C.3) and place at the canonical paths (`assets/audio/<type>/<id>.wav` or `.ogg`, wrapped in `assets/data/<category>/<id>.tres` per §C.6 path convention). If silent decision: update game-concept.md §Audio Needs to match and document AudioRouter as "wired but silent until post-MVP". | audio-director + creative-director | 0.5d (decision) + 1.0d (sourcing if non-silent) | none | ADR authored; if non-silent, all 11 SFX cues + 2 music beds resolve through DataRegistry; AudioRouter cue-dispatch tests in `audio_router_signal_handlers_test.gd` continue to pass; manual smoke verifies at least the level-up chime + UI tap chime + floor-clear fanfare audibly play. |
| S13-M2 | **Return-to-App Screen wire-up** (GDD `offline-progression-engine.md` §J Story 9 — sprint-plan-vs-GDD reconciled in S12-S3 closure note in sprint-12.md) — author `assets/screens/return_to_app_view/` per the existing screen pattern (Control + tscn + .gd, registered in SceneRegistry). Subscribes to `OfflineProgressionEngine.offline_rewards_collected` via `on_enter`; renders OfflineSummary fields (`gold_earned`, `kills_by_tier`, `floors_cleared_in_window`, `hero_levels_gained`); has an "Acknowledge" Button that calls `SceneManager.hide_modal(self)` and routes back to `guild_hall`. Uses `UIFramework.apply_parchment_panel` + `UIFramework.wire_touch_feedback` + `UIFramework.format_localized` per ADR-0008. | ui-programmer + ux-designer | 1.0d | S13-M1 (the modal stinger composition affects the screen's audio cue choreography) | Modal renders within 2 frames of `offline_rewards_collected`; gold/kills/floors fields populated; Acknowledge button dismisses cleanly; `SceneManager.show_modal(modal)` and `hide_modal(modal)` round-trip through PAUSED→IDLE state per Story 009 contract; subscribes once (no double-fire on hot-reload). |
| S13-M3 | **OE Story 10 — E2E offline replay budget verification test** | qa-tester + gameplay-programmer | 0.5d | S13-M2 done | `tests/integration/offline_progression_engine/end_to_end_offline_replay_test.gd` simulates cold launch → synthetic offline_elapsed_seconds → replay → summary → screen. Asserts AC-OE-12 (5s ADVISORY total wall-clock budget on dev hardware; flagged as advisory because min-spec mobile validation requires real device, not headless CI) + AC-OE-13 (16ms BLOCKING per-chunk wall-clock budget — verifiable via `summary.total_replay_wall_time_ms / summary.chunks_consumed` proxy). |
| S13-M4 | **`tests/PATTERNS.md` authoring** — distill captured patterns from Sprint 12 retro into a reusable doc | qa-lead + godot-gdscript-specialist | 0.25d | none (parallel) | Doc covers: gdunit4 signal API surface (the canonical and the forbidden), Array-spy lambda pattern, hygiene-barrier pattern (reset-on-entry-and-exit), ConfigFile path-override pattern, async-API-change-regression-audit checklist, debug-build spy field pattern (`_test_play_*_log` from AudioRouter). Replaces ad-hoc rediscovery in future test-authoring work. |

**Sprint 13 Must Have total**: ~2.25–3.25d depending on audio-sourcing decision branch (silent: 0.5d M1 + 1.0d M2 + 0.5d M3 + 0.25d M4 = 2.25d; non-silent: 1.5d M1 + 1.0d M2 + 0.5d M3 + 0.25d M4 = 3.25d). Both fit within 7.2-day available capacity with substantial Should Have buffer.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S13-S1 | **S10-S1 carry-forward — Story 014 orchestrator state advancement during SceneManager TRANSITIONING** | gameplay-programmer + godot-specialist | 1.25d | none |
| S13-S2 | **S10-S3 carry-forward — scene_manager test env flakes cleanup** | godot-gdscript-specialist | 0.5–1.0d | none (the `_settings_cfg_path` pattern from S12-S2 is part of the fix) |
| S13-S3 | **M3 Stories 5-6 — cost-stability invariant tests + Save/Load schema migration scaffold** (per recruitment-system.md §J) | gameplay-programmer + qa-tester | 0.75d | none |
| S13-S4 | **`reduce_motion` Settings overlay UI** (the surface owned by Settings GDD #30 — but the plumbing is wired in S12-S2; this story authors the toggle Control + label + screen-reader hooks) | ui-programmer + accessibility-specialist | 0.5d | depends on Settings GDD #30 authoring (not yet started) |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S13-N1 | **AudioRouter ADR for `_test_play_*_log` debug-spy pattern** — codify the convention if a 2nd autoload adopts it. If only AudioRouter uses it through Sprint 13, defer to Sprint 14+. | godot-gdscript-specialist | 0.25d | (gating: 2nd consumer must exist) |
| S13-N2 | **S10-N2 carry-forward — re-dispatch shortcut on main_menu** | ui-programmer | 0.5d | none |
| S13-N3 | **Audio bus volume sliders in Settings overlay** — pairs with S13-S4; Master/Music/SFX 3-slider layout per audio-system.md §G. | ui-programmer + audio-director | 0.25d | depends on S13-S4 + Settings GDD #30 |
| S13-N4 | **M3 Story 7 — RecruitScreen wire-up** | ui-programmer + ux-designer | 0.75d | needs UX pass for recruit-card layout |

## Sprint 13 sequencing recommendation

- **Day 1 morning**: S13-M1 audio sourcing decision (gating). If decision is "ship silent", proceed; if "source", commission/AI-generate the assets.
- **Day 1 afternoon**: S13-M4 `tests/PATTERNS.md` (parallel; no deps).
- **Day 2-3**: S13-M2 Return-to-App Screen authoring + integration with SceneManager.show_modal + AudioRouter chime cascade verification.
- **Day 3-4**: S13-M3 E2E offline replay test.
- **Day 4-7**: cherry-pick Should Haves in priority order — S13-S2 (test env flakes; biggest debt + load-bearing for any future sprint), S13-S1 (orchestrator state advancement), S13-S3 (recruitment cost-stability + schema scaffold).
- **Day 7+**: Nice to Haves OR pre-emptive Sprint 14 work (if the buffer allows it; Sprint 12 retro warns NOT to expect the Sprint 11 / 12 absorption ratio to repeat).

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **S13-M1 sourcing decision blocks more than the audio surface** — if the decision is "commission" and commission turnaround > 1 sprint, Sprint 13 ships silent regardless. | MEDIUM | LOW (silent fallback is clean) | Make the decision binary on Day 1; if commission timeline > 9 days, ship silent for MVP and defer non-silent to Sprint 14+. |
| **Return-to-App Screen UX has no design pass** — `/ux-design` for the cozy summary layout has not run. The screen may look generic or violate the cozy-register pillar. | MEDIUM | MEDIUM | Run `/ux-design return-to-app-screen` BEFORE S13-M2 implementation begins. Don't author the screen blind. Estimate 0.25d for the UX pass; pre-flight before Day 2. |
| **The 5s ADVISORY budget (AC-OE-12) cannot be verified on dev hardware alone** — min-spec mobile is the actual target. Headless CI on macOS dev box cannot model min-spec. | LOW | LOW | Mark S13-M3 assertions as ADVISORY explicitly; budget compliance is a post-launch profiling task not a Sprint 13 blocker. The structural test (algorithm completes; `total_replay_wall_time_ms` is populated) is the ship-gate; the wall-clock comparison is a soft check. |
| **No pre-emptive buffer means Day 5 slippage is real** — Sprints 11-12 had heavy Day 0 absorption that masked per-day variance. Sprint 13 will surface real day-by-day slippage. | HIGH | MEDIUM | Hold strict 1.0× plan estimates. Defer aggressively if any Must Have hits >1.5× its estimate. Sprint 14 backlog is the safety valve. |
| **`_settings_cfg_path` pattern not yet adopted across all autoloads — the contamination problem will recur** when Sprint 13 introduces another `user://*.cfg` consumer (likely S13-S4 Settings overlay). | MEDIUM | LOW | When authoring any new ConfigFile-reading autoload in Sprint 13+, follow the path-override pattern from `feedback_test_isolation_user_configfile.md`. Add to `tests/PATTERNS.md` (S13-M4) so the precedent is discoverable. |

## Dependencies on External Factors

- **Audio sourcing budget / vendor availability** — gates S13-M1 non-silent path. Out of engineering scope; needs project-level approval.
- **UX design pass for Return-to-App Screen** — gates S13-M2. Needs `/ux-design` invocation OR a quick mockup. Out of engineering scope until the design pass runs.
- **Settings GDD #30 authoring** — gates S13-S4 Settings overlay UI. Currently unscheduled. If it doesn't land by Day 5, S13-S4 falls out of scope for Sprint 13.
- **ADR-0014** ✓ Accepted — gates S13-M2 (modal coordination — show_modal/hide_modal already shipped in S12-S2).

## Definition of Done for Sprint 13

- [ ] All 4 Must Have tasks (S13-M1 through S13-M4) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] Full unit + integration sweep ≥1450 tests, 0 failures, 0 errors
- [ ] Audio sourcing decision is documented (ADR or sprint-plan note) — silent OR non-silent, no ambiguity
- [ ] Manual smoke: cold launch with persisted save → 30+ minutes elapsed → reopen → Return-to-App modal renders → tap acknowledge → routes to guild_hall → audio cascade verified (or silently confirmed if S13-M1 decision was silent)
- [ ] Sprint 13 retrospective committed at `production/retrospectives/sprint-13-retrospective-<date>.md`

## Sprint 14+ candidates (post-Sprint-13)

- M3 Stories 5-7 finish (RecruitScreen UI work)
- HD-2D shader pass (tilt-shift depth-of-field, warm-light overlays per Visual Identity Anchor)
- Full XP curve formula (deferred from S10-M4 stub — replace `+1 per clear` with real progression)
- Audio Stories 6-7 (hydration suppression hook + post-launch tunable curves)
- Story 014 (if S13-S1 doesn't land it)
- M3 schema migration when first save-version bump occurs (currently V1.0; bump triggers on adding a new save consumer or changing an existing field shape)
- ADR-candidate authoring sweep — S12 surfaced multiple candidates (audio asset sourcing, debug-spy pattern, ConfigFile path migration to envelope per OQ-7)

## Notes

- Authored 2026-05-06 by post-Sprint-12 close-out work (autonomous-execution session, 12-commit pre-emptive sprint absorbtion). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 13 kickoff (2026-06-08).
- The Sprint 13 nominal date range follows the same 9-working-day cadence as Sprints 10-12.
- Sprint 12's autonomous Day-0 closure pattern is NOT expected to repeat — the pre-emptive buffer is exhausted. Sprint 13 must execute day-by-day at planned pace.
- The cozy-register MVP polish bar is the Sprint 13 sprint goal. After Sprint 13, remaining work is HD-2D visual polish + balance tuning + content authoring (Sprint 14+ scope).
