# Story 001: Detection logic + RunSnapshot.synergy_id field

> **Epic**: class-synergy
> **Status**: Complete (implementation 2026-05-09 Sprint 21 S21-M1; story file 2026-05-10 audit-cascade closure)
> **Layer**: Gameplay
> **Type**: Logic
> **Manifest Version**: 2026-04-26

---

## Context

**GDD**: `design/gdd/class-synergy-system.md` §C.1 + §D.1 — synergy roster + detection predicate
**Requirements**: AC-CS-01..05 (detection accuracy), AC-CS-12 (save round-trip), AC-CS-18 (V1.5+ forward-compat unknown synergy_id)

**Governing ADR(s)**: ADR-0001 (mid-run reassignment policy — synergy is dispatch-time snapshotted, immutable for the run)
**ADR Decision Summary**: The active synergy for a run is determined ONCE at dispatch time and stored on `RunSnapshot.synergy_id`. Mid-run formation edits do NOT recompute the synergy. Detection itself is a pure function over the multiset of class_id strings — order-independent, no signals, no side effects.

**Engine**: Godot 4.6 | **Risk**: LOW (pure function, well-bounded)

**Control Manifest Rules (Gameplay Layer)**:
- **Required**: `detect_active_synergy` is pure — must NOT emit signals, must NOT mutate autoload state. Signal emission for live-preview is a separate caller surface (`notify_synergy_detected`).
- **Required**: V1.0+ forward-compat — unknown `synergy_id` strings (loaded from save files written by future versions) MUST resolve to 1.0 multipliers without crash or push_error.
- **Forbidden**: detection MUST NOT consider hero level, tier, or identity in V1.0 first-pass — composition only. (Future extension hook documented in GDD §C.5.)

---

## Acceptance Criteria

- [x] **AC-CS-01** — 3-Warrior formation returns `"steel_wall"`. Order of slots does NOT matter (sort-based comparison per D.1).
- [x] **AC-CS-02** — 3-Mage formation returns `"arcane_elite"`.
- [x] **AC-CS-03** — 1+1+1 mix (Warrior + Mage + Rogue) in any order returns `"triple_threat"`.
- [x] **AC-CS-04** — 2+1 mix (e.g., 2 Warriors + 1 Mage) returns `""` (no synergy in V1.0 first-pass).
- [x] **AC-CS-05** — Any empty slot returns `""` regardless of other slots' classes.
- [x] **AC-CS-12** — `RunSnapshot.synergy_id` persists verbatim across save/load round-trip (String preservation; not subject to JSON int/float typeof pitfall per `project_json_int_round_trip_typeof_pattern`).
- [x] **AC-CS-18** — V1.5+ forward-compat: unknown `synergy_id` (e.g., `"veteran_squad"` from a future save) returns 1.0 multiplier in resolver, no crash, no `push_error`.
- [x] Detection function is idempotent and pure (no signals fired, no state mutated). Safe to call every slot edit.

---

## Implementation Notes

- **Detection function**: `src/core/formation_assignment/formation_assignment.gd:298` — `detect_active_synergy(formation_snapshot: Dictionary) -> String`. Accepts either `{ "heroes": Array[Dictionary] }` (test path) or `{ "instance_ids": Array[int] }` (production path resolving via HeroRoster).
- **Synergy id constants**: `formation_assignment.gd:260-262` — `SYNERGY_STEEL_WALL`, `SYNERGY_ARCANE_ELITE`, `SYNERGY_TRIPLE_THREAT`. Stable strings; the resolver switch in DungeonRunOrchestrator and AC-CS-18 forward-compat depend on these.
- **RunSnapshot field**: `src/core/dungeon_run_orchestrator/run_snapshot.gd:148` — `var synergy_id: String = ""`. Default `""` makes pre-V1.0 saves load without migration (forward-compat).
- **to_dict / from_dict**: `synergy_id` is field 12 of 12 in the snapshot dict (per `run_snapshot_and_fsm_test.gd:325`); both directions covered.
- **Signal surface (separate from detection)**: `formation_assignment.gd:65` — `signal class_synergy_detected_signal(synergy_id: String)` + `notify_synergy_detected` helper at line 381. AudioRouter subscribes; detection function itself stays pure.

### Detection algorithm

```gdscript
detect_active_synergy(formation_snapshot: Dictionary) -> String:
    extract class_ids: Array[String] from snapshot (heroes path or instance_ids path)
    if any slot empty or count != 3 → return ""
    class_ids.sort()  # canonical multiset comparison
    match class_ids:
        ["mage", "mage", "mage"]      → "arcane_elite"
        ["warrior", "warrior", "warrior"] → "steel_wall"
        ["mage", "rogue", "warrior"]  → "triple_threat"
        _                              → ""
```

---

## Test Evidence

**Logic story — automated tests required (BLOCKING gate per `coding-standards.md` Test Evidence table).**

| Test File | AC Coverage |
|---|---|
| `tests/unit/formation_assignment/class_synergy_detection_test.gd` | AC-CS-01..05 + variants (any-order, missing-keys, two-slot, three-rogue) |
| `tests/unit/dungeon_run_orchestrator/run_snapshot_and_fsm_test.gd` | AC-CS-12 (synergy_id is field 12 of 12 in to_dict / from_dict) |
| `tests/unit/dungeon_run_orchestrator/class_synergy_perkill_wiring_test.gd:211` | AC-CS-18 (unknown synergy_id → baseline 1.0 multiplier) |
| `tests/unit/dungeon_run_orchestrator/class_synergy_formula_test.gd` | AC-CS-18 (formula resolver F path: unknown synergy_id) |

All tests pass under the project sweep that ran 2026-05-08 (1763/1763) and have been stable through subsequent epics.

---

## Closure Notes

- **Audit-cascade closure 2026-05-10**: implementation shipped during Sprint 21 S21-M1 work session (commits referenced inline in source file headers as "Sprint 21 S21-M1 (Class Synergy V1.0 first-pass, 2026-05-09)"). The story file was deferred — same pattern noted in `production/session-state/active.md` for tick-system/006 + dungeon-run-orchestrator/013. This story file closes that paperwork gap retrospectively.
- **No design deviations**: implementation matches GDD §C.1 + §D.1 verbatim.
- **No deferred work within Story 1 scope**: AC-CS-01..05, AC-CS-12, AC-CS-18 all closed. Stories 2 (formula extension), 3 (audio + locale), and 4 (UI badge) are tracked separately.
