# Architecture Review — 2026-04-22f (sixth re-run, post ADR-0013 landing)

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 13 (all Accepted: 0001–0013) |
| Registry State | populated (425 TR-IDs, v2, unchanged) |
| Prior Reviews | `architecture-review-2026-04-22.md` (CONCERNS initial); `22b` (post ADR-0009); `22c` (post ADR-0010); `22d` (post ADR-0011); `22e` (post ADR-0012) |
| Verdict | **CONCERNS** (gap-only, reduced severity vs 22e; coverage rises to ~87%; PASS-verdict candidate pending ADR-X02; NO drift items — lockstep cascade pattern held for second consecutive review) |

---

## What changed since the prior review (2026-04-22e)

One ADR landing since the prior review, fully lockstep-cascaded in the authoring session:

1. **ADR-0013** (**Accepted 2026-04-22**, authored + promoted same-session) — Economy State Shape + Cost Curves + Offline Batch Contract. Fills the `ADR-C01` slot the 22e review flagged as top unwritten Required ADR (projected ~87% coverage landing). Codifies:
   - `class_name Economy extends Node` autoload **rank 3** (per ADR-0003 rank table, unchanged); zero-arg `_init` per Amendment #3 + autoload.md Claim 4 [VERIFIED].
   - **3 persisted state fields**: `_gold_balance: int` (int64, 1T sanity cap); `_lifetime_gold_earned: int` (unbounded statistic); `_floor_clear_bonus_credited: Dictionary[int, int]` (ADR-0002 monotonic ledger). 1 transient: `_is_offline_replay: bool`.
   - **7-method public API** — `add_gold(amount, reason)`, `try_spend(amount, reason) -> bool`, `try_award_floor_clear(floor_index, bonus_amount) -> bool`, `recruit_cost(class_id: String, copies_owned: int) -> int` (caller passes class_id String; Economy resolves tier internally via DataRegistry per ADR-0006 + ADR-0011), `level_cost(class_tier, current_level) -> int` (returns `-1` past `LEVEL_CAP` sentinel), `compute_offline_batch(tick_budget) -> OfflineResult`, `get_save_data` / `load_save_data`.
   - **2 typed signals** — `gold_changed(new_balance: int, delta: int, reason: String)` 3-arg, `first_clear_awarded(floor_index: int)` at-most-once-per-floor-per-save.
   - **26 tuning knobs** live in `assets/data/config/economy_config.tres` (`EconomyConfig extends GameData` per ADR-0011 pattern) — `BASE_RECRUIT[tier]`, `BASE_LEVEL[tier]`, `LEVEL_COPIES_DIVISOR`, `FLOOR_CLEAR_BONUS[floor]`, `BASE_DRIP[floor]`, `LEVEL_CAP`, `LOSING_RUN_LOOT_FACTOR`, etc.
   - **Closed-form offline drip** (O(1) multiply) + batch-event iteration + signal suppression during replay + aggregate emit after (AC H-10 500ms offline-batch budget compliance; Economy ceiling ~100–150ms of the budget).
   - **4 new CI-enforced forbidden patterns** (ADR-elevated from previously-implicit GDD rules):
     - `hardcoded_balance_value_outside_economy_config` — project-wide grep; balance magic numbers must trace to EconomyConfig.
     - `economy_reads_losing_run_state` — Economy stays directional-authoritative; Orchestrator owns LOSING_RUN_LOOT_FACTOR application.
     - `economy_signal_emission_during_offline_replay` — `gold_changed` + `first_clear_awarded` suppressed while `_is_offline_replay=true`; single aggregate emit after.
     - `try_spend_with_non_positive_amount` — guards the spend path from zero/negative callers.
   - `OfflineResult extends RefCounted` **inline class** (Specialist NOTE #9 fold — prevents memory leak from bare Dictionary return type drifting).
   - **Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant** codified (Economy neither reads nor multiplies; Orchestrator is sole applicator).

### Artifacts landed in lockstep during ADR-0013 authoring

1. `docs/architecture/ADR-0013-economy-state-and-cost-curves.md` — new ADR (Accepted, 928 lines).
2. `docs/registry/architecture.yaml` — 7 interfaces (`economy_state_shape`, `economy_mutation_api`, `economy_cost_curves_api`, `economy_offline_batch_contract`, `gold_changed_signal`, `first_clear_awarded_signal`, `economy_config_resource`); 5 api_decisions (`gold_currency_storage_type`, `recruit_cost_id_string_not_tier`, `level_cost_cap_sentinel`, `offline_replay_closed_form_drip`, `economy_tuning_knob_location`); 4 forbidden_patterns (listed above); 1 performance_budget (`compute_offline_batch_economy_share` AC H-10 500ms budget, Economy ~100–150ms ceiling); 5 `referenced_by` bumps (ADR-0004, 0005, 0006, 0011, 0012).
3. `design/gdd/economy-system.md` — Pass-ADR-0013-SYNC note at top-of-file documenting 4 signature-drift items resolved verbatim against ADR-0013:
   - `try_spend(amount)` → `try_spend(amount, reason)` — CLOSED
   - `add_gold(amount)` → `add_gold(amount, reason := "credit")` — CLOSED
   - `recruit_cost(class_tier, copies_owned)` → `recruit_cost(class_id: String, copies_owned: int)` — CLOSED (NEW; ADR-0013 tightened contract — Economy resolves tier internally per ADR-0006/0011)
   - `gold_changed(new_balance)` → `gold_changed(new_balance, delta, reason)` — CLOSED
4. `docs/architecture/architecture.md` — 5-location cascade: line 7 (Version + ADR-0013 Accepted note with full landed scope); line 8 (Last Updated bumped to post-ADR-0013); line 13 (ADRs Referenced through ADR-0013); line ~702 (§Required ADRs Core Layer ADR-C01 row → ADR-0013 Accepted with full landed Decides + Blocks columns); line 729 (total-count paragraph bumped to 13 Accepted / 3 remain to author — C03, X02, X04).
5. `production/session-state/active.md` — authoring arc entry appended (per prior review convention; still pending this review's Session Extract).

godot-gdscript-specialist Step 4.5 review occurred during ADR-0013 authoring (per session state authoring arc entry); APPROVE-WITH-NOTES with 1 LOAD-BEARING fold (NOTE #9: `OfflineResult` from bare `Dictionary` return type → inline `OfflineResult extends RefCounted` — prevents memory-leak drift and gives Economy's offline aggregate a stable schema). technical-director Step 4.6 SKIPPED (solo review mode per `.claude/docs/director-gates.md` §TD-ADR).

---

## Traceability Summary

**Total requirements**: 425 (no new TRs in this review — ADR-0013 codifies existing `TR-economy-001..028` pool verbatim; no new requirements surfaced by the GDD-level ratification).

| Status | Count | % | Δ vs prior |
|---|---|---|---|
| ✅ Covered | ~370 | ~87% | **+21** (ADR-0013 covers ~20 TR-economy gaps + unblocks TR-biome-dungeon-db-017 BASE_DRIP path) |
| ⚠️ Partial | ~32 | ~8% | unchanged |
| ❌ Gap | ~23 | ~5% | **−21** |

Coverage crosses **~87%** — PASS-verdict candidacy is now **one Required ADR away** (ADR-X02 projected ~92%+ clear PASS). The 22e projection of "~87% post-ADR-C01" is confirmed empirically.

Per-system coverage (post ADR-0013):

| System (GDD) | TRs | Governing ADRs | Covered | Gap | Gap Routes To |
|---|---|---|---|---|---|
| save-load | 60 | 0003, 0004, 0005, 0007 | ~56 | ~4 | minor UX/debug |
| time | 36 | 0003, 0005 | ~35 | ~1 | — |
| data-loading | 28 | 0003, 0006, 0011 | ~27 | ~1 | — |
| scene-manager | 39 | 0003, 0007, 0008 | ~37 | ~2 | OQ-7 |
| hero-class-db | 24 | 0006, 0011 | ~24 | ~0 | — |
| enemy-db | 23 | 0006, 0011 | ~23 | ~0 | — |
| biome-dungeon-db | 28 | 0006, 0011, **0013** | ~23 | ~5 | ADR-X02 (TR-019 offline retrigger), direct orchestrator story (TR-015/016/018), Art Bible (TR-023 palette_key content) — **TR-017 BASE_DRIP lookup path now unblocked by ADR-0013** |
| matchup-resolver | 33 | 0009 | ~31 | ~2 | minor (CI helper wording) |
| combat | 32 | 0010 | ~32 | ~0 | — |
| orchestrator | 32 | 0001, 0002, 0003, 0004, 0005, 0009, 0010, **0013** | ~28 | ~4 | ADR-X02 (Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant now locked by ADR-0013) |
| **economy** | **28** | **0002, 0013** | **~26** | **~2** | **ADR-0013 now Accepted — 20-gap pool closed; remaining ~2 partial route to ADR-X02 (offline batch chunking surface) + direct implementation story** |
| hero-roster | 30 | 0003, 0012 | ~30 | ~0 | — |
| floor-unlock | 32 | 0002, 0003 | ~14 | ~18 | direct story OK (X05 deferred V1.0) |
| **TOTAL** | **425** | — | **~370** | **~23** | — |

### Economy coverage delta detail (~20 TRs moved from gap to covered)

ADR-0013's §Decision §1–§5 and §GDD Requirements Addressed table map to `TR-economy-001..028` as follows:

- **State shape (TR-economy-001..005)**: §Decision §2 locks the 3 persisted fields + 1 transient flag; int64 storage via GDScript `int` primitive; 1 T sanity cap on `_gold_balance`.
- **Public API surface (TR-economy-006..012)**: §Decision §2 mutation methods + cost curve methods + offline batch method + save/load getter/setter pair. All signatures concretely typed.
- **Cost curve contracts (TR-economy-013..019)**: §Decision §3 formula specifications for `recruit_cost` (tier-gated base × copies-owned multiplier) and `level_cost` (tier-gated base × current-level multiplier, `-1` past `LEVEL_CAP` sentinel). `LOSING_RUN_LOOT_FACTOR` multiplier is Orchestrator-applied (directional invariant) — Economy never reads losing-run state.
- **Offline batch contract (TR-economy-020..024)**: §Decision §4 closed-form drip computation + batch-event iteration + signal suppression during replay + single aggregate `gold_changed` emit after. AC H-10 500ms offline-batch budget compliance codified as performance_budget in registry.
- **Signal contract (TR-economy-025..027)**: §Decision §2 `gold_changed` 3-arg signal + `first_clear_awarded` at-most-once-per-floor-per-save; `_is_offline_replay` flag suppresses emission.
- **Tuning knob location (TR-economy-028)**: §Decision §1 locks all 26 knobs in `assets/data/config/economy_config.tres` (EconomyConfig extends GameData per ADR-0011 pattern); `hardcoded_balance_value_outside_economy_config` forbidden_pattern enforces single-source-of-truth.

### Biome-dungeon-db coverage delta detail (TR-017 BASE_DRIP unblocked)

`TR-biome-dungeon-db-017` previously required Economy's `BASE_DRIP[floor_index]` lookup path to be architecturally specified. ADR-0013's `economy_config.tres → BASE_DRIP: Array[int]` keyed by `floor_index` closes this TR. The per-floor BASE_DRIP authoring surface remains a content-authoring concern (Biome DB authors populate; Economy consumes), not an architectural gap.

### Orchestrator partial-coverage note (~4 TRs remain)

ADR-0013 locks the **Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant** — Orchestrator multiplies the factor before calling `Economy.add_gold(amount, reason)`; Economy never multiplies, never reads losing-run state. This is 1 of ~4 orchestrator gap items now closed. The remaining 3-4 items (batch chunking strategy, offline-replay snapshot schema, yield policy during long replays) route to ADR-X02.

### Economy partial-coverage note (~2 TRs remain)

The remaining 2 economy TRs are: (1) offline-batch chunking refinement — how does Economy's `compute_offline_batch` integrate with ADR-X02's chunk-yield policy? (2) minor UX-boundary concern — how does first-clear-awarded dedup against replay-emitted-after edge case? Both route cleanly to ADR-X02.

---

## Cross-ADR Conflicts

**NONE DETECTED.**

ADR-0013 is architected for pure inheritance from its upstream ADRs; it reinforces (never contradicts) the existing invariants:

| Potential collision surface | Result |
|---|---|
| ADR-0013 ↔ ADR-0003 (autoload rank) | Inheritance only — Economy rank 3 preserved (already in ADR-0003 rank table); zero-arg `_init` per Amendment #3. No redeclaration. |
| ADR-0013 ↔ ADR-0002 (LOSING first-clear reclaimable) | **Reinforces** — `_floor_clear_bonus_credited: Dictionary[int, int]` monotonic ledger shape codifies ADR-0002 per-floor at-most-once semantics at the state-container level. `try_award_floor_clear` method embodies the monotonic credit rule; `first_clear_awarded` signal fires at-most-once-per-floor-per-save. No redeclaration. |
| ADR-0013 ↔ ADR-0004 (save envelope) | Inheritance only — `get_save_data` / `load_save_data` consumer contract re-used verbatim; `_is_offline_replay` transient not persisted; `save_sequence_number` gating upstream per ADR-0004. |
| ADR-0013 ↔ ADR-0005 (time system) | Companion — `compute_offline_batch(tick_budget)` consumes TickSystem's batch dispatch seam; per-tick_fired foreground path consumes the same seam in forward direction. No redeclaration. |
| ADR-0013 ↔ ADR-0006 (data loading) | Inheritance only — `DataRegistry.resolve("classes", id) -> HeroClass` used in `recruit_cost` to get `HeroClass.tier` (Economy resolves tier internally per ADR-0013 api_decision `recruit_cost_id_string_not_tier`); `DataRegistry.resolve("config", "economy_config") -> EconomyConfig` for tuning knobs. No DAG change. |
| ADR-0013 ↔ ADR-0009 (MatchupResolver) | No direct code overlap — Economy is not a MatchupResolver consumer. Orthogonal layers. |
| ADR-0013 ↔ ADR-0010 (CombatResolver) | No direct code overlap — Economy credits gold post-dispatch via Orchestrator-brokered callbacks, not via direct CombatResolver consumption. The Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant is the codified seam. |
| ADR-0013 ↔ ADR-0011 (resource schemas) | **Reinforces** — `EconomyConfig extends GameData` follows the canonical GameData subclass pattern; `HeroClass.tier: int` consumed by `recruit_cost` / `level_cost` per ADR-0011's locked schema. `economy_tuning_knob_location` api_decision enforces the ADR-0011 "all config-type resources live under `assets/data/config/`" convention. |
| ADR-0013 ↔ ADR-0012 (Hero Roster) | **Companion** — Economy consumes `roster.get_formation_strength() -> float` per ADR-0012's locked `[1.0, 3.0]` range contract; consumes `roster.get_copies_owned(class_id: String) -> int` per ADR-0012's locked read API. Both signatures were locked by ADR-0012 in anticipation of ADR-0013 consumption; this review confirms the consumer-side call sites in ADR-0013 match the locked producer-side contracts. No redeclaration. |
| ADR-0013 ↔ ADR-0001 (formation reassignment) | No direct overlap — ADR-0001 concerns formation snapshot semantics; Economy is a post-dispatch consumer via Orchestrator, not a direct snapshot holder. Orthogonal. |
| ADR-0013 ↔ ADR-0007 (scene transition) | No direct code overlap — scene-boundary-persist is a SaveLoad concern. Economy's `get_save_data` is the read-side; no direct scene-transition coupling. |
| ADR-0013 ↔ ADR-0008 (UI framework) | No direct code overlap. GuildHallScreen / RecruitScreen / RosterScreen will consume `gold_changed` 3-arg signal per ADR-0013's locked signature + ADR-0008's theme + tap-target invariants. Forward reference — not a conflict. |

No data ownership, integration contract, performance budget, dependency cycle, or architecture pattern conflicts.

### Forward references to ADR-X02 (expected, not conflicts)

ADR-0013 §Decision §4 documents two explicit forward references to ADR-X02 (unwritten):

1. **Offline batch chunking integration** — `compute_offline_batch(tick_budget)` currently assumes the entire offline window fits within a single `tick_budget` call. ADR-X02 will refine the chunking strategy (max ticks per chunk, yield cadence) and either (a) ADR-0013 stays correct and ADR-X02 wraps chunked calls around `compute_offline_batch`, or (b) ADR-X02 supersedes ADR-0013's single-call model with a chunk-iterator interface. Both options preserve ADR-0013's closed-form drip O(1) primitive; only the outer iteration policy changes.
2. **Offline-replay snapshot schema** — ADR-0013's `_is_offline_replay` flag is set by Orchestrator before `compute_offline_batch` starts and cleared after. ADR-X02's snapshot schema will determine whether this flag is part of the snapshot or managed externally. ADR-0013 is agnostic.

Both references are documented handoffs, not conflicts. ADR-X02 authoring will cite ADR-0013 as companion decision + reuse the locked `compute_offline_batch` + `OfflineResult` primitives.

---

## ADR Dependency Graph

Updated from 22e review:

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
```

- **13 of 13 ADRs Accepted.** No Proposed backlog.
- **No cycles.** No unresolved dependencies.
- ADR-0013's dependency chain (0002 / 0003 / 0004 / 0005 / 0006 / 0011 / 0012) is entirely Accepted. Safe to consume.

**Recommended authoring order for remaining Required ADRs** (post ADR-0013 Accept):

1. **ADR-X02** — Offline batch chunking + offline-replay snapshot schema. Cites ADR-0010 for `CombatBatchResult` chunking unit; cites ADR-0009 for `matched_archetypes` frozen-at-dispatch; cites ADR-0011 for `Floor.enemy_list` freeze target; cites ADR-0012 for `HeroInstance` snapshot allowlist exception; cites ADR-0013 for `compute_offline_batch` + `OfflineResult` primitives. Covers TR-orchestrator-010..013/029 + TR-economy-017..019 + TR-biome-dungeon-db-019. Projected coverage post-X02: ~92%+ → **clear PASS verdict**.

After ADR-X02: ADR-C03 (Audio) + ADR-X04 (Recruitment) remain blocked on their GDDs being authored (not architectural gaps — GDD gaps). ADR-X05 (Floor Unlock designer-UI) deferred V1.0.

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 13 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 13 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] via autoload.md Claim 1 (2026-04-21) + Claim 4 (2026-04-22) |

### Post-cutoff APIs in use (by ADR-0013)

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| `Dictionary[int, int]` typed-dict syntax | Godot 4.4+ | ADR-0013 §Decision §2 `_floor_clear_bonus_credited` ledger | LOW | Direct precedent in ADR-0009 `Dictionary[StringName, int]`, ADR-0010 `Dictionary[String, int]`, ADR-0012 `Dictionary[int, HeroInstance]`. Stable 4.4+. |
| `RandomNumberGenerator` deterministic seed pattern | Godot 4.0+ | N/A for MVP ADR-0013 scope (recruitment pool deferred to ADR-X04) | — | Not consumed in ADR-0013's code surface. |
| `floori` / explicit int cast in offline batch math | Godot 4.0+ | ADR-0013 §Decision §4 `compute_offline_batch` | LOW | Stable 4.0+; specialist NOTE (non-LOAD-BEARING) documents `int(x)` truncation semantics vs `floori(x)` for negative floats (irrelevant in Economy since all budgets are non-negative). |
| Typed signals with primitive payloads (`signal gold_changed(new_balance: int, delta: int, reason: String)`) | Godot 4.0+ (typing) | ADR-0013 §Decision §2 | LOW | Stable; typed payloads are documentation-only at runtime (prior specialist NOTE on ADR-0012 retained as cross-ADR lesson). |
| Inline `class OfflineResult extends RefCounted` | Godot 4.0+ | ADR-0013 §Decision §4 | LOW | Stable; specialist LOAD-BEARING fold NOTE #9 — inline class prevents bare-Dictionary-return-type drift and memory leaks across offline replay. |

No new engine-state verifications added by ADR-0013 — all primitives have direct ADR precedent or are stable 4.0+ patterns.

### Engine Specialist Consultation

godot-gdscript-specialist was invoked at ADR-0013 authoring time (Step 4.5) — **APPROVE-WITH-NOTES** per session state authoring arc entry. One LOAD-BEARING fold applied in-place (NOTE #9: `OfflineResult extends RefCounted` inline class); remaining notes were forward-looking / implementation-story-awareness concerns (int→float promotion in offline drip math; Dictionary.get(key, default) null-default; signal-emission-during-replay guard granularity; tuning-knob export `@export_range` hints).

No mechanically-wrong engine claims flagged. No new deprecated-API flags.

### Outstanding verifications (pre-MVP-ship)

Unchanged from prior review:

1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe; AC-DLS-01 covers implicitly. ADR-0011's `extends GameData` inherits this pending verification; ADR-0013's `EconomyConfig extends GameData` inherits same.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10) — now also covers ADR-0013 `compute_offline_batch` p99 < 150ms performance budget.
3. **iOS/Android atomic-rename fallback** (ADR-0004 Risk #4).

No new verifications added by ADR-0013.

---

## GDD Revision Flags (Architecture → Design Feedback)

**None.**

- `design/gdd/economy-system.md` — Pass-ADR-0013-SYNC header note + 4 signature-drift items (try_spend, add_gold, recruit_cost, gold_changed) **cleaned in lockstep** with ADR-0013 authoring. No stale signatures remain.
- `design/gdd/hero-roster.md` §F bidirectional-consistency entry — confirmed resolved (ADR-0012 producer-side + ADR-0013 consumer-side signatures match).
- `design/gdd/dungeon-run-orchestrator.md` — Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant already present in GDD §E; ADR-0013 elevates to CI-enforced via `economy_reads_losing_run_state` forbidden pattern. GDD + ADR consistent.
- No other GDDs touched by ADR-0013's scope.

No new GDD revision flags surfaced by this review.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (Draft, last amended in-session 2026-04-22 with ADR-0013):

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow coverage | ✅ (4 diagrams: frame, offline, persist, hydrate) |
| API boundaries support integration requirements | ✅ — Economy API surface fully reflected |
| Orphaned architecture | ⚠️ Same as prior: HD2D + VFX deferred; Onboarding + SettingsAccessibility deferred. Acceptable for MVP. |
| Internal consistency (post ADR-0013 landing) | ✅ **CLEAN — NO DRIFT** |

### Drift status: CLEAN (second consecutive review with zero drift items)

All artifact cascades landed **in lockstep** with ADR-0013 authoring, continuing the pattern established by ADR-0012. Verified in-review via Explore agent spot-reads:

| Location | Expected post-ADR-0013 state | Verified |
|---|---|---|
| `architecture.md:7` (Version) | ADR-0013 Accepted 2026-04-22 landing note appended with Economy rank-3 + 7-method API + cost curves + 4 forbidden patterns scope | ✅ |
| `architecture.md:8` (Last Updated) | "2026-04-22 (post `/architecture-decision` ADR-0013 landing + Accept promotion + registry lockstep + economy-system.md Pass-ADR-0013-SYNC signature harmonization)" | ✅ |
| `architecture.md:13` (ADRs Referenced) | "ADR-0001 through ADR-0013 (all Accepted as of 2026-04-22)" | ✅ |
| `architecture.md:~702` (§Required ADRs Core Layer — ADR-C01 row) | Row header "ADR-C01 → **ADR-0013 (Accepted 2026-04-22)**" with full landed scope in Decides-column; Blocks-column includes Recruitment / Hero Leveling / ADR-X02 / TR-biome-dungeon-db-017 BASE_DRIP / HUD-consumer screens | ✅ |
| `architecture.md:729` (total-count paragraph) | "13 Accepted / 3 remain to author (C03, X02, X04)"; top-priority shifted to ADR-X02 | ✅ |
| `design/gdd/economy-system.md` | Pass-ADR-0013-SYNC note + 4 signature-drift closures; line 549 provisional text absent (already resolved in ADR-0012 lockstep) | ✅ |
| `docs/registry/architecture.yaml` | 7 interfaces + 5 api_decisions + 4 forbidden_patterns + 1 perf budget + 5 referenced_by bumps all present | ✅ |

No drift items surfaced. This review does **NOT** apply any architecture.md or GDD edits.

### Traceability index update (applied in this review)

`docs/architecture/requirements-traceability.md` is updated in this review to reflect:

- Last Updated bumped to 2026-04-22f
- Verdict annotation bumped to 22f review cite
- Coverage Summary bumped to ~370 / ~87% (+21 from ADR-0013)
- economy row: Governing ADRs → `ADR-0002, ADR-0013`; gap count → ~2; Gap-Maps-To → "ADR-0013 now Accepted — 20-gap pool closed; ~2 partial remaining route to ADR-X02"
- biome-dungeon-db row: Gap-Maps-To — note TR-017 BASE_DRIP lookup path now unblocked by ADR-0013
- orchestrator row: Governing ADRs add ADR-0013 (Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant locked)
- New ADR-0013 cross-ref section appended (full TR coverage + §Decision anchors + Registry expansion summary)
- Required ADRs authoring order renumbered: ADR-C01 removed (now landed as ADR-0013); X02 → 1
- Re-run Log row appended for 22f

### Registry status

`docs/registry/architecture.yaml` was expanded in lockstep with ADR-0013 authoring (7 interfaces + 5 api_decisions + 4 forbidden_patterns + 1 perf budget + 5 referenced_by bumps per Explore-agent verification). NOT touched by this review.

`docs/architecture/tr-registry.yaml` — header note appended for 22f re-run; no TR-IDs added or text-bumped.

---

## Verdict: **CONCERNS** (gap-only, reduced severity vs 22e — PASS-verdict candidate after ADR-X02)

**Why not PASS**:
1. 1 unwritten Required ADR still blocks ~8-12 TRs spread across Orchestrator / Economy / biome-dungeon-db (ADR-X02 = Offline batch chunking + snapshot schema). This is a **−1 from the prior review** (ADR-C01 now landed as ADR-0013).
2. 2 additional Required ADRs remain blocked on their own undesigned GDDs (ADR-C03 Audio + ADR-X04 Recruitment) — these are GDD gaps, not architectural gaps; outside `/architecture-review` scope.

**Why not FAIL**:
- No structural conflicts. ADR-0013 inherits cleanly from ADR-0002/0003/0004/0005/0006/0011/0012 and reinforces (never contradicts) the locked signatures and directional invariants.
- No GDD revision flags surfaced. Lockstep economy-system.md Pass-ADR-0013-SYNC cleanup completed within the authoring session; 4 signature-drift items closed.
- All 13 Accepted ADRs are dependency-ordered, engine-verified, and internally consistent.
- ADR-0013's content is materially correct and fully covers its scope (3 state fields + 1 transient flag + 7-method public API + 2 typed signals + 26 config knobs + 4 CI-enforced forbidden patterns + OfflineResult inline RefCounted + Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant + closed-form offline drip).
- The ~23 remaining gaps are all routed to the 1 remaining Required ADR (ADR-X02), undesigned-GDD ADRs (ADR-C03, ADR-X04), V1.0 deferral (ADR-X05), or non-ADR territory (Art Bible palette_key content validation, floor-unlock direct-story items).
- Coverage crosses **~87%** — matches 22e's projection exactly. PASS candidacy is single-ADR-away.
- **NO DRIFT ITEMS** — architecture.md + economy-system.md + registry cascaded in lockstep during ADR-0013 authoring (second consecutive review with zero same-day follow-up cascades; continues the pattern established by ADR-0012).

### Blocking Issues (must resolve before PASS verdict)

**None are same-day mechanical cascades.** This is the **second consecutive review** in the 22a/b/c/d/e/f series to surface **zero** same-day blocking drift-fix items. ADR-0013 landed with full in-session cascade. The verdict gap is purely "one more Required ADR needs to be authored," which is expected project progression rather than review-surfaced drift.

The path to PASS:

1. **Author ADR-X02** (Offline batch chunking + offline-replay snapshot schema). Consumes ADR-0009 + ADR-0010 + ADR-0011 + ADR-0012 + ADR-0013; allowlists Orchestrator-owned formation snapshot from ADR-0012 `caching_heroinstance_reference_across_save_boundary` forbidden pattern; refines ADR-0013's `compute_offline_batch` single-call assumption with chunk-iterator policy. Projected post-X02 coverage: ~92%+ → **clear PASS**.

### Non-Blocking Findings

- Open questions unchanged from prior review: OQ-1, OQ-4, OQ-5 (partial), OQ-7, OQ-8, OQ-9, OQ-10. None blocks MVP.
- 1 Required ADR remains unwritten (X02) — expected; routing is correctly scoped in architecture.md §Required ADRs.
- 2 Required ADRs blocked on undesigned GDDs (ADR-C03 Audio, ADR-X04 Recruitment) — GDD authoring precedes ADR authoring; outside this review's scope.
- ADR-0013 §Risks — `economy_reads_losing_run_state` forbidden pattern relies on a new CI grep test that does NOT exist yet (no `src/` exists yet); must land alongside the first Economy implementation story. Same standing concern applies to all 4 new forbidden patterns introduced by ADR-0013.
- Implementation-story forward-looking note: the `@export_range` hints for EconomyConfig's 26 tuning knobs (specialist NOTE from ADR-0013 review) should be applied at the EconomyConfig resource-authoring story, not deferred indefinitely.

---

## Immediate Actions (recommended order)

1. **Open a fresh `/architecture-decision` session for ADR-X02** (Offline batch chunking + offline-replay snapshot schema). Final architectural gap before PASS candidacy. Must cite ADR-0009 (`matched_archetypes` frozen-at-dispatch), ADR-0010 (`CombatBatchResult` chunking unit), ADR-0011 (`Floor.enemy_list` freeze target), ADR-0012 (HeroInstance snapshot allowlist exception), ADR-0013 (`compute_offline_batch` + `OfflineResult` primitives + `_is_offline_replay` flag coordination).
2. After ADR-X02 lands, re-run `/architecture-review` → expected **PASS verdict** (projected coverage ~92%+).
3. When PASS verdict confirmed: `/create-control-manifest` → `/gate-check pre-production` → `/create-epics layer: foundation` → `/create-stories` → `/sprint-plan`.

### Rerun Trigger

Re-run `/architecture-review` after ADR-X02 lands. Given 22e + 22f both surfaced zero drift items, the lockstep-cascade pattern is now reliable — future authoring sessions should continue the practice demonstrated by ADR-0012 + ADR-0013.

---

## Files Written This Review

- `docs/architecture/architecture-review-2026-04-22f.md` — this report
- `docs/architecture/requirements-traceability.md` — coverage summary bumped to ~87%; economy row updated (Governing ADRs add ADR-0013, gap ~2); orchestrator row updated (Governing ADRs add ADR-0013); biome-dungeon-db Gap-Maps-To note updated (TR-017 BASE_DRIP unblocked); ADR-0013 cross-ref section appended; Required ADRs authoring order renumbered; Re-run Log row appended
- `docs/architecture/tr-registry.yaml` — header note appended for 22f run; no TR-IDs added or text-bumped
- `production/session-state/active.md` — Session Extract appended

No GDD edits, no ADR edits, no architecture.md edits performed by this review — none are needed (ADR-0013 artifact cascades landed in lockstep during authoring).

---

## Summary

ADR-0013 lands cleanly. Coverage crosses **~87%** (~349 → ~370 of 425; +21, matching 22e's projection exactly). No cross-ADR conflicts, no GDD revision flags, no engine anti-patterns, **no drift items** — the second consecutive review with zero same-day follow-up cascades. All 13 ADRs Accepted; dependency graph acyclic; forward references to ADR-X02 documented and expected. Only remaining Required ADR: **ADR-X02 (Offline batch chunking + snapshot schema)**, projected ~92%+ coverage for a clear PASS verdict on the next review.
