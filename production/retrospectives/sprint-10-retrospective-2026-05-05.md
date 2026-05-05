# Sprint 10 Retrospective — 2026-05-05

**Sprint window**: 2026-05-06 → 2026-05-15 (nominal)
**Closure date**: 2026-05-05 (Day 0 — pre-sprint autonomous push)
**Effective duration**: a single autonomous session
**Review mode**: solo
**Stage**: Production (entered same day via Pre-Prod → Prod gate PASS WITH NOTES)

This retro is unusual: the entire sprint scope (minus 3 deferred items) closed in one autonomous session before the sprint nominally started. The pattern is worth analyzing because it has both a "this worked great" face and a "this could mask risk" face — and Sprint 11 calibration depends on understanding which.

---

## What was completed

| ID | Title | Priority | Realized cost | Plan estimate |
|---|---|---|---|---|
| S10-M1 | parchment_theme.tres content authoring | Must Have | ~0.4d | 1.0d |
| S10-M2 | UIFramework apply_parchment_panel + wire_touch_feedback + tests | Must Have | ~0.4d | 0.5d |
| S10-M3 | Audio System GDD authoring (507 lines, 11 sections) + post-authoring audit | Must Have | ~1.0d | 1.5d |
| S10-M4 | Stub XP grant in orchestrator + level-up toast + tests | Must Have | ~0.5d | 0.5d |
| S10-S2 | TD-008 ADR-0007 diagram amendment | Should Have | ~0.1d | 0.25d |
| S10-S4 | Cross-test live-autoload contamination cleanup (hygiene barrier pattern) | Should Have | ~0.4d | 0.25d |
| S10-S5 | Sprint 11 plan groundwork (sprint-11.md skeleton) | Should Have | ~0.3d | 0.25d |
| S10-N1 | tr() safe-format helper hoist (UIFramework.format_localized) + tests | Nice to Have | ~0.3d | 0.25d |
| **Realized total** | | | **~3.4d** | **4.5d** |

## What was deferred

| ID | Title | Reason | New home |
|---|---|---|---|
| S10-S1 | Story 014 — orchestrator state advancement during SceneManager TRANSITIONING | Scope touches FSM + Screen base class refactor; risk of overrun beyond 1.25d time-box; S8-M4 hotfix is good-enough | Sprint 11 backlog |
| S10-S3 | scene_manager test env flakes cleanup | Root cause is `scene_manager.gd:617` test-env coupling; production-code refactor exceeds 0.5d budget; test-level fixture would mask root cause | Sprint 11 Day 1 pre-flight |
| S10-N2 | Re-dispatch shortcut on main_menu | Investigation revealed feature-work scope (track last formation + bypass button + show/hide logic) closer to 0.5–0.75d than 0.25d nominal | Sprint 12 backlog |

---

## What went well

1. **Pre-flight investigation prevented a re-run of the Sprint 9 → 10 pivot.** Sprint 10 was originally pivoted on 2026-05-05 morning after `/dev-story` Phase 2 discovery on story-016 revealed unimplemented prerequisites. The "Honest dependency status check" production-process discipline added in that pivot (sprint-10.md §Production-Phase Process Notes #4) was applied to S10-M4 from the start: investigation confirmed XP grant logic was entirely absent, so the risk-register fallback ("scope-reduce to feedback only on a stub-grant") was activated immediately rather than after burning 2 days assuming it existed.

2. **Plan-estimates mostly held; underestimates on tests.** Realized cost (~3.4d for 8 items) tracked plan estimates (4.5d for the same 8 items) within ~25%. The Must Haves were collectively faster than estimated; the Should Have S10-S4 was slower than estimated (0.4d vs 0.25d) because of the snapshot-vs-reset bug discovered mid-implementation. The S10-N1 hoist was slower (0.3d vs 0.25d) for the same reason — discovered `tr()` not callable from static context, fixed inline.

3. **Test-driven verification caught two real bugs same-session.** Both bugs were patterns, not edge cases: (a) `tr()` is an Object instance method, not callable from static; fixed via `TranslationServer.translate(StringName(key))`. (b) snapshot-then-restore preserves cross-suite contamination; fixed via reset-on-entry-and-exit hygiene barrier pattern. Both fixes propagate as future-proofing — any future static helper needing localization will use `TranslationServer.translate`; any future test touching live autoloads has a documented hygiene barrier pattern to copy.

4. **Cross-system verification at the end found GDD drift before it shipped.** The audio-system.md GDD had 3 real signature drifts (SceneManager/Economy/SaveLoadSystem) that a quick grep against actual codebase caught. Post-authoring `/design-review` is a real value-add even in solo mode; the discipline of "verify cross-system claims against the live codebase" is worth keeping.

5. **Sprint 11 is fully pre-scoped.** sprint-11.md exists with day-by-day sequencing, Must Have / Should Have / Nice to Have decomposition, 6 risk entries, and capacity math. Sprint 11 can start cleanly the moment the calendar reaches 2026-05-16 — no cold-start authoring required.

## What was surprising

1. **Audio System GDD authoring took ~1.0d, not 1.5d.** The 1.5d estimate assumed creative-direction iteration; the actual GDD shipped in one pass because the existing context (Art Bible §7 Animation Feel + game-concept.md Audio Needs + the structurally-similar scene-screen-manager GDD) provided enough constraint that the design space collapsed quickly. The post-authoring audit then added ~0.2d for cross-system drift fixes — net ~1.2d, still under the original estimate. This is a bookkeeping signal: when the design constraints are well-established (cozy register + 2-bus hierarchy + signal-driven autoload pattern already proven in UIFramework), GDD authoring is faster than the comparable Sprint 5–6 GDDs were.

2. **The deferred items collectively reflect a real cost-discipline pattern.** S10-S1 (1.0d), S10-S3 (0.5d), S10-N2 (0.25d nominal but realistically 0.5–0.75d) are deferred because each was discovered to be larger or riskier than the budget said. This is the production-process discipline working as intended: when investigation reveals scope is bigger, defer rather than absorb. The opposite pattern — silently absorbing scope creep — is what produced the Sprint 9 → 10 pivot.

3. **The single-session autonomous push closed more scope than several prior sprints' Should Have absorption.** Sprints 5–9 averaged ~3 Should Haves closed per sprint (the rest deferred). Sprint 10's 3 Should Haves + 1 Nice to Have closed in one session is comparable to a full sprint's Should Have absorption rate. This is the strongest possible signal that pre-sprint autonomous work is high-leverage when the Must Have scope is well-decomposed.

## What to keep doing

1. **The "Honest dependency status check" pre-flight pattern.** Codified in sprint-10.md §Production-Phase Process Notes #4: before estimating any "wiring" story, grep the codebase to verify dependencies are actually implemented, not just `Status: Ready`. Apply at every Sprint 11 story start.

2. **The "post-authoring audit" pattern for GDDs.** Manual cross-system grep against the live codebase, even in solo review mode. 3 drifts found in audio-system.md in a 5-minute audit is a strong signal — every future GDD should get this treatment before being declared done.

3. **The "reset-based hygiene barrier" pattern for tests touching live autoloads.** Documented in `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` header. Snapshot+restore preserves contamination; reset cleans cross-suite leak. Apply to Sprint 11's save-persist integration tests, which will involve substantial multi-system flows where contamination would be hardest to debug.

4. **The "TaskCreate / TaskUpdate" task tracking discipline.** Every multi-step story used 3–4 tasks (implement, wire, test, update artifacts). Closing each as it completes provided a clean trace of what was actually done vs claimed-done.

5. **The "Stub formula explicitly Sprint-11-replaced" pattern.** S10-M4's stub +1 grant is documented as "real XP-curve formula belongs to a Sprint 11 economy/progression GDD pass". Sprint 11 doesn't have to discover this — the deferral is documented at the call site AND in the GDD AND in sprint-11.md.

## What to change

1. **The S10-S4 initial implementation pattern was wrong; lesson is real.** Snapshot+restore is the wrong primitive for cross-suite hygiene; reset-on-entry-and-exit is the right primitive. The lesson generalizes: when the goal is "make this suite order-independent within a shared session", reset is correct; when the goal is "preserve state across a single test", snapshot+restore is correct. These two patterns are NOT interchangeable. Document this distinction in any future test-hygiene work.

2. **The S10-N1 `tr()` parse error caught in test, not in code review.** A static-context call to a non-static method is a parse error that fails the entire script load. The fix was trivial (`TranslationServer.translate`), but the discovery cost was a full test-run cycle (~5 minutes including subprocess boot). Future: when adding any new method to UIFramework or other static-class scripts, sanity-check with a quick `--check-only` parse before running tests. Or: maintain a checklist that every static helper must use only static-callable APIs.

3. **GDD authoring on Day 0 did not get a `/design-review` invocation.** The post-authoring audit was manual. Solo review mode skips automatic department-director review at sprint-level work — but for GDDs specifically, a `/design-review` invocation is not a department-director review; it's a structural-checklist pass. Future: even in solo mode, run `/design-review` on every new GDD as a self-check before declaring the story done. The post-audit discovered 3 drifts in 5 minutes; a `/design-review` would have surfaced more.

4. **The sprint-status.yaml `status: deferred-to-sprint-11` enum value is non-standard.** Existing entries used `done` / `ready-for-dev` / `backlog`. The "deferred-to-sprint-11" / "deferred-to-sprint-12" suffixes communicate intent but break enum tooling assumptions. Future: standardize on `deferred` with a `target_sprint: 11` field, OR add `deferred-to-sprint-N` to the canonical enum in the sprint-plan skill template. (Low priority — purely cosmetic.)

## Risks / lessons for Sprint 11

1. **Sprint 11's Must Have surface is 4 stories on the same subsystem (save-persist).** Unlike Sprint 10's heterogeneous Must Haves (theme / framework / GDD / orchestrator), Sprint 11 is concentrated. If the save-persist surface area expands during implementation (as story-016 did in the Sprint 9 → 10 pivot), the WHOLE sprint is at risk, not just one Must Have. **Mitigation**: pre-sequence the 4 stories so an early dependency surprise can be surfaced on Day 1–2, not Day 5.

2. **Sprint 10 closed ~3.4d of work in one autonomous session. Sprint 11's save-persist Must Haves total ~4.5d.** The pace was sustainable because the Must Haves were well-decomposed and had clear ACs. Sprint 11's stories are similarly well-decomposed (sprint-11.md §Tasks). But save-persist has the Production-stage discipline gates (regression tests for every wiring change, test-env hygiene for the heartbeat path, etc.) that Sprint 10's Must Haves didn't fully exercise. **Calibration**: assume Sprint 11's per-story cost is 1.2× the estimate to account for the Production-stage rigor.

3. **The deferred items are now a Sprint 11 risk surface.** S10-S1 (orchestrator state advancement) and S10-S3 (scene_manager test env flakes) are both **load-bearing for save-persist work**. S10-S3 in particular: save-persist integration tests will trigger the `scene_manager.gd:617` test-env coupling failure mode unless cleaned up first. **Recommendation**: tackle S10-S3 as Sprint 11 Day 1 pre-flight, before any save-persist story starts. Budget 0.5–1.0d for it (conservatively, since the 0.5d Sprint 10 estimate didn't account for production-code refactor risk).

4. **Audio-system.md GDD has 8 ADR candidates surfaced but not yet authored.** Sprint 11 audio implementation will discover whether any are gating. OQ-AS-1 (autoload rank ADR-0003 amendment) is the most likely Day-1 blocker — it's a 0.25d edit but Sprint 11 should plan for it before Story S11-S2 begins. **Mitigation**: include the ADR-0003 amendment as a sub-task of S11-S2 (Audio MVP Story 1).

## Memory items worth saving

These are insights from this session that future autonomous sessions should inherit:

- **`tr()` is an Object instance method, NOT static.** Use `TranslationServer.translate(StringName(key))` for static-context localization lookup.
- **Snapshot+restore preserves contamination; reset cleans it.** When a test suite needs to be order-independent within a shared gdUnit4 session, use the reset-on-entry-and-exit hygiene barrier pattern (see `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd`).
- **Save/Load uses per-consumer `get_save_data` / `load_save_data` per Save/Load GDD canonical contract.** There is no flat "settings save category" — each save-aware autoload implements its own consumer interface, namespaced under its node name in the composed save dict.
- **`SceneManager.screen_changed` signature is `(new_screen_id: String, old_screen_id: String)`** — `_id` suffixes matter when matching against actual signal declarations.
- **`Economy.gold_changed` signature is 3-arg `(new_balance: int, delta: int, reason: String)`** — `reason` is the emit-reason string, NOT a payload field.
- **The audio-system GDD's "8 ADR candidates surfaced for Sprint 11" pattern is the canonical model** for any first-pass GDD that touches multiple subsystems: surface ADR candidates inline, defer authoring unless gating, document each in OQ-* entries with explicit Sprint-N landing target.

## Verdict

**Sprint 10: SUCCESSFUL.** Definition-of-success bar (all 4 Must Haves done, no S1/S2 bugs, ≥99% test pass rate) was met on Day 0 of a 9-working-day sprint. 3 deferred items are explicitly carry-forward with clear rationale; none are silent slippage. Sprint 11 is pre-scoped and ready to begin on 2026-05-16.

The autonomous Day-0 closure pattern is reproducible **conditional on**: (a) Must Have scope is well-decomposed before the session begins, (b) every story has a clear AC checklist, (c) the "Honest dependency status check" pre-flight is applied to every story, (d) the post-authoring audit is treated as part of "done" not as optional polish. Sprint 11's save-persist Must Haves do not meet condition (a) yet (4 stories on the same subsystem with implementation interactions); Day 1 of Sprint 11 should be spent decomposing further, not implementing.
