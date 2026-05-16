# Playtest 17 — Sprint 26 content pivot (berserker + cleric + biome filter + tier-2 synergies)

> **Sprint Mapping**: S26-M5 (`production/sprints/sprint-26.md`).
> **Gate**: Sprint 26 Definition of Done — content additions read as player progression.
> **Status**: PENDING — graded by tester. Can be run as a single deep session covering BOTH playtest-16 (Sprint 25) and playtest-17 (Sprint 26) signal axes.
> **Precedent**: Per-check granularity per `_template-visual-playtest.md`.

## Session Info

- **Date**: TBD (post-merge of PRs #158-#164)
- **Build**: TBD (will be the version after all S26 PRs land)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build)
- **Input Method**: Mouse
- **Session Type**: Sprint 26 content-pivot validation. Stacked on top of Sprint 25 additions (boss floor visual, paladin, archer, lock indicator). Tester should run a deep playthrough that exercises floor-clear progression on at least 2 biomes.

## Hypothesis Under Test

Sprint 26 added:
- **M1** (PR #158): Dispatch only shows unlocked biomes (4 starter on fresh save → reveals on chain unlock)
- **M2** (PR #159): Berserker class (brawler archetype)
- **M3** (PR #161): Cleric class (support archetype, 2x tick_output_contribution)
- **M4** (PR #164): Bastion / Volley / Frenzy / Vigil synergies (3-of-a-kind for each tier-2 class)
- **N1** (PR #160): Internal — ClassRegistrationTestHelper (no player-visible change)

**Question for M5**: does the post-Sprint-26 playthrough feel like the game has GROWN AGAIN since Sprint 25? Specifically:
1. Did the recruit pool show paladin/archer/berserker/cleric over multiple refreshes?
2. Did the Dispatch screen show 4 biome tabs at game start (not 6)?
3. Did a chained biome appear as a new tab after its gate cleared?
4. Did the SynergyPreviewLabel correctly fire "Gold (Bastion)" / "(Volley)" / "(Frenzy)" / "(Vigil)" for 3-of-a-kind tier-2 formations?
5. Did the matchup payoff (×1.25 gold for conditional synergies; ×1.20 XP for Vigil) actually land visibly?

**Disconfirmation criterion**: if the new classes never appear in the recruit pool OR the new synergies never fire OR the player can't perceive the gold/XP multiplier difference, the content delivery has wiring gaps. Likely root cause: `feedback_scaffolded_but_unwired_pattern`.

## Per-Check Validation

Fill in PASS / PARTIAL / FAIL for each.

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | Recruit pool refresh surfaces ≥3 distinct tier-2 classes (paladin/archer/berserker/cleric) across 5+ refreshes | TBD | Open Recruit Screen, tap Refresh button 5 times, note which class_ids appear. With 7 classes in pool generation + uniform random pick, P(specific class ≥1 of 3 slots) ≈ 1-(6/7)^3 ≈ 37% per refresh. Across 5 refreshes the probability of seeing each class is high. |
| (b) | Dispatch screen on fresh save shows exactly 4 biome tabs (not 6) | TBD | Reset save OR observe a fresh-save state. Open Dispatch → floor picker. Count biome tabs. Expected: forest_reach + frostmire + sunken_ruins + whispering_crags (4 tabs). Chained: ember_wastes, hollow_stair NOT visible until gates fire. |
| (c) | Chained biome appears as a new Dispatch tab after gate clears (in-session, not just on reload) | TBD | Clear floors of frostmire to F5. Stay on Dispatch screen (or open picker after Victory Moment). New tab `ember_wastes` should appear. Earlier behavior: required a full screen re-entry. New (S26-M1): live re-render via `_on_biome_unlocked` handler. |
| (d) | 3-of-a-kind formation of a tier-2 class fires the new synergy with correct tier label | TBD | Compose a 3-paladin formation (recruit + slot). SynergyPreviewLabel reads "Synergy: Gold (Bastion)". Repeat for 3-archer (Volley), 3-berserker (Frenzy), 3-cleric (Vigil). Each fires with Gold tier prefix. |
| (e) | Conditional gold multiplier visibly applies on counter-archetype kills | TBD | Dispatch 3-berserker formation against a bruiser-archetype floor (forest_reach has dominant_archetypes=[bruiser, armored]). Run resolves; gold reward at Victory Moment should be ~×1.25 the baseline 3-warrior-vs-non-bruiser run would have given. Vigil XP path: 3-cleric formation, observe XP gain on Victory Moment ~×1.20 baseline. |

**Per-check protocol**: PASS / PARTIAL / FAIL. PARTIAL with notes preferred to vague PASS.

## Findings (to fill in)

**Tester report (TBD)**: TBD

## Test Suite Impact

- **Before Sprint 26**: ~2293 tests (from Sprint 25 close estimate)
- **After Sprint 26**: ~2335 tests (+42 net new: tier2 synergy detection 8 + tier2 multipliers 15 + berserker registration 11 + cleric registration 8)
- **Regressions**: TBD on full-suite run

## Sprint 26 Definition of Done — verdict pending

- [x] M1 Dispatch biome filter (PR #158)
- [x] M2 Berserker class (PR #159)
- [x] M3 Cleric class (PR #161)
- [x] M4 Tier-2 synergies (PR #164)
- [x] N1 Test helper (PR #160)
- [x] /simplify+/review cleanup (PR #162)
- [x] Parse error hotfix (PR #163)
- [ ] M5 playtest graded across 5 checks (this doc)
- [ ] Sprint 26 retro committed

## After-Action Decision Tree

**If 4-5 of 5 PASS**: Sprint 26 succeeded. Sprint 27 continues content cadence:
- More UX hints for synergies (effect text alongside name)
- Recruit pool size tuning (3 → 5?)
- Real product art ingestion (if workstream lands)

**If 2-3 of 5 PASS**: Wiring gaps. Sprint 27 starts with carryforward for the failed checks.

**If 0-1 of 5 PASS**: Content was scoped wrong direction. Likely escalation:
- Inspect whether players still feel "uiux and functions are not progressing"
- Consider equipment/items system as a new mechanic layer
- Consider real art as the load-bearing visual upgrade

## Notes on stacked Sprint 25 + 26 grading

Sprint 25's playtest (playtest-16) was also pending when Sprint 26 shipped. To minimize duplicate playtest sessions, the tester CAN grade both in a single deep playthrough. The compounded content surface is:
- 7 classes (warrior/mage/rogue MVP + paladin/archer/berserker/cleric tier-2)
- 4-6 biomes visible based on progression
- 8 detectable synergies (Steel Wall/Arcane Elite/Triple Strike/Triple Threat + Bastion/Volley/Frenzy/Vigil)
- F5 boss floor visual differentiation
- 🔒 lock indicator with tooltip
- Recruit pool empty-state placeholder

A single playthrough through forest_reach F1→F5 + a 3-paladin run + a 3-cleric run would exercise most of the above.
