# Story: Rooms 1-5 Configuration

> **Epic**: room-content
> **Type**: Config
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-room-001 (10 RoomConfig SOs), TR-room-002 (4 archetypes + Hybrid), TR-room-004 (minimum arena sizes), TR-room-005 (spawn point minimums), TR-room-006 (trap coverage max 15%), TR-room-009 (clear time targets), TR-room-010 (per-wave SpawnItemInfo), TR-room-011 (boss spawns after final wave)
**ADR Reference**: ADR-0006 -- Asset Naming Convention, Migration Plan steps 5-8
**Control Manifest Rules**: R-017 (RoomConfig fields), R-018 (RoomArchetype enum values), G-010 (trap coverage <= 15%), G-012 (2-phase bosses for rooms 1-5)

## Description

Author the first 5 `RoomConfig` ScriptableObject assets that form the introductory half of the v1.0 campaign. These rooms introduce all 4 archetypes plus the first Hybrid room. All rooms use 2-phase bosses and simpler trap layouts. This is the largest single content authoring task in the E1 epic.

**Assets to create in `Assets/Trizzle/Data/Rooms/`:**

1. **`RoomConfig_Room01.asset`** -- Crypt Entrance (Swarm)
   - Archetype: Swarm
   - Waves: 4 waves, 6-10 enemies per wave, mostly regular, 10% elites in wave 4
   - Enemy types: 2 types (e.g., Skeleton, Zombie)
   - Boss: Stone Guardian (Boss A, 2-phase)
   - Traps: Fire grates (2-3 placements)
   - Target clear time: ~105s Normal

2. **`RoomConfig_Room02.asset`** -- Sorcerer's Chamber (Ambush)
   - Archetype: Ambush
   - Waves: 3 waves, 2-4 enemies per wave, mixed regular+elite, flanking spawns
   - Enemy types: 2-3 types
   - Boss: Dark Sorcerer (Boss B, 2-phase)
   - Traps: Projectile traps (2-3 placements)
   - Target clear time: ~120s Normal

3. **`RoomConfig_Room03.asset`** -- Necromancer's Corridor (Gauntlet)
   - Archetype: Gauntlet
   - Waves: 5 waves, 4-6 enemies per wave, regular enemies spawning ahead
   - Enemy types: 3 types
   - Boss: Necromancer (Boss C, 2-phase)
   - Traps: Spike floors + poison vents (3-4 placements)
   - Target clear time: ~135s Normal

4. **`RoomConfig_Room04.asset`** -- War Hall (Arena)
   - Archetype: Arena
   - Waves: 3 waves, 0 enemies (boss-only, minions via boss abilities)
   - Enemy types: Boss-summoned only
   - Boss: War Chief (Boss D, 2-phase)
   - Traps: Ground slam zones (2-3 placements)
   - Target clear time: ~150s Normal

5. **`RoomConfig_Room05.asset`** -- Lich's Antechamber (Hybrid: Swarm + Ambush)
   - Archetype: Hybrid
   - Waves: 5 waves, alternating Swarm and Ambush patterns
   - Enemy types: 3-4 types
   - Boss: Lich King (Boss E, 2-phase)
   - Traps: Mixed fire grates + projectile traps (3-4 placements)
   - Target clear time: ~165s Normal

**Wave composition rules (from GDD):**
- `baseEnemyCount(room) = 4 + (roomIndex * 0.6)` -- Room 1: 5, Room 5: 7
- `eliteRatio(room) = 0.10 + (roomIndex * 0.03)` -- Room 1: 13%, Room 5: 25%
- `waveCount(room) = 3 + Ceil(roomIndex / 3)` -- Room 1: 4, Room 5: 5
- Enemy variety increases: Room 1 uses 2 types, Room 5 uses 3-4 types

**Key constraints:**
- All values are Normal baseline only; Hard mode derived automatically via CampaignWaveProvider
- Boss references point to 2-phase BossConfig assets (from E3 Boss Phase System)
- Trap placements must keep coverage under 15% of navigable floor area
- Each SpawnItemInfo entry must reference a valid enemy prefab from the D5 enemy library

## Acceptance Criteria

- [ ] 5 `RoomConfig` assets exist in `Assets/Trizzle/Data/Rooms/` with correct naming convention
- [ ] Room 1 (Swarm): 4 waves, 6-10 enemies, 2 enemy types, Boss A (2-phase), fire grate traps
- [ ] Room 2 (Ambush): 3 waves, 2-4 enemies, 2-3 types, Boss B (2-phase), projectile traps
- [ ] Room 3 (Gauntlet): 5 waves, 4-6 enemies, 3 types, Boss C (2-phase), spike+poison traps
- [ ] Room 4 (Arena): 3 waves, boss-only encounter, Boss D (2-phase), ground slam traps
- [ ] Room 5 (Hybrid): 5 waves, alternating Swarm/Ambush, 3-4 types, Boss E (2-phase), mixed traps
- [ ] No null references on enemy prefabs, trap prefabs, or boss configs in any asset (GDD AC 1)
- [ ] Archetypes match the GDD room assignment table (GDD AC 2)
- [ ] Boss assignments match: Room 1 = Boss A, Room 2 = Boss B, Room 3 = Boss C, Room 4 = Boss D, Room 5 = Boss E (GDD AC 3)
- [ ] All bosses are 2-phase (rooms 1-5 per GDD and G-012)
- [ ] Trap coverage does not exceed 15% of navigable floor area per room (GDD AC 6, G-010)
- [ ] Wave enemy counts follow GDD progression formulas within 20% tolerance
- [ ] Elite ratios follow GDD progression (10% Room 1, 25% Room 5) within 5% tolerance

## Test Evidence

**Type**: Smoke Check
**Path**: `production/qa/evidence/`

- Smoke check: Load each of the 5 room assets in the Inspector, verify no null references (missing enemy prefab, trap prefab, or boss config)
- Smoke check: Verify each room's Archetype field matches the expected enum value
- Smoke check: Count waves per room and verify against GDD table (4, 3, 5, 3, 5)
- Smoke check: Count total enemies per room across all waves and verify rough alignment with GDD formulas
- Smoke check: Verify boss config references point to the correct 2-phase boss assets

## Dependencies

- **Blocked by**: 001-roomconfig-scriptableobject (RoomConfig type must exist), E3 Boss Phase System (BossConfig assets for bosses A-E must exist), D5 Enemy AI (enemy prefabs must exist), D6 Trap System (trap prefabs must exist)
- **Blocks**: 005-room-layout-spawn-points (spawn points reference room configs), 006-room-content-tests (integration tests verify room loading)

## Engine Notes

This is a pure Inspector authoring task -- no code is written. All work is in creating and populating Unity ScriptableObject assets via the Project window Create menu ("Trizzle/Room Config"). Verify that nested list editing (waves containing SpawnItems lists) works smoothly in Unity 6000.3.11f1 Inspector. Large nested lists may benefit from the Inspector debug mode for verification.
