# Story 002: attribute_kill_gold + attribute_kill_xp synergy_multiplier wiring

> **Epic**: class-synergy
> **Status**: Complete (implementation 2026-05-09 Sprint 21 S21-S1; story file 2026-05-10 audit-cascade closure)
> **Layer**: Gameplay
> **Type**: Logic
> **Manifest Version**: 2026-04-26

---

## Context

**GDD**: `design/gdd/class-synergy-system.md` §C.3 + §D.2 + §D.3 — multiplicative effect application
**Requirements**: AC-CS-06..11 (per-kill multiplier behavior), AC-CS-13 (mid-run reassignment immutability), AC-CS-16 (per-synergy ≤+50% cap)

**Governing ADR(s)**: ADR-0001 (mid-run reassignment — synergy_id immutable), ADR-0002 (LOSING_RUN_LOOT_FACTOR ordering in formula composition)
**ADR Decision Summary**: Synergy multipliers compose multiplicatively into the existing `attribute_kill_gold` formula (and the new `attribute_kill_xp` formula). The composition order is: `BASE_KILL × matchup × loot_factor × synergy_mult`. Steel Wall is conditional on `archetype == "bruiser"`; Triple Threat is unconditional gold; Arcane Elite is unconditional XP and 1.0× for gold.

**Engine**: Godot 4.6 | **Risk**: LOW (formula extension; numeric checks)

**Control Manifest Rules (Gameplay Layer)**:
- **Required**: per-synergy multipliers MUST be ≤ 1.5 (cozy register hard floor per OQ-32-6 + AC-CS-16). Static-analysis CI test enforces against `economy_config.tres`.
- **Required**: unknown synergy_id (V1.5+ saves loaded by V1.0 build) MUST resolve to 1.0 baseline, no crash.
- **Required**: Steel Wall is conditional on archetype — non-bruiser kills get baseline gold even when `synergy_id == "steel_wall"`.
- **Forbidden**: synergy multipliers MUST NOT compound across the per-synergy cap. Compound product (matchup × loot × synergy × prestige) IS allowed and bounded by each factor's own cap (per AC-CS-16 scope-clarification note added 2026-05-10).

---

## Acceptance Criteria

- [x] **AC-CS-06** — Steel Wall + Tier-1 Bruiser kill (advantaged matchup, not losing) → `floori(BASE_KILL[1] × 1.5 × 1.0 × 1.25)`. Steel Wall multiplier applies.
- [x] **AC-CS-07** — Steel Wall + Tier-1 Skirmisher kill (same other params) → `floori(BASE_KILL[1] × 1.5 × 1.0 × 1.0)`. Steel Wall does NOT apply to non-bruiser kills.
- [x] **AC-CS-08** — Triple Threat applies 1.15× unconditionally to every kill regardless of tier, archetype, or matchup.
- [x] **AC-CS-09** — Arcane Elite gold pathway: returns 1.0× (Arcane Elite is XP-only). Verified by parity test against the no-synergy gold output.
- [x] **AC-CS-10** — Arcane Elite XP pathway: 1.20× multiplier applied. Tier-2 kill → `floori(BASE_XP_PER_KILL × 2 × 1.20)` = 24.
- [x] **AC-CS-11** — synergy_id == "" → both gold and XP at baseline; functionally identical to MVP path.
- [x] **AC-CS-13** — Mid-run formation reassignment does NOT recompute synergy. `RunSnapshot.synergy_id` stays as snapshotted at dispatch for the run's full duration.
- [x] **AC-CS-16** (static-analysis side) — `_resolve_synergy_*_multiplier` returns ≤ 1.5 for all known synergy_ids; CI test asserts that `STEEL_WALL_GOLD_MULT`, `TRIPLE_THREAT_GOLD_MULT`, `ARCANE_ELITE_XP_MULT` are all ≤ 1.5 in `economy_config.tres`.

---

## Implementation Notes

- **Resolver functions**: `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd:1170` — `_resolve_synergy_gold_multiplier(synergy_id, archetype)`; line 1195 — `_resolve_synergy_xp_multiplier(synergy_id)`. Pure switch over synergy_id; archetype branch only relevant for Steel Wall.
- **Per-kill loop**: `dungeon_run_orchestrator.gd:1132` (gold) and `:1160` (XP) call the resolvers and multiply into the final `floori()` result.
- **Constants source**: `assets/data/economy/economy_config.tres` — `STEEL_WALL_GOLD_MULT = 1.25`, `TRIPLE_THREAT_GOLD_MULT = 1.15`, `ARCANE_ELITE_XP_MULT = 1.20`, `BASE_XP_PER_KILL = 10`.
- **Mid-run immutability**: enforced by NOT calling `detect_active_synergy` anywhere after dispatch. The orchestrator's `_process_kill_events` reads `run_snapshot.synergy_id` directly — frozen at dispatch via `snapshot_synergy_for_run`.

### Formula composition

```
attribute_kill_gold(tier, advantaged, losing_run, synergy_id, archetype):
    matchup_mult   = 1.5 if advantaged else 1.0
    loot_factor    = 0.5 if losing_run else 1.0
    synergy_mult   = _resolve_synergy_gold_multiplier(synergy_id, archetype)
    return floori(BASE_KILL[tier] × matchup_mult × loot_factor × synergy_mult)

attribute_kill_xp(tier, synergy_id):
    synergy_mult   = _resolve_synergy_xp_multiplier(synergy_id)
    return floori(BASE_XP_PER_KILL × tier × synergy_mult)
```

---

## Test Evidence

| Test File | AC Coverage |
|---|---|
| `tests/unit/dungeon_run_orchestrator/class_synergy_perkill_wiring_test.gd` | AC-CS-06..11 (Steel Wall conditional, Triple Threat unconditional, Arcane Elite XP-only, baseline parity) |
| `tests/unit/dungeon_run_orchestrator/class_synergy_formula_test.gd` | Formula resolver coverage (paths A-F including unknown synergy_id) |

---

## Closure Notes

- **Audit-cascade closure 2026-05-10**: implementation shipped Sprint 21 S21-S1 same session as Story 1; story file deferred. This file closes the paperwork gap.
- **AC-CS-13 verification**: indirect — covered by the orchestrator's per-kill loop reading `run_snapshot.synergy_id` directly without recomputing. Mid-run reassignment changes the formation but NOT the snapshot's synergy_id field. No explicit "edit-then-verify-synergy-unchanged" test, but the architectural invariant is enforced by code structure (no `detect_active_synergy` call sites after dispatch). Optional: add an integration test that mid-run-edits and confirms the next kill still uses the original synergy_id.
- **AC-CS-16 dynamic check**: the resolver itself does NOT clamp at 1.5 — it returns whatever the constants are. The clamp lives in the static-analysis CI test (per the GDD's Tuning Knobs G section). If a designer raises a constant past 1.5 in the .tres, the CI fails at build, not at runtime. This is intentional — the cap is a design contract enforced at the data layer, not a runtime guard.
