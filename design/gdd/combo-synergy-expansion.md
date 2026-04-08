# Combo/Synergy Expansion

> **Status**: In Design
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-04-07
> **System ID**: E4
> **Priority**: P1

## Overview

The Combo/Synergy Expansion transforms skill drafting from "pick good skills" into "build toward devastating combinations." It extends the existing `ComboDatabase` (currently 5 hardcoded Mage-only pairs with no gameplay effect) into a full combo-reward system where discovering specific skill pairings grants named combo bonuses — damage multipliers, unique VFX, or triggered effects that make the whole greater than the sum of its parts. The expansion adds archer-exclusive combos, cross-class universal combos, and a synergy hint system that nudges players toward undiscovered combinations without spelling them out.

Players interact with combos passively through the draft system — they choose skills for their individual value, then discover that certain pairs unlock powerful bonuses. The "I didn't plan this but it's amazing" moment is the core of Pillar 1 (Build-Craft Fantasy). Without this system, skill drafting is linear — more skills = more power. With it, skill drafting is combinatorial — the right two skills together are worth more than three good skills separately.

The system is data-driven: all combo definitions, bonuses, and hint rules live in the `ComboDatabase` ScriptableObject and can be tuned in the Inspector without code changes. v1.0 targets 15-20 total combos across three categories: Mage-exclusive, Archer-exclusive, and Universal (shared skills).

## Player Fantasy

**The Alchemist's Eureka** — the player fantasy isn't raw power; it's the flash of insight when two skills click together into something neither could do alone. It's the roguelite version of "I broke the game" — except you earned it through draft choices, not an exploit. The combo system makes every draft pick a potential ingredient in a recipe the player hasn't discovered yet.

The feeling reference is Slay the Spire's synergy discovery: the moment you realize Barricade + Body Slam creates an infinite scaling loop. In Trizzle, the equivalent is drafting Piercing Arrow and then finding Poison Arrow in the next room — suddenly every arrow poisons a line of enemies. The "Plague Volley" combo name appears on screen, confirming the discovery and rewarding the insight.

**Two distinct emotional beats:**
1. **Discovery** — "Wait, these two work together?" The first time a combo triggers, the player learns something about the system. This is the Explorer's moment.
2. **Exploitation** — "I'm going to build toward that combo every run." Subsequent runs, the player hunts specific skill pairs. This is the Achiever's moment.

The system must serve both beats: surprising the first time, satisfying the tenth.

## Detailed Design

### Core Rules

**Combo Structure (expanded `ComboDefinition`):**
```
ComboDefinition
├── skillA: BaseSkill          (first required skill)
├── skillB: BaseSkill          (second required skill)
├── comboName: string          (localized display name)
├── description: string        (localized effect description)
├── comboCategory: enum        (Mage / Archer / Universal)
├── triggerCondition: enum     (OnDraft / OnSkillUse / OnKill / Passive)
├── triggerEffect: ComboEffect (ScriptableObject — the unique behavior)
└── discoveredFlag: bool       (persisted per-save, tracks first discovery)
```

**Detection Flow:**
1. Player drafts a skill via `DraftRunController`
2. After drafting, `ComboRegistry.CheckCombos()` runs against all drafted skills this run
3. If a new combo pair is found AND not yet discovered this run:
   - Flash combo name on screen (gold text, Cinzel font, center screen, 2s fade)
   - Play combo discovery SFX (distinct from level-up or rarity sounds)
   - Register the combo's `triggerEffect` on the player
   - If first-ever discovery: set `discoveredFlag = true` in save data
4. Combos are active for the remainder of the run. They reset on run end.

**Trigger Conditions:**
| Condition | When Effect Fires | Use For |
|-----------|------------------|---------|
| **OnDraft** | Immediately when combo is discovered | Passive buffs, auras |
| **OnSkillUse** | When either SkillA or SkillB is used | Damage additions, projectile modifications |
| **OnKill** | When the player kills an enemy | Proc-on-kill explosions, chain effects |
| **Passive** | Continuous while both skills are held | Stat modifiers, regeneration |

**Category Rules:**
- **Mage combos**: Both skills are Mage-exclusive or shared. Available only when playing Mage.
- **Archer combos**: Both skills are Archer-exclusive or shared. Available only when playing Archer.
- **Universal combos**: Both skills are shared (available to either class). Same combo may feel different per class due to different base skills.

**No hints, no codex.** Combos are discovered through play only. This is intentional — the discovery moment is the reward. A codex would turn discovery into a checklist. Players who want to track combos can use community wikis.

### Combo Library (v1.0 — 18 total)

**Mage-Exclusive Combos (5 — upgrading from current 5 fallbacks):**

| # | Combo Name | Skill A | Skill B | Trigger | Effect |
|---|-----------|---------|---------|---------|--------|
| 1 | Inferno | FireballSkill | BurnAttackSkill | OnSkillUse | Fireball explosions leave a burning ground patch (3s, ticks Burn damage) |
| 2 | Blizzard | FrostShardSkill | FreezeAttackSkill | OnKill | Killed frozen enemies explode in a frost nova (3-unit radius, applies Slow) |
| 3 | Thunderstrike | LightningBoltSkill | StunAttackSkill | OnSkillUse | Stunned enemies take 2x damage from Lightning attacks |
| 4 | Venom | PoisonCloudSkill | PoisonAttackSkill | Passive | Poison stacks 50% faster (tick interval reduced from 1.0s to 0.67s) |
| 5 | Supernova | SolarFlareSkill | ExplosionAttackSkill | OnKill | Kills have a 25% chance to trigger a secondary explosion (50% original damage, 4-unit radius) |

**Archer-Exclusive Combos (6):**

| # | Combo Name | Skill A | Skill B | Trigger | Effect |
|---|-----------|---------|---------|---------|--------|
| 6 | Plague Volley | PiercingArrow | PoisonArrow | OnSkillUse | Piercing arrows spread Poison to all pierced targets (not just first hit) |
| 7 | Hailstorm | Multishot | FreezeAttackSkill | OnSkillUse | Each multishot arrow has a 30% chance to apply Freeze (vs normal single-target) |
| 8 | Shadow Step | DodgeRollSkill | Afterimage | OnSkillUse | Afterimage decoy now explodes on death for 50% Attack damage in 2-unit radius |
| 9 | Predator's Mark | EagleEye | CounterRoll | Passive | Counter Roll damage bonus increased from 2x to 3x against targets beyond Eagle Eye range threshold |
| 10 | Rapid Assault | Quickdraw | Multishot | OnSkillUse | Quickdraw's attack speed buff also applies to Multishot (all 3 arrows fire faster) |
| 11 | Venomous Hail | PoisonArrow | Multishot | OnSkillUse | All multishot arrows apply Poison (instead of only the center arrow) |

**Universal Combos (7 — shared skills, either class):**

| # | Combo Name | Skill A | Skill B | Trigger | Effect |
|---|-----------|---------|---------|---------|--------|
| 12 | Berserker's Fury | Frenzy | Rampage | Passive | Kill streaks of 5+ grant +10% move speed for 3s (stacks with existing buffs) |
| 13 | Ironclad | Stoneguard | ColdBlood | Passive | When below 30% HP, defense doubled instead of normal Stoneguard bonus |
| 14 | Gold Rush Combo | GoldRush | GemRush | OnKill | Kills have 10% chance to drop a bonus currency bundle (3x normal drop) |
| 15 | Elemental Storm | BurnAttackSkill | FreezeAttackSkill | OnSkillUse | Enemies with both Burn and Freeze active take 30% bonus damage from the next 5 hits, then the bonus resets (requires both statuses to be reapplied) |
| 16 | Vampiric Strikes | BurnAttackSkill | HealthRecover | OnKill | Burn-killed enemies heal player for 5% of their max HP |
| 17 | Gale Force | SwiftWind | Frenzy | Passive | Move speed bonus from SwiftWind also increases attack speed by half the amount |
| 18 | Executioner | Berserk | SlowAttackSkill | OnSkillUse | Slowed enemies below 25% HP are instantly killed (boss-immune) |

### Interactions with Other Systems

**Upstream (reads from):**
- **Skill System (D4)**: Combo detection reads the player's drafted skill list. `UpgradableSkill` framework handles skill references. No changes to the skill framework needed — combos read-only.
- **Roguelite Draft (D7)**: Combo check runs after each draft pick in `DraftRunController`. No changes to draft weighting — combos are not factored into draft odds.
- **Core Combat (D1)**: Triggered effects hook into existing event system: `Health.OnDamaged`, `Health.OnDied`, skill activation events. Each `ComboEffect` is a ScriptableObject that registers listeners.
- **Status Effects (D3)**: Several combos interact with status effects (Burn, Freeze, Poison, Slow, Stun). Combos read status state but do not modify the state machine — they add bonus damage or secondary effects on top.

**Downstream (other systems read from this):**
- **Room Content (E1)**: Room design should consider combo potential — enemy compositions that cluster together reward AoE combos, scattered enemies reward single-target combos.
- **Achievements (N3)**: Combo discovery is an achievement category (e.g., "Discover 10 combos", "Discover all Archer combos").
- **Archer Character (N1)**: Archer GDD references 6 archer-specific combos defined here.

**Code changes required:**
1. Extend `ComboDefinition` with `comboCategory`, `triggerCondition`, `triggerEffect`, `discoveredFlag`
2. Create `ComboEffect` base ScriptableObject with `Activate(PlayerController)` and `Deactivate()`
3. Create 18 `ComboEffect` implementations (many reuse existing damage/status patterns)
4. Extend `ComboRegistry.CheckCombos()` to activate effects on detection
5. Add combo discovery UI (gold text flash, SFX)
6. Extend save data to persist `discoveredFlag` per combo
7. Populate `ComboDatabase.asset` with all 18 combo entries

## Formulas

**Burning Ground DPS (Inferno combo):**
```
tickDamage = burnDamagePerTick  // from BurnState, not recalculated
duration = 3.0s
tickInterval = 0.5s
totalDamage = tickDamage * (duration / tickInterval) = tickDamage * 6
```

**Frost Nova (Blizzard combo):**
```
radius = 3.0 units (fixed)
damage = 0 (applies Slow status only)
```

**Supernova Proc (secondary explosion):**
```
procChance = 0.25
explosionDamage = killingBlow.damage * 0.5
explosionRadius = 4.0 units
Expected extra damage per kill = killingBlow.damage * 0.5 * 0.25 = 12.5% average
```

**Shadow Step Explosion:**
```
explosionDamage = archer.GetAttribute(Attack).CurrentValue * 0.5
explosionRadius = 2.0 units
```

**Elemental Storm Bonus:**
```
bonusDamageMultiplier = 1.30  // 30% more damage from all sources
condition: target.HasStatus(Burn) AND target.HasStatus(Freeze)
```

**Executioner Threshold:**
```
if (target.CurrentHP / target.MaxHP <= 0.25 AND target.HasStatus(Slow) AND !target.isBoss):
    target.Kill()  // instant
```

**Vampiric Strikes Healing:**
```
healAmount = killedEnemy.MaxHealth * 0.05
condition: enemy killed while Burn status active
```

## Edge Cases

1. **Both combo skills drafted in same pick**: Only one draft happens per room. If both SkillA and SkillB are somehow already held when a combo check runs, the combo activates immediately. No special handling needed.
2. **Multiple combos discovered simultaneously**: If drafting one skill completes two combos at once, both activate. Both names flash sequentially (0.5s delay between). Both effects register.
3. **Combo + OneShotKill interaction**: Executioner combo kills bypass OneShotKill boss immunity — but Executioner is ALSO boss-immune (explicit in its definition). No conflict.
4. **Combo effects that modify status effects**: Combos do not modify `StateMachine` states. "Poison stacks 50% faster" reduces tick interval via an `AttributeModifier`, not by changing PoisonState code.
5. **Combo effects on run end**: All `ComboEffect.Deactivate()` called on run end. Effects do not persist between runs. `discoveredFlag` persists in save (tracks lifetime discovery).
6. **Duplicate skills**: A player cannot draft the same skill twice. Combo pairs are always distinct skills. No self-combo possible.
7. **Combo with Incomplete Skill (E5)**: If either skill in a combo pair is one of the E5 incomplete skills still needing prefabs, the combo is silently unavailable until the skill is functional. `CheckCombos()` already handles null skill references.
8. **Frost Nova on non-frozen kill**: Blizzard combo only triggers if the killed enemy had Frozen status at time of death. A frozen enemy that thaws, then dies, does NOT trigger the nova.
9. **Predator's Mark range check**: If Archer is at exactly the Eagle Eye threshold distance, the combo bonus applies (>=, not >).
10. **Hailstorm + Freeze immune enemies**: If an enemy is Freeze-immune, the 30% proc simply fails. No error, no fallback.

## Dependencies

**Hard Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Skill System (D4) | Upstream | `PlayerController.CollectedSkills` list for combo detection. `BaseSkill` references in `ComboDefinition`. |
| Roguelite Draft (D7) | Upstream | `DraftRunController` triggers combo check after each draft. Provides drafted skill names. |
| Core Combat (D1) | Upstream | `Health.OnDied` for OnKill triggers. `DamageCalculator` for bonus damage application. |
| Status Effects (D3) | Upstream | `StateMachine.HasState()` for status-conditional combos. `AttributeModifier` for tick rate changes. |
| Incomplete Skills (E5) | Upstream | Shared skill pool must be complete for all combos to be available. |

**Soft Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Archer Character (N1) | Upstream | Archer-exclusive skills referenced in 6 combos. Combos work without archer — just fewer available. |
| Room Content (E1) | Downstream | Room design considers combo-friendly enemy compositions. Works without. |
| Achievements (N3) | Downstream | Combo discovery triggers achievement events. Works without. |
| Save/Load (D11) | Upstream | `discoveredFlag` persistence. Combos still function without save — just lose lifetime tracking. |

**Owned by this system:** `ComboDefinition` (extended), `ComboEffect` base class, 18 `ComboEffect` implementations, combo discovery UI, `ComboDatabase.asset` population.

## Tuning Knobs

All values are per-combo `SerializeField` properties on `ComboEffect` ScriptableObjects.

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| Burning Ground duration | 3.0s | 1.0–6.0s | Area denial too punishing (friendly fire on player positioning) | Patch disappears before enemies walk through it |
| Frost Nova radius | 3.0 units | 1.5–5.0 | Chain-freezes entire rooms, trivializes density | Only catches 1 enemy, not worth the combo slot |
| Supernova proc chance | 0.25 | 0.10–0.50 | Chain explosions cascade out of control | Rarely procs, feels unrewarding |
| Supernova damage ratio | 0.50 | 0.25–1.00 | Secondary explosion deals more than primary kill | Explosion is negligible |
| Elemental Storm bonus | 0.30 | 0.10–0.50 | Burn+Freeze stack becomes mandatory meta | Bonus too small to notice |
| Executioner threshold | 0.25 | 0.10–0.40 | Instant-kill triggers too often, cheapens boss fights | Enemies die normally before reaching threshold |
| Hailstorm freeze chance | 0.30 | 0.10–0.50 | Multishot freezes everything, trivializes rooms | Barely ever procs with 3 arrows |
| Shadow Step explosion damage | 0.50 | 0.25–1.00 | Decoy becomes a damage tool, not a distraction | Explosion negligible, no reason to combo |
| Vampiric heal percent | 0.05 | 0.02–0.10 | Sustain too easy, removes Archer glass-cannon pressure | Healing negligible |
| Predator's Mark bonus | 3.0x | 2.0–4.0 | One-shots from range, removes challenge | Barely better than base Counter Roll |

## Acceptance Criteria

1. **Combo detected on draft** — Draft PiercingArrow while holding PoisonArrow as Archer. Verify: "Plague Volley" name flashes on screen, combo effect activates.
2. **Combo effect is functional** — Activate Inferno combo (Fireball + BurnAttack). Fire fireball at enemy. Verify: burning ground patch appears at explosion point, ticks damage for 3s.
3. **Multiple combos stack** — Draft 4 skills that form 2 combos. Verify: both combo effects are active simultaneously.
4. **Category filtering works** — As Mage, draft Frenzy + Rampage (Universal). Verify: Berserker's Fury activates. As Mage, verify: Archer-exclusive combos cannot activate (Archer skills not in draft pool).
5. **Combo resets on run end** — Activate a combo, complete/fail the run. Verify: combo effect is deactivated. Start new run — combo is not active until re-drafted.
6. **DiscoveredFlag persists** — Discover a combo for the first time. Quit and reload. Verify: `discoveredFlag` is true for that combo in save data.
7. **Boss immunity on Executioner** — Activate Executioner combo. Slow a boss and get it below 25% HP. Verify: boss is NOT instant-killed.
8. **Frost Nova on frozen kill** — With Blizzard combo, kill a frozen enemy. Verify: frost nova appears at death position, nearby enemies receive Slow. Kill a non-frozen enemy — verify: no frost nova.
9. **18 combos in ComboDatabase** — Verify: ComboDatabase.asset contains exactly 18 entries. All 18 have non-null SkillA, SkillB, and triggerEffect.
10. **No null reference on missing skills** — If a combo references a skill that doesn't exist yet (E5 incomplete), verify: no NullReferenceException. Combo is silently skipped.

## Open Questions

1. **Triple combos**: Should 3-skill combinations exist (SkillA + SkillB + SkillC = mega combo)? Deferred to post-v1.0 — 18 pair combos is enough content. Triple combos would require significant UI and detection changes.
2. **Combo VFX**: Should each combo have unique VFX beyond the discovery flash? Budget concern — 18 unique VFX sets is expensive. Consider shared VFX templates colored by combo category.
3. **Combo discovery notification persistence**: Should the discovery flash show EVERY run when a combo activates, or only the first time ever? Current design: every run (reinforces the "build achieved" moment). Could be configurable.
