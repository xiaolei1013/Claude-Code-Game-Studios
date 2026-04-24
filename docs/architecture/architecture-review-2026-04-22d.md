# Architecture Review — 2026-04-22d (fourth re-run, post ADR-0011 landing)

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 11 (10 Accepted: 0001–0010; 1 **Proposed**: 0011) |
| Registry State | populated (425 TR-IDs, v2) |
| Prior Reviews | `architecture-review-2026-04-22.md` (CONCERNS — initial); `22b.md` (CONCERNS — post ADR-0009); `22c.md` (CONCERNS — post ADR-0010) |
| Verdict | **CONCERNS** (gap-only, reduced severity vs 22c; coverage rises; drift items surfaced by ADR-0011 authoring) |

---

## What changed since the prior review (2026-04-22c)

One ADR landing since the prior review:

1. **ADR-0011** (**Proposed 2026-04-22**) — Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor. Covers the `ADR-C02` slot the prior review flagged as top unwritten Required ADR. Codifies:
   - 5 concrete `GameData` subclass field schemas (14+11+5+2+5 `@export` fields across HeroClass / EnemyData / Biome / Dungeon / Floor).
   - 2 new constant-set modules (`EnemyArchetypes` with 3 MVP + 3 V1.0 constants; `ClassRoles` with 6 constants) as `class_name X extends RefCounted` — single source of truth for string enums shared across `HeroClass.counter_archetype` ↔ `EnemyData.archetype`.
   - Full load-time validation semantics: universal + per-type + cross-type validator tables with explicit failure actions (`ERROR` state vs `push_warning`).
   - Three cross-type invariants: archetype distribution (F1-F3 cover 3 MVP archetypes), boss-floor uniqueness, HeroClass tier-1 counter_archetype ∈ MVP_SET.
   - `Floor.enemy_list: Array[Dictionary]` of `{enemy_id: String, count: int}` contract — NOT `Array[EnemyData]` inline refs (hot-reload + save-file stability rationale).
   - Consumes ADR-0006 base + directory + DAG verbatim (no redeclaration). Locks the `Floor` opaque type ADR-0010 consumes. Provides the archetype constant set ADR-0009 `matched_archetypes` frozen-snapshot cite.

Out-of-lockstep touches already landed by ADR-0011's authoring session:

- `docs/registry/architecture.yaml` — expanded in lockstep: 7 new interfaces (`hero_class_schema`, `enemy_data_schema`, `biome_schema`, `dungeon_schema`, `floor_schema`, `enemy_archetypes_constant_set`, `class_roles_constant_set`), 4 new api_decisions (`archetype_string_universe_single_source`, `role_string_universe_single_source`, `floor_enemy_list_id_string_not_inline_ref`, `static_constant_module_base_class`), 5 new forbidden_patterns (`content_field_without_export_annotation`, `archetype_string_hardcoded_outside_constant_set`, `role_string_hardcoded_outside_constant_set`, `subclass_redeclare_id_or_display_name`, `expected_clear_time_seconds_as_runtime_gate`), 4 `referenced_by` bumps on ADR-0006 entries (`content_base_class`, `content_id_convention`, `data_load_order`) + ADR-0009 `matchup_result_value_type`. `last_updated` bumped with ADR-0011 reference.
- `design/gdd/data-loading.md` — Rule 3 + Rule 6 + Enemy Database Interactions paragraph synced `Enemy → EnemyData` with ADR-0011 cross-references (3 locations).
- godot-gdscript-specialist Step 4.5 APPROVE-WITH-NOTES; 2 load-bearing notes folded (`Array[Dictionary]` inspector-UX tradeoff; constant modules `extends RefCounted` not `Object`); 8 forward-looking notes retained for implementation-story awareness.

---

## Traceability Summary

**Total requirements**: 425 (no new TRs in this review — ADR-0011 codifies existing schema-scope TRs across 3 Core DB systems; no new requirements surfaced).

| Status | Count | % | Δ vs prior |
|---|---|---|---|
| ✅ Covered | ~321 | ~75% | **+57** (ADR-0011 covers hero-class-db + enemy-db + biome-dungeon-db schema pool) |
| ⚠️ Partial | ~32 | ~8% | unchanged |
| ❌ Gap | ~72 | ~17% | **−57** |

Per-system coverage (post ADR-0011):

| System (GDD) | TRs | Governing ADRs | Covered | Gap | Gap Routes To |
|---|---|---|---|---|---|
| save-load | 60 | 0003, 0004, 0005, 0007 | ~52 | ~4 | minor UX/debug |
| time | 36 | 0003, 0005 | ~34 | ~1 | — |
| data-loading | 28 | 0003, 0006, 0011 | ~27 | ~1 | — |
| scene-manager | 39 | 0003, 0007, 0008 | ~35 | ~2 | OQ-7 |
| **hero-class-db** | **24** | **0006, 0011 (Proposed)** | **~24** | **~0** | **promote 0011 to Accepted** |
| **enemy-db** | **23** | **0006, 0011 (Proposed)** | **~23** | **~0** | **promote 0011 to Accepted** |
| **biome-dungeon-db** | **28** | **0006, 0011 (Proposed)** | **~22** | **~6** | ADR-X02 (offline bonus retrigger), ADR-C01 (Economy BASE_DRIP lookup), Art Bible (palette_key / environmental_storytelling content validation) |
| matchup-resolver | 33 | 0009 | ~31 | ~2 | minor (CI helper wording) |
| combat | 32 | 0010 | ~32 | ~0 | — |
| orchestrator | 32 | 0001, 0002, 0003, 0004, 0005, 0009, 0010 | ~24 | ~4 | ADR-X02 |
| economy | 28 | 0002 | ~6 | ~20 | ADR-C01 |
| hero-roster | 30 | 0003 (partial) | ~2 | ~26 | ADR-X03 |
| floor-unlock | 32 | 0002, 0003 | ~10 | ~18 | direct story OK (X05 deferred V1.0) |
| **TOTAL** | **425** | — | **~321** | **~72** | — |

### Core DB coverage delta detail

ADR-0011 raises Core DB coverage by ~57 TRs:

- **hero-class-db (all 24 now covered)**: TR-hero-class-db-001..024 — schema fields (16), role taxonomy (6 roles), archetype taxonomy (6 archetypes, MVP + V1.0), V1.0 stub rationale, 12 ACs (H-01..H-12). ADR-0011 §1 + §Archetype/Role constant sets + §Load-Time Validation Semantics HeroClass + §Cross-Type validators cover all 24.
- **enemy-db (all 23 now covered)**: TR-enemy-db-001..023 — schema fields (13), archetype distribution invariant (F1-F3 coverage), 8 MVP stat blocks, boss HP 4818 per Pass 2B. ADR-0011 §2 + §Cross-Type archetype-distribution validator cover all 23.
- **biome-dungeon-db (~22 of 28 now covered)**: TR-biome-dungeon-db-001..014, -020..028 covered via ADR-0011 §3-§5 schemas + §Cross-Type validators. **Remaining 6 gap TRs** route correctly to unwritten ADRs:
  - TR-biome-dungeon-db-015/016/018 (Orchestrator-side dispatch validation, floor iteration, boss-death fanfare trigger) → ADR-0001 partial + ADR-X03 / direct orchestrator story
  - TR-biome-dungeon-db-017 (Economy `BASE_DRIP[floor_index]` / `FLOOR_CLEAR_BONUS[floor_index]` lookup) → ADR-C01
  - TR-biome-dungeon-db-019 (Offline Engine FLOOR_CLEAR_BONUS retrigger semantics) → ADR-X02
  - TR-biome-dungeon-db-023 (palette_key match against Art Bible content) → Art Bible + direct story (not ADR territory)

### Orchestrator + Combat coverage (unchanged since 22c)

ADR-0011 locks the `Floor` type ADR-0010 consumes opaquely — no orchestrator or combat TR count change, but the downstream consumption story is now fully typed. Combat implementation stories can now cite `floor.enemy_list[i].enemy_id` + `floor.is_boss_floor` + `floor.floor_index` with concrete typed contracts.

---

## Cross-ADR Conflicts

**NONE DETECTED.**

ADR-0011 is architected for pure ADR-0006 inheritance + lock-concrete-types; it explicitly does NOT redeclare:

- **Base class**: `GameData` + `id: String` + `display_name: String` are re-used from ADR-0006 (§Base class section cites but does not redeclare). `referenced_by` bumps only, no duplicate interface entries.
- **Directory layout + ordered_categories**: Re-used from ADR-0006. No rank change, no category reorder.
- **DAG cross-reference rule**: Re-used from ADR-0006. ADR-0011's `Floor.enemy_id` id-string contract is a *refinement* of the DAG rule (loose coupling via id-string), not a conflicting stance.
- **Read-only runtime contract**: Re-used from ADR-0006. All fields `@export`-decorated; no runtime setters.
- **`MatchupResult` / matchup-resolver**: Untouched by ADR-0011. `EnemyArchetypes.ALL_SET` becomes the single-source-of-truth enum the `MatchupResult.matched_archetypes` field elements MUST draw from — strengthens ADR-0009 without conflicting. `referenced_by` bump on ADR-0009's `matchup_result_value_type` entry.
- **ADR-0010 `Floor` opaque type**: ADR-0011 §5 fully locks the shape ADR-0010 consumed opaquely. Zero stance collision — ADR-0010's signature `compute_offline_batch(formation, floor: Floor, tick_budget, error_logger)` was authored specifically to leave `Floor` underspecified pending ADR-C02.

Spot-checks of potential collision surfaces (all clean):

- ADR-0011 ↔ ADR-0004 (Save Envelope): `Array[Dictionary]` dict entries serialize via `JSON.stringify(save_data)` per save-load-system.md Rule 5 — `{enemy_id: String, count: int}` is JSON-safe. No envelope schema overlap.
- ADR-0011 ↔ ADR-0005 (Time System): Resource schemas are pure content; no clock reads, no tick subscriptions. Orthogonal.
- ADR-0011 ↔ ADR-0007 (Scene Transition): Resources are loaded at rank 1 (DataRegistry); scene transitions at rank 13 (SceneManager). No lifecycle overlap.
- ADR-0011 ↔ ADR-0009: companion — archetype constant set feeds matchup-resolver's `matched_archetypes` field. No redeclaration; reinforces the single-source-of-truth intent.
- ADR-0011 ↔ ADR-0010: companion — locks the `Floor` opaque type ADR-0010 consumes. Zero stance collision.

No data ownership, integration contract, performance budget, dependency cycle, or architecture pattern conflicts.

---

## ADR Dependency Graph

Updated from 22c review:

```
Level 0 (no dependencies):       ADR-0001, ADR-0002, ADR-0003 (triple-amended)
Level 1 (depends on 0003):       ADR-0004, ADR-0006
Level 2 (depends on Level 1):    ADR-0005 (requires 0003 + 0004)
Level 3 (depends on Level 2):    ADR-0007 (requires 0003 + 0004 + 0005 + 0006)
                                 ADR-0009 (requires 0003-Amendment-#3 + 0006)
Level 4 (depends on Level 3):    ADR-0008 (requires 0006 + 0007)
                                 ADR-0010 (requires 0003 + 0006 + 0009)
                                 ADR-0011 (requires 0006) — Proposed
```

- **10 of 11 ADRs Accepted.** ADR-0011 is Proposed (awaiting Accept promotion).
- **No cycles.** No unresolved dependencies.
- ADR-0011's sole `Depends On` (ADR-0006) is Accepted — ADR-0011 is safe to promote.

**Recommended authoring order for remaining Required ADRs** (given ADR-0011 is Proposed, not Accepted):

0. **Promote ADR-0011 to Accepted** (status flip; no content change required).
1. **ADR-X03** — Hero Roster mutation contract + HeroInstance identity stability. Covers TR-hero-roster-001..030 gap pool (~26 TRs). Cites ADR-0011 for `HeroClass.id` / `HeroClass.tier` consumption contract.
2. **ADR-C01** — Economy state shape + recruitment cost curve + drip ticker. Covers TR-economy-001..028 gap pool minus ADR-0002 coverage (~20 TRs). Cites ADR-0011 for `HeroClass.tier` + `EnemyData.tier` input contracts; unblocks TR-biome-dungeon-db-017.
3. **ADR-X02** — Offline batch chunking + offline-replay snapshot schema. Cites ADR-0011 for `Floor.enemy_list` freeze target + `EnemyArchetypes.ALL_SET` as source of `matched_archetypes`. Covers TR-orchestrator-010..013/029 + TR-economy-017..019 + TR-biome-dungeon-db-019.

After those 3 ADRs: ADR-C03 (Audio) + ADR-X04 (Recruitment) remain blocked on their GDDs being authored (not architectural gaps — GDD gaps).

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 11 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 11 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] via autoload.md Claim 1 (2026-04-21) + Claim 4 (2026-04-22) |

### Post-cutoff APIs in use (by ADR-0011)

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| `@abstract` decorator on Resource-derived base (inherited from ADR-0006) | Godot 4.5+ | ADR-0011 via `extends GameData` | LOW | Inherited from ADR-0006; verification already catalogued in `autoload.md` Claim 3 [INCONCLUSIVE] for editor-UI hint rendering (MVP-runtime unaffected). One-time @abstract-on-Resource probe is an ADR-0006 outstanding item, not an ADR-0011 new risk. |
| `Array[Dictionary]` typed-array-of-untyped-Dictionary syntax | Godot 4.4+ | ADR-0011 §5 `Floor.enemy_list` | LOW | Stable 4.4+. Per ADR-0011 Negative Consequences: inspector does NOT render per-element dict editing UI; authoring is text-file-driven for MVP. Validator catches malformed entries at load time. Tradeoff documented; custom `EditorInspectorPlugin` deferred to V1.0. |
| `class_name X extends RefCounted` for static-constant modules (`EnemyArchetypes`, `ClassRoles`) | stable since 4.0 | ADR-0011 §Archetype/Role constant sets | LOW | godot-gdscript-specialist NOTE #5 LOAD-BEARING folded: `extends RefCounted` chosen over `extends Object` because RefCounted self-manages instance memory if `.new()` is accidentally called in a test. Safer default for a pure static-constant module. |
| `ExtResource()` cross-file references + `duplicate_deep()` boundary | Godot 4.4+ | ADR-0011 DAG rule (inherited from ADR-0006) + §5 Floor.enemy_list id-string pattern | LOW | `ExtResource` is stable 4.0+; `duplicate_deep()` boundary semantics catalogued in `docs/engine-reference/godot/breaking-changes.md` 4.4+ entry. ADR-0011 §5 chose id-string refs over inline `ExtResource` specifically to sidestep the `duplicate_deep()` shallow-by-default-across-files caveat (hot-reload + save-file stability rationale). |

No new engine-state verifications added by ADR-0011 — all primitives are stable 4.0+ patterns or inherited from already-catalogued ADRs.

### Engine Specialist Consultation

godot-gdscript-specialist was invoked at ADR-0011 authoring time (Step 4.5) — **APPROVE-WITH-NOTES** recorded in ADR-0011 §Specialist Review. Ten notes issued:

- **2 LOAD-BEARING (folded in-place)**:
  - NOTE #4: `Array[Dictionary]` inspector-UX limitation — added to Negative Consequences with explicit rationale for rejecting `Array[Dictionary[K,V]]` typed-dict alternative (mixed-type-value case is awkward) + forward-looking custom `EditorInspectorPlugin` story.
  - NOTE #5: `class_name X extends Object` → `class_name X extends RefCounted` for both constant modules. RefCounted handles its own memory if `.new()` is accidentally called in tests; Object would leak a tracked engine instance.
- **8 forward-looking (retained for implementation-story awareness)**: inspector-dropdown-UX for String role/archetype fields; PackedStringArray.has(StringName) coercion caveat; StringName vs String micro-optimization (non-concern at MVP scale); @export-group rendering order; @export inheritance behavior; default-value handling; validation-approach comparison; static func validator idiom.

No mechanically-wrong engine claims flagged.

### Outstanding verifications (pre-MVP-ship)

Unchanged from prior review:

1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe; AC-DLS-01 covers implicitly. ADR-0011's `extends GameData` inherits this pending verification.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10).
3. **iOS/Android atomic-rename fallback** (ADR-0004 Risk #4).

No new verifications added by ADR-0011.

---

## GDD Revision Flags (Architecture → Design Feedback)

**None.**

`design/gdd/data-loading.md` was synced in lockstep with ADR-0011 authoring (3 edits: Rule 3 GameData tree `Enemy → EnemyData` with ADR-0011 cross-reference; Rule 6 DAG prose `Enemy → EnemyData` + Floor→EnemyData id-string clarification; Enemy Database Interactions paragraph `Array[Enemy] → Array[EnemyData]`). No additional GDD drift.

All 3 Core DB GDDs (`hero-class-database.md`, `enemy-database.md`, `biome-dungeon-database.md`) were authored before ADR-0011 and their schema sections are the authoritative source ADR-0011 codifies verbatim — ADR + GDD aligned from birth.

No new GDD revision flags surfaced by this review.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (Draft, last amended 2026-04-22c drift-fix pass):

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow coverage | ✅ (4 diagrams: frame, offline, persist, hydrate) |
| API boundaries support integration requirements | ✅ — but see drift items below |
| Orphaned architecture | ⚠️ Same as prior: HD2D + VFX deferred; Onboarding + SettingsAccessibility deferred. Acceptable for MVP. |
| Internal consistency (post ADR-0011 landing) | ⚠️ 5 drift items (ADR-0011 has not been cascaded into architecture.md — listed in Blocking Issues section below) |

### ⚠️ New drift items (architecture.md has not been updated for ADR-0011)

ADR-0011 is authored + Proposed, but `docs/architecture/architecture.md` still treats `ADR-C02` as the unwritten top-priority slot. Five locations carry stale pre-ADR-0011 phrasing:

| Location | Stale text | Should say |
|---|---|---|
| `architecture.md:7` (Version field) | "Version 0.1 (Draft) — amended 2026-04-22 (rank table … `_init(args)` cascade corrected per Amendment #3)" | Append ADR-0011 Proposed landing note: "+ ADR-0011 (Core Resource Schemas) Proposed 2026-04-22 — `Floor` opaque type now fully locked; archetype + role constant sets centralized" |
| `architecture.md:8` (Last Updated field) | "2026-04-22b (post `/architecture-review` drift-fix pass)" | "2026-04-22d (post `/architecture-review` fourth re-run + ADR-0011 landing)" |
| `architecture.md:13` (Document Status header — ADRs Referenced field) | "ADR-0001 through ADR-0010 (all Accepted as of 2026-04-22c — ADR-0010 promoted Proposed→Accepted in the 2026-04-22c review follow-up)" | "ADR-0001 through ADR-0011 (0001–0010 Accepted; ADR-0011 Proposed 2026-04-22 — locks Core DB resource schemas, unblocks 3 Core DB systems + ~57 TRs)" |
| `architecture.md:703` (§Required ADRs Core Layer — ADR-C02 row) | "ADR-C02 \| Resource schema for HeroClass / Enemy / Biome / Dungeon `.tres` files \| Field set per resource type; required vs optional; id naming convention; validation on load (DataRegistry side) \| Hero Class DB, Enemy DB, Biome Dungeon DB" | Row header "ADR-C02 → **ADR-0011 (Proposed 2026-04-22)**"; Decides-column rewritten to landed scope: five `GameData` subclass schemas (16+11+5+2+5 `@export` fields); two canonical constant modules (`EnemyArchetypes` 6 strings / `ClassRoles` 6 strings); universal + per-type + cross-type validator tables with explicit failure actions; `Floor.enemy_list: Array[Dictionary]` of `{enemy_id: String, count: int}` id-string pattern (NOT inline `Array[EnemyData]`); three cross-type invariants (archetype distribution F1-F3, boss-floor uniqueness, tier-1 counter_archetype ∈ MVP_SET); ADR-0010 `Floor` opaque type fully locked; archetype constant set single-source-of-truth for `HeroClass.counter_archetype` ↔ `EnemyData.archetype` ↔ `MatchupResult.matched_archetypes`. Blocks-column: Hero Class DB + Enemy DB + Biome Dungeon DB implementation (unblocked post-Accept); ADR-X02 offline snapshot Floor freeze target (unblocked); content-authoring stories. |
| `architecture.md:727-729` (§Required ADRs total-count paragraph) | "10 Accepted (0001, 0002, 0003-0008, 0009, 0010 … C04 ↔ 0009, X01 ↔ 0010) and **6 remain to author** (C01, C02, C03, X02, X03, X04)" with "**ADR-C02 (Resource schemas)** now the top priority" | Post ADR-0011 Proposed: "10 Accepted + **1 Proposed** (0011 covering C02); **5 remain to author** (C01, C03, X02, X03, X04)". Post-Accept-promotion: "**11 Accepted** (0001, 0002, 0003-0008, 0009, 0010, 0011 — where ADR-0011 = Required slot C02 \"Resource schemas\"); **5 remain to author** (C01, C03, X02, X03, X04)". Top-priority call-out shifts to **ADR-X03 (Hero Roster mutation)** (~26 TRs) or equivalently **ADR-C01 (Economy)** (~20 TRs). ADR-C03 (Audio) + ADR-X04 (Recruitment) remain blocked on their GDDs being authored. |

These are low-severity drift (ADR-0011 itself is internally consistent and the registry is already synced), but they are real internal contradictions between `architecture.md` and the landed ADR. Recommend a single architecture.md drift-fix pass analogous to the 22b/22c same-day follow-ups.

### ⚠️ Traceability index drift (`docs/architecture/requirements-traceability.md`) — applied in this review

| Location | Stale text | Update applied by this review |
|---|---|---|
| `requirements-traceability.md:3` (Last Updated) | "2026-04-22c (third re-run — post ADR-0010 Proposed landing)" | "2026-04-22d (fourth re-run — post ADR-0011 Proposed landing)" |
| `requirements-traceability.md:6` (Verdict annotation) | references 22c review | references 22d review |
| `requirements-traceability.md:11-15` (Coverage Summary) | "~264 (~62%) … Gap ~129 (~30%)" | "~321 (~75%) … Gap ~72 (~17%) — +57 from ADR-0011 covering hero-class-db + enemy-db + biome-dungeon-db schema pool" |
| `requirements-traceability.md:40-42` (hero-class-db / enemy-db / biome-dungeon-db rows) | "ADR-0006 (partial — file format only)" with gap ~18/~18/~21 | Bump Governing ADRs to "ADR-0006, ADR-0011 (Proposed)"; reduce gap counts to ~0/~0/~6; change Gap-Maps-To to "promote ADR-0011 to Accepted" for hero-class-db + enemy-db; biome-dungeon-db maps to ADR-X02 + ADR-C01 + Art Bible |
| `requirements-traceability.md:163-170` (Required ADRs authoring order) | "1. ADR-C02 — Resource schemas …" | Strike item 1 (ADR-C02 is now ADR-0011 Proposed — moved to Blocking Items list). Renumber remaining items: X03 → 1, C01 → 2, X02 → 3. |
| Missing ADR-0011 cross-ref section (after ADR-0010 section) | — | Added new section listing ADR-0011 primary coverage: TR-hero-class-db-001..024, TR-enemy-db-001..023, TR-biome-dungeon-db-001..014 + -020..028; cross-type invariant coverage (F1-F3 archetype distribution, boss-floor uniqueness, tier-1 counter_archetype ∈ MVP_SET); ADR-0006 + ADR-0009 + ADR-0010 `referenced_by` bumps. |
| Re-run Log row | — | Appended 2026-04-22d row noting ADR-0011 coverage delta. |

### ⚠️ Minor cosmetic drift in `design/gdd/data-loading.md`

Line 170 of `data-loading.md` still contains `Array[Enemy]` in the Dependency Matrix table row for Enemy Database — the 3 ADR-0011-era sync edits (lines 38, 54, 69, 97) caught most occurrences but missed this table row. Recommend appending to the architecture.md drift-fix pass: change `Array[Enemy]` → `Array[EnemyData]` at `data-loading.md:170`. Cosmetic only; ADR-0011 itself carries the authoritative `EnemyData` class-name lock.

---

## Verdict: **CONCERNS** (gap-only, reduced severity vs 22c)

**Why not PASS**:
1. ADR-0011 is `Proposed`, not `Accepted`. Per `docs/CLAUDE.md`: "Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked." Same-day Accept promotion follows the 22b / 22c pattern for ADR-0009 / ADR-0010.
2. 5 architecture.md drift items + 1 minor data-loading.md cosmetic drift — ADR-0011 has not been cascaded into the primary architecture document. Low-impact but real contradictions.
3. 3 unwritten Required ADRs still block ~72 TRs (ADR-X03, ADR-C01, ADR-X02) — this is a further −1 from the prior review's 4 unwritten Required ADRs (ADR-C02 is now ADR-0011 Proposed).

**Why not FAIL**:
- No structural conflicts. ADR-0011 is architected for pure ADR-0006 inheritance; `referenced_by` bumps only, no redeclaration.
- All 10 Accepted ADRs + ADR-0011 are dependency-ordered, engine-verified, and internally consistent.
- ADR-0011's content is materially correct and fully covers its scope (5 subclass schemas + 2 constant modules + universal/per-type/cross-type validators + `Array[Dictionary]` rationale + 5 alternatives exhaustively considered + 7 risks with mitigations + 10 specialist notes folded).
- The 72 remaining gaps are all routed to Required ADRs already enumerated in architecture.md §Required ADRs — this is the expected state after the Core Phase-2 ADR (0011) lands.
- No GDD revision flags surfaced. data-loading.md was synced in lockstep BEFORE ADR-0011 finalized; remaining 1 minor cosmetic drift is trivial.
- Coverage crosses the 75% threshold for the first time — PASS candidacy is now achievable with a single further ADR (X03 or C01 would push to ~81%).

### Blocking Issues (must resolve before PASS verdict)

1. **Promote ADR-0011 to Accepted** — content is ready; status flip only. Sole dependency (ADR-0006) is Accepted; safe to promote. Follows the same same-day-follow-up pattern as ADR-0009 promotion on 2026-04-22b and ADR-0010 promotion on 2026-04-22c.
2. **architecture.md drift fix pass** — 5 locations (line 7 Version, 8 Last Updated, 13 Document Status ADRs Referenced, 703 Required ADRs ADR-C02 row, 727-729 total-count paragraph) carry pre-ADR-0011 phrasing. Same-style pass as the 22b/22c drift-fix follow-ups. Single lockstep edit session.
3. **data-loading.md cosmetic drift fix** — line 170 still has `Array[Enemy]`; append to drift-fix pass. Trivial one-line edit.
4. **Traceability index drift fix** — applied in this review (7 locations + new ADR-0011 cross-ref section + re-run log row).

Items 1-3 are low-risk mechanical cascades. Recommended to land in a single session per the prior 22b/22c pattern.

### Non-Blocking Findings

- Open questions unchanged from prior review: OQ-1, OQ-4, OQ-5 (partial), OQ-7, OQ-8, OQ-9, OQ-10. None blocks MVP.
- 3 Required ADRs remain unwritten (X03, C01, X02) — expected; routing is correctly scoped.
- godot-gdscript-specialist NOTE #7 (typed Array covariance gotcha) remains a V1.0 forward-looking concern; not an MVP concern.
- ADR-0011 §Consequences / Negative — `Array[Dictionary]` inspector-UX limitation is a known content-authoring tradeoff; V1.0 `EditorInspectorPlugin` story tracked.

---

## Immediate Actions (recommended order)

1. **Fix the 3 blocking items above in a single lockstep session** (analogous to the 22b / 22c same-day follow-ups):
   - Promote ADR-0011 status: Proposed → Accepted (single status-field edit + add promotion note)
   - Edit architecture.md at 5 locations (line 7 Version, 8 Last Updated, 13 Document Status, 703 ADR-C02 row, 727-729 total-count paragraph)
   - Edit data-loading.md at line 170 (Array[Enemy] → Array[EnemyData])
2. Open a fresh `/architecture-decision` session for **ADR-X03** (Hero Roster mutation contract + HeroInstance identity stability). Unblocks Hero Roster system (~26 TRs). Cites ADR-0011 for `HeroClass.id` / `HeroClass.tier` consumption contract + cites save-load-system.md for persistence shape.
3. After ADR-X03 lands, re-run `/architecture-review` to verify coverage rises (projected ~81%) and no new conflicts.
4. Author ADR-C01 + ADR-X02 in that order.
5. When all Required ADRs Accepted → `/create-control-manifest` → `/gate-check pre-production` → `/create-epics layer: foundation`.

### Rerun Trigger

Re-run `/architecture-review` after each new ADR lands (or after the 3 blocking items above are cleared).

---

## Files Written This Review

- `docs/architecture/architecture-review-2026-04-22d.md` — this report
- `docs/architecture/requirements-traceability.md` — coverage summary bumped; Core DB rows updated; ADR-0011 cross-ref section added; Required ADRs authoring order renumbered; Re-run Log row appended

No GDD edits, no ADR edits, no architecture.md edits performed by this review — those are the blocking items awaiting their own review/approval cycle.

---

## Summary

ADR-0011 lands cleanly. Coverage crosses 75% for the first time. No cross-ADR conflicts, no GDD revision flags, no engine anti-patterns flagged. 3 blocking drift items + 1 minor data-loading.md cosmetic drift pending — all low-risk mechanical cascades for a same-day lockstep follow-up. Next best unwritten Required ADR: **ADR-X03 (Hero Roster)**, projected coverage ~81% on landing.

---

## Same-Day Follow-Up: Blocking Items Cleared (2026-04-22d)

After the review report was written, the user authorized the 3 blocking items to be resolved in a single lockstep pass. All three are now complete:

1. ✅ **ADR-0011 status: Proposed → Accepted** (`docs/architecture/ADR-0011-resource-schemas-core-databases.md`). Status header updated; note added citing the same-day `/architecture-review 2026-04-22d` follow-up as the promotion gate. Content unchanged.

2. ✅ **architecture.md drift fix pass** (`docs/architecture/architecture.md`):
   - Line 7 (Version field) — appended ADR-0011 Accepted 2026-04-22d landing note (`Floor` opaque type locked; archetype + role constant sets centralized)
   - Line 8 (Last Updated field) — "2026-04-22b" → "2026-04-22d (post `/architecture-review` fourth re-run + ADR-0011 Accept promotion + drift-fix pass)"
   - Line 13 (Document Status — ADRs Referenced) — "ADR-0001 through ADR-0010 (all Accepted as of 2026-04-22c)" → "ADR-0001 through ADR-0011 (all Accepted as of 2026-04-22d — ADR-0011 promoted Proposed→Accepted; locks Core DB resource schemas, unblocks 3 Core DB systems + ~57 TRs; coverage crosses 75% threshold)"
   - Line 703 (§Required ADRs Core Layer — ADR-C02 row) — row header "ADR-C02" → "ADR-C02 → **ADR-0011 (Accepted 2026-04-22d)**"; Decides-column rewritten with landed scope (5 subclass schemas + 2 constant modules + universal/per-type/cross-type validator tables + `Array[Dictionary]` id-string pattern + 3 cross-type invariants + ADR-0010 `Floor` lock + archetype single-source-of-truth); Blocks-column refreshed with unblocked state
   - Lines 727-729 (§Required ADRs total-count paragraph) — "10 Accepted / 6 remain to author (C01, C02, C03, X02, X03, X04)" → "11 Accepted (0001, 0002, 0003-0008, 0009, 0010, 0011) / 5 remain to author (C01, C03, X02, X03, X04)"; top-priority call-out shifted from ADR-C02 to ADR-X03 (Hero Roster); Core/Feature Phase progress noted (C04 + C02 + X01 landed); PASS-verdict runway noted (single further Required ADR → ~81%)

3. ✅ **data-loading.md cosmetic drift fix** (`design/gdd/data-loading.md:170`) — Enemy Database Interactions dependency table row: `Array[Enemy]` → `Array[EnemyData]` with inline ADR-0011 cross-reference ("class name `EnemyData` per enemy-database.md §C.1 + ADR-0011"). Completes the lockstep sync started by ADR-0011 authoring; no residual `Array[Enemy]` references remain in `data-loading.md`.

4. ✅ **Traceability index drift fix applied** (`docs/architecture/requirements-traceability.md`) — already applied in the primary review pass:
   - Coverage Summary bumped to ~321 / ~75% (+57 from ADR-0011)
   - Core layer rows (hero-class-db, enemy-db, biome-dungeon-db) updated to cite ADR-0011 as Governing ADR; gaps reduced to 0/0/6
   - ADR-0009 cross-ref gained "Archetype constant set" bullet
   - ADR-0010 status tag corrected (Proposed → Accepted 2026-04-22c, stale from 22c)
   - ADR-0011 cross-ref section added (full TR coverage + constant sets + cross-type invariants + registry expansion)
   - Required ADRs authoring order renumbered (ADR-C02 removed — now landed as ADR-0011; X03 → 1, C01 → 2, X02 → 3)
   - Re-run Log row appended for 22d

5. ✅ **tr-registry.yaml header note appended** — 22d re-run note records coverage bump to 75% (321/425); no TR-IDs added or renumbered; ADR-0011 codifies existing schema-scope TRs verbatim.

### Post-cleanup state

- **11 of 11 ADRs Accepted** (0001-0011). ADR-0011 was the sole Proposed ADR; now promoted.
- No internal contradictions in architecture.md.
- No stale TR text (TR-hero-class-db / TR-enemy-db / TR-biome-dungeon-db entries were never stale — ADR-0011 codifies them as-written; traceability index ADR-0010 status tag corrected in this pass).
- No cycles, no unresolved ADR dependencies.
- Coverage: **~75% (~321/425)**. Remaining ~72 gaps are purely Core/Feature-layer and route cleanly to 3 unwritten Required ADRs (X03, C01, X02) or direct stories / Art Bible content validation.
- **75% threshold crossed for the first time.** A single further Required ADR (ADR-X03 projected ~81%, ADR-C01 projected ~80%) puts PASS verdict in reach.

**Still NOT a PASS verdict** because 3 unwritten Required ADRs still block ~72 TRs — this is the expected state after the Core Phase-2 ADR lands, not a regression. Verdict remains CONCERNS until at least ADR-X03 or ADR-C01 lands.

**Next action (fresh session)**: `/architecture-decision` for **ADR-X03** (Hero Roster mutation + HeroInstance identity stability — cites ADR-0011 for `HeroClass.id`/`HeroClass.tier` consumption contract + cites save-load-system.md for persistence shape). Prerequisites all Accepted; no blockers.
