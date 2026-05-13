# Sprint 14 — 2026-05-09 to 2026-05-23 (10 working days, retroactive)

> **Status: RETROACTIVE — authored 2026-05-13 after 7 of 12 stories already shipped.** Sprint started ad-hoc on the `sprint-14/*` branch when Sprint 13 deferred S13-M4 (Hero Detail) and S13-S2 (Settings). This plan codifies what's shipped + scopes the remaining work.

## Sprint Goal

**Wire the Guild Hall surfaces to production quality.** Sprint 13 left two big "code exists but unreachable" gaps — Hero Detail modal and Settings overlay. Sprint 14's already-shipped work fixed both, then iterated on HeroCard visuals (XP bar, touch feedback) and Settings polish (dB, locale, mute, reset). Remaining work: a manual playtest gate, a `SceneManager.show_modal` lifecycle regression hardening, and the carryover S13-M3 close-reload smoke.

**Definition of Sprint 14 success**: (a) Guild Hall HeroCard tap reliably opens Hero Detail with real data; (b) Settings overlay covers volume/mute/reduce-motion/locale/reset; (c) `show_modal` lifecycle bug pattern is locked out via test + SceneManager patch; (d) playtest-07 confirms the loop "Onboarding → Guild Hall → Hero Detail → Settings → dispatch → victory" survives a quit/reopen.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days
- Available: **8.0 days**
- **Burned to-date (2026-05-09 → 2026-05-13)**: ~5.0 days (7 PRs shipped)
- **Remaining**: ~3.0 days

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance / Evidence |
|----|------|-------|-----------|--------------|------------------------|
| S14-M1 | **DONE** — Hero Detail modal wire-up from Guild Hall RosterPanel HeroCard (closes deferred S13-M4) | gameplay-programmer | 0.5d | — | PR #52, v0.0.0.11, merge `fe84cea` |
| S14-M2 | **DONE** — Settings overlay real content + gear icon on Guild Hall (closes deferred S13-S2) | ui-programmer | 1.0d | — | PR #53, v0.0.0.12, merge `4bc2919` |
| S14-M3 | **DONE** — Onboarding first-session E2E test (lock the seed pathway) | qa-tester | 0.5d | — | PR #54, v0.0.0.13, merge `447d12b` |
| S14-M4 | **Carryover from S13-M3** — Story 016 AC-9 close-reload smoke playtest (manual) — real Godot build, verify gold/heroes/dungeon-progress survive quit/reopen | xiaolei (human) | 0.5d | none | `production/playtests/playtest-07-ac9-close-reload-2026-05-??.md` exists; gold + roster + floor unlocks unchanged across restart |
| S14-M5 | **Sprint 14 playtest-07** — full Guild Hall → HeroCard tap → Hero Detail close → Settings open → adjust volume → dispatch → victory loop. Confirm PR #58 visual fixes hold. | xiaolei (human) | 0.5d | M1, M2, S4 | `production/playtests/playtest-07-sprint-14-2026-05-??.md`; no S1/S2 visual bugs observed |
| S14-M6 | **`show_modal` lifecycle hardening** — patch `SceneManager.show_modal()` to call `on_enter()` automatically; add a regression test that opens Hero Detail through the production code path and asserts labels populate (not placeholders). Prevents the next instance of the PR #58 bug class. | godot-gdscript-specialist | 0.75d | — | New test in `tests/unit/scene_manager/show_modal_lifecycle_test.gd`; all existing show_modal call sites audited for `on_enter` double-call safety |

**Must Have total**: 3.75 days. ~2.0 days already burned on M1+M2+M3; ~1.75 remaining for M4+M5+M6.

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S14-S1 | **DONE** — HeroCard XP-progress bar on Guild Hall | ui-programmer | 0.5d | M1 | PR #55, v0.0.0.14, merge `daa08c2` |
| S14-S2 | **DONE** — HeroCard touch feedback + Settings mute toggle | ui-programmer | 0.5d | M1 + M2 | PR #56, v0.0.0.15, merge `570949b` |
| S14-S3 | **DONE** — Settings overlay polish: dB display + locale dropdown + Reset to Defaults button | ui-programmer | 1.0d | M2 | PR #57, v0.0.0.16, merge `1efabb2` |
| S14-S4 | **DONE** — Hero Detail modal placeholder labels + dim backdrop + RosterPanel overlap fixes | gameplay-programmer | 0.5d | M1 | PR #58, v0.0.0.17, commit `701ac4b` |
| S14-S5 | **Sprint 14 retrospective** — extract patterns; especially the `show_modal` lifecycle bug class | producer + claude-code | 0.25d | M4–M6 | `production/retrospectives/sprint-14-retrospective-2026-05-??.md` |

**Should Have total**: 2.75 days. 2.5d already done; 0.25d remaining (retro).

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Notes |
|----|------|-------|-----------|--------------|-------|
| S14-N1 | **Hero Detail interactive actions** — level-up confirm button if hero has reached threshold; dismiss-hero stub (confirms modal pattern works for destructive actions). Per `design/gdd/roster-hero-detail-screen.md`. | gameplay-programmer + ux-designer | 1.0d | M6 (lifecycle harden) | Defer to Sprint 15 if playtest-07 reveals other priorities |
| S14-N2 | **Level-up toast polish** — Sprint 14+ candidate from sprint-13.md. Simple bottom-of-screen toast on `hero_leveled` signal. | ui-programmer | 0.5d | none | Pure additive |
| S14-N3 | **First-run onboarding flow polish** — per Onboarding GDD #29; the seed pathway test (M3) covers logic, but the UX of the first screen needs a designer pass. | ux-designer + ui-programmer | 1.0d | playtest-07 signal | Defer if playtest-07 flags no onboarding-specific complaint |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| S13-M3 Story 016 AC-9 close-reload smoke playtest | Sprint 13 left it open; gated on human availability | → S14-M4 (0.5d) |
| Hero Detail wire-up (S13-M4) | Sprint 13 deferred; absorbed at start of Sprint 14 | → S14-M1 DONE |
| Settings overlay (S13-S2) | Sprint 13 deferred; absorbed at start of Sprint 14 | → S14-M2 DONE |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Playtest-07 surfaces N>3 wiring gaps like playtest-05 did | MEDIUM | MEDIUM | If playtest gaps fit in 1 day, fix in-sprint; otherwise carry to Sprint 15 with a "playtest-driven" tag (per `feedback_playtest_driven_closure.md`) |
| `show_modal` audit (M6) finds other broken call sites | LOW-MEDIUM | LOW | The patch makes `on_enter()` automatic, so other callers benefit silently. Audit step catches any caller that would double-call. |
| Manual playtest (M4) gets deferred again | MEDIUM | LOW | It's been carried for 2 sprints. If still unclosed at Sprint 14 end, S15 absorbs as S15-M1 with explicit user-input tag. |

## Dependencies on External Factors

- Human availability for M4 + M5 playtests (no automation possible)

## Definition of Done for this Sprint

- [x] All Must Have tasks completed (M1–M3 done; M4–M6 pending)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-14.md`)
- [x] All Logic/Integration stories have passing tests — 2089/2089 PASS at v0.0.0.17
- [ ] Playtest-07 report committed
- [ ] No S1 or S2 bugs in delivered features (subject to playtest-07)
- [ ] Sprint 14 retrospective written
- [x] Code reviewed and merged (7 PRs to date)

## Sprint 15+ candidates (post-Sprint-14)

- Recruitment Stories 5-7 — RecruitScreen UI refactor + cost-stability invariant tests
- FormationAssignment Stories 5-7 — named-presets V1.0 surface
- Multi-biome unlock + Matchup Assignment polish (Forest Reach is the only biome)
- Steam Deck verification rehearsal (1280×800 native, 60fps stable)
- Audio asset sourcing follow-through (silent-MVP triggered pivot?)
- Telemetry events V1.0 implementation
- HD-2D shader pass (tilt-shift / warm-lantern per Visual Identity Anchor)

## Notes

- **Retroactive plan**: 7 of 12 stories shipped before this plan was authored. Normal cadence would have started with the plan; this sprint inherited an ad-hoc state from Sprint 13's deferrals. Pattern: when a sprint's branch already exists, plan it Day 0.
- **Solo review mode** — no PR-SPRINT producer gate per `production/review-mode.txt`.
- **PR #58 produced a regression-class insight** captured in M6: `SceneManager.show_modal()` lifecycle hook is non-symmetric vs `request_screen`. Worth a focused fix this sprint.

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.
