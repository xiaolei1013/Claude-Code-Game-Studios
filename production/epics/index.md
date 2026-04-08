# Epics Index

Last Updated: 2026-04-08
Engine: Unity 6000.3.11f1

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [E2 Difficulty System](difficulty-system/EPIC.md) | Foundation (L0) | E2 Difficulty | [difficulty-system.md](../../design/gdd/difficulty-system.md) | Not created | Ready |
| [E5 Incomplete Skills](incomplete-skills/EPIC.md) | Foundation (L0) | E5 Incomplete Skills | N/A (code task) | Not created | Ready |
| [N1 Archer Character](archer-character/EPIC.md) | Core (L1) | N1 Archer | [archer-character.md](../../design/gdd/archer-character.md) | Not created | Ready |
| [E3 Boss Phase System](boss-phase-system/EPIC.md) | Core (L1) | E3 Boss Phases | [boss-phase-system.md](../../design/gdd/boss-phase-system.md) | 11 stories | Ready |
| [E4 Combo/Synergy](combo-synergy/EPIC.md) | Core (L1) | E4 Combos | [combo-synergy-expansion.md](../../design/gdd/combo-synergy-expansion.md) | Not created | Ready |
| [E1 Room Content](room-content/EPIC.md) | Content (L2) | E1 Room Content | [room-content.md](../../design/gdd/room-content.md) | Not created | Ready |
| [N2 Endless Mode](endless-mode/EPIC.md) | Content (L3) | N2 Endless | [endless-mode.md](../../design/gdd/endless-mode.md) | Not created | Ready |

## Dependency Graph

```
Layer 0 -- Foundation (no dependencies)
  +-- E2: Difficulty System      [ADR-0001]
  +-- E5: Incomplete Skills      [no ADR]

Layer 1 -- Core (depends on Layer 0)
  +-- N1: Archer Character       [ADR-0005]        <-- depends on E5
  +-- E3: Boss Phase System      [ADR-0004]        <-- depends on E2
  +-- E4: Combo/Synergy          [ADR-0003]        <-- depends on E5

Layer 2 -- Content (depends on Layer 1)
  +-- E1: Room Content           [ADR-0002, 0006]  <-- depends on N1, E3, E4, E2

Layer 3 -- Mode (depends on Layer 2)
  +-- N2: Endless Mode           [ADR-0001, 0002, 0007] <-- depends on E1, E2, E3
```

## Critical Path

E5 --> N1 --> E1 --> N2

## Bottleneck Systems

- **E5: Incomplete Skills** -- blocks Archer (N1) and Combos (E4)
- **E2: Difficulty System** -- blocks Boss Phases (E3), Room Content (E1), and Endless (N2)

## ADR Coverage Summary

| ADR | Status | Epic(s) |
|-----|--------|---------|
| ADR-0001 | Proposed | E2 Difficulty, N2 Endless |
| ADR-0002 | Proposed | E1 Room Content, N2 Endless |
| ADR-0003 | Proposed | E4 Combo/Synergy |
| ADR-0004 | Proposed | E3 Boss Phase System |
| ADR-0005 | Accepted | N1 Archer Character |
| ADR-0006 | Proposed | E1 Room Content |
| ADR-0007 | Proposed | N2 Endless Mode |
