# Epic: Room Content

> **Layer**: Content (Layer 2)
> **GDD**: design/gdd/room-content.md
> **Architecture Module**: E1 Room Content -- Content Layer
> **Governing ADRs**: ADR-0002, ADR-0006
> **Status**: Ready
> **Stories**: 6 stories created (2026-04-07)

## Stories

| # | Story | Type | Priority | Size | Status | Dependencies |
|---|-------|------|----------|------|--------|-------------|
| 001 | [RoomConfig ScriptableObject](001-roomconfig-scriptableobject.md) | Logic | P0 | M | Ready | ADR-0001, ADR-0002, ADR-0006 |
| 002 | [CampaignWaveProvider](002-campaign-wave-provider.md) | Logic | P0 | M | Ready | 001 |
| 003 | [Rooms 1-5 Configuration](003-rooms-1-5-configuration.md) | Config | P1 | L | Ready | 001, E3, D5, D6 |
| 004 | [Rooms 6-10 Configuration](004-rooms-6-10-configuration.md) | Config | P1 | L | Ready | 001, 003, E3, D5, D6 |
| 005 | [Room Layout & Spawn Points](005-room-layout-spawn-points.md) | Config | P1 | M | Ready | 001, 003, Room scenes |
| 006 | [Room Content Integration Tests](006-room-content-tests.md) | Logic | P0 | M | Ready | 001, 002, 003, 004, 005 |

### Critical Path

```
ADR-0001, ADR-0002, ADR-0006 (must be Accepted)
    |
    v
001 RoomConfig SO (P0, M)
    |
    +---> 002 CampaignWaveProvider (P0, M)
    |         |
    +---> 003 Rooms 1-5 (P1, L) -----+
    |         |                       |
    |         +-> 004 Rooms 6-10 (P1, L)
    |         |                       |
    |         +-> 005 Layout/Spawn (P1, M)
    |                                 |
    +---> 006 Integration Tests (P0, M) <--- all above must complete
```

### Dependency Summary

- **External blockers**: ADR-0001, ADR-0002, ADR-0006 must all reach Accepted status
- **Cross-epic blockers**: E3 Boss Phase System (BossConfig assets), D5 Enemy AI (enemy prefabs), D6 Trap System (trap prefabs)
- **Internal chain**: 001 -> 002 (code), 001 -> 003 -> 004 (config), 001 -> 005 (layout), all -> 006 (tests)

## Overview

The Room Content system defines the 10 combat rooms forming the v1.0 campaign, using 4 room archetypes (Swarm, Ambush, Gauntlet, Arena) plus Hybrid to create 10 distinct encounters. Each room is a self-contained combat arena with wave-based enemy spawns, environmental traps, and a boss encounter, defined as a `RoomConfig` ScriptableObject. Architecturally, `SpawnManager` has zero mode-awareness via the `IWaveProvider` strategy interface (ADR-0002): `CampaignWaveProvider` wraps each `RoomConfig` and applies `IDifficultyProvider` multipliers at runtime for Hard mode derivation -- no per-difficulty authoring (ADR-0006). The `RoomConfig` schema stores Normal-only wave lists, trap placements, boss assignment, and archetype tag. This is the largest content deliverable in v1.0 (10 rooms x 2 difficulties = 20 encounter configurations). Depends on N1 (Archer), E3 (Boss Phases), E4 (Combos), and E2 (Difficulty).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: SpawnManager Mode Routing | SpawnManager has zero mode-awareness; `CampaignWaveProvider` (reads RoomConfig) and `EndlessWaveProvider` (procedural formulas) swap at mode entry. Wave composition separated from difficulty scaling. `WaveData` struct is stack-allocated. | LOW -- uses MonoBehaviour, ScriptableObject, C# interfaces; all stable pre-cutoff APIs |
| ADR-0006: Room Content Data Pipeline | 10 `RoomConfig` ScriptableObjects store Normal-only wave/trap/boss data; Hard mode derived at runtime by `CampaignWaveProvider` applying `IDifficultyProvider` multipliers. `RoomArchetype` enum, `WaveDefinition`, `TrapPlacement` types defined. | LOW -- uses ScriptableObject, SerializeField, CreateAssetMenu; all stable pre-cutoff APIs |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|-------------|
| TR-room-001 | 10 RoomConfig ScriptableObjects: wave lists, trap placements, boss assignment, archetype tag | ADR-0006: RoomConfig schema with all four fields defined |
| TR-room-002 | 4 room archetypes (Swarm, Ambush, Gauntlet, Arena) + Hybrid; RoomArchetype enum | ADR-0006: RoomArchetype enum with all five values |
| TR-room-003 | Hard mode derived automatically from Normal baseline via IDifficultyProvider multipliers | ADR-0006: CampaignWaveProvider applies EnemyCountMultiplier and PacingMultiplier at runtime |
| TR-room-004 | Minimum arena size: 20x20 (Swarm/Ambush), 30x20 (Gauntlet), 25x25 (Arena) | Not covered by ADR -- level design story |
| TR-room-005 | Spawn point minimum: 4 per room (cardinal directions); Swarm rooms need 6-8 | Not covered by ADR -- level design story |
| TR-room-006 | Trap coverage max 15% of navigable floor area; at least one safe path | ADR-0006: Design authoring constraint; manual QA check |
| TR-room-007 | Every room has at least one 8-unit clear lane for Archer kiting | Not covered by ADR -- level design story |
| TR-room-008 | Room replay is deterministic: same enemy types, spawn points, traps | ADR-0006: RoomConfig is static asset with no randomized fields |
| TR-room-009 | Room clear time targets: Room 1 ~105s, Room 10 ~240s on Normal; Hard adds 30-50% | Not covered by ADR -- balance/playtest story |
| TR-room-010 | Wave composition per-wave: each WaveDefinition stores List<SpawnItemInfo> with enemy type, count, delay | ADR-0006: WaveDefinition.SpawnItems is List<SpawnItemInfo> |
| TR-room-011 | Boss spawns after final wave is cleared; no dead time between wave clear and boss spawn | ADR-0002: CampaignWaveProvider.IsBossWave() returns true after all waves exhausted |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All acceptance criteria from GDD verified
- All Logic/Integration stories have passing tests
- All Visual/Feel/UI stories have evidence docs
- All 10 `RoomConfig` assets authored in `Assets/Trizzle/Data/Rooms/`
- `CampaignWaveProvider` functional: reads RoomConfig, applies difficulty scaling
- `IWaveProvider` integration with SpawnManager verified
- Hard mode scales automatically from Normal baseline (no per-difficulty assets)
- Room replay is deterministic
- All rooms playable with both Mage and Archer
- Boss encounters trigger correctly after final wave
- ADR-0002 and ADR-0006 validation criteria all passing

## Next Step

Stories created. Run `/sprint-plan new` to schedule E1 stories into a sprint, or `/story-readiness [story-file]` to validate a story before starting it.
