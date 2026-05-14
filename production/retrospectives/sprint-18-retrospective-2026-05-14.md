# Sprint 18 Retrospective — 2026-05-14

> **Sprint Mapping**: S18-M5. Closes Sprint 18 (`production/sprints/sprint-18.md`).
> **Sprint Window**: 2026-05-14 to 2026-05-27 nominal; actual execution compressed to ~12 hours (same-day-compressed cadence — fourth consecutive sprint to land Day-0 plan + close in <24h).
> **Review Mode**: Solo.

## Sprint Goal — Met

> **Ship Class Synergy V1.0 — the first cross-class team bonus mechanic — and validate it feels rewarding without trivializing the cozy register.**

All three success conditions satisfied:
- (a) 4 synergies shipped end-to-end — Steel Wall (3W vs bruiser ×1.25 gold), Arcane Elite (3M ×1.20 XP), Triple Strike (3R vs armored ×1.25 gold), Triple Threat (1+1+1 ×1.15 gold). PRs #97 (GDD revisions), #98 (backend + ADR-0018), #99 (live preview + locale closeout). ✅
- (b) Playtest validated the synergies feel rewarding without trivializing — and surfaced two unrelated critical hidden bugs that had been silently degrading combat since Sprint 7 / Sprint 16. ✅
- (c) ADR-0018 (multiplier composition order) authored. The 18th architecture decision; cumulative ADR coverage continues to track sprint complexity. ✅

## By the Numbers

- **PRs merged**: 7 (#96 plan, #97 GDD revisions, #98 synergy backend + ADR-0018, #99 M3 + S1 + S2 closeout, #100 LOSING wiring, #101 materialize_enemy_list, #102 tilt-shift DoF + disable-by-default fix)
- **Cumulative tests at sprint close**: ~2393 PASS (was 2196 at Sprint 17 close — +5 tilt-shift + 2 disabled-by-default + 10 materialize_enemy_list + 5 losing_run_wiring + 5 triple_strike additions + other synergy tests across PRs #97–#102)
- **Regressions**: 0
- **Critical hidden bugs surfaced + fixed**: 2 — LOSING-run wiring (PR #100) + Floor.enemy_list never materialized (PR #101). Both predate Sprint 18.
- **Visible-content PRs**: 4/7 (#97 GDD, #98 synergy backend, #99 live preview, #102 tilt-shift infrastructure)
- **Hygiene / wiring-correctness PRs**: 3/7 (#96 plan doc, #100 LOSING wiring, #101 materialize fix)
- **ADRs authored**: 1 (ADR-0018 — multiplier composition order)

## What Worked

- **Playtest as load-bearing closure gate, again — and harder than Sprint 17.** Three rounds of playtest each surfaced a critical bug the 2300+ automated test suite missed. Round 1: "do we have failed dispatch if defeated?" → LOSING wiring (PR #100). Round 2: "we still no defeat status, can't progress" → Floor.enemy_list never materialized (PR #101). Round 3: "the UI is still weird" → tilt-shift UI ghost-smear (PR #102 disable-fix). Project memory `feedback_playtest_driven_closure` continues to compound in value — it is now the single highest-ROI quality gate in the project's process toolkit.
- **GDD re-review caught the 3-Rogue asymmetric class treatment gap.** First-pass GDD #32 design-review approved with revisions; the re-review (S18-M1 inside the active sprint) surfaced that 3 Warriors got Steel Wall, 3 Mages got Arcane Elite, but 3 Rogues got nothing. Triple Strike addition kept the synergy roster symmetric across the three MVP classes. The `/design-review` skill's Sprint 13→14 retro improvement (BLOCKING revisions inside the sprint, not the next) is paying compounding interest.
- **ADR-amendment test-coverage audit pattern (S2) was authored BEFORE its first triggering event.** S17 retro proposed it reactively after PR #90's multi-biome ledger collision; S18 added it to PATTERNS.md §15 preventively. First time in the project's process-improvement history that a closing-the-barn-door action was authored before a second horse escaped. The pattern caught nothing this sprint (no ADR amendments shipped) but the scaffolding is ready.
- **Bug discovery → bug fix → ship cycle stayed compressed.** Each critical bug surfaced in playtest was fixed, regression-tested, reviewed, and merged within a few hours of discovery. No deferral to "next sprint." Same-day-compressed cadence (Sprint 14→15→16→17→18) is now the established rhythm, not an outlier.
- **/review skill caught a rebase conflict resolution that lost a function.** PR #101's rebase onto post-PR-#100 main produced a stuck merge state where `_floor_total_enemy_attack` was silently dropped. The `/review` Phase 1 diff inspection caught the missing function before it shipped; the recovery merge preserved both functions cleanly. Pattern: `/review` is load-bearing on rebased branches with prerequisite-merge timing.

## What Hurt

- **Two critical scaffolded-but-unwired bugs the entire ~2200-test suite missed.** Same pattern, twice in one sprint:
  - **LOSING-run scaffolding** (`run_snapshot.losing_run` field, `LOSING_RUN_LOOT_FACTOR` constant, `attribute_kill_gold` parameter, the entire `survived` predicate machinery in the combat resolver) existed since Sprint 7 — but `hp_bonus_factor` was hardcoded to `1.0` in `_build_combat_snapshot`. Every dispatch was implicitly a WIN since S7-M13. ADR-0002 (LOSING reclaim) had been dead code for 11 sprints.
  - **Floor.enemy_list materialization** was deferred during MVP per the smoking-gun comment at `data_registry.gd:983` ("for MVP; other cross-refs (Floor.enemy_list[].enemy_id → EnemyData)"). Real Floor data stored `[{enemy_id, count}]` per ADR-0011 §Decision but combat read `entry.get("base_hp")` / `entry.get("archetype")` / `entry.get("base_attack")` — fields that didn't exist on the raw shape. Result: every real-floor dispatch silently produced degenerate combat (base_hp=0 → instant-kill cascades, archetype="" → matchup advantage never fired, formation_total_hp/floor_total_enemy_attack defensively returned 1.0 → losing_run always false). Pre-Sprint 16 the Forest Reach test data happened to use the synthetic shape that worked; Sprint 16 widened to 5 biomes using the real `{enemy_id, count}` shape and the issue lit up — but only on a playtest, not on any test.
  - **Same class of bug**: feature LOOKS wired in code (fields exist, methods declared, ADR authored) but a critical wiring step is missing, defaulted to a no-op constant, or deferred-with-`# MVP`-comment-and-never-landed. The test suite checks each piece in isolation; the integration is what's broken. **This is the dominant bug class on this project.**
- **N1 shader visual landed before its playtest.** Tilt-shift DoF on UI-only screens with no background art produced a "Gold: 1824" ghost-smear at the top of the Guild Hall (PR #102 first round). String-grep + scene-resolution tests verified "wiring is correct" but not "looks right on current content." The architecture mismatch (shader designed to blur background sprites; everything below it is currently UI text) wasn't catchable by any automated check we could realistically author. Should have shipped disabled-by-default from the start, matching the Sprint 15 N2 warm-lantern precedent. The disable-fix landed inside the same PR but it was a round-trip.
- **PR ordering surfaced rebase edge cases.** PR #101 was branched off main before PR #100 merged; the eventual rebase onto post-#100 main caused a stuck merge where conflict resolution lost a function. The user (correctly) preferred merge-not-force-push for the recovery; my initial force-push recommendation was reflexive and not the safer option for a solo branch. Lesson: when a prerequisite PR is mid-review, either wait for it to merge before branching, or rebase locally as soon as it merges (and run `/review` before pushing).

## Action Items for Sprint 19

| # | Action | Priority | Owner |
|---|--------|----------|-------|
| 1 | **Scaffolded-but-unwired audit, codified.** Both critical S18 bugs (LOSING wiring + materialize_enemy_list) share a pattern: feature exists in code shape but a wiring step is missing, hardcoded to a defensive constant, or `# MVP`-deferred-and-never-landed. Once-per-sprint, before the playtest gate, grep for: `= 1.0  # provisional`, `# MVP`, `# stub`, `# placeholder`, fields declared on snapshot objects that are never written outside `_init`, helper methods declared that are never called. Could be a `/check-scaffolds` skill or a manual pre-playtest pass. **This is the highest-ROI process improvement available right now** — both critical bugs this sprint, plus PR #90 multi-biome ledger collision last sprint, would have been caught by a deliberate scaffolds audit. | **HIGH** | producer + claude-code |
| 2 | **Sprint 19 theme decision.** Sprint 18 closed clean — no deferred work. Candidates: (a) Class synergy V1.5 — unlock cadence, V1.5 tuning based on playtest data, additional synergy types; (b) Real biome background art — would activate the N1 tilt-shift shader and is the biggest visual lift available; (c) Audio asset sourcing — ADR-0016 silent-MVP pivot has open playtest signal "would SFX help here?"; (d) New mechanic — prestige V1.5, hero traits, dungeon modifiers. Recommendation: pick on playtest signal, not roadmap velocity. | **HIGH** | user + claude-code |
| 3 | **`/review` on rebased branches is non-optional.** PR #101's stuck-merge function loss would have shipped had `/review` Phase 1 not caught it. Codify: any branch that's been rebased onto a prerequisite must run `/review` before push, with explicit attention to "function/symbol present at HEAD but absent from diff vs base." | Med | claude-code |
| 4 | **Visual-correctness test gap is accepted, not closed.** String-grep + scene-resolution tests cannot catch "shader looks right on current content." Screenshot-diff tests would be cheap to author but expensive to maintain (every UI tweak invalidates baselines). Decision: keep manual playtest as the visual-correctness gate. Document the gap explicitly so future contributors don't expect automated coverage there. | Low | claude-code |
| 5 | **Tilt-shift activation timing.** N1 shader is in main but `enabled = 0.0`. Activation requires (a) real biome background art shipped at z_index < 0, AND (b) playtest signal that current vibe needs more polish. Track in the project memory but don't pull into Sprint 19 unless (a)+(b) both fire. | Low | producer |

## Process Improvements

- **The "ship visible content, retro the rest" rhythm continues to hold.** Sprint 16/17/18 all followed this with zero missed critical paths. Sprint 18 added a new wrinkle: visible-content PRs surfaced playtest signals that themselves required hygiene-PR fixes (LOSING + materialize). The pattern now: visible content drives playtest, playtest surfaces hygiene work, hygiene work ships inside the active sprint. The retro-the-rest discipline is what makes this work.
- **Pre-emptive future-sprint work has measurable closure savings.** S18-M3 (live preview in Formation Assignment) was estimated 0.5d; the actual gap was 2 locale keys + 1 test (~30 min) because the SynergyBadge Label node, `_refresh_synergy_badge` function, tween animation, reduce-motion variant, and `detect_active_synergy` wiring all already existed from prior pre-emptive Sprint 19+ work. **When a future-sprint scaffolding exists, the closure work is dramatically smaller than estimated.** Worth knowing for Sprint 19 planning — the same may apply to other "pre-emptive" pieces sitting in the codebase.
- **Adversarial sanity check via the user.** "Why force-push?" (during the PR #101 rebase recovery) was the right question and resulted in the safer merge-not-force-push path. Pattern: when the AI proposes a destructive-default action, "why?" is a load-bearing user question. Adopt as a project memory candidate.
- **Test count growth tracks feature complexity, not LOC.** S17 close: 2196 PASS. S18 close: ~2393 PASS (+197). Most of the growth is regression tests for the two critical bugs caught this sprint — not the visible content. Pattern: when playtest catches a bug, the regression test that fixes it permanently is more valuable than any feature-side test. Continue prioritizing.

## Notes

- **Sprint 18 closes clean.** 7/7 Must Have done, 2/2 Should Have done, 1/1 Nice to Have done. No deferred items. No active blockers. Sprint goal MET.
- **Day-0 plan + same-day close: fifth consecutive sprint.** Sprint 14→15→16→17→18. The cadence is now structural, not happenstance.
- **18 ADRs cumulative.** Architecture continues to accumulate at ~1 ADR/sprint average. `/architecture-review` before Sprint 20 was flagged in the Sprint 18 plan as a healthy hygiene checkpoint; reaffirm.
- **Class synergy is the first net-new mechanic since Sprint 9.** The mechanism shipped cleanly; the cozy-register guardrails (per-synergy caps, no decisive triggers below ×1.25, identical Victory Moment fanfare for triggered vs untriggered) held through playtest. The "rewarding but not trivializing" goal landed.
