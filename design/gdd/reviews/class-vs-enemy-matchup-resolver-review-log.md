# Review Log: Class-vs-Enemy Matchup Resolver

History of `/design-review` invocations on `design/gdd/class-vs-enemy-matchup-resolver.md`.

---

## Review — 2026-04-19 — Verdict: MAJOR REVISION NEEDED (first-pass) → REVISED (same session)

**Scope signal**: L (revision pass) / M (resolver implementation once revised)
**Depth**: full
**Specialists consulted**: game-designer, systems-designer, qa-lead, economy-designer, creative-director (senior synthesis)
**Blocking items**: 5 | **Recommended**: 10 | **Nice-to-have**: 2
**Prior verdict resolved**: N/A (first review)

### Summary

Four specialists ran adversarial review in parallel. Convergence on 3 critical issues: (1) Section B fantasy ("+9,200g came from your Rogue") architecturally unimplementable on current Orchestrator → Economy data flow; (2) boolean OR aggregation + 3 archetypes × 3 classes creates a "decision evaporates after run 1" collapse where W+M+R is trivially dominant; (3) Economy GDD C.2.4 wording is a model conflict (per-run vs per-kill), not a typo, with ~25% gold-projection error risk. Creative-director synthesis: GDD is structurally sound but lacks honesty about what the surrounding pipeline can deliver and what the MVP archetype count can sustain as a decision space. Rejected on first pass; revised same session after user opted to resolve all blockers immediately.

### Blocking items (all resolved in revision)

1. **[creative-director, game-designer, economy-designer]** Section B per-hero attribution fantasy unimplementable. → Section B reframed as **collective formation attribution** ("your formation's matchup advantage banked an extra 4,200g"). "1,847 kills" specific number removed (unsupported by any kill-rate spec). Honest scope statement added.
2. **[game-designer, economy-designer]** Boolean OR + 3-archetype × 3-class collapse. → **Rule 6 changed from boolean OR to majority threshold** (`n > N/2`). Cascaded through Rule 7, Rule 8, D.2, D.3 formulas, E.8, E.9 examples, and 6 ACs. Generalist W+M+R now crosses zero thresholds; specialist W+W+M crosses one. Forces a real specialist-vs-generalist decision per dungeon.
3. **[economy-designer, systems-designer]** Economy C.2.4 + Class DB C.6 model conflict. → Cross-GDD errata applied same session: Economy C.2.4 + `matchup_multiplier` variable description rewritten to per-kill majority language; Class DB C.6 + D.2 note + E.5 rewritten from "at least one counter / caches per run" to "majority threshold / per-kill no-cache".
4. **[qa-lead, systems-designer]** Multiple load-bearing rules with no covering ACs. → New ACs added: H-15 (threshold-fail load-bearing test — generalist crosses zero thresholds), H-16 (static class structure: no instance vars, no signals, no autoload), H-17 (per-kill replay calls neither resolver nor DataRegistry — stubbed canary). H-04 extended with garbage-string + case-sensitivity sub-cases. H-10 extended with null-excluded-from-N contract. H-11 extended with GdUnit4 API verification note + signal-fallback escape hatch. H-13 extended with floor_archetypes mutation sub-case + DataRegistry call-count assertion. H-07 extended with explicit "do NOT assert_eq RefCounted" warning.
5. **[qa-lead, systems-designer]** H-12/H-13 stub-based BLOCKING ACs with no real-system re-validation plan. → **Demoted to ADVISORY**; re-validation ownership reassigned to Orchestrator GDD #13 + Offline Engine GDD #12 (BLOCKING ACs to be added there when authored). Open Question entry added documenting the handoff.

### Recommended items (status)

6. **[qa-lead]** H-14 "CI equivalent of Steam Deck" undefined. → **Resolved**: H-14 split into CI canary (200ms, GitHub Actions ubuntu-latest, BLOCKING within ADVISORY gate) + Steam Deck manual (50ms, milestone gate).
7. **[systems-designer]** Section G.2 wrongly classifies aggregation rule as "not a knob." → **Resolved**: G.2 rewritten to acknowledge alternatives (boolean OR / supermajority / unanimity) and document playtest evidence triggers for re-opening Rule 6.
8. **[systems-designer]** HeroInstance serializability for offline snapshot unverified. → **Resolved**: Rule 14 extended with explicit serializability contract — snapshot stores `MatchupResult` + `Array[String]` of class_ids, NOT live `HeroInstance` references.
9. **[systems-designer]** Frozen-formation invariant load-bearing but unenforceable for `floor_archetypes`. → **Resolved**: Rule 14 extended with explicit "frozen floor_archetypes" invariant; H-13 extended with mutation sub-case.
10. **[qa-lead]** E.11 thread-safety claim ignores Godot 4.6 WorkerThreadPool. → **Open question** entry added (deferred: only re-evaluate if WorkerThreadPool migration is proposed).
11. **[economy-designer]** MATCHUP × DRIP combined ceiling unmodeled. → **Open question** entry added (owner: economy-designer, target: Economy tuning pass).
12. **[economy-designer]** MATCHUP_GOLD_MULTIPLIER recalibration needed under new lower hit-rate. → **Open question** entry added; Economy errata note also flags this calibration risk.
13. **[game-designer]** Floor-composition guarantee for archetype variety not specified anywhere. → **Open question** entry added (target: Biome & Dungeon DB next revision).
14. **[economy-designer]** Per-class gold attribution UI has no data pipeline. → **Resolved by Section B reframe**: collective attribution is what the data flow can deliver; per-class attribution explicitly out of MVP scope.
15. **[game-designer]** Pillar 2 fails when archetype under-represented in single MVP biome. → Folded into floor-composition open question (#13 above).

### Nice-to-have

16. **[qa-lead]** E.5 (duplicate `instance_id`) has no AC. → **Logged, not actioned** (deduplication-absorbs-doubling is implicit in matched_archetypes dedup; low priority).
17. **[economy-designer]** Hero Class DB C.6 caching language errata. → **Resolved** (same edit as blocking item #3).

### Specialist disagreements

- **`MatchupResult` as RefCounted vs Dictionary** — systems-designer wanted Dictionary to avoid allocation pressure on the Matchup Assignment per-slot-change UI path; creative-director sided with the GDD's RefCounted choice for type safety, conditional on H-07's explicit "do NOT assert object equality" warning being added (which it now is). **Resolution**: type safety wins; allocation pressure is measure-then-optimize, not design-time blocker.

### User design decisions

- **Section B fantasy**: collective formation attribution (no per-hero ledger).
- **Aggregation rule**: switch to k-of-n majority threshold (`n > N/2` integer division). For MVP `FORMATION_SIZE = 3` this means `n >= 2`.
- **Cross-GDD errata scope**: edit both sibling GDDs (Economy C.2.4 + Class DB C.6/D.2/E.5) in the same session.
- **H-12/H-13 disposition**: demote to ADVISORY here; real-system re-validation ownership moves to GDDs #12 and #13.

### Files touched

- `design/gdd/class-vs-enemy-matchup-resolver.md` (extensive: Section A overview, Section B fantasy, Rules 6/7/8/14, formulas D.2/D.3, edge cases E.8/E.9, F bidirectional consistency, G.2, ACs H-01/H-04/H-05/H-06/H-07/H-09/H-10/H-11/H-12/H-13/H-14, new ACs H-15/H-16/H-17, classification table, Open Questions section)
- `design/gdd/economy-system.md` (2 edits: C.2.4 wording + `matchup_multiplier` variable description)
- `design/gdd/hero-class-database.md` (3 edits: C.6 caching language, D.2 "at least one" note, E.5 stacking note)
- `design/gdd/systems-index.md` (status: Designed (pending review) → Revised (re-review pending))

### Follow-up actions

- **Re-review planned**: new session via `/clear` → `/design-review design/gdd/class-vs-enemy-matchup-resolver.md` (recommended, since this session used substantial context for the 4-specialist + creative-director synthesis + revision).
- **Cross-GDD downstream**: Orchestrator GDD #13 must add a BLOCKING AC owning the Orchestrator → Economy pipeline integration (formerly H-12 here). Offline Engine GDD #12 must add a BLOCKING AC owning the snapshot pattern + DataRegistry/Resolver call-count check (formerly H-13 here).
- **Cross-GDD downstream**: Enemy DB next revision must add load-time validation that `archetype` strings match the `EnemyArchetypes` constant set (catches typos at the Enemy DB layer; resolver remains silent per Rule 13).
- **Cross-GDD downstream**: Return-to-App Screen GDD #20 must render matchup contribution as a distinctly named **collective** line item ("your formation's matchup advantage banked +Xg"). Per-hero attribution NOT required.
- **Pre-sprint**: qa-lead to verify GdUnit4's `assert_error_logged()` substring API support in Godot 4.6. If unsupported, switch H-11 to test-only `_test_invalid_archetype` signal (Rule 2 exception, document then).
- **Playtest gate**: validate majority threshold against Section G.2 playtest evidence triggers. Recalibrate `MATCHUP_GOLD_MULTIPLIER` against new hit-rate.

### Verdict

**REVISED** — first-pass MAJOR REVISION resolved in same session via 5 BLOCKING + 10 RECOMMENDED items addressed. Awaiting re-review (recommend `/clear` first; this session ran 4 specialists + 1 senior synthesis + extensive revision).

---

## Review — 2026-04-19 (re-review pass) — Verdict: NEEDS REVISION → APPROVED (revisions applied same session)

**Scope signal**: M (resolver implementation; revision delta was textual cross-doc cleanup only)
**Depth**: lean (single-session analysis — prior pass exhausted full-mode value with 4 specialists + creative-director)
**Specialists consulted**: main session only (re-review)
**Blocking items**: 3 | **Recommended**: 6 (deferred — not addressed in this pass) | **Bonus fixes**: 2
**Prior verdict resolved**: Yes — all 5 prior blockers verified as cleanly applied to the Resolver GDD itself; the gap was scope of cascade — Enemy DB and entities.yaml were not updated alongside Class DB and Economy.

### Summary

Re-review verified that the 2026-04-19 majority-threshold revision landed correctly inside the Resolver GDD, Class DB (C.6, D.2, E.5), and Economy (C.2.4, `matchup_multiplier` description). However, the revision pass did not cascade into two additional sibling docs: `enemy-database.md` retained "at least one counter" wording in 3 places (including a worked example that computed the wrong multiplier under the new rule), and `design/registry/entities.yaml` still cited "boolean OR over heroes" in the canonical formula notes. A separate AC count math error (12+5≠17) was found in the Resolver GDD itself. All issues mechanical, no design decisions; user opted to fix all blockers inline.

### Blocking items (all resolved in re-review)

1. **[main session]** Stale "boolean OR over heroes" in `entities.yaml:395` (`is_class_counter` formula notes). → **Resolved**: replaced with majority-threshold language citing Resolver Rule 6 + D.2.
2. **[main session, economy-designer]** `enemy-database.md` carried pre-revision "at least one" wording in lines 322 (also wrong API name `is_enemy_countered_by` vs canonical `is_class_counter`), 368, and 385 (worked example computed `matchup_multiplier = 1.5` for a generalist W+M+R formation — now correctly 1.0 under majority rule). → **Resolved**: lines 322 (canonical name + threshold note), 368 (threshold wording), 371-387 (3 worked examples rewritten under new rule with explanatory note).
3. **[qa-lead, main session]** AC count math error: §H header and Classification Summary both said "12 BLOCKING + 5 ADVISORY" but the table shows 13 BLOCKING + 4 ADVISORY. → **Resolved**: corrected counts in both locations + listed the BLOCKING/ADVISORY membership explicitly.

### Bonus fixes (caught by post-edit verification grep)

- Resolver GDD line 64: stale doc-comment in `MatchupResult` struct (`# true = formation has at least one counter`) → updated to majority-threshold language.
- Enemy DB line 454: leftover `is_enemy_countered_by` reference in E-section bullet → renamed to `is_class_counter`.

### Recommended items (NOT addressed in this re-review pass — deferred)

4. **[systems-designer]** Rule 8 worked-example notation drift (`0/3 < 2` vs the rest of the doc using `n >= 2` style). Cosmetic only. Defer.
5. **[game-designer]** Section B fantasy paragraph asserts "4,200 of 12,400 gold" matchup contribution — implies ~34% of total gold, but under MVP majority threshold + `MATCHUP_GOLD_MULTIPLIER = 1.5` the realistic share is ~17% of kill gold + 0% of drip. Either soften the number or wait for the `MATCHUP_GOLD_MULTIPLIER` recalibration to lock first. Owner: game-designer + economy-designer at Economy tuning pass.
6. **[qa-lead]** H-11 is BLOCKING but depends on an unverified GdUnit4 substring-assertion API. Pre-sprint validation step from §I open question. Either resolve before story-author handoff or demote H-11 to ADVISORY pending verification.
7. **[systems-designer]** Rule 14 declares snapshot schema fields the Offline Engine GDD #12 must own (`MatchupResult`, `class_ids: Array[String]`, `floor_archetypes: Array[String]`) but no Open Question entry surfaces this requirement explicitly. Risk: #12 author has to reverse-engineer the contract. Add to Open Questions next pass.
8. **[systems-designer]** Open Question on `MatchupResult` registry entry (entities.yaml `types:` section) — useful follow-up at next `/consistency-check`.
9. **Status header** updated this pass to `Approved 2026-04-19 (re-review pass)`.

### Files touched

- `design/registry/entities.yaml` (1 edit: `is_class_counter` notes → majority threshold)
- `design/gdd/enemy-database.md` (4 edits: C.5 Matchup Resolver row API name + threshold note; D.1 `matchup_multiplier` definition; D.1 three worked examples + explanatory note; E-section `is_class_counter` rename)
- `design/gdd/class-vs-enemy-matchup-resolver.md` (3 edits: §H header AC count; Classification Summary AC count + BLOCKING/ADVISORY membership; `MatchupResult` struct doc-comment; status header)
- `design/gdd/systems-index.md` (1 edit: status `Revised (re-review pending)` → `Approved 2026-04-19 (re-review pass)`)

### Verdict

**APPROVED** — first-pass MAJOR REVISION + same-day re-review resolved in same week. 17 ACs in place (13 BLOCKING + 4 ADVISORY). Cross-GDD wording verified consistent across Resolver, Class DB, Enemy DB, Economy, and `entities.yaml`. 6 RECOMMENDED items deferred (none design-blocking; all are next-pass polish or playtest-gated). Ready for `/create-architecture` to consume; ready for `/create-stories` once architecture lands.

---

## Pass 5C — DI Conversion (2026-04-20)

**Pass type**: DI-only revision in the Orchestrator Pass 5 arc. Third sub-pass (5A author decisions → 5B upstream reconciliation → 5C production wiring + this conversion).
**Scope**: Convert `MatchupResolver` from static-only utility class to injectable instance class (`class_name MatchupResolver extends RefCounted`) + `DefaultMatchupResolver extends MatchupResolver` concrete impl. Mirror Combat Pass 3D pattern exactly. No changes to the majority-threshold aggregation, the `MatchupResult` struct, or any rule semantics.
**Driver**: Orchestrator independent re-review 2026-04-20 Cluster α item 2 (3-way specialist convergence: systems-designer + qa-lead + godot-gdscript-specialist all flagged that the static-only class blocks Orchestrator AC-ORC-11 mockability).
**Review mode**: solo
**Duration**: ~45 min (GDD edits + AC rewrites + cross-doc citations)
**Blocks closed**: 1 of 17 re-review BLOCKERs (Cluster α item 2 on this GDD). Cluster α item 1 (Node autoload wiring) closed separately by Orchestrator Pass 5C §J Production Wiring.
**Prior Approved status preserved**: This pass is a DI revision only — no rule changes, no acceptance-criterion semantic changes beyond wording. The 2026-04-19 re-review's APPROVED verdict carries forward into Pass 5C.

### What changed

**Rule 1 rewrite** (GDD §C.1):
- Pre-Pass-5C: "The resolver is a static utility class — `class_name MatchupResolver` declared [...]. Every public method is declared `static`. Callers invoke it as `MatchupResolver.resolve_formation_matchup(...)`."
- Post-Pass-5C: "The resolver is an injectable instance class — `class_name MatchupResolver extends RefCounted` declared [...]. Public methods are regular instance methods (NOT `static`). The Orchestrator holds one `matchup_resolver: MatchupResolver` instance injected at construction; tests substitute a subclass that records calls or overrides return values. Production wiring creates one `DefaultMatchupResolver` [...] and passes it to `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)`. Callers invoke it as `matchup_resolver.resolve_formation_matchup(...)` — no static dispatch."
- Added inline `class_name MatchupResolver extends RefCounted` declaration block + `DefaultMatchupResolver` concrete-impl paragraph. Statelessness note refined (Rule 2 + Rule 12 unchanged; "zero state" now means "zero per-run mutation").

**Rule 4 rewrite** (GDD §C.1 "Public API"):
- Signatures `static func resolve_formation_matchup(...)` / `static func resolve_floor_matchup(...)` → `func resolve_formation_matchup(...)` / `func resolve_floor_matchup(...)`.
- Added Pass 5C call-site migration note documenting: Orchestrator C.3/C.4 (both migrated this pass via Orchestrator Pass 5C); Combat `_kill_schedule_for_loop` (Pass 3E bridge item — temporary static-dispatch form remains until Combat Pass 3E lands the `matchup_resolver` parameter on `emit_events_in_range` / `compute_offline_batch`); Matchup Assignment Screen (#23 — will inject when authored).

**H-16 "Static Class Structure" → "Injectable-Class Structure"**:
- Predicate set inverted: pre-Pass-5C required `static func` on all public methods; post-Pass-5C requires the inverse (explicit regression check against static-form reintroduction).
- New predicates added: `extends RefCounted` on base class; `DefaultMatchupResolver` file existence + `extends MatchupResolver`; no autoload entry for either class.
- Pass 5C note appended explaining the predicate inversion is intentional (AC catches drift in whichever direction violates the current contract).

**H-12 + H-13 + H-17 spy language updates**:
- H-12: "Orchestrator calls `MatchupResolver.resolve_formation_matchup(...)`" → "Orchestrator calls `matchup_resolver.resolve_formation_matchup(...)` (instance method on injected field)".
- H-13: "mocked `MatchupResolver`" → "spy subclass of `MatchupResolver` (extend `MatchupResolver` directly; override the two public methods to record and forward)".
- H-17: "mocked `MatchupResolver`" → "spy subclass of `MatchupResolver` injected into the Engine via the usual Pass 5C DI path".

**Dependencies tables** (§C Consumers + §F Dependencies):
- Orchestrator row upgraded to instance-call form + Pass 5C DI note.
- Matchup Assignment Screen row upgraded to instance-call form + "will receive the injected resolver from its host when #23 is authored" note.
- Combat Resolution row extended with Pass 5C bridge explanation (static form remains temporarily; Combat Pass 3E will complete the DI propagation).

**New Cross-System Contracts list** (§F.new):
- Added: `MatchupResolver` injectable instance class; `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)` constructor signature (matches Orchestrator Pass 5C §J Production Wiring).
- The pre-Pass-5C entry "`MatchupResolver.resolve_formation_matchup()` per-kill public API" is replaced (the API exists but via instance dispatch, not static).

**Header Last-Updated** bumped with a Pass 5C summary prepended to the existing 2026-04-19 re-review entry.

### Files modified

- `design/gdd/class-vs-enemy-matchup-resolver.md` — header + §C Rule 1 (major rewrite) + Rule 2 clarification + Rule 4 signatures + Dependencies tables (two rows in different tables) + H-12 + H-13 + H-16 (major rewrite + predicate inversion) + H-17 + New Cross-System Contracts list.
- `design/gdd/reviews/class-vs-enemy-matchup-resolver-review-log.md` — THIS entry.
- (Cross-doc) `design/gdd/dungeon-run-orchestrator.md` — §C.3 code block, §C.4 cache description, §D matchup-advantage row, §F Matchup Resolver dependency row, §H AC-ORC-11 rewrite (two new sub-ACs), Classification Summary, header. Landed under Orchestrator Pass 5C.

### Non-scope of this pass

- Combat GDD #11 `_kill_schedule_for_loop` migration — **Combat Pass 3E** work, not Pass 5C. Combat's internal resolver calls still use the pre-Pass-5C static-dispatch form; this is an explicitly documented temporary bridge. When Combat Pass 3E lands, the bridge goes away and Combat accepts `matchup_resolver: MatchupResolver` as a method parameter (forwarded from the Orchestrator's injected field).
- Matchup Assignment Screen (#23) wiring — undesigned. When #23 is authored, it receives the injected resolver from its host per the usual Pass 5C DI path. Docs reflect this contract.
- No rule semantics changes: Rule 6 (majority threshold), Rule 11 (frozen dispatch snapshot), Rule 12 (pure function), Rule 14 (DataRegistry call-count invariant), H-07 (RefCounted equality), H-15 (threshold-fail load-bearing) — all unchanged.

### Verdict

**APPROVED (carry-forward)** — the 2026-04-19 APPROVED verdict preserves across the Pass 5C DI-only revision. The DI shape now enables Orchestrator AC-ORC-11 to be mocked with a `SpyMatchupResolver`, closing the Cluster α item at both ends (this GDD's side + the Orchestrator's side via §J + AC-ORC-11 rewrite).

### Next step

No new Matchup-Resolver-side work emerges from Pass 5C. The remaining items in the Orchestrator Pass 5 arc (5D AC Triangulation Sweep, 5E gate re-run) do not touch this GDD further. Combat Pass 3E is the next event that would bring additional Matchup-related edits (the bridge retirement + parameter addition on `CombatResolver.emit_events_in_range` / `compute_offline_batch`), but Pass 3E is a Combat GDD concern — Matchup's contract is already stable.
