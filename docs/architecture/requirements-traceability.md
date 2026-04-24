# Architecture Traceability Index

> Last Updated: 2026-04-22g (seventh re-run — post ADR-0014 Accepted landing — **PASS**)
> Engine: Godot 4.6 (pinned 2026-02-12)
> Populated by: `/architecture-review full` (2026-04-22 initial; 22b re-run + drift-fix; 22c third re-run covering ADR-0010; 22d fourth re-run covering ADR-0011; 22e fifth re-run covering ADR-0012; 22f sixth re-run covering ADR-0013; 22g seventh re-run covering ADR-0014)
> Verdict: **PASS** (see `architecture-review-2026-04-22g.md` §Verdict — all MVP-scope Required ADRs Accepted; all architectural-layer gaps closed; remaining gaps route to GDD-authoring, V1.0 deferral, or non-ADR territory; THIRD consecutive review with ZERO same-day drift-fix items)

## Coverage Summary

| Metric | Count | Δ vs prior run |
|---|---|---|
| **Total requirements** | **425** | unchanged |
| ✅ Covered (explicit ADR coverage) | ~382 (~90%) | **+12** (ADR-0014 closes 8-12 TRs routed to ADR-X02: orchestrator batch chunking / snapshot schema / yield policy / mid-run persist; economy offline-batch chunking integration + first-clear dedup; biome-dungeon-db TR-019 offline-retrigger; plus some partials flip to covered) |
| ⚠️ Partial | ~27 (~6%) | −5 (some orch/economy/scene-manager/time/matchup partials now fully covered by ADR-0014) |
| ❌ Gap (no ADR yet) | ~16 (~4%) | **−7** |

Gap breakdown is entirely content-authoring / V1.0-deferred / non-ADR. **All architectural-layer gaps for MVP are closed.** Foundation layer (ADR-0003 through ADR-0008) complete. Core DB (ADR-0011), Economy (ADR-0013), Hero Roster (ADR-0012), MatchupResolver (ADR-0009), CombatResolver (ADR-0010), and **OfflineProgressionEngine (ADR-0014)** all Accepted. Coverage crosses **~90%** — **PASS verdict achieved**. Remaining ~16 gap TRs route to: direct orchestrator stories (biome-dungeon-db TR-015/016/018 + floor-unlock direct-story items + save-load minor UX/debug), Art Bible content authoring (biome-dungeon-db TR-023 palette_key), or V1.0 deferral (ADR-X05 floor-unlock designer-UI with runtime fallback). The 2 remaining Required-ADR slots (ADR-C03 Audio, ADR-X04 Recruitment) are blocked on their own undesigned GDDs — GDD gaps, not architectural gaps; outside `/architecture-review` scope.

## How to read this index

- **TR-ID** format: `TR-[system-slug]-[NNN]` (zero-padded 3-digit sequence per system). **IDs are permanent** — never renumber, never reuse.
- Full requirement text, status field, and gdd-pointer live in `tr-registry.yaml`.
- This index is the **audit-friendly cross-reference** between requirements and the ADRs that govern them.

## Per-System Coverage Matrix

### Foundation Layer

| System | TR Range | Total | Governing ADRs | Gap Count | Gap Maps To |
|---|---|---|---|---|---|
| save-load | TR-save-load-001..060 | 60 | ADR-0003, 0004, 0005, 0007, **0014** | ~3 | minor UX/debug; direct story OK |
| time | TR-time-001..036 | 36 | ADR-0003, 0005, **0014** | ~1 | — (AC-TICK-10 dual-budget clarification landed via Pass-ADR-0014-SYNC) |
| data-loading | TR-data-loading-001..028 | 28 | ADR-0003, 0006, 0011 | ~1 | — |
| scene-manager | TR-scene-manager-001..039 | 39 | ADR-0003, 0007, 0008, **0014** | ~2 | OQ-7 (Settings GDD #30) — modal show/hide during offline replay now covered by ADR-0014 §5 |

### Core Layer

| System | TR Range | Total | Governing ADRs | Gap Count | Gap Maps To |
|---|---|---|---|---|---|
| **hero-class-db** | **TR-hero-class-db-001..024** | **24** | **ADR-0006, ADR-0011** | **~0** | **ADR-0011 now Accepted — full coverage** |
| **enemy-db** | **TR-enemy-db-001..023** | **23** | **ADR-0006, ADR-0011** | **~0** | **ADR-0011 now Accepted — full coverage** |
| **biome-dungeon-db** | **TR-biome-dungeon-db-001..028** | **28** | **ADR-0006, ADR-0011, ADR-0013, ADR-0014** | **~4** | direct orchestrator story (TR-015/016/018); Art Bible (TR-023 palette_key content) — **TR-017 BASE_DRIP lookup unblocked by ADR-0013; TR-019 offline FLOOR_CLEAR_BONUS retrigger prevention closed by ADR-0014 §2 monotonic fields** |
| matchup-resolver | TR-matchup-resolver-001..033 | 33 | ADR-0009, **0014** | ~1 | minor (CI helper wording) — zero-call-during-replay invariant CI-enforced by ADR-0014 allowlist scope |

### Feature Layer

| System | TR Range | Total | Governing ADRs | Gap Count | Gap Maps To |
|---|---|---|---|---|---|
| combat | TR-combat-001..032 | 32 | ADR-0010, **0014** | ~0 | — (AC-COMBAT-10 parity invariant preserved across chunk boundaries per ADR-0014 §Consequences) |
| orchestrator | TR-orchestrator-001..032 | 32 | ADR-0001, 0002, 0003, 0004, 0005, 0009, 0010, 0013, **0014** | **~0** | — **ALL 4 gap TRs (batch chunking strategy, offline-replay snapshot schema, yield policy, mid-run persist semantics) closed by ADR-0014** |
| **economy** | **TR-economy-001..028** | **28** | **ADR-0002, ADR-0013, ADR-0014** | **~0** | — **Both 2 partial TRs (offline batch chunking integration, first-clear-awarded dedup against replay edge case) closed by ADR-0014 aggregate-emit-ordering policy** |
| **hero-roster** | **TR-hero-roster-001..030** | **30** | **ADR-0003, ADR-0012, ADR-0014** | **~0** | **ADR-0014 allowlist exception precisely-scoped — invariant preserved** |
| floor-unlock | TR-floor-unlock-001..032 | 32 | ADR-0002, 0003 | ~18 | direct story OK for MVP-scope; ADR-X05 deferred V1.0 (runtime fallback works) |

---

## ADR → TR Cross-Reference

### ADR-0001 (Mid-Run Formation Reassignment)
- **Primary coverage**: TR-orchestrator-020, TR-orchestrator-021, TR-orchestrator-025
- **Supporting**: TR-combat-001/002/003/029
- **RunSnapshot invariants**: TR-orchestrator-004, TR-orchestrator-005

### ADR-0002 (LOSING First-Clear Monotonic Credit)
- **Primary coverage**: TR-economy-011, TR-economy-012, TR-economy-013, TR-economy-024
- **Orchestrator side**: TR-orchestrator-017, TR-orchestrator-018
- **Floor Unlock parity**: TR-floor-unlock-009, TR-floor-unlock-027

### ADR-0003 (Autoload Rank Table Canonical — triple-amended 2026-04-22)
- **Rank assignments**: TR-save-load-031, TR-time-001, TR-data-loading-001, TR-orchestrator-023, TR-floor-unlock-001/003
- **Rank invariant + forward-connect pattern**: TR-save-load-034, TR-time-017, TR-floor-unlock-006
- **Amendments**:
  - #1 (rank invariant phrasing) — signal subscription is rank-independent; only state READS at `_ready()` are rank-constrained.
  - #2 (CONFLICT-1 + CONFLICT-2 resolution) — ranks 8 and 9 vacated; MatchupResolver + CombatResolver reclassified as non-autoload RefCounted modules.
  - #3 (`_init(args)` phrasing corrected) — supersedes Amendment #2's `_init(combat_resolver, matchup_resolver)` phrasing with the lazy-default-with-public-setters pattern from `dungeon-run-orchestrator.md` §J.1 Option A (backed by `autoload.md` Claim 4 [VERIFIED]). Project-wide CI forbidden pattern `autoload_init_with_required_args` added.

### ADR-0004 (Save Envelope + HMAC Scheme)
- **Envelope layout**: TR-save-load-001..005
- **HMAC scheme**: TR-save-load-019..022
- **Validation order**: TR-save-load-023, TR-save-load-024
- **_meta sub-schema**: TR-save-load-027..030
- **Consumer contract**: TR-save-load-006, TR-save-load-033, TR-save-load-034, TR-save-load-035
- **Atomic write**: TR-save-load-012..015
- **CI / anti-tamper**: TR-save-load-050..054

### ADR-0005 (Time System Dual-Clock)
- **Wall/Sim separation**: TR-time-002..006
- **20Hz accumulator**: TR-time-005, TR-time-010
- **`tick_fired` synchronous**: TR-time-013, TR-time-014
- **State machine + BG/FG**: TR-time-008, TR-time-015, TR-time-034
- **Heartbeat partial envelope**: TR-time-012, TR-time-031 (refines ADR-0004)
- **Bidirectional Save/Load contract**: TR-time-032, TR-save-load-041
- **flag_suspicious_timestamp state-vs-signal**: TR-time-017..019, TR-save-load-042
- **Debug-only surface**: TR-time-020, TR-time-021

### ADR-0006 (Data Loading Boot Scan)
- **Autoload rank 1**: TR-data-loading-001
- **Directory layout**: TR-data-loading-002, TR-data-loading-003
- **GameData abstract base**: TR-data-loading-004..006 (NOW also backs hero-class-db + enemy-db GDDs post-sync — see prior review GDD Revision Flags CLEARED)
- **Eager synchronous load**: TR-data-loading-007, TR-data-loading-008
- **Read-only contract**: TR-data-loading-009
- **Hot-reload (dev)**: TR-data-loading-010, TR-data-loading-013
- **State machine + signals**: TR-data-loading-011, TR-data-loading-012
- **resolve() API**: TR-data-loading-014, TR-data-loading-024
- **Validation**: TR-data-loading-016..019, TR-data-loading-023
- **Save/Load hydration gate**: TR-save-load-043

### ADR-0007 (Scene Transition + Persist Coupling)
- **Autoload + persistent root**: TR-scene-manager-001..003
- **Screen base class + swap**: TR-scene-manager-004, TR-scene-manager-005, TR-scene-manager-033
- **State machine**: TR-scene-manager-012..014
- **`scene_boundary_persist`**: TR-scene-manager-015, TR-scene-manager-016, TR-scene-manager-035, TR-save-load-009, TR-save-load-057
- **Pause coupling**: TR-scene-manager-018, TR-scene-manager-019, TR-time-034
- **Transition mechanics**: TR-scene-manager-020..025
- **Performance + leaks**: TR-scene-manager-030, TR-scene-manager-031

### ADR-0008 (UI Framework Dual-Focus Parity + Parchment Theme)
- **Non-autoload pattern**: confirmed in scene-manager interactions
- **Tap-target enforcement**: cross-references all screen TRs via `UIFramework.assert_tap_target_min`
- **Steam Deck viewport strategy**: confirms architecture.md OQ-5 partial closure
- Note: UI Framework has no dedicated GDD; ADR-0008 is the authoritative source

### ADR-0009 (Matchup Resolver DI + Majority Threshold) — **Accepted 2026-04-22b**
- **Module shape + statelessness**: TR-matchup-resolver-001, TR-matchup-resolver-002, TR-matchup-resolver-003, TR-matchup-resolver-030
- **Injection contract** (lazy-default + public setters): TR-matchup-resolver-004 (text bumped 2026-04-22b; revised date set)
- **MatchupResult schema**: TR-matchup-resolver-005, TR-matchup-resolver-006
- **Aggregation rule (majority threshold)**: TR-matchup-resolver-007..014
- **Offline replay zero-call invariant**: TR-matchup-resolver-020..024
- **CI structural invariants**: TR-matchup-resolver-025..029, TR-matchup-resolver-031..033
- **Combat companion (CombatResolver)**: ADR-0010 (Accepted 2026-04-22c) re-uses ADR-0009's `set_combat_resolver` setter + lazy-default `_ready()` DI seam verbatim; `MatchupResult` consumed per-enemy inside `_kill_schedule_for_loop`
- **Archetype constant set**: ADR-0011 §Archetype constant set (`EnemyArchetypes.ALL_SET`) is the single-source-of-truth enum `MatchupResult.matched_archetypes` elements MUST come from; `referenced_by` bump on `matchup_result_value_type` registry entry
- **ADR-X02 cross-reference**: `MatchupResult.matched_archetypes` persisted in offline-replay snapshot (snapshot schema owned by future ADR-X02)

### ADR-0010 (Combat Resolver — Snapshot Shape + Foreground/Offline Parity) — **Accepted 2026-04-22c**
- **Module shape + statelessness**: TR-combat-001, TR-combat-004, TR-combat-029, TR-combat-030 (zero class-scope var, zero signal, no public static func; `CombatResolver` + `DefaultCombatResolver` non-autoload)
- **Two-public-entry-point contract**: TR-combat-002
- **Shared-private-helper parity invariant (structural, not aspirational)**: TR-combat-003, TR-combat-022, TR-combat-023
- **Five RefCounted value types** (`KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot`; `MatchupResult` consumed from ADR-0009): TR-combat-013, TR-combat-014, TR-combat-015
- **Dict equality by key-walk (hash-based forbidden)**: TR-combat-016
- **Float compare via `is_equal_approx`; typed dicts engine-checked**: TR-combat-017
- **Offline aggregate-only output asymmetry (perf contract)**: TR-combat-023, TR-combat-024
- **Kill schedule arithmetic (`ceili`, integer-only, no RNG, no time reads)**: TR-combat-005..012, TR-combat-018..021, TR-combat-025..028, TR-combat-031, TR-combat-032
- **`error_logger: Callable` per-call DI (AC-COMBAT-11)**: TR-combat-020
- **Injection contract** — re-uses ADR-0009 §Injection contract verbatim; TR-orchestrator-008 now ADR-backed via ADR-0010 §Architecture diagram foreground path
- **Orchestrator-side parity invariants**: TR-orchestrator-022, TR-orchestrator-028, TR-orchestrator-029 now ADR-backed via ADR-0010 §Parity invariant — formal statement
- **Performance budget registered**: `combat_compute_offline_batch` (100ms p95 CI / 200ms p95 min-spec mobile for 576k-tick batch — BLOCKING, backs AC-COMBAT-14 + TR-combat-024)

### ADR-0012 (Hero Roster Mutation API + HeroInstance Identity Stability) — **Accepted 2026-04-22**
- **HeroInstance shape lock**: TR-hero-roster-001, TR-hero-roster-002, TR-hero-roster-003, TR-hero-roster-004, TR-hero-roster-012 (class_name extends RefCounted; 5-field set; to_dict/from_dict; no-mutation-methods-on-instance; immutability contract)
- **HeroRoster state + container locks**: TR-hero-roster-005, TR-hero-roster-006, TR-hero-roster-007, TR-hero-roster-028, TR-hero-roster-030 (extends Node rank 7; Dictionary[int, HeroInstance]; Array[int] formation; underscore-private encapsulation; roster_config.tres tuning knobs)
- **Mutation API**: TR-hero-roster-008, TR-hero-roster-013, TR-hero-roster-014 (add_hero cap+resolve; set_hero_level clamp+push_warning; set_formation_slot auto-clear)
- **Signals + suppression**: TR-hero-roster-009, TR-hero-roster-010 (three typed signals; `_boot_validating` suppression per ADR-0004 inheritance)
- **Identity stability (ADR-elevated forbidden pattern)**: TR-hero-roster-011 + new `caching_heroinstance_reference_across_save_boundary` forbidden pattern codifies the implicit GDD Rule 4 + Rule 13 cross-save boundary rule; consumers reference by `instance_id: int` and re-resolve via `get_hero(id)`
- **Boot validation order**: TR-hero-roster-015, TR-hero-roster-016 (4-step order: orphan drop → slot clear → cap trim → next_id repair; atomic before signal emission per ADR-0004; `_orphaned_heroes` accumulation drives player-facing notice)
- **Economy formula contract**: TR-hero-roster-017, TR-hero-roster-018, TR-hero-roster-027 (get_formation_strength verbatim per GDD §D.1; avg_formation_level helper; get_formation_heroes skips empty slots; range [1.0, 3.0] locked for forthcoming ADR-C01)
- **Save/Load contract**: TR-hero-roster-019, TR-hero-roster-025, TR-hero-roster-029 (save dict shape {heroes, formation_slots, next_instance_id}; duplicate instance_id last-write-wins + push_error; full round-trip preservation)
- **First-launch seed**: TR-hero-roster-020, TR-hero-roster-021 (seed_first_launch_state Roster-owned deterministic Theron at id=1 slot 0; Onboarding does NOT inject)
- **Name pool**: TR-hero-roster-022, TR-hero-roster-023 (`_select_name_from_pool` uniform random over available; fallback `{base} the {ordinal}`; ≥20 names per class validated by ADR-0006 required-resource contract)
- **Performance**: TR-hero-roster-024 (ADVISORY 50µs p99 budget registered; rolls into ADR-0004 save_load_roundtrip for load path)
- **Default sort**: TR-hero-roster-026 (BY_CLASS registry declaration order then BY_LEVEL_DESC via `_default_sort_comparator` + `DataRegistry.get_declaration_index`)
- **Economy cross-consumer confirmation**: `economy-system.md:549` provisional "roster GDD may refine the signature" annotation cleaned up in lockstep (ADR-0012 citation added; bidirectional-consistency entry in `hero-roster.md` §F marks provisional tag resolved)
- **Registry expansion**: 7 interfaces (hero_instance_shape, hero_roster_mutation_api, hero_roster_read_api, 3 signal interfaces, seed_first_launch_contract); 6 api_decisions (heroinstance_value_type_choice, instance_id_scheme, roster_state_container_choice, formation_state_ownership, roster_boot_validation_order, heroinstance_reference_lifetime); 8 forbidden_patterns; 1 performance_budget (get_formation_strength_call ADVISORY); 2 `referenced_by` bumps (ADR-0011 hero_class_schema + ADR-0006 data_resolve_contract)
- **Forward reference to ADR-X02**: Orchestrator-owned formation snapshot will be allowlisted from `caching_heroinstance_reference_across_save_boundary` forbidden pattern by ADR-X02 (documented in ADR-0012 §5 + §Related Decisions — explicit handoff, not a conflict)

### ADR-0011 (Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor) — **Accepted 2026-04-22d**
- **HeroClass schema**: TR-hero-class-db-001..024 (16-field schema + role taxonomy + archetype taxonomy + 12 ACs H-01..H-12)
- **EnemyData schema**: TR-enemy-db-001..023 (13-field schema + archetype distribution invariant + 8 MVP stat blocks + boss HP 4818 per Pass 2B)
- **Biome / Dungeon / Floor schemas**: TR-biome-dungeon-db-001..014, TR-biome-dungeon-db-020..028 (7+4+5 field sets + Forest Reach MVP composition + multi-dungeon forward-compat)
- **Archetype + Role constant sets**: single-source-of-truth enums (`EnemyArchetypes.ALL_SET` / `MVP_SET`; `ClassRoles.ALL_SET`); forbidden patterns forbid hardcoding archetype/role strings outside these modules; cross-references `MatchupResult.matched_archetypes` element universe per ADR-0009
- **Cross-type validators**: archetype distribution (F1-F3 cover 3 MVP archetypes), boss-floor uniqueness within Dungeon, is_boss_floor↔EnemyData.is_boss parity, HeroClass.counter_archetype ∈ MVP_SET for tier==1 classes
- **`Floor.enemy_list: Array[Dictionary]` id-string contract**: save-file stability + hot-reload safety rationale; DAG boundary between Floor and EnemyData via `DataRegistry.resolve("enemies", enemy_id)` round-trip
- **ADR-0010 `Floor` opaque type locked**: Combat implementers can now cite `floor.enemy_list[i].enemy_id` + `floor.is_boss_floor` + `floor.floor_index` with concrete typed contracts
- **Remaining biome-dungeon-db gap** (6 TRs): TR-015/016/018 (orchestrator behavior); TR-017 (Economy BASE_DRIP lookup → ADR-C01); TR-019 (offline FLOOR_CLEAR_BONUS retrigger → ADR-X02); TR-023 (palette_key match Art Bible — not ADR territory)
- **Registry expansion**: 7 new interfaces, 4 new api_decisions, 5 new forbidden_patterns, 4 `referenced_by` bumps on ADR-0006 + ADR-0009 + ADR-0010 entries
- **No new performance budget**: costs fit inside ADR-0006's `boot_scan_time` + `total_loaded_memory` budgets (validation <10ms for all 5 subclasses; content ~400 KB total)

### ADR-0013 (Economy State Shape + Cost Curves + Offline Batch Contract) — **Accepted 2026-04-22**
- **State shape**: TR-economy-001, TR-economy-002, TR-economy-003, TR-economy-004, TR-economy-005 (`_gold_balance: int` int64 + 1 T sanity cap; `_lifetime_gold_earned: int` unbounded statistic; `_floor_clear_bonus_credited: Dictionary[int, int]` ADR-0002 monotonic ledger; `_is_offline_replay: bool` transient not persisted; autoload rank 3 per ADR-0003 + zero-arg `_init` per Amendment #3)
- **Public API**: TR-economy-006, TR-economy-007, TR-economy-008, TR-economy-009, TR-economy-010, TR-economy-011, TR-economy-012 (7-method surface: `add_gold(amount, reason)`, `try_spend(amount, reason) -> bool`, `try_award_floor_clear(floor_index, bonus_amount) -> bool`, `recruit_cost(class_id: String, copies_owned: int) -> int`, `level_cost(class_tier, current_level) -> int`, `compute_offline_batch(tick_budget) -> OfflineResult`, `get_save_data`/`load_save_data`; all signatures concretely typed)
- **Cost curve contracts**: TR-economy-013, TR-economy-014, TR-economy-015, TR-economy-016, TR-economy-017, TR-economy-018, TR-economy-019 (`recruit_cost` tier-gated `BASE_RECRUIT[tier] × copies_owned` multiplier; `level_cost` tier-gated `BASE_LEVEL[tier] × current_level / LEVEL_COPIES_DIVISOR` with `-1` cap-sentinel past `LEVEL_CAP`; Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant — Economy never reads losing-run state)
- **Offline batch contract**: TR-economy-020, TR-economy-021, TR-economy-022, TR-economy-023, TR-economy-024 (closed-form drip O(1) multiply + batch-event iteration + signal suppression during replay via `_is_offline_replay` flag + single aggregate `gold_changed` emit after; AC H-10 500ms offline-batch budget codified as `compute_offline_batch_economy_share` performance_budget, Economy ~100–150ms ceiling)
- **Signal contract**: TR-economy-025, TR-economy-026, TR-economy-027 (`gold_changed(new_balance: int, delta: int, reason: String)` 3-arg; `first_clear_awarded(floor_index: int)` at-most-once-per-floor-per-save; both suppressed during offline replay)
- **Tuning knob location**: TR-economy-028 (all 26 knobs in `assets/data/config/economy_config.tres` via `EconomyConfig extends GameData` per ADR-0011 pattern; `hardcoded_balance_value_outside_economy_config` forbidden pattern enforces single-source-of-truth)
- **Biome-dungeon-db TR-017 unblocked**: `BASE_DRIP[floor_index]` lookup path now architecturally specified; content-authoring surface (per-floor BASE_DRIP values) remains a Biome DB authoring concern, not an architectural gap
- **Orchestrator-directional invariant codified**: `economy_reads_losing_run_state` forbidden pattern elevates the previously-implicit Orchestrator-applies-LOSING_RUN_LOOT_FACTOR GDD rule to CI-enforced
- **OfflineResult inline RefCounted**: Specialist LOAD-BEARING NOTE #9 fold — inline `class OfflineResult extends RefCounted` prevents bare-Dictionary-return-type drift and gives offline aggregate a stable schema across chunks
- **Forward references to ADR-X02**: (a) `compute_offline_batch(tick_budget)` single-call assumption — ADR-X02 will either wrap chunked calls or supersede with chunk-iterator; closed-form drip O(1) primitive preserved either way. (b) `_is_offline_replay` flag coordination — ADR-X02 snapshot schema will determine whether flag is part of snapshot or managed externally; ADR-0013 is agnostic.
- **Registry expansion**: 7 new interfaces (economy_state_shape, economy_mutation_api, economy_cost_curves_api, economy_offline_batch_contract, gold_changed_signal, first_clear_awarded_signal, economy_config_resource); 5 new api_decisions (gold_currency_storage_type, recruit_cost_id_string_not_tier, level_cost_cap_sentinel, offline_replay_closed_form_drip, economy_tuning_knob_location); 4 new forbidden_patterns (hardcoded_balance_value_outside_economy_config, economy_reads_losing_run_state, economy_signal_emission_during_offline_replay, try_spend_with_non_positive_amount); 1 new performance_budget (compute_offline_batch_economy_share AC H-10); 5 `referenced_by` bumps (ADR-0004, 0005, 0006, 0011, 0012)
- **economy-system.md Pass-ADR-0013-SYNC**: 4 signature-drift items closed in lockstep (try_spend, add_gold, recruit_cost, gold_changed) — no GDD revision flags surfaced

### ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema) — **Accepted 2026-04-22**
- **OfflineProgressionEngine autoload (rank 15)**: TR-orchestrator-010, TR-orchestrator-011, TR-orchestrator-013, TR-orchestrator-029 (class_name OfflineProgressionEngine extends Node autoload rank 15 with zero-arg `_init`; subscribes to `TickSystem.offline_elapsed_seconds` at `_ready()`; transient state container; no persisted fields)
- **RunSnapshot schema + persistence**: TR-orchestrator-004, TR-orchestrator-005, TR-orchestrator-029 (standalone `class_name RunSnapshot extends RefCounted` in `src/core/run_snapshot.gd`; 11 primitive fields + `formation_ids: Array[int]` size 3 + `matched_archetypes: Array[String]`; persisted via ADR-0004 consumer contract; orphan-hero recovery path `run_snapshot_discarded_orphan` signal + Economy refund)
- **Adaptive time-budgeted chunking**: `OFFLINE_CHUNK_TARGET_WALL_MS = 12` (25% AC-TICK-10 headroom); initial 5000 ticks; min 500; max 50000; deadband ±25%; adjust ratio 0.6; converges within 2-3 chunks under hardware skew
- **Main-thread yield strategy**: `await get_tree().process_frame` between chunks; `WorkerThreadPool` explicitly rejected for MVP (`worker_thread_pool_for_offline_replay_in_mvp` forbidden pattern prevents regression)
- **HeroInstance allowlist exception**: ADR-0012's `caching_heroinstance_reference_across_save_boundary` forbidden pattern gains precisely-scoped allowlist carve-out — lifetime-scoped to post-hydrate replay cycle; 3 allowlisted consumer call sites (CombatResolver.compute_offline_batch + emit_events_in_range + MatchupResolver.resolve); 3 CI grep invariants enforce boundary (regex broadened per LOAD-BEARING-3 to catch array-typed fields)
- **Signal emission policy**: TR-economy-025, TR-economy-026 closed for replay-edge-case (Economy `gold_changed` / `first_clear_awarded` suppressed per-chunk + single aggregate post-replay); `tick_fired` never during replay (CI-enforced via `per_chunk_domain_signal_emission_during_offline_replay`); aggregate emission order locked (Economy → Orchestrator → OfflineProgressionEngine final)
- **Progress UX (OQ-4 CLOSED)**: time-gated cozy modal; `PROGRESS_MODAL_THRESHOLD_MS = 100`; silent for <100ms estimated; cozy modal ≥100ms with indeterminate spinner + tone-of-voice variants ("Stitching your lantern lamp back on…"); determinate progress bar rejected (non-linear with adaptive chunking); instant black-out rejected (perceived-freeze hazard)
- **biome-dungeon-db TR-019 closed**: FLOOR_CLEAR_BONUS offline-retrigger prevention — RunSnapshot `kills_so_far` + `loops_executed` monotonic fields combined with ADR-0002 per-floor-at-most-once ledger (inherited via ADR-0013 `_floor_clear_bonus_credited`)
- **AC-TICK-10 dual-budget clarification**: per-chunk CPU wall time ≤16ms (BLOCKING) vs total wall-clock-including-yield ≤5s (ADVISORY, Android ANR headroom) — two distinct budgets; game-time-and-tick.md Pass-ADR-0014-SYNC cascades the clarification to GDD
- **OfflineSummary inline RefCounted**: Specialist LOAD-BEARING-1 fold — inline `class OfflineSummary extends RefCounted` with 11 telemetry-inclusive fields prevents bare-Dictionary-return memory leak (matches ADR-0013 NOTE #9 pattern)
- **Registry expansion**: 4 new interfaces (run_snapshot_schema, offline_progression_engine_api, offline_summary_shape, offline_replay_progressed_signal); 4 new api_decisions (offline_chunking_strategy adaptive time-budgeted, offline_yield_strategy main-thread await, progress_ux_threshold 100ms, run_snapshot_persistence); 5 new forbidden_patterns (offline_replay_progressed_domain_subscriber, heroinstance_cache_outside_runsnapshot_allowlist, offline_summary_field_set_expansion_without_version_bump, per_chunk_domain_signal_emission_during_offline_replay, worker_thread_pool_for_offline_replay_in_mvp); 2 new performance_budgets (offline_chunk_cpu_wall_time BLOCKING; offline_replay_total_wall_clock_budget ADVISORY); 8 `referenced_by` bumps (ADR-0003/0004/0005/0009/0010/0011/0012/0013); ADR-0012 `caching_heroinstance_reference_across_save_boundary` gains explicit `exception_allowlist` field
- **Pass-ADR-0014-SYNC GDD cascade (lockstep)**: 4 GDDs updated — dungeon-run-orchestrator.md (RunSnapshot schema + per-chunk consumption + AC-TICK-10 dual-budget); hero-roster.md (allowlist exception + 3 CI grep invariants); save-load-system.md (Orchestrator RunSnapshot payload + orphan-hero recovery via Rule 16 pattern); game-time-and-tick.md (canonical OfflineProgressionEngine subscriber + AC-TICK-10 dual-budget + TickSystem-does-not-chunk + CI-enforcement reference). No GDD revision flags surfaced.
- **ADR-0013 forward reference resolved**: "wrap without superseding" — ADR-0013's single-call `compute_offline_batch(tick_budget)` model remains correct; ADR-0014 chunk-iterator wraps it; closed-form drip O(1) primitive preserved

---

## Known Gaps (all ❌ items with suggested ADRs)

### Blocking for PASS verdict — all 3 items CLEARED (2026-04-22b)

1. ✅ **ADR-0009 promoted to Accepted** — status flip completed; content unchanged (matchup-resolver scope TR coverage now fully backed by an Accepted ADR).
2. ✅ **architecture.md drift fix pass complete** — 5 locations (lines 144, 159, 589, 600, 694) updated to reflect ADR-0003 Amendment #3 lazy-default-with-setters pattern. §Rank invariant paragraph rephrased per Amendment #1. Document Status header ADR count bumped to 0001..0009.
3. ✅ **TR-matchup-resolver-004 text bump applied** — requirement text updated to the lazy-default-with-setters pattern; `revised: "2026-04-22"` set; ID unchanged per maintenance protocol.

### Blocking for PASS verdict — all 3 items CLEARED (2026-04-22c)

1. ✅ **ADR-0010 promoted to Accepted** — status flip completed; content unchanged (combat scope TR coverage now fully backed by an Accepted ADR).
2. ✅ **architecture.md drift fix pass complete** — 5 locations (line 13 Document Status header, line 315 Module Ownership Map, line 598 API Boundaries code comment, line 711 Required ADRs row, lines 727-729 total-count paragraph) updated to reflect ADR-0010 Accepted state. ADRs Referenced header bumped to 0001..0010; Required ADRs count: 10 Accepted / 6 remaining.
3. ✅ **Traceability index drift fix applied** — coverage summary bumped to ~62% (264/425); combat row now points to ADR-0010; orchestrator row gap reduced to ~4; ADR-0009 cross-ref updated; Required ADRs authoring order renumbered (ADR-C02 now top priority); new ADR-0010 cross-ref section added.

### Required ADRs authoring order (unwritten, estimated gap coverage)

> **All MVP-scope Required ADRs are Accepted as of 2026-04-22g PASS.** Prior ADR-X02 slot is now **ADR-0014 (Accepted 2026-04-22)** — landed same-session via `/architecture-decision` with all cascades lockstep-applied. Prior ADR-C01 slot is ADR-0013 (Accepted 22f). Prior ADR-X03 slot is ADR-0012 (Accepted 22e). Prior ADR-C02 slot is ADR-0011 (Accepted 22d). Prior ADR-X01 slot is ADR-0010 (Accepted 22c). Prior ADR-C04 slot is ADR-0009 (Accepted 22b).

**No remaining Required ADRs for MVP architectural completeness.** The 2 remaining Required-ADR slots below are blocked on their own undesigned GDDs — GDD gaps, not architectural gaps; outside `/architecture-review` scope.

### Deferred (V1.0)

- **ADR-X05** — Floor Unlock designer-UI ProjectSettings pattern. OQ-1; MVP runtime fallback works.
- **Accessibility V1.0 ADR** — supersedes ADR-0008 `FOCUS_NONE` default. OQ-9.

### Not-in-scope (no GDD yet)

- **ADR-C03** — Audio System minimal MVP. Audio GDD not authored.
- **ADR-X04** — Recruitment pool generation determinism. Recruitment GDD not authored.

---

## Superseded Requirements

None — 425 TR-IDs remain the canonical set. One requirement (TR-matchup-resolver-004) has a pending text bump to reflect Amendment #3 — intent preserved, ID unchanged.

---

## Open Questions (from architecture.md + ADRs)

| OQ | Description | Source | Blocks | Status |
|---|---|---|---|---|
| OQ-1 | Floor Unlock designer-UI ProjectSettings pattern | architecture.md / Floor Unlock §I.11 | V1.0 multi-biome authoring | Deferred V1.0 |
| OQ-4 | Offline replay perceived progress UX | architecture.md / ADR-0014 §5 | Return-to-App UX | **CLOSED 2026-04-22 by ADR-0014 §5** (time-gated cozy modal; silent <100ms / modal ≥100ms) |
| OQ-5 | Steam Deck 1280×800 hardware testing access | architecture.md | MVP QA sign-off | Partial closure by ADR-0008 |
| OQ-6 | ADR-0003 rank invariant phrasing | ADR-0005 | — | **CLOSED 2026-04-22** (Amendment #1) |
| OQ-7 | `reduce_motion` Save/Load integration | ADR-0007 | Settings GDD #30 | Open |
| OQ-8 | SceneManager autoload rank assignment | ADR-0007 | Implementation-time | Open |
| OQ-9 | V1.0 keyboard/gamepad navigation strategy | ADR-0008 | V1.0 Accessibility GDD #30 | Open |
| OQ-10 | Steam Deck per-platform tap-target override | ADR-0008 | Hardware test cycle | Open |

---

## Maintenance Protocol

- `/architecture-review` re-runs append new TR-IDs at the end of each system's list in `tr-registry.yaml`; never renumber.
- When a GDD requirement is reworded (same intent), update `requirement` text + set `revised` date; ID stays stable. **Example pending**: TR-matchup-resolver-004 requires this bump.
- When a GDD requirement is removed, set `status: deprecated` (do not delete the entry).
- When a requirement is split or replaced, set `status: superseded-by: TR-xxx-NNN` with the new ID.
- `/create-stories` embeds TR-IDs into story context sections; `/story-done` cross-references against this registry at review time.

## Re-run Log

| Date | Verdict | Covered % | Gaps | Notes |
|---|---|---|---|---|
| 2026-04-22 (initial) | CONCERNS | 47% | ~192 | First population; CONFLICT-1/2 + 2 GDD revision flags surfaced. |
| 2026-04-22b (re-run) | CONCERNS | ~55% | ~161 | CONFLICT-1/2 RESOLVED; both GDD flags CLEARED; ADR-0009 (Proposed) covers matchup-resolver; 5 architecture.md drift items surfaced from incomplete Amendment #3 cascade. |
| 2026-04-22b (drift-fix follow-up) | CONCERNS → reduced to gap-only | ~55% | ~161 | All 3 blocking items CLEARED in same-day follow-up: ADR-0009 promoted to Accepted; architecture.md drift fixed (5 lines); TR-matchup-resolver-004 text bumped. Remaining CONCERNS are pure gap-driven (5 unwritten Required ADRs: X01, C02, X03, C01, X02). No structural conflicts, no internal contradictions, no stale text. Next PASS candidate: after 2 of 5 Required ADRs land (X01 + C02 would push coverage to ~85%+). |
| 2026-04-22c (third re-run — post ADR-0010 landing) | CONCERNS (gap-only) | ~62% | ~129 | ADR-0010 (Combat Resolver — Snapshot Shape + Foreground/Offline Parity) **Proposed 2026-04-22**; covers TR-combat-001..032 + ~4 orchestrator TRs (+32 total). No cross-ADR conflicts (re-uses ADR-0009 DI seam + ADR-0003 zero-arg `_init` verbatim). No new GDD revision flags (combat-resolution.md was Pass-INIT-PROBE-SYNC'd BEFORE ADR-0010 authored). 3 blocking items pending (mirrors 2026-04-22b pattern): promote ADR-0010 Proposed→Accepted; architecture.md drift fix (5 lines); traceability index drift fix (applied in this commit). Remaining CONCERNS route to 4 unwritten Required ADRs (C02, X03, C01, X02). Next PASS candidate: after ADR-C02 lands (unblocks 3 Core DB systems, ~57 TRs → ~85%+ coverage). |
| 2026-04-22d (fourth re-run — post ADR-0011 landing) | CONCERNS (gap-only, reduced severity) | ~75% | ~72 | ADR-0011 (Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor) **Proposed 2026-04-22**; covers TR-hero-class-db-001..024 + TR-enemy-db-001..023 + TR-biome-dungeon-db-001..014/-020..028 (+57 total). No cross-ADR conflicts (pure ADR-0006 inheritance — `referenced_by` bumps only, no redeclaration; locks `Floor` opaque type ADR-0010 consumes; provides archetype constant set `MatchupResult.matched_archetypes` elements must draw from per ADR-0009). No new GDD revision flags (data-loading.md was synced in lockstep with ADR-0011 authoring; 1 minor cosmetic residual at `data-loading.md:170` `Array[Enemy]` → `Array[EnemyData]`). 3 blocking items pending (mirrors 22b/22c pattern): promote ADR-0011 Proposed→Accepted; architecture.md drift fix (5 locations: line 7 Version, 8 Last Updated, 13 Document Status, 703 ADR-C02 row, 727-729 total-count paragraph); data-loading.md:170 cosmetic fix. Traceability index drift fix applied in this commit. **Coverage crosses 75% threshold for the first time.** Remaining CONCERNS route to 3 unwritten Required ADRs (X03, C01, X02). Next PASS candidate: after ADR-X03 lands (~81% coverage) or equivalently ADR-C01 lands (~80%). |
| 2026-04-22e (fifth re-run — post ADR-0012 landing) | CONCERNS (gap-only, reduced severity; **ZERO drift items**) | ~82% | ~44 | ADR-0012 (Hero Roster Mutation API + HeroInstance Identity Stability) **Accepted 2026-04-22** — authored + promoted same-session via `/architecture-decision`; covers TR-hero-roster-001..030 in full (+28 from partial ~2 covered). No cross-ADR conflicts (inheritance-only from ADR-0003/0004/0006/0011; reinforces ADR-0009 + ADR-0010 statelessness via new `caching_heroinstance_reference_across_save_boundary` forbidden pattern — no redeclaration). No GDD revision flags (economy-system.md:549 provisional "roster GDD may refine" annotation cleaned up in lockstep with ADR-0012 citation; hero-roster.md §F bidirectional-consistency entry confirms resolved). **FIRST review in 22a-22e series with ZERO same-day drift-fix items** — ADR-0012 landed all artifact cascades in lockstep during authoring (ADR file + `docs/registry/architecture.yaml` expansion + `economy-system.md:549` cleanup + `architecture.md` 5-location cascade + session state). Traceability index drift fix applied in this commit (ADR-0012 cross-ref section; hero-roster row update; Required ADRs authoring order renumbered; Re-run Log row). **Coverage crosses ~80% threshold for the first time.** Remaining CONCERNS route to 2 unwritten Required ADRs (C01, X02). Next PASS candidate: after ADR-C01 lands (~87% coverage). |
| 2026-04-22f (sixth re-run — post ADR-0013 landing) | CONCERNS (gap-only, reduced severity; **ZERO drift items** — second consecutive) | ~87% | ~23 | ADR-0013 (Economy State Shape + Cost Curves + Offline Batch Contract) **Accepted 2026-04-22** — authored + promoted same-session via `/architecture-decision`; covers 20 of 28 TR-economy TRs + unblocks TR-biome-dungeon-db-017 BASE_DRIP lookup path + adds ADR-0013 to orchestrator row governing ADRs (Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant locked). No cross-ADR conflicts (inheritance-only from ADR-0002/0003/0004/0005/0006/0011/0012; reinforces ADR-0002 monotonic ledger semantics via `_floor_clear_bonus_credited: Dictionary[int, int]` + `try_award_floor_clear` + `first_clear_awarded` at-most-once-per-floor-per-save; companions ADR-0012 consumer-side signatures `get_formation_strength()`, `get_copies_owned(class_id)` — no redeclaration). No GDD revision flags (economy-system.md Pass-ADR-0013-SYNC cleaned 4 signature-drift items in lockstep: try_spend/add_gold/recruit_cost/gold_changed signatures closed). **SECOND consecutive review** in 22a-22f series with ZERO same-day drift-fix items — ADR-0013 landed all artifact cascades in lockstep during authoring (ADR file 928 lines + `docs/registry/architecture.yaml` expansion of 7 interfaces + 5 api_decisions + 4 forbidden_patterns + 1 perf budget + 5 `referenced_by` bumps + `economy-system.md` Pass-ADR-0013-SYNC note + 4 signature closures + `architecture.md` 5-location cascade + session state). Traceability index drift fix applied in this commit (ADR-0013 cross-ref section; economy/orchestrator/biome-dungeon-db rows updated; Required ADRs authoring order renumbered; Re-run Log row). **Coverage crosses ~87% — matches 22e's projection exactly.** Remaining CONCERNS route to 1 unwritten Required ADR (ADR-X02). Next PASS candidate: after ADR-X02 lands (projected ~92%+ — clear PASS). |
| 2026-04-22g (seventh re-run — post ADR-0014 landing) | **PASS** (gap-only, **ZERO drift items** — third consecutive) | ~90% | ~16 | ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema) **Accepted 2026-04-22** — authored + promoted same-session via `/architecture-decision`, matching ADR-0012/0013 pattern; covers orchestrator TR-010/011/013/029 (batch chunking / snapshot schema / yield policy / mid-run persist) + economy offline-batch chunking integration + first-clear-dedup + biome-dungeon-db TR-019 offline FLOOR_CLEAR_BONUS retrigger prevention + OQ-4 closure (time-gated cozy modal). No cross-ADR conflicts (inheritance-only from ADR-0003/0004/0005/0009/0010/0011/0012/0013; reinforces ADR-0005 tick_fired not-during-replay invariant via new `per_chunk_domain_signal_emission_during_offline_replay` forbidden pattern; ADR-0012 `caching_heroinstance_reference_across_save_boundary` gains precisely-scoped allowlist exception with 3 CI grep invariants; resolves ADR-0013's forward reference to ADR-X02 by "wrap without superseding" — ADR-0013 single-call model remains correct, ADR-0014 chunk-iterator wraps it). No GDD revision flags (Pass-ADR-0014-SYNC notes applied in lockstep to dungeon-run-orchestrator.md + hero-roster.md + save-load-system.md + game-time-and-tick.md). **THIRD consecutive review** in 22a-22g series with ZERO same-day drift-fix items — ADR-0014 landed all artifact cascades in lockstep during authoring (ADR file 604 lines + `docs/registry/architecture.yaml` expansion of 4 interfaces + 4 api_decisions + 5 forbidden_patterns + 2 perf budgets + 8 `referenced_by` bumps + ADR-0012 `exception_allowlist` field + 4 GDD Pass-ADR-0014-SYNC notes + `architecture.md` 5-location cascade including OQ-4 closure). Traceability index drift fix applied in this commit (ADR-0014 cross-ref section; 8 row updates adding ADR-0014 to Governing ADRs; Required ADRs authoring order updated — X02 removed as landed; OQ-4 status flipped to CLOSED; Re-run Log row). **Coverage crosses ~90% — matches 22f's projection exactly. FIRST PASS verdict in 22a-22g series.** All architectural-layer gaps for MVP are closed. Remaining ~16 gap TRs route to direct orchestrator stories, Art Bible content (biome-dungeon-db TR-023 palette_key), or V1.0 deferral (ADR-X05 floor-unlock designer-UI). 2 Required-ADR slots remain blocked on their undesigned GDDs (ADR-C03 Audio, ADR-X04 Recruitment) — GDD gaps, not architectural gaps; outside `/architecture-review` scope. Unblocks `/create-control-manifest` → `/gate-check pre-production` → `/create-epics` → `/create-stories` → `/sprint-plan`. |
