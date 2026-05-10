# Epic / PRD: Test Coverage Backfill (Ralph V1 trial)

> **Dual-role doc**: this file serves as both (a) the project's epic-tracking document at `production/epics/test-coverage-backfill/EPIC.md` per the existing convention, AND (b) the Ralph PRD that `/ralph-skills:ralph` converts to `prd.json` for autonomous execution.

> **Status**: Authored 2026-05-10 as the first scoped Ralph autonomous-execution trial. Per the session-arc recommendation: low-risk Ralph trial (clear `passes` predicate, bounded scope, no design judgment per iteration). If this trial yields good results, expand Ralph scope to other paperwork-grade workstreams; if not, the work product (test coverage) is still useful and Ralph stays scoped tighter.

---

## Introduction

Godot has no built-in line-coverage tooling and gdunit4 doesn't produce coverage reports. Rather than block on tooling-setup work, this epic uses a **measurable proxy**: every public function (non-underscore-prefixed `func`) on every `src/core/*.gd` file should have at least one happy-path test plus at least one obvious-edge-case test.

The unit of work is **one source file → one test file**. Some source files are already at or above this bar (most autoloads ship with extensive test suites under different filenames). For those, the corresponding Ralph iteration audits + marks `passes: true` quickly. For files genuinely below the bar, the iteration writes the missing tests.

## Goals

- Every `src/core/*.gd` public function has ≥1 happy-path test + ≥1 obvious-edge-case test
- All tests follow `tests/PATTERNS.md` naming convention (`test_[scenario]_[expected_result]`)
- All tests use clear arrange/act/assert structure
- All tests pass against the live Godot 4.6 + gdunit4 setup
- No regression in existing 1529-test baseline
- Test files committed alongside any new test infrastructure (helper functions, fixtures) needed

## Non-Goals (Out of Scope)

- **Line-coverage tooling setup** (gcov, lcov, custom Godot instrumentation) — explicitly deferred. The proxy is good enough for this trial.
- **Refactoring source code for testability** — if a function is genuinely untestable without DI seams, the story for that file marks the function as `[DEFER: needs DI refactor]` in the story file's closure note rather than cracking the source open.
- **Integration tests** — this epic is unit-test backfill only. Integration tests live under `tests/integration/` and have their own gating per the existing project convention.
- **Performance tests** — separate scope; live under `tests/perf/`.
- **Test files for `tests/fixtures/` or `tests/probes/` themselves** — those ARE the test infrastructure, not subjects.
- **Visual / Feel / UI / Config-Data tests** per the `coding-standards.md` Test Evidence by Story Type table — those use screenshot evidence + manual walkthrough, not unit tests. This epic is Logic-tier only.
- **Modifying the `tests/PATTERNS.md` conventions** — Ralph follows the existing rules; PATTERNS.md changes are out-of-scope.

## Functional Requirements

- **FR-1**: For each `src/core/*.gd` file, a corresponding test file at `tests/unit/<system>/<basename>_test.gd` exists. Naming follows the convention in `tests/PATTERNS.md`.
- **FR-2**: Each test file covers EVERY public function (does NOT start with `_`) with at least one happy-path test asserting the documented return shape / behavior.
- **FR-3**: For functions with documented edge cases (per docstring or domain — null inputs, empty arrays, boundary values, error returns), each edge case has a corresponding test.
- **FR-4**: Test naming follows `test_[scenario]_[expected_result]` per `tests/PATTERNS.md` line 4.
- **FR-5**: Each test has a clear arrange/act/assert structure — the Ralph iteration must NOT ship a test like `func test_thing() -> void: assert_bool(true).is_true()`. Patterns from `tests/PATTERNS.md` §3 (hygiene barriers, before_test/after_test cleanup, autoload state reset) are applied.
- **FR-6**: Source files that already have ≥80% public-function coverage via existing test files (via grep audit, see implementation notes) mark the story `passes: true` without writing new tests.
- **FR-7**: Pure data classes (Resources, RefCounteds with no public methods beyond field accessors) are EXEMPT — story marks `passes: true` with note "no testable public surface".
- **FR-8**: Test files MUST NOT introduce new test failures in the existing suite. If a new test surfaces a real bug in source code, the story PAUSES (Ralph emits `<promise>BLOCKED</promise>` so the human reviews) — bug fixes are out of scope.
- **FR-9**: Each Ralph iteration appends a one-line summary to `production/epics/test-coverage-backfill/progress.txt` (Ralph's standard learnings file): `<US-NNN> <basename> | <passes_status> | <new_tests_added> | <notes>`.

## Technical Considerations

- **Audit predicate (per-file)**: Ralph runs `grep -nE "^func [a-z]" <source-file.gd>` to enumerate public functions. Then for each function name, `grep -rn "<func_name>" tests/` to confirm it appears in at least one test file. If the function name appears in test code with an `assert_*` call within ~5 lines, count it as covered.
- **Naming convention enforcement**: a simple grep at iteration end validates `func test_[a-z_]+ -> void` pattern. CI does NOT yet enforce this; future hardening pass can promote the grep to a static-analysis test.
- **Project memories load-bearing for this work**: Ralph's `CLAUDE.md` should reference: `project_typed_collection_test_fixtures` (typed Array/Dict literal-rejection), `project_godot_autoload_class_name_collision` (autoload reference patterns), `project_json_int_round_trip_typeof_pattern` (JSON.parse_string typeof), `project_gdunit4_signal_api` (assert_signal API quirks), `feedback_test_isolation_user_configfile` (path-override pattern), `feedback_async_api_change_caller_audit` (await-aware test fixtures), `feedback_gdunit4_spy_state_not_auto_cleared` (spy field cleanup in before_test).
- **Test structure reference**: existing exemplars to mirror — `tests/unit/audio_router/audio_router_signal_handlers_test.gd` (signal-subscriber autoload test pattern), `tests/unit/formation_assignment/class_synergy_detection_test.gd` (pure-function test pattern with groups), `tests/unit/save_load/autoload_skeleton_test.gd` (constant-table assertion pattern).
- **Hero injection pattern**: when test setup needs synthetic HeroRoster heroes, mirror `tests/unit/hero_detail/prestige_button_visibility_test.gd:30` (`HeroRoster._heroes[id] = fake; _injected_hero_ids.append(id)` with `after_test` cleanup).
- **Ralph branch shape**: one feature branch (`feat/test-coverage-backfill`), iterations commit directly to it. NOT one branch per story (the project's normal convention) — Ralph's pattern is single-branch-per-PRD.

## Success Metrics

- **Primary**: 45 of 45 stories report `passes: true`
- **Coverage delta**: at least N new test files created (where N ≈ count of files genuinely below the bar — likely 10-20)
- **Test count delta**: existing 1529-test baseline grows by the count of new tests added (probably +50-200)
- **Zero regressions**: 0 new failures in any pre-existing test
- **Naming convention compliance**: a grep at epic-end shows zero `test_*` functions violating the `[scenario]_[expected_result]` shape
- **Honest false-passes are caught**: at least one story BLOCKED because audit revealed a function whose existing test was a smoke check (e.g., `assert_bool(thing).is_not_null()` only) — this is a feature, not a failure

## Open Questions

- Should files in `src/core/<system>/` that are pure interface/abstract base classes (e.g., `combat_resolver.gd`, `matchup_resolver.gd`) be tested via their concrete implementations only (current convention), or get separate "interface contract" tests? **Default for V1**: skip — the concrete implementations cover the surface.
- Should the audit predicate handle private-function coverage at all? **Default for V1**: no — the proxy is "public functions only" per scope choice.
- What happens when Ralph's iteration discovers an existing test whose name violates the convention but content is fine? **Default for V1**: leave the existing test alone; only new tests must follow the convention. A separate rename-pass story is out of scope.
- Should the `progress.txt` file be committed per-iteration (Ralph default) or batched at end? **Default**: per-iteration commit, so each Ralph step's evidence is isolated.

---

## User Stories

Each story = one src/core file. Story IDs are stable; ordering reflects the source file path alphabetic order. The standard AC pattern is:

```
- [ ] Audit src/core/<path>.gd: enumerate public functions (non-underscore-prefixed `func`)
- [ ] For each, verify ≥1 test reference in tests/ with assert_* within 5 lines
- [ ] If any function lacks coverage, write a test_<scenario>_<expected_result> per uncovered function
- [ ] Cover at least one obvious edge case (null input, empty array, boundary value) per function with documented edge cases
- [ ] All new tests pass; no regression in existing 1529-test baseline
- [ ] Naming convention verified via grep
```

For brevity below, ACs are abbreviated as `[STD-AC]` to mean the 6 standard items above. Story-specific deviations are noted explicitly.

### Autoloads (high-priority — these are the load-bearing surfaces)

#### US-001: audio_router.gd
**Description:** As a maintainer, I want every public function on AudioRouter (volume getters/setters, play_sfx, play_music, stop_music, set_master_muted, get/load_save_data) to have a happy-path + edge-case test so volume regressions surface immediately.
**Acceptance Criteria:** [STD-AC]

#### US-002: data_registry.gd
**Description:** As a maintainer, I want DataRegistry's public surface (resolve, list_category, state, get_validation_errors, etc.) covered.
**Acceptance Criteria:** [STD-AC]

#### US-003: dungeon_run_orchestrator.gd
**Description:** Cover orchestrator public surface (dispatch, get_*, run_snapshot accessors, signal-emit helpers). NOTE: this file is the most heavily-tested in the project; expect mostly `passes: true` after audit with minimal new-test additions.
**Acceptance Criteria:** [STD-AC]

#### US-004: economy.gd
**Description:** Cover Economy public surface (add_gold, get_gold_balance, recruit_cost, level_cost, get/load_save_data).
**Acceptance Criteria:** [STD-AC]

#### US-005: enemy_database.gd
**Description:** Cover EnemyDatabase public surface (lookup methods, list_all, etc.).
**Acceptance Criteria:** [STD-AC]

#### US-006: floor_unlock_system.gd
**Description:** Cover FloorUnlock public surface (is_unlocked, set_unlocked, get/load_save_data, signal emitters).
**Acceptance Criteria:** [STD-AC]

#### US-007: formation_assignment.gd
**Description:** Cover FormationAssignment public surface (browse, commit, detect_active_synergy, notify_synergy_detected, set_target, get_target, get/load_save_data). NOTE: detect_active_synergy + notify_synergy_detected already covered as of 2026-05-10; expect partial new work.
**Acceptance Criteria:** [STD-AC]

#### US-008: hero_class_database.gd
**Description:** Cover HeroClassDatabase public surface (lookup methods, list_classes, unlock signals).
**Acceptance Criteria:** [STD-AC]

#### US-009: hero_roster.gd
**Description:** Cover HeroRoster public surface (add_hero, remove_hero, prestige_hero, set_formation_slot, get_*, set_hero_level, get_prestige_count, get_prestige_multiplier, get/load_save_data, etc.). NOTE: heaviest public surface in the project; expect most existing coverage but may surface gaps.
**Acceptance Criteria:** [STD-AC]

#### US-010: locale_loader.gd
**Description:** Cover LocaleLoader public surface (load_locale, list_locales, etc.).
**Acceptance Criteria:** [STD-AC]

#### US-011: offline_progression_engine.gd
**Description:** Cover OfflineProgressionEngine public surface (bootstrap_offline_replay, is_replay_in_flight, etc.).
**Acceptance Criteria:** [STD-AC]

#### US-012: recruitment.gd
**Description:** Cover Recruitment public surface (refresh_pool, get_recruit_pool, get_recruit_cost, recruit, get/load_save_data).
**Acceptance Criteria:** [STD-AC]

#### US-013: save_load_system.gd
**Description:** Cover SaveLoadSystem public surface (request_full_persist, request_full_load, acknowledge_corrupt_both_begin, state, signal emitters). NOTE: already very heavily tested; expect mostly `passes: true`.
**Acceptance Criteria:** [STD-AC]

#### US-014: scene_manager.gd
**Description:** Cover SceneManager public surface (request_screen, push_overlay, pop_overlay, set_reduce_motion, etc.).
**Acceptance Criteria:** [STD-AC]

#### US-015: telemetry_sink.gd
**Description:** Cover TelemetrySink public surface (set_opt_in, is_opt_in, get/load_save_data). NOTE: just shipped today (PR #46-#47); skeleton tests already cover most surface. Likely `passes: true` after audit.
**Acceptance Criteria:** [STD-AC]

#### US-016: tick_system.gd
**Description:** Cover TickSystem public surface (now_ms, current_tick, last_persist_ts setters/getters, _read_wall_clock_unix_time singleton-call-site invariant).
**Acceptance Criteria:** [STD-AC]

### Boot / framework files

#### US-017: boot_namespace.gd
**Description:** Cover BootNamespace public surface (get_namespace_bytes, etc.).
**Acceptance Criteria:** [STD-AC]

#### US-018: engine_bootstrap.gd
**Description:** Cover EngineBootstrap public surface (boot diagnostics, error reporting).
**Acceptance Criteria:** [STD-AC]

#### US-019: runtime_locale_guard.gd
**Description:** Cover RuntimeLocaleGuard public surface (locale validation, error reporting).
**Acceptance Criteria:** [STD-AC]

#### US-020: scene_manager/main_root.gd
**Description:** Cover MainRoot's _ready bootstrap behavior. NOTE: existing `mainroot_boot_wiring_test.gd` covers this; expect `passes: true`.
**Acceptance Criteria:** [STD-AC]

### Combat layer

#### US-021: combat/combat_resolver.gd
**Description:** Cover the abstract CombatResolver interface contract (if any default methods exist).
**Acceptance Criteria:** [STD-AC]
**Note:** Likely abstract base — may mark `passes: true` with "covered via DefaultCombatResolver tests".

#### US-022: combat/default_combat_resolver.gd
**Description:** Cover DefaultCombatResolver public surface (resolve_kill, resolve_batch).
**Acceptance Criteria:** [STD-AC]

### Matchup layer

#### US-023: matchup_resolver/matchup_resolver.gd
**Description:** Cover the abstract MatchupResolver interface contract.
**Acceptance Criteria:** [STD-AC]
**Note:** Likely abstract base.

#### US-024: matchup_resolver/default_matchup_resolver.gd
**Description:** Cover DefaultMatchupResolver public surface (archetype_for_enemy, is_advantaged, etc.).
**Acceptance Criteria:** [STD-AC]

### Data classes (Resource / RefCounted with mostly fields)

The following stories are likely EXEMPT per FR-7 (no testable public surface beyond field accessors). Each story's audit step confirms the exemption and marks `passes: true` with note "no testable public surface, fields covered via consumer tests". If any data class has a non-trivial public method (validate, to_dict, from_dict, is_valid, etc.), that method gets tested per the standard AC.

#### US-025: biome_dungeon_database/biome.gd
**Description:** Audit Biome resource for public methods; test any non-trivial ones.
**Acceptance Criteria:** [STD-AC]

#### US-026: biome_dungeon_database/dungeon.gd
**Description:** Audit Dungeon resource for public methods; test any non-trivial ones.
**Acceptance Criteria:** [STD-AC]

#### US-027: biome_dungeon_database/floor.gd
**Description:** Audit Floor resource for public methods; test any non-trivial ones.
**Acceptance Criteria:** [STD-AC]

#### US-028: biome_dungeon_database/biome_dungeon_database.gd
**Description:** Cover BiomeDungeonDatabase autoload public surface.
**Acceptance Criteria:** [STD-AC]

#### US-029: combat/combat_batch_result.gd
**Description:** Audit CombatBatchResult for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-030: combat/combat_config.gd
**Description:** Audit CombatConfig resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-031: combat/combat_run_snapshot.gd
**Description:** Audit CombatRunSnapshot for public methods (likely to_dict/from_dict).
**Acceptance Criteria:** [STD-AC]

#### US-032: combat/combat_tick_events.gd
**Description:** Audit CombatTickEvents for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-033: combat/kill_event.gd
**Description:** Audit KillEvent for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-034: dungeon_run_orchestrator/dungeon_run_state.gd
**Description:** Audit DungeonRunState (likely an enum + state-machine helper).
**Acceptance Criteria:** [STD-AC]

#### US-035: dungeon_run_orchestrator/run_snapshot.gd
**Description:** Cover RunSnapshot's public surface (to_dict, from_dict, equals). NOTE: already covered by `run_snapshot_and_fsm_test.gd`; expect `passes: true`.
**Acceptance Criteria:** [STD-AC]

#### US-036: economy/economy_config.gd
**Description:** Audit EconomyConfig resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-037: enemy_database/enemy_data.gd
**Description:** Audit EnemyData resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-038: hero_class_database/hero_class.gd
**Description:** Audit HeroClass resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-039: hero_roster/hero_instance.gd
**Description:** Audit HeroInstance for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-040: hero_roster/name_pool.gd
**Description:** Audit NamePool resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-041: hero_roster/roster_config.gd
**Description:** Audit RosterConfig resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-042: matchup_resolver/matchup_result.gd
**Description:** Audit MatchupResult for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-043: save_load_system/load_result.gd
**Description:** Audit LoadResult for public methods (likely an enum).
**Acceptance Criteria:** [STD-AC]

#### US-044: scene_manager/scene_manager_config.gd
**Description:** Audit SceneManagerConfig resource for public methods.
**Acceptance Criteria:** [STD-AC]

#### US-045: scene_manager/screen.gd
**Description:** Cover Screen base class public surface (on_enter / on_exit / on_pause / on_resume contract — these are virtual hooks but the base implementation may have invariants).
**Acceptance Criteria:** [STD-AC]

---

## Ralph Configuration

```yaml
branchName: feat/test-coverage-backfill
maxIterations: 50  # 45 stories + 5 buffer iterations
quality_check_command: godot --headless --script tests/gdunit4_runner.gd
quality_check_pass_predicate: "Aggregate: 1529+ test cases, 0 errors, 0 failures"
ci_link: .github/workflows/tests.yml
```

The `progress.txt` file at `production/epics/test-coverage-backfill/progress.txt` is the append-only learnings log. Each iteration appends one line.

When all 45 stories report `passes: true`, Ralph emits `<promise>COMPLETE</promise>` and exits.

If any iteration BLOCKS (per FR-8 — new test surfaces a real source bug), Ralph emits `<promise>BLOCKED</promise>` and pauses for human triage.

---

## Notes

- This is the project's first Ralph autonomous-execution trial. The scope is intentionally bounded to mechanical work where the predicate (test exists + green) is unambiguous.
- If Story 003 (DungeonRunOrchestrator), 009 (HeroRoster), or 013 (SaveLoadSystem) take more than 2 iterations each, it likely indicates the audit-grep predicate needs sharpening — those files have hundreds of public-function call sites and the simple grep may produce false positives.
- The Ralph CLAUDE.md prompt template (`scripts/ralph/CLAUDE.md` per the Ralph repo convention) should reference this PRD path AND the project's `tests/PATTERNS.md` AND the load-bearing project memories listed in Technical Considerations.
- Post-Ralph review: a single squash-merge to main per the project's PR convention, OR per-story commits if Ralph's iteration commits are clean enough to land as-is. Decision deferred to post-Ralph state.
- Outstanding decision after Ralph completes: whether to promote the naming-convention grep into a static-analysis test in CI (currently advisory only).
