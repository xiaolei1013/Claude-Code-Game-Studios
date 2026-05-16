# Unified Playtest Protocol — Playtests 16 + 17 + 18 (Sprints 25-27 compounded)

> **Purpose**: collapse the 3-sprint, 15-axis playtest backlog into a single deep playthrough. Grading the 3 fragmented templates separately would require 3 separate sessions; this unified protocol traces a single play journey that touches all 15 axes naturally.
>
> **Status**: SESSION PROTOCOL — not a separate sprint deliverable. The 3 individual playtest docs (playtest-16, -17, -18) remain canonical; this is a *guide* for running them as one session. Mark each axis on its source doc after this protocol completes.
>
> **Estimated time**: 25-40 min (vs ~60 min if run separately as 3 sessions).

## Pre-session setup

1. Pull latest main: `git pull origin main`
2. Confirm VERSION: `cat VERSION` → should read `0.0.0.74`
3. Open the project in Godot 4.6 editor; let UID cache rebuild on first scan (the "Unrecognized UID" warnings clear once `.godot/uid_cache.bin` regenerates)
4. **Optional**: delete `user://save_*.dat` to force a fresh-save session if you want to exercise the cold-launch axes
5. Launch the game (F5 or run main scene)

## Session journey (one continuous playthrough)

### Phase 1 — Cold launch (covers playtest-17 axes b, c partially)

1. **Observe Guild Hall on cold launch**
   - Theron is seeded (1 hero in roster)
   - Gold counter at 100 (starting amount)
   - Dispatch button is the only enabled CTA
2. **Tap Dispatch → Open the floor picker**
   - ✅ **playtest-17 axis (b)**: Confirm 4 starter biome tabs visible (forest_reach, frostmire, sunken_ruins, whispering_crags). NOT 6 (no ember_wastes or hollow_stair).
   - ✅ **playtest-16 axis (c)**: Confirm F1 is `F1` (no 🔒 prefix); F2-F5 are `🔒 F2` through `🔒 F5` with tooltip on hover/long-press reading "Clear floor 1 first" / "Clear floor 4 first" etc.

### Phase 2 — First dispatch (covers playtest-16 axis d)

3. **Select forest_reach F1, deploy Theron + 0 + 0** (single-hero formation; doesn't matter for this axis)
4. **Watch the run resolve** (~5-10 seconds)
5. **Victory Moment screen**
   - ✅ **playtest-16 axis (d)**: Confirm "Floor 2 now available." callout on `UnlockNoticeLabel`. Floor 1 cleared = F2 unlocks visibly.
6. **Continue → return to Guild Hall**

### Phase 3 — Recruit pool refresh (covers playtest-16 axis a + playtest-17 axis a)

7. **Open Recruit Screen**
8. **Tap Refresh button 5-10 times**, noting which classes appear:
   - Track 7 candidate classes: warrior, mage, rogue, paladin, archer, berserker, cleric
   - ✅ **playtest-16 axis (a)**: Confirm paladin OR archer appears at least once across the refreshes
   - ✅ **playtest-17 axis (a)**: Confirm berserker OR cleric appears at least once across the refreshes (note: with 7 classes × 3 picks, probability of seeing a specific one in 5 refreshes is ~95%)
9. **Recruit a paladin if one appears** (or any tier-2 class — needed for Phase 4)
10. **Recruit 2 more of the SAME class** (refresh + recruit, refresh + recruit) until you have 3 of one tier-2 class

### Phase 4 — Tier-2 synergy fire (covers playtest-17 axes d, e + all playtest-18 axes)

11. **Open Dispatch**
12. **Slot all 3 tier-2 heroes into formation slots 0, 1, 2**
13. **Watch the SynergyPreviewLabel above the slots**
    - ✅ **playtest-17 axis (d)**: Confirm label reads "Synergy: Gold (X)" where X is the matching synergy name (Bastion for paladins, Volley for archers, Frenzy for berserkers, Vigil for clerics)
    - ✅ **playtest-18 axis (a/b/c)**: Confirm label format includes em-dash + effect text. Examples:
      - 3 paladins → "Synergy: Gold (Bastion) — +25% gold vs casters"
      - 3 archers → "Synergy: Gold (Volley) — +25% gold vs swarm"
      - 3 berserkers → "Synergy: Gold (Frenzy) — +25% gold vs bruisers"
      - 3 clerics → "Synergy: Gold (Vigil) — +20% XP from all kills"
    - ✅ **playtest-18 axis (e)**: While viewing the label, narrow the window (if testing on desktop) or rotate to portrait (Steam Deck) and confirm the em-dash separator doesn't break wrapping awkwardly.
14. **Select forest_reach F2** (now unlocked from Phase 2)
15. **Dispatch the synergy formation**
16. **Watch the run; observe gold/XP accumulation**
    - ✅ **playtest-17 axis (e)**: Compare the gold (or XP for Vigil) gain on Victory Moment against the baseline you'd expect. With the conditional bonus active, kills against the matching archetype should produce ~25% more gold (or 20% more XP for Vigil). NOTE: this is a feel-based comparison — exact arithmetic would require pre/post baseline data. Mark PASS if the player visibly perceives "this run earned more" vs the synergy-free Phase 2 run.
17. **Empty one slot to break the synergy**
    - ✅ **playtest-18 axis (d) negative-space check**: Confirm the label collapses to "Synergy: None" — NO em-dash, NO effect text. The em-dash should be absent in the no-synergy state.

### Phase 5 — Boss floor visual (covers playtest-16 axis b)

18. **Clear forest_reach floors 2 → 5 in sequence** (or skip ahead if you've already played far enough; the visual axis only matters on the F5 dispatch)
19. **On the F5 dispatch (boss floor), watch the DungeonRunView background**
    - ✅ **playtest-16 axis (b)**: Confirm the biome palette renders visibly DARKER than F1-F4 baseline. Forest Reach's moss-green should shift to a dusk/night register. The boss fight should feel like a culmination.

### Phase 6 — Biome chain unlock (covers playtest-16 axis e + playtest-17 axis c remainder)

20. **If forest_reach F5 cleared (you reached the boss above)**, return to Guild Hall.
21. **Watch for the biome unlock toast** when the chain fires (after frostmire F5, the toast shows "Unlocked: Ember Wastes" — but forest_reach F5 doesn't chain in current data; check the unlock_after fields):
    - frostmire F5 → unlocks ember_wastes (gated)
    - ember_wastes F5 → unlocks hollow_stair (gated)
    - forest_reach + sunken_ruins + whispering_crags are starter biomes (no chain dependency)
    - ✅ **playtest-16 axis (e)**: If you cleared a chain-trigger biome's F5, confirm the "Unlocked: [X]" toast appeared on Guild Hall.
22. **Open Dispatch screen**
    - ✅ **playtest-17 axis (c)**: Confirm the newly-unlocked biome appears as a new tab. If you were ON the Dispatch screen when the chain fired, the new tab should appear IN-SESSION (via the `biome_unlocked` signal handler). Otherwise, it appears on next Dispatch open.

## Result tabulation

After the playthrough, fill in the 5 axes on each of:
- `production/playtests/playtest-16-sprint-25-content-pivot-2026-05-16.md`
- `production/playtests/playtest-17-sprint-26-content-pivot-2026-05-16.md`
- `production/playtests/playtest-18-sprint-27-synergy-effect-text-2026-05-16.md`

PASS / PARTIAL / FAIL per axis. Add notes for any PARTIAL or FAIL.

## Retro flip protocol

After all 15 axes graded:

1. **Update each retro's "Sprint Goal — Final Disposition" section**:
   - `production/retrospectives/sprint-25-retrospective-2026-05-16.md`
   - `production/retrospectives/sprint-26-retrospective-2026-05-16.md`
   - `production/retrospectives/sprint-27-retrospective-2026-05-16.md`
2. **Flip status from DRAFT to COMMITTED** in each retro's header
3. **Update sprint-status.yaml**: M5 (Sprint 25) / M5 (Sprint 26) / M2 (Sprint 27) → status: done
4. **Decide Sprint 28 direction** based on aggregated verdict:
   - 13-15/15 PASS → Sprint 28 picks up the deferred Sprint 27 recommendations (recruit pool tuning, per-floor matchup hint, real art)
   - 8-12/15 PASS → Sprint 28 addresses the specific FAIL axes first
   - <8/15 PASS → Escalate; the content pivot needs reassessment

## After-action decision tree summary

The 3 individual playtest docs each have their own After-Action Decision Tree. The unified verdict is the BITWISE-AND of all three — Sprint 28 direction is the most conservative of the three decision branches.

## Why this protocol exists

The Sprint 27 retro committed a new process rule: "cap playtest backlog at 1 sprint." With 3 sprints worth of playtest pending grading, that rule is currently violated. This protocol is the bridge — it converts the 3-sprint backlog into a single graded session, restoring compliance and unblocking Sprint 28 planning.

After this session completes, the Sprint 28 plan should explicitly bundle Day-0 PR + first content PR (per Sprint 27 retro rule #6) AND defer new content until the playtest from Sprint 28 lands (per rule #7).
