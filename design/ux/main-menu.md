# UX Spec: Main Menu

> **Status**: In Design (drafted 2026-04-25 in auto mode for Sprint 4 S4-M1)
> **Author**: solo dev (acting as ux-designer)
> **Last Updated**: 2026-04-25
> **Journey Phase(s)**: Pre-session (every launch); Re-engagement (returning after 1+ idle hours)
> **Template**: UX Spec
> **Sprint**: 4 (S4-M1, Must Have)

---

## Purpose & Player Need

The main menu is the **front door** to a session-based idle game. Its job is
to deliver the player to the playing surface in **one tap or click** for
returning sessions, while still serving as a respectful onboarding for the
first-time launch and a mute-and-quit point for unplanned exits.

The player arrives at this screen wanting to: **resume their guild and see
what accumulated while they were away.**

If the menu fails its job, retention craters — the #1 risk per
`design/gdd/game-concept.md` line 222 ("if the first-return feel isn't
satisfying, retention craters immediately"). The main menu sits directly in
the path of every return-to-app moment.

---

## Player Context on Arrival

Three distinct arrival contexts:

1. **First launch** (Day 1, Session 1): player has just installed the game;
   curious but uncommitted; expects a friendly door, not a wall of options.
2. **Returning session** (default cadence: 2-4× per day): player has been
   away for 1-12 hours; their mental model is "let me see what I earned";
   they expect minimal friction between launch and the offline-rewards
   moment.
3. **Returning after extended absence** (>24h): player may have forgotten
   their roster composition; needs a calm orientation moment, not a
   high-energy "WELCOME BACK!" cascade.

Voluntary arrival (not redirected). Players are calm in case 2 + 3, mildly
curious in case 1. Time-pressured for case 2 (cozy idle is fit-into-2-min;
slow main menu defeats the purpose).

---

## Navigation Position

This screen lives at: **app launch → main menu**.

It is a top-level destination — always reachable via the title screen on
fresh launch, and reachable from the pause menu via "Quit to main menu"
(which prompts a save first).

There is no "deeper" hub above the main menu; this IS the hub from which
all other screens descend.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| App launch (cold start) | Engine boot completes; SaveLoadSystem reaches READY | Save loaded if exists; otherwise fresh state |
| Pause menu → Quit to main menu | Player taps "Quit to main menu" + confirms save | Active session saved |
| Settings screen → back | Player taps back | Same state as before settings |
| First-launch tutorial completion | Tutorial finish event | Initial save state; first-time guild seeded |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Guild Hall (the playing surface) | Tap "Continue" / "Play" | If saved game exists, opens Guild Hall directly with offline rewards already pending; if no saved game, drops into first-time tutorial flow |
| Settings screen | Tap "Settings" | Settings screen modal-overlays main menu; back returns here |
| App quit | Tap "Quit" + confirm | Save flushed; OS exit |
| First-time tutorial flow | Tap "New Game" on a fresh install | Bypasses main menu after first completion |

No one-way exits — all paths back are reachable.

---

## Layout Specification

### Information Hierarchy

In priority order (top = highest):

1. **Continue / Play** — the dominant CTA. Returning sessions land here 95% of
   the time. Must be the largest, most visually weighted element on screen.
2. **Game logo / title** — establishes identity for first-launch; smaller
   visual weight on returning sessions.
3. **Pending offline rewards indicator** — optional one-line teaser ("Your
   guild earned 2,400 gold while you were away") shown ABOVE the Continue
   button when offline rewards are pending. Cozy preview, not a number-jam.
4. **Settings / Quit** — secondary; smaller; corner-positioned.
5. **Version display** — bottom-corner; informational; no emphasis.

The hierarchy reflects the design pillar (Pillar 1: Respect the Player's
Time) — the menu prioritizes "let me play" over "let me configure".

### Layout Zones

Four zones on a 1280×800 canvas (Steam Deck native; scales up to 1920×1080):

```
+---------------------------------------------------------------+
|                          [LOGO ZONE]                          |
|              Game title + lantern-glow background             |
|                                                               |
+---------------------------------------------------------------+
|                                                               |
|              [PRIMARY CTA ZONE — vertical center]             |
|                                                               |
|              "Your guild earned 2,400 gold while               |
|               you were away" (offline rewards line)           |
|                                                               |
|              [   CONTINUE   ] (large, golden, lantern-lit)    |
|                                                               |
|              "New Game" (text link, smaller, only if no save) |
|                                                               |
+---------------------------------------------------------------+
|  [Settings]                                          [Quit]   |
|  (bottom-left)                                  (bottom-right)|
+---------------------------------------------------------------+
|                                              v0.1.0-alpha.1   |
+---------------------------------------------------------------+
```

Zone roles:
- **Logo Zone** (top 30%): identity + warmth; lantern-gold glow per Visual Identity Anchor
- **Primary CTA Zone** (middle 50%): single dominant action + optional reward teaser
- **Bottom Bar** (bottom ~15%): secondary actions positioned to NOT compete with primary CTA
- **Footer** (bottom edge ~5%): version + small build info

### Component Inventory

Per zone:

| Zone | Component | Type | Pattern (existing/new) |
|---|---|---|---|
| Logo | Title image | Static texture | Existing: `static-illustration` |
| Logo | Lantern-glow backdrop | Animated subtle (2-frame loop OK) | NEW: `lantern-glow-backdrop` (add to library) |
| Primary CTA | Offline rewards teaser line | Conditional text label | Existing: `flavor-text-line` |
| Primary CTA | Continue button | Large primary button | Existing: `primary-cta-button` |
| Primary CTA | New Game text link | Tertiary text link | Existing: `tertiary-text-action` |
| Bottom Bar | Settings button | Secondary icon-button | Existing: `secondary-icon-button` |
| Bottom Bar | Quit button | Secondary icon-button | Existing: `secondary-icon-button` |
| Footer | Version label | Static text | Existing: `meta-info-label` |

NEW pattern flagged: `lantern-glow-backdrop` — a slow-loop ambient backdrop
animation (≤ 2 fps cycle, ≤ 5% screen-area coverage variance) intended
exclusively for ambient warmth zones. Add to interaction-patterns.md when
this spec passes review.

### ASCII Wireframe

```
+--------------------------------------------------------------+
|                                                              |
|             *~ Lantern Guild ~*                              |
|          (lantern-glow backdrop, warm)                       |
|                                                              |
|                                                              |
|                                                              |
|        Your guild earned 2,400 gold while you were away      |
|                                                              |
|                                                              |
|             +----------------------+                         |
|             |                      |                         |
|             |       CONTINUE       |                         |
|             |   (lantern-gold)     |                         |
|             |                      |                         |
|             +----------------------+                         |
|                                                              |
|                  New Game (smaller link)                     |
|                                                              |
|                                                              |
|                                                              |
| [Settings ⚙]                                    [Quit ✕]    |
|                                                              |
|                                          v0.1.0-alpha.1      |
+--------------------------------------------------------------+
```

When no save exists (first launch), the layout collapses: the offline rewards
line is hidden, Continue becomes "Play" (and is the same large button), and
the "New Game" tertiary link is also hidden.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default — returning session** | Save exists; offline rewards available | Continue (large) + offline-rewards teaser; New Game (tertiary link) shown |
| **Default — fresh launch** | No save file present | "Play" button (replaces Continue); offline-rewards teaser hidden; New Game tertiary link HIDDEN (Play IS the new game CTA) |
| **Default — same-day return** | Save exists; offline rewards = 0 | Continue (large); offline-rewards teaser hidden; New Game (tertiary link) shown |
| **Loading — initial save read** | App boot in progress; SaveLoadSystem still LOADING | Logo + lantern glow visible; Continue button replaced by "Loading…" placeholder; bottom bar dimmed |
| **Error — save corrupted** | SaveLoadSystem returned ERROR or HMAC mismatch | Continue button replaced by "Save corrupted — start new game?" (warm red, NOT alarming); offers "New Game (recommended)" + "Try recovery" link to restore from .bak per ADR-0004 |
| **Error — save migration in progress** | Schema version mismatch detected | Cozy modal: "Updating your guild's records…" with progress bar; blocks all interaction until migration completes |
| **Animation — lantern glow** | Always when on screen | Subtle 4-second-cycle warm intensity wave; respects reduced-motion preference (drops to static glow) |
| **Animation — offline rewards arrival** | Returning session with rewards | Offline-rewards teaser line fades in over 600ms after Continue button settles, with a single soft warm-tone sting |

---

## Interaction Map

Input methods (per `.claude/docs/technical-preferences.md`): Mouse primary;
Touch full parity; Keyboard shortcuts only. No gamepad.

| Action | Mouse | Touch | Keyboard | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| Tap Continue / Play | Click | Tap | Enter | Button press anim (50ms) + warm-tone click sound | Transitions to Guild Hall (or first-time tutorial if fresh) |
| Tap Settings | Click | Tap | S key (shortcut) | Button press anim + neutral tap sound | Opens Settings as modal overlay |
| Tap Quit | Click | Tap | Esc key (shortcut) | Button press anim + neutral tap sound | Confirm modal: "Quit to desktop?" Yes saves and exits; No returns |
| Tap New Game (when save exists) | Click | Tap | N key (shortcut) | Button press anim + warning-tone tap sound | Confirm modal: "Start a new guild? This will overwrite your saved progress." Yes wipes save and opens tutorial; No returns |
| Tap version label | Click | Tap | None | None | None (cosmetic info — no interaction) |

**Hover states (mouse only)**: every interactive element has a subtle warm-glow
hover state lasting as long as the cursor remains. Touch shows no hover state
(per `technical-preferences.md`: "No hover-only interactions" rule).

**Tap target minimum size**: 44×44 logical pixels per `technical-preferences.md`
(mobile parity target). Continue button is significantly larger; Settings/Quit
icons fill 56×56 minimum to clear the bar.

---

## Events Fired

| Player Action | Event Fired | Payload |
|---|---|---|
| Screen entered | `main_menu_opened` | `{ has_save: bool, hours_since_last_session: int }` |
| Continue / Play tapped | `main_menu_continue_tapped` | `{ pending_offline_gold: int }` (0 if none) |
| Settings tapped | `main_menu_settings_opened` | none |
| Quit tapped + confirmed | `main_menu_quit_confirmed` | `{ session_duration_seconds: int }` |
| New Game tapped + confirmed | `main_menu_new_game_started` | `{ overwrote_existing_save: bool }` |
| Save-corrupted error displayed | `main_menu_save_error_shown` | `{ error_kind: String, recovery_attempted: bool }` |
| Save migration completed | `main_menu_save_migration_completed` | `{ from_version: int, to_version: int, duration_ms: int }` |

`main_menu_new_game_started` modifies persistent game state (wipes save) —
**flag for architecture team**: ensure SaveLoadSystem treats this as an
explicit "new game" intent, not a corrupted-save fallback. Per ADR-0004,
the .bak rotation should NOT preserve the wiped save (different intent).

---

## Transitions & Animations

| Transition | From | To | Duration | Notes |
|---|---|---|---|---|
| Enter (cold start) | App boot | Main menu visible | 600ms fade-in (logo first, then CTA, then bottom bar; staggered 100ms each) | Reduced-motion: instant |
| Enter (from settings) | Settings closed | Main menu visible | 200ms fade-in | Reduced-motion: instant |
| Exit to Guild Hall | Continue tapped | Main menu fades out | 400ms warm-glow wipe (lantern flares brighter, then fades white) | Reduced-motion: 100ms cut-fade |
| Exit to Settings | Settings tapped | Main menu dims | 250ms (main menu loses 30% opacity; settings overlays from bottom) | Reduced-motion: instant overlay |
| Quit confirm modal appear | Quit tapped | Modal visible | 200ms (modal scales from 0.9 to 1.0 + fades in) | Reduced-motion: 50ms cut |
| Lantern-glow ambient | Always | Always | 4-second cycle | Disabled when reduced-motion ON |
| Offline-rewards teaser | Save loaded | Visible | 600ms fade-in (after Continue settles) | Reduced-motion: 200ms fade |

All transitions respect `reduce_motion` preference (per ADR-0007 OQ-7
deprecated reduced-motion settings; user setting persisted via Save/Load).

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Save file presence | SaveLoadSystem | Read | Determines Default vs Fresh-Launch state |
| Pending offline gold | OfflineProgressionEngine OR cached estimate | Read | If full offline replay hasn't run yet, show "calculating…" placeholder; full number arrives when replay completes |
| Hours since last session | TickSystem.get_last_persist_ts | Read | For analytics + reduce/keep teaser line |
| Schema version | SaveLoadSystem (envelope header) | Read | Triggers migration-modal state if mismatch |
| Game version (for footer) | Project config (compile-time) | Read | Static |

The offline-rewards teaser is presented BEFORE the full Guild Hall
transition for emotional pacing — the player should taste the reward before
they see the full collection screen. This requires either an O(1) drip
estimate (per ADR-0014 §closed-form math) or a "calculating…" placeholder if
the full replay is still chunking.

**Architecture concern (flag for review)**: the main menu reads
`OfflineProgressionEngine`'s in-progress replay state. ADR-0014 specifies
the engine yields the main thread between chunks via `await
get_tree().process_frame` — but the cozy-modal threshold (100ms) per
ADR-0014 means the main menu MUST handle the case where the replay is still
running on first paint. Recommended pattern: show "calculating…" placeholder;
swap to actual number when `offline_rewards_collected` signal fires.

---

## Accessibility

Target tier: **Standard** (per `design/accessibility-requirements.md`).

| Requirement | Implementation |
|---|---|
| Keyboard-only navigation | Every interactive element reachable via Tab; visible focus indicator (warm-amber outline ≥ 2px); Enter / Space activates focused element |
| Adjustable text size | Title, button labels, footer all scale with the global UI size setting (per accessibility-requirements.md scaling factor) |
| Color-independent communication | Continue is "large + lantern-gold glow"; Settings/Quit are "icon + label"; save-corrupted error uses an icon (warning triangle) AND warm-red text — not color alone |
| Reduced motion | Disables lantern-glow ambient + screen transitions; replaces with instant cuts |
| Subtitle support | Not applicable — no voiced content on this screen |
| No timed inputs | All actions are user-initiated; no auto-dismiss; no input timeouts |
| Colorblind-mode (≥1 mode) | The "lantern-gold" Continue accent has an alternate desaturated-gold version that contrasts ≥ 4.5:1 against background per WCAG AA (deuteranopia + protanopia tested) |
| Screen reader (Comprehensive — out of scope) | OUT OF SCOPE for Standard tier; flagged for Comprehensive upgrade if accessibility tier rises |

**Open accessibility question**: should the lantern-glow ambient be tied to
`reduce_motion` or to a separate "ambient effects" toggle? Reduced-motion is
typically about vestibular triggers, not ambient warmth. **Recommended**: keep
under reduced-motion for Standard tier; offer separate "ambient effects"
toggle if Comprehensive tier is later targeted.

---

## Localization Considerations

| Element | Concern | Priority |
|---|---|---|
| "Continue" button label | German `Fortsetzen` (10 chars) vs English `Continue` (8 chars) — fits | LOW |
| "Your guild earned X gold while you were away" | German + French expansion ~40% — line wrap to 2 lines OK | MEDIUM — verify wrap doesn't push the Continue button below safe-zone on Steam Deck portrait orientation |
| "Save corrupted — start new game?" | Multi-clause; expansion to ~50 chars in German; line wrap acceptable | MEDIUM |
| Number formatting (gold values) | EU locales use `.` for thousands separator; format via locale-aware integer formatter | LOW |
| Time-since-last-session ("3 hours ago") | Pluralization rules vary; use ICU MessageFormat | MEDIUM |

No element is layout-critical — all text can wrap. Title image is image asset,
not localized text (the game name "Lantern Guild" is the canonical English
name; if a market requires localization, separate art-spec work).

---

## Acceptance Criteria

- [ ] Main menu opens within 800ms of app launch on min-spec hardware (per `production/qa/minimum-spec.md`)
- [ ] Layout renders correctly at 1280×800 (Steam Deck native), 1920×1080 (PC default), and at 100% / 125% / 150% UI size settings (resolution + scale matrix)
- [ ] Continue button is the visually dominant element (3× area of Settings + Quit combined)
- [ ] When a save exists, offline-rewards teaser appears within 1500ms of menu open (or "calculating…" placeholder if replay is still chunking)
- [ ] When no save exists, "New Game" tertiary link is HIDDEN (Play button is the only path forward)
- [ ] Quit + New Game both show explicit confirmation modals — neither is a one-tap destructive action
- [ ] Save-corrupted state offers BOTH "New Game (recommended)" AND "Try recovery" — the player chooses, not the system
- [ ] All interactive elements reachable via Tab navigation in this order: Continue → Settings → Quit → version footer (skip if non-interactive) → wraparound
- [ ] All text scales with global UI size setting from accessibility settings (verified at 100% / 125% / 150%)
- [ ] Reduced-motion setting disables lantern-glow ambient + replaces enter/exit transitions with instant cuts
- [ ] Save-migration modal is uninterruptible until migration completes — no Quit shortcut bypasses it (data integrity)
- [ ] All analytics events fire exactly once per occurrence (verified via event-spy in integration test)

---

## Open Questions

1. **First-launch onboarding split**: should "New Game" on first launch immediately drop into a tutorial, or should there be a brief intro overlay first? Recommended: skip intro overlay on Day 1 (Pillar 1 — respect time); the tutorial IS the first session.
2. **"Continue" copy variations**: should the button label change based on context? E.g., "Welcome Back" for >24h absence, "Continue" for typical return, "Resume" for same-session resume after pause-quit? Recommended: keep "Continue" universal — variation adds localization burden + cognitive load. The offline-rewards teaser already provides emotional context.
3. **Ambient audio**: a warm-lamplit menu wants a soft hum of fireflies / crackling distant fire / pages turning. Audio system is blocked (ADR-C03 unauthored). Defer to audio-system epic (Sprint 5+); silence is acceptable in MVP if the visual warmth carries.
4. **Settings shortcut on touch**: keyboard-only games can offer "S" for settings; touch has no equivalent shortcut. Acceptable — settings is reachable via the bottom-bar button.
5. **Steam Deck input layer**: trackpad-as-mouse should work out of the box; verify in playtest pass before MVP ship. Steam Input gamepad mappings → trackpad/touchscreen per project config.

---

## Acceptance verification path

This spec passes when `/ux-review design/ux/main-menu.md` returns APPROVED or
NEEDS REVISION (with revisions accepted). Required for Sprint 4 S4-M1 close.

Cross-references this spec emits:
- New pattern flagged for `design/ux/interaction-patterns.md`: `lantern-glow-backdrop`
- Architecture concern flagged: OfflineProgressionEngine in-progress-replay state read from main menu
- Localization concern: 40% expansion verification on Steam Deck portrait orientation
