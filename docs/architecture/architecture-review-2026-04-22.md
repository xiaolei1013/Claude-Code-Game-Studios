# Architecture Review — 2026-04-22

| Field | Value |
|---|---|
| Mode | `/architecture-review full` (auto-mode, solo review) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| GDDs Reviewed | 13 system GDDs |
| ADRs Reviewed | 8 (all Accepted) |
| Registry State Before | `tr-registry.yaml` empty (`requirements: []`) |
| Registry State After | 425 TR-IDs assigned (first population) |
| Verdict | **CONCERNS** |

---

## Traceability Summary

**Total requirements extracted**: 425

| Status | Count | % |
|---|---|---|
| ✅ Covered | ~201 | 47% |
| ⚠️ Partial | ~32 | 8% |
| ❌ Gap | ~192 | 45% |

Per-system coverage:

| System (GDD) | TRs | Existing ADR Coverage | Covered | Partial | Gap | Gap Routes To |
|---|---|---|---|---|---|---|
| save-load | 60 | ADR-0003, 0004, 0005, 0007 | ~52 | ~4 | ~4 | minor UX/debug items |
| time | 36 | ADR-0003, 0005 | ~34 | ~1 | ~1 | — |
| data-loading | 28 | ADR-0003, 0006 | ~27 | 0 | ~1 | — |
| scene-manager | 39 | ADR-0003, 0007, 0008 | ~35 | ~2 | ~2 | OQ-7 (Settings GDD) |
| hero-class-db | 24 | ADR-0006 (partial — file format only) | ~4 | ~2 | ~18 | ADR-C02 |
| enemy-db | 23 | ADR-0006 (partial) | ~3 | ~2 | ~18 | ADR-C02 |
| biome-dungeon-db | 28 | ADR-0006 (partial) | ~5 | ~2 | ~21 | ADR-C02 |
| matchup-resolver | 33 | — | 0 | ~2 | ~31 | **ADR-C04 (NEW)** |
| combat | 32 | ADR-0001 (partial) | ~5 | ~3 | ~24 | ADR-X01 |
| orchestrator | 32 | ADR-0001, 0002, 0003, 0004, 0005 | ~18 | ~6 | ~8 | ADR-X01 / X02 |
| economy | 28 | ADR-0002 | ~6 | ~2 | ~20 | ADR-C01 |
| hero-roster | 30 | ADR-0003 (partial) | ~2 | ~2 | ~26 | ADR-X03 |
| floor-unlock | 32 | ADR-0002, 0003 | ~10 | ~4 | ~18 | direct story (X05 deferred V1.0) |
| **TOTAL** | **425** | — | **~201** | **~32** | **~192** | — |

> Gap counts are rough aggregate estimates over the 425 TRs. Full per-TR status is carried in `tr-registry.yaml` and the traceability index. Gap routing (the rightmost column) maps each system's gap pool to the Required ADR architecture.md already enumerates — confirming the architecture.md §Required ADRs plan is correctly scoped.

---

## Coverage Gaps — Routes to Required ADRs

No surprising gaps. Every gap group maps to a Required ADR already listed in `architecture.md` §Required ADRs. The review confirms the plan is correctly scoped:

| Required ADR | Status | Covers Gaps In | Est. Count |
|---|---|---|---|
| **Amend ADR-0003** | **BLOCKING** (see CONFLICT-1/2 below) | architecture.md rank table, ClassEnemyMatchupResolver + CombatResolution | structural |
| **ADR-C01** | Not Started | economy | ~20 |
| **ADR-C02** | Not Started | hero-class-db + enemy-db + biome-dungeon-db | ~57 |
| **ADR-C03** | Not Started (no GDD yet) | audio | N/A |
| **ADR-C04 (NEW)** | Not Started | matchup-resolver | ~31 |
| **ADR-X01** | Not Started | combat + orchestrator (parity, snapshot shapes) | ~27 |
| **ADR-X02** | Not Started | orchestrator + economy (offline chunking refinement over ADR-0005) | ~5 |
| **ADR-X03** | Not Started | hero-roster | ~26 |
| **ADR-X04** | Not Started (no GDD yet) | recruitment | N/A |
| **ADR-X05** | Deferred V1.0 | floor-unlock designer-UI (OQ-1) | ~3 |

**New ADR identified by this review**: ADR-C04 (Matchup Resolver). The `class-vs-enemy-matchup-resolver.md` GDD specifies a stateless DI-injected pattern that does not fit existing ADR coverage and is not in architecture.md §Required ADRs. Add to architecture.md §Required ADRs §Core Layer.

---

## Cross-ADR Conflicts

### 🔴 CONFLICT-1: MatchupResolver autoload rank vs GDD DI model

| Side | Claim |
|---|---|
| ADR-0003 + architecture.md §Autoload Rank Table | Rank 8 `ClassEnemyMatchupResolver` is an autoload. |
| matchup-resolver GDD §Architecture + TR-matchup-resolver-001/002/003/004/030 | `class_name MatchupResolver extends RefCounted`; explicitly **NOT autoload**; injected via `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)`; CI check enforces "no autoload entry". |

**Impact**: If implementation follows ADR-0003, the GDD's spy-subclass-for-testing DI pattern and stateless-instance invariant break. If implementation follows the GDD, rank 8 in ADR-0003 is vacant.

**Resolution options**:
1. **(Recommended)** Amend ADR-0003 + architecture.md: remove rank 8 from the autoload table; relabel as "Pure-function module (non-autoload, DI-injected into Orchestrator)". The GDDs are newer and more specific.
2. Supersede the matchup-resolver GDD: require autoload pattern. Breaks spy-injection testing.

### 🔴 CONFLICT-2: CombatResolution autoload rank vs GDD DI model

Parallel to CONFLICT-1.

| Side | Claim |
|---|---|
| ADR-0003 + architecture.md | Rank 9 `CombatResolution` is an autoload (stateless). |
| combat-resolution GDD + TR-combat-001/004 | `class_name CombatResolver extends RefCounted`; `DefaultCombatResolver` injected via DI; spy subclasses override for tests. |

**Resolution**: same as CONFLICT-1 — amend ADR-0003 + architecture.md in lockstep to remove rank 9.

**Consequence of fix (both conflicts)**: the rank table shrinks from 16 to 14 ranks; ranks 8 and 9 vacate. Rank re-numbering of downstream autoloads (10-15) is NOT required — leaving gaps (ranks 8 and 9) empty is preferable to a full renumber per ADR-0003 §Editing Protocol (reordering requires a superseding ADR + code-review pass + save schema bump; a rank slot simply being unoccupied is not a reorder).

### No other conflicts detected

- Save/Load ADR-0004 (full envelope) vs ADR-0005 (heartbeat partial envelope) — **reconciled explicitly**; ADR-0005 "refines ADR-0004's full-payload contract with a partial-envelope path."
- ADR-0003 rank invariant phrasing was amended same-day (2026-04-22) to match Claim 1 [VERIFIED]. No residual conflict.
- ADR-0001 deep-copy contract vs Orchestrator TR-004 formation deep copy — consistent.
- ADR-0002 monotonic ledger vs Economy TR-011/012/024 — consistent.
- ADR-0007 SceneManager rank unspecified (OQ-8) — documented open question, not a conflict.

---

## ADR Dependency Graph

Topological sort from each ADR's `Depends On` field:

```
Level 0 (no dependencies):       ADR-0001, ADR-0002, ADR-0003
Level 1 (depends on 0003):       ADR-0004, ADR-0006
Level 2 (depends on Level 1):    ADR-0005 (requires 0003 + 0004)
Level 3 (depends on Level 2):    ADR-0007 (requires 0003 + 0004 + 0005 + 0006)
Level 4 (depends on Level 3):    ADR-0008 (requires 0006 + 0007)
```

**All 8 ADRs are Accepted.** No cycles detected. No unresolved dependencies (no ADR depends on a Proposed or missing ADR).

**Recommended Required-ADR authoring order** (given CONFLICT-1/2 must resolve first):

1. **Amend ADR-0003** — structural precondition for ADR-C04 and ADR-X01
2. ADR-C04 (Matchup Resolver) — unblocks ADR-X01 (Combat snapshot references MatchupResolver contract)
3. ADR-X01 (Combat snapshot shape + parity)
4. ADR-C02 (Resource schemas for hero-class / enemy / biome / dungeon)
5. ADR-X03 (Hero Roster mutation + identity)
6. ADR-C01 (Economy state shape + recruitment cost curve)
7. ADR-X02 (Offline chunking refinement — likely a small ADR layering over ADR-0005)

---

## Engine Compatibility Audit

### Summary

| Check | Result |
|---|---|
| Version consistency | ✅ All 8 ADRs declare Godot 4.6 |
| Engine Compatibility sections present | ✅ All 8 ADRs |
| Post-cutoff APIs catalogued | ✅ |
| Deprecated APIs referenced | ✅ None |
| Autoload init semantics | ✅ [VERIFIED] 2026-04-21 probe (Claim 1) |

### Post-cutoff APIs in use

| API | Version | Used By | Risk | Mitigation |
|---|---|---|---|---|
| `FileAccess.store_*` → `bool` | 4.4 | ADR-0004 | NEAR-CUTOFF | Asserted truthy per coding standard |
| `@abstract` keyword | 4.5 | ADR-0006 (`GameData` base) | MEDIUM | **One-time probe required** (Resource-derived `@abstract` behavior undocumented) |
| 4.6 dual-focus UI | 4.6 | ADR-0008 | MEDIUM | **SIDESTEPPED** — FOCUS_NONE default; V1.0 Accessibility ADR revisits |
| 4.5 Recursive Control disable | 4.5 | ADR-0008 | LOW | Per Step 4.5 Note 3: IGNORE cascades, STOP does not — implementation distinguishes |
| 4.5 FoldableContainer | 4.5 | ADR-0008 (Settings) | LOW | — |

### Outstanding Verifications (pre-MVP-ship)

1. **`@abstract` on Resource-derived base** (ADR-0006) — one-time probe in scratch project; AC-DLS-01 covers implicitly.
2. **Steam Deck 1280×800 hardware test** (ADR-0008 OQ-5 + OQ-10).
3. **iOS/Android atomic-rename fallback** (`.commit` marker pattern, ADR-0004 Risk #4).

### godot-specialist Consultation

Per-ADR `godot-specialist Step 4.5` reviews were already folded into ADR-0003 through ADR-0008 during the 2026-04-22 Foundation-batch authoring session (see session-state). No additional consultation launched — cross-ADR interactions verified by this review pass did not surface new findings that contradicted the per-ADR specialist sign-offs.

---

## GDD Revision Flags (Architecture → Design Feedback)

| GDD | Assumption | Reality (from ADR / engine reference) | Action |
|---|---|---|---|
| `design/gdd/hero-class-database.md` | TR-001: `class_name HeroClass extends Resource` | ADR-0006 mandates `@abstract GameData` base (4.5+) | Revise §Architecture to use GameData base |
| `design/gdd/enemy-database.md` | TR-001: `class_name EnemyData extends Resource` | ADR-0006 mandates `@abstract GameData` base | Revise §Architecture to use GameData base |

> `design/gdd/biome-dungeon-database.md` already adopts GameData — the hero-class-db and enemy-db GDDs were missed in the Pass-DataLoader-propagation cascade (session state indicates 5 occurrences renamed; these two GDDs' class-declaration lines appear to have been skipped).

### Proposed systems-index status field updates

- Hero Class Database #10 → **Needs Revision** (Note: adopt `extends GameData` per ADR-0006)
- Enemy Database #11 → **Needs Revision** (Note: adopt `extends GameData` per ADR-0006)

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v0.1 Draft, 2026-04-22) was reviewed against `systems-index.md`:

| Check | Result |
|---|---|
| Every GDD-listed system appears in §Module Ownership Map | ✅ |
| Data flow section covers all cross-system signals | ✅ (4 flow diagrams cover frame, offline, persist, hydrate) |
| API boundaries support integration requirements | ✅ (public contracts for 7 autoloads + 6 consumers) |
| Orphaned architecture (modules without GDDs) | ⚠️ `HD2DRenderingPipeline` + `VFXSystem` are deferred (Vertical Slice); `Onboarding` + `SettingsAccessibility` are deferred (Polish). Acceptable for MVP scope. |

**Architecture.md drift findings** (fold into next architecture.md edit):

1. Rank table must reflect CONFLICT-1/2 resolution: remove ranks 8, 9 from the ranked autoload enumeration; add a §Non-Autoload Pure-Function Modules section listing MatchupResolver + CombatResolution with DI contract.
2. §Required ADRs §Core Layer: add ADR-C04 (Matchup Resolver DI + threshold contract).

---

## Known Conflict-Prone Areas (from `docs/consistency-failures.md`)

File does not exist. No prior consistency failures logged. This review's CONFLICT-1/2 entries are the first candidates for the reflexion log — recommend creating `docs/consistency-failures.md` as part of the next governance pass (out of scope for this review per skill: "Do not create the file if missing — only append when it already exists").

---

## Verdict: **CONCERNS**

**Why not PASS**: Two binding cross-artifact conflicts (CONFLICT-1, CONFLICT-2) and two GDD sync gaps must be resolved before the Core/Feature layer story authoring can start on the affected systems.

**Why not FAIL**: All 6 Foundation ADRs Accepted, dependency-ordered, engine-verified. The 192 gaps are all in Core/Feature and map cleanly to Required ADRs architecture.md already enumerates — this is the expected state immediately after Foundation batch landing.

### Blocking Issues (must resolve before PASS)

1. **Amend ADR-0003 + architecture.md** to resolve CONFLICT-1 (MatchupResolver non-autoload) + CONFLICT-2 (CombatResolution non-autoload).
2. **Sync hero-class-database.md + enemy-database.md** to use `extends GameData` per ADR-0006.
3. **Author ADR-C04** (Matchup Resolver DI + majority threshold contract) — new Required ADR surfaced by this review.

### Non-Blocking Findings

- 5 open questions remain (OQ-1 Floor Unlock V1.0; OQ-4 Offline replay UX; OQ-7 reduce_motion persistence; OQ-9 V1.0 keyboard/gamepad nav; OQ-10 Steam Deck per-platform tap-target). All tracked; none block MVP story authoring.
- `@abstract GameData` Resource-derived probe outstanding (one-time pre-MVP-ship verification).

---

## Immediate Actions

1. Resolve CONFLICT-1 + CONFLICT-2 by amending ADR-0003 (in a fresh session, via `/architecture-decision` amendment flow or direct edit with user approval). Same session updates architecture.md rank table + adds ADR-C04 to §Required ADRs.
2. Propagate `extends GameData` to hero-class-database.md and enemy-database.md (data-loading Pass-6 cleanup).
3. After amendment lands: run `/architecture-decision` in a fresh session for ADR-C04, ADR-X01, ADR-C02 in that order.
4. After ADR-C02 lands: re-run `/architecture-review single-gdd design/gdd/hero-class-database.md` (and the other two databases) to confirm coverage rises to ≥95%.
5. When all ADRs needed for MVP Core+Feature are Accepted: run `/gate-check pre-production` to validate implementation-ready state.

### Rerun Trigger

Re-run `/architecture-review` after each new ADR is written to verify coverage improves and no new conflicts are introduced.

---

## Files Written This Session

- `docs/architecture/architecture-review-2026-04-22.md` — this report
- `docs/architecture/requirements-traceability.md` — traceability index (425 TR-IDs, per-system, cross-referenced to ADRs)
- `docs/architecture/tr-registry.yaml` — populated from empty to 425 entries; all `status: active`, all `created: 2026-04-22`

No GDD edits, no ADR edits, no architecture.md edits performed by this review — those are follow-up actions requiring their own review/approval cycles per the collaborative protocol.
