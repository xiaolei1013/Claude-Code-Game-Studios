# Architecture Review — 2026-04-22b (re-run)

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 9 (8 Accepted: 0001–0008; 1 **Proposed**: 0009) |
| Registry State | populated (425 TR-IDs, v2, last_updated 2026-04-22) |
| Prior Review | `architecture-review-2026-04-22.md` (morning of same day — CONCERNS) |
| Verdict | **CONCERNS** (reduced severity — 2 structural conflicts RESOLVED since prior run) |

---

## What changed since the prior review (2026-04-22 morning)

Three landings in lockstep since the prior review:

1. **ADR-0003 Amendment #2** (Accepted) — autoload ranks 8 + 9 vacated. Resolves CONFLICT-1 (MatchupResolver) + CONFLICT-2 (CombatResolver) from the prior review.
2. **ADR-0003 Amendment #3** (Accepted) — corrects `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)` phrasing to the **lazy-default-with-public-setters** pattern per `dungeon-run-orchestrator.md` §J.1 Option A (locked Pass 5C+). Backed by empirical `autoload.md` Claim 4 [VERIFIED] via Pass-INIT-PROBE 2026-04-22 (fifth engine-claim-falsified-by-probe in the project's history).
3. **ADR-0009** (**Proposed**) — Matchup Resolver DI + majority threshold contract (this is the "ADR-C04 (NEW)" the prior review surfaced; formal ADR number assigned).

Plus out-of-lockstep:
- `design/gdd/hero-class-database.md` + `design/gdd/enemy-database.md` — synced to `extends GameData` per ADR-0006. Prior review's GDD Revision Flags both **CLEARED**.
- `design/gdd/class-vs-enemy-matchup-resolver.md` + `design/gdd/combat-resolution.md` + `design/gdd/dungeon-run-orchestrator.md` — Pass-INIT-PROBE-SYNC notes appended in lockstep with Amendment #3 + ADR-0009.
- `docs/engine-reference/godot/modules/autoload.md` — Claim 4 [VERIFIED] authored.
- `docs/registry/architecture.yaml` — expanded with ADR-0009 interfaces, api_decisions, and the project-wide `autoload_init_with_required_args` forbidden pattern.

---

## Traceability Summary

**Total requirements**: 425 (no new TRs in this review — ADR-0009 codifies existing matchup-resolver GDD rules; no new requirements surfaced).

| Status | Count | % | Δ vs prior |
|---|---|---|---|
| ✅ Covered | ~232 | ~55% | +31 (ADR-0009 covers matchup-resolver ~31 gap pool) |
| ⚠️ Partial | ~32 | ~8% | unchanged |
| ❌ Gap | ~161 | ~38% | −31 |

Per-system coverage (post ADR-0009):

| System (GDD) | TRs | Governing ADRs | Covered | Gap | Gap Routes To |
|---|---|---|---|---|---|
| save-load | 60 | 0003, 0004, 0005, 0007 | ~52 | ~4 | minor UX/debug |
| time | 36 | 0003, 0005 | ~34 | ~1 | — |
| data-loading | 28 | 0003, 0006 | ~27 | ~1 | — |
| scene-manager | 39 | 0003, 0007, 0008 | ~35 | ~2 | OQ-7 |
| hero-class-db | 24 | 0006 (partial) | ~4 | ~18 | ADR-C02 |
| enemy-db | 23 | 0006 (partial) | ~3 | ~18 | ADR-C02 |
| biome-dungeon-db | 28 | 0006 (partial) | ~5 | ~21 | ADR-C02 |
| **matchup-resolver** | **33** | **0009 (Proposed)** | **~31** | **~2** | **promote 0009 to Accepted → full coverage** |
| combat | 32 | 0001 (partial) | ~5 | ~24 | ADR-X01 |
| orchestrator | 32 | 0001, 0002, 0003, 0004, 0005, 0009 | ~20 | ~6 | ADR-X01 / X02 |
| economy | 28 | 0002 | ~6 | ~20 | ADR-C01 |
| hero-roster | 30 | 0003 (partial) | ~2 | ~26 | ADR-X03 |
| floor-unlock | 32 | 0002, 0003 | ~10 | ~18 | direct story (X05 deferred V1.0) |
| **TOTAL** | **425** | — | **~232** | **~161** | — |

---

## Cross-ADR Conflicts

### ✅ Resolved since prior review

- **CONFLICT-1** (MatchupResolver autoload rank vs GDD DI model) — **RESOLVED** by ADR-0003 Amendment #2 (rank 8 vacated) + ADR-0009 (codifies non-autoload RefCounted contract).
- **CONFLICT-2** (CombatResolver autoload rank vs GDD DI model) — **RESOLVED** by ADR-0003 Amendment #2 (rank 9 vacated). Full CombatResolver contract deferred to ADR-X01.

### ⚠️ New (internal drift in `architecture.md` — incomplete Amendment #3 cascade)

These are internal contradictions WITHIN `docs/architecture/architecture.md` — the authoritative §Non-Autoload Pure-Function Modules section (line 148) has been updated correctly, but five secondary locations still carry the pre-Amendment-#3 `_init(args)` phrasing:

| Location | Stale text | Should say |
|---|---|---|
| `architecture.md:144` | "injected into `DungeonRunOrchestrator` via `_init`" | "injected via `DungeonRunOrchestrator.set_matchup_resolver` / `set_combat_resolver` public setters (lazy-default in `_ready()`)" |
| `architecture.md:159` | "rank N may only connect to signals on ranks ≥ N+1 (forward references)" | Contradicts ADR-0003 Amendment #1 — signal SUBSCRIPTION is rank-independent; state READS at `_ready()` are constrained. Replace with Amendment #1 phrasing. |
| `architecture.md:589` (API Boundaries CombatResolver code comment) | "Constructed once at boot; injected into Orchestrator via `_init`" | "Lazily constructed inside Orchestrator._ready() via `.new()` OR pre-injected via `set_combat_resolver(resolver)` before `_ready()` fires" |
| `architecture.md:600` (API Boundaries MatchupResolver code comment) | "Constructed once at boot; injected into Orchestrator via `_init` alongside CombatResolver" | Same pattern as line 589 with `set_matchup_resolver` |
| `architecture.md:694` (§Required ADRs ADR-C04 row) | "Non-autoload `RefCounted` pattern + `Orchestrator._init` injection contract" + row still says "ADR-C04 / Not Started" | Row now represents ADR-0009 (Proposed). Update to: "ADR-0009 — Matchup Resolver DI + majority-threshold contract — **Proposed 2026-04-22** (awaiting Accept promotion)". Decides-column text should say "setter-based DI contract" not "_init injection contract". |

These are low-severity drift (the authoritative §Non-Autoload Pure-Function Modules section + ADR-0003 Amendment #3 + ADR-0009 all agree), but they are real internal contradictions that could confuse implementation-story authors. Recommend a single architecture.md drift-fix pass.

### ⚠️ One stale TR in registry

`docs/architecture/tr-registry.yaml:296` — `TR-matchup-resolver-004` requirement field still says `"Orchestrator constructor: DungeonRunOrchestrator._init(combat_resolver, matchup_resolver: MatchupResolver)"`. The GDD wording this TR represents has been corrected in lockstep with Amendment #3. Needs `revised: "2026-04-22"` bump + updated text: `"Orchestrator injection: lazy-default in _ready() + public setters set_matchup_resolver / set_combat_resolver (zero-arg _init per Claim 4 [VERIFIED])"`. ID unchanged.

### No other conflicts detected

- Save/Load ADR-0004 ↔ ADR-0005 heartbeat path: reconciled.
- ADR-0009 ↔ ADR-0004: `MatchupResult.matched_archetypes` is NOT persisted via Orchestrator's `get_save_data` — lives only in the ephemeral offline-replay snapshot owned by Offline Engine (future ADR-X02). No contract collision.
- ADR-0009 ↔ ADR-X01 (unwritten): ADR-0009 defers full Combat shape to ADR-X01; only provides the Orchestrator's `set_combat_resolver` setter shape as a companion decision.
- ADR-0001 deep-copy contract ↔ Orchestrator TR-004: consistent.

---

## ADR Dependency Graph

Updated from prior review:

```
Level 0 (no dependencies):       ADR-0001, ADR-0002, ADR-0003 (amended x3)
Level 1 (depends on 0003):       ADR-0004, ADR-0006
Level 2 (depends on Level 1):    ADR-0005 (requires 0003 + 0004)
Level 3 (depends on Level 2):    ADR-0007 (requires 0003 + 0004 + 0005 + 0006)
                                 ADR-0009 (requires 0003-Amendment-#3 + 0006) — Proposed
Level 4 (depends on Level 3):    ADR-0008 (requires 0006 + 0007)
```

- **8 of 9 ADRs Accepted.** ADR-0009 is Proposed (awaiting author sign-off / Accept promotion).
- **No cycles.** No unresolved dependencies.
- **ADR-0003 is now triple-amended** (Amendments #1, #2, #3 all on 2026-04-22). All amendments are in-place; the ADR retains its original number.

**Recommended authoring order for remaining Required ADRs** (given ADR-0009 is Proposed, not Accepted):

0. **Promote ADR-0009 to Accepted** (status flip; no content change required).
1. **ADR-X01** — Combat snapshot shape + foreground/offline parity (cites ADR-0009 as companion, reuses `set_combat_resolver` setter pattern per Amendment #3).
2. **ADR-C02** — Resource schemas for HeroClass / Enemy / Biome / Dungeon / Floor `.tres`.
3. **ADR-X03** — Hero Roster mutation + HeroInstance identity.
4. **ADR-C01** — Economy state shape + recruitment cost curve + drip ticker.
5. **ADR-X02** — Offline batch chunking refinement + offline-replay snapshot schema (carries `matched_archetypes` per ADR-0009 §Offline replay zero-call invariant).

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 9 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 9 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] via 2026-04-21 probe (Claim 1) + 2026-04-22 probe (Claim 4) |

### Post-cutoff APIs in use

Unchanged from prior review, plus ADR-0009 adds:

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| Autoload `_init` zero-arg constraint (not a new API — a previously-undocumented constraint) | stable since 4.0 | ADR-0009 + ADR-0003 Amendment #3 (project-wide CI invariant) | LOW (now VERIFIED per Claim 4) | Project-wide grep CI check added to registry as `autoload_init_with_required_args` forbidden pattern |
| `class_name X extends RefCounted` with subclass-override test pattern | stable since 4.0 | ADR-0009 (MatchupResolver + DefaultMatchupResolver) | LOW | Standard GDScript feature; spy-subclass pattern is widely used in GdUnit4 projects |

### Outstanding verifications (pre-MVP-ship)

1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe; AC-DLS-01 covers implicitly.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10).
3. **iOS/Android atomic-rename fallback** (ADR-0004 Risk #4).

No new verifications added by ADR-0009 (Claim 4 already executed and captured).

---

## GDD Revision Flags (Architecture → Design Feedback)

**None.** The prior review's two flags (hero-class-db + enemy-db extending `Resource`) are both **CLEARED** — both GDDs now say `extends GameData` per ADR-0006.

No new GDD revision flags surfaced by this review. The three Pass-INIT-PROBE-SYNC notes on matchup-resolver, combat-resolution, and dungeon-run-orchestrator GDDs are documentation updates authored in lockstep with Amendment #3 + ADR-0009 — they are not review-flagged revisions.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (Draft, last amended 2026-04-22):

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow coverage | ✅ (4 diagrams: frame, offline, persist, hydrate) |
| API boundaries support integration requirements | ✅ — but see drift items #3 and #4 above |
| Orphaned architecture | ⚠️ Same as prior review: HD2D + VFX deferred; Onboarding + SettingsAccessibility deferred. Acceptable for MVP. |
| Internal consistency (post Amendment #3) | ⚠️ 5 drift items (listed in Conflicts section above) |

---

## Verdict: **CONCERNS** (reduced severity)

**Why not PASS**:
1. ADR-0009 is `Proposed`, not `Accepted`. Per `docs/CLAUDE.md`: "Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked."
2. 5 architecture.md drift items + 1 stale TR text (internal contradictions with Amendment #3 + ADR-0009).
3. 5 unwritten Required ADRs still block ~161 TRs (ADR-X01, C02, X03, C01, X02).

**Why not FAIL**:
- All structural conflicts from the prior review (CONFLICT-1, CONFLICT-2, both GDD revision flags) are **RESOLVED**.
- All 8 Accepted ADRs are dependency-ordered, engine-verified, and internally consistent.
- ADR-0009's content is materially correct and fully covers its scope (matchup-resolver DI + aggregation + CI invariants).
- The 161 gaps are all routed to Required ADRs already enumerated in architecture.md §Required ADRs — this is the expected state after Foundation batch landing.

### Blocking Issues (must resolve before PASS verdict)

1. **Promote ADR-0009 to Accepted** — content is ready; status flip only.
2. **architecture.md drift fix pass** — 5 locations (lines 144, 159, 589, 600, 694) carry pre-Amendment-#3 phrasing. Low-impact but real contradiction.
3. **TR-matchup-resolver-004 text bump** — update `requirement` text + add `revised: "2026-04-22"`.

### Non-Blocking Findings

- Open questions unchanged from prior review: OQ-1, OQ-4, OQ-5 (partial), OQ-7, OQ-9, OQ-10. None blocks MVP.
- 5 Required ADRs remain unwritten (X01, C02, X03, C01, X02) — expected; routing is correctly scoped.

---

## Immediate Actions (recommended order)

1. Fix the 3 blocking items above in lockstep (all three fit in a single short edit session):
   - Promote ADR-0009 status: Proposed → Accepted
   - Edit architecture.md lines 144, 159, 589, 600, 694 (Amendment #3 cascade)
   - Edit tr-registry.yaml TR-matchup-resolver-004 (text + revised date)
2. Open a fresh `/architecture-decision` session for **ADR-X01** (Combat snapshot shape + CombatResolver DI companion to ADR-0009).
3. Open a fresh `/architecture-decision` session for **ADR-C02** (Resource schemas for HeroClass / Enemy / Biome / Dungeon).
4. After ADR-X01 + ADR-C02 land, re-run `/architecture-review` to verify coverage rises to ~85%+ and no new conflicts.
5. Author ADR-X03, ADR-C01, ADR-X02 in that order.
6. When all Required ADRs Accepted → `/create-control-manifest` → `/gate-check pre-production` → `/create-epics layer: foundation`.

### Rerun Trigger

Re-run `/architecture-review` after each new ADR lands (or after the 3 blocking items above are cleared).

---

## Files Written This Review

- `docs/architecture/architecture-review-2026-04-22b.md` — this report
- `docs/architecture/requirements-traceability.md` — updated coverage summary + ADR-0009 cross-ref
- `docs/architecture/tr-registry.yaml` — `last_updated` bumped; TR-matchup-resolver-004 flagged in follow-up action (NOT edited in this review per user approval scope — see Immediate Actions item 1)

No GDD edits, no ADR edits, no architecture.md edits performed by this review — those are the 3 blocking items awaiting their own review/approval cycle.

---

## Same-Day Follow-Up: Blocking Items Cleared (2026-04-22b)

After the review report was written, the user authorized the 3 blocking items to be resolved in a single lockstep pass. All three are now complete:

1. ✅ **ADR-0009 status: Proposed → Accepted** (`docs/architecture/ADR-0009-matchup-resolver-di-and-majority-threshold.md`). Status header updated; note added citing the same-day `/architecture-review 2026-04-22b` follow-up as the promotion gate. Content unchanged.

2. ✅ **architecture.md drift fix pass** (`docs/architecture/architecture.md`):
   - Line 144 — "injected via `_init`" → "injected via public setters + lazy-default in `_ready()`" + Amendment #3 cross-reference
   - Line 159 — rank invariant paragraph rephrased per Amendment #1 (signal subscription is rank-independent; state reads at `_ready()` are rank-constrained)
   - Line 589 (API Boundaries CombatResolver code comment) — "Constructed once at boot; injected via `_init`" → full lazy-default + `set_combat_resolver` setter description
   - Line 600 (API Boundaries MatchupResolver code comment) — same pattern as line 589 with `set_matchup_resolver`
   - Line 694 (§Required ADRs ADR-C04 row) — row updated to show "ADR-C04 → **ADR-0009 (Accepted 2026-04-22)**" with setter-based DI phrasing
   - Document Status header — ADRs Referenced field bumped from "ADR-0001, ADR-0002" to "ADR-0001 through ADR-0009 (all Accepted)"; version note appended for Amendment #3 cascade

3. ✅ **TR-matchup-resolver-004 text bump** (`docs/architecture/tr-registry.yaml:300`):
   - Old: `"Orchestrator constructor: DungeonRunOrchestrator._init(combat_resolver, matchup_resolver: MatchupResolver)"`
   - New: `"Orchestrator injection: zero-arg _init + lazy-default construction in _ready() + public setters set_matchup_resolver / set_combat_resolver (autoload _init is called with zero args per autoload.md Claim 4 [VERIFIED]; see ADR-0003 Amendment #3 + ADR-0009)"`
   - `revised: "2026-04-22"` set. ID unchanged per maintenance protocol. Registry header note updated accordingly.

**Traceability index updated** (`docs/architecture/requirements-traceability.md`): §Known Gaps blocking-list replaced with ✅-cleared items; Re-run Log extended with the drift-fix entry noting CONCERNS verdict is now "gap-only" (no structural conflicts, no internal contradictions).

### Post-cleanup state

- All 9 ADRs Accepted.
- No internal contradictions in architecture.md.
- No stale TR text.
- No cycles, no unresolved ADR dependencies.
- Coverage: ~55% (232/425). The remaining ~161 gaps are purely Core/Feature-layer and route cleanly to 5 unwritten Required ADRs (X01, C02, X03, C01, X02).

**Next PASS candidate**: after 2 of the 5 Required ADRs land (X01 + C02 would push coverage to ~85%+).

**Still NOT a PASS verdict** because 5 unwritten Required ADRs still block ~161 TRs — this is the expected state after Foundation batch landing, not a regression. Verdict remains CONCERNS until ADR-X01 and ADR-C02 land at minimum.

