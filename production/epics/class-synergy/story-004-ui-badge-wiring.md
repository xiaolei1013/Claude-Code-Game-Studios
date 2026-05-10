# Story 004: UI badge wiring on formation_assignment screen + reduce-motion variant

> **Epic**: class-synergy
> **Status**: Complete (2026-05-10)
> **Layer**: Gameplay (UI)
> **Type**: UI
> **Manifest Version**: 2026-04-26

---

## Context

**GDD**: `design/gdd/class-synergy-system.md` §C.2 (live preview detection timing) + §C.4 (audio + visual feedback) + §G (`class_synergy_badge_glow_duration_seconds = 0.4`)
**Requirements**: AC-CS-15 (localized strings via `tr()`), AC-CS-17 (reduce-motion variant), AC-CS-20 (perf: detection runs <1ms p99)

**Governing ADR(s)**: ADR-0007 (persistent root scene + reduce_motion accessibility), ADR-0008 (mouse_filter defaults + localization-ready strings)
**ADR Decision Summary**: The synergy badge is a screen-side Label that re-evaluates after every formation slot mutation by calling `FormationAssignment.detect_active_synergy(snapshot)`. State de-dup at the screen level (track `_current_synergy_id` across refreshes) prevents the glow tween + audio chime from re-triggering when slot toggles don't change the composition multiset. The reduce-motion variant skips the glow tween entirely and uses an alternate theme variation, mirroring the canonical pattern in `hero_detail_modal.gd::_is_reduce_motion_enabled`.

**Engine**: Godot 4.6 | **Risk**: LOW (UI-only; pattern mirrors existing toast + prestige UI slices)

**Control Manifest Rules (Gameplay UI Layer)**:
- **Required**: All player-facing synergy strings route through `tr()` (AC-CS-15). Locale keys live in `assets/locale/en.csv` (already shipped in Sprint 21 S21-S2).
- **Required**: Reduce-motion path skips ALL synergy badge animations (AC-CS-17). Theme variation `class_synergy_badge_active_reduced_motion` is used when `SceneManager.reduce_motion = true`.
- **Required**: Tween cleanup in `on_exit()` — badge glow tween must be killed before the screen frees so the bound `modulate.a` target isn't a freed Label.
- **Forbidden**: NO popups, NO modals, NO fanfare animation per GDD §C.4 cozy-register constraint.

---

## Acceptance Criteria

- [x] Formation_assignment screen has a `SynergyBadge` Label node positioned just above the FormationPanel slots area.
- [x] Badge re-evaluates active synergy after every formation slot mutation (calling `_refresh_synergy_badge()` from `_refresh_formation_panel()`).
- [x] Badge text renders as `"<DisplayName>: <Effect>"` using `tr("class_synergy_badge_<id>")` and `tr("class_synergy_effect_<id>")` (AC-CS-15).
- [x] Badge hides (visible=false) when no synergy is active (composition doesn't match any V1.0 first-pass synergy).
- [x] Badge fades in over `SYNERGY_BADGE_GLOW_DURATION_SEC = 0.4` seconds via tween on `modulate:a` (full-motion path; per GDD §G).
- [x] **AC-CS-17** — When `SceneManager.reduce_motion = true`: badge appears at full alpha instantly (no tween), theme variation `class_synergy_badge_active_reduced_motion`.
- [x] When reduce_motion=false: badge uses theme variation `class_synergy_badge_active`.
- [x] State de-dup: rapid slot toggles within the same composition multiset (e.g., swapping two warriors between slots while 3-Warrior is active) do NOT re-trigger the glow tween or audio chime. Tracked via `_current_synergy_id`.
- [x] Audio chime fires via `FormationAssignment.notify_synergy_detected(synergy_id)` only when synergy CHANGES to non-empty. AudioRouter's 2.0s throttle is a backstop, not the primary de-dup.
- [x] In-flight badge tween is killed in `on_exit()` to avoid modulating a freed Label node.

---

## Implementation Notes

- **Scene addition**: `SynergyBadge` Label node added at root level of `formation_assignment.tscn` as a sibling of FormationPanel (PanelContainer is single-child; can't nest the badge inside). Anchored at top=0.66 / bottom=0.70 / full width with autowrap, so it sits visually just above the formation slots. `mouse_filter = 2` (decorative; no input capture).
- **Screen wiring**: `formation_assignment.gd` adds `@onready var _synergy_badge: Label`, const `SYNERGY_BADGE_GLOW_DURATION_SEC = 0.4`, two theme-variation StringName constants, two state vars (`_current_synergy_id`, `_synergy_badge_tween`), and four private helpers (`_refresh_synergy_badge`, `_build_formation_snapshot`, `_is_reduce_motion_enabled`, `_kill_synergy_badge_tween`).
- **Refresh hook**: `_refresh_synergy_badge()` is called from the existing `_refresh_formation_panel()` after the slot button rebuild. This catches every formation mutation (initial render, slot tap, hero tap, hero recruited/removed) without adding new signal subscriptions.
- **Snapshot construction**: `_build_formation_snapshot()` builds `{ "instance_ids": Array[int] }` from `HeroRoster.get_formation_slot(i)` over `formation_size()`. Empty slots (id=0) cause `detect_active_synergy` to return `""` per AC-CS-05.
- **Reduce-motion read**: `_is_reduce_motion_enabled()` defensively checks `/root/SceneManager` exists and has the `reduce_motion` property — mirrors the canonical pattern from `hero_detail_modal.gd:460`.
- **Tween cleanup**: `on_exit()` kills the badge tween (mirrors the existing toast tween cleanup at the same site).

### Refresh sequence

```
formation slot mutation
  ├─ _refresh_formation_panel()  // existing
  │   ├─ rebuild slot buttons
  │   └─ _refresh_synergy_badge()  // NEW
  │       ├─ snapshot = _build_formation_snapshot()
  │       ├─ synergy_id = FormationAssignment.detect_active_synergy(snapshot)
  │       ├─ if synergy_id == _current_synergy_id: return  // de-dup
  │       ├─ _current_synergy_id = synergy_id
  │       ├─ if synergy_id == "": hide badge, kill tween, return
  │       ├─ render text via tr() keys
  │       ├─ if reduce_motion: alt theme + alpha 1.0 instantly
  │       ├─ else: animated theme + alpha 0 → tween to 1.0 over 0.4s
  │       └─ FormationAssignment.notify_synergy_detected(synergy_id)
  │             └─ class_synergy_detected_signal emit (AudioRouter throttled)
```

---

## Test Evidence

| Test File | AC Coverage |
|---|---|
| `tests/unit/formation_assignment/synergy_badge_test.gd` (NEW) | Visibility (Group A: hidden / shown / hide-on-break), localized text rendering (Group B: AC-CS-15), state de-dup (Group C: composition unchanged → no re-trigger), reduce-motion variant (Group D: AC-CS-17 instant alpha + alt theme), tween cleanup (Group E: on_exit kills in-flight tween) |

The autoload-side detection function (`FormationAssignment.detect_active_synergy`) is exercised by the existing `tests/unit/formation_assignment/class_synergy_detection_test.gd` (Stories 1 covered AC-CS-01..05 + edge cases).

---

## Closure Notes

- **Closes the V1.0 Class Synergy implementation epic.** All 4 stories now Complete: detection logic + RunSnapshot field, attribute_kill formula extension, audio + locale, UI badge wiring. The epic is implementation-complete pending V1.0 playtest data per AC-CS-19 (balance regression check — needs simulator-driven data, not unit-test-able).
- **Cross-system surfaces still V1.0+ deferred** per GDD §C.5 + Open Questions:
  - OQ-32-5 — Recruit Screen "synergy preview" surface (V1.0+ UX iteration; recommend hide-by-default with accessibility toggle)
  - OQ-32-5 — Roster/Hero Detail Modal "this hero appears in N synergies" hint (V1.0+ UX iteration)
  - OQ-32-5 — Matchup Assignment Screen Steel Wall + biome dominant_archetype combined hint (V1.0+ UX iteration)
- **No design deviations** from GDD §C.4 + AC-CS-17. The badge placement (top-of-FormationPanel sibling) was chosen because PanelContainer is single-child — the alternative (wrapping SlotsHBox in a VBoxContainer inside FormationPanel) would have required updating the existing `$FormationPanel/SlotsHBox` @onready path and broken existing tests. The sibling-with-anchor placement is the smaller-blast-radius choice.
- **Theme variations may not yet exist in `parchment_theme.tres`.** When the variations are absent, Godot falls back to the default Label theme — no runtime error, just a visually undecorated badge. Adding parchment styling for the two variations is a `/design-review` polish pass, deferred to a future Visual Identity Anchor iteration.
- **Visual placement may need tuning** — the 4% vertical band (anchor_top=0.66 to anchor_bottom=0.70) is a thin strip. Player-visible during real playtest may surface a need to either expand the band or relocate the badge below the slots. Defer to playtest feedback.
