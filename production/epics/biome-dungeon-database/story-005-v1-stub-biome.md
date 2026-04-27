# Story 005: V1.0 stub biome (forward-compat fixture + filter test)

> **Epic**: biome-dungeon-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §H-07, §H-08, §C V1.0 stubs
**Requirements**: TR-biome-dungeon-db-013
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (V1.0 stub pattern + status filter)
**ADR Decision Summary**: 1+ V1.0 stub biome authored as `status="planned_v1"` with empty `dungeons` array. Loads as LOADED into DataRegistry but FILTERED OUT of `get_playable_biomes()` (Story 002 filter). Existence supports forward-compat testing without shipping V1.0 content.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Permitted**: V1.0 content stubs in repo (forward-compat). — ADR-0011
- **Required**: status field accurately reflects content presence. — ADR-0011

---

## Acceptance Criteria

- [ ] At least 1 V1.0 stub biome `.tres` exists in `assets/data/biomes/` with:
  - `id` distinct from "forest_reach" (e.g., "stormwood_keep" or another from systems-index V1.0 list)
  - `status = "planned_v1"`
  - `display_name` non-empty
  - `dungeons = []` (empty array — TR-biome-dungeon-db-013 forward-compat)
  - `flavor_text` non-empty (advisory; gives the stub identity)
- [ ] **AC H-07 + TR-biome-dungeon-db-013**: stub passes Story 004 schema validation (`status` is in valid enum; empty dungeons array is acceptable for `planned_v1` stubs)
- [ ] Stub resolvable via `BiomeDungeonDatabase.get_biome_by_id("[stub_id]")` (returns non-null)
- [ ] **AC H-08**: stub absent from `get_playable_biomes()` (Story 002 filter excludes status != "active")
- [ ] `get_all_biome_ids()` includes BOTH Forest Reach AND the stub (filter is one-way — they're loaded, just not playable)
- [ ] `design/registry/entities.yaml` updated with the V1.0 stub entry (or confirmed already present from Sprint 1 systems-index work)

---

## Implementation Notes

*Derived from ADR-0011 §V1.0 stub pattern + GDD §C:*

- Author the stub biome `.tres` via Godot inspector. Suggested values:
  - `id`: pick from the systems-index V1.0 list (e.g., "stormwood_keep", "iron_marshes", "obsidian_pass" — verify against the systems-index for consistency)
  - `status`: `"planned_v1"`
  - `dungeons`: `[]` empty array
  - `display_name`: human-readable
  - `flavor_text`: evocative ≤ 200 chars per advisory
  - `dominant_archetypes`: `[]` empty (stubs don't yet declare archetype mix)
  - `primary_palette_key`: empty string OR a placeholder palette key (validation Story 004 doesn't enforce non-empty for stubs — verify at story pickup)
  - `environmental_storytelling`: `[]` empty (Art Bible Section 4 content lands for V1.0)
- DO NOT author Dungeon or Floor resources for the stub — `dungeons = []` is the entire point.
- entities.yaml registration: append a single entry for the stub biome. Status field tracks 'planned_v1'.

---

## Out of Scope

- Story 003: Forest Reach (sibling)
- Story 004: schema validation
- Story 002: filter implementation (already verified)
- V1.0 stub content beyond the biome shell — actual dungeons/floors land in V1.0 sprint when content is authored

---

## QA Test Cases

- **AC: stub loads**
  - **Given**: stub biome `.tres` at `assets/data/biomes/[stub_id].tres`
  - **When**: `BiomeDungeonDatabase.get_biome_by_id(stub_id)`
  - **Then**: returns non-null Biome with `status == "planned_v1"`, `dungeons.is_empty()`
  - **Edge cases**: re-load test confirms stable state across boots

- **AC H-08: stub excluded from playable list**
  - **Given**: Forest Reach + V1.0 stub both loaded
  - **When**: `get_playable_biomes()`
  - **Then**: returned array contains Forest Reach but NOT the V1.0 stub
  - **Edge cases**: only V1.0 stub loaded (no Forest Reach yet — hypothetical) → empty playable list, no error

- **AC: stub appears in get_all_biome_ids**
  - **Given**: same setup
  - **When**: `get_all_biome_ids()`
  - **Then**: returned `Array[String]` contains BOTH ids; sorted alphabetical
  - **Edge cases**: single-stub state → array has length 1

- **AC: schema validation accepts planned_v1 status**
  - **Given**: V1.0 stub biome
  - **When**: `_validate()` (Story 004) runs
  - **Then**: returns empty array (no violations); validator's status enum accepts "planned_v1"
  - **Edge cases**: invalid status (e.g., "deprecated") → Story 004 validator rejects

- **AC: entities.yaml registration**
  - **Given**: `design/registry/entities.yaml` post-update
  - **When**: parse YAML
  - **Then**: stub entry present with `status: planned_v1`

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- 1+ stub biome `.tres` in `assets/data/biomes/`
- `design/registry/entities.yaml` updated
- A passing smoke check report at `production/qa/smoke-*.md`
- Cross-check assertion in `tests/integration/biome_dungeon_database/biome_dungeon_database_autoload_test.gd::test_get_playable_biomes_filters_v1_stubs`

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (Biome schema), Story 002 (BiomeDungeonDatabase autoload + filter), Story 004 (validator must accept "planned_v1" status)
- **Unlocks**: Story 002 H-08 filter test fixture; V1.0 sprint content addition
