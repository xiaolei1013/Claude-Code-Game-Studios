# Archer Character

> **Status**: In Design
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-03-29
> **System ID**: N1
> **Priority**: P1

## Overview

The Archer is the second playable character, offering a faster, squishier alternative to the Mage. It extends `PlayerController` with `PlayerClassType.Archer` and uses the same skill collection, draft, and combo systems. Its two unique base skills are **Arrow Shot** (fast single-target projectile — higher fire rate, lower per-hit damage than Fireball) and **Dodge Roll** (short-range sidestep with brief invincibility frames — more reactive than Mage's teleport Blink). The archer rewards constant movement and kiting: higher base move speed and attack range, lower HP pool. The skill pool is partially shared with the Mage — universal passives and upgrades work for both, but each class also has exclusive skills that fit their fantasy. Arrow-specific upgrades favor rapid-fire and piercing builds; dodge upgrades favor aggressive hit-and-run plays.

## Player Fantasy

**The Swift Hunter** — the archer fantasy is about speed, precision, and never standing still. Where the mage plants and casts, the archer flows — shooting on the move, rolling through danger, picking enemies apart from range. Getting hit feels like a mistake the player made (they're fast enough to avoid it), not bad luck. The power fantasy isn't raw destruction — it's "I cleared the room without getting touched."

**Reference feel:** Dodge-roll archer in Hades (Coronacht bow), the kiting rhythm of Vampire Survivors at high speed, Dead Cells' fast combat pacing.

## Detailed Design

### Base Skills

**Arrow Shot** (`ArrowShotSkill : UpgradableSkill`)
- Type: Active (defaultActiveHitSkill)
- Projectile-based, single target, auto-aims at nearest enemy (same targeting as FireballSkill)
- Faster fire rate, lower damage: shorter cooldown than Fireball, lower base damage per hit
- Projectile travels faster than Fireball (feels snappy)
- Uses the same UpgradableSkill framework — receives upgrades via effects
- Casts to `PlayerController` (not MagePlayerController) so it's class-agnostic

Comparison to Fireball:

| Property | Fireball | Arrow Shot |
|----------|----------|------------|
| Cooldown | ~1.0s | ~0.5s |
| Damage multiplier | 1.0x Attack | 0.6x Attack |
| Projectile speed | 10 | 18 |
| DPS ratio | 1.0x/s | 1.2x/s |
| AoE | Small splash (via upgrades) | None (single target, piercing via upgrades) |

**Dodge Roll** (`DodgeRollSkill : UpgradableSkill`)
- Type: Active (defaultActiveRunSkill)
- Short directional roll in movement direction (not facing direction like Blink)
- Invincibility frames: 0.2s i-frames during the roll (player cannot take damage)
- Shorter distance than Blink but faster recovery
- Does NOT pass through walls (unlike Blink which teleports through obstacles)
- Uses AdvancedWalkerController momentum (same pattern as DashSkill)

Comparison to Blink:

| Property | Blink (Mage) | Dodge Roll (Archer) |
|----------|-------------|---------------------|
| Distance | 3.0 units | 2.0 units |
| Cooldown | ~2.0s | ~1.5s |
| I-frames | None | 0.2s |
| Passes walls | Yes | No |
| Direction | Forward (facing) | Movement direction (input) |
| Animation | Teleport VFX | Roll animation |

### Stats & Attributes

Archer base attributes are initialized in `ArcherPlayerController.InitAttributes()` from `GamePlayDatabase` fields (new fields needed).

| Attribute | Mage Value | Archer Value | Delta | Rationale |
|-----------|-----------|--------------|-------|-----------|
| Health | 100 | 75 | -25% | Squishier — dodge roll compensates |
| Attack | 100 | 80 | -20% | Lower per-hit, but higher fire rate = ~20% more DPS |
| AttackRange | 8 | 10 | +25% | Longer range rewards kiting |
| MoveSpeed | 3.0 | 3.6 | +20% | Faster base movement |
| Defense | 5 | 3 | -40% | Glass cannon — mistakes hurt more |
| CriticalChance | 0.05 | 0.08 | +60% | Rapid hits + higher crit = rewarding crit builds |
| CriticalDamageMultiplier | 1.5 | 1.5 | Same | No change |
| PinpointAttackMultiplier | 1.0 | 1.0 | Same | No change |

**Note**: Exact values are placeholder — these are `GamePlayDatabase` fields and are tuned via ScriptableObject without code changes. The ratios matter more than absolutes.

### Shared Skill Pool

**Skill Categories by Class Availability:**

| Category | Sharing Rule | Examples |
|----------|-------------|---------|
| **Attribute passives** | Shared | Frenzy, Stoneguard, SwiftWind — stat buffs work for any class |
| **Condition passives** | Shared | Rampage, ColdBlood, Berserk — trigger conditions are class-agnostic |
| **Status effect upgrades** | Shared | BurnAttack, SlowAttack, FreezeAttack — applied via Effect system on any hit |
| **Misc skills** | Shared | GoldRush, GemRush, HealthRecover — economy/utility |
| **Fireball upgrades** | Mage-only | BurnAttackSkill_For_FireballSkill, ExplosionFireball, etc. — require FireballSkill as base |
| **Dash upgrades** | Mage-only | ExplosionDashSkill_For_DashSkill, etc. — require DashSkill as base |
| **Arrow upgrades** | Archer-only | New skills that upgrade ArrowShotSkill |
| **Dodge upgrades** | Archer-only | New skills that upgrade DodgeRollSkill |

**Implementation**: The existing `UpgradableSkill.CanApplyUpgrade()` already checks `compatibleUpgradeTypes`. Arrow upgrades set their compatible type to match ArrowShotSkill; fireball upgrades match FireballSkill. No new gating logic needed — the upgrade system naturally filters by compatibility.

**Draft pool behavior**: When drafting skills mid-run, the draft system filters out upgrades incompatible with the current character's base skills. Shared passives appear for both. This is handled by checking `CanApplyUpgrade()` against the player's collected skills before offering drafts.

**New Archer-Exclusive Skills (7):**

| # | Skill Name | Type | Description |
|---|-----------|------|-------------|
| 1 | **Piercing Arrow** | Arrow Upgrade | Arrows pass through enemies, hitting up to 3 targets in a line. Damage reduced 20% per pierce. |
| 2 | **Multishot** | Arrow Upgrade | Fire 3 arrows in a fan spread instead of 1. Each deals 50% damage. |
| 3 | **Poison Arrow** | Arrow Upgrade | Arrows apply Poison status (DoT over 4s). Stacks up to 3 times. |
| 4 | **Afterimage** | Dodge Upgrade | Dodge roll leaves a decoy at the start position for 2s. Decoy draws enemy aggro. |
| 5 | **Counter Roll** | Dodge Upgrade | If dodge roll i-frames block an attack, next Arrow Shot deals 2x damage (3s window). |
| 6 | **Quickdraw** | Passive | After dodge roll ends, attack speed +50% for 2s. Rewards weaving dodge → attack. |
| 7 | **Eagle Eye** | Passive | +30% crit chance against enemies beyond 50% of attack range. Rewards maintaining distance. |

### Interactions with Other Systems

**Upstream (reads from):**
- **Core Combat (D1)**: Arrow Shot uses `DamageCalculator` and projectile system. Dodge Roll uses `Health` for i-frame damage negation.
- **Skill System (D4)**: Archer collects skills via `PlayerController.CollectSkill()`. Upgrades apply via `UpgradableSkill.ApplyUpgrade()`. No changes to the framework.
- **Roguelite Draft (D7)**: `DraftRunController` offers skills filtered by class compatibility. Needs to check `CanApplyUpgrade()` against archer's base skills when generating draft options.
- **Difficulty System (E2)**: Enemy scaling applies identically regardless of player character. No archer-specific difficulty changes.

**Downstream (other systems read from this):**
- **Combo/Synergy (E4)**: New archer-specific combos needed in `ComboDatabase` (e.g., Piercing Arrow + Poison Arrow = "Plague Volley"). Cross-class combos possible if both characters share universal skills.
- **Room Content (E1)**: Room enemy compositions should be balanced for both characters. Rooms with lots of ranged enemies test the archer differently than the mage.
- **Achievements (N3)**: Archer-specific achievements (e.g., "Clear Room 5 as Archer without taking damage").

**Code changes required:**
1. Add `Archer` to `PlayerClassType` enum
2. Create `ArcherPlayerController : PlayerController` with `InitAttributes()` and `GetClassType()`
3. Add archer base stat fields to `GamePlayDatabase`
4. Add archer entry to `CharacterDatabase` asset
5. Create `ArrowShotSkill : UpgradableSkill` and `DodgeRollSkill : UpgradableSkill`
6. Create 7 new archer-exclusive skill ScriptableObjects
7. Refactor `DashSkill` references: currently casts to `MagePlayerController` — needs to cast to `PlayerController` or use `ICharacter` interface
8. Update `DraftRunController` to filter draft options by class compatibility
9. Create arrow projectile prefab and dodge roll animation/VFX

## Formulas

**Arrow Shot DPS vs Fireball DPS:**
```
Mage DPS  = Attack * 1.0 / 1.0s cooldown = 1.0x Attack/s
Archer DPS = Attack * 0.6 / 0.5s cooldown = 1.2x Attack/s (at archer's lower Attack)

Effective DPS comparison (with base stats):
  Mage:   100 * 1.0 / 1.0 = 100 DPS
  Archer:  80 * 0.6 / 0.5 =  96 DPS
```
Archer has ~4% less raw DPS but higher crit chance (0.08 vs 0.05) compensates:
```
Mage effective DPS   = 100 * (1 + 0.05 * 0.5) = 102.5
Archer effective DPS  =  96 * (1 + 0.08 * 0.5) = 99.8
```
Near-parity at base stats. Archer scales better with crit upgrades due to more hits per second.

**Piercing Arrow damage falloff:**
```
Target 1: baseDamage * 1.0
Target 2: baseDamage * 0.8
Target 3: baseDamage * 0.64
Formula: damage = baseDamage * (0.8 ^ pierceIndex)
```

**Multishot damage split:**
```
Per-arrow damage = baseDamage * 0.5
Total if all 3 hit = baseDamage * 1.5 (50% DPS increase, but requires clustered enemies)
```

**Dodge Roll i-frames:**
```
rollDuration = dodgeDistance / rollSpeed
iFrameStart = 0.0s (immediate on activation)
iFrameEnd = 0.2s
iFrameRatio = 0.2 / rollDuration
```
During i-frames, `Health.TakeDamage()` is suppressed (return early if `isDodging && Time.time < iFrameEnd`).

**Eagle Eye crit bonus:**
```
distanceToTarget = Vector3.Distance(archer.position, target.position)
rangeThreshold = archer.GetAttribute(AttackRange).CurrentValue * 0.5
if (distanceToTarget > rangeThreshold):
    effectiveCritChance = baseCritChance + 0.30
```

**Quickdraw attack speed buff:**
```
On dodge roll end:
    cooldownTime = baseCooldownTime * 0.5  (for 2 seconds)
Effectively doubles fire rate during the window.
```

## Edge Cases

1. **Dodge Roll into a wall**: Roll stops at the wall. i-frames still apply for their full 0.2s duration even if distance is shortened. Momentum is zeroed on wall contact.
2. **Dodge Roll off platform/edge**: Same as Blink — raycast checks for ground. If no ground at destination, roll stops at last valid ground position.
3. **I-frames vs traps**: i-frames protect against all damage sources — enemy attacks, projectiles, AND trap damage. Consistent behavior, no exceptions.
4. **I-frames vs status effects**: i-frames block damage AND status effect application during the window. Keep simple — i-frames block everything.
5. **Piercing Arrow + Multishot interaction**: If both upgrades are applied, each of the 3 fan arrows can pierce. Each arrow independently tracks its pierce count. Maximum targets per shot: 3 arrows × 3 pierces = 9 hits (rare, requires dense enemy line).
6. **Counter Roll with no attack target**: Counter Roll buff is applied on successful i-frame block. If the 3s window expires without attacking, buff is lost. No stacking — a second i-frame block refreshes the 3s window.
7. **Quickdraw + Counter Roll stacking**: Both can be active simultaneously. Quickdraw doubles fire rate AND Counter Roll doubles damage = a massive burst window after a well-timed dodge. This is intentional — rewarding skilled play.
8. **Archer vs melee enemies**: Archer has no melee option. If enemies close to point-blank range, Arrow Shot still fires (minimum range = 0). Dodge Roll is the escape tool. This is the intended pressure point — archers who can't kite die fast.
9. **Character switch mid-run**: Not supported. Character is selected before entering a room and locked for the run. Draft pool is filtered at run start.
10. **Afterimage decoy aggro**: Decoy has 1 HP and is destroyed by any hit. Enemies targeting the decoy switch to the player when decoy dies. Decoy does not block projectiles.

## Dependencies

**Hard Dependencies (cannot function without):**

| System | Direction | Interface |
|--------|-----------|-----------|
| Core Combat (D1) | Upstream | Arrow Shot uses `DamageCalculator`, projectile system, `SpellWeaponHandler` |
| Health & Death (D2) | Upstream | Dodge Roll i-frames suppress `Health.TakeDamage()`. Death/respawn flow unchanged. |
| Skill System (D4) | Upstream | `PlayerController.CollectSkill()`, `UpgradableSkill.ApplyUpgrade()`, `BaseSkill` framework |
| Enemy AI (D5) | Upstream | Afterimage decoy needs to be targetable by enemy BehaviourTree |
| Roguelite Draft (D7) | Upstream | Draft pool filtering by class — `DraftRunController` checks upgrade compatibility |
| Status Effects (D3) | Upstream | Poison Arrow applies `PoisonState` via `StateMachine.SwitchState()` |
| Incomplete Skills (E5) | Upstream | Shared skill pool must be functional before archer can use them |

**Soft Dependencies (enhanced by, works without):**

| System | Direction | Interface |
|--------|-----------|-----------|
| Combo/Synergy (E4) | Downstream | Archer-specific combos in `ComboDatabase`. Works without — just fewer combos. |
| Room Content (E1) | Downstream | Rooms should be playtested with archer. Works without — just less balanced. |
| Achievements (N3) | Downstream | Archer-specific achievements. Works without. |
| Difficulty System (E2) | Upstream | Enemy scaling applies to all characters. No archer-specific hooks needed. |

**Owned by this system:** `ArcherPlayerController`, `ArrowShotSkill`, `DodgeRollSkill`, 7 archer-exclusive skills, archer entry in `CharacterDatabase`, archer stat fields in `GamePlayDatabase`.

## Tuning Knobs

All values live in `GamePlayDatabase` (ScriptableObject) and per-skill `SerializeField` properties. Editable in Inspector.

**Character Stats:**

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| `ArcherBaseHealth` | 75 | 50 – 120 | Loses glass cannon identity, feels like mage | One-shot by Hard mode enemies |
| `ArcherBaseMoveSpeed` | 3.6 | 2.5 – 5.0 | Enemies can't catch archer, too easy to kite | No speed advantage over mage, loses identity |
| `ArcherBaseAttack` | 80 | 50 – 120 | Kills too fast, rooms feel trivial | Takes too long to clear, frustrating |
| `ArcherBaseCritChance` | 0.08 | 0.03 – 0.15 | Crits feel routine, not exciting | Crit builds don't feel viable |

**Arrow Shot:**

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| `arrowCooldown` | 0.5s | 0.2 – 1.5s | Machine gun feel, too spammy | Feels sluggish, loses rapid-fire identity |
| `arrowDamageMultiplier` | 0.6 | 0.3 – 1.0 | Per-hit too strong for the fire rate | Each hit feels insignificant |
| `arrowProjectileSpeed` | 18 | 10 – 30 | Hard to dodge for enemies (PvE irrelevant), visually hard to track | Feels floaty, not snappy |

**Dodge Roll:**

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| `dodgeDistance` | 2.0 | 1.0 – 4.0 | Covers too much ground, trivializes positioning | Doesn't escape melee range |
| `dodgeCooldown` | 1.5s | 0.8 – 3.0s | Spammable, archer becomes untouchable | Can't dodge consecutive attacks |
| `iFrameDuration` | 0.2s | 0.1 – 0.4s | Too forgiving, rolling through everything | Requires frame-perfect timing, frustrating |

**Exclusive Skills:**

| Knob | Default | Safe Range | Notes |
|------|---------|------------|-------|
| Piercing max targets | 3 | 2 – 5 | Higher = more crowd clear power |
| Piercing falloff | 0.8 | 0.5 – 1.0 | At 1.0 = no falloff (overpowered for line-ups) |
| Multishot arrow count | 3 | 2 – 5 | Higher = more spread, harder to land all |
| Multishot damage per arrow | 0.5 | 0.3 – 0.8 | Sum must stay below 2.0 to prevent DPS explosion |
| Poison DoT duration | 4s | 2 – 8s | Longer = more total damage, diluted over time |
| Poison max stacks | 3 | 1 – 5 | Higher = rewards sustained fire on single target |
| Counter Roll damage mult | 2.0 | 1.5 – 3.0 | Higher = more reward for risky dodging |
| Counter Roll window | 3.0s | 1.5 – 5.0s | Shorter = harder to use, more skill-expressive |
| Quickdraw attack speed buff | 0.5 | 0.3 – 0.8 | Lower = faster fire rate during window |
| Eagle Eye crit bonus | 0.30 | 0.15 – 0.50 | Higher = more reward for maintaining distance |

## Acceptance Criteria

1. **Archer selectable on character select screen** — `CharacterDatabase` shows Archer alongside Mage. Archer has name, description, and visual in all 11 locales.
2. **Arrow Shot fires and deals damage** — Pressing attack fires an arrow projectile at the nearest enemy. Arrow travels at speed 18, deals 0.6x Attack damage. Cooldown is 0.5s.
3. **Dodge Roll moves and grants i-frames** — Pressing dodge rolls 2.0 units in movement direction. During the first 0.2s, all incoming damage is blocked. Verify with a melee enemy swinging during roll.
4. **Dodge Roll respects walls** — Roll stops at walls (no clipping through). Verify by rolling toward a wall from 1 unit away — should stop at wall, not pass through.
5. **Stats match design** — Archer has lower HP (-25%), higher move speed (+20%), higher crit (+60%), lower defense (-40%) compared to Mage. Verify via Inspector on `GamePlayDatabase`.
6. **Shared skills work** — Equip 3+ shared skills (Frenzy, BurnAttack, GoldRush) on Archer. All activate and apply effects correctly.
7. **Mage-only skills filtered out** — FireballSkill upgrades (e.g., BurnAttack_For_FireballSkill) do NOT appear in Archer's draft pool.
8. **Archer-exclusive skills work** — All 7 new skills: Piercing Arrow pierces 3 targets, Multishot fires 3 arrows, Poison Arrow applies Poison state, Afterimage spawns decoy, Counter Roll buffs next shot, Quickdraw speeds up attacks, Eagle Eye adds crit at range.
9. **Both characters clear Room 1 Normal** — Playtest both Mage and Archer through Room 1 on Normal difficulty. Clear times should be within 20% of each other (neither drastically easier/harder).
10. **No MagePlayerController casts on shared code** — Grep for `MagePlayerController` in skills shared by both classes. None should remain — all must use `PlayerController` or `ICharacter`.

## Open Questions

1. **Archer unlock gating**: Is the archer available from the start, or unlocked after clearing N rooms as Mage? If gated, what's the unlock condition?
2. **Archer model/animations**: Low-poly archer model needed. How many unique animations? (idle, run, arrow shot, dodge roll, death, hit reaction — minimum 6). Can any be shared with existing characters?
3. **Arrow projectile VFX**: Should arrows have elemental trail effects when upgraded (poison = green trail, etc.), or keep them visually simple?
4. **DashSkill refactor scope**: The mage's DashSkill casts to `MagePlayerController`. Refactoring to `PlayerController` may break existing mobile code. Evaluate impact before changing.
