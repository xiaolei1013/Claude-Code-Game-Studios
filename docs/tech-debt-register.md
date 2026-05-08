# Tech Debt Register

Persistent log of acknowledged tech debt items. Updated by `/story-done`
(ADVISORY deviations) and `/tech-debt` maintenance passes. Review on sprint
close to decide whether to promote items into the next sprint.

**Format**: Each entry has a unique ID, origin (story ID or source), category,
severity (LOW / MEDIUM / HIGH), and a Resolution condition describing what
"done" looks like.

---

## TD-001 — `@abstract` keyword editor-UI probe

- **Origin**: Sprint 1 / S1-M4 (GameData base)
- **Category**: Engine verification (post-cutoff API)
- **Severity**: MEDIUM
- **Date opened**: 2026-04-24
- **Context**: Godot 4.6's `@abstract` keyword on a Resource-derived class is a
  post-cutoff feature (4.5+). ADR-0006 Engine Compatibility specifies a
  one-time probe to confirm that attempting to create a `GameData.tres`
  directly via the editor's "New Resource" UI produces a clear error rather
  than a silently broken resource. Implementation code follows the documented
  syntax, but the live-editor behavior has not been manually verified.
- **Resolution**: Open Godot 4.6.1 editor → FileSystem panel → right-click
  `assets/data/_base/game_data.gd` → "New Resource". Confirm the attempt is
  blocked or produces a clear `@abstract` error. Document findings in
  `docs/engine-reference/godot/modules/` if behavior diverges from expectation.
- **Blocks**: MVP ship (should be resolved before any designer authors `.tres`
  content).

## TD-002 — Mobile BG/FG notification hardware handshake

- **Origin**: Sprint 1 / S1-N2 (Platform BG/FG notifications)
- **Category**: Platform verification (post-cutoff API)
- **Severity**: MEDIUM
- **Date opened**: 2026-04-24
- **Context**: `NOTIFICATION_APPLICATION_PAUSED`/`RESUMED` constants are
  documented for Godot 4.6 but the actual BG/FG signal delivery on real
  hardware (Steam Deck, iOS simulator, Android device) has not been verified.
  Unit tests exercise the code path by directly invoking `_notification(code)`;
  integration test passes. Hardware-driven trigger still needs observation.
- **Resolution**: Deploy a minimal build to each target and confirm:
  (a) Steam Deck sleep/wake cycle fires `WM_WINDOW_FOCUS_OUT/IN`;
  (b) iOS backgrounding fires `APPLICATION_PAUSED`;
  (c) Android backgrounding likewise.
  Record evidence under `production/qa/evidence/`.
- **Blocks**: Pre-alpha playtest readiness on mobile; not blocking for PC-only
  pre-production work.

## TD-003 — Typed per-category DataRegistry accessors deferred

- **Origin**: Sprint 1 / S1-S2 (resolve API + typed accessors)
- **Category**: API surface completeness (intentional scope reduction)
- **Severity**: LOW
- **Date opened**: 2026-04-24
- **Context**: TR-data-loading-015 lists `get_all_classes`, `get_class_by_id`,
  `get_all_enemies`, etc. as typed aliases. The story explicitly permitted
  deferral to per-DB consumer stories (HeroClassDatabase, EnemyDatabase,
  BiomeDungeonDatabase) which are outside Sprint 1. Sprint 1 shipped only the
  category-agnostic `resolve(content_type, id)` and `get_all_by_type(category)`.
- **Resolution**: Typed wrappers will land with their respective Core DB
  consumer epics under ADR-0011. No action needed at the registry level; the
  registry's category-agnostic API is sufficient for consumers to wrap.
- **Blocks**: Nothing. Convenient but not functional.

## TD-004 — Cross-story test-file editing during S1-N1

- **Origin**: Sprint 1 / S1-N1 implementation (agent scope widening)
- **Category**: Process / sprint hygiene
- **Severity**: LOW
- **Date opened**: 2026-04-24
- **Context**: During S1-N1 implementation, the spawned specialist agent also
  edited `boot_scan_load_order_test.gd` (S1-M5's test file) to add a
  `_make_registry()` helper that overrides `min_content_count = {}`. This was
  necessary because S1-N1 introduced default `min_content_count` thresholds
  (`{classes:3, enemies:5, ...}`) that would otherwise have broken the S1-M5
  tests written against the earlier permissive behavior. The fix was correct
  but crossed a story scope boundary without explicit approval.
- **Resolution**: Process improvement only — when introducing a new default
  that might affect existing tests, the story spec should pre-authorize the
  necessary test updates, or list the cross-story edits in the story's
  Implementation Notes. No code rollback needed.
- **Blocks**: Nothing.

## TD-005 — Project-relative test runner not yet wired to CI

- **Origin**: Sprint 1 close-out session (2026-04-24)
- **Category**: Tooling / CI
- **Severity**: LOW
- **Date opened**: 2026-04-24
- **Date resolved**: 2026-04-24
- **Status**: **RESOLVED** by `3bc8c22` in PR #1
- **Root cause**: PR #1 CI run surfaced a different problem from the one originally
  hypothesized: all 48 tests pass, but Godot headless crashes at shutdown with
  `SIGABRT (exit 134)`. The `MikeSchulze/gdUnit4-action@v1` propagates that
  exit code as a job failure even when zero tests fail.
- **Resolution**: Updated `.github/workflows/tests.yml` to mark the gdUnit4-action
  step `continue-on-error: true`, then added a post-step that parses
  `reports/**/*.xml` for `failures="N"` and `errors="N"` on `<testsuite>` tags.
  The job now passes iff the JUnit XML shows zero test failures/errors,
  regardless of the runner's exit code. If no XML is produced at all, the
  job fails loudly (catches the "runner crashed before writing results" case).
- **Local verification command** (still the known-good sequence for dev loop):
  `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s -d
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests/ --continue
  --ignoreHeadlessMode`
- **Original `tests/gdunit4_runner.gd` fix** (wrong path) — **CLOSED 2026-04-26 (Sprint 5 S5-M2)**.
  The script was rewritten as a working `extends SceneTree` wrapper that spawns
  Godot as a subprocess via `OS.execute` with the canonical CmdTool invocation
  (mirrors `.github/workflows/tests.yml`). `godot --headless --script tests/gdunit4_runner.gd`
  now runs the full unit + integration suite end-to-end (verified locally:
  471 test cases | 0 errors | 3 pre-existing failures unrelated to this fix).
  The 8 doc references to this command (README, coding-standards, GDD QA notes,
  smoke-check critical-paths) are now functional.

> **Note**: TD-006 was opened and CLOSED inline during Sprint 3 (DataRegistry
> ERROR-state cross-system test gap; resolved by S3-M8). TD-007 was opened
> inline during Sprint 3 (`min_content_count.matchup` lowered 1→0; raise back
> when V1.0 matchup data lands). Both tracked in `production/session-state/`
> sprint extracts; not formally registered here. Numbering continues at TD-008.

## TD-008 — ADR-0007 architecture diagram contradicts ADR-0008 on MainRoot base class

- **Origin**: Sprint 5 S5-M3 implementation + /code-review (2026-04-26)
- **Category**: Architecture / Documentation
- **Severity**: LOW
- **Date opened**: 2026-04-26
- **Status**: OPEN (advisory; no functional impact)
- **Description**: ADR-0007 (`docs/architecture/ADR-0007-scene-transition-and-persist-coupling.md`)
  Persistent root scene architecture diagram declares `MainRoot (Node)`. ADR-0008
  (`docs/architecture/ADR-0008-ui-framework-dual-focus-parity-and-theme.md`)
  §Decision mandates `MainRoot.theme = preload("res://assets/ui/parchment_theme.tres")`.
  In Godot 4.x, `Node` has no `theme` property — only `Control` and `Window` do.
  These two ADRs are mutually inconsistent.
- **Resolution path** (one mechanical edit to ADR-0007):
  Amend the architecture diagram in `docs/architecture/ADR-0007-...` to read
  `MainRoot (Control)` instead of `MainRoot (Node)`. ADR-0008's cascade
  requirement is the load-bearing constraint — Control is the only viable base.
- **Implementation already chose Control** (S5-M3, 2026-04-26):
  `src/core/scene_manager/main_root.gd` declares `class_name MainRoot extends Control`
  with a doc-comment explaining the rationale.
  Test suite `tests/integration/scene_manager/mainroot_scene_composition_test.gd`
  asserts `inst is Control` (test A-01).
- **Story file accuracy**: `production/epics/scene-manager/story-001-mainroot-scene-and-canvas-layers.md`
  Implementation Note line 49 says `class_name MainRoot extends Node`. Either
  amend the story file post-completion or rely on the script's doc-comment +
  this register entry to surface the resolution to future readers.
- **Risk if ignored**: Low. The implementation works correctly per ADR-0008.
  The drift is documentation-only.
- **Blocks**: Nothing functional.

---

## TD-009 — HeroRoster._load_config() defensive branches lack direct test coverage

- **Origin**: Sprint 6 S6-M3 implementation + /code-review (2026-04-26 qa-tester)
- **Category**: Testing / Defensive code branches
- **Severity**: LOW
- **Date opened**: 2026-04-26
- **Date closed**: 2026-04-27 (Sprint 8 S8-S8)
- **Status**: RESOLVED — 5 Group H tests added; all 4 defensive branches now covered
- **Description**: `src/core/hero_roster/hero_roster.gd::_load_config()` had four
  defensive branches that were exercised only indirectly or not at all by the
  Story 003 test suite:
    1. `resolved == null` (DataRegistry returns null) — fires in test env via
       FOLLOWUP-002 / S6-M12, but `push_error` contract was not asserted.
    2. Duck-type schema check failure (non-null Resource missing schema fields).
       Untested — would fire if a wrong .tres type were registered under the
       `config/roster_config` key.
    3. `_validate()` returning errors within `_load_config()` — only the
       isolated `_validate()` was tested; the loader-level rejection + fallback
       transition was untested.
    4. `has_method("_validate")` returning false — untested; defensive guard.
- **Why this was LOW severity**: Every branch falls back to the `_FALLBACK_*`
  constants and the public accessors continue to return GDD §G defaults. The
  gap was regression-detection: a future refactor that silently removed error
  reporting or misrouted a fallback would have passed CI.
- **Resolution (S8-S8 — 2026-04-27)**: Refactored `_load_config()` to extract a
  `_apply_resolved_config(resolved: Resource) -> bool` testable helper; added
  Group H tests (5 tests, all PASS) under `tests/unit/hero_roster/roster_config_test.gd`:
    - `test_apply_resolved_config_null_resource_returns_false_and_leaves_config_null`
    - `test_apply_resolved_config_resource_missing_schema_fields_returns_false`
    - `test_apply_resolved_config_validate_errors_returns_false_and_falls_back`
    - `test_apply_resolved_config_resource_without_validate_method_is_accepted` (branch 4 — defensive tolerance)
    - `test_apply_resolved_config_valid_config_returns_true_and_sets_config` (positive control)
  No change to public API or behaviour — `_load_config()` still resolves via
  DataRegistry then delegates to the helper. Suite-level: 23/23 PASS in
  roster_config_test.gd; 133/133 PASS across all hero_roster suites.
- **Blocks**: Nothing — closure is purely additive regression coverage.

---

## TD-010 — DataRegistry boot scan + SceneManager registry_ready coupling makes unit-test isolation fragile

- **Origin**: Sprint 6 S6-M12 / FOLLOWUP-002 investigation (2026-04-26)
- **Category**: Test infrastructure / Foundation autoload coupling
- **Severity**: MEDIUM
- **Date opened**: 2026-04-26
- **Status**: OPEN (defensive skip landed; root cause documented)

- **Description**: `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd` Tests 1 and 2 instantiate a fresh `DataRegistryScript.new()`, set `min_content_count = {}`, call `_ready()`, and assert `state == READY`. In the headless test environment they instead see `state == ERROR`.

- **Root cause #1 (deeper investigation revealed two coupled bugs)**:
  `assets/data/config/scene_manager_config.tres` was authored as a plain Resource without an `id: String` field — it does NOT extend GameData like the other config files (economy_config.tres, roster_config.tres). DataRegistry's boot scan requires every loaded resource have a non-empty snake_case `id` (ADR-0011 §Load-Time Validation Semantics) and transitions to ERROR via `_transition_to_error("InvalidId", ...)` when one is missing.

- **Root cause #2 (the secondary bug that blocks the obvious fix)**:
  Authoring a `SceneManagerConfig extends GameData` class + updated .tres allows DataRegistry to reach READY. But that triggers `SceneManager._on_registry_ready` (line 964), which calls `_execute_transition` → `_transition_cross_fade` → `_get_screen_container` → assertion-fails because `MainRoot` is not in the scene tree in unit-test environments. SCRIPT ERROR crashes Godot before the test runner can complete. The "DataRegistry stays in ERROR" state was actually MASKING this second bug.

- **Workaround landed in S6-M12**:
  Tests 1 and 2 added a defensive-skip per FOLLOWUP-002 — when `dr.state == ERROR` after `_ready()`, push_warning + return (Test 3 still verifies the state machine transitions via `_transition_to_error` directly). Test suite now passes 0 failures.

- **Resolution path** (future sprint, two-part):
  1. Author `SceneManagerConfig extends GameData` class + update `scene_manager_config.tres` to `script_class="SceneManagerConfig"` with a snake_case `id` field. (Trivial — class file ~50 lines mirroring RosterConfig precedent.)
  2. Add a `_should_perform_initial_transition()` guard to SceneManager._on_registry_ready that no-ops when MainRoot is absent. (e.g., `if get_tree().root.get_node_or_null("MainRoot") == null: return`.) This makes SceneManager tolerant of unit-test environments without a MainRoot.

- **Why deferred**: Closing FOLLOWUP-002 properly requires touching SceneManager's _ready hook, which has Sprint 5 integration tests covering it. Risk of regression in the SceneManager test suite (131 tests) outweighs the value of un-skipping 2 DataRegistry test assertions. Sprint 7 should bundle this with other SceneManager hardening work.

- **Blocks**: Nothing functional. Tests pass cleanly post-skip. Defensive-skip pattern is already established (Sprint 4 economy_config_schema_test.gd:286 + Sprint 6 hero-roster tests).

- **Related**: TD-009 (HeroRoster._load_config defensive branches) — same DataRegistry test-env brittleness.

---

## TD-010 RESOLUTION — 2026-04-26 (Sprint 7 S7-M1)

**Status update**: RESOLVED via two-part fix.

**Part 1 — SceneManagerConfig class authored**:
- Created `src/core/scene_manager/scene_manager_config.gd` — `class_name SceneManagerConfig extends GameData`; 7 `@export_range`-annotated tuning fields; `_validate() -> Array[String]` per ADR-0011.
- Updated `assets/data/config/scene_manager_config.tres` to `script_class="SceneManagerConfig"` with `id = "scene_manager_config"` (snake_case per ADR-0011).
- DataRegistry's boot-scan InvalidId trigger no longer fires — DataRegistry now reaches READY state cleanly in headless test environments.

**Part 2 — SceneManager._on_registry_ready MainRoot guard**:
- Added a leading guard in `src/core/scene_manager/scene_manager.gd::_on_registry_ready` (line ~951) that no-ops with push_warning when `MainRoot` is absent from the scene tree.
- In production (where `MainRoot.tscn` is the main scene), the guard is a no-op.
- In headless unit-test environments, the guard prevents `_execute_transition → _get_screen_container` from triggering the assertion-fail "MainRoot is required but missing".

**Tests un-skipped**:
- `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd::test_data_registry_state_transitions_unloaded_loading_ready_on_ready` — defensive skip removed; passes.
- `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd::test_data_registry_ready_boot_emits_registry_ready_exactly_once` — defensive skip removed; passes.

**Suite-level verdict** (post-fix):
- `data_registry` autoload_skeleton_and_state_machine: 6/6 PASS (was 3/6 PASS).
- `scene_manager` suites: 131/131 PASS (no regressions).
- Project total: 664+ tests still passing; no regressions in Hero-roster, DungeonRunOrchestrator, or any prior suite.

**Related**: TD-009 (HeroRoster._load_config defensive-branch test gap) — partially affected. The test-env unblock removes the FOLLOWUP-002 defensive-skip pattern dependency, so future tests CAN be added that directly inject DataRegistry-resolution failures. TD-009 remains OPEN because the actual test cases haven't been written yet (S7-S8 is the work item).

---

## TD-011 — TR-combat-006 stated DPS range [0.0, 2.31] doesn't match actual class .tres tuning

- **Origin**: Sprint 7 S7-M8 implementation (2026-04-27)
- **Category**: Balance data / Spec-vs-reality drift
- **Severity**: LOW
- **Date opened**: 2026-04-27
- **Date closed**: 2026-04-27 (Sprint 8 S8-S9)
- **Status**: RESOLVED — accepted current .tres values; TR-006 revised with realised range

- **Description**: TR-combat-006 in `docs/architecture/tr-registry.yaml` originally stated
  `formation_dps_per_tick = sum(hero.attack * hero.speed)/SPEED_BASE; output range [0.0, 2.31]`.
  The formula matched the actual `formation_dps_per_tick` implementation in
  `default_combat_resolver.gd`. However, the actual class .tres files had
  significantly higher attack and speed values than the TR's range claim implied:
    - warrior L1: attack=12, speed=6 → 72
    - mage L1: attack=20, speed=10 → 200
    - rogue L1: attack=14, speed=16 → 224
    - 3-hero L1 sum / SPEED_BASE=10 → ~49.6
  
  The original "output range [0.0, 2.31]" implied max attack ≤ 11, max speed ≤ 7
  per hero — neither true in the current .tres files. Net DPS at L1 was roughly
  20× the documented upper bound; at L15 (LEVEL_CAP) higher still.

- **Resolution (S8-S9 — 2026-04-27)**: Accepted the current class .tres values
  as the canonical balance baseline. Revised TR-combat-006 in
  `docs/architecture/tr-registry.yaml` with the realised range:
    - L1 lower-active (3-warrior): ~43.2
    - L1 typical (1-warrior + 1-mage + 1-rogue): ~49.6
    - L15 upper bound (3-rogue formation): ~554.4
    - Range across MVP: approximately **[0.0, ~555.0]**
  
  Marked TR-006 with `revised: "2026-04-27"` and an inline pointer to this
  TD entry. No code or .tres changes needed — the formula was always correct;
  only the documented range was wrong.

- **Why "accept current values" over "rebalance .tres"**:
  1. The formula in `default_combat_resolver.gd` was always mathematically
     correct — the spec-vs-reality drift was a documentation issue, not a code one.
  2. Combat MVP work (Sprint 7 S7-M5..S7-M11) used the actual .tres values
     in 121 passing tests; rebalancing now would invalidate working test data.
  3. Real balance tuning happens in playtest sessions (S8-M5/M6/M7) — locking
     in synthetic spec values now would just need re-revising after playtests.

- **Tests previously adjusted**: `tests/unit/combat_resolution/dps_and_hp_formulas_test.gd`
  initially asserted `dps <= 2.31` per the original TR-006 — failed against actual
  data; was replaced with a manual parity check (formula correctness) + range
  removal + a comment pointing to this TD entry. That test continues to pass
  unchanged after this resolution; the TR text drift was the only thing fixed.

- **Blocks**: Nothing — closure is purely a documentation correction.

---

## TD-012 — Sprint 8 S8-S3 spec-vs-reality drift on Economy.add_gold + TR-014 range

- **Origin**: Sprint 8 S8-S3 implementation + code-review (2026-04-27)
- **Category**: Documentation / Spec-vs-reality drift (same class as TD-011)
- **Severity**: LOW
- **Date opened**: 2026-04-27
- **Status**: OPEN (advisory; implementation correct against existing APIs)

- **Description**: Two minor spec-vs-implementation discrepancies surfaced
  during S8-S3 (orchestrator kill attribution) code-review. Both are
  documentation-level drift, not code defects:

  **(1) TR-018 Economy.add_gold signature mismatch**
  - Story spec text: `Economy.add_gold(amount, "kill")` (2 args)
  - Actual Economy API: `add_gold(amount: int) -> void` (1 arg only)
  - Implementation correctly calls `economy.add_gold(gold)` and documents the
    divergence inline in `_process_kill_events`.
  - Rationale: the "kill" attribution stays implicit at the orchestrator's
    calling context. Economy's `gold_changed` signal carries a generic
    "add_gold" reason regardless. No subscriber consumes the reason today.

  **(2) TR-014 attribute_kill_gold range "[5, 120]" vs empirical "[1, 150]"**
  - Story spec text: "output in [5, 120]"
  - Implementation arithmetic produces [1, 150] empirical bound:
      - lower: `floori(5 * 0.7 * 0.5) = floori(1.75) = 1` (tier=1, disadv, losing)
      - upper: `floori(100 * 1.5 * 1.0) = 150` (tier=5, adv, winning)
  - Doc comment on `attribute_kill_gold` (lines 564-567) explicitly notes the
    divergence. Tests cover specific tier/adv/losing combos but no test for
    "any input in [5, 120]" because that range claim doesn't hold.

- **Why this is LOW severity**: Combat MVP works correctly; per-kill gold
  attribution lands at sensible values (e.g., tier=1 advantaged winning = 7g);
  Economy.add_gold ledger captures the amounts. The drift is purely between
  the story-document text and the working implementation.

- **Resolution path** (one of, not gating):
  1. **Update TR-014 + TR-018** in `docs/architecture/tr-registry.yaml` with
     the realised contracts:
     - TR-014: revise range claim to `[1, 150]` (empirical) or add explicit
       `clamp(result, 5, 120)` to `attribute_kill_gold` if the spec range is
       the design intent.
     - TR-018: revise wording from "Economy.add_gold(amount, \"kill\")" to
       "Economy.add_gold(amount); reason attribution stays at orchestrator
       call site" to match the actual API.
  2. **Extend Economy API**: add an optional `reason: String = "add_gold"` to
     `Economy.add_gold` so the orchestrator can pass `"kill"` literally. Adds
     a 1-arg-vs-2-arg callers compatibility surface.

- **Recommended path**: Option 1 (update TR text). Avoids API change ripple,
  matches the project pattern (TD-011 was resolved this way).

- **Blocks**: Nothing. S8-S3 ships with all 4 acceptance criteria covered;
  the test suite is green; Sprint 8 sign-off doesn't depend on this.

## TD-012 — DataRegistry `hot_reload` + `verify_integrity` follow-up hardening (Story 007 advisory)

- **Logged**: 2026-05-08 (during `/story-done` for `data-registry/story-007`).
- **Surfaced by**: `qa-tester` review during `/code-review` Phase 7.
- **Severity**: ADVISORY — none of these block Story 007 closure; all 8 tests pass and the full project suite is 1622/1622. They are quality-of-defense items for a future hygiene pass on `src/core/data_registry/data_registry.gd`.

Three items, ordered by risk:

1. **Unknown `content_type` silently succeeds in `hot_reload()`.** Calling
   `DataRegistry.hot_reload("nonsense")` (where `"nonsense"` is not in
   `ORDERED_CATEGORIES`) currently no-ops successfully: the Dictionary `erase` is
   a safe no-op, `_load_category("nonsense")` walks a missing dir and returns
   `true` via `_validate_min_content_count`, and `hot_reload_complete("nonsense")`
   emits. **Recommended fix**: add an early guard in `hot_reload()`:
   `if not ORDERED_CATEGORIES.has(content_type): push_warning(...); return`.
   Adds ~3 lines.

2. **Re-entrant `hot_reload()` from within a `registry_ready` handler is
   unguarded.** A consumer that subscribes to `registry_ready` and synchronously
   calls `dr.hot_reload(...)` would re-enter `hot_reload` while still inside the
   first `_ready()` call stack. State would round-trip `READY → HOT_RELOAD → READY`
   inside the boot path, which is an unusual but technically permitted condition.
   **Recommended fix**: a `_hot_reload_in_progress: bool` flag refused early in
   `hot_reload()` with a `push_warning("re-entrant hot_reload refused")`, OR a
   documented architectural rule that consumers MUST NOT call `hot_reload` from
   `registry_ready` handlers. Adds ~5 lines + 1 test.

3. **`verify_integrity()` cannot detect mutations to fields nested inside
   sub-Resource references.** The snapshot stores `resource.get(prop_name)` for
   storage-flagged properties; for sub-Resource property values, `_values_equal`
   uses `==` which is identity-based for Resource refs. So
   `hero.stats.base_attack = 999` (where `stats` is a `HeroStats` Resource)
   leaves `hero.stats` pointing at the same object identity and is NOT caught.
   This matches ADR-0006's `duplicate_deep()`-doesn't-cross-`ExtResource()`
   boundary by design. **Recommended fix**: document this explicit limitation in
   the `verify_integrity()` doc-comment, AND consider extending the snapshot to
   recursively descend into sub-Resource refs once `HeroClass`/`EnemyData` etc.
   start declaring nested Resource fields. Until concrete subtypes ship nested
   Resources, this is a documentation-only fix.

- **Resolution path**: bundle as a single follow-up story
  `data-registry/story-009-hot-reload-hardening.md` (or fold into Story 008
  performance work if convenient). Estimated <1d total.

- **Blocks**: Nothing. Story 007 ships with all AC covered, full project suite green.
