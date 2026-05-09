# Roster / Hero Detail Screen — GDD #22

> **Status: First-pass DRAFT 2026-05-07** by post-Recruit-Screen-GDD autonomous-execution session, continuing the Sprint-14-prep design-coverage push (Settings/Hero Leveling/Onboarding/UI Framework/Return-to-App/Guild Hall/Recruit Screen). All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. Run `/design-review` before APPROVED. Closes the systems-index #22 "Not Started" gap.

---

## A. Overview

**Hero Detail** is the modal overlay summoned from a Guild Hall HeroCard tap (per Guild Hall GDD #19's "HeroCards are non-interactive in MVP — Sprint 14+ Roster / Hero Detail Screen #22 may make them tappable") and shows one hero's detailed stats: portrait, class, level, copies-owned-of-class, current-XP-progress-toward-next-level, and a "Level Up (cost: Ng)" button when affordable. Player taps anywhere outside the modal (or a Close button) to dismiss; the modal returns the player to Guild Hall.

The "Roster" half of the GDD title is satisfied by Guild Hall's existing RosterPanel (#19 §C.4) — Guild Hall IS the roster overview screen. This GDD scopes only the **Hero Detail modal** sub-component. A dedicated full-screen Roster view is V1.0+ scope when the roster grows past Guild Hall's visible-card capacity (~8-12 HeroCards depending on screen height).

The screen is **read-only on roster identity fields** (instance_id, class_id, display_name are immutable post-recruit per ADR-0012). The only mutation surface is the Level Up button, which charges Economy gold and increments the hero's level via `HeroRoster.set_hero_level`.

---

## B. Player Fantasy

> *"I tap on Theron's card on the Guild Hall. The roster panel dims; a parchment-bordered detail modal slides in from below. I see Theron's portrait, his class (Warrior), his level (5), the number of warriors I own total (3), and a progress bar showing he's 250 / 350 XP toward level 6. There's a 'Level Up' button under the progress bar — '450 gold' — and I can afford it. I tap it. Gold drops, level ticks to 6, the progress bar resets to 0/400, and the chime plays. I tap outside the modal to dismiss; back to the Guild Hall."*

The cozy register applies:
- **Identity, not abstraction.** Each hero is a person — Theron the Warrior, Mira the Mage. The detail modal reinforces personhood (portrait + name + history-via-level).
- **Predictable progression.** Level cost is deterministic per ADR-0013 (`level_cost(tier, current_level)`); what the player sees is what they'll be charged.
- **No buried information.** XP-to-next-level + cost-to-level-via-gold are both visible. Player can plan: "I need 600g to level Theron up; I'll dispatch one more run."
- **Modal-friendly dismissal.** Tap-outside-to-dismiss is the cozy default (matches Settings overlay per Settings GDD #30 §C.6); no "Are you sure?" prompts; no destructive actions.

---

## C. Detailed Rules

### C.1 Layout

The modal Control hierarchy follows the Settings overlay pattern (per Settings GDD #30 §C.1):

```
hero_detail_modal.tscn (Control, modal-anchored)
├── DimBackdrop (ColorRect, alpha=0.5, gui_input → dismiss)
└── DetailPanel (PanelContainer, parchment-themed via UIFramework.apply_parchment_panel, centered, max_width=400px)
    ├── HeaderRow (HBoxContainer)
    │   ├── ClassPortrait (TextureRect, 96×96 logical px, placeholder when class.portrait absent)
    │   └── HeaderLabels (VBoxContainer)
    │       ├── DisplayNameLabel (Label, IdentityHeader theme variation, "Theron")
    │       ├── ClassNameLabel (Label, slate-ink secondary, "Warrior")
    │       └── OwnedCountLabel (Label, slate-ink secondary, "(3 warriors total)")
    ├── DividerLine (HSeparator, parchment-grain)
    ├── StatsBlock (VBoxContainer)
    │   ├── LevelRow (HBoxContainer: "Level" label + LevelValue label "5")
    │   └── XPRow (VBoxContainer)
    │       ├── XPLabel (Label, "XP: 250 / 350")
    │       └── XPProgressBar (ProgressBar, 250/350 fill, parchment-themed)
    ├── ActionRow (HBoxContainer, justified-around)
    │   ├── LevelUpButton (Button, "Level Up — 450g", parchment-themed; SelectedSlotButton variation when affordable)
    │   └── CloseButton (Button, "Close", parchment-themed)
```

Sizing/spacing notes (anchored to UIFramework + Art Bible §4):
- DetailPanel max_width: 400px (cozy modal sizing per Settings precedent).
- DimBackdrop covers full screen; alpha=0.5 dim on parchment background.
- ClassPortrait: 96×96 logical px (matches Recruit Screen GDD #21 §C.1 sizing).
- All Buttons: min height 44 logical px per `.claude/docs/technical-preferences.md` Touch Support requirement.
- DetailPanel padding: 24 logical px parchment gutter.
- StatsBlock vertical spacing: 12 logical px between rows.

### C.2 Lifecycle hooks

`hero_detail_modal.gd` extends `Screen` (per `src/core/scene_manager/screen.gd`); shown via `SceneManager.show_modal(self)`, dismissed via `SceneManager.hide_modal(self)`.

The modal receives the hero's `instance_id` via a setter called BEFORE `show_modal` — pattern per Settings overlay's `set_target` style:

```gdscript
# Caller (Guild Hall):
var modal := preload("res://assets/screens/hero_detail/hero_detail_modal.tscn").instantiate()
modal.set_target_hero(instance_id)
SceneManager.show_modal(modal)
```

**on_enter:**
- Resolve hero via `HeroRoster._heroes[_target_instance_id]` — null-guard with push_warning + auto-dismiss if absent (race condition: hero removed between tap and modal display)
- Resolve class via `DataRegistry.resolve("classes", hero.class_id)` — null-guard with push_warning + auto-dismiss if orphan
- Connect `HeroRoster.hero_leveled` → `_on_hero_leveled` (refresh on self-level-up via the LevelUpButton OR cascade from XP grant)
- Connect `Economy.gold_changed` → `_on_gold_changed` (refresh LevelUpButton affordability)
- Connect `HeroRoster.hero_removed` → `_on_hero_removed` (auto-dismiss if THIS hero is removed; rare V1.0+ retire-UI scenario)
- Connect `HeroRoster.hero_recruited` → `_on_hero_recruited` (refresh OwnedCountLabel if a new hero of the same class is recruited)
- Wire LevelUpButton.pressed → `_on_level_up_pressed`
- Wire CloseButton.pressed → `_on_close_pressed`
- Wire DimBackdrop.gui_input → `_on_backdrop_input` (mouse/touch outside modal → dismiss per cozy register)
- Initial render: `_refresh_all()` (header, stats, level-up button cost + gating)

**on_exit:**
- Disconnect all 4 signals + 3 button presses
- DimBackdrop input disconnect

**on_pause / on_resume:**
- pass — modal does not pause the underlying Guild Hall (it's a passive overlay)

### C.3 Header render

`_refresh_header()`:
- ClassPortrait.texture from class_data.portrait (placeholder when null)
- DisplayNameLabel.text = hero.display_name (immutable; no formatting)
- ClassNameLabel.text = `tr(class_data.display_name_key)` (locale-aware)
- OwnedCountLabel.text = `tr("hero_detail_owned_format")` formatted with `HeroRoster.get_copies_owned(hero.class_id)` — e.g., "(3 warriors total)" or "(1 warrior total)" with locale-correct pluralization

### C.4 Stats render

`_refresh_stats()`:
- LevelValue.text = "%d" % hero.current_level
- XPLabel.text computed from XP fields:
  - If `hero.current_level >= LEVEL_CAP`: XPLabel = `tr("hero_detail_xp_capped")` → e.g., "MAX LEVEL"; XPProgressBar.value = 1.0; bar styled with full-fill golden tint
  - Else: XPLabel = `tr("hero_detail_xp_format")` formatted with `hero.xp` and `HeroRoster.xp_threshold(hero.current_level)` (per Hero Leveling GDD #15 §C.3); XPProgressBar.value = `hero.xp / float(threshold)` clamped to [0, 1]
- Both fields update on `hero_leveled` signal subscriber

### C.5 Level-Up button

`_refresh_level_up_button()`:
- If `hero.current_level >= LEVEL_CAP`: button hidden (cozy register; no negative-feedback "can't level up" state)
- Else:
  - cost = `Economy.level_cost(class_data.tier, hero.current_level)` per ADR-0013 + Economy GDD §G
  - LevelUpButton.text = `tr("hero_detail_level_up_format")` formatted with `format_short_number(cost)` — e.g., "Level Up — 450g"
  - LevelUpButton.disabled = (Economy.get_gold_balance() < cost)
  - LevelUpButton theme variation: SelectedSlotButton (warm) when affordable; default (dimmed) when not

### C.6 Level-Up interaction

`_on_level_up_pressed()`:
1. Defensive check: `hero.current_level < LEVEL_CAP` — if at cap, push_warning + return (visibility gate should prevent this path)
2. Compute cost at tap time: `cost = Economy.level_cost(class_data.tier, hero.current_level)`
3. Atomic transaction (mirrors Recruitment.try_recruit pattern per Recruitment §C.5):
   - `Economy.try_spend(cost, "level_up")` → returns false on insufficient gold; toast "Not enough gold."
   - On true: `HeroRoster.set_hero_level(hero.instance_id, hero.current_level + 1)` — clamps to LEVEL_CAP, emits hero_leveled
4. Subscribers (this modal + AudioRouter chime + dungeon_run_view toast if visible) react via signals
5. Modal stays open (player may want to level multiple times in a row); LevelUpButton refreshes via `_on_hero_leveled` and `_on_gold_changed`

The transaction MUST be atomic — `try_spend` first, then `set_hero_level`. If `set_hero_level` somehow returned false (it shouldn't in practice — id always exists at tap time per the modal's hero resolution), the gold spend would NOT roll back. This is acceptable per existing single-writer pattern (see Recruitment GDD §E for the rollback discussion).

### C.7 Dismissal

`_on_close_pressed()` and `_on_backdrop_input(event)` both call `SceneManager.hide_modal(self)`. The backdrop input handler accepts `InputEventMouseButton.pressed` (any button) and `InputEventScreenTouch.pressed` for touch parity per `.claude/docs/technical-preferences.md`.

ESC key dismissal is V1.0+ (mouse/touch is the MVP-pinned input per technical-preferences.md "No keyboard-exclusive interactions").

### C.8 Auto-dismiss on stale hero

If the modal's target hero is removed from the roster while the modal is open (V1.0+ retire UI; should not occur in MVP):
- `hero_removed(id, ...)` signal subscriber checks `id == _target_instance_id`
- If true: push_warning("[HeroDetailModal] target hero removed; auto-dismissing") + `SceneManager.hide_modal(self)`

### C.9 Locale-aware formatting

All numeric labels use `UIFramework.format_short_number` for thresholds ≥1000 (consistent with Guild Hall + Recruit Screen). Class names use `tr(class.display_name_key)`. XP format string uses `tr("hero_detail_xp_format")` with %d substitutions. Owned-count uses `tr("hero_detail_owned_format")` with %d substitution AND locale-aware pluralization (English: "1 warrior" vs "3 warriors"; locale-correct via locale CSV columns per the existing locale infrastructure).

### C.10 reduce_motion accessibility

Per Settings GDD #30 §C + ADR-0008:
- `Settings.reduce_motion == true`: XPProgressBar value-set is instant (no fill animation); LevelUpButton tap-feedback uses 1.0× scale (no pulse); modal entrance/exit transitions are instant (no slide-in/fade).
- `reduce_motion == false`: XPProgressBar fills with a 200ms easing (cozy progress feedback); LevelUpButton uses 1.05× pulse per UIFramework; modal entrance/exit uses 200ms cross-fade.

---

## D. Formulas

### D.1 Level-up cost (cross-reference)

Per ADR-0013 + Economy GDD §G:
```
level_cost(tier, current_level) = floori(BASE_LEVEL[tier] × LEVEL_RATIO^(current_level - 1))
```
Where defaults: `BASE_LEVEL = {1: 40, 2: 600}`, `LEVEL_RATIO = 1.6`. Returns `-1` when `current_level >= LEVEL_CAP` (Hero Leveling GDD #15 §C.5 + AC-15-13).

The Hero Detail modal does NOT compute this independently — it READS via `Economy.level_cost(class_data.tier, hero.current_level)`. Cost-stability per ADR-0013: cost shown matches cost charged at try_spend time.

### D.2 XP threshold (cross-reference)

Per Hero Leveling GDD #15 §C.3:
```
xp_threshold(current_level) = XP_THRESHOLD_BASE + XP_THRESHOLD_STEP * current_level
```
Read via `HeroRoster.xp_threshold(current_level)`.

XPProgressBar.value = `hero.xp / float(threshold)` clamped to [0, 1]. When at LEVEL_CAP, value = 1.0 with full-fill golden tint per §C.4.

### D.3 Affordability (same pattern as Recruit Screen)

```
is_affordable(cost) = Economy.get_gold_balance() >= cost
```
Used in C.5 LevelUpButton gating. Returns false also when cost == -1 (LEVEL_CAP path) — though that path hides the button rather than disabling it.

### D.4 Owned count (cross-reference)

```
owned(class_id) = HeroRoster.get_copies_owned(class_id)
```
Used in C.3 OwnedCountLabel render.

---

## E. Edge Cases

### E.1 Tap a hero that's been removed
Race condition: player taps a HeroCard, but between the tap and modal display, `HeroRoster.remove_hero(id)` is called (V1.0+ retire UI). On_enter resolves null hero; push_warning + auto-dismiss without showing modal. Player sees the dim flash + immediate dismiss; no visible error.

### E.2 Tap a hero whose class becomes orphan
Content patch removes the class. DataRegistry.resolve returns null on modal enter. Per C.2, push_warning + auto-dismiss. Same UX as E.1.

### E.3 Insufficient gold at tap time
Gold dropped between render and tap. `try_spend` returns false. Toast "Not enough gold." displays for 3.0s; modal stays open; LevelUpButton dimmed via `gold_changed` signal subscriber.

### E.4 Hero reaches LEVEL_CAP via this modal
Player taps Level Up at level 14; transaction succeeds → level 15 (cap). `hero_leveled` fires; `_refresh_stats` sees `current_level == LEVEL_CAP`; XPLabel shows "MAX LEVEL"; LevelUpButton hides; cozy "achievement" feel (no pop-up celebration in MVP — V1.0+ may add a confetti animation).

### E.5 Hero leveled externally while modal open
Player has the modal open while a kill cascade levels their hero up via `HeroRoster.add_xp` (e.g., dispatched a run, came back to Guild Hall, dispatched again, opened the detail modal — but a backgrounded run could complete via offline replay and trigger a level-up). `_on_hero_leveled` re-renders stats; XPProgressBar updates; LevelUpButton cost re-computes; player sees the cascade live.

### E.6 Modal opens during offline replay
Per ADR-0014 + OfflineProgressionEngine §C.6, signals are suppressed during replay. The modal subscribes to `hero_leveled` + `gold_changed` + `hero_recruited`; during replay these don't fire. Modal renders the pre-replay state stably until flush completes; on flush, aggregate signals fire → modal re-renders. Cozy: no flickering mid-replay.

### E.7 Save / load mid-modal
SaveLoadSystem persists during heartbeat or scene boundary. `_suppress_signals` is set true during hydration per ADR-0004; modal subscribers don't fire spurious refreshes. On hydration completion, `_refresh_all` could be called as a safety net (though the next signal that fires anyway would refresh). MVP: trust the signal chain; hydration is fast enough that visible flicker is sub-frame.

### E.8 Multiple modal opens (fast tap-spam)
Player taps multiple HeroCards rapidly. Per SceneManager.show_modal contract, only one modal can be active at a time. Subsequent show_modal calls are queued or rejected per SceneManager's policy. The modal must be designed to handle "modal already open" gracefully — Guild Hall HeroCard tap handler should check `SceneManager.is_modal_visible()` and ignore taps when true, OR show_modal should idempotently dismiss the prior modal first. **Resolution path**: Guild Hall HeroCard tap handler ignores taps while a modal is open (gating).

### E.9 reduce_motion midway through level-up
Player toggles reduce_motion via Settings overlay (V1.0+ scenario; MVP doesn't support live toggle without restart). XPProgressBar refreshes pick up the new setting on next signal-driven refresh. MVP-safe.

### E.10 Locale change midway through modal
V1.0+ scenario; MVP locale is set at boot and doesn't change. Modal labels re-render on next on_enter (i.e., next tap) per Recruit Screen E.8 precedent.

### E.11 Modal opened on non-existent class portrait
Class portraits are placeholder rectangles in MVP per Recruit Screen GDD #21 §I OQ-21-3 (audio-style sourcing decision pending). Modal shows colored rectangle per tier. ADR-0016 silent-MVP precedent: ship with placeholder; pivot when assets land.

---

## F. Dependencies

### Hard dependencies (Hero Detail Modal requires these to function)

| System | Why | Surface used |
|---|---|---|
| `HeroRoster` (#9) | Hero state source | `_heroes[id]` (read), `set_hero_level(id, new_level)`, `xp_threshold(level)`, `level_cap()`, `get_copies_owned(class_id)`, `hero_leveled`/`hero_recruited`/`hero_removed` signals |
| `Economy` (#5) | Gold + level-up cost | `get_gold_balance()`, `level_cost(tier, current_level)`, `try_spend(amount, reason)`, `gold_changed` signal |
| `DataRegistry` (#2) | Class resource resolution | `resolve("classes", class_id)` |
| `HeroClassDatabase` (#6) | Class portrait + display name + tier | per-class data via DataRegistry |
| `SceneManager` (#4) | Modal show/hide | `show_modal(self)`, `hide_modal(self)` |
| `UIFramework` (#18) | Theme + touch feedback + format helpers | `apply_parchment_panel`, `wire_touch_feedback`, `format_short_number`, `format_localized` |
| `TranslationServer` (Godot built-in) | Localization | `translate(StringName)` |

### Reverse dependencies (systems that depend on Hero Detail Modal)

- **Guild Hall Screen** (#19) — RosterPanel HeroCards become tappable to open this modal (per Guild Hall §C.4 note)

### Soft dependencies

- **AudioRouter** (#28) — level-up chime fires via existing `hero_leveled` subscriber; modal does not invoke audio directly

### V1.0 progression-layer additions (added 2026-05-09)

The following V1.0-tier system extends this modal:

- **Prestige System** (#31, V1.0 first-pass 2026-05-09) — adds a "Prestige Hero" button visible when `HeroRoster.is_prestige_eligible(instance_id)` returns true (hero at LEVEL_CAP=15, prestige_count below max). Tap shows confirmation modal with cozy copy ("[hero_name] has earned their retirement..."). Confirm calls `HeroRoster.prestige_hero(instance_id)` which is synchronous + persists. The button replaces the Level-Up button at LEVEL_CAP (existing modal hides Level-Up at cap per §C.5 step 1; Prestige System fills the slot). Per `prestige-system.md` §C.2 + §F. Locale keys: `prestige_button_label`, `prestige_confirmation_modal_body`, `prestige_confirmation_button_confirm/_cancel`, `prestige_complete_toast`, `prestige_disabled_active_run_tooltip`.

---

## G. Tuning Knobs

### Layout knobs (parchment_theme + modal.tscn)
- DetailPanel max_width: 400px (cozy modal sizing).
- ClassPortrait size: 96×96 logical px (matches Recruit Screen).
- DetailPanel padding: 24 logical px parchment gutter.
- StatsBlock row spacing: 12 logical px.

### Animation knobs (UIFramework constants per ADR-0008)
- Modal entrance/exit cross-fade: 200ms (matches Settings overlay precedent).
- XPProgressBar fill animation: 200ms ease-out. reduce_motion → instant.
- LevelUpButton tap-feedback: UIFramework.TOUCH_PULSE_SCALE 1.05 / EXPAND 0.08s / RETURN 0.016s.
- DimBackdrop alpha: 0.5 (parchment-friendly dim per Settings precedent).

### Toast knobs
- Toast linger: 3.0s (formation_assignment + Recruit Screen precedent).
- Toast fade: 0.6s.

### Cost / threshold knobs (cross-reference, NOT owned by this screen)
- BASE_LEVEL, LEVEL_RATIO, LEVEL_CAP: per Economy GDD §G + EconomyConfig.
- XP_THRESHOLD_BASE, XP_THRESHOLD_STEP: per Hero Leveling GDD #15 §G + EconomyConfig.

### V1.0+ knob: dedicated full-screen Roster
When roster grows past Guild Hall RosterPanel's visible card count (~8-12 depending on screen height), a dedicated full-screen "Roster" view is needed. V1.0+ scope; tuning knob: `ROSTER_OVERVIEW_THRESHOLD: int = 12` — when roster.size() exceeds this, Guild Hall's RosterPanel becomes scrollable AND/OR a "View All Heroes" button appears that navigates to a dedicated roster screen. MVP defers this; Guild Hall RosterPanel is the roster overview.

---

## H. Acceptance Criteria

**AC-22-01 — Modal opens with target hero data on Guild Hall HeroCard tap**
Tapping a HeroCard on Guild Hall calls `set_target_hero(instance_id)` then `SceneManager.show_modal(modal)`. Modal renders with the correct hero's portrait, name, class, level, owned-count.

**AC-22-02 — DisplayNameLabel matches hero.display_name**
Header DisplayNameLabel shows the immutable hero.display_name string (e.g., "Theron").

**AC-22-03 — ClassNameLabel and ClassPortrait match the hero's class**
Resolved via `DataRegistry.resolve("classes", hero.class_id)`; locale-correct ClassNameLabel; class portrait or placeholder texture.

**AC-22-04 — OwnedCountLabel matches HeroRoster.get_copies_owned**
Reads `HeroRoster.get_copies_owned(hero.class_id)`; locale-correct pluralization.

**AC-22-05 — LevelValue label matches hero.current_level**
Reads hero.current_level as integer.

**AC-22-06 — XPLabel + XPProgressBar match hero.xp / xp_threshold**
At level < LEVEL_CAP: XPLabel = `"%d / %d"` formatted; XPProgressBar.value = xp / threshold clamped [0, 1].

**AC-22-07 — At LEVEL_CAP: XPLabel reads "MAX LEVEL"**
hero.current_level == LEVEL_CAP → XPLabel = `tr("hero_detail_xp_capped")`; bar at full-fill golden tint.

**AC-22-08 — LevelUpButton hidden at LEVEL_CAP**
hero.current_level == LEVEL_CAP → LevelUpButton.visible = false.

**AC-22-09 — LevelUpButton text shows level_cost from Economy**
Formatted via `format_short_number`. Reads `Economy.level_cost(class.tier, hero.current_level)`.

**AC-22-10 — LevelUpButton affordability gating**
Disabled when gold < cost; SelectedSlotButton variation when affordable.

**AC-22-11 — Level-Up press is atomic transaction**
`try_spend` first, then `set_hero_level`. On success: gold debits + level increments + hero_leveled fires + chime + modal refreshes. On try_spend failure: toast shown; modal stays open.

**AC-22-12 — hero_leveled signal triggers stat refresh**
External cascade (e.g., XP grant from offline replay) refreshes XPLabel + XPProgressBar + LevelUpButton cost.

**AC-22-13 — gold_changed signal triggers LevelUpButton refresh**
External gold mutation refreshes affordability gating.

**AC-22-14 — hero_recruited signal triggers OwnedCountLabel refresh**
Recruiting another hero of the same class increments the displayed count.

**AC-22-15 — hero_removed signal auto-dismisses modal if target removed**
If the target hero's id is removed (V1.0+ retire UI), modal auto-dismisses with push_warning.

**AC-22-16 — Backdrop tap dismisses modal**
DimBackdrop receives mouse-button-pressed OR touch-pressed events → calls `hide_modal`.

**AC-22-17 — CloseButton dismisses modal**
CloseButton.pressed → `hide_modal`.

**AC-22-18 — Touch-feedback on all buttons**
LevelUpButton + CloseButton use `UIFramework.wire_touch_feedback`. reduce_motion → 1.0× scale.

**AC-22-19 — reduce_motion suppresses XPProgressBar fill animation + modal cross-fade**
reduce_motion == true → instant value-set on bar; instant modal show/hide.

**AC-22-20 — Locale-aware labels**
ClassNameLabel + OwnedCountLabel + XPLabel + LevelUpButton text all use locale-keyed strings.

---

## I. Open Questions & ADR Candidates

**OQ-22-1 — Sort order for Guild Hall RosterPanel after this lands**
Guild Hall RosterPanel currently sorts BY_CLASS-then-BY_LEVEL_DESC per HeroRoster default. Should the modal expose a "go to next hero" / "previous hero" navigation within the modal so the player can browse without dismissing? MVP says NO — dismiss + tap the next card. V1.0+ may add navigation arrows.

**OQ-22-2 — Show a dedicated full-screen Roster view**
When roster grows large (V1.0+), a separate roster view becomes useful. Tuning knob in §G captures the threshold. Defer to V1.0+ scope.

**OQ-22-3 — Hero rename UI**
MVP: names are immutable post-recruit per ADR-0012. Should the player be able to rename their heroes? Cozy register suggests YES (personalization is engagement); MVP says NO (data complexity + immutability is simpler). V1.0+ candidate.

**OQ-22-4 — Hero retire / dismiss UI**
MVP has no way to remove heroes from the roster; V1.0+ retire UI would surface here as a "Retire" button (secondary, requires confirmation). AC-22-15 already documents the auto-dismiss-on-removal contract. V1.0+ scope.

**OQ-22-5 — Per-hero stats beyond level**
MVP shows level + XP. V1.0+ may show: kills participated in, runs survived, longest streak. Cozy "this hero's history" feel. Out of MVP scope.

**OQ-22-6 — Confirm-on-level-up at high cost**
At late-game, level-up cost can be substantial (BASE_LEVEL=600 × 1.6^14 ≈ 116,490g for tier 2 at level 14). Should an expensive level-up require a confirmation tap? MVP says NO — single-tap is the cozy default; player owns their own decisions. If post-launch playtest reveals fat-finger spending complaints, add a confirm threshold.

**OQ-22-7 — Background opacity of DimBackdrop**
0.5 alpha matches Settings overlay; Settings is a "you're configuring something" dim, while Hero Detail is a "you're inspecting an entity" dim. Should the latter be lighter (0.3) so the underlying Guild Hall is more visible? Cozy register may prefer the lighter dim. MVP: 0.5 for consistency; revisit during /design-review.

**OQ-22-8 — Tap-outside-modal dismissal vs accidental dismiss**
DimBackdrop input dismissal is the cozy default but also the "I accidentally dismissed before tapping Level Up" failure mode. Mitigation: button placement leaves clear margin between DetailPanel edge and DimBackdrop boundary. If post-launch playtest reveals accidental dismissals, add a small "are you in the middle of something?" delay (e.g., 200ms hold-to-dismiss instead of instant tap-to-dismiss).

---

## J. Implementation Sequencing (Sprint 15+ candidate)

This GDD is design-first; implementation is Sprint 15+ candidate scope (~0.75d). Pre-sequenced as 4 stories:

1. **Story 1 (~0.2d)** — `hero_detail_modal.tscn` authoring per §C.1 layout. Anchor preset 0 + DimBackdrop ColorRect + parchment-themed DetailPanel with HeaderRow + StatsBlock + ActionRow. Editor work; no .gd changes required.
2. **Story 2 (~0.25d)** — `hero_detail_modal.gd` lifecycle hooks per §C.2. on_enter / on_exit signal subscriptions; set_target_hero setter; resolve hero + class with null-guards; wire all 3 button + backdrop event handlers; touch_feedback on all buttons. Tests for ACs 22-01 (target resolution), 22-15 (auto-dismiss on removal).
3. **Story 3 (~0.2d)** — Render logic per §C.3 / §C.4 / §C.5. `_refresh_header`, `_refresh_stats`, `_refresh_level_up_button`. Tests for ACs 22-02 through 22-10, 22-12 through 22-14.
4. **Story 4 (~0.1d)** — Level-Up interaction per §C.6 + dismissal per §C.7 + accessibility per §C.10. Tests for ACs 22-11, 22-16, 22-17, 22-18, 22-19.

Plus Guild Hall integration (~0.05d): make HeroCards tappable on Guild Hall (#19 §C.4 note), wire taps to open this modal with the tapped hero's instance_id. Skipped from Sprint 14 S14-S5 if S14-S5 ships before this GDD; otherwise rolled into S14-S5.

Total Sprint 15+ scope: ~0.75d. Pairs with Guild Hall full implementation (S14-S5) — best landed in the same sprint to surface the cross-screen contract immediately.

---

## Notes

- Authored 2026-05-07 by post-Recruit-Screen-GDD autonomous-execution session, continuing the Sprint-14-prep design-coverage push (7th first-pass GDD across the cumulative 2026-05-06 + 2026-05-07 sessions). systems-index.md row 22 status flips from "Not Started" to "DRAFT 2026-05-07".
- All ACs are testable via patterns documented in `tests/PATTERNS.md`.
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED.
- The "Roster" half of the GDD title is satisfied by Guild Hall #19's existing RosterPanel; this GDD scopes only the Hero Detail modal sub-component. A dedicated full-screen Roster view is V1.0+ scope (tuning knob in §G).
- Closes the design-coverage gap for Roster / Hero Detail Screen that has existed since the Sprint 1 GDD-authoring pass — systems-index.md row 22 has been "Not Started" since project inception.
- This GDD pairs with Hero Leveling GDD #15 (XP curve + add_xp consumer ecosystem) + Economy GDD #5 (level_cost + try_spend) + Guild Hall GDD #19 (the originator of the modal tap path).
- Implementation pre-scheduled for Sprint 15+ alongside Guild Hall full implementation (S14-S5 if it slips to Sprint 15) to surface the cross-screen tap-to-modal contract in one sprint.
