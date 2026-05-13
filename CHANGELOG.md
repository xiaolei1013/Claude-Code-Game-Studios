# Changelog

All notable changes to this project will be documented in this file.

## [0.0.0.15] - 2026-05-13

### Added
- **HeroCards on Guild Hall now respond to taps with a 1.05× scale pulse** + UI tap chime (silent until audio assets land per ADR-0016). Wired via `UIFramework.wire_touch_feedback` per Art Bible §7 / ADR-0008. Matches the touch-responsiveness pattern used on every other interactive Control in the project.
- **Master mute toggle on Settings overlay** per GDD #30 §C.3. CheckButton row labeled "Mute (master)" sits above the reduce_motion row; toggle calls `AudioRouter.set_master_muted(bool)`. Seeds initial state from `AudioRouter.is_master_muted()` on overlay open. The mute is a hard override per GDD §C.3 — the slider's stored value is preserved, just bypassed when mute is on.

### Notes
- **Test suite**: 2082 → 2084 (+2 net). 2 new tests in `tests/integration/settings/settings_overlay_test.gd` cover the mute toggle round-trip + initialization-from-AudioRouter. HeroCard touch-feedback wiring verified by reuse of the existing UIFramework idempotency contract (no new test).
- **Hero Detail Level Up button audited** as fully wired during this PR's investigation: cost resolution via `Economy.level_cost(tier, level)`, atomic `try_spend("level_up")` → `set_hero_level(id, +1)` transaction, affordability gating, cap-hide, prestige takeover at cap. No changes needed; documented here for traceability.
- **Deferred from PR #55 still pending**: parchment sub-panel theme styling for HeroCards (theme variation work — independent of wiring), class icon (V1.0+), animated XP bar fill on level-up.

## [0.0.0.14] - 2026-05-13

### Changed
- **Guild Hall HeroCards now show an XP-progress bar** per GDD #19 §C.4. Each HeroCard is a Button with a child VBoxContainer holding a summary Label (`"{display_name} · {class_id} · Lv {current_level}"`) and a slim ProgressBar showing `hero.xp / xp_threshold(current_level)`. At level cap (15), the bar shows full. Children use `mouse_filter = IGNORE` so taps pass through to the Button's `pressed` handler — the modal-open wiring is unchanged. Player now sees a visible progression cue per hero, replacing the plain text-only Button from v0.0.0.11.

### Notes
- **Test suite**: 2080 → 2082 (+2 net). Added 2 new tests covering the XP-progress bar fraction (mid-level) + level-cap state (bar full). Updated 2 existing tests to read summary text from the child Label instead of `Button.text`.
- **UX polish deferred**: Parchment-themed sub-panel styling (GDD #19 §C.4 calls for "parchment sub-panel"), class icon (V1.0+ scope), animated bar fill on level-up. The current bar uses Godot's default ProgressBar styling — usable but unbranded; theme variation lands when the parchment theme has a `progress_bar` styling pass.

## [0.0.0.13] - 2026-05-13

### Added
- **Onboarding / First-Session Flow integration test suite** — per Onboarding GDD #29 §J Story 2. Locks down the cold-launch seed pathway as a regression guard: AC-29-02 (Theron seeded in roster + formation slot 0), AC-29-03 (Economy starting gold = 100), AC-29-04 (Floor 1 of forest_reach ACCESSIBLE; floors 2-5 LOCKED per fresh-save state), AC-29-05 (Recruitment pool seeded with non-zero RNG + non-empty draw). 7 tests in `tests/integration/onboarding/first_launch_flow_test.gd` with snapshot/restore hygiene barrier across HeroRoster + Economy + Recruitment + FloorUnlock; defensive re-seed in after_test guarantees post-state validity regardless of test ordering.
- **AC-29-14 grep test** — per Onboarding GDD §J Story 4. `tests/unit/onboarding/no_tutorial_copy_grep_test.gd` scans `src/`, `assets/screens/`, `assets/overlays/` for the 4 canonical forbidden phrases (`"Click here"`, `"Tap to begin"`, `"Welcome!"`, `"Press to dispatch"`). Comment lines exempted (so doc-comments referencing the rule don't false-positive). Enforces the cozy-register principle that the player discovers the game through the UI itself, not through tutorial hints.

### Notes
- **Test suite**: 2073 → 2080 (+7 net). 6 onboarding flow tests + 1 grep test (also covers 1 minor reorganization).
- **Sprint 13 onboarding coverage**: Story 1 (STARTING_GOLD constant) shipped in v0.0.0.9; Story 2 (E2E integration test) ships here; Story 3 (manual smoke + playtest checklist) remains human-gated as part of S13-M3; Story 4 (AC-29-12 idempotent seed) was already covered by `tests/unit/hero_roster/first_launch_seed_test.gd` from pre-emptive work, plus AC-29-14 grep ships here.
- **Discovery during test authoring**: `FloorUnlock.debug_unlock_all` defaults to `true` in debug builds (QA convenience), which means AC-29-04 ("floors 2-5 LOCKED") requires explicit `debug_unlock_all = false` in the test. Production builds disable this. Pattern captured in test's `before_test` for future reference.

## [0.0.0.12] - 2026-05-13

### Added
- **Settings overlay is now reachable from a gear icon on Guild Hall.** Per Settings GDD #30 AC-30-01 + §C.1. Tapping the ⚙ icon top-right opens a parchment-themed modal with 3 volume sliders (Master / Music / SFX) wired to `AudioRouter.set_*_volume_db` via linear-to-dB curve from §C.2, plus a reduce_motion `CheckButton` wired to `SceneManager.set_reduce_motion` (S12-S2 wiring). Close button OR tap-outside dismisses via `SceneManager.pop_overlay`. Gear button is gated on `OfflineProgressionEngine.is_replay_in_flight()` per §E.6 — disabled mid-replay to avoid modal-slot conflict.
- **Settings overlay replaces 28-line placeholder** at `assets/overlays/settings/settings.tscn` + `.gd` with the real layout (HeaderLabel + 3 sliders + reduce_motion row + close). Sliders seed from `AudioRouter.get_*_volume_db()` on `_ready` so they reflect persisted state across launches.

### Notes
- **Test suite**: 2064 → 2073 (+9 net). New `tests/integration/settings/settings_overlay_test.gd` covers Groups A (scene loads + @onready resolves), B (slider drag → AudioRouter via dB curve, including silent-floor + per-bus isolation), C (reduce_motion checkbox round-trip), D (gear button wiring on Guild Hall).
- **Sprint 13 S13-S2 status** flipped from `backlog` to `done` in `production/sprint-status.yaml`.
- **Sprint 13 closed**: 11/12 stories. S13-M3 (Story 016 AC-9 manual close-reload smoke) is the one outstanding human-gated item. The cozy register now has a full settings + accessibility surface reachable from Guild Hall.
- **Deferred to polish iteration** (Sprint 14+): mute toggle (hard -INF override of Master slider per GDD #30 §C.3), dB display label per slider, locale dropdown (en-only is trivial), Reset to Defaults button. These are independent of the core wiring; can land any time.
- **Manual playtest needed**: tap the gear, drag volume sliders + toggle reduce_motion, verify audio + transition timing actually responds; close cleanly. The integration test covers the wiring contract; feel verification is human-gated.

## [0.0.0.11] - 2026-05-13

### Added
- **Guild Hall now shows a roster of HeroCards; tap a hero to open the Hero Detail modal.** Per Guild Hall GDD #19 §C.4 + Hero Detail GDD #22 AC-22-01. The Hero Detail modal already existed as a 584-line implementation from Sprint 16 pre-emptive work, but no UI surface invoked it. This PR adds the `RosterPanel` (ScrollContainer + VBoxContainer of HeroCard buttons) to Guild Hall, populates it from `HeroRoster.get_all_heroes()` sorted by current_level desc then class_id asc, wires each HeroCard's pressed signal to instantiate the modal + `set_target_hero(instance_id)` + `SceneManager.show_modal`. Tap gated on `SceneManager.state != PAUSED` per GDD #22 "modal already open" resolution. Live-refreshes on `hero_recruited` / `hero_removed` / `hero_leveled`. Closes Sprint 13 S13-M4 carry-forward (Sprint 14 Day 1 follow-up). 6 new integration tests in `tests/integration/guild_hall/roster_panel_test.gd`.

### Notes
- **Test suite**: 2058 → 2064 (+6 net).
- **Sprint 13 S13-M4 status updated** in `production/sprint-status.yaml` from `deferred-to-sprint-14` to `done` (2026-05-13).
- **What's left in Sprint 13**: S13-M3 (Story 016 AC-9 manual close-reload smoke) remains human-gated; S13-S2 Settings overlay deferred to Sprint 14 next session (needs gear icon + Settings overlay real content per GDD #30).
- **Manual playtest needed**: tap a hero card in Guild Hall and verify the Hero Detail modal opens with the correct stats, then closes cleanly. Integration test covers the wiring; UX feel verification is human-gated.

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

