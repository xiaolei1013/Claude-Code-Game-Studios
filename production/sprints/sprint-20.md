# Sprint 20 — 2026-05-14 to 2026-05-27 (10 working days)

> **Status: Day-0 plan authored 2026-05-14**, same-day close of Sprint 19.
> Seventh consecutive same-day-compressed sprint (Sprint 14→15→16→17→18→19→20).
> Solo review mode.

## Sprint Goal

**Lock the UI/HUD design pass for the cozy register: finish the design system + all per-screen UX specs, implement Guild Hall to validate the system end-to-end, and ship the long-overdue scaffolds audit.**

Sprint 19 closed with the HD-2D visual pipeline active, and the user surfaced the UI/HUD design as the next priority during the M5 playtest. Pre-sprint work has already shipped the foundation (DESIGN.md, Guild Hall + Formation Assignment + Recruit Screen UX specs). Sprint 20 formalizes the remaining UX specs (5 screens), drops in the font assets the design system relies on, applies the design system to Guild Hall to prove the end-to-end pipeline works, and finally closes the twice-deferred scaffolds audit from Sprint 18's retro action #1.

**Definition of Sprint 20 success**:
(a) 5 remaining UX specs (DungeonRunView, Return-to-App, Victory Moment, Hero Detail Modal, Matchup Assignment) all reach Draft status with ≥15 ACs each;
(b) Lora + IM Fell English TTF assets present at `res://assets/fonts/`, wired into the parchment theme;
(c) Guild Hall theme refresh implemented per its UX spec — visible visual delta when the player loads the game;
(d) Pattern library updated with 6 new patterns from the 3 specced screens;
(e) Scaffolds audit (S18 retro action #1) executed; any confirmed ghosts fixed;
(f) Sprint 20 playtest validates the Guild Hall refresh feels right against the cozy register;
(g) Sprint 20 retro captures lessons + Sprint 21 setup.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: this sprint mixes content (UX specs, pattern library), platform (font assets, theme refresh), and discipline (scaffolds audit). The most volatile item is M5 (Guild Hall theme implementation) — first time the design system applies to real code; allow buffer for DESIGN.md token-to-Godot-Theme translation surprises.

## Pre-Plan Deliverables (already merged 2026-05-14, NOT counted in sprint scope)

These shipped before the Sprint 20 plan was formally authored. They constitute the foundation that this plan formalizes:

| PR | Deliverable | Closed |
|----|-------------|--------|
| #110 | Guild Hall UX spec (`design/ux/guild-hall.md`) — first per-screen UX spec | 2026-05-14 |
| #111 | DESIGN.md — design system source of truth | 2026-05-14 |
| #112 | Formation Assignment UX spec (`design/ux/formation-assignment.md`) | 2026-05-14 |
| #113 | Recruit Screen UX spec (`design/ux/recruit-screen.md`) | 2026-05-14 |

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance |
|----|------|-------|------|--------------|------------|
| S20-M1 | **Scaffolds audit** (S18 retro action #1, twice-deferred — non-negotiable now) — grep across `src/` for `# provisional`, `# MVP`, `# stub`, `# placeholder`, `= 1.0  #`, snapshot fields never written outside `_init`, helper methods with no callers. Produce report; fix any confirmed scaffolding ghosts with regression tests. Per project memory `feedback_scaffolded_but_unwired_pattern`. | claude-code | 0.25d | none | Audit report committed to `production/sprint-20-scaffolds-audit.md`; confirmed ghosts fixed + regression-tested; zero `# provisional` placeholders remain in non-test code |
| S20-M2 | **Font sourcing — Lora + IM Fell English** — download TTF files for both font families (Regular / Medium / SemiBold / Bold for Lora; Regular / Italic for IM Fell English) from Google Fonts (SIL OFL licenses). Place at `res://assets/fonts/Lora/` and `res://assets/fonts/IM_Fell_English/` with LICENSE.txt copies. Update `assets/ui/parchment_theme.tres` to declare the fonts in Godot's theme system. | claude-code | 0.25d | none | All font weight files present at expected paths; LICENSE.txt files copied; parchment theme references the fonts; one smoke test verifies Theme resource loads without error |
| S20-M3 | **5 remaining UX specs** — author Draft specs for: (a) Dungeon Run View (the in-run HUD per `design/gdd/dungeon-run-view.md`); (b) Return-to-App (per `design/gdd/return-to-app-screen.md`); (c) Victory Moment (per `design/gdd/victory-moment.md` if exists, else from `design/art/art-bible.md` §reward-moment); (d) Hero Detail Modal (per `design/gdd/hero-detail-modal.md` if exists); (e) Matchup Assignment Screen (per `design/gdd/matchup-assignment-screen.md`). Each follows the established 14-section template + ≥15 ACs + ASCII wireframe. References DESIGN.md tokens. | claude-code | 1.25d | M2 (fonts need to exist before specs can reference them precisely) | 5 new `design/ux/*.md` files committed; each has all 14 required sections; each has ≥15 testable ACs; each references DESIGN.md tokens |
| S20-M4 | **Pattern library additions — 6 new patterns** to `design/ux/interaction-patterns.md` — surfaced by the 3 pre-plan specs: (a) **Guild-Ledger-Entry** (parchment sub-panel register from Guild Hall HeroCards); (b) **Conditional Strip** (zero-height when inactive, expand on activate — Guild Hall synergy strip + Recruit empty-state); (c) **Slot Button** (large square button as content container — Formation Assignment slot buttons); (d) **Two-Tap Assignment Flow** (tap-target-then-tap-source pattern — Formation Assignment formation editing); (e) **Affordability Gating** (universal cost-shown / gated-action / deficit-tooltip — Guild Hall recruit gate + Recruit Screen rows); (f) **Pool Entry Card** (ledger-row variant with portrait + multi-line details + action — Recruit Screen pool entries). | claude-code | 0.5d | none | All 6 patterns added to `interaction-patterns.md` with: When to Use / When NOT / Specification / Accessibility / Reference; pattern catalog index updated |
| S20-M5 | **Guild Hall theme implementation** — apply DESIGN.md tokens + Guild Hall UX spec to `assets/screens/guild_hall/guild_hall.tscn` + `guild_hall.gd`. Wire Lora + IM Fell English fonts into the screen's Theme overrides. Add the synergy strip node (conditional 48px height) per spec UX-GH-09. Apply parchment-default + ledger-row panel variants. Update existing 14 ACs into runtime tests. | godot-gdscript-specialist | 0.75d | M2 + M4 | Guild Hall renders the locked DESIGN.md system; HeroCards use ledger-row variant; synergy strip appears conditionally; existing tests stay green; new test asserts theme override coverage |
| S20-M6 | **Sprint 20 playtest** — visual validation of redesigned Guild Hall. 5 checks: (a) typography reads as designed (Lora body + IM Fell English title); (b) palette matches DESIGN.md exactly; (c) synergy strip conditional behavior works; (d) tap targets feel right at touch-parity scale; (e) cozy register holds — no FOMO patterns introduced. | xiaolei (human) | 0.5d | M5 | `production/playtests/playtest-12-guild-hall-refresh-2026-05-??.md` committed with verdict on all 5 checks |
| S20-M7 | **Sprint 20 retrospective** | producer + claude-code | 0.25d | M6 | Retro doc committed; sprint-status.yaml closed |

**Must Have total**: 3.75 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S20-S1 | **Formation Assignment theme implementation** — apply DESIGN.md + UX spec to existing `formation_assignment.tscn`. Slot Button variant + tap-tap flow polish + mid-run modal styling. Most polish-tier; current scene already works functionally. | godot-gdscript-specialist | 0.75d | M2 + M5 (gain confidence in token translation pipeline before doing a second screen) | Spec UX-FA-01..21 satisfied; existing tests stay green |
| S20-S2 | **Recruit Screen theme implementation** — apply DESIGN.md + UX spec to existing `recruitment.tscn`. Pool Entry Card variant + Affordability Gating pattern + cross-fade pool refresh animation per UX-RS-10. | godot-gdscript-specialist | 0.75d | M2 + M5 | Spec UX-RS-01..20 satisfied; existing tests stay green |

**Should Have total**: 1.5 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S20-N1 | **ClassPortrait placeholder art** — generate 6 placeholder class portrait textures (Warrior / Mage / Rogue / Cleric / Ranger / Tactician) as parchment-cream squares with the class's IM Fell English first letter inset in Slate Ink. Resolves OQ-RS-01 from Recruit Screen spec. Drop-in replacement for real art when it arrives. | claude-code + godot-shader-specialist | 0.5d | M2 | Pull in only if M+S completes with playtest headroom |

**Nice to Have total**: 0.5 days

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S19-S1 (Scaffolded-but-unwired audit) | Twice-deferred (S18 retro #1 → S19-S1 → ???). Pulled forward as S20-M1. | → S20-M1 (0.25d) |
| S19-S2 (per-biome tilt-shift presets) | Retired per Sprint 19 retro pending real-biome-art trigger | ❌ RETIRED |
| S19-N1 (gradient shader) | Same — retired pending real-biome-art trigger | ❌ RETIRED |

## Risks

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| DESIGN.md token-to-Godot-Theme translation hits unexpected friction during M5 (first end-to-end application) | MED | MED | M5 has 0.75d budget with explicit allowance for surprises. If translation reveals gaps in DESIGN.md (e.g., font metric overrides needed), pause M5 and patch DESIGN.md before continuing. Token surprises are the most valuable signal this sprint can produce. |
| 5 UX specs in M3 trigger fatigue or shortcut-taking | MED | LOW | The first 3 specs (pre-plan) established the template + 3 ACs minimum per section. Use the same template; each spec inherits ~70% of the structural decisions. Per-spec effort drops with practice. Buffer 0.25d/spec is generous. |
| Lora tabular-nums not supported by Godot 4.6 FontFile (OQ-DS-01) | LOW | LOW | Verified at M2 font sourcing. Fallback: ship without tabular-nums; column-align stat tables manually via padding. Document in DESIGN.md amendment. |
| Scaffolds audit surfaces critical wiring bugs that need immediate fixes | LOW-MED | MED | Treat as discovery — if M1 surfaces a critical scaffolded-but-unwired bug, halt other work and ship the fix as a hotfix PR. This is the whole point of running the audit; finding bugs is the success state. |
| Visual playtest signals a major design system flaw | LOW | MED-HIGH | M6 is the gate. If playtest signals "this doesn't feel right," scope-defer M5/S1/S2 to fix the design system iteratively rather than ship a flawed system. |

## Dependencies on External Factors

- **Lora + IM Fell English font availability**: Google Fonts SIL OFL licenses verified during DESIGN.md authoring. Download path: https://fonts.google.com/specimen/Lora + https://fonts.google.com/specimen/IM+Fell+English. No external blocking.
- **Real product art** (user's separate workstream, no ETA): Sprint 20 does not gate on real art. The pre-plan Guild Hall + Formation + Recruit specs all assume placeholder portraits; real art swaps in zero-code.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and reviewed
- [ ] Scaffolds audit report committed; confirmed ghosts fixed + regression-tested (M1)
- [ ] Lora + IM Fell English assets in `res://assets/fonts/` with LICENSE.txt (M2)
- [ ] 5 new UX specs (DRV / Return-to-App / Victory Moment / Hero Detail / Matchup Assignment) each have all 14 required sections + ≥15 ACs (M3)
- [ ] 6 new patterns added to `interaction-patterns.md` (M4)
- [ ] Guild Hall renders the DESIGN.md system; new theme test covers token application (M5)
- [ ] Sprint 20 playtest PASS on all 5 visual checks (M6)
- [ ] Sprint 20 retro committed; sprint-status.yaml all Must Haves marked done
- [ ] No S1 or S2 bugs in delivered features
- [ ] All 4 pre-plan PRs (#110-#113) referenced in retro as foundation work

## Notes

- **Pre-plan deliverables consumed real effort** (~3 days across Guild Hall spec + DESIGN.md + Formation spec + Recruit spec). Sprint 20's 3.75d Must Have budget is on top of that. The grand "Sprint 20 phase" effort is closer to 7 days total — appropriate for the UI/HUD theme.
- **Solo same-day cadence target**: seventh consecutive sprint. If M5 (Guild Hall theme implementation) hits unexpected friction, extending into Sprint 21 is acceptable — same-day close is preference, not commitment.
- **20 ADRs cumulative + pre-Sprint-20 `/architecture-review` recommendation**: Sprint 18 retro flagged `/architecture-review` before Sprint 20 as healthy hygiene. Not blocking. Recommend running it during Sprint 20 wind-down (post-M7) as Sprint 21 setup.
- **The cozy register is the load-bearing acceptance gate**: every Must Have must be reviewed against "does this preserve cozy register?" before merge. Specifically: no FOMO patterns, no aggressive feedback, no friction-for-engagement. The scaffolds audit (M1) may surface latent FOMO scaffolding that should be retired alongside any actual code fixes.
