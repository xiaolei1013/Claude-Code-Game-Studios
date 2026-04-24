---
name: Lantern Guild project context
description: Core facts about the Lantern Guild game project — locked contracts, design decisions, and GDD status
type: project
---

Session-based cozy fantasy idle-clicker on Godot 4.6 + GDScript. Player runs a hero guild, dispatches class-based formations into dungeons, returns to accumulated gold. Core tactical verb: class-vs-enemy matchup at formation assignment (not mid-combat).

**Why:** indie game in pre-production; 4 GDDs complete as of 2026-04-18; building out remaining 21 MVP GDDs.

**How to apply:** Reference locked contracts below before proposing any stat or formula. Never contradict Economy GDD formulas.

## Locked contracts (from Economy GDD #4)
- `recruit_cost = floor(BASE_RECRUIT[tier] × 1.8^copies_owned)`
- `level_cost = floor(BASE_LEVEL[tier] × 1.6^(current_level - 1))`, cap 15
- `BASE_RECRUIT[tier_1]=150`, `BASE_RECRUIT[tier_2]=8000`
- `BASE_LEVEL[tier_1]=40`, `BASE_LEVEL[tier_2]=600`
- `formation_strength_factor = clamp(1.0 + (avg_hero_level - 1) × 0.2, 1.0, 3.0)`
- `MATCHUP_GOLD_MULTIPLIER = 1.5` on kill bonus
- BASE_DRIP by floor: 2, 4, 7, 12, 20 (floors 1-5)

## Pillars
1. Respect the Player's Time — offline accrual; no FOMO
2. Every Class Feels Distinct — silhouette, role, counter niche non-overlapping; legible at 32px
3. Matchup Is a Decision, Not a Reflex — formation assignment layer; 1.5× kill bonus
4. HD-2D Pixel Pride — art carries emotional weight

## GDD status (2026-04-18)
- #1 Game Time & Tick System: Designed (pending review) — `design/gdd/game-time-and-tick.md`
- #2 Data Loading System: Designed — `design/gdd/data-loading.md`
- #3 Save/Load System: Designed — `design/gdd/save-load-system.md`
- #4 Economy System: Designed — `design/gdd/economy-system.md`
- #5 Hero Class Database: Designed (pending review) — `design/gdd/hero-class-database.md`
- #6 Enemy Database: In Progress (C,D,E,G drafted; A,B,F,H stubs) — `design/gdd/enemy-database.md`
- #7+ Biome DB, Hero Roster, Matchup Resolver, Combat Resolution: Not Started

## Taxonomy decisions (locked)
- Single-tag counter: each class has ONE counter_archetype string
- Linear stat scaling (base + per_level × (level-1))
- Level cap: 15
- Archetype constants: bruiser, caster, armored (MVP); beast, construct, incorporeal (V1.0)
- Role taxonomy: tank, striker, precision, support, ranged, commander

## MVP class stat blocks (locked in hero-class-database.md)
- Warrior: HP 120, ATK 12, SPD 6; per_level: HP 17, ATK 2, SPD 1; counter: bruiser
- Mage: HP 70, ATK 20, SPD 10; per_level: HP 10, ATK 3, SPD 1; counter: caster
- Rogue: HP 55, ATK 14, SPD 16; per_level: HP 8, ATK 2, SPD 2; counter: armored

## MVP enemy stat blocks (drafted in enemy-database.md — pending review)
- Hollow Brute (bruiser, T1): HP 52, ATK 8, SPD 3, is_boss: false — ease-in floor-1 anchor
- Glowmoth (caster, T1): HP 60, ATK 11, SPD 5, is_boss: false
- Shellback (armored, T1): HP 72, ATK 9, SPD 2, is_boss: false
- Elder Boar (bruiser, T2): HP 195, ATK 18, SPD 4, is_boss: false
- Moss Druid (caster, T2): HP 185, ATK 24, SPD 6, is_boss: false
- Vined Knight (armored, T2): HP 225, ATK 20, SPD 3, is_boss: false
- Thorn Guardian (bruiser, T3 elite): HP 680, ATK 32, SPD 5, is_boss: false
- Ancient Rootking (bruiser, T3 boss): HP 2200, ATK 45, SPD 3, is_boss: true
- BASE_KILL: tier_1=15, tier_2=35, tier_3=80 gold (inherited from Economy GDD)
