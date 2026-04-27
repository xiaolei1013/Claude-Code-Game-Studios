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
- **Original `tests/gdunit4_runner.gd` fix** (wrong path) is NOT done yet —
  the script still references `res://addons/gdunit4/GdUnitRunner.gd` which
  doesn't exist. CI now works via the `MikeSchulze/gdUnit4-action` directly;
  the runner script is orphaned and can be deleted or repointed in a follow-up.
