# Epic: Combo/Synergy Expansion

> **Layer**: Core (Layer 1)
> **GDD**: design/gdd/combo-synergy-expansion.md
> **Architecture Module**: E4 Combos -- Gameplay Layer
> **Governing ADRs**: ADR-0003
> **Status**: Stories Created
> **Stories**: 9 stories (see table below)

## Overview

The Combo/Synergy Expansion transforms skill drafting from "pick good skills" into "build toward devastating combinations." It extends the existing `ComboDatabase` (currently 5 hardcoded Mage-only pairs with no gameplay effect) into a full combo-reward system with 18 combo effects across three categories: 5 Mage-exclusive, 6 Archer-exclusive, and 7 Universal. Architecturally, `ComboEffect` is an abstract ScriptableObject base class with `Activate(PlayerController)`, `Deactivate()`, and `OnTrigger(TriggerContext)` methods. Four trigger conditions (OnDraft, OnSkillUse, OnKill, Passive) are implemented via event subscription -- not per-frame polling -- staying within the < 0.5 ms/frame budget. `ComboRegistry.CheckCombos()` activates effects on discovery and deactivates on run end. `TriggerContext` is a stack-allocated readonly struct for zero heap allocation. Depends on E5 (Incomplete Skills) for shared skill pool readiness.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: ComboEffect ScriptableObject Architecture | 18 combo effects are concrete `ScriptableObject` subclasses; triggers are event-subscribed (not polled); `Activate`/`Deactivate` lifecycle guarantees clean run boundaries; < 0.5 ms/frame budget. `TriggerContext` readonly struct for zero GC. `IComboRegistry` interface for DraftRunController. | LOW -- uses abstract ScriptableObject, C# events, SerializeField; all stable pre-cutoff APIs |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|-------------|
| TR-combo-001 | ComboEffect abstract ScriptableObject base class with Activate, Deactivate, OnTrigger | ADR-0003: Abstract `ComboEffect : ScriptableObject` with exactly these methods |
| TR-combo-002 | 18 concrete ComboEffect implementations: 5 Mage, 6 Archer, 7 Universal | ADR-0003: Each maps to one concrete subclass asset |
| TR-combo-003 | 4 trigger conditions (OnDraft, OnSkillUse, OnKill, Passive) via event subscription, not polling | ADR-0003: Subscription pattern per condition type specified |
| TR-combo-004 | ComboRegistry.CheckCombos() runs after each draft pick; activates ComboEffect on discovery | ADR-0003: IComboRegistry.CheckCombos() with Activate() call on detection |
| TR-combo-005 | Combo discovery UI: gold text flash (Cinzel font, center screen, 2s fade) with distinct SFX | Not covered by ADR -- presentation story |
| TR-combo-006 | discoveredFlag persisted per-combo in save data; tracks lifetime discovery | ADR-0003: discoveredFlag on ComboDefinition; save data serialization |
| TR-combo-007 | Combos reset on run end; ComboEffect.Deactivate() called | ADR-0003: DeactivateAllCombos() on run end; clean asset state |
| TR-combo-008 | Executioner combo: instant kill on slowed enemies below 25% HP, MUST be boss-immune | ADR-0003: ExecutionerComboEffect checks EnemyData.isBoss |
| TR-combo-009 | Elemental Storm: 30% bonus on Burn+Freeze targets, resets after 5 hits (resolved B4) | ADR-0003: Per-target hit counter with _hitLimit = 5 |
| TR-combo-010 | Performance budget: < 0.5ms/frame total for all active combo effects | ADR-0003: Event-driven, no per-frame polling; estimated < 0.05 ms/frame |
| TR-combo-011 | TriggerContext struct is stack-allocated (zero heap allocation per trigger event) | ADR-0003: `readonly struct TriggerContext` specified |
| TR-combo-012 | ComboDefinition extended with comboCategory, triggerCondition, triggerEffect SO reference, discoveredFlag | ADR-0003: All four fields specified with types |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All acceptance criteria from GDD verified
- All Logic/Integration stories have passing tests
- All Visual/Feel/UI stories have evidence docs
- `ComboEffect` base class and all 18 concrete subclass assets created
- `ComboDatabase.asset` populated with all 18 ComboDefinition entries
- `ComboRegistry.CheckCombos()` activates effects on discovery
- All effects properly Deactivate on run end (no state leak between runs)
- Executioner is boss-immune; Elemental Storm respects 5-hit cap
- Combo discovery UI functional with gold flash and SFX
- Performance verified < 0.5 ms/frame with all combos active
- ADR-0003 validation criteria all passing

## Stories

| # | Story | Type | Priority | Size | Dependencies | Status |
|---|-------|------|----------|------|-------------|--------|
| 001 | [Extend ComboDefinition](001-extend-combo-definition.md) | Logic | P0 | M | None | Ready |
| 002 | [ComboEffect Base Class](002-combo-effect-base-class.md) | Logic | P0 | M | 001 | Ready |
| 003 | [Mage Combo Effects (5)](003-mage-combo-effects.md) | Logic | P1 | L | 001, 002 | Ready |
| 004 | [Archer Combo Effects (6)](004-archer-combo-effects.md) | Logic | P1 | L | 001, 002; soft: N1 | Ready |
| 005 | [Universal Combo Effects (7)](005-universal-combo-effects.md) | Logic | P1 | L | 001, 002; soft: E3 | Ready |
| 006 | [Combo Discovery UI](006-combo-discovery-ui.md) | UI | P1 | M | 002 | Ready |
| 007 | [ComboDatabase Population](007-combo-database-population.md) | Config | P1 | M | 001, 003, 004, 005 | Ready |
| 008 | [Discovery Persistence](008-discovery-persistence.md) | Logic | P1 | S | 002 | Ready |
| 009 | [Combo System Tests](009-combo-system-tests.md) | Logic | P0 | M | 001-005, 007 | Ready |

### Dependency Graph

```
001 Extend ComboDefinition
 |
 v
002 ComboEffect Base Class
 |
 +----+----+----+----+
 |    |    |    |    |
 v    v    v    v    v
003  004  005  006  008
(Mage)(Arch)(Uni)(UI)(Save)
 |    |    |
 +----+----+
      |
      v
     007 ComboDatabase Population
      |
      v
     009 Combo System Tests
```

### Critical Path

001 -> 002 -> 003/004/005 (parallel) -> 007 -> 009

Stories 006 (UI) and 008 (Persistence) are off the critical path and can be done in parallel with the effect implementations.

## Next Step

Run `/sprint-plan new` to schedule these stories into sprints, or `/story-readiness 001-extend-combo-definition.md` to validate the first story before implementation.
