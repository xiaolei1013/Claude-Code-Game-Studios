# Playtest 18 — Sprint 27 synergy effect text on Dispatch label

> **Sprint Mapping**: S27-M2 (`production/sprints/sprint-27.md`).
> **Gate**: Sprint 27 Definition of Done — effect text closes the teaching gap for synergies.
> **Status**: PENDING — graded by tester. Can be folded into a single deep playthrough alongside playtest-16 (Sprint 25) and playtest-17 (Sprint 26) given the compounded content surface.
> **Precedent**: Per-check granularity per `_template-visual-playtest.md`.

## Session Info

- **Date**: TBD (post-merge of PRs #166 + #167)
- **Build**: TBD (will be the version after all S27 PRs land)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build)
- **Input Method**: Mouse
- **Session Type**: Sprint 27 single-Must-Have validation. Compounds on top of Sprint 25 + 26 content.

## Hypothesis Under Test

Sprint 27 M1 added effect text to the SynergyPreviewLabel format. Before:
- "Synergy: Gold (Steel Wall)" — player knows synergy is active but not what it does.

After:
- "Synergy: Gold (Steel Wall) — +25% gold vs bruisers" — player sees both name AND effect inline.

The effect text for all 8 synergies (4 V1 + 4 tier-2) routes through `class_synergy_effect_<id>` locale keys. The new `UIFramework.synergy_effect_text(synergy_id)` helper centralizes the lookup.

**Question for M2**: does the post-Sprint-27 SynergyPreviewLabel teach the player what each synergy does, and does the em-dash separator format read cleanly?

**Disconfirmation criterion**: if the effect text feels cluttered, wraps badly, or contradicts what the matchup mechanic actually does, the surface needs revision.

## Per-Check Validation

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | 3-warrior formation → label reads "Synergy: Gold (Steel Wall) — +25% gold vs bruisers" | TBD | Open Dispatch with 3 warriors slotted. Verify label format includes em-dash + effect text. |
| (b) | 3-paladin formation → label reads "Synergy: Gold (Bastion) — +25% gold vs casters" | TBD | Tests tier-2 synergy effect text (V2 set). |
| (c) | 3-cleric formation → label reads "Synergy: Gold (Vigil) — +20% XP from all kills" | TBD | Tests XP-path effect text (Vigil mirrors Arcane Elite). |
| (d) | No-synergy formation (e.g., 2 warriors + 1 mage) → label reads "Synergy: None" (NO effect text appended) | TBD | Negative-space check: no em-dash, no garbage effect text when no synergy fires. |
| (e) | Effect text wraps acceptably at narrow widths (Steam Deck portrait, mobile-equivalent ~720px) | TBD | UI sanity check: the longer effect text shouldn't cause label overflow or weird wrapping. |

## Findings (to fill in)

**Tester report (TBD)**: TBD

## Test Suite Impact

- **Before Sprint 27**: ~2335 tests (from Sprint 26 close estimate)
- **After Sprint 27**: ~2340 tests (+5 net new: 3 effect-text in Group D + 2 helper self-tests in Group I)
- **Tests relocated**: 4 Group E tier-mapping tests moved from `tier2_synergy_multipliers_test.gd` to `ui_framework_helpers_test.gd` Group H (no count change)
- **Regressions**: TBD on full-suite run

## Sprint 27 Definition of Done — verdict pending

- [x] M1 Synergy preview label effect text (PR #166)
- [x] /simplify+/review cleanup (PR #167)
- [ ] M2 playtest graded
- [ ] Sprint 27 retro committed

## After-Action Decision Tree

**All 5 checks PASS**: Sprint 27 succeeded. Sprint 28 picks up the deferred Sprint 27 candidates:
- Recruit pool size tuning (3 → 4 or 5)
- Per-floor matchup hint
- Hero milestone toasts
- Real product art (if workstream lands)

**Mixed PASS/PARTIAL**: Fix the failed check first; Sprint 28 candidates remain provisional.

**Multiple FAIL**: Effect text format needs revision. Candidates:
- Move effect to a second line instead of inline em-dash
- Show effect only on hover/long-press (tooltip)
- Shorter effect text (e.g., "+25% gold/bruisers" instead of "+25% gold vs bruisers")

## Compounded grading notes (playtest 16 + 17 + 18)

Given that Sprint 25 (boss floor visual, paladin, archer, lock indicator), Sprint 26 (berserker, cleric, Dispatch biome filter, tier-2 synergies), and Sprint 27 (synergy effect text) all stacked their playtest gates, a single deep playthrough can cover all three:

1. Cold launch → Dispatch shows 4 starter biomes (S26-M1)
2. Recruit pool refresh until paladin/archer/berserker/cleric appears (S25-M2-rev, S25-S2-rev, S26-M2, S26-M3)
3. Compose 3-of-a-kind formation → SynergyPreviewLabel reads "Synergy: Gold (X) — effect text" (S26-M4 + S27-M1)
4. Dispatch to F1 → see locked floors with 🔒 + tooltip (S25-N2-rev)
5. Clear F1 → F2 visible unlock + Victory Moment "Floor 2 now available." (existing)
6. Continue through F5 → boss floor darkens (S25-M3-rev)
7. Clear frostmire F5 (if reached) → ember_wastes unlocks in-session as new tab (S26-M1)

5 checks each for playtest-16, -17, -18 → 15 axes. Single playthrough covers ~12 of them naturally; the remaining 3 are edge cases (mid-pool-empty placeholder, biome unlock toast, em-dash wrapping at narrow widths).
