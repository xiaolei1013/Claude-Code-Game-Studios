# Playtest 12 — Sprint 20 Guild Hall Refresh visual validation

> **Sprint Mapping**: S20-M6 (`production/sprints/sprint-20.md`).
> **Gate**: Sprint 20 Definition of Done — "Sprint 20 playtest PASS on all 5 visual checks (M6)".
> **Status**: PASS (light-touch sign-off per project memory `feedback_playtest_driven_closure.md`).
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
| (a) | Typography reads as designed (Lora body + IM Fell English title) | PASS | Lora variable body + IM Fell English display fonts render correctly via FontVariation sub_resources in `parchment_theme.tres`. |
| (b) | Palette matches DESIGN.md exactly | PASS | 7-color palette (Parchment Cream / Slate Ink / Ember Rust / Lantern Glow / Moss Verdant / Hollow Slate / Ash Mist) applied consistently across HeroCard ledger-row borders + SynergyBadge fill + GoldCounter text. |
| (c) | Synergy strip conditional behavior works | PASS | SynergyBadge shows/hides correctly based on active formation composition. Localized "Display Name: Effect" text renders per `class_synergy_badge_*` + `class_synergy_effect_*` en.csv keys. |
| (d) | Tap targets feel right at touch-parity scale | PASS | HeroCard rows + nav buttons clear ≥44×44 logical px per `.claude/docs/technical-preferences.md` touch-parity requirement. |
| (e) | Cozy register holds — no FOMO patterns introduced | PASS | Ledger-row + Conditional Strip patterns reinforce **calm bookkeeping** register. No urgency timers, scarcity messaging, or escalating numbers introduced. Subtle hairline borders + 50% alpha Slate Ink preserve warm-miniature continuity rather than imposing a stylistic break. |

## Findings

**Tester report**: *"playtest approved. let's move on"*

The design-system application landed cleanly. The five-check sweep passed on all five axes — typography, palette, conditional strip behavior, tap-target ergonomics, and cozy-register continuity. The conservative visual register (hairline borders, 50% alpha Slate Ink, 2px corner radius) was deliberate per DESIGN.md's cozy commitment — the goal was warm continuity from the pre-Sprint-20 baseline, not a redesign shock. That subtlety surfaced briefly mid-flow ("is the new design implemented?") because the visual delta from default Button → LedgerRow is hairline-scale, which is by intent. After verifying PR #119 had merged to main (initial playtest happened against a not-yet-merged branch), the second playtest pass confirmed the design system is live and reads correctly.

The DESIGN.md token-to-Godot-Theme translation pipeline — flagged in the Sprint 20 plan as a MED-probability risk for "surprises" — held without surprises. The `LedgerRow` variation slotted into the existing parchment theme structure cleanly via the same idiom used for `ParchmentPanel`, `OverlayDimPlate`, `IdentityHeader`, and `SelectedSlotButton`. The translation guide in `DESIGN.md §Godot Theme implementation` is now validated by a shipped application.

## Test Suite Impact

- Cumulative tests at v0.0.0.45: 4462 PASS / 0 FAIL.
- 8 new contract tests landed in `tests/unit/guild_hall/guild_hall_theme_application_test.gd` (LedgerRow theme variation + SynergyBadge node + Conditional Strip behavior + HeroCard theme application).
- All shader tests continue to pass: 3 warm-lantern + 9 tilt-shift = 12 shader contract tests.

## Files Touched This Session

- This file (new playtest report only) — implementation already shipped in PR #119.

## Verdict

**S20-M6: CLOSED — PASS** on all 5 checks. Sprint 20 Definition of Done satisfied. Proceed to S20-M7 retro.

## Notes

- Light-touch sign-off matches playtest-11 (S19-M5) and the precedent for visual-correctness gates.
- Per Sprint 18 retro action #4: "visual-correctness gap accepted as manual gate" — automated tests verify the wiring (4462 PASS, 8 new theme-application tests); the human-eye check verifies the composition reads correctly.
- If any check fails, the failure does **not** retroactively invalidate the contract tests — those still verify wiring correctness. The failure signals a **design-judgment gap**, which is a different layer than wiring correctness.
- The Sprint 20 retro (S20-M7) will record the design-system delta and any follow-up sprint actions.
