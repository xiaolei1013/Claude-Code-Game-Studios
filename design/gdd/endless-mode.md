# Endless Mode

> **Status**: In Design
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-04-07
> **System ID**: N2
> **Priority**: P1

## Overview

Endless Mode is a single-arena survival mode where players face infinitely scaling waves of enemies, drafting skills every 5 waves to build increasingly powerful combos. Score equals waves cleared. The mode reuses the campaign's combat systems, enemy pool, and skill draft but replaces the 10-room structure with a continuous escalation in a single arena. Difficulty scales independently from the campaign's Normal/Hard system via its own `EndlessDifficultyConfig` curve. A strong run lasts 10-15 minutes (~20-30 waves); exceptional runs can push further but enemy scaling eventually overwhelms any build. Both Mage and Archer are available with class-specific leaderboards.

## Player Fantasy

**The Infinity Machine** — Endless Mode is where builds go to be tested to destruction. The campaign teaches you which combos are good; Endless Mode shows you exactly how good. Every run is a personal record attempt: "Can this build survive one more wave?" The draft picks between waves become increasingly agonizing — do you shore up a weakness or double down on your combo? The mode should feel like a ticking clock that your build is racing against. The power fantasy isn't clearing it — it's lasting longer than you thought possible.

## Detailed Design

### Core Loop

```
Start -> Wave 1-5 -> Draft Pick -> Wave 6-10 -> Draft Pick -> ... -> Death -> Score Screen
```

1. Player selects Endless Mode from main menu (no room selection)
2. Player enters a single large arena (reuses Arena archetype, 30x30 units)
3. Waves spawn continuously. Each wave has a 3s breathing window after completion.
4. Every 5 waves: a skill draft screen appears (3 options, same as campaign)
5. Every 10 waves: a boss wave (random boss from the 5 campaign bosses, always 2-phase in Endless — simpler than campaign rooms 6-10 which use 3-phase. Endless difficulty comes from stat scaling, not phase complexity.)
6. Scaling continues until the player dies. No healing between waves except drops.
7. **Config routing**: `SpawnManager` reads `EndlessDifficultyConfig` in Endless mode, NOT campaign `DifficultyConfig`. Mode is set at Endless entry and checked by SpawnManager before applying any multiplier.
7. Score = total waves cleared. Displayed on death screen.

### Wave Composition

**Base wave (wave 1):**
- 4 regular enemies, 0 elites
- 1 enemy type (weakest available)

**Scaling per wave:**
```
enemyCount(wave) = 4 + Floor(wave * 0.5)        // Wave 1: 4, Wave 10: 9, Wave 20: 14, Wave 30: 19
eliteRatio(wave) = Min(0.50, wave * 0.02)        // Wave 1: 2%, Wave 10: 20%, Wave 25: 50% cap
enemyTypeCount(wave) = Min(5, 1 + Floor(wave/5)) // New type every 5 waves, cap at 5
```

**Boss waves (every 10 waves):**
- Wave 10: Boss A (Stone Guardian), 2-phase
- Wave 20: Boss B (Dark Sorcerer), 2-phase
- Wave 30: Boss C (Necromancer), 2-phase
- Wave 40: Boss D (War Chief), 2-phase
- Wave 50: Boss E (Lich King), 2-phase
- Wave 60+: Cycle back to Boss A with enhanced stats

Boss waves spawn the boss only (no wave enemies). Boss stat scaling follows the endless curve, not campaign DifficultyConfig.

### Endless Difficulty Curve

The endless mode uses its own `EndlessDifficultyConfig` separate from the campaign:

```
EndlessDifficultyConfig
  statMultiplier(wave) = 1.0 + (wave * 0.04)    // Wave 1: 1.04x, Wave 10: 1.4x, Wave 25: 2.0x
  healDropMultiplier(wave) = Max(0.1, 1.0 - (wave * 0.03))  // Wave 10: 0.7, Wave 30: 0.1
  spawnPacing(wave) = Max(0.5, 1.0 - (wave * 0.015))  // Wave 20: 0.7, Wave 33+: 0.5 floor
  rewardMultiplier = 1.5  // flat, not scaling
```

**Design intent:** Stat scaling is linear (not exponential) so builds have time to come online. Healing reduction and faster pacing create the squeeze — the player doesn't get one-shot, they get ground down. By wave 25-30, even a strong build feels the pressure.

### Draft System in Endless

- Draft offered every 5 waves (waves 5, 10, 15, 20...)
- Uses the same `DraftRunController` and skill pool as campaign
- Class filtering applies (Mage gets Mage pool, Archer gets Archer pool)
- Combo detection runs after each draft (E4 system)
- No limit on total skills — player accumulates all drafted skills
- Draft pool does not deplete — the same skill can be offered again (duplicates of shared passives stack per existing UpgradableSkill rules)

### Arena Layout

- Single arena, 30x30 units, Arena archetype
- No traps (traps add complexity without serving the Endless fantasy)
- 6 spawn points (one per hex direction for variety)
- No obstacles — pure open space for kiting and positioning
- Consistent lighting (no per-wave visual changes)

### Score and Leaderboard

- Score = waves cleared (integer)
- Displayed on HUD during run (top-right, below currency)
- Death screen shows: waves cleared, total kills, combos discovered this run, class used
- Per-class leaderboard: Mage high score and Archer high score tracked separately
- Persistence: high scores saved in existing `LevelStats` system with a special "Endless" level ID

### Interactions with Other Systems

**Upstream:**
- **Difficulty System (E2)**: Endless has its own `EndlessDifficultyConfig`. Does NOT use campaign Normal/Hard.
- **Room Content (E1)**: Reuses Arena archetype layout. Does not reuse room-specific configs.
- **Skill System (D4)**: Full skill pool available. Draft system unchanged.
- **Combo/Synergy (E4)**: All 18 combos available. Combo discovery works identically.
- **Boss Phase System (E3)**: Boss waves use `BossController` prefabs with 2-phase configs only (Endless does not use 3-phase — difficulty comes from stat scaling, not phase complexity). SpawnManager reads `EndlessDifficultyConfig`, not campaign `DifficultyConfig`.
- **Core Combat (D1)**: All combat systems apply normally.

**Downstream:**
- **Achievements (N3)**: Endless-specific achievements (e.g., "Reach wave 20", "Reach wave 30 as Archer").

## Formulas

**Enemy stat scaling:**
```
statMultiplier(wave) = 1.0 + (wave * 0.04)

Wave 1:  1.04x (nearly baseline)
Wave 10: 1.40x (comparable to campaign Hard)
Wave 20: 1.80x (beyond campaign Hard)
Wave 25: 2.00x (double base stats)
Wave 30: 2.20x (extreme — most builds fail here)
Wave 50: 3.00x (theoretical limit for optimized builds)
```

**Enemy count scaling:**
```
enemyCount(wave) = 4 + Floor(wave * 0.5)

Wave 1:  4 enemies
Wave 10: 9 enemies
Wave 20: 14 enemies
Wave 30: 19 enemies (screen getting full)
```

**Healing drop reduction:**
```
healDropMultiplier(wave) = Max(0.1, 1.0 - (wave * 0.03))

Wave 1:  97% of base heal chance
Wave 10: 70% of base heal chance
Wave 20: 40% of base heal chance
Wave 30: 10% of base heal chance (nearly no healing)
```

**Spawn pacing compression:**
```
spawnPacing(wave) = Max(0.5, 1.0 - (wave * 0.015))

Wave 1:  0.985x base delay
Wave 20: 0.70x base delay (30% faster)
Wave 33+: 0.50x base delay (floor — 50% faster)
```

**Expected run duration:**
```
avgWaveDuration(wave) = 15s + (wave * 0.5s)  // more enemies = longer waves
draftTime = 10s (every 5 waves)
breathingWindow = 3s per wave

runDuration(waves) = Sum(avgWaveDuration(1..waves)) + (waves/5 * draftTime) + (waves * 3s)

Wave 20 run: ~12 minutes (target for average player)
Wave 30 run: ~18 minutes (strong build)
Wave 40+ run: 25+ minutes (exceptional)
```

**Kill-time validation targets (must be validated in playtest):**
```
At wave 25 (2.0x stats), a baseline Mage (no combos) should kill a regular enemy in 4-6 hits.
At wave 25 (2.0x stats), a combo-optimized Archer should kill a regular enemy in 2-3 hits.
At wave 50 (3.0x stats), even an optimized build should take 6-10 hits per regular enemy.
Boss kill time at wave 30 (2.2x stats): 60-90 seconds (2-phase boss).
If any kill time exceeds these targets by >50%, the stat scaling rate needs reduction.
```

## Edge Cases

1. **Player kills boss on a draft wave (wave 10, 20, etc.)**: Boss wave completes first, then draft screen appears. Boss death counts as the wave clear trigger for the draft.
2. **Wave 60+ boss cycling**: After all 5 bosses have appeared, cycle back to Boss A. Boss stat scaling from `EndlessDifficultyConfig` applies, making recycled bosses harder than their first appearance.
3. **Combo discovery persistence in Endless**: `discoveredFlag` from combo system applies globally. A combo discovered in Endless is flagged as discovered for campaign runs too, and vice versa.
4. **Skill draft with full pool**: Player cannot receive more than 1 copy of the same active skill. Passive duplicates stack via existing UpgradableSkill rules. If the draft pool is exhausted (extremely long runs), offer gold/gem bonuses instead.
5. **Performance at wave 30+**: 19+ enemies on screen simultaneously. Performance budget: <16.6ms frame time on PC, <33ms on mobile. If enemy count exceeds mobile performance, cap visible enemies and queue spawns.
6. **Endless Mode with no character unlocked**: Mage is always available. Archer requires unlock (per N1 GDD open question). If Archer isn't unlocked, Endless Mode shows Mage only.
7. **Save during Endless run**: Endless runs are NOT saveable mid-run. Quitting = run lost. This is intentional — runs are 10-15 minutes and saving would allow save-scumming.

## Dependencies

**Hard Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Core Combat (D1) | Upstream | `SpawnManager` handles wave spawning. All combat applies. |
| Skill System (D4) | Upstream | Full skill pool for drafting. `DraftRunController` handles picks. |
| Boss Phase System (E3) | Upstream | Boss waves use `BossController` prefabs. |
| Save/Load (D11) | Upstream | High score persistence. `LevelStats` with Endless level ID. |

**Soft Dependencies:**

| System | Direction | Interface |
|--------|-----------|-----------|
| Difficulty System (E2) | Reference | Endless uses own config, not campaign DifficultyConfig. Reuses the struct format. |
| Room Content (E1) | Reference | Reuses Arena archetype layout. |
| Combo/Synergy (E4) | Upstream | All 18 combos available. Not required — Endless works without combos. |
| Achievements (N3) | Downstream | Endless-specific achievement triggers. |

**Owned by this system:** `EndlessDifficultyConfig`, Endless wave spawner, Endless scoring, Endless draft timing, per-class leaderboard, Endless arena layout.

## Tuning Knobs

| Knob | Default | Safe Range | If Too High | If Too Low |
|------|---------|------------|-------------|------------|
| Stat scaling rate | 0.04 per wave | 0.02-0.08 | Enemies become walls too fast, frustrating | Too easy, runs go forever |
| Heal drop reduction rate | 0.03 per wave | 0.01-0.05 | No healing by wave 15, too punishing | Healing never runs out, removes pressure |
| Spawn pacing floor | 0.5x | 0.3-0.7 | Enemies overlap spawns, unfair | Pacing never gets intense |
| Draft frequency | Every 5 waves | 3-10 waves | Too many skills, choices feel cheap | Too few skills, build never comes online |
| Boss wave frequency | Every 10 waves | 5-15 waves | Too many bosses, repetitive | Long stretches without a challenge spike |
| Reward multiplier | 1.5x | 1.0-3.0 | Endless becomes best farming method | No incentive to play Endless |
| Enemy count scaling | +0.5 per wave | +0.3-1.0 | Screen floods, performance risk | Never feels overwhelming |

## Acceptance Criteria

1. **Endless Mode accessible from main menu** — Select Endless Mode. Arena loads, wave 1 spawns. No room selection needed.
2. **Waves escalate correctly** — Wave 1 has 4 enemies. Wave 10 has 9 enemies. Wave 20 has 14. Verify counts match formula.
3. **Draft appears every 5 waves** — After clearing wave 5, draft screen appears with 3 skill options. Class filtering works.
4. **Boss spawns every 10 waves** — Wave 10 spawns Boss A. Wave 20 spawns Boss B. Verify boss identity matches cycle.
5. **Stat scaling applies** — Damage taken from wave 20 enemies is measurably higher than wave 1. Verify via damage numbers.
6. **Healing reduces over time** — Count healing drops over waves 1-5 vs waves 20-25. Later waves have noticeably fewer heals.
7. **Score displays on HUD** — Waves cleared count visible during run. Updates after each wave.
8. **Death screen shows stats** — On death: waves cleared, kills, combos, class. High score saved if new record.
9. **Per-class leaderboards** — Set Mage high score at 25 waves. Switch to Archer. Verify: Archer leaderboard is independent.
10. **Run under 15 minutes at wave 20** — Time a wave-20 run. Should be approximately 12 minutes.

## Open Questions

1. **Trap integration**: Should later waves introduce traps into the arena (e.g., fire grates appear at wave 15)? Adds variety but complicates the "pure combat" feel.
2. **Wave modifiers**: Should certain waves have special rules (e.g., "all enemies are elite", "enemies regenerate")? Could create memorable moments but adds complexity.
3. **Endless Mode unlocking**: Should Endless be available from the start, or unlock after clearing Room 5 (or Room 10) on Normal? Gating ensures players understand the combat before attempting survival.
4. **Multiplayer leaderboard**: Should high scores be uploaded to Steam leaderboards, or stay local only? Steam leaderboards add social competition but require server infrastructure.
