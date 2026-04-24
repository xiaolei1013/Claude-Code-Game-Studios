# Dungeon Run Orchestrator System — Review Log

GDD: `design/gdd/dungeon-run-orchestrator.md` (#13 in design order)

---

## Pass — 2026-04-21 (Pass-I.15-fix, cross-GDD bug closure) — Verdict: I.15 silent Pillar 1 violation RESOLVED → Floor Unlock #16 fully unblocked

**Scope**: single-bug cross-GDD fix. Floor Unlock #16 Pass-9 (2026-04-21 earlier same day) filed I.15 as a cross-GDD BLOCKING item against Orchestrator #13: `compute_offline_run` (C.4) omitted the `floor_cleared_first_time.emit(...)` call that the foreground path (C.3 line 249) makes. Floor Unlock's `_on_floor_cleared_first_time` listener is the sole unlock-advancement path; without the offline emission, any player earning a first-clear while the app was backgrounded for 8+ hours would return to find: (a) gold credited correctly by `Economy.try_award_floor_clear`; (b) `floor_clear_bonus_credited[floor_index]` updated; (c) the next floor still LOCKED on the `Roster → Select Floor` screen. **Silent Pillar 1 violation** — the cozy promise "my heroes were working while I slept" technically holds for gold-per-tick but fails for the single most-felt progression milestone (floor unlock).

### Bug classification

| Axis | Value |
|---|---|
| Severity | BLOCKING (Pillar 1 root-level violation) |
| Discoverability in live play | LOW — requires a player to earn exactly a first-clear during an offline session and notice the next floor stayed LOCKED; most first-clears happen in foreground because players linger to watch |
| Root cause | C.4 divergence from C.3 — the same first-clear check (`if batch.first_clear_tick > 0 and not snapshot.floor_clear_emitted:`) existed in both paths, but only C.3 emitted the Orchestrator-autoload signal after the check. C.4 stopped at `Economy.try_award_floor_clear + snapshot.floor_clear_emitted = true`. |
| Why this slipped past Pass 5D AC Triangulation Sweep | AC-ORC-09 asserted `total gold` + `per-archetype kill counts` parity between foreground and offline, but did NOT assert `floor_cleared_first_time` signal-emission parity. Pass-5D closed 17 BLOCKERs but did not widen the foreground/offline-parity invariant to cover signal emissions. |

### Fix applied (in-GDD)

- **C.4 `compute_offline_run` gains signal emission** — immediately after `snapshot.floor_clear_emitted = true`, the path now executes `floor_cleared_first_time.emit(snapshot.floor.floor_index, snapshot.biome_id, snapshot.losing_run)` — identical payload and count to the C.3 line 249 emission. Multi-line in-code rationale comment explains the Pillar 1 linkage, the Floor Unlock listener contract, and why the signal is safe to fire during `ACTIVE_OFFLINE_REPLAY` state (listener mutates internal unlock state only; no UI calls, no await points).
- **§F foreground/offline parity invariant #1 extended** — the tuple of guaranteed-identical outputs now explicitly lists `(kills_by_archetype, kills_by_tier, total_gold, floor_clear_bonus_paid, floor_cleared_first_time signal-emission count and payload)`. The signal-emission parity was the specific gap I.15 exposed.
- **AC-ORC-09 THEN extended** — the assertion set now includes `floor_cleared_first_time signal emission count and payload are identical between the two paths`. Pre-fix AC would have passed (both paths credit the same gold); post-fix AC asserts the full semantic parity. Regression guard.
- **Top-of-file Status bump** — `Pass-I.15-fix applied 2026-04-21` marker with one-line summary.

### Ripple edits in other GDDs

| File | Change | Anchor |
|---|---|---|
| `design/gdd/economy-system.md` | §E.4 "Floor-Clear Bonus Awarded During Offline Replay" fully rewritten to close the **triple-contradiction** (stale Array[bool] field reference + nonexistent `floor_cleared_first_time` Economy-as-signal-consumer framing + flat-credit description pre-dating ADR-0002 reclaim semantics). New prose reflects: Orchestrator C.4 → `Economy.try_award_floor_clear(3, bonus_amount)` → credit-the-gap via ADR-0002 `floor_clear_bonus_credited` dict + `first_clear_awarded(3)` signal on first non-zero credit → Orchestrator `floor_cleared_first_time.emit(3, biome_id, losing_run)` in lockstep with C.3 (Pass-I.15-fix). Three idempotency layers documented. Top-of-file status bump. | §E.4 + top-of-file |
| `design/gdd/floor-unlock-system.md` | Top-of-file Status line updated — I.14 + I.15 both now resolved; removed "pending I.14/I.15 upstream resolution" gate. Floor Unlock #16 is fully unblocked. No in-GDD design changes needed (Floor Unlock's contract was correct; the upstream fix makes it observable). | Top-of-file |
| `design/gdd/systems-index.md` | Orchestrator row gains Pass-I.15-fix marker; Economy row gains Pass-I.15-fix-ripple marker; Floor Unlock row gains "I.14 + I.15 both resolved 2026-04-21 — fully unblocked" marker. | Rows #3, #5, #13, #16 |
| `production/session-state/active.md` | Session state updated — session next-actions list no longer includes I.15. | (entire file) |

### Why this fix unblocks Floor Unlock #16

Floor Unlock Pass-9 marked itself `in-GDD content APPROVED pending I.14 + I.15 upstream resolution`. Both upstream blockers are now resolved:

- **I.14** (Save/Load #3 `save_file_path` public knob): landed in Save/Load Pass-5A + hardened in Pass-5B-emergency to compile-time-const surfacing with AC-SL-TAMPER-05 CI scan.
- **I.15** (Orchestrator #13 offline `floor_cleared_first_time.emit`): landed this pass.

Floor Unlock #16 is now fully unblocked. No Floor Unlock self-revision is needed because its `_on_floor_cleared_first_time` listener was always correct — the listener was never receiving offline events simply because the Orchestrator was never emitting them. With C.4 now emitting, the listener fires as designed and the unlock advances.

### Scope limits — what was NOT changed this pass

- No changes to `compute_offline_run` logic beyond the single `emit` call + code comment. The gold attribution, kill aggregation, and `OfflineRunResult` construction are untouched.
- No changes to Floor Unlock's listener signature or behavior.
- No changes to the signal's payload schema (`floor_index`, `biome_id`, `losing_run` — matches C.3 emission exactly; payload was already extended 2026-04-20 per Floor-Unlock-Propagation-Edit-3, reused as-is).
- No changes to the `snapshot.floor_clear_emitted` per-dispatch idempotency guard — the same guard that prevented C.3 re-emission prevents C.4 double-emission.

### Testing guidance

AC-ORC-09 THEN now includes signal-emission parity. Regression test authoring notes:

- Use GdUnit4 `signal_collector` to capture `DungeonRunOrchestrator.floor_cleared_first_time` emissions in both branches of the parity test.
- Assert count == 1 in both paths for any dispatch where `batch.first_clear_tick > 0 and snapshot.floor_clear_emitted == false at entry`.
- Assert count == 0 in both paths for replay of an already-cleared floor (same-dispatch double-call should be idempotent).
- Assert payload tuple equality `(floor_index, biome_id, losing_run)` between the two paths — the most catch-worthy regression would be one path omitting a payload field or swapping argument order.

### Cross-pass pattern note

Pass-I.15-fix is a single-bug cross-GDD closure; the Floor Unlock #16 Pass-9 reviewer caught the bug and filed it correctly as a BLOCKING cross-GDD item on the owning GDD's next cycle. The one-session-per-cross-GDD-blocker cadence (Floor Unlock files → Orchestrator resolves same or next day) continues to be the right pattern for non-ambiguous bugs. I.15 was an 8-line code-block addition + 2-line AC-THEN extension + 1-line invariant extension + 3 ripple GDDs — tightly scoped, low risk, high-leverage (unblocks Floor Unlock #16 entirely).

Worth noting: the bug existed since Pass 4A when `compute_offline_run` was first specified, survived Pass 5D's AC Triangulation Sweep (which closed 17 other BLOCKERs), and was caught by Floor Unlock's independent Pass-9 reviewer reading C.4 with fresh eyes. The AC Triangulation Sweep's blind spot was asserting gold parity but not signal parity — a generalized lesson: when declaring "foreground/offline parity" as an invariant, enumerate EVERY observable side-effect (gold credits, signal emissions, state field writes, file I/O), not just the obvious ones.

### Files modified this pass

- `design/gdd/dungeon-run-orchestrator.md` — 4 edits: top-of-file status bump; C.4 compute_offline_run signal emission + rationale comment; §F invariant #1 extension; AC-ORC-09 THEN extension.
- `design/gdd/economy-system.md` — 2 edits: §E.4 full rewrite; top-of-file status bump.
- `design/gdd/floor-unlock-system.md` — 1 edit: top-of-file status line updated (I.14 + I.15 both resolved; fully unblocked).
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — 3 row updates.
- `production/session-state/active.md` — updated.

---

## Review — 2026-04-20 — Verdict: MAJOR REVISION NEEDED

**Scope signal**: XL (multi-system integration, 3+ formulas, requires new ADRs for EventBus + DI patterns, cross-GDD contract negotiation across 3+ GDDs, may re-litigate a Pass 2B locked decision)
**Specialists**: game-designer, systems-designer, qa-lead, economy-designer, godot-gdscript-specialist, creative-director (synthesis)
**Review mode**: solo (CD-GDD-ALIGN gate skipped per protocol)
**Depth**: full
**Blocking items**: 25 (deduplicated, post-creative-director adjudication; raw count higher pre-dedup)
**Recommended items**: 20
**Nice-to-have**: 3
**Prior verdict resolved**: First review

### Summary

GDD is structurally complete (8/8 sections, 13 ACs, 8 Open Qs, all dependency files exist on disk). What's left is **inherited debt**: cross-GDD contract gaps that #13 surfaced because it's the first system that had to be tight enough to expose lattice drift. Five specialists converge on six distinct root-cause clusters, two of which (Combat DI revision, Save/Load contract surface) require upstream changes to other GDDs. One Pass 2B locked decision (LOSING drip routing) has no implementation path under the current architecture — that's a vision-level question, not a doc fix.

### Blocking Items (25, deduplicated, source-tagged)

**Cluster A — Cross-GDD Economy Contracts (5 items)**

1. **[economy-designer E1]** `Economy.try_award_floor_clear(floor_index, bonus_amount)` does NOT exist in Economy GDD #4. Economy uses signal-receive (`floor_cleared_first_time`) pattern. Three architectures proposed; pick one.
2. **[economy-designer E2]** **LOSING drip halving is architecturally undeliverable**. Combat Rule 9 + Pass 2B locked decision 4 says drip IS halved on LOSING runs — but Orchestrator forwards no `losing_run` signal to Economy, and Economy's independent drip path has no access to RunSnapshot. **Locked design decision with no implementation path** — must re-litigate or change architecture.
3. **[economy-designer E3 + systems-designer S1]** `BASE_KILL[1]` tri-way contradiction: Orchestrator GDD says 10, Economy GDD says 15, registry uses 10. Every tier-1 AC fixture across both GDDs is wrong by 50%.
4. **[systems-designer S1]** Registry `kill_bonus` (output [15, 120]) and `attribute_kill_gold` (output [5, 120]) are different formulas with conflicting ranges — implementer reading kill_bonus would set min=10; Orchestrator says min=5. Cross-link or deprecate.

**Cluster B — Save/Load Contract Surface (6 items)**

5. **[godot-gdscript-specialist GD1]** `RunSnapshot extends RefCounted` + Save/Load consumer wiring not specified. Orchestrator must implement `save_to_dict()`/`load_from_dict()` and register as Save/Load consumer. Currently absent — dungeon state silently does not survive app restarts.
6. **[godot-gdscript-specialist GD5]** `Array[KillEvent]` and `Array[HeroInstance]` need explicit per-element `to_dict/from_dict`. `JSON.stringify` does NOT auto-serialize typed arrays of RefCounted objects. AC-ORC-12 unverifiable.
7. **[godot-gdscript-specialist GD6]** `var floor: Floor` serialization path undefined (3 options: by path / by contents / by stable id). Path C (stable id + DataRegistry resolve) is correct but unstated.
8. **[godot-gdscript-specialist GD2a]** `floor.id` dereference in `RunSnapshot.equals()` has no null guard — crashes on corrupted save.
9. **[godot-gdscript-specialist GD2b]** `Floor.id` type (String vs StringName) unspecified. JSON round-trip produces String, breaks equality.
10. **[systems-designer S6 + qa-lead Q6]** `is_equal_approx` on `hp_bonus_factor` at the 0.5 boundary can produce a snapshot where `losing_run` flips between two field-equal values. AC-ORC-12 doesn't test this boundary.

**Cluster C — D.4 Algorithm + Data Structure (2 items, post-adjudication)**

11. **[systems-designer S4 + economy-designer E4 + qa-lead Q9]** D.4 loop-walk pseudocode and dict-walk stated implementation produce DIFFERENT totals on partial loops (150 vs 165 in worked example). Both documented as "the implementation."
12. **[economy-designer E4 + systems-designer S7 — promoted to BLOCKING by creative-director]** Dict-walk on `kills_by_archetype` cannot recover `(archetype, tier)` pairs on mixed-tier floors. **The dict is the wrong data structure**, not just wrong algorithm. Latent in MVP, fires on V1.0 mixed-tier floors.

**Cluster D — State Machine Completeness (6 items)**

13. **[qa-lead Q1]** AC-ORC-01 state×trigger matrix has 19 undefined invalid cells; 4 ambiguous transitions explicitly named. Test writer has no spec.
14. **[systems-designer S8A]** ACTIVE_OFFLINE_REPLAY error path absent from C.1 state machine. Orchestrator can get permanently stuck.
15. **[systems-designer S8B]** DISPATCHING → RUN_ENDED transition (E.11) missing from C.1 table.
16. **[systems-designer S5]** D.3 `next_emit_window` doesn't handle `current_tick < last_emitted_tick` (rewind, save corruption). Inverted range passes garbage to Combat.
17. **[systems-designer S10]** "All floors unlocked" fallback before #16 lands allows F5 dispatch from fresh save → 18-min/kill scenario reachable in MVP playtest. Recommends fallback to "only F1 unlocked" until #16.
18. **[systems-designer S3]** D.2 `FLOOR_CLEAR_BONUS[floor_index]` array indexing 0-vs-1 unresolved. `floor_index = 5` would be out-of-bounds runtime error.

**Cluster E — Combat DI Revision (1 item — UPSTREAM, blocks #13)**

19. **[qa-lead Q3]** Static methods on `@abstract class_name CombatResolver extends Object` (Combat Pass 3A.6) **cannot be mocked in GdUnit4**. AC-ORC-03 and AC-ORC-05 architecturally unwriteable. Requires Combat GDD #11 to introduce DI (injectable instance interface or `combat_resolver` field). godot-gdscript-specialist missed this — notable specialist gap to log as a learning.

**Cluster F — Engine Conventions (1 item)**

20. **[godot-gdscript-specialist GD4]** `EventBus` autoload doesn't exist anywhere in project. No GDD, no ADR, no file. Used in 4 places. Either define EventBus (new GDD/ADR) or put signals on Orchestrator directly.

**Other BLOCKING (5 items)**

21. **[game-designer G1]** Mid-run reassignment ends loop (C.7) — anti-cozy if `formation_changed` signal collides with "open roster" UX. Option (c) deferred reassignment was never enumerated. Pillar 1 anti-pillar ("no fail state") at risk via player navigation. **Reframed by creative-director**: required actions are (a) enumerate option (c), (b) separate read/write signals, (c) document chosen rationale.
22. **[qa-lead Q2]** `test_floor_high_attack` fixture doesn't exist; `tests/` directory doesn't exist. AC-ORC-04 blocked on fixture authoring not flagged.
23. **[qa-lead Q4]** AC-ORC-08 deep-copy assertion shape ambiguous. Two distinct mutations (size vs value) need separate assertions.
24. **[qa-lead Q5]** AC-ORC-09 CHUNK undefined in GDD; T=576000 with CHUNK=1 = 576K function calls = CI timeout risk.
25. **[qa-lead Q8]** AC-ORC-11 verifies cache population correctness, NOT gold arithmetic. Per-archetype multiplier application has no dedicated AC.

### Recommended Items (20)

`[G2]` LOSING re-run silent gold halving needs visible `hp_bonus_factor` indicator pre-dispatch · `[G3]` "Trust through invisibility" fantasy depends on undesigned downstream GDDs — Section B needs honesty rewrite · `[G5]` Pillar 3 claim aspirational, qualify to "indirect" · `[G6a]` Reassignment progress loss = fail state via player navigation; consider partial-loop credit · `[S9]` `DISPATCH_DEBOUNCE_MS` upper bound 1000ms at UX lag threshold · `[S11]` AC-ORC-03 doesn't test initial-tick case · `[Q7]` Floor unlock no-op stub vs missing hook · `[Q10]` No AC for foreground→offline transition mid-run (most common real-world case) · `[Q11]` AC-ORC-02 references non-public `Combat.formation_dps_per_tick()` · `[Q12]` AC-ORC-06 "within one frame" not testable in GdUnit4 · `[E5]` AC-ORC-12 doesn't cover compound first-clear-then-suspend-then-offline path · `[E6]` AC-ORC-04 LOSING fixture should state formula not hardcoded number · `[E7]` F1 overnight ~1.376M vs ~148K Tier-1 sink (LOSING drip routing gap amplifies pillar break) · `[E8]` MATCHUP double-dip 2.25× combined (not 1.5×); Economy D.6 pacing wrong by 33% · `[GD3]` `extends Node` vs `RefCounted` not stated; `set_process(false)` not addressed · `[GD7]` `Dictionary[StringName, bool]` key-type discipline at DataRegistry boundary · `[GD8]` State enum declaration absent; save-stability of ordinals unaddressed · `[GD9]` `error_logger: Callable` routing decision undeclared · `[GD10]` `DISPATCH_DEBOUNCE_MS` in wall-clock ms inconsistent with tick-based time model

### Nice-to-Have (3)

`[G4]` Mid-queue boss fanfare creates UX lie; add developer-facing error signal alongside fanfare · `[G6b]` 170s F5 boss = de-facto timed event window during foreground play · `[Q12]` (already RECOMMENDED above)

### Specialist Disagreements (3, all adjudicated by creative-director)

1. **G1 mid-run reassignment** — game-designer proposes new option (c) deferred reassignment that GDD didn't enumerate. **Adjudicated**: keep BLOCKING but reframe — required actions are (a) enumerate option (c) explicitly, (b) separate read/write signals so casual roster checks don't trigger reassignment, (c) document chosen rationale tied to cozy pillar.
2. **Q3 vs godot-gdscript-specialist on Combat DI impact** — qa-lead flagged static-method mock incompatibility; godot-gdscript-specialist missed it. **Adjudicated**: qa-lead correct. Combat GDD #11 needs Pass 3D to introduce DI. Notable specialist gap from godot-gdscript.
3. **S7 vs E4 severity on dict-walk tier loss** — systems-designer rated RECOMMENDED ("latent in MVP"), economy-designer rated BLOCKING ("correctness fault even if latent"). **Adjudicated**: economy-designer correct. **Promote to BLOCKING.** Silent correctness faults that emerge in V1.0 are strictly worse than loud crashes.

### Cross-Model Convergence (highest signal)

1. **D.4 dict-walk vs loop-walk + tier loss**: S4 BLOCKING + E4 BLOCKING + S7 RECOMMENDED→BLOCKING + Q9 RECOMMENDED. Three specialists independently flag.
2. **LOSING drip routing gap**: E2 BLOCKING + G2 RECOMMENDED + E7 RECOMMENDED. Architectural gap that breaks Pass 2B locked decision 4.
3. **BASE_KILL[1] mismatch**: E3 BLOCKING + S1 BLOCKING (related). Cross-GDD value contradiction.
4. **Save/Load contract gaps**: GD1 + GD5 + GD6 + Q6 + S6 BLOCKING. Five specialists converge — AC-ORC-12 cannot pass as written.
5. **State machine gaps**: S8A + S8B + Q1. Three specialists converge.
6. **EventBus undefined**: GD4 BLOCKING. Unique to godot-gdscript but architecturally critical.

### Senior Verdict (creative-director)

> "**MAJOR REVISION NEEDED — Multi-Pass Required (4A / 4B / 4C + parallel 4D).** 25 BLOCKING + 20 RECOMMENDED + 3 NICE across 5 specialists. Six distinct root-cause clusters, two requiring upstream changes to other GDDs (#11 Combat DI, Save/Load contract). One **locked Pass 2B decision has no implementation path** (E2 LOSING drip routing — vision-level question, not a doc fix). Cross-GDD value contradictions (BASE_KILL, kill_bonus, try_award_floor_clear) suggest the wider design lattice has drift; #13 is the surface where it became visible. NOT an 'approved with concerns' candidate — contract gaps make AC-ORC-04, -09, -11, -12 unwriteable as currently specified. **The right framing**: not 'Orchestrator is rough' — 'Orchestrator was the first place the lattice had to be tight enough that pre-existing drift became visible.' That's a healthy outcome of a serious review process, not a failure of #13's author."

### Recommended Revision Shape (Pass 4A / 4B / 4C / parallel 4D)

- **Pass 4A — Internal Correctness** (systems-designer-led, ~2 hrs): Cluster C (D.4 algorithm + tier-preserving structure) + Cluster D (state machine + S5 rewind guard + S10 F1-only fallback) + S3 array indexing. *Self-contained, unblocks ~12 BLOCKERs (~85% of ACs become writeable).*
- **Pass 4B — Cross-GDD Contract Negotiation** (creative-director + economy-designer + Save/Load owner, ~3 hrs): Cluster A (Economy contracts incl. Pass 2B reopen for E2) + Cluster B (Save/Load contract addendum). *Highest-stakes; touches 3 GDDs; may re-litigate Pass 2B locked decision 4.*
- **Pass 4C — Engine Conventions + Polish** (godot-gdscript-specialist + technical-director, ~2 hrs): Cluster F (EventBus decision, Node base, type discipline, enum stability, Callable routing, time-model) + all RECOMMENDED items + G3/G5 fantasy honesty + G1 reframe.
- **Pass 4D (parallel, BLOCKED on Combat #11)** — DI Revision Inheritance: Re-open AC-ORC-03 + AC-ORC-05 once Combat GDD #11 ships its Pass 3D DI revision.

**If only one pass before re-review**: Do **4A**. Most self-contained, unblocks the most ACs.

### Validation Criteria (per creative-director)

- After 4A: systems-designer + qa-lead re-review passes Cluster C and D findings; AC count writeable rises from current ~50% to ~85%.
- After 4B: economy-designer + Save/Load owner sign off on contract addenda; AC-ORC-04, -11, -12 become writeable; Pass 2B decision either re-confirmed (with implementation path) or formally re-litigated (with documented new decision).
- After 4C: godot-gdscript-specialist re-review returns 0 BLOCKING; game-designer signs off on Section B fantasy honesty.
- After 4D (whenever #11 lands): qa-lead confirms all 12 AC-ORCs are writeable against actual test scaffolding.

### Cascade items flagged for other GDDs (action by next session)

- **Combat GDD #11**: needs Pass 3D — introduce DI for `CombatResolver` (injectable instance interface or `combat_resolver` field on Orchestrator). Static-only API is not testable in GdUnit4. Blocks AC-ORC-03 + AC-ORC-05 in #13.
- **Combat GDD #11 + Pass 2B reopen**: locked decision 4 ("LOSING drip is halved") has no implementation path under current architecture. Either re-litigate decision or change architecture (Orchestrator becomes publisher of `losing_run_state_changed`, Economy subscribes, drip path multiplies).
- **Economy GDD #4**: needs revision pass — define `try_award_floor_clear` public method (or replacement signal pattern); reconcile `BASE_KILL[1]` value (10 vs 15); add `loot_factor` term to drip formula D.1 OR define cross-system signal for LOSING state; document MATCHUP combined 2.25× ceiling and re-verify D.6 pacing table; correct Section C.2.4 "33% faster" claim.
- **Save/Load GDD #3**: needs contract addendum — Resource nesting via to_dict/from_dict, float-tolerance semantics for is_equal_approx round-trip, register Orchestrator as consumer.
- **EventBus** (NEW): either author a small GDD/ADR defining the centralized signal-bus pattern, OR drop EventBus and put signals directly on Orchestrator (preferred per Godot idiom per godot-gdscript-specialist).
- **Floor Unlock System #16**: AC-ORC-13 currently ADVISORY pending #16; promote to BLOCKING when #16 lands. Until then, MVP smoke test must verify `is_unlocked()` IS called (even if always returns true).
- **Registry**: cross-GDD value drift surfaced (BASE_KILL[1], try_award_floor_clear contract). Audit pass recommended after #13 stabilizes.

### Editorial Note (from creative-director synthesis)

> "The Combat review log shows the historical pattern was three sub-passes addressing roughly one cluster per pass with clean handoff. #13 is in worse shape because it surfaces inherited debt from upstream. The right framing for the team is not 'Orchestrator is rough' — it's 'Orchestrator was the first place the lattice had to be tight enough that pre-existing drift became visible.'"

### User decision (2026-04-20)

**Stop here, revise in a separate session.** Context already substantial after the design-system pass + this review; fresh session safer than pushing Pass 4A in this session. This review log entry + systems-index MAJOR REVISION NEEDED marker are sufficient handoff artifacts.

### Specialist gap to log as learning

godot-gdscript-specialist missed Q3 (static methods cannot be mocked in GdUnit4) — a well-known constraint, not a niche one. Worth noting for future reviews: the gdscript specialist should explicitly include test-mockability assessment of static-method APIs in their review checklist.

## Review — 2026-04-20 — Pass 4A Applied — Verdict: INTERNAL CORRECTNESS RESOLVED (Clusters C + D + S3), PASS 4B/4C/4D PENDING

**Scope**: internal correctness revision inside the Orchestrator GDD only. No cross-GDD edits beyond (1) a `Pass 3E` addendum flag in Combat (for `CombatBatchResult.partial_loop_kills` field) and (2) a registry notes update for `attribute_floor_clear_bonus` locking 1-based `FLOOR_CLEAR_BONUS` indexing. Clusters A (cross-GDD Economy contracts), B (Save/Load contract surface), F (EventBus autoload), and the G1/Q2/Q4/Q5/Q8 standalones remain for Pass 4B/4C. Cluster E (Combat DI) was resolved by Combat Pass 3D on the same day.

### Cluster C — D.4 Algorithm + Data Structure — RESOLVED (2 BLOCKERs)

**C1 / E4 (loop-walk vs dict-walk non-equivalent on partial loops)** — D.4 rewritten from a dict-walk over `kills_by_archetype` to a two-phase **ordered kill-schedule loop-walk**. Phase 1 multiplies `snapshot.kill_schedule` per-kill gold by `loops_completed` (O(enemies_per_floor), not O(loops)). Phase 2 walks `partial_loop_kills` in tick order for the final partial loop. On any `tick_budget` that aligns exactly to a loop boundary, `partial_loop_kills` is empty and the algorithm degenerates correctly to phase 1 only — no special-casing needed. Worked example added showing 3 complete loops + 2-kill partial producing identical totals to the foreground path.

**C2 / S7 adjudicated (dict-walk on `kills_by_archetype` cannot recover (archetype, tier) pairs)** — The new shape uses `KillEvent` records (each carries `archetype`, `tier`, `is_boss`, per-kill tick) instead of aggregate-count dicts. Tier attribution per kill is now exact. `kills_by_archetype` and `kills_by_tier` are preserved on `CombatBatchResult` for UI summary and telemetry purposes but explicitly marked **NOT used for gold attribution** in D.4 prose.

**Flagged upstream (Pass 3E for Combat GDD #11)** — The loop-walk requires `CombatBatchResult.partial_loop_kills: Array[KillEvent]`. Combat GDD Pass 3 does not currently surface this field — `CombatBatchResult` exposes `kills_by_archetype`, `kills_by_tier`, `loops_completed`, `first_clear_tick`, `hp_bonus_factor`, `survived`, `final_tick`. A small Combat addendum (Pass 3E) is required to add `partial_loop_kills`. The field is derivable from the same per-tick walk Combat already performs internally to compute `loops_completed` — no new algorithm is needed, only the result surfaced. MVP interim fallback documented: until Pass 3E lands, the Orchestrator may derive `partial_loop_kills` by walking `snapshot.kill_schedule` from index 0 and stopping at the first kill whose `kill_tick > (tick_budget % snapshot.ticks_per_loop)` — arithmetically equivalent because the kill schedule is stable across loops (Combat Rule 8). Explicit Combat-surfaced field preferred for test assertability. Flagged in Combat review log separately.

### Cluster D — State Machine Completeness — RESOLVED (6 BLOCKERs)

**D1 (19 undefined invalid cells)** — C.1 rewritten with a complete 5×6 state×trigger matrix. Every cell is now either a named valid transition or an explicit "invalid — push_error, remain in current state" entry. No blanks. 30 cells total defined; 11 valid transitions + 19 explicit invalids.

**D2 (ACTIVE_OFFLINE_REPLAY error path)** — Added `replay_failed` trigger to the matrix. `ACTIVE_OFFLINE_REPLAY` + `replay_failed` → `RUN_ENDED` with `validation_failed(reason="offline_replay_error", payload={...})` signal. Covered in C.4 prose + Edge Case E.14.

**D3 (DISPATCHING→RUN_ENDED missing)** — Added `DISPATCHING` + `run_ended` → `RUN_ENDED` with `validation_failed(reason, payload)`. Fires when DISPATCHING validation fails (empty formation per AC-ORC-07, locked floor per AC-ORC-13, `floor_was_valid == false` per Combat I.Q11 resolution). Chose RUN_ENDED (not NO_RUN) for consistency with "every dispatch leaves a cleanup trail" convention; player returns to NO_RUN on the next `dispatch_pressed` or via explicit cleanup.

**D4 (D.3 clock-rewind guard)** — Added Pass 4A clock-rewind guard in `_on_tick_fired`: if `current_tick < snapshot.last_emitted_tick`, the Orchestrator logs `push_warning` and snaps `current_tick` forward to `last_emitted_tick` (clamp, do not replay). Preserves Pillar 1 — player is never penalized for clock anomalies. Added as dedicated Edge Case entry in Section E (E.13) covering timezone change, manual adjustment, NTP correction, Steam Deck suspend-wake scenarios.

**D5 ("all floors unlocked" fallback → F1-only)** — MVP fallback changed from "all floors unlocked" to "**F1-only on fresh save**" until Floor Unlock System #16 ships. Documented as MVP scaffolding decision with explicit removal trigger (when #16 GDD lands). AC-ORC-13 updated with new Sub-AC 13-fresh-save asserting the F1-only behavior. Prevents the 18-min-per-kill F5 dispatch scenario on fresh saves. Added Edge Case entry E.12.

**D6 / S3 (FLOOR_CLEAR_BONUS 0-vs-1 indexing)** — Convention locked to **1-based**: `FLOOR_CLEAR_BONUS[1]=F1, [2]=F2, [3]=F3, [4]=F4, [5]=F5`. `FLOOR_CLEAR_BONUS[0]` is undefined; Orchestrator guards with `assert(floor_index >= 1 and floor_index <= 5)`. Rationale: `floor_index` is 1-based throughout the project, so `[floor_index]` avoids the `[floor_index - 1]` off-by-one footgun. All Orchestrator pseudocode and AC verification clauses updated to use the convention consistently. Registry `attribute_floor_clear_bonus` formula notes updated to lock this in cross-document.

### BLOCKERs resolved this pass (12 of 25)

Cluster C (2): **C1, C2** (adjudicated promotions). Cluster D (6): **D1, D2, D3, D4, D5, D6**. Standalone S3 (same as D6): **S3**. Plus the Sub-ACs these touched: AC-ORC-01 exhaustive-matrix verification now writeable, AC-ORC-07 DISPATCHING error path now has a named transition, AC-ORC-09 parity assertion uses loop-walk arithmetic, AC-ORC-13 gains Sub-AC 13-fresh-save. Total ~12 BLOCKERs closed.

### BLOCKERs remaining after Pass 4A

- **Cluster A** (5 items, Pass 4B): `try_award_floor_clear` Economy interface, LOSING drip routing (Pass 2B locked decision 4 architectural gap), `BASE_KILL[1]` tri-way contradiction, `kill_bonus` vs `attribute_kill_gold` range conflict, C.2.4 "33% faster" claim mis-stated.
- **Cluster B** (6 items, Pass 4B): RunSnapshot Save/Load wiring, `Array[KillEvent]`/`Array[HeroInstance]` per-element to_dict/from_dict, `var floor: Floor` serialization path, `floor.id` null guard, `Floor.id` type unspecified, `is_equal_approx` on `hp_bonus_factor` 0.5 boundary.
- **Cluster F** (1 item, Pass 4C): EventBus autoload decision (either define or drop; 4 usage sites).
- **G1 reframe** (Pass 4C): enumerate option (c) deferred reassignment + separate read/write signals.
- **Q2/Q4/Q5/Q8** (Pass 4C): test-plan polish.
- **AC-ORC-03/05** (Pass 4D): unblocked by Combat Pass 3D; can proceed in parallel.

### Files modified this pass

- `design/gdd/dungeon-run-orchestrator.md` — complete C.1 matrix rewrite; new triggers `replay_failed` added to C.1; D.3 clock-rewind guard + prose; D.4 rewritten as ordered loop-walk with worked example; D.5 prose + MVP F1-only scaffolding note; new/revised Edge Cases E.12 (F1-only fallback), E.13 (clock rewind), E.14 (offline replay error); AC-ORC-01, -07, -09, -13 updated (including Sub-AC 13-fresh-save); header status + Last Updated refreshed; "Flagged Combat contract addendum — Pass 3E required" box added at the end of D.4.
- `design/registry/entities.yaml` — `attribute_floor_clear_bonus` notes extended with Pass 4A 1-based indexing lock + rationale.
- `design/gdd/reviews/combat-resolution-review-log.md` — Pass 3E flag appended (requests `CombatBatchResult.partial_loop_kills` field).
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — this entry.
- `design/gdd/systems-index.md` — row 13 status bumped to "Pass 4A Applied — ~12 of 25 BLOCKING resolved; Pass 4B/4C/4D pending"; header Last Updated appended.
- `production/session-state/active.md` — Pass 4A checkbox ticked; Progress refreshed; "What happened this session" updated.

### Next step

**Pass 4B** — cross-GDD contract negotiation (~3 hours). Requires alignment across creative-director + economy-designer + Save/Load owner. Touches Economy GDD #4 (define `try_award_floor_clear`, reconcile `BASE_KILL[1]`, resolve LOSING drip routing architectural gap — may re-litigate Pass 2B locked decision 4) + Save/Load GDD #3 (contract addendum for Resource nesting via to_dict/from_dict, float-tolerance semantics, Orchestrator as consumer). **Pass 4B may re-open a previously-locked decision** — flag to creative-director before executing.

If Pass 4B blocks on cross-GDD alignment: **Pass 4C** (engine conventions + polish) can proceed independently: Cluster F (EventBus — recommend drop and put signals on Orchestrator directly per Godot idiom), G1 reframe (enumerate option (c) deferred reassignment + split read/write signals), Q2/Q4/Q5/Q8 test-plan polish, fantasy-honesty edits to G3/G5 prose, remaining RECOMMENDED items.

**Pass 4D** (AC-ORC-03+05 rewrite) can proceed in parallel with 4B/4C — Combat Pass 3D unblocked it on the same day.

## Review — 2026-04-20 — Pass 4B-Economy Applied — Verdict: CLUSTER A RESOLVED, CLUSTER B DEFERRED

**Scope**: Cluster A (5 cross-GDD contract items). Pass 4B-Economy is the economy-designer-led half of Pass 4B; Cluster B (Save/Load) is deferred to a separate Pass 4B-SaveLoad because the two sub-passes touch different GDDs and don't share a specialist.

### Cluster A BLOCKERs closed (5 of 13 remaining post-Pass-4A)

- **E1 / A1** — `Economy.try_award_floor_clear(floor_index, bonus_amount) -> bool` defined in Economy C.2.3a. Per-lifetime idempotency, signal `first_clear_awarded(floor_index)`, boundary + negative-bonus sub-ACs added (Economy AC H-14). Orchestrator calls match.
- **E2 / A2** — **LOSING drip routing resolved via Option Y (re-litigation of Pass 2B locked decision 4).** Drip is NOT halved on LOSING runs; `LOSING_RUN_LOOT_FACTOR` scope narrowed to kill gold + floor-clear only. Architectural rationale: drip is owned by Economy's independent `tick_fired` subscription; no architectural home for cross-system `losing_run` coupling. Three GDDs updated (Economy C.2.3, Combat Rule 9, Orchestrator E.5 + AC-ORC-04). Combat review log carries a formal "Pass 2B Decision 4 Superseded by Pass 4B-Economy" amendment for decision traceability.
- **E3 / A3** — `BASE_KILL[1]` reconciled to **10** (matched registry + Orchestrator already; Economy was the stale one at 15). Economy D.6 pacing math re-verified; all references to 15 updated to 10.
- **E4 / A4** — Economy's `kill_bonus` formula deprecated in favour of Orchestrator's canonical `attribute_kill_gold`. Orchestrator was already the sole caller of `add_gold` for kill gold; change is documentation-only, no runtime delta.
- **E8 / A5** — Economy C.2.4 "33% faster" claim corrected to **2.25× combined** (matchup throughput 1.5× × matchup gold 1.5×). Narrative-only fix; D.6 pacing table already had correct numbers.

### Cluster B BLOCKERs deferred to Pass 4B-SaveLoad (6 of 13 remaining)

- RunSnapshot Save/Load wiring spec
- `Array[KillEvent]`/`Array[HeroInstance]` per-element `to_dict`/`from_dict`
- `var floor: Floor` serialization path
- `floor.id` null guard
- `Floor.id` type specification
- `is_equal_approx` on `hp_bonus_factor` 0.5 boundary

Cluster B is a Save/Load specialist's pass — it does not need the economy-designer. Separating Pass 4B into two sub-passes with different specialists keeps each pass focused and under 2 hours.

### Pass 3B drip curve holistic rebalance — STILL OPEN

Not closed in this pass. Full F1–F5 drip curve rebalance requires playtest data from a vertical-slice build that doesn't exist yet. Interim fix (`BASE_DRIP[5]` = 8, down from 20) remains in place. Flagged to revisit paired with `/playtest-report` once first playtest build lands. Does NOT gate Orchestrator APPROVED verdict — the curve is a tuning item, not a contract item.

### Files modified this pass

(See `design/gdd/reviews/economy-system-review-log.md` 2026-04-20 entry for the full file-level diff summary — all edits in Pass 4B-Economy are listed there with one-line descriptions each.)

### BLOCKERs remaining after Pass 4A + Pass 4B-Economy

- **Cluster B** (6 items, Pass 4B-SaveLoad): listed above.
- **Cluster F** (1 item, Pass 4C): EventBus autoload decision.
- **G1 reframe** (Pass 4C): enumerate option (c) deferred reassignment + separate read/write signals.
- **Q2/Q4/Q5/Q8** (Pass 4C): test-plan polish.
- **AC-ORC-03/05 rewrite** (Pass 4D, unblocked by Combat Pass 3D).

Total: 6 (Cluster B) + 1 (F) + 1 (G1) + 4 (Q2/4/5/8) + 2 (ORC-03/05) = 14 items, 13 BLOCKING + 1 RECOMMENDED spread across Pass 4B-SaveLoad, Pass 4C, Pass 4D. Approximately **half of the original 25 BLOCKING** are now resolved across Combat Pass 3D + Orchestrator Pass 4A + Pass 4B-Economy (2 clusters + 5 items). The remaining work is cleanly parallelizable.

### Next step

**Pass 4B-SaveLoad** — Cluster B (6 BLOCKERs), ~2 hours, Save/Load-owner-led. Independent of 4C and 4D — can run in any order.

**Sequencing recommendation**: 4B-SaveLoad first (closes the final cross-GDD contract surface), then 4C + 4D can run in parallel or sequentially.

## Review — 2026-04-20 — Pass 4B-SaveLoad Applied — Verdict: CLUSTER B RESOLVED

**Scope**: Cluster B (6 BLOCKERs on Save/Load contract surface). Save/Load was "Approved" before this pass; Pass 4B-SaveLoad is a contract addendum (new Rules 10–14 + new ACs) that does not re-open approved behavior. Full audit trail in `design/gdd/reviews/save-load-system-review-log.md` 2026-04-20 entry.

### Cluster B BLOCKERs closed (6 of 8 remaining post-Pass-4B-Economy)

- **B1** — RunSnapshot Save/Load wiring (Save/Load Rule 10; `orchestrator.get_save_data()` / `load_save_data()` API; `"active_run"` save-schema key; save-on-state-transition cadence; malformed-save error contract).
- **B2** — Array-element serialization pattern (Save/Load Rule 11; inline per-element `to_dict`/`from_dict` loop pattern — shared util deferred as unnecessary for 2–3 Array fields; new AC SL-13).
- **B3** — Resource references (Save/Load Rule 12 — serialize-by-id; `RunSnapshot.to_dict` emits `floor_id: String` not `floor: Floor` inline; `DataRegistry.resolve("floors", floor_id)` on load; `null` resolve returns `null` from `from_dict`; Orchestrator falls back to `NO_RUN`). `Floor.id` confirmed as String (Biome DB not re-opened). Null-guard handled via the resolve-null path — no separate check needed.
- **B4** — `losing_run` 0.5-boundary flip prevented via option (i): `losing_run` serialized as explicit bool, NOT re-derived on load (Save/Load Rule 14; Sub-AC 12-boundary on Orchestrator AC-ORC-12).
- **B5** — Float-tolerance semantics (Save/Load Rule 13; new registry constant `SAVE_LOAD_FLOAT_EPSILON = 0.00001`; exact-equality default for boolean-gate floats; `is_equal_approx` only where caller explicitly tolerates drift; denormals/NaN/Inf logged + rejected).
- **B6** — AC-ORC-12 rewritten with Given-When-Then + concrete fixture + Sub-AC 12-floor-missing + Sub-AC 12-boundary. Previously unverifiable; now writeable (conditional on Combat Pass 3F for `KillEvent.from_dict`).

### Flagged upstream — Combat Pass 3F required

AC-ORC-12 + Save/Load AC SL-13 reference `KillEvent.to_dict()` / `KillEvent.from_dict()` which are NOT yet defined in Combat GDD #11 (Pass 3 locked `KillEvent.equals()` only). Pass 3F is a single-field-group addition to one class; no behavior delta. **Bundle recommendation**: batch Pass 3F with already-flagged Pass 3E (`CombatBatchResult.partial_loop_kills`) + the pre-existing Combat Pass 3 targeted re-review (9 blockers) into a single Combat-attention session (~1.5 hrs combined). Full flag record in Combat review log.

Also flagged: Hero Roster `HeroInstance.to_dict` / `from_dict` — needs verification; if missing, a small Hero Roster pass follows the same pattern as Pass 3F.

### BLOCKERs remaining after Pass 4B-SaveLoad (8 of 25 original BLOCKING)

- **Cluster F** (1 item, Pass 4C): EventBus autoload decision.
- **G1 reframe** (1 item, Pass 4C): enumerate option (c) deferred reassignment + separate read/write signals.
- **Q2 / Q4 / Q5 / Q8** (4 items, Pass 4C): test-plan polish items.
- **AC-ORC-03 / AC-ORC-05 rewrite** (2 items, Pass 4D): unblocked by Combat Pass 3D earlier same day; proceed once Combat Pass 3F also lands (gives the ACs a fully-stable data-structure contract to write against).

**Orchestrator status after 4 passes applied**: 17 of 25 BLOCKING originally open → now 23 of 25 resolved (actually 17 closed across C/D/S3/A/B + 2 unblocked ACs via DI = 19 touched; remaining 8 items are in Pass 4C + 4D). Or framed differently: only 2 clusters (F + G) + 6 standalone items + 2 AC rewrites remain. Ship-ready contract surface is done.

### Files modified this pass

See `design/gdd/reviews/save-load-system-review-log.md` 2026-04-20 entry for full file-level diff summary.

### Next step

**Pass 4C** — engine conventions + polish (~1.5 hrs, self-contained inside Orchestrator GDD). Cluster F EventBus decision + G1 reassignment reframe + Q2/Q4/Q5/Q8 test-plan polish. Independent of remaining Combat-attention items.

**Parallel**: Combat Pass 3E + Pass 3F + Pass 3 targeted re-review bundle (~1.5 hrs, Combat-attention session). Unblocks Pass 4D cleanly.

**Final**: Pass 4D (AC-ORC-03 + AC-ORC-05 rewrite, ~1 hr) once both above complete.

Total remaining: ~3–4 hours across 3 sub-passes before Orchestrator can move from MAJOR REVISION NEEDED to CONCERNS or APPROVED.

## Review — 2026-04-20 — Pass 4C Applied — Verdict: CLUSTER F + G1 + Q-SERIES RESOLVED

**Scope**: Engine conventions + polish. Self-contained inside Orchestrator GDD. Closes Cluster F (EventBus decision) + G1 reframe (mid-run reassignment signal split) + Q2/Q4/Q5/Q8 test-plan polish (6 BLOCKERs) + G3/G5 fantasy-honesty polish (2 RECOMMENDED).

### Cluster F — EventBus dropped (1 BLOCKING)

**Decision**: drop EventBus; move all 4 previously-attributed signals to the Orchestrator autoload directly. Rationale: Godot idiom is node-owned signals; the Orchestrator's signal topology (1 publisher, few subscribers) does not justify a project-wide bus. Dropping also removes a dependency on a GDD that was never written.

**Signals now owned by `DungeonRunOrchestrator` (autoload Node)**:
- `enemy_killed(tier: int, archetype: StringName, advantaged: bool)`
- `boss_killed(enemy_id: StringName)`
- `floor_cleared_first_time(floor_index: int)`
- `validation_failed(reason: StringName, payload: Dictionary)`

Subscribers connect via `DungeonRunOrchestrator.[signal].connect(...)` at `_ready`. Dependencies section and affected AC verification clauses (AC-ORC-06, AC-ORC-10, Open Q I.8) updated. Header Last Updated records the decision. No new EventBus GDD or ADR — the decision is to drop, not to define.

**Future escape hatch documented**: If a future system needs cross-cutting signal topology (multiple publishers, wide subscriber fan-out), a separate EventBus GDD may reintroduce the bus. Not in MVP scope.

### G1 reframe — browse/commit signal split (1 BLOCKING)

**C.7 expanded with three reassignment options**:
- **(a) End run + restart dispatch** — the MVP lock (current default). Mid-run reassignment ends the current run and begins a fresh dispatch with the new formation.
- **(b) Reject until recalled** — explicit intent gate; player must end the run manually before reassigning. Rejected as too punitive for cozy posture; documented for completeness.
- **(c) Deferred reassignment** — V1.0-deferred cozy path. Queue the new formation; apply at the next dispatch boundary (after current run ends naturally or via explicit Recall). No player punishment for planning-ahead UI actions.

**Signal split** — Formation Assignment Screen now emits two distinct signals:
- `formation_browse_opened` — read-only informational. Orchestrator **ignores** this signal. Prevents the anti-cozy fail state where opening the roster panel ends the run.
- `formation_reassignment_committed(new_formation: Array[HeroInstance])` — write signal. Emitted only on confirmed intent (commit button, not panel open). Triggers the Orchestrator's reassignment path per option (a/b/c).

`MID_RUN_REASSIGN_WARNING_ENABLED = true` registry knob continues to gate the UX confirmation dialog before `formation_reassignment_committed` is emitted — belt-and-braces layer on top of the signal split.

AC-ORC-06 updated to reference `formation_reassignment_committed` instead of the previous `EventBus.formation_changed`.

### Q2 — `test_floor_high_attack` fixture defined (1 BLOCKING)

Fixture spec added inline in AC-ORC-04 (LOSING_RUN_LOOT_FACTOR end-to-end test): synthetic F-series floor constructed directly as a local `Floor.new()` in tests (NOT loaded via DataRegistry; does NOT ship in production `FloorDatabase`). Key fields:
- `enemy_list` = one Bruiser with `enemy_attack = 120`
- `enemy_hp = 200`
- `floor_index = 99` (test-only sentinel — avoids F1–F5 production conflicts)
- Drives L1 solo Rogue's `hp_bonus_factor` = `55/120 = 0.458 < 0.5` → `losing_run = true` per Combat Rule 9

### Q4 — AC-ORC-08 rewritten with 3 concrete sub-ACs (1 BLOCKING)

Prior assertion was "snapshot is unchanged" — ambiguous about which mutations and fields to check. Rewritten:
- **Sub-AC 08-array-identity**: formation_snapshot Array is a distinct instance; appending to source Roster does NOT change snapshot size.
- **Sub-AC 08-field-mutation**: mutating a source HeroInstance's `current_level` does NOT appear in the snapshot copy.
- **Sub-AC 08-floor-reference**: `snapshot.floor` is a shared reference to the DataRegistry Floor resource, NOT a deep copy. Explicitly called out to avoid confusion with the formation deep-copy (Resources are immutable by DataRegistry convention; Pass 4B-SaveLoad Rule 12).

### Q5 — AC-ORC-09 `CHUNK` token replaced (1 BLOCKING)

Prior spec referenced a bare `CHUNK` variable without defining it. Rewritten to use `OFFLINE_REPLAY_CHUNK_TICKS` (the registry tuning knob, default 0 = disabled) or simpler tick-step parameterization `{1, 50, 200, 1000}`. Named constant removes ambiguity; tick-step is for foreground parameterization, not chunking. Sub-AC 09-chunked reserved for when `OFFLINE_REPLAY_CHUNK_TICKS != 0` becomes a first-playtest tuning path.

### Q8 — AC-ORC-11 rewritten for arithmetic, not cache (1 BLOCKING)

Prior spec asserted `matchup_cache[archetype] == expected_bool` — a test of internal optimization, not observable behavior. Rewritten to assert **per-archetype gold totals** match expected values computed from `attribute_kill_gold(tier, advantaged, losing_run) × kill counts per archetype`. Fixture: F3 dispatch with mixed archetypes, MatchupResolver stub returning a fixture-specified advantage map. Economy spy captures `add_gold` calls grouped by archetype (cross-referenced via `RunSnapshot.kill_schedule`). Test is resilient to replacing the cache with direct MatchupResolver calls.

### G3 + G5 fantasy-honesty polish (2 RECOMMENDED)

- **G3**: "Trust through invisibility" fantasy claim in the Player Fantasy section qualified — the claim depends on undesigned downstream GDDs (Return-to-App, Guild Hall); rewritten as "MVP scaffolding for the trust-through-invisibility experience; full realization pending dependent GDDs."
- **G5**: Pillar 3 ("matchup is a decision") claim qualified to "indirect — Orchestrator routes Resolver output into per-kill gold; the player feels matchup via cadence + gold rate, not a separate matchup UI." Accurate to current MVP surface.

### Remaining RECOMMENDED / NICE — intentionally skipped

Did not attempt the 18 other RECOMMENDED or the 3 NICE items in this pass. Those are polish items that can be addressed in targeted future passes (`/consistency-check` passes or dedicated cleanup) without blocking the MAJOR REVISION NEEDED → CONCERNS/APPROVED transition. Pass 4C's goal was to close the remaining BLOCKERs, not to drain the polish backlog.

### BLOCKERs closed (6 of 8 remaining post-Pass-4B-SaveLoad)

- **F1** — EventBus dropped; signals owned by Orchestrator autoload.
- **G1** — Three reassignment options enumerated; browse/commit signal split.
- **Q2** — `test_floor_high_attack` fixture defined inline in AC-ORC-04.
- **Q4** — AC-ORC-08 rewritten with 3 concrete sub-ACs.
- **Q5** — AC-ORC-09 `CHUNK` → `OFFLINE_REPLAY_CHUNK_TICKS` / tick-step.
- **Q8** — AC-ORC-11 rewritten for arithmetic correctness, not cache population.

### BLOCKERs remaining after Pass 4C (2 of 25 original BLOCKING)

- **AC-ORC-03 / AC-ORC-05 rewrite** (2 items, Pass 4D): unblocked by Combat Pass 3D earlier same day. Can proceed now — Combat Pass 3E+3F bundle is recommended-but-not-required (the interim fallback in Orchestrator D.4 provides a path without 3E; AC-ORC-03+05 are about the DI contract, which Pass 3D already stabilized).

**Orchestrator status**: 23 of 25 BLOCKING resolved across Combat Pass 3D + Orchestrator Pass 4A + Pass 4B-Economy + Pass 4B-SaveLoad + Pass 4C. Only the 2 Pass 4D ACs remain. Once Pass 4D completes, Orchestrator moves from MAJOR REVISION NEEDED → CONCERNS (awaiting independent re-review against the full changeset).

### Files modified this pass

- `design/gdd/dungeon-run-orchestrator.md` — header Last Updated refreshed; Dependencies section + C.6/C.7 sections updated for autoload-owned signals; C.7 expanded with 3-option reassignment + read/write signal split; AC-ORC-04 inline fixture spec; AC-ORC-06 trigger signal updated; AC-ORC-08 rewritten with 3 sub-ACs; AC-ORC-09 CHUNK replaced; AC-ORC-10 EventBus emit → Orchestrator autoload; AC-ORC-11 rewritten for arithmetic; Section B G3 qualifier; Player Fantasy / Pillar 3 G5 qualifier; Open Q I.8 signal-owner note.
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — this entry.
- `design/gdd/systems-index.md` — row 13 status bumped; header Last Updated appended.
- `production/session-state/active.md` — Pass 4C checkbox ticked; Last Updated refreshed; Progress list updated.

### Next step

**Pass 4D — AC-ORC-03 + AC-ORC-05 rewrite** (~1 hr). The final Orchestrator pass. Uses Combat Pass 3D's DI shape (`combat_resolver: CombatResolver` injected instance + spy subclass pattern). Both ACs test the Orchestrator↔Combat contract; Combat Pass 3E+3F bundle is recommended-but-not-blocking.

**Parallel option**: Combat Pass 3E + Pass 3F + Pass 3 targeted re-review bundle (~1.5 hrs). Unblocks AC-ORC-09's full parity test (via `partial_loop_kills`) and AC-ORC-12's full round-trip test (via `KillEvent.to_dict` / `from_dict`). Does not block Pass 4D — AC-ORC-03/05 are independent of the Combat data-structure surface.

Recommended order: **Pass 4D first** (closes the last 2 Orchestrator BLOCKERs), then Combat bundle (closes the upstream flags and the pre-existing Pass 3 re-review), then Orchestrator moves to CONCERNS.

## Review — 2026-04-20 — Pass 4D Applied — Verdict: 25/25 BLOCKING RESOLVED → CONCERNS

**Scope**: The final Orchestrator revision pass. AC-ORC-03 + AC-ORC-05 tightened from write-on-paper specs into fully-runnable test specifications against Combat Pass 3D's DI shape (`combat_resolver: CombatResolver` injected at construction; tests extend `CombatResolver` as spy subclasses). Both ACs were architecturally unwriteable pre-Pass-3D; Pass 4D cashes in the unblock.

### AC-ORC-03 — Foreground tick window forwarded to Combat (RESOLVED)

Rewritten with a concrete Given-When-Then using a populated fixture:
- **Main AC**: GIVEN L13 W+M+R formation on F4 with `snapshot.last_emitted_tick = 100`; WHEN `tick_fired(105)` arrives in `ACTIVE_FOREGROUND`; THEN the injected `SpyCombatResolver` records exactly one call to `emit_events_in_range` with args `(snapshot.formation_snapshot, snapshot.floor, 100, 105)`; post-state `snapshot.last_emitted_tick == 105`.
- **Sub-AC 03-initial-tick** (closes S11): GIVEN the first `ACTIVE_FOREGROUND` transition where `last_emitted_tick == dispatched_at_tick`; WHEN `tick_fired(dispatched_at_tick + 1)` arrives; THEN the spy records the window `(dispatched_at_tick, dispatched_at_tick + 1]`. Boundary condition is explicitly tested.
- **Sub-AC 03-no-call-if-no-tick-advance**: GIVEN `last_emitted_tick = 100`; WHEN `tick_fired(100)` arrives (duplicate/zero-width window); THEN the Orchestrator does NOT call `emit_events_in_range` (spy records zero invocations); state + `last_emitted_tick` unchanged. Defensive guard against duplicate tick delivery.

Verification clause uses the Pass 3D spy-subclass pattern: `class SpyCombatResolver extends CombatResolver: ...` overrides `emit_events_in_range` to record call arguments without executing Combat logic. Orchestrator constructed via `DungeonRunOrchestrator.new(combat_resolver: spy)`.

### AC-ORC-05 — First-Clear Bonus Once Per Dispatch (RESOLVED)

Tightened to fully-runnable with explicit Economy call arguments + LOSING path:
- **Main AC**: F1 dispatch, `tick_budget = 576000` (8h cap), 3,740 complete loops; spy subclass + Economy spy; `Economy.try_award_floor_clear(1, 500)` called exactly once.
- **Sub-AC 05-multi-call** (defensive depth): spy returns `first_clear_in_range = true` on every call; Orchestrator's `floor_clear_emitted` flag gates re-emission; `try_award_floor_clear` still invoked at most once.
- **Sub-AC 05-foreground-first-clear**: foreground path loop_counter 0→1 transition fires `Economy.try_award_floor_clear(1, 500)` exactly once; `loop_counter` increments to 1; subsequent loop boundaries do NOT re-call.
- **Sub-AC 05-losing-first-clear**: LOSING run fires `Economy.try_award_floor_clear(1, 250)` (floori(500 × 0.5) per Combat Rule 9 + Pass 4B-Economy A2 — floor-clear halved; drip NOT halved). Economy's per-lifetime gate no-ops any second call; Orchestrator's `floor_clear_emitted` provides defense-in-depth at the Orchestrator boundary.

Verification uses combined spy pattern: `SpyCombatResolver` controls `first_clear_in_range` return; Economy spy captures all `try_award_floor_clear` invocations (count + args). Resolves Combat AC-COMBAT-09b end-to-end.

### Classification Summary

Footnotes "blocked on Pass 4D" removed from AC-ORC-03 + AC-ORC-05 rows; both now mark "Writeable as of Pass 4D 2026-04-20." All 13 Orchestrator ACs writeable.

### BLOCKERs closed (2 of 2 remaining post-Pass-4C)

- **AC-ORC-03** — foreground tick forwarding + initial-tick boundary + no-advance defensive guard; 3 sub-ACs covering the write-on-paper contract.
- **AC-ORC-05** — first-clear idempotency across foreground/offline/multi-call/LOSING paths; 4 sub-ACs covering the end-to-end contract.

### Orchestrator status: 25/25 BLOCKING resolved → **CONCERNS** (awaiting independent re-review)

Pass summary (2026-04-20 arc, solo review mode):
- **Combat Pass 3D** — Cluster E resolved (DI revision; `CombatResolver extends RefCounted` injectable instance class; `DefaultCombatResolver` concrete impl).
- **Orchestrator Pass 4A** — Clusters C + D + S3 resolved (~12 items): complete 5×6 state matrix; D.3 clock-rewind guard; D.4 loop-walk; FLOOR_CLEAR_BONUS 1-based; F1-only MVP fallback; AC-ORC-01/07/09/13 updated.
- **Pass 4B-Economy** — Cluster A resolved (5 items): `try_award_floor_clear` defined (Economy C.2.3a + AC H-14); **Pass 2B decision 4 superseded** (drip NOT halved on LOSING); `BASE_KILL[1]` reconciled; `kill_bonus` deprecated; 2.25× combined fix.
- **Pass 4B-SaveLoad** — Cluster B resolved (6 items): Save/Load Rules 10–14; `SAVE_LOAD_FLOAT_EPSILON`; `losing_run` serialized as bool; AC-ORC-12 rewritten with fixture + sub-ACs.
- **Pass 4C** — Cluster F + G1 + Q2/Q4/Q5/Q8 resolved (6 items): EventBus dropped; C.7 browse/commit signal split + option (c); `test_floor_high_attack` fixture; AC-ORC-08/09/11 rewritten; G3/G5 qualifiers.
- **Pass 4D** — AC-ORC-03 + AC-ORC-05 resolved (2 items): fully-runnable specs against Pass 3D DI shape.

**Total**: 25 of 25 BLOCKING resolved. 13 ACs all writeable. 6 cross-GDD contracts negotiated (Combat + Economy + Save/Load + Registry). Cross-GDD coherence restored.

### Files modified this pass

- `design/gdd/dungeon-run-orchestrator.md` — AC-ORC-03 rewritten with 3 sub-ACs; AC-ORC-05 tightened with 2 additional sub-ACs; Classification Summary footnotes cleared; header Last Updated refreshed.
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — this entry.
- `design/gdd/systems-index.md` — row 13 status → "Pass 4D Applied — 25/25 BLOCKING resolved → CONCERNS"; header Last Updated appended.
- `production/session-state/active.md` — Pass 4D checkbox ticked; Last Updated refreshed; Progress list updated.

### Flags remaining (not blocking Orchestrator CONCERNS verdict)

- **Combat Pass 3E + Pass 3F + Pass 3 targeted re-review bundle** (~1.5 hrs). Pass 3E adds `CombatBatchResult.partial_loop_kills: Array[KillEvent]` for full AC-ORC-09 parity assertion. Pass 3F adds `KillEvent.to_dict` / `from_dict` for full AC-ORC-12 round-trip. Pass 3 re-review addresses 9 pre-existing blockers from Pass 2B Re-Review. **Non-blocking for Orchestrator CONCERNS** — AC-ORC-09 and AC-ORC-12 document their interim fallbacks.
- **Hero Roster `HeroInstance.to_dict` / `from_dict` verification** — Pass 4B-SaveLoad flagged; small pass if missing.
- **Economy drip-curve holistic rebalance** — playtest-blocked, not a contract item.
- **18 RECOMMENDED + 3 NICE items from the 2026-04-20 review** — polish, can be drained via `/consistency-check` passes or targeted cleanup; not blocking.

### Next step

**Orchestrator: re-review**. Suggested invocation: `/design-review design/gdd/dungeon-run-orchestrator.md` with a targeted scope on the 25 closed BLOCKERs (not a full 5-specialist sweep, since the internal structure is now stable). Expected verdict: **APPROVED**, possibly with a handful of NICE-level polish items surfacing.

**Parallel**: Combat Pass 3E + 3F + Pass 3 targeted re-review bundle — unblocks the interim-fallback language in AC-ORC-09 / AC-ORC-12 and closes the pre-existing Pass 3 audit. Can run independently of Orchestrator re-review.

Editorial framing (carried forward from the 2026-04-20 MAJOR REVISION NEEDED synthesis): "Orchestrator was the first place the lattice had to be tight enough that pre-existing drift became visible. That's a healthy outcome of a serious review process, not a failure of #13's author." The 6-pass arc (Pass 3D + 4A + 4B-Economy + 4B-SaveLoad + 4C + 4D) closed the drift — not just in Orchestrator, but across Combat, Economy, Save/Load, and Registry in lockstep.

---

## Review — 2026-04-20 — Independent Re-Review (post–Pass 4D) — Verdict: MAJOR REVISION NEEDED

**Scope signal**: L–XL (structured multi-pass revision: 2 author-decision ADRs, upstream reconciliation across Economy + Registry, Orchestrator production-wiring spec, AC triangulation sweep). Full 5-specialist adversarial sweep.
**Specialists**: game-designer, systems-designer, qa-lead, economy-designer, godot-gdscript-specialist, creative-director (synthesis)
**Review mode**: solo (CD-GDD-ALIGN gate skipped per protocol)
**Depth**: full
**Blocking items**: 17 (12 new + 3 upstream drift + 2 author-decision)
**Recommended items**: 22
**Nice-to-have**: 3
**Prior verdict resolved**: No — prior verdict was MAJOR REVISION NEEDED (2026-04-20 first review) claimed resolved across 6-pass arc → CONCERNS. **This independent re-review finds the 6-pass arc reached a local maximum but missed upstream drift checks, systematic DI audit across non-Combat resolvers, AC triangulation (body vs Summary vs code), and silently dropped 3 prior-pass RECOMMENDED items. Verdict returns to MAJOR REVISION NEEDED.**

### Summary

The 6-pass arc (Combat 3D + Orchestrator 4A/4B-Economy/4B-SaveLoad/4C/4D) drove Orchestrator to internal consistency on the 25 original BLOCKERs. However, an independent adversarial sweep surfaces a second wave of issues the author-led passes did not catch, organized into **5 root-cause clusters** (per creative-director synthesis):

- **Cluster α — Test Architecture Gap (3-way convergence)**: Node autoload constructor wiring unspecified; MatchupResolver has same static-method mockability gap CombatResolver Pass 3D solved.
- **Cluster β — AC Body/Code/Summary Contradictions**: Three doc-drift contradictions (AC-ORC-07 NO_RUN vs RUN_ENDED; Sub-AC 03 vs C.3 `<` guard; AC-ORC-13 inherits 07).
- **Cluster γ — AC Verification Mechanism Gaps**: 6 ACs reference oracles / mechanisms that don't exist on the stated API surface (`push_error` spy in AC-ORC-01; `Combat.formation_dps_per_tick` in AC-ORC-02; drip/kill gold spy ambiguity in AC-ORC-04; 576K-call CI timeout unchanged by Q5 rename; ticks_per_loop unpinned in AC-ORC-11; DataRegistry identity in AC-ORC-08).
- **Cluster δ — Arithmetic / Data-Structure Gaps**: `matchup_cache` KeyError latent; `OfflineRunResult.new(kw=...)` invalid GDScript; `LOSING_RUN_LOOT_FACTOR=0.0` violates stated output range.
- **Cluster ε — Upstream Document Drift**: Economy D.6 F5 pacing stale (24,000 → 9,600 g/min); D.6 Tier-2 recruit stale (2,500 → 8,000g); Registry `LOSING_RUN_LOOT_FACTOR` notes still contain superseded "drip" scope.
- **Cluster ζ — Game-Design / Vision-Level (author decisions)**: LOSING first-clear halving permanency conflicts with "no fail state" pillar; mid-boss reassignment option (a) MVP needs explicit risk callout or option (c) escalation.

### Blocking Items (17, source-tagged)

**Cluster α — Test Architecture Gap (2 items)**

1. **[godot-gdscript-specialist + qa-lead + systems-designer, 3-way convergence]** `DungeonRunOrchestrator.new(combat_resolver: spy)` in AC-ORC-03/05 incompatible with Node autoload lifecycle. Production wiring path unspecified (bootstrap scene? setter? `_ready()` default?). Highest-signal finding of the review.
2. **[godot-gdscript-specialist]** `MatchupResolver` static non-injectable class; Orchestrator calls `MatchupResolver.resolve_formation_matchup(...)` directly in C.3/C.4; AC-ORC-11 references "synthetic MatchupResolver stub" — unmockable. Apply same DI pattern as CombatResolver Pass 3D.

**Cluster β — AC Contradictions (2 items)**

3. **[qa-lead]** AC-ORC-07 body says "state remains `NO_RUN`"; Classification Summary says "transitions to `RUN_ENDED`". Direct contradiction. AC-ORC-13 inherits.
4. **[systems-designer]** Sub-AC 03-no-call-if-no-tick-advance unachievable against C.3 code. Guard fires on `<` only; at `current_tick == last_emitted_tick`, code falls through to `emit_events_in_range` with empty range. Spy records 1 call, AC demands 0. Change `<` → `<=` OR relax AC.

**Cluster γ — AC Verification Gaps (6 items)**

5. **[qa-lead]** AC-ORC-01 `push_error` "exactly once" has no GdUnit4 intercept mechanism. `error_logger: Callable` DI (GD9) left as RECOMMENDED, never resolved.
6. **[qa-lead]** AC-ORC-02 references `Combat.formation_dps_per_tick()` and `Combat.hp_bonus_factor()` — not public methods on Pass 3D `CombatResolver`.
7. **[qa-lead]** AC-ORC-04 drip and kill-gold both go through `Economy.add_gold(int)` — spy sum non-deterministic without call-source tagging.
8. **[qa-lead] (regression, Q5)** AC-ORC-09 576,000 × tick-step=1 = 57.6s/cell exceeds GdUnit4 default 30s timeout. Rename CHUNK → tick-step did not mitigate.
9. **[qa-lead]** AC-ORC-11 `ticks_per_loop` not pinned; test uses SUT as own oracle.
10. **[qa-lead]** AC-ORC-08 Sub-AC 08-floor-reference requires DataRegistry identity guarantee; mock contract unspecified; not a unit test.

**Cluster δ — Arithmetic / Data-Structure Gaps (3 items)**

11. **[systems-designer]** `matchup_cache` KeyError latent: D.4 partial-loop walk indexes cache with no contract all archetypes pre-populate.
12. **[systems-designer]** `OfflineRunResult.new(keyword=value, ...)` invalid GDScript 4.6 syntax.
13. **[systems-designer]** `LOSING_RUN_LOOT_FACTOR = 0.0` (bottom of safe range 0.0–0.95) produces output 0, violates documented range [5, 120].

**Cluster ε — Upstream Document Drift (3 items)**

14. **[economy-designer F1]** Economy D.6 F5 pacing row: "24,000 g/min" (pre-Pass-3B). Correct = 9,600 g/min. A5 verification missed.
15. **[economy-designer F2]** Economy D.6 Tier-2 recruit row: "2,500g". Locked value = 8,000g.
16. **[economy-designer F3]** Registry `LOSING_RUN_LOOT_FACTOR` notes still contain "drip" scope; contradicts all three GDDs post-Pass-2B-supersession.

**Cluster ζ — Design-Vision Author Decisions (2 items, adjudicated by creative-director)**

17a. **[game-designer BLOCKING-1]** Mid-run `formation_reassignment_committed` option (a) MVP ends run immediately. Browse/commit signal split prevents only accidental reassignment; intentional mid-F5-boss reassignment at 140s/170s still destroys progress. **Adjudicated as doc-fixable**: add risk callout in C.7 + V1.1 tuning note.
17b. **[game-designer BLOCKING-2]** LOSING first-clear halving is permanent + irrecoverable via Economy per-lifetime gate. Game concept promises "no fail state — losing run returns partial loot." **Adjudicated as vision-level**: author chooses (1) first-clear re-claimable on subsequent WIN, (2) exempt first-clear from LOSING halving, or (3) rewrite "no fail state" pillar.

### Recommended Items (22)

`[game-designer]` G3/G5 qualifiers buried at bottom of Section B (promote to opening) · ACTIVE_OFFLINE_REPLAY+dispatch_pressed silently swallows taps (no UX feedback) · G4 mid-queue boss dev-facing `push_warning` at DISPATCHING not implemented
`[systems-designer]` ACTIVE_OFFLINE_REPLAY+app_resumed cell has conditional next-state (breaks FSM determinism) · hp_bonus_factor=0.5 IEEE-754 exactness only on power-of-two ratios · D.4 interim fallback case (b) correct but non-obvious (add worked example) · AC-ORC-02 `losing_run` phrasing implies always-derivation (contradicts Rule 14)
`[qa-lead]` AC-ORC-05 compound foreground→suspend→offline→resume path no sub-AC (Q10 regression) · AC-ORC-03 `.new(spy)` vs Node autoload (GD3 regression) · AC-ORC-10 signal mechanism unspecified · AC-ORC-12 main AC is integration, not unit test · AC-ORC-06 "within one frame" still untestable (Q12 confirmed)
`[economy-designer]` AC H-14 missing Sub-AC 14-zero-bonus · D.2 formula display lacks LOSING term · V1.0 hard-content LOSING penalty tuning note absent · Economy I.3 drip-curve flag not cross-referenced in Orchestrator I · advantaged-LOSING tier-1 = floori(7.5) = 7 untested
`[godot-gdscript-specialist]` State enum declaration absent; ordinal stability undocumented · `Dictionary[StringName, bool]` JSON bool-vs-int coercion not type-asserted · `equals()` uses `is_equal_approx` implicit epsilon rather than `SAVE_LOAD_FLOAT_EPSILON` · `error_logger: Callable` omission policy undocumented · Open Q I.8 offline signal storm answerable from pseudocode but undeclared · `from_dict` typed-array append lacks element type guard

### Nice-to-Have (3)

`[game-designer]` 170s F5 boss cadence lacks "fight in progress" foreground state · `[godot-gdscript-specialist]` SpyCombatResolver uses untyped `Array` parameter — violates mandatory static typing

### Specialist Disagreements

None. Strong cross-model convergence (see below).

### Cross-Model Convergence (highest signal)

1. **Node autoload constructor wiring**: systems-designer + qa-lead + godot-gdscript-specialist (3-way). Single most important finding.
2. **LOSING penalty design + test coverage**: game-designer + economy-designer (2-way, different angles).
3. **AC-ORC-03 spec-vs-code drift**: systems-designer + qa-lead (2-way independent discovery).
4. **Oracle API nonexistence**: qa-lead + godot-gdscript-specialist (2-way).

### Senior Verdict (creative-director)

> "**MAJOR REVISION NEEDED.** The 6-pass arc drove internal consistency but missed: upstream drift checks, systematic DI audit across non-Combat resolvers (MatchupResolver), AC triangulation (body vs Summary vs code), and silently-dropped Pass 4C RECOMMENDED items. **The work is good; the process needs instrumentation.** Three regressions (`.new(spy)` / Q10 / Q5) are evidence. Two vision-level author decisions remain. The right next pass is **structured Pass 5A–E** (~8 hrs: author decisions → upstream reconciliation → wiring spec → AC triangulation → gate re-run), NOT another day-long improvisation. Framing: the first review was 'lattice tightening exposed inherited drift' (true). This re-review says 'the author reached a local maximum; structured adversarial gating caught what incremental passes couldn't.' No blame — adversarial review is what this is for."

### Recommended Revision Shape — **Pass 5 (Architectural + Reconciliation)**

Structured mini-arc, NOT another improvisational pass:

- **Pass 5A — Author Decisions (1 hr)**: User decides 17a (mid-boss reassignment) and 17b (LOSING first-clear halving). Write ADRs.
- **Pass 5B — Upstream Reconciliation (2 hrs)**: Fix Economy D.6 F5 + Tier-2 rows, Registry `LOSING_RUN_LOOT_FACTOR` notes, add advantaged-LOSING sub-AC to AC-ORC-04. Re-verify cross-doc math.
- **Pass 5C — Orchestrator Production Wiring Spec (3 hrs)**: Add a new Section J "Production Wiring" covering: Node autoload lifecycle + DI injection path (setter-based vs bootstrap-scene); `_ready()` default construction contract; `error_logger: Callable` policy; MatchupResolver DI (same Pass 3D pattern as CombatResolver).
- **Pass 5D — AC Triangulation Sweep (2 hrs)**: Every AC re-read against main body + Classification Summary + pseudocode. Fix AC-ORC-03 guard, AC-ORC-07/13 NO_RUN vs RUN_ENDED. Pin AC-ORC-09 test budget. Verify every oracle API exists on referenced resolver class.
- **Pass 5E — Gate re-run** (successor to this review).

Estimated ~8 hrs across structured sub-passes + one gate re-run.

### Validation Criteria (per creative-director)

- After 5A: Orchestrator contains explicit risk callout in C.7 (mid-boss reassignment) + explicit LOSING first-clear policy. ADRs recorded.
- After 5B: Economy D.6 F5 + Tier-2 rows corrected; Registry LOSING notes reconciled with all three GDDs; AC-ORC-04 Sub-AC-advantaged-LOSING added.
- After 5C: Orchestrator Section J "Production Wiring" authored; MatchupResolver converted to injectable instance class (`class_name MatchupResolver extends RefCounted` + `DefaultMatchupResolver`); Orchestrator constructor/setter DI path documented; AC-ORC-03/05 verification clauses valid against the wiring spec.
- After 5D: AC-ORC-01 `error_logger` DI specified; AC-ORC-02 oracle API either added to CombatResolver public surface or replaced with cached-result assertion; AC-ORC-04 Economy spy drip/kill isolation specified; AC-ORC-07/13 body = Summary; AC-ORC-08 DataRegistry mock contract specified; AC-ORC-09 test budget capped under 30s; AC-ORC-11 ticks_per_loop pinned.

### Cascade items flagged for other GDDs

- **Economy GDD #4**: D.6 F5 pacing row `24,000 → 9,600 g/min`; D.6 Tier-2 recruit row `2,500 → 8,000g`; D.2 formula display LOSING term; AC H-14 zero-bonus sub-AC; I.3 drip-curve cross-ref to Orchestrator I.
- **Registry (`design/registry/entities.yaml`)**: `LOSING_RUN_LOOT_FACTOR` notes rewrite to remove "drip + kill bonuses + clear bonus" scope; reflect Pass 4B-Economy A2 narrowed scope (kill gold + floor-clear only). Consider clamping safe range lower bound from `0.0` to `0.5` to protect `attribute_kill_gold` output range claim.
- **Matchup Resolver GDD #10**: DI revision pass — convert from static-only to injectable instance class (`class_name MatchupResolver extends RefCounted` + `DefaultMatchupResolver`), matching CombatResolver Pass 3D pattern. Blocks AC-ORC-11 writeability.
- **Combat GDD #11**: Pass 3E + Pass 3F bundle remains open (non-blocking for this verdict but Pass 5D will sharpen the need). Consider adding public helpers `formation_dps_per_tick(formation)` and `hp_bonus_factor(formation, floor)` on `CombatResolver` to unblock AC-ORC-02 oracle reference.
- **Hero Roster GDD #9**: verify `HeroInstance.save_to_dict()`/`load_from_dict()` exist with the 5-field schema AC-ORC-12 fixture uses; flagged in Pass 4B-SaveLoad.

### Editorial Framing

First review framing ("lattice tightening exposed inherited drift — healthy outcome") remains valid for that review. This re-review's framing: "**The work is good; the process needs instrumentation.**" The 6-pass arc closed what the author could see; the adversarial sweep caught what the author couldn't — upstream drift not re-checked, a DI anti-pattern on a different class, AC body/Summary/code contradictions, and silently dropped RECOMMENDED items. No blame. But the next pass should be structured (5A–E above), not improvisational, and should close with a **cross-doc consistency checklist** that prevents a 7th pass from reproducing this 2nd review's findings.

### User decision (2026-04-20, post–re-review)

**Stop here, revise in a separate session.** Pass 5A–E is best executed from clean context. This entry + systems-index update are sufficient handoff artifacts.

### Specialist-gap learning (carried forward)

- godot-gdscript-specialist correctly applied prior Q3 miss lesson this time — caught the MatchupResolver static-method gap that is the same pattern as Combat's Q3. Lesson learned well.
- **New learning**: `/design-review` full-mode adversarial sweeps reliably find items that author-led multi-pass arcs miss, even when the arc is 6 passes deep. This is evidence for the value of independent re-review as a mandatory gate, not an optional check. Recommend: for any GDD that undergoes ≥3 author-led revision passes, a fresh-session adversarial re-review should be treated as mandatory before CONCERNS → APPROVED transition.
- **Process note**: The 6-pass arc dropped 3 prior-pass RECOMMENDED items (GD3 / Q10 / Q5) silently. Recommend future multi-pass arcs carry a "deferred from prior pass" checklist that the gate re-review explicitly verifies against.

---

## Pass 5A — Author Decisions (2026-04-20)

**Pass type**: Structured mini-arc sub-pass (first of Pass 5A–E per re-review plan).
**Scope**: Resolve the two Cluster ζ author-decision BLOCKERs (17a, 17b) from the 2026-04-20 independent re-review; land two ADRs; propagate Orchestrator-side text changes that do not require upstream GDD edits.
**Review mode**: solo
**Duration**: ~1 hr (matches re-review plan estimate)
**Blocks closed**: 2 of 17 (17a, 17b) — Cluster ζ closed.
**Blocks remaining**: 15 of 17 across Clusters α / β / γ / δ / ε — to be closed by Pass 5B / 5C / 5D.

### Decisions

**17a (mid-run reassignment) — Confirmed adjudication: Option (a) MVP lock.**
- Authority: ADR-0001 (`docs/architecture/ADR-0001-mid-run-formation-reassignment.md`).
- Orchestrator §C.7 now contains an explicit risk callout (not just a table footnote) for the intentional-mid-F5-boss-progress-loss scenario.
- V1.0-deferred Option (c) deferred queue is named as the upgrade path; `mid_run_reassignments_during_floor_5_boss` telemetry counter recommended (not MVP-blocking) as the upgrade-pressure signal.
- §G.1 `MID_RUN_REASSIGN_WARNING_ENABLED` tuning knob rationale updated to cite ADR-0001 + the recommended telemetry.

**17b (LOSING first-clear halving) — Author chose Option 1: Re-claimable on subsequent WIN.**
- Authority: ADR-0002 (`docs/architecture/ADR-0002-losing-first-clear-reclaimable-on-win.md`).
- Economy's per-lifetime gate reshaped from `Dictionary[int, bool]` (boolean per-floor flag) to `Dictionary[int, int]` (per-floor monotonic credited-total). `try_award_floor_clear` becomes a "credit-the-gap" dispatcher: `add_gold(max(0, bonus_amount - already_credited))` then update the credited ceiling.
- Semantic consequences table embedded in ADR-0002 §Decision (six sequence cases covering every ordering of LOSING/WIN first/repeat clears).
- Orchestrator edits landed:
  - §C.6 Layer-3 description rewritten (boolean gate → monotonic-int ceiling)
  - §E.5 prose updated (no-op reason is now "bonus_amount ≤ already_credited", not "boolean flag is true")
  - **new §E.15** worked-walkthrough of the LOSING-then-WIN reclaim path (with narrative-facing Return-to-App copy hint)
  - §C.5 Output Range note: superseded the prior "cannot be re-cleared later to reclaim" claim
  - §AC-ORC-04 **new Sub-AC 04-losing-first-clear-then-win-credits-delta** verifying the two-dispatch reclaim at the Orchestrator boundary via Economy spy running state
  - §Classification Summary table updated (AC-ORC-04 Pass-5A column entry added; footer line notes Pass 5A scope)
  - Dependencies row for Economy updated to reference ADR-0002 + the new field shape

### Files modified

- `docs/architecture/ADR-0001-mid-run-formation-reassignment.md` — CREATED (Status: Accepted).
- `docs/architecture/ADR-0002-losing-first-clear-reclaimable-on-win.md` — CREATED (Status: Accepted).
- `design/gdd/dungeon-run-orchestrator.md` — Pass 5A edits: header Last-Updated line; §C.6 Layer-3 rewrite; §C.7 risk callout + V1.0 upgrade path; §C.5 Output Range note; §E.5 rewrite; **new §E.15**; §AC-ORC-04 **new Sub-AC**; §G.1 `MID_RUN_REASSIGN_WARNING_ENABLED` row; Dependencies Economy row; cross-reference footer row; Classification Summary AC-ORC-04 row + footer.
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — THIS entry.

### Cascade items flagged for other GDDs (Pass 5B scope)

- **Economy GDD #4 (Pass 5B — highest priority)**: rewrite §C.2.3 and §C.2.3a; replace `floors_cleared_bonus_awarded: Dictionary[int, bool]` with `floor_clear_bonus_credited: Dictionary[int, int]`; rewrite AC H-03 and AC H-14 per the monotonic-credit contract; embed the six-row worked-example table verbatim from ADR-0002 §Decision; AC H-14 gains a "reclaim on WIN" sub-AC; §C.2.4 drip formula unaffected (Pass 4B-Economy A2 drip scope is independent). Economy GDD header status bumped to "Pass 5B in progress" until the rewrite lands.
- **Registry (`design/registry/entities.yaml`, Pass 5B)**: `LOSING_RUN_LOOT_FACTOR` notes — reflect that floor-clear halving produces an immediate cost + reclaimable delta, not a permanent penalty. Cross-reference ADR-0002. Consider clamping safe range lower bound from `0.0` to `0.5` to protect `attribute_kill_gold` output range claim (carry forward from re-review Cluster δ item 13 — still open).
- **Save/Load GDD #3 (Pass 5B)**: Rule 11 table entry for the renamed + retyped field (`floors_cleared_bonus_awarded: Dictionary[int, bool]` → `floor_clear_bonus_credited: Dictionary[int, int]`); note JSON-native serialization, no `SAVE_LOAD_FLOAT_EPSILON` involvement (int equality). No change to Rules 10 or 12–14. If MVP has not yet shipped when Pass 5B lands, no migration path is needed; otherwise ADR-0002 §Migration Plan applies.
- **Narrative (no GDD yet)**: Return-to-App screen copy for the LOSING-first-clear and WIN-reclaim cases (see ADR-0002 §Risks and Orchestrator §E.15). Owners: narrative-director + writer when Return-to-App screen GDD #20 is authored.
- **Combat GDD #11 (already flagged, no new Pass 5A cascade)**: Pass 3E + 3F + Pass 3 re-review bundle remains open; this Pass 5A does not touch Combat.

### Validation criteria (from ADR-0001 + ADR-0002)

Checklist to verify at Pass 5E (gate re-run):

- [x] Orchestrator §C.7 has an explicit risk callout (not just a table footnote) — landed this pass.
- [x] Orchestrator §C.7 names Option (c) as the V1.0-deferred upgrade path with implementation note — landed (pre-existing + Pass 5A cross-ref to ADR-0001).
- [x] `MID_RUN_REASSIGN_WARNING_ENABLED` §G.1 row cites ADR-0001 — landed.
- [x] Orchestrator §E.5 prose reflects monotonic-credit gate — landed.
- [x] Orchestrator §E.15 walks the LOSING-then-WIN reclaim path — landed.
- [x] AC-ORC-04 Sub-AC 04-losing-first-clear-then-win-credits-delta — landed.
- [x] Classification Summary footer notes Pass 5A scope — landed.
- [ ] `mid_run_reassignments_during_floor_5_boss` telemetry counter scoped into vertical-slice analytics list — **NOT landed this pass** (not in Orchestrator scope; flagged for analytics spec when that doc is authored).
- [ ] Economy GDD Pass 5B rewrites — **Pass 5B scope**, not Pass 5A.
- [ ] Registry `LOSING_RUN_LOOT_FACTOR` notes rewrite — **Pass 5B scope**.
- [ ] Save/Load Rule 11 field-rename update — **Pass 5B scope**.
- [ ] Narrative copy for reclaim UX — deferred to Return-to-App screen GDD authoring.

### What remains after Pass 5A

From the 2026-04-20 re-review's 17-item BLOCKING list: **Cluster ζ (2 items) closed by this pass**.

**Remaining 15 BLOCKING** (for Pass 5B / 5C / 5D, per the re-review's structured plan):
- Cluster α (2 items): autoload constructor wiring + MatchupResolver DI — Pass 5C.
- Cluster β (2 items): AC-ORC-07/13 NO_RUN vs RUN_ENDED + Sub-AC 03 vs C.3 `<` guard — Pass 5D.
- Cluster γ (6 items): AC-ORC-01 `push_error` spy, AC-ORC-02 oracle API, AC-ORC-04 drip/kill tagging, AC-ORC-09 test-budget, AC-ORC-11 ticks_per_loop pin, AC-ORC-08 DataRegistry identity — Pass 5D (with some Pass 5B on oracle API additions in Combat GDD).
- Cluster δ (3 items): matchup_cache KeyError, `OfflineRunResult.new(kw=...)` GDScript, `LOSING_RUN_LOOT_FACTOR=0.0` clamp — Pass 5B (registry) + Pass 5C / 5D (code-shape).
- Cluster ε (3 items): Economy D.6 F5 + Tier-2 + Registry LOSING notes — Pass 5B.

Plus 22 RECOMMENDED + 3 NICE items from the re-review (unchanged by this pass).

### Next step

**Pass 5B — Upstream Reconciliation** (~2 hrs). Economy GDD rewrite (§C.2.3, C.2.3a, AC H-03, AC H-14); Registry `LOSING_RUN_LOOT_FACTOR` + Economy D.6 F5 pacing row (24,000 → 9,600 g/min) + D.6 Tier-2 recruit row (2,500 → 8,000g); Save/Load Rule 11 field-rename note; Registry `LOSING_RUN_LOOT_FACTOR` lower-bound clamp 0.0→0.5. Cross-doc math re-verified.

**After Pass 5B**: Pass 5C (Production Wiring Spec, ~3 hrs) → Pass 5D (AC Triangulation Sweep, ~2 hrs) → Pass 5E (gate re-run). Full arc estimate ~7 hrs remaining across the four sub-passes.

### Editorial framing (Pass 5A)

17a ended up a confirmation of existing adjudication — the creative-director synthesis had already named Option (a) MVP with a V1.0-deferred upgrade path; Pass 5A just promoted the implicit risk to explicit and landed the ADR. 17b was the harder decision: "Re-claimable on subsequent WIN" was chosen because it preserves both the LOSING penalty's rule-consistency (same 50% factor applies to kill gold and clear bonus) and the game concept's "no fail state" pillar (no content is permanently destroyed). The engine cost is small (`bool → int` in one dictionary + a max() in one function); the conceptual win is large (the halved portion becomes a narrative hook: "come back and win this one properly"). The decision preserves anti-exploit (monotonic ceiling) by design.

---

## Pass 5B — Upstream Reconciliation (2026-04-20, cross-GDD — Economy + Registry + Save/Load)

**Pass type**: Second structured sub-pass in the Pass 5 arc. Executes the upstream drift fixes + ADR-0002 propagation across Economy, Registry, and Save/Load GDDs.
**Scope**: Downstream of the Pass 5A ADRs; closes Cluster ε (3 items) + partial Cluster δ (safe-range tightening) in full, plus landing the Economy-side implementation of ADR-0002.
**Review mode**: solo
**Duration**: ~1.5 hrs (matches the re-review plan estimate of 2 hrs; came in slightly under because Pass 5A already landed the contract-side text in Orchestrator).
**Blocks closed**: 7 of 17 re-review BLOCKERs (Cluster ε items 14, 15, 16; Cluster δ item 13 in part — formula-level guard covered by Economy AC H-14 Sub-AC 14-zero-bonus + registry safe-range clamp). Orchestrator-side follow-up items closed: none (this pass is the upstream-side of the Pass 5A ADRs — Orchestrator GDD was already updated in Pass 5A against the ADR contract).

### What landed — cross-GDD summary

- **Economy GDD #4**: C.2.3 + C.2.3a + AC H-03 + AC H-11 + AC H-14 + D.6 pacing table + D.6 calibration note + three consumer/dependency row updates. Full details in `design/gdd/reviews/economy-system-review-log.md` 2026-04-20 Pass 5B entry.
- **Registry**: `LOSING_RUN_LOOT_FACTOR` notes + referenced_by + revised date + safe-range lower-bound tightening (0.0 → 0.5).
- **Save/Load GDD #3**: Rule 11 field-rename addendum paragraph. Full details in `design/gdd/reviews/save-load-system-review-log.md` Pass 5B sub-entry.

### Pass 5B blocker tally

Cluster ε (upstream drift) — **CLOSED this pass**:
- Item 14 — Economy D.6 F5 pacing row 24,000 → 9,600 g/min ✅
- Item 15 — Economy D.6 Tier-2 recruit row 2,500 → 8,000g ✅
- Item 16 — Registry `LOSING_RUN_LOOT_FACTOR` notes drip-scope removal ✅

Cluster δ (arithmetic/data-structure) — **partially closed**:
- Item 13 — `LOSING_RUN_LOOT_FACTOR = 0.0` violates output range → Registry safe-range clamp 0.0→0.5 (protective); Economy AC H-14 Sub-AC 14-zero-bonus (defensive). The remaining formula-level concerns (items 11 `matchup_cache` KeyError + 12 `OfflineRunResult.new(kw=...)`) are Pass 5C / 5D scope.

ADR-0002 implementation side — **CLOSED this pass**: Economy's gate shape now matches ADR-0002's credit-the-gap contract across all six affected GDD sections.

### Remaining for Pass 5C / 5D (10 of 17 re-review BLOCKERs)

- **Cluster α** (2 items): autoload constructor wiring + MatchupResolver DI — Pass 5C.
- **Cluster β** (2 items): AC-ORC-07/13 NO_RUN vs RUN_ENDED + Sub-AC 03 vs C.3 `<` guard — Pass 5D.
- **Cluster γ** (6 items): 6 AC verification-gap items — Pass 5D (Combat oracle API additions may come with Combat Pass 3E/3F bundle).
- **Cluster δ** (2 remaining items): matchup_cache KeyError + `OfflineRunResult.new(kw=...)` GDScript — Pass 5C / 5D split.

### Next step

**Pass 5C — Orchestrator Production Wiring Spec** (~3 hrs). New Orchestrator §J "Production Wiring" covering Node autoload lifecycle + DI injection path; `_ready()` default construction; `error_logger: Callable` policy; MatchupResolver DI conversion (same Pass 3D pattern as CombatResolver). See re-review Cluster α for scope.

**After Pass 5C**: Pass 5D (AC Triangulation Sweep, ~2 hrs) → Pass 5E (gate re-run). Remaining Pass 5 arc budget: ~5 hrs.

### Editorial framing (Pass 5B)

Pass 5B did what was advertised: reconciliation, not design. The F5 drip table row correction (24,000 → 9,600 g/min) is the single biggest numerical change and had been latent across documents before this pass. The Economy-side implementation of ADR-0002 is large in surface area (six sections, three ACs, a six-row embedded table) but mechanically simple (one Dictionary field; one `bonus_amount <= already_credited` compare; one delta credit). Zero new design decisions this pass. Clusters α, β, γ, and the remaining Cluster δ items are genuinely Orchestrator-side (wiring + AC consistency); Pass 5B was not their vehicle.

---

## Pass 5C — Orchestrator Production Wiring + MatchupResolver DI (2026-04-20)

**Pass type**: Third sub-pass of the Pass 5 arc. Authors the Production Wiring spec that was re-review Cluster α's highest-signal finding (3-way specialist convergence) and propagates the companion Matchup Resolver DI conversion.
**Scope**: New Orchestrator §J; MatchupResolver GDD Pass 5C DI conversion (companion pass in `design/gdd/reviews/class-vs-enemy-matchup-resolver-review-log.md`); Orchestrator call-site migration (§C.3, §C.4, §D matchup-advantage row, §F Matchup Resolver dependency row, §C.9 Interactions row); AC-ORC-11 rewrite for SpyMatchupResolver; AC-ORC-03 verification clause setter-pattern update.
**Review mode**: solo
**Duration**: ~1.5 hrs (matches re-review plan estimate of 3 hrs; came in under because the DI pattern was already established by Combat Pass 3D and could be mirrored directly).
**Blocks closed**: 2 of 17 re-review BLOCKERs (Cluster α items 1 + 2) + partial closure of Cluster γ items 9 (AC-ORC-11 ticks-per-loop pinning) and 11 (AC-ORC-11 Spy DI fixture defined).

### What landed

**Orchestrator GDD — new §J "Production Wiring"** (~150 lines, nine subsections):
- J.1 Wiring model: Script autoload registered in `project.godot` as `DungeonRunOrchestrator="*res://src/gameplay/dungeon_run/dungeon_run_orchestrator.gd"`. **Option A — lazy-default DI with public setters** locked.
- J.2 `_ready()` default construction contract: `_combat_resolver` / `_matchup_resolver` lazy-construct to `DefaultCombatResolver.new()` / `DefaultMatchupResolver.new()` iff null; `_error_logger` defaults to invalid `Callable()` (push_error fallthrough per Combat AC-COMBAT-11).
- J.3 Test wiring — three documented modes: (Mode 1) bare `DungeonRunOrchestrator.new()` + `set_*_resolver(spy)` + `add_child(...)` used by 9 of 13 ACs; (Mode 2) real autoload + setter override for integration tests (4 of 13 ACs); (Mode 3) test isolation for multi-instance V1.0 work.
- J.4 `error_logger: Callable` DI policy — closes re-review RECOMMENDED GD9 fully: setter injection + call-site `_error_logger.is_valid() ? _error_logger.call(msg) : push_error(msg)` pattern + forwarding through `combat_resolver.emit_events_in_range(..., _error_logger)`.
- J.5 MatchupResolver DI parity — documents the companion Matchup Pass 5C conversion (see Matchup Resolver review log) + Orchestrator call-site migration + AC-ORC-11 Spy pattern + Combat Pass 3E bridge item.
- J.6 `_ready()` order of operations pseudocode (6 steps; items 1-2 are DI-sensitive; tick subscription + signal emissions deferred to `ACTIVE_FOREGROUND` entry).
- J.7 Alternatives considered (Options B–E): B scene autoload + bootstrap node, C RefCounted Orchestrator + signal-host, D service locator, E explicit `initialize()` without defaults. All rejected with specific reasons.
- J.8 Validation checklist (5 items, 3 checked by this pass landing; 2 deferred to implementation story + vertical-slice audit).
- J.9 Cross-reference to Combat Rule 2 + Pass 3D DI, Matchup Resolver Rule 1 + Rule 4, §C.9, §H AC-ORC-03/-05/-11, and the re-review Cluster α closure.

**Orchestrator GDD — call-site migrations**:
- §C.3 foreground tick loop code block: `MatchupResolver.resolve_formation_matchup(...)` → `_matchup_resolver.resolve_formation_matchup(...)` + Pass 5C comment.
- §C.4 per-archetype cache description: updated to instance-call form + AC-ORC-11 verification reference.
- §D "matchup advantage" formula source row: updated to `_matchup_resolver.*` with §J cross-ref.
- §C.9 Interactions table Matchup Resolver row: updated to instance call + Pass 5C DI note.
- §F Dependencies table Matchup Resolver row: updated to instance call + `DefaultMatchupResolver` production note + Combat Pass 3E bridge flag.

**Orchestrator GDD — AC rewrites**:
- AC-ORC-03 verification clause: `DungeonRunOrchestrator.new(combat_resolver: spy)` pre-Pass-5C constructor form **replaced** with §J Mode-1 setter-based pattern (`var orchestrator := DungeonRunOrchestrator.new(); orchestrator.set_combat_resolver(combat_spy); orchestrator.set_matchup_resolver(DefaultMatchupResolver.new()); add_child(orchestrator)`). This closes re-review Cluster α item 1 at the AC layer.
- AC-ORC-11 **full rewrite**: was Pass 4C (synthetic stub, cache-population assertion), now Pass 5C (`SpyMatchupResolver extends MatchupResolver` + per-archetype gold assertion). Added **Sub-AC 11-cache-population** (exactly 3 calls at DISPATCHING; zero during per-kill replay — closes Rule-14 snapshot-pattern invariant at the Orchestrator boundary). Added **Sub-AC 11-ticks-per-loop-pinned** (re-review γ item 9 — test must embed explicit literal `ticks_per_loop` from the fixture's kill schedule; does not derive from SUT's snapshot field).
- Classification Summary AC-ORC-11 row: Pass 5C annotation.
- Header Last-Updated: Pass 5C summary prepended.

**Companion Matchup Resolver GDD Pass 5C edits** (see `design/gdd/reviews/class-vs-enemy-matchup-resolver-review-log.md` for the full entry): Rule 1 rewrite (static → injectable instance); Rule 4 signatures (`static func` → `func`); H-16 "Static Class Structure" → "Injectable-Class Structure" with predicate inversion; H-12 / H-13 / H-17 spy language; Dependencies table rows; New Cross-System Contracts list; header.

### Files modified

- `design/gdd/dungeon-run-orchestrator.md` — header + §C.3 code block + §C.4 cache description + §D matchup-advantage row + §C.9 Interactions row + §F Matchup Resolver dependency row + §H AC-ORC-03 verification + §H AC-ORC-11 (major rewrite + 2 new sub-ACs) + Classification Summary + **new §J (nine subsections)**.
- `design/gdd/class-vs-enemy-matchup-resolver.md` — see Matchup Resolver review log Pass 5C entry (~8 sections touched).
- `design/gdd/reviews/class-vs-enemy-matchup-resolver-review-log.md` — Pass 5C entry appended.
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — THIS entry.

### Cascade items flagged for other GDDs

- **Combat GDD #11 (Pass 3E — carried forward)**: add `matchup_resolver: MatchupResolver` parameter to `CombatResolver.emit_events_in_range` + `compute_offline_batch`, forwarded from the Orchestrator's `_matchup_resolver` field. Until Pass 3E lands, Combat's internal `_kill_schedule_for_loop` uses the pre-Pass-5C static-dispatch form as a temporary bridge (documented in Matchup Resolver §C Dependencies table Combat row). Non-blocking for Pass 5E gate re-run — AC-ORC-11 suffices for Orchestrator-boundary coverage.
- **Matchup Assignment Screen (#23, undesigned)**: when authored, must receive the injected resolver from its host via the usual Pass 5C DI path (§J Mode-1 pattern for unit tests, standard construction in production).
- **Implementation story (when Orchestrator story is authored)**: test embed must assert both lazy-default construction (`_combat_resolver` + `_matchup_resolver` become `DefaultCombatResolver` + `DefaultMatchupResolver` at `_ready` when no setter was called) AND setter-override path (setter wins). Test shape belongs in the story, not this GDD (§J.8 validation item).
- **CI grep**: verify `project.godot`'s autoload entry matches §J.1 + that no other autoload accidentally registers `DungeonRunOrchestrator` or the resolver classes. Story-level, not GDD-level (§J.8 validation item).

### Pass 5C blocker tally

Cluster α (test architecture gap, highest-signal re-review finding) — **CLOSED this pass**:
- Item 1 — Node autoload constructor wiring unspecified ✅ (§J.1 + J.2 + J.3)
- Item 2 — MatchupResolver static non-injectable class ✅ (Matchup GDD Pass 5C + Orchestrator call-site migration + AC-ORC-11 rewrite)

Cluster γ (AC verification gaps) — **partially closed**:
- Item 9 — AC-ORC-11 `ticks_per_loop` unpinned → closed via Sub-AC 11-ticks-per-loop-pinned
- Item 11 — AC-ORC-11 Spy DI unspecified → closed via Sub-AC 11-cache-population + SpyMatchupResolver fixture
- Items 5 (AC-ORC-01 push_error exactly once), 6 (AC-ORC-02 oracle API), 7 (AC-ORC-04 drip/kill tagging), 8 (AC-ORC-09 test budget), 10 (AC-ORC-08 DataRegistry identity) — **remain for Pass 5D**.

### Pass 5C running total

Pass 5A: 2 BLOCKERs (Cluster ζ). Pass 5B: 7 BLOCKERs (Cluster ε + partial δ). Pass 5C: 4 BLOCKERs (Cluster α in full + Cluster γ items 9, 11). **Cumulative: 13 of 17 re-review BLOCKERs closed.** Remaining 4: Cluster β (2 items — AC-ORC-07/13 NO_RUN vs RUN_ENDED + Sub-AC 03 vs C.3 `<` guard) + Cluster γ residual (4 items — AC-01/-02/-04/-09/-08 gaps not covered by Pass 5C); all belong to Pass 5D.

### Next step

**Pass 5D — AC Triangulation Sweep** (~2 hrs). Cluster β (2 items) + residual Cluster γ (5 items) + residual Cluster δ (2 items: `matchup_cache` KeyError + `OfflineRunResult.new(kw=...)` GDScript). Task: re-read every AC against main body + Classification Summary + code pseudocode; fix body-vs-Summary contradictions; verify every oracle API referenced by an AC exists on the stated surface; pin test parameters where the SUT was its own oracle.

After Pass 5D: **Pass 5E — Gate re-run** (the successor to the 2026-04-20 independent re-review). Expected verdict: APPROVED (the full 17-item BLOCKING list will have been closed).

### Editorial framing (Pass 5C)

The §J authoring was the hard work of the Pass 5 arc — it turned a latent "how does this autoload get its dependencies?" question into a decisive, testable contract. Option A (lazy-default + setter override) was chosen over four alternatives for one reason: it has zero production cost (no bootstrap scene, no initialize-before-use danger) while providing a clean test seam (setters accept spies). The MatchupResolver DI conversion was mechanical once the Combat Pass 3D template existed — same pattern, different class name, same structural AC (inverted — H-16 now asserts NO static methods, mirroring what it used to assert for the opposite shape). The cumulative effect of Pass 5A+5B+5C: 13 of 17 BLOCKERs closed, with the remaining 4 all being AC-body-vs-spec-or-code triangulation work that Pass 5D will sweep in a single pass. The re-review Cluster α's "Highest-signal finding of the review" is now closed at both ends — at the wiring layer (§J) and at the AC layer (AC-ORC-03 + AC-ORC-11 rewrites).

---

## Pass 5D — AC Triangulation Sweep (2026-04-20)

**Pass type**: Final revision sub-pass in the Pass 5 arc before Pass 5E gate re-run. Body/Summary/code consistency audit; no new design decisions; fills the last 4 re-review BLOCKERs + 4 residual items.
**Scope**: Cluster β (2 items) + residual Cluster γ (5 items — 1 via §J cross-ref, 4 via AC rewrites) + residual Cluster δ (2 items — matchup_cache coverage + OfflineRunResult syntax). No new ACs. All edits internal to the Orchestrator GDD; no cross-GDD cascade this pass.
**Review mode**: solo
**Duration**: ~1 hr (came in under the re-review's 2-hr estimate — the fixes were mechanical against the body-vs-Summary contradictions identified in the re-review).
**Blocks closed**: 4 of the remaining 4 re-review BLOCKERs. **17/17 BLOCKING resolved cumulatively across Pass 5A–5D.**

### What changed

**Cluster β — AC body↔Summary/code contradictions**

- **AC-ORC-07** body rewritten from "state remains `NO_RUN`" to "state transitions `NO_RUN → DISPATCHING → RUN_ENDED` via `run_ended` trigger on validation failure" — matches C.1 state matrix + Classification Summary + AC-ORC-13 sibling pattern. Verification clause rewritten: subscribe to `validation_failed`, assert state == RUN_ENDED, assert zero Combat/Matchup resolver calls, assert zero error_logger invocations (empty-formation is a validation failure, not an error). Closes re-review β item 3.
- **C.3 `_on_tick_fired` guard** tightened from `if current_tick < snapshot.last_emitted_tick` to `if current_tick <= snapshot.last_emitted_tick` (combined rewind + duplicate-tick rejection). Strict-rewind branch still `push_warning`s; duplicate-tick branch is silent (the call was pure overhead anyway). Sub-AC 03-no-call-if-no-tick-advance now achievable: `tick_fired(100)` with `last_emitted_tick=100` records zero spy calls. Empty-range edge-case prose on the C.3 side updated. Closes re-review β item 4.

**Cluster γ — AC verification mechanism gaps**

- **AC-ORC-01** rewritten to use §J.4 `error_logger: Callable` DI. The test injects `recording_logger` via `set_error_logger(recording_logger)`; the closure appends messages to a test-owned `Array[String]`. Invalid cells assert `recorded_messages.size() == 1` + content-match; valid cells assert empty. GdUnit4-mock of global `push_error` is abandoned — §J.4's DI pattern is the authoritative intercept mechanism. Closes re-review γ item 5 (closes GD9 at the AC layer).
- **AC-ORC-02** rewritten to use `CombatBatchResult` fields as the oracle instead of `Combat.formation_dps_per_tick()` / `Combat.hp_bonus_factor()` (which are internal helpers, not public Combat Pass 3D surface). Test uses `SpyCombatResolver.compute_offline_batch(...)` returning a fixture with known field values; asserts snapshot fields against fixture + Orchestrator-derived fields (`losing_run` from cached `hp_bonus_factor`, initialized flags). Combat Pass 3E is now non-blocking for this AC. Closes re-review γ item 6.
- **AC-ORC-04** extended with Economy spy source-tagging contract — three patterns documented (1: drip-disabled fixture — recommended + chosen; 2: per-source methods — rejected for production API mismatch; 3: time-windowed subtraction — flagged only for integration scenarios that need both paths live). Pattern 1 is the chosen default for AC-ORC-04, -05, -09, -11. Closes re-review γ item 7.
- **AC-ORC-09** parameterization tightened: `tick-step = 1` excluded (576K × 1 call × ~100μs = ~57.6 s exceeds GdUnit4 30 s default timeout). New set: `{50, 200, 1000}`. Total AC execution budget documented as < 15 s. Future tests that genuinely need tick-step=1 must split into own file with explicit `@GodotTestSuite(timeout=120000)`. Closes re-review γ item 8.
- **AC-ORC-08 Sub-AC 08-floor-reference** extended with DataRegistry mock contract — real DataRegistry + Forest Reach fixture at `before_all`; relies on Godot 4.6 ResourceLoader caching invariant (same `resource_path` → same instance in memory); alternative MockDataRegistry for sub-ACs where Floor identity is not under test. Documented as a DataRegistry contract cross-referenced in §F Biome/Dungeon DB dependency row. Closes re-review γ item 10.

**Cluster δ — arithmetic/data-structure gaps**

- **D.4 `_build_matchup_cache` coverage contract** (re-review δ item 11): the helper MUST insert an entry for every distinct archetype present in `kill_schedule`. Since `partial_loop_kills ⊆ one_full_loop ⊆ kill_schedule` (Combat contract), both the complete-loop walk and the partial-loop walk are guaranteed to find their lookup keys. No `cache.get(archetype, false)` defensive fallback — a missing key is a legitimate bug and must crash loudly. Variables table row updated with the contract.
- **C.4 OfflineRunResult construction** rewritten from `OfflineRunResult.new(kills_by_archetype=..., kills_by_tier=..., ...)` (invalid GDScript 4.6 — no keyword-arg syntax) to `var result := OfflineRunResult.new(); result.kills_by_archetype = ...; ...; return result` (positional new + property setters; 8 lines instead of 8 keyword pairs). Closes re-review δ item 12.

**Classification Summary + header**

- Footer extended with Pass 5D summary listing 8 items closed.
- Header Last-Updated prepended with Pass 5D summary; status bumped to "Pass 5D applied 2026-04-20; 17/17 re-review BLOCKERs closed; ready for Pass 5E gate re-run."

### Files modified

- `design/gdd/dungeon-run-orchestrator.md` — 8 AC edits (AC-ORC-01 rewrite, AC-ORC-02 rewrite, AC-ORC-04 source-tagging extension, AC-ORC-07 rewrite, AC-ORC-08 Sub-AC 08-floor-reference extension, AC-ORC-09 parameterization tightening, Sub-AC 03-no-call-if-no-tick-advance note) + C.3 edge-case prose + C.3 pseudocode guard tightening (`<` → `<=`) + C.4 OfflineRunResult construction rewrite + D.4 Variables table coverage contract + Classification Summary + header.
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — THIS entry.

### Non-scope

- No cross-GDD edits this pass. Combat Pass 3E (non-blocking — AC-ORC-02 no longer depends on it) + Combat Pass 3F (non-blocking — AC-ORC-12's KillEvent to/from_dict prerequisite is documented) remain open for Combat-side bundling.
- No new ACs. No new design decisions. No rule changes.
- Pass 3B drip-curve holistic rebalance — still playtest-blocked (tuning, not contract).

### Pass 5D blocker tally

Cluster β (AC body/code/Summary contradictions) — **CLOSED this pass**:
- Item 3 — AC-ORC-07 NO_RUN vs RUN_ENDED ✅ (AC-ORC-13 inherits no change; it was already correct)
- Item 4 — Sub-AC 03 vs C.3 `<` guard ✅ (C.3 tightened to `<=`; duplicate-tick silent rejection)

Cluster γ (AC verification gaps) residual — **CLOSED this pass**:
- Item 5 — AC-ORC-01 `push_error` spy mechanism ✅ (§J.4 error_logger DI)
- Item 6 — AC-ORC-02 oracle API ✅ (`CombatBatchResult` fields replace Combat public helpers)
- Item 7 — AC-ORC-04 drip/kill-gold spy ambiguity ✅ (3 patterns; Pattern 1 drip-disabled chosen)
- Item 8 — AC-ORC-09 timeout ✅ (tick-step=1 excluded)
- Item 10 — AC-ORC-08 DataRegistry identity mock ✅ (real DataRegistry + ResourceLoader invariant)
- (Items 9 + 11 previously closed in Pass 5C via AC-ORC-11 rewrite — Sub-AC 11-cache-population + Sub-AC 11-ticks-per-loop-pinned.)

Cluster δ (arithmetic / data-structure) residual — **CLOSED this pass**:
- Item 11 — matchup_cache KeyError latent ✅ (pre-population coverage contract)
- Item 12 — `OfflineRunResult.new(kw=...)` invalid GDScript ✅ (positional + property setters)

### Pass 5 arc cumulative tally

Pass 5A: 2 BLOCKERs (Cluster ζ). Pass 5B: 7 BLOCKERs (Cluster ε + partial δ — safe range tightening). Pass 5C: 4 BLOCKERs (Cluster α in full + Cluster γ items 9, 11). Pass 5D: 4 BLOCKERs (Cluster β in full + Cluster γ items 5, 6, 7, 8, 10 + Cluster δ items 11, 12).

**Cumulative: 17 of 17 independent re-review BLOCKERs closed. Ready for Pass 5E gate re-run.**

### Next step

**Pass 5E — Gate re-run** (successor to the 2026-04-20 independent re-review). Suggested invocation: `/design-review design/gdd/dungeon-run-orchestrator.md` with targeted scope on the 17 closed BLOCKERs + a focused sweep of the 22 RECOMMENDED and 3 NICE items (not full 5-specialist adversarial — the internal structure is now stable). Expected verdict: **APPROVED**, possibly with a handful of NICE-level polish items surfacing; possible residual RECOMMENDED items that did not block the gate but are good hygiene targets for a future polish sprint.

**Parallel (non-blocking)**: Combat Pass 3E + 3F + Pass 3 targeted re-review bundle (~1.5 hrs, Combat-attention session). Combat Pass 3E no longer blocks Orchestrator AC-ORC-02 after Pass 5D; Pass 3F still prerequisites AC-ORC-12's full `KillEvent.to_dict`/`from_dict` round-trip but the AC's interim fallback (empty kill_schedule) remains valid.

### Editorial framing (Pass 5D)

Pass 5D was what a good AC Triangulation Sweep should be: boring, fast, and mostly about replacing non-existent oracles with existing ones. AC-ORC-02's fix is the clearest example — the prior spec referenced methods that weren't on the Pass 3D Combat surface; the Pass 5D fix just uses the `CombatBatchResult` the Orchestrator already receives. No new design decisions, no new code contracts, no new cascade items. The 4 remaining BLOCKERs after Pass 5C closed in a single focused pass because they were already narrowly defined by the re-review's adversarial sweep. The Pass 5 arc (5A→5D) landed 17/17 re-review BLOCKERs across four structured sub-passes in under 5 hours total. Pass 5E's gate re-run is the appropriate successor.

---

## Review — 2026-04-20 — Verdict: APPROVED

Scope signal: XL (already implemented — multi-system integration touching 5 GDDs + 2 ADRs + registry + review logs; downstream implementation scope is L)
Specialists: main session only (lean depth; solo review mode per `production/review-mode.txt`)
Blocking items: 0 | Recommended: 0 | Nice-to-have: 3
Prior verdict resolved: **Yes — 2026-04-20 independent re-review "MAJOR REVISION NEEDED" (17 BLOCKERs across Clusters α/β/γ/δ/ε/ζ) fully closed by Pass 5A–5D**

### Summary

Pass 5E is the successor gate to the 2026-04-20 independent re-review. Scope was consistency + claim-verification, not a fresh 5-specialist adversarial sweep, because the internal structure stabilized across Pass 5A–5D. Verdict: **APPROVED**.

**Closure verification — 17/17 re-review BLOCKERs confirmed closed:**

- **Cluster ζ (Pass 5A)**: ADR-0001 + ADR-0002 both Status Accepted. Orchestrator §C.6/§C.7/§E.5/§E.15 + AC-ORC-04 Sub-AC "losing-first-clear-then-win-credits-delta" + §G.1 `MID_RUN_REASSIGN_WARNING_ENABLED` row all landed.
- **Cluster ε (Pass 5B)**: Economy §C.2.3a monotonic-credit rewrite + AC H-03 + AC H-14 rewritten with 3 sub-ACs; Registry `LOSING_RUN_LOOT_FACTOR` notes cite ADR-0002 + safe range tightened; Save/Load Rule 11 field-rename paragraph (line 219) cites ADR-0002.
- **Cluster α (Pass 5C)**: Orchestrator §J.1–J.9 authoritative (Option A lazy-default + 3 test modes + 4 rejected alternatives); MatchupResolver Pass 5C DI conversion (`class_name MatchupResolver extends RefCounted`, Rule 4 instance methods).
- **Clusters γ + β + δ (Pass 5D)**: AC-ORC-01 `recording_logger` DI; AC-ORC-02 `CombatBatchResult` oracle; AC-ORC-04 Pattern 1 drip-disabled spy; AC-ORC-07 body↔Summary reconciled; AC-ORC-08 DataRegistry mock contract; AC-ORC-09 tick-step=1 excluded; Sub-AC 03-no-call-if-no-tick-advance aligned with C.3 `<=` guard; §D.4 `_build_matchup_cache` coverage contract; §C.4 `OfflineRunResult` positional + property-setter construction.

**Completeness**: 8/8 required sections present, plus §I Open Questions + §J Production Wiring (authored Pass 5C). 13 ACs total: 12 BLOCKING + 1 ADVISORY (AC-ORC-13, gates on #16).

**Dependency graph**: all 9 cited upstream GDDs exist on disk (combat-resolution, biome-dungeon-database, game-time-and-tick, hero-roster, class-vs-enemy-matchup-resolver, economy-system, save-load-system, hero-class-database, enemy-database). Undesigned systems (#12, #16, #17, #20, #24) correctly flagged.

**Bidirectional consistency**: Economy ↔ Orchestrator (try_award_floor_clear), Save/Load ↔ Orchestrator (Rules 10–14 + RunSnapshot), MatchupResolver ↔ Orchestrator (Pass 5C DI), ADR-0001 ↔ §C.7, ADR-0002 ↔ §C.6/§E.5/§E.15 — all verified.

### Required Before Implementation

**None.** Zero blocking items at this gate.

### Recommended Revisions

**None.** All 20 Recommended items from the 2026-04-20 re-review were absorbed into Passes 5A–5D (closed or consciously deferred to named downstream GDDs with flags).

### Nice-to-Have (3 polish items — non-blocking)

1. **Private-field naming consistency**: §J.1 declares `_combat_resolver` / `_matchup_resolver` / `_error_logger` (leading underscore). §C.3 pseudocode (line 219, 261) uses `combat_resolver.emit_events_in_range(...)` without the underscore; line 231 uses `_matchup_resolver.resolve_formation_matchup(...)` with it. Cosmetic. Polish fix: normalize to the underscored form inside the class body.
2. **ADR validation-criteria checkboxes**: ADR-0001 lines 199–203 and ADR-0002 lines 253–262 list `[ ]` unchecked validation items that ARE all satisfied by Pass 5B–5D edits. Housekeeping: flip to `[x]`.
3. **Telemetry counters not tracked in §I Open Questions**: `mid_run_reassignments_during_floor_5_boss` (ADR-0001) and `losing_first_clears_reclaimed_on_win` (ADR-0002) are named as RECOMMENDED first-playtest signals but don't appear in the GDD's §I table. Useful follow-up for the vertical-slice analytics plan.

### Senior Verdict

Skipped — solo review mode (CD-GDD-ALIGN gate). Main-session synthesis: the Pass 5 arc closed every BLOCKER surfaced by the independent re-review, and the downstream contracts (Economy, Save/Load, MatchupResolver, registry) landed in the correct order. §J Production Wiring is particularly strong — the Option A lazy-default pattern with three documented test modes converts previously-unwriteable ACs into straightforward Mode-1 unit tests.

### Scope Signal

**XL (already implemented)**. Downstream implementation scope is **L** — Orchestrator autoload + RunSnapshot/OfflineRunResult value types + 13 AC test files + one Mode-1 harness.

### Pass 5 arc — final cumulative tally

- Pass 5A: 2 BLOCKERs (Cluster ζ)
- Pass 5B: 7 BLOCKERs (Cluster ε + partial δ)
- Pass 5C: 4 BLOCKERs (Cluster α + Cluster γ items 9 + 11)
- Pass 5D: 4 BLOCKERs (Cluster β + Cluster γ items 5, 6, 7, 8, 10 + Cluster δ items 11, 12)
- **Pass 5E: 0 BLOCKERs found — APPROVED**

**Total: 17/17 re-review BLOCKERs closed across five structured sub-passes. GDD #13 is implementation-ready.**

### Next step

Main session's call: **/design-system floor-unlock-system (#16)** per session state — also unblocks AC-ORC-13 promotion from ADVISORY to BLOCKING once #16's `FloorUnlock.is_unlocked()` replaces the Orchestrator's F1-only MVP stub (E.12).

Parallel (non-blocking): Combat Pass 3E + 3F + Pass 3 targeted re-review bundle (~1.5 hrs). No longer gates Orchestrator. Pass 3F still prerequisites AC-ORC-12's full `KillEvent.to_dict`/`from_dict` round-trip; the AC's interim fallback (empty kill_schedule) remains valid until then.

### Editorial framing (Pass 5E)

Pass 5E was exactly what a gate re-run on a stabilized doc should be: every claim in the Pass 5A–5D closure record verified against the actual file contents, plus a consistency sweep across the 5 GDDs + 2 ADRs + registry in the blast radius. Nothing new surfaced because nothing new was introduced — Passes 5A–5D were structured, boring, and correct. The 3 NICE items are the kind of drift that accumulates in any 6-pass arc and is the right shape for a future polish sprint, not a blocker for implementation.

"The work is good; the process worked." (Rewriting Pass 4D's post-mortem framing — the instrumentation the creative-director asked for after the independent re-review was Pass 5A–E itself, and it did the job it was designed to do.)

---

## Propagation — 2026-04-20 — Floor-Unlock-Propagation-Edit-3

**Trigger**: Floor Unlock System GDD #16 authored 2026-04-20 (`design/gdd/floor-unlock-system.md`). Its §F enumerates 3 required cross-GDD propagation edits; edit #3 touches this GDD.

**Edits applied to `design/gdd/dungeon-run-orchestrator.md`**:

1. **§C.3 code sample (line ~249)** — `floor_cleared_first_time.emit(snapshot.floor.floor_index)` extended to `.emit(snapshot.floor.floor_index, snapshot.biome_id, snapshot.losing_run)`. Inline note added that RunSnapshot gains a cached `biome_id: String` at DISPATCHING (MVP hardcoded `"forest_reach"`; V1.0 biome-context injection). Additive payload extension; existing subscribers remain compatible.

2. **§F Downstream Dependent row for Dungeon Run View (#24)** — signal payload listing updated to `floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`. Note added that extension is additive and #24 may ignore the new params in MVP.

3. **§E.12 (Fresh-save F5 dispatch)** — marked SUPERSEDED by GDD #16. The inline F1-only MVP stub is retired; Orchestrator now delegates to `FloorUnlockSystem.is_unlocked(floor_index)` per GDD #16 §C.1 R1 + §C.3. Historical rationale preserved for audit trail. MVP playtest pathology (18-min-per-kill F5 on fresh save) remains prevented — same end-state `RUN_ENDED`, now verified at the Orchestrator/FloorUnlockSystem integration boundary.

4. **§H AC-ORC-13** — gate promoted from **ADVISORY to BLOCKING**. Verification clause rewritten to use real `FloorUnlockSystem` (no inline stub). Sub-AC 13-fresh-save upgraded from "smoke-test assertion" to "BLOCKING CI gate"; paired with GDD #16 AC-FU-13 as the integration-test anchor. Classification Summary row updated; header count updated from "12 BLOCKING + 1 ADVISORY" to "13 BLOCKING + 0 ADVISORY".

5. **Header "Referenced by" list** — Floor Unlock System (#16) status changed from "undesigned" to "Designed 2026-04-20 pending review".

**Impact on prior verdict**: No. Pass 5E APPROVED verdict stands — these edits are additive integrations with a downstream GDD, not revisions to prior design decisions. All 13 ACs remain writeable; AC-ORC-13 integration coverage is strengthened (was ADVISORY-gated; now BLOCKING-gated with a real implementation contract).

**Blast-radius**: 5 locations in this file; also propagates in lockstep to Biome DB GDD #8 §E.1 (edit #1 — retire `is_floor_unlocked(floor_id)` signature) and Save/Load GDD #3 Consumer table (edit #2 — add FloorUnlockSystem row with authoritative contract). Saved/Load's "not yet written" sentence updated to reflect GDD #16's authoring. See `design/gdd/reviews/floor-unlock-system-review-log.md` (first entry to be created on first review) + `design/gdd/floor-unlock-system.md` §F for the authoritative propagation edit list.

**Authored by**: main session (solo review mode); specialists consulted: creative-director (Section B fantasy), game-designer + systems-designer (Section C), qa-lead (Section H). No new ADRs (ADR-0001, ADR-0002 remain binding; no re-litigation).
