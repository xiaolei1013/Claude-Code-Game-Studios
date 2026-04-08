# Epic: Difficulty System

> **Layer**: Foundation (Layer 0)
> **GDD**: design/gdd/difficulty-system.md
> **Architecture Module**: E2 Difficulty -- Gameplay Layer
> **Governing ADRs**: ADR-0001
> **Status**: Ready
> **Stories**: 9 stories created (2026-04-07)

## Stories

| # | File | Title | Type | Priority | Size |
|---|------|-------|------|----------|------|
| 001 | [001-idfficulty-provider-interface.md](001-idfficulty-provider-interface.md) | IDifficultyProvider Interface & Campaign Provider | Logic | P0 | M |
| 002 | [002-normal-hard-config-presets.md](002-normal-hard-config-presets.md) | Normal & Hard Config Presets | Config | P0 | S |
| 003 | [003-enemy-stat-scaling.md](003-enemy-stat-scaling.md) | Enemy Stat Scaling Integration | Integration | P0 | M |
| 004 | [004-enemy-count-scaling.md](004-enemy-count-scaling.md) | Enemy Count Scaling | Logic | P1 | M |
| 005 | [005-healing-drop-rate.md](005-healing-drop-rate.md) | Healing Drop Rate Scaling | Logic | P1 | S |
| 006 | [006-spawn-pacing-scaling.md](006-spawn-pacing-scaling.md) | Spawn Pacing Scaling | Logic | P1 | S |
| 007 | [007-reward-scaling.md](007-reward-scaling.md) | Reward Scaling | Logic | P1 | S |
| 008 | [008-hard-mode-unlock-gating.md](008-hard-mode-unlock-gating.md) | Hard Mode Unlock Gating | UI | P1 | M |
| 009 | [009-difficulty-system-tests.md](009-difficulty-system-tests.md) | Difficulty System Tests | Logic | P0 | M |

### Dependency Graph

```
001 (Interface + Provider)
 ├── 002 (Config Presets) ──┐
 │    ├── 003 (Enemy Stat Scaling) ──┐
 │    ├── 004 (Enemy Count Scaling) ─┤
 │    ├── 005 (Healing Drop Rate) ───┤
 │    ├── 006 (Spawn Pacing) ────────┤
 │    ├── 007 (Reward Scaling) ──────┤
 │    └── 008 (Hard Mode Unlock) ────┘── (no downstream)
 └── 009 (Tests) ←── blocked by 003-007 for integration tests
```

**Critical Path**: 001 -> 002 -> 003 (P0 chain); 009 requires all consumer stories

## Overview

The Difficulty System governs two selectable difficulty tiers -- Normal and Hard -- across all 10 campaign rooms. Hard mode is gated behind clearing the room on Normal first. Difficulty affects five axes simultaneously: enemy stat scaling, wave enemy count, healing drop rate, spawn pacing, and reward multipliers. Architecturally, this system introduces `IDifficultyProvider` as the sole interface all consumers read, with `CampaignDifficultyProvider` (wrapping `DifficultyConfig` ScriptableObjects) and `EndlessDifficultyProvider` (wave-based computed values) as the two concrete implementations swapped at mode entry via `GameManager.ActiveDifficultyProvider`. This is the foundational layer that all other systems depend on -- no Gameplay or Content layer story can proceed until `IDifficultyProvider` is stable.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: DifficultyConfig as Interface | All difficulty multiplier access goes through `IDifficultyProvider`; two providers (campaign flat SO, Endless per-wave computed) swap at mode entry via `GameManager.ActiveDifficultyProvider`. Consumers never access `DifficultyConfig` fields or difficulty enums directly. | LOW -- uses MonoBehaviour, ScriptableObject, and C# interfaces; all stable pre-cutoff APIs |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|-------------|
| TR-difficulty-001 | DifficultyConfig ScriptableObject holds all 6 multipliers editable in Inspector without code changes | ADR-0001: Elevates struct to SO with `IDifficultyProvider` interface |
| TR-difficulty-002 | Systems query IDifficultyProvider interface rather than checking difficulty enum directly | ADR-0001: Structural enforcement -- consumers have no access to the enum |
| TR-difficulty-003 | Hard mode for a room is locked until player clears that room on Normal; unlock state derived from LevelStats save data | Not covered by ADR -- implementation story |
| TR-difficulty-004 | Enemy count scaling: Ceil(baseCount * enemyCountMultiplier); extra enemies round-robin across spawn points | ADR-0001: `EnemyCountMultiplier` is an `IDifficultyProvider` property |
| TR-difficulty-005 | Healing drop rate multiplied by healDropMultiplier; non-healing drops unaffected | ADR-0001: `HealDropMultiplier` is an `IDifficultyProvider` property |
| TR-difficulty-006 | Spawn pacing: actualDelay = baseDelay * pacingMultiplier; affects inter-wave delay only | ADR-0001: `PacingMultiplier` is an `IDifficultyProvider` property |
| TR-difficulty-007 | Reward scaling: Ceil(baseReward * rewardMultiplier); applies to enemy kills, boss drops, room-clear bonuses; shop prices unaffected | ADR-0001: `RewardMultiplier` is an `IDifficultyProvider` property |
| TR-difficulty-008 | Boss enemies (tagged isBoss in EnemyData) are exempt from enemy count scaling | ADR-0001: `IsBossExemptFromCount` is a first-class interface member, always true |
| TR-difficulty-009 | Difficulty cannot be changed mid-room; set per-room before entering | Not covered by ADR -- UI/flow story |
| TR-difficulty-010 | Performance: Room 1 Hard with max concurrent enemies must not drop below 30 FPS on minimum-spec target hardware | Not covered by ADR -- performance validation story |
| TR-difficulty-011 | Endless Mode uses separate EndlessDifficultyConfig with wave-based scaling; SpawnManager checks active mode and reads corresponding config | ADR-0001: `EndlessDifficultyProvider` computes per-wave values; `GameManager.ActiveDifficultyProvider` swaps at mode entry |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All acceptance criteria from GDD verified
- All Logic/Integration stories have passing tests
- All Visual/Feel/UI stories have evidence docs
- `IDifficultyProvider` interface implemented and stable
- `DifficultyConfig_Normal.asset` and `DifficultyConfig_Hard.asset` created and tuned
- `EndlessDifficultyConfig.asset` created with default values matching N2 GDD
- All four consumer systems (SpawnManager, EnemyController, drop behaviors, EndlessWaveSpawner) migrated to use `IDifficultyProvider`
- Hard mode unlock gating functional via LevelStats
- ADR-0001 validation criteria all passing

## Next Step

Stories created. Run `/sprint-plan new` to schedule these stories into a sprint.
