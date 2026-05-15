# UX Spec: Hero Detail Modal

> **Status**: Draft — ready for `/ux-review` before implementation
> **Author**: user + ux-designer
> **Last Updated**: 2026-05-15
> **Journey Phase(s)**: Idle core loop — roster inspection + per-hero progression
> **Platform Target**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch port)
> **GDD Source**: `design/gdd/roster-hero-detail-screen.md` (#22)
> **Template**: UX Spec

---

## Purpose & Player Need

Hero Detail Modal is the **per-hero inspection surface** — a parchment-bordered overlay summoned by tapping a HeroCard in Guild Hall (or other roster-displaying screens). It shows one hero's detailed stats: portrait, class, level, XP progress, copies-owned-of-class, and a Level Up button when affordable.

**Player goal on arrival**: *"Tell me about this hero. Can I level them up right now?"* — and *"I'm done; back to the game."*

The modal serves two parallel intents:
1. **Inspection**: read-only check on hero stats (level, XP, class context). No action required; just looking.
2. **Progression**: spend gold to level the hero up. The Level Up button is the only mutation surface.

Per the cozy register:
- **Identity, not abstraction.** Each hero is a person — display_name + portrait + level history. The modal reinforces personhood.
- **Predictable progression.** Level cost is deterministic per ADR-0013; what the player sees is what they'll be charged.
- **Modal-friendly dismissal.** Tap outside, tap a Close button, or Escape — all dismiss. No "are you sure?" prompts.

---

## Player Context on Arrival

| Arrival | Prior action | Emotional state | Design implication |
|---------|-------------|-----------------|-------------------|
| **Tap on Guild Hall HeroCard** | Was scanning roster; wants more info on a specific hero | Curious — "what's Theron's exact XP?" | Modal slides in cleanly; data immediately visible; no loading |
| **Tap on Formation Assignment HeroSlotRow (V1.0+)** | Considering formation choices; wants to inspect candidate | Strategic — "is Bram leveled enough for this run?" | Modal context-switches to the candidate; close returns to Formation Assignment |
| **Tap on Hall of Retired Heroes portrait (V1.0)** | Viewing retired heroes; wants memorial detail | Reflective | Modal shows the retired hero's final-state stats; no Level Up affordance |

The modal is **non-destructive** — opening it never changes game state. Only the Level Up button (when affordable) mutates state.

---

## Navigation Position

Hero Detail Modal is a **modal overlay** — not a full screen change. It sits ON TOP of the source screen (typically Guild Hall) without removing it from the scene tree.

```
Guild Hall  (dimmed under modal)
  └── Hero Detail Modal  ← THIS MODAL (push_overlay; pauses underlying screen)
        └── (close / outside-tap / Escape) → Guild Hall (resumed)
```

The modal pushes via `SceneManager.show_modal` (or `push_overlay`) per ADR-0007 — underlying screen is dimmed, paused (ProcessMode), and resumed on modal close. Tick + signals continue in the background autoloads but the underlying screen's input is suppressed.

---

## Entry & Exit Points

**Entry sources:**

| Entry | Source | What player brings |
|-------|--------|--------------------|
| Tap HeroCard | Guild Hall | `instance_id` of the tapped hero |
| Tap HeroSlotRow (V1.0+) | Formation Assignment | `instance_id` of the tapped hero |
| Tap retired hero portrait (V1.0) | Hall of Retired Heroes | retired hero record (no instance_id — historical data) |

**Exit destinations:**

| Exit | Trigger | Notes |
|------|---------|-------|
| Close button | Tap CloseButton (X in top-right) | Dismiss modal; resume underlying screen |
| Outside-tap | Tap on `ModalDimBackdrop` (outside ModalPanel) | Same — dismiss + resume |
| Escape key (PC) | Press Escape | Same — dismiss + resume |
| Modal navigates elsewhere | n/a in MVP | V1.0+ may have "compare with hero X" or similar; currently no |

The modal is **always single-action-or-dismiss**. The Level Up button is the only thing that doesn't dismiss the modal — after a successful level-up, the modal updates in place (level + XP bar + Level Up cost refresh) so the player can level again if they want.

---

## Layout Specification

### Information Hierarchy

1. **Hero portrait** — identity anchor; largest visual element
2. **Hero name + level** — primary identity text
3. **Class + copies owned** — context info
4. **XP progress bar + current/threshold** — the "where they are" stat
5. **Level Up button** — primary action; cost visible
6. **Close button** — secondary navigation

### Layout Zones

Modal is a centered panel; not full-screen. Approximate dimensions: 480×640px logical (portrait-friendly, fits all aspect ratios).

| Zone | Height (of modal) | Contents |
|------|-------------------|----------|
| Modal header | ~10% | Close button (top-right) |
| Portrait area | ~40% | Hero portrait (large, centered) |
| Stats area | ~30% | Name + level + class + copies + XP progress |
| Action area | ~20% | Level Up button (or "Max Level" placeholder) |

### Component Inventory

| Component | Type | Content | Interactive | DESIGN.md token |
|-----------|------|---------|-------------|-----------------|
| ModalDimBackdrop | ColorRect | Slate Ink at 70% alpha; full-rect | Yes — outside-tap dismisses | `Color(SlateInk, alpha=0.7)` |
| ModalPanel | PanelContainer | The actual modal container | No | `panel` variant `modal` |
| CloseButton | IconButton | "×" close icon | Yes | `button` variant `icon`, 44×44 |
| HeroPortrait | TextureRect | 192×192 logical px (large) | No | n/a — uses placeholder fallback per OQ-RS-01 |
| HeroNameLabel | Label | `hero.display_name` (player-set or auto-seeded) | No | `title-section` IM Fell English 24px |
| HeroLevelLabel | Label | `tr("hero_detail_level_format", [current_level])` ("Level 5") | No | `stat-value` Lora SemiBold 20px Lantern Gold |
| HeroClassLabel | Label | `tr("class_<id>_display_name")` ("Warrior") | No | `body-emphasis` Lora SemiBold 18px |
| CopiesOwnedLabel | Label | `tr("hero_detail_copies_format", [count])` ("3 Warriors in roster") | No | `secondary` Lora Regular 14px |
| XpProgressContainer | VBoxContainer | Wraps bar + value | No | n/a |
| XpProgressBar | ProgressBar | Fill = `xp / xp_threshold(level)` (range 0..1) | No | Guild Amber fill on Parchment Cream track, 8px tall |
| XpProgressLabel | Label | `tr("hero_detail_xp_format", [xp, threshold])` ("250 / 350 XP") | No | `body` Lora Regular 16px |
| LevelUpButton | Button | `tr("hero_detail_level_up_button_format", [cost])` ("Level Up — 450 gold") | Yes (gated) | `button` variant `primary` when affordable; 40% opacity disabled when not |
| MaxLevelLabel | Label (conditional) | `tr("hero_detail_max_level_label")` ("Maximum Level Reached") | No | `body-emphasis` Slate Ink at 60% alpha; replaces LevelUpButton at level cap |

### ASCII Wireframe

```
   (Guild Hall dimmed at 70% alpha behind modal)

     ┌───────────────────────────────────┐
     │                                ×  │  ← Close
     │                                   │
     │           ┌─────────┐             │
     │           │         │             │  ← Portrait
     │           │  ▼▼▼▼▼  │             │     (192×192)
     │           │ Theron  │             │
     │           │         │             │
     │           └─────────┘             │
     │                                   │
     │            Theron                 │  ← Name (24px IM Fell)
     │            Level 7                │  ← Level (20px Gold)
     │                                   │
     │            Warrior                │  ← Class
     │         3 Warriors in roster      │  ← Copies
     │                                   │
     │         ████████░░░░░░            │  ← XP bar
     │            250 / 350 XP           │
     │                                   │
     │   [    Level Up — 450 gold   ]    │  ← Action button
     │                                   │
     └───────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What changes |
|-------|---------|--------------|
| **Default — affordable** | Modal opened; gold ≥ level-up cost | LevelUpButton enabled (`primary`, Guild Amber fill); button label shows cost |
| **Default — unaffordable** | Modal opened; gold < level-up cost | LevelUpButton disabled (40% opacity); tap-tooltip "Need N more gold" |
| **Max level reached** | Hero is at `MAX_LEVEL` per Hero Leveling GDD #15 | LevelUpButton hidden; MaxLevelLabel shown with "Maximum Level Reached" |
| **Level-up success** | LevelUpButton tap → `HeroRoster.set_hero_level` writes new level | Modal stays open; HeroLevelLabel ticks up with Guild Amber pulse; XpProgressBar resets to 0; XpProgressLabel updates; LevelUpButton label updates with new cost; gold counter (Guild Hall background) pulses |
| **Level-up insufficient gold (race)** | Player tapped enabled button but gold dropped between display + tap | Toast or push_warning; modal stays open; button re-evaluates affordability |
| **Retired hero (V1.0)** | Modal opened for a prestiged-out hero from Hall of Retired Heroes | LevelUpButton replaced with read-only "Retired Lv N" label; XpProgressBar shows final state; modal subtitle "Retired Hero" |
| **XP gain during modal open** | `hero_leveled` signal fires for THIS hero (e.g., offline replay running in background) | XpProgressBar + HeroLevelLabel + XpProgressLabel re-render live |
| **Hero removed during modal open** | `HeroRoster.hero_removed(instance_id)` fires for this hero | Modal auto-dismisses (defensive); routes back to source screen with a brief toast "Hero no longer in roster" |

---

## Interaction Map

Input methods: **Mouse (primary)** + **Touch parity** (single-tap). No Gamepad.

| Component | Action | Input | Feedback | Outcome |
|-----------|--------|-------|----------|---------|
| CloseButton | Tap | Mouse LMB / touch | `sfx_ui_tap` + button press | Dismiss modal; resume underlying screen |
| ModalDimBackdrop | Tap | Mouse LMB / touch | `sfx_ui_tap` | Same — dismiss + resume (outside-tap dismissal pattern) |
| Escape key | Press | Keyboard | n/a | Same — dismiss + resume |
| LevelUpButton (enabled) | Tap | Mouse LMB / touch | `sfx_ui_tap` + Guild Amber → Lantern Gold flash + scale pulse (1.05×) | `HeroRoster.set_hero_level(instance_id, level + 1)` + Economy deduct; modal updates in place |
| LevelUpButton (disabled) | Tap | Mouse LMB / touch | No feedback | No-op. PC: hover shows tooltip "Need N more gold." Touch: long-press shows same. |
| ModalPanel | Tap (inside) | Mouse LMB / touch | No feedback | No-op (tap inside the panel consumed; does NOT dismiss the modal) |
| HeroPortrait / Labels | Tap | Mouse LMB / touch | No feedback | No-op (display-only) |

**Tap-outside-to-dismiss**: cozy default per Settings GDD #30 §C.6 + pattern library. Single-finger touch parity: ModalDimBackdrop must consume taps outside the panel area.

---

## Events Fired

| Player action | Event | Payload |
|---------------|-------|---------|
| Modal opened | `ui_hero_detail_opened` | `{ instance_id, class_id, current_level, source: "guild_hall" or other }` |
| Level Up tapped (enabled) | `ui_hero_level_up_committed` | `{ instance_id, old_level, new_level, cost_paid, gold_balance_after }` |
| Modal closed (any path) | `ui_hero_detail_closed` | `{ instance_id, method: "close_button" or "outside_tap" or "escape" or "auto_dismiss" }` |

**Persistent state writes**:
- `HeroRoster._heroes[instance_id].current_level` via `HeroRoster.set_hero_level` (in response to LevelUpButton tap)
- `Economy._gold_balance` via `Economy.try_spend(cost, "level_up")` (atomic with the level-up via `Hero.try_level_up` flow)

All writes are atomic through the HeroRoster autoload's `try_level_up` method.

---

## Transitions & Animations

**Modal enter**: ModalDimBackdrop fades from 0 → 70% alpha over 200ms. ModalPanel slides from below-center to centered + scales from 0.95× → 1.0× over 200ms `enter` curve (parallel). Reduce-motion: instant.

**Modal exit (any path)**: ModalDimBackdrop fades from 70% → 0 over 150ms. ModalPanel scales to 0.95× + fades out over 150ms `exit`. Reduce-motion: instant.

**Level-up success animation** (reward-moment exception per Art Bible §7 — up to 400ms):
- 0ms: gold deducted; Economy fires `gold_changed` (Guild Hall background pulses if visible through dim)
- 50ms: HeroLevelLabel scales 1.05× + color shifts to brief Lantern Gold flash (settles back to default Lantern Gold)
- 100ms: XpProgressBar empties (animated drain from current → 0 over 150ms)
- 250ms: XpProgressLabel cross-fades to new threshold ("0 / 400 XP")
- 300ms: LevelUpButton label cross-fades to new cost ("Level Up — 600 gold")
- 400ms: complete; button re-evaluates affordability + re-styles enabled/disabled
- Reduce-motion: all instant at final values

**XP gain mid-modal** (signal-driven, not user-initiated):
- XpProgressBar animates from old value → new value over 250ms `move` easing (linear fill animation)
- HeroLevelLabel snaps to new level instantly (no flash — this is background progression, not a reward beat)
- Reduce-motion: instant fill

---

## Data Requirements

| Data | Source | Read / Write | Live-updating? | Notes |
|------|--------|--------------|----------------|-------|
| Hero record | `HeroRoster.get_hero(instance_id)` | Read | Yes — `hero_leveled` signal | Drives Name/Level/XP/Class labels |
| Hero display name | `hero.display_name` | Read | Static (immutable post-recruit per ADR-0012) | — |
| Hero class_id | `hero.class_id` | Read | Static | Used to look up class display name + count copies |
| Hero current_level | `hero.current_level` | Read | Signal | Drives HeroLevelLabel + XP threshold lookup |
| Hero XP | `hero.xp` | Read | Signal — `hero_leveled` + XP gain | Drives XpProgressBar fill |
| XP threshold | `xp_threshold(current_level)` per Hero Leveling formula | Read | Computed | Drives XpProgressBar max + XpProgressLabel format |
| Copies owned of class | Count of heroes in HeroRoster with matching class_id | Read | Signal — `hero_recruited`, `hero_removed` | Drives CopiesOwnedLabel |
| Level-up cost | `level_cost(class_tier, current_level)` per Hero Leveling formula | Read | Computed per level | Drives LevelUpButton label + gating |
| Gold balance | `Economy.get_gold_balance()` | Read | Signal — `gold_changed` | Gates LevelUpButton affordability |
| Hero portrait | `HeroClass.portrait` (or placeholder fallback per OQ-RS-01) | Read | Static | Drives HeroPortrait texture |

**Write paths**: `HeroRoster.try_level_up(instance_id)` — atomic (gold deduct + level increment + xp reset).

---

## Accessibility

**Committed tier**: Standard.

| Requirement | Implementation |
|-------------|---------------|
| Tap targets | CloseButton: 44×44. LevelUpButton: 80×wide. ModalDimBackdrop: full-rect outside panel |
| No color-only indicators | LevelUpButton disabled state: 40% opacity + `disabled=true` + tooltip with deficit. Affordability is text-readable, not color-only |
| Reduce-motion | Modal enter/exit instant; level-up animations clamp to instant; XP bar fill animation clamps to instant |
| Colorblind backup cues | Guild Amber (affordable) vs disabled (gray) backed by `disabled` property + tooltip text |
| Text contrast | Slate Ink + Lantern Gold on Parchment Cream; verify Lantern Gold-on-cream contrast per Art Bible §4 |
| Font size floor | All ≥14px; primary text ≥16px; name 24px; level 20px |
| Mouse + touch parity | All interactions single-tap; outside-tap-dismiss works on both |
| Tap-outside-dismiss vs accidental dismiss | The 70% dim backdrop is unambiguous (clearly outside the panel); accidental dismiss risk is low. Standard cozy pattern. |
| Modal-pause underlying screen | Per ADR-0007 push_overlay — Guild Hall pauses; gold counter still updates via signal but no input. Player can read changes through the dim. |

---

## Localization Considerations

| Element | Max comfortable length | Risk level | Notes |
|---------|------------------------|------------|-------|
| HeroNameLabel | Variable (player-set display_name) | n/a | Not localized |
| HeroLevelLabel (`hero_detail_level_format`) | ~15 chars ("Level 5" = 7) | LOW | Number primarily |
| HeroClassLabel (`class_<id>_display_name`) | ~20 chars | MEDIUM | "Warrior" / "Krieger" / "Guerrier" — German "Krieger" = 7 |
| CopiesOwnedLabel (`hero_detail_copies_format`) | ~30 chars ("3 Warriors in roster") | MEDIUM | Plural-aware localization needed for "N Warriors" vs "1 Warrior" |
| XpProgressLabel (`hero_detail_xp_format`) | ~20 chars ("250 / 350 XP") | LOW | Number primarily |
| LevelUpButton format (`hero_detail_level_up_button_format`) | ~30 chars ("Level Up — 450 gold") | MEDIUM | German "Stufe aufsteigen — 450 Gold" = 30; tight on standard button width |
| MaxLevelLabel (`hero_detail_max_level_label`) | ~30 chars ("Maximum Level Reached") | LOW | Replaces button; wraps if needed |
| Insufficient gold tooltip (`hero_detail_insufficient_tooltip_format`) | ~30 chars | LOW | Tooltip wraps freely |

**HIGH PRIORITY for loc review**:
- CopiesOwnedLabel — plural forms in Slavic languages (1 / few / many) need locale-aware formatting
- LevelUpButton format — if 30 chars overflows, consider splitting to "Level Up" with cost as a sub-label below the button label

---

## Acceptance Criteria

- [ ] **UX-HD-01 (modal opens)**: Tapping a HeroCard on Guild Hall opens the modal; ModalDimBackdrop visible at 70% alpha; ModalPanel centered on screen
- [ ] **UX-HD-02 (hero data loaded)**: Modal displays the correct hero's name, level, class, XP, copies-owned count from `HeroRoster.get_hero(instance_id)`
- [ ] **UX-HD-03 (XP progress)**: XpProgressBar fill matches `hero.xp / xp_threshold(hero.current_level)`; XpProgressLabel shows the localized "current / threshold" format
- [ ] **UX-HD-04 (level up — affordable)**: When `gold >= level_cost(class_tier, current_level)`, LevelUpButton is enabled (`primary` variant, Guild Amber fill); button label shows current cost
- [ ] **UX-HD-05 (level up — unaffordable)**: When gold < cost, LevelUpButton is disabled (40% opacity); tooltip shows "Need N more gold"
- [ ] **UX-HD-06 (level up success)**: Tapping enabled LevelUpButton calls `HeroRoster.try_level_up(instance_id)`. On success: HeroLevelLabel updates with Lantern Gold pulse; XpProgressBar empties and animates to new state; LevelUpButton updates with new cost
- [ ] **UX-HD-07 (atomic level-up)**: Level-up either commits BOTH gold deduction AND level increment, or neither. Per ADR-0013 atomicity
- [ ] **UX-HD-08 (max level)**: When `hero.current_level == MAX_LEVEL`, LevelUpButton is replaced by MaxLevelLabel "Maximum Level Reached"
- [ ] **UX-HD-09 (close button)**: Tapping CloseButton dismisses the modal via `pop_overlay`; underlying screen (Guild Hall) resumes
- [ ] **UX-HD-10 (outside-tap dismiss)**: Tapping ModalDimBackdrop (outside ModalPanel) dismisses the modal
- [ ] **UX-HD-11 (Escape dismiss — PC)**: Pressing Escape on PC dismisses the modal; gracefully no-op on touch-only platforms
- [ ] **UX-HD-12 (tap inside does not dismiss)**: Tapping inside ModalPanel (but not on a button) does NOT dismiss the modal
- [ ] **UX-HD-13 (live XP update)**: When `HeroRoster.hero_leveled` fires for THIS hero (e.g., offline replay), XpProgressBar + HeroLevelLabel update within one frame
- [ ] **UX-HD-14 (hero removed defensive)**: When `HeroRoster.hero_removed(instance_id)` fires for the modal's hero, modal auto-dismisses; toast notifies player
- [ ] **UX-HD-15 (tap target)**: CloseButton 44×44; LevelUpButton ≥80px tall (well above 44 floor)
- [ ] **UX-HD-16 (event fired on level up)**: `ui_hero_level_up_committed` event fires with payload incl. `instance_id`, old_level, new_level, cost_paid
- [ ] **UX-HD-17 (reduce-motion)**: Modal enter/exit + level-up animations skip to final states instantly with reduce_motion flag
- [ ] **UX-HD-18 (DESIGN.md compliance)**: ModalPanel uses `modal` variant; HeroNameLabel uses `title-section`; HeroLevelLabel uses `stat-value` Lantern Gold; XpProgressBar uses Guild Amber fill on Parchment Cream track
- [ ] **UX-HD-19 (cozy register)**: No "Are you sure?" prompts on level-up; no "Don't show again" toggles; level-up is a single-tap commit

---

## Open Questions

- **OQ-HD-01**: Hero rename — should the modal allow renaming the hero (display_name is the player-set identity)? Sprint 21+ candidate. Cozy register favors personalization. ADR-0012 immutability concern: display_name is currently immutable post-recruit; would need an ADR amendment.
- **OQ-HD-02**: Bulk-level-up (level up N times in one tap, if gold allows) — Sprint 22+ polish. Risk: feels too efficient + skips the satisfying per-level animation. Recommend: stay with single-level-per-tap for MVP.
- **OQ-HD-03**: Hero portrait placeholder — same as Recruit OQ-RS-01. Parchment-cream square with class letter inset until real art lands.
- **OQ-HD-04**: Class detail tap — could HeroClassLabel be tappable to open a class-detail modal showing class stats, perks, lore? V1.0+ enhancement. Currently informational text only.
- **OQ-HD-05**: Compare-with-hero — V1.0+ "swipe left/right to compare with another hero" pattern. Out of scope for MVP.
- **OQ-HD-06**: Retired hero view variant — Hall of Retired Heroes (Prestige V1.0) shows retired heroes; this modal needs a variant for retired heroes where Level Up is replaced with "Retired Lv N" + retirement-date label.
- **OQ-HD-07**: 1 new pattern for `interaction-patterns.md`: **Inspection Modal with Single Action** — modal pattern with read-only inspection fields + one primary action (gated by resource) + tap-outside-dismiss. Reusable for future inventory item detail, building inspection, etc.
