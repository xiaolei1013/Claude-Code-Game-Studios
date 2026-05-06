# Sprint 12 — 2026-05-26 to 2026-06-04 (9 working days)

> **Status: AUTHORED 2026-05-05 by post-Sprint-11 close-out (S11-M4 commit `de6e256`).**
> Sprint 12 nominally begins 2026-05-26 after Sprint 11 closes (2026-05-25). This plan synthesizes carry-forward from Sprint 11 (deferred Should/Nice + Story 016 unfinished ACs) plus the pre-sequenced work in `recruitment-system.md` §J (Stories 2–8), `offline-progression-engine.md` §J (Stories 1–10), `audio-system.md` §K (Stories 3–5), and `formation-assignment-system.md` §J (Stories 2–7). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 12 kickoff.

## Sprint Goal

**The cozy idle-game register, end-to-end.** Sprint 11 closed the save-persist workstream + the consumer ecosystem; Sprint 12 closes the remaining MVP gameplay loops:

1. **Recruit flow** — Sprint 11 shipped the Recruitment autoload + ADR-0015 + save schema. Sprint 12 ships the actual playable feature: try_recruit transaction with full cross-system tests, pool deduplication policy, RecruitScreen wire-up.
2. **Offline progression engine** — the "Return-to-App fantasy" anchor. ADR-0014 + GDD §J are both fully specified; Sprint 11 closed the cross-system signal contracts (S11-X6/X7 flush_offline_signals). Sprint 12 ships the autoload skeleton + batch chunking + cap + signal-suppression policy.
3. **Audio cue-play** — Sprint 11 shipped AudioRouter skeleton + bus layout + volume persistence (S11-S2/S3). Stub `_on_*` handlers are wired; Sprint 12 implements the actual cue-play for state_changed + enemy_killed + boss_killed + floor_cleared_first_time + hero_leveled + gold_changed.

**Definition of Sprint 12 success**: a player can launch → recruit a Mage with gold → dispatch with a 3-hero formation → close the app for 30 minutes → reopen and see the Return-to-App modal showing accumulated offline gold + hero levels → tap to continue, hearing the level-up chime cascade. The end-to-end cozy loop, audible, with offline progression respected.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

## Pre-flight checklist (Day 0 — apply S11 "Honest Dependency Status Check" lesson)

Before starting any Must Have, grep the codebase to confirm:
- [ ] `Economy.recruit_cost(class_id, copies_owned)` is unstubbed (Sprint 11 confirmed it returns 0 — STORY 007 Economy work owns this; verify Sprint 12 picks it up before Recruitment Story 2 starts)
- [ ] `OfflineProgressionEngine` autoload registration absent (`grep "OfflineProgressionEngine" project.godot` — should return nothing pre-implementation)
- [ ] `AudioRouter._on_*` handler bodies are stubs (verify the deferred surface)
- [ ] `tests/` is green at Sprint 11 close (1281/1281 PASS expected)

If any of the above is unexpectedly already implemented (not impossible — pre-emptive Sprint 11 work bridged Sprint 12 in several places), re-scope the affected Must Have item.

## Tasks

### Must Have (Critical Path — close MVP loops)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S12-M1 | **Economy.recruit_cost formula implementation** — ✓ DONE 2026-05-05 (post-Sprint-11 close-out, pre-emptive). Closed the STUB at `economy.gd:519`; formula is `floori(BASE_RECRUIT[tier] × RECRUIT_RATIO^copies_owned)` per ADR-0013 §D.3 + §recruit_cost (NOT the original sprint-12.md draft formula — corrected to match ADR + economy_config.tres canonical schema). EconomyConfig.tres data-driven. New 13-test suite `tests/unit/economy/economy_recruit_cost_test.gd` (Groups A/B/C/D/E: warrior tier-1 boundary cases, tier-2 unit fixture, sentinel paths, pure-function invariants, AC H-07 geometric-1.8× anchor). Existing skeleton test downgraded from "stub returns 0" to "method exists with correct arity". | economy-designer + gameplay-programmer | 0.5 | none | Unit tests for tier 1 × copies 0/1/2/3 PASS; sentinel paths PASS; AC H-07 anchor PASS; pure-function invariants PASS. |
| S12-M2 | **Recruitment Stories 2 + 4 — try_recruit transaction + pool integration tests** (per recruitment-system.md §J) — ✓ DONE 2026-05-05 (post-Sprint-11 close-out, pre-emptive). New 11-test suite `tests/integration/recruitment/recruitment_try_recruit_test.gd` against live Economy + HeroRoster + Recruitment + DataRegistry. Snapshot/restore hygiene barrier via get_save_data + remove_hero loop. Story 3 (refund path AC-RC-09) **DEFERRED to Sprint 13** — requires DI infrastructure for spy HeroRoster (can't trigger live add_hero contract violation without injection). | gameplay-programmer + qa-tester | 1.0 | S12-M1 ✓ done | AC-RC-04 happy path PASS (gold deducted, hero added, signal); cost-stability adjacent (second warrior costs 270 = 150 × 1.8); AC-RC-05/06/07/08 failure-path tests PASS; AC-RC-10 pool mutation isolation PASS; AC-RC-12 pool_refreshed + counter increment PASS; refresh_pool_paid insufficient/sufficient gold paths PASS. |
| S12-M3 | **Recruitment Stories 5–8 — cost-stability + Save/Load schema migration + RecruitScreen wire-up + AC-RC-14 CI grep** (per recruitment-system.md §J) — Story 8 (AC-RC-14 CI grep) ✓ DONE 2026-05-05 (post-Sprint-11 close-out, pre-emptive). New `tests/unit/recruitment/recruitment_single_writer_ci_grep_test.gd` enforces single-writer for HeroRoster.add_hero (Recruitment) + HeroRoster.set_formation_slot (FormationAssignment, AC-FA-12 sibling). Stories 5–7 remain Sprint 13+ scope (Story 5 cost-stability invariant tests overlap with S12-M2 Group A coverage; Story 6 schema migration is Sprint 13+ when first save-version bump occurs; Story 7 RecruitScreen UI requires UI work). | gameplay-programmer + ui-programmer | 1.0 | S12-M2 done | AC-RC-14 CI grep ✓ enforced (recruitment.gd is the only file outside hero_roster.gd with `add_hero` code-line mentions); AC-FA-12 sibling ✓ enforced (formation_assignment.gd is the only file outside hero_roster.gd with `set_formation_slot` code-line mentions). |
| S12-M4 | **OfflineProgressionEngine Stories 1–3 — autoload skeleton + boot orchestration + OfflineSummary class** (per offline-progression-engine.md §J) — ✓ DONE 2026-05-05 (post-Sprint-11 close-out, pre-emptive). New autoload `src/core/offline_progression_engine/offline_progression_engine.gd` (~250 lines) at rank 15 per ADR-0003 Amendment #8. OfflineSummary inner class with 7 locked fields per GDD §C.1. Signals: `offline_rewards_collected(summary)` + `cap_reached(seconds_clipped)`. Public API: `run_offline_replay(elapsed)` + `is_replay_in_flight()`. Boot subscribes to TickSystem.offline_elapsed_seconds. Cap clipping per GDD §D.2. Single-replay-in-flight invariant per ADR-0014. **Chunked replay loop body STUBBED** — S12-M5 (Stories 4-6) lands the real per-chunk implementation. NOT in CONSUMER_PATHS per GDD §C.7. New 16-test skeleton suite (Groups A/B/C/D/E/F/G/H). | gameplay-programmer + godot-gdscript-specialist | 1.0 | S11-X6 + S11-X7 ✓ (flush_offline_signals already shipped) | Autoload at rank 15 ✓; boot subscribes to TickSystem.offline_elapsed_seconds ✓; OfflineSummary 7 fields locked ✓; cap_reached emits only on strict-greater ✓; cold-launch zero-elapsed silent ✓; re-entrant calls dropped via _replay_in_flight guard ✓; NOT in CONSUMER_PATHS ✓. |
| S12-M5 | **OfflineProgressionEngine Stories 4–6 — batch chunking + signal suppression + cap handling** (per offline-progression-engine.md §J) | gameplay-programmer + economy-designer | 1.5 | S12-M4 done | Tick replay loop with adaptive chunk-size + per-chunk yield budget (ADR-0014 §C two-budget split); 5 ADR-0014 forbidden patterns CI-enforced (no per-tick signal emit during replay); cap clipping per AC-OE-* gates; AC-OE-12 5s ADVISORY total wall budget + AC-OE-13 16ms BLOCKING per-chunk budget. |
| S12-M6 | **Audio cue-play Stories 3–5** (per audio-system.md §K) — actual chime/ding implementation in `AudioRouter._on_*` handler bodies | audio-director + ui-programmer | 1.0 | none (parallel with M-track) | UI tap chime (UIFramework hook); enemy_killed pitch-modulated tier chime; boss_killed stinger; floor_cleared_first_time fanfare; hero_leveled level-up chime; gold_changed throttled coin sound. AC-AS-01 through AC-AS-08 covered. |

**Must Have total**: 6.0 days base; ~6.5 days realistic. Within 7.2-day available capacity with ~0.7d for Should Have absorption.

### Should Have

| ID | Task | Owner | Est. Days | Dependencies |
|----|------|-------|-----------|--------------|
| S12-S1 | **S11-S5 carry-forward — Re-playtest with persisted save** (manual smoke; covers Story 016 AC-9) | producer + qa-tester | 0.5 | S12-M3 + S12-M5 done (so the loop is end-to-end live) |
| S12-S2 | **S11-S1 carry-forward — Story 009 reduce_motion + offline-replay modal** (per scene-manager.md + ADR-0007) | gameplay-programmer + ui-programmer | 1.0 | S12-M5 done (offline-replay surface exists) |
| S12-S3 | **OfflineProgressionEngine Stories 7–8 — replay screen + acknowledge** (per offline-progression-engine.md §J) | ui-programmer + audio-director | 0.75 | S12-M5 done; integrates with S12-S2 |
| S12-S4 | **FormationAssignment Stories 2–4 — commit signal + length validation + screen integration tests** (per formation-assignment-system.md §J — Sprint 11 S11-X9 deferred these) | gameplay-programmer + qa-tester | 1.0 | none |
| S12-S5 | **Audio asset placeholders** — silent .ogg / .wav stubs at canonical paths so DataRegistry.resolve doesn't error (per S11-N3 carry-forward) | technical-artist | 0.25 | S12-M6 (consumes the canonical paths) |

**Should Have total**: 3.5 days. Realistic absorption depends on Must Have actuals.

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies |
|----|------|-------|-----------|--------------|
| S12-N1 | **OfflineProgressionEngine Stories 9–10 — edge cases + V1.0 forward-compat** (per offline-progression-engine.md §J) | gameplay-programmer | 0.5 | S12-M5, S12-S3 |
| S12-N2 | **Audio Stories 6–7 — hydration suppression hook + post-launch tunable curves** (per audio-system.md §K) | audio-director | 0.5 | S12-M6 |
| S12-N3 | **Story 015 — perf verification suite** (Story 016 AC-7/AC-8 deferred) — ✓ DONE 2026-05-05 (post-Sprint-11 close-out, pre-emptive). New `tests/perf/save_persist_perf_test.gd` — 3 tests: persist p95 100-call benchmark; load p95 100-call benchmark; envelope-size sanity (<50 KB MVP target per AC-SL-12). 5-call warm-up loop per matchup_resolver_perf_test convention. Soft-warn at spec budget (10 ms persist / 50 ms load PC ADVISORY); hard-fail at 5× ceiling (50 ms persist / 250 ms load) absorbing CI variance. Mobile BLOCKING AC-SL-11 (≤ 50 ms persist) deferred to platform certification — cannot run headlessly. | qa-lead + gameplay-programmer | 0.5 | none |
| S12-N4 | **FormationAssignment Stories 5–7 — RecruitScreen-style refactor + named-presets V1.0 forward-compat surface** | gameplay-programmer + ui-programmer | 0.75 | S12-S4 |
| S12-N5 | **Economy.level_cost formula implementation** — ✓ DONE 2026-05-05 (post-Sprint-11 close-out, pre-emptive). Refined scope: closed the Story 008 STUB at `economy.gd:595` (sibling to S12-M1 recruit_cost). Formula `floori(BASE_LEVEL[tier] × LEVEL_RATIO^(level - 1))` per ADR-0013 §D.4. Past-cap returns -1; below-level-1 returns -1; null _config returns -1; missing tier returns -1. New 15-test suite `tests/unit/economy/economy_level_cost_test.gd` (Groups A/B/C/D/E: tier-1 boundary cases, tier-2 fixture, sentinels, pure-function invariants, AC H-08 geometric-1.6× anchor + total-cost-to-cap range check). Existing skeleton test downgraded from "stub returns 0" to "method exists". **NOT REPLACED**: the original S12-N5 description "replace S10-M4 stub +1-per-clear grant with XP curve" was multi-day scope (requires real XP system: per-hero XP field + level-up trigger + XP gain on kill). The +1-per-clear stub remains active until Sprint 13+ XP system implementation lands. This S12-N5 closes the adjacent level_cost surface (used by Level-Up UI in Sprint 13+) without inventing the XP system. | economy-designer + gameplay-programmer | 0.5 | none |

**Nice to Have total**: 2.75 days.

## Sprint 12 sequencing recommendation

**Day 1 — Economy unblock + audio cue-play start**
- Morning: S12-M1 (0.5d) — Economy.recruit_cost formula
- Afternoon: S12-M6 starts (audio cue-play in parallel; no dep on M1)

**Days 2–3 — Recruit flow integration**
- S12-M2 (1.0d) — try_recruit transaction + failure paths
- S12-M3 (1.0d) — cost-stability + save schema + RecruitScreen wire-up

**Days 4–5 — Offline progression engine core**
- S12-M4 (1.0d) — autoload skeleton + boot orchestration
- S12-M5 (1.5d) — batch chunking + signal suppression + cap

**Day 6 — Should Haves: re-playtest + offline modal**
- S12-S1 morning — re-playtest (validates the full Sprint 12 loop)
- S12-S2 + S12-S3 afternoon — offline modal + replay-screen acknowledge

**Day 7 — Should Haves: FormationAssignment + audio assets**
- S12-S4 (1.0d) — FormationAssignment integration tests
- S12-S5 (0.25d) — audio placeholders

**Day 8 — Nice to Haves + Sprint 12 closure**
- S12-N3 (perf benchmarks) — Story 015 closeout
- S12-N1/N2/N4/N5 cherry-picks per remaining capacity

**Day 9 — buffer / Sprint 13 plan groundwork + retrospective**

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Economy.recruit_cost formula tuning regresses Sprint 11 cost-stability assumptions** — S11-X10 + S11-S3 + S11-X8 (ADR-0015) all assume a specific cost-curve shape; a designer-tuning pass could shift values | LOW | LOW | EconomyConfig.tres makes the curve data-driven; AC-RC-11 cost-stability invariant test (S12-M3) catches any divergence between get_recruit_cost-displayed and try_spend-charged |
| **OfflineProgressionEngine batch chunking exceeds CPU budgets on min-spec mobile** — ADR-0014 §C two-budget split (16ms BLOCKING per-chunk + 5s ADVISORY total) is tight | MEDIUM | HIGH | Adaptive chunk-size adjustment per GDD §D.3; fall back to coarser tick-multiplier if 16ms chunk budget breaches; defer S12-N1 edge cases if M5 drags; profile on macOS dev loop early in Day 4 |
| **S12-M6 audio cue-play reveals AudioServer bus configuration gaps** — bus layout authored in S11-S2 but live cue-play has not exercised it | MEDIUM | LOW | Defensive `has_bus(name)` guards in `_play_cue` per audio-system.md §C.4; soft-fail on missing bus with push_warning; defer to S12-S5 placeholder asset commit if needed |
| **Recruit pool dedup policy (OQ-0015-2) playtest signal differs from initial choice** — ADR-0015 OQ-0015-2 was deferred to Sprint 12+ Story 4 implementation | LOW | LOW | Land Story 4 with the simplest "draw with replacement" choice; document as Sprint 13+ tunable per playtest-06+ signal; the data-driven config makes the change frictionless |
| **Re-playtest (S12-S1) reveals the offline-replay UX is jarring or confusing** — first time players see the Return-to-App modal | MEDIUM | MEDIUM | Treat as expected playtest signal; document in `production/playtests/playtest-05-sprint-12-offline-replay-2026-XX-XX.md`; add UX iteration stories to Sprint 13 backlog. Pillar 2 (visible honest progression) is the correct frame for evaluating |
| **Honest dependency status check — Pre-flight surface verification** | N/A | N/A | Apply Sprint 11's Day-0 protocol: `grep` codebase for any remaining "stub" / "TODO" bodies on the M-track call chain BEFORE starting each story. The Story 007b discovery (S11-M4 pre-flight surfaced unimplemented load-side body) is the canonical example |

## Dependencies on External Factors

- **Sprint 11 close** ✓ — 4/4 Must Haves DONE; consumer ecosystem 7/7; full unit + integration suite at 1281/1281 PASS as of S11-M4 commit `de6e256` 2026-05-05.
- **ADR-0014** ✓ Accepted (Offline Replay Batch Chunking + RunSnapshot Schema) — gates S12-M4/M5.
- **ADR-0015** ✓ Accepted (Recruitment Pool Determinism + Refresh + Cost-Curve) — gates S12-M2/M3.
- **`recruitment-system.md` §J** ✓ pre-sequenced (Stories 2–8 + 0a/0b prereqs already closed).
- **`offline-progression-engine.md` §J** ✓ pre-sequenced (Stories 1–10 + 0a cross-system contracts already closed via S11-X6/X7).
- **`audio-system.md` §K** ✓ pre-sequenced (Stories 3–5 cue-play implementation).
- **No external API/SDK dependencies**.
- **No pending design ADRs** — every system in Sprint 12 scope has accepted-state ADRs governing it.

## Definition of Done for Sprint 12

- [ ] All 6 Must Have tasks (S12-M1 through S12-M6) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] Recruit flow live: player taps Recruit Mage → Economy gold deducted → HeroRoster has new Mage → hero_recruited signal fires → cost increments per ADR-0013 + ADR-0015
- [ ] Offline progression: 30-minute idle session produces a non-empty OfflineSummary on next launch; cap clips at 8h per ADR-0005 default; signal-suppression contract verified by CI grep
- [ ] Audio cue-play: every signal in audio-system.md §C.3 produces an audible cue (placeholder OK if S12-S5 ships) with no `push_error` from AudioServer
- [ ] At minimum S12-S1 (re-playtest) executed and documented in `production/playtests/playtest-05-sprint-12-2026-XX-XX.md`
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code reviewed (inline review during `/code-review` per Sprint 6–11 pattern)
- [ ] Test suite ≥99% pass rate (Sprint 11 baseline 1281/1281 PASS; Sprint 12 nominal target ≥1350)
- [ ] Sprint 12 closure note documents what shipped vs. deferred to Sprint 13

## Sprint 13+ candidates (post-Sprint-12)

- **First-run onboarding flow** — currently no tutorial; new players land in Guild Hall with no guidance
- **Settings overlay UI** — wires the AudioRouter volume API + accessibility toggles (reduce_motion) into a player-visible screen
- **Multi-floor picker / multi-biome unlock** — replaces hard-coded forest_reach floor 1
- **Real audio asset commission/license/AI-under-license** — currently silent placeholders
- **Per-hero detail / inspection screen** — currently no way to view hero stats individually
- **HeroLeveling rank-13 implementation** — currently the +1 stub from Sprint 10 S10-M4
- **Save schema version migration** — first MAJOR schema bump (planned for Sprint 13 if any breaking change lands; CURRENT_SAVE_VERSION 1→2)
- **Cloud-save validation** (V1.0) — pool integrity verification per ADR-0015 deterministic seed
- **Daily-reset signal** for refresh_cost(refreshes_today) — currently resets on app boot per ADR-0015 OQ-0015-1 MVP scope
- **Tamper modal UX** (Save/Load Story 013) — currently emits `tamper_detected_on_load` signal but no UI surface

## Closure Notes

### S12-M5 — OfflineProgressionEngine batch chunking + signal suppression + cap (✓ DONE 2026-05-06)

Verdict: **COMPLETE**.

Replaces the S12-M4 stub body in `run_offline_replay` with the production chunked replay loop per ADR-0014 §C.2 + GDD §C.2 (`src/core/offline_progression_engine/offline_progression_engine.gd` lines 207–300). Per-chunk loop calls `Orchestrator.compute_offline_batch` then `Economy.compute_offline_batch`, accumulates into `OfflineSummary`, yields one process_frame, and adapts chunk size per ADR-0014 §D.3 (deadband [9,15] ms, ratio 0.6, clamp [500, 50000] ticks). Signal suppression flags set TRUE before the loop, FALSE after, then `flush_offline_signals` is called on each domain in canonical order. `_replay_in_flight` cleared BEFORE emit per GDD §E.6 (listener exception must not leave the engine stuck mid-flight).

**Commits**:
- `fa6dfd9` — S12-M5: implementation + 3 test suites (851 +/6 -)
- `bba0965` — fix: add missing `_data_registry_can_resolve_test_class` helper to `tests/integration/hero_roster/save_load_round_trip_test.gd` (unblocks running unit + integration in one gdunit invocation; was a parse-error blocker surfaced during S12-M5 verification)

**Tests**:
- `tests/integration/offline_progression_engine/offline_batch_chunking_test.gd` (NEW, 570 lines, 20 tests, Groups A–I).
- `tests/unit/offline_progression_engine/offline_forbidden_patterns_ci_grep_test.gd` (NEW, 178 lines, 10 tests). Group E grep recognizes both `if not _is_offline_replay: emit` and `if _is_offline_replay: ... else: emit` as valid guards.
- `tests/unit/offline_progression_engine/offline_progression_engine_skeleton_test.gd` (modified) — three pre-S12-M5 tests now `await` the rewards signal since the loop body is async.

**Verification (2026-05-06)**: 1068 unit + 300 integration = **1368 tests, 0 failures, 0 errors**. The 3 OE suites alone are 46/46 PASS.

**Process notes captured**:
1. Initial test file authored against fictional gdunit4 API (`watch_signals`, `was_emitted_once`, `get_signal_emissions`, `clear_signal_emissions`, `raise_error` — none exist in this project's gdunit4). Lesson: validate the test framework's actual API surface BEFORE authoring 25 tests against it. Project pattern is `assert_signal(instance).wait_until(ms).is_emitted("name")` plus the canonical Array-spy lambda capture (see `tests/integration/scene_manager/request_screen_and_node_swap_test.gd`).
2. S12-M5 introduced an async-emit regression in 3 pre-existing skeleton tests (they expected synchronous emit against the S12-M4 stub). Fixed by adding `await` on those tests. Lesson: when changing a synchronous API to async (`await get_tree().process_frame` per chunk), audit ALL existing tests that call the API.
3. Manual verification (load saved game with >30m elapsed → Return-to-App modal → OfflineSummary populated) **DEFERRED** to S12-S1 re-playtest scope.

### Carry-forward

S12-M6 (Audio cue-play Stories 3–5) is the only remaining Must Have for Sprint 12. S12-S1 (re-playtest with persisted save) is unblocked once S12-M6 lands.

## Notes

- Authored 2026-05-05 by post-Sprint-11 close-out work (autonomous-execution session). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 12 kickoff (2026-05-26).
- The Sprint 12 nominal date range (2026-05-26 → 2026-06-04) follows the same 9-working-day cadence as Sprints 10 + 11.
- This plan inherits the "investigation-before-execution" discipline from Sprint 10/11 — every Must Have story should run a pre-flight grep against the codebase BEFORE starting work, per the Honest Dependency Status Check protocol established in Sprint 11.
- Sprint 11's autonomous-execution session shipped a substantial pre-emptive bridge into Sprint 12 (13 bonus stories including all 3 missing CONSUMER_PATHS GDDs + ADR-0015 + flush_offline_signals + skeletons). Sprint 12's scope reflects this: more implementation, less design.
- The Sprint 12 sprint goal (cozy idle-game register, end-to-end) closes the MVP gameplay loop. After Sprint 12, the remaining work is polish + content (Sprint 13+).
