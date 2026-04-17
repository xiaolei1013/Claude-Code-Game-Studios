# Evidence: E1-003 Rooms 1-5 Configuration

**Date**: 2026-04-18
**Story**: production/epics/room-content/003-rooms-1-5-configuration.md
**Type**: Config/Data (Inspector authoring)

---

## Configuration Specification

Create 5 RoomConfig assets in `Assets/Trizzle/Data/Rooms/`:

### Room 1: Crypt Entrance (Swarm)
- **Asset**: `RoomConfig_Room01.asset`
- **Archetype**: Swarm
- **Waves**: 4 waves, 6-10 enemies per wave, mostly regular, 10% elites in wave 4
- **Enemy types**: 2 types (Skeleton, Zombie variants)
- **Boss**: Stone Guardian (Boss A, 2-phase variant)
- **Traps**: Fire grates (2-3 placements, <15% coverage)
- **Target clear time**: ~105s Normal

### Room 2: Sorcerer's Chamber (Ambush)
- **Asset**: `RoomConfig_Room02.asset`
- **Archetype**: Ambush
- **Waves**: 3 waves, 4-6 enemies per wave, surprise spawn positions
- **Enemy types**: 3 types (Archer, Mage, Melee mix)
- **Boss**: Dark Sorcerer (Boss B, 2-phase)
- **Traps**: Spike traps (1-2 placements)
- **Target clear time**: ~120s Normal

### Room 3: Bone Corridor (Gauntlet)
- **Asset**: `RoomConfig_Room03.asset`
- **Archetype**: Gauntlet
- **Waves**: 5 waves, escalating 4→8 enemies, linear progression
- **Enemy types**: 3 types (mix of undead)
- **Boss**: Necromancer (Boss C, 2-phase)
- **Traps**: Arrow traps (2-3 placements along corridor)
- **Target clear time**: ~135s Normal

### Room 4: War Arena (Arena)
- **Asset**: `RoomConfig_Room04.asset`
- **Archetype**: Arena
- **Waves**: 4 waves, 6-8 enemies, balanced spawns
- **Enemy types**: 4 types (orc variants)
- **Boss**: War Chief (Boss D, 2-phase)
- **Traps**: None (open arena)
- **Target clear time**: ~150s Normal

### Room 5: Cursed Sanctum (Hybrid)
- **Asset**: `RoomConfig_Room05.asset`
- **Archetype**: Hybrid (Swarm + Ambush)
- **Waves**: 4 waves, 8-12 enemies, mixed spawn patterns
- **Enemy types**: 4 types (demon variants)
- **Boss**: Lich King (Boss E, 2-phase)
- **Traps**: Fire grates + spike traps (3-4 placements, <15% coverage)
- **Target clear time**: ~180s Normal

---

## Smoke Check Checklist

- [ ] 5 RoomConfig assets exist in `Assets/Trizzle/Data/Rooms/`
- [ ] Each has correct Archetype enum value
- [ ] Each has non-empty Waves list (3-5 waves per room)
- [ ] Each has non-null BossConfig referencing correct 2-phase boss
- [ ] Trap coverage ≤15% navigable area (G-010)
- [ ] Each wave has valid SpawnItemInfo entries with non-null prefabs
- [ ] In Play mode: Room 1 waves spawn correctly
- [ ] In Play mode: Boss spawns after final wave

## Status

**BLOCKED ON UNITY EDITOR**: Requires Inspector authoring of 5 RoomConfig assets + wave data.
