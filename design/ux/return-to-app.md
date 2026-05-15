# UX Spec: Return-to-App

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-15
> **Journey Phase(s)**: Re-engagement / Session start after offline window
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/return-to-app-screen.md` (#20); reverse-documented from shipped Sprint 13 S13-M2 implementation
> **Template**: UX Spec

---

## Purpose & Player Need

Return-to-App is the **cozy welcome-back summary** the player sees on cold-launch when offline-elapsed time produced a non-zero offline replay. The screen renders accumulated rewards from the offline window: gold earned, enemies defeated, floors cleared, hero levels gained.

**Player goal on arrival**: *"What did my guild do while I was away?"* — and *"OK, take me back to the game."*

The screen is the **#1 retention surface** per `game-concept.md` line 222: "if the first-return feel isn't satisfying, retention craters immediately." Sprint 14 playtests confirmed the offline-replay → return-screen → guild-hall loop is the single most-touched moment for returning players.

The screen's UX promise: **answer "what happened?" in one glance, then get out of the way**. No dwelling, no upsells, no FOMO. The player taps Continue, lands back on Guild Hall, gold counter already showing the new balance, and resumes the loop.

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **Cold launch after offline window** | Closed the app yesterday / overnight / over the weekend | Curious / mild anticipation — "let's see what my heroes earned" | Numbers prominent, immediate; Continue button reachable |
| **Cold launch — short offline window** | Closed the app 30 min ago | Mild curiosity — "anything from that quick break?" | Same layout; small numbers; no special-case "too short for rewards" message |
| **Cold launch — no offline rewards** | First-ever launch, OR cap-time exceeded with zero credited | n/a — screen NOT shown | The screen is gated on `summary.seconds_credited > 0`; first-launch and zero-credit cases bypass it |
| **Re-enter after first dismissal** | Tapped Continue, then re-entered via dev navigation | n/a — screen NOT shown | One-time per cold-launch; cached summary cleared on dismiss |

The screen is **always a positive beat** — there's always something to show, because the gate excludes empty cases. The player is in receive-mode; the design's job is to deliver the goods quickly.

---

## Navigation Position

Return-to-App is a **special-case session-start screen** — entered automatically on cold-launch when offline rewards exist; exits only to Guild Hall.

```
(cold launch)
  └── (offline replay completes)
        └── Return-to-App  ← THIS SCREEN  (only when summary.seconds_credited > 0)
              └── Continue → Guild Hall
```

The screen sits **between** the offline replay engine's completion and the player's first interactive moment of the session. It is NOT reachable from Guild Hall, Settings, or any other screen.

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|--------------------|
| Auto-route on offline replay completion | `OfflineProgressionEngine.offline_rewards_collected` signal → SceneManager auto-trigger | Cached `OE._last_summary` payload with all reward fields |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Continue → Guild Hall | Tap Continue button | `SceneManager.request_screen("guild_hall", CROSS_FADE)`; cached summary cleared |
| App close | OS home / force-quit | Summary persists (player will see it again on next cold-launch if not yet dismissed) |

No back button. No alternative exits. The screen is a one-shot: see, acknowledge, continue.

---

## Layout Specification

### Information Hierarchy

1. **"While you were away..." header** — establishes the cozy welcome-back framing
2. **Gold earned** — the most-anticipated number; largest visual treatment
3. **Enemies defeated + Floors cleared** — secondary stats; smaller but clearly readable
4. **Hero level-ups (if any)** — list of heroes who leveled up during the offline window
5. **Continue button** — primary CTA; bottom of screen for thumb reach

### Layout Zones

| Zone | Height | Contents |
|------|--------|----------|
| Header | ~80px (~10%) | "While you were away..." identity title |
| Summary panel | flex (~70%) | Gold earned (large) + secondary stats + hero level-up list |
| Continue bar | ~120px (~15%) | Continue button (primary CTA) |

### Component Inventory

**Header zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| HeaderLabel | Label | `tr("return_to_app_header_title")` ("While you were away...") | No | `title-screen` IM Fell English 32px Slate Ink |

**Summary panel zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| SummaryPanel | PanelContainer | Container with all reward rows | No | `panel` variant `parchment-default` |
| OfflineDurationLabel | Label | `tr("return_to_app_duration_format", [formatted_elapsed])` ("Away for 7 hours 23 minutes") | No | `secondary` Lora Regular 14px |
| GoldEarnedRow | HBoxContainer | Coin icon + gold value | No | n/a |
| GoldEarnedIcon | TextureRect | 32×32 coin icon, Lantern Gold | No | n/a |
| GoldEarnedLabel | Label | `tr("return_to_app_gold_earned_format", [gold])` ("+ 1,247 gold") | No | `stat-value` Lora SemiBold 32px Lantern Gold (the headline number; bigger than DESIGN.md's standard `stat-value` 20px) |
| EnemiesDefeatedRow | HBoxContainer | Sword icon + value | No | n/a |
| EnemiesDefeatedLabel | Label | `tr("return_to_app_enemies_format", [count])` ("128 enemies defeated") | No | `body-emphasis` Lora SemiBold 18px Slate Ink |
| FloorsClearedRow | HBoxContainer | Floor icon + value | No | n/a |
| FloorsClearedLabel | Label | `tr("return_to_app_floors_format", [count])` ("4 floors cleared (×2 first-clears)") | No | `body-emphasis` |
| LevelUpsSectionLabel | Label | `tr("return_to_app_level_ups_section_label")` ("Heroes leveled up:") — only visible if any | No | `stat-label` |
| LevelUpRow (×N) | HBoxContainer | Hero name + "Lv X → Lv Y" — one row per hero who leveled | No | `body` Lora Regular 16px |

**Continue bar zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| ContinueButton | Button (primary) | `tr("return_to_app_continue_button")` ("Continue") | Yes | `button` variant `primary` — full-width × 80px, Guild Amber fill, Lora SemiBold 18px |

### ASCII Wireframe

```
┌─────────────────────────────────────────────┐
│         While you were away...              │  ← Header
├─────────────────────────────────────────────┤
│  Away for 7 hours 23 minutes                │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │                                     │   │
│  │         ⬡  + 1,247 gold             │   │  ← Headline
│  │                                     │   │     (32px)
│  │                                     │   │
│  │      ⚔  128 enemies defeated        │   │
│  │      ▭   4 floors cleared (×2 new)  │   │
│  │                                     │   │
│  │  Heroes leveled up:                 │   │
│  │     Theron     Lv 7 → Lv 8          │   │
│  │     Bram       Lv 3 → Lv 4          │   │
│  │                                     │   │
│  └─────────────────────────────────────┘   │
│                                             │
├─────────────────────────────────────────────┤
│          [        Continue        ]         │  ← Action
└─────────────────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **Default — with rewards** | Normal arrival; summary has gold + enemies + floors | Full layout renders; LevelUpsSection visible if any hero leveled |
| **No level-ups** | No hero leveled during the offline window | LevelUpsSection hidden (0px); GoldEarned + EnemiesDefeated + FloorsCleared still shown |
| **Single hero leveled** | One hero leveled once | One LevelUpRow visible |
| **Multiple hero level-ups** | N heroes leveled, possibly multiple times each | N rows; if same hero leveled multiple times, show as "Theron Lv 7 → Lv 9" (range) |
| **Offline cap hit** | Offline window exceeded `OFFLINE_CAP_HOURS` (~8h default) | OfflineDurationLabel shows actual elapsed time with "(rewards capped)" suffix; gold/enemies/floors reflect cap-clamped values |
| **First-launch bypass** | Fresh save (no offline window) | Screen NOT shown (gated by `summary.seconds_credited > 0`) |
| **Zero-credit bypass** | Offline window too short to credit anything | Screen NOT shown (same gate) |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Feedback | Outcome |
|-----------|--------|-------|----------|---------|
| ContinueButton | Tap | Mouse LMB / touch | `sfx_ui_tap` + button press scale pulse | `SceneManager.request_screen("guild_hall", CROSS_FADE)`; cached summary cleared |
| Any other element | Tap | Mouse LMB / touch | No feedback (`mouse_filter = PASS`) | No-op |

**Single CTA design**: only one button on the screen. The player has one decision: continue. No "claim rewards" intermediate step — rewards are already credited to Economy + HeroRoster autoloads before this screen renders. The Continue button only navigates.

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Screen open | `ui_return_to_app_shown` | `{ gold_earned, enemies_defeated, floors_cleared, first_clears, level_ups_count, offline_seconds }` |
| Continue tapped | `ui_return_to_app_continued` | `{ offline_seconds }` |

**No persistent state writes from this screen.** All reward state was already committed by `OfflineProgressionEngine.run_offline_replay` before this screen entered. The screen is display + acknowledgment only.

---

## Transitions & Animations

**Screen enter**: SLIDE_DOWN per SceneManager.TransitionType. ~250ms. The slide-from-above register reinforces "rewards arriving" feel.

**Screen exit**: CROSS_FADE to Guild Hall. ~150ms.

**Gold counter "fly-in"** (optional polish): GoldEarnedLabel starts at 0 and counts up to the final value over 800ms with `ease-out` (per DESIGN.md `enter` curve). This is the reward-moment exception to the 150ms UI budget (per Art Bible §7 — ceremony can run up to 800ms; primary number rendered ≤100ms). Reduce-motion: instant render at final value.

**Hero level-up rows appear** (optional polish): stagger 50ms between rows for the "ledger reveal" feel. Reduce-motion: all visible immediately.

**ContinueButton appearance**: button enabled immediately on screen render — do NOT gate behind animation completion. Player should be able to tap Continue at any moment, even during reward-count animation.

---

## Data Requirements

| Data | Source | Read / Write | Live-updating? | Notes |
|------|--------|--------------|----------------|-------|
| Offline elapsed seconds | `OfflineProgressionEngine._last_summary.seconds_credited` | Read | Static at render | Drives OfflineDurationLabel + duration formatter |
| Gold earned | `_last_summary.gold_delta` (or equivalent field) | Read | Static | Drives GoldEarnedLabel |
| Enemies defeated | `_last_summary.enemies_defeated` | Read | Static | Drives EnemiesDefeatedLabel |
| Floors cleared | `_last_summary.floors_cleared` (Array) | Read | Static | Drives FloorsClearedLabel; count + first-clear-count derived |
| Hero level-ups | `_last_summary.level_ups` (Array of {instance_id, old_level, new_level}) | Read | Static | Drives LevelUpRow list |
| Hero display names | `HeroRoster.get_hero(instance_id).display_name` | Read | Static | Resolved at row-render time |

**No write paths.** The screen is a summary-only surface.

---

## Accessibility

**Committed tier**: Standard.

| Requirement | Implementation |
|-------------|---------------|
| Tap target | ContinueButton: 80px tall × full-width (≥44×44) |
| No color-only indicators | Gold counter uses Lantern Gold for visual emphasis but value is a number; coin icon reinforces meaning |
| Reduce-motion | Gold count-up animation clamps to instant render; level-up row stagger clamps to all-visible-immediately; reward-moment per Art Bible §7 reduce-motion rule |
| Colorblind backup cues | Icons (coin, sword, floor) accompany every reward number; no color-only meaning |
| Text contrast | Slate Ink + Lantern Gold on Parchment Cream; verify ≥4.5:1 (Lantern Gold on Cream is the tightest pair — needs Slate Ink 1px outline per Art Bible §4) |
| Font size floor | All body ≥16px; headline ≥32px; identity ≥32px (the "While you were away..." title) |
| Mouse + touch parity | Single CTA works identically on mouse + touch |
| Screen reader | OfflineDurationLabel + GoldEarnedLabel + LevelUpRow content all readable via Godot AccessKit |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| HeaderLabel (`return_to_app_header_title`) | ~30 chars ("While you were away..." = 21) | LOW | Wraps if needed |
| OfflineDurationLabel (`return_to_app_duration_format`) | ~30 chars ("Away for 7 hours 23 minutes" = 28) | MEDIUM | Localized duration formatting needed (hours/minutes/seconds in target locale) |
| Gold format (`return_to_app_gold_earned_format`) | ~16 chars ("+ 1,247 gold" = 12) | LOW | Number primarily |
| Enemies format (`return_to_app_enemies_format`) | ~25 chars ("128 enemies defeated") | MEDIUM | German "Gegner besiegt" — fits |
| Floors format (`return_to_app_floors_format`) | ~30 chars ("4 floors cleared (×2 new)" = 26) | MEDIUM | "First-clear" terminology may need locale variant |
| Level-up format (`return_to_app_level_up_row_format`) | ~30 chars per row | LOW | Hero name + level range |
| ContinueButton (`return_to_app_continue_button`) | ~12 chars ("Continue" = 8) | LOW | Wide button accommodates |

**HIGH PRIORITY for loc review**: duration formatting — "Away for X hours Y minutes" requires locale-specific time-formatting helper (or fall back to ISO-style "7h 23m" which is language-neutral).

---

## Acceptance Criteria

- [ ] **UX-RTA-01 (layout)**: Header / Summary panel / Continue bar all render at 1280×800 Steam Deck native without scrolling
- [ ] **UX-RTA-02 (gold prominence)**: GoldEarnedLabel is the visually largest element on screen (32px); positioned at the top of SummaryPanel
- [ ] **UX-RTA-03 (gold value)**: GoldEarnedLabel displays the correct `_last_summary.gold_delta` formatted per locale
- [ ] **UX-RTA-04 (enemies)**: EnemiesDefeatedLabel displays the correct `_last_summary.enemies_defeated` count
- [ ] **UX-RTA-05 (floors)**: FloorsClearedLabel displays the correct floor count + first-clear count (e.g., "4 floors cleared (×2 first-clears)")
- [ ] **UX-RTA-06 (duration)**: OfflineDurationLabel displays the correct `seconds_credited` formatted as "Away for N hours M minutes" (or locale-equivalent)
- [ ] **UX-RTA-07 (level-ups)**: LevelUpsSection is hidden when `_last_summary.level_ups` is empty; visible with one row per hero when non-empty
- [ ] **UX-RTA-08 (level-up format)**: Each LevelUpRow shows `hero.display_name + " Lv X → Lv Y"` with old/new levels from the summary entry
- [ ] **UX-RTA-09 (continue)**: Tapping ContinueButton routes to Guild Hall via `SceneManager.request_screen("guild_hall", CROSS_FADE)`
- [ ] **UX-RTA-10 (continue idempotency)**: Multiple rapid taps on Continue produce exactly one `request_screen` call (idempotent flag)
- [ ] **UX-RTA-11 (offline cap suffix)**: When `OFFLINE_CAP_HOURS` was hit, OfflineDurationLabel includes a "(rewards capped)" suffix or equivalent locale string
- [ ] **UX-RTA-12 (no-rewards bypass)**: Screen does NOT render if `summary.seconds_credited == 0` (the gate is OE-side; this AC documents the contract)
- [ ] **UX-RTA-13 (cached summary cleared)**: After Continue, `OfflineProgressionEngine._last_summary` is cleared so re-entering via dev nav doesn't re-render stale data
- [ ] **UX-RTA-14 (reduce-motion)**: With reduce_motion flag enabled, GoldEarnedLabel renders at final value instantly (no count-up); LevelUpRows appear all at once (no stagger)
- [ ] **UX-RTA-15 (DESIGN.md compliance)**: Header uses `title-screen` (IM Fell English 32px); gold uses oversized `stat-value` Lantern Gold 32px; other body uses Lora; ContinueButton is `primary` variant
- [ ] **UX-RTA-16 (tap target)**: ContinueButton ≥80×full-width logical pixels (well above 44×44 minimum)
- [ ] **UX-RTA-17 (event fired)**: `ui_return_to_app_continued` event fires on Continue tap with payload `{ offline_seconds }`

---

## Open Questions

- **OQ-RTA-01**: Gold-count fly-in animation — does the count-up feel celebratory or slow? Reward ceremony budget is up to 800ms (Art Bible §7); 800ms is generous and might delay the player's eye for too long when the gold value is huge (5-digit numbers). Playtest signal: try 400ms easeOut and tune up if it feels too quick.
- **OQ-RTA-02**: Should there be a "Tap to continue" affordance hint somewhere on screen, in case the player doesn't see the button immediately? Cozy register favors trust; current spec assumes the button is sufficiently prominent. Playtest signal.
- **OQ-RTA-03**: Hero portrait in LevelUpRow — should each row show the hero's class icon or portrait? Currently just text. V1.0 enhancement when class portrait art lands.
- **OQ-RTA-04**: Same-hero-multi-level format — "Theron Lv 7 → Lv 9" or "Theron leveled up twice (Lv 7 → 9)"? Recommend the range format for compactness.
- **OQ-RTA-05**: Offline-replay-in-flight visual — if the player cold-launches and the replay is still computing when this screen renders, should there be a brief "calculating..." state? Currently the screen renders only after `offline_rewards_collected` signal fires; the gate ensures the summary is ready. No "calculating" state needed for MVP.
- **OQ-RTA-06**: 1 new pattern for `interaction-patterns.md`: **Reward Summary Panel** — large headline number + supporting stats + level-up list + single CTA. Reusable for Victory Moment + future end-of-day summary screens.
