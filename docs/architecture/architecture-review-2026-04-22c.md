# Architecture Review — 2026-04-22c (third re-run, post ADR-0010 landing)

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 10 (9 Accepted: 0001–0009; 1 **Proposed**: 0010) |
| Registry State | populated (425 TR-IDs, v2) |
| Prior Reviews | `architecture-review-2026-04-22.md` (CONCERNS — initial population); `architecture-review-2026-04-22b.md` (CONCERNS — gap-only after ADR-0009 + drift-fix) |
| Verdict | **CONCERNS** (gap-only, unchanged severity from 22b; coverage rises; new drift items surfaced by ADR-0010 authoring) |

---

## What changed since the prior review (2026-04-22b)

One landing since the prior review:

1. **ADR-0010** (**Proposed 2026-04-22**) — Combat Resolver — Snapshot Shape + Foreground/Offline Parity Invariants. Covers the `ADR-X01` slot the prior review flagged as the top unwritten Required ADR. Codifies the 5 RefCounted value types (`KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot`, plus `MatchupResult` consumed from ADR-0009), the shared-private-helper parity invariant, the `dict_equals` key-walk contract (hash-based equality forbidden), the foreground-per-event vs offline-aggregate-only asymmetry, and the `error_logger: Callable` per-call DI pattern. Re-uses ADR-0009's `set_combat_resolver` setter + lazy-default `_ready()` DI seam verbatim; does not redeclare.

Out-of-lockstep touches already landed by ADR-0010's authoring session:

- `docs/registry/architecture.yaml` — expanded in lockstep with ADR-0010: 2 new interfaces (`combat_resolver_module_shape`, `combat_value_type_contracts`), 4 new api_decisions (`combat_foreground_offline_parity_via_shared_helpers`, `combat_dict_equality_policy`, `combat_offline_output_asymmetry`, `combat_error_logger_per_call_di`), 3 new forbidden_patterns (`combat_resolver_state_or_signal_addition`, `combat_resolver_hash_based_dict_equality`, `combat_batch_result_per_event_regression`), 1 new performance_budget (`combat_compute_offline_batch` — 100ms CI / 200ms mobile for 576k-tick batch, BLOCKING, backs AC-COMBAT-14 + TR-combat-024). `last_updated` bumped with ADR-0010 reference.
- `design/gdd/combat-resolution.md` — already Pass-INIT-PROBE-SYNC'd 2026-04-22 (DI phrasing pre-corrected before ADR-0010 authored); NO additional GDD touch needed by ADR-0010.

---

## Traceability Summary

**Total requirements**: 425 (no new TRs in this review — ADR-0010 codifies existing combat-resolution.md TRs; no new requirements surfaced).

| Status | Count | % | Δ vs prior |
|---|---|---|---|
| ✅ Covered | ~264 | ~62% | **+32** (ADR-0010 covers TR-combat-001..032 gap pool) |
| ⚠️ Partial | ~32 | ~8% | unchanged |
| ❌ Gap | ~129 | ~30% | **−32** |

Per-system coverage (post ADR-0010):

| System (GDD) | TRs | Governing ADRs | Covered | Gap | Gap Routes To |
|---|---|---|---|---|---|
| save-load | 60 | 0003, 0004, 0005, 0007 | ~52 | ~4 | minor UX/debug |
| time | 36 | 0003, 0005 | ~34 | ~1 | — |
| data-loading | 28 | 0003, 0006 | ~27 | ~1 | — |
| scene-manager | 39 | 0003, 0007, 0008 | ~35 | ~2 | OQ-7 |
| hero-class-db | 24 | 0006 (partial) | ~4 | ~18 | ADR-C02 |
| enemy-db | 23 | 0006 (partial) | ~3 | ~18 | ADR-C02 |
| biome-dungeon-db | 28 | 0006 (partial) | ~5 | ~21 | ADR-C02 |
| matchup-resolver | 33 | 0009 | ~31 | ~2 | minor (CI helper wording) |
| **combat** | **32** | **0010 (Proposed)** | **~32** | **~0** | **promote 0010 to Accepted → full coverage** |
| orchestrator | 32 | 0001, 0002, 0003, 0004, 0005, 0009, 0010 | ~24 | ~4 | ADR-X02 |
| economy | 28 | 0002 | ~6 | ~20 | ADR-C01 |
| hero-roster | 30 | 0003 (partial) | ~2 | ~26 | ADR-X03 |
| floor-unlock | 32 | 0002, 0003 | ~10 | ~18 | direct story (X05 deferred V1.0) |
| **TOTAL** | **425** | — | **~264** | **~129** | — |

### Orchestrator coverage delta

ADR-0010 raises orchestrator coverage by ~4 TRs by codifying the orchestrator-side consumption contracts for CombatResolver:

- **TR-orchestrator-008** (`_on_tick_fired` calls `combat_resolver.emit_events_in_range`) — now ADR-backed via ADR-0010 §Architecture diagram foreground path.
- **TR-orchestrator-022/028/029** (foreground/offline parity invariants) — now ADR-backed via ADR-0010 §Parity invariant — formal statement.
- **TR-combat-029/030** (Combat does NOT subscribe to tick_fired; emits no signals) — now ADR-backed via ADR-0010 §Module shape statelessness contract.

Remaining orchestrator gap (~4 TRs) routes to ADR-X02 (offline batch chunking snapshot schema — `matchup_cache` + `kill_schedule` fields persisted in offline-replay snapshot).

---

## Cross-ADR Conflicts

**NONE DETECTED.**

ADR-0010 is architected to NOT introduce new stances; it explicitly re-uses ADR-0009's patterns:

- **DI seam**: ADR-0010 §Injection contract says verbatim "re-uses ADR-0009 §Injection contract … cites the existing one" — does not add a new `orchestrator_di_pattern` registry entry; bumps `referenced_by` only.
- **Zero-arg `_init` invariant**: inherited from ADR-0003 Amendment #3 project-wide forbidden pattern; ADR-0010 adds a `referenced_by` bump only.
- **`MatchupResult` value type**: consumed from ADR-0009; ADR-0010 bumps `matchup_result_value_type.referenced_by` to add itself, does not redeclare.
- **Autoload rank 9**: already vacated by ADR-0003 Amendment #2; ADR-0010 confirms non-autoload status; no rank-table mutation.

No data ownership, integration contract, performance budget, dependency cycle, or architecture pattern conflicts.

Spot-checks of potential collision surfaces (all clean):

- ADR-0010 ↔ ADR-0004 (Save Envelope): Combat value types are transient per-call. `CombatRunSnapshot` lives on Orchestrator-owned `RunSnapshot`; ADR-0004 persists `RunSnapshot.to_dict()` via Orchestrator's `get_save_data`, which is already covered by TR-orchestrator-003/005. No schema overlap.
- ADR-0010 ↔ ADR-0005 (Time System): Combat reads no time state directly — Orchestrator bridges `tick_fired(n)` → `emit_events_in_range(last, n)`. No clock coupling.
- ADR-0010 ↔ ADR-0009: explicit companion — ADR-0010's §Related Decisions block names ADR-0009 as companion; §Injection contract re-uses verbatim without duplication.

---

## ADR Dependency Graph

Updated from prior review:

```
Level 0 (no dependencies):       ADR-0001, ADR-0002, ADR-0003 (triple-amended)
Level 1 (depends on 0003):       ADR-0004, ADR-0006
Level 2 (depends on Level 1):    ADR-0005 (requires 0003 + 0004)
Level 3 (depends on Level 2):    ADR-0007 (requires 0003 + 0004 + 0005 + 0006)
                                 ADR-0009 (requires 0003-Amendment-#3 + 0006)
Level 4 (depends on Level 3):    ADR-0008 (requires 0006 + 0007)
                                 ADR-0010 (requires 0003 + 0006 + 0009) — Proposed
```

- **9 of 10 ADRs Accepted.** ADR-0010 is Proposed (awaiting author sign-off / Accept promotion).
- **No cycles.** No unresolved dependencies.
- All ADR-0010 `Depends On` links (ADR-0003, ADR-0006, ADR-0009) are Accepted — ADR-0010 is safe to promote.

**Recommended authoring order for remaining Required ADRs** (given ADR-0010 is Proposed, not Accepted):

0. **Promote ADR-0010 to Accepted** (status flip; no content change required).
1. **ADR-C02** — Resource schemas for HeroClass / Enemy / Biome / Dungeon / Floor `.tres`. Unblocks ~57 TRs across 3 Core DB systems. (Floor schema consumed opaquely by ADR-0010 becomes fully locked.)
2. **ADR-X03** — Hero Roster mutation + HeroInstance identity.
3. **ADR-C01** — Economy state shape + recruitment cost curve + drip ticker.
4. **ADR-X02** — Offline batch chunking refinement + offline-replay snapshot schema (depends on ADR-0010's `CombatBatchResult` as the chunking unit; carries `matched_archetypes` per ADR-0009 §Offline replay zero-call invariant; adds `matchup_cache` + `kill_schedule` to snapshot shape).

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 10 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 10 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] via autoload.md Claim 1 (2026-04-21) + Claim 4 (2026-04-22) |

### Post-cutoff APIs in use (by ADR-0010)

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| `Dictionary[StringName, int]` + `Dictionary[int, int]` typed dictionary syntax | Godot 4.4+ | ADR-0010 `CombatBatchResult.kills_by_archetype`, `kills_by_tier` | LOW | Already verified live in combat-resolution.md C.4 and ADR-0009's `MatchupResult` shape; same idiom reused. Read-path returns direct value; write-path engine-checked at assignment. |
| `extends RefCounted` + subclass override (`DefaultCombatResolver extends CombatResolver`) | stable since 4.0 | ADR-0010 five value types + resolver base class | LOW | Standard GDScript; mirrors ADR-0009 `MatchupResolver` → `DefaultMatchupResolver` pattern. |
| `Callable()` default parameter with `is_valid() == false` | stable since 4.0 | ADR-0010 `error_logger: Callable = Callable()` optional DI | LOW | godot-specialist APPROVE-WITH-NOTES #4 confirmed idiomatic; `Callable = null` would be invalid for typed Callable parameter. |
| Typed `Array[KillEvent]`, `Array[HeroInstance]`, `Array[int]` element-wise `!=` | stable since 4.4 (typed arrays) | ADR-0010 `CombatTickEvents.equals()` | LOW | godot-specialist APPROVE-WITH-NOTES #2 confirmed element-wise equality correct; caveat documented in the ADR body for typed-vs-untyped coercion. |

No new engine-state verifications added by ADR-0010 — all structural primitives are reuses of ADR-0009's verified shape (`.new()` on non-autoload RefCounted subclass, zero-arg autoload `_init`, lazy-default `_ready()`, public setter DI, `extends` inheritance override for test spies). Pass-INIT-PROBE (2026-04-22) on Godot 4.6.1.stable.mono.official is the empirical backing for the composed pattern.

### Engine Specialist Consultation

godot-specialist was invoked at ADR-0010 authoring time (Step 4.5) — **APPROVE-WITH-NOTES** recorded in ADR-0010 §Specialist Review. Seven notes issued; five folded in-place into the ADR body, two retained for implementation-story awareness (NOTE #4 `Callable()` idiom confirmation — no change needed; NOTE #7 typed Array covariance gotcha — forward-looking for V1.0 hero subclass hierarchies, not MVP). No mechanically-wrong engine claims flagged.

### Outstanding verifications (pre-MVP-ship)

Unchanged from prior review:

1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe; AC-DLS-01 covers implicitly. Note: ADR-0010 explicitly does NOT use `@abstract` on `CombatResolver` — Pass 3D (combat-resolution.md §C.4) superseded the `@abstract extends Object` static-only shape with the concrete-base-class instance-methods shape specifically to unlock GdUnit4 spy-subclass mocking.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10).
3. **iOS/Android atomic-rename fallback** (ADR-0004 Risk #4).

No new verifications added by ADR-0010.

---

## GDD Revision Flags (Architecture → Design Feedback)

**None.**

`design/gdd/combat-resolution.md` was already Pass-INIT-PROBE-SYNC'd on 2026-04-22 (DI phrasing corrected from `_init(combat_resolver)` to `set_combat_resolver(resolver)` + lazy-default `_ready()`) — ADR-0010 authored AFTER that sync, so the ADR's codification matches the GDD exactly. No GDD-vs-ADR drift.

No new GDD revision flags surfaced by this review.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (Draft, last amended 2026-04-22b drift-fix pass):

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow coverage | ✅ (4 diagrams: frame, offline, persist, hydrate) |
| API boundaries support integration requirements | ✅ — but see drift items below |
| Orphaned architecture | ⚠️ Same as prior review: HD2D + VFX deferred; Onboarding + SettingsAccessibility deferred. Acceptable for MVP. |
| Internal consistency (post ADR-0010 landing) | ⚠️ 5 drift items (ADR-0010 has not been cascaded into architecture.md — listed in Blocking Issues section below) |

### ⚠️ New drift items (architecture.md has not been updated for ADR-0010)

ADR-0010 is authored + Proposed, but `docs/architecture/architecture.md` still treats it as "ADR-X01 (upcoming)". Five locations carry stale pre-ADR-0010 phrasing:

| Location | Stale text | Should say |
|---|---|---|
| `architecture.md:13` (Document Status header — ADRs Referenced field) | "ADR-0001 through ADR-0009 (all Accepted as of 2026-04-22)" | "ADR-0001 through ADR-0010 (0001–0009 Accepted; ADR-0010 Proposed 2026-04-22)" |
| `architecture.md:315` (§Module Ownership Map CombatResolver row) | "See ADR-0003 Amendment #2 + #3, **ADR-X01 (upcoming)**, `dungeon-run-orchestrator.md` §J.1 (locked Option A wiring), and `design/gdd/combat-resolution.md`." | Replace `ADR-X01 (upcoming)` with `ADR-0010 (Proposed 2026-04-22)`. |
| `architecture.md:598` (API Boundaries CombatResolver code comment) | "# See ADR-0003 Amendment #3 + **ADR-X01 (upcoming)**; dungeon-run-orchestrator.md §J.1 is the locked source." | Replace `ADR-X01 (upcoming)` with `ADR-0010 (Proposed 2026-04-22)`. |
| `architecture.md:711` (§Required ADRs ADR-X01 row) | "ADR-X01 \| Combat Resolution input + output snapshot shape \| Exact `FormationSnapshot`, `FloorSnapshot`, `CombatOutcome` field set; …" | Row header should read "ADR-X01 → **ADR-0010 (Proposed 2026-04-22)**"; Decides-column should describe the landed scope (5 RefCounted value types, shared-helper parity invariant, dict-equals policy, error_logger DI). |
| `architecture.md:727-729` (§Required ADRs total-count paragraph) | "6 Foundation … + 4 Core … + 4 Feature … = **14 ADRs**. Plus the 2 originally-Accepted ADRs (0001, 0002) = **16 ADRs total**. Of those, **8 are Accepted** (0001, 0002, 0003-0008) and **8 remain to author** (C01-C04, X01-X04)." | Refresh: "9 are Accepted (0001, 0002, 0003-0008, 0009); **1 is Proposed** (0010); **6 remain to author** (C01, C02, C03, C04, X02, X03, X04 — note X01 is now ADR-0010; X05 deferred V1.0)." Core/Feature priority shifts: ADR-C02 + ADR-X03 are now the next two priorities. |

These are low-severity drift (ADR-0010 itself is internally consistent and the registry is already synced), but they are real internal contradictions between `architecture.md` and the landed ADR. Recommend a single architecture.md drift-fix pass analogous to the 2026-04-22b drift-fix follow-up.

### ⚠️ Traceability index drift (`docs/architecture/requirements-traceability.md`)

| Location | Stale text | Should say |
|---|---|---|
| `requirements-traceability.md:13-15` (Coverage Summary) | "232 (~55%) … Gap ~161 (~38%)" | "264 (~62%) … Gap ~129 (~30%) — +32 from ADR-0010 covering TR-combat-001..032" |
| `requirements-traceability.md:49` (combat row in Feature Layer matrix) | "combat \| TR-combat-001..032 \| 32 \| ADR-0001 (partial) \| ~24 \| ADR-X01" | "combat \| TR-combat-001..032 \| 32 \| ADR-0010 (Proposed) \| ~0 \| promote ADR-0010 to Accepted" |
| `requirements-traceability.md:50` (orchestrator row) | "orchestrator … Gap Maps To: ADR-X01 / ADR-X02" | "orchestrator … Gap Maps To: ADR-X02" (ADR-0010 closed ~4 orchestrator TRs) |
| `requirements-traceability.md:130` (ADR-0009 cross-ref) | "Combat companion (CombatResolver) `set_combat_resolver` setter: cross-reference to ADR-X01 (pending)" | "Combat companion (CombatResolver): ADR-0010 (Proposed 2026-04-22) — ADR-0009's `set_combat_resolver` setter re-used verbatim" |
| `requirements-traceability.md:145` (Required ADRs authoring order item 1) | "ADR-X01 — Combat snapshot shape … Covers: TR-combat-001..032 gap pool" | Strike item 1 (ADR-X01 is now ADR-0010 Proposed — covered above). Renumber remaining 4 items. |
| Missing ADR-0010 cross-ref section (after ADR-0009 section) | — | Add new section listing ADR-0010 primary coverage: TR-combat-001..032; supporting TR-orchestrator-008/022/028/029; value-type schema TR-combat-013..015; dict-equality policy TR-combat-016; parity invariant TR-combat-022/023. |

---

## Verdict: **CONCERNS** (gap-only, unchanged severity from 22b)

**Why not PASS**:
1. ADR-0010 is `Proposed`, not `Accepted`. Per `docs/CLAUDE.md`: "Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked." Same-day Accept promotion follows the 2026-04-22b pattern for ADR-0009.
2. 5 architecture.md drift items + 6 traceability index drift items — ADR-0010 has not been cascaded into the two index documents. Low-impact but real contradictions.
3. 4 unwritten Required ADRs still block ~129 TRs (ADR-C02, ADR-X03, ADR-C01, ADR-X02). This is a further −1 from the prior review's 5 unwritten Required ADRs (ADR-X01 is now ADR-0010 Proposed).

**Why not FAIL**:
- No structural conflicts. ADR-0010 is architected to re-use ADR-0009's DI seam + ADR-0003's rank + `_init` invariants; no redeclaration, no collision.
- All 9 Accepted ADRs + ADR-0010 are dependency-ordered, engine-verified, and internally consistent with each other.
- ADR-0010's content is materially correct and fully covers its scope (5 value types + parity invariant + dict equality + asymmetry rationale + error-logger DI + CI structural invariants).
- The 129 gaps are all routed to Required ADRs already enumerated in architecture.md §Required ADRs — this is the expected state after the Core/Feature Phase-1 ADR (0010) lands.
- No GDD revision flags surfaced. combat-resolution.md was Pass-INIT-PROBE-SYNC'd 2026-04-22 BEFORE ADR-0010 authored; GDD + ADR are already aligned.

### Blocking Issues (must resolve before PASS verdict)

1. **Promote ADR-0010 to Accepted** — content is ready; status flip only. All dependencies (ADR-0003, ADR-0006, ADR-0009) are Accepted; safe to promote. Follows the same same-day-follow-up pattern as ADR-0009 promotion on 2026-04-22b.
2. **architecture.md drift fix pass** — 5 locations (line 13 header, 315 Module Ownership Map row, 598 API Boundaries comment, 711 Required ADRs row, 727-729 total-count paragraph) carry pre-ADR-0010 phrasing. Same-style pass as the 2026-04-22b drift-fix follow-up.
3. **Traceability index drift fix pass** — 6 locations (line 13-15 coverage summary, 49 combat row, 50 orchestrator row, 130 ADR-0009 cross-ref, 145 Required ADRs list, + new ADR-0010 cross-ref section). Single lockstep edit session.

All three are low-risk mechanical cascades. Recommended to land in a single session per the prior pattern.

### Non-Blocking Findings

- Open questions unchanged from prior review: OQ-1, OQ-4, OQ-5 (partial), OQ-7, OQ-8, OQ-9, OQ-10. None blocks MVP.
- 4 Required ADRs remain unwritten (C02, X03, C01, X02) — expected; routing is correctly scoped.
- godot-specialist NOTE #7 (typed Array covariance gotcha) is a V1.0 forward-looking concern for any hero subclass hierarchy — not an MVP concern. ADR-0010 correctly marked as implementation-story awareness, not ADR-level.

---

## Immediate Actions (recommended order)

1. **Fix the 3 blocking items above in a single lockstep session** (analogous to the 2026-04-22b same-day drift-fix follow-up):
   - Promote ADR-0010 status: Proposed → Accepted
   - Edit architecture.md at 5 locations (line 13, 315, 598, 711, 727-729)
   - Edit requirements-traceability.md at 6 locations + add ADR-0010 cross-ref section
2. Open a fresh `/architecture-decision` session for **ADR-C02** (Resource schemas for HeroClass / Enemy / Biome / Dungeon / Floor `.tres`). Unblocks 3 Core DB systems (~57 TRs). Prerequisite already complete (hero-class-db + enemy-db extends GameData sync landed 2026-04-22).
3. After ADR-C02 lands, re-run `/architecture-review` to verify coverage rises to ~85%+ and no new conflicts.
4. Author ADR-X03, ADR-C01, ADR-X02 in that order.
5. When all Required ADRs Accepted → `/create-control-manifest` → `/gate-check pre-production` → `/create-epics layer: foundation`.

### Rerun Trigger

Re-run `/architecture-review` after each new ADR lands (or after the 3 blocking items above are cleared).

---

## Files Written This Review

- `docs/architecture/architecture-review-2026-04-22c.md` — this report
- `docs/architecture/requirements-traceability.md` — coverage summary bumped; ADR-0010 cross-ref section added; Re-run Log row added noting ADR-0010 coverage delta

No GDD edits, no ADR edits, no architecture.md edits performed by this review — those are the 3 blocking items awaiting their own review/approval cycle.

---

## Same-Day Follow-Up: Blocking Items Cleared (2026-04-22c)

After the review report was written, the user authorized the 3 blocking items to be resolved in a single lockstep pass. All three are now complete:

1. ✅ **ADR-0010 status: Proposed → Accepted** (`docs/architecture/ADR-0010-combat-resolver-snapshot-and-parity.md`). Status header updated; note added citing the same-day `/architecture-review 2026-04-22c` follow-up as the promotion gate. Content unchanged.

2. ✅ **architecture.md drift fix pass** (`docs/architecture/architecture.md`):
   - Line 13 (Document Status — ADRs Referenced field) — "ADR-0001 through ADR-0009" → "ADR-0001 through ADR-0010 (all Accepted as of 2026-04-22c — ADR-0010 promoted Proposed→Accepted)"
   - Line 315 (§Module Ownership Map CombatResolver row) — "ADR-X01 (upcoming)" → "ADR-0010 (Accepted 2026-04-22c)"
   - Line 598 (API Boundaries CombatResolver code comment) — "ADR-X01 (upcoming)" → "ADR-0010 (Accepted 2026-04-22c)"
   - Line 711 (§Required ADRs ADR-X01 row) — row header "ADR-X01" → "ADR-X01 → **ADR-0010 (Accepted 2026-04-22c)**"; Decides-column rewritten to describe the landed scope (five RefCounted value types, shared-helper parity invariant, dict-equality policy, foreground/offline asymmetry, `error_logger` DI, statelessness CI invariants); Blocks-column updated to reflect unblocked state
   - Lines 727-729 (§Required ADRs total-count paragraph) — "8 Accepted … 8 remain to author (C01-C04, X01-X04)" → "10 Accepted (0001-0010) … 6 remain to author (C01, C02, C03, X02, X03, X04)"; top-priority call-out updated to ADR-C02 (Resource schemas) as the next unblocking authoring target

3. ✅ **Traceability index drift fix pass** (`docs/architecture/requirements-traceability.md`) — already applied in the primary review pass:
   - Coverage Summary bumped to ~264/~62% (+32 from ADR-0010)
   - Combat row: "ADR-0001 (partial) / gap ~24 / ADR-X01" → "ADR-0010 (Proposed→Accepted) / gap ~0"
   - Orchestrator row: "ADR-X01 / ADR-X02" → "ADR-X02" (gap dropped to ~4)
   - ADR-0009 cross-ref: "cross-reference to ADR-X01 (pending)" → "ADR-0010 (Accepted 2026-04-22c) re-uses setter verbatim"
   - Required ADRs authoring order: item 1 "ADR-X01" removed (now ADR-0010 Accepted); remaining items renumbered; ADR-C02 now top priority
   - New ADR-0010 cross-ref section added after ADR-0009 section
   - Re-run Log row appended for 2026-04-22c

**Traceability index updated** (`docs/architecture/requirements-traceability.md`): all drift fixes in lockstep. Verdict annotation changed to reflect post-cleanup state.

### Post-cleanup state

- **10 of 10 ADRs Accepted** (0001-0010). ADR-0010 was the sole Proposed ADR; now promoted.
- No internal contradictions in architecture.md.
- No stale TR text (TR-combat-001..032 were never stale — ADR-0010 codifies them as-written).
- No cycles, no unresolved ADR dependencies.
- Coverage: **~62% (~264/425)**. Remaining ~129 gaps are purely Core/Feature-layer and route cleanly to 4 unwritten Required ADRs (C02, X03, C01, X02).

**Next PASS candidate**: after ADR-C02 lands (unblocks 3 Core DB systems ~57 TRs → projected coverage ~85%+). ADR-C02's prerequisite (hero-class-db + enemy-db extends GameData sync) has been COMPLETE since 2026-04-22.

**Still NOT a PASS verdict** because 4 unwritten Required ADRs still block ~129 TRs — this is the expected state after the Core/Feature Phase-1 ADR lands, not a regression. Verdict remains CONCERNS until ADR-C02 lands at minimum.
