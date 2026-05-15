# Sprint 20 Scaffolded-but-Unwired Audit

> **Sprint**: 20 / S20-M1
> **Date**: 2026-05-15
> **Author**: claude-code
> **Triggered by**: Sprint 18 retro action #1 (twice-deferred: → S19-S1 → S20-M1; non-negotiable now)
> **Per project memory**: `feedback_scaffolded_but_unwired_pattern`
>
> **Verdict**: **2 confirmed ghosts found** (low severity, no player impact); 1 explicit class of V1.1-tagged deferrals confirmed (intentional, well-documented); ~12 other suspicious-grep hits investigated and confirmed as intentional MVP-scope documentation, not unwired code.

---

## Why this audit exists

Sprint 18 surfaced two critical bugs that the entire ~2200-test suite missed:

1. **LOSING-run wiring (PR #100)** — `hp_bonus_factor = 1.0  # provisional` was the literal scaffolding marker. Dead code for 11 sprints.
2. **Floor.enemy_list materialization (PR #101)** — `# for MVP; other cross-refs (Floor.enemy_list[].enemy_id → EnemyData)` smoking-gun comment at `data_registry.gd:983`. Materialization step deferred during MVP and never landed.

Both bugs share a pattern: feature LOOKS wired in code, but a critical wiring step is missing or defaulted to a no-op constant. The test suite checks each piece in isolation; the integration is what's broken. Project memory `feedback_scaffolded_but_unwired_pattern` records this as the dominant bug class on the project.

This audit grep-hunts for the same pattern signatures across `src/` before Sprint 20's implementation work compounds on top of any latent ghosts.

---

## Audit methodology

Patterns searched across `src/**/*.gd`:

1. `# provisional` (the LOSING bug signature)
2. `# MVP` (placeholder/deferred markers)
3. `# stub`
4. `# placeholder`
5. `# defer` / `# deferred`
6. `# TODO` / `# FIXME`
7. `= 1.0  #` (literal hardcoded-constant-with-comment, the LOSING signature)
8. `for MVP` (in-docstring deferral language)
9. **Helper methods with suspiciously low reference counts** (declaration + 0-1 mentions elsewhere)
10. **RunSnapshot fields with no production writes outside `_init`** (the LOSING `losing_run` field signature)

For each hit, manually inspected the surrounding code to classify as:
- **GHOST** — confirmed unwired; fields/methods exist but production code never writes/calls them with real values
- **DEFERRED** — explicit version-tagged TODO (e.g., `TODO V1.1`); documented intentional scope cut, not a bug
- **DOCUMENTATION** — comment describing scope/historical context inside otherwise-correct code (e.g., "Sprint 14 S14-M4 replaces the Sprint 10 S10-M4 stub..."); the word "stub" appears but the code is no longer a stub
- **INTENTIONAL EMPTY CONTRACT** — methods documented as no-op for MVP per a deferred-feature scope (e.g., `get_save_data() -> {}` per Rule 10 deferral)

---

## Findings

### CONFIRMED GHOSTS (2)

#### Ghost #1: `RunSnapshot.kill_schedule`

**File**: `src/core/dungeon_run_orchestrator/run_snapshot.gd:46`

```gdscript
## Ordered tick events scheduled at DISPATCHING. Entries are dicts with
## per-event payload (tick, archetype, kill_count, etc.). Walked sequentially
## as `current_tick` advances; never reordered or rewritten mid-run.
var kill_schedule: Array = []
```

**Why it's a ghost**:
- Field declared with docstring describing intended use ("Walked sequentially as `current_tick` advances")
- Serialized in `get_save_data` (line 172) + deserialized in `load_save_data` (line ~217); save schema includes it
- Equality check honors it (line ~239)
- Existing tests pass — `test_run_snapshot_kill_schedule_default_is_empty_array`, etc. test the persistence shape, NOT the production wiring
- **No production code writes to or reads from this field.** The combat resolver maintains its own local `_kill_schedule_for_loop` helper method that builds a one-loop schedule on demand; the orchestrator's `_process_kill_events` handler reads kill events from the resolver directly via signal, not from `snap.kill_schedule`.

**Severity**: LOW
- No player-visible impact (combat works correctly via the parallel resolver path)
- Save file wastes ~16 bytes (empty array) per saved run
- A future feature (replay viewer, debug tools, telemetry replay aggregator) that reads `snap.kill_schedule` would see an empty array forever — silent broken contract for the consumer

**Recommendation**: **Option B — annotate the deferral explicitly in the docstring**; defer wiring/deletion to a V1.0 save schema bump. The docstring should say "DEFERRED — not yet populated by production code; the combat resolver maintains its own per-loop kill schedule. This field is reserved for future replay-viewer / debug-tools work." This makes the ghost visible to future contributors without introducing save schema risk.

#### Ghost #2: `RunSnapshot.loop_counter`

**File**: `src/core/dungeon_run_orchestrator/run_snapshot.gd:64`

```gdscript
## Number of times the formation has rotated through the floor's enemies.
## Advanced by Combat Resolver on loop completion. Never decremented.
var loop_counter: int = 0
```

**Why it's a ghost**:
- Field declared with docstring claiming "Advanced by Combat Resolver on loop completion"
- Set to `0` once at dispatch (`snap.loop_counter = 0` in `_build_run_snapshot`, line 1582)
- Serialized + deserialized + equality-checked + tested for persistence
- **Combat Resolver does NOT advance it.** `grep loop_counter src/core/combat/` returns zero hits. The combat resolver maintains its own internal loop tracking via `combat_run_snapshot.gd` (a separate snapshot class), not by writing to RunSnapshot.loop_counter.

**Severity**: LOW
- Same as Ghost #1: no player impact, but the docstring lies (it says "advanced by Combat Resolver" — Combat Resolver does no such thing)
- Save file persists 0 forever for this field

**Recommendation**: Same as Ghost #1 — annotate the deferral in the docstring; defer real wiring or deletion to a V1.0 save schema bump. Suggested wording: "DEFERRED — not yet advanced by production code; the combat resolver's per-loop tracking is internal to `CombatRunSnapshot`. This field is reserved for future replay-progress visualization (e.g., 'loop 3 of 5' UI strip)."

---

### CONFIRMED INTENTIONAL (NOT GHOSTS)

| File:line | Pattern | Classification | Why it's not a ghost |
|-----------|---------|----------------|---------------------|
| `dungeon_run_orchestrator.gd:1661` | `= 1.0  # provisional; overwritten below after enemy_list materializes` | DOCUMENTATION | The `# provisional` comment describes the INITIAL declaration; the real value is computed ~40 lines later at line 1701 via `_combat_resolver.call("hp_bonus_factor", ...)`. Sprint 18 PR #100 + PR #101 wired this correctly. The comment now reads as historical commentary, not a placeholder marker. |
| `floor_unlock_system.gd:226` | `# MVP: single dungeon per biome` | DOCUMENTATION | Scope statement explaining MVP architecture (vs V1.0 multi-dungeon-per-biome). Code itself works correctly within MVP scope. |
| `hero_class.gd:49`, `enemy_data.gd:36` | `## MVP ships Tier 1` | DOCUMENTATION | Class-tier scope docs; data files honor this. |
| `economy.gd:468` | `## MVP closed-form drip path` | DOCUMENTATION | Implementation note; the closed-form is the correct MVP implementation, not a placeholder. |
| `telemetry_sink.gd:151` | `"seed_class": "warrior",  # MVP` | INTENTIONAL HARDCODE | Theron is the auto-seeded class per Onboarding GDD #29 §C.9. The hardcoded value is correct because Theron IS always the seeded class in MVP. If multi-seed support lands V1.0+, this changes. |
| `telemetry_sink.gd:152, 176, 291, 294` | `# TODO V1.1` (4 instances) | DEFERRED | Explicit V1.1-tagged TODOs for `cold_launch_ms`, `cost_paid`, `xp_earned`, `was_offline_replay`. Sentinel values (0 / false) shipped intentionally pending: (a) platform-timing-hook for cold launch; (b) Recruitment GDD amendment to expose transaction cost; (c) RunSnapshot xp_earned aggregate field; (d) RunSnapshot was_offline_replay flag. **These ARE scaffolded-but-unwired** but with clear V1.1 acceptance criteria + non-blocking-for-gameplay scope (telemetry-only). Distinct from gameplay-logic ghosts. Track as a Sprint 21+ candidate. |
| `dungeon_run_orchestrator.gd:1126` | `# stub +1-per-clear grant per AC-15-14` | DOCUMENTATION | Historical commentary — "Sprint 14 S14-M4 Story 3 replaces the Sprint 10 S10-M4 stub". The CURRENT code calls `_grant_xp_to_formation(roster, xp_per_floor_clear(floor_idx))` with the real formula. The word "stub" describes what was replaced, not current behavior. |
| `dungeon_run_orchestrator.gd:1496, 1564` | `# MVP harness` / `# MVP build populates enough fields` | DOCUMENTATION | Comments inside `_build_combat_snapshot` documenting that the MVP harness path produces a working data path; both code paths are wired and tested. |
| `dungeon_run_orchestrator.gd:1703` | `# loops_per_run: 1 for MVP` | DOCUMENTATION | Confirms the design choice that MVP runs are single-loop. Field is correctly set; no ghost. |
| `save_load_system.gd:1214` | `## MVP placeholder behavior (Story 010)` | INTENTIONAL EMPTY CONTRACT | `_migrate_payload_version` docstring explaining the default behavior (no-op for same version, null for unknown migration). Real migrations DO exist (`_migrate_v1_to_v2` at line 1294). The "placeholder behavior" describes the FALLBACK contract, not unwired code. |
| `save_load_system.gd:1298` | `# Defensive: HeroRoster namespace missing entirely. Add a minimal stub` | INTENTIONAL DEFENSIVE PAYLOAD | The word "stub" describes a defensive empty-dict payload for V1→V2 migration when HeroRoster namespace is missing entirely. The code IS the stub (empty dict), correctly handling the edge case. |
| `audio_router.gd:451` | `## MVP note: panel-open SFX deferred` | DEFERRED | Documented MVP scope cut for panel-open audio cue; not a bug. |
| `hero_roster.gd:855` | `## placeholder with push_warning. Production code paths require all MVP` | INTENTIONAL DEFENSIVE PATH | Documentation for a defensive code path that fires `push_warning` if MVP-required class data is missing. The "placeholder" describes the failure-mode return value, not unwired code. |
| `formation_assignment.gd:148, 161` | `## MVP: empty payload` for `get_save_data` / `load_save_data` | INTENTIONAL EMPTY CONTRACT | Per `formation-assignment-system.md` Rule 10: FormationAssignment owns no persistent state in MVP; HeroRoster persists formation slots. The empty contract is correct. V1.0 named-presets work fills this in. |
| `data_registry.gd:983` | `# for MVP; other cross-refs (Floor.enemy_list[].enemy_id → EnemyData) are non-cycling by construction` | DOCUMENTATION | This is the comment that LOOKED LIKE the smoking gun for the Sprint 18 materialize bug, but it's about CYCLE DETECTION scope (the cycle-checker only walks dungeon↔biome edges; enemy cross-refs are acyclic by construction so don't need cycle checking). The actual materialization bug was in the orchestrator's `_build_combat_snapshot`, not here. Comment is benign. |
| `scene_manager.gd:61` | `## for MVP — emits push_warning if selected` | DOCUMENTATION | Comment describing a deprecated transition type that fires a warning if used; correctly wired. |
| 6 private helpers in `dungeon_run_orchestrator.gd` (`_subscribe_to_formation_reassignment`, `_enter_active_foreground`, `_exit_active_foreground`, `_resolve_synergy_gold_multiplier`, `_detect_synergy_for_dispatch`, `_resolve_floor`) | Suspiciously low reference count (2 mentions each: declaration + call site) | NOT GHOSTS | Each has exactly one call site within the file (verified manually). All wired correctly. |

---

## Fixes applied this audit

**Fix 1**: Annotate `RunSnapshot.kill_schedule` docstring with explicit DEFERRED marker.

**Fix 2**: Annotate `RunSnapshot.loop_counter` docstring with explicit DEFERRED marker.

Both fixes update the docstring only — no behavior change, no save schema change, no test changes. The goal is to make the deferral visible to future contributors so they don't write code that depends on these fields' undocumented-emptiness, and so they understand the wiring gap without re-running the audit.

---

## Recommendations for follow-up

1. **V1.1 scope**: pick up the 4 telemetry sentinel fields (`cold_launch_ms`, `cost_paid`, `xp_earned`, `was_offline_replay`) when their upstream wiring lands. Each has clear acceptance criteria in its `TODO V1.1` comment. None block MVP ship.
2. **V1.0+ save schema bump**: when the next save schema migration ships (V2 → V3), evaluate whether `RunSnapshot.kill_schedule` and `loop_counter` should be wired (combat resolver writes them) or removed (V3 schema drops them). Either choice closes the deferred-ghost state. Until then, the explicit DEFERRED annotation makes the gap visible.
3. **Audit cadence**: per the Sprint 18 retro recommendation, run this audit **before every sprint's playtest gate**. The pattern hunt takes ~15 min; produces the report; catches ghosts before they compound. Reuse this audit's structure as the template. Add new patterns as they're identified (e.g., from future bug postmortems).

---

## Process improvement note

The two ghosts found this round (`kill_schedule`, `loop_counter`) had **passing tests** for their persistence shape. The tests directly set the fields' values and verified round-trip — they did NOT exercise production code paths that should write the fields. This is the same test-coverage gap that hid the Sprint 18 critical bugs: piece-tests pass; integration is what's broken.

**Reaffirms** the Sprint 18 retro process improvement: every ADR amendment / new field declaration should be paired with an INTEGRATION test that exercises the production write path, not just a unit test that sets the value directly. The unit test verifies the field SHAPE; the integration test verifies the field WIRING.

---

*End of audit.*
