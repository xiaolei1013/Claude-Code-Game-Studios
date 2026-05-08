# Story 007: get_recruitable_classes filter (MVP tier-1 only)

> **Epic**: hero-class-database
> **Status**: Complete (system shipped; see systems-index Implementation Status #6. Test evidence: `tests/{unit,integration}/hero_class_database/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §H-09, §C
**Requirements**: TR-hero-class-db-015
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011
**ADR Decision Summary**: `get_recruitable_classes() -> Array[HeroClass]` returns only `tier == 1` classes in MVP builds. Tier-2 V1.0 stubs are LOADED into the registry (resolvable individually) but FILTERED OUT of the recruitable pool. Filter is `class.tier == 1`, not a separate `status` field — keeps schema minimal.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Required**: filter by `tier`, not by separate `status` field. — ADR-0011

---

## Acceptance Criteria

- [ ] `get_recruitable_classes() -> Array[HeroClass]` returns array of HeroClass instances where `class.tier == 1`
- [ ] **H-09**: 3 MVP classes (warrior/mage/rogue) loaded + 3 V1.0 stubs (cleric/ranger/tactician at tier=2) loaded → `get_recruitable_classes()` returns array of length 3 containing only the MVP classes
- [ ] V1.0 stubs are still individually resolvable: `get_by_id("cleric")` returns non-null (LOADED), but cleric is absent from the recruitable list
- [ ] Sort order: returned array sorted by `id` (alphabetical) for deterministic UI rendering — OR by a stable order documented in the AC (decide when picked up; recommend alphabetical)
- [ ] Empty case: if no tier-1 classes loaded, returns empty array (not null)
- [ ] No mutation: repeated calls return equivalent arrays; the underlying registry is not modified

---

## Implementation Notes

*Derived from ADR-0011 §Decision §recruitable filter:*

- Pseudocode:
  ```
  func get_recruitable_classes() -> Array[HeroClass]:
      var result: Array[HeroClass] = []
      for id in DataRegistry.get_all_ids("classes"):
          var hc: HeroClass = DataRegistry.resolve("classes", id)
          if hc != null and hc.tier == 1:
              result.append(hc)
      result.sort_custom(func(a, b): return a.id < b.id)
      return result
  ```
- Do NOT cache the result. The cost is O(N) over class count, with N ≤ 6 in MVP — cheap.
- Sort is for UI determinism; if Recruitment screen needs a different order (e.g., role grouping), add that in the screen code, not here.

---

## Out of Scope

- Story 011: 3 V1.0 stub `.tres` files (Cleric / Ranger / Tactician at tier=2)
- Recruitment Feature epic — consumes this filter

---

## QA Test Cases

- **AC H-09: filter excludes V1.0 stubs**
  - **Given**: 3 MVP classes (tier=1) + 3 V1.0 stubs (tier=2) loaded
  - **When**: `get_recruitable_classes()`
  - **Then**: returned array length = 3; all three results have `tier == 1`; ids are exactly `["mage","rogue","warrior"]` (alphabetical)
  - **Edge cases**: each stub still resolvable individually via `get_by_id`

- **AC: V1.0 stubs still resolvable**
  - **Given**: same setup
  - **When**: `get_by_id("cleric")`, `get_by_id("ranger")`, `get_by_id("tactician")`
  - **Then**: each returns non-null with `tier == 2`
  - **Edge cases**: filter is one-way (excludes from recruitable, doesn't unregister)

- **AC: sort order deterministic**
  - **Given**: 3 MVP classes
  - **When**: `get_recruitable_classes()` called 100 times
  - **Then**: every call returns the same id ordering
  - **Edge cases**: if class set changes (e.g., adding a V1.0 promotion to MVP later), the filter re-sorts correctly

- **AC: empty case**
  - **Given**: only tier-2 classes loaded (no tier-1)
  - **When**: `get_recruitable_classes()`
  - **Then**: returns empty `Array[HeroClass]`; not null
  - **Edge cases**: zero classes loaded total → still returns empty array, no error

- **AC: no mutation**
  - **Given**: call `get_recruitable_classes()` and capture the array
  - **When**: modify the captured array (e.g., remove an element)
  - **Then**: subsequent calls still return the full filtered set (returned arrays are owned by caller)
  - **Edge cases**: HeroClass instances themselves remain immutable (Story 002 contract)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_class_database/get_recruitable_classes_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (autoload), Story 003 (3 MVP classes), Story 011 (3 V1.0 stubs for the H-09 filter test)
- **Unlocks**: Recruitment Feature epic
