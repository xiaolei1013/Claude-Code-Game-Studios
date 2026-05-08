# Story 009: 3 V1.0 stub class .tres files + flavor_text advisory check

> **Epic**: hero-class-database
> **Status**: Complete (system shipped; see systems-index Implementation Status #6. Test evidence: `tests/{unit,integration}/hero_class_database/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §H-09, §H-11, §C V1.0 stubs
**Requirements**: TR-hero-class-db-020 (flavor_text 120 char limit, advisory)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (V1.0 stub pattern + advisory limits)
**ADR Decision Summary**: 3 V1.0 stub classes (Cleric, Ranger, Tactician) authored as `tier=2` `.tres` files. They load into DataRegistry but are filtered out of the recruitable pool by Story 007. Existence supports forward-compat testing without shipping V1.0 content. flavor_text length is advisory: ≤ 120 chars; overrun triggers `push_warning` (not error); UI truncates with ellipsis.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Inspector-authored `.tres`; same pattern as Story 003.

**Control Manifest Rules (Core Layer)**:
- **Permitted**: V1.0 content stubs in repo (forward-compat). — ADR-0011
- **Advisory**: flavor_text ≤ 120 chars; overrun is warning, not error. — ADR-0011

---

## Acceptance Criteria

- [ ] `assets/data/classes/cleric.tres` exists with: `id="cleric"`, `tier=2`, `role="support"` (or "healer"), `counter_archetype=EnemyArchetypes.INCORPOREAL` (or other distinct archetype — verify against GDD §C V1.0 stubs)
- [ ] `assets/data/classes/ranger.tres` exists with: `id="ranger"`, `tier=2`, role + counter_archetype per GDD
- [ ] `assets/data/classes/tactician.tres` exists with: `id="tactician"`, `tier=2`, role + counter_archetype per GDD
- [ ] All three pass schema validation (Story 008's `_validate()`)
- [ ] All three resolvable via `DataRegistry.resolve("classes", id)`
- [ ] None appear in `get_recruitable_classes()` (Story 007 filter excludes tier=2)
- [ ] **TR-hero-class-db-020 advisory check**: each stub's `flavor_text.length() <= 120` OR `push_warning` is fired at load time (not a hard fail)
- [ ] **H-11**: a smoke check report at `production/qa/smoke-*.md` records flavor_text length for all 6 classes (3 MVP from Story 003 + 3 V1.0 stubs); none over 120 chars (or warnings present for any over)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §V1.0 stubs + GDD §C:*

- Author the 3 stubs in inspector. Stub stat values can be approximate / placeholder — they're not played in MVP; what matters is they parse and validate.
- Suggested `counter_archetype` distribution to demonstrate forward-compat archetype usage:
  - Cleric → `EnemyArchetypes.INCORPOREAL` (canon: clerics counter undead/spirits)
  - Ranger → `EnemyArchetypes.BEAST` (rangers vs beasts)
  - Tactician → `EnemyArchetypes.CONSTRUCT` (tactical insight vs constructs)
  - (Adjust per GDD §C V1.0 stub table when picked up — these are educated guesses.)
- Add a tiny advisory checker to HeroClass `_validate()` OR as a separate boot-time scan: `if class.flavor_text.length() > 120: push_warning("HeroClass[%s]: flavor_text length %d exceeds 120-char advisory limit" % [class.id, class.flavor_text.length()])`. This is non-fatal; the resource still loads.
- Smoke check evidence: include the script `tools/qa/check_flavor_text_lengths.sh` (or equivalent) that emits a report per class.

---

## Out of Scope

- Story 003: 3 MVP class `.tres` files (sibling)
- Story 007: get_recruitable_classes filter (consumes this content)
- V1.0 stub stat balance — placeholder values acceptable

---

## QA Test Cases

- **AC: 3 V1.0 stubs load**
  - **Given**: Godot booted with 6 `.tres` files in `assets/data/classes/` (3 MVP + 3 V1.0)
  - **When**: `get_by_id("cleric")`, `get_by_id("ranger")`, `get_by_id("tactician")`
  - **Then**: each returns non-null HeroClass with `tier == 2`
  - **Edge cases**: each stub passes schema validation (Story 008's `_validate()` returns empty array)

- **AC: stubs absent from recruitable**
  - **Given**: 6 classes loaded
  - **When**: `get_recruitable_classes()`
  - **Then**: returned array length = 3; none of the V1.0 stub ids appear
  - **Edge cases**: see Story 007 for full filter assertions

- **AC: flavor_text advisory check**
  - **Given**: each class's flavor_text
  - **When**: load-time advisory check runs
  - **Then**: lengths recorded; any > 120 triggers `push_warning` with the offending id; load proceeds normally
  - **Edge cases**: empty flavor_text is treated as 0 length (passes the limit; might trigger a separate "missing flavor" content warning, decide when picked up)

- **AC: smoke check evidence**
  - **Given**: clean `godot --headless` boot
  - **When**: smoke check script runs and produces `production/qa/smoke-*.md`
  - **Then**: report contains a section listing each class id + flavor_text length
  - **Edge cases**: report format matches Sprint 1 smoke check pattern

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- 3 `.tres` files in `assets/data/classes/`
- A passing smoke check report at `production/qa/smoke-*.md`
- Cross-check assertion in `tests/unit/hero_class_database/v1_stubs_load_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (schema), Story 002 (autoload), Story 008 (schema validator)
- **Unlocks**: Story 007 H-09 filter test fixtures
