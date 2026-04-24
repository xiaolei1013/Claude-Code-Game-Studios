# Story 010: Schema VERSION migration path (placeholder for MVP; full fail-forward/restore logic)

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-007, TR-save-load-045 (MIGRATION state row), TR-save-load-055 (ERR_SCHEMA_MISMATCH code)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0004 (primary — Migration Plan section), ADR-0003 (lockstep edit for consumer list changes)
**ADR Decision Summary**: Header `VERSION` u16 = 1 for MVP; mismatch enters MIGRATION state before `load_save_data` calls. Future schema migrations bump `CURRENT_SAVE_VERSION`, add `_migrate_from_vN_to_vN_plus_1(payload) -> Dictionary` transform, and re-persist atomically on success. On migration failure, fall through to corruption policy (try `.bak`, then fresh start with modal).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (MVP placeholder — not exercised in v1 because no shipped saves exist; must not silently mishandle `version < CURRENT_SAVE_VERSION` or crash on an unexpected future-build save)
**Engine Notes**: No engine API novelty — this is state-machine wiring + atomic re-persist (which Story 008 owns).

**Control Manifest Rules (Foundation Layer, migration)**:
- **Required**: Header VERSION u16 = 1 for MVP; mismatch enters MIGRATION state before `load_save_data` calls. Adding/removing autoloads requires lockstep edit of (a) architecture.md rank table, (b) project.godot `[autoload]`, (c) `SaveLoadSystem.CONSUMER_PATHS`, and (d) save schema_version bump if a save consumer. Adding a new `_meta` field requires a save VERSION bump.
- **Forbidden**: Silent migration (future-build save that this build can't understand must surface a modal, never hydrate with defaults). Mutating the on-disk save during migration without the atomic re-persist (Story 008) pipeline.

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `CURRENT_SAVE_VERSION: int = 1` declared as compile-time `const`
- [ ] On load, `version == CURRENT_SAVE_VERSION` → proceed to hydration (Story 007 loop)
- [ ] On load, `version < CURRENT_SAVE_VERSION` → transition to MIGRATION state; invoke `_run_migration_chain(payload, version, CURRENT_SAVE_VERSION)`; on success, re-persist atomically (Story 008); on failure, fall through to `.bak` → corruption policy
- [ ] On load, `version > CURRENT_SAVE_VERSION` → return `LoadResult{code: ERR_SCHEMA_MISMATCH, detail: "version_future"}`; CORRUPT modal copy "your save is from a newer build; please update the game" (final copy owned by writer in Story 013)
- [ ] `_run_migration_chain(payload, from_version, to_version) -> Variant`: returns migrated Dictionary on success, null on failure. MVP body is a no-op for `from == to == 1`; stub returning `null` for any `from != 1` (no migrations authored yet — returns `ERR_SCHEMA_MISMATCH` until real migrations land)
- [ ] MIGRATION state appears in the state-transition table with boundary actions: `LOADING → MIGRATION → (READY | CORRUPT)`
- [ ] Post-migration atomic re-persist writes under `CURRENT_SAVE_VERSION`; `_meta.save_sequence_number` advances; `save_completed` emits
- [ ] Lockstep-edit checklist comment block in the migration source file documents the 4-step edit required when adding/removing a consumer (ADR-0003 + ADR-0004 cross-ref)

---

## Implementation Notes

- MVP reality: `CURRENT_SAVE_VERSION = 1` and no migrations authored. This story is the scaffolding so the first real migration (post-MVP) slots in without re-architecting. Body is intentionally thin.
- State transition wiring:
  - `LOADING → MIGRATION` (on version mismatch; keeps hydration deferred)
  - `MIGRATION → READY` (on migration success + successful re-persist)
  - `MIGRATION → CORRUPT` (on migration failure — fall through to `.bak` first via Story 013; CORRUPT is terminal for the session)
- Migration chain shape (for future use):
  ```gdscript
  func _run_migration_chain(payload: Dictionary, from_v: int, to_v: int) -> Variant:
      var current := payload
      for v in range(from_v, to_v):
          current = _migrate_from_v_to_next(current, v)
          if current == null: return null
      return current

  func _migrate_from_v_to_next(payload: Dictionary, from_v: int) -> Variant:
      match from_v:
          1: return null  # no v1→v2 migration authored yet
          _: return null  # unknown
  ```
- The re-persist after migration uses Story 008's atomic pipeline; the new envelope carries `CURRENT_SAVE_VERSION` in the header. If the re-persist fails, the on-disk save still has `version < CURRENT_SAVE_VERSION`; next launch re-runs migration (idempotent by design)
- Future migrations MUST include the migration in the `get_save_data()` / `load_save_data()` regression-test suite so that `v1→v2` output hydrates correctly through `v2`'s `load_save_data`
- Future-version detection: `future_version_save_policy = refuse` is the MVP default; a future build might offer a "downgrade not supported — please update game" deep link. MVP copy is owned by Story 013 writer
- Lockstep-edit reminder: any new consumer in CONSUMER_PATHS MUST bump `CURRENT_SAVE_VERSION` and add a migration that seeds default state for the new consumer's namespace. This is documented in the file header as a checklist

---

## Out of Scope

- Story 013: migration failure UX (both corrupt modal / future-version modal copy)
- Future stories: actual v1→v2 migrations (landed when first schema change ships)

---

## QA Test Cases

- **TR-save-load-007 (same version happy path)**
  - **Given**: Loaded envelope with `VERSION == CURRENT_SAVE_VERSION == 1`
  - **When**: Post-validation pipeline runs
  - **Then**: Skips MIGRATION; proceeds to Story 007 hydration directly
  - **Edge cases**: State transition is `LOADING → READY`, not through MIGRATION

- **TR-save-load-007 (MIGRATION state transition)**
  - **Given**: Test-forced `CURRENT_SAVE_VERSION = 2` with a loaded envelope carrying `VERSION = 1` (simulated by a test hook that flips the constant or by a fixture envelope)
  - **When**: Validation succeeds and version-check runs
  - **Then**: State transitions `LOADING → MIGRATION`; `_run_migration_chain` is invoked; on MVP return of `null`, transitions `MIGRATION → CORRUPT` (because no migration authored)
  - **Edge cases**: Real migration landing future-proofs this; test harness covers both branches

- **TR-save-load-055 (future version code)**
  - **Given**: Envelope with `VERSION = CURRENT_SAVE_VERSION + 1` (e.g., 2 when MVP is 1)
  - **When**: Validation returns `{ok: false, failure: "version_future"}` from Story 006
  - **Then**: LoadResult returned is `{code: ERR_SCHEMA_MISMATCH, detail: "version_future"}`; Story 013 modal surfaces
  - **Edge cases**: No migration attempt (can't migrate forward to an unknown version)

- **TR-save-load-045 (MIGRATION → CORRUPT fallthrough)**
  - **Given**: Migration chain returns null
  - **When**: Fallthrough handler runs
  - **Then**: Attempts `.bak` via Story 013 logic; on `.bak` valid + version == CURRENT, hydrates from `.bak`; on `.bak` also mismatched, CORRUPT modal fires
  - **Edge cases**: `.bak` might itself need migration — same pipeline applies recursively (one level only; if `.bak` also fails, CORRUPT terminal)

- **Post-migration re-persist**
  - **Given**: A successful migration (hypothetical future v1→v2)
  - **When**: Re-persist fires via Story 008 pipeline
  - **Then**: On-disk `.dat` now carries `VERSION = 2`; `save_sequence_number` advanced by 1; next launch loads directly without migration
  - **Edge cases**: Re-persist failure → on-disk stays v1; migration re-runs idempotently next launch

- **Lockstep-edit reminder (documentation)**
  - **Given**: Reviewer opens the migration source file
  - **When**: Header comment block is read
  - **Then**: Block lists the 4 files requiring lockstep edit when adding/removing a consumer: (a) architecture.md rank table, (b) project.godot `[autoload]`, (c) `SaveLoadSystem.CONSUMER_PATHS`, (d) `CURRENT_SAVE_VERSION` bump + migration authored
  - **Edge cases**: Doc-only check; verified by code review, not GdUnit4

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/save_load/schema_migration_test.gd` — must exist and pass (MVP tests stub migration returning null + verifies state-machine transitions)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 006 (version extraction during validation), Story 008 (atomic re-persist pipeline), Story 009 (`_meta.save_sequence_number` advance on re-persist)
- **Unlocks**: Story 013 (migration-failure modal UX)
