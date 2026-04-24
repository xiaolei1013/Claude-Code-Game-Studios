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
- **Context**: `tests/gdunit4_runner.gd` points at `res://addons/gdunit4/GdUnitRunner.gd`
  (lowercase; file doesn't exist). GdUnit4 v6 CLI entry point is
  `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` (mixed-case) and requires
  `--ignoreHeadlessMode` to run the full suite. The runner script and the CI
  workflow referenced in `tests/README.md` both need updating.
- **Resolution**: Update `tests/gdunit4_runner.gd` to call `GdUnitCmdTool`
  directly, or replace it with a shell wrapper. Update
  `.github/workflows/tests.yml` (if present) to use the corrected path with
  `--ignoreHeadlessMode`. Local verification command that works today:
  `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s -d
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests/ --continue
  --ignoreHeadlessMode`
- **Blocks**: Automated CI gate enforcement on PRs/main pushes. Local runs
  work with the known-good command above.
