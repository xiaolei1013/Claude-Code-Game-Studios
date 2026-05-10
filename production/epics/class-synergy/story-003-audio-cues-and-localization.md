# Story 003: Audio cues + localization keys

> **Epic**: class-synergy
> **Status**: Complete (locale 2026-05-09; audio subscriber 2026-05-09 + 2026-05-10 throttle; story file 2026-05-10 audit-cascade closure)
> **Layer**: Gameplay (Integration)
> **Type**: Integration
> **Manifest Version**: 2026-04-26

---

## Context

**GDD**: `design/gdd/class-synergy-system.md` §C.4 — audio + visual feedback (cozy register)
**Requirements**: AC-CS-14 (audio cue suppression on rapid slot toggling), AC-CS-15 (localization — 6 new keys via `tr()`)

**Governing ADR(s)**: ADR-0008 (localization-ready strings via `tr()` for all player-facing text), ADR-0016 (audio asset sourcing — silent-MVP)
**ADR Decision Summary**: Audio integration follows the silent-MVP path — AudioRouter subscribes to two new signals (`class_synergy_detected_signal`, `class_synergy_dispatched_signal`), routes through `play_sfx`, and the cue resource is intentionally absent in MVP. Locale strings are the 6 keys for badge label + effect summary across 3 synergies. All player-facing strings route through `tr()`; CI grep enforces no hardcoded names.

**Engine**: Godot 4.6 | **Risk**: LOW (signal-subscriber pattern; mirrors existing audio routes)

**Control Manifest Rules (Gameplay Layer)**:
- **Required**: `sfx_class_synergy_detected` cue throttle window = 2.0s per `audio-system.md` §F (single source of truth; Class Synergy GDD G note added 2026-05-10 confirms re-use, no synergy-specific knob).
- **Required**: All 6 synergy strings use `tr("class_synergy_<badge|effect>_<id>")` keys; CI grep blocks hardcoded display names in `assets/screens/formation_assignment/` and `assets/screens/dungeon_run_view/`.
- **Forbidden**: NO mid-run audio. Synergy is established at dispatch; the player has already "felt" it in the live preview chime.

---

## Acceptance Criteria

- [x] **AC-CS-14** — Rapid slot-toggling that fires `class_synergy_detected_signal` 5 times within 1.0s plays the chime ONCE. Subsequent emissions within the 2.0s suppress window are throttled.
- [x] **AC-CS-15** — All 6 synergy strings (3 badges + 3 effect summaries) exist in `assets/locale/en.csv` and route through `tr()`.
- [x] AudioRouter subscribes to BOTH `class_synergy_detected_signal` (FormationAssignment, autoload rank 11) AND `class_synergy_dispatched_signal` (DungeonRunOrchestrator, autoload rank 14) at `_ready()`.
- [x] Dispatch-time chime is NOT throttled — DungeonRunOrchestrator's natural DISPATCH_DEBOUNCE_MS (250ms) rate-limits emissions; no per-cue throttle needed.
- [x] Both cues route through `play_sfx`, which honors the silent-MVP fallback (DataRegistry returns null for absent cue resource → no-op, no crash).

---

## Implementation Notes

- **AudioRouter handlers**: `src/core/audio_router/audio_router.gd:540` (`_on_class_synergy_detected`) + `:559` (`_on_class_synergy_dispatched`). Throttle clock var `_class_synergy_detected_last_played_ms` + const `_CLASS_SYNERGY_DETECTED_THROTTLE_MS = 2000`.
- **Subscriptions**: `audio_router.gd:200` (orchestrator dispatched signal) + `:205` (formation_assignment detected signal). Defensive `has_signal` guard before `connect`.
- **Cue routing**: both ids added to `_CUE_BUS_MAP` and `_CUE_VOLUME_MULT_MAP` — route to `SFX/Reward` bus at appropriate volume_mult.
- **Locale file**: `assets/locale/en.csv:40-45` — 6 keys total:
  - `class_synergy_badge_steel_wall` → "Steel Wall"
  - `class_synergy_badge_arcane_elite` → "Arcane Elite"
  - `class_synergy_badge_triple_threat` → "Triple Threat"
  - `class_synergy_effect_steel_wall` → "+25% gold vs bruisers"
  - `class_synergy_effect_arcane_elite` → "+20% XP from all kills"
  - `class_synergy_effect_triple_threat` → "+15% gold from all kills"

---

## Test Evidence

| Test File | AC Coverage |
|---|---|
| `tests/unit/audio_router/audio_router_signal_handlers_test.gd` (added 2026-05-10) | AC-CS-14 (throttle drops 2nd call, releases after window); subscription contract |
| Locale grep (manual / CI) | AC-CS-15 (6 keys present in en.csv) |

---

## Closure Notes

- **Audit-cascade closure 2026-05-10**: locale + signal subscriptions shipped Sprint 21 S21-S2; the AudioRouter throttle const + handlers were also in place. The 2026-05-10 follow-up (PR #41) added the equivalent prestige_completed throttle pattern. Story file deferred until now.
- **CI grep for hardcoded synergy names**: not yet implemented as a dedicated test. AC-CS-15 enforcement currently relies on code review. Recommend adding a `*_no_hardcoded_strings_test.gd` in a future hardening pass — applies to other player-facing systems too, not just synergy.
- **Cue resources**: per ADR-0016, `sfx_class_synergy_detected.ogg` and `sfx_class_synergy_dispatched.ogg` are intentionally absent in MVP. When the silent-MVP ADR is superseded, the cues become audible without code change.
