# UX Spec: Unlock / Victory Moment

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-15
> **Journey Phase(s)**: Post-run celebration / Floor-clear payoff
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/unlock-victory-moment.md` (#25)
> **Template**: UX Spec

---

## Purpose & Player Need

Victory Moment is the **foreground celebration screen** that renders the post-run payoff after Dungeon Run View completes a floor-clear. It tells the player: *"You did the thing. Here's what you earned. Here's what's now unlocked."*

**Player goal on arrival**: *"Show me my reward. Tell me what I unlocked. Take me back to the game."*

The screen serves three distinct outcome states:
1. **First-ever clear of a higher floor**: shows the unlock fanfare + "Floor N+1 now available" + reward summary
2. **Re-clear (already at this high-water mark)**: shows the reward summary with quieter confirmation (no "newly unlocked" message)
3. **LOSING first-clear** (per ADR-0002 reclaim path): **identical fanfare** as WIN — Floor Unlock System §C.1 R5 locked this design floor; no differentiation in audio, animation, palette, or intensity

The screen is **foreground-only** — offline-replay clears do NOT trigger this screen (Return-to-App aggregates offline rewards). Victory Moment is the live-moment reward beat.

Per Art Bible §7 reward-moment exception: this screen's animation budget is up to 800ms (vs 150ms for standard UI). The primary number (kill count + gold delta) MUST render within the first 100ms even if ceremony continues after.

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **First-ever clear (advancement)** | Just watched a run resolve in DRV; Floor N+1 unlocked | Triumphant / discovery — "I broke through to the next floor" | Unlock message PROMINENT; fanfare audio + visual; player should know they advanced |
| **Re-clear at high-water mark** | Cleared an already-cleared floor; no new unlock | Satisfied / grinding — "got my gold and XP" | Quieter beat; same reward summary minus the unlock callout |
| **LOSING first-clear (reclaim)** | Lost the run but still first-cleared the floor per ADR-0002 | Mixed — outcome was below expectation but still got the unlock | **Identical fanfare** to WIN per Floor Unlock §C.1 R5 — the player should NOT feel punished for the loss |
| **Auto-skipped (silent run)** | Settings → "skip victory moment" enabled (V1.0+) | n/a — bypassed | Not in MVP; flagged as OQ |

The screen is **always celebratory**. Even LOSING runs get the celebration — the cozy register doesn't punish; it rewards progression regardless of outcome.

---

## Navigation Position

Victory Moment is a **mid-loop celebration screen** — entered from Dungeon Run View on RUN_ENDED with floor-clear; exits to Guild Hall.

```
Dungeon Run View
  └── (state_changed → RUN_ENDED + floor_cleared)
        └── Victory Moment  ← THIS SCREEN
              └── (tap or auto-advance) → Guild Hall
```

Per `dungeon_run_view.gd` §C-13 lifecycle: if `victory_moment` scene is registered AND `run_snapshot.floor_clear_emitted` is true, DRV routes to Victory Moment instead of directly to Guild Hall.

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|--------------------|
| Run-end transition (foreground only) | Dungeon Run View on RUN_ENDED + `floor_clear_emitted` | run_snapshot final state; FloorUnlock biome/floor unlock state |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Tap-to-continue | Tap anywhere on screen | `SceneManager.request_screen("guild_hall", CROSS_FADE)` |
| Auto-advance | `VICTORY_AUTO_ADVANCE_MS` (default 4000ms after ceremony completes) | Same route; idempotent with tap-skip |
| App close | OS home / force-quit | Run state already persisted; next launch resumes in Guild Hall |

The screen is **dismissible by any tap** — the cozy register favors trust; the player decides when to leave. Auto-advance is a fallback for non-interactive moments.

---

## Layout Specification

### Information Hierarchy

1. **Unlock callout (first-ever clear only)** — "Floor N+1 now available" — biggest visual treatment when present
2. **Hero portrait + kill count** — the felt-progression beat ("Theron killed 12 enemies")
3. **Gold delta** — accumulated gold from the run
4. **Hero level-ups (if any)** — list of heroes who leveled during the run
5. **Continue affordance** — visible "Tap to continue" hint at bottom

### Layout Zones

| Zone | Height | Contents |
|------|--------|----------|
| Header | ~80px (~10%) | Unlock callout (conditional) |
| Ceremony panel | flex (~70%) | Hero portrait + kill count + gold delta + level-up list |
| Continue affordance | ~80px (~10%) | "Tap to continue" hint |

### Component Inventory

**Header zone (conditional)**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| UnlockCalloutLabel | Label | `tr("victory_moment_unlock_callout_format", [biome_name, next_floor])` ("Forest Reach — Floor 2 now available") | No | `title-reward` IM Fell English 40px Lantern Gold on Slate Ink ground |

**Ceremony panel zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| CeremonyPanel | PanelContainer | Container | No | `panel` variant `ceremony` (full-bleed parchment with edge vignette) |
| HeroPortraitGroup | HBoxContainer | Up to 3 hero portraits (left-to-right, current formation) | No | n/a |
| HeroPortrait (×3) | TextureRect | 96×96 logical px hero portrait | No | n/a |
| KillCountHeadline | Label | `tr("victory_moment_kill_count_format", [final_kill_count])` ("12 enemies defeated") | No | `stat-value` Lora SemiBold 32px Slate Ink (oversized) |
| GoldDeltaRow | HBoxContainer | Coin icon + gold delta value | No | n/a |
| GoldDeltaLabel | Label | `tr("victory_moment_gold_delta_format", [delta])` ("+ 115 gold") | No | `stat-value` Lora SemiBold 32px Lantern Gold (oversized, reward signal) |
| LevelUpsSectionLabel | Label | `tr("victory_moment_level_ups_section_label")` ("Heroes leveled up:") — only visible if any | No | `stat-label` |
| LevelUpRow (×N) | Label | `tr("victory_moment_level_up_row_format", [hero_name, new_level])` ("Theron is now Level 2") | No | `body-emphasis` |

**Continue affordance zone**

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| ContinueAffordanceLabel | Label | `tr("victory_moment_continue_hint")` ("Tap anywhere to continue") | No | `secondary` Lora Regular 14px Slate Ink at 60% alpha; pulse subtly |

The entire screen is **tap-anywhere-to-continue** — there's no explicit Button. ContinueAffordanceLabel is a visual hint, not a click target; the tap-anywhere behavior is wired at the screen root.

### ASCII Wireframe

**First-ever clear variant** (with unlock callout):

```
┌─────────────────────────────────────────────┐
│   Forest Reach — Floor 2 now available      │  ← Unlock callout
│              ✦                              │     (40px, Gold)
├─────────────────────────────────────────────┤
│                                             │
│        ┌──┐  ┌──┐  ┌──┐                     │
│        │T │  │B │  │Y │                     │  ← Hero portraits
│        │ho│  │ra│  │ar│                     │
│        │ro│  │m │  │a │                     │
│        │n │  │  │  │  │                     │
│        └──┘  └──┘  └──┘                     │
│                                             │
│         12 enemies defeated                 │  ← Kill headline
│            ⬡ + 115 gold                     │  ← Gold delta
│                                             │
│        Heroes leveled up:                   │
│          Theron is now Level 2              │
│                                             │
├─────────────────────────────────────────────┤
│          Tap anywhere to continue           │  ← Affordance
└─────────────────────────────────────────────┘
```

**Re-clear variant** (no unlock callout):

```
┌─────────────────────────────────────────────┐
│                                             │  ← Header empty
├─────────────────────────────────────────────┤
│                                             │
│        ┌──┐  ┌──┐  ┌──┐                     │
│        │T │  │B │  │Y │                     │
│        └──┘  └──┘  └──┘                     │
│                                             │
│          8 enemies defeated                 │
│             ⬡ + 70 gold                     │
│                                             │
├─────────────────────────────────────────────┤
│          Tap anywhere to continue           │
└─────────────────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **First-ever clear (advancement)** | `FloorUnlock.is_new_high_clear(biome, floor)` returns true | UnlockCalloutLabel visible with biome+next-floor format; ceremony fully expressive |
| **Re-clear (no advancement)** | Same floor already at high-water mark | UnlockCalloutLabel hidden; ceremony quieter (no fanfare audio; same reward summary) |
| **LOSING first-clear** | `run_snapshot.losing_run == true` AND first-clear | **Identical to WIN first-clear** per Floor Unlock §C.1 R5 |
| **LOSING re-clear** | Losing + already cleared | Same as WIN re-clear (no differentiation) |
| **No level-ups** | No hero leveled during this run | LevelUpsSection hidden (0px) |
| **Multiple level-ups** | Multi-level cascade or multiple heroes leveled | One row per leveled hero |
| **Ceremony complete + auto-advance pending** | After CEREMONY_DURATION_MS (~800ms reveal) + `VICTORY_AUTO_ADVANCE_MS` (~4000ms hold) | Auto-route triggers; ContinueAffordanceLabel pulses to draw tap intent |
| **Reduce-motion mode** | `SceneManager.reduce_motion == true` | Instant reveal of all elements at final values; no count-up; no portrait fade-in |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Feedback | Outcome |
|-----------|--------|-------|----------|---------|
| Screen root | Tap anywhere | Mouse LMB / touch | `sfx_ui_tap` | Route to Guild Hall via CROSS_FADE; cancel auto-advance timer |
| Auto-advance timer | Timeout (4000ms after ceremony) | n/a | None (the route IS the feedback) | Same route as tap |
| ContinueAffordanceLabel | — | Display only | — | No specific action (the hint says tap anywhere) |

**Tap-anywhere design**: per cozy register; the entire screen is the affordance. No button to find; no precision required.

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Screen open (foreground-floor-clear) | `ui_victory_moment_shown` | `{ biome_id, floor_index, losing_run, is_new_high_clear, kill_count, gold_delta, level_up_count }` |
| Tap-to-continue | `ui_victory_moment_continued` | `{ method: "tap" }` |
| Auto-advance | `ui_victory_moment_continued` | `{ method: "auto" }` |

**No persistent state writes from this screen.** All reward state was committed by the orchestrator + Economy + HeroRoster autoloads upstream. The screen reads + celebrates + navigates.

---

## Transitions & Animations

**Screen enter**: CROSS_FADE from Dungeon Run View. ~150ms.

**Screen exit**: CROSS_FADE to Guild Hall. ~150ms.

**Reward ceremony reveal** (per Art Bible §7 reward-moment budget — up to 800ms):
- 0ms: KillCountHeadline + GoldDeltaLabel render at final values (the primary numbers — **MUST be visible within 100ms** per Art Bible §7 admonition)
- 100ms: HeroPortraits fade in (3 portraits stagger 50ms each = 100-250ms range)
- 300ms: UnlockCalloutLabel (if present) scales from 0.95× → 1.0× over 200ms with `bounce` easing
- 500ms: LevelUpsSection fades in
- 700ms: ContinueAffordanceLabel fades in + begins subtle 3s-cycle alpha pulse (60% → 80% → 60%)
- 800ms: Ceremony complete; auto-advance timer starts (4000ms)

**Reduce-motion mode** (per ADR-0007):
- All elements render at final state immediately
- No scale animations
- No fade-ins (all visible at 100% opacity)
- ContinueAffordanceLabel does NOT pulse (static at 60% alpha)
- Auto-advance still applies (it's a time-based skip, not motion)

**Auto-advance route**: same 150ms CROSS_FADE as tap-skip route. Player should not notice difference except for timing.

---

## Data Requirements

| Data | Source | Read / Write | Live-updating? | Notes |
|------|--------|--------------|----------------|-------|
| Final kill count | `DungeonRunOrchestrator.run_snapshot.kill_count` | Read | Static at render | Drives KillCountHeadline |
| Gold delta | `run_snapshot.kill_count × per_kill_gold` OR Economy delta from pre_dispatch_gold to current | Read | Static | Drives GoldDeltaLabel |
| Biome + floor | `run_snapshot.biome_id` + `_dispatched_floor_index` | Read | Static | Drives UnlockCalloutLabel context |
| Is-new-high-clear | `FloorUnlock.is_new_high_clear(biome, floor)` (or equivalent) | Read | Static | Drives UnlockCalloutLabel visibility |
| Losing-run | `run_snapshot.losing_run` | Read | Static | Per §C.1 R5: does NOT differentiate visuals; logged in event payload only |
| Hero portraits | `HeroRoster.get_hero(instance_id).portrait` per formation slot | Read | Static | Drives 3 HeroPortrait textures; falls back to class-letter placeholder per OQ-RS-01 |
| Hero level-ups | Collected during run; `run_snapshot.level_ups_collected` (or HeroRoster.recent_level_ups) | Read | Static | Drives LevelUpRow list |
| reduce_motion flag | `SceneManager.reduce_motion` | Read | Static at render | Branches animation paths |

**No write paths.** Display + acknowledge + navigate.

---

## Accessibility

**Committed tier**: Standard.

| Requirement | Implementation |
|-------------|---------------|
| Tap targets | Entire screen is the affordance (≥full-rect ≫ 44×44) |
| No color-only indicators | Gold delta uses Lantern Gold but value is numeric + coin icon; kill count is plain Slate Ink |
| Reduce-motion (locked) | All ceremony animations clamp to instant-reveal per ADR-0007; primary numbers always render at final state ≤100ms; auto-advance still applies |
| Colorblind backup cues | Coin icon next to gold; class portraits identify heroes by silhouette not color |
| Text contrast | Lantern Gold on Parchment Cream is the tightest pair (40px UnlockCalloutLabel on Slate Ink ground per DESIGN.md `title-reward` — verified ≥4.5:1) |
| Font size floor | All text ≥14px; primary numbers ≥32px (well above floor) |
| Mouse + touch parity | Tap-anywhere works identically |
| WIN vs LOSING parity | Visual + audio + animation IDENTICAL per Floor Unlock §C.1 R5 — accessibility benefit: no player feels punished for a LOSING outcome |
| Auto-advance timing | 4000ms is comfortable reading speed; reduce-motion does NOT shorten this (the timer is not motion) |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| UnlockCalloutLabel (`victory_moment_unlock_callout_format`) | ~40 chars ("Forest Reach — Floor 2 now available" = 36) | MEDIUM | Biome names + "Floor N now available" — German may expand 50% |
| KillCountHeadline (`victory_moment_kill_count_format`) | ~25 chars ("12 enemies defeated") | LOW | Number primarily |
| GoldDeltaLabel (`victory_moment_gold_delta_format`) | ~16 chars ("+ 115 gold") | LOW | Number primarily |
| LevelUpRow (`victory_moment_level_up_row_format`) | ~30 chars ("Theron is now Level 2") | LOW | Hero name + level |
| ContinueAffordanceLabel (`victory_moment_continue_hint`) | ~25 chars ("Tap anywhere to continue") | LOW | German "Tippen, um fortzufahren" = 24 |
| LevelUpsSectionLabel (`victory_moment_level_ups_section_label`) | ~20 chars ("Heroes leveled up:") | LOW | German "Helden aufgestiegen:" = 20 |

**HIGH PRIORITY for loc review**: UnlockCalloutLabel format — 40-char budget at 40px font means width is tight. May need to allow 2-line wrap for German + Hungarian.

---

## Acceptance Criteria

- [ ] **UX-VM-01 (layout)**: Header / Ceremony / Continue zones render at 1280×800 native; UnlockCalloutLabel visible conditionally
- [ ] **UX-VM-02 (primary numbers within 100ms)**: KillCountHeadline + GoldDeltaLabel render at final values within 100ms of screen entry (per Art Bible §7 reward-moment admonition; AC verified by timing measurement)
- [ ] **UX-VM-03 (unlock callout — first clear)**: When `FloorUnlock.is_new_high_clear` returns true, UnlockCalloutLabel visible with biome + next-floor format
- [ ] **UX-VM-04 (unlock callout — re-clear)**: When already at high-water mark, UnlockCalloutLabel hidden (visible = false)
- [ ] **UX-VM-05 (LOSING fanfare identical)**: When `run_snapshot.losing_run == true` AND first-clear, the rendered visuals (palette, animations, audio, text emphasis) are EXACTLY identical to a WIN first-clear. Per Floor Unlock §C.1 R5 lock.
- [ ] **UX-VM-06 (kill count value)**: KillCountHeadline displays the localized format with the correct `run_snapshot.kill_count` value
- [ ] **UX-VM-07 (gold delta value)**: GoldDeltaLabel displays the localized format with the correct gold delta (current Economy balance minus pre_dispatch_gold OR equivalent)
- [ ] **UX-VM-08 (hero portraits)**: HeroPortraitGroup displays up to 3 portraits matching the dispatched formation in slot order
- [ ] **UX-VM-09 (level-ups list)**: LevelUpsSection visible when at least one hero leveled during the run; one row per leveled hero with "Hero is now Level N" format
- [ ] **UX-VM-10 (tap to continue)**: Tapping anywhere on the screen routes to Guild Hall via CROSS_FADE
- [ ] **UX-VM-11 (auto-advance)**: If no tap occurs within ceremony (~800ms) + dwell (~4000ms = 4.8s total), screen auto-routes to Guild Hall
- [ ] **UX-VM-12 (continue idempotency)**: Multiple rapid taps + simultaneous auto-advance produce exactly one `request_screen` call
- [ ] **UX-VM-13 (continue affordance pulse)**: ContinueAffordanceLabel pulses subtly (3s cycle) starting at ~700ms; reduce-motion disables the pulse
- [ ] **UX-VM-14 (reduce-motion)**: With reduce_motion enabled, all reveal animations skip to final state instantly; primary numbers still at 100ms; auto-advance timing unchanged
- [ ] **UX-VM-15 (offline replay bypass)**: This screen does NOT trigger when `OfflineProgressionEngine.is_replay_in_flight() == true` (offline rewards aggregate to Return-to-App instead)
- [ ] **UX-VM-16 (DESIGN.md compliance)**: UnlockCalloutLabel uses `title-reward` IM Fell English 40px Lantern Gold; KillCountHeadline + GoldDeltaLabel use oversized `stat-value` 32px (per reward-moment exception)
- [ ] **UX-VM-17 (event fired on continue)**: `ui_victory_moment_continued` event fires with payload `{ method: "tap" or "auto" }`

---

## Open Questions

- **OQ-VM-01**: V1.0+ "skip victory moment" setting — should the player be able to disable this screen entirely for fast loop cycles? Cozy register favors keeping the celebration; if added, should be opt-in (default ON), reachable from Settings. Sprint 21+.
- **OQ-VM-02**: First-clear audio fanfare vs re-clear audio — Floor Unlock §C.1 R5 locks WIN/LOSING parity; what about new-vs-re-clear parity? Recommend: NEW-clear gets the fanfare audio cue; re-clear is silent (no SFX) but visually identical layout. The "you advanced" beat should be felt.
- **OQ-VM-03**: Hero portrait placeholder strategy — same as Recruit Screen OQ-RS-01. Parchment-cream square with class letter inset until real art lands.
- **OQ-VM-04**: Multi-level cascade format — "Theron leveled up twice (Lv 5 → 7)" vs two rows. Recommend single-row range format for compactness; matches Return-to-App OQ-RTA-04.
- **OQ-VM-05**: Auto-advance interruption on Settings overlay — if the player opens Settings during the auto-advance dwell (unlikely but possible), the timer should pause; resume on Settings dismiss. ADR-0007 push_overlay path should handle this; verify in implementation.
- **OQ-VM-06**: Gold delta from negative (LOSING run, half-rewards) — `LOSING_RUN_LOOT_FACTOR = 0.5` produces half-gold; display should NOT show negative number; the delta is positive (just smaller). Verify.
- **OQ-VM-07**: 1 new pattern for `interaction-patterns.md`: **Tap-Anywhere Continue** — full-screen receive-mode pattern where the entire surface is the affordance + a hint label tells the player. Reusable for splash screens, lore moments, ceremony beats.
