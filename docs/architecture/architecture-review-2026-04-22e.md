# Architecture Review — 2026-04-22e (fifth re-run, post ADR-0012 landing)

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 12 (all Accepted: 0001–0012) |
| Registry State | populated (425 TR-IDs, v2) |
| Prior Reviews | `architecture-review-2026-04-22.md` (CONCERNS — initial); `22b.md` (post ADR-0009 Accept); `22c.md` (post ADR-0010 Accept); `22d.md` (post ADR-0011 Accept) |
| Verdict | **CONCERNS** (gap-only, reduced severity vs 22d; coverage rises; NO drift items — `/architecture-decision` landed all artifact cascades in-session) |

---

## What changed since the prior review (2026-04-22d)

One ADR landing since the prior review, fully lockstep-cascaded in the authoring session:

1. **ADR-0012** (**Accepted 2026-04-22**, authored + promoted same-session) — Hero Roster Mutation API + HeroInstance Identity Stability. Covers the `ADR-X03` slot the 22d review flagged as top unwritten Required ADR. Codifies:
   - `class_name HeroInstance extends RefCounted` — pure data record with 5 private underscore-prefixed fields (`_instance_id`, `_class_id`, `_display_name`, `_current_level`, `_xp`); 5 read-only property getters; static factory pattern (`HeroInstance.create` + `HeroInstance.from_dict`); underscore-prefixed `_set_level` as HeroRoster's sole mutation path. Zero-arg `_init`.
   - `class_name HeroRoster extends Node` autoload rank 7 (ADR-0003 inheritance); zero-arg `_init`; state containers `_heroes: Dictionary[int, HeroInstance]` + `_formation_slots: Array[int]` size 3 with `0` sentinel + `_next_instance_id: int` monotonic never-reused.
   - 4-method mutation API with sole-caller contracts per GDD Rule 11 (`add_hero` / `remove_hero` / `set_hero_level` / `set_formation_slot`).
   - 16-method read API; `get_formation_strength() -> float` with locked range `[1.0, 3.0]` + empty-formation guard (Economy contract locked for the forthcoming ADR-C01).
   - 3 typed signals (`hero_recruited(HeroInstance)`, `hero_leveled(id, old, new)`, `hero_removed(id, class_id, display_name)`); `_boot_validating` suppression flag per ADR-0004 inheritance.
   - 4-step boot validation order inside `load_save_data()` (orphan drop → slot clear → cap trim → next_id repair); all steps atomic before any signal emission.
   - **ADR-elevated forbidden pattern**: `caching_heroinstance_reference_across_save_boundary` — object identity is NOT stable across load; consumers reference by `instance_id: int` and re-resolve via `get_hero(id)`. Implicit in GDD Rules 4 + 13, never previously stated explicitly.
   - `seed_first_launch_state()` Roster-owned deterministic tutorial Warrior seeding (Onboarding does NOT inject).
   - 5 Alternatives exhaustively considered (Array vs Dictionary; promote HeroInstance to GameData; UUID vs monotonic int; separate FormationAssignment autoload; HeroInstance as plain Dict).
   - 7 Risks with mitigations (field-typed HeroInstance caching; _next_instance_id overflow; hand-edited instance_id 0; Dictionary insertion-order determinism; missing name pool; missing roster_config; set_hero_level clamp loss; cap-trim "wrong heroes").

### Artifacts landed in lockstep during ADR-0012 authoring

Per session state `Files touched in lockstep = 9`:

1. `docs/architecture/ADR-0012-hero-roster-mutation-and-identity.md` — new ADR (Accepted)
2. `docs/registry/architecture.yaml` — 7 interfaces (`hero_instance_shape`, `hero_roster_mutation_api`, `hero_roster_read_api`, `hero_recruited_signal`, `hero_leveled_signal`, `hero_removed_signal`, `seed_first_launch_contract`); 6 api_decisions (`heroinstance_value_type_choice`, `instance_id_scheme`, `roster_state_container_choice`, `formation_state_ownership`, `roster_boot_validation_order`, `heroinstance_reference_lifetime`); 8 forbidden_patterns (`caching_heroinstance_reference_across_save_boundary`, `external_access_to_underscore_private`, `heroinstance_direct_construction_outside_factory`, `heroinstance_mutation_outside_heroroster`, `instance_id_value_zero_as_real_hero`, `instance_id_reuse_after_remove`, `heroinstance_field_set_expansion_without_schema_version_bump`, `roster_state_container_direct_mutation_outside_heroroster`); 1 perf budget (`get_formation_strength_call` ADVISORY 50µs p99 per GDD H-14); 2 `referenced_by` bumps (ADR-0011 `hero_class_schema` + ADR-0006 `data_resolve_contract`).
3. `design/gdd/economy-system.md:549` — provisional "roster GDD may refine the signature" annotation replaced with ADR-0012 citation; bidirectional-consistency entry in `hero-roster.md` §F noted the provisional tag can be confirmed resolved.
4. `docs/architecture/architecture.md` — 5 locations updated: line 7 (Version + ADR-0012 Accepted note); line 8 (Last Updated bumped); line 13 (ADRs Referenced: through ADR-0012 all Accepted); line 713 (§Required ADRs Feature Layer ADR-X03 row → ADR-0012 Accepted with full landed scope); lines 727-729 (total-count paragraph bumped to 12 Accepted / 4 remain; top-priority shifted to ADR-C01).
5. `production/session-state/active.md` — authoring arc entry appended.

godot-gdscript-specialist Step 4.5 returned APPROVE-WITH-NOTES (10 notes); 2 LOAD-BEARING folded in-place (NOTE #3: `Array[int] sorted_ids` typed-keys coerce in cap-trim step; NOTE #10: `assert(_heroes.is_empty(), ...)` guard in `seed_first_launch_state` against double-seed contract violation). 8 forward-looking notes retained for implementation-story awareness (property-getter pattern, factory + zero-arg `.new()`, signal-payload-types-doc-only, `_boot_validating` vs `set_block_signals()`, int→float promotion, PackedStringArray `in` operator, rank-7 `_ready()` race-window analysis, `Dictionary.get` null-default). technical-director Step 4.6 SKIPPED (solo review mode per `.claude/docs/director-gates.md` §TD-ADR).

---

## Traceability Summary

**Total requirements**: 425 (no new TRs in this review — ADR-0012 codifies existing TR-hero-roster-001..030 pool verbatim; no new requirements surfaced by the GDD-level ratification).

| Status | Count | % | Δ vs prior |
|---|---|---|---|
| ✅ Covered | ~349 | ~82% | **+28** (ADR-0012 covers TR-hero-roster-001..030 in full, up from ~2 partial via ADR-0003) |
| ⚠️ Partial | ~32 | ~8% | unchanged |
| ❌ Gap | ~44 | ~10% | **−28** |

Coverage crosses the ~80% threshold for the first time. PASS-verdict candidacy is now one additional Required ADR away (ADR-C01 projected ~87%).

Per-system coverage (post ADR-0012):

| System (GDD) | TRs | Governing ADRs | Covered | Gap | Gap Routes To |
|---|---|---|---|---|---|
| save-load | 60 | 0003, 0004, 0005, 0007 | ~52 | ~4 | minor UX/debug |
| time | 36 | 0003, 0005 | ~34 | ~1 | — |
| data-loading | 28 | 0003, 0006, 0011 | ~27 | ~1 | — |
| scene-manager | 39 | 0003, 0007, 0008 | ~35 | ~2 | OQ-7 |
| hero-class-db | 24 | 0006, 0011 | ~24 | ~0 | — |
| enemy-db | 23 | 0006, 0011 | ~23 | ~0 | — |
| biome-dungeon-db | 28 | 0006, 0011 | ~22 | ~6 | ADR-X02, ADR-C01, Art Bible |
| matchup-resolver | 33 | 0009 | ~31 | ~2 | minor (CI helper wording) |
| combat | 32 | 0010 | ~32 | ~0 | — |
| orchestrator | 32 | 0001, 0002, 0003, 0004, 0005, 0009, 0010 | ~24 | ~4 | ADR-X02 |
| economy | 28 | 0002 | ~6 | ~20 | ADR-C01 |
| **hero-roster** | **30** | **0003, 0012** | **~30** | **~0** | **ADR-0012 now Accepted — full coverage** |
| floor-unlock | 32 | 0002, 0003 | ~10 | ~18 | direct story OK (X05 deferred V1.0) |
| **TOTAL** | **425** | — | **~349** | **~44** | — |

### Hero-Roster coverage delta detail (all 30 TRs now covered)

ADR-0012's §Decision §1–§2 and §GDD Requirements Addressed table map to TR-hero-roster-001..030 as follows:

- **Schema + type locks (TR-001..005, TR-012)**: §Decision §1 locks `class_name HeroInstance extends RefCounted`, 5-field set, property-getter read-only pattern, factory + `from_dict` construction, `_set_level` sole-mutation path.
- **Capacity + config (TR-006, TR-007, TR-030)**: §Decision §2 + §Migration Plan #4 lock `MAX_ROSTER_SIZE = 30` + `FORMATION_SIZE = 3` in `roster_config.tres`; inter-knob constraint validator `MAX_ROSTER_SIZE >= FORMATION_SIZE` preserved per GDD §G.1.
- **Mutation API (TR-008, TR-013, TR-014)**: §Decision §2 mutation API block — `add_hero` cap + resolve check; `set_hero_level` clamp + out-of-range `push_warning`; `set_formation_slot` auto-clear-prior-slot semantics.
- **Signals + suppression (TR-009, TR-010)**: §Decision §2 signal declarations with typed payloads; `_boot_validating` flag gates all three `.emit()` calls.
- **Identity stability (TR-011)**: §Decision §2 `_next_instance_id` monotonic + never-reused; §5 Cross-consumer stability invariant codifies the `caching_heroinstance_reference_across_save_boundary` forbidden pattern as ADR-elevated rule.
- **Boot validation order (TR-015, TR-016)**: §Decision §2 `load_save_data` block implements the exact 4-step order per GDD Rule 16 with `_orphaned_heroes` accumulation; §Orphan accessor returns the list to SaveLoadSystem.
- **Formula contracts (TR-017, TR-018, TR-027)**: §Decision §2 `get_formation_strength` + `get_formation_heroes` verbatim per GDD §D.1–§D.2; empty-formation guard explicit; clamp range `[1.0, 3.0]`.
- **Save dict shape (TR-019, TR-025, TR-029)**: §Decision §2 `get_save_data` / `load_save_data` with `{heroes, formation_slots, next_instance_id}` keys; duplicate instance_id handling per Dictionary semantics + `push_error` log; H-07 round-trip via §Validation Criteria.
- **First-launch seed (TR-020, TR-021)**: §Decision §2 `seed_first_launch_state` verbatim — deterministic Theron at id=1, slot 0; emits one `hero_recruited`; NOT boot-validation-suppressed (legitimate player-visible recruit).
- **Name pool (TR-022, TR-023)**: §Decision §2 `_select_name_from_pool` helper — uniform random over available; fallback `{base} the {ordinal}`; ≥20 names per class enforced via ADR-0006 required-resource validator.
- **Performance (TR-024)**: §Performance Implications ADVISORY 50µs p99 budget; Registry `performance_budget` entry added in lockstep.
- **Default sort (TR-026)**: §Decision §2 `_default_sort_comparator` — BY_CLASS (registry declaration order via `DataRegistry.get_declaration_index`) then BY_LEVEL_DESC.
- **Encapsulation (TR-028)**: §Validation Criteria CI asserts — all underscore-prefixed state containers, external-access forbidden pattern, `_set_level` sole-owner grep check.

No partial matches remain — all 30 TRs are now fully ADR-backed.

### Economy contract partial-coverage note

ADR-0012 locks the `roster.get_formation_strength() -> float` signature (range, clamp, empty guard). Economy's consumption of this API is still ADR-C01 territory — the 20 unwritten economy TRs (formula shape, cost curves, drip ticker) remain gap. However, the provisional "roster GDD may refine the signature" annotation at `economy-system.md:549` is now cleaned up in lockstep: Economy's upstream contract to HeroRoster is fully locked; what remains for ADR-C01 is Economy's own state shape + downstream formula.

---

## Cross-ADR Conflicts

**NONE DETECTED.**

ADR-0012 is architected for pure inheritance from its upstream ADRs; it reinforces (never contradicts) the statelessness invariants of ADR-0009 + ADR-0010:

| Potential collision surface | Result |
|---|---|
| ADR-0012 ↔ ADR-0003 (autoload rank) | Inheritance only — HeroRoster rank 7 (already in ADR-0003 rank table); zero-arg `_init` per Amendment #3 + autoload.md Claim 4 [VERIFIED]. No redeclaration. |
| ADR-0012 ↔ ADR-0004 (save envelope) | Inheritance only — `get_save_data` / `load_save_data` consumer contract re-used verbatim; `_boot_validating` flag fulfills boot-validation-before-signal-emission guarantee. |
| ADR-0012 ↔ ADR-0006 (data loading) | Inheritance only — `DataRegistry.resolve("classes", id)` used in `add_hero` precondition + boot validation Step 1 orphan check; `DataRegistry.resolve("config", "roster_config")` + `DataRegistry.resolve("name_pools", class_id)` re-used. No DAG change. |
| ADR-0012 ↔ ADR-0009 (MatchupResolver) | Companion — ADR-0009's value-pass `Array[HeroInstance]` assumption is now codified on the HeroRoster side: `get_formation_heroes()` returns per-call value array; the new `caching_heroinstance_reference_across_save_boundary` forbidden pattern explicitly reinforces MatchupResolver statelessness. **Reinforces** — no redeclaration. |
| ADR-0012 ↔ ADR-0010 (CombatResolver) | Companion — ADR-0010's value-pass `compute_tick_events(formation: Array[HeroInstance], ...)` + `compute_offline_batch(formation: Array[HeroInstance], ...)` assumption is now codified on the HeroRoster side. **Reinforces** — no redeclaration. |
| ADR-0012 ↔ ADR-0011 (resource schemas) | Consumer — `HeroClass.id: String` consumed as `HeroInstance.class_id`; `HeroClass.tier: int` forward-referenced for future ADR-C01 Economy cost curves; `DataRegistry.resolve("classes", id) -> HeroClass` return type now concretely typed thanks to ADR-0011 `class_name HeroClass extends GameData`. **Reinforces** — locks the return type ADR-0006 + ADR-0011 had established. |
| ADR-0012 ↔ ADR-0001 (formation reassignment) | ADR-0001 operates on `RunSnapshot.formation: Array[HeroInstance]` — a value-pass array captured at dispatch. ADR-0012 confirms this is the sanctioned cross-save-boundary HeroInstance reference holder (future ADR-X02 will allowlist it explicitly from the forbidden pattern). No conflict; ADR-0012 §5 and §Related Decisions anticipate this allowlist. |
| ADR-0012 ↔ ADR-0002 (losing first-clear reclaimable) | No overlap — ADR-0002 concerns Economy ledger semantics. Orthogonal to Roster identity. |
| ADR-0012 ↔ ADR-0005 (time system) | No overlap — HeroRoster is not a TickSystem consumer; no `tick_fired` subscription; Economy mediates per-tick access to `get_formation_strength`. |
| ADR-0012 ↔ ADR-0007 (scene transition) | No overlap — scene-boundary-persist is a SaveLoad concern. HeroRoster's `get_save_data` is the read-side; no direct scene-transition coupling. |
| ADR-0012 ↔ ADR-0008 (UI framework) | No direct code overlap. RosterScreen/RecruitScreen/FormationAssignmentScreen will consume via signals + `instance_id: int` per the new forbidden pattern — ADR-0008's theme + tap-target invariants apply to the screens, not to HeroRoster. |

No data ownership, integration contract, performance budget, dependency cycle, or architecture pattern conflicts.

### Forward reference to ADR-X02 (expected, not a conflict)

ADR-0012 §5 Cross-consumer stability invariant + §Related Decisions both note that ADR-X02 (Offline batch chunking + snapshot schema, unwritten) will need to **allowlist** the Orchestrator-owned formation snapshot from the `caching_heroinstance_reference_across_save_boundary` forbidden pattern. This is an explicit forward reference with a documented handoff, not a conflict. ADR-X02's CI pattern will grep `src/presentation/` + `src/ui/` for field-typed HeroInstance vars; the Orchestrator snapshot (owned by ADR-X02) will be the sole allowlisted exception.

---

## ADR Dependency Graph

Updated from 22d review:

```
Level 0 (no dependencies):       ADR-0001, ADR-0002, ADR-0003 (triple-amended)
Level 1 (depends on 0003):       ADR-0004, ADR-0006
Level 2 (depends on Level 1):    ADR-0005 (requires 0003 + 0004)
Level 3 (depends on Level 2):    ADR-0007 (requires 0003 + 0004 + 0005 + 0006)
                                 ADR-0009 (requires 0003-Amendment-#3 + 0006)
                                 ADR-0011 (requires 0006)
Level 4 (depends on Level 3):    ADR-0008 (requires 0006 + 0007)
                                 ADR-0010 (requires 0003 + 0006 + 0009)
                                 ADR-0012 (requires 0003 + 0004 + 0006 + 0011)
```

- **12 of 12 ADRs Accepted.** No Proposed backlog.
- **No cycles.** No unresolved dependencies.
- ADR-0012's dependency chain (0003 / 0004 / 0006 / 0011) is entirely Accepted. Safe to consume.

**Recommended authoring order for remaining Required ADRs** (post ADR-0012 Accept):

1. **ADR-C01** — Economy state shape + recruitment cost curve + drip ticker. Covers TR-economy-001..028 gap pool minus ADR-0002 coverage (~20 TRs). Consumes `roster.get_formation_strength() -> float` + `roster.get_copies_owned(class_id) -> int` per ADR-0012 locked signatures; consumes `HeroClass.tier` + `EnemyData.tier` per ADR-0011. Unblocks TR-biome-dungeon-db-017 (`BASE_DRIP[floor_index]` lookup). Projected coverage post-C01: ~87%.
2. **ADR-X02** — Offline batch chunking + offline-replay snapshot schema. Cites ADR-0010 for `CombatBatchResult` chunking unit; cites ADR-0009 for `matched_archetypes` frozen-at-dispatch; cites ADR-0011 for `Floor.enemy_list` freeze target; cites ADR-0012 for `HeroInstance` snapshot allowlist exception (the sole sanctioned cross-save-boundary HeroInstance reference holder). Covers TR-orchestrator-010..013/029 + TR-economy-017..019 + TR-biome-dungeon-db-019.

After those 2 ADRs: ADR-C03 (Audio) + ADR-X04 (Recruitment) remain blocked on their GDDs being authored (not architectural gaps — GDD gaps). ADR-X05 (Floor Unlock designer-UI) deferred V1.0.

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 12 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 12 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] via autoload.md Claim 1 (2026-04-21) + Claim 4 (2026-04-22) |

### Post-cutoff APIs in use (by ADR-0012)

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| `Dictionary[int, HeroInstance]` typed-dict syntax | Godot 4.4+ | ADR-0012 §Decision §2 `_heroes` state container | LOW | Direct precedent in ADR-0009 `Dictionary[StringName, int]` and codebase-active ADR-0010 `Array[KillEvent]`. Stable 4.4+. godot-gdscript-specialist NOTE #3 (LOAD-BEARING folded): `.keys()` returns `Array[int]` on typed dicts in 4.4+; annotated explicitly in cap-trim step 3. |
| `Array[HeroInstance]` + `Array[int]` typed-array syntax | Godot 4.4+ | ADR-0012 §Decision §2 `_formation_slots: Array[int]`, `get_all_heroes() -> Array[HeroInstance]`, `get_formation_heroes() -> Array[HeroInstance]`, signal return-types | LOW | Stable 4.4+ with direct ADR-0010 precedent. |
| Property-getter read-only pattern (`var x: int: get: return _x`) | Stable 4.0+ | ADR-0012 §Decision §1 HeroInstance five-field read-only exposure | LOW | Stable 4.0+; godot-gdscript-specialist forward-looking NOTE documents the boilerplate is GDScript idiom; Godot 5 may add `readonly` keyword. MVP accepts. |
| Typed signals with RefCounted payload (`signal hero_recruited(instance: HeroInstance)`) | Godot 4.0+ (typing) | ADR-0012 §Decision §2 three signals | LOW | Stable; godot-gdscript-specialist forward-looking NOTE clarifies typed payloads are documentation-only at parse time (runtime dispatch is still dynamic). No mitigation needed. |

No new engine-state verifications added by ADR-0012 — all primitives have direct ADR precedent or are stable 4.0+ patterns.

### Engine Specialist Consultation

godot-gdscript-specialist was invoked at ADR-0012 authoring time (Step 4.5) — **APPROVE-WITH-NOTES** recorded in ADR-0012 §Specialist Review (per session state). Ten notes issued:

- **2 LOAD-BEARING (folded in-place)**:
  - NOTE #3: `var sorted_ids: Array = _heroes.keys()` → `var sorted_ids: Array[int] = _heroes.keys()` — Dictionary[int, T].keys() returns Array[int] in Godot 4.4+; explicit annotation satisfies the project static-typing mandate.
  - NOTE #10: `seed_first_launch_state()` gained `assert(_heroes.is_empty(), "seed_first_launch_state called on non-empty roster")` guard against contract violation on erroneous invocation after partial load.
- **8 forward-looking (retained for implementation-story awareness)**: property-getter pattern idiom + Godot 5 `readonly` note; factory vs zero-arg `.new()` consistency; signal-payload types are doc-only at runtime; `_boot_validating` vs `set_block_signals()` tradeoff (per-signal vs bulk); int→float promotion in `get_formation_strength` sum; PackedStringArray `in` operator coercion caveat; rank-7 `_ready()` race-window analysis (clean per Claim 1 [VERIFIED]); `Dictionary.get(key, default)` null-default semantics.

No mechanically-wrong engine claims flagged. No new deprecated-API flags.

### Outstanding verifications (pre-MVP-ship)

Unchanged from prior review:

1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe; AC-DLS-01 covers implicitly. ADR-0011's `extends GameData` inherits this pending verification; ADR-0012's consumer chain (`DataRegistry.resolve("classes", id) -> HeroClass`) depends on the same.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10) — now also covers ADR-0012 `get_formation_strength` p99 < 50µs performance budget.
3. **iOS/Android atomic-rename fallback** (ADR-0004 Risk #4).

No new verifications added by ADR-0012.

---

## GDD Revision Flags (Architecture → Design Feedback)

**None.**

- `design/gdd/economy-system.md:549` was synced in lockstep with ADR-0012 authoring (provisional "roster GDD may refine the signature" annotation replaced with ADR-0012 citation; bidirectional-consistency entry added to `hero-roster.md` §F confirming the provisional tag resolved).
- `design/gdd/hero-roster.md` itself is the authoritative source ADR-0012 ratifies verbatim — GDD + ADR aligned from birth.
- No other GDDs touched by ADR-0012's scope.

No new GDD revision flags surfaced by this review.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (Draft, last amended in-session 2026-04-22 with ADR-0012):

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow coverage | ✅ (4 diagrams: frame, offline, persist, hydrate) |
| API boundaries support integration requirements | ✅ — HeroRoster API surface fully reflected |
| Orphaned architecture | ⚠️ Same as prior: HD2D + VFX deferred; Onboarding + SettingsAccessibility deferred. Acceptable for MVP. |
| Internal consistency (post ADR-0012 landing) | ✅ **CLEAN — NO DRIFT** |

### Drift status: CLEAN

All artifact cascades landed **in lockstep** with ADR-0012 authoring (departing from the 22b/22c/22d pattern where drift was surfaced by `/architecture-review` and fixed in a same-day follow-up). Verified in-review by spot-reading architecture.md at lines 1-20 and 700-740:

| Location | Expected post-ADR-0012 state | Verified |
|---|---|---|
| `architecture.md:7` (Version) | ADR-0012 Accepted 2026-04-22 landing note appended with HeroRoster + HeroInstance scope | ✅ |
| `architecture.md:8` (Last Updated) | "2026-04-22 (post `/architecture-decision` ADR-0012 landing + Accept promotion + registry lockstep + economy-system.md provisional cleanup)" | ✅ |
| `architecture.md:13` (ADRs Referenced) | "ADR-0001 through ADR-0012 (all Accepted as of 2026-04-22)" | ✅ |
| `architecture.md:713` (§Required ADRs Feature Layer — ADR-X03 row) | Row header "ADR-X03 → **ADR-0012 (Accepted 2026-04-22)**" with full landed scope in Decides-column; Blocks-column refreshed | ✅ |
| `architecture.md:727-729` (total-count paragraph) | "12 Accepted / 4 remain to author (C01, C03, X02, X04)"; top-priority ADR-C01 | ✅ |

No drift items surfaced. This review does NOT apply any architecture.md edits.

### Traceability index update (applied in this review)

`docs/architecture/requirements-traceability.md` is updated in this review to reflect:

- Last Updated bumped to 2026-04-22e
- Verdict annotation bumped to 22e review cite
- Coverage Summary bumped to ~349 / ~82% (+28 from ADR-0012)
- hero-roster row: Governing ADRs → `ADR-0003, ADR-0012`; gap count → ~0; Gap-Maps-To → "ADR-0012 now Accepted — full coverage"
- New ADR-0012 cross-ref section appended (full TR coverage + 5 §Decision anchors + Registry expansion summary)
- Required ADRs authoring order renumbered: ADR-X03 removed (now landed as ADR-0012); C01 → 1; X02 → 2
- Re-run Log row appended for 22e

### Registry status

`docs/registry/architecture.yaml` was expanded in lockstep with ADR-0012 authoring (7 interfaces + 6 api_decisions + 8 forbidden_patterns + 1 perf budget + 2 referenced_by bumps per session state). NOT touched by this review.

`docs/architecture/tr-registry.yaml` — header note appended for 22e re-run; no TR-IDs added or text-bumped.

---

## Verdict: **CONCERNS** (gap-only, reduced severity vs 22d)

**Why not PASS**:
1. 2 unwritten Required ADRs still block ~32 Core/Feature TRs (ADR-C01 ~20 TRs + ADR-X02 ~8-12 TRs spread across Orchestrator / Economy / biome-dungeon-db). This is a −1 from the prior review's 3 unwritten Required ADRs (ADR-X03 now landed as ADR-0012).
2. 2 additional Required ADRs remain blocked on their own undesigned GDDs (ADR-C03 Audio + ADR-X04 Recruitment) — these are GDD gaps, not architectural gaps; outside `/architecture-review` scope.

**Why not FAIL**:
- No structural conflicts. ADR-0012 inherits cleanly from ADR-0003/0004/0006/0011 and reinforces (never contradicts) ADR-0009 + ADR-0010 statelessness.
- No GDD revision flags surfaced. Lockstep economy-system.md cleanup completed within the authoring session.
- All 12 Accepted ADRs are dependency-ordered, engine-verified, and internally consistent.
- ADR-0012's content is materially correct and fully covers its scope (1 RefCounted value type + 1 autoload module + 4-method mutation API + 16-method read API + 3 typed signals + 4-step boot validation order + 1 ADR-elevated forbidden pattern + 5 alternatives exhaustively considered + 7 risks with mitigations + 10 specialist notes processed).
- The ~44 remaining gaps are all routed to Required ADRs already enumerated in architecture.md §Required ADRs (ADR-C01, ADR-X02) or to undesigned-GDD ADRs (ADR-C03, ADR-X04) or to the V1.0 deferral (ADR-X05) or to non-ADR territory (Art Bible palette_key content validation). Expected state after Core Phase-2 + Feature Phase-2 ADRs land.
- Coverage crosses ~82% for the first time — PASS candidacy is single-ADR-away.
- **NO DRIFT ITEMS** — architecture.md cascaded in lockstep during ADR-0012 authoring (cleaner than the 22b/22c/22d pattern which each had to run a follow-up drift-fix pass).

### Blocking Issues (must resolve before PASS verdict)

**None are same-day mechanical cascades.** This is the first review in the 22a/b/c/d/e series to surface **zero** same-day blocking drift-fix items — ADR-0012 landed with full in-session cascade (artifacts + economy-system.md + architecture.md + registry all synced before the ADR was promoted to Accepted). The verdict gap is purely "more Required ADRs need to be authored," which is expected project progression rather than review-surfaced drift.

The path to PASS:

1. **Author ADR-C01** (Economy state shape + recruitment cost curve + drip ticker). Consumes ADR-0012-locked `roster.get_formation_strength` + `roster.get_copies_owned` signatures + ADR-0011-locked `HeroClass.tier` + `EnemyData.tier` input contracts. Projected post-C01 coverage: ~87% → PASS candidate pending re-run confirmation.
2. **Author ADR-X02** (Offline batch chunking + offline-replay snapshot schema). Consumes ADR-0009 + ADR-0010 + ADR-0011 + ADR-0012; Orchestrator snapshot allowlisted from ADR-0012 `caching_heroinstance_reference_across_save_boundary` forbidden pattern. Projected post-X02 coverage: ~92%+ → clear PASS.

### Non-Blocking Findings

- Open questions unchanged from prior review: OQ-1, OQ-4, OQ-5 (partial), OQ-7, OQ-8, OQ-9, OQ-10. None blocks MVP.
- 2 Required ADRs remain unwritten (C01, X02) — expected; routing is correctly scoped in architecture.md §Required ADRs.
- 2 Required ADRs blocked on undesigned GDDs (ADR-C03 Audio, ADR-X04 Recruitment) — GDD authoring precedes ADR authoring; outside this review's scope.
- godot-gdscript-specialist NOTE #8 (typed Array covariance gotcha, retained from ADR-0011 specialist review) remains a V1.0 forward-looking concern; not an MVP concern.
- ADR-0012 §Risks — field-typed HeroInstance caching mitigation relies on a new CI test `heroroster_identity_test.gd` that greps `src/presentation/` + `src/ui/` for field-typed HeroInstance vars. This CI test does NOT exist yet (no `src/` exists yet); must land alongside the first HeroRoster implementation story.

---

## Immediate Actions (recommended order)

1. **Open a fresh `/architecture-decision` session for ADR-C01** (Economy state shape + recruitment cost curve + drip ticker). Unblocks Economy system (~20 TRs). Cites ADR-0012 for `get_formation_strength` + `get_copies_owned` consumer signatures; cites ADR-0011 for `HeroClass.tier` + `EnemyData.tier` input contracts; cites ADR-0002 for LOSING first-clear reclaimable semantics (`floor_clear_bonus_credited` ledger shape).
2. After ADR-C01 lands, re-run `/architecture-review` to verify coverage rises (projected ~87%) and no new conflicts. Expected verdict: **CONCERNS → PASS candidate** pending ADR-X02.
3. Open a fresh `/architecture-decision` session for **ADR-X02** (Offline batch chunking + offline-replay snapshot schema). Final architectural gap; projected post-X02 coverage ~92%+. Explicitly allowlists the Orchestrator-owned formation snapshot from ADR-0012's `caching_heroinstance_reference_across_save_boundary` forbidden pattern.
4. After ADR-X02 lands, re-run `/architecture-review` → expected **PASS verdict**.
5. When PASS verdict confirmed: `/create-control-manifest` → `/gate-check pre-production` → `/create-epics layer: foundation` → `/create-stories` → `/sprint-plan`.

### Rerun Trigger

Re-run `/architecture-review` after each new ADR lands. Given 22e surfaced zero drift items, future authoring sessions should continue the lockstep-cascade pattern demonstrated by ADR-0012.

---

## Files Written This Review

- `docs/architecture/architecture-review-2026-04-22e.md` — this report
- `docs/architecture/requirements-traceability.md` — coverage summary bumped to ~82%; hero-roster row updated (Governing ADRs add ADR-0012, gap ~0); ADR-0012 cross-ref section appended; Required ADRs authoring order renumbered; Re-run Log row appended
- `docs/architecture/tr-registry.yaml` — header note appended for 22e run; no TR-IDs added or text-bumped
- `production/session-state/active.md` — Session Extract appended

No GDD edits, no ADR edits, no architecture.md edits performed by this review — none are needed (ADR-0012 artifact cascades landed in lockstep during authoring).

---

## Summary

ADR-0012 lands cleanly. Coverage crosses ~82% (321 → ~349 of 425; +28). No cross-ADR conflicts, no GDD revision flags, no engine anti-patterns, **no drift items** — the first review in the 22a/b/c/d/e series with zero same-day follow-up cascades. All 12 ADRs Accepted; dependency graph acyclic; forward-reference to ADR-X02 documented and expected. Next best unwritten Required ADR: **ADR-C01 (Economy)**, projected coverage ~87% on landing; then **ADR-X02 (Offline snapshot)**, projected ~92%+ for clear PASS.
