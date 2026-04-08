# Story: Endless Arena Setup

> **Epic**: endless-mode
> **Type**: Config
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-endless-008 (single 30x30 unit arena, Arena archetype, no traps, 6 spawn points)
**ADR Reference**: ADR-0007 -- Migration Plan step 6 (create Endless arena scene: 30x30, 6 EnemySpawnPoint transforms, no trap prefabs, reuses Arena lighting); Decision section (arena is a scene-level decision)
**Control Manifest Rules**: G-014 (PC and Mobile share gameplay code; platform divergence in Scenes/PC/ and Scenes/Mobile/ only), G-015 (mobile enemy count cap in platform config, not in wave provider)

## Description

Create the Endless Mode arena scene -- a single open arena used for all Endless runs. This is a scene-level authoring task, not a code task.

**Scene to create:**

**`EndlessArena.unity`** (or appropriate scene name per project conventions) in the Scenes directory:

1. **Arena dimensions**: 30x30 units, matching the Arena archetype from E1 Room Content. Use the same floor/wall prefabs and tileset as the campaign Arena archetype for visual consistency.

2. **Spawn points**: Place 6 `EnemySpawnPoint` transforms at the hexagonal directions (N, NE, SE, S, SW, NW) around the arena perimeter. Spawn points should be positioned at the arena edges, inside the navigable area.

3. **No traps**: Zero trap prefabs placed. `EndlessWaveProvider.GetTrapLayout()` returns null and the arena scene itself has no trap geometry.

4. **No obstacles**: Pure open space for kiting and positioning (GDD: "No obstacles -- pure open space for kiting and positioning").

5. **Lighting**: Consistent lighting, no per-wave visual changes. Reuse the Arena archetype lighting setup from campaign.

6. **Player spawn**: Central player spawn point.

7. **Scene components**: Place `EndlessSessionController`, `EndlessWaveProvider`, and `EndlessDifficultyProvider` MonoBehaviours in the scene hierarchy (on GameManager child or dedicated EndlessManager object). Wire all Inspector references.

**Key constraints:**
- The arena is always the same layout -- no procedural variation (simplicity for v1.0)
- Mobile performance concern: 19+ enemies at wave 30 in this arena must stay within frame budget (G-001). Performance caps are in platform config, not in the scene.

## Acceptance Criteria

- [ ] Endless arena scene exists with 30x30 unit navigable area
- [ ] 6 `EnemySpawnPoint` transforms placed at hexagonal positions around the perimeter
- [ ] No trap prefabs or trap geometry in the scene
- [ ] No obstacle geometry -- open arena floor only
- [ ] Player spawn point at arena center
- [ ] `EndlessSessionController` MonoBehaviour placed in scene with Inspector references wired
- [ ] `EndlessWaveProvider` MonoBehaviour placed in scene with `EndlessWaveConfig` SO assigned
- [ ] `EndlessDifficultyProvider` MonoBehaviour placed in scene with `EndlessDifficultyConfig` SO assigned
- [ ] Arena uses Arena archetype lighting (consistent, no per-wave changes)
- [ ] Scene loads successfully from main menu Endless Mode entry

## Test Evidence

**Type**: Manual Walkthrough
**Path**: `production/qa/evidence/`

- Visual verification: screenshot showing 30x30 arena with all 6 spawn point gizmos visible
- Manual test: Enter Endless Mode from main menu, verify arena loads and wave 1 spawns correctly
- Spot check: Verify no trap geometry appears during gameplay

## Dependencies

- **Blocked by**: 001-endless-difficulty-provider, 002-endless-wave-provider, 003-endless-session-controller (MonoBehaviours must exist to place in scene)
- **Blocks**: 008-endless-mode-tests (integration tests need the arena scene)

## Engine Notes

Scene authoring in Unity 6000.3.11f1. Uses standard scene hierarchy, Transform placement, and MonoBehaviour component wiring. No post-cutoff APIs. The 6 spawn point placement mirrors the Swarm archetype pattern (which uses 6-8 spawn points per TR-room-005) but in a larger 30x30 arena.
