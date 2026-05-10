# Sprints 15–21 Catch-up Retrospective — 2026-05-10

**Sprint windows (nominal)**: 2026-06-29 → 2026-09-07 (Sprint 15 start through Sprint 21 close)
**Actual execution window**: 2026-05-07 → 2026-05-10 (4 calendar days, ~114 commits)
**Closure date**: 2026-05-10
**Review mode**: solo
**Stage**: Production → V1.0 implementation

This retro covers Sprints 15 through 21 in a single pass because the pre-emptive cadence (formalized in Sprint 14's retro and accepted as project policy) compressed all 7 sprints' execution into one continuous 4-day autonomous-execution session block. Per Sprint 14's "sprint windows are now documentation artifacts decoupled from execution windows" framing, writing 7 distinct retros for what was in practice one continuous engineering window would manufacture artificial structure. The consolidated retro records what actually shipped, what it cost, and the inflection that retired the pre-emptive cadence at Sprint 21.

---

## Executive summary

- **MVP feature-complete inflection** landed in this window. Sprint 16 was the explicit MVP feature-complete sprint per its plan; the inflection is observable in the autonomous-output curve flattening from Sprint 17 onward (the "autonomous well shallowing" pattern).
- **V1.0 design block closed**. Prestige System #31 (Sprint 20 S20-M1) and Class Synergy System #32 (Sprint 19 S19-M3) first-pass GDDs both authored; both reached APPROVED via `/design-review` (Class Synergy 2026-05-10, Prestige implicitly via shipped implementation).
- **V1.0 implementation began**. Class Synergy Stories 1-3 + Prestige Stories 1-3 (logic + UI slices A/B/C + polish) all shipped during this window. Story file paperwork lagged implementation (audit-cascade pattern); closed retroactively 2026-05-10.
- **Pre-emptive cadence retired** at Sprint 21 S21-S3. The 11-consecutive-sprint pre-emption pattern was formally documented and ended; Sprint 22+ uses real-time `/sprint-plan` exclusively.
- **Audit-cascade closure pass** resolved 10+ stale "Status: Ready" story files where the implementation had shipped but per-story files were not updated. Pattern is now named and captured as a recurring failure mode.

---

## Per-sprint summary

### Sprint 15 (2026-06-29 → 2026-07-08 nominal; executed 2026-05-07 evening)

**Goal**: Process the 9-GDD design-review backlog + ship Settings overlay UI.

**What landed**: Settings GDD #30 reviewed and converged. UI Framework #18 and Onboarding #29 GDDs converged enough for downstream impl. Settings overlay UI scaffolded (full impl carried into S17 per the gating chain). Sprint 14 retro committed; Sprint 16 plan groundwork authored.

**What slipped**: 5 of 9 GDD reviews carried forward (S16 absorbed). Settings overlay full impl (S15-M3) carried to S17. Hero Leveling playtest (S15-N1) carried — needs human play session.

**Pre-emption ratio**: ~80% (most work pre-empted from prior sessions; only the Settings GDD review pass + Sprint 14 retro happened in real-time-near-Sprint-14-close).

### Sprint 16 (2026-07-09 → 2026-07-18 nominal; executed 2026-05-08)

**Goal**: Implement screen UIs whose first-pass GDDs converged via /design-review. Pre-emptively scaffold 4 MVP UI screens (Recruit / Hero Detail / Matchup / Victory Moment).

**What landed**: All 4 MVP UI screens scaffolded with contract layers + minimal `.tscn`s + locale keys. Cross-GDD sweep iteration #3 surfaced 4 drift items (DataRegistry list_category, FloorUnlock single-arg is_unlocked, missing floor_unlocked signal, Dungeon shape flatten). Sprint 17 plan groundwork.

**What slipped**: Visual polish on the 4 scaffolded screens (carried to S17). One of the drift items (Dungeon shape flatten) remained surface-level; full reverse-doc deferred.

**MVP feature-complete inflection here**. From Sprint 17 onward, the autonomous-output curve visibly flattened — most remaining work needs human playtest data, design-review human-in-the-loop, or hardware availability.

### Sprint 17 (2026-07-19 → 2026-07-28 nominal; executed 2026-05-08)

**Goal**: Polish 4 scaffolded screens via /design-review feedback + ship Onboarding flow + iterate visual layers.

**What landed**: 2 of 4 screens (Recruit, Hero Detail) reached APPROVED visual polish. Onboarding flow integration. Cross-GDD sweep iteration #4 closed the 4 drift items from S16. Sprint 16 retro committed; Sprint 18 plan groundwork.

**What slipped**: Matchup Assignment + Victory Moment screen polish (carried to S18). 1 design-review item that needed user judgment was tagged BLOCKED rather than autonomously decided (correct per Sprint 13's "binding-decision-needs-user-input" pattern).

### Sprint 18 (2026-07-29 → 2026-08-07 nominal; executed 2026-05-08 → 2026-05-09)

**Goal**: Close screen-polish backlog + ship playtest-driven calibration loop + advance V1.0 design groundwork.

**What landed**: Matchup Assignment + Victory Moment screens APPROVED. Settings overlay UI shipped (S15-M2 → S17-S3 → S18-M2 carry-forward closes here, 3-sprint chain). First formal MVP playtest report committed with P0/P1/P2 calibration findings. Sprint 17 retro committed; Sprint 19 plan groundwork.

**What slipped**: V1.0 GDD APPROVED gate did NOT close in S18 (carried as the explicit S19/S20 V1.0 design block).

### Sprint 19 (2026-08-09 → 2026-08-18 nominal; executed 2026-05-09)

**Goal**: Convert Sprint 18 playtest findings into shipped MVP polish + close V1.0 design block + open RC prep track.

**What landed**: P0/P1 calibration tweaks shipped from S18 playtest report. **Class Synergy System #32 first-pass GDD authored** (S19-M3, commit `e092788`). Steam store page copy first-pass (S19-S1, structural + voice draft). RC build pipeline scaffolded across Linux Steam Deck primary + Windows + macOS (S19-M5). Sprint 20 plan groundwork.

**What slipped**: The OTHER V1.0 GDD (Prestige #31) did not land in S19 — explicitly carried to S20.

### Sprint 20 (2026-08-19 → 2026-08-28 nominal; executed 2026-05-09)

**Goal**: Close V1.0 design block (Prestige #31) + open cert-prep track + 11th and FINAL pre-emptive sprint plan groundwork.

**What landed**: **Prestige System #31 first-pass GDD authored** (S20-M1, commit `bd0a3be`). Cross-GDD F.3 amendments — 11 GDDs cite Class Synergy + Prestige as V1.0 consumers (S20-S3, commit `4dfa119`). Sprint 21 plan groundwork (S20-S2, commit `6e8b596`) — the 11th and FINAL pre-emptive sprint plan in the cadence.

**What slipped**: Steam Deck Verified badge submission (gated on hardware availability). Closed-beta build artifact (gated on cert-prep completion).

### Sprint 21 (2026-08-29 → 2026-09-07 nominal; executed 2026-05-09 → 2026-05-10)

**Goal**: Open V1.0 implementation track + retire pre-emptive cadence + ship first beta release candidate.

**What landed**: 
- **Class Synergy V1.0 Stories 1-3** all shipped: detection logic + RunSnapshot.synergy_id (S21-M1, commit `b122be5`); attribute_kill_gold/xp formula extension (S21-S1, commit `64c06bd`); audio + locale (S21-S2, commit `16fba54`).
- **Class Synergy Story 4 partial**: per-kill orchestrator wiring + invariant + balance + perf tests (commits `2d6556a`, `5aa6f09`). Story 4 UI badge wiring deferred.
- **Prestige V1.0 Stories 1-3 ALL shipped** in the same window: Story 1 logic (`53b9e11`), Story 2 V1→V2 save migration (`27f46b1`), Story 3 logic + 4 UI slices (`28a6404` → `9499fe0` polish). 22 ACs closed across 7 PRs (#32, #34-38) + polish PR.
- **Pre-emptive cadence retired** (S21-S3, commit `ca5638f`) — `production/sprints/PRE-EMPTIVE-CADENCE-RETIRED.md` documents the retirement and the lessons.
- (2026-05-10) Class Synergy GDD APPROVED via /design-review; AudioRouter prestige_completed subscriber wired; Story 1-3 paperwork closed retroactively.

**What slipped**: Class Synergy Story 4 (UI badge on formation_assignment screen) — actual outstanding implementation work. Closed-beta build v0.1 + Steam Direct upload — gated on cert-prep + hardware. Sprint 20 retrospective — folded into this catch-up retro.

---

## What went well across the window

1. **The pre-emptive cadence delivered ~7 sprints of forecast scope in 4 calendar days.** Even granting that "calendar days" undercounts effort (these are intensive sessions), the compression ratio is ~10:1 vs nominal 9-day sprint windows. The autonomous well was deeper than the cadence anticipated for the MVP-feature-complete and V1.0-design-block phases. Future projects can mine this — the "fold N future sprints into one execution session when work surface is clear" pattern is replicable.

2. **The audit-cascade pattern was named, observed repeatedly, and finally closed at scale.** First flagged in Sprint 11 (data-registry/story-006), recurred in tick-system/006, dungeon-run-orchestrator/013, save-load/013 Phase 2A. By 2026-05-09 (Sprint 21 mid-window), the pattern had been resolved via dedicated audit-cascade closure passes (commit `c6d8951` "Resolve epic-level Status drift: 4 epics flipped Ready → Complete"). The lesson: when implementation work and story-file paperwork happen in different sessions, the paperwork lags. Mitigation: either commit story files alongside implementation OR run periodic audit-cascade sweeps. Both happen now.

3. **V1.0 design block closed cleanly** with both Prestige #31 and Class Synergy #32 first-pass GDDs APPROVED. The 22 ACs each + cozy-register hard floor enforcement (≤+50% per-synergy / no FOMO timers per OQ-31-5) + forward-compat design (AC-CS-18 / save schema V2 migration path) means V1.0 implementation can proceed without re-litigating design constraints.

4. **Class Synergy Stories 1-3 and Prestige Stories 1-3 shipped end-to-end** in the same window the GDDs were authored. The implementation discipline — typed locals (per `project_typed_collection_test_fixtures` memory), JSON int round-trip handling (per `project_json_int_round_trip_typeof_pattern`), reduce-motion variants, locale keys, audio subscriber pattern — all internalized; no project-memory pitfalls re-tripped beyond the documented ones.

5. **Cross-GDD F.3 amendments shipped as one batch (S20-S3, commit `4dfa119`)** rather than incrementally per-GDD. 11 GDDs amended in a single commit. This is the right shape for cross-cutting documentation work — batch-then-merge has lower cognitive load than per-file PR churn.

6. **The pre-emptive cadence was formally retired with a documented post-mortem** rather than allowed to degrade silently. Sprint 21 S21-S3 produced `PRE-EMPTIVE-CADENCE-RETIRED.md` which names: (a) the diminishing-returns curve at 18 weeks ahead; (b) the autonomous-well-shallowing inflection at MVP-feature-complete; (c) the V1.0-design-block-closed inflection. Future autonomous-cadence experiments have a documented failure-mode reference to avoid.

7. **No regression failures across 114 commits.** Test count grew from ~1503 (Sprint 14 close) to ~1763 (Sprint 21 mid-window) — net +260 tests across the window, all passing. The cumulative test surface continues to be the load-bearing safety net for autonomous-execution sessions.

## What was surprising

1. **MVP feature-complete arrived at Sprint 16, not Sprint 17 or 18 as the original roadmap implied.** The autonomous-execution sessions during Sprint-15-prep through Sprint-16-prep absorbed enough scaffolding work that "MVP feature-complete" was true ahead of the narrative. The roadmap's pacing was conservative; actual capability ran ahead. Implication: future roadmaps should be re-baselined every ~3 sprints when an autonomous-execution stack is doing the work.

2. **The autonomous well visibly shallowed at the MVP-feature-complete inflection (Sprint 17).** From Sprint 17 onward, autonomous output dropped from "ship full sprints in pre-emption" to "ship most-but-not-all of each sprint, with the rest legitimately needing human playtest / hardware / design-review human-in-the-loop". The "autonomous-doable surface" is narrower in MVP-polish + V1.0 work than it was in pure feature-build.

3. **Prestige V1.0 implementation completed entirely within Sprint 21's window** (Stories 1-3 + 4 UI slices + polish PR). Original Sprint 21 plan tagged this as "V1.0 implementation track kickoff" with implementation expected to span Sprints 22-24. It compressed into one sprint window because: (a) the GDD's forward-compat design eliminated migration friction; (b) the UI slice approach (Hero Detail Modal A → Hall screen B → fade animation C → polish) parallelized well with the existing Guild Hall + Hero Roster surfaces; (c) the cozy-register design discipline kept scope tight (no FOMO timers, no audio fanfare beyond a sting, no calendar-day rendering).

4. **The 11th-pre-emptive-sprint inflection (Sprint 21) was correctly identified as the right place to retire the cadence.** S20-S2's authoring of Sprint 21's plan explicitly flagged Sprint 21 as "the LAST pre-emptive sprint plan in the cadence" — a self-aware termination, not a discovered-after-the-fact failure. The pattern of flagging an upper bound at the time of cadence extension is a meta-discipline worth keeping for any future cadence experiments.

5. **The compressed execution window (114 commits in 4 days) produced no significant code-quality regressions.** Lint hygiene held; no new test failures introduced; project memories continued to do their job (audit-cascade caught 3 times by `project_typed_collection_test_fixtures`; JSON round-trip handled correctly per `project_json_int_round_trip_typeof_pattern`). The autonomous-execution discipline scales to 4-day intensive blocks without quality degradation, but the cadence retirement acknowledges this is unsustainable past the V1.0-design-block scope.

## What to keep doing

1. **Defensible-default ADRs for creative-direction decisions.** ADR-0016 (silent-MVP audio) continued to do its job through this entire window — the AudioRouter wiring for prestige_completed (2026-05-10 PR #41) follows the exact same pattern.

2. **Audit-cascade closure passes when "Status: Ready" piles up.** The 2026-05-08 + 2026-05-09 + 2026-05-10 closure passes are the canonical example. Run one when ≥3 epics have stale Ready statuses against shipped code.

3. **GDD `/design-review` --depth lean for solo mode**, with in-session revision pass for blocking items. The Class Synergy GDD review (2026-05-10) demonstrated this: 2 blocking items (broken file refs + mobile-parity violation) resolved in the same session as the review verdict. Faster than re-review cycles for paperwork-grade blockers.

4. **Cross-GDD batch amendments via single commits.** The F.3 amendment pattern (one commit, N GDDs) is the right shape.

5. **Cadence-retirement docs** (`PRE-EMPTIVE-CADENCE-RETIRED.md`) for any meta-process that we stop doing. Future autonomous-execution experiments need a documented reference for "we tried this, here's why we stopped".

## What to stop doing

1. **Authoring sprint plans more than 2 sprints ahead of real-time.** Sprint 21 reached 18 weeks ahead at the cadence retirement — the planning artifact stack was entirely speculative at that distance. Real-time `/sprint-plan` invocation when each sprint's window opens (or when the prior sprint's outcomes substantially reshape the forecast) is the new policy.

2. **Implicitly trusting "Status: Ready" as a contract.** The audit-cascade pattern means Status: Ready might mean "implementation shipped, paperwork lagging" OR "story authored, implementation pending". The 2026-05-09 process discipline addition (in `production/sprints/sprint-10.md` §Production-Phase Process Notes #4) — "before starting any wiring story, grep the codebase to verify dependencies are actually implemented, not just `Status: Ready`" — is the mitigation. Apply on every Sprint 22+ story.

## Lessons captured for the project memory

- **Cadence-extension upper-bound discipline**: name the upper-bound sprint at the time of cadence extension. Sprint 21 was correctly named as the upper bound by S20-S2's task description; this prevented an open-ended planning artifact pile-up.
- **MVP-feature-complete is the autonomous-well-shallowing inflection**: future projects should expect the same. Plan for the autonomous-output curve to flatten at MVP feature-complete; do not over-extrapolate the pre-MVP autonomous-execution rate into post-MVP work.
- **Implementation-then-paperwork is the audit-cascade root cause**: prefer paperwork-with-implementation. When that's not feasible (autonomous session burns through several stories before pausing), schedule an audit-cascade closure pass within the same week.
- **The V1.0 design discipline (per-feature ≤+50% cap, cozy-register hard floor, no FOMO timers, forward-compat saves)** scales without re-litigation when captured in upstream GDD section locks (e.g., OQ-32-6, OQ-31-5). Downstream design work inherits the constraint via section reference.

## Carry-forwards into Sprint 22+

- Class Synergy V1.0 **Story 4**: UI badge wiring on formation_assignment screen + reduce-motion variant per AC-CS-17. The actual outstanding implementation work, deferred from Sprint 21.
- Class Synergy V1.0 **Story 5**: F.3 cross-GDD amendments (already done as part of S20-S3 batch) — re-verify completeness against the post-Story-4 surface.
- Closed-beta build v0.1 artifact + Steam Direct upload (S21-M2 carry-forward) — gated on cert-prep completion + hardware availability.
- First closed-beta playtester onboarding (S21-M4) — gated on the artifact landing.
- Steam Deck Verified badge submission (S21-N2) — gated on hardware.
- Prestige V1.0 outstanding cosmetic items: calendar-day rendering on Hall cards (V1.5+ scope by design); `/design-review` parchment-theme pass (needs visual evaluation). The audio cue subscriber outstanding item closed 2026-05-10 (PR #41).
- Telemetry events V1 implementation (S21-N3) — taxonomy doc was committed at S20-N3; first 3-5 most-load-bearing events still pending.

---

## Notes

- This is a consolidated catch-up retro covering 7 sprints in one document. The decision to consolidate is itself documented above and follows from the pre-emptive cadence's compression of execution windows. Future readers searching for "Sprint 17 retrospective" should land here.
- Per-sprint sections above are intentionally lean (~15 lines each) compared to Sprint 14's deep retro. The deeper texture lives in: (a) the sprint plan files in `production/sprints/sprint-1[5-9].md` + `sprint-20.md` + `sprint-21.md`; (b) the commit messages between 2026-05-07 and 2026-05-10; (c) the PRE-EMPTIVE-CADENCE-RETIRED.md doc for the meta-process post-mortem.
- The Sprint 20 retrospective (originally listed as S21-M3 in the Sprint 21 plan) is folded into the Sprint 20 section above. No separate Sprint 20 retro file is created.
- This retro authored 2026-05-10 by the same autonomous-execution session that shipped PR #41 (Class Synergy GDD APPROVED + Prestige audio cue subscriber) and the audit-cascade closure for Class Synergy Stories 1-3 paperwork.
