# Difficulty System

> **Status**: In Design
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-03-29
> **System ID**: E2
> **Priority**: P0 (Foundation)

## Overview

The Difficulty System governs two selectable difficulty tiers — Normal and Hard — across all 10 rooms. Hard mode is gated behind clearing the room on Normal first. Difficulty affects five axes simultaneously: enemy stat scaling (existing), wave enemy count, healing drop rate, spawn pacing, and reward multipliers. The system builds on the existing `LevelDifficulty` enum and `ApplyRandomVariation()` scaling in `EnemyController.cs`, extending it to cover wave composition, economy, and pacing. The goal is to make Hard mode feel like a genuinely different challenge — not just "same room, spongier enemies" — while incentivizing players with better rewards.

## Player Fantasy

**Normal**: The "learning and mastering" experience. Players explore rooms, discover skill combos, and feel increasingly powerful. Deaths happen but feel fair — "I know what I did wrong." The pace allows breathing room between waves to plan the next move.

**Hard**: The "proving grounds" experience. Players return to a room they already cleared and face a genuinely different challenge. The room feels more dangerous — more enemies, less healing, faster pressure. Clearing Hard feels earned and rewarding, not just a grind. The better rewards reinforce "I earned this." Reference feeling: clearing a higher heat in Hades — same arena, different intensity.

## Detailed Design

### Core Rules

**Difficulty Tiers**: Normal and Hard. Easy is unused in PC v1.0 (enum value preserved for mobile).

**Five Difficulty Axes:**

| Axis | Normal | Hard | Implementation |
|------|--------|------|----------------|
| Enemy Stats | 1.0-1.2x multiplier | 1.2-1.5x multiplier | Existing `ApplyRandomVariation()` in `EnemyController.cs` |
| Enemy Count | Base wave count | +25% per wave (rounded up) | New: multiply `SpawnCount` in each `SpawnItemInfo` |
| Healing Drops | 100% drop rate | 50% drop rate | New: multiply healing drop probability |
| Spawn Pacing | Base delay | 75% of base delay (25% faster) | New: multiply wave `Delay` values in `SpawnItemInfo` |
| Rewards | 1x gold & gems | 2x gold & gems | New: multiply drop amounts on kill and room clear |

**Rules:**
1. All five axes apply simultaneously — Hard is not just "pick one modifier"
2. Difficulty is set per-room before entering (UI selection in MenuPrepareStagePanelPC)
3. Difficulty cannot be changed mid-room
4. Each room tracks Normal and Hard progress independently (existing `LevelStats` behavior)
5. Enemy count rounding: `Ceil(baseCount * 1.25)` — a wave of 3 becomes 4, a wave of 7 becomes 9
6. Healing drop rate applies to both destructible crate drops and enemy death drops
7. Reward multiplier applies to gold, gems, and any material drops (boss essence, etc.)

### Difficulty Axis Breakdown

**Enemy Stats**: No changes needed — existing `ApplyRandomVariation()` already handles Normal (1.0-1.2x) and Hard (1.2-1.5x) across all 8 attributes (Health, Attack, AttackRange, MoveSpeed, Defense, CriticalChance, CriticalDamageMultiplier, AbilityInterval).

**Enemy Count**: Applied at spawn time by `SpawnManager`. For each `SpawnItemInfo` in a wave, if difficulty is Hard: `spawnCount = Mathf.CeilToInt(baseSpawnCount * 1.25f)`. Extra enemies use the same spawn points (round-robin across available `EnemySpawnPoint` transforms).

**Healing Drops**: Applied via a difficulty-aware roll in drop behavior. When an enemy dies or a crate breaks, healing drops check: `if (Random.value <= healDropRate * difficultyHealMultiplier)`. Normal: multiplier = 1.0. Hard: multiplier = 0.5. Non-healing drops (gold, gems, skills) are unaffected.

**Spawn Pacing**: Applied at spawn time by `SpawnManager`. For each wave's `Delay` value: `actualDelay = baseDelay * difficultyPacingMultiplier`. Normal: multiplier = 1.0. Hard: multiplier = 0.75. This affects the gap between waves, not within-wave spawn timing.

**Rewards**: Applied at the moment of drop/grant. For gold and gem drops: `amount = Mathf.CeilToInt(baseAmount * difficultyRewardMultiplier)`. Normal: multiplier = 1.0. Hard: multiplier = 2.0. Applied to enemy kill drops, boss drops, and room-clear bonuses. Shop prices are NOT affected.

### Unlock Gating

**Rule**: Hard mode for a room is locked until the player clears that room on Normal.

**Unlock check**: When rendering the room select UI, read `LevelStats` for the room's Normal entry. If `levelState == LevelState.Completed`, enable the Hard toggle. Otherwise, Hard is grayed out with tooltip: "Clear on Normal to unlock."

**Persistence**: Unlock state is derived from existing `LevelStats` save data — no additional save field needed. If Normal is cleared, Hard is unlocked. This survives save/load automatically.

**UI**: The difficulty selector in `MenuPrepareStagePanelPC` shows both Normal and Hard buttons. Hard button is visually dimmed with a lock icon when gated. On unlock, a brief gold flash animation plays (reuse rarity glow from DESIGN.md).

**Endless Mode interaction**: Endless Mode has no difficulty gate — it's a single mode with its own scaling (designed separately in N2).

### Interactions with Other Systems

**Upstream (this system reads from):**
- **Core Combat (D1)**: Difficulty modifies enemy stats via `ApplyRandomVariation()`. Combat formulas (DamageCalculator) are unaware of difficulty — they just see the final stat values.
- **Loot & Drops (D8)**: Difficulty modifies healing drop rate and reward amounts. Drop behavior checks difficulty multipliers before rolling.
- **Save/Load (D11)**: `LevelStats` already tracks per-difficulty progress. Unlock gating reads Normal completion state.

**Downstream (other systems read from this):**
- **Boss Phase System (E3)**: Bosses use the same five-axis scaling. Boss-specific phase thresholds are defined in HP percentages, so they scale naturally with the stat multiplier.
- **Room Content (E1)**: Room designers author wave compositions for Normal. Hard values are derived automatically via the multipliers — no per-difficulty room authoring needed.
- **Endless Mode (N2)**: Endless has its own `EndlessDifficultyConfig` with wave-based scaling, independent of campaign `DifficultyConfig`. `SpawnManager` checks the active mode (campaign vs Endless) and reads the corresponding config. The config struct format is shared; the values are different.

**Interface**: A `DifficultyConfig` struct holds all five multipliers for the current difficulty. Systems query it rather than checking the enum directly. This centralizes tuning and supports Endless Mode reusing the structure with custom values.

```
DifficultyConfig
├── statMultiplierMin: float    (Normal: 1.0, Hard: 1.2)
├── statMultiplierMax: float    (Normal: 1.2, Hard: 1.5)
├── enemyCountMultiplier: float (Normal: 1.0, Hard: 1.25)
├── healDropMultiplier: float   (Normal: 1.0, Hard: 0.5)
├── pacingMultiplier: float     (Normal: 1.0, Hard: 0.75)
└── rewardMultiplier: float     (Normal: 1.0, Hard: 2.0)
```

## Formulas

**Enemy Stat Scaling** (existing, unchanged):
```
finalStat = baseStat * Random.Range(statMultiplierMin, statMultiplierMax)

Normal: finalStat = baseStat * Random.Range(1.0, 1.2)
Hard:   finalStat = baseStat * Random.Range(1.2, 1.5)
```
Applied to: Health, Attack, AttackRange, MoveSpeed, Defense, CriticalChance, CriticalDamageMultiplier

**Enemy Count Scaling**:
```
hardCount = Ceil(baseCount * enemyCountMultiplier)

Example: baseCount = 3, multiplier = 1.25 → Ceil(3.75) = 4
Example: baseCount = 7, multiplier = 1.25 → Ceil(8.75) = 9
```

**Healing Drop Rate**:
```
actualDropChance = baseDropChance * healDropMultiplier

Normal: 10% base → 10% actual
Hard:   10% base → 5% actual
```

**Spawn Pacing**:
```
actualDelay = baseDelay * pacingMultiplier

Normal: 4.0s base → 4.0s actual
Hard:   4.0s base → 3.0s actual
```

**Reward Scaling**:
```
actualReward = Ceil(baseReward * rewardMultiplier)

Normal: 5 gold base → 5 gold
Hard:   5 gold base → 10 gold
```

**Effective Difficulty Increase** (combined estimate):
Hard mode effective difficulty vs Normal ≈ 2.5-3x harder (enemies are ~35% stronger AND ~25% more numerous AND heal less AND arrive faster). Reward of 2x compensates roughly 60-70% of the extra effort — Hard should feel rewarding but not strictly efficient for farming.

## Edge Cases

1. **Wave of 1 enemy on Hard**: `Ceil(1 * 1.25) = 2`. A solo enemy becomes a pair. This is intentional — no wave should feel identical on Hard.
2. **Healing drop chance rounds to 0%**: If a crate has a base 1% heal chance, Hard makes it 0.5%. This is fine — `Random.value <= 0.005` still works. No floor needed.
3. **Boss rooms**: Bosses are single spawns. `Ceil(1 * 1.25) = 2` would spawn two bosses — **exception: boss enemies (tagged as boss in EnemyData) are exempt from enemy count scaling.** Boss stat scaling still applies.
4. **Player clears Hard before Normal** (impossible due to gating): Gate enforced in UI. Even if bypassed via save editing, both LevelStats entries would be written — no harm.
5. **Reward rounding on odd values**: `Ceil(3 * 2.0) = 6`. Always rounds up. Minimum reward is 1 (never 0).
6. **Spawn points overflow**: If Hard adds enemies beyond available spawn points, extra enemies spawn at random existing spawn points (round-robin). No new spawn points needed.
7. **Difficulty mid-run via pause menu**: Not allowed. Difficulty selector is only on the room select screen. Pause menu shows current difficulty as read-only info.
8. **Draft system interaction**: Roguelite skill drafts are the same on both difficulties — draft pool, weighting, and combo system are difficulty-agnostic. Players don't get better draft options on Hard (rewards are the incentive, not power).

## Dependencies

**Hard Dependencies (cannot function without):**

| System | Direction | Interface |
|--------|-----------|-----------|
| Core Combat (D1) | Upstream | `EnemyController.InitAttributes()` reads `DifficultyConfig.statMultiplierMin/Max` |
| Loot & Drops (D8) | Upstream | Drop behaviors read `DifficultyConfig.healDropMultiplier` and `rewardMultiplier` |
| Save/Load (D11) | Upstream | `LevelStats` provides per-difficulty completion state for unlock gating |
| Wave/Room System (E1) | Upstream | `SpawnManager` reads `DifficultyConfig.enemyCountMultiplier` and `pacingMultiplier` |

**Soft Dependencies (enhanced by, works without):**

| System | Direction | Interface |
|--------|-----------|-----------|
| Boss Phase System (E3) | Downstream | Bosses use stat scaling but are exempt from count scaling. Phase thresholds are HP-percentage-based, so they adapt automatically. |
| Endless Mode (N2) | Downstream | May reuse `DifficultyConfig` struct with its own scaling values. Not required — Endless can define its own config independently. |
| Achievements (N3) | Downstream | Achievements may reference difficulty (e.g., "Clear Room 5 on Hard"). Reads `LevelStats.difficulty` field. |

**Owned by this system:** `DifficultyConfig` struct definition, `GlobalSettings.LevelDifficulty` storage, unlock gating logic.

## Tuning Knobs

All values live in a `DifficultyConfig` ScriptableObject, editable in the Unity Inspector without code changes.

| Knob | Default (Normal) | Default (Hard) | Safe Range | If Too High | If Too Low |
|------|-----------------|----------------|------------|-------------|------------|
| `statMultiplierMin` | 1.0 | 1.2 | 0.5 – 2.0 | Enemies feel spongy/unfair | No challenge, trivial |
| `statMultiplierMax` | 1.2 | 1.5 | 0.5 – 3.0 | Extreme variance, feels random | No variance between enemies |
| `enemyCountMultiplier` | 1.0 | 1.25 | 1.0 – 2.0 | Spawn point overflow, frame drops on low-end PCs | No difference from Normal |
| `healDropMultiplier` | 1.0 | 0.5 | 0.0 – 1.5 | At 0: no healing at all (may be too punishing). Above 1.0: more heals than Normal | Hard feels the same as Normal |
| `pacingMultiplier` | 1.0 | 0.75 | 0.3 – 1.5 | Below 0.3: waves overlap massively, screen floods | Above 1.0: slower than Normal, feels wrong |
| `rewardMultiplier` | 1.0 | 2.0 | 1.0 – 5.0 | Economy inflation — Hard becomes the only viable farming mode | No incentive to play Hard |

**Interaction warning:** `enemyCountMultiplier` and `pacingMultiplier` compound — more enemies arriving faster can spike CPU load. If `enemyCountMultiplier > 1.5` AND `pacingMultiplier < 0.5`, test on minimum-spec hardware.

## Acceptance Criteria

1. **Normal plays identically to current demo** — no regressions. Existing `ApplyRandomVariation()` behavior unchanged for Normal difficulty.
2. **Hard mode locked by default** — Room select UI shows Hard as dimmed/locked for any room not yet cleared on Normal.
3. **Hard unlocks on Normal clear** — After clearing Room N on Normal, Hard toggle becomes active for Room N. Persists across sessions.
4. **Enemy count scales on Hard** — A wave with `spawnCount = 4` spawns 5 enemies on Hard. Verify with at least 3 different wave sizes (1, 4, 7).
5. **Healing drops reduced on Hard** — Over 100 enemy kills on Hard, healing drops appear roughly half as often as on Normal (tolerance: ±15%).
6. **Spawn pacing faster on Hard** — Measure time between wave 1 and wave 2 start. Hard should be ~75% of Normal delay (tolerance: ±0.2s).
7. **Rewards doubled on Hard** — Gold and gem drop amounts are exactly 2x Normal values. Verify on enemy kill drops, boss drops, and room-clear bonus.
8. **Boss exempt from count scaling** — Boss wave spawns exactly 1 boss on both Normal and Hard. Boss stats still scale.
9. **DifficultyConfig is data-driven** — All 6 multiplier values are editable in a ScriptableObject without code changes. Changing a value and entering play mode applies immediately.
10. **Performance** — Room 1 on Hard with max concurrent enemies does not drop below 30 FPS on minimum-spec target hardware.

## Open Questions

1. **Should Hard mode have a visual indicator during gameplay?** (e.g., red-tinted border, skull icon on HUD) — or is the difficulty selector on the room screen enough?
2. **Endless Mode reuse**: Will Endless Mode use `DifficultyConfig` directly with its own scaling curve, or define a separate system entirely? (Deferred to N2 design.)
3. **Future difficulty tiers**: If post-launch feedback requests a third tier (e.g., Nightmare), the `DifficultyConfig` approach supports it — just add another ScriptableObject preset. No architectural changes needed.
