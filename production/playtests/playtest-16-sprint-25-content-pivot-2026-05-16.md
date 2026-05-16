# Playtest 16 — Sprint 25 content pivot (paladin + archer + boss floor visual + lock indicator)

> **Sprint Mapping**: S25-M5-rev (`production/sprints/sprint-25.md` + the §"ADDENDUM" content-pivot revision).
> **Gate**: Sprint 25 Definition of Done — "Visual playtest validates content additions read as actual player progression."
> **Status**: PENDING — graded by tester after a deeper playthrough than Sprint 24 (clear F1→F5 of forest_reach minimum).
> **Precedent**: Per-check granularity per `_template-visual-playtest.md` (S22-S1).

## Session Info

- **Date**: TBD (post-merge of PRs #152, #153, #154, #155)
- **Build**: TBD (will be the version after all S25 PRs land)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build)
- **Input Method**: Mouse
- **Session Type**: Sprint 25 content-pivot validation — does the game feel like it's progressing this sprint, after the Sprint 24 verdict of "uiux and functions are not progressing"?

## Hypothesis Under Test

Sprint 25 explicitly pivoted away from infrastructure cleanup toward player-visible content + UX polish:

- **M2-rev** (PR #152) added **paladin** as a tier-2 cozy-tank class. Class count 3 → 4.
- **M3-rev** (PR #153) made the boss floor (F5) **visually distinct** — 65% RGB intensity on the biome palette.
- **S2-rev** (PR #154) added **archer** as a tier-2 ranged-DPS class. Class count 4 → 5.
- **N2-rev** (PR #155) replaced grayed-out locked floor buttons with **🔒 + tooltip**.

Additionally, the grep audit during Sprint 25 confirmed:
- Floor Unlock System is fully implemented (already done before Sprint 25)
- 6 biomes shipped with rich data + distinct palettes (already done)
- Biome unlock chains + celebration toasts (already done)
- Diegetic onboarding per GDD #29 §A (already done)

**Question for M5-rev**: does the post-Sprint-25 playthrough feel like the game has GROWN in a way the player notices? Specifically:
1. Did paladin or archer appear in the recruit pool?
2. Did the boss floor visual register as different from F1–F4?
3. Did the 🔒 + tooltip clarify why F2–F5 weren't tappable at start?
4. After clearing forest_reach floor 1, did F2 visibly unlock?
5. (Optional, if the playthrough goes that deep) After clearing forest_reach F5, did a NEW biome chain unlock with a Guild Hall toast?

**Disconfirmation criterion**: if the playthrough feels identical to Sprint 24's session despite 4 new player-visible PRs, the content-pivot strategy is BLOCKED and Sprint 26 must escalate further (real art, equipment/items, new mechanics).

## Per-Check Validation

Fill in PASS / PARTIAL / FAIL for each. PARTIAL with notes preferred to vague PASS.

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | After refreshing the recruit pool, at least one entry is paladin OR archer (visible as a 4th/5th distinct portrait color) | TBD | Open Recruit Screen, tap Refresh until a paladin or archer entry appears. ClassPortraitFactory generates a deterministic hash-to-color portrait for each class_id. If only warrior/mage/rogue ever appears across 5+ refreshes, the new classes aren't being loaded into the recruit pool — likely a DataRegistry scan ordering issue. |
| (b) | The boss floor (F5) of forest_reach renders with a visibly darker biome background than F1–F4 | TBD | Dispatch a run to forest_reach F1: DungeonRunView shows the warm moss-green palette. Dispatch a run to forest_reach F5 (after clearing F1–F4): DungeonRunView shows the SAME palette darkened — the boss fight visually reads as "this is the big one." If F5 looks identical to F1, the new `set_biome_for_floor` wiring didn't reach the active code path. |
| (c) | Locked floors (F2–F5 at game start) show 🔒 prefix + a tooltip on long-press/hover | TBD | Open Dispatch screen with a fresh save. Floor picker should show: "F1" (tappable), "🔒 F2", "🔒 F3", "🔒 F4", "🔒 F5". Long-press or hover any locked button — tooltip reads "Clear floor N first" (e.g., for F2 the tooltip says "Clear floor 1 first"). If 🔒 is missing OR the tooltip is empty, the UX polish didn't ship correctly. |
| (d) | After clearing forest_reach F1 (WIN or LOSING), F2 visibly unlocks on the Dispatch screen and "Floor 2 now available." appears on Victory Moment | TBD | Dispatch to F1, watch the run resolve. Victory Moment screen: UnlockNoticeLabel reads "Floor 2 now available." (existing wiring, pre-Sprint-25). Tap Continue → returns to Guild Hall. Tap Dispatch → Floor picker now shows "F2" tappable (the 🔒 prefix is GONE). If F2 still shows 🔒, the `floor_unlocked` signal isn't refreshing the picker. |
| (e) | (Optional — deeper play) After clearing forest_reach F5, a NEW biome unlock toast fires on Guild Hall and that biome appears as a NEW tab on the Dispatch floor picker | TBD | Clear forest_reach floors 1–5 in sequence. After F5 (boss), Victory Moment shows "Forest Reach completed!" (existing wiring). Return to Guild Hall: a toast reads "Unlocked: [biome name]" — the chained biome (per Biome.unlock_after data). Dispatch screen: the new biome appears as a 2nd biome tab with all its floors. If no toast OR no new tab, the chain didn't fire end-to-end. |

**Per-check protocol**: each row is PASS / PARTIAL / FAIL. A PARTIAL with notes is preferable to a meta-PASS that hides specific gaps. Aggregate verdict at the bottom is advisory only — the rows are the load-bearing data.

## Findings (to fill in)

**Tester report (TBD)**: TBD

## Test Suite Impact

- **Before Sprint 25**: ~2270 tests
- **After Sprint 25**: ~2293 tests (+23: paladin 9, archer 9, boss floor 7, floor lock 3 — exact final count depends on test infrastructure resolving correctly across all 4 PRs)
- **Regressions**: TBD on full-suite run

## Sprint 25 Definition of Done — verdict pending

- [x] M2-rev paladin (PR #152) shipped
- [x] M3-rev boss floor visual (PR #153) shipped
- [x] S2-rev archer (PR #154) shipped
- [x] N2-rev floor lock indicator (PR #155) shipped
- [ ] M5-rev playtest graded across all 5 checks (this doc)
- [ ] Sprint 25 retro committed (`production/retrospectives/sprint-25-retrospective-*.md`)

## After-Action Decision Tree

**If all 5 checks PASS or PARTIAL**: Sprint 25 closes successfully. Strategic verdict = content-pivot worked; Sprint 26 continues the content-first cadence (next candidates: real art ingestion, equipment/items system, more classes, new mechanics).

**If 1–2 checks FAIL**: Sprint 25 closes with carryforward stories specifically targeting the failed checks. Sprint 26 starts with those carries as Must Have.

**If 3+ checks FAIL OR the tester's overall verdict is "still not progressing"**: the content-pivot strategy is insufficient. Sprint 26 should escalate to:
- Real product art ingestion (replacing all programmatic placeholders)
- Equipment/items system (new mechanic layer)
- Live progression depth (prestige integration with content; sub-floor variant rooms)

This decision tree should be the basis for the Sprint 26 Day-0 plan.
