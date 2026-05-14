# ADR-0018: Class Synergy Multiplier Insertion in Combat Formula

## Status

**Accepted 2026-05-14** — authored as part of Sprint 18 S18-M2 implementation per the Class Synergy V1.0 GDD #32 (APPROVED 2026-05-10 + re-review revisions 2026-05-14). Documents the existing multi-multiplier composition order in `DungeonRunOrchestrator.attribute_kill_gold` after the Sprint 19 pre-emptive scaffolding plus the 2026-05-14 Triple Strike addition.

## Date

2026-05-14

## Last Verified

2026-05-14

## Decision Makers

- Author (user) — final decision; **sign-off via Sprint 18 S18-M1 design-review APPROVED verdict on GDD #32**
- godot-gdscript-specialist — formula composition + GDScript idiom alignment
- game-designer — cozy register hard floor + per-synergy ≤+50% cap (AC-CS-16)
- producer — Sprint 18 M2 scope confirmation

## Summary

Locks the **multi-multiplier composition order** for the per-kill gold + XP formulas in `DungeonRunOrchestrator.attribute_kill_gold` and `attribute_kill_xp`. The synergy multiplier is the **innermost multiplicative factor** applied to baseline tier-indexed gold/XP, multiplied alongside matchup-advantage and LOSING-run-loot-factor. Order matters for floor() truncation behavior and for the per-synergy ≤+50% cap enforcement at the resolver layer (not at the compound product layer).

The 4-factor gold composition is:

```
attribute_kill_gold(tier, advantaged, losing_run, synergy_id, archetype) -> int:
    return floori(BASE_KILL[tier] × matchup_mult × loot_factor × synergy_mult)
```

The 2-factor XP composition is:

```
attribute_kill_xp(tier, synergy_id) -> int:
    return floori(BASE_XP_PER_KILL × tier × synergy_mult)
```

Where `synergy_mult` is the output of `_resolve_synergy_gold_multiplier(synergy_id, archetype)` (gold path) or `_resolve_synergy_xp_multiplier(synergy_id)` (XP path), both of which dispatch on the dispatch-time-snapshotted `RunSnapshot.synergy_id` String.

## Engine Compatibility

- **Godot 4.6** (project pinned).
- `floori(float)` per `docs/engine-reference/godot/modules/variant_utility.md` — truncates toward negative infinity, matching the existing matchup-resolver convention. Differs from `int(float)` (truncation toward zero) and `roundi(float)` (rounds to nearest). The `floori` choice is the project convention for per-kill gold and is preserved here.
- No new engine APIs introduced.

## ADR Dependencies

- **ADR-0002** (LOSING first-clear reclaim, Amendment 1 multi-biome ledger) — synergy applies to per-kill gold only, NOT to first-clear bonuses. Economy's `try_award_floor_clear(biome_id, floor_index, bonus_amount)` continues to gate floor-clear gold independently of synergy. The two channels do not interact.
- **ADR-0001** (mid-run reassignment MVP lock) — `RunSnapshot.synergy_id` is FROZEN at dispatch via `DungeonRunOrchestrator.snapshot_synergy_for_run`. Mid-run formation edits do NOT recompute the synergy. This invariant is load-bearing for AC-CS-13.
- **ADR-0003** (autoload rank ordering) — `FormationAssignment` (rank ~11) owns the `detect_active_synergy` method that the orchestrator (rank ~13) reads at dispatch. Read-only consume from a higher-ranked autoload is the established pattern.
- **ADR-0004** (Save/Load consumer contract) — `RunSnapshot.synergy_id: String` is in the orchestrator save namespace. Default `""` on missing key (V1 → V1.x forward compat). AC-CS-18 forward-compat fallback: unknown synergy_id strings resolve to 1.0 multiplier (no crash).

## Context

Class Synergy V1.0 introduces a fourth multiplier source into the per-kill gold formula. Before this ADR, the formula composed three factors:

```
floori(BASE_KILL[tier] × matchup_multiplier × loot_factor)
```

The synergy GDD §C.3 specifies a fourth `synergy_multiplier` factor must compose multiplicatively. Three questions emerged:

1. **Order of operations.** Does the synergy multiplier go innermost (multiplied last, before `floori`) or somewhere in the middle? Order doesn't affect mathematical result for pure multiplication, but it does affect *test readability* and *future-extension cleanliness*.

2. **Truncation behavior at compound boundaries.** With multiple sub-1.0 factors (e.g., LOSING_RUN_LOOT_FACTOR=0.5) combined with super-1.0 factors (e.g., STEEL_WALL_GOLD_MULT=1.25), intermediate truncation could produce different output than single-shot truncation. The project convention is **single-shot `floori` at the outermost level** to preserve precision through the composition.

3. **Cap enforcement layer.** The cozy-register hard floor (OQ-32-6 + AC-CS-16) limits each synergy multiplier to ≤1.5 individually. Should the cap be enforced per-factor (at the resolver) or per-compound-product (at the formula)? The decision favors **per-factor** since the compound product can legitimately exceed +50% over baseline when multiple bonus factors stack (e.g., matchup-advantaged + synergy = 1.5 × 1.25 = 1.875× = +87.5% over baseline kill gold). The cap protects against a *single* synergy growing degenerate, not against the compound stack.

The 2026-05-14 Triple Strike addition is the first net-new synergy since the original 3 first-pass synergies were scaffolded. It validates the extension pattern: adding a synergy is one new `const`, one new `match` arm in the resolver, one new clause in detection, and parallel test coverage. No formula changes required.

## Decision

**Multi-multiplier composition order — locked**:

1. `BASE_KILL[tier]` is the **innermost** value. Sourced from the `BASE_KILL: Dictionary` table (tier-indexed, 1–5).

2. `matchup_multiplier` applies next. `MATCHUP_GOLD_MULTIPLIER` (currently 1.5) when `advantaged == true`, else 1.0. Sourced from class-vs-enemy-matchup-resolver (#10).

3. `loot_factor` applies third. `LOSING_RUN_LOOT_FACTOR` (currently 0.5) when `losing_run == true`, else 1.0. Sourced from ADR-0002 + dungeon-run-orchestrator GDD.

4. `synergy_multiplier` applies fourth (outermost factor before `floori`). Resolved per `_resolve_synergy_gold_multiplier(synergy_id, archetype)` which dispatches on the dispatch-time-snapshotted `RunSnapshot.synergy_id`. Conditional synergies (Steel Wall vs bruiser, Triple Strike vs armored) collapse to 1.0 when their archetype condition fails.

5. `floori(...)` is applied **once** at the end, NOT after each factor. This preserves precision through the float chain.

**XP composition order** (2-factor):

1. `BASE_XP_PER_KILL` × `tier` — float multiplication.
2. `synergy_multiplier` from `_resolve_synergy_xp_multiplier(synergy_id)` — currently only Arcane Elite (×1.20 unconditional) modifies XP; all other synergies pass 1.0.
3. `floori(...)` once at the end.

**Per-synergy cap enforcement layer**: enforced at the **resolver** layer via static-analysis CI test (per AC-CS-16). The resolver returns float values; the CI test asserts that each declared synergy constant (STEEL_WALL_GOLD_MULT, TRIPLE_STRIKE_GOLD_MULT, TRIPLE_THREAT_GOLD_MULT, ARCANE_ELITE_XP_MULT) is ≤1.5. The compound product is intentionally unbounded.

**Snapshot point**: `RunSnapshot.synergy_id` is set by `DungeonRunOrchestrator.snapshot_synergy_for_run(formation_snapshot)` at the DISPATCHING state transition, **before** the run enters ACTIVE_FOREGROUND. The orchestrator queries `FormationAssignment.detect_active_synergy(formation_snapshot)` if the autoload exists and has the method; otherwise the synergy_id stays empty (defensive against rank-ordering edge cases). The snapshot is IMMUTABLE for the run's duration per AC-CS-13.

## Alternatives Considered

### Alternative A — Wrap into a `RunModifier` aggregator object

A future-facing abstraction where all multipliers (matchup, loot_factor, synergy, plus a planned V1.5 prestige multiplier and potential V1.5 buff/debuff multipliers) become entries in a `RunModifier` resource. `attribute_kill_gold` would query `run_modifier.compute_gold_multiplier(archetype)` and apply it as a single factor.

**Rejected for V1.0** because:
- Only 1 new multiplier source emerges in V1.0 (synergy). The 4-factor explicit composition stays under the cognitive ceiling for direct readability.
- A third multiplier source (e.g., V1.5 buff/debuff system) would trigger the abstraction. The GDD §OQ-32-8 explicitly defers this to "when a third multiplier source emerges."
- Premature abstraction would obscure the order of operations + cap enforcement layer, both of which need to be understood by anyone debugging gold output.

### Alternative B — Floor at each step

Apply `floori` after each multiplier rather than once at the end:

```
gold = floori(BASE_KILL[tier] × matchup_mult)
gold = floori(gold × loot_factor)
gold = floori(gold × synergy_mult)
```

**Rejected** because:
- Loses precision through intermediate truncation. Example: BASE_KILL[1]=5 × 1.5 = 7.5 → floori → 7. Then 7 × 0.5 = 3.5 → floori → 3. Then 3 × 1.25 = 3.75 → floori → 3. Single-shot path: 5 × 1.5 × 0.5 × 1.25 = 4.6875 → floori → 4.
- The single-shot result (4) differs from the per-step result (3) in this scenario. Single-shot is the project convention and matches GDD §D.4 worked examples.
- Per-step truncation makes the loot_factor (and any future sub-1.0 multiplier) more punishing than the GDD specifies. Cozy register favors the gentler single-shot path.

### Alternative C — Move constants to `EconomyConfig.tres`

The GDD §G specifies constants live in `EconomyConfig.tres` (designer-tunable via Inspector). The current implementation has them as `const` in the orchestrator script. Moving to a `.tres` resource would unlock designer tuning without code changes.

**Deferred to V1.5+** because:
- The Sprint 19 pre-emptive scaffolding put them in code; refactoring now would expand M2 scope beyond the GDD's stated "wire synergy into the formula" intent.
- The `const` declarations are still designer-readable (single source of truth, well-documented per ADR section).
- Future ADR will document the migration path when EconomyConfig.tres gains its first new field for designer-tuning purposes outside of synergy work.
- Implementer note: the GDD §G's "lives in `EconomyConfig.tres`" line is currently aspirational; the actual reality is `const` in `dungeon_run_orchestrator.gd`. Either the GDD or the code is correct; this ADR pins the code-as-truth state for V1.0.

## Consequences

**Positive**:
- Composition order is explicit and testable. Each synergy gets its own test group; the cap is enforced at one well-defined layer.
- Forward-extension pattern is established. Triple Strike (added 2026-05-14) demonstrated the recipe: one new const + one new resolver match arm + one new detection clause + parallel test coverage. The 2026-05-14 work touched 6 files and ~30 lines of code.
- `RunSnapshot.synergy_id` as a String (not a typed resource) makes save/load forward-compat trivial (AC-CS-18 fallback). Unknown synergy_ids in V1.5+ saves degrade gracefully to 1.0.

**Negative**:
- Adding a third multiplier source (e.g., V1.5 prestige multiplier) without first abstracting into a `RunModifier` aggregator will produce a 5-factor explicit chain that approaches the cognitive ceiling. Refactor trigger: when the 5th factor lands, author the RunModifier ADR per §OQ-32-8.
- Constants-in-code vs constants-in-tres divergence from the GDD §G is a latent debt. Recoded as a deferred consequence rather than a blocking issue per Alternative C.
- The single-shot `floori` policy depends on every future multiplier source respecting the precision-through-the-chain pattern. A future contributor adding intermediate truncation would silently change gold-output values. Mitigation: this ADR documents the policy + the test suite pins the existing values.

**Test coverage at landing (2026-05-14)**:
- `tests/unit/dungeon_run_orchestrator/class_synergy_formula_test.gd` — 19 tests covering Steel Wall (3, including the GDD §D.4 worked example), Triple Strike (4, including symmetric-with-Steel-Wall), Triple Threat (2), Arcane Elite gold (1), Arcane Elite XP (2), no-synergy baseline (1), and the bounded-by-precision invariants.
- `tests/integration/dungeon_run_orchestrator/class_synergy_invariants_test.gd` — 8 tests covering composition × synergy × archetype matrices, including the AC-CS-19 balance regression (no mono-class dominance >30% above mean).
- `tests/unit/formation_assignment/class_synergy_detection_test.gd` — 20 tests covering detection accuracy for all 4 first-pass synergies + 2+1 mixes + empty-slot + order-independence + hero-roster-fallback path.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/class-synergy-system.md` §C.3 | Class Synergy | "The Combat Resolution + Orchestrator integration extends `attribute_kill_gold` with a `synergy_multiplier` factor" | Composition order locked; integration point + ordering documented. |
| `design/gdd/class-synergy-system.md` §D.2 + §D.3 | Class Synergy | Per-synergy gold + XP multiplier resolution functions | Resolver layer is the cap-enforcement layer per this ADR. |
| `design/gdd/class-synergy-system.md` AC-CS-16 | Class Synergy | "no PER-SYNERGY multiplier exceeds +50%" — static analysis assertion | Per-factor cap enforcement at the resolver layer; static-analysis CI test target documented. |
| `design/gdd/class-synergy-system.md` AC-CS-13 | Class Synergy | Mid-run reassignment does NOT change active synergy | Snapshot point at DISPATCHING + immutability for run duration documented. |
| `design/gdd/class-synergy-system.md` AC-CS-18 | Class Synergy | Unknown synergy_id falls back to 1.0 (forward-compat) | Resolver `_` match arm returns 1.0; documented as the V1.5+ migration path. |
| `design/gdd/dungeon-run-orchestrator.md` §D.1 | Orchestrator | Per-kill gold formula composition | 4-factor multiplicative composition with single-shot `floori` documented as the canonical pattern. |

## Related

- ADR-0001 (mid-run reassignment MVP lock — synergy snapshot immutability)
- ADR-0002 (LOSING first-clear reclaim + Amendment 1 multi-biome ledger — synergy does not interact with floor-clear bonuses)
- ADR-0003 (autoload rank ordering — orchestrator reads FormationAssignment.detect_active_synergy)
- ADR-0004 (Save/Load consumer contract — RunSnapshot.synergy_id namespacing)
- `design/gdd/class-synergy-system.md` (#32, APPROVED 2026-05-10 + re-review 2026-05-14)
- `design/gdd/dungeon-run-orchestrator.md` (#13, §D.1 + §C.6 three-layer idempotency)
- `design/gdd/economy-system.md` (#5, separate per-floor-clear gold channel — synergy does NOT modify floor-clear bonuses)
- Sprint 18 plan (`production/sprints/sprint-18.md` S18-M2)
