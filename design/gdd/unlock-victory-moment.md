# Unlock / Victory Moment — GDD #25

> **Status: First-pass DRAFT 2026-05-07** by post-Matchup-Assignment-GDD autonomous-execution session, continuing the Sprint-14-prep design-coverage push (9th first-pass GDD; **closes the last MVP-tier UI screen "Not Started" gap**). All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. Run `/design-review` before APPROVED.
>
> **Design floor pre-locked**: Floor Unlock System #16 §C.1 R5 explicitly locks the LOSING-fanfare register for this screen ("identical fanfare for WIN and LOSING first-clears; no audio, animation, palette, or intensity differentiation"). This GDD honors that lock and does NOT branch on `losing_run`. Pass-4 of Floor Unlock locked this design floor 2026-04-21.

---

## A. Overview

**Unlock / Victory Moment** is the foreground celebration screen that renders the post-run payoff after `dungeon_run_view` completes a floor-clear run. It subscribes to `DungeonRunOrchestrator.floor_cleared_first_time` (or reads the orchestrator's run_snapshot directly on enter) + reads `FloorUnlock.get_highest_cleared(biome_id)` to classify the event as "new-high advancement" vs "re-clear" and renders accordingly:

- **First-ever clear of a higher floor**: shows the unlock fanfare + "Floor N+1 now available" message + gold/kill/level-up summary
- **Re-clear (already at this high water mark)**: shows the gold/kill/level-up summary with a quieter confirmation (no "newly unlocked" message)
- **LOSING first-clear** (per ADR-0002 reclaim path): shows the **identical fanfare** as WIN — no differentiation in audio, animation, palette, or intensity (Floor Unlock §C.1 R5 lock)

Player taps anywhere on the screen (or waits for an auto-advance after RUN_END_DWELL_MS expires + a per-screen continuation dwell) to navigate to `guild_hall` via CROSS_FADE.

This screen is **foreground-only** — offline replay clears do NOT trigger this screen (the Return-to-App Screen #20 aggregates offline replay rewards into a single cozy summary). The screen is entered only via `dungeon_run_view._on_state_changed → RUN_ENDED → request_screen("victory_moment", CROSS_FADE)`.

---

## B. Player Fantasy

> *"I just finished my run. Theron killed 12 enemies, gold went from 60 to 175 — I gained 115g. Forest Reach Floor 1 cleared for the first time. The screen settles into a parchment scene with Theron's portrait, the kill count, the gold gained, the level-up notice (Theron is now level 2). A small parchment-warm caption: 'Forest Reach — Floor 2 now available.' I tap once; the scene fades back to the Guild Hall, gold counter pre-pulsed to 175 because I already saw it. The lantern moved one step further."*

The cozy register applies, per Floor Unlock GDD #16 §C.1 R5 + game-concept.md Pillar 2 (Cozy Pacing) + Pillar 3 (Visible, Honest Progression Without Pressure):

- **Quiet ceremony, not triumphant cinematic.** "The lantern moved one step further" register; no "NEW CHAPTER UNLOCKED!!!" framing.
- **Identical fanfare WIN/LOSING.** A first-clear is a first-clear; the cozy game register does not punish losing.
- **Information not pressure.** Player sees what they earned (gold, kills, level-ups) and what's now available (next floor unlocked) — no urgency, no "claim now or lose it" prompt.
- **Tap-to-continue, no skip button.** Per onboarding-first-session.md OQ-29-X (no skip-animation button) — the moment plays at the cozy pace; reduce_motion handles accessibility; manual skipping is V1.0+ scope.

The screen is the **emotional capstone of a session**. Per game-concept.md "Devil Lord-inspired" framing: each run produces a clear win condition (the floor cleared / the lantern advanced / the gold counted). The Victory Moment is where that win is acknowledged.

---

## C. Detailed Rules

### C.1 Layout

The Control hierarchy follows the Return-to-App Screen pattern (per `return-to-app-screen.md` precedent — both are post-event payoff screens):

```
victory_moment.tscn (Control, anchors_preset = 15 full-rect)
├── ParchmentBackdrop (TextureRect or ColorRect, parchment-grain texture)
├── CenterPanel (PanelContainer, parchment-themed via UIFramework.apply_parchment_panel, max_width=480px)
│   ├── HeroPortraitRow (HBoxContainer of formation hero portraits, justified-around)
│   │   ├── HeroPortrait[0] (TextureRect, 96×96 logical px)
│   │   ├── HeroPortrait[1]
│   │   └── HeroPortrait[2]
│   ├── DividerLine (HSeparator, parchment-grain)
│   ├── HeadlineLabel (Label, IdentityHeader theme variation, "Forest Reach — Floor 1 cleared")
│   ├── UnlockNoticeLabel (Label, parchment-warm slate-ink, "Floor 2 now available." — visible only on new-high advancement)
│   ├── DividerLine (HSeparator)
│   ├── StatsBlock (VBoxContainer, padded)
│   │   ├── KillCountRow (HBoxContainer: "Kills" label + KillCountValue "12")
│   │   ├── GoldGainedRow (HBoxContainer: "Gold gained" label + GoldGainedValue "+115g")
│   │   └── LevelUpsBlock (VBoxContainer of LevelUpRow, hidden when no level-ups)
│   │       └── LevelUpRow[N] (Label, "Theron reached level 2")
│   └── ContinuationPromptLabel (Label, slate-ink secondary, "Tap to continue", visible after CONTINUATION_DWELL_MS)
└── DimBackdrop (DimBackdrop ColorRect over the whole screen, alpha=0.0 initially; full-screen tap target via gui_input)
```

Sizing/spacing notes (anchored to UIFramework + Art Bible §4):
- CenterPanel max_width: 480px (slightly larger than Return-to-App's 400px to accommodate the celebration register).
- HeroPortrait size: 96×96 logical px.
- HeroPortraitRow vertical-margin: 24 logical px.
- All Labels: parchment-themed; slate-ink primary for headers, slate-ink secondary for stats.
- DimBackdrop: full-screen ColorRect with alpha animated from 0 → 0.4 over 200ms on entry (gentle parchment dim — softer than Settings overlay's 0.5).
- ContinuationPromptLabel: subtle pulse animation (0.8 → 1.0 alpha over 1.5s loop, reduce_motion → static at 1.0).

### C.2 Lifecycle hooks

`victory_moment.gd` extends `Screen`. Entered via `SceneManager.request_screen("victory_moment", CROSS_FADE)` from dungeon_run_view's RUN_ENDED route (replacing the current Sprint-9 hard-coded `main_menu` target at `assets/screens/dungeon_run_view/dungeon_run_view.gd:308`).

**on_enter:**
- Read `DungeonRunOrchestrator.run_snapshot` for: kill_count, formation_snapshot.heroes, dispatched_floor_index, dispatched_biome_id
- Read `FloorUnlock.get_highest_cleared(biome_id)` BEFORE the unlock state advances — this read tells the screen "was this a new-high?" by comparing `dispatched_floor_index` against the prior `get_highest_cleared` value
  - **Sequencing note**: FloorUnlock receives `floor_cleared_first_time` and advances `_highest_cleared` BEFORE the screen routes. The screen's read happens AFTER the advance. To classify "new-high" vs "re-clear", the screen uses a different signal: it checks whether the orchestrator's `floor_cleared_first_time` fired with `losing_run = false` AND `dispatched_floor_index > FloorUnlock.get_highest_cleared(biome_id) - 1`. The "−1" accounts for the post-advance state. **Resolution path**: add `FloorUnlock.was_first_clear` accessor or a `floor_cleared_first_time` payload extension flag to disambiguate; defer to /design-review.
- Track gold delta from `Economy.gold_changed` reason="kill" + reason="floor_clear" deltas captured during the run (V1.0+: orchestrator's run_snapshot.gold_gained field) OR compute delta against a snapshot of pre-dispatch gold balance (MVP scope).
- Track per-hero level-ups: subscribe to `HeroRoster.hero_leveled` during the run? Cleaner: use the orchestrator's run_snapshot to track per-hero level changes (V1.0+) OR query each formation hero's current_level + compare against snapshot's stored pre-run level (MVP scope).
- Render `_render_payoff()`:
  - HeroPortraitRow: per formation hero, resolve class portrait via DataRegistry
  - HeadlineLabel: tr-format with biome name + floor index — e.g., "Forest Reach — Floor 1 cleared"
  - UnlockNoticeLabel: visible only when new-high advancement; tr-format with next floor index — e.g., "Floor 2 now available." (hidden when no new floor unlocked)
  - StatsBlock:
    - KillCountValue from run_snapshot.kill_count
    - GoldGainedValue formatted via UIFramework.format_short_number with `+` prefix
    - LevelUpsBlock: one LevelUpRow per leveled hero (tr-format: "Theron reached level 2")
  - ContinuationPromptLabel hidden initially
- Wire DimBackdrop.gui_input → `_on_screen_tapped` (any mouse-button-pressed OR touch-pressed → continuation)
- Auto-show ContinuationPromptLabel after CONTINUATION_DWELL_MS (default 1500ms; matches RUN_END_DWELL_MS pacing)
- Connect `floor_cleared_first_time` → `_on_floor_cleared_re_emit` (defensive: if signal re-fires due to a state machine bug, ignore — the screen state is set on first enter; subsequent emits are no-ops)

**on_exit:**
- Disconnect DimBackdrop input + signal
- All animations cleared

**on_pause / on_resume:**
- pass — victory_moment is not pausable (modal-like behavior over guild_hall; player must dismiss to continue)

### C.3 Headline + unlock notice

`_render_headline_and_unlock()`:
- HeadlineLabel reads from biome.display_name_key (resolved via DataRegistry) + floor_index. Format: tr("victory_headline_format") with %s biome + %d floor.
- UnlockNoticeLabel:
  - new-high advancement (this floor was just made the new highest cleared): visible, text = tr("victory_unlock_format") with next floor (e.g., "Floor 2 now available.")
  - re-clear: hidden (no message)
  - LOSING first-clear: visible (per Floor Unlock §C.1 R5 — identical fanfare WIN/LOSING). The unlock notice fires because the floor is genuinely first-cleared even on LOSING.
- "newly accessible" classification per Floor Unlock §C.1 R5: a floor counts as new-high when `floor_cleared_first_time` fires for the first time on that floor (both WIN and LOSING qualify).

### C.4 Stats render

`_render_stats()`:
- KillCountValue: integer count, no formatting needed for typical 5-30 kill values; format_short_number applied if > 999 (V1.0+ multi-floor batch runs).
- GoldGainedValue: tr("victory_gold_gained_format") with format_short_number(gold_delta) + "g" suffix. Color-coded: amber-warm for positive (always positive in MVP — runs only credit gold).
- LevelUpsBlock: per-hero rows, one per hero who leveled up during this run. If zero level-ups, the entire block is hidden (cozy: don't render an empty section).

Gold delta computation (MVP):
1. on_enter, read `Economy.get_gold_balance()` as `_post_balance`
2. If `_pre_balance` was captured before dispatch (V1.0+ requires orchestrator's pre-dispatch balance snapshot), use `_post_balance - _pre_balance`
3. MVP fallback: read `_pre_balance` from DungeonRunOrchestrator.run_snapshot.pre_dispatch_gold (NEW field; ~5 LoC orchestrator extension)

**Resolution path**: orchestrator extension (Sprint 15+ implementation) adds `run_snapshot.pre_dispatch_gold: int` captured at dispatch validation time. The Victory Moment screen reads this for the delta. Captured in §I OQ-25-1.

### C.5 Continuation interaction

`_on_screen_tapped(event)`:
- Accept InputEventMouseButton.pressed OR InputEventScreenTouch.pressed
- Defensive: respect a 200ms grace period from on_enter (ignore taps in the first 200ms to prevent accidental dismiss when the screen first appears post-fade — common cozy register pattern)
- Call `SceneManager.request_screen("guild_hall", CROSS_FADE)`

`_on_continuation_dwell_elapsed()` (after CONTINUATION_DWELL_MS):
- Show ContinuationPromptLabel with subtle pulse animation
- Player can tap immediately or wait (no auto-advance — Pillar 2 cozy register; player owns the pace)

### C.6 reduce_motion accessibility

Per Settings GDD #30 §C + ADR-0008 + onboarding-first-session.md OQ:
- `Settings.reduce_motion == true`:
  - DimBackdrop alpha snap to 0.4 (no fade-in)
  - ContinuationPromptLabel pulse disabled (static at 1.0 alpha)
  - HeroPortraitRow / StatsBlock entrance animations disabled (static reveal)
  - Cross-fade transitions on screen entry/exit are instant (per existing reduce_motion contract)
- `reduce_motion == false`:
  - DimBackdrop alpha 0 → 0.4 over 200ms ease-in
  - ContinuationPromptLabel pulse 0.8 → 1.0 alpha over 1.5s loop
  - Subtle 200ms staggered fade-in on HeroPortraitRow → DividerLine → HeadlineLabel → UnlockNoticeLabel → StatsBlock (cozy progressive reveal; total reveal time ≤500ms)

### C.7 Foreground-only invariant

The screen is entered ONLY when foreground combat completes a run. Offline replay floor-clears do NOT trigger this screen — they aggregate into Return-to-App Screen #20 per ADR-0014 + offline-progression-engine.md.

Why this matters: a player returning from a 4-hour offline session might have 12+ floor clears in the replay. If victory_moment fired for each, the player would face an unworkable "tap 12 times to dismiss the celebration cascade" UX. Instead, Return-to-App Screen aggregates all 12 clears into a single cozy summary; the foreground victory_moment fires only on the live "I just finished a run" moment.

Implementation: dungeon_run_view's `_on_state_changed` is the sole entry path. Offline replay does not transition through dungeon_run_view; it goes directly through OfflineProgressionEngine + Return-to-App Screen.

### C.8 No-skip invariant

Per onboarding-first-session.md OQ-29-skip + Pillar 2 cozy register: there is NO skip button. The screen plays at its natural pace. reduce_motion handles the accessibility case (instant reveals + static prompt). V1.0+ MAY add an opt-in "always skip victory moments" Settings toggle for accessibility users beyond reduce_motion's scope; deferred.

### C.9 Tap-debounce (sub-200ms grace)

Per §C.5 step 2 — taps in the first 200ms after on_enter are ignored. This prevents the case where the player was about to tap something on dungeon_run_view as the run ended; the cross-fade transitions to victory_moment mid-tap, and the tap accidentally dismisses the celebration before the player has read it. 200ms is short enough to feel responsive once intentional.

### C.10 Multi-hero level-up cascade

Per Hero Leveling GDD #15 §C.4 (multi-level cascade): a single XP grant can produce multiple level-ups per hero via the `add_xp` cascade. Screen shows ONE LevelUpRow per hero per LEVEL crossed. So if Theron went 1→3 and Mira went 2→4 in one run, the LevelUpsBlock shows 4 rows ("Theron reached level 2", "Theron reached level 3", "Mira reached level 3", "Mira reached level 4") OR a consolidated form ("Theron reached level 3", "Mira reached level 4" — terminal level only).

**Resolution path**: MVP shows terminal level only ("Theron reached level 3"; Mira reached level 4") to avoid cascade-row spam. The HeroRoster signal cascade emits per level, but the screen consolidates by tracking pre-run level and post-run level per hero; one row per hero who leveled at all. Captured in §I OQ-25-2.

### C.11 RUN_END_DWELL_MS pacing

dungeon_run_view holds the run-end overlay for `RUN_END_DWELL_MS = 1500ms` (Sprint 9 S9-M2) BEFORE routing to victory_moment. So total pacing is:
- Combat resolves → dungeon_run_view shows overlay → 1500ms dwell → CROSS_FADE 200ms → victory_moment on_enter → 200ms grace → ~500ms staggered reveal → CONTINUATION_DWELL_MS 1500ms → "Tap to continue" pulse → player tap → CROSS_FADE 200ms → guild_hall

Total ceremony: ~3500-4000ms minimum. Cozy pace; never rushed.

---

## D. Formulas

### D.1 New-high classification (cross-reference)

Per Floor Unlock GDD #16 §C.1:
```
is_new_high(biome_id, floor_index, prior_high) = floor_cleared_first_time fired AND floor_index > prior_high
```
Where `prior_high` is `FloorUnlock.get_highest_cleared(biome_id)` BEFORE the floor_cleared_first_time advance.

Per §C.3 sequencing-note resolution path: the orchestrator's `floor_cleared_first_time` signal payload is the canonical "this WAS a first-clear" indicator. The screen uses the signal-firing AS the classifier; if the signal fired AND the floor matches the run's dispatched floor, it's a new-high (the signal fires only for genuine first-clears per Floor Unlock + Economy idempotency).

### D.2 Gold delta (cross-reference)

```
gold_delta = post_run_gold_balance - pre_dispatch_gold_balance
```
Where `pre_dispatch_gold_balance` is captured at dispatch time on `DungeonRunOrchestrator.run_snapshot.pre_dispatch_gold` (NEW field per §I OQ-25-1; Sprint 15+ orchestrator extension).

### D.3 Per-hero level delta (cross-reference)

```
hero_level_delta(hero) = hero.current_level - run_snapshot.formation_snapshot.heroes[i].current_level
```
Where the snapshot's heroes array stores pre-dispatch level (per `dungeon-run-orchestrator.md` snapshot construction). HeroRoster's current_level reflects post-XP-cascade state.

LevelUpsBlock renders one LevelUpRow per hero where `hero_level_delta > 0`. Terminal level is shown ("Theron reached level %d" with post-cascade level).

---

## E. Edge Cases

### E.1 Re-clear of existing floor (no new-high)
Player re-runs Forest Reach Floor 1 after already clearing it. floor_cleared_first_time does NOT fire (per Economy idempotency + Floor Unlock §C.1). UnlockNoticeLabel hidden. Stats render normally (kills + gold delta + level-ups if any). Cozy: re-clear is acknowledged but quieter than first-clear.

### E.2 LOSING first-clear
Player completed a LOSING run (lost some heroes mid-run) but the floor still credited per ADR-0002 reclaim semantic. floor_cleared_first_time fires with `losing_run = true`. Per Floor Unlock §C.1 R5 LOCK: identical fanfare. UnlockNoticeLabel visible. No "you LOST" framing anywhere on the screen. The LOSING-WIN reclaim path on a future run shows ZERO additional reward (already credited per ADR-0002).

### E.3 Zero kills
Defensive — a run that resolves with 0 kills (improbable but possible if the floor's enemy_list is empty). KillCountValue = 0. GoldGainedValue likely 0 unless floor-clear bonus credited. Cozy: render the row anyway; data honesty over "hide the zero" framing.

### E.4 Zero level-ups
Most runs don't produce level-ups in the early game (XP per kill is low per Hero Leveling §C.1; multi-run accumulation needed). LevelUpsBlock hidden entirely (cozy: don't render an empty "Level-ups: 0" row).

### E.5 Hero in formation removed mid-run (V1.0+ retire UI)
MVP doesn't have retire UI. V1.0+: if a formation hero was removed during the run (between dispatch and clear), the snapshot still has the hero's pre-dispatch state. The Hero Leveling cascade still grants XP to the snapshot's formation slots per Hero Leveling §C.6 formation determinism. The screen renders a level-up row for the now-removed hero. Cozy: name is still shown as a salute. V1.0+ may add a "(retired)" footnote.

### E.6 Save / load mid-screen
Player closes the app while on victory_moment. SaveLoadSystem persists. On reopen, the screen does NOT auto-restore — `_pre_dispatch_gold` snapshot is gone; the screen's render data is gone. **Resolution**: on cold-launch, the player skips victory_moment entirely (Return-to-App Screen handles the offline-replay aggregation, which DOES survive close-reopen). Mid-screen close is treated as "the player saw enough; route directly to guild_hall on next launch". Captured in §I OQ-25-3.

### E.7 reduce_motion mid-screen
V1.0+ scenario; MVP doesn't support live reduce_motion toggle without restart. Mid-screen flag change does not retroactively update the current animation; next on_enter picks up the new value.

### E.8 Locale change mid-screen
V1.0+ scenario; MVP locks locale at boot. Static labels don't refresh mid-screen.

### E.9 Floor 5 boss clear (biome completion)
Per biome-dungeon-database.md, Floor 5 is a boss floor. Cleared = biome completed. UnlockNoticeLabel may say "Forest Reach completed!" instead of "Floor 6 now available" (no Floor 6 in MVP single-biome scope). **Resolution path**: special-case Floor 5 clear; tr-format "victory_biome_completed_format" with biome name. V1.0+ multi-biome unlocks the next biome here; MVP locks at "Forest Reach completed."

### E.10 Tap-spam during reveal animation
Player taps rapidly during the 200ms grace window. All taps before the grace expires are ignored (§C.9). After grace, first tap dismisses; subsequent taps fall on guild_hall (which has its own input handling). No double-dispatch concern.

### E.11 Backgrounding / foreground cycle
Player backgrounds the app on victory_moment. Per `tick_system.md` + ADR-0005, the tick system pauses (ProcessMode.WHEN_PAUSED). Animations do NOT advance in the background. On foreground, animations resume from their paused state; no special handling needed. The screen is not time-sensitive — there's no timeout to dismiss.

### E.12 _replay_in_flight = true on enter
This screen is foreground-only per §C.7 invariant. If `OfflineProgressionEngine._replay_in_flight == true`, the screen should NOT have been entered (the orchestrator wouldn't have transitioned through dungeon_run_view's RUN_ENDED handler during replay). Defensive check on enter: push_warning + immediate route to guild_hall if this invariant is violated. Captured in §I OQ-25-4.

---

## F. Dependencies

### Hard dependencies (Victory Moment requires these to function)

| System | Why | Surface used |
|---|---|---|
| `DungeonRunOrchestrator` (#13) | Run state + snapshot data | `run_snapshot` (kill_count, formation_snapshot.heroes, dispatched_floor_index, dispatched_biome_id, pre_dispatch_gold per §I OQ-25-1), `floor_cleared_first_time` signal (classifier per §D.1) |
| `Economy` (#5) | Post-run gold balance | `get_gold_balance()` |
| `HeroRoster` (#9) | Per-hero post-run level | `_heroes[id]` (read), `level_cap()` |
| `FloorUnlock` (#16) | Re-clear vs new-high classifier | `get_highest_cleared(biome_id)` |
| `BiomeDungeonDatabase` (#8) | Biome display name resolution | per-biome `display_name_key` via DataRegistry.resolve("biomes", id) |
| `DataRegistry` (#2) | Class portrait + biome resolution | `resolve("classes", id)`, `resolve("biomes", id)` |
| `SceneManager` (#4) | Navigation | `request_screen("guild_hall", CROSS_FADE)` |
| `UIFramework` (#18) | Theme + format helpers | `apply_parchment_panel`, `format_short_number`, `format_localized` |
| `TranslationServer` (Godot built-in) | Localization | `translate(StringName)` |

### Reverse dependencies (systems that depend on Victory Moment)

- **Dungeon Run View** (#24) — `_on_state_changed` RUN_ENDED handler routes here (replaces the current Sprint 9 placeholder route to `main_menu`)

### Soft dependencies

- **AudioRouter** (#28) — fanfare stinger fires via existing `floor_cleared_first_time` subscriber per audio-system.md; the screen does not invoke audio directly (silent until ADR-0016 pivot trigger fires)

---

## G. Tuning Knobs

### Layout knobs (parchment_theme + screen.tscn)
- CenterPanel max_width: 480px.
- HeroPortrait size: 96×96 logical px.
- DimBackdrop alpha target: 0.4 (softer than Settings overlay's 0.5).

### Pacing knobs (per ADR-0008 timing pillars)
- CONTINUATION_DWELL_MS: 1500ms (matches RUN_END_DWELL_MS for symmetric pacing). Range: 800-2500ms; below 800ms feels rushed; above 2500ms feels frozen.
- TAP_GRACE_MS: 200ms (sub-200ms taps ignored to prevent accidental dismiss).
- DimBackdrop fade-in duration: 200ms.
- Staggered reveal duration: 500ms total across 5 elements (100ms per element). reduce_motion → 0ms.
- ContinuationPromptLabel pulse cycle: 1.5s (0.8 → 1.0 alpha → 0.8). reduce_motion → static.

### Tunable string templates (locale CSV)
- "victory_headline_format" → "{biome} — Floor {floor} cleared"
- "victory_unlock_format" → "Floor {next_floor} now available."
- "victory_biome_completed_format" → "{biome} completed!"
- "victory_gold_gained_format" → "+{amount}g"
- "victory_level_up_format" → "{hero_name} reached level {level}"
- "victory_continuation_prompt" → "Tap to continue"

### V1.0+ tuning knob: per-biome celebration variation
V1.0+ may add per-biome celebration cues — e.g., Forest Reach uses parchment-warm green tinting; Cinder Keep uses amber. MVP keeps a single parchment register for simplicity. Tuning knob: `Biome.victory_tint_color: Color` (V1.0+ field).

---

## H. Acceptance Criteria

**AC-25-01 — Screen entered from dungeon_run_view RUN_ENDED**
Sole entry path is `dungeon_run_view._on_state_changed → RUN_ENDED → request_screen("victory_moment", CROSS_FADE)`. Replaces the Sprint 9 hard-coded `main_menu` route at `dungeon_run_view.gd:308`.

**AC-25-02 — HeroPortraitRow shows formation heroes**
The 3 (or formation_size) HeroPortraits render with class portraits resolved via DataRegistry.

**AC-25-03 — HeadlineLabel shows biome + floor cleared**
Format: tr("victory_headline_format") with biome.display_name + floor_index.

**AC-25-04 — UnlockNoticeLabel visible only on new-high advancement**
When `floor_cleared_first_time` fired during this run (i.e., this floor was just made the new highest cleared) → label visible. Re-clear → label hidden.

**AC-25-05 — UnlockNoticeLabel fires on LOSING first-clear**
Per Floor Unlock §C.1 R5 LOCK: identical fanfare WIN/LOSING. LOSING run that produced a first-clear → UnlockNoticeLabel visible with the same text + same theme as WIN.

**AC-25-06 — KillCountValue matches run_snapshot.kill_count**
Integer value rendered without formatting for typical 5-30 kill values.

**AC-25-07 — GoldGainedValue shows positive delta**
Format: tr("victory_gold_gained_format") with format_short_number(gold_delta) + "g". Always positive (runs only credit gold in MVP).

**AC-25-08 — LevelUpsBlock shows one LevelUpRow per leveled hero (terminal level)**
For each hero in formation where `hero.current_level > snapshot_pre_run_level`: render one row with terminal level. Block hidden when zero level-ups.

**AC-25-09 — Tap-grace ignores taps in first 200ms**
Tap before TAP_GRACE_MS expires → no-op. Tap after → routes to guild_hall.

**AC-25-10 — ContinuationPromptLabel appears after CONTINUATION_DWELL_MS**
At t=CONTINUATION_DWELL_MS post-enter, label fades in (or appears statically with reduce_motion).

**AC-25-11 — Tap routes to guild_hall via CROSS_FADE**
Player tap (after grace) → `SceneManager.request_screen("guild_hall", CROSS_FADE)`.

**AC-25-12 — No skip button**
The screen has no Button labeled "Skip", "Skip Animation", "Continue", or similar. Tap-anywhere is the sole continuation mechanism.

**AC-25-13 — reduce_motion suppresses animations**
`Settings.reduce_motion == true` → DimBackdrop alpha snap; staggered reveal disabled; ContinuationPromptLabel pulse static; cross-fade transitions instant.

**AC-25-14 — Floor 5 biome-completion message**
On Floor 5 clear: UnlockNoticeLabel text uses tr("victory_biome_completed_format") with biome name (no "Floor 6 now available" message).

**AC-25-15 — Foreground-only invariant**
Offline replay floor-clears do NOT trigger this screen. The orchestrator's flush_offline_signals emits floor_cleared_first_time without routing through dungeon_run_view; victory_moment is not entered. Return-to-App Screen #20 handles offline aggregation.

**AC-25-16 — _replay_in_flight defensive guard**
If on_enter detects `OfflineProgressionEngine._replay_in_flight == true` (invariant violation): push_warning + route directly to guild_hall without rendering the celebration.

**AC-25-17 — Locale-aware labels**
HeadlineLabel, UnlockNoticeLabel, KillCountRow label, GoldGainedRow label, LevelUpRow strings, ContinuationPromptLabel all use tr() for locale-keyed strings.

**AC-25-18 — Identical fanfare WIN/LOSING (Floor Unlock §C.1 R5)**
Audio (per AudioRouter via existing floor_cleared_first_time subscriber), visual theme (parchment-warm), animation pacing, and intensity are IDENTICAL between WIN and LOSING first-clears. The `losing_run` payload field is read but does NOT branch any visual or audio logic.

---

## I. Open Questions & ADR Candidates

**OQ-25-1 — DungeonRunOrchestrator.run_snapshot.pre_dispatch_gold field**
The screen needs a gold delta = post_run - pre_dispatch. The current run_snapshot does NOT store pre_dispatch_gold. Sprint 15+ implementation must add this field (~5 LoC orchestrator extension). Defer the implementation decision to /design-review; the field is non-controversial and the GDD assumes it lands.

**OQ-25-2 — Multi-level cascade rendering: terminal-only vs per-level**
§C.10 documents the resolution path: MVP shows terminal level only ("Theron reached level 3"). Alternative: show per-level rows ("Theron reached level 2", "Theron reached level 3"). Cozy register favors terminal-only (avoid row spam); /design-review may prefer per-level for celebration register. Resolution path: MVP terminal-only; revisit during playtest if cascades feel under-celebrated.

**OQ-25-3 — Mid-screen save/load behavior**
§E.6 documents the resolution path: cold-launch from a save mid-victory_moment skips the screen entirely; route to guild_hall directly. Alternative: try to reconstruct the celebration from save state (complicated; Sprint 15+ scope). Resolution path: MVP skips on cold-launch.

**OQ-25-4 — _replay_in_flight defensive guard behavior**
§E.12 documents AC-25-16 behavior: if invariant violated, push_warning + route to guild_hall without celebrating. Alternative: route to Return-to-App instead. The push_warning is enough — the invariant violation is a state-machine bug; the route-to-guild_hall recovers gracefully.

**OQ-25-5 — Per-biome celebration tint variation**
§G V1.0+ tuning knob: `Biome.victory_tint_color`. MVP locks single parchment-warm register. V1.0+ candidate when 2nd biome lands.

**OQ-25-6 — Skip-animation accessibility opt-in**
Per §C.8 + onboarding-first-session.md: no skip button in MVP. V1.0+ MAY add a Settings opt-in for "always skip celebrations" beyond reduce_motion's scope. Some accessibility users (e.g., cognitive impairments) prefer "minimal cognitive load" over reduce_motion's "minimal motion". Captured for V1.0+ Accessibility GDD.

**OQ-25-7 — Sound design for the fanfare**
ADR-0016 silent-MVP path means the fanfare is silent in MVP. When ADR-0016's pivot trigger fires, the fanfare cue is one of the highest-priority SFX cues per audio-system.md §C.3 (Reward register). Soft dependency.

**OQ-25-8 — Multi-clear cascade display (V1.0+ multi-floor batch)**
V1.0+ may allow a single dispatched run to clear multiple floors (e.g., a "raid" mode or a guaranteed-progress cascade). The screen would need to aggregate multiple floor-clears. MVP: single-floor-per-run; this concern is V1.0+.

**OQ-25-9 — UnlockNoticeLabel for re-clear with reclaim**
ADR-0002 LOSING-then-WIN reclaim path: floor was first-cleared LOSING (UnlockNoticeLabel fired), then re-cleared WIN (delta gold credited; floor_cleared_first_time does NOT re-fire per Economy idempotency). On the WIN re-clear, UnlockNoticeLabel hidden (no "newly unlocked" message). Cozy: the WIN re-clear shows just the additional gold credit + kill count. Player understands the floor was already unlocked; the reclaim is a bonus, not a milestone. Captured for /design-review verification.

---

## J. Implementation Sequencing (Sprint 15+ candidate)

This GDD is design-first; implementation is Sprint 15+ candidate scope (~1.0d). Pre-sequenced as 5 stories:

1. **Story 1 (~0.2d)** — `victory_moment.tscn` authoring per §C.1 layout. Anchor preset 15 + parchment-themed CenterPanel + HeroPortraitRow + StatsBlock + ContinuationPromptLabel + DimBackdrop. Editor work; no .gd changes required.
2. **Story 2 (~0.2d)** — DungeonRunOrchestrator extension: add `run_snapshot.pre_dispatch_gold: int` field captured at dispatch validation time per §I OQ-25-1. Tests for the snapshot extension (~0.05d).
3. **Story 3 (~0.3d)** — `victory_moment.gd` lifecycle hooks per §C.2. on_enter / on_exit; read run_snapshot + classify new-high vs re-clear; render headline + unlock notice + stats block; wire DimBackdrop tap handler with TAP_GRACE_MS. Tests for ACs 25-01, 25-02, 25-03, 25-04, 25-05, 25-06, 25-07, 25-08.
4. **Story 4 (~0.2d)** — Animation polish per §C.6. Staggered reveal; ContinuationPromptLabel pulse; reduce_motion clamps. Tests for ACs 25-09, 25-10, 25-11, 25-13.
5. **Story 5 (~0.1d)** — Edge cases per §E. Floor-5 biome-completion message; foreground-only invariant; _replay_in_flight defensive guard; locale-aware labels. Tests for ACs 25-14, 25-15, 25-16, 25-17, 25-18.

Plus dungeon_run_view integration (~0.05d): replace the current Sprint-9 hard-coded `request_screen("main_menu", CROSS_FADE)` at `assets/screens/dungeon_run_view/dungeon_run_view.gd:308` with `request_screen("victory_moment", CROSS_FADE)`. One-line change + regression test for the routing.

Total Sprint 15+ scope: ~1.05d. Best landed in a sprint that also touches the dungeon_run_view → victory_moment → guild_hall pacing surface (the cozy ceremony spans 3 screens; testing the full cycle benefits from being all in one sprint).

---

## Notes

- Authored 2026-05-07 by post-Matchup-Assignment-GDD autonomous-execution session, continuing the Sprint-14-prep design-coverage push (9th first-pass GDD across 2026-05-06 + 2026-05-07 sessions). systems-index.md row 25 status flips from "Not Started" to "DRAFT 2026-05-07". **Closes the last MVP-tier UI screen "Not Started" gap.**
- All ACs are testable via patterns documented in `tests/PATTERNS.md`.
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED.
- This screen is the **emotional capstone of a foreground session**. Per game-concept.md Pillar 2 (Cozy Pacing) + Pillar 3 (Visible, Honest Progression Without Pressure): the celebration is quiet, predictable, and equal across WIN/LOSING per Floor Unlock §C.1 R5 LOCK.
- This GDD pairs with: Floor Unlock #16 (§C.1 R5 design floor), DungeonRunOrchestrator #13 (run_snapshot data source), Hero Leveling #15 (level-up cascade), Economy #5 (gold delta), Return-to-App Screen #20 (the offline-replay aggregation counterpart), Audio System #28 (fanfare cue, silent until ADR-0016 pivot).
- Implementation pre-scheduled for Sprint 15+ alongside the dungeon_run_view routing replacement (one-line change). Sprint 14 completes its scope without this; Sprint 15+ candidate.

---

## Closure

With this GDD authored, ALL MVP-tier UI screen GDDs are now covered. The systems-index.md "Not Started" tally drops from 7 to 6 — the remaining 6 entries are Vertical Slice / V1.0+ scope:
- #26 HD-2D Rendering Pipeline (Vertical Slice; gated on ADR-0017 sign-off + Steam Deck profiling)
- #27 VFX System (Vertical Slice; same gate)
- #31 Prestige System (V1.0)
- #32 Class Synergy System (V1.0+)

Plus 2 GDDs still pending /design-review feedback from the prior session's drafts:
- #29 Onboarding (drafted 2026-05-06)
- #30 Settings (drafted 2026-05-06)

The cumulative design-coverage push (Sprint-14-prep + this session) has closed 9 first-pass GDDs across systems-index "Not Started" gaps. MVP scope is now **fully GDD-covered** — every MVP-tier system has a design document, and every player-facing UI screen has a design document.
