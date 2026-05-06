# Return-to-App / Offline Rewards Screen — GDD #20

> **Status: First-pass DRAFT 2026-05-06** by autonomous-execution session. All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. **Reverse-documentation:** the screen was implemented in Sprint 13 S13-M2 (commit `2648492`); this GDD formalizes the contract that's already in source. Run `/design-review` to surface drift between this GDD and the live implementation.

---

## A. Overview

**Return-to-App Screen** is the cozy summary the player sees on cold-launch when offline-elapsed time produced a non-zero offline replay. The screen renders accumulated rewards from the offline window: gold earned, enemies defeated, floors cleared, hero levels gained.

The screen is a **registered screen** in the SceneRegistry (`return_to_app` ID), routed via `SceneManager.request_screen("return_to_app", SLIDE_DOWN)`. It is NOT a modal overlay — it occupies the full screen surface during the post-replay moment, dismissed by the player tapping "Continue" which routes back to guild_hall via CROSS_FADE.

The screen's role in the loop:
1. `OfflineProgressionEngine.run_offline_replay` completes (per S12-M5)
2. `OfflineProgressionEngine._last_summary` cached + `offline_rewards_collected` signal emitted (per S13-M2)
3. If `summary.seconds_credited > 0`: OE auto-triggers `SceneManager.request_screen("return_to_app", SLIDE_DOWN)` (per S13-M2 §autoload-side hook)
4. Screen `on_enter` reads cached summary + renders fields
5. Player taps "Continue" → `request_screen("guild_hall", CROSS_FADE)`

---

## B. Player Fantasy

> *"I close the app. I come back later. There's a parchment-warm summary screen telling me what my heroes did while I was away — the gold they earned, the enemies they defeated, the levels they gained. It's a brief moment of 'see what happened?' before I'm back in the cozy register."*

The cozy register sets the bar: the summary is **celebratory but quiet**. NO confetti. NO "huge bonus!" toasts. NO reward-rarity tiers. Just the numbers, in the parchment palette, with the fanfare audio cue that says "this is a milestone moment".

Critical: **the screen NEVER blocks gameplay**. The player can tap "Continue" instantly; they don't have to read any text or watch any animation through completion. The summary is informational, not gating.

---

## C. Detailed Rules

### C.1 Screen lifecycle

`return_to_app` is registered in SceneManager's screen map (`scene_manager.gd:204`). `request_screen("return_to_app", SLIDE_DOWN)` routes via the standard SceneManager pipeline:
1. Old screen `on_exit` fires (typically guild_hall or main_menu)
2. SLIDE_DOWN transition (~150ms per `_get_slide_duration_ms`)
3. New screen instantiated + `on_enter` fires
4. `transition_complete` signal emits

**`on_enter`** subscribes to:
- `OfflineProgressionEngine.offline_rewards_collected` — re-render if a NEW replay completes while screen is alive (defensive; rare)
- `OfflineProgressionEngine.cap_reached` — show the cap notice if the replay was clipped

Reads cached `OfflineProgressionEngine.last_summary()` to populate the summary fields. If null (no recent replay), renders the no-summary fallback message.

Applies parchment panel via `UIFramework.apply_parchment_panel($SummaryPanel)` + touch feedback via `UIFramework.wire_touch_feedback($AcknowledgeButton)`.

**`on_exit`** disconnects both signals defensively (idempotent guard via `is_connected`).

### C.2 Summary field rendering

The screen displays:
- **HeaderLabel**: `tr("return_to_app_title")` ("Welcome back!")
- **ElapsedSubhead**: `format_localized("return_to_app_seconds_credited_format", [int(summary.seconds_credited / 60)])` ("You were away for N minutes.")
- **GoldRow**: `format_localized("return_to_app_gold_earned_format", [summary.gold_earned])` ("+N gold earned")
- **KillsRow**: total kills summed across the `_kills_by_tier` meta Dictionary; `format_localized("return_to_app_kills_format", [total_kills])`
- **FloorsRow**: count of `summary.floors_cleared_in_window` Array; `format_localized("return_to_app_floors_format", [floors_count])`
- **CapNotice** (conditionally visible): `format_localized("return_to_app_cap_reached_notice_format", [int(summary.seconds_clipped / 3600)])` — only shown if `summary.seconds_clipped > 0`
- **AcknowledgeButton**: `tr("return_to_app_acknowledge_button")` ("Continue")

Locale keys defined in `assets/locale/en.csv` (added in S13-M2 commit `2648492`).

### C.3 Cap notice handling

`OfflineProgressionEngine.cap_reached(seconds_clipped)` signal fires during replay if elapsed > offline_cap_seconds (default 28800 / 8h). The screen handler `_on_cap_reached(seconds_clipped)` caches the value; on next `_render_summary` call, the CapNotice Label is set visible with the formatted text.

Per the cozy register, the cap notice is informational, not punitive. "Capped at 8 hours offline." — no "you missed out!" framing.

### C.4 Acknowledge button → guild_hall

Tap "Continue" → `_on_acknowledge_button_pressed` → `SceneManager.request_screen("guild_hall", CROSS_FADE)`. Standard 150ms cross-fade.

The button is wired via `Button.pressed` signal, NOT `gui_input`. Per audio-system.md AC-AS-15: `gui_input` connects on press; `pressed` fires on release. The Acknowledge button intentionally uses `pressed` because:
- The button is the player's INTENT moment, not their TAP moment
- A press-and-drag-off-then-release should NOT route (the player changed their mind)
- Standard Button semantics are correct here

The UI tap chime + touch pulse still fire on `gui_input` press via `UIFramework.wire_touch_feedback`. The release doesn't fire a second chime (chime is wired to press only per AC-AS-15).

### C.5 No-summary fallback

If the screen is reached without a cached summary (e.g., player navigates manually via debug tooling, or a save corruption produced a state where `request_screen("return_to_app")` fired but `_last_summary` is null), the screen renders:

- HeaderLabel still shows the title
- All summary rows hidden
- A single Label: `tr("return_to_app_no_summary_fallback")` ("No recent rewards to summarize.")
- Acknowledge button still functional → routes back to guild_hall

This is defensive, not a player-facing path in production.

### C.6 Re-render on signal during screen lifetime

If the screen is on-entered and STILL alive when a NEW `offline_rewards_collected` fires (rare — would require a replay completing while the screen is showing), the `_on_offline_rewards_collected(summary)` handler re-calls `_render_summary(summary)`. The display updates to the new summary; the player sees the most recent.

Production scenario: this should never happen — OE only runs replays at boot time, and the screen would be alive AFTER replay completes. But the defensive subscription guards against future scenarios where replay could re-trigger (e.g., a manual debug invoke, or V1.0+ multi-replay-per-session).

### C.7 Save/Load behavior

The screen has NO save state. It's a transient view. `OfflineSummary` itself is held by `OfflineProgressionEngine` in-memory (`_last_summary`); per ADR-0014 + GDD §C.1 line 74, the V1.0 forward-compat field `hero_levels_gained: Dictionary[int, int]` is staged but NOT yet populated by S12-M5 (HeroLeveling GDD #15 §J Story 4 specifies the offline-replay XP-batching that populates this).

OQ-OE-1 (per offline-progression-engine.md §I) flags persisting OfflineSummary between replay-complete and screen-acknowledge — Sprint 13+ scope. Per Pillar 1 No-Fail-State, if the player closes the app DURING the Return-to-App screen (before tapping Continue), the summary should persist so they see it on the next cold-launch. MVP behavior: NOT persisted; closing during the screen loses the summary. V1.0 fixes this via Sprint 14+ persistence.

---

## D. Formulas

### D.1 Elapsed minutes display
`minutes_elapsed = int(summary.seconds_credited / 60)` — integer floor. 4500 seconds shows as "75 minutes."

### D.2 Cap notice hours display
`hours_capped = int(summary.seconds_clipped / 3600)` — integer floor. 7200 seconds clipped shows as "Capped at 2 hours offline."

### D.3 Total kills summing
`total_kills = sum(_kills_by_tier.values())` if the meta is populated; 0 otherwise. Defensive: meta not always populated (depends on whether `compute_offline_batch` returned non-null kill data).

### D.4 No other formulas
The screen is pure rendering; gameplay math is in the upstream OfflineProgressionEngine + Hero Leveling GDDs.

---

## E. Edge Cases

### E.1 OfflineProgressionEngine returns null summary
The `last_summary()` getter returns null. `_render_summary(null)` is guarded; falls through to `_render_no_summary_fallback()`. AcknowledgeButton still functional.

### E.2 summary.seconds_credited == 0 (edge case)
Shouldn't happen in production (OE doesn't auto-route on zero-credit replays per S13-M2 §autoload-side hook gating). If reached manually, the elapsed subhead shows "You were away for 0 minutes." which is clearly off but not crashing. Defensive.

### E.3 _kills_by_tier meta missing
If OE's compute_offline_batch returned no kill data, `_kills_by_tier` meta isn't populated. `total_kills` resolves to 0; KillsRow shows "0 enemies defeated." Cozy register tolerates this; no special "no kills" framing.

### E.4 Locale not loaded
Per UIFramework.format_localized fallback: missing locale keys produce raw-key + space-separated args output. Headless tests get "return_to_app_title" instead of "Welcome back!" — functional, ugly, acceptable for tests.

### E.5 Tap Continue during the SLIDE_DOWN transition
SceneManager.request_screen during a TRANSITIONING state queues into `_queued_request` per ADR-0007. The route fires after the transition completes. No crash; minor 150ms delay perceived.

### E.6 cap_reached fires before on_enter completes subscription
Race: OE emits cap_reached during `_load_interim_settings` boot, before the screen has subscribed. The screen reads `summary.seconds_clipped` directly in `_render_summary` (not via the cap_reached signal — the signal is supplemental for late-fire cases). MVP relies on the direct read. Tested per `tests/integration/return_to_app/return_to_app_screen_test.gd`.

### E.7 Player closes app during the Return-to-App screen
Per §C.7, MVP doesn't persist the summary. On next cold-launch, OE's `_last_summary` is null (in-memory only). If offline_elapsed > 0 produced a NEW replay, the new summary supersedes; if not, no Return-to-App route fires + the player resumes at main_menu / guild_hall. Documented limitation.

### E.8 Multi-replay scenario (V1.0+)
If a future feature triggers a second replay while the Return-to-App screen is alive (e.g., player manually triggers a debug "fast forward 1 hour"), the screen re-renders via `_on_offline_rewards_collected`. The Acknowledge button continues to work; routing remains correct.

### E.9 Acknowledge tap during replay-still-in-flight
`OfflineProgressionEngine.is_replay_in_flight()` returns false by the time the screen is reached (replay completes BEFORE the OE auto-route fires per S12-M5 §C.2). If by some race condition the screen is reached mid-replay, the cached summary is from a PRIOR replay; tapping Continue routes to guild_hall and the in-flight replay continues in the background. Not a clean state but doesn't crash.

### E.10 Hero levels gained displayed as 0 in MVP
Per the V1.0 forward-compat field note (offline-progression-engine.md §C.1), `summary.hero_levels_gained` is staged but NOT populated by S12-M5. The MVP screen does NOT render a "hero levels gained" row (it's not in the render list). HeroLeveling GDD #15 §J Story 4 will populate the field; the screen can add the row in a Sprint 14+ amendment.

---

## F. Dependencies

### Hard dependencies (Return-to-App Screen requires these)

| System | Why | Surface used |
|---|---|---|
| `OfflineProgressionEngine` (#12) | Source of OfflineSummary | `last_summary()`, `offline_rewards_collected` signal, `cap_reached` signal |
| `SceneManager` (#4) | Routing in/out | `request_screen("return_to_app", ...)` to enter; `request_screen("guild_hall", ...)` to dismiss |
| `UIFramework` (#18) | Parchment theme + touch feedback + locale-format | `apply_parchment_panel`, `wire_touch_feedback`, `format_localized` |
| `Screen` base class (#18 §C.2) | Lifecycle hooks | `on_enter`, `on_exit`, `on_pause`, `on_resume` |
| `assets/locale/en.csv` | Locale keys | 8 keys with `return_to_app_*` prefix |

### Reverse dependencies

- **OfflineProgressionEngine** (#12) — auto-routes to this screen post-replay per S13-M2 §autoload-side hook
- **Onboarding flow** (#29) — first offline reward per AC-29-13 references this screen as the visible artifact

---

## G. Tuning Knobs

### Screen width / height
- PanelContainer center-anchored. Width depends on locale + content. NOT a tunable.

### SLIDE_DOWN transition duration
- Per SceneManager `_get_slide_duration_ms` default. NOT tunable per-screen unless the screen exports `transition_override_ms`.

### Hide-on-no-summary policy
- Currently shows the no-summary fallback. Could alternatively auto-route to guild_hall if `_last_summary == null`. MVP picks "show fallback" because the screen was reached intentionally (debug or unexpected state); routing-back-without-acknowledgment hides the fact that something was unexpected.

### Cap notice display threshold
- Currently shows whenever `seconds_clipped > 0`. Could tune to "show only if > 1 hour clipped" to avoid noise on near-cap edge cases. MVP picks ">0" (any clip is informational).

---

## H. Acceptance Criteria

**AC-20-01 — Screen registers in SceneManager screen map**
`SceneManager._SCREEN_RETURN_TO_APP` preloads the .tscn; `_screen_paths.get("return_to_app") != null`.

**AC-20-02 — on_enter subscribes to OfflineProgressionEngine signals**
After `on_enter`: `OfflineProgressionEngine.offline_rewards_collected.is_connected(_on_offline_rewards_collected) == true` AND `cap_reached.is_connected(_on_cap_reached) == true`.

**AC-20-03 — on_exit disconnects subscribed signals**
After `on_exit`: both connections removed; `is_connected` returns false. Idempotent (calling on_exit twice doesn't crash).

**AC-20-04 — Renders summary fields when cache is populated**
With `OfflineProgressionEngine._last_summary` set to a populated OfflineSummary: `on_enter` reads it; HeaderLabel + ElapsedSubhead + GoldRow + KillsRow + FloorsRow are all visible with non-empty text. AcknowledgeButton enabled.

**AC-20-05 — Renders fallback when summary cache is null**
With `_last_summary == null`: `on_enter` calls `_render_no_summary_fallback`; the fallback Label is visible; summary rows are hidden. AcknowledgeButton still functional.

**AC-20-06 — Cap notice visible when seconds_clipped > 0**
With `summary.seconds_clipped > 0`: CapNotice Label is visible with formatted text. With `seconds_clipped == 0`: CapNotice hidden.

**AC-20-07 — Acknowledge button routes to guild_hall**
Tap AcknowledgeButton → `SceneManager.request_screen("guild_hall", CROSS_FADE)` is invoked. End-to-end transition is SceneManager's own test scope; this AC asserts the wiring.

**AC-20-08 — Re-render on signal emission while alive**
With screen on-entered: emit `offline_rewards_collected` with a NEW summary → `_on_offline_rewards_collected(new_summary)` runs → fields update to reflect the new summary.

**AC-20-09 — Parchment theme applied**
`SummaryPanel.theme_type_variation == "ParchmentPanel"`.

**AC-20-10 — Touch feedback wired on AcknowledgeButton**
`AcknowledgeButton.has_meta(_TOUCH_FEEDBACK_META) == true`. Tap fires `sfx_ui_tap` per S12-M6 AC-AS-14.

**AC-20-11 — OE auto-route fires on real replay**
In an integration test simulating cold-launch + offline_elapsed > 0: OfflineProgressionEngine.run_offline_replay completes → `seconds_credited > 0` → `request_screen("return_to_app", SLIDE_DOWN)` fires → screen mounts → summary renders.

**AC-20-12 — OE auto-route SUPPRESSED on zero-elapsed**
With `seconds_credited == 0`: OE does NOT call request_screen("return_to_app"). The cold-launch path proceeds to guild_hall normally.

**AC-20-13 — Locale keys present in en.csv**
`assets/locale/en.csv` contains all 8 `return_to_app_*` keys per S13-M2 commit. Each key has a non-empty translation.

**AC-20-14 — Headless test path works**
Integration test at `tests/integration/return_to_app/return_to_app_screen_test.gd` runs in headless mode without crash (the screen instantiates outside MainRoot + the request_screen call to guild_hall is asserted via button-connection check, not actual transition).

---

## I. Open Questions & ADR Candidates

**OQ-20-1 — Hero levels gained row**
HeroLeveling GDD #15 §J Story 4 specifies the offline-replay XP-batching populates `summary.hero_levels_gained: Dictionary[int, int]`. Once that ships, the Return-to-App Screen should add a row showing "+N levels gained" or per-hero rows. Sprint 14+ amendment.

**OQ-20-2 — Persist OfflineSummary between replay-complete and screen-acknowledge**
Per offline-progression-engine.md OQ-OE-1 + this GDD §C.7: MVP loses the summary if the player closes the app on the Return-to-App screen. Pillar 1 No-Fail-State concern. V1.0 fix: persist `_last_summary` to a small file at replay-complete time; load it on cold-launch if it exists; clear it on Acknowledge. Sprint 14+ candidate.

**OQ-20-3 — Cozy reveal animation**
Currently the screen renders all fields immediately on enter. A staggered reveal (gold, then kills, then floors) over 1–2 seconds would feel more ceremonial — like "see what happened, one beat at a time". Sprint 14+ UX polish; UX pass needed for the staging.

**OQ-20-4 — Sound design for the screen entrance**
Currently no dedicated cue plays on Return-to-App entry. Audio-system.md §C.3 specifies `music_floor_clear_stinger` for floor-clear moments; could add a `music_offline_summary_stinger` for this entrance. Sprint 14+ audio polish (ties into S14-M1 sourcing decision).

**OQ-20-5 — Multi-replay UX**
If V1.0+ adds multi-replay-per-session (debug menu, time-travel feature), the screen re-renders correctly per AC-20-08. But the player might need to know "this is your 2nd replay" — currently no UX for that. Sprint 16+ if the feature lands.

**OQ-20-6 — Skip animation for accessibility**
S12-S2 reduce_motion clamps standard transitions to 50ms. The Return-to-App entry SLIDE_DOWN inherits the clamp; if reduce_motion is on, the screen appears in 50ms instead of 150ms. Test coverage exists. No special handling.

---

## J. Implementation Sequencing (already done — reverse-documentation)

The screen was implemented in Sprint 13 S13-M2 (commit `2648492`):
- `assets/screens/return_to_app/return_to_app.gd` (replaces stub; ~270 lines)
- `assets/screens/return_to_app/return_to_app.tscn` (PanelContainer + VBoxContainer layout)
- `OfflineProgressionEngine._last_summary` cache + `last_summary()` getter (added in same commit)
- OE `run_offline_replay` post-emit auto-route to `return_to_app` (gated by MainRoot null-check + `seconds_credited > 0`)
- `assets/locale/en.csv`: 8 new locale keys
- `tests/integration/return_to_app/return_to_app_screen_test.gd`: 13 tests / 13 PASS

No further implementation needed for the screen itself. Outstanding amendments:
1. **Sprint 14+** (~0.25d) — Add hero_levels_gained row when HeroLeveling GDD #15 Story 4 populates the field.
2. **Sprint 14+** (~0.5d) — Persist `_last_summary` per OQ-20-2 (Pillar 1 hardening).
3. **Sprint 14+ UX polish** (~0.5d) — Staggered reveal animation (OQ-20-3) — needs UX pass.
4. **Sprint 14+ audio polish** (~0.25d) — `music_offline_summary_stinger` cue + AudioRouter wiring (OQ-20-4) — depends on S14-M1 sourcing decision.

Total post-GDD work: ~1.5d. None of this gates MVP shipping; the screen is functionally complete.

---

## Notes

- Authored 2026-05-06 by autonomous-execution session as REVERSE-DOCUMENTATION of the screen shipped in Sprint 13 S13-M2 (`2648492`). The GDD's purpose is to formalize the contract that's already in source.
- Run `/design-review` to surface drift between this GDD and the live implementation. Expected verdict: CONCERNS rather than NEEDS REVISION (the implementation is correct; the documentation is the artifact).
- Closes the design-coverage gap that's existed since project inception. systems-index.md row 20 ("Not Started" since Sprint 1) flips to DRAFT.
- Continues the Sprint 13-S14 prep autonomous-execution session: 5 first-pass GDDs drafted (Settings #30, Hero Leveling #15, Onboarding #29, UI Framework #18, Return-to-App #20). Each unblocks a downstream dep that's been silently blocked since project inception.
