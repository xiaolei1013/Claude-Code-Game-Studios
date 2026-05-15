# UX Spec: Dungeon Run View

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-15
> **Journey Phase(s)**: Active dispatch (in-run spectator)
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/dungeon-run-view.md` (#24); reverse-documented from shipped Sprint 5-13 implementation
> **Template**: UX Spec

---

## Purpose & Player Need

Dungeon Run View is the **spectator screen** the player watches while a dispatched run resolves. The player has tapped Dispatch; the run is now happening; this is the moment they observe their decision pay off (or pay back).

**Player goal on arrival**: *"Show me what's happening. Show me the result clearly when it's over. Take me home when I'm done."*

The screen is **read-only** — no interactions during the run itself. The player observes; they do not steer. This is a deliberate cozy-register commitment: the dispatch is a contemplative beat, not an action game.

Two distinct sub-purposes:
1. **Live observation** (during ACTIVE_FOREGROUND): tick counter ticking, kill count rising, occasional level-up toast for the felt-progression moment. The player can look away and look back; nothing punishes inattention.
2. **Run-end summary** (after RUN_ENDED): outcome overlay shows kill total + transition back to Guild Hall after a brief dwell so the player has time to read the result.

The screen is the **canonical hot-path performance constraint** for the entire game. `_on_tick_fired` runs at 20 Hz during ACTIVE_FOREGROUND. Per `.claude/rules/engine-code.md` zero-allocations-in-hot-paths invariant, the handler does the absolute minimum: two label.text assignments. UX decisions on this screen must respect that budget — no inline formatting, no `tr()` in the hot path, no allocations.

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **Pre-dispatch transition** | Just tapped Dispatch on Formation Assignment | Anticipatory — they want to see what happens | Tick + kill labels visible immediately; no loading state needed |
| **Mid-run-reassignment restart** | Cancelled active run + restarted with new formation | Curious / experimental — testing the new lineup | Same as pre-dispatch; the restart is invisible at the screen layer |
| **App resume mid-run** (rare) | Backgrounded the app; came back during ACTIVE_FOREGROUND | Brief disorientation — "what's happening?" | Tick counter shows current state immediately; the snap-to-snapshot covers the gap |

The player is in **observation mode** — they read, they don't act. The screen's UX promise is that nothing demands their attention until the run ends.

---

## Navigation Position

Dungeon Run View is a **mid-loop screen** — entered only from Formation Assignment (dispatch), exits only to Guild Hall (auto-route on RUN_ENDED).

```
Formation Assignment
  └── Dungeon Run View  ← THIS SCREEN
        └── (auto-route on RUN_ENDED) → Guild Hall  (or Victory Moment, if that screen lands first)
```

The player cannot back-nav out of this screen during ACTIVE_FOREGROUND — the dispatch is committed. Only RUN_ENDED triggers an exit.

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|--------------------|
| Dispatch transition | Formation Assignment | Active run snapshot in DungeonRunOrchestrator |
| Mid-run reassignment | Formation Assignment (after ADR-0001 restart) | New active run snapshot |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Auto-route (RUN_ENDED) | `DungeonRunOrchestrator.state_changed` → RUN_ENDED | After `RUN_END_DWELL_MS` (1500ms), routes to `guild_hall` via CROSS_FADE. Idempotent via `_routed` flag. |
| Auto-route (RUN_ENDED, Victory Moment exists) | Same | If `victory_moment` screen is registered, routes there instead of `guild_hall`. Victory Moment then routes to Guild Hall. |
| App close | OS home / force-quit | Orchestrator snapshot persists; resume restores the in-flight state |

No back button on this screen. No pause overlay during MVP (the pause menu is reachable from Guild Hall + Formation Assignment but not DRV).

---

## Layout Specification

### Information Hierarchy

1. **Run state visible at a glance** — tick + kill count tell the player "this is what's happening right now"
2. **Run-end overlay** — when RUN_ENDED fires, the overlay communicates the outcome clearly
3. **Level-up toast (rare)** — the felt-progression moment when a hero levels up mid-run
4. **Biome context** (V1.0 add) — biome name + floor index for orientation
5. **Synergy badge** (optional) — if a synergy was active at dispatch, show it as a static badge

### Layout Zones

| Zone | Height | Contents |
|------|--------|----------|
| BiomeBackground | full (z=-1) | per-biome palette per S19-M3; sits under tilt-shift blur |
| Header | ~80px (~10%) | HeaderLabel (biome + floor) |
| StatsPanel | center | TickRow (Tick: N) + KillCountRow (Kills: N) — large + readable |
| RunEndOverlay | conditional, full-rect | shown on RUN_ENDED; contains RunEndLabel (final kill summary) |
| Level-up toast (conditional) | floating | brief overlay; auto-dismisses after `LEVEL_UP_TOAST_LIFETIME_SEC` |

### Component Inventory

**Header zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| HeaderLabel | Label | `tr("dungeon_run_view_header_format", [biome_display_name, floor_index])` ("Forest Reach · Floor 3") | No | `title-section` IM Fell English 24px Slate Ink |

**StatsPanel zone (live tick + kill display)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| StatsPanel | VBoxContainer | Container for tick + kill rows | No | `panel` variant `parchment-default` |
| TickRow | HBoxContainer | "Tick:" + value | No | n/a |
| TickPrefixLabel | Label | `tr("dungeon_run_view_tick_prefix")` ("Tick:") | No | `stat-label` — Lora SemiBold 16px |
| TickLabel | Label | `str(current_tick)` — UPDATED PER TICK (hot path) | No | `stat-value` — Lora SemiBold 20px Slate Ink |
| KillCountRow | HBoxContainer | "Kills:" + value | No | n/a |
| KillCountPrefixLabel | Label | `tr("dungeon_run_view_kill_prefix")` ("Kills:") | No | `stat-label` |
| KillCountLabel | Label | `str(kill_count)` — UPDATED PER TICK | No | `stat-value` Lora SemiBold 20px Lantern Gold (reward signal) |

**RunEndOverlay zone (conditional)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| RunEndOverlay | PanelContainer | Container, full-rect anchored | No (consumes outside-taps with no action) | `panel` variant `modal` |
| RunEndLabel | Label | `tr("run_complete_kill_count_format")` % final_kill_count ("Run complete: 12 kills") | No | `title-screen` IM Fell English 32px |

**Level-up toast (conditional, floating)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| ToastLabel | Label | `tr("level_up_toast_format", [hero_name, new_level])` ("Theron reached Lv 4!") | No | `body-emphasis` Lora SemiBold 18px Lantern Gold |

### ASCII Wireframe

```
┌─────────────────────────────────────────────┐
│  Forest Reach · Floor 3                     │  ← Header
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│        ┌─────────────────────────┐          │
│        │  Tick:    127           │          │  ← Live stats
│        │  Kills:     8           │          │     (center)
│        └─────────────────────────┘          │
│                                             │
│            ✦ Theron reached Lv 4!           │  ← Level-up toast
│                                             │     (transient)
│                                             │
└─────────────────────────────────────────────┘

RUN_ENDED state overlays:

┌─────────────────────────────────────────────┐
│                                             │
│            Run complete: 12 kills           │  ← RunEndOverlay
│                                             │     (1500ms dwell)
│                                             │
│         (auto-routing to Guild Hall...)     │
│                                             │
└─────────────────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **DISPATCHING** | Just entered from Formation Assignment | Tick + kill snap to current snapshot (typically 0 + 0); RunEndOverlay hidden |
| **ACTIVE_FOREGROUND** | Orchestrator state advances | Tick + kill labels update every 50ms (20 Hz hot path); RunEndOverlay hidden |
| **RUN_ENDED** | Orchestrator transitions to RUN_ENDED | RunEndOverlay appears with final kill count; auto-route timer starts (1500ms) |
| **Auto-routing** | Dwell timer expired | RunEndOverlay still visible; transition to Guild Hall (or Victory Moment) via CROSS_FADE |
| **Level-up toast** | `HeroRoster.hero_leveled` signal | Toast appears with hero name + new level; auto-dismisses after `LEVEL_UP_TOAST_LIFETIME_SEC` (~3s); does NOT block tick display |
| **App resume mid-run** | `app_in_foreground_changed(true)` from SceneManager | Tick + kill snap to current snapshot; no special UI |

---

## Interaction Map

**No interactive elements during ACTIVE_FOREGROUND.** The screen is observation-only.

| Component | Action | Input | Feedback | Outcome |
|-----------|--------|-------|----------|---------|
| Any element | Tap | Mouse LMB / touch | No feedback (mouse_filter = PASS on all elements) | No-op |

Per ADR-0008 mouse_filter rules: all Labels use `MOUSE_FILTER_PASS` so taps fall through; no focus stealing; no inadvertent interruption. The screen is a "look, don't touch" surface by design.

---

## Events Fired

| Event source | Event | Payload |
|--------------|-------|---------|
| Tick (handled, not fired) | `TickSystem.tick_fired` (received from autoload) | `{ n: int }` |
| State change (handled, not fired) | `DungeonRunOrchestrator.state_changed` (received) | `{ old: State, new: State }` |
| Hero level-up (handled, not fired) | `HeroRoster.hero_leveled` (received) | `{ instance_id, old_level, new_level }` |
| Run end auto-route | `ui_run_ended_routed` (fired once) | `{ final_kill_count, biome_id, floor_index, losing_run }` |

**No persistent state writes from this screen.** All state mutation happens upstream in the orchestrator + autoloads.

---

## Transitions & Animations

**Screen enter**: FADE_TO_BLACK from Formation Assignment (per SceneManager.request_screen transition type used at dispatch). ~200ms.

**Screen exit**: CROSS_FADE to Guild Hall (or Victory Moment) after RUN_END_DWELL_MS (1500ms). ~150ms cross-fade.

**Tick label updates**: instant (no animation). The numbers tick visibly at 20 Hz — the rapid update IS the visual feedback.

**Kill count update**: instant. Same hot-path performance constraint.

**RunEndOverlay appear**: 200ms fade-in from 0 → 100% opacity. Reduce-motion: instant.

**Level-up toast appear/dismiss**: 200ms fade-in + 1.05× scale pulse + 3000ms hold + 200ms fade-out. Reduce-motion: instant appear, instant dismiss after hold.

---

## Data Requirements

| Data | Source | Read / Write | Live-updating? | Notes |
|------|--------|--------------|----------------|-------|
| Current tick | `DungeonRunOrchestrator.run_snapshot.current_tick` | Read | Yes — every 50ms | Drives TickLabel |
| Kill count | `DungeonRunOrchestrator.run_snapshot.kill_count` | Read | Yes — every 50ms | Drives KillCountLabel |
| Run state | `DungeonRunOrchestrator.get_state()` | Read | Signal — `state_changed` | Drives RunEndOverlay visibility |
| Biome + floor | `DungeonRunOrchestrator.get_dispatched_biome_id()` + `_dispatched_floor_index` | Read | Static during run | Drives HeaderLabel |
| Final kill count (on RUN_ENDED) | `run_snapshot.kill_count` at RUN_ENDED moment | Read | Captured once | Drives RunEndLabel |
| Hero leveled (toast) | `HeroRoster.hero_leveled` signal | Read | Per-event | Drives ToastLabel |

**No write paths.** Screen is display-only.

---

## Accessibility

**Committed tier**: Standard.

| Requirement | Implementation |
|-------------|---------------|
| No interactive controls | Compliant by design — no tap targets needed |
| Reduce-motion | Tick label updates remain (they're not animations); RunEndOverlay fade clamps to instant; toast clamps to instant |
| Colorblind backup cues | Kill count uses Lantern Gold (reward signal) but the value is a number — no color-only signal |
| Text contrast | Lora 16-32px on Parchment Cream + occasional RunEndOverlay on dimmed background; verify ≥4.5:1 WCAG AA |
| Font size floor | Tick + kill values at 20px; header at 24px; RunEndLabel at 32px — all above floor |
| Hot-path budget | UX decisions respect `_on_tick_fired` zero-allocation constraint (no `tr()` inline; no format strings) |
| Mouse + touch parity | n/a — no interactions |
| Screen reader | Tick + kill labels are AccessKit-readable per Godot 4.6 default; RunEndOverlay announces when shown |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| HeaderLabel (`dungeon_run_view_header_format`) | ~30 chars | LOW | Biome name + "Floor N" — fits header width |
| Tick prefix (`dungeon_run_view_tick_prefix`) | ~10 chars ("Tick:" = 5) | LOW | German "Tick:" same |
| Kill prefix (`dungeon_run_view_kill_prefix`) | ~10 chars ("Kills:" = 6) | LOW | German "Tötungen:" = 9 |
| Run-end format (`run_complete_kill_count_format`) | ~30 chars | LOW | Wraps if needed |
| Level-up toast (`level_up_toast_format`) | ~30 chars | LOW | Hero name + level |

No HIGH-priority loc concerns.

---

## Acceptance Criteria

- [ ] **UX-DRV-01 (layout)**: Header, StatsPanel, and (when active) RunEndOverlay all render correctly at 1280×800 Steam Deck native
- [ ] **UX-DRV-02 (live tick)**: TickLabel.text updates within one frame of every `tick_fired` signal during ACTIVE_FOREGROUND state; lags by ≤1 tick
- [ ] **UX-DRV-03 (live kill count)**: KillCountLabel.text updates within one frame of every `tick_fired` signal; reads from `run_snapshot.kill_count` directly
- [ ] **UX-DRV-04 (hot-path zero-alloc)**: `_on_tick_fired` handler does not allocate (no `String.format`, no `%d`, no `tr()` calls; only `str(int)` + label assignment); profiled at <0.5ms per call on dev hardware
- [ ] **UX-DRV-05 (run-end overlay)**: When orchestrator state transitions to RUN_ENDED, RunEndOverlay becomes visible with `RunEndLabel.text` containing the localized final-kill-count format
- [ ] **UX-DRV-06 (auto-route)**: After RUN_ENDED + `RUN_END_DWELL_MS` (1500ms) dwell, `SceneManager.request_screen` is called exactly once with destination "guild_hall" (or "victory_moment" if registered) and `CROSS_FADE` transition
- [ ] **UX-DRV-07 (auto-route idempotency)**: The `_routed` flag prevents `request_screen` from being called twice even if `state_changed` fires multiple times in the same RUN_ENDED window
- [ ] **UX-DRV-08 (transition timing)**: Auto-route transition completes within ≤500ms wall-clock time after dwell expires
- [ ] **UX-DRV-09 (level-up toast)**: When `HeroRoster.hero_leveled` fires during ACTIVE_FOREGROUND, a toast appears with the hero's localized name + new level; auto-dismisses after `LEVEL_UP_TOAST_LIFETIME_SEC`
- [ ] **UX-DRV-10 (toast does not block tick display)**: Tick + kill labels continue updating while toast is visible; toast does not consume taps or block any other rendering
- [ ] **UX-DRV-11 (lifecycle cleanup)**: After `on_exit`, all subscriptions (`tick_fired`, `state_changed`, `hero_leveled`) report `is_connected == false`
- [ ] **UX-DRV-12 (no interactive controls)**: No interactive Control on the screen has FOCUS_ALL focus mode; `suppress_keyboard_focus` called in `on_enter`
- [ ] **UX-DRV-13 (BiomeBackground + tilt-shift)**: Per Sprint 19 wiring, BiomeBackground at z=-1 + tilt-shift active produces the diorama register; UI labels render sharp on top (z=0)
- [ ] **UX-DRV-14 (biome context)**: HeaderLabel displays the active dispatched biome's display_name + floor_index format on entry
- [ ] **UX-DRV-15 (app resume mid-run)**: When the app resumes from background mid-run, tick + kill labels snap to the current `run_snapshot` values within one frame; no flicker
- [ ] **UX-DRV-16 (no bypass)**: The screen never calls `SceneTree.change_scene_to_*` — all screen changes route via SceneManager per ADR-0007
- [ ] **UX-DRV-17 (DESIGN.md compliance)**: TickLabel uses `stat-value` Slate Ink 20px; KillCountLabel uses `stat-value` Lantern Gold 20px (the reward signal); RunEndLabel uses `title-screen` IM Fell English 32px

---

## Open Questions

- **OQ-DRV-01**: Should the kill count be color-shifted to Lantern Gold during ACTIVE_FOREGROUND, or only on the RUN_ENDED overlay? Current behavior per DESIGN.md: kill count is a reward signal → Lantern Gold always. Could feel too "loud" during the in-run tick. Playtest signal.
- **OQ-DRV-02**: V1.0 add — biome ambient audio loop (per audio-system.md). Currently ADR-0016 silent MVP. Worth flagging in this spec since the screen is the audio-presence canonical surface.
- **OQ-DRV-03**: Synergy badge during run — if the dispatch had an active synergy (e.g., "Steel Wall +25%"), should a static badge persist on this screen as a reminder? Currently the synergy is visible only on Formation Assignment. Playtest signal.
- **OQ-DRV-04**: Per-biome ambient particle effects (lantern bugs in Forest Reach, ember sparks in Ember Wastes) — Vertical Slice tier. Not blocking MVP.
- **OQ-DRV-05**: Run-end overlay tap-to-skip-dwell — should tapping the overlay skip the 1500ms dwell and route immediately? Cozy register favors trust over guardrails; recommend: yes, single tap skips remaining dwell.
- **OQ-DRV-06**: 1 new pattern for `interaction-patterns.md`: **Hot-Path Display** — the read-only screen pattern where high-frequency state changes drive label updates without animation. Used by DRV's tick + kill display.
