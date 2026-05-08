# Test Infrastructure

**Engine**: Godot 4.6 (pinned 2026-02-12; see `docs/engine-reference/godot/VERSION.md`)
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-04-24

> **Authoring tests?** Read [`tests/PATTERNS.md`](PATTERNS.md) FIRST — it covers the gdunit4 signal API surface, Array-spy idiom, hygiene barriers, ConfigFile test isolation, async-API-change auditing, `auto_free` in factory helpers, `before_test` spy-clear, and other patterns whose rediscovery has cost real time.

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
  probes/         # Empirical engine-behavior probes (see autoload.md Pass-PROBE)
  gdunit4_runner.gd  # Headless CI test runner entry point
```

## Installing GdUnit4

1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdunit4/` exists

## Running Tests

Headless (same command CI uses):

```
godot --headless --script tests/gdunit4_runner.gd
```

In the editor: run the GdUnit4 panel (View → GdUnit4) and press "Run All".

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `combat_damage_test.gd` → `func test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## Coverage Targets

Per `.claude/docs/technical-preferences.md`:

- **80% minimum** for balance formulas and offline-progression math (project's highest-risk logic).
- **Required tests**: offline progression math, class-vs-biome matchup resolution, save/load round-trip integrity, roster state transitions.

## Determinism Rules

- No random seeds (or: seed deterministically from test input; expose via DI per ADR-0009, ADR-0010).
- No time-dependent assertions outside explicit TickSystem tests.
- No file I/O outside `tests/integration/` save/load tests.
- Each test owns its setup/teardown; order-independent.

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging. See `.github/workflows/tests.yml`.
