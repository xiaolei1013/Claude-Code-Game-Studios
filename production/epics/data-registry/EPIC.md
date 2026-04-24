# Epic: Data Registry

> **Layer**: Foundation
> **GDD**: `design/gdd/data-loading.md`
> **Architecture Module**: `DataRegistry` (autoload rank 1)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: 8 defined (all Ready)

## Overview

Implements the single authoritative content-loading subsystem for Lantern
Guild per ADR-0006. Eager + synchronous `ResourceLoader.load` boot scan
(not `load_threaded_request` for MVP) over the fixed deterministic order
`classes → enemies → biomes → dungeons → items → matchup` defined in
`ordered_categories: PackedStringArray`. Fires `registry_ready` exactly once
per session (LOADING→READY transition), `registry_error(reason, details)` on
fatal load error, and `hot_reload_complete(content_type)` in dev-only builds.
State machine: `UNLOADED → LOADING → READY | ERROR | HOT_RELOAD`; `ERROR`
is terminal — game cannot proceed; SaveLoadSystem checks `state == READY`
before hydrating consumers. All `.tres` content lives only under
`assets/data/{classes,enemies,biomes,dungeons,items,matchup}/`; adding a
new category requires explicit edit to `ordered_categories` and
`min_content_count`. Resources returned by `get_all_by_type()` / `resolve()`
are immutable by convention — consumers MUST `.duplicate()` or
`.duplicate_deep()` (4.5+) for mutable copies, with the caveat that
`duplicate_deep()` does NOT cross `ExtResource()` boundaries. Cross-reference
DAG validation runs post-load via `_validate_dag()` BFS traversal; cycle
detection triggers `ERROR` state. `hot_reload(content_type)` is
runtime-gated by `OS.is_debug_build()` — production no-op.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Autoload Rank Table Canonical | DataRegistry is rank 1; bare-identifier resolution `DataRegistry.registry_ready.connect(...)` (Claim 1 [VERIFIED]) | LOW |
| ADR-0006: Data Loading Boot Scan Strategy | Eager + synchronous scan; fixed category order; resource immutability convention; DAG validation; dev-only hot reload; `@abstract class_name GameData extends Resource` base | **MEDIUM** — `@abstract` keyword (4.5+, verified); `duplicate_deep()` (4.5+, does not cross `ExtResource()`); `ResourceLoader.load` synchronous path |
| ADR-0011: Resource Schemas for Core Databases | 5 GameData subclass schemas locked (HeroClass 16 fields, EnemyData 13, Biome 7, Dungeon 4, Floor 7); all content fields `@export`-decorated; archetype/role constants; cross-type invariants (is_boss_floor, archetype-distribution, boss-uniqueness) | LOW — pure data schema |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-data-loading-001..028`) | **28** |
| Covered by Accepted ADR | ~27 |
| Partial | ~1 |
| Gap | 0 |

Full per-TR detail: `docs/architecture/requirements-traceability.md` §Foundation Layer and `docs/architecture/tr-registry.yaml` (filter by `TR-data-loading-*`).

## Engine Compatibility Notes

Verify during story implementation (Godot 4.6):
- `@abstract` keyword (4.5+) — required for `GameData` base class per ADR-0006/0011; editor UI for abstract instantiation attempts is undocumented but expected to produce a clear error
- `duplicate_deep()` (4.5+) does NOT cross `ExtResource()` boundaries — cross-file references remain shared (ADR-0006 LOAD-BEARING note, verified)
- `ResourceLoader.load(path)` synchronous — no `load_threaded_request` in MVP boot path
- `Array[Dictionary]` is NOT inspector-editable in 4.6 (surfaced in ADR-0011) — `Floor.enemy_list` uses `{enemy_id: String, count: int}` dicts, not `Array[EnemyData]` inline refs

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/data-loading.md` are verified (AC-DLS-01..08)
- All Logic stories have passing test files in `tests/unit/data_registry/` (load order determinism, DAG validator cycle detection, state-machine transitions, archetype/role constant-set validation)
- All Integration stories have passing test files in `tests/integration/data_registry/` (full MVP-scale boot scan, SaveLoadSystem hydration-gate sequencing, hot-reload dev-only gating)
- Cross-type validator (ADR-0011) passes on all shipped `.tres` content: archetype-distribution invariant (floors 1-3 cover bruiser+caster+armored), boss-uniqueness invariant (exactly one `is_boss_floor == true` per dungeon), `is_boss_floor` ⇔ resolved EnemyData has `is_boss == true`
- Boot scan time <200ms on min-spec mobile at MVP scale (AC-DLS-07 BLOCKING)
- Total loaded content memory <400KB MVP (BUDGET)
- No `ResourceLoader.load("res://assets/data/...")` outside DataRegistry (CI grep per ADR-0006)
- No consumer mutates a Resource returned by accessors (CI assertion per ADR-0006)
- No filename-as-id assignments; `id` is authored `snake_case` (CI grep per ADR-0011)

## Stories

| # | Story | Type | Status | Governing ADR |
|---|---|---|---|---|
| 001 | DataRegistry autoload skeleton and state machine | Logic | Ready | ADR-0006 + ADR-0003 |
| 002 | GameData abstract base and archetype/role constant sets | Logic | Ready | ADR-0006 + ADR-0011 |
| 003 | Boot scan load order and per-category enumeration | Logic | Ready | ADR-0006 |
| 004 | `resolve()` API and typed category accessors | Logic | Ready | ADR-0006 |
| 005 | Per-type validators, duplicate id detection, and `min_content_count` | Logic | Ready | ADR-0006 + ADR-0011 |
| 006 | Cross-reference DAG validation and cross-type invariants | Logic | Ready | ADR-0006 + ADR-0011 |
| 007 | Hot-reload, immutability enforcement, and SaveLoadSystem hydration gate | Integration | Ready | ADR-0006 + ADR-0003 |
| 008 | Boot scan performance budget (MVP <200 ms on min-spec mobile) | Integration | Ready | ADR-0006 |

**Dependency chain**: 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 (strictly sequential; each story unlocks only the next numbered story).

## Next Step

Run `/create-stories data-registry` to break this epic into implementable stories.
