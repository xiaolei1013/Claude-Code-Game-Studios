# Sprint 26 — 2026-07-10 to 2026-07-23

> **Status: Retroactively authored 2026-05-16** after the sprint's content work shipped directly (PRs #158-#164). Mirrors the Sprint 25 closure pattern: ship before plan, document the plan for the canonical record. Thirteenth consecutive same-day-compressed sprint (Sprint 14 → 26).
> Solo review mode.

## Sprint Goal — MET (player-visible content delivered)

**Continue the content-pivot from Sprint 25 — expand the class roster, surface progression-gated biomes correctly in Dispatch, and close the synergy gap created by the new tier-2 classes.**

Why this scope: Sprint 25's playtest verdict was still pending, but the underlying content surface was already 80% wired. The 5-of-9 Sprint-24 non-player-visible PR ratio is gone — Sprint 26 shipped 5 player-visible PRs, 1 hygiene refactor (triggered by Rule-of-Three), and 1 critical hotfix.

## Pre-Plan Disposition

| PR / Gate | Status | Action |
|-----------|--------|--------|
| **Sprint 25 retro** | DRAFT (playtest verdict pending) | Continued in DRAFT; Sprint 26 work doesn't depend on Sprint 25 closure |
| **playtest-16** | Templates ready | Tester to grade after deeper playthrough; not blocking Sprint 26 |

## Tasks (all shipped)

### Must Have

| ID | Task | PR | Status |
|----|------|----|----|
| S26-M1 | Dispatch floor picker honors `FloorUnlock.get_available_biomes()` (R7 compliance) | #158 | DONE |
| S26-M2 | Berserker class (6th class, brawler archetype) | #159 | DONE |
| S26-M3 | Cleric class (7th class, support archetype, 2x tick_output) | #161 | DONE |
| S26-M4 | Tier-2 class synergies (Bastion / Volley / Frenzy / Vigil) + multiplier resolvers + locale + tier mapping + GDD §C.6 amendment | #164 | DONE |
| S26-M5 | Sprint 26 playtest + retro | TBD | **HUMAN-BLOCKED** |

### Nice to Have (shipped opportunistically)

| ID | Task | PR | Status |
|----|------|----|----|
| S26-N1 | ClassRegistrationTestHelper (Rule-of-Three refactor; future class tests are ~50 LOC) | #160 | DONE |

### Cleanup PRs (not story-tracked)

| PR | Purpose |
|---|---|
| #162 | `/simplify+/review` cleanup pass on Sprint 26 (stale reference + handler rename + stat-name guard) |
| #163 | Hotfix: const PackedStringArray parse error + Godot-regenerated UIDs + .uid sidecars |

## By the Numbers

- **PRs this sprint**: 7 (5 content/UX + 1 refactor + 1 hotfix). 1 still pending = M5 playtest+retro.
- **Player-visible PRs**: 5 of 7 (~71%) — improvement over Sprint 24's 2 of 10 (20%) and on par with Sprint 25's 4 of 6 (66%).
- **Tests added**: ~36 (paladin-style 8 × 2 classes + tier-2 multiplier tests 15 + tier-2 detection tests 8 + lock-indicator-already-shipped 3 + biome-filter 3 — note some of these were earlier sprints).
- **Classes shipped**: 5 → 7 (paladin already shipped Sprint 25; this sprint added berserker + cleric = +2)
- **Synergies detectable**: 4 → 8 (Bastion + Volley + Frenzy + Vigil added)
- **Dispatch UX**: 6 confusing tabs → 4 starter biomes + chain reveal
- **Tier-2 roster coverage**: 5/7 classes now have mono-class synergies (paladin/archer/berserker/cleric); only the 3 V1 MVP classes had them before

## What Worked

- **Grep-first GDD-existence check ran cleanly throughout sprint planning.** No duplicate GDD authoring this sprint (the Sprint 25 mistake didn't repeat).
- **Content addition via pure data extension.** Both classes shipped as pure `.tres` + test files. DataRegistry auto-discovers, Recruitment auto-pools, ClassPortraitFactory auto-portraits. The data-driven infrastructure investment paid off.
- **Rule-of-Three refactor at the right moment.** The 3rd tier-2 class (berserker) triggered the ClassRegistrationTestHelper extraction. Cleric immediately benefitted (~50 LOC test file).
- **Tier-2 synergy work used the existing AC-CS-18 forward-compat path.** The orchestrator's `_:` fallback already returned 1.0 for unknown synergy_ids; adding 4 new match arms was purely additive, no system surgery needed.
- **Hotfix turnaround was fast.** Parse error caught + fixed within the same session as the cleanup PR.

## What Could Be Better

- **The const PackedStringArray parse error should have been caught BEFORE merging the cleanup PR.** A local `godot --headless --check-only` lint pass would have caught it. The cleanup PR was approved + merged without an editor open, so the parse error landed on main and broke the test runner. Process learning: run a parse check on test-helper changes before merging.
- **Hand-written placeholder UIDs in .tres files don't survive editor scan.** I wrote `uid://b2berserkermvp001` etc. (invalid format); the editor regenerated them. Twice. Process learning: never hand-author UIDs for new .tres files — leave the `uid="..."` attribute out and let Godot fill it on first import.
- **Sprint 25 retro is still DRAFT.** The playtest verdict on Sprint 25's content (boss floor visual, paladin, archer, lock indicator) hasn't been graded. Sprint 26 shipped MORE content on top, which compounds the playtest scope. Recommendation: tester should grade playtests 16 + 17 in a single pass.
- **No retroactive author / Day-0 plan for Sprint 26 means tracking was implicit.** The previous Sprint 25 had its Day-0 plan PR'd first; Sprint 26 work just happened. This retroactive doc closes that gap, but the pattern should be: plan first OR plan-and-implement bundled in the first PR.

## What I'd Do Differently Next Time

1. **Open the Godot editor once per session before/after substantial test-helper changes.** The parse error would have been visible in seconds; instead it landed on main.
2. **Skip hand-written UIDs.** Let Godot regenerate; if a UID must be referenced from elsewhere, use the path-based reference, not `uid://...`.
3. **Bundle Sprint Day-0 plan into the first content PR.** Saves the retroactive-authoring step + makes the sprint's intent visible at first PR open.
4. **Run playtest after every 4-5 content PRs**, not waiting for the end-of-sprint gate. Sprint 26's content surface compounded on top of Sprint 25's, which compounds the playtest grading scope.

## Sprint 27 Recommendations

**Provisional, pending playtest verdicts.**

If playtest-16 + playtest-17 grade well:
- **More UX hints for the new synergies.** Right now a player sees "Synergy: Gold (Bastion)" but doesn't know "Bastion gives +25% gold vs caster." The Dispatch label could append "→ +25% gold vs caster" when a conditional synergy is active.
- **Recruit pool size tuning.** With 7 classes and pool size 3, the chance of any specific class appearing per refresh is ~37%. Players who want to deliberately build a 3-of-a-kind synergy may find this frustrating. Consider increasing pool size to 5 OR adding a "filter by class" pool refresh option.
- **Real product art ingestion.** Still blocked on external workstream; ClassPortraitFactory continues to be the production path.

If playtest verdicts show specific gaps:
- Address the named gap first; defer broader content expansion.

**Anti-pattern guardrails** (per `feedback_infrastructure_debt_drift` + `feedback_grep_first_check_must_run_pre_planning`):
- No new GDD authoring stories without grep-first check
- No test fixture hygiene stories unless Rule-of-Three is met
- No engine optimization stories that produce zero player-visible change

## Sprint 26 Process Rules (carried forward)

1. **Per-task PR with `base=main`.** No stacked PRs. Continued from Sprint 25.
2. **Grep-first GDD-existence check** before any "author GDD X" story.
3. **Player-visible surface check at mid-sprint.** Halfway through, ask: *what does the player see different after the work shipped so far?* If "nothing yet", focus on M-tasks.
4. **Run godot editor / parse check on test-helper changes** before merging (NEW from Sprint 26 retro).
5. **Skip hand-written UIDs** on new `.tres` files (NEW from Sprint 26 retro).

## After Sprint 26

Sprint 27 candidates (pending playtest verdicts) — see Sprint 27 Recommendations above. Anti-pattern guardrails carried forward.
