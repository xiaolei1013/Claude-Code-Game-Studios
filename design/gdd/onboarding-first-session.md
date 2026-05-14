# Onboarding / First-Session Flow — GDD #29

> **Status: First-pass DRAFT 2026-05-06** by autonomous-execution session. All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. Run `/design-review` before APPROVED. Specifies the **5-minute first-session experience** referenced in `game-concept.md` §Flow State Design.

---

## A. Overview

**Onboarding** is the first-session player journey from "tap the icon" to "see the first offline reward notification". MVP target per `game-concept.md` §Onboarding curve: **5 minutes**. The experience is **strictly diegetic** — no tutorial overlays, no "click here" arrows, no skippable splash text. The UI's affordances (parchment theme + tap-targets + the seeded Theron warrior) carry the player through the loop.

The flow:
1. **Cold launch** → main_menu (or guild_hall on first launch with seeded Theron).
2. **Recruit-already-handled**: `HeroRoster.seed_first_launch_state()` (S8-S? era) seeded Theron at instance_id=1, level=1. Player has 1 hero before they touch anything.
3. **First dispatch**: tap "Dispatch" → formation_assignment screen → assign Theron → tap floor 1 → run resolves in ~5–10 seconds → victory_moment.
4. **First reward**: gold, level-up if XP threshold crossed (per Hero Leveling GDD #15).
5. **First offline reward** (post-MVP-but-spec-here): close the app for 5+ minutes → reopen → Return-to-App Screen renders the cozy summary.

The first-session bar is simply: **the player can complete this loop without typed instructions, without mode confusion, and without dead-ends**. The Pillar 2 playtest score (per playtest-04 / S9-M5 gate-check) is the canonical measurement.

---

## B. Player Fantasy

> *"I open the game. There's a warrior. There's a dungeon. I tap, things happen, and 30 seconds later I'm seeing gold pour in. I close the game and forget about it. When I come back, my warriors leveled up while I was away."*

The cozy register sets the onboarding bar: a player should never feel they're being lectured to OR being asked to remember a rule. Every UI element teaches its own affordance — the gold counter is a number that goes up, the dispatch button is a button that obviously dispatches. The only "tutorial" is the seeded Theron + floor-1-only initial state — the player has fewer choices because the game has already pruned the choices they don't need yet.

Critical: **the first session must end with the player closing the game on their own terms**, not because they got confused or stuck. Per Pillar 1 (No-Fail-State, game-concept.md), there is no failure path — a "loss" returns partial gold + a hint, then routes back to formation_assignment. The player can re-dispatch immediately.

---

## C. Detailed Rules

### C.1 Cold-launch detection

`SaveLoadSystem.request_full_load` reports either:
- **First-launch**: no save file exists → emit `load_completed("first_launch")` per S11-M4 contract. Triggers seed pathway.
- **Returning-launch**: save file exists → load consumers, then route to main_menu OR (if offline_elapsed_seconds > 0) trigger Return-to-App per S13-M2.

First-launch routing:
1. `HeroRoster.seed_first_launch_state()` runs synchronously in the load handler. Seeds Theron (warrior, instance_id=1, current_level=1, xp=0).
2. `Economy._gold_balance` initializes to STARTING_GOLD (default 100 — tunable).
3. `FloorUnlock` initializes with floor 1 of the starter biome (forest_reach) unlocked; floors 2–5 LOCKED.
4. `Recruitment` initializes with a fresh `_save_pool_seed = randi()` (deterministic per ADR-0015) and generates the initial pool.
5. `SceneManager.request_screen("guild_hall")` — first screen the player sees.

### C.2 Seeded starter content

Theron is the **canonical starter hero** per `hero-roster.md` Story 011 / TR-021. Hardcoded warrior, deterministic across reinstalls, single hero. Seed cannot be re-run on a non-empty roster (idempotency-blocked per `seed_first_launch_state`'s push_warning).

The initial recruit pool is a 5-entry pool of mixed Tier 1 classes (warrior, mage if unlocked at character-level-0). Initially the player can only afford a warrior (cost 150 vs. 100 gold) — they CANNOT recruit until they earn gold from a dispatch. This is intentional: forces the first-dispatch action.

### C.3 Guild Hall first-render

On first-launch arrival at guild_hall:
- **Roster panel**: shows Theron (single hero card, level 1).
- **Gold counter**: 100 (starting amount).
- **Dispatch button**: enabled (Theron is in formation_slot 0 by default per HeroRoster initial state).
- **Recruit button**: dimmed/grayed (insufficient gold; tooltip "Need 50 more gold").
- **Settings gear icon**: visible top-right; functional.

There is NO "Welcome!" toast. NO "Tap Dispatch to begin" arrow. The Dispatch button is the only enabled actionable element + its own label tells the player what it does.

### C.4 First-dispatch flow

Tap Dispatch → `SceneManager.request_screen("formation_assignment", FADE_TO_BLACK)`:
- formation_assignment shows Theron in slot 0; slots 1 + 2 empty.
- Floor selector shows floor 1 (forest_reach) unlocked + floors 2–5 grayed.
- "Dispatch" button at bottom — enabled (Theron's there).

Tap floor 1 → tap Dispatch → `SceneManager.request_screen("dungeon_run_view", FADE_TO_BLACK)`:
- Run resolves over ~5–10 seconds (real time, gated by RUN_END_DWELL_MS + tick budget).
- Kill counter ticks up in real time.
- On floor clear: gold credit (~30–50), XP grant (per Hero Leveling §C.1), `floor_cleared_first_time` signal, victory_moment.

### C.5 First level-up moment

Per Hero Leveling §C.3: level 1 → 2 needs 150 XP. A typical floor-1 run grants ~30 kills × 5 XP = 150 XP + 50 floor-clear XP = 200 XP. Theron cleanly clears the level-1 threshold on the first dispatch.

The level-up toast (S10-M4) + chime (S12-M6 AC-AS-05) fire together. This is the **canonical felt-progression moment** per the cozy register: the first time the player sees their action produce a hero gaining a level. Pillar 2 playtest evidence shows this moment is the key driver of "I want to keep playing".

### C.6 First offline reward (return-to-app)

After the first dispatch + level-up, the player typically closes the app within ~3 minutes (per the 5-min onboarding curve). On reopen:
- If `offline_elapsed_seconds > 0`: `OfflineProgressionEngine` runs replay (per S12-M5). Per S13-M2 + ADR-0014, replay produces a summary; `_last_summary` is cached; `SceneManager.request_screen("return_to_app", SLIDE_DOWN)` fires.
- The Return-to-App Screen renders gold + kills + floor clears + hero levels gained.
- "Continue" button → request_screen("guild_hall").

This closes the loop: the player has now seen the **full MVP cycle** — recruit (seeded) → dispatch → reward → offline progress → continue.

### C.7 Failure/dead-end recovery

If the player's first dispatch loses (Theron dies before clearing floor 1 — possible if matchup is unfavorable, per ADR-0002 LOSING-then-WIN reclaim contract):
- victory_moment shows partial reward (halved gold per LOSING-bonus formula).
- "Try Again" button routes to formation_assignment.
- No "you lost" framing — the run "ended"; the player has gold + can dispatch again.

If the player lingers on guild_hall without dispatching for >2 minutes:
- No tutorial nag toast. The cozy register accepts player pacing.

If the player closes the app on guild_hall before dispatching:
- TickSystem records the timestamp. On reopen, no offline replay (zero kills, zero gold drip — drip only accrues during ACTIVE runs per Economy §D.1). guild_hall re-renders identically.

### C.8 Gating

The Settings gear icon is gated on `OfflineProgressionEngine.is_replay_in_flight()` per Settings GDD #30 §E.6. During the first cold-launch, no replay is in flight (no save), so the gear icon is enabled. If a player closes the app mid-run (during their second session+) and reopens during a replay, the gear icon is dimmed until replay completes.

---

## D. Formulas

### D.1 Starting gold
`STARTING_GOLD = 100` (tunable in EconomyConfig). Set just below recruit cost (150) so the player MUST dispatch to earn the recruit gap.

### D.2 First-run reward target
Floor-1 forest_reach mid-tier opponents:
- Expected kill count: 30 ± 10 (per combat-resolution.md formation_strength × DPS curves)
- Expected gold: 30 × BASE_KILL[1] (10) × MATCHUP_MULTIPLIER (~1.0 average) = ~300 gold
- Expected XP: 30 × XP_PER_KILL[1] (5) + 50 floor-clear = 200 XP per hero in formation

Post-first-run gold: 100 + 300 = 400. Player can now afford 1× warrior recruit (150) + ~1.5× refresh-pool (100). The recruitment gating opens up after one dispatch.

### D.3 First-cycle pacing
- Cold-launch → guild_hall first-render: < 1 second (per Pillar 5 boot budget)
- Guild_hall → dispatch tap: depends on player; expected ~5–30 seconds
- formation_assignment → dispatch tap: ~5–15 seconds
- dungeon_run_view → victory_moment: 5–10 seconds (run_end_dwell + transitions)
- victory_moment → guild_hall: ~1 second (CROSS_FADE)
- guild_hall second-render → close-app: variable

Total first-cycle target: under 5 minutes wall-clock per game-concept.md §Onboarding curve.

---

## E. Edge Cases

### E.1 First-launch save corruption
If `SaveLoadSystem` detects a corrupted save during what looks like a returning-launch (header MAGIC mismatch / HMAC fail), per ADR-0004 + corrupt_both_acknowledged signal, the player is shown a "save lost" reset modal. After acknowledgment, treat as first-launch (run seed pathway). Onboarding flow proceeds identically.

### E.2 First-launch with no audio device
Per audio-system.md §E.1 + AudioRouter._headless_mode, audio is silent but routing is wired. The level-up TOAST still fires (visual feedback). The player completes the loop without audio confirmation. Cozy register tolerates this — the onboarding bar is visual-first.

### E.3 First-launch with reduce_motion=true
If the player toggled reduce_motion=true in a prior session AND save was corrupted (so we're in the first-launch path), the user://settings.cfg may still hold `reduce_motion=true`. Per S12-S2: SceneManager loads the flag at boot independent of the save state. First-launch transitions are clamped to 50ms. The flow completes faster but identically. No special handling needed.

### E.4 First-launch interrupted at any step
If the player closes the app between cold-launch and dispatch (e.g., quits at guild_hall), the seeded state is now persisted via the next save trigger (S11-M2b heartbeat). On reopen: returning-launch path runs; no seed re-run (idempotency); guild_hall renders with Theron + 100 gold.

### E.5 First-launch with localization to non-English
MVP ships English-only. Locale dropdown (Settings GDD #30 §C.5) is disabled if only "en" is loaded. First-launch flow assumes "en" — all `tr()` strings render in English. If V1.0 rollout adds a locale, the cold-launch detection of locale preference (browser locale on web build, OS locale on mobile) is OQ-29-3.

### E.6 First-launch with extremely low memory / slow disk
DataRegistry boot scan + autoload chain takes a few hundred ms; on min-spec hardware (Steam Deck OLED, 4GB RAM), this can stretch to 1–2 seconds. The first guild_hall render may show empty panels for ~500ms while the autoloads finish. Mitigation: a loading splash with the parchment color (~50ms) covering the boot gap. NOT in MVP scope; Sprint 15+ if playtest reveals the cold-launch flash.

### E.7 First dispatch that immediately ends in RUN_ENDED via the buffered-replay path
Story 013 (S13-S1) fixed the case where combat resolves DURING the FADE_TO_BLACK transition into dungeon_run_view. First-dispatch on a low-HP starter Theron against a high-DPS floor-1 enemy could produce a sub-300ms run (combat resolves before the 300ms fade completes). The buffered-replay handles it; the player sees dungeon_run_view briefly then victory_moment. No special onboarding handling needed.

### E.8 Multiple rapid dispatches
After the first floor-1 clear, the player taps Dispatch immediately again. dungeon_run_view is now showing victory_moment. They want to re-dispatch. Per S10-N2 (deferred re-dispatch shortcut), there's currently NO shortcut — they must navigate guild_hall → formation_assignment → tap floor → tap Dispatch. This is fine for first-session pacing; S10-N2 (Sprint 14 N2 candidate) addresses the streamlining.

### E.9 First-launch with `seed_first_launch_state` failing
If DataRegistry fails to resolve "warrior" class_id (content corruption or test-env without DataRegistry seeding), `seed_first_launch_state` push_warns and seeds Theron as a placeholder hero with class_id="warrior" (resolved at runtime as a "Hero 1" fallback per `_generate_name`). The flow continues; Theron renders + dispatches; combat may show degraded behavior but doesn't crash.

### E.10 Player uninstalls and reinstalls
On reinstall, `user://` is wiped per platform conventions. First-launch path runs identically to a never-played install. No "welcome back" treatment. (V1.0+ may add reinstall detection via a server-side player ID, but MVP is local-only.)

---

## F. Dependencies

### Hard dependencies (Onboarding requires these to function)

| System | Why | Surface used |
|---|---|---|
| `SaveLoadSystem` (#3) | Detect first-launch vs. returning | `request_full_load`, `load_completed` signal with reason="first_launch" |
| `HeroRoster` (#9) | Seed Theron | `seed_first_launch_state` |
| `Economy` (#5) | Initialize gold | `_gold_balance` initial value (STARTING_GOLD) |
| `FloorUnlock` (#16) | Unlock floor 1 of starter biome | `set_floor_unlocked(forest_reach, 1)` |
| `Recruitment` (#14) | Initialize recruit pool seed | `_save_pool_seed = randi()` |
| `SceneManager` (#4) | Route to guild_hall | `request_screen("guild_hall")` |
| `HeroLeveling` (#15) | First level-up moment per §C.5 | `enemy_killed` + `floor_cleared_first_time` signal subscribers |
| `OfflineProgressionEngine` (#12) | First offline reward per §C.6 | `offline_rewards_collected` signal subscriber |

### Reverse dependencies

- **Game launcher / Main scene** (production wiring) — first-launch detection is the launcher's first-frame logic.

---

## G. Tuning Knobs

### STARTING_GOLD (int = 100)
- Range: 0–500. Below 0 invalid. Above 200 makes the player skip the first-dispatch-required moment (they can recruit immediately).

### Theron starter class
- Currently hardcoded "warrior" per `seed_first_launch_state` line 376. NOT a knob — TR-021 requires the deterministic-across-reinstalls invariant. If this becomes tunable, treat as a separate epic.

### Tutorial dungeon floor
- Hardcoded floor 1 of forest_reach (per game-concept.md §Tutorial). NOT a knob.

### First-cycle target time
- 5 minutes per game-concept.md §Onboarding curve. NOT a runtime knob — playtest measurement target.

---

## H. Acceptance Criteria

**AC-29-01 — First-launch detection routes to guild_hall**
With no save file: cold-launch produces `load_completed("first_launch")` → `seed_first_launch_state` runs → guild_hall renders within 1 second.

**AC-29-02 — Seeded Theron is present in roster + formation slot 0**
Post-seed: `HeroRoster._heroes[1].class_id == "warrior"`, `display_name == "Theron"`, `current_level == 1`, `xp == 0`. `_formation_slots[0] == 1` (Theron in slot 0).

**AC-29-03 — Starting gold is 100**
Post-seed: `Economy._gold_balance == 100`.

**AC-29-04 — Floor 1 of forest_reach is unlocked; floors 2–5 are LOCKED**
Post-seed: `FloorUnlock.get_floor_state("forest_reach", 1) == UNLOCKED_AVAILABLE`. Floors 2–5 == LOCKED.

**AC-29-05 — Recruit pool is seeded with deterministic RNG**
Post-seed: `Recruitment._save_pool_seed != 0` (non-default, randi-initialized). `Recruitment.get_recruit_pool().size() > 0`.

**AC-29-06 — Recruit button is dimmed on first guild_hall render**
With 100 gold and no Tier-1 class affordable (warrior cost 150): the recruit button is disabled. Tapping it produces no scene transition.

**AC-29-07 — Dispatch button is enabled with seeded Theron in slot 0**
With Theron in formation_slot 0: tap Dispatch routes to formation_assignment. The pre-flight check "formation must have at least one hero" passes.

**AC-29-08 — First floor-1 dispatch produces gold + XP grant**
After clearing floor 1: gold increases by ≥ floor-1-clear-bonus + sum of kill drips. Theron's XP increases by ≥ 200 (typical run, per Formula D.2).

**AC-29-09 — First level-up fires toast + chime**
If the first dispatch crosses Theron's level 1 → 2 threshold (XP 150): `hero_leveled(1, 1, 2)` emits exactly once. dungeon_run_view shows the level-up toast. AudioRouter dispatches sfx_reward_level_up_chime (verifiable via `_test_play_sfx_log`).

**AC-29-10 — First-cycle wall-clock under 5 minutes**
Manual smoke: cold-launch → dispatch → clear floor 1 → return to guild_hall. Timed wall-clock < 300 seconds. Pillar 2 playtest measurement target.

**AC-29-11 — Save corruption recovery routes to first-launch**
With a corrupt save file: `corrupt_both_acknowledged` modal → acknowledge → `seed_first_launch_state` runs → guild_hall renders. No crash, no double-seed.

**AC-29-12 — Idempotent seed**
Calling `seed_first_launch_state` on a non-empty roster: push_warning + return; no mutation. (Already covered by `tests/unit/hero_roster/first_launch_seed_test.gd`).

**AC-29-13 — First offline reward renders Return-to-App Screen**
After first session ends + ≥ 30 minutes elapsed real-time: cold-launch on returning-launch path → OfflineProgressionEngine runs replay → `offline_rewards_collected` fires with seconds_credited > 0 → SceneManager routes to `return_to_app` screen → modal renders gold + kills + floor clears + hero levels gained.

**AC-29-14 — No tutorial overlay text exists in the codebase**
Repo grep: `grep -r "Click here" assets/ src/` returns zero matches. Same for "Tap to begin" / "Welcome!" / "Press to dispatch". The cozy register is enforced by the absence of tutorial copy.

---

## I. Open Questions & ADR Candidates

**OQ-29-1 — Loading splash for slow cold-launches**
Min-spec hardware (Steam Deck OLED 4GB) may show empty UI for 500ms while autoloads boot. A parchment-color loading splash would mask this but adds a frame. MVP: defer; observe in playtest. Sprint 15+ candidate if reported.

**OQ-29-2 — First-session metrics for designer feedback**
Should the first session record telemetry (time-to-first-dispatch, time-to-first-floor-clear, first-cycle-completion-rate)? MVP: NO — telemetry pipeline is V1.0 scope. Sprint 16+ candidate.

**OQ-29-3 — Locale detection on first launch**
Should the game auto-detect the player's OS locale and pre-select it in Settings? MVP: NO — only "en" is loaded; locale dropdown is disabled. V1.0 rollout adds locales + auto-detection.

**OQ-29-4 — "Welcome back" recognition for returning players**
After the player's second+ session, should the game show different text (e.g., "Welcome back" instead of empty)? MVP: NO — cozy register avoids over-personalization. V1.0+ candidate.

**OQ-29-5 — Failed-first-dispatch handling**
If the player's first floor-1 dispatch LOSES (low formation_strength vs. an unfavorable matchup), they get partial reward + a "try a different class" hint. Currently the hint is per-Pillar-1 NO-FAIL-STATE wording. Should the hint be more directive on the first-session loss specifically (e.g., "Recruit a Mage for elemental enemies")? MVP: NO — keep the hint identical regardless of session count. Sprint 15+ may add session-aware hints if playtest reveals first-session drop-off.

**OQ-29-6 — Skippable polish**
Should there be a "Skip animation" button on the victory_moment? MVP: NO — Pillar 2 cozy-register requires the moment to play. Reduce_motion (S12-S2) handles the accessibility case via clamp.

---

## J. Implementation Sequencing (Sprint 14+ candidate)

This GDD is design-first; implementation is mostly Sprint 14 S14-S3 (~1.0d) but DEPENDS on prior sprints' wiring (which is mostly already done):

1. **Story 1 (~0.25d)** — `STARTING_GOLD = 100` constant added to EconomyConfig. `Economy._gold_balance` initialization in `_ready` reads the constant. AC-29-03.
2. **Story 2 (~0.5d)** — End-to-end integration test `tests/integration/onboarding/first_launch_flow_test.gd` that simulates cold-launch + verifies seed pathway runs + guild_hall renders + Theron is in slot 0 with starting gold. ACs 29-01, 29-02, 29-04, 29-05, 29-06, 29-07.
3. **Story 3 (~0.25d)** — Manual smoke + playtest checklist: cold-launch → dispatch → clear → return-to-app. AC-29-10 + AC-29-13. Documented in `production/qa/onboarding-smoke-checklist.md`.
4. **Story 4 (~0.0d already done)** — AC-29-12 idempotent seed already covered by `tests/unit/hero_roster/first_launch_seed_test.gd`. AC-29-14 grep-test addable in 0.1d if not already present.

Total Sprint 14 scope: ~1.0d. Smaller than the typical first-pass GDD because most of the wiring (seed pathway, screen routing, save detection) is already shipped — this story is the connective integration test + the constant + the documentation.

---

## Notes

- Authored 2026-05-06 by post-Sprint-14-prep autonomous-execution session. Drafted to unblock Sprint 14 S14-S3.
- All ACs are testable via the patterns in `tests/PATTERNS.md`.
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED. Expect review to surface ~3–5 BLOCKING items (lower than first-pass GDDs because the implementation surface is mostly done; the GDD is reverse-documentation + integration spec).
- Closes the design-coverage gap that's existed since project inception (systems-index row 29 has been "Not Started").

---

## J — Retirement Note for Onboarding UX Polish Carry (Sprint 18, 2026-05-14)

**Status**: The "onboarding UX polish" carryover story is formally **RETIRED** as deferred-indefinitely. The 5-minute first-session flow specified in this GDD §A–§H is shipped and working; the carry chain (Sprint 15 S15-N3 → Sprint 16 S16-N4 → Sprint 17 S17-N2 → Sprint 18 S18-S1) was for *additional polish* on top of the working flow.

**Why retired rather than pulled in**: across 4 sprints of carry, **zero playtest sessions produced a signal demanding onboarding polish**. The Sprint 17 S17-M6 progression-chain playtest validated the live game end-to-end and verdicted "works great" — onboarding included. The Sprint 16 retro identified content + mechanic variety as the load-bearing player ask, not polish on an already-working onboarding surface.

**What still applies**: every AC in §H of this GDD (AC-29-01 through AC-29-14) remains the system's contract for any future onboarding changes. The retirement closes the *historical polish carry* line item only; it does not retire the ACs themselves.

**Pull trigger** (V1.5+): if a future playtest, beta cohort, or onboarding-completion telemetry surfaces a measurable first-session drop-off or a player complaint about the 5-minute flow, re-open this story with the specific signal as the design brief. Until then, the existing flow is "good enough by the playtest-driven closure rule."

**Audit closure reference**: `production/sprints/sprint-18.md` S18-S1 (closed 2026-05-14) + `production/retrospectives/sprint-17-retrospective-2026-05-14.md` action item #3 final disposition.
