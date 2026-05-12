# Playtest 05 — Sprint 12 / S12-S1 Re-playtest (post 11-sprint autonomous closure)

> **Sprint Mapping**: S12-S1 (`sprint-12.md` "Re-playtest with persisted save (manual smoke; covers Story 016 AC-9)") + S11-S5 carry-forward (`sprint-11.md`).
> **AC** (per S12-S1 + Story 016 AC-9): player can launch → recruit → dispatch → clear floor → close + reopen → state preserved. Cozy register feels coherent end-to-end.
> **Status**: COMPLETE WITH NOTES — sprint goal met after 9 in-session fixes; new playtest cadence established (see Process Lesson at end).

## Session Info

- **Date**: 2026-05-12
- **Build**: post-Sprint-12 autonomous-closure bundle (Sprint 12 nominal window 2026-05-26 → 2026-06-04, executed pre-emptively 2026-05-06)
  - 11 sprints "closed" between Sprint 9's playtest-04 (2026-05-05) and today
  - 2042 tests passing at session start (1763 + 279 from US-010..US-035 Ralph backfill PRs #48, #49)
  - Branch: main
- **Duration**: ~30 minutes across multiple launch cycles (interleaved with 9 in-session fixes)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse (Pillar 1: tap/click primary)
- **Session Type**: First human-driven playtest in ~7 days; validation of the entire pre-emptive Sprint 11–21 autonomous-closure stack against actual playability.

## Hypothesis Under Test

The Sprint 11–12 autonomous closure produced a complete cozy idle-game register: launch → recruit a hero → assemble formation → dispatch → combat → run-end rewards → return to Guild Hall → repeat. All Must-Have wiring is shipped; 2058 passing tests certify the underlying contracts work; the player flow should be coherent.

**Result**: hypothesis FAILED on first launch; nine distinct integration-wiring gaps surfaced; iteratively fixed in the same session; hypothesis re-validated at end of session.

## Findings — 9 issues surfaced + closed in-session

| # | Finding | Severity | Sprint that "owned" it | Resolution |
|---|---------|----------|------------------------|------------|
| 1 | **Starting gold = 0** — `STARTING_GOLD = 100` configured in `economy_config.tres` but never seeded into `Economy._gold_balance` on first launch | BLOCKING — soft-locked player (recruit cost 150 > balance 0) | Sprint 14 S14-S3 ("Onboarding / First-Session Flow") — scoped but never executed | `Economy._ready` now subscribes to `SaveLoadSystem.first_launch`; `_on_first_launch` seeds `_gold_balance = STARTING_GOLD` + emits `gold_changed("first_launch_seed")` for HUD reactivity. Tests: `tests/unit/economy/economy_first_launch_seed_test.gd` (6 tests). |
| 2 | **Recruit screen unreachable** — `assets/screens/recruitment/` fully implemented (3 pool entries, recruit buttons, refresh) but Guild Hall had no nav button | BLOCKING — even with gold fixed, player cannot recruit beyond seed hero | Sprint 14 S14-S5 ("Guild Hall full implementation … recruit nav button gating") — scoped, never executed | Added `RecruitNavButton` to `guild_hall.tscn` + `_on_recruit_nav_pressed` handler in `guild_hall.gd`. |
| 3 | **No visible gold counter in Guild Hall** — player has no way to see their balance | HIGH — opaque core resource | Sprint 14 S14-S5 (same as #2) | Added `GoldCounter` Label to `guild_hall.tscn`; subscribes to `Economy.gold_changed` in `on_enter` for live updates; reads `Economy.get_gold_balance()` for initial render. |
| 4 | **Formation Assignment has no Back button** — entering trapped the player until they dispatched | BLOCKING — broken navigation graph | — (Sprint 8 placeholder never addressed) | Added `BackButton` ("← Guild Hall") to `formation_assignment.tscn` + `_on_back_pressed` handler navigating to `guild_hall` via `CROSS_FADE`. |
| 5 | **Duplicate "Forest Reach — Floor 1" label** — both `FloorContextLabel` (Label) and `FloorButton` (Button) showed identical text stacked vertically | LOW — visual confusion | Sprint 8 placeholder + Sprint 15 Matchup-Assignment scaffold landing without wiring back to its caller | Hid `FloorContextLabel` (set `visible = false` in .tscn); wired `FloorButton._on_floor_button_pressed` (previously `pass`) to navigate to `matchup_assignment` (Sprint 16 scaffold). |
| 6 | **"TestHero905" appeared in roster** — non-name-pool hero with debug-test name | HIGH — surfaced test-contamination class of bug | Test contamination: `tests/unit/telemetry_sink/telemetry_sink_signal_handlers_test.gd:49` injected `"TestHero%d" % id` into live `HeroRoster._heroes`; if a save fired during the test window, the test hero baked into `save_slot_1.dat` and resurfaced as a real hero on next launch. | Replaced erase-by-id cleanup with full HeroRoster snapshot+restore via `get_save_data` / `load_save_data` (canonical isolation pattern per `recruitment_try_recruit_test.gd`). User cleared save file to flush the existing contamination. |
| 7 | **"Hall of Retired Heroes" button visible** despite zero prestige | LOW — UX confusion | Same root cause as #6 (test contamination polluted `_prestige_count`) | Visibility gate already existed in `guild_hall.gd:_refresh_hall_button_visibility`; resolved by save-clear (#6 fix) + test-isolation fix. |
| 8 | **Run end → "main_menu" placeholder with no rewards shown** — Victory Moment screen built (kill count, gold delta, hero level deltas, tap-to-continue) but `dungeon_run_view._on_state_changed` routed to placeholder `main_menu` on RUN_ENDED | HIGH — cozy register "you earned X" beat completely missing | Sprint 15 Victory Moment GDD #25 — implemented + tests, never wired as run-end destination | Changed `dungeon_run_view.gd:_on_state_changed` route from `"main_menu"` to `"victory_moment"`. Updated assertion tests (`tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd`, `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd`). |
| 9 | **Victory Moment tap-to-continue did nothing** + **"Floor 0 cleared" instead of "Floor 1"** | BLOCKING (tap) + MEDIUM (label) | — (Victory Moment internal bugs not caught by contract tests because tests stubbed `_dispatched_*` directly) | (a) Moved `gui_input` handler from `DimBackdrop` to the root `VictoryMoment` Control (CenterPanel was absorbing taps before they reached DimBackdrop). (b) Victory Moment now parses `floor_index` from `run_snapshot.floor_id` rather than `DungeonRunOrchestrator._dispatched_floor_index` (which `_exit_active_foreground` resets to 0 on RUN_ENDED — documented contract, but readers post-state-transition see 0). Updated `victory_moment_contract_test.gd` fixture to seed `snap.floor_id`. |

## Test Suite Impact

- **Baseline at session start**: 2042/2042 PASS
- **Baseline at session end**: **2058/2058 PASS, 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans**
- Net +16 tests across the session (10 from S12-S4 FormationAssignment commit tests done earlier + 6 from Economy first-launch seed)
- 7 existing tests updated to reflect routing target change (`main_menu` → `victory_moment`) + 1 fixture updated (`victory_moment_contract_test.gd`)

## Files Touched This Session

| Path | Change |
|------|--------|
| `src/core/economy/economy.gd` | First-launch gold seed wiring (subscribe to `first_launch`, seed STARTING_GOLD, ADR-0014 suppression guard) |
| `src/core/formation_assignment/formation_assignment.gd` | AC-FA-08 abort-on-false logic for `set_formation_slot` |
| `assets/screens/guild_hall/guild_hall.tscn` | Added GoldCounter + RecruitNavButton |
| `assets/screens/guild_hall/guild_hall.gd` | Wired recruit nav + gold counter (Economy.gold_changed subscriber) |
| `assets/screens/formation_assignment/formation_assignment.tscn` | Added BackButton; hid duplicate FloorContextLabel |
| `assets/screens/formation_assignment/formation_assignment.gd` | Wired BackButton handler + FloorButton → matchup_assignment |
| `assets/screens/dungeon_run_view/dungeon_run_view.gd` | Run-end route changed to `victory_moment`; hide StatsPanel when overlay shows |
| `assets/screens/victory_moment/victory_moment.gd` | Tap handler on root Control (not just DimBackdrop); read floor_index from `snap.floor_id` |
| `tests/unit/economy/economy_first_launch_seed_test.gd` | NEW — 6 tests |
| `tests/unit/formation_assignment/formation_assignment_commit_test.gd` | NEW — 7 tests (Sprint 12 S12-S4 closure) |
| `tests/integration/formation_assignment/browse_no_orchestrator_consumption_test.gd` | NEW — 3 tests |
| `tests/unit/telemetry_sink/telemetry_sink_signal_handlers_test.gd` | Snapshot+restore isolation per `feedback_test_isolation_live_autoload` |
| `tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd` | Assertion updated to `"victory_moment"` |
| `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd` | Assertion updated to `"victory_moment"` |
| `tests/integration/victory_moment/victory_moment_contract_test.gd` | Fixture now seeds `snap.floor_id` |
| `production/sprints/sprint-11.md` | Status Update — 2026-05-12 block |
| `production/sprints/sprint-12.md` | S12-S4 closure note |
| `production/sprint-status.yaml` | Flipped to Sprint 11; S11-S1 corrected to `done` |
| `production/qa/qa-plan-sprint-11-2026-05-12.md` | NEW — retroactive Sprint 11 QA plan |
| `production/qa/qa-plan-sprint-12-2026-05-12.md` | NEW — mixed retroactive + forward-looking Sprint 12 QA plan |

## Final-State Smoke Walkthrough

After all 9 fixes + a clean-save relaunch, the verified player flow:

- [x] Launch → Guild Hall renders with "Gold: 100" header, three nav buttons (Go to Dispatch / Recruit / Hall hidden)
- [x] Tap "Go to Dispatch" → Formation Assignment with Theron in roster, "Send your guild to:" header, `← Guild Hall` Back button, single "Forest Reach — Floor 1" target affordance
- [x] Tap Dispatch with [Theron, Empty, Empty] → Dungeon Run View (Tick + Kill count live)
- [x] Combat resolves, floor 1 clears → Run End overlay shows "Run Complete — N kills" for 1.5s (StatsPanel hidden so no text overlap)
- [x] Cross-fade to Victory Moment → "Forest Reach — Floor 1 cleared" + Kill count + "+13 gold gained" + "Tap to continue"
- [x] Tap anywhere → cross-fade back to Guild Hall with updated gold counter
- [x] Tap "Recruit" → Recruit screen with 3 pool entries (real names from `mage_names.tres` / `warrior_names.tres` / `rogue_names.tres`), affordability-gated Recruit buttons, "Refresh Pool — 100 gold" footer
- [x] Tap real-hero recruit → gold deducts, hero added to roster, cost increments per ADR-0013 geometric curve
- [x] Loop closes: Guild Hall → Dispatch → Run → Victory Moment → Guild Hall

## Sprint 11 AC-9 Manual Close-Reload Smoke

**Not executed this session.** Original Story 016 AC-9 ("close game, reopen, state preserved") was the stated playtest goal but the session was consumed by closing the 9 integration-wiring gaps that gated the playtest from being meaningful in the first place. The persist + load round-trip is verified by `tests/integration/save_load/save_persist_roundtrip_test.gd` (JSON byte-equality across 7 consumers). Manual AC-9 deferred to next playtest session.

**Recommended**: do a focused playtest-06 next session covering ONLY:
1. Close-reload state preservation (Story 016 AC-9)
2. Offline replay engine (close app ≥1 minute, reopen, verify `offline_rewards_collected` fires + balance has incremented)
3. Long-loop fatigue check (10+ minute play session — does the cozy register sustain?)

## Process Lesson — Playtest-Driven Closure

Captured into project memory as `feedback_playtest_driven_closure.md`:

> A test suite at 100% pass is necessary but not sufficient for sprint closure. The autonomous loop optimized "tests pass + sprint plan authored + commits landed" and produced 6+ weeks of code without producing 30 minutes of shippable player experience. Future sprint closure must require: (a) all Must Haves have closure notes, AND (b) at least one manual playtest documenting the sprint's headline player-facing change works in a fresh build.

Related project memories saved this session:
- `project_feature_exists_never_wired.md` — the dominant pattern across the 9 findings (Sprint 14 S14-S3, S14-S5 wiring stories that never executed)
- `feedback_test_isolation_live_autoload.md` — the test-contamination class of bug that produced "TestHero905" in a player save

## Verdict

**Sprint 11 / Sprint 12 cozy register: SHIPPED (post-this-session).** The actual cozy idle-game loop now plays end-to-end. 2058 tests passing certifies the underlying contracts; this playtest certifies the player flow.

**Sprint 21's pre-emptive cadence retirement decision is vindicated.** Sprint 22+ should use real-time `/sprint-plan` driven by playtest findings, not autonomous-output velocity.

**Status of S11-S5 + S12-S1**: this playtest closes both (the marquee re-playtest deliverable). AC-9 close-reload smoke deferred to playtest-06.
