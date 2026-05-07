# Sprint 13 Retrospective — 2026-05-07

**Sprint window**: 2026-06-08 → 2026-06-17 (nominal)
**Closure date**: 2026-05-07 (deep pre-emptive — closed during the post-Sprint-12 + Sprint-14-prep autonomous-execution session, with the final S13-M1 audio sourcing decision landing 2026-05-07 via ADR-0016)
**Effective duration**: rolled into the Sprint 12 close-out and Sprint 14 prep cadence; Sprint 13 never had a distinct nominal-window block of work
**Review mode**: solo
**Stage**: Production

This retro continues the autonomous-execution Day-0-absorption pattern that Sprints 10/11/12 established, with one notable inflection: Sprint 13 became the sprint where the pre-emptive surface area finally exhausted itself. By 2026-05-07 every actionable Sprint 13 item was either CLOSED or reclassified as "needs human/budget" and pushed to Sprint 14+. The S13-M1 audio sourcing decision, which Sprint 12's retro flagged as Sprint 13's single highest-priority gating item, took until 2026-05-07 (post Sprint 14 plan authoring) to lock — the longest single carry-forward in the project to date.

---

## What was completed

| ID | Title | Priority | Realized cost | Plan estimate |
|---|---|---|---|---|
| S13-M2 | Return-to-App Screen wire-up | Must Have | ~0.75d (pre-emptive 2026-05-06) | 1.0d |
| S13-M3 | OE Story 10 E2E offline replay budget verification test | Must Have | ~0.4d (pre-emptive 2026-05-06) | 0.5d |
| S13-M4 | `tests/PATTERNS.md` authoring | Must Have | ~0.25d (pre-emptive 2026-05-06) | 0.25d |
| S13-S1 | S10-S1 carry-forward — Story 013 orchestrator state buffering during TRANSITIONING | Should Have | ~1.0d implementation + 0.25d tests (~1.25d total — matched estimate) | 1.25d |
| S13-S2 | S10-S3 carry-forward — scene_manager test env flakes cleanup | Should Have | ~0.5d (the `_settings_cfg_path` pattern from S12-S2 was already half the fix) | 0.5–1.0d |
| S13-S3 | M3 Stories 5-6 — cost-stability invariant tests + Save/Load schema migration scaffold | Should Have | ~0.6d (pre-emptive 2026-05-06; Recruitment closure work) | 0.75d |
| S13-M1 | Audio asset sourcing decision (ADR-0016 silent-MVP) | Must Have (gating) | ~0.4d (decision authoring + game-concept.md update + audio-system.md OQ-AS-6 resolution) | 0.5d (decision) + 1.0d (if non-silent — N/A) |
| **Realized total** | | | **~4.4d** (across two sessions: Sprint 12 close-out 2026-05-06 + post-Sprint-14-prep 2026-05-07) | **~4.25d** |

The Sprint 13 design-coverage push (5 first-pass GDDs drafted, closing systems-index.md "Not Started" gaps) is technically Sprint-13-window work since it landed during the Sprint-12 close / Sprint-14-prep session. Counted under Sprint 14 prep groundwork rather than Sprint 13 retro since the GDDs unblock S14 stories specifically.

## What was deferred

| ID | Title | Reason | New home |
|---|---|---|---|
| S13-S4 | `reduce_motion` + audio sliders Settings overlay UI | Depends on Settings GDD #30 design-review APPROVED — that's an interactive `/design-review` skill the autonomous session can't run | Sprint 14 S14-M3 (now its single home post-S14-M1 unblock) |
| S13-N1 | AudioRouter `_test_play_*_log` debug-spy pattern ADR | 2nd consumer threshold not met (Settings overlay UI is the candidate 2nd consumer; lands in S14-M3) | Sprint 14 S14-N1 (re-thresholded after S14-M3 lands) |
| S13-N2 | S10-N2 carry-forward — re-dispatch shortcut on main_menu | UI work; small but main_menu UI surface; deferred when S13 had Should-Have surplus | Sprint 14 S14-N2 (5-sprint deferred carry-forward) |
| S13-N3 | Audio bus volume sliders polished | Pairs with S13-S4 (Settings overlay UI) — same gating | Sprint 14 S14-N3 (absorbed into S14-M3 if cleanly wired) |
| S13-N4 | M3 Story 7 — RecruitScreen wire-up | Needs UX pass for recruit-card layout — not autonomously decidable | Sprint 14 S14-S4 (with explicit UX gate noted) |

The Sprint 13 plan also flagged S13-M1's non-silent branch (1.0d sourcing pass) — that branch resolved to "do not execute" via ADR-0016's silent-MVP decision, so the 1.0d was reclaimed.

---

## What went well

1. **Sprint 13's three pure-engineering Must Haves closed cleanly during Sprint 12 close-out work.** S13-M2 (Return-to-App Screen) + S13-M3 (E2E offline replay test) + S13-M4 (`tests/PATTERNS.md`) all landed pre-emptively 2026-05-06. The pattern that worked: each was a discrete, well-scoped piece with a single artifact; none required a creative call or external review. The pattern that DIDN'T work for S13-M1: same session attempted to land the audio sourcing decision but stalled because the decision-tree had budget/timeline branches the autonomous session could not bind. Pure engineering work amortizes well into Day-0 sessions; binding decisions need a separate authoring pass.

2. **The Story 013 orchestrator state buffering closed a 3-sprint carry-forward.** S10-S1 was deferred from Sprint 10 → Sprint 11 → Sprint 12 → Sprint 13 because the early scoping ("0.5d" → "1.5d") kept colliding with sprint capacity. S13-S1 finally landed at 1.25d realized cost (matching the late estimate), via a clean refactor: `_buffered_state_change` field + slow-path `_on_state_changed` as the sole RUN_ENDED handler + screen-level early-detection block removed. The lesson: **carry-forward items deserve a re-scoping pass at the start of every sprint they enter** (not just the first sprint they're scheduled). S10-S1's 0.5d original estimate was wrong from the start; honest scoping at Sprint 11 entry would have caught it 2 sprints earlier.

3. **The S12-S2 `_settings_cfg_path` test-isolation pattern paid off in S13-S2.** Sprint 12 invested ~0.2d to extract a per-instance ConfigFile path override on SceneManager. Sprint 13 reused that pattern in S13-S2 to fix scene_manager test env flakes — net cost ~0.3d (vs. 0.5–1.0d planned). Cross-sprint pattern investment is real: short, focused refactors that improve test isolation pay back within 1-2 sprints.

4. **`tests/PATTERNS.md` distilled hard-won institutional knowledge.** Sprint 12 retro flagged it as a Nice-to-Have estimated at 0.25d. Sprint 13 closed it at 0.25d realized cost. The doc captures the gdunit4 canonical API surface, Array-spy lambda pattern, hygiene-barrier pattern, ConfigFile path-override pattern, async-API-change audit checklist, and the forbidden-API list. Future test-authoring work (including agent delegations) should reference it, eliminating most of the gdunit4-API-mismatch class of regression that S12-M5 surfaced.

5. **The design-coverage push closed 4 Sprint-13-vintage "Not Started" gaps.** systems-index.md showed 14 "Not Started" GDDs at Sprint 12 close; 5 first-pass drafts during the Sprint-14-prep session brought it to 10. Hero Leveling GDD #15 (drafted Sprint-14-prep, implemented S14-M4) is the canonical demonstration: a 1-session GDD authoring → in-session implementation cycle. Pre-emptive design coverage compounds — each GDD drafted is one less Sprint-N+M blocker.

6. **Sprint 14 plan groundwork landed during Sprint 13 close.** The 0.25d sprint-plan groundwork item (S13-S2 in spirit — though not numbered) authored sprint-14.md with 5 Must Haves + 5 Should Haves + 3 Nice-to-Haves pre-scoped. Sprint 14 entered with a complete plan and zero re-scoping cost on Day 0.

## What was surprising

1. **The audio sourcing decision required four sprints to land.** S13-M1 was scheduled Sprint 13 explicitly as "the sprint where the audio decision lands". It carried into Sprint 14 (S14-M1), and only resolved 2026-05-07 with ADR-0016 (silent-MVP path). The reasons for the delay: (a) the decision tree had a budget branch the autonomous session could not bind without explicit user authorization, (b) the silent-MVP path had no apparent urgency because AudioRouter degrades gracefully, (c) downstream items (Settings overlay UI) were also gated on other things (Settings GDD review), so the audio decision wasn't on the critical path. **Lesson**: gating decisions that benefit from human input should explicitly state "needs user input" in the sprint plan, not just be tagged with a generic owner. If S13-M1 had been tagged "BLOCKED — user budget call required" in sprint-13.md, it would have surfaced earlier as something to ask, not something to attempt.

2. **The `Array[Dictionary]` typed-collection literal-rejection gotcha resurfaced.** S14-M4 Story 4 hit the same pattern Sprint 11/12 captured in `project_typed_collection_test_fixtures.md` — `Array[Dictionary]` field rejects untyped `[]` literal assignment from test fixtures; must use a typed local var first. The memory item caught it on the first re-run, but the fact that this gotcha keeps catching net-new test code suggests it should be in `tests/PATTERNS.md` (not just session memory). **Recommendation**: extend `tests/PATTERNS.md` with a "Typed-collection assignment in test fixtures" section. ~0.1d.

3. **The strict-AC reading on AC-15-02 (XP-per-floor-clear ties to first_clear signal) introduced a UX subtlety.** Hero Leveling GDD §C.2 + AC-15-02 say "floor_cleared_first_time signal causes XP to increase". Strict reading = XP only on first-ever lifetime clear; re-runs of cleared floors get kill-XP only. This was implemented in S14-M4 Story 3 (XP grant moved INSIDE `if awarded:` Layer 3 sub-branch). **Surprise**: the §D.4 cap-rate sanity check assumes "per run" XP — if floor-clear XP is only first-ever, the cap-rate slows materially for players who've already cleared all floors. OQ-15-1 already flags this for playtest calibration, but the implementation makes a calibration call (strict AC) ahead of playtest data. Captured as documented in the S14-M4 Story 3 commit body. If post-launch playtest shows leveling drag for re-grinding players, the calibration fix is a one-line move (XP grant out of `if awarded:` branch, into Layer 2 gate).

4. **5/5 first-pass GDDs drafted in one session was a cadence inflection.** Prior sprints averaged ~1 GDD per session. The Sprint-14-prep session drafted Settings + Hero Leveling + Onboarding + UI Framework + Return-to-App in one block. Two factors enabled this: (a) reverse-documentation paths (UI Framework + Return-to-App) describe shipped code rather than fresh design, (b) the systems-index.md "Not Started" list provided a backlog with clear scope. Pure-design GDDs are still slower (Settings + Hero Leveling + Onboarding took the bulk of the time). **Lesson**: reverse-doc GDDs are cheap; fresh-design GDDs benefit from being authored in a focused session rather than spread across multiple.

5. **Sprint 13 effectively never had a distinct execution window.** The plan was authored, but the items closed in Sprint-12-close-out + Sprint-14-prep work. There was no "Sprint 13 Day 1" — only "items previously in Sprint 13 plan" and "items from Sprint 12 retro that became Sprint 13 follow-ups". This is the natural endpoint of the pre-emptive Day-0-absorption pattern, but it has accounting consequences: realized cost is hard to attribute to a specific sprint window. The Sprint 12 retro flagged this in its "What to change" section (#2 — log pre-emptive Sprint-N+1 work AT Sprint-N close-out time, not amortized). Sprint 13 did NOT follow that recommendation — pre-emptive items got logged in active.md but not back-attributed in sprint-N+1.md. The retros are still readable, but tracking discipline is loose.

## What to keep doing

1. **The Day-0 / pre-emptive cadence for pure engineering items.** S13-M2 + S13-M3 + S13-M4 closed during Sprint 12 close-out. S14-M4 closed during this Sprint 13 retro session. Each is a clean engineering deliverable; absorbing them into the close-out window saves the "Day 1 ramp-up" cost of a fresh sprint window.

2. **Test-isolation pattern propagation.** S12-S2 → S13-S2 demonstrated that test-isolation patterns extracted in one sprint pay back within 1-2 sprints. Sprint 14 should continue this: when S14-M3 (Settings overlay UI) lands, look for opportunities to extract test-friendly DI patterns into `tests/PATTERNS.md`.

3. **`tests/PATTERNS.md` as the single source of truth for test idioms.** Going forward, any new test idiom that appears in 2+ test files should be documented there. Sprint 14 candidates: typed-collection literal assignment pattern (item #2 in "What was surprising" above), the RecordingOrchestrator subclass pattern from S14-M4 Story 4 (used to capture method calls without affecting live state).

4. **Carry-forward re-scoping at every sprint entry.** S13-S1 (S10-S1) finally landed at 4× the original 0.5d estimate. The honest re-scoping at Sprint 11 entry (1.5d realistic) was correct; Sprint 13's "1.25d" was the closest accurate scope. Apply this discipline at Sprint 14 → Sprint 15 transition: re-scope S14-N2 (5-sprint deferred re-dispatch shortcut) honestly before scheduling.

5. **Reverse-doc GDDs for shipped systems.** UI Framework GDD #18 + Return-to-App Screen GDD #20 are reverse-docs; they cost less than fresh-design GDDs and fill the systems-index gap immediately. Apply where shipped systems lack GDDs.

6. **Pre-emptive Sprint-N+1 plan authoring during Sprint-N close.** Sprint 14 plan authored during Sprint 13 close cost ~0.25d but unblocked Day 0 of Sprint 14 entirely. Sprint 14 should author Sprint 15 plan groundwork during Sprint 14 close.

## What to change

1. **Tag binding-decision items with explicit "needs user input" markers.** S13-M1 took 4 sprints to resolve partially because the autonomous session never explicitly surfaced "this is BLOCKED on a user decision". Future sprint plans should distinguish "implementation-ready" items from "decision-ready, needs user input" items. Recommended marker in the sprint plan owner column: `decision: user` or `BLOCKED: needs user input`. The autonomous session then knows to ask, not attempt.

2. **Back-attribute pre-emptive Sprint-N+1 work in the Sprint-N+1 plan.** Sprint 12 retro recommended this; Sprint 13 didn't follow through. Sprint 14 should: when S14-M4 closure lands during Sprint 13 close, sprint-14.md gains a "completed pre-emptively 2026-05-07" annotation against M4. This makes per-sprint realized-cost attributable. Apply at Sprint 14 close for any S15+ work that pre-empts.

3. **Add typed-collection literal-rejection pattern to `tests/PATTERNS.md`.** ~0.1d. Currently lives only in `~/.claude/projects/.../memory/project_typed_collection_test_fixtures.md`; promoting to repo-tracked PATTERNS.md surfaces it for non-Claude developers.

4. **Sprint 13 effectively skipped a distinct execution window — that's a process anomaly worth flagging.** The pre-emptive Day-0 cadence has now compounded to where Sprint 13 had no Day 1 at all. Sprint 14 starts with substantially less pre-emptive surface (per Sprint 12 + 13 calibration warnings). If Sprint 14 also closes during Sprint 13 close-out, sprint windows will become decoupled from execution windows entirely. **Recommendation**: explicitly track the pre-emption ratio (realized-cost-during-prior-sprint / total-realized-cost). When the ratio exceeds 0.5, the next sprint's calibration warning gets escalated to a hard "no pre-emption permitted" rule for at least 50% of capacity, or the sprint gets re-baselined.

5. **The §D.4 cap-rate calibration vs §C.2 strict-AC implementation tension on Hero Leveling needs playtest data.** S14-M4 Story 3 made an implementation call that's defensible against the AC but may produce leveling drag for players re-grinding cleared floors. OQ-15-1 already flags this. **Recommendation**: prioritize a Hero Leveling-focused playtest in Sprint 14 S14-S1 (the manual playtest) to validate the calibration before the design becomes load-bearing for downstream content.

## Risks / lessons for Sprint 14

1. **Sprint 14 has NO pre-emptive buffer.** Sprints 10-13 absorbed substantially more than planned via Day-0 sessions. Sprint 14 starts genuinely cold for items that aren't already absorbed. The remaining S14 work is: M2 (interactive design-review skill) + M3 (Settings overlay UI, ~2.0d implementation) + M5 (HD-2D shader pass, needs Steam Deck profiling). Each has external dependencies the autonomous session cannot satisfy alone.

2. **The S13-M1 → S14-M1 audio sourcing pattern repeats for S14-M5 (Steam Deck profiling).** S14-M5 needs hardware the autonomous session does not have. Like S13-M1, this should be tagged "BLOCKED: needs hardware access" explicitly. If a defensible "ship without HD-2D shader pass" decision exists (parchment theme alone), document it as Sprint 14's M5 fallback ADR — same pattern as ADR-0016 for audio.

3. **Settings GDD #30 review is the single largest gating dependency.** S14-M2 + S14-M3 are 2.5d of work both gated on the Settings GDD review pass converging on APPROVED or CONCERNS-only. The interactive `/design-review` skill is human-in-the-loop. **Mitigation**: Sprint 14 Day 1 should explicitly schedule the design-review with a time-box on revision (already noted in sprint-14.md S14-M2 plan).

4. **The pre-emption pattern continuing into Sprint 15 risks "no sprint" anti-pattern.** If Sprint 14 also closes during Sprint 13 close-out, and Sprint 15 also closes during Sprint 14 close-out, the project effectively executes one continuous autonomous session with sprint windows as accounting fictions. This may be fine (the work gets done!) but degrades the retrospective signal. Sprint 14 retro should explicitly compute the pre-emption ratio per "What to change" #4 above and decide whether to recalibrate the cadence.

5. **No new ADRs landed in Sprint 13 implementation; ADR-0016 (this session, classed as Sprint 14 S14-M1 work) is the first decision-locked artifact since ADR-0015 in Sprint 11.** ADR cadence is roughly one per sprint historically. Sprint 14 should expect 1-2 ADRs (S14-N1 debug-spy ADR if 2nd consumer materializes; possibly an HD-2D shader ADR if S14-M5's Steam Deck profiling reveals constraints).

## Memory items worth saving

These are insights from this session that future autonomous sessions should inherit (project memory adds beyond what was added during Sprint 12):

- **Binding decisions need explicit "needs user input" tagging.** The S13-M1 4-sprint delay is the canonical example. Sprint plans should distinguish implementation-ready from decision-ready items. *Captured to memory as feedback note: tag binding-decision items in sprint plans.*
- **Pre-emption ratio matters for retro signal.** When 50%+ of a sprint's realized cost happens during the prior sprint's close-out, the sprint window decouples from the execution window. Worth tracking explicitly.
- **Carry-forward re-scoping at sprint entry.** S10-S1 (3-sprint deferral, 4× original estimate) is the canonical lesson. Re-scope every carry-forward item honestly at every sprint entry, not just the first scheduling.
- **Reverse-doc GDDs are 2-3× cheaper than fresh-design GDDs.** Apply where shipped systems lack documentation.
- **The Hero Leveling AC-15-02 strict-AC vs §D.4 cap-rate tension.** If post-launch playtest shows leveling drag for re-grinding players, the calibration fix is a one-line move of XP grant out of `if awarded:` branch.

## Verdict

**Sprint 13: SUCCESSFUL but accounting-anomalous.** Definition-of-success bar (3+ Must Haves done; ≥99% test pass rate) was met. **1457 tests / 0 failures / 0 errors** at Sprint 12 close → **1493 tests / 0 failures / 0 errors** at Sprint 13 close (post-S14-M4 absorption) — net +36 tests across the Sprint 13 close-out + Sprint 14 prep + Hero Leveling implementation work. 4/4 Must Haves are now closed counting S13-M1's 2026-05-07 ADR-0016 landing. All actionable Should Haves closed. Two Nice-to-Haves (N2 + N4) deferred with explicit rationale.

The autonomous Day-0 closure pattern continued, but Sprint 13 surfaced its first systemic limit: the gating decision (S13-M1 audio sourcing) that benefits from human input couldn't close in autonomous-only sessions. The 4-sprint delay between authoring (Sprint 11 audio-system.md OQ-AS-6) and resolution (ADR-0016 2026-05-07) is the canonical "binding-decision-needs-user-input" gap that future sprint plans should explicitly mark.

**Recommendation**: Sprint 14 plans should (a) accept that no pre-emptive buffer remains (per Sprint 12 + 13 retros), (b) tag any remaining binding-decision items as "BLOCKED: needs user input" or "BLOCKED: needs hardware access" so the autonomous session knows to ask not attempt, (c) explicitly compute the pre-emption ratio at retro time, and (d) prioritize an early Hero Leveling playtest signal to validate the OQ-15-1 calibration before the curve becomes load-bearing for later content.
