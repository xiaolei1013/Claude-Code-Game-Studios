# Changelog

All notable changes to this project will be documented in this file.

## [0.0.0.10] - 2026-05-13

### Changed
- **Sprint 13 audit + scaffold archival** — Sprint 13 (real-time-authored 2026-05-13) Day 0 audit found 5 of 12 stories already shipped pre-emptively during the 2026-05-06 → 2026-05-09 autonomous-execution window: S13-M1 (audio sourcing decision via ADR-0016 silent-MVP), S13-M2 (Return-to-App Screen 282-line implementation + integration test + locale + OfflineProgressionEngine routing), S13-S1 (OE Story 10 E2E budget verification test, 411 lines), S13-S3 (HeroLeveling real XP curve via HeroRoster.add_xp + Orchestrator.xp_per_floor_clear / xp_per_kill data-driven from EconomyConfig), S13-N2 (tests/PATTERNS.md, 460 lines). Sprint plan + sprint-status.yaml updated to reflect these as DONE pre-emptive. S13-M4 (Hero Detail overlay) and S13-S2 (Settings overlay) deferred to Sprint 14 pending UX pass — both have placeholder overlay files at the SceneManager-registered paths plus pre-emptive real implementations that aren't wired to player-reachable surfaces yet. S13-M3 (Story 016 AC-9 close-reload manual smoke) remains the one outstanding human-gated Must Have.
- **Sprint 14-21 pre-emptive scaffolds archived** to `production/sprints/archive/` per S13-S4. The `PRE-EMPTIVE-CADENCE-RETIRED.md` README at the sprints root (authored 2026-05-09 by Sprint 21 S21-S3 retirement work) documents the cadence retirement decision and the lessons that motivated it. Sprint 14+ planning uses real-time `/sprint-plan` invocation exclusively.

### Notes
- **Audit lesson captured** — Future real-time sprint planning should run a "what's already shipped" sweep against the proposed scope before finalizing Must Haves. The 2026-05-13 Sprint 13 plan was authored against the written spec, not the current code state — 5 of 12 stories turned out to be already-done. Pattern is the inverse mirror of the previously-captured `project_feature_exists_never_wired.md` memory: in this case, features exist AND are wired, but the planner didn't realize during scoping.
- **Sprint 13 effective state**: 9 of 12 stories closed (M1, M2, M3 skipped pending human session, S1, S2 deferred, S3, S4, M4 deferred, N1 gated, N2, N3 gated, N4 end-of-sprint). The substantive autonomous-doable work is complete; the remaining 3 are human-gated or blocked on UX passes.

## [0.0.0.9] - 2026-05-13

### Added
- **Guild Hall now shows gold balance and has a Recruit button** — Players can see their current gold balance at the top of Guild Hall, and a Recruit button navigates to the recruitment screen. Previously the Recruit screen existed but no UI route reached it; the cozy onboarding loop (dispatch → earn → recruit → fill formation) was unreachable. Closes the Sprint 14 S14-S5 wiring gap.
- **Formation Assignment now has a Back button** — Tapping `← Guild Hall` returns the player to Guild Hall without requiring a dispatch first. Closes a navigation deadlock where the only escape from this screen was running a full dungeon.
- **Floor button on Formation Assignment opens the Matchup Assignment screen** — Tapping the current target floor now lets the player browse biomes and select a different floor; the selection is applied on return. Previously a `pass` placeholder from Sprint 8. Closes a Sprint 16 scaffold that shipped without a caller.
- **Run-end now routes to the Victory Moment screen** — After clearing a floor, the player sees a "Forest Reach — Floor N cleared" summary with kill count, gold gained, and tap-to-continue (back to Guild Hall). Previously routed to a placeholder main menu with no rewards shown.

### Fixed
- **First-launch players now start with 100 gold instead of 0** — `Economy._on_first_launch` now subscribes to `SaveLoadSystem.first_launch` and seeds `_gold_balance = EconomyConfig.STARTING_GOLD`, emitting `gold_changed` for HUD reactivity. Closes the documented Sprint 14 S14-S3 wiring gap that soft-locked first-session players (recruit cost 150 > balance 0).
- **`FormationAssignment.commit()` now aborts on invalid hero_id mid-write** — Implements AC-FA-08: when `HeroRoster.set_formation_slot` returns false (unknown hero_id), `commit()` push_errors with slot+hero_id detail, aborts further slot writes, and does NOT emit `formation_reassignment_committed`. HeroRoster is left in a partial-write state for the screen to re-query.
- **Victory Moment now reads floor_index from `run_snapshot.floor_id`** — The screen previously read `DungeonRunOrchestrator._dispatched_floor_index`, which `_exit_active_foreground` resets to 0 at the ACTIVE_FOREGROUND → RUN_ENDED transition. Players saw "Floor 0 cleared" on every run. The snapshot's `floor_id` survives the state transition; floor_index is parsed back out.
- **Victory Moment tap-to-continue now works** — The `gui_input` handler is now wired to the root `VictoryMoment` Control in addition to `DimBackdrop`. CenterPanel sits on top of DimBackdrop and was absorbing taps before they reached the backdrop's handler.
- **Formation Assignment now reflects the matchup target selected on the Matchup Assignment screen** — `on_enter` now reads `FormationAssignment.get_target()` and updates the dispatch target. Previously the autoload accessors shipped (Sprint 15 S15-N1) but the consumer wiring was missing; selecting Floor 2 still dispatched to Floor 1.
- **Duplicate "Forest Reach — Floor 1" label on Formation Assignment is gone** — The redundant FloorContextLabel is hidden; the FloorButton serves as both display and tap affordance.
- **Run-end overlay no longer shows live tick/kill text bleeding through** — `StatsPanel` is now hidden when the run-end overlay shows. Both nodes were anchored at center 50% with the overlay's PanelContainer rendered with transparent background.
- **Telemetry sink test no longer leaks "TestHero" entries into player save files** — `tests/unit/telemetry_sink/telemetry_sink_signal_handlers_test.gd` now snapshot/restores HeroRoster's full state via `get_save_data` / `load_save_data` in `before_test` / `after_test`. The prior erase-by-id cleanup pattern was vulnerable to save-persistence leakage: if a save fired during the test window, the synthetic "TestHero%d" hero got baked into `save_slot_1.dat` and resurfaced on next launch.

### Notes
- **Cozy idle-game register now plays end-to-end** — Vertical slice validated through Forest Reach floors 1-5 in playtest-05 (2026-05-12). 9 player-facing wiring gaps surfaced and closed in-session. See `production/playtests/playtest-05-sprint-12-2026-05-12.md` for the full session record. Sprint 22+ planning shifts to real-time `/sprint-plan` driven by playtest findings per the Sprint 21 pre-emptive cadence retirement.
- **Test suite**: 2042 → 2058 (+16 net). +6 Economy first-launch tests, +7 FormationAssignment commit-contract tests, +3 AC-FA-09 cross-system tests. 4 existing assertions updated for the `main_menu` → `victory_moment` route change.

## [0.0.0.8] - 2026-05-10

### Fixed
- **TelemetrySink opt-in toggle now persists across launches** — Stage 2 telemetry shipped without the SaveLoadSystem.CONSUMER_PATHS registration, which meant the opt-in field would have reset to `false` on every launch (defeating the toggle's purpose once the Settings UI lands). Added `/root/TelemetrySink` as the 8th consumer path; `get_save_data` / `load_save_data` now round-trip the field through the save envelope under the `"telemetry"` namespace. Updated 3 existing CONSUMER_PATHS test assertions (size 7→8 + canonical-order list + happy-path-deferred sentinel). Also corrected a misleading autoload-rank comment in `telemetry_sink.gd` (Stage 2 commentary said "rank 19" using project.godot position; correct ADR-0003 canonical rank is 17, after AudioRouter at rank 16).

## [0.0.0.7] - 2026-05-10

### Added
- **Telemetry Events V1.0 Stage 2 — TelemetrySink autoload** — New `TelemetrySink` autoload (rank 19) implements the 5-event opt-in local-sink layer per the V1 taxonomy spec. Subscribes to gameplay signals (`SaveLoadSystem.first_launch`, `HeroRoster.hero_recruited`, `HeroRoster.prestige_completed_signal`, `DungeonRunOrchestrator.state_changed` filtered to DISPATCHING/RUN_ENDED). Each handler short-circuits when opt-in is OFF (the cozy-register default). When opted in, events are wrapped in the §D envelope (schema_version, timestamp_unix, ephemeral session_id, event_type, payload) and appended to `user://telemetry/events-YYYY-MM-DD.jsonl` with daily rotation. Save-consumer surface persists the opt-in toggle for future Settings UI wiring (consumer registration deferred to that PR; Stage 2 ships the autoload + signal infrastructure only).

## [0.0.0.5] - 2026-05-10

### Fixed
- **`FormationAssignment.detect_active_synergy` instance_ids fallback now functional** — The instance_ids-only path previously called a non-existent `HeroRoster.get_hero(id)` method via `has_method` guard, so it silently returned `""` for any caller not also providing the `heroes` key. Now resolves via `HeroRoster.get_all_heroes()` lookup map (the canonical idiom used by the orchestrator and the formation_assignment screen). Adds 3 regression tests locking in the fallback contract: happy path, unknown-id defensive, and empty-slot guard.

## [0.0.0.4] - 2026-05-10

### Added
- **Class Synergy V1.0 Story 4 — Formation panel synergy badge** — When a player assembles a formation that activates a class synergy (3-Warrior → Steel Wall, 3-Mage → Arcane Elite, 1+1+1 → Triple Threat), a localized badge now appears on the formation_assignment screen showing the synergy's display name and effect summary. The badge fades in over 0.4 seconds for full-motion players; reduce-motion players see it appear instantly with an alternate theme variation. State de-dup ensures rapid slot toggles within the same composition multiset don't re-trigger the glow tween or audio chime. Closes the V1.0 Class Synergy implementation epic.

## [0.0.0.3] - 2026-05-10

### Changed
- **Class Synergy V1.0 epic + Stories 1-3 documented retrospectively** — Implementation work shipped during Sprint 21 S21-M1/S1/S2 sessions had no per-story files (audit-cascade pattern). Created `production/epics/class-synergy/` with EPIC.md tracking + 3 story files (detection logic + RunSnapshot field, attribute_kill formula extension, audio + locale) marked Complete with full AC matrix and test evidence. Story 4 (UI badge wiring on formation_assignment screen) confirmed as the actual outstanding implementation work.
- **Sprints 15-21 catch-up retrospective** — Authored single consolidated retro at `production/retrospectives/sprints-15-through-21-catchup-retrospective-2026-05-10.md` covering all 7 sprints (windows nominally 2026-06-29 → 2026-09-07; actually executed 2026-05-07 → 2026-05-10 in one continuous 4-day autonomous session, ~114 commits). Per-sprint summary sections plus cross-window themes (MVP feature-complete inflection at S16, V1.0 design block closure at S20, pre-emptive cadence retirement at S21) plus lessons captured for project memory.

## [0.0.0.2] - 2026-05-10

### Added
- **Prestige Audio Cue (silent-MVP wiring)** — AudioRouter now subscribes to `HeroRoster.prestige_completed_signal` and routes a `sfx_prestige_completed` cue through the SFX/Reward bus with a 2-second throttle. The cue resource is intentionally absent in MVP per ADR-0016, so the sting is currently silent. When the audio asset lands, the fanfare becomes audible without further code changes.

### Changed
- **Class Synergy GDD #32 status flipped to FIRST-PASS DRAFT APPROVED** — `/design-review` resolved 2 blocking items in-session (broken `formation-assignment-screen.md` and `scene-manager.md` dependency references retargeted to the actual files; mobile-parity violation in E.3 rewritten as tap-to-reveal disclosure per `technical-preferences.md` Input rules) and applied 2 recommended revisions (audio knob single-source vs synergy-specific override; AC-CS-16 per-synergy vs compound multiplier scope clarified). Implementation gating now lifted; epic kickoff is a real-time scheduling decision.
- **Systems Index** — Prestige System (#31) outstanding list shortened: audio cue subscriber per ADR-0016 silent-MVP is now wired and tested. Class Synergy System (#32) flipped to "FIRST-PASS DRAFT APPROVED 2026-05-10".

## [0.0.0.1] - 2026-05-10

### Added
- **Prestige Completion Toast** — Guild Hall screen now displays a cozy toast when a hero completes their prestige, showing the hero's name as they retire. Toast fades over 4 seconds, matching the existing formation assignment and recruitment toast pattern.
- **Unit Tests** — Added comprehensive test coverage for prestige toast functionality, including hero name interpolation, missing name handling, and proper tween cleanup on rapid emissions.

### Changed
- **Systems Index Status** — Prestige System (#31) marked as "FIRST-PASS DRAFT IMPLEMENTED" with full AC closure summary across all story slices (logic, UI modal, Hall screen, animation, toast).

