# Boss Phase System

> **Status**: In Design
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-03-29
> **System ID**: E3
> **Priority**: P1

## Overview

The Boss Phase System adds multi-phase behavior to boss enemies, making them shift abilities at HP thresholds. Currently bosses are regular enemies with no distinct behavior — this system formally classifies them via a `BossController` subclass and gives each boss 2-3 phases with unique attack patterns. 5 unique bosses cover the 10 rooms (each appearing twice with phase variation on Hard). Early bosses (rooms 1-5) have 2 phases; late bosses (rooms 6-10) have 3 phases, escalating complexity as the player progresses. Phase transitions include a brief stagger animation + visual cue so players can read the shift. The system reuses the `GuardianPhase` health-threshold pattern and the custom BehaviourTree override pattern from `DragonEnemyController`.

## Player Fantasy

Each boss is a "puzzle with teeth." Phase 1 teaches the boss's patterns — predictable, learnable. Phase 2 (and 3 for late bosses) breaks those patterns, forcing adaptation. The moment the boss staggers and shifts should feel like a cinematic beat — "oh no, it's getting serious." Defeating a boss should feel like outsmarting it, not just out-DPSing it. The archer kites and exploits openings between phases; the mage tanks through with burst damage during transitions.

**Reference feel:** Hades boss phase shifts (Megaera's rage, Theseus calling Asterius), Hollow Knight's boss escalation, Dead Cells' elite enemy tells.

## Detailed Design

### Phase Transition Rules

**BossController : EnemyController**

A new subclass that adds phase monitoring on top of the existing enemy system.

**Phase Definition:**
```
BossPhase
├── healthThreshold: float     (0.0-1.0, percentage of max HP to trigger)
├── behaviourTree: BTNode      (the AI tree for this phase)
├── transitionVFX: GameObject  (visual effect on transition)
├── statModifiers: float[]     (optional per-phase stat multipliers, e.g., +20% speed in enrage)
└── hasTriggered: bool         (one-way flag, phases never reverse)
```

**Transition Rules:**
1. `BossController.Update()` checks HP after each damage event (not every frame)
2. Phases are checked in order from lowest threshold to highest (Phase 3 at 30% checked before Phase 2 at 60%) — if boss takes a massive hit that skips a threshold, all skipped phases trigger in sequence
3. On threshold crossed: boss enters a **stagger state** (0.5s invulnerable, plays transition animation)
4. During stagger: swap the active BehaviourTree to the new phase's tree, apply stat modifiers
5. After stagger: boss resumes with new AI pattern
6. Phases are one-way — healing a boss (if applicable) does NOT reverse a phase
7. Phase transitions are exempt from status effects — stagger clears all debuffs (Frozen, Stun, etc.)

**2-Phase Bosses (Rooms 1-5):**
- Phase 1: 100% - 50% HP (normal patterns)
- Phase 2: 50% - 0% HP (enraged/new ability)

**3-Phase Bosses (Rooms 6-10):**
- Phase 1: 100% - 60% HP (normal patterns)
- Phase 2: 60% - 30% HP (new ability added)
- Phase 3: 30% - 0% HP (desperate/enraged, all abilities)

### Phase Ability Templates

Boss phases draw from a library of **ability templates**. Each boss combines 2-4 templates across its phases, creating unique encounters without needing fully custom code per boss.

**Attack Templates:**

| Template | Type | Description | Implementation |
|----------|------|-------------|----------------|
| **Melee Combo** | Melee | 2-3 hit combo with increasing range per swing | Existing `MeleeWeaponHandler` + animation sequence |
| **Projectile Burst** | Ranged | Fire 3-5 projectiles in a spread pattern | Existing projectile system, multiple `SpellProjectile` spawns |
| **Ground Slam** | AoE | Slam ground, shockwave expanding outward. Telegraphed with 0.8s windup | New: radial damage zone from boss position |
| **Charge** | Movement | Dash toward player, damage on contact. Telegraphed with 0.5s windup + line indicator | New: momentum-based movement on `EnemyController` |
| **Summon Minions** | Summon | Spawn 2-4 regular enemies. Reuse existing `SpawnManager` | Existing: call `SpawnManager.SpawnEnemies()` with a mini wave list |
| **Enrage Aura** | Buff | Boss gains +30% attack speed, +20% move speed. Visual: red glow | Existing: `AttributeModifier` on boss's own stats |
| **Shield Phase** | Defense | Boss spawns a shield (takes N hits to break). Boss doesn't attack during shield but minions do. | New: temporary invulnerability + hit counter |
| **Rain of Fire** | AoE | Random AoE circles appear on ground (1s telegraph), then explode for damage | New: spawned area hazards similar to trap system |

**Per-Boss Template Assignment (high-level, detailed in Room Content E1):**

| Boss | Rooms | Phase 1 | Phase 2 | Phase 3 |
|------|-------|---------|---------|---------|
| Boss A (early melee) | 1, 6 | Melee Combo | + Charge, Enrage Aura | (Room 6: + Summon Minions) |
| Boss B (early ranged) | 2, 7 | Projectile Burst | + Ground Slam | (Room 7: + Rain of Fire) |
| Boss C (mid summoner) | 3, 8 | Projectile Burst, Summon Minions | + Shield Phase | (Room 8: + Enrage Aura) |
| Boss D (late tank) | 4, 9 | Melee Combo, Ground Slam | + Charge, Enrage Aura | (Room 9: + Summon Minions, Rain of Fire) |
| Boss E (final) | 5, 10 | All ranged + melee mix | + Summon + Shield | (Room 10: + Enrage + Rain of Fire) |

**Hard mode variant**: When a boss appears in its second room (6-10), it gets 3 phases instead of 2, plus the difficulty system's stat/count/pacing multipliers on top.

### Per-Boss Design

Detailed boss encounters are defined in Room Content (E1). This section establishes the **identity and archetype** of each boss.

| Boss | Name (WIP) | Archetype | Visual | Signature Move |
|------|-----------|-----------|--------|----------------|
| A | Stone Guardian | Melee Bruiser | Heavy armored golem, slow but powerful | Charge — telegraphed dash across the room, leaves rubble |
| B | Dark Sorcerer | Ranged Caster | Robed mage with staff, hovers | Rain of Fire — AoE denial forces constant repositioning |
| C | Necromancer | Summoner | Skeletal figure with glowing eyes | Summon Minions — overwhelming numbers if not DPS'd quickly |
| D | War Chief | Hybrid Tank | Large armored warrior with greataxe | Ground Slam — room-wide shockwave, must dodge or take massive damage |
| E | Lich King | All-rounder | Floating undead king, ornate dark armor | Shield Phase — summons minions while invulnerable, tests player's ability to multitask |

Boss names and visuals are placeholder — art and narrative teams finalize these. The mechanical identity (archetype + signature move) is the contract this GDD establishes.

### Interactions with Other Systems

**Upstream (reads from):**
- **Core Combat (D1)**: Bosses use `DamageCalculator`, `Health`, weapons. Phase check hooks into `Health.OnDamaged` event.
- **Enemy AI (D5)**: `BossController` overrides `BuildTreeForThisEnemy()` to return phase-specific BehaviourTrees. Swaps active tree on phase transition.
- **Difficulty System (E2)**: Boss stats scale via `DifficultyConfig`. Boss is exempt from `enemyCountMultiplier` (edge case #3 in difficulty GDD). Stat multipliers still apply.
- **Status Effects (D3)**: Phase transition clears all debuffs via `StateMachine.ResetState()`. Bosses can apply status effects to the player (Burn from Rain of Fire, Slow from Ground Slam).
- **Trap System (D6)**: Rain of Fire template spawns temporary AoE hazards — reuses trap damage pattern.

**Downstream (other systems read from this):**
- **Room Content (E1)**: Each room's boss encounter references a `BossController` prefab with configured phases. Room design doc specifies which boss + which phase config.
- **Endless Mode (N2)**: Endless mode may introduce boss waves at intervals (e.g., every 10 waves). Uses the same `BossController` with scaling phase thresholds.
- **Achievements (N3)**: Boss-specific achievements (e.g., "Defeat Lich King without taking damage", "Kill a boss in Phase 1 before Phase 2 triggers").

**Code changes required:**
1. Create `BossController : EnemyController` with `List<BossPhase>` and phase monitoring
2. Add `isBoss` flag to `EnemyData` (replaces tag-based detection)
3. Fix `DraftRunController.OnRunComplete()` — detect actual boss kill instead of hardcoding `true`
4. Implement 4 new ability templates: Ground Slam, Charge, Shield Phase, Rain of Fire
5. Create stagger animation + transition VFX
6. Update `OneShotKillEffect` to use `EnemyData.isBoss` instead of tag/name check

## Formulas

**Phase Threshold Check:**
```
currentHPPercent = health.CurrentHealth / health.MaxHealth
for each phase in phases (sorted by threshold ascending):
    if (!phase.hasTriggered && currentHPPercent <= phase.healthThreshold):
        TriggerPhaseTransition(phase)
        phase.hasTriggered = true
```

**Stagger Duration:**
```
staggerDuration = 0.5s (fixed, not affected by difficulty)
During stagger: boss.isInvulnerable = true
```

**Enrage Aura Stat Modifiers:**
```
enragedAttackSpeed = baseAttackInterval * 0.7  (30% faster attacks)
enragedMoveSpeed = baseMoveSpeed * 1.2         (20% faster movement)
```

**Summon Minion Count (scales with difficulty):**
```
minionCount = baseMinionCount  // Hard mode does NOT multiply boss minion count
                               // (boss is exempt from enemyCountMultiplier)
                               // but minion stats DO scale via difficulty
```

**Shield Phase Hit Counter:**
```
shieldHits = baseShieldHits + (phaseIndex * 2)
Boss A (phase 2): 4 hits to break
Boss E (phase 3): 8 hits to break
Each hit plays a crack VFX. Shield breaking plays shatter VFX.
```

**Boss HP Scaling (from Difficulty System):**
```
Normal: bossHP = baseHP * Random.Range(1.0, 1.2)
Hard:   bossHP = baseHP * Random.Range(1.2, 1.5)
Phase thresholds are percentage-based, so they scale automatically.
```

## Edge Cases

1. **One-shot past multiple thresholds**: Boss at 70% HP takes a hit for 50% max HP → drops to 20%. Both Phase 2 (60%) and Phase 3 (30%) trigger in sequence. Each gets its 0.5s stagger. Total stagger: 1.0s. Both phases' stat modifiers stack.
2. **Boss killed during stagger**: If boss HP reaches 0 during a phase transition stagger, boss dies immediately. Skip remaining phase transitions. Death takes priority.
3. **Status effects during stagger**: Stagger clears all existing debuffs. New debuffs applied during the 0.5s invulnerability are ignored (boss is invulnerable).
4. **Summoned minions outlive boss**: If boss dies while summoned minions are alive, minions persist until killed. Room does NOT clear until all enemies (boss + minions) are dead.
5. **Shield phase + status effects**: While shield is active, boss is invulnerable to damage but NOT to status effects. Freeze/Stun can still affect the boss during shield (giving the player a window to clear minions).
6. **Archer rapid fire vs shield**: Each arrow hit counts as 1 shield hit regardless of damage. Archer's faster fire rate breaks shields faster than mage — intentional, rewards rapid-fire builds.
7. **OneShotKill effect vs boss**: Remains blocked. `EnemyData.isBoss = true` prevents instant kill effects.
8. **Boss in Endless Mode**: If Endless Mode includes boss waves, boss HP and phase thresholds scale with the endless wave multiplier, not the room difficulty system. Details in Endless Mode GDD (N2).
9. **Multiple bosses in one room**: Not supported in v1.0. Each room has exactly 1 boss. If needed later, `BossController` is per-entity and would work independently.
10. **Boss kill tracking**: `SpawnManager` detects when a `BossController` entity dies and sets `bossKilled = true` on `DraftRunController`. Replaces the current hardcoded `true`.

## Dependencies

**Hard Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Core Combat (D1) | Upstream | `Health.OnDamaged` event triggers phase checks. `DamageCalculator` handles boss damage. |
| Enemy AI (D5) | Upstream | `BuildTreeForThisEnemy()` override. Per-phase BehaviourTree swapping. |
| Difficulty System (E2) | Upstream | `DifficultyConfig` scales boss stats. Boss exempt from count multiplier. |
| Status Effects (D3) | Upstream | `StateMachine.ResetState()` on phase transition. Bosses apply status effects via ability templates. |

**Soft Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Trap System (D6) | Upstream | Rain of Fire reuses trap damage pattern. Works without — can use direct damage zones instead. |
| Room Content (E1) | Downstream | Rooms reference `BossController` prefabs. |
| Endless Mode (N2) | Downstream | May spawn bosses at wave intervals. |
| Achievements (N3) | Downstream | Boss-specific achievement triggers. |

**Owned by this system:** `BossController`, `BossPhase` data struct, 4 new ability templates (Ground Slam, Charge, Shield Phase, Rain of Fire), stagger state, `EnemyData.isBoss` flag.

## Tuning Knobs

All values are per-boss `SerializeField` properties on `BossController` and per-template properties on ability ScriptableObjects.

**Phase System:**

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| Phase 2 threshold (2-phase) | 0.50 | 0.3 – 0.7 | Phase 2 too brief, player barely sees it | Phase 1 too short, doesn't teach patterns |
| Phase 2 threshold (3-phase) | 0.60 | 0.4 – 0.8 | Phase 2 triggers late, Phase 3 too brief | Phase 1 too short |
| Phase 3 threshold (3-phase) | 0.30 | 0.15 – 0.5 | Long desperate phase, may feel tedious | Phase 3 barely exists, anticlimactic |
| Stagger duration | 0.5s | 0.2 – 1.0s | Too long, breaks combat flow | Too short, player can't read the transition |

**Ability Templates:**

| Knob | Default | Safe Range | Notes |
|------|---------|------------|-------|
| Ground Slam telegraph | 0.8s | 0.5 – 1.5s | Shorter = harder to dodge. Must be readable. |
| Ground Slam radius | 5 units | 3 – 8 | Larger = must dodge further. Scales with room size. |
| Charge telegraph | 0.5s | 0.3 – 1.0s | Line indicator shows charge path. |
| Charge distance | 8 units | 5 – 12 | Room-dependent. Must not clip through walls. |
| Summon count | 2-4 | 1 – 6 | More = harder. Too many overwhelms the player. |
| Enrage attack speed boost | 0.30 | 0.1 – 0.5 | Higher = more dangerous. Above 0.5 may feel unfair. |
| Enrage move speed boost | 0.20 | 0.1 – 0.4 | Higher = harder to kite. Critical for archer balance. |
| Shield hit count | 4-8 | 2 – 12 | Archer breaks faster (rapid fire). Balance between classes. |
| Rain of Fire circle count | 3-5 | 2 – 8 | More = less safe space. Must leave at least 1 safe zone. |
| Rain of Fire telegraph | 1.0s | 0.5 – 2.0s | Red circles on ground before explosion. |

## Acceptance Criteria

1. **BossController exists and extends EnemyController** — Boss prefabs use `BossController` with configurable `List<BossPhase>` in Inspector.
2. **Phase transition triggers at HP threshold** — Damage Boss A to 50% HP. Verify: stagger animation plays, AI pattern changes, stat modifiers apply.
3. **Multi-threshold skip works** — Deal 80% max HP in one hit to a 3-phase boss. Verify: both Phase 2 and Phase 3 trigger in sequence (1.0s total stagger).
4. **Stagger grants invulnerability** — During 0.5s stagger, hit boss with fireball. Verify: 0 damage dealt.
5. **Stagger clears debuffs** — Freeze boss, then trigger phase transition. Verify: Frozen state is removed on stagger.
6. **Summoned minions persist after boss death** — Kill boss while 2 minions alive. Verify: room does NOT complete until minions are killed.
7. **Shield blocks damage but not status effects** — During Shield Phase, hit boss with freeze attack. Verify: shield takes a hit count, boss takes 0 damage, Frozen state IS applied.
8. **Boss exempt from count multiplier** — Play Room 1 on Hard. Verify: 1 boss spawns (not 2). Boss stats do scale.
9. **Boss kill tracking fixed** — Kill boss, verify `DraftRunController.OnRunComplete()` receives `bossKilled = true`. Die before boss, verify `bossKilled = false`.
10. **`EnemyData.isBoss` flag works** — Set `isBoss = true` on boss EnemyData. Verify: `OneShotKillEffect` is blocked. No more tag/name string checking.
11. **5 unique bosses playable** — All 5 bosses load, fight, transition phases, and die correctly across rooms 1-10.

## Open Questions

1. **Boss health bars**: Should bosses have a distinct UI health bar (top of screen, named, phase indicators) vs the standard enemy health bar? UX impact is significant.
2. **Boss music**: Should phase transitions trigger a music change (e.g., more intense track in Phase 2+)? Audio team input needed.
3. **DragonEnemyController migration**: Existing Dragon has custom attacks. Migrate to `BossController` with phases, or keep as a separate implementation? Recommend migration to avoid two boss patterns.
4. **Boss loot**: Should bosses drop guaranteed rewards (rare skills, materials)? Currently drops use the generic loot system. Ties into Room Content (E1) design.
