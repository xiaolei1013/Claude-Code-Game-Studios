# Epic: Endless Mode

> **Layer**: Content (Layer 3)
> **GDD**: design/gdd/endless-mode.md
> **Architecture Module**: N2 Endless -- Content Layer
> **Governing ADRs**: ADR-0001, ADR-0002, ADR-0007
> **Status**: Ready
> **Stories**: 8 stories created (2026-04-07)

## Stories

| # | File | Title | Type | Priority | Size |
|---|------|-------|------|----------|------|
| 001 | [001-endless-difficulty-provider.md](001-endless-difficulty-provider.md) | EndlessDifficultyProvider | Logic | P0 | M |
| 002 | [002-endless-wave-provider.md](002-endless-wave-provider.md) | EndlessWaveProvider | Logic | P0 | M |
| 003 | [003-endless-session-controller.md](003-endless-session-controller.md) | EndlessSessionController | Logic | P0 | L |
| 004 | [004-boss-wave-cycling.md](004-boss-wave-cycling.md) | Boss Wave Cycling | Logic | P1 | M |
| 005 | [005-endless-arena-setup.md](005-endless-arena-setup.md) | Endless Arena Setup | Config | P1 | S |
| 006 | [006-score-and-leaderboard.md](006-score-and-leaderboard.md) | Score & Leaderboard | UI | P1 | M |
| 007 | [007-endless-draft-integration.md](007-endless-draft-integration.md) | Endless Draft Integration | Integration | P1 | M |
| 008 | [008-endless-mode-tests.md](008-endless-mode-tests.md) | Endless Mode Tests | Logic | P0 | M |

### Dependency Graph

```
E2-001 (IDifficultyProvider) ──┐
                                ├── 001 (EndlessDifficultyProvider) ──┐
                                └── 002 (EndlessWaveProvider) ────────┤
                                                                      ├── 003 (EndlessSessionController)
                                     E3 Boss Assets ──── 004 (Boss  ──┘        │
                                                          Wave Cycling)        │
                                                                               ├── 005 (Arena Setup)
                                                                               ├── 006 (Score & Leaderboard)
                                                                               ├── 007 (Draft Integration) ←── E4 Combo
                                                                               └── 008 (Tests) ←── 001, 002, 003
```

**Critical Path**: E2-001 -> N2-001/002 (parallel) -> N2-003 -> N2-008 (P0 chain)
**Secondary**: N2-003 -> N2-005, N2-006, N2-007 (P1 stories can run in parallel)

## Overview

Endless Mode is a single-arena survival mode where players face infinitely scaling waves of enemies, drafting skills every 5 waves to build increasingly powerful combos. Score equals waves cleared, with per-class leaderboards (Mage/Archer). Architecturally, this system introduces three new classes: `EndlessWaveProvider` (procedural wave generation via N2 formulas, implementing `IWaveProvider` from ADR-0002), `EndlessDifficultyProvider` (wave-based stat/heal/pacing scaling via `IDifficultyProvider` from ADR-0001), and `EndlessSessionController` (wave counter, draft timing every 5 waves, boss cycling every 10 waves, score tracking). Boss cycling iterates through the 5 campaign bosses (A-E) with 2-phase configs, restarting at wave 60+. Score persists via `LevelStats` with synthetic IDs `"Endless_Mage"` and `"Endless_Archer"`. No mid-run save. Single 30x30 arena, no traps, 6 spawn points. Depends on E1 (Room Content), E2 (Difficulty), and E3 (Boss Phases).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: DifficultyConfig as Interface | `EndlessDifficultyProvider` computes per-wave stat/heal/pacing/reward values; swapped in at Endless entry via `GameManager.ActiveDifficultyProvider`. | LOW -- stable APIs |
| ADR-0002: SpawnManager Mode Routing | `EndlessWaveProvider` implements `IWaveProvider`; SpawnManager has zero mode-awareness; wave composition uses N2 procedural formulas. | LOW -- stable APIs |
| ADR-0007: Endless Mode Integration | `EndlessSessionController` coordinates the run: wave counter, draft timing, boss cycling, score persistence. `EndlessWaveConfig` SO holds boss cycle array and enemy pool. Score via `LevelStats` with synthetic IDs. No mid-run save. | LOW -- uses MonoBehaviour, ScriptableObject, coroutines; all stable pre-cutoff APIs |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|-------------|
| TR-endless-001 | EndlessDifficultyConfig ScriptableObject with wave-based scaling formulas | ADR-0001: EndlessDifficultyConfig SO with StatScalingRate, HealDropReductionRate, etc. |
| TR-endless-002 | Enemy count formula: enemyCount(wave) = 4 + Floor(wave * 0.5) | ADR-0007: Implemented in EndlessWaveProvider.GetNextWave() |
| TR-endless-003 | Elite ratio formula: eliteRatio(wave) = Min(0.50, wave * 0.02) | ADR-0007: Implemented in EndlessWaveProvider.GetNextWave() |
| TR-endless-004 | Enemy type introduction: enemyTypeCount(wave) = Min(5, 1 + Floor(wave/5)) | ADR-0007: Implemented in EndlessWaveProvider.GetNextWave() |
| TR-endless-005 | Skill draft every 5 waves via DraftRunController.ShowDraft(); class filtering applies | ADR-0007: EndlessSessionController calls ShowDraft() at wave % 5 == 0 |
| TR-endless-006 | Boss wave every 10 waves: cycle A-E (2-phase only in Endless), cycle restarts at wave 60+ | ADR-0007: EndlessWaveProvider.GetBossConfig() with deterministic index |
| TR-endless-007 | 3s breathing window between waves | ADR-0007: WaveLoop() yields WaitForSeconds(3f) |
| TR-endless-008 | Single 30x30 unit arena, Arena archetype, no traps, 6 spawn points | ADR-0007: GetTrapLayout() returns null; arena is a scene-level decision |
| TR-endless-009 | Score = waves cleared; per-class leaderboard via LevelStats with synthetic IDs | ADR-0007: LevelStats.SaveEndlessScore() with "Endless_Mage" / "Endless_Archer" |
| TR-endless-010 | No mid-run save; quitting = run lost | ADR-0007: All run state in memory only; no persistence path |
| TR-endless-011 | SpawnManager reads EndlessDifficultyConfig in Endless mode, NOT campaign DifficultyConfig | ADR-0001: GameManager.ActiveDifficultyProvider set to EndlessDifficultyProvider at entry |
| TR-endless-012 | Performance: wave 30+ with 19+ enemies must maintain <16.6ms PC, <33ms mobile | Not covered by ADR -- performance validation story |
| TR-endless-013 | EndlessSessionController coordinates wave loop: wave counter, draft timing, boss cycling, score | ADR-0007: EndlessSessionController class fully specified |
| TR-endless-014 | Death screen shows: waves cleared, total kills, combos discovered, class used | Not covered by ADR -- UI presentation story |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All acceptance criteria from GDD verified
- All Logic/Integration stories have passing tests
- All Visual/Feel/UI stories have evidence docs
- `EndlessWaveProvider` generating correct wave compositions per N2 formulas
- `EndlessDifficultyProvider` computing correct per-wave scaling values
- `EndlessSessionController` managing full run lifecycle (wave loop, draft timing, boss cycling, score)
- `EndlessWaveConfig` SO authored with boss cycle array and enemy pool
- Score persistence functional via LevelStats with per-class high scores
- Endless arena scene created (30x30, 6 spawn points, no traps)
- Main menu Endless Mode entry point wired
- Death screen showing run statistics
- Boss cycling verified through wave 60+
- Performance verified at wave 30+ within frame budget
- ADR-0001, ADR-0002, and ADR-0007 validation criteria all passing

## Next Step

Stories created. Run `/sprint-plan new` to schedule these stories into a sprint.
