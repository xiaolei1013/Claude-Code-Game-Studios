# Difficulty Curve — Trizzle / Shadow Quest v1.0

> **Status**: Draft
> **Author**: xiaolei + Claude
> **Last Updated**: 2026-04-17
> **References**: design/gdd/difficulty-system.md, DifficultyConfig_Normal.asset, DifficultyConfig_Hard.asset

## Design Intent

The difficulty curve serves one goal: make the player feel increasingly competent across Normal, then genuinely tested on Hard. Normal teaches the game; Hard proves mastery. The combo/draft system is the primary power-scaling tool the player has against rising difficulty — rooms should feel harder until a combo clicks and the player's damage spikes. That "combo discovery moment" is the fun hypothesis: difficulty exists to make power feel earned.

## Target Metrics

### Run Length

| Difficulty | Rooms 1-3 | Rooms 4-7 | Rooms 8-10 |
|------------|-----------|-----------|------------|
| **Normal** | 3-4 min | 5-7 min | 7-10 min |
| **Hard** | 4-5 min | 7-9 min | 9-12 min |

Median full-clear time (all 10 rooms, Normal): ~55-70 min across multiple sessions.
Hard adds ~30% to run time due to more enemies and faster pressure requiring more careful play.

### Target Death Rate (per room attempt)

| Room Range | Normal | Hard |
|------------|--------|------|
| Rooms 1-2 | 5-10% | 15-25% |
| Rooms 3-5 | 10-20% | 25-40% |
| Rooms 6-8 | 20-35% | 40-55% |
| Rooms 9-10 | 30-45% | 50-65% |

"Death rate" = percentage of attempts where the player dies before clearing the room. These are targets for a player who has cleared the previous room — not a first-time player encountering the entire game.

### Win-Rate Bands

| Difficulty | First Attempt | After 3 Attempts | Mastered |
|------------|---------------|-------------------|----------|
| **Normal** | 50-70% | 80-90% | 95%+ |
| **Hard** | 20-40% | 50-70% | 80-90% |

Normal should feel clearable on the first try for most rooms (skill expression through draft choices). Hard should require 2-3 attempts for mid-game rooms and feel like a genuine achievement to clear rooms 8-10.

## Difficulty Ramp by Room

### Normal Mode Curve

```
Pressure ▲
         │                                    ╭──── Room 10 (boss + full wave)
         │                              ╭─────╯
         │                        ╭─────╯         Rooms 8-10: full 5-axis
         │                  ╭─────╯               pressure, complex waves
         │            ╭─────╯
         │      ╭─────╯                           Rooms 4-7: mid-game ramp
         │  ╭───╯                                 new enemy types introduced
         │──╯
         │                                        Rooms 1-3: teaching rooms
         └─────────────────────────────────────▶ Room
           1    2    3    4    5    6    7    8    9   10
```

- **Rooms 1-3 (Teaching)**: Low enemy count (2-4 per wave), generous healing, slow pacing. Player learns combat, discovers first combo. Stat multiplier at baseline (1.0x). Goal: 90%+ clear rate on first attempt.
- **Rooms 4-7 (Ramp)**: Enemy count increases (4-7 per wave), new enemy types with varied behaviors. Healing still available but drafts matter more. Player should have 2-3 combos active. Goal: 60-80% first-attempt clear rate.
- **Rooms 8-10 (Peak)**: Full wave complexity (6-10 per wave), boss rooms with phase transitions, tight pacing. Combo synergies are the difference between clearing and dying. Goal: 50-70% first-attempt clear rate.

### Hard Mode Offset

Hard applies all five axes simultaneously on top of the Normal baseline:

| Axis | Effect on Curve |
|------|----------------|
| Stat 1.2-1.5x | Enemies survive ~30% longer, hit ~30% harder |
| Count 1.25x | +1-2 enemies per wave across all rooms |
| Heal 0.5x | Half as many healing drops — mistakes cost more |
| Pacing 0.75x | Waves arrive 25% faster — less breathing room |
| Reward 2.0x | Double gold/gems — incentivizes the harder path |

Combined effect: ~2.5-3x effective difficulty increase over Normal. The curve shape is the same (teaching → ramp → peak) but shifted upward. Rooms 1-2 on Hard feel like rooms 4-5 on Normal.

## Wave Composition Guidelines

| Room Tier | Waves | Enemies/Wave (Normal) | Enemies/Wave (Hard) | Elite Ratio |
|-----------|-------|-----------------------|----------------------|-------------|
| 1-3 | 3-4 | 2-4 | 3-5 | 0% |
| 4-7 | 4-5 | 4-7 | 5-9 | 10-20% |
| 8-10 | 5-6 | 6-10 | 8-13 | 20-30% |

Boss rooms (5 and 10) have a final boss wave after clearing all standard waves. Boss is exempt from count scaling (R-022, Edge Case 3).

## Healing Economy

| Room Tier | Heal Drops/Room (Normal) | Heal Drops/Room (Hard) | Player HP Pool |
|-----------|--------------------------|------------------------|----------------|
| 1-3 | 3-4 | 1-2 | Comfortable surplus |
| 4-7 | 2-3 | 1-1.5 | Roughly break-even |
| 8-10 | 1-2 | 0.5-1 | Deficit — must play clean |

Hard mode rooms 8-10 should average less than 1 heal drop per room. This is intentional: the player must rely on combo-based sustain (VampiricStrikes, defensive combos) or perfect play.

## Reward Curve

| Room | Gold/Clear (Normal) | Gold/Clear (Hard) | Gems/Clear (Normal) | Gems/Clear (Hard) |
|------|--------------------|--------------------|---------------------|---------------------|
| 1 | ~50 | ~100 | 0 | 0 |
| 5 (boss) | ~200 | ~400 | 5 | 10 |
| 10 (boss) | ~500 | ~1000 | 15 | 30 |

Hard rewards compensate ~60-70% of extra time/effort. Hard is not the most efficient farming path — it's the prestige path. Players who want raw gold per hour should speed-run Normal. Players who want the challenge and the flex should play Hard.

## Tuning Validation Checklist

Before shipping, validate these with playtesting:

- [ ] Room 1 Normal clears in under 4 minutes for a new player
- [ ] Room 5 Normal boss is beatable without any combos active (skill floor)
- [ ] Room 5 Normal with 2+ combos feels noticeably easier (combo payoff)
- [ ] Room 10 Hard requires 2+ attempts for an experienced player (ceiling)
- [ ] Hard mode heal scarcity feels tense but not hopeless (at least 1 heal per 2 rooms)
- [ ] Reward 2x on Hard feels "worth it" but not mandatory for progression
- [ ] No room feels like a pure stat check — player skill (dodging, combo use) always matters
- [ ] Death feels fair ("I made a mistake") not cheap ("that was unavoidable")
