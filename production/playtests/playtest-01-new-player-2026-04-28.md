# Playtest 01 — New Player Experience (S8-M5)

> **Sprint Mapping**: S8-M5 (sprint-8.md "Playtest session #1 — new player experience")
> **AC**: identify whether "core fantasy" matches hero-roster GDD Player Fantasy section; ≥1 unprompted statement of player intent captured
> **Status**: Complete

## Session Info

- **Date**: 2026-04-28
- **Build**: post-S8-M4 hotfix bundle (5 fixes landed; full VS loop verified end-to-end)
  - Branch: main
- **Duration**: ~30 minutes including diagnostic iterations
- **Tester**: Project lead (solo mode per sprint-8.md "Solo mode allows the project lead to be the tester for all 3")
- **Platform**: macOS (Apple M2 Max, Godot 4.6.1.stable.mono)
- **Input Method**: Mouse (Pillar 1: tap/click primary)
- **Session Type**: First-time / new player simulation

## Test Focus

**Hypothesis under test**: a new player who has never seen the build can boot the game, understand what to do, dispatch a formation, watch a run, and return to the main menu without external guidance — and feel something resembling the **hero-roster GDD's Player Fantasy** of running a small guild of named heroes.

## First Impressions (First 5 minutes)

- **Understood the goal?** Partially — Guild Hall placeholder gave no orientation; only the "Go to Dispatch" button surfaced what to do next (and that button label was added as an S8-M4 hotfix, not original Sprint 8 spec).
- **Understood the controls?** Yes — single mouse-click everywhere. No keyboard nav, no gamepad. Pillar 1 input model is intact.
- **Emotional response**: Confused → engaged → confused again. Boot landing on a placeholder with one button felt sparse. Reaching formation_assignment, the tester didn't know what to tap first.
- **Time-to-first-dispatch**: ~3-5 seconds (after explanation; without explanation, tester paused at formation_assignment uncertain what to do)
- **Notes**: Locale keys ("formation_assignment_title", "tick_label_prefix", "run_complete_kill_count_format 3") visible throughout — cosmetic, expected per Sprint 8 minimum-stub UIFramework, but does not help orientation.

## Core Fantasy Match — vs hero-roster GDD §Player Fantasy

**GDD-stated core fantasy** (paraphrased): The player runs a small guild of named heroes. They make decisions about who to send, where to send them. They feel like a guildmaster.

**Did the build evoke this?**
- [x] Theron has a name ("Theron (warrior Lv1)" appears in roster — first-launch seed worked after S8-M4 hotfix #3)
- [x] Player makes a decision (tapped slot, tapped hero, tapped Dispatch)
- [~] Player watches the run play out — **but the run is so fast (sometimes <1s) that "watching" doesn't happen**
- [~] Player gets a sense of "I sent Theron and he came back with 3 kills" — kill_count=3 is communicated via run-end overlay, but the dwell is 0ms (auto-route fires immediately) so the moment isn't perceived
- [x] Player feels delegation/agency rather than direct action (combat is automated; tester didn't try to control combat)

**Verdict on core fantasy match**: **Partial Match**.

The structural pieces are present (named hero, slot assignment, dispatch decision, automated combat, return to base). What's missing for full match:
- A felt moment of "the run is happening" — current pacing is too fast to register
- A felt moment of "Theron came back" — run-end overlay flashes by in 0ms dwell
- Decision context — the tester didn't know which floor existed or what would happen

Pillar 2 ("Decisions Matter") is the primary gap. Without explanatory copy on formation_assignment and without a perceptible run, decisions are made blindly and produce results faster than the player can connect cause and effect.

## ≥1 Unprompted Player Intent Statement (AC-required)

> Verbatim quotes captured during the session, before any specific UX questioning.

1. _"actually, not sure what will happen in this scene"_ — context: tester arrived at formation_assignment after tapping "Go to Dispatch" from Guild Hall. Theron was pre-seeded in slot 0. Floor button shows hardcoded "Forest Reach — Floor 1". No tooltip, hint, or instruction text on screen. Tester unsure whether to tap Dispatch or assign more heroes or do something else first. **Pillar 2 hit: missing intent surface, no expected-outcome signaling, no empty-slot affordance.**

2. _"nothing happens when i click on the slot_empty_label"_ — context: tester tapped an empty slot button expecting feedback. The tap DID set `_active_slot_index` (so a subsequent hero tap would assign), but no visual state surfaced (no highlight, no border, no "Selected" indicator). The action was successful at the data layer but invisible at the UX layer. **Pillar 2 hit: decision affordance hidden. Severity: High for VS playable target.**

3. _"i don't get what is 'Forest Reach - Floor 1' for?"_ — context: tester saw a button labeled with a location name with no surrounding context. No "Send to:" prefix, no enemy preview card, no difficulty indicator, no rewards. Sprint 8 hardcoded single-floor scope is intentional, but the LABEL ALONE doesn't communicate "this is your dispatch destination." **Pillar 2 hit: decision target unclear. Severity: Medium.**

4. _"it go to next scene but almost immediately go back to the main scene"_ — context: tester tapped Dispatch from formation_assignment with Theron in slot 0. FADE_TO_BLACK fired (300ms). The run resolved within or just after the fade — total perceived run duration ≤500ms. Tester saw dungeon_run_view briefly through the fade-out, then was already cross-fading to main_menu. **Pillar 1 + Pillar 2 + Pillar 3 hit: no moment to watch the run. The "I sent Theron to fight" beat is missing. Severity: HIGH for VS feel.**

## Gameplay Flow

### What worked well
- Boot to first screen → "Go to Dispatch" → formation_assignment chain works
- Theron seed fired (after S8-M4 hotfix #3 wired the call_deferred trigger)
- Layout — buttons aren't clipped (after S8-M4 hotfix #1)
- Click events reach Buttons (after S8-M4 hotfix #2 fixed the Fade ColorRect mouse_filter)
- Auto-route closes the loop at the kernel level (Story 013 + S8-M4 hotfix #5 deferred-route works)
- Loop is repeatable: from main_menu, "Go to Dispatch" returns to formation_assignment with state preserved

### Pain points
- **Run pacing too fast** (sub-second runs in some dispatches) — Severity: HIGH
- **No visual feedback on slot tap** (active_slot_index invisible) — Severity: HIGH
- **No instructional copy** on formation_assignment — Severity: HIGH
- **Locale keys visible everywhere** (no CSV authored) — Severity: Medium-cosmetic
- **Run-end overlay 0ms dwell** — overlay flashes, no moment of "Run Complete" to feel — Severity: Medium

### Confusion points
- formation_assignment screen on first arrival: tester didn't know what to do
- Floor button: tester didn't understand its role
- After Dispatch: tester didn't see the run, just landed back at main_menu

### Moments of delight
- The auto-route worked once we landed on it — going back to main_menu felt like the loop closed properly (not a "stuck" feeling)
- Theron's name appearing in the roster felt *more meaningful* than just "Hero 1" or generic — small but real
- The cross-fade transitions (when they fired with proper timing, ~150ms) felt smooth (Pillar 4 timing budget honored)

## Bugs Encountered

> Pre-known cosmetic issues (do NOT log as new bugs — already on Sprint 9 backlog):
> - All UI strings show as locale keys ("formation_assignment_title", "tick_label_prefix 141", "run_complete_kill_count_format 3")
> - Default Godot text colors / panel backgrounds (no parchment theme content authored)

| # | Description | Severity | Reproducible |
|---|-------------|----------|--------------|
| - | None new — 5 hotfixes in S8-M4 already addressed the bugs surfaced this session | - | - |

## Feature-Specific Feedback

### Hero Picker (formation_assignment Roster panel)
- **Understood purpose?** Yes (after explanation)
- **Found engaging?** Neutral — only one hero, so picker felt empty
- **Notes**: Single hero means picker has no real "picking" feel. Sprint 9+ Recruit flow needed for real evaluation.

### Slot Assignment (formation_assignment Slots panel)
- **Understood that taps assign hero to slot?** No — tester explicitly stated "nothing happens when I click slot_empty_label"
- **Did the auto-clear-prior-slot behavior surprise or confuse?** Not tested in this session — tester didn't reach the move-hero-between-slots state because they couldn't tell tapping a slot did anything.
- **Notes**: **HIGHEST-VALUE finding from this playtest.** Slot tap has no visual feedback. Sprint 9 polish: add active-slot border / highlight / "Selected" indicator.

### Floor Selector (formation_assignment, single button "Forest Reach — Floor 1")
- **Did tester understand they could only pick one floor?** No — tester didn't realize it was a button or that multiple floors exist conceptually.
- **Did the single-floor-only feel limiting or appropriate for first run?** Couldn't evaluate — purpose was unclear.
- **Notes**: Sprint 9 polish: add explanatory header ("Send to:" or "Destination:"), add floor info card.

### Dispatch Button + Live Run (DungeonRunView)
- **Understood "Dispatch" sends the formation?** Yes (after explanation)
- **Watched the tick + kill counter?** No — runs were too fast (most under 1 second)
- **Felt rewarding to see kill_count tick up?** No — couldn't see ticks counting up
- **Run length felt**: Too short
- **Notes**: This is the **second-highest-value finding**. Combat resolution produces unwatchable runs. Need either combat-tick budget tuning OR a minimum-perceived-run-duration overlay (Sprint 9 polish).

### Run-end Overlay → Auto-route
- **Saw the "Run Complete — N kills" overlay?** Yes — but only briefly
- **Understood the run ended?** Partially — the overlay flashed too fast to register the kill_count
- **Did the auto-route to MainMenu feel natural?** Abrupt — "almost immediately go back to the main scene"
- **Notes**: Sprint 9 polish: bump `RUN_END_DWELL_MS` from 0 to 1500-2000 ms, OR add an explicit "Continue" button on the run-end overlay (Story 012/013 spec allows it).

## Quantitative Data

- **Boot-to-first-dispatch**: ~10 seconds (cold launch + Guild Hall + nav)
- **Run duration (tick-count at RUN_ENDED)**: 141, 338, ~10 (3 dispatches observed; ranges 0.5s–17s wall-clock at 20Hz)
- **Final kill_count**: 3 in all observed runs (deterministic-feeling outcome despite RNG)
- **Cycles completed**: 3+ full Guild Hall → Run → Main Menu loops
- **Features discovered**: Hero picker, slot system (after explanation), floor button (purpose missed), Dispatch button, run view, run-end overlay, main_menu return
- **Features missed**: Recruit flow (not present in build), per-hero detail (not present), formation strength/preview (not present)

## Overall Assessment

- **Would play again?** [Subjective — tester to fill in: Yes / No / Maybe]
- **Difficulty**: N/A — combat is automated; outcome was always 3 kills with this formation
- **Pacing**: Too Fast (severe)
- **Session length preference**: [Subjective — N/A for kernel-level VS smoke; meaningful with real content]

## Pillar Alignment Check

> Per `design/gdd/game-concept.md`, score each pillar 1-5 (subjective; tester to refine):

| Pillar | Description | Score (1-5) | Notes |
|---|---|---|---|
| 1 | Respect the Player's Time | 2/5 | Boot fast (good), but sub-second runs disrespect the player's attention in the OPPOSITE direction. The "I'm doing something" beat is missing. |
| 2 | Decisions Matter | 1/5 | Decisions made blindly (no context), invisibly (no slot affordance), and produce outcomes faster than perception. The 3 unprompted intent statements above are all Pillar 2 hits. |
| 3 | Cozy / No-Fail | 3/5 | No-fail is honored (no death screen, no penalty). Cozy is undermined by jittery pacing. |
| 4 | (4th pillar from concept doc) | -/5 | Tester to fill in based on game-concept.md |

## Top 3 Priorities from this session

1. **Slot affordance + formation_assignment instructional copy** — single highest-impact polish item. Sprint 9 ticket: add active-slot visual state, add header copy explaining the screen, add a floor-context card.
2. **Run pacing — minimum perceived duration** — sub-second runs make the core loop unwatchable. Sprint 9 ticket: either tune combat tick budget upward OR add a minimum 2-3s run-view dwell with kill_count animating up to final value, OR bump `RUN_END_DWELL_MS` to 1500-2000 ms.
3. **Locale CSV authoring** — locale keys visible everywhere is a cosmetic blocker for any felt-experience playtest. Sprint 9 ticket: author EN locale CSV with the ~12 keys used by Stories 011/012.

---

## Verdict

- [x] **AC-1 satisfied**: core fantasy MATCH = **Partial**. Structural pieces present; pacing + decision context gaps prevent full match. Documented above with rationale.
- [x] **AC-2 satisfied**: ≥1 unprompted player intent statement captured = **YES, 4 captured**.

**Overall**: **PASS WITH NOTES** — playtest produced exactly the kind of high-signal findings S8-M5 was designed for. Sprint 8 VS contract was "kernel works + ugly UI accepted + 3 playtests document gaps". This session documents 3+ high-priority Sprint 9 polish items that, when addressed, transition the build from "kernel proof" to "playable VS that feels like the game."

**Next**: continue to S8-M6 (mid-game pacing) using `production/playtests/playtest-02-mid-game-2026-04-28.md`. Then S8-M7 (offline + return-to-app) using `playtest-03-offline-return-2026-04-28.md`. Then S8-M8 `/gate-check production`.
