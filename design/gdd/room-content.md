# Room Content

> **Status**: In Design
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-04-07
> **System ID**: E1
> **Priority**: P1

## Overview

The Room Content system defines the 10 combat rooms that form the v1.0 campaign, using 4 room archetypes with per-room variation to create 10 distinct encounters without requiring fully unique designs for each. Each room is a self-contained combat arena with wave-based enemy spawns, environmental traps, and a boss encounter. Rooms 1-5 introduce the archetypes on Normal difficulty; rooms 6-10 remix them with harder variants, 3-phase bosses, and new trap combinations. Hard mode applies the Difficulty System's (E2) 5-axis scaling on top of the base room design.

The system is data-driven: each room is defined as a `RoomConfig` ScriptableObject containing wave lists, trap placements, boss assignment, and archetype tag. Room designers author Normal configurations; Hard mode values are derived automatically via `DifficultyConfig` multipliers. The 4 archetypes — **Swarm**, **Ambush**, **Gauntlet**, and **Arena** — each emphasize a different combat rhythm, ensuring both Mage and Archer have rooms that play to their strengths and rooms that test their weaknesses.

## Player Fantasy

**The Proving Ground** — each room is a contained puzzle with teeth. The player enters knowing the archetype ("this is a swarm room — I need AoE") and adapts their drafted build to the encounter. The fantasy isn't surviving — it's mastering. Rooms 1-5 teach the archetypes; rooms 6-10 test whether you truly learned them. Clearing all 10 on Hard with both classes should feel like graduating from a combat school.

## Detailed Design

### Room Archetypes

| Archetype | Combat Rhythm | Player Skill Tested | Mage Advantage | Archer Advantage |
|-----------|--------------|-------------------|----------------|-----------------|
| **Swarm** | Many weak enemies, fast waves, overwhelming numbers | AoE management, positioning, crowd control | AoE splash, burn ground (Inferno combo) | Piercing arrows, Multishot spread |
| **Ambush** | Few strong enemies, staggered spawns from multiple directions | Threat prioritization, spatial awareness | High single-target damage, Blink repositioning | Dodge Roll i-frames, kiting speed |
| **Gauntlet** | Linear progression through trap-heavy corridor into waves | Trap navigation, movement under pressure | Blink through traps (passes walls) | Dodge Roll i-frames through traps |
| **Arena** | Boss encounter with minion phases, large open space | Pattern recognition, phase adaptation, sustained damage | Tank through with burst during transitions | Kite at range, exploit openings |

### Room Assignments

| Room | Archetype | Theme | Boss | Waves (Normal) | Key Trap |
|------|-----------|-------|------|----------------|----------|
| 1 | Swarm | Crypt Entrance | A: Stone Guardian (2-phase) | 4 waves | Fire grates |
| 2 | Ambush | Sorcerer's Chamber | B: Dark Sorcerer (2-phase) | 3 waves | Projectile traps |
| 3 | Gauntlet | Necromancer's Corridor | C: Necromancer (2-phase) | 5 waves | Spike floors + poison vents |
| 4 | Arena | War Hall | D: War Chief (2-phase) | 3 waves | Ground slam zones |
| 5 | Swarm + Ambush | Lich's Antechamber | E: Lich King (2-phase) | 5 waves | Mixed (fire + projectile) |
| 6 | Swarm (remix) | Deep Crypt | A: Stone Guardian (3-phase) | 5 waves | Fire grates + spike floors |
| 7 | Ambush (remix) | Dark Sanctum | B: Dark Sorcerer (3-phase) | 4 waves | Projectile + poison |
| 8 | Gauntlet (remix) | Catacombs | C: Necromancer (3-phase) | 6 waves | All trap types |
| 9 | Arena (remix) | Throne Room | D: War Chief (3-phase) | 4 waves | Ground slam + fire |
| 10 | All archetypes | Lich's Domain | E: Lich King (3-phase) | 6 waves | All trap types + rain of fire |

### Wave Composition Rules

Each wave is defined as a list of `SpawnItemInfo` entries with enemy type, count, and delay.

**Normal baseline per archetype:**
- **Swarm**: 6-10 enemies per wave, mostly regular, 1-2 elites in later waves
- **Ambush**: 2-4 enemies per wave, all elites or mixed regular+elite, spawn from flanking points
- **Gauntlet**: 4-6 enemies per wave, regular, spawning ahead along the corridor
- **Arena**: 0 enemies in wave (boss-only), boss may summon minions via phase abilities

**Progression rules (rooms 1 to 10):**
- Enemy variety increases: Room 1 uses 2 enemy types, Room 10 uses 5+ types
- Elite ratio increases: Room 1 has 10% elites, Room 10 has 40% elites
- Wave count increases: Room 1 has 4 waves, Room 10 has 6 waves
- New enemy types introduced every 2 rooms

**Hard mode (applied automatically via DifficultyConfig):**
- Enemy count: x1.25 (rounded up)
- Enemy stats: x1.2-1.5 (random per enemy)
- Healing drops: x0.5
- Spawn pacing: x0.75 (25% faster waves)
- Rewards: x2.0

### Room Layout Rules

- **Minimum arena size**: 20x20 units (Swarm, Ambush), 30x20 units (Gauntlet corridor), 25x25 units (Arena boss room)
- **Spawn point count**: Minimum 4 per room (one per cardinal direction). Swarm rooms need 6-8 for wave flooding.
- **Trap placement**: Traps occupy no more than 15% of navigable floor area. At least one safe path exists through any trap layout.
- **Line of sight**: Arena rooms have no full-cover obstacles (boss must always be targetable). Swarm/Ambush rooms may have 1-2 waist-height obstacles for partial cover.
- **Kiting space**: Every room has at least one 8-unit clear lane for Archer kiting. Rooms should not be so open that Archer trivializes them, nor so tight that kiting is impossible.

### Interactions with Other Systems

**Upstream (reads from):**
- **Difficulty System (E2)**: `DifficultyConfig` scales all 5 axes. Room design is Normal-only; Hard is derived.
- **Boss Phase System (E3)**: Each room references a `BossController` prefab with configured phases. Rooms 1-5: 2-phase bosses, Rooms 6-10: 3-phase.
- **Combo/Synergy (E4)**: Enemy compositions should reward different combo builds. Swarm rooms reward AoE combos, Ambush rooms reward single-target combos.
- **Archer Character (N1)**: Room layouts must work for both classes. Kiting lanes and open spaces test Archer; enclosed areas test Mage.
- **Trap System (D6)**: 14 existing trap types available for placement. New trap combinations per room.
- **Enemy AI (D5)**: 30 existing enemy controllers. Room configs reference enemy prefabs by type.

**Downstream (other systems read from this):**
- **Endless Mode (N2)**: Endless may reuse room layouts as arena templates. Wave composition patterns inform endless scaling.
- **Achievements (N3)**: Room-specific achievements (e.g., "Clear Room 5 on Hard without taking damage").

## Formulas

**Wave enemy count progression:**
```
baseEnemyCount(room) = 4 + (roomIndex * 0.6)  // Room 1: 4.6->5, Room 10: 10
eliteRatio(room) = 0.10 + (roomIndex * 0.03)  // Room 1: 13%, Room 10: 40%
waveCount(room) = 3 + Ceil(roomIndex / 3)     // Room 1: 4, Room 5: 5, Room 10: 7

For Hard mode:
  hardCount = Ceil(baseCount * 1.25)
  hardEliteRatio = eliteRatio  // elites scale via stats, not count
```

**Room clear time target (Normal, average player):**
```
targetClearTime(room) = 90s + (roomIndex * 15s)
Room 1: ~105s (~1:45)
Room 5: ~165s (~2:45)
Room 10: ~240s (~4:00)
Hard mode adds ~30-50% to clear time due to more enemies and higher stats.
```

**Trap density formula:**
```
trapCoverage = floorArea * 0.15  // max 15% of navigable space
trapCount = Ceil(trapCoverage / averageTrapSize)
Rooms 1-3: 2-4 traps
Rooms 4-7: 4-6 traps
Rooms 8-10: 6-8 traps
```

## Edge Cases

1. **Room with 0 enemies remaining but boss not spawned**: Boss spawns after the final wave is cleared. If all wave enemies die simultaneously, boss spawn triggers on the next frame. No dead time.
2. **Player dies during boss phase transition**: Death takes priority over phase transition. No need to complete the stagger animation.
3. **Trap kills vs enemy kills**: Trap kills do NOT count toward combo OnKill triggers (traps are environment, not player). Trap kills DO count toward wave completion.
4. **Archer in tight Gauntlet corridors**: Gauntlet corridors must be at least 4 units wide (Dodge Roll distance is 2 units, needs room on both sides). Archer should feel pressured but not trapped.
5. **Room 10 (all archetypes)**: Waves alternate between Swarm, Ambush, and Gauntlet patterns. Boss arena phase at the end. This is the "final exam" room.
6. **Hard mode + 3-phase boss**: Hard mode stat scaling applies to the boss. Phase thresholds are HP-percentage, so they scale automatically. No double-scaling.
7. **Room replay after clearing**: Rooms are replayable. Enemy compositions, trap placements, and boss configs are identical each replay (no randomization). Mastery comes from player skill improvement, not RNG.
8. **Both classes must clear Room 1 Normal**: This is the Archer unlock gate (if gated). Room 1 must be clearable by Mage (existing) before Archer is available.

## Dependencies

**Hard Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Difficulty System (E2) | Upstream | `DifficultyConfig` scales all 5 axes. Room config is Normal baseline. |
| Boss Phase System (E3) | Upstream | Each room references a `BossController` prefab. Boss assignment per room. |
| Enemy AI (D5) | Upstream | 30 enemy controllers. Room wave lists reference enemy prefabs. |
| Trap System (D6) | Upstream | 14 trap types. Room configs place traps by type + position. |
| Core Combat (D1) | Upstream | `SpawnManager` handles wave spawning. `DamageCalculator` processes combat. |

**Soft Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Combo/Synergy (E4) | Upstream | Room enemy compositions should reward combo builds. Not required. |
| Archer Character (N1) | Upstream | Room layouts must work for both classes. Works without — just less balanced. |
| Endless Mode (N2) | Downstream | May reuse room arenas as templates. |
| Achievements (N3) | Downstream | Room-specific achievement triggers. |

**Owned by this system:** 10 `RoomConfig` ScriptableObjects, wave composition data, trap placement data, spawn point layouts, room archetype definitions.

## Tuning Knobs

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| Waves per room (early) | 4 | 3-6 | Room drags, pacing feels slow | Over too fast, no build-up |
| Waves per room (late) | 6 | 4-8 | Exhausting, session too long | Final rooms feel anticlimatic |
| Enemies per Swarm wave | 8 | 5-15 | Screen floods, performance risk on mobile | Swarm doesn't feel swarmy |
| Enemies per Ambush wave | 3 | 2-5 | Ambush becomes a swarm | No flanking pressure |
| Elite ratio (Room 10) | 0.40 | 0.20-0.60 | Most enemies are elites, regular enemies feel pointless | Room 10 doesn't feel harder than Room 5 |
| Trap coverage | 15% | 5%-25% | Navigation feels unfair, especially on mobile | Traps are ignorable |
| Room clear time (Room 1) | 105s | 60-180s | First room is a wall for new players | First room teaches nothing |
| Room clear time (Room 10) | 240s | 120-360s | Session too long per run | Final room doesn't feel climactic |
| Kiting lane width | 8 units | 5-12 | Archer trivializes rooms | Archer can't kite, forced to play like Mage |

## Acceptance Criteria

1. **10 rooms exist and load** — Each room (1-10) loads from its `RoomConfig` ScriptableObject. No null references on enemies, traps, or bosses.
2. **4 archetypes represented** — Rooms 1/6 (Swarm), 2/7 (Ambush), 3/8 (Gauntlet), 4/9 (Arena) match their archetype wave patterns. Room 5/10 are hybrid.
3. **Boss assignment matches E3 GDD** — Room 1 has Boss A, Room 2 has Boss B, through Room 5 has Boss E. Rooms 6-10 repeat bosses with 3 phases.
4. **Hard mode scales automatically** — Play Room 1 Normal then Room 1 Hard. Verify: more enemies, faster waves, less healing, double rewards, stronger stats. No room-specific Hard authoring needed.
5. **Kiting lane exists in every room** — Walk Archer through each room. At least one 8-unit clear lane exists for kiting in every room.
6. **Trap coverage under 15%** — Measure trap footprint vs floor area. No room exceeds 15% trap coverage.
7. **Clear time within budget** — Average player clears Room 1 Normal in 90-120s, Room 10 Normal in 200-300s.
8. **Both classes clear Room 1** — Playtest Room 1 as Mage and Archer. Both clear on Normal within 20% clear time of each other.
9. **Wave progression feels escalating** — Room 5 feels harder than Room 1. Room 10 feels hardest. Verify via enemy count, variety, and elite ratio.
10. **Room replay is deterministic** — Clear Room 3, replay Room 3. Same enemy types, same spawn points, same traps. No randomization between replays.

## Open Questions

1. **Room visual themes**: Should each room have a distinct visual theme (crypt, sanctum, throne room), or share a single dungeon tileset with lighting variation? Budget concern for solo dev.
2. **Room select screen**: How does the player choose rooms? Linear progression (must clear 1 to unlock 2)? Or hub with branching paths? Linear is simpler to implement.
3. **Room-specific modifiers**: Should any rooms have unique rules beyond the archetype (e.g., "no healing drops in Room 7", "double trap damage in Room 8")? Could add variety but also complexity.
4. **Miniboss waves**: Should non-Arena rooms have a "mini-boss" wave (an elite with enhanced abilities) before the final boss? Could bridge difficulty between regular waves and boss.
