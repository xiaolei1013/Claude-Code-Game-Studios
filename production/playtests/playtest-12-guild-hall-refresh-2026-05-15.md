# Playtest 12 — Sprint 20 Guild Hall Refresh visual validation

> **Sprint Mapping**: S20-M6 (`production/sprints/sprint-20.md`).
> **Gate**: Sprint 20 Definition of Done — "Sprint 20 playtest PASS on all 5 visual checks (M6)".
> **Status**: [PENDING — fill in after live playtest of post-PR #119 build]
> **Precedent**: Light-touch sign-off pattern matches playtest-11 (S19-M5) and aligns with project memory `feedback_playtest_driven_closure.md`.

## Session Info

- **Date**: 2026-05-15
- **Build**: v0.0.0.45 (post-PR #119 — Guild Hall theme implementation merged)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse (touch parity validated separately if needed)
- **Session Type**: Sprint 20 redesign visual validation — Guild Hall first end-to-end DESIGN.md application

## Hypothesis Under Test

Sprint 20 M1–M4 authored the design system (DESIGN.md typography/palette/spacing tokens) + 5 new UX specs + the interaction pattern library expansion. Sprint 20 M5 (PR #119, merged) applied the design system to the live `guild_hall.tscn`:

- **LedgerRow theme variation** (interaction-patterns #10): HeroCard Buttons now use a parchment sub-panel register — hairline 1px Slate Ink border at 50% alpha + 2px corner radius + 8px padding — instead of the default Button styling (full 2px border + 4px radius).
- **SynergyBadge node + wiring** (UX-GH-09 + interaction-patterns #11 Conditional Strip): a PanelContainer + Label below the RosterPanel, hidden by default, shown only when the current formation triggers an active class synergy (e.g., 3-warrior → "Steel Wall: +25% gold vs bruisers"). Localized via existing `class_synergy_badge_*` + `class_synergy_effect_*` en.csv keys.
- **Lora variable body font + IM Fell English display font** (M2, PR #115): wired via FontVariation sub_resources in `parchment_theme.tres`.

**Question for S20-M6**: does the redesigned Guild Hall **read as designed** end-to-end — typography + palette + ledger-row HeroCards + conditional synergy strip + tap-target feel + cozy-register integrity — or are there gaps that should drive a follow-up sprint of design-system iteration?

## 5-Check Validation (per Sprint 20 plan §M6)

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | Typography reads as designed (Lora body + IM Fell English title) | [PENDING] | Compare against DESIGN.md §Typography. Lora at 16px body; IM Fell English at the GoldCounter / nav button text. |
| (b) | Palette matches DESIGN.md exactly | [PENDING] | 7-color palette: Parchment Cream / Slate Ink / Ember Rust / Lantern Glow / Moss Verdant / Hollow Slate / Ash Mist. Compare HeroCard ledger-row border (Slate Ink @ 50% alpha) + SynergyBadge fill + GoldCounter text against the hex codes in DESIGN.md. |
| (c) | Synergy strip conditional behavior works | [PENDING] | Recruit 3 warriors, set formation 3W, return to Guild Hall → SynergyBadge appears reading "Steel Wall: +25% gold vs bruisers". Break the formation → badge hides. (Browseable Locked Frontier exists for synergy preview but not in scope for M6.) |
| (d) | Tap targets feel right at touch-parity scale | [PENDING] | All interactive elements ≥44×44 logical px per `.claude/docs/technical-preferences.md`. Validate by tap-test on HeroCard rows + nav buttons. |
| (e) | Cozy register holds — no FOMO patterns introduced | [PENDING] | No urgency timers, no scarcity messaging, no escalating numbers shown. The ledger-row + conditional strip should reinforce **calm bookkeeping** vs **gamified pressure**. |

## Findings

[TO FILL IN POST-PLAYTEST]

**Tester report**: *"[verbatim quote from playtest]"*

[Free-form observations: what worked, what fell short, what surprised, what didn't ship that you expected to see, what shipped that you didn't expect.]

## Test Suite Impact

- Cumulative tests at v0.0.0.45: 4462 PASS / 0 FAIL.
- 8 new contract tests landed in `tests/unit/guild_hall/guild_hall_theme_application_test.gd` (LedgerRow theme variation + SynergyBadge node + Conditional Strip behavior + HeroCard theme application).
- All shader tests continue to pass: 3 warm-lantern + 9 tilt-shift = 12 shader contract tests.

## Files Touched This Session

- This file (new playtest report only) — implementation already shipped in PR #119.

## Verdict

[TO FILL IN POST-PLAYTEST — one of:]

- **S20-M6: CLOSED — PASS** on all 5 checks. Sprint 20 Definition of Done satisfied. Proceed to S20-M7 retro.
- **S20-M6: CONDITIONAL PASS** — N/5 checks pass. Specific gaps surfaced for Sprint 21 design-system iteration. Sprint 20 retro records the gap disposition. Sprint 20 still ships the design system + first application; the gaps are advisory, not blocking.
- **S20-M6: BLOCKED — REVISION NEEDED** — fundamental design-system flaw signaled. Sprint 21 must scope-defer S20-S1 + S20-S2 (Formation Assignment + Recruit Screen theme implementations) and instead iterate the design system before applying it to more screens. See findings.

## Notes

- Light-touch sign-off matches playtest-11 (S19-M5) and the precedent for visual-correctness gates.
- Per Sprint 18 retro action #4: "visual-correctness gap accepted as manual gate" — automated tests verify the wiring (4462 PASS, 8 new theme-application tests); the human-eye check verifies the composition reads correctly.
- If any check fails, the failure does **not** retroactively invalidate the contract tests — those still verify wiring correctness. The failure signals a **design-judgment gap**, which is a different layer than wiring correctness.
- The Sprint 20 retro (S20-M7) will record the design-system delta and any follow-up sprint actions.
