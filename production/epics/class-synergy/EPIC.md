# Epic: Class Synergy V1.0 (first-pass)

> **Status**: Stories 1-3 Complete (audit-cascade closure 2026-05-10); Story 4 Ready
> **Layer**: Gameplay
> **GDD**: `design/gdd/class-synergy-system.md` (#32)
> **Authored**: 2026-05-10 retrospectively to formalize Sprint 21 S21-M1/S1/S2 implementation work that shipped without per-story files (audit-cascade pattern)

---

## Scope

Implements the V1.0 first-pass class synergy system per the APPROVED GDD: 3 composition synergies (Steel Wall, Arcane Elite, Triple Threat), live-preview detection at formation_assignment, dispatch-time snapshot, per-kill multiplier application, audio cues, localization, and UI badge.

## Stories

| # | Title | Type | Status |
|---|---|---|---|
| 1 | Detection logic + RunSnapshot.synergy_id field | Logic | Complete (2026-05-09; story file 2026-05-10) |
| 2 | attribute_kill_gold + attribute_kill_xp synergy_multiplier wiring | Logic | Complete (2026-05-09; story file 2026-05-10) |
| 3 | Audio cues + localization keys | Integration | Complete (2026-05-09 + 2026-05-10 audio; story file 2026-05-10) |
| 4 | UI badge wiring on formation_assignment screen + reduce-motion variant | UI | Complete (2026-05-10 — see story-004) |

## Cross-references

- **Sibling epic**: Prestige System V1.0 (#31) — also progression-tier, ships in V1.0 release block
- **F.3 cross-GDD amendments**: deferred — 8 GDDs need bidirectional dependency mention (per GDD F.3); batch this when Story 4 lands
- **Per-synergy ≤+50% cap**: AC-CS-16 enforces via static analysis of `economy_config.tres`
- **Forward-compat**: AC-CS-18 — unknown synergy_ids resolve to 1.0, no crash, no migration required

## Test surface

| Test file | Stories covered | Test count (current) |
|---|---|---|
| `tests/unit/formation_assignment/class_synergy_detection_test.gd` | Story 1 | ~10 (AC-CS-01..05 + extras) |
| `tests/unit/dungeon_run_orchestrator/class_synergy_perkill_wiring_test.gd` | Story 2 | ~6 (AC-CS-06..11) |
| `tests/unit/dungeon_run_orchestrator/class_synergy_formula_test.gd` | Story 2 | (formula resolver coverage) |
| `tests/unit/dungeon_run_orchestrator/run_snapshot_and_fsm_test.gd` | Story 1 (round-trip) | (synergy_id is field 12 of 12) |
| `tests/unit/audio_router/audio_router_signal_handlers_test.gd` | Story 3 | +4 (added 2026-05-10) |

## Outstanding (post-Story-4)

- F.3 cross-GDD amendments (8 GDDs) — single batch pass when Story 4 lands
- AC-CS-19 balance regression test (100-run simulation) — defer to V1.0 playtest data
