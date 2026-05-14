# Sprint 17 — 2026-05-13 to 2026-05-26 (10 working days)

> **Status: Retroactive Day-1 plan authored 2026-05-14**, day 2 of the sprint window. Sprint 17 already shipped 4 PRs (#83–#86) on 2026-05-13 — a single-day burst executing Sprint 16 retro action #2 ("check biome saturation; pivot if filler"). The pivot direction chosen: **matchup hints UI sweep** (counter-archetype signals across all surfaces). One PR (recruit + HeroCard counter-tag, branch `sprint-17/recruit-and-herocard-counter-tag` @ commit `d2da2af`, v0.0.0.36) is ready-to-merge and closes the chain. Solo review mode.

## Sprint Goal

**Ship the counter-archetype matchup-hints UI sweep end-to-end and validate the Sprint 16 progression chain via playtest.** Sprint 16 added 5 biomes and a progression-gate mechanic but produced more *content* than *guidance* — the player can choose biomes but doesn't know *which hero classes* counter which biomes. Sprint 17 closes that loop: every surface where the player picks a hero or a biome now surfaces the matchup signal (biome tabs, recommended classes, Hero Detail, Formation roster, Recruit screen, HeroCard). Once the chain is shipped, the Sprint 16 progression-chain playtest validates the combined Sprint 16+17 experience.

**Definition of Sprint 17 success**: (a) all 5 matchup-hints surfaces shipped (PRs #83, #84, #85, #86, + the d2da2af branch merged); (b) progression-chain playtest committed with a verdict on whether the combined Sprint 16+17 experience feels good; (c) at least one Sprint 16 retro action item closed beyond the matchup-hints pivot itself.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days
- Available: **8.0 days**

**Calibration note**: Sprint 16 shipped 9 PRs in compressed cadence. Sprint 17 shipped 4 PRs on Day 1 alone. The same-day-compressed pattern is now the norm (S14: ~2 days, S15: 1 day, S16: ~1 day, S17 Day 1: 4 PRs). Estimate Sprint 17 will close inside the 10-day window with substantial Nice-to-Have headroom.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S17-M1 | **Matchup hints on biome tabs + accurate `dominant_archetypes`** — surface counter-archetype info on the biome selection surface. | claude-code | 0.25d | none | PR #83 merged (`bdc35d4`, v0.0.0.32) ✅ |
| S17-M2 | **Matchup hint prescriptive — "Recommended: Rogue, Mage"** — convert raw archetype info into actionable class recommendation. | claude-code | 0.25d | M1 | PR #84 merged (`3b728ea`, v0.0.0.33) ✅ |
| S17-M3 | **Hero Detail shows "Strong vs: <archetype>"** — surface counter info from the hero perspective. | claude-code | 0.25d | M1 | PR #85 merged (`bf132f8`, v0.0.0.34) ✅ |
| S17-M4 | **Formation roster shows "vs <archetype>" per hero** — surface counter info on the assignment surface. | claude-code | 0.25d | M1, M3 | PR #86 merged (`8b293ee`, v0.0.0.35) ✅ |
| S17-M5 | **Matchup signal on HeroCard + Recruit Screen (chain complete)** — final two surfaces; closes the matchup-hints UI sweep. | claude-code | 0.25d | M1–M4 | Branch `sprint-17/recruit-and-herocard-counter-tag` (`d2da2af`, v0.0.0.36) → merged to main |
| S17-M6 | **Progression-chain playtest (Sprint 16 retro action #1)** — cold launch → clear Forest Reach + Frostmire bosses → see Ember Wastes unlock → clear → see Hollow Stair unlock. Validate cozy feel of unlock moments and that matchup hints are *useful* in actual play. | xiaolei (human) | 0.5d | M5 | `production/playtests/playtest-09-progression-chain-2026-05-??.md` committed with verdict |
| S17-M7 | **Sprint 17 retrospective** | producer + claude-code | 0.25d | M6 | `production/retrospectives/sprint-17-retrospective-2026-05-??.md` |

**Must Have total**: 2.0 days (1.25 already shipped; 0.75 remaining)

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S17-S1 | **Recruitment Stories 5+7 audit closure** (Sprint 16 retro action #3; carried 4 sprints) — either do the audit (walk §J ACs, mark each shipped/N/A) OR formally retire the checklist as superseded. | qa-tester + claude-code | 0.5d | none | §J each story marked DONE or N/A with PR reference, OR retirement note appended to `recruitment-system.md` |
| S17-S2 | **Re-baseline biome cost in production docs** (Sprint 16 retro action #4) — biome adds are now ~0.2d under data-only pattern, not 0.5d. Update sprint-planning calibration notes. | claude-code | 0.1d | none | Calibration note in `production/sprints/sprint-N+1.md` template or `production/sprint-status.yaml` comment |

**Should Have total**: 0.6 days

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Notes |
|----|------|-------|-----------|--------------|-------|
| S17-N1 | **Class synergy V1.0 implementation** — if M6 playtest signals biome saturation (per Sprint 16 retro action #2 pivot logic), this is the next-mechanic candidate. | game-designer + claude-code | 2.0d | M6 verdict | GDD already exists at `design/gdd/class-synergy-system.md` |
| S17-N2 | **First-run onboarding flow UX polish** (carryover S15-N3 → S16-N4 → S17-N2) | ux-designer + ui-programmer | 1.0d | M6 playtest signal | Carried 2 sprints |
| S17-N3 | **HeroLeveling AC-15-02 calibration playtest re-run** (carryover from Sprint 16 plan S16-M1) — only if Sprint 16 retro flagged it as needing a 4th attempt | xiaolei (human) | 0.5d | hardware | Sprint 16 retro should already note disposition |
| S17-N4 | **HD-2D tilt-shift DoF shader** (carryover from S16-N2) — second visible polish pass | godot-shader-specialist | 2.0d | none | Deferred per ADR-0017 |

**Nice to Have total**: 5.5 days (only if M+S completes early with playtest pivot direction)

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| S16 retro action #1 (progression-chain playtest) | Sprint 16 closed without running the validation playtest | → S17-M6 (0.5d) |
| S16 retro action #3 (Recruitment audit) | Has now carried 4 consecutive sprints; either close or retire this sprint | → S17-S1 (0.5d) |
| S16 retro action #4 (re-baseline biome cost) | Documentation fix | → S17-S2 (0.1d) |
| S16-N4 onboarding UX polish | No playtest signal yet demanded it | → S17-N2 (1.0d) |

**Net carryover**: ~2.1 days of nominally-Sprint-16 follow-up into Sprint 17. Acceptable per the cadence pattern.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Progression-chain playtest (M6) reveals matchup hints feel *prescriptive* in a way that reduces player agency (i.e., "follow the recommendation" replaces "experiment with team comps") | MEDIUM | HIGH | M6 playtest report explicitly asks the question; if confirmed, Sprint 18 includes a tuning pass to soften the hint phrasing (e.g., "Common counters" instead of "Recommended") |
| S17-S1 Recruitment audit carries to Sprint 18 (5th sprint) | MEDIUM | LOW | Sprint 17 retro must take a hard decision: do it or retire it. No 5th carry permitted. |
| M5 (recruit + HeroCard) introduces a regression in the recruit flow because it touches a high-traffic screen | LOW | MEDIUM | d2da2af branch is data-only counter-tag display; behavior is read-only. Existing recruit tests cover regressions. |

## Dependencies on External Factors

- Human availability for S17-M6 playtest (Sprint 16 retro action #1)
- Designer review cycles if S17-N1 (class synergy V1.0) is pulled in

## Definition of Done for this Sprint

- [x] M1–M4 matchup-hints PRs merged (PRs #83–#86)
- [ ] M5 recruit + HeroCard PR merged
- [ ] M6 progression-chain playtest report committed with verdict
- [ ] M7 Sprint 17 retrospective written
- [ ] S17-S1 Recruitment audit closed OR formally retired
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code reviewed and merged

## Sprint 18+ candidates

- Class synergy V1.0 implementation (if S17-N1 doesn't fit in S17)
- Matchup-hint tuning pass (if S17-M6 playtest surfaces prescriptiveness concern)
- Onboarding flow polish (carry chain: S15-N3 → S16-N4 → S17-N2)
- HeroLeveling AC-15-02 final disposition (carry: S13-M3 → S14 → S15-M4 → S16-M1 → S17-N3)
- HD-2D tilt-shift DoF (carry from S16-N2)
- FormationAssignment named-presets V1.0 implementation (per `design/gdd/formation-presets.md` shipped in Sprint 16)

## Notes

- **Solo review mode** — no PR-SPRINT producer gate.
- **Retroactive Day-1 plan** — authored 2026-05-14 against work already shipped 2026-05-13. Captures the matchup-hints pivot decision (Sprint 16 retro action #2) and reframes Sprint 17 around the now-visible theme.
- **Cadence inheritance**: Sprint 14 → 15 → 16 → 17 Day 1 all followed compressed real-time-with-zero-carryover. Sprint 17 inherits this.
- **Player-visible weight**: 5/5 Must Haves so far are player-visible UI changes. Honors Sprint 15 retro action item #1 and Sprint 16's "ship visible content" template.

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Per the solo + playtest-driven closure pattern established in Sprints 14-16, the M6 playtest is the load-bearing closure gate.
