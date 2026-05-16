# Sprint 27 Retrospective — 2026-05-16

> **Sprint Mapping**: S27-M2 (playtest gate + retro authoring per the retroactive Sprint 27 Day-0 plan).
> **Sprint Window**: 2026-07-24 to 2026-08-06 nominal; actual close 2026-05-16 (fourteenth consecutive same-day-compressed sprint).
> **Review Mode**: Solo.
> **Status**: DRAFT — pending playtest-18 verdict per `production/playtests/playtest-18-sprint-27-synergy-effect-text-2026-05-16.md`. Flips to COMMITTED once tester grades 5 per-check rows.

## Sprint Goal — Technically MET (single Must Have shipped), strategic verdict pending playtest

Original retroactive goal: *"Close the synergy teaching loop by surfacing effect text on the Dispatch SynergyPreviewLabel, so the player sees BOTH 'what synergy is active' AND 'what does it do' in one line."*

Final status (technical surface):
- (a) M1 Synergy effect text — ✅ shipped (PR #166)
- (b) `/simplify+/review` cleanup (synergy_effect_text helper hoist + comment cleanup + test relocation) — ✅ shipped (PR #167)
- (c) M2 playtest + retro — ⚠️ playtest TBD; this retro is DRAFT until tester grades playtest-18

## By the Numbers

- **PRs this sprint**: 2 (1 Must Have + 1 cleanup) — leanest sprint since Sprint 16
- **Player-visible PRs**: 1 of 2 (50%) — the cleanup PR was post-merge hygiene, not player-facing
- **Cumulative tests at sprint close**: ~2340 (was ~2335 at start of S27; +5 net new + 4 relocated)
- **Regressions**: 0
- **New ADRs**: 0
- **GDD authoring**: 0 NEW. 0 amendments.
- **New player-visible surface**:
  - Synergy preview label appends effect text for all 8 synergies (4 V1 + 4 tier-2)
  - Em-dash separator format: "Synergy: Gold (X) — effect description"
- **Locale keys added**: 5 (4 tier-2 effect keys + 1 format key)
- **New UIFramework helpers**: 1 (`synergy_effect_text(synergy_id)`)
- **Tests added**: 5 (3 effect-text + 2 helper self-tests)
- **Tests relocated**: 4 (Group E tier-mapping tests to ui_framework_helpers_test.gd Group H)
- **Version**: ~0.0.0.75 → ~0.0.0.77 across the sprint (2 PRs)
- **Solo same-day cadence**: 14th consecutive sprint (S14 → S27)

## What Worked

- **Sprint 26 retro's Sprint 27 recommendation pointed directly at the work.** No Day-0 plan needed at scope-time; the carryforward arrow from Sprint 26 retro → Sprint 27 M1 was unambiguous.
- **Rule-of-Three pattern applied for the third time this project.** Three call sites for `tr("class_synergy_effect_" + id)` → hoist to `UIFramework.synergy_effect_text` next to the existing `synergy_display_name` + `synergy_id_to_tier` helpers (same S24-M3 hoist pattern).
- **Single-PR sprint shipped cleanly.** Just 1 content PR + 1 cleanup. No stacking, no retroactive plan needed at scope-time (only post-facto for canonical record).
- **Locale-key naming pattern held.** `synergy_preview_tiered_format_with_effect` mirrors `synergy_preview_tiered_format` — sibling key family preserved.
- **Test relocation closed a category-drift gap.** Group E tier-mapping tests were collocated with orchestrator multiplier tests but actually exercised a pure UIFramework helper. Moving them to `ui_framework_helpers_test.gd` Group H restored category clarity.

## What Could Be Better

- **Third consecutive sprint with retroactive Day-0 plan.** Sprint 25 had addendum-after-Day-0; Sprint 26 had retroactive Day-0; Sprint 27 has retroactive Day-0 + retro. The pattern is consistent: implementation lands first, meta-work backfilled. For single-PR sprints this is acceptable; for multi-PR sprints (Sprint 28+) the Day-0 plan should bundle into the first content PR.
- **Playtest backlog now 3 sprints deep.** Sprint 25 playtest DRAFT. Sprint 26 playtest DRAFT. Sprint 27 added another content surface. Tester has 15 axes (5 per playtest × 3 sprints) to grade. Single deep playthrough is the right mitigation but the cadence is drifting toward "content-shipped >> content-validated."
- **GDScript match-case scaling concern accumulating.** `_resolve_synergy_gold_multiplier` is at 8 arms. `/simplify+/review` agents flagged Dictionary-ize as impractical (match cases must be literals) but the friction will keep growing as new synergies land. Document the ~12-arm tipping point for refactor.
- **No Sprint 27 N1 (Nice-to-Have) shipped.** Sprint 26 had N1 (test helper); Sprint 27 had zero NTHs. The "Should Have / Nice to Have" tiers were entirely deferred — fine for a single-Must-Have sprint but the carryforward to Sprint 28 grows.

## What I'd Do Differently Next Time

1. **Bundle Day-0 plan into the first content PR** for multi-PR sprints. Single-Must-Have sprints can defer the plan to a retroactive doc, but the pattern of 3 consecutive retroactive plans is a process-drift signal.
2. **Cap playtest backlog at 1 sprint.** Don't ship Sprint N+1 content while Sprint N playtest is DRAFT. Current backlog of 3 sprints' worth of content compounds the playtest grading effort.
3. **Document the match-case refactor tipping point.** When `_resolve_synergy_gold_multiplier` hits 12 arms, refactor to the Dictionary-driven approach the reviewers suggested.
4. **Run /simplify+/review on every multi-PR sprint, not just content-heavy ones.** Even single-PR sprints have benefit (Sprint 27 cleanup PR found 4 actionable items).

## Sprint 28 Recommendations (provisional, pending playtest verdicts)

If playtest 16+17+18 grade well:
- **Recruit pool size tuning** (3 → 4 or 5 picks). Justification: 7 classes × 3 picks = ~37% per-class probability per refresh; players building 3-of-a-kind synergies may find it slow. Required: `.tscn` surgery to add PoolEntry3 (and 4) nodes, OR programmatic pool entry creation refactor.
- **Per-floor matchup hint** (instead of per-biome). Each floor has its own `enemy_list`; the floor picker could show "Recommended: Berserker" per floor based on floor-specific archetype composition.
- **Hero milestone toasts** ("Theron reached level 10!") for level milestones beyond level 1.
- **Real product art ingestion** if art workstream lands an ETA. Still blocked external.

If verdict shows specific gaps in the compound surface:
- Address named gap first; defer Sprint 28 expansion.

**Anti-pattern guardrails** (carried from Sprint 24 + 25 + 26 memories):
- No new GDD authoring without grep-first check
- No test fixture hygiene unless Rule-of-Three is met
- No engine optimization producing zero player-visible change
- **NEW (S27 retro)**: No new content PRs while playtest backlog > 1 sprint

## Files Touched This Session

Sprint 27 content / UX:
- `src/ui/ui_framework.gd` — `synergy_effect_text(synergy_id)` helper added (PR #167); minor comment cleanup (PR #167)
- `assets/screens/formation_assignment/formation_assignment.gd` — `_refresh_synergy_preview_label` effect text appended (PR #166); refactored to use `synergy_effect_text` helper (PR #167); badge call site refactored to helper (PR #167)
- `assets/screens/guild_hall/guild_hall.gd` — synergy summary badge refactored to `synergy_effect_text` helper (PR #167)
- `src/core/formation_assignment/formation_assignment.gd` — Sprint-prefix comments stripped (PR #167)
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — Sprint-prefix comments stripped (PR #167)
- `assets/locale/en.csv` — 4 tier-2 effect keys + 1 format key (PR #166)
- `tests/unit/formation_assignment/synergy_preview_label_test.gd` — Group D (3 effect-text tests) added (PR #166)
- `tests/unit/dungeon_run_orchestrator/tier2_synergy_multipliers_test.gd` — Group E tier-mapping tests removed (PR #167; relocated)
- `tests/unit/ui_framework/ui_framework_helpers_test.gd` — Group H (4 tier-2 tier mapping) + Group I (2 synergy_effect_text self-tests) added (PR #167)

Sprint 27 meta-work (this PR):
- `production/sprints/sprint-27.md` (NEW)
- `production/playtests/playtest-18-sprint-27-synergy-effect-text-2026-05-16.md` (NEW)
- `production/retrospectives/sprint-27-retrospective-2026-05-16.md` (NEW)
- `production/sprint-status.yaml` — Sprint 26 archived, Sprint 27 stories block

## Memory Recorded This Sprint

- No NEW memory entries. Prior memories (`feedback_infrastructure_debt_drift`, `feedback_grep_first_check_must_run_pre_planning`) both held — Sprint 27 honored them. New process learning ("cap playtest backlog at 1 sprint") recorded in Sprint 27 Process Rules; if it recurs, promote to memory entry.

## Carryover Acknowledged

- **None mandatory.** Sprint 27's one Must Have shipped. Sprint 28 candidates are provisional pending playtest.
- The accumulated playtest backlog (16 + 17 + 18) carries to whichever session the tester runs them in. This is a coordination handoff, not a code carryover.

## Sprint Goal — Final Disposition

**PENDING playtest-18.** Sprint 27 shipped 1 player-visible PR (synergy effect text on the Dispatch preview label) + 1 cleanup PR. The strategic verdict — does the effect text close the teaching gap the Sprint 26 retro flagged? — depends on the tester's grading. This retro flips from DRAFT to COMMITTED once playtest-18 grades the 5 per-check rows.
