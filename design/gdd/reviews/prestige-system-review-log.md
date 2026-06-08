# Prestige System — Review Log

## Review — 2026-06-08 — Verdict: APPROVED WITH CONDITIONS
Scope signal: L
Specialists: none (`--depth lean` per skill invocation for S28-S2)
Blocking items: 4 | Recommended: 5
Summary: Thorough first-pass GDD with strong cozy-register discipline, 22 testable ACs, and well-grounded pillar alignment. Per-hero retirement model is the correct architecture for this game. Four blocking items require resolution before V1.0 implementation: (1) `remove_hero` sole-caller violation in the prestige action — `HeroRoster.remove_hero` is documented in hero-roster.md Rule 11 as callable by "Save/Load fallback only," but §C.2 calls it directly as step 1 of the prestige flow; (2) `_run_migration_chain` is a phantom method name — the save-load GDD describes the migration mechanism as `migrate_v1_to_v2()` with no `_run_migration_chain` identifier anywhere in its text; (3) false section reference in §E.1 (hero-roster.md §C.5 is the Per-Class Name Pool rule, not a minimum-hero invariant); (4) `prestige_hero(instance_id) -> bool` is specified in §F.1 as the public API but §C.2 describes the action body as calling `remove_hero` directly, creating an API contract ambiguity the implementer cannot resolve without a design decision. Five recommended items are non-blocking but should be addressed before or during implementation. The ratify-vs-pivot question is strongly resolved in favor of the per-hero model.
Prior verdict resolved: First review

---

### Ratify-vs-Pivot Recommendation

**RECOMMENDATION: RATIFY the per-hero retirement model.**

**Analysis of both models against Lantern Guild's four pillars and economic safety:**

#### Per-Hero Retirement (drafted model)
- **Cozy-register fit**: Excellent. Each prestige action is a named, remembered decision about a specific hero the player has invested in. "Theron has earned their retirement" is emotionally coherent with the game-concept.md Player Fantasy of "the wall where you hang every hero you chose to keep." Voluntary, narrative-weighted, no FOMO pressure. Passes the Pillar 1 design test: no timed event, no urgency.
- **Implementability**: Good. All API surface maps to existing HeroRoster patterns (remove_hero shape already exists; multiplier computes cleanly; save schema is additive). Four blocking items are solvable within the V1.0 epic without redesign.
- **Economic safety**: Strong. The ×2.0 hard cap with a voluntary trigger means the game cannot be optimized by speed-running prestige. Players will prestige at natural cap-hit moments, spreading the multiplier gain across months of play. AC-PR-16's tuning invariant (GAIN_PER × MAX == CAP - 1.0) ensures the formula never silently drifts outside design intent.
- **Player-fantasy coherence**: Strong. The Hall of Retired Heroes is a visual record of player decisions — consistent with Pillar 2 (every class feels distinct) and the emotional register of Pillar 4 (art does the emotional heavy lifting).

#### Pure-Global Ascension (competing wireframe model)
- **Cozy-register fit**: Poor. A "reset everything for a global bonus" model is structurally a FOMO mechanism in disguise — players will feel pressure to prestige at the "optimal" moment (maximizing heroes to cap before resetting), which contradicts Pillar 1's "timed event vs always-available content — pick always-available" design test. The game concept explicitly rejects mechanics that create optimization pressure around timing.
- **Implementability**: Comparable. Would also require new HeroRoster API, but losing all hero state on prestige would require much more defensive handling in all downstream systems (formation assignments, dungeon run state, etc.).
- **Economic safety**: Riskier. A full roster reset creates an incentive to rush the first prestige, then optimize subsequent prestige timing — producing the exactly the urgency-adjacent behavior the cozy register forbids.
- **Player-fantasy coherence**: Weak. "Reset everything" is antithetical to the "guild persisting while you're away" player fantasy. Pillar 1's guarantor is "my guild is still here"; a full reset breaks this promise.

**Rationale in two sentences**: The per-hero model fits the cozy register precisely because it makes prestige an individual act of remembered generosity (one hero's retirement) rather than an economic optimization trigger (reset-everything timing); the voluntary, bounded, non-FOMO structure is also mathematically safer against runaway gold inflation than a full-reset model where players could theoretically abuse timing. This is a user-ratified design call — the reviewer recommends RATIFY but the user confirms final direction.

---

### Completeness: 8/8 sections present

All 8 required sections are present and substantive:
- [x] A. Overview — strong one-paragraph summary
- [x] B. Player Fantasy — specific feel-state taxonomy with anti-patterns rejected
- [x] C. Detailed Rules — 6 subsections; comprehensive action flow
- [x] D. Formulas — named expressions, variable tables, output ranges, worked examples (meets mandatory formula format)
- [x] E. Edge Cases — 12 cases with explicit behavior descriptions (no hand-waving)
- [x] F. Dependencies — bidirectional table with F.3 amendment list
- [x] G. Tuning Knobs — safe ranges and gameplay impact documented
- [x] H. Acceptance Criteria — 22 ACs, mostly testable Given-When-Then format

---

### Dependency Graph

| Declared Dependency | GDD File | Exists on Disk |
|---|---|---|
| Hero Roster (#9) | hero-roster.md | Yes |
| Hero Leveling (#15) | hero-leveling.md | Yes |
| DungeonRunOrchestrator (#13) | dungeon-run-orchestrator.md | Yes |
| Economy (#5) | economy-system.md | Yes |
| Save/Load System (#3) | save-load-system.md | Yes |
| Class Synergy System (#32) | class-synergy-system.md | Yes |
| Hero Class Database (#6) | hero-class-database.md | Yes |
| Audio System (#28) | audio-system.md | Yes |
| Scene Manager (#4) | scene-screen-manager.md | Yes |
| Locale Loader (S9-M3) | (autoload, not a GDD) | N/A |
| Onboarding System (#29) | onboarding-first-session.md | Yes |
| Hero Detail Modal (#22) | roster-hero-detail-screen.md | Yes |
| Guild Hall Screen (#19) | guild-hall-screen.md | Yes |

All GDD file dependencies exist on disk. No broken references in the dependency graph.

---

### Required Before Implementation (Blocking)

**BLOCKING-1: `remove_hero` sole-caller contract violation**
Source: `hero-roster.md` §C Rule 11 mutation API table vs `prestige-system.md` §C.2 step 1.

`hero-roster.md` Rule 11 explicitly documents `remove_hero(instance_id)` with "Sole Caller: Save/Load fallback only." The prestige action in §C.2 step 1 calls `HeroRoster.remove_hero(instance_id)` directly from the prestige flow. These are contradictory: either (a) the hero-roster.md must be updated to add Prestige as a permitted caller of `remove_hero`, or (b) the prestige flow must route retirement through the new `prestige_hero(instance_id) -> bool` method declared in §F.1, which internally calls `remove_hero` — keeping `remove_hero` as a roster-internal implementation detail. Option (b) is the cleaner API design and is already implied by the §F.1 method declaration. **§C.2 must be revised to describe the prestige action as invoking `prestige_hero(instance_id)` (the public API declared in §F.1), with the internal steps (remove, append record, increment count, recompute, emit, persist) documented as the body of `prestige_hero`. The Hero Detail Modal calls `prestige_hero`, not `remove_hero` directly.**

File: `prestige-system.md` §C.2 + §F.1 (internal inconsistency to resolve at implementation).

**BLOCKING-2: `_run_migration_chain` phantom method reference**
Source: `prestige-system.md` §C.5 "V1→V2 migration body" description: "per `save-load-system.md` `_run_migration_chain`."

The save-load GDD (Rule 4 + §V1.0 downstream consumers entry 2026-05-09) describes the migration mechanism as a `migrate_v1_to_v2()` function invoked from the migration chain during `MIGRATION` state. The identifier `_run_migration_chain` does not appear anywhere in `save-load-system.md`. The prestige GDD's reference to it is a phantom method name. An implementer following this reference would search for a nonexistent hook point. **§C.5 must correct the reference to the actual save-load migration mechanism: the `_migrate_v1_to_v2(payload_v1: Dictionary) -> Dictionary` function body should be described as what gets added to save_load_system.gd when V1.0 ships, invoked from the versioned migration path described in save-load GDD Rule 4 (version-mismatch → MIGRATION state → run appropriate migration script).**

File: `prestige-system.md` §C.5.

**BLOCKING-3: False section reference for minimum-hero invariant**
Source: `prestige-system.md` §E.1: "HeroRoster's `remove_hero` enforces a 'minimum-1-hero' invariant (per `hero-roster.md` §C.5 — first-launch seed guarantees at least one hero)."

`hero-roster.md` §C.5 is "Per-Class Name Pool" (Rule 5 — per-class name pools in `assets/data/classes/{class_id}/names.tres`). It has no connection to a minimum-hero invariant. The first-launch seed guarantee is in `hero-roster.md` §C.1 Rule 18 (First-Launch Initialization). More importantly, `remove_hero` in the roster GDD does NOT document a minimum-hero guard — the E.11 note says player-initiated removal doesn't exist in MVP. The prestige GDD's §E.1 relies on an invariant that is not documented as enforced by the roster: there is no `remove_hero` guard that prevents removing the last hero. The prestige button visibility logic (`is_prestige_eligible` returning false when roster size == 1) is the correct gate, and it is in the prestige GDD — but the §E.1 prose attributes the invariant to `remove_hero` itself, which is incorrect. **§E.1 must be revised to correctly attribute the protection to `is_prestige_eligible`'s roster-size check (which the prestige GDD itself controls), not to `remove_hero` enforcing an internal invariant. The cross-reference to `hero-roster.md §C.5` must be removed or corrected to `§C.1 Rule 18`.**

File: `prestige-system.md` §E.1.

**BLOCKING-4: `request_full_persist` API name not in save-load GDD vocabulary**
Source: `prestige-system.md` §C.2 step 6: "`SaveLoadSystem.request_full_persist("prestige_completed")`."

The save-load GDD (Rule 5 persist triggers) does not define a `request_full_persist` method. The documented persist trigger vocabulary includes scene-boundary triggers via `request_scene_boundary_persist()` (Rule 5 row 5) and heartbeat/pause/shutdown triggers that fire automatically. There is no `request_full_persist(reason: String)` API in save-load GDD. **Before implementation, the save-load GDD must either (a) define a `request_full_persist(reason: String)` API as a new public trigger entry point, or (b) the prestige GDD must describe the persist as a scheduled heartbeat action with a note that the prestige state will be captured at next heartbeat (with rationale for why this is safe given the synchronous prestige execution).**  The implementer cannot choose between these without a design decision — the prestige GDD's claim of a synchronous immediate persist is functionally important (crash-safety guarantee in §C.2), so option (a) is the more likely intent. This must be resolved before the API surface is coded.

File: `prestige-system.md` §C.2 step 6; `save-load-system.md` must be updated with the new API if option (a) is chosen.

---

### Recommended Revisions

**RECOMMENDED-1: §C.2 prose / §F.1 API table inconsistency — method call clarity**
The action body in §C.2 is written as direct field mutation (`_prestige_count += 1`, `_prestige_multiplier = ...`) but these are private fields. The implementer needs clarity on whether the prestige body is inside the `prestige_hero()` method or is a caller-visible sequence. Recommend §C.2 be reframed as "the body of `prestige_hero(instance_id) -> bool`" to match §F.1's declaration. Minor; advisory once BLOCKING-1 is resolved.

**RECOMMENDED-2: §E.1 last-hero check needs explicit roster-size gate definition**
`is_prestige_eligible` in §D.2 does not include a `_heroes.size() == 1` check. The protection against prestiging the last hero is implied in §E.1 and §H (AC-PR-20) but is absent from the eligibility predicate code in §D.2. Recommend adding an explicit `if _heroes.size() <= 1: return false` branch to the §D.2 eligibility predicate with explanation. This makes the AC-PR-20 assertion traceable to formula code.

**RECOMMENDED-3: §C.3 effect application — `BASE_XP_PER_KILL` formula mismatch with hero-leveling GDD**
The prestige GDD §C.3 quotes `attribute_kill_xp` as `floori(BASE_XP_PER_KILL × tier × synergy_multiplier × prestige_multiplier)`. The hero-leveling GDD §C.1 defines per-kill XP as `XP_PER_KILL[tier]` (a lookup table, not `BASE_XP_PER_KILL × tier`). These are different formula shapes. `hero-leveling.md` tier-1 = 5, tier-2 = 10, tier-3 = 20, tier-4 = 40, tier-5 = 80 — which is approximately `5 × 2^(tier-1)`, not perfectly linear. If `BASE_XP_PER_KILL` is defined as the tier-1 base (5), the multiply-by-tier gives 5, 10, 15, 20, 25 — not matching the actual values 5, 10, 20, 40, 80. This is a formula inconsistency with the implemented XP system. Recommend cross-checking with dungeon-run-orchestrator.md §D.1 for the authoritative `attribute_kill_xp` signature and aligning §C.3 to match.

**RECOMMENDED-4: §C.4 — hover interactions**
The §C.4 Hall UI description mentions "Hovering a portrait shows the hero's stats at retirement." Per `technical-preferences.md`, hover-only interactions are forbidden (no hover-only interactions; all interactions must work with a single finger tap). This is the same class-synergy GDD mobile-parity issue resolved in the 2026-05-10 review (Blocking item 2 at that time). Recommend §C.4 be revised to "tapping a portrait" per the tap-to-reveal pattern established in the class-synergy precedent.

**RECOMMENDED-5: §G tuning knob `prestige_confirmation_modal_minimum_dwell_seconds` location**
This UX/interaction knob (dwell time before the Prestige button becomes tappable) feels out of place in `economy_config.tres` alongside economic constants. The class-synergy review log noted a similar cross-domain coupling for `class_synergy_badge_glow_duration_seconds`. Recommend either: (a) move the dwell knob to a UI config resource, or (b) add a note that it will be relocated in V1.0 when the UX configuration strategy is resolved. Non-blocking; advisory.

---

### Specialist Disagreements
None (lean-mode review; no specialist agents spawned).

---

### Cross-GDD Consistency Findings

**Consistent:**
- `LEVEL_CAP = 15` — matches hero-leveling.md §C.5 and hero-roster.md Rule 19. Correctly referenced.
- `get_prestige_multiplier()` return type `float` — consistent with usage in `attribute_kill_gold` / `attribute_kill_xp` formulas in dungeon-run-orchestrator.md shape (5-factor product).
- Economy GDD `economy_config.tres` as the config location — consistent with economy-system.md §G and GDD §G.
- `hero-roster.md` F section — prestige is listed as a downstream dependent with the full new API surface (confirmed in hero-roster.md §F "Downstream Dependents" row for Prestige #31, added 2026-05-09). Bidirectional reference exists.
- `hero-leveling.md` F section — Prestige #31 is listed as a reverse dependency with correct LEVEL_CAP consumption semantics. Bidirectional reference exists.
- `economy-system.md` F section — Prestige #31 is listed with the 5 new economy_config.tres constants. Bidirectional reference exists.
- `save-load-system.md` V1.0 downstream consumers section (line 654) — Prestige #31 version bump and migration body are documented. Bidirectional reference exists.
- `PRESTIGE_GAIN_PER × PRESTIGE_MAX == PRESTIGE_MULTIPLIER_CAP - 1.0` invariant: 0.05 × 20 = 1.0 == 2.0 - 1.0. Confirmed algebraically. AC-PR-16 correctly encodes this.

**Inconsistent (blocking):**
- `remove_hero` sole-caller rule violated — see BLOCKING-1.
- `_run_migration_chain` phantom method name — see BLOCKING-2.
- `hero-roster.md §C.5` false cross-reference — see BLOCKING-3.
- `request_full_persist` undefined API — see BLOCKING-4.

**Inconsistent (recommended):**
- `attribute_kill_xp` formula shape vs hero-leveling.md XP table — see RECOMMENDED-3.
- Hover interaction in §C.4 violates technical-preferences.md — see RECOMMENDED-4.

---

### Economic Safety Analysis

The 5-factor multiplicative product (BASE × matchup × loot × synergy × prestige) is correctly bounded:
- Theoretical max: 1.5 × 1.0 × 1.5 × 2.0 = 4.5× baseline
- This is a late-game, fully-optimized peak — requires PRESTIGE_MAX prestiges + active matchup advantage + synergy active simultaneously
- The voluntary trigger and PRESTIGE_MULTIPLIER_CAP = 2.0 hard ceiling prevent runaway: even an infinitely patient player cannot exceed 2.0× from prestige alone
- The AC-PR-15 simulation AC (100-kill test) and AC-PR-16 tuning invariant together provide adequate economic safety gates

The 5% per-prestige gain resolves to +3 gold on a tier-3 bruiser kill at matchup advantage (worked example §D.4: 78 vs 75). This is measurably small per-kill but compounds across hundreds of kills per session. The §I OQ-31-11 concern ("5% feels small") is a legitimate first-playtest risk but is a marketing/framing problem, not a balance problem. The GDD handles this correctly by deferring the "feels small" question to playtest evidence.

---

### Scope Signal

Rough scope signal: **L** (producer should verify before sprint planning)

Rationale: 3 new public HeroRoster methods + 3 private fields + 1 signal + V2 save migration + formula insertion into 2 existing formulas (kill-gold + kill-xp) + new UI surface (Retired tab on existing Guild Hall screen) + 8 new locale keys + 2 new audio cues. Touches 10 existing GDDs requiring bidirectional amendment (§F.3 deferred amendment list). While individual pieces are small, the cross-cutting nature (HeroRoster, Economy config, SaveLoad migration, DungeonRunOrchestrator formula, AudioRouter, GuildHallScreen, HeroDetailModal) puts this firmly in L scope. The §F.3 bidirectional amendment pass adds non-trivial coordination overhead.

---

### Verdict: APPROVED WITH CONDITIONS

The prestige GDD is a well-structured, cozy-register-consistent design with strong formula documentation and comprehensive acceptance criteria. The per-hero retirement model is the correct architecture for this game — it honors Pillar 1, delivers genuine narrative weight, and is economically safe within the existing kill-gold + kill-xp formula chain.

Four blocking items must be resolved before V1.0 implementation begins. None require redesign — all are API contract clarifications or reference corrections that can be resolved in a single focused amendment pass. The recommended items (particularly RECOMMENDED-3 on XP formula consistency and RECOMMENDED-4 on the hover interaction) should be folded into that same amendment pass.

The §F.3 bidirectional amendment list (10 GDDs) was correctly identified and explicitly deferred to the V1.0 implementation epic. This deferral is acceptable as long as the amendments are bundled into the implementation epic's opening sprint, not treated as optional cleanup. The prior class-synergy review log found the same deferral appropriate, but the class-synergy re-review (2026-05-14) had to reclassify this as BLOCKING when implementation began. Recommend flagging this deferral as a sprint-opening gate for the prestige implementation epic.

**Condition for APPROVED transition**: Resolve all 4 blocking items (in-GDD amendments + save-load API definition) before the V1.0 Prestige implementation epic's first story is written.
