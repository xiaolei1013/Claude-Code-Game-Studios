# Cross-Sprint Meta-Retrospective — Sprints 24-27

> **Authored**: 2026-05-16, post-Sprint-27 closure.
> **Scope**: synthesizes learnings across 4 consecutive sprints (S24 → S27). Treats the sprint sequence as a single unit of analysis to surface patterns invisible from any single retro.
> **Purpose**: inform Sprint 28+ planning AND establish "what we learned about how we work" as a durable record. Companion to the per-sprint retros — not a replacement.

## Headline finding

**The Sprint 24-27 arc was a recovery from infrastructure-debt-drift.** Sprint 24 was the WORST of these 4 sprints by player-visible PR ratio (2 of 10 PRs = 20%); Sprint 27 was the LEANEST (1 of 2 PRs = 50% player-visible, but only 2 PRs total). Sprint 25 + 26 in the middle ramped up the player-visible ratio (66% + 71%) on the way out of drift.

The user's mid-Sprint-24 feedback ("uiux and functions are not progressing too much") forced a strategic pivot mid-arc. Without that intervention, Sprint 25 + 26 would likely have continued the cleanup-heavy cadence.

## The 4-sprint trajectory

| Sprint | PRs | Player-visible | Headline | Player-visible delta |
|---|---|---|---|---|
| 24 | 10 | 2 (20%) | Class Synergy V2 tier ladder | Tier label format + 1 empty-state placeholder |
| 25 | 8 | 4 (66%) | Content pivot begins | +2 classes (paladin, archer), boss floor visual, 🔒 indicator |
| 26 | 8 | 5 (71%) | Content pivot accelerates | +2 classes (berserker, cleric), Dispatch R7 filter, +4 synergies |
| 27 | 3 | 1 (33%) | Synergy effect text + closure | Effect text inline with synergy names |

**Cumulative**: 29 PRs across 4 sprints. 12 PRs (41%) touched player-visible surface. That ratio is HIGHER than Sprint 24 alone (20%) but LOWER than the content-pivot peak (Sprint 26: 71%). The Sprint 27 single-PR scope skews the recent average down.

## Five recurring patterns

### 1. Infrastructure-debt-drift is self-reinforcing without external check

Sprint 24 was an extreme example — 5 of 10 PRs were GDD audits OR test fixtures OR engine hygiene. None of those moved the player needle. Despite recent memories warning against this pattern, the agent (me) re-committed the same mistake in Sprint 25's Day-0 plan within MINUTES of writing the warning memory.

**The lesson is harsh**: memory entries don't self-enforce. A documented warning is a soft commitment. The grep-first check (Sprint 25+ rule #3) only worked because it's a HARD step that requires a verification command. Soft rules drift; hard rules stick.

**Carries to Sprint 28+**: the "no new content while playtest backlog > 1 sprint" rule (Sprint 27 #7) is currently SOFT. After the playtest, if I find myself wanting to ship more content despite an ungraded playtest, the rule needs to become a hard step (e.g., `gh pr create` should refuse if `ls production/playtests/*.md | head -1` is older than the latest sprint).

### 2. Rule-of-Three is the canonical refactor trigger

- Sprint 24 M3: `clear_children_immediate` extracted after the 6th call site
- Sprint 24 M3: `synergy_display_name` extracted after the 3rd call site
- Sprint 26 N1: `ClassRegistrationTestHelper` extracted after the 3rd class-registration test file
- Sprint 27 cleanup: `synergy_effect_text` extracted after the 3rd `tr("class_synergy_effect_" + id)` inline build

Every single one of these refactors was triggered by Rule-of-Three. The pattern is reliable; the question is whether to wait for it or front-run it. Front-running is premature abstraction; waiting is the right call.

**Carries to Sprint 28+**: continue waiting for Rule-of-Three. Resist the impulse to refactor at 2 occurrences.

### 3. Day-0 plan retroactive-authoring is the default mode

- Sprint 24: Day-0 plan authored before content (correct flow) → 10 PRs shipped under it
- Sprint 25: Day-0 plan authored before content → 8 PRs shipped — but addendum needed within session because Day-0 plan had wrong assumptions
- Sprint 26: NO Day-0 plan PR; work shipped directly; retroactive plan authored at sprint close
- Sprint 27: NO Day-0 plan PR; single content PR; retroactive plan authored at sprint close

The Sprint 26 + 27 pattern (ship first, plan after) is faster but it means PR descriptions and commit messages carry the planning weight. For single-PR sprints this is fine. For multi-PR sprints (Sprint 26 with 8 PRs), the retroactive plan is necessary AND awkward — by the time it's written, half the plan's value (forward-looking scoping) has evaporated into "documenting what already shipped."

**Carries to Sprint 28+**: Sprint 27 rule #6 ("bundle Day-0 plan into first content PR") is the right balance. Write the plan WITH the first content PR — not before, not after. The plan's forward-looking scoping aligns with first-PR commit context; sprint-status.yaml can flip mid-stream.

### 4. The playtest gate is the load-bearing closure mechanism — and it's drifting

The 4 sprints produced 4 playtest templates (playtest-15 closed; playtest-16, -17, -18 still DRAFT at session end). The playtest backlog now stands at 3 sprints deep.

The Sprint 27 retro flagged this and committed rule #7 ("cap playtest backlog at 1 sprint"). The unified playtest protocol (PR #170) is the bridge — it converts 3 fragmented playtests into 1 unified session.

**The lesson here**: playtest cadence is the project's tempo regulator. When the agent ships content faster than the human can validate it, playtest backlog grows. Backlog growth invalidates the playtest signal (15 axes are hard to keep mental state for in one session; some signals get lost).

**Carries to Sprint 28+**: respect rule #7. Don't ship content faster than the human can playtest. The Sprint 27 single-Must-Have sprint cadence (1 content PR + 1 cleanup) is probably the sustainable rate IF the human is also playing the game on cadence. If the human is not playing on cadence, the sustainable rate is ZERO new content until they catch up.

### 5. "Player-visible PR ratio" is a better health metric than "PR count"

Sprint 24 shipped 10 PRs (high count) but only 2 were player-visible. Sprint 27 shipped 2 PRs (low count) but 1 was player-visible. By PR count, Sprint 24 looks more productive; by player-visible ratio, Sprint 27 looks more productive.

This ratio is what the project's `feedback_infrastructure_debt_drift` memory entry indirectly tracks. Making it an explicit metric on every retro would close the gap between "what the agent thinks they shipped" and "what the player perceives shipped."

**Carries to Sprint 28+**: every retro's "By the Numbers" section should include the player-visible PR ratio AS A NUMBER (not just narratively). When the ratio drops below 50%, the retro should explicitly flag it as a process signal.

## Memory entry inventory

The 4-sprint arc produced 2 NEW memory entries:

1. `feedback_infrastructure_debt_drift` (Sprint 24 retro) — recent sprints landed cleanup with no player-visible progress; prefer content + mechanics + implementation-of-existing-GDDs over new GDD authoring + hygiene refactors.

2. `feedback_grep_first_check_must_run_pre_planning` (Sprint 25 addendum) — agent committed infrastructure-debt-drift mistake within minutes of writing the warning memory; lesson is memory entries don't self-enforce.

Both held across Sprints 26 + 27 (no recurrence). Memory-as-soft-rule mechanism works for first violations; doesn't always work for second.

**Recommendation**: NO new memory entries from this meta-retro. The patterns above are PROCESS RULES (codified in Sprint 24-27 retros + sprint plan docs), not memory entries. Process rules are checked at sprint planning time; memory entries are checked at task execution time. The 5 patterns belong in the planning step.

## Sprint 28 framing

The Sprint 27 retro § Sprint 28 Recommendations lists 4 candidates (recruit pool size tuning, per-floor matchup hint, hero milestone toasts, real product art) — provisional pending playtest verdicts.

This meta-retro doesn't add or remove candidates. But it adds a framing rule: **whichever candidate gets picked first for Sprint 28, the Day-0 plan must bundle into the first content PR (rule #6) AND the playtest backlog must be at 0 before content ships (rule #7).**

If Sprint 28 starts with the 3-sprint playtest backlog still ungraded, the rule says: ship NOTHING new. Only the playtest grading + retro flips + Sprint 28 Day-0 plan are in scope.

## What this meta-retro does NOT cover

- Per-sprint detail (delegated to the 4 individual retros)
- Per-PR breakdowns (delegated to the 4 individual retros + CHANGELOG)
- Memory entry detail (each entry's own .md file in `/Users/xiaolei/.claude/projects/.../memory/`)
- Implementation specifics of any feature (delegated to GDDs + ADRs)
- Sprint 28 task scoping (provisional list lives in Sprint 27 retro § recommendations)

## Closure

The 4-sprint arc ends with:
- 29 PRs shipped
- 7 classes (was 3)
- 8 detectable synergies (was 4)
- 6 biomes visible (was 1 visible by accident of UI bug; now 4 starter + chain)
- 2 memory entries written
- 7 process rules codified
- 3 playtests DRAFT pending grading
- 0 open PRs on main

The project is in good shape for Sprint 28 — pending the playtest verdict that the human needs to deliver. After that verdict, Sprint 28 picks up content cadence again per the rules above.
