# Story: Room Layout & Spawn Points

> **Epic**: room-content
> **Type**: Config
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-room-004 (minimum arena sizes per archetype), TR-room-005 (spawn point minimums: 4 cardinal, Swarm needs 6-8), TR-room-006 (trap coverage max 15%, safe path exists), TR-room-007 (every room has 8-unit kiting lane for Archer)
**ADR Reference**: ADR-0006 -- TrapPlacement stores world-space positions within room's local coordinate frame
**Control Manifest Rules**: G-010 (trap coverage <= 15%), G-011 (max concurrent enemies: ~13 campaign, object pooling required)

## Description

Define the spatial layout rules for all 10 rooms: spawn point positions per archetype, arena dimensions, kiting lane placement, and trap zone boundaries. This story bridges the gap between the `RoomConfig` data (what spawns) and the physical room scenes (where it spawns). Spawn points and layout constraints are critical for both class balance (Archer kiting) and gameplay feel (Swarm flooding vs Ambush flanking).

**Work items:**

1. **Spawn point definitions per archetype:**
   - **Swarm rooms (1, 6)**: 6-8 spawn points distributed around the perimeter for wave flooding. No clustering -- enemies should approach from all directions.
   - **Ambush rooms (2, 7)**: 4-6 spawn points at flanking positions (behind obstacles, side corridors). Not visible from room center -- enemies should "surprise" the player.
   - **Gauntlet rooms (3, 8)**: 4 spawn points ahead of the player along the corridor. Enemies spawn in the path, not behind. Plus 2 side-spawn points for variety in later waves.
   - **Arena rooms (4, 9)**: 4 spawn points at cardinal directions (boss entrance points). Boss spawns from one primary point; minions from remaining 3.
   - **Hybrid rooms (5, 10)**: 6-8 spawn points combining Swarm and Ambush positions. Room 10 needs maximum coverage for its all-archetype waves.

2. **Arena dimension verification:**
   - Swarm/Ambush rooms: minimum 20x20 units
   - Gauntlet corridors: minimum 30x20 units (length x width)
   - Arena boss rooms: minimum 25x25 units
   - Room 10 (all archetypes): at least 30x30 units to support all wave patterns

3. **Kiting lane placement (TR-room-007):**
   - Every room must have at least one 8-unit clear lane (no obstacles, no traps)
   - Kiting lanes must connect to at least 2 edges of the room (not dead-ends)
   - Swarm rooms: 2 kiting lanes (perpendicular) to handle wave flooding
   - Gauntlet corridors: the corridor width (minimum 4 units per GDD Edge Case 4) IS the kiting lane
   - Arena rooms: perimeter lane around the arena edge

4. **Trap zone constraints:**
   - Traps must NOT be placed in kiting lanes
   - Traps must NOT block all paths between any two spawn points
   - At least one safe path exists through any trap layout (TR-room-006)
   - Gauntlet corridors: traps along edges, center path remains passable (minimum 4-unit width for Dodge Roll per Edge Case 4)

5. **Documentation:** Create a room layout reference document at `design/gdd/room-layouts.md` (or within `room-content.md`) that maps each room's spawn point positions, kiting lane locations, and trap zone boundaries. This serves as the authoring guide for placing `TrapPlacement` positions in stories 003/004.

**Key constraints:**
- Spawn points are scene-level data (Transform positions in the room scene), not stored on `RoomConfig` -- `SpawnManager` reads them from the scene
- `TrapPlacement.Position` values in `RoomConfig` must align with the physical room layout
- Kiting lane width of 8 units is a hard minimum (GDD Tuning Knob safe range: 5-12 units)
- Both Mage and Archer must be viable in every room -- no room should be trivial or impossible for either class

## Acceptance Criteria

- [ ] Spawn point positions defined for all 10 rooms following archetype rules
- [ ] Swarm rooms have 6-8 spawn points; Ambush rooms have 4-6; Gauntlet 4-6; Arena 4; Hybrid 6-8 (TR-room-005)
- [ ] All room arenas meet minimum size requirements: 20x20 (Swarm/Ambush), 30x20 (Gauntlet), 25x25 (Arena) (TR-room-004)
- [ ] Every room has at least one 8-unit clear kiting lane connecting to 2+ room edges (TR-room-007)
- [ ] No traps placed within kiting lanes
- [ ] At least one safe path exists through every room's trap layout (TR-room-006)
- [ ] Gauntlet corridors are at least 4 units wide at all points (GDD Edge Case 4: Dodge Roll clearance)
- [ ] Spawn points are placed as Transforms in the room scenes
- [ ] `TrapPlacement.Position` values in RoomConfig assets align with physical room geometry
- [ ] Room layout reference document created with spawn point maps and kiting lane diagrams
- [ ] GDD AC 5: "Walk Archer through each room -- at least one 8-unit clear lane exists for kiting"

## Test Evidence

**Type**: Manual Walkthrough
**Path**: `production/qa/evidence/`

- Manual walkthrough: In each room, walk Archer through the kiting lane. Verify 8+ unit clearance with no obstructions.
- Manual walkthrough: Verify spawn points are at expected positions per archetype (Swarm: perimeter flooding, Ambush: flanking, etc.)
- Manual walkthrough: Verify at least one safe path exists through trap layouts (no forced trap damage paths)
- Manual walkthrough: Verify Gauntlet corridor width >= 4 units at narrowest point
- Screenshot evidence: Capture top-down view of each room showing spawn points (marked), kiting lanes (highlighted), and trap zones (outlined)

## Dependencies

- **Blocked by**: 001-roomconfig-scriptableobject (TrapPlacement type needed for position authoring), 003-rooms-1-5-configuration (rooms 1-5 config needed for trap position alignment), Room scenes (physical rooms must exist in Unity -- may be blocked by level art)
- **Blocks**: 006-room-content-tests (layout verification is part of integration testing)

## Engine Notes

Spawn points are Unity `Transform` components placed as child GameObjects in the room scene hierarchy -- standard Unity pattern. `TrapPlacement.Position` uses `Vector3` in the room's local coordinate frame, so room rotation/repositioning automatically adjusts trap world positions. Verify local-to-world coordinate conversion works correctly when rooms are loaded in Unity 6000.3.11f1. No post-cutoff API dependencies.
