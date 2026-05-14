# Sprint 17 Retrospective — 2026-05-14

> **Sprint Mapping**: S17-M7. Closes Sprint 17 (`production/sprints/sprint-17.md`).
> **Sprint Window**: 2026-05-13 to 2026-05-26 nominal; actual execution compressed to ~36 hours per the established same-day-compressed cadence (Sprint 14→15→16→17 all followed this pattern).
> **Review Mode**: Solo.

## Sprint Goal — Met

> **Ship the counter-archetype matchup-hints UI sweep end-to-end and validate the Sprint 16 progression chain via playtest.**

All three success criteria satisfied:
- (a) All 5 matchup-hints surfaces shipped — PRs #83, #84, #85, #86, #87. ✅
- (b) Progression-chain playtest committed with PASS verdict — `playtest-09-progression-chain-2026-05-14.md`. ✅
- (c) At least one Sprint 16 retro action closed beyond the matchup-hints pivot — S17-S2 biome-cost re-baseline (PR #88 yaml header) + S17-S1 Recruitment audit (this PR, retired as superseded). ✅

## By the Numbers

- **PRs merged**: 10 (#83 matchup biome tabs → #92 gitignore octopath glob)
- **Cumulative tests at sprint close**: 2196 PASS (was 2129 at Sprint 15 close; +6 from PR #90 regression suite, +61 from Sprint 16's biome + matchup test additions across PRs #83–#87)
- **Regressions**: 0
- **Critical hidden bugs surfaced + fixed**: 1 (multi-biome ledger collision, PR #90)
- **Visible-content PRs**: 5/10 (#83–#87 — the entire matchup-hints sweep)
- **Hygiene PRs**: 5/10 (#88 plan doc, #89 stray uids, #90 ledger fix, #91+#92 gitignore policy)

## What Worked

- **The matchup-hints UI sweep landed cleanly.** Five surfaces in one day, each PR a small surgical change against a pre-existing test scaffold. The S17-M3 → M4 → M5 chain (Hero Detail → Formation roster → HeroCard + Recruit) all shipped with regression tests against the `counter_archetype` data field. Pattern reuse paid off.
- **Playtest-driven closure proved itself, hard.** The S17-M6 playtest caught the multi-biome ledger collision (PR #90) that the entire 2190-test suite missed. Every test was authored against the MVP single-biome scope — when Sprint 16 widened to 5 biomes, no single existing test was wrong, but the *invariant* the suite was protecting had shifted. The human-eye playtest was the only signal that could surface this gap. Project memory `feedback_playtest_driven_closure` is now load-bearing for the architecture-amendment case, not just the wiring-gap case.
- **Compressed cadence held.** Sprint 14→15→16→17 all completed in ≤2 days against a nominal 10-day window. Same-day-compressed-with-real-time-planning is now the established rhythm, not an outlier.

## What Hurt

- **2190/2190 PASS while half the game was broken.** Forest Reach worked. Every other biome's F2+ was silently bricked from Sprint 16's biome-2-whispering-crags merge until PR #90 fixed it ~12 hours after S17-M6 caught it. The bug existed for ~24 hours of merged main. No automated check would have caught it; the architectural assumption shifted faster than test coverage.
- **ADR-0002 was authored against MVP scope** (single-biome, `floor_index → bonus` predicate) and Sprint 16's multi-biome content drop never triggered an ADR amendment audit. The `_floor_clear_bonus_credited` schema was the failure surface — int-keyed instead of `(biome_id, floor_index)`-keyed — and nothing in the Sprint 16 review caught it. Sprint 16's "ship visible content fast" rhythm rewarded biome-data-only PRs that didn't surface the structural gap.
- **Test coverage of Sprint 16's multi-biome additions was data-shape coverage** (each `.tres` loads, each Floor has 5 entries, each progression gate fires when its prereq fires) without testing the *combined* invariant (clearing F_N in one biome should not affect F_N progression in another biome). The regression suite shipped with PR #90 fills this gap retroactively.

## Action Items for Sprint 18

| # | Action | Priority | Owner |
|---|--------|----------|-------|
| 1 | **Sprint 18 theme decision.** S17-M6 playtest said "it works great." That signal points away from more content (biome 7) and toward variety. Options: class synergy V1.0 implementation (S17-N1 candidate, GDD already exists), onboarding UX polish (3-sprint carry: S15-N3 → S16-N4 → S17-N2), or HD-2D tilt-shift DoF shader (S17-N4 / S16-N2 polish carry). | **High** | user + claude-code |
| 2 | **ADR-amendment test-coverage audit pattern.** When an ADR is amended for a scope-widening change (like Sprint 16's biome expansion vs. ADR-0002's MVP assumption), trigger an explicit test-coverage audit of the affected predicate before the next ship. Process improvement: `/architecture-decision` skill (or `/architecture-review`) should output a "regression-test gap list" alongside the amendment. | High | producer + claude-code |
| 3 | **Sprint 16 deferred carries final disposition.** S15-N3/S16-N4/S17-N2 onboarding polish has now carried 3 sprints with no playtest demanding it. Either pull into Sprint 18 actively or formally retire as "deferred indefinitely — pull on playtest signal." | Med | user |
| 4 | **HeroLeveling AC-15-02 carry chain closed.** PR #87 + the M6 playtest implicitly re-validated leveling behavior; the explicit Sprint 16 S16-M1 re-run (carried as S17-N3) is no longer needed. Remove from Sprint 18 candidates list. | Low | producer |

## Process Improvements

- **The "ship visible content, retro the rest" rhythm from Sprint 16 still works**, but Sprint 17 surfaced its limit: visible content can mask structural debt accumulating underneath. Sprint 18 should keep the visible-content weighting but pair it with one explicit invariant-audit per sprint — pick one ADR, regenerate its regression coverage against the current shipping scope.
- **Adversarial sanity check on PR descriptions.** PR #90's adversarial check was applied inline (LOSING-reclaim, anti-exploit, save migration, tampered-save defenses) and caught nothing — but it was a useful forcing function. Adopt for Sprint 18 PRs touching schema or invariants.
- **Repo hygiene PRs (#88, #89, #91, #92) clustered well.** Doing them inside the active sprint rather than deferring to "cleanup sprint" kept the working tree clean and the cognitive overhead low. Pattern worth keeping.

## Memory Items Worth Saving

- **2190 tests passing ≠ the game working.** Tests measure code correctness, not feature correctness. Sprint 17's PR #90 is the canonical example: every test was internally correct against the scope it was authored for, but the scope itself had shifted. The playtest was the only signal that could catch the gap. Reinforces `feedback_playtest_driven_closure` for the architecture-amendment case, not just the wiring-gap case.
- **Architectural amendments are silent test-coverage gaps.** When ADR-0002 was authored against a single-biome MVP, every Economy test was correct for that scope. Sprint 16's multi-biome content drop didn't amend ADR-0002, so the tests stayed correct for the old scope and missed the new failure mode. The lesson: ADR amendments need to trigger explicit regression-coverage audits of the affected predicate before the architectural change ships. PR #90 retroactively closed this for ADR-0002; the pattern generalizes to every future scope-widening amendment.
- **Same-day-compressed sprints work for 1–2 person teams with tight scope.** Sprint 14→15→16→17 all closed in ≤2 calendar days of a nominal 10-day window. The compressed rhythm trades off retro depth (these retros read more like session logs than month-long-sprint postmortems) for faster signal-to-shipping cadence. The trade is net-positive at current team size; might need revisiting if the team grows or scope widens substantially.

## Verdict

**Sprint 17: SUCCESSFUL — matchup-hints chain shipped + critical hidden bug caught and fixed mid-sprint.**

By the numbers: 10 PRs, all 7 Must Haves done, 2 of 2 Should Haves done (S2 in #88 yaml, S1 retired this PR), 0 of 4 Nice-to-Haves pulled (S17-N1 class synergy V1.0 is the leading Sprint 18 candidate).

By the player-experience signal: the matchup-hints UI sweep makes counter-archetype information visible on every screen where it's useful (biome tabs, hero detail, formation roster, recruit screen, hero card). And the silent biome-progression bricking that was shipped without any of us knowing is now fixed — the Sprint 16 multi-biome content drop is finally actually playable end-to-end.

**Most important takeaway**: when an architectural assumption changes (Sprint 16's single-biome → multi-biome shift), test coverage written under the old assumption is no longer protective — even if it still passes. The playtest is the only signal that crosses the assumption-change boundary cleanly.

**Recommendation for Sprint 18**: pick one architectural invariant per sprint and re-audit its test coverage against the current shipping scope. The matchup-hints sweep + the multi-biome chain work; what's the next thing the player actually wants? S17-M6 said "it works great" without asking for more content — that's a sign to go for variety (class synergy V1.0, onboarding polish, or visual polish) rather than another biome.
