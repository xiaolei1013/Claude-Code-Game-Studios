# Sprint 24 Retrospective — 2026-05-16

> **Sprint Mapping**: S24-M4 (playtest gate + retro authoring per the Sprint 24 plan).
> **Sprint Window**: 2026-06-12 to 2026-06-25 nominal; actual close 2026-05-16 (twelfth consecutive same-day-compressed sprint).
> **Review Mode**: Solo.
> **Status**: COMMITTED 2026-05-16 — Sprint 24 Definition of Done satisfied on technical metrics; **player-progress signal FAILED per playtester's verdict**. See §"What Could Be Better" for the load-bearing finding.

## Sprint Goal — TECHNICALLY MET, STRATEGICALLY FAILED

> **Close the Class Synergy V2 tier ladder design loop + refresh the preview label, ship UIFramework hygiene helpers, author Onboarding + Floor Unlock GDDs, and clean up two clarity-polish carryovers.**

Final status against the 7 success conditions defined in the plan:
- (a) `class-synergy-system.md` extended with §V2 Tier Ladder mapping V1 synergies → None/Bronze/Silver/Gold/Platinum tiers; locale keys for tier display names — ✅ S24-M1 shipped (PR #141).
- (b) `SynergyPreviewLabel` on Dispatch screen renders tier names per the new GDD, with tests refreshed — ✅ S24-M2 shipped (PR #142).
- (c) `UIFramework.clear_children_immediate(container)` + `UIFramework.synergy_display_name(synergy_id)` helpers shipped; pre-existing call sites refactored — ✅ S24-M3 shipped (PR #143).
- (d) M4 clarity polish landed — ⚠️ S24-S1 shipped PARTIAL (PR #148: only the Recruit pool empty-state placeholder; Guild Hall active-roster empty-state, Dispatch empty-slot hints, and tap-target audit all deferred).
- (e) `design/gdd/onboarding-first-session.md` authored — ⚠️ S24-S2 closed as VERIFIED-IN-PLACE (PR #144: GDD #29 already existed from 2026-05-06; §K audit note added). **GDD authoring was DUPLICATE work that would have been avoided by grep-first check.**
- (f) `tests/helpers/hero_roster_test_fixture.gd` shipped + ~5 sites refactored — ⚠️ S24-S3 shipped PARTIAL (PR #145: helper + 2 of 5 planned site refactors; the helper is non-breaking so remaining sites can migrate incrementally).
- (g) Visual playtest validates the tier label changes + M4 clarity polish — ✅ playtest completed 2026-05-16. **Playtester's verdict was that the game is not progressing on UI/UX or functions** (see §"What Could Be Better"); the technical surface changes verified clean.

Two additional stories landed beyond plan:
- S24-N1 ClassPortraitFactory `fill_rect` optimization — ✅ shipped (PR #146).
- S24-N2 Floor Unlock GDD authorship — ⚠️ closed as VERIFIED-IN-PLACE (PR #147: GDD #16 already existed from Sprint 18 with 9-pass review history; §K audit note added). **Second duplicate GDD-authoring this sprint.**

## By the Numbers

- **PRs this sprint**: 10 (1 plan + 8 implementation/verification + 1 chore cleanup for `.uid` sidecars).
- **Cumulative tests at sprint close**: ~2270 (was ~2250 at start of S24; +20 net new across 4 new test files).
- **Regressions**: 0. Full suite green across the sprint.
- **New ADRs**: 0.
- **GDD status transitions**: 0 NEW (S24-S2 + S24-N2 both turned out to be already-authored). 1 AMENDMENT (`class-synergy-system.md` §C.6 V2 Tier Ladder via S24-M1).
- **New player-visible surface**: 1 tier label format change on Dispatch (Bronze/Silver/Gold/Platinum + None) + 1 empty-state placeholder on Recruit pool. **2 of 10 PRs touched player-visible surface.**
- **Locale keys added**: 7 (6 synergy tier + 1 recruit pool empty-state).
- **Scene registry**: unchanged (6 screens + 1 overlay).
- **Version**: 0.0.0.57 → ~0.0.0.65 across the sprint (8 implementation PRs + cleanup).
- **Solo same-day cadence**: 12th consecutive sprint (S14 → S24).

## What Worked

- **Per-task PR with `base=main` (Sprint 24 Process Rule #1) prevented the Sprint 23 stacked-PR cascade.** All 9 sprint PRs + 1 cleanup PR merged cleanly in numerical order; no recovery PR needed. The rule should stay in every sprint plan going forward.
- **Grep-first dependency check (Sprint 24 Process Rule #3) caught two pre-existing GDDs that would have produced duplicate authoring** (S24-S2 Onboarding + S24-N2 Floor Unlock). Both closed as VERIFIED-IN-PLACE with audit notes appended. The check should move upstream into `/sprint-plan new` itself so future plans never scope "author GDD X" when the file already exists.
- **HeroRoster test fixture helper centralized a 5+ site duplication** (S24-S3). Even with only 2 sites refactored in the PR, the helper is non-breaking; new tests can use it and old sites can migrate incrementally without coordination.
- **Tier ladder GDD amendment shipped self-contained** (S24-M1 + M2). The Bronze/Silver/Gold/Platinum mapping anchored to existing V1 synergy strength (3-of-a-kind = Gold; 1-of-a-kind = None) avoided the "contentious tier mapping" risk flagged in the plan.
- **ClassPortraitFactory fill_rect refactor** (S24-N1) replaced ~9000 wasted-iteration set_pixel branches per first-paint per class with 4 strip memsets + a regression-tested glyph mask. Cache amortizes the cost in production, but the optimization made the intent clear and shipped with 4 regression tests verifying strip boundaries.

## What Could Be Better

**LOAD-BEARING FINDING: Sprint 24 surfaced the "infrastructure debt drift" pattern.** Playtester verdict: *"for now we still do not have much progress. the uiux and functions are not progressing too much."* This is honest signal that the project has been spinning wheels on cleanup work for multiple consecutive sprints while the player-facing game has not grown.

Sprint 24 PR-by-PR player impact audit:
- 5 of 10 PRs had **zero player-visible change**:
  - PR #144 (S24-S2) — GDD audit note only
  - PR #145 (S24-S3) — internal test helper
  - PR #143 (S24-M3) — internal hygiene helpers
  - PR #146 (S24-N1) — perf optimization invisible to player (cache-amortized)
  - PR #147 (S24-N2) — GDD audit note only
- 2 of 10 PRs touched player-visible surface but **only minor changes**:
  - PRs #141 + #142 (S24-M1 + M2) — tier label format on Dispatch (Bronze/Silver/Gold/Platinum)
  - PR #148 (S24-S1) — Recruit pool empty-state placeholder (defensively triggered, rarely seen)
- 3 of 10 PRs were process plumbing (Day-0 plan, sprint-24.md, .uid sidecar cleanup).

**This is not a Sprint-24-specific failure.** Sprint 22 was scene consolidation; Sprint 23 was scene retire + pause modal + settings; Sprint 21 was theme inheritance fix ("5 sprints of theme work were invisible to players" — Sprint 21 retro). **The game's content surface has been frozen at 3 classes / 1 biome / 5 floors / programmatic placeholder art for many consecutive sprints while internal infrastructure has been heavily refined.**

Companion findings:
- **Third occurrence of "author GDD X" stories scoping work that's already done** (S24-S2 Onboarding GDD authored 2026-05-06; S24-N2 Floor Unlock GDD authored through 9 review passes by Sprint 18; the Sprint 24 plan asked for both as if NEW). Grep-first check is the durable fix and should land in `/sprint-plan new` itself.
- **Sprint 24 S1 polish item under-delivered.** Plan called for empty-state copy on 3 screens + tap-target audit + Primary Button pattern audit. Only 1 of 4 items landed (Recruit pool placeholder). Advisory polish is intentionally trimmable, but if the plan is going to consistently land partial polish, future plans should scope it as the 1 thing that's most player-facing, not the 4-item wishlist.
- **The Onboarding GDD #29 + Floor Unlock GDD #16 have BOTH been ready for implementation since Sprint 14/18.** Neither has shipped implementation. The implementation work is what would actually move the player-progress needle; the GDD-authoring work is what we've spent sprints duplicating.

## What I'd Do Differently Next Time

1. **Before scoping any sprint, ask: "what does the player SEE differently after this sprint?"** If the answer is "nothing or barely anything," challenge the scope. Sprint 24 would not have passed this check.
2. **Prefer implementation of existing GDDs over authoring new ones.** Sprint 25 candidates from the prior plan (Onboarding implementation, Floor Unlock implementation, real product art ingestion) are all implementation-of-existing-GDD work. That's the path forward.
3. **Run `/sprint-plan new` with grep-first GDD-existence check baked in.** Three occurrences in three sprints (S24-S2 Onboarding, S24-N2 Floor Unlock, the catchup retro's mention of similar earlier drift) confirms the check needs to live in the planning skill, not in the developer's discipline.
4. **Constrain Should/Nice-to-Have polish stories to ONE item, not a wishlist.** S24-S1's "empty-state copy on 3 screens + tap-target audit + Primary Button audit" was 4 items that the sprint only had 1.0d budget for. Picking the highest-impact 1 item up front would have produced the same shipping outcome with clearer accountability.
5. **Treat "test count grew but player surface didn't" as a Sprint Goal NOT-met signal even when all 5 success conditions tick green.** Sprint 24's Definition of Done was 7 boxes that all ticked but none of them said "player feels the game is bigger after this sprint."

## Sprint 25 Recommendations

**Pivot to content + implementation-of-existing-GDDs, not new infrastructure.** Per the load-bearing finding above and the new memory entry `feedback_infrastructure_debt_drift.md`, Sprint 25 should ship work that the playtester sees a difference in. Candidate epics:

1. **Floor Unlock System implementation** (GDD #16 ready since Sprint 18). Multi-floor progression gating with biome unlocks. This is the load-bearing "feels like the game has depth" change. ~3-4 days estimated based on the GDD's §J implementation sequencing (4 stories).
2. **Add 1-2 new biomes** with distinct visual identity + matchup interactions. Gives Floor Unlock content to gate. Each biome adds ~5 floors + a biome background + matchup tuning. ~2 days per biome with the existing biome-context pattern.
3. **Onboarding first-session flow implementation** (GDD #29 ready since 2026-05-06). First-time player sees a Tutorial context, not bare Guild Hall. ~2 days estimated.
4. **Add 1-2 new classes** (paladin, ranger). Doubles synergy interaction space; the V2 tier ladder amendment in S24-M1 already documented the expected synergy expansion. ~1.5 days per class with the existing class-data pattern.
5. **DEFER**: new GDD authoring, test fixture refactoring of remaining sites, further `/simplify+/review` polish on already-shipped surfaces, theme polish iterations, and similar internal refinement work — **unless** a specific item is blocking a content story.

**Capacity recommendation**: target 8 days of player-visible work in Sprint 25. If that means dropping 2-3 of the candidate epics, drop the "add new classes/biomes" ones (more content of the same shape) and keep Floor Unlock + Onboarding implementation (more depth in existing shape).

**Process recommendation**: at sprint mid-point, run a "show me the diff a player sees" self-check. If you can't articulate the answer in one sentence, the plan is drifting back into infrastructure.

## Files Touched This Session

- `production/sprints/sprint-24.md` (NEW) — Day-0 plan (PR #140)
- `production/sprint-status.yaml` — Sprint 23 archived, Sprint 24 stories block (PR #140)
- `design/gdd/class-synergy-system.md` — §C.6 V2 Tier Ladder amendment + 5 new ACs (PR #141)
- `assets/locale/en.csv` — 6 synergy tier keys + 1 recruit pool empty-state key (PRs #141, #142, #148)
- `assets/screens/formation_assignment/formation_assignment.gd` — tier-aware preview label (PR #142)
- `assets/screens/formation_assignment/formation_assignment.gd` + `guild_hall/guild_hall.gd` + `victory_moment/victory_moment.gd` — refactor to use UIFramework helpers (PR #143)
- `src/ui/ui_framework.gd` — new helpers: `clear_children_immediate`, `synergy_display_name`, `synergy_id_to_tier` (PR #143)
- `tests/unit/ui_framework/ui_framework_helpers_test.gd` — 11 new tests for new helpers (PR #143)
- `tests/unit/formation_assignment/synergy_preview_label_test.gd` — tier rendering tests (PRs #142, #145)
- `design/gdd/onboarding-first-session.md` — §K Sprint 24 audit note (PR #144)
- `tests/helpers/hero_roster_test_fixture.gd` (NEW) — fixture helper (PR #145)
- `tests/unit/helpers/hero_roster_test_fixture_test.gd` (NEW) — fixture tests (PR #145)
- `tests/unit/guild_hall/retired_tab_render_test.gd` — refactored to use fixture (PR #145)
- `src/ui/class_portrait_factory.gd` — border strip fill_rect refactor (PR #146)
- `tests/unit/class_portrait_factory/class_portrait_factory_test.gd` — 4 new border-pixel regression tests (PR #146)
- `design/gdd/floor-unlock-system.md` — §K Sprint 24 audit note (PR #147)
- `assets/screens/recruitment/recruitment.gd` — empty-state placeholder (PR #148)
- `tests/unit/recruitment/recruit_pool_empty_state_test.gd` (NEW) — 2 tests (PR #148)
- `tests/helpers/*.uid`, `tests/unit/helpers/*.uid`, `tests/unit/recruitment/*.uid` — sidecars (PR #149)
- `production/retrospectives/sprint-24-retrospective-2026-05-16.md` (NEW) — this file

## Memory Recorded This Sprint

- `feedback_infrastructure_debt_drift.md` — **load-bearing**: recent sprints land lots of cleanup with no player-visible progress; user flagged "uiux and functions are not progressing." Prefer content + mechanics + implementation-of-existing-GDDs over new GDD authoring + hygiene refactors. References [[feedback_playtest_driven_closure]] (100% tests passing ≠ shipped game) and [[feedback_scaffolded_but_unwired_pattern]] (sibling failure mode).

## Carryover Acknowledged

- S24-S1 partial: Guild Hall active-roster empty-state, Dispatch empty-slot hints, tap-target audit, Primary Button pattern audit — **defer permanently** unless playtest signal demands them. Sprint 25 should not pick these up.
- S24-S3 partial: 3 remaining test sites (`tests/integration/guild_hall/roster_panel_test.gd`, `tests/unit/formation_assignment/synergy_badge_test.gd`, etc.) un-refactored to use the new fixture. Helper is non-breaking; defer until next time those test files are touched for unrelated reasons.

## Sprint Goal — Final Disposition

**MET on technical surface; FAILED on strategic intent.** The sprint plan's success conditions all ticked, but the playtester's verdict establishes that "Sprint 24 shipped 10 PRs" is not the same as "Sprint 24 advanced the game." Sprint 25 must answer this honestly in its plan: what does the player see, feel, or experience that's different after this sprint ships?
