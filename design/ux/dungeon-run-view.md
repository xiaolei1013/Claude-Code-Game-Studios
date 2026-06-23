# UX Spec: Dungeon Run View

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-06-22
> **Journey Phase(s)**: Active dispatch (in-run spectator)
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/dungeon-run-view.md` (#24); reverse-documented from shipped Sprint 5-13 implementation. **Hero Combat Presence section** added 2026-06-22 for `design/gdd/hero-combat-animation.md` (#35).
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

## Hero Combat Presence (GDD #35)

> Added 2026-06-22 for the `hero-combat-animation` epic (GDD #35). This section
> is **additive** — it extends the spectator screen with the party's heroes as
> animated diorama sprites. It does not alter any behaviour specified above.

Today the party is represented only by **text tiles** in the top-left "Party" HUD (name · class · Lv) plus a single **aggregate** HP bar; the enemies stand center-stage as sprites. The player watches their *enemies* and a *number*, but never sees the heroes they recruited and formed up. This epic puts the heroes on screen as animated sprites standing in the diorama, facing the enemy lineup — **one sprite per occupied formation slot** — and reacting to combat. The screen stays read-only and the 20 Hz hot path stays zero-allocation.

### Hero Placement (where)

The heroes form a **center-stage "front line"** — a horizontal row positioned *below* the existing enemy lineup (which occupies the center-upper band, `_place` offsets top ≈188 → 384). This makes the two-sided HP race read spatially: the threat ahead (enemies, cool-lit, upper) versus the party (heroes, warm-lit, lower-center). Reading top-to-bottom the diorama becomes: **Header → Enemies ahead → Your party → channel-light lantern**.

| Property | Decision |
|---|---|
| Container | A new dedicated full-rect `Control` — `PartyDioramaLayer` — added via `add_child` on the screen root, a **sibling** of the existing wireframe panels. **Not** reparented under `WirePartyHud` (screen-node hard-path coupling: restructure additively, never reparent). |
| Layout | A centered `HBoxContainer` inside that layer; one child per occupied slot. |
| Count | `HeroRoster.get_formation_heroes().size()` — data-driven (`formation_size`, default 3, **never hardcoded**). Empty/unfilled slots render nothing (no ghost, no placeholder). Empty party (dev-nav idle DRV) → zero sprites, no error. |
| Starting anchor | `anchor 0.5/0/0.5/0`, offsets ≈ `(-280, 408, 280, 540)` — centered, just below the enemy band, above the bottom-center lantern. **Starting values; Story 005 finalizes against the live 1280×800 layout** and verifies no collision with the lantern / progress / event-feed panels. |
| Orientation | Reuse the existing in-scene idle sprite orientation (no new art) — pose, not facing, carries the reaction (see OQ-DRV-HERO-2). |

### Hero Sizes

| Property | Decision |
|---|---|
| Source art | The in-scene-tier 4-frame strip via `ClassSpriteFactory.get_idle_frames(class_id)` (`FRAME_COUNT = 4`), silhouette-first per art-bible §5 "LOD Philosophy". Same asset already shipping on Recruit cards + Hero Detail modal. |
| Display height | `HERO_SPRITE_DISPLAY_PX` — tuning knob, default **72px**, range 48–96. Heroes are the diorama focal subjects, so larger than the 48px codex/start-menu thumbnails but within the in-scene tier. |
| Render | `TextureRect`, `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`, **nearest-neighbour** (no blur) — consistent with every existing `ClassSpriteFactory` consumer. |
| Spacing | Centered `HBox` separation is a tuning knob; for large formations the row shrinks/tightens rather than overflowing (GDD #35 §E.2). Heroes must stay silhouette-distinct and non-overlapping for 1 … `formation_size`. |
| Scale reference | Art-bible §2: small enemies ≈ one hero-sprite height; boss-tier ≈ 2× hero width. Heroes set the diorama unit scale. |

### Per-Hero vs Aggregate HP — DECISIVE: **Aggregate**

HP is and remains **aggregate**. The combat resolver models party HP as a *single pool* driving the two-sided race (ADR-0010; GDD #34 §I). Per the shipped rationale in `dungeon_run_view.gd:815` — *"per-hero bars would be a fiction the model can't back."* Therefore:

- **No hero carries an individual HP bar, health number, or floating damage number.** None. The single aggregate HP bar + numeric `HP cur/max` label in the top-left Party HUD remains the **sole truthful HP readout** (and stays colorblind-safe — never color-only).
- Heroes communicate run state through **presence + reaction beats** — idle when calm, a strike/flash beat on `enemy_killed`/`boss_killed`, a slump on `run_defeated`, a flourish on first-clear — **not** through per-hero health UI. This is the whole-party-pulse decision (GDD #35 §C.5): the *party* reacts as one, mirroring the single HP pool.
- The top-left Party HUD is **unchanged** (aggregate HP bar + per-hero text tiles retained). Division of labor: **HUD = precise readout** (name / level / aggregate HP); **diorama = emotional presence** (the heroes you watch fight). Potential redundancy of the text tiles is flagged for playtest (OQ-DRV-HERO-1), not resolved destructively here.

### Layering (z-order)

| Plane | z | Contents | Focus |
|---|---|---|---|
| Far backdrop | −1 | `BiomeBackground` + `BackBufferCopy` + `TiltShiftDof` | **Softened** by the tilt-shift DoF |
| Diorama plane | 1 (`_WIRE_Z`) | Enemy lineup, **hero front line (NEW)**, greybox HUD panels | **Sharp** focal plane |
| Live readouts | 2 | `HeaderLabel`, `StatsPanel` (tick/kill) | Sharp |
| Run-end overlay | 5 | `RunEndOverlay` (victory / defeat) | Top — covers heroes when shown |

- Heroes render at the **diorama plane (z = 1)**, i.e. *in front of* the tilt-shift DoF (z = −1), so they are **sharp, never blurred** — matching art-bible "heroes sit in the sharp mid-plane; the painterly biome backdrop falls into the softer far-plane." The DoF softens only the far biome backdrop it samples through `BackBufferCopy`.
- The hero row must **not occlude** the HeaderLabel, the aggregate HP bar, the enemy lineup, or the run-end overlay. When `RunEndOverlay` (z = 5) shows, it covers the heroes — and the defeat-slump / victory beat coordinates *with* that overlay rather than fighting it (GDD #35 §E.5; the overlay is the existing `_show_defeat_overlay` / run-end surface, hooked, not replaced — see GDD #35 §C.7).
- **Theme cascade (ADR-0008):** `PartyDioramaLayer` is a `Control` sibling and must not be inserted between a themed `Control` and its descendants. A `type="Node"` intermediate silently breaks theme inheritance with no error — the layer and the hero `TextureRect`s are `Control` nodes, so the cascade is preserved for all siblings.

### Read-Only — No New Input

The screen is "look, don't touch," and the hero layer must not change that:

- The **entire** hero subtree — `PartyDioramaLayer`, the `HBoxContainer`, and every hero `TextureRect` + its `SpriteSheetAnimator` — is `MOUSE_FILTER_IGNORE`.
- `z_index` does **not** affect Godot input picking; GUI input routes by **tree order**, so a sprite layer added "on top" *will* steal taps unless it is `MOUSE_FILTER_IGNORE` (this exact mistake caused two prior "can't tap" playtest bugs — victory + dispatch). No hero is a tap target; none takes `FOCUS_ALL`; no hover-only or right-click-only affordance (touch parity).
- The **Interaction Map above is unchanged** — the hero layer adds **zero** new interactions. The "no interactive elements during ACTIVE_FOREGROUND" promise holds.

### Hot-Path & Lifecycle

- Hero sprites are built **once** (in the existing `_build_wireframe_once()` / `on_enter` build path), **never** in `_on_tick_fired`. The 20 Hz tick handler gains no allocation, format string, `tr()`, or node creation (Story 007 extends the Story-012 per-tick budget test to prove this with heroes + animators present).
- Idle animation is `_process`-driven on `SpriteSheetAnimator` nodes — its own clock, independent of the tick.
- Reaction beats fire on the human-frequency signals already subscribed in `on_enter` (`enemy_killed`, `boss_killed`, `floor_cleared_first_time`, `run_defeated`) — never polled per tick.
- `on_exit` frees `PartyDioramaLayer` (and thus all animators), with no orphaned `_process`; existing subscription teardown parity (per UX-DRV-11) extends to the hero layer.

### Reduce-Motion

Per `SceneManager.reduce_motion` (precedent: `prestige_fade_animation_test` AC-PR-18): idle animation **holds frame 0** — heroes stay *present*, just static (presence ≠ motion) — and **all reaction beats are suppressed** (GDD #35 §C.8). The flag is read **at beat time**, so a mid-run accessibility toggle is honored immediately (GDD #35 §E.6).

### ASCII Wireframe (hero layer added)

```
┌─────────────────────────────────────────────┐
│  Forest Reach · Floor 3        ┌──────────┐  │  ← Header (z2) + run-stats (top-right)
│ ┌────────────┐                 │ Tick: 127│  │
│ │ Party      │                 │ Kills:  8│  │
│ │ HP 84/120  │   ┌───────────┐ └──────────┘  │  ← top-left Party HUD = aggregate HP
│ │ ▓▓▓▓▓▓░░   │   │ Enemies   │               │     (+ retained text tiles)
│ │ Theron W3  │   │  ahead    │               │
│ │ Mara   M2  │   │ 👹  👹  👹 │               │  ← enemy lineup (center-upper, z1)
│ │ Ula    R2  │   │  3 / 5    │               │
│ └────────────┘   └───────────┘               │
│                                              │
│            🛡️42    🔮42    🗡️42             │  ← HERO FRONT LINE (NEW, z1, sharp)
│           Warrior  Mage   Rogue              │     one sprite / occupied slot
│                                              │     idle-anim; react to kills/boss/end
│                   ( 🏮 )                      │  ← channel-light lantern (bottom-center)
└─────────────────────────────────────────────┘
   No per-hero HP — the aggregate bar (top-left) is the only HP readout.
   Heroes are MOUSE_FILTER_IGNORE: tapping one is a no-op.
```

### Acceptance Criteria (Hero Combat Presence)

- [ ] **UX-DRV-HERO-01 (placement)**: At 1280×800, exactly one hero sprite renders per occupied formation slot, in a centered row below the enemy lineup, not occluding header / HP bar / enemy lineup / run-end overlay.
- [ ] **UX-DRV-HERO-02 (data-driven count)**: The screen renders `HeroRoster.get_formation_heroes().size()` sprites for any count 1 … `formation_size`; an empty party renders zero sprites with no error (dev-nav idle DRV).
- [ ] **UX-DRV-HERO-03 (aggregate HP only)**: No per-hero HP bar, health number, or damage number appears anywhere on the screen; the single aggregate HP bar + `HP cur/max` label remains the sole HP readout.
- [ ] **UX-DRV-HERO-04 (read-only)**: `PartyDioramaLayer` and every descendant report `mouse_filter == MOUSE_FILTER_IGNORE`; a tap on any hero is a no-op and never steals focus or blocks the run-end overlay.
- [ ] **UX-DRV-HERO-05 (layering / focus plane)**: Heroes render sharp (in front of the tilt-shift DoF); the run-end overlay (z = 5) covers heroes when shown.
- [ ] **UX-DRV-HERO-06 (hot-path zero-alloc)**: `_on_tick_fired` allocates nothing with heroes + animators present (Story-012 budget test, extended in Story 007); idle animation is `_process`-driven, not tick-driven.
- [ ] **UX-DRV-HERO-07 (lifecycle cleanup)**: After `on_exit`, `PartyDioramaLayer` is freed, no animator `_process` remains active, and hero-related subscriptions report `is_connected == false`.
- [ ] **UX-DRV-HERO-08 (reduce-motion)**: With `reduce_motion` enabled, heroes render a static frame (present, not animating) and every reaction beat is suppressed.
- [ ] **UX-DRV-HERO-09 (sizes / readability)**: Heroes display at `HERO_SPRITE_DISPLAY_PX` with nearest-neighbour scaling (no blur), silhouette-distinct per class, non-overlapping for 1 … `formation_size`.
- [ ] **UX-DRV-HERO-10 (theme cascade intact)**: Adding `PartyDioramaLayer` does not break theme inheritance for any sibling `Control` (no `type="Node"` intermediate in the cascade path).

### Open Questions (Hero Combat Presence)

- **OQ-DRV-HERO-1**: Once on-screen sprites land, should the top-left Party HUD's per-hero text tiles be **retired** (the sprites carry identity) or **kept** (they show the exact level the 32–48px sprite can't)? Recommend **keep for MVP** — it's additive and test-safe (the `dungeon_run_view_screen_test` binds `WirePartyHud` structure); revisit at the Story 016 playtest if it reads as redundant.
- **OQ-DRV-HERO-2**: Hero facing — all heroes face the enemy lineup (away/up), or face the viewer (3/4)? The existing in-scene idle art is a fixed 3/4 view; recommend **reuse it** (no new art) and let pose/the reaction beat carry direction. Playtest signal.
- **OQ-DRV-HERO-3**: Should the hero row parallax or scale subtly with floor tier as a depth cue, or stay fixed? Defer to Phase 4 polish (Story 014/015).

---

## Open Questions

- **OQ-DRV-01**: Should the kill count be color-shifted to Lantern Gold during ACTIVE_FOREGROUND, or only on the RUN_ENDED overlay? Current behavior per DESIGN.md: kill count is a reward signal → Lantern Gold always. Could feel too "loud" during the in-run tick. Playtest signal.
- **OQ-DRV-02**: V1.0 add — biome ambient audio loop (per audio-system.md). Currently ADR-0016 silent MVP. Worth flagging in this spec since the screen is the audio-presence canonical surface.
- **OQ-DRV-03**: Synergy badge during run — if the dispatch had an active synergy (e.g., "Steel Wall +25%"), should a static badge persist on this screen as a reminder? Currently the synergy is visible only on Formation Assignment. Playtest signal.
- **OQ-DRV-04**: Per-biome ambient particle effects (lantern bugs in Forest Reach, ember sparks in Ember Wastes) — Vertical Slice tier. Not blocking MVP.
- **OQ-DRV-05**: Run-end overlay tap-to-skip-dwell — should tapping the overlay skip the 1500ms dwell and route immediately? Cozy register favors trust over guardrails; recommend: yes, single tap skips remaining dwell.
- **OQ-DRV-06**: 1 new pattern for `interaction-patterns.md`: **Hot-Path Display** — the read-only screen pattern where high-frequency state changes drive label updates without animation. Used by DRV's tick + kill display.
