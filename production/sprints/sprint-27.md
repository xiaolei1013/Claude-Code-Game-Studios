# Sprint 27 — 2026-07-24 to 2026-08-06

> **Status: Retroactively authored 2026-05-16** after Sprint 27 content work shipped directly (PR #166 + cleanup PR #167). Mirrors the Sprint 26 closure pattern. Fourteenth consecutive same-day-compressed sprint (Sprint 14 → 27).
> Solo review mode.

## Sprint Goal — MET on the one Must Have

**Close the synergy teaching loop by surfacing effect text on the Dispatch SynergyPreviewLabel, so the player sees BOTH "what synergy is active" AND "what does it do" in one line.**

Why this scope: The Sprint 26 retrospective's top Sprint 27 recommendation was the effect-text surfacing — Bastion/Volley/Frenzy/Vigil shipped with detection + multiplier resolution but the player couldn't see what each does. This sprint closes that gap. Other Sprint 27 candidates (recruit pool tuning, real art) deferred to Sprint 28+.

## Pre-Plan Disposition

| PR / Gate | Status | Action |
|-----------|--------|--------|
| **Sprint 25 retro** | DRAFT (playtest-16 verdict pending) | Continued in DRAFT |
| **Sprint 26 retro** | DRAFT (playtest-17 verdict pending) | Continued in DRAFT |
| **Playtest backlog** | 2 sessions pending grading | Single deep playthrough recommended (covers both axes) |

## Tasks (all shipped)

### Must Have

| ID | Task | PR | Status |
|----|------|----|----|
| S27-M1 | Synergy preview label appends effect text — "Synergy: Gold (Bastion) — +25% gold vs casters" | #166 | DONE |
| S27-M2 | Sprint 27 playtest + retro | TBD | **HUMAN-BLOCKED** |

### Cleanup PRs (not story-tracked)

| PR | Purpose |
|---|---|
| #167 | `/simplify+/review` cleanup — `synergy_effect_text` helper extracted (Rule-of-Three hoist) + Sprint-prefix comments stripped + Group E tier-mapping tests relocated to ui_framework_helpers_test.gd |

## By the Numbers

- **PRs this sprint**: 2 (1 content + 1 refactor) — leanest sprint since Sprint 16
- **Player-visible PRs**: 1 of 2 (50%) — the cleanup PR was post-merge hygiene
- **Tests added**: +5 (3 effect-text in synergy_preview_label_test.gd Group D + 2 helper self-tests in ui_framework_helpers_test.gd Group I)
- **Tests relocated**: 4 (Group E tier-mapping tests from `tier2_synergy_multipliers_test.gd` to `ui_framework_helpers_test.gd` Group H)
- **Locale keys added**: 5 (4 tier-2 effect keys + 1 format key with em-dash separator)
- **Version**: ~0.0.0.75 → ~0.0.0.77 across the sprint
- **Solo same-day cadence**: 14th consecutive sprint (S14 → S27)

## What Worked

- **Single Must Have, single PR scope kept the sprint clean.** No Day-0 plan needed at scope-time; the recommendation flow from Sprint 26 retro pointed directly at the work.
- **Rule-of-Three pattern repeated cleanly.** Three call sites for `tr("class_synergy_effect_" + id)` → hoist to `UIFramework.synergy_effect_text` next to the existing `synergy_display_name` and `synergy_id_to_tier` helpers. Same Sprint 24 S24-M3 pattern applied again.
- **Locale-key naming pattern held.** The em-dash separator format `synergy_preview_tiered_format_with_effect` mirrors `synergy_preview_tiered_format` — sibling key family preserved.
- **Test relocation closed a category-drift gap.** Group E tier-mapping tests had been wrongly collocated with orchestrator multiplier tests (they exercised a pure UIFramework helper, not the orchestrator). Moving them to `ui_framework_helpers_test.gd` Group H restored category clarity.

## What Could Be Better

- **Sprint 27 has no Day-0 plan PR — third consecutive sprint shipping work before plan documentation.** Sprint 25 had a retroactive addendum; Sprint 26 had a retroactive Day-0 plan; Sprint 27 has this retroactive Day-0 plan + retro. The pattern is: implementation lands first, meta-work gets backfilled. Acceptable for single-PR sprints; should improve for multi-PR sprints in Sprint 28.
- **Playtest backlog compounding across 3 sprints.** Sprint 25 playtest still DRAFT. Sprint 26 playtest still DRAFT. Sprint 27 added another content surface (effect text + 4 new synergies). Tester now has 3 playtests' worth of grading to do. Single deep playthrough recommendation is the right mitigation but the cadence is drifting.
- **`/simplify+/review` agents flagged "Dictionary-ize synergy match statements" — skipped as impractical** because GDScript match case labels must be literals. Documented in the cleanup PR but the underlying friction (8-arm match in `_resolve_synergy_gold_multiplier`) will keep growing as new synergies land. Defer until ~12 entries; revisit then.

## What I'd Do Differently Next Time

1. **Bundle the Day-0 plan into the first content PR** even for single-Must-Have sprints. Avoids the retroactive-authoring step + makes intent visible at PR creation time.
2. **Cap playtest backlog at 1 sprint.** Don't ship Sprint N+1 content until Sprint N playtest verdict lands. Sprint 25 + 26 + 27 backlog is a process drift signal.
3. **For the GDScript match-case scaling concern: document a "tipping point" for refactoring.** At 12 synergy match arms, the Dictionary-driven approach becomes worth the indirection cost. Add to Sprint 28 retro candidate list when the count grows.

## Sprint 28 Recommendations (provisional, pending playtest verdicts)

If playtests grade well across the 3-sprint compound surface:
- **Recruit pool size tuning** (3 → 4 or 5 picks). Required: programmatic pool entry creation (or .tscn surgery to add PoolEntry3 + PoolEntry4 nodes). Justification: 7 classes × 3 picks = ~37% per-class probability per refresh; players building 3-of-a-kind may find it slow.
- **Per-floor matchup hint** (instead of per-biome). Each floor has its own `enemy_list`; the floor picker could show "Recommended: Berserker" per floor based on floor-specific archetype composition.
- **Hero milestone toasts** ("Theron reached level 10!") for level milestones beyond level 1.
- **Real product art ingestion** if art workstream lands an ETA.

If playtests show specific gaps:
- Address named gap first; defer broader expansion.

**Anti-pattern guardrails** (carried from Sprint 24 onward):
- No new GDD authoring without grep-first check
- No test fixture hygiene unless Rule-of-Three is met
- No engine optimization producing zero player-visible change
- No new content PRs while playtest backlog > 1 sprint

## Sprint 27 Process Rules (carried + updated)

1. Per-task PR with `base=main`. Continued from Sprint 25+26.
2. Grep-first GDD-existence check before any "author GDD X" story.
3. Player-visible surface check at mid-sprint.
4. Parse-check before merging test-helper changes (added Sprint 26).
5. Skip hand-written UIDs on new `.tres` files (added Sprint 26).
6. **NEW**: Bundle Day-0 plan into first content PR — no retroactive plans (codified after 3 consecutive retroactive plans).
7. **NEW**: Cap playtest backlog at 1 sprint — defer new content if backlog grows.

## After Sprint 27

Sprint 28 candidates (pending playtest) — see above. Anti-pattern guardrails carried forward.
