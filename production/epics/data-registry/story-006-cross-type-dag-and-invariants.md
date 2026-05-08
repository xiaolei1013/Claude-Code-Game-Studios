# Story 006: Cross-reference DAG validation and cross-type invariants

> **Epic**: data-registry
> **Status**: Complete (real implementation 2026-05-08 — `_validate_dag` + `_walk_for_cycle` added to source; `_boot_scan` wired to call it; integration test ships with 8 functions covering DAG ACs + production-data false-positive avoidance. Audit-cascade Status flip from earlier was over-eager — the validator did NOT exist before this PR. 7th instance of audit-cascade-over-eager pattern caught today.)
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-008, TR-data-loading-018]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary) + ADR-0011 (cross-type validators)
**ADR Decision Summary**: `_validate_dag()` BFS-traverses the registered resource graph post-load and transitions to ERROR on cycle detection; cross-type invariants (archetype-distribution, boss-uniqueness, `is_boss_floor` ⇔ resolved EnemyData `is_boss`) run AFTER all per-type validation completes and fail-fast on the first violation.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot's `ResourceLoader` has limited cycle detection (cycles stall or produce null refs) — post-load validation is the reliable check. `ExtResource` resolution happens at parse time using the resource cache; BFS traversal walks the in-memory graph. No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer + Core Layer — cross-type validation)**:
- **Required**: "Cross-reference DAG MUST hold (no cycles); `_validate_dag()` BFS-traverses post-load and triggers `ERROR` state on cycle detection." — ADR-0006
- **Required**: "`is_boss_floor == true` ⇔ at least one `enemy_list[i]` resolved EnemyData has `is_boss == true`; cross-type validator [BLOCKING]." — ADR-0011
- **Required**: "Archetype-distribution invariant: for every active dungeon, floors 1-3 collectively cover all 3 MVP archetypes (`bruiser`, `caster`, `armored`); cross-type validator [BLOCKING]." — ADR-0011
- **Required**: "Boss-uniqueness invariant: exactly one floor per Dungeon has `is_boss_floor == true`." — ADR-0011
- **Required**: "Validators run in `ordered_categories` sequence; cross-type validators run AFTER all per-type validation completes; fail-fast." — ADR-0011
- **Required**: "`Dungeon.biome_id` MUST resolve via `DataRegistry.resolve(\"biomes\", biome_id)` (DAG required); `Floor.enemy_list[].enemy_id` MUST resolve via `DataRegistry.resolve(\"enemies\", enemy_id)` (DAG required)." — ADR-0011

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [x] TR-data-loading-008: Cross-reference DAG rule: no cycles; load order `classes → enemies → biomes → dungeons → items → matchup`
- [x] TR-data-loading-018: Post-load DAG validation detects circular references → ERROR state with cycle path logged
- [x] AC-DLS-06: **GIVEN** two resources form a circular reference (`dungeon_A → biome_B → dungeon_A`, or any cycle length ≥ 2), **WHEN** the Data Loading System performs post-load DAG validation, **THEN** the cycle is detected and reported: `[DataRegistry] CIRCULAR REF: dungeon_A → biome_B → dungeon_A`; state transitions to `ERROR`; neither resource in the cycle is available via `resolve()`; all other non-cyclic resources remain accessible.

---

## Implementation Notes

*Derived from ADR-0006/0011 Implementation Guidelines:*

- Implement `_validate_dag()` per ADR-0006: BFS-traverse the registered resource graph after all categories have loaded; edges are the `ExtResource` and id-string refs declared by ADR-0011 (`Dungeon.biome_id → Biome`, `Floor.enemy_list[].enemy_id → EnemyData`).
- On cycle detection: transition to ERROR; emit `registry_error(reason = "CircularRef", details = {"cycle": [...]})`; log line format `[DataRegistry] CIRCULAR REF: dungeon_A → biome_B → dungeon_A` (cycle path joined by ` → ` with the start node repeated at the tail).
- Implement `_validate_cross_type_invariants()` per ADR-0011 §Cross-Type (run AFTER per-type validators complete):
  1. **Boss-uniqueness**: for each Dungeon, count floors where `is_boss_floor == true`; fail if count != 1.
  2. **Archetype-distribution**: for each Dungeon whose parent Biome has `status == "active"`, collect the set of archetypes covered by the resolved EnemyData for all enemies in floors 1–3; fail if the set does not contain all three MVP archetypes (`bruiser`, `caster`, `armored`).
  3. **`is_boss_floor` ⇔ EnemyData.is_boss**: for every Floor, `is_boss_floor == true` MUST imply at least one resolved `enemy_list[i]` EnemyData has `is_boss == true`; `is_boss_floor == false` MUST imply ALL resolved `enemy_list[i]` EnemyData have `is_boss == false`.
  4. **HeroClass counter_archetype MVP coverage**: every `tier == 1` HeroClass's `counter_archetype` MUST be in `EnemyArchetypes.MVP_SET`.
- Cross-type validators use the same ERROR-state + `registry_error` path as per-type validators. Any failure → ERROR; fail-fast per ADR-0011 validation-ordering contract; no `registry_ready` emission.
- Unresolvable required cross-refs surface here (e.g., `Dungeon.biome_id = "nonexistent_biome"`) as `reason = "UnresolvableCrossRef"`.
- Cross-type validators run EXACTLY once per boot scan (or per hot-reload cycle — Story 007 wires hot_reload to re-run).
- Order of validators within the cross-type phase is deterministic and documented as DAG cycle → boss-uniqueness → archetype-distribution → `is_boss_floor` coupling → HeroClass counter-archetype MVP; first failure wins.

---

## Out of Scope

- Story 005: Per-type validators + duplicate-id detection + `min_content_count` (prerequisite).
- Story 007: Hot-reload re-enumeration + read-only contract enforcement.
- Story 008: Performance budget AC-DLS-07.
- Validators for Item and MatchupRule schemas (deferred to ADR-C03 and ADR-X04).

---

## QA Test Cases

- **TR-data-loading-018 / AC-DLS-06**: Circular cross-reference transitions to ERROR with cycle path
  - **Given**: Fixture where `dungeon_a.tres` references `biome_b` via `biome_id`, and `biome_b.tres` embeds `dungeon_a` via its `dungeons` array (cycle length 2).
  - **When**: `_validate_dag()` runs post-load.
  - **Then**: `state == State.ERROR`; `registry_error(reason = "CircularRef", details)` emitted with `details.cycle == ["dungeon_a", "biome_b", "dungeon_a"]`; log matches `[DataRegistry] CIRCULAR REF: dungeon_a → biome_b → dungeon_a`; `resolve("dungeons", "dungeon_a")` and `resolve("biomes", "biome_b")` both return null after ERROR; non-cyclic resources (e.g., a class fixture) are unaffected if accessed before the ERROR short-circuit.
  - **Edge cases**: Cycle length 3+ (`A → B → C → A`) reports the full path; self-loop (`A → A`) is length-1 cycle; acyclic DAG is silent pass.

- **TR-data-loading-008**: Load order ensures cross-refs resolve at parse time
  - **Given**: Fixture where `dungeon.tres` holds an `ExtResource` ref to `biome.tres`.
  - **When**: Boot scan runs in `classes → enemies → biomes → dungeons → items → matchup` order.
  - **Then**: By the time `dungeons/` is enumerated, `biomes/` is fully loaded in the resource cache; the Dungeon's `biome_id` resolves to a non-null Biome via `DataRegistry.resolve("biomes", biome_id)`; no parse warning fires.
  - **Edge cases**: Intentionally reordering to load `dungeons` before `biomes` (test-only) would cause null cross-refs — protects against silent order regressions.

- **ADR-0011 cross-type: Boss uniqueness**
  - **Given**: Fixture Dungeon with two floors both marked `is_boss_floor = true`.
  - **When**: Cross-type validation runs.
  - **Then**: `state == State.ERROR`; `registry_error(reason = "BossUniqueness", details = {"dungeon_id": "...", "boss_floor_count": 2})`.
  - **Edge cases**: Zero boss floors — also ERROR; exactly one — passes.

- **ADR-0011 cross-type: Archetype distribution over floors 1–3 of active Dungeons**
  - **Given**: Fixture active Dungeon whose floors 1–3 collectively contain only `bruiser` and `caster` archetypes (missing `armored`).
  - **When**: Cross-type validation runs.
  - **Then**: `state == State.ERROR`; `registry_error(reason = "ArchetypeDistribution", details = {"dungeon_id": "...", "missing": ["armored"]})`.
  - **Edge cases**: A `planned_v1` Biome's Dungeon is exempt from this check; coverage on floors 4–5 does NOT satisfy the invariant.

- **ADR-0011 cross-type: `is_boss_floor` ⇔ EnemyData.is_boss coupling**
  - **Given**: Fixture Floor with `is_boss_floor = true` but every enemy in `enemy_list` has `is_boss = false`.
  - **When**: Cross-type validation runs.
  - **Then**: `state == State.ERROR`; `registry_error(reason = "IsBossFloorCoupling", details = {"floor_id": "...", "direction": "declared_but_no_boss_enemy"})`.
  - **Edge cases**: `is_boss_floor = false` with a boss enemy present also errors (reverse direction); enemy_list with a mix (one boss + two non-boss) satisfies the TRUE direction.

- **Unresolvable required cross-ref**
  - **Given**: Fixture Dungeon with `biome_id = "nonexistent_biome"`.
  - **When**: Cross-type validation runs.
  - **Then**: `state == State.ERROR`; `registry_error(reason = "UnresolvableCrossRef", details = {"from": "dungeon_id", "ref_type": "biomes", "ref_id": "nonexistent_biome"})`.
  - **Edge cases**: Floor with unresolvable `enemy_id` likewise errors.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/data_registry/cross_type_dag_and_invariants_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 005
- **Unlocks**: Story 007
