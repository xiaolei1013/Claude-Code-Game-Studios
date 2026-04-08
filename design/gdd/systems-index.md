# Systems Index — Trizzle / Shadow Quest

**Created**: 2026-03-29
**Game**: Medieval Fantasy Action Roguelite (Hit & Run)
**Engine**: Unity 6000.3.11f1 (URP)
**Target**: PC (Steam) full release, expanding from shipped demo

---

## v1.0 Scope Summary

- 2 playable characters: Mage (existing) + Archer (new)
- 10 rooms with 2 difficulty levels (Normal / Hard)
- Endless Mode (scaling waves, score = waves cleared)
- Roguelite draft/combo system (expanding existing prototype)
- Achievements (P2)
- **Cut from GDD**: Equipment system, Forging/Crafting, Talent Tree (meta-progression)

---

## Systems Enumeration

### Already Implemented (No design work needed)

| ID | System | Category | Files | Status |
|----|--------|----------|-------|--------|
| D1 | Core Combat | Gameplay | 22 files (DamageCalculator, weapons, projectiles) | Approved |
| D2 | Health & Death | Gameplay | Health.cs, death/respawn flow | Approved |
| D3 | Status Effects | Gameplay | 27 states in StateMachine/ (Burn, Frozen, Stun, etc.) | Approved |
| D4 | Skill System | Gameplay | 125+ skill implementations, BaseSkill, upgrades | Approved |
| D5 | Enemy AI | Gameplay | Custom BehaviourTree, 30 enemy controllers | Approved |
| D6 | Trap System | Level | 14 trap types (fire, spikes, projectile, etc.) | Approved |
| D7 | Roguelite Draft | Meta | DraftRunController, RunDraftPanel, draft weighting | Approved |
| D8 | Loot & Drops | Economy | DropItem system, chests, drop behaviors | Approved |
| D9 | Shop | Economy | ShopItem, in-app purchases, gem/gold shops | Approved |
| D10 | Currency | Economy | Gold, Gems, Energy via PurchaseManager | Approved |
| D11 | Save/Load | Infrastructure | CloudServiceManager, save migration scaffolding | Approved |
| D12 | Localization | Infrastructure | 11 locales, CJK fonts, Unity Localization | Approved |
| D13 | Audio | Presentation | AudioManager, AudioDatabase | Approved |
| D14 | UI Framework | Presentation | 101+ UGUI components, PC/Mobile split | Approved |

### Systems to Design & Build

| ID | System | Category | Type | Priority | GDD Status |
|----|--------|----------|------|----------|------------|
| E2 | Difficulty System | Gameplay | Expand | P0 | Designed |
| E5 | Incomplete Skills | Gameplay | Expand | P0 | In Progress |
| N1 | Archer Character | Gameplay | New | P1 | Designed |
| E3 | Boss Phase System | Gameplay | Expand | P1 | Designed |
| E4 | Combo/Synergy Expansion | Gameplay | Expand | P1 | Designed |
| E1 | Room Content | Content | Expand | P1 | Designed |
| N2 | Endless Mode | Gameplay | New | P1 | Designed |
| N3 | Achievements | Meta | New | P2 | Not Started |

---

## Dependency Map

```
Layer 0 — Foundation (no dependencies)
  ├── E2: Difficulty System
  └── E5: Incomplete Skills

Layer 1 — Core (depends on Layer 0)
  ├── N1: Archer Character        ← depends on: E5
  ├── E3: Boss Phase System       ← depends on: E2
  └── E4: Combo/Synergy Expansion ← depends on: E5

Layer 2 — Content (depends on Layer 1)
  └── E1: Room Content            ← depends on: N1, E3, E4, E2

Layer 3 — Mode (depends on Layer 2)
  └── N2: Endless Mode            ← depends on: E1, E2

Layer 4 — Meta (depends on all gameplay)
  └── N3: Achievements            ← depends on: N1, N2, E1
```

### Bottleneck Systems (high fan-out)
- **E5: Incomplete Skills** — blocks Archer, Combos
- **E2: Difficulty System** — blocks Bosses, Rooms, Endless

### Leaf Systems (low risk, design last)
- **N3: Achievements** — depends on everything, impacts nothing

---

## Recommended Design Order

| Order | System ID | System | Rationale |
|-------|-----------|--------|-----------|
| 1 | E2 | Difficulty System | Small design surface, defines scaling rules everything else uses. What changes between Normal and Hard? Enemy HP multiplier? More traps? Faster waves? |
| 2 | E5 | Incomplete Skills | Not a GDD — code audit and completion task. 15+ skills (ArcaneRebound, IcePond, IceWall, FrostFocus, ExecutionFlow, Chain, Multicast) need TODO resolution. |
| 3 | N1 | Archer Character | Major content pillar. Design unique base skills (arrow rain? dodge roll?), stats tuning, which existing skills transfer, archer-specific upgrades. |
| 4 | E3 | Boss Phase System | Design multi-phase boss behavior. HP thresholds, phase abilities (enrage/summon/AoE), per-boss design for each chapter. |
| 5 | E4 | Combo/Synergy Expansion | Expand ComboDatabase with archer combos, cross-class combos. Design synergy hints and discovery rewards. |
| 6 | E1 | Room Content | 10 rooms x 2 difficulties. Layout, enemy composition, trap placement, boss assignment. Biggest content deliverable. |
| 7 | N2 | Endless Mode | Scaling wave formula, enemy introduction curve, score/leaderboard, when new enemy types appear, difficulty ramp rate. |
| 8 | N3 | Achievements | Steam achievement list, in-game tracking, unlock triggers. Define after all gameplay is playable. |

---

## High-Risk Systems

| System | Risk | Mitigation |
|--------|------|------------|
| N1: Archer Character | New class — most unknowns. Needs unique skills, animations, balancing against mage. | Prototype archer base skills early. Reuse existing framework as much as possible. |
| E1: Room Content | Largest deliverable. 10 rooms x 2 difficulties = 20 room configs. | Design room templates/archetypes first, then fill in specifics. Reuse trap/enemy building blocks. |
| N2: Endless Mode | Scaling balance — too easy gets boring, too hard feels unfair. | Playtest early with placeholder scaling. Tune based on average clear times. |

---

## Progress Tracker

| System | GDD | Implementation | Tests | Polish |
|--------|-----|----------------|-------|--------|
| E2: Difficulty System | [Designed](difficulty-system.md) | - | - | - |
| E5: Incomplete Skills | Code Fixed | 2 done, 3 need prefabs | - | - |
| N1: Archer Character | [Designed](archer-character.md) | - | - | - |
| E3: Boss Phase System | [Designed](boss-phase-system.md) | - | - | - |
| E4: Combo/Synergy | [Designed](combo-synergy-expansion.md) | - | - | - |
| E1: Room Content | [Designed](room-content.md) | - | - | - |
| N2: Endless Mode | [Designed](endless-mode.md) | - | - | - |
| N3: Achievements | Not Started | - | - | - |
