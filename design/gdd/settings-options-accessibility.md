# Settings / Options & Accessibility — GDD #30

> **Status: First-pass DRAFT 2026-05-06** by post-Sprint-13-S1 close-out (autonomous-execution session). All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md` and the `audio-system.md` / `recruitment-system.md` precedent. Run `/design-review` before declaring this GDD APPROVED.

---

## A. Overview

**Settings** is the player-controllable preferences surface — volume mix, mute, accessibility flags, locale. It owns no gameplay state: it's a thin UI layer over already-shipping autoload APIs (`AudioRouter` for audio, `SceneManager.set_reduce_motion` for motion, `TranslationServer` for locale). No new persistence schemas; existing per-consumer `get_save_data` / `load_save_data` (audio) and `user://settings.cfg` ConfigFile (reduce_motion) cover the storage surface.

The MVP Settings overlay is invoked from the Guild Hall via a gear icon. It opens as a modal over the current screen via `SceneManager.show_modal` (S12-S2 contract), pauses the current screen visually, but does NOT pause the tick loop (game-time keeps advancing — settings are tweaked while idle progression continues). On close, modal dismisses; AudioRouter applies any volume changes immediately; reduce_motion takes effect on the next transition.

---

## B. Player Fantasy

> *"I can quickly tune the experience to my context — quiet workplace, hard-of-hearing partner, accessibility needs — without leaving the game or losing my place."*

The Settings overlay should feel like the parchment-themed Guild Hall: warm, low-friction, no menus-of-menus. Three sliders + two toggles + a locale dropdown is the entire surface. Reset-to-defaults is a single button at the bottom — for the player who tweaked things and wants to undo without remembering the values.

The cozy register applies: no harsh feedback when adjusting, no warning toasts on extreme values, no "are you sure?" confirmations. The defaults are sane; the player is trusted to recover from their own choices.

Accessibility-first stance: every gameplay-relevant signal has an audio cue (S12-M6 wired) AND a visual cue (toast for hero_leveled, count for kills, etc.) — settings cannot break gameplay. Mute the audio entirely → game still playable. Enable reduce_motion → transitions are 50ms instead of 150–800ms; ceremony is an instant cut; touch feedback (1.05× pulse, 80ms) stays per S12-S2 §reduce_motion §G.

---

## C. Detailed Rules

### C.1 Settings overlay layout

The overlay is a single PanelContainer at center-screen, parchment-themed via `UIFramework.apply_parchment_panel`. Width 480px, dynamic height. Anchors centered. Closeable via:
- "Save" button at bottom (closes modal; persists via existing pathways)
- "Reset to Defaults" button (separate row; resets in-memory, requires Save click to persist)
- Escape key OR back-button (closes modal; auto-saves)
- Tap-outside (closes modal; auto-saves)

VBoxContainer rows in order:
1. **HeaderLabel** — `tr("settings_title")` ("Settings")
2. **MasterVolumeRow** — Label + HSlider + dB display (0–100% mapped to -INF dB at 0% to 0 dB at 100%)
3. **MusicVolumeRow** — Label + HSlider + dB display (same mapping)
4. **SFXVolumeRow** — Label + HSlider + dB display (same mapping)
5. **MuteToggleRow** — Label + CheckButton (Master mute, hard -INF override)
6. **Separator** — visual divider
7. **ReduceMotionToggleRow** — Label + CheckButton + helper text ("Faster transitions; ceremony cut to instant")
8. **LocaleRow** — Label + OptionButton (locale dropdown — Sprint 14+ will populate; MVP shows English-only)
9. **Separator**
10. **ResetToDefaultsButton**
11. **SaveButton**

### C.2 Volume slider mapping

Linear slider position [0.0, 1.0] maps to dB:

```
slider_to_db(s):
  if s <= 0.001: return -INF
  return 20.0 * log10(s)   # standard linear-to-dB conversion
```

Examples:
- s = 0.0 → -INF dB (mute via slider)
- s = 0.1 → -20 dB
- s = 0.5 → -6 dB
- s = 0.7 → -3 dB
- s = 1.0 → 0 dB

Inverse for restoring slider position from saved dB (per `AudioRouter.get_*_volume_db()`):
```
db_to_slider(db):
  if db == -INF: return 0.0
  return clamp(pow(10.0, db / 20.0), 0.0, 1.0)
```

Defaults (matching audio-system.md §C.7):
- Master: 0.0 dB → slider position 1.0
- Music: -8.0 dB → slider position ≈ 0.398
- SFX: -3.0 dB → slider position ≈ 0.708

### C.3 Mute toggle behavior

Master mute (via CheckButton) overrides the Master volume slider with a hard -INF dB. Per audio-system.md §E.5, mute is immediate — no fade. Reward fanfares in progress are silenced mid-cue. The intent is "when the player mutes, they expect immediate silence; deferring would feel sluggish."

When mute is enabled: Master slider visually dims (still adjustable; the value is saved, just bypassed by the mute). When mute is disabled: Master slider's stored value is restored.

Toggle state is persisted via `AudioRouter.set_master_muted(bool)` which routes through the existing `get_save_data` / `load_save_data` consumer surface.

### C.4 reduce_motion toggle behavior

Wired by S12-S2 — the toggle calls `SceneManager.set_reduce_motion(value)` which:
- Updates the in-memory flag immediately (next transition uses clamped duration)
- Persists to `user://settings.cfg` via ConfigFile (interim path; OQ-7 migration to Save/Load envelope when this GDD's persistence section lands)
- Emits no signal — the change is read at duration-getter time

Helper text under the toggle: `tr("settings_reduce_motion_helper")` ("Faster transitions; ceremony cut to instant.") — explains the visible effect without medical/accessibility framing (matches the cozy register).

### C.5 Locale selector (V1.0 forward-compat)

OptionButton populated by `TranslationServer.get_loaded_locales()`. MVP shows only "en" (English) in the dropdown — disabled/grayed if only one locale exists.

When changed: `TranslationServer.set_locale(locale_id)` is called; UI re-renders (each `tr()` call retraces); selection persists via `user://settings.cfg` `[locale] active_locale` key.

Forward-compat: V1.0 i18n delivery adds locale resources; this dropdown auto-populates from the loaded set. No GDD changes needed in this row.

### C.6 Reset to Defaults

Resets in-memory values to the defaults from §C.2 (volumes), §C.3 (mute=false), §C.4 (reduce_motion=false), and §C.5 (locale="en"). Does NOT auto-save — player must click Save to persist. This avoids the "I clicked Reset by accident, then closed the overlay, lost my settings" pitfall.

### C.7 Persistence routing

| Setting | Pathway | Persistence |
|---|---|---|
| Master / Music / SFX volume | `AudioRouter.set_*_volume_db()` | SaveLoadSystem consumer (per-autoload `get_save_data`/`load_save_data`) — namespaced under top-level `"audio"` key per audio-system.md §C.7 |
| Master mute | `AudioRouter.set_master_muted()` | Same consumer surface |
| reduce_motion | `SceneManager.set_reduce_motion()` | ConfigFile at `user://settings.cfg` (interim path; OQ-30-1 migration plan to Save/Load envelope per ADR-0007 §OQ-7) |
| Locale | `TranslationServer.set_locale()` + ConfigFile write | ConfigFile at `user://settings.cfg` `[locale] active_locale` (parallel to reduce_motion's `[accessibility] reduce_motion`) |

Save persistence is triggered by the Save button OR by tap-outside / escape (auto-save on close). The auto-save path mirrors the explicit Save button's effect — both call the same persist function.

---

## D. Formulas

### F.1 Linear-slider-to-dB curve (§C.2)

Standard 20·log10 audio convention. Documented in §C.2 above.

### F.2 No other formulas

Settings has no gameplay math. All other values are direct pass-throughs to existing autoload APIs.

---

## E. Edge Cases

### E.1 First-launch (no save data)

All values use defaults from §C.2 / §C.3 / §C.4 / §C.5. Settings overlay loads cleanly. The "Save" button on first open is a no-op (values match what would be saved); player perceives no state difference.

### E.2 Save corruption on volume settings

If `AudioRouter.load_save_data` receives a corrupt or missing field, it falls back to the per-field default per audio-system.md §E.2. Settings overlay re-reads via `AudioRouter.get_*_volume_db()` and shows the defaults — player sees the recovery seamlessly. No corruption banner needed (per cozy register).

### E.3 Mid-playback volume change

Volume slider drag emits `set_master_volume_db()` continuously (or on `value_changed` if drag-throttled). AudioRouter's `_apply_to_audio_server()` runs each call; live audio mix updates without artifacts. Reward fanfares + ambient music both re-mix in real time.

### E.4 Mute toggle during a Stinger

Per audio-system.md §E.5: mute is hard-immediate. Stinger that's playing at toggle time is silenced mid-cue. This is intentional — the player expects mute to mean "silent NOW".

### E.5 reduce_motion toggle mid-transition

Per Story 009 (S12-S2) §QA Test Cases: flipping reduce_motion mid-transition does NOT abort the in-flight tween. The clamp applies only to FUTURE `_resolved_duration_ms` calls. The next transition starts at clamped duration; the current transition completes at its started duration.

### E.6 Settings overlay opened during offline replay

The cozy progress modal (per Story 009) already occupies the SceneManager's modal slot. Settings overlay attempts to open via `SceneManager.show_modal` would fail or stack — UNDEFINED in MVP. Mitigation: gate the gear-icon button on `OfflineProgressionEngine.is_replay_in_flight()` — disable the button when replay is in flight. The icon shows a loading-spinner overlay; tapping shows a tooltip "Settings available after replay completes."

### E.7 Locale change with unsaved settings

If the player adjusts volume sliders, changes the locale, then taps Save, both the volume changes AND the locale change persist together. The locale change applies immediately (`TranslationServer.set_locale`); the UI re-renders all `tr()` strings on next frame. The settings overlay itself re-renders too — labels switch language without closing.

### E.8 Headless / no-audio-device

Per audio-system.md §E.1, AudioRouter operates in headless-mode with `_apply_to_audio_server` as a no-op. Settings overlay sliders still update the cached values + persist correctly; the audio path just doesn't produce sound.

### E.9 ConfigFile write failure (out-of-disk, permission error)

`SceneManager.set_reduce_motion` already handles this via `push_warning` on save_err per S12-S2 implementation. Settings overlay does NOT block the close path on a save_err — it logs the warning and lets the player continue. The in-memory value still applies for the session.

### E.10 Reset button while sliders being dragged

If the player is mid-drag on a slider and clicks Reset, the drag is interrupted — the slider snaps to the default. The drag's `value_changed` signal during the drag fired previously, but the Reset's snapping fires the canonical default value. AudioRouter applies the default. Smooth, no audio click.

---

## F. Dependencies

### Hard dependencies (Settings requires these to function)

| System | Why | Surface used |
|---|---|---|
| `AudioRouter` (#28) | Volume + mute control | `set_master_volume_db`, `set_music_volume_db`, `set_sfx_volume_db`, `set_master_muted`, `get_*_volume_db`, `is_master_muted` |
| `SceneManager` (#4) | reduce_motion toggle + modal show/hide | `set_reduce_motion`, `reduce_motion`, `show_modal`, `hide_modal` |
| `SaveLoadSystem` (#3) | Volume persistence (via AudioRouter consumer) | Indirect — AudioRouter's `get_save_data`/`load_save_data` |
| `UIFramework` (Foundation) | Parchment theme + touch feedback | `apply_parchment_panel`, `wire_touch_feedback`, `format_localized` |
| `TranslationServer` (Godot core) | Locale switching | `set_locale`, `get_loaded_locales` |
| `OfflineProgressionEngine` (#12) | Gating Settings opening during replay (E.6) | `is_replay_in_flight()` |

### Signal-source dependencies

Settings does NOT subscribe to any gameplay signals — it's a thin UI layer.

### Reverse dependencies (systems that depend on Settings)

- **Guild Hall Screen** (#19) — gear icon button that opens the Settings modal
- **Onboarding flow** (#29) — first-launch may show Settings as part of accessibility check (Sprint 14+)

---

## G. Tuning Knobs

### Slider-to-dB curve constants
- Linear-to-dB convention (20·log10) is industry-standard; not tunable.
- Mute threshold: `s <= 0.001 → -INF` (avoid log10(0) singularity). Hardcoded.

### Defaults (override via `AudioRouter` constants)
- Master default: 0.0 dB (slider 1.0)
- Music default: -8.0 dB (slider ~0.398)
- SFX default: -3.0 dB (slider ~0.708)
- Mute default: false
- reduce_motion default: false
- Locale default: "en"

### Modal close-on-outside-tap behavior
- Tap-outside auto-saves and closes. Tunable via `_settings_overlay.close_on_outside_tap: bool = true` (Sprint 14+ if a "discard changes" mode is added).

---

## H. Acceptance Criteria

**AC-30-01 — Settings overlay opens via Guild Hall gear icon**
Tapping the gear icon while in Guild Hall calls `SceneManager.show_modal(<settings_overlay>)`. The overlay renders centered with the parchment theme.

**AC-30-02 — All three volume sliders reflect AudioRouter state on open**
On open, each slider's position matches `db_to_slider(AudioRouter.get_<bus>_volume_db())` per §C.2. If a saved value is at -INF dB, the slider reads 0. If at 0 dB, the slider reads 1.0.

**AC-30-03 — Volume slider drag updates AudioRouter immediately**
Dragging the Master slider fires `AudioRouter.set_master_volume_db(slider_to_db(slider.value))` continuously (or on `value_changed` if throttled). AudioServer.get_bus_volume_db("Master") reflects the change within one frame.

**AC-30-04 — Mute toggle hard-overrides volume**
With Master volume at 0.0 dB, toggling mute=true causes `AudioServer.get_bus_volume_db("Master")` to read -INF (within the frame). Toggling mute=false restores to 0.0 dB.

**AC-30-05 — reduce_motion toggle persists round-trip**
Toggle reduce_motion=true → tap Save → close modal → re-open modal: toggle still reads true. ConfigFile at `user://settings.cfg` contains `[accessibility] reduce_motion=true`.

**AC-30-06 — Reset to Defaults restores documented defaults**
Click Reset: Master slider 1.0, Music slider ~0.398, SFX slider ~0.708, mute=false, reduce_motion=false, locale="en". AudioRouter / SceneManager state has NOT yet changed (Reset is in-memory until Save).

**AC-30-07 — Save button persists all changes atomically**
After adjusting sliders + toggles, tap Save: AudioRouter consumer save fires; ConfigFile write fires for reduce_motion + locale. Re-launch the game: all settings restored exactly.

**AC-30-08 — Tap-outside auto-saves**
With unsaved changes, tap outside the overlay: the overlay closes AND all changes persist (same effect as tapping Save).

**AC-30-09 — Escape key auto-saves**
Same as AC-30-08 but triggered via Escape key.

**AC-30-10 — Settings unavailable during offline replay**
With `OfflineProgressionEngine.is_replay_in_flight() == true`, the Guild Hall gear icon is disabled (no tap response, dimmed visual). Tapping it produces no overlay; an optional tooltip explains the gating (Sprint 14+ polish).

**AC-30-11 — Headless / no-audio-device path does not crash**
Open Settings on a system with no audio device: sliders render, drag updates the cached values, Save persists. AudioServer.set_bus_volume_db calls are no-ops (per audio-system.md §E.1). No crash, no error toasts.

**AC-30-12 — Save corruption recovery**
With a corrupt `user://settings.cfg`, opening Settings: ConfigFile.load returns non-OK → defaults apply per §E.2. Sliders show defaults. No corruption banner shown.

**AC-30-13 — Locale dropdown only shows loaded locales**
With only "en" loaded, the OptionButton has 1 entry ("English"); disabled/grayed since no alternative exists. With Sprint 14+ multi-locale, the dropdown auto-expands.

**AC-30-14 — Settings overlay respects parchment theme + touch feedback**
PanelContainer uses `UIFramework.apply_parchment_panel`; all interactive Controls (sliders, buttons, toggles) wired via `UIFramework.wire_touch_feedback` (touch pulse + UI tap chime). Verified via meta-sentinel + audio spy.

---

## I. Open Questions & ADR Candidates

**OQ-30-1 — `user://settings.cfg` migration to Save/Load envelope**
ADR-0007 §OQ-7 defers the migration of `reduce_motion` from `user://settings.cfg` to the Save/Load envelope. Locale is similarly persisted via ConfigFile in this GDD. Both should migrate together when the Save/Load envelope's settings namespace lands (Sprint 14+ candidate). Until then, two persistence pathways exist: AudioRouter consumer (envelope) + ConfigFile (interim). Documented; not gating MVP.

**OQ-30-2 — Volume slider granularity**
Linear slider in [0, 1] mapped to dB has nonlinear perceived loudness (the bottom 30% of the slider covers most of the audible range; the top 70% is barely perceptible). Two options: (a) keep linear slider, accept the perceptual mismatch (MVP simplicity); (b) use a perceptual-loudness curve (e.g., x^2 or x^3) for slider position → linear-loudness mapping. MVP picks (a); revisit post-playtest if "the slider feels broken near max" is reported.

**OQ-30-3 — Per-cue volume multipliers exposed in Settings?**
audio-system.md §C.2 has per-cue volume multipliers (e.g., level-up chime 1.2×, floor-clear fanfare 1.4×). Should the player tune these per cue? MVP says NO — the multipliers are mix-design, not player preferences. Sprint 14+ may add an "Audio Mix" advanced panel if playtest reveals specific cues are too loud/quiet for some players.

**OQ-30-4 — Accessibility flags beyond reduce_motion**
V1.0 may add: subtitles for stingers (deaf/hard-of-hearing), high-contrast mode (low-vision), colorblind-safe palette (already locked in Art Bible §3 via the parchment palette — no toggle needed). Subtitles + high-contrast are V1.0 stories; this GDD scopes only reduce_motion for MVP.

**OQ-30-5 — Localization handoff between Settings save and active runtime**
TranslationServer.set_locale takes effect immediately, but if the locale changes in the middle of a Stinger or fanfare playback, the audio cue does NOT re-render (audio assets are not localized in MVP). This is fine — visual text re-renders on next frame. Documented, not a blocker.

**OQ-30-6 — Gear icon placement**
Guild Hall gear icon position: top-right, top-left, or in a hamburger menu? MVP locks top-right per the existing parchment-screen convention; revisit if playtest reveals discoverability issues.

---

## J. Implementation Sequencing (Sprint 14+ candidate)

This GDD is design-first; implementation is Sprint 14+ scope. Pre-sequenced as 5 stories totaling ~2.0 days:

1. **Story 1 (~0.5d)** — Settings overlay scene authoring (`assets/screens/settings_overlay/`): PanelContainer + VBoxContainer + 3 sliders + 2 toggles + 1 OptionButton + Save/Reset buttons. Apply parchment theme. Wire touch feedback. AC-30-14.
2. **Story 2 (~0.5d)** — Volume slider wiring: bind sliders to AudioRouter via `slider_to_db` helper; on `value_changed`, call `set_*_volume_db`. AC-30-02 / AC-30-03 / AC-30-04.
3. **Story 3 (~0.25d)** — Mute toggle + reduce_motion toggle + locale dropdown wiring. AC-30-05 / AC-30-13.
4. **Story 4 (~0.5d)** — Save / Reset / Auto-save (tap-outside + escape) flows. AC-30-06 / AC-30-07 / AC-30-08 / AC-30-09.
5. **Story 5 (~0.25d)** — Gating + edge cases: gear icon disable during offline replay (AC-30-10), corruption recovery (AC-30-12), tests for ACs 30-01 through 30-14.

Total Sprint 14+ scope: ~2.0 days. Smaller than recent Sprint 11/12/13 GDD-authoring follow-ups (~3–4d each) because Settings is a thin UI layer with no new persistence schemas.

---

## Notes

- Authored 2026-05-06 by post-Sprint-13-S1 close-out work (autonomous-execution session). Drafted to unblock Sprint 13 S13-S4 (`reduce_motion` Settings UI) which referenced this GDD as a hard dependency.
- All ACs are testable via the patterns documented in `tests/PATTERNS.md` (signal-driven assertions + Array spy + `_settings_cfg_path` override for test isolation).
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED. Expect review to surface ~5–10 BLOCKING items per the audio-system.md / recruitment-system.md precedent (first-pass GDDs typically need 1 revision cycle before APPROVED).
