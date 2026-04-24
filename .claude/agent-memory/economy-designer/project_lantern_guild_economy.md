---
name: Lantern Guild Economy System — locked decisions and open flags
description: Core economy parameters and design decisions locked for Lantern Guild MVP; open calibration flags for playtest
type: project
---

Single currency (Gold, int64). No second currency, no gacha shards in MVP. Cost curve: geometric.

**Why:** User locked these constraints before economy GDD was drafted. Anti-pillars explicitly prohibit gacha and real-money accelerators.

**How to apply:** Never propose a second currency or probabilistic unlock system for MVP. All future GDDs referencing gold must use values consistent with the formulas in `design/gdd/economy-system.md`.

## Locked numbers (as of 2026-04-18)

- BASE_DRIP per floor: 2 / 4 / 7 / 12 / 20 (floor 5 = exactly 10× floor 1)
- MATCHUP_GOLD_MULTIPLIER: 1.5× — applied to kill bonuses only, not drip
- BASE_RECRUIT[tier_1]: 150 gold; BASE_RECRUIT[tier_2]: 8 000 gold (recommended starting value — 2 500 in doc is illustration only)
- RECRUIT_RATIO: 1.8; LEVEL_RATIO: 1.6; LEVEL_CAP: 15
- Floor-clear bonuses: 500 / 1 200 / 3 000 / 7 500 / 18 000 gold
- GOLD_SANITY_CAP: 1 T (1e12) gold
- Display thresholds: K at 1 000; M at 1 000 000; B at 1 000 000 000; T at 1 000 000 000 000

## Open calibration flags

1. BASE_RECRUIT[tier_2] = 2 500 in D.6 milestone table is explicitly flagged as too low. Recommended: 8 000. Confirm before playtest build.
2. formation_strength_factor formula (1.0 + (avg_level - 1) * 0.2) is an economy-side approximation pending Hero Roster and Combat Resolution GDDs.
3. Kill frequency assumption (1/10 sec) is superseded. Combat Resolution D.7 (locked 2026-04-19 Pass 1) sets F3 cadence at 85s/5 enemies = 17s/kill. Economy D.6 milestone table is WRONG: at BASE_DRIP[3]=7 and formation_strength_factor≈1.8, F3 earns ~240g/tick = 8,640g/min from drip alone. The 8,000g Tier-2 threshold is reachable in ~33s of active F3 play, NOT Day 3–4. Economy D.6 milestone table needs full re-validation against Combat-locked kill cadence BEFORE MVP playtest. This is BLOCKING.
4. LOSING_RUN_LOOT_FACTOR scope for floor-clear bonus is unresolved. Combat Rule 9 and entities.yaml say "all gold" (implies clear bonus is halved); Economy C.2.3 and H-03 treat clear bonus as unconditional one-shot. Policy decision required before Orchestrator GDD #13 is authored. Options: (A) exclude floor-clear from LOSING_RUN_LOOT_FACTOR (milestone is always full); (B) include it (document explicitly). One-shot nature makes this non-recoverable for players if wrong.
5. F5 boss HP cascade: ancient_rootking.base_hp = 2200 is too low (77.65s clear vs 170s Biome target). Combat I.2 recommends 4820. BUT: (a) the 170s target may be a phantom from a superseded cadence model; (b) F4→F5 HP jump becomes ×2.36 which may feel like a wall. Decision requires explicit experiential target (e.g., "F5 should take N× longer than F4"). 7 documents affected (Enemy DB C.3 + G.1 + G.3, Biome DB F5, entities.yaml floor_total_hp range + SPEED_BASE notes, Combat D.7 + D.4, Enemy DB H-08 AC bounds). entities.yaml ancient_rootking.referenced_by is missing biome-dungeon-database.md and combat-resolution.md — must add before any HP cascade.

## Pass 2 review status (2026-04-20)

Combat Resolution GDD #11 Pass 2 economy re-review complete. Remaining BLOCKING items:
- Economy D.6 re-validation (item 3 above)
- F5 HP cascade with explicit experiential target decision (item 5)
- entities.yaml ancient_rootking.referenced_by update (prerequisite for item 5)
Rule 7/Economy C.2.3 reconciliation is logically resolved (H-03 covers lifetime guard); one documentation gap remains (UI/UX for re-clear fanfare on repeat dispatches — document in Orchestrator GDD #13).

## Tuning policy

Patch changes to knobs are forward-only (no retroactive refunds). Extreme changes (e.g., doubling costs) require a save-migration compensation gold grant.

## Registry entries added

Formulas: drip_per_tick, kill_bonus, recruit_cost, level_cost
Constants: GOLD_SANITY_CAP, MATCHUP_GOLD_MULTIPLIER, LEVEL_CAP, RECRUIT_RATIO, LEVEL_RATIO
