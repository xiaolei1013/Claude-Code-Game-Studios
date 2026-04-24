# Architecture Review — 2026-04-22g (seventh re-run, post ADR-0014 landing — **PASS**)

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 14 (all Accepted: 0001–0014) |
| Registry State | populated (425 TR-IDs, v2, unchanged) |
| Prior Reviews | 22 (initial CONCERNS); 22b (post ADR-0009); 22c (post ADR-0010); 22d (post ADR-0011); 22e (post ADR-0012); 22f (post ADR-0013) |
| Verdict | **PASS** — all MVP-scope Required ADRs Accepted; all architectural-layer gaps closed; remaining gaps are GDD-authoring (out of scope), V1.0 deferrals, or non-ADR territory. **THIRD consecutive review with ZERO drift items.** |

---

## What changed since the prior review (2026-04-22f)

One ADR landing since the prior review, fully lockstep-cascaded in the authoring session:

1. **ADR-0014** (**Accepted 2026-04-22**, authored + promoted same-session — matches ADR-0012/0013 pattern) — Offline Replay Batch Chunking + RunSnapshot Schema. Fills the `ADR-X02` slot the 22f review flagged as the single remaining architectural gap. Codifies:
   - `class_name OfflineProgressionEngine extends Node` autoload **rank 15** (per ADR-0003 rank table, already-vacant slot); zero-arg `_init` per Amendment #3 + autoload.md Claim 4 [VERIFIED].
   - **Adaptive time-budgeted chunking** — `OFFLINE_CHUNK_TARGET_WALL_MS = 12` (25% headroom under AC-TICK-10 ≤16ms/chunk); initial 5000 ticks; min 500; max 50 000; deadband ±25%; exponential-smoothing adjust ratio 0.6. Converges within 2-3 chunks on hardware skew.
   - **Main-thread yield**: `await get_tree().process_frame` between chunks. `WorkerThreadPool` explicitly rejected for MVP (new forbidden pattern `worker_thread_pool_for_offline_replay_in_mvp` — prevents future regression).
   - **RunSnapshot schema** (11 primitive fields + `formation_ids: Array[int]` size 3 + `matched_archetypes: Array[String]`) — `class_name RunSnapshot extends RefCounted` in `src/core/run_snapshot.gd` standalone file (matches ADR-0009/0010/0013 per-class-file convention). Persisted via ADR-0004 consumer contract; Orchestrator owns.
   - **Orphan-hero recovery** (§2.3) — `HeroRoster.get_hero(id) == null` path → discard snapshot + `run_snapshot_discarded_orphan(removed_instance_id)` signal + Economy refund + cozy notify.
   - **HeroInstance allowlist exception** to ADR-0012's `caching_heroinstance_reference_across_save_boundary` forbidden pattern — lifetime-scoped to post-hydrate replay cycle; 3 allowlisted call sites (CombatResolver.compute_offline_batch + emit_events_in_range + MatchupResolver.resolve); 3 CI grep invariants enforce the boundary.
   - **OQ-4 resolved** — time-gated cozy modal (`PROGRESS_MODAL_THRESHOLD_MS = 100`); silent for <100ms estimated; cozy modal ≥100ms with cozy tone-of-voice variants + indeterminate spinner (determinate rejected: adaptive chunking makes progress non-linear).
   - **Signal emission policy** (§4 table) — `tick_fired` never during replay (ADR-0005 invariant), `gold_changed` / `first_clear_awarded` / `floor_cleared_first_time` suppressed per-chunk + aggregated post-replay; `offline_rewards_collected(summary)` emitted last (SceneManager transition waits on this).
   - **5 new CI-enforced forbidden patterns** — `offline_replay_progressed_domain_subscriber`, `heroinstance_cache_outside_runsnapshot_allowlist`, `offline_summary_field_set_expansion_without_version_bump`, `per_chunk_domain_signal_emission_during_offline_replay`, `worker_thread_pool_for_offline_replay_in_mvp`.
   - **2 new performance budgets** — `offline_chunk_cpu_wall_time` BLOCKING (AC-TICK-10 ≤16ms/chunk min-spec mobile); `offline_replay_total_wall_clock_budget` ADVISORY (≤5s for 8h cap, Android ANR headroom — distinct from the per-chunk CPU budget).
   - **`OfflineSummary` inline RefCounted** — 11 fields including telemetry (`replay_wall_ms`, `chunks_executed`, `avg_chunk_wall_usec`); prevents bare-Dictionary-return drift (same pattern as ADR-0013 NOTE #9 fold).

### Artifacts landed in lockstep during ADR-0014 authoring

1. `docs/architecture/ADR-0014-offline-replay-batch-chunking-and-snapshot-schema.md` — new ADR (Accepted, 604 lines).
2. `docs/registry/architecture.yaml` — 4 interfaces (`run_snapshot_schema`, `offline_progression_engine_api`, `offline_summary_shape`, `offline_replay_progressed_signal`); 4 api_decisions (`offline_chunking_strategy` adaptive time-budgeted, `offline_yield_strategy` main-thread await, `progress_ux_threshold` 100ms, `run_snapshot_persistence` save-persisted + orphan-recovery); 5 forbidden_patterns (listed above); 2 performance_budgets (listed above); 8 `referenced_by` cross-bumps (ADR-0003/0004/0005/0009/0010/0011/0012/0013); ADR-0012 forbidden pattern gains explicit `exception_allowlist` field documenting the carve-out.
3. `design/gdd/dungeon-run-orchestrator.md` — Pass-ADR-0014-SYNC header note: RunSnapshot schema codified at ADR level; `compute_offline_batch(tick_budget)` now consumed per-chunk by OfflineProgressionEngine (not a single call); AC-TICK-10 clarified as two distinct budgets (per-chunk CPU vs total wall-clock-with-yield ANR); persistence via ADR-0004 consumer contract + orphan-hero recovery; §J.1 Option A wiring inherited verbatim.
4. `design/gdd/hero-roster.md` — Pass-ADR-0014-SYNC header note: ADR-0012 forbidden pattern gains an ADR-0014 allowlist exception; §F cross-system contracts clarified (allowlist is precisely-scoped carve-out, not weakening).
5. `design/gdd/save-load-system.md` — Pass-ADR-0014-SYNC header note: Orchestrator consumer contract carries RunSnapshot payload; orphan-hero recovery uses Rule 16 per-consumer fallback pattern.
6. `design/gdd/game-time-and-tick.md` — Pass-ADR-0014-SYNC header note: `offline_elapsed_seconds` canonical subscriber is OfflineProgressionEngine (not Orchestrator direct); AC-TICK-10 clarification (CPU vs wall-clock distinction); TickSystem does not chunk; `tick_fired` not-during-offline invariant CI-enforced via new forbidden pattern.
7. `docs/architecture/architecture.md` — 5-location cascade: line 7 (Version + ADR-0014 Accepted note with full landed scope); line 8 (Last Updated bumped post-ADR-0014); line 13 (ADRs Referenced through ADR-0014); line 712 (§Required ADRs Feature Layer `ADR-X02` row → **ADR-0014 Accepted 2026-04-22** with full landed Decides + Blocks columns); line 729 (total-count paragraph bumped to 14 Accepted / 2 remain to author — C03, X04; coverage projected ~92%+ → PASS-candidate note); §Open Questions OQ-4 marked CLOSED by ADR-0014 §5.

godot-gdscript-specialist Step 4.5 review occurred during ADR-0014 authoring; APPROVE-WITH-NOTES with **3 LOAD-BEARING folds** applied in-place:
- NOTE LOAD-BEARING-1: `OfflineSummary` from bare `Dictionary` → inline `OfflineSummary extends RefCounted` (prevents memory-leak drift; matches ADR-0013 NOTE #9 pattern).
- NOTE LOAD-BEARING-2: Autoload lifetime reasoning — no `is_instance_valid(self)` needed in per-chunk `await` loop (autoload cannot be freed by scene transition); `SceneManager.show_modal` internal-await compounding analysis documented.
- NOTE LOAD-BEARING-3: CI grep regex broadened from `"HeroInstance "` (space-only) to `"HeroInstance[\] ]"` — catches BOTH bare-type `var hero: HeroInstance =` form AND typed-array `var formation: Array[HeroInstance]` form; the narrow regex would have silently missed array-typed fields.

technical-director Step 4.6 SKIPPED (solo review mode per `.claude/docs/director-gates.md` §TD-ADR).

---

## Traceability Summary

**Total requirements**: 425 (no new TRs in this review — ADR-0014 codifies existing orchestrator / economy / biome-dungeon-db gap-pool TRs verbatim; no new requirements surfaced).

| Status | Count | % | Δ vs 22f |
|---|---|---|---|
| ✅ Covered | ~382 | ~90% | **+12** (ADR-0014 closes the 8-12 TRs routed to ADR-X02 + flips some partials to full) |
| ⚠️ Partial | ~27 | ~6% | −5 (some orch/economy partials now fully covered by ADR-0014) |
| ❌ Gap | ~16 | ~4% | **−7** |

Coverage crosses **~90%** — PASS threshold cleared. All remaining gaps are outside architectural scope.

Per-system coverage (post ADR-0014):

| System (GDD) | TRs | Governing ADRs | Covered | Gap | Gap Routes To |
|---|---|---|---|---|---|
| save-load | 60 | 0003, 0004, 0005, 0007, **0014** | ~57 | ~3 | minor UX/debug (direct story OK) |
| time | 36 | 0003, 0005, **0014** | ~35 | ~1 | — |
| data-loading | 28 | 0003, 0006, 0011 | ~27 | ~1 | — |
| scene-manager | 39 | 0003, 0007, 0008, **0014** | ~37 | ~2 | OQ-7 (`reduce_motion` when Settings GDD lands) |
| hero-class-db | 24 | 0006, 0011 | ~24 | ~0 | — |
| enemy-db | 23 | 0006, 0011 | ~23 | ~0 | — |
| biome-dungeon-db | 28 | 0006, 0011, 0013, **0014** | ~24 | ~4 | direct orchestrator story (TR-015/016/018); Art Bible (TR-023 palette_key content — non-ADR) — **TR-019 FLOOR_CLEAR_BONUS offline-retrigger prevention closed by ADR-0014 §2 kills_so_far + loops_executed monotonic fields** |
| matchup-resolver | 33 | 0009, **0014** | ~32 | ~1 | minor (CI helper wording) |
| combat | 32 | 0010, **0014** | ~32 | ~0 | — |
| orchestrator | 32 | 0001, 0002, 0003, 0004, 0005, 0009, 0010, 0013, **0014** | ~32 | ~0 | — **ALL 4 gap TRs (batch chunking strategy, offline-replay snapshot schema, yield policy, mid-run persist semantics) closed by ADR-0014** |
| economy | 28 | 0002, 0013, **0014** | ~28 | ~0 | — **Both 2 partial TRs (offline batch chunking integration, first-clear-awarded dedup against replay edge case) closed by ADR-0014 aggregate-emit-ordering policy** |
| hero-roster | 30 | 0003, 0012, **0014** | ~30 | ~0 | — (allowlist exception precisely-scoped; invariant preserved) |
| floor-unlock | 32 | 0002, 0003 | ~14 | ~18 | direct story OK for MVP-scope items; V1.0 designer-UI deferred as ADR-X05 |
| **TOTAL** | **425** | — | **~382** | **~16** | — |

### ADR-0014 TR-coverage delta detail (12 TRs moved to covered)

ADR-0014's §Decision §1-§6 and §GDD Requirements Addressed table map to previously-gap TRs as follows:

- **Orchestrator (4 TRs closed)**: TR-orchestrator-010 (batch chunking strategy) / 011 (offline-replay snapshot schema) / 013 (yield policy during long replays) / 029 (mid-run persist semantics) — all covered by §1 autoload + §2 schema/persistence + §3 chunking algorithm + §4 signal ordering.
- **Economy (2 partials → covered)**: TR-economy-017/018 partial entries for offline batch chunking integration — closed by §3 algorithm documenting how `Economy.compute_offline_batch(chunk)` is called per chunk; `_is_offline_replay` flag set once batch-wide (ADR-0013 invariant preserved). First-clear-awarded dedup against replay-emitted-after edge case — closed by §4 aggregate emission order table (Economy.first_clear_awarded fires once per cleared floor in aggregate pass, not per chunk).
- **biome-dungeon-db (1 TR closed)**: TR-biome-dungeon-db-019 FLOOR_CLEAR_BONUS offline-retrigger prevention — closed by RunSnapshot §2 `kills_so_far` + `loops_executed` monotonic fields combined with ADR-0002 per-floor-at-most-once ledger (inherited via ADR-0013 `_floor_clear_bonus_credited` Dictionary).
- **save-load (1 partial → covered)**: Hydrate-then-replay ordering + Orchestrator as save consumer — closed by ADR-0014 §2 RunSnapshot's direct use of ADR-0004 consumer contract.
- **time (0 → partial becomes fully-covered for 1 TR)**: AC-TICK-10 per-chunk CPU budget clarification — closed by Pass-ADR-0014-SYNC applied to game-time-and-tick.md + ADR-0014 §Performance Implications clarifying CPU vs wall-clock-with-yield distinction.
- **scene-manager (0 → partial becomes fully-covered for 1 TR)**: Modal show/hide policy during offline replay — closed by ADR-0014 §5 progress UX (cozy modal ≥100ms threshold + dismissal on `offline_rewards_collected`).
- **matchup-resolver (0 → partial becomes fully-covered for 1 TR)**: Zero-call-during-replay invariant explicitly asserted via §6 allowlist's 3rd call site (`MatchupResolver.resolve` as the ONLY in-replay-allowlisted call, fired once at dispatch).
- **hero-roster (confirms ADR-0012 is fully covered with allowlist exception)**: §F HeroInstance identity invariant + ADR-0012 forbidden pattern + ADR-0014 allowlist — all 30 TRs now fully covered (allowlist is a documented carve-out, not a new gap).

### Remaining gap detail (~16 TRs — none are architectural)

| Source | Count | Route |
|---|---|---|
| biome-dungeon-db TR-015/016/018 | 3 | Direct orchestrator story (non-ADR — system-level wiring covered in implementation story) |
| biome-dungeon-db TR-023 palette_key content | 1 | Art Bible (non-ADR — content validation) |
| floor-unlock direct-story items | ~10 | Direct story OK for MVP-scope; V1.0 designer-UI deferred as ADR-X05 |
| save-load minor UX/debug | ~2 | Direct story OK |

**No remaining gap routes to a Required ADR for MVP.** ADR-C03 (Audio) and ADR-X04 (Recruitment) remain blocked on their own undesigned GDDs — these are GDD gaps, not architectural gaps, and are outside `/architecture-review` scope. ADR-X05 (Floor Unlock designer-UI) is a documented V1.0 deferral with runtime fallback in place.

---

## Cross-ADR Conflicts

**NONE DETECTED.**

ADR-0014 is architected for pure inheritance from its upstream ADRs; it reinforces (never contradicts) the existing invariants:

| Potential collision surface | Result |
|---|---|
| ADR-0014 ↔ ADR-0003 (autoload rank) | Inheritance only — OfflineProgressionEngine rank 15 slot already in rank table; zero-arg `_init` per Amendment #3. No redeclaration. |
| ADR-0014 ↔ ADR-0004 (save envelope) | Inheritance only — RunSnapshot uses ADR-0004 consumer contract verbatim; Orchestrator owns the save-payload lifetime. No envelope/HMAC changes. |
| ADR-0014 ↔ ADR-0005 (time system) | **Reinforces** — `offline_elapsed_seconds` has a canonical direct subscriber (OfflineProgressionEngine, not Orchestrator); `tick_fired` foreground-only invariant CI-enforced via new forbidden pattern `per_chunk_domain_signal_emission_during_offline_replay`. game-time-and-tick.md Pass-ADR-0014-SYNC clarifies AC-TICK-10 as two distinct budgets (CPU vs wall-clock-with-yield). No redeclaration. |
| ADR-0014 ↔ ADR-0009 (MatchupResolver) | **Reinforces** — `matched_archetypes: Array[String]` frozen-at-dispatch is persisted in RunSnapshot; §6 allowlist's 3rd site is `MatchupResolver.resolve` called once at dispatch (zero in-replay calls). Matches ADR-0009 zero-call-during-replay invariant. |
| ADR-0014 ↔ ADR-0010 (CombatResolver) | **Reinforces** — `CombatBatchResult` is the chunking unit; `compute_offline_batch(formation, floor, chunk, error_logger)` signature consumed per chunk; AC-COMBAT-10 parity invariant preserved (chunk boundaries are implementation detail; aggregated result is byte-identical to single-call equivalent per AC-OFFLINE-03). |
| ADR-0014 ↔ ADR-0011 (resource schemas) | Inheritance only — `Floor` opaque type serialized as `floor_id: String` + rehydrated via `DataRegistry.resolve("floors", floor_id)`; `biome_id` same pattern. No schema change. |
| ADR-0014 ↔ ADR-0012 (Hero Roster) | **Precisely-scoped carve-out** — `caching_heroinstance_reference_across_save_boundary` forbidden pattern gains ADR-0014 §6 allowlist exception: lifetime-scoped to post-hydrate replay cycle; 3 specific consumer call sites; 3 CI grep invariants enforce boundary. Registry `exception_allowlist` field documents the site. The invariant is NOT weakened — the exception is bounded, greppable, and has a precise lifetime (ends at `offline_rewards_collected` emission OR next save/load boundary). hero-roster.md Pass-ADR-0014-SYNC confirms §F invariant remains authoritative. |
| ADR-0014 ↔ ADR-0013 (Economy) | **Companion** — `Economy.compute_offline_batch(chunk) -> OfflineResult` consumed per chunk (not single-call); `_is_offline_replay` flag set once batch-wide (not per chunk); single aggregate `gold_changed` + `first_clear_awarded` emission after replay completes. ADR-0013's §Decision §4 single-call model is now wrapped by ADR-0014's chunk-iterator (ADR-0013 §Decision §4's forward reference to ADR-X02 is now resolved — both wrapping options documented there; ADR-0014 chose "wrap without superseding" so ADR-0013 remains correct). No redeclaration. |
| ADR-0014 ↔ ADR-0001 (formation reassignment) | No direct overlap — formation snapshot semantics are dispatch-time concern; ADR-0014 persists the snapshot payload but doesn't modify formation-reassignment rules. Orthogonal. |
| ADR-0014 ↔ ADR-0002 (first-clear reclaimable) | **Reinforces** — `kills_so_far` + `loops_executed` monotonic fields in RunSnapshot combine with ADR-0002's per-floor-at-most-once semantics (via ADR-0013's `_floor_clear_bonus_credited` ledger) to prevent FLOOR_CLEAR_BONUS offline-retrigger (TR-biome-dungeon-db-019). |
| ADR-0014 ↔ ADR-0006 (data loading) | Inheritance only — `DataRegistry.resolve("floors", id)` + `resolve("biomes", id)` at hydrate; O(1) dictionary lookups. No DAG change. |
| ADR-0014 ↔ ADR-0007 (scene transition) | **Companion** — SceneManager transition to ReturnToAppScreen is gated on `offline_rewards_collected` emission (last in the aggregate emission order table §4); `show_modal` / `hide_modal` used for cozy-modal UX; SceneManager.show_modal internal-await compounding analyzed and documented in NOTE LOAD-BEARING-2. No redeclaration. |
| ADR-0014 ↔ ADR-0008 (UI framework) | Forward reference — modal content spec (§5) consumes parchment theme + cozy tone-of-voice from ADR-0008; 44-logical-px tap-target floor applies to modal's (no) Cancel button affordance. No redeclaration (ReturnToAppScreen + OfflineSummary UI remain story-authoring work). |

No data ownership, integration contract, performance budget, dependency cycle, or architecture pattern conflicts.

---

## ADR Dependency Graph

Updated from 22f review (ADR-0014 added):

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
Level 5 (depends on Level 4):    ADR-0013 (requires 0002 + 0003 + 0004 + 0005 + 0006 + 0011 + 0012)
Level 6 (depends on Level 5):    ADR-0014 (requires 0003 + 0004 + 0005 + 0009 + 0010 + 0011 + 0012 + 0013)
```

- **14 of 14 ADRs Accepted.** No Proposed backlog.
- **No cycles.** No unresolved dependencies.
- ADR-0014's full dependency chain (0003/0004/0005/0009/0010/0011/0012/0013) is entirely Accepted. Safe to consume.
- Dependency graph is now as deep as it will need to be for MVP — remaining Required ADRs (C03, X04) are at Level 4-5 (C03 Audio depends only on ADR-0008; X04 Recruitment depends on ADR-0013 + undesigned Recruitment GDD).

**No more Required ADRs remain to author for MVP architectural completeness.** ADR-C03 (Audio) and ADR-X04 (Recruitment) remain blocked on their undesigned GDDs — GDD authoring precedes ADR authoring; outside this review's scope.

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 14 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 14 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] via autoload.md Claim 1 (2026-04-21) + Claim 4 (2026-04-22) |

### Post-cutoff APIs in use (by ADR-0014)

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| `Dictionary[int, HeroInstance]` + `Array[HeroInstance]` typed-container syntax | Godot 4.4+ | ADR-0014 §6 allowlist exception + §2 RunSnapshot formation_ids array | LOW | Direct precedent in ADR-0009/0010/0012/0013. Stable 4.4+. |
| `Time.get_ticks_usec()` | Godot 4.0+ | ADR-0014 §3 chunking algorithm per-chunk wall time measurement | LOW | Canonical `Time` singleton (not `OS.*` — deprecated since 4.0 per deprecated-apis.md). Stable. |
| `await get_tree().process_frame` | Godot 4.0+ | ADR-0014 §3 chunking algorithm main-thread yield | LOW | Idiomatic Godot 4 coroutine. Stable. |
| `mini` / `maxi` / `clampi` / `lerpf` global functions | Godot 4.0+ | ADR-0014 §3 `_adjust_chunk_size` | LOW | Stable 4.0+. |

No new engine-state verifications added by ADR-0014 — all primitives have direct ADR precedent or are stable 4.0+ patterns.

### Engine Specialist Consultation

godot-gdscript-specialist was invoked at ADR-0014 authoring time (Step 4.5) — **APPROVE-WITH-NOTES** per the 3 LOAD-BEARING folds applied in-place during authoring:
1. **LOAD-BEARING-1** — `OfflineSummary` inline `extends RefCounted` (prevents bare-Dictionary-return memory leak; mirrors ADR-0013 NOTE #9).
2. **LOAD-BEARING-2** — autoload lifetime reasoning: no `is_instance_valid(self)` needed in per-chunk await loop; SceneManager.show_modal internal-await compounding analyzed and documented as non-hazard.
3. **LOAD-BEARING-3** — CI grep regex broadened from `"HeroInstance "` (space-only) to `"HeroInstance[\] ]"` to catch array-typed field declarations.

Remaining notes were forward-looking / implementation-story concerns (exact `mini`/`maxi` vs explicit comparison style; `PROGRESS_MODAL_THRESHOLD_MS` value telemetry calibration; `OFFLINE_CHUNK_INITIAL_TICKS` sensitivity to min-spec hardware baseline).

No mechanically-wrong engine claims flagged. No new deprecated-API flags.

### Outstanding verifications (pre-MVP-ship)

Unchanged from prior review:
1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe; AC-DLS-01 covers implicitly.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10) — now also covers ADR-0014 `compute_offline_batch` per-chunk ≤16ms on touchscreen hardware.
3. **iOS/Android atomic-rename fallback** (ADR-0004 Risk #4).
4. **NEW — AC-TICK-10 / AC-OFFLINE-02 min-spec mobile synthetic 576k-tick replay** — ADR-0014 §Verification Required: validates adaptive chunking converges and `avg_chunk_wall_usec ≤ 15_000`, `max_chunk_wall_usec ≤ 20_000`. Test case authored at implementation-story time.
5. **NEW — AC-OFFLINE-05 RunSnapshot save/load round-trip with orphan-hero test** — synthesized save file + mid-session hero removal + load; assert refund path fires + `snapshot_discarded=true` in summary.

---

## GDD Revision Flags (Architecture → Design Feedback)

**None.**

- `design/gdd/dungeon-run-orchestrator.md` — Pass-ADR-0014-SYNC header note applied in lockstep; RunSnapshot schema + per-chunk consumption + AC-TICK-10 dual-budget clarification all landed.
- `design/gdd/hero-roster.md` — Pass-ADR-0014-SYNC header note applied; §F invariant preserved; allowlist exception documented.
- `design/gdd/save-load-system.md` — Pass-ADR-0014-SYNC header note applied; Orchestrator RunSnapshot payload + orphan-hero recovery via Rule 16 pattern documented.
- `design/gdd/game-time-and-tick.md` — Pass-ADR-0014-SYNC header note applied; `offline_elapsed_seconds` canonical subscriber + AC-TICK-10 dual-budget + TickSystem-does-not-chunk + `tick_fired` not-during-replay CI-enforced all documented.
- `design/gdd/economy-system.md` — No changes required (ADR-0013 already anticipated chunked calls + `_is_offline_replay` flag).
- `design/gdd/combat-resolution.md` — No changes required (ADR-0010 §compute_offline_batch signature consumed verbatim; AC-COMBAT-10 parity invariant preserved).
- `design/gdd/biome-dungeon-database.md` — No changes required (TR-019 offline retrigger prevention codified via RunSnapshot monotonic fields + ADR-0002 ledger inheritance).

No new GDD revision flags surfaced by this review.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (Draft, last amended in-session 2026-04-22 with ADR-0014):

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow coverage | ✅ (4 diagrams: frame, offline, persist, hydrate; offline-replay flow now concretely realized by ADR-0014 §Architecture Diagram) |
| API boundaries support integration requirements | ✅ — OfflineProgressionEngine rank 15 API surface fully reflected; Orchestrator.compute_offline_batch + Economy.compute_offline_batch consumed per-chunk |
| Orphaned architecture | ⚠️ Same as prior: HD2D + VFX deferred; Onboarding + SettingsAccessibility deferred. Acceptable for MVP. |
| Internal consistency (post ADR-0014 landing) | ✅ **CLEAN — NO DRIFT** (third consecutive review) |

### Drift status: CLEAN (third consecutive review with zero drift items)

All artifact cascades landed **in lockstep** with ADR-0014 authoring, continuing the pattern established by ADR-0012 and ADR-0013. Verified in-review via targeted greps:

| Location | Expected post-ADR-0014 state | Verified |
|---|---|---|
| `architecture.md:7` (Version) | ADR-0014 Accepted 2026-04-22 landing note appended with OfflineProgressionEngine rank 15 + adaptive chunking + RunSnapshot schema + allowlist exception + OQ-4 close + 5 forbidden patterns scope | ✅ |
| `architecture.md:8` (Last Updated) | "2026-04-22 (post `/architecture-decision` ADR-0014 landing + Accept promotion + registry lockstep + Pass-ADR-0014-SYNC notes applied to dungeon-run-orchestrator.md + hero-roster.md + save-load-system.md + game-time-and-tick.md)" | ✅ |
| `architecture.md:13` (ADRs Referenced) | "ADR-0001 through ADR-0014 (all Accepted as of 2026-04-22)" | ✅ |
| `architecture.md:~712` (§Required ADRs Feature Layer — ADR-X02 row) | Row header "ADR-X02 → **ADR-0014 (Accepted 2026-04-22)**" with full landed scope; Blocks-column includes Offline Progression Engine + Orchestrator mid-run persist + ReturnToAppScreen + AC-TICK-10 verification + Save schema v1 freeze + `/create-control-manifest` | ✅ |
| `architecture.md:~729` (total-count paragraph) | "14 Accepted / 2 remain to author (C03, X04)"; **"All architectural gaps for MVP are now closed"**; projected coverage ~92%+ → PASS-verdict candidate | ✅ |
| `architecture.md:~762` (§Open Questions OQ-4) | OQ-4 struck-through + "**CLOSED 2026-04-22 by ADR-0014 §5**" marker with full policy summary (silent <100ms / cozy modal ≥100ms / determinate progress rejected / instant black-out rejected) | ✅ |
| `design/gdd/dungeon-run-orchestrator.md` | Pass-ADR-0014-SYNC header note present with RunSnapshot + per-chunk + AC-TICK-10 dual-budget detail | ✅ |
| `design/gdd/hero-roster.md` | Pass-ADR-0014-SYNC header note present with allowlist exception + 3 CI grep invariant reference | ✅ |
| `design/gdd/save-load-system.md` | Pass-ADR-0014-SYNC header note present with RunSnapshot + orphan-hero recovery + Rule 16 pattern reference | ✅ |
| `design/gdd/game-time-and-tick.md` | Pass-ADR-0014-SYNC header note present with `offline_elapsed_seconds` canonical subscriber + AC-TICK-10 dual-budget + TickSystem-does-not-chunk + CI-enforcement reference | ✅ |
| `docs/registry/architecture.yaml` | 4 interfaces + 4 api_decisions + 5 forbidden_patterns + 2 perf budgets + 8 referenced_by bumps + ADR-0012 `exception_allowlist` field all present | ✅ |
| `docs/registry/architecture.yaml` last_updated header comment | ADR-0014 scope documented (full 4+4+5+2 + cross-bumps enumeration) | ✅ |

No drift items surfaced. This review does **NOT** apply any architecture.md or GDD edits.

### Minor nits (non-blocking)

1. **Registry `caching_heroinstance_reference_across_save_boundary` enforcement note still refers to "ADR-X02"** (line ~2515: `"(ADR-X02 will define snapshot lifetime explicitly)"`). The slot alias is now fulfilled by ADR-0014; text could be updated to "ADR-0014 defines snapshot lifetime explicitly (see §6 allowlist)." Not drift — the forward-looking language still applies at story-authoring time — but a cosmetic improvement candidate for the next registry touch.
2. **Registry `last_updated` comment** has a minor dup: "ADR-0013 ADR-0014 Prior same-day:" appears once (around the transition between the new ADR-0014 block and the appended ADR-0013 historical block). Cosmetic; does not affect registry consumers.

Both items are sub-drift-threshold and do not require a same-day follow-up.

### Traceability index update (applied in this review)

`docs/architecture/requirements-traceability.md` is updated in this review to reflect:

- Last Updated bumped to 2026-04-22g
- Verdict annotation bumped to **PASS** (first PASS verdict in the 22a-22g series)
- Coverage Summary bumped to ~382 / ~90% (+12 from ADR-0014)
- save-load row: Governing ADRs add ADR-0014
- time row: Governing ADRs add ADR-0014
- scene-manager row: Governing ADRs add ADR-0014
- biome-dungeon-db row: Governing ADRs add ADR-0014; Gap-Maps-To note — TR-019 offline-retrigger prevention closed by ADR-0014
- matchup-resolver row: Governing ADRs add ADR-0014
- combat row: Governing ADRs add ADR-0014
- orchestrator row: Governing ADRs add ADR-0014; gap count → 0
- economy row: gap count → 0 (ADR-0014 closed the 2 partial items)
- hero-roster row: Governing ADRs add ADR-0014 (allowlist exception)
- New ADR-0014 cross-ref section appended (full TR coverage + §Decision anchors + Registry expansion summary)
- Required ADRs authoring order: ADR-X02 removed (now landed as ADR-0014); remaining list: ADR-C03 Audio (undesigned GDD — out of scope); ADR-X04 Recruitment (undesigned GDD — out of scope); ADR-X05 Floor Unlock designer-UI (V1.0 deferred).
- Re-run Log row appended for 22g PASS

### Registry status

`docs/registry/architecture.yaml` was expanded in lockstep with ADR-0014 authoring (4 interfaces + 4 api_decisions + 5 forbidden_patterns + 2 perf budgets + 8 referenced_by bumps + ADR-0012 `exception_allowlist` field per in-review verification). NOT touched by this review.

`docs/architecture/tr-registry.yaml` — header note appended for 22g PASS re-run; no TR-IDs added or text-bumped.

---

## Verdict: **PASS**

**Why PASS**:

1. **All MVP-scope Required ADRs are Accepted.** 14 of 14 ADRs landed (0001-0014); Foundation (6) + Core (3 of 4 — C03 Audio blocked on undesigned GDD) + Feature (3 of 4 — X04 Recruitment blocked on undesigned GDD; X05 Floor Unlock designer-UI deferred V1.0 with runtime fallback in place). **No more Required ADRs remain to author for architectural completeness** — the remaining 2 (C03, X04) are blocked on their own undesigned GDDs, not on architectural decisions, and are outside `/architecture-review` scope.

2. **No cross-ADR conflicts.** ADR-0014 inherits cleanly from all 8 upstream ADRs (0003/0004/0005/0009/0010/0011/0012/0013); reinforces (never contradicts) their invariants; resolves ADR-0013's forward reference to ADR-X02 by "wrap without superseding" (ADR-0013's single-call model is wrapped by ADR-0014's chunk-iterator; both remain correct).

3. **No GDD revision flags.** Four Pass-ADR-0014-SYNC notes landed in lockstep (Orchestrator + Hero Roster + Save/Load + Time System); Economy / Combat / biome-dungeon-db required no changes because their invariants were already anticipated by upstream ADRs.

4. **OQ-4 closed.** The time-gated cozy modal UX policy (silent <100ms / modal ≥100ms) resolves a long-standing architecture.md open question with a clear policy rationale (determinate progress rejected: non-linear with adaptive chunking; instant black-out rejected: perceived-freeze hazard).

5. **Coverage at ~90% (~382/425).** Remaining ~16 gap TRs all route to non-architectural remediation: direct orchestrator stories (biome-dungeon-db TR-015/016/018 + floor-unlock direct-story items + save-load minor UX/debug), Art Bible content authoring (biome-dungeon-db TR-023 palette_key), or documented V1.0 deferral (floor-unlock designer-UI with runtime fallback).

6. **Zero structural conflicts, zero internal contradictions, zero stale text.** Third consecutive review with zero same-day drift-fix items — lockstep-cascade authoring discipline established across ADR-0012 / ADR-0013 / ADR-0014.

7. **All 14 Accepted ADRs are dependency-ordered, engine-verified, and internally consistent.** Dependency graph is acyclic; Level 6 (ADR-0014) is the deepest; no unresolved upstream dependencies.

8. **Engine compatibility clean.** All post-cutoff APIs catalogued; no deprecated APIs referenced; autoload init semantics [VERIFIED] via autoload.md Claims 1 + 4. Outstanding pre-MVP-ship verifications (5 items) are all implementation-story-time tests, not architectural gaps.

### Blocking Issues

**None.** This is the **FIRST PASS verdict** in the 22a-22g series and the **third consecutive review** with zero same-day blocking drift-fix items.

### Non-Blocking Findings

- **Open questions unchanged from prior review**: OQ-1 (V1.0 Floor Unlock designer-UI — deferred with runtime fallback); OQ-5 (Steam Deck hardware testing — partial closure by ADR-0008; hardware testing still required); OQ-7 (`reduce_motion` when Settings GDD lands); OQ-8 (SceneManager autoload rank at `project.godot` registration — implementation-time); OQ-9 (V1.0 keyboard/gamepad navigation); OQ-10 (V1.0 Steam Deck per-platform tap-target override). **OQ-4 CLOSED** by ADR-0014 §5 this review.

- **2 Required ADRs remain unwritten**: ADR-C03 Audio + ADR-X04 Recruitment — both blocked on their own undesigned GDDs. GDD authoring precedes ADR authoring; outside this review's scope. Do NOT block `/create-control-manifest` or `/gate-check pre-production` for the Foundation + Core DB + MVP-Feature layer — those layers are fully architecturally specified.

- **ADR-0014 §Risks — 3 CI grep invariants** (`heroinstance_cache_outside_runsnapshot_allowlist`, array-typed regex, `offline_replay_progressed.connect` UI-only) rely on CI scripts that do NOT exist yet (no `src/` exists yet); must land alongside the first offline-progression implementation story. Same standing concern as ADR-0013's 4 new forbidden patterns.

- **Implementation-story forward-looking notes from ADR-0014**: (a) `PROGRESS_MODAL_THRESHOLD_MS = 100` is a guess — calibrate against live telemetry in V1.0; (b) adaptive chunk size oscillation risk under thermal throttling — deadband mitigates; AC-OFFLINE-06 validates; (c) orphan-hero discard path needs a UI string + cozy modal + test, deferred to `refund_run_on_orphan_hero` story.

- **Minor cosmetic nits** (sub-drift-threshold; not blocking):
  1. Registry `caching_heroinstance_reference_across_save_boundary` enforcement comment still refers to "ADR-X02" (slot alias) instead of "ADR-0014" (now-concrete ID).
  2. Registry `last_updated` comment has a minor duplicate: "ADR-0013 ADR-0014 Prior same-day:" phrasing.

---

## Immediate Actions (recommended order)

With **all architectural gaps closed**, the project is now unblocked for downstream workflow:

1. **Run `/create-control-manifest`** — flat programmer rules sheet derived from all 14 Accepted ADRs + registry state. Consumes: every ADR's forbidden_patterns + api_decisions; registry's CI-enforcement-note column. Output: `docs/architecture/control-manifest.md` date-stamped to 2026-04-22.

2. **Run `/gate-check pre-production`** — validates Foundation + Core architecture is implementation-ready. Expected verdict: PASS (this review satisfies the architectural prerequisite; remaining gates are content-authoring + engine-reference-currency + test-scaffolding gates).

3. **Run `/create-epics layer: foundation`** — re-attempt with full prerequisites met (empty-TR-registry blocker closed by 22b-22g runs; missing-architecture.md blocker closed by /create-architecture v0.1; missing-control-manifest blocker closed by step 1 above).

4. **Run `/create-stories <epic-slug>`** per Foundation epic once epics exist.

5. **Run `/sprint-plan`** for the first implementation sprint.

### Parallel (unblocked)

- **ADR-C03 Audio GDD authoring** (if desired to un-gate ADR-C03). Not MVP-blocking for Foundation layer implementation.
- **ADR-X04 Recruitment GDD authoring** (if desired to un-gate ADR-X04). Not MVP-blocking for Foundation layer implementation.

### Rerun Trigger

Re-run `/architecture-review` only if: (a) a new ADR is authored (e.g., ADR-C03 or ADR-X04 when their GDDs land); (b) a GDD is substantively revised in a way that could invalidate an existing ADR; (c) engine version is bumped (VERSION.md changes). Given 22e + 22f + 22g all surfaced zero drift items, the lockstep-cascade pattern is now reliable practice.

---

## Files Written This Review

- `docs/architecture/architecture-review-2026-04-22g.md` — this report (PASS verdict)
- `docs/architecture/requirements-traceability.md` — coverage summary bumped to ~90% / ~382 covered; PASS verdict annotation; 8 row updates (save-load, time, scene-manager, biome-dungeon-db, matchup-resolver, combat, orchestrator, economy, hero-roster all gain ADR-0014 to Governing ADRs); ADR-0014 cross-ref section appended; Required ADRs authoring order updated (X02 removed as landed); Re-run Log row appended (22g PASS)
- `docs/architecture/tr-registry.yaml` — header note appended for 22g PASS run; no TR-IDs added or text-bumped
- `production/session-state/active.md` — Session Extract appended

No GDD edits, no ADR edits, no architecture.md edits performed by this review — none are needed (ADR-0014 artifact cascades landed in lockstep during authoring).

---

## Summary

ADR-0014 lands cleanly and closes the final Required ADR for MVP architectural completeness. Coverage crosses **~90%** (~370 → ~382 of 425; +12 TRs, matching the 22f projection exactly). No cross-ADR conflicts, no GDD revision flags, no engine anti-patterns, **no drift items** — the third consecutive review with zero same-day follow-up cascades. All 14 ADRs Accepted; dependency graph acyclic; OQ-4 closed. The remaining 2 Required-ADR slots (C03 Audio, X04 Recruitment) are blocked on their own undesigned GDDs and are outside `/architecture-review` scope. **Architecture phase is complete for MVP.** Unblocks `/create-control-manifest` → `/gate-check pre-production` → `/create-epics` → `/create-stories` → `/sprint-plan`.
