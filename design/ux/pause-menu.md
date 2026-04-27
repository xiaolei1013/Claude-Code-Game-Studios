# UX Spec: Pause Menu

> **Status**: In Design (drafted 2026-04-25 in auto mode for Sprint 4 S4-M2)
> **Author**: solo dev (acting as ux-designer)
> **Last Updated**: 2026-04-25
> **Journey Phase(s)**: Mid-session (any time during Guild Hall / Dungeon Run / sub-screens)
> **Template**: UX Spec
> **Sprint**: 4 (S4-M2, Must Have)

---

## Purpose & Player Need

The pause menu is the **trapdoor exit** — a calm, always-reachable overlay
that lets the player step away, change settings, or quit without losing
progress. It is NOT a "freeze the game" button in the traditional action-game
sense; the underlying tick continues to accumulate per ADR-0005 dual-clock
contract, and offline accumulation per Pillar 1 (Respect the Player's Time)
is preserved.

The player arrives at this screen wanting to: **stop interacting with the
game without quitting, OR access settings, OR quit cleanly.**

This game has no fail state and no time-pressured moments — pause is
primarily a settings/quit gateway, not a tactical breather.

---

## Player Context on Arrival

Three distinct arrival contexts:

1. **Settings access** (most common): player wants to change a setting
   (volume, text size, accessibility) without leaving their current screen.
2. **Step-away** (medium frequency): something interrupted them — phone
   call, doorbell, kid; they want to mark "I'm not actively playing right
   now" without quitting.
3. **Quit-to-main-menu** (rare): player wants to start a fresh session view
   or close the app properly with a save flush.

In all three cases the player is calm. There is no "stressed" pause context
because there's no urgency to pause from. This is the cozy-fantasy idle
identity — pause is a gentle off-ramp, not a tactical retreat.

---

## Navigation Position

This screen lives at: **any in-session screen → pause menu (overlay)**.

Pause is a modal overlay — it does NOT replace the underlying screen, it
sits on top of it. The underlying screen is dimmed (~40% opacity) and
remains visible behind the pause modal. This preserves spatial continuity
("the game is still here, I'm just on top of it").

Pause is reachable from:
- Guild Hall main screen
- Dungeon Run view
- Recruit screen
- Roster screen
- Formation Assignment screen
- Return-to-App screen (offline rewards collection)

Pause is NOT reachable from:
- Main menu (no "pause" while at the front door — Quit closes the app or returns to Continue)
- Settings screen (settings opens AS a sub-screen of pause; pausing while in settings would be redundant)
- Save migration modal (uninterruptible)

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Any in-session screen | Tap pause button (HUD top-right) | Current screen state preserved underneath |
| Any in-session screen | Esc key (shortcut) | Same as button |
| OS application paused (mobile) | NOTIFICATION_APPLICATION_PAUSED | Auto-pause; no UI shown — TickSystem freezes ticks per S1-N2; pause menu appears on resume |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Underlying screen (resume) | Tap "Resume" + tap outside modal + Esc + tap pause button again | Tick emission resumes; offline accumulation continues from where it paused |
| Settings screen | Tap "Settings" | Settings overlays pause; back from settings returns to pause |
| Main menu | Tap "Quit to main menu" + confirm | Save flushed; current session unwound; main menu shown |
| Underlying screen (resume after settings change) | Settings closed | Pause menu reappears with confirmation that change was saved; player resumes from there |

No one-way exits. Every path back is reachable.

---

## Layout Specification

### Information Hierarchy

In priority order:

1. **Resume** — the dominant CTA. Most pause sessions end in resume; the
   player should feel the off-ramp back to play is one click away.
2. **Pause status indicator** — small text confirming "Game paused." This is
   the cozy reassurance that the world isn't ticking forward without them.
3. **Settings** — secondary action.
4. **Quit to main menu** — secondary action.
5. **Session info (small)** — current biome, current floor, gold balance —
   for orientation when player has been away from the game and forgotten
   what they were doing.

The hierarchy reflects the design pillar (Pillar 1: Respect the Player's
Time) — pause is a brief moment, not a deep menu dive.

### Layout Zones

```
+---------------------------------------------------------------+
|  [DIMMED UNDERLYING SCREEN — 40% OPACITY, NON-INTERACTIVE]    |
|                                                               |
|       +-------------------------------------------+           |
|       |                                           |           |
|       |          [HEADER ZONE]                    |           |
|       |          "Game Paused"                    |           |
|       |          (small, calm, lantern-gold)      |           |
|       |                                           |           |
|       +-------------------------------------------+           |
|       |                                           |           |
|       |          [PRIMARY CTA ZONE]               |           |
|       |          [    RESUME    ] (large)         |           |
|       |                                           |           |
|       +-------------------------------------------+           |
|       |                                           |           |
|       |          [SECONDARY ACTIONS ZONE]         |           |
|       |          [Settings]   [Quit to menu]      |           |
|       |                                           |           |
|       +-------------------------------------------+           |
|       |                                           |           |
|       |          [STATUS ZONE — small]            |           |
|       |          Floor 3 — 2,400 gold             |           |
|       |                                           |           |
|       +-------------------------------------------+           |
|                                                               |
+---------------------------------------------------------------+
```

Zone roles:
- **Header**: cozy status reassurance ("Game Paused") — no aggressive language
- **Primary CTA**: the single large Resume button
- **Secondary Actions**: Settings + Quit to main menu, side-by-side, equal weight
- **Status**: orientation footer (current biome/floor/gold) for returning-from-distraction context

The modal is centered both horizontally and vertically. Underlying screen is
dimmed but visible (preserves spatial continuity per Visual Identity Anchor's
"warm miniature you want to pick up" — the game is still there).

### Component Inventory

| Zone | Component | Type | Pattern (existing/new) |
|---|---|---|---|
| Background | Dim overlay | Full-screen translucent layer | NEW: `modal-dim-overlay` (add to library) |
| Header | "Game Paused" label | Static text | Existing: `header-label` |
| Primary CTA | Resume button | Large primary button | Existing: `primary-cta-button` (same as main menu) |
| Secondary | Settings button | Medium secondary button | Existing: `secondary-action-button` |
| Secondary | Quit to main menu button | Medium secondary button | Existing: `secondary-action-button` |
| Status | Biome / Floor / Gold compact line | Read-only orientation strip | NEW: `compact-status-strip` (add to library) |

NEW patterns flagged:
- `modal-dim-overlay`: standardized 40% opacity overlay used for any modal overlay (pause, settings, confirmations)
- `compact-status-strip`: read-only orientation strip used in modal contexts to remind player of current game state

### ASCII Wireframe

```
+----------------------------------------------------------+
|                                                          |
|  (faded Guild Hall in background, 40% opacity)           |
|                                                          |
|    +---------------------------------------------+       |
|    |                                             |       |
|    |              Game Paused                    |       |
|    |              (warm gold, small)             |       |
|    |                                             |       |
|    |                                             |       |
|    |          +-----------------+                |       |
|    |          |                 |                |       |
|    |          |     RESUME      |                |       |
|    |          |                 |                |       |
|    |          +-----------------+                |       |
|    |                                             |       |
|    |                                             |       |
|    |     [Settings]      [Quit to main menu]     |       |
|    |                                             |       |
|    |                                             |       |
|    |     Floor 3: Wolf Hollow  -  2,400 gold     |       |
|    |     (small, dim, orientation only)          |       |
|    |                                             |       |
|    +---------------------------------------------+       |
|                                                          |
+----------------------------------------------------------+
```

Modal dimensions: ~400px × 350px on 1280×800 canvas; scales with UI size
setting per accessibility tier.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default** | Pause invoked | Modal visible; underlying screen dimmed; tick emission paused |
| **Loading — saving on quit** | Quit to main menu confirmed; save in progress | Status zone replaces with "Saving your guild's progress…" with small progress indicator; Resume + Settings + Quit disabled until save completes |
| **Confirm — quit to main menu** | Quit tapped | Inline modal: "Quit to main menu? Your progress is auto-saved." [Yes / Cancel] |
| **Settings overlay** | Settings tapped | Settings screen overlays pause modal; pause stays active (tick still paused); back from settings returns to pause modal |
| **Auto-pause from OS** | OS background notification (mobile) | Pause modal NOT shown — OS handles UI; tick freezes per S1-N2; on app resume, pause menu appears with text "Welcome back — your game was paused while you were away." Tap Resume to continue. |
| **Animation — modal enter** | Pause invoked | Modal scales from 0.92 to 1.0 over 200ms + fades in; underlying screen dims over same 200ms |
| **Animation — modal exit (resume)** | Resume tapped | Modal fades out + scales to 0.92 over 200ms; underlying screen restores opacity over same 200ms |

---

## Interaction Map

Input methods (per `.claude/docs/technical-preferences.md`): Mouse primary;
Touch full parity; Keyboard shortcuts only. No gamepad.

| Action | Mouse | Touch | Keyboard | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| Resume | Click button | Tap button | Esc OR Enter | Button press anim + warm-tone click | Modal exits; underlying screen restores; tick emission resumes |
| Tap outside modal | Click on dim overlay | Tap on dim overlay | n/a | Modal exit anim plays | Resume (treat tap-outside as "I changed my mind, keep playing") |
| Settings | Click | Tap | S key | Button press anim + neutral tap | Settings screen overlays pause; pause stays active |
| Quit to main menu | Click | Tap | Q key | Button press anim + warning-tone tap | Confirm modal: "Quit to main menu? Your progress is auto-saved." Yes saves + exits to main menu; No returns to pause |
| Status zone | n/a | n/a | n/a | None (read-only) | None |

**Touch-specific**: tap-outside-modal is the touch-friendly version of "press
Esc to dismiss". On mouse, click-outside also dismisses (standard modal
pattern).

**Tap target minimum size**: 44×44 logical pixels (mobile parity).

**No gamepad**: per `technical-preferences.md` ("Gamepad Support: None — idle
game UX is click/tap-driven").

---

## Events Fired

| Player Action | Event Fired | Payload |
|---|---|---|
| Pause invoked | `pause_menu_opened` | `{ source_screen: String, hours_into_session: float, current_floor: int }` |
| Resume tapped | `pause_menu_resumed` | `{ pause_duration_seconds: int }` |
| Settings tapped | `pause_menu_settings_opened` | none |
| Quit to main menu confirmed | `pause_menu_quit_to_main_confirmed` | `{ pause_duration_seconds: int, session_duration_seconds: int }` |
| Auto-pause from OS | `pause_auto_invoked_by_os` | `{ source: "os_background"\|"window_focus_lost" }` |
| Tap-outside-modal dismissal | `pause_menu_dismissed_by_tap_outside` | none (counts as Resume in analytics) |

`pause_menu_quit_to_main_confirmed` modifies persistent game state (save
flush) — **flag for architecture team**: ensure SaveLoadSystem treats this as
a clean-shutdown save, not a heartbeat or scene-boundary save.

---

## Transitions & Animations

| Transition | From | To | Duration | Notes |
|---|---|---|---|---|
| Pause enter | Underlying screen | Pause modal | 200ms (modal scale 0.92→1.0 + fade-in; underlying dim 0%→40%) | Reduced-motion: 50ms fade |
| Pause exit (resume) | Pause modal | Underlying screen | 200ms (modal scale 1.0→0.92 + fade-out; underlying undim 40%→0%) | Reduced-motion: 50ms fade |
| Settings overlay enter | Pause modal | Settings | 250ms (settings slides up from bottom, pause modal stays in place but de-emphasized) | Reduced-motion: instant overlay |
| Settings overlay exit | Settings | Pause modal | 250ms (settings slides down) | Reduced-motion: instant |
| Quit confirmation enter | Pause modal | Confirm sub-modal | 200ms (sub-modal fades in atop pause modal) | Reduced-motion: 50ms cut |
| Quit save-in-progress state | Confirm yes | Saving label | Instant (no animation; just text swap) | n/a |
| Quit complete → main menu | Save complete | Main menu | 400ms warm-glow wipe (matches main-menu enter from save) | Reduced-motion: 100ms cut |

All transitions respect `reduce_motion` preference.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Current biome name | DungeonRunOrchestrator (or BiomeDungeonDatabase via current floor) | Read | For status zone |
| Current floor index | DungeonRunOrchestrator | Read | For status zone |
| Current gold balance | Economy.get_gold_balance() | Read | For status zone |
| Pause state (active/inactive) | New: PauseManager (or inline in scene-manager) | Read + Write | Pause invocation flips this; consumers (TickSystem, ambient audio) listen |
| Quit-save in progress | SaveLoadSystem state | Read | Drives "Saving your guild's progress…" loading state |

**Architecture concern (flag for review)**: pause state needs a system that
can broadcast "pause active" to TickSystem (to suppress tick_fired emission)
and to audio (to fade ambient). Sprint 1 S1-N2 already handles
NOTIFICATION_APPLICATION_PAUSED for OS-driven pause; user-driven pause via
this menu needs a parallel signal path. Recommended: PauseManager singleton
emits `pause_state_changed(is_paused: bool)`; TickSystem subscribes and gates
its emission timer. Sprint 5 candidate.

The status zone is READ-ONLY — pause menu must not mutate game state apart
from its own active/inactive flag and the explicit quit-save action.

---

## Accessibility

Target tier: **Standard**.

| Requirement | Implementation |
|---|---|
| Keyboard-only navigation | Tab order: Resume → Settings → Quit → wraparound. Esc invokes Resume from any focus. Enter activates focused button. |
| Adjustable text size | All text scales with global UI size setting; modal dimensions auto-resize |
| Color-independent communication | Resume is "large + lantern-gold"; Settings/Quit are "icon + label"; saving state uses an icon (small spinner) AND text — not color alone |
| Reduced motion | Disables modal scale anim; replaces enter/exit with instant fades |
| Subtitle support | n/a (no voiced content) |
| No timed inputs | Pause is fully user-controlled; no auto-resume; no input timeouts |
| Colorblind-mode | Modal accent uses same lantern-gold as main menu; alternate desaturated-gold for ≥4.5:1 contrast |
| Focus trap | Pause modal is a focus trap — Tab cycles only within the modal; Tab cannot escape to underlying screen elements (which are non-interactive while paused) |
| **Tap-outside-to-dismiss** is a discoverability concern | Mitigation: include "Tap outside to resume" hint text under the Resume button, optionally hideable via "I get it" button after first dismissal |

**Open accessibility question**: the focus trap behavior is critical for
keyboard users — verify that Esc behaves as Resume (not "exit modal without
saving" or any other escape semantics). Recommended: Esc = Resume always; no
other Esc behaviors on this screen.

---

## Localization Considerations

| Element | Concern | Priority |
|---|---|---|
| "Game Paused" header | German `Spiel pausiert` (14 chars vs English 11); fits | LOW |
| "Resume" button label | French `Reprendre` (9 chars vs English 6); fits | LOW |
| "Quit to main menu" label | German `Zum Hauptmenü` (14 chars); long but fits in button | MEDIUM — verify on smallest target (Steam Deck portrait if portrait-supported) |
| "Quit to main menu? Your progress is auto-saved." | ~50 chars in English; ~70 in German; line-wraps to 2 lines | MEDIUM |
| "Saving your guild's progress…" | Mid-sentence wrap; ICU handles fine | LOW |
| Status zone: "Floor 3 — 2,400 gold" | Number formatting (locale-aware thousands separators); floor name is from biome data | LOW — biome names are in entity registry |

No element is layout-critical at the modal level — the modal can grow
slightly to accommodate longer text, since it's centered overlay.

---

## Acceptance Criteria

- [ ] Pause menu opens within 150ms of pause button tap or Esc keypress
- [ ] Modal renders centered and proportional at 1280×800 (Steam Deck), 1920×1080 (PC default), and at 100% / 125% / 150% UI size settings
- [ ] Resume button is the visually dominant element (≥3× area of Settings + Quit combined)
- [ ] Tapping outside the modal (on the dimmed underlying area) invokes Resume
- [ ] Esc key invokes Resume from any focus state inside the modal
- [ ] Tab order cycles: Resume → Settings → Quit → wraparound (no escape to underlying screen)
- [ ] Quit to main menu requires explicit confirmation — no one-tap quit
- [ ] When paused, TickSystem stops emitting `tick_fired` (verified via signal-spy in integration test)
- [ ] When resumed, TickSystem resumes emitting `tick_fired` at 20 Hz (verified via signal-spy)
- [ ] Underlying screen is dimmed to ~40% opacity (visually verifiable)
- [ ] Status zone displays current biome name + floor index + gold balance — read-only, accurate to current state
- [ ] Reduced-motion setting replaces modal scale anim with instant fades
- [ ] All text scales with global UI size setting (verified at 100% / 125% / 150%)
- [ ] OS-driven auto-pause (mobile NOTIFICATION_APPLICATION_PAUSED, desktop window-focus-lost) does NOT show this menu — it auto-resumes when app foregrounds
- [ ] All analytics events fire exactly once per occurrence
- [ ] During quit-save, all menu buttons are disabled (no double-quit, no settings during save flush)

---

## Open Questions

1. **PauseManager singleton vs inline-in-scene-manager**: should pause be its own autoload (rank ~7 between Core and Feature) or a property on the SceneManager? Recommended: PauseManager singleton — cleaner separation; subscribers (TickSystem, audio) need a stable signal source independent of scene transitions. Architecture review needed in Sprint 5.
2. **"Status zone" data display when DungeonRunOrchestrator hasn't loaded yet**: in early-session contexts (Guild Hall before any run), there is no current floor. Recommended: hide the status zone entirely when no run is active; the modal becomes shorter and no information is faked.
3. **Quit-save vs heartbeat-save semantic**: ADR-0004 distinguishes full-envelope (scene-boundary) vs heartbeat (in-flight) saves. A user-invoked quit-to-main-menu should be FULL envelope (clean shutdown). Verify with Save/Load epic owner before Sprint 4 S4-M3 lands.
4. **Pause during offline replay**: if the player invokes pause while OfflineProgressionEngine is still chunking through a long replay (e.g., 8h offline cap), should pause halt the replay or let it complete in the background? Per ADR-0014, replay completes in chunks with `await get_tree().process_frame` yields; pausing the tree pauses the replay. Recommended: allow it; show a small "Computing offline rewards…" indicator in the status zone if active. Verify with ADR-0014 owner in Sprint 4-5.
5. **Ambient audio during pause**: should ambient audio fade or continue? Audio system blocked (ADR-C03 unauthored). Defer.
6. **Discoverability of tap-outside-to-dismiss**: first-launch users may not realize tap-outside dismisses the modal. Recommended: small italic hint text ("Tap anywhere outside to resume") under the Resume button on first 3 invocations, then hide.

---

## Acceptance verification path

This spec passes when `/ux-review design/ux/pause-menu.md` returns APPROVED
or NEEDS REVISION (with revisions accepted). Required for Sprint 4 S4-M2
close.

Cross-references this spec emits:
- New patterns flagged for `design/ux/interaction-patterns.md`: `modal-dim-overlay`, `compact-status-strip`
- Architecture concern: PauseManager singleton needed; flag for ADR-X-PauseManager (Sprint 5 architecture work)
- Cross-system concern: pause state must be subscribable by TickSystem and (later) audio; design the signal path before Sprint 5 PauseManager implementation
- Localization concern: German "Quit to main menu" label length verification on smallest target (Steam Deck portrait if supported)
