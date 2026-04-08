# Story: Rooms 6-10 Configuration

> **Epic**: room-content
> **Type**: Config
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-room-001 (10 RoomConfig SOs), TR-room-002 (remixed archetypes), TR-room-004 (minimum arena sizes), TR-room-005 (spawn point minimums), TR-room-006 (trap coverage max 15%), TR-room-009 (clear time targets), TR-room-010 (per-wave SpawnItemInfo)
**ADR Reference**: ADR-0006 -- Asset Naming Convention, Migration Plan steps 5-8
**Control Manifest Rules**: R-017 (RoomConfig fields), R-018 (RoomArchetype enum values), G-010 (trap coverage <= 15%), G-012 (3-phase bosses for rooms 6-10)

## Description

Author the second 5 `RoomConfig` ScriptableObject assets that form the advanced half of the v1.0 campaign. These rooms remix the archetypes from rooms 1-5 with harder variants: more waves, higher elite ratios, 3-phase bosses, and combined trap types. This is the "final exam" content -- rooms 6-10 test mastery of the archetypes introduced in rooms 1-5.

**Assets to create in `Assets/Trizzle/Data/Rooms/`:**

1. **`RoomConfig_Room06.asset`** -- Deep Crypt (Swarm remix)
   - Archetype: Swarm
   - Waves: 5 waves, 8-12 enemies per wave, 25% elites in later waves
   - Enemy types: 3-4 types (expanded from Room 1's 2)
   - Boss: Stone Guardian (Boss A, 3-phase)
   - Traps: Fire grates + spike floors (4-5 placements, combined trap types)
   - Target clear time: ~180s Normal

2. **`RoomConfig_Room07.asset`** -- Dark Sanctum (Ambush remix)
   - Archetype: Ambush
   - Waves: 4 waves, 3-5 enemies per wave, higher elite ratio, more flanking positions
   - Enemy types: 3-4 types
   - Boss: Dark Sorcerer (Boss B, 3-phase)
   - Traps: Projectile traps + poison vents (4-5 placements)
   - Target clear time: ~195s Normal

3. **`RoomConfig_Room08.asset`** -- Catacombs (Gauntlet remix)
   - Archetype: Gauntlet
   - Waves: 6 waves, 5-7 enemies per wave, increasing elite waves
   - Enemy types: 4 types
   - Boss: Necromancer (Boss C, 3-phase)
   - Traps: All trap types combined (5-6 placements)
   - Target clear time: ~210s Normal

4. **`RoomConfig_Room09.asset`** -- Throne Room (Arena remix)
   - Archetype: Arena
   - Waves: 4 waves, boss-only with more aggressive minion summoning
   - Enemy types: Boss-summoned, wider variety than Room 4
   - Boss: War Chief (Boss D, 3-phase)
   - Traps: Ground slam zones + fire grates (4-5 placements)
   - Target clear time: ~225s Normal

5. **`RoomConfig_Room10.asset`** -- Lich's Domain (All archetypes)
   - Archetype: Hybrid
   - Waves: 6 waves alternating between Swarm, Ambush, and Gauntlet patterns (GDD Edge Case 5: "final exam" room)
   - Enemy types: 5+ types (max variety in the game)
   - Elite ratio: 40% (highest in the campaign, per GDD)
   - Boss: Lich King (Boss E, 3-phase)
   - Traps: All trap types + rain of fire environmental hazard (6-8 placements)
   - Target clear time: ~240s Normal

**Wave composition rules (from GDD, rooms 6-10):**
- `baseEnemyCount(room)` = Room 6: 7.6->8, Room 10: 10
- `eliteRatio(room)` = Room 6: 28%, Room 10: 40%
- `waveCount(room)` = Room 6: 5, Room 10: 7 (capped at 6 in GDD table)
- New enemy types introduced every 2 rooms
- Room 10 uses 5+ enemy types and 40% elite ratio

**Key constraints:**
- All values are Normal baseline only; Hard mode derived automatically
- All bosses are 3-phase (rooms 6-10 per GDD and G-012) -- same 5 boss identities as rooms 1-5 but with an additional phase
- Combined trap types create more complex navigation challenges
- Room 10 must feel like the hardest room: highest enemy count, most variety, all trap types, toughest boss
- Trap coverage stays under 15% despite more trap placements (larger rooms or smaller traps)

## Acceptance Criteria

- [ ] 5 `RoomConfig` assets exist in `Assets/Trizzle/Data/Rooms/` with correct naming convention
- [ ] Room 6 (Swarm remix): 5 waves, 8-12 enemies, 3-4 types, Boss A (3-phase), fire+spike traps
- [ ] Room 7 (Ambush remix): 4 waves, 3-5 enemies, 3-4 types, Boss B (3-phase), projectile+poison traps
- [ ] Room 8 (Gauntlet remix): 6 waves, 5-7 enemies, 4 types, Boss C (3-phase), all trap types
- [ ] Room 9 (Arena remix): 4 waves, boss encounter, Boss D (3-phase), ground slam+fire traps
- [ ] Room 10 (All archetypes): 6 waves alternating patterns, 5+ types, 40% elites, Boss E (3-phase), all trap types
- [ ] No null references on enemy prefabs, trap prefabs, or boss configs in any asset (GDD AC 1)
- [ ] Rooms 6-10 repeat bosses A-E with 3-phase configs (GDD AC 3)
- [ ] All bosses are 3-phase (rooms 6-10 per GDD and G-012)
- [ ] Trap coverage does not exceed 15% of navigable floor area per room (GDD AC 6, G-010)
- [ ] Room 10 has the highest enemy count, most variety, and highest elite ratio in the campaign
- [ ] Wave enemy counts follow GDD progression formulas within 20% tolerance
- [ ] Room 10 feels like an escalation from Room 5 (GDD AC 9: "Room 10 feels hardest")

## Test Evidence

**Type**: Smoke Check
**Path**: `production/qa/evidence/`

- Smoke check: Load each of the 5 room assets in the Inspector, verify no null references
- Smoke check: Verify each room's Archetype field matches expected enum value
- Smoke check: Count waves per room and verify against GDD table (5, 4, 6, 4, 6)
- Smoke check: Count total enemies per room and verify escalation from rooms 1-5
- Smoke check: Verify boss config references point to the correct 3-phase boss assets
- Smoke check: Verify Room 10 has the highest wave count, enemy count, and elite ratio

## Dependencies

- **Blocked by**: 001-roomconfig-scriptableobject (RoomConfig type must exist), 003-rooms-1-5-configuration (rooms 1-5 establish the baseline that rooms 6-10 remix), E3 Boss Phase System (3-phase BossConfig assets must exist), D5 Enemy AI (expanded enemy prefab set), D6 Trap System (all 14 trap prefabs must exist for Room 8/10)
- **Blocks**: 006-room-content-tests (integration tests verify all 10 rooms)

## Engine Notes

Pure Inspector authoring task -- no code written. Same authoring workflow as story 003 but with more complex wave compositions and trap layouts. Room 10 has the most complex `WaveDefinition` list (6 waves with alternating archetype patterns); verify Inspector UX handles this depth of nested data cleanly in Unity 6000.3.11f1. Consider using Inspector debug mode for verification of large nested lists.
