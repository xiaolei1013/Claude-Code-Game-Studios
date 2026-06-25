# Settings / Options & Accessibility — GDD #30

> **Status: IMPLEMENTED & SHIPPED — reconciled 2026-06-25 (Sprint 30).** Originally a first-pass DRAFT (2026-05-06, post-Sprint-13-S1 close-out). The overlay shipped across Sprints 13/23/30 and lives at `assets/overlays/settings/` (`settings.gd` + `settings.tscn`) — NOT the `assets/screens/settings_overlay/` path the original draft predicted. This revision reconciles the spec to the as-built code. Key as-built deltas from the original draft:
> - **No Save button (auto-save model).** Every change persists immediately through its consumer (`AudioRouter`, `SceneManager.set_reduce_motion`, `LocaleLoader.persist_locale`, `TelemetrySink.set_opt_in`). Close / tap-outside / Esc only pop the overlay. AC-30-07's atomic-Save-button requirement is an **intentional divergence** (see §H).
> - **Invoked via `SceneManager.push_overlay("settings", false)`** (`pause_on_open=false`, so an in-flight offline replay keeps ticking) — not the `show_modal` of the original S12-S2 sketch.
> - **Locale persists via `LocaleLoader.persist_locale`** (load-modify-save of the shared `user://settings.cfg`, per ADR-0026 §D-b), not a raw ConfigFile write from the overlay.
> - **Three controls were added post-draft, specced in their own docs:** a telemetry opt-in checkbox (`telemetry-events-v1.md` §C.1, default OFF), a version readout, and a Quit-to-Desktop button (both Sprint 23 S23-S2).
> - **AC tally: 14/14 covered** — 13 met as-specified, AC-30-07 met-as-diverged (auto-save). AC-30-09 (Esc-to-close) landed in this Sprint 30 reconciliation pass.

---

## A. Overview

**Settings** is the player-controllable preferences surface — volume mix, mute, accessibility flags, locale, telemetry opt-in, plus a version readout and Quit-to-Desktop. It owns no gameplay state: it's a thin UI layer over already-shipping autoload APIs (`AudioRouter` for audio, `SceneManager.set_reduce_motion` for motion, `TranslationServer` + `LocaleLoader` for locale, `TelemetrySink` for the analytics opt-in). No new persistence schemas; existing per-consumer `get_save_data` / `load_save_data` (audio) and the shared `user://settings.cfg` ConfigFile (reduce_motion + locale) cover the storage surface.

The Settings overlay is invoked from the Guild Hall via a gear icon. It opens over the current screen via `SceneManager.push_overlay("settings", false)` — `pause_on_open=false`, so the tick loop keeps advancing (settings are tweaked while idle progression continues, and an in-flight offline replay is never interrupted). Changes apply and persist immediately (auto-save model — see §C.1); closing the overlay (Close button, tap-outside, or Esc) simply pops it via `SceneManager.pop_overlay("settings")`. AudioRouter applies volume changes on the frame they happen; reduce_motion takes effect on the next transition.

---

## B. Player Fantasy

> *"I can quickly tune the experience to my context — quiet workplace, hard-of-hearing partner, accessibility needs — without leaving the game or losing my place."*

The Settings overlay should feel like the parchment-themed Guild Hall: warm, low-friction, no menus-of-menus. A handful of sliders and toggles, a locale dropdown, and a telemetry opt-in — a single scroll-free panel. Reset-to-defaults is a single button in the bottom row — for the player who tweaked things and wants to undo without remembering the values.

The cozy register applies: no harsh feedback when adjusting, no warning toasts on extreme values, no "are you sure?" confirmations. The defaults are sane; the player is trusted to recover from their own choices.

Accessibility-first stance: every gameplay-relevant signal has an audio cue (S12-M6 wired) AND a visual cue (toast for hero_leveled, count for kills, etc.) — settings cannot break gameplay. Mute the audio entirely → game still playable. Enable reduce_motion → transitions are 50ms instead of 150–800ms; ceremony is an instant cut; touch feedback (1.05× pulse, 80ms) stays per S12-S2 §reduce_motion §G.

---

## C. Detailed Rules

### C.1 Settings overlay layout

The overlay is a `$Panel` PanelContainer at center-screen, parchment-themed via `UIFramework.apply_parchment_panel` (ADR-0008). A `$DimBackdrop` ColorRect sits behind it; tapping the backdrop closes the overlay. A modal scale-in entrance (0.94→1.0, 300ms `enter` easing per DESIGN.md §Motion) plays on open and is skipped under reduce_motion.

**Auto-save model — there is NO Save button.** Every control persists its change immediately through its consumer surface the instant it changes (see §C.7). Closeable via:
- **Close button** (in the bottom button row) — pops the overlay
- **Tap-outside** on the dim backdrop (AC-30-08) — pops the overlay
- **Escape key** (`ui_cancel`, AC-30-09) — pops the overlay, but only when Settings is the topmost overlay (mirrors `pause_menu.gd`, so a pause → Settings chain closes Settings first)

All three close paths route through one `_request_close()` → `SceneManager.pop_overlay("settings")`. There is nothing to persist on close — state was already saved on each change.

`Panel/VBox` rows in order (parchment section eyebrows — Audio / Accessibility / Data & locale — are inserted before the first row of each group via `ParchmentKit.eyebrow`):
1. **HeaderLabel** — `tr("settings_title")` ("Settings")
2. **MasterRow** — Label + HSlider + dB display (0–100% mapped to -INF dB at 0% to 0 dB at 100%)
3. **MusicRow** — Label + HSlider + dB display (same mapping)
4. **SFXRow** — Label + HSlider + dB display (same mapping)
5. **MuteRow** — Label + CheckButton (Master mute, hard -INF override)
6. **ReduceMotionRow** — Label + CheckButton + helper text ("Faster transitions; ceremony cut to instant")
7. **LocaleRow** — Label + OptionButton (locale dropdown; disabled/grayed when only one locale is loaded — §C.5)
8. **TelemetryRow** — Label + CheckButton (analytics opt-in; default OFF — specced in `telemetry-events-v1.md` §C.1, not this GDD)
9. **ButtonRow** — ResetButton + CloseButton + QuitToDesktopButton
10. **VersionLabel** — app version readout (Sprint 23 S23-S2; reads `application/config/version`, falls back to "unknown")

> **As-built note:** the original draft listed a SaveButton (row 11) and Separator-delimited groups. The shipped overlay replaced the Save button with the auto-save model and added the Telemetry row, Quit-to-Desktop button, and Version label (Sprint 23 S23-S2). Telemetry, version, and quit each carry their own spec/story and are not given full AC treatment here.

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

### C.5 Locale selector

OptionButton populated by `TranslationServer.get_loaded_locales()`, disabled/grayed when only one locale is loaded (single-locale → no choice to make). A defensive fallback guarantees "en" is present even when the headless test env reports no loaded locales.

When changed: `TranslationServer.set_locale(locale_id)` is called (UI re-renders as each `tr()` retraces), then the choice is persisted via **`LocaleLoader.persist_locale(locale_id)`** — a load-modify-save of the shared `user://settings.cfg` that preserves sibling keys (e.g. `[accessibility] reduce_motion`). The matching boot-time read lives in `LocaleLoader` too, per ADR-0026 §D-b. The overlay does NOT write the cfg directly.

Forward-compat: locale resources auto-populate this dropdown as they ship (German landed post-draft); no GDD changes are needed per added locale.

### C.6 Reset to Defaults

Resets all controls to the defaults from §C.2 (volumes), §C.3 (mute=false), §C.4 (reduce_motion=false), §C.5 (locale="en"), and the telemetry opt-in (OFF, per `telemetry-events-v1.md` §C.1).

**As-built:** because the overlay has no Save button (auto-save model), Reset applies *immediately* — it sets each control to its default and explicitly fires the control's change handler (`CheckButton.button_pressed =` and `OptionButton.select()` do not emit on assignment in Godot 4, so `toggled.emit` / `item_selected.emit` are called manually), which propagates the default straight to its consumer. This diverges from the original draft's "in-memory until Save"; the accidental-reset pitfall the draft worried about is mitigated instead by the defaults being sane and recoverable (cozy register), not by a Save gate.

### C.7 Persistence routing

| Setting | Pathway | Persistence |
|---|---|---|
| Master / Music / SFX volume | `AudioRouter.set_*_volume_db()` | SaveLoadSystem consumer (per-autoload `get_save_data`/`load_save_data`) — namespaced under top-level `"audio"` key per audio-system.md §C.7 |
| Master mute | `AudioRouter.set_master_muted()` | Same consumer surface |
| reduce_motion | `SceneManager.set_reduce_motion()` | ConfigFile at `user://settings.cfg` `[accessibility] reduce_motion` (interim path; OQ-30-1 migration plan to Save/Load envelope per ADR-0007 §OQ-7) |
| Locale | `TranslationServer.set_locale()` + `LocaleLoader.persist_locale()` | `LocaleLoader` load-modify-saves `user://settings.cfg` `[locale] active_locale` (preserves sibling keys); boot-read also in `LocaleLoader` per ADR-0026 §D-b |
| Telemetry opt-in | `TelemetrySink.set_opt_in()` | `TelemetrySink` consumer surface; default OFF per `telemetry-events-v1.md` §C.1 |

**Auto-save model:** every change persists the instant it happens through the pathway above — there is no Save button and no deferred-commit step. Closing the overlay (Close / tap-outside / Esc) only pops it; nothing is persisted on close because nothing is pending.

---

## D. Formulas

### F.1 Linear-slider-to-dB curve (§C.2)

Standard 20·log10 audio convention. Documented in §C.2 above.

### F.2 No other formulas

Settings has no gameplay math. All other values are direct pass-throughs to existing autoload APIs.

---

## E. Edge Cases

### E.1 First-launch (no save data)

All values use defaults from §C.2 / §C.3 / §C.4 / §C.5 (+ telemetry OFF). Settings overlay loads cleanly, seeding each control from its consumer's current (default) state. With the auto-save model there is no Save step on first open; the player perceives no state difference until they actually change something.

### E.2 Save corruption on volume settings

If `AudioRouter.load_save_data` receives a corrupt or missing field, it falls back to the per-field default per audio-system.md §E.2. Settings overlay re-reads via `AudioRouter.get_*_volume_db()` and shows the defaults — player sees the recovery seamlessly. No corruption banner needed (per cozy register).

### E.3 Mid-playback volume change

Volume slider drag emits `set_master_volume_db()` continuously (or on `value_changed` if drag-throttled). AudioRouter's `_apply_to_audio_server()` runs each call; live audio mix updates without artifacts. Reward fanfares + ambient music both re-mix in real time.

### E.4 Mute toggle during a Stinger

Per audio-system.md §E.5: mute is hard-immediate. Stinger that's playing at toggle time is silenced mid-cue. This is intentional — the player expects mute to mean "silent NOW".

### E.5 reduce_motion toggle mid-transition

Per Story 009 (S12-S2) §QA Test Cases: flipping reduce_motion mid-transition does NOT abort the in-flight tween. The clamp applies only to FUTURE `_resolved_duration_ms` calls. The next transition starts at clamped duration; the current transition completes at its started duration.

### E.6 Settings overlay opened during offline replay

The cozy progress modal (per Story 009) is shown during an in-flight replay. Because Settings opens with `pause_on_open=false` it would not interrupt the replay tick — but opening Settings over the replay modal is still UNDEFINED UX in MVP. Mitigation: gate the gear-icon button on `OfflineProgressionEngine.is_replay_in_flight()` — disable the button when replay is in flight. The icon shows a loading-spinner overlay; tapping shows a tooltip "Settings available after replay completes."

### E.7 Locale change applies live

There are no "unsaved settings" — each change persists as it happens (§C.7). When the player changes the locale, `TranslationServer.set_locale` applies immediately and `LocaleLoader.persist_locale` writes it; the UI re-renders all `tr()` strings on the next frame. The settings overlay itself re-renders too — labels switch language without closing. Any volume changes made just before are already persisted independently.

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
| `SceneManager` (#4) | reduce_motion toggle + overlay push/pop | `set_reduce_motion`, `reduce_motion`, `push_overlay`, `pop_overlay`, `topmost_overlay_id` |
| `SaveLoadSystem` (#3) | Volume persistence (via AudioRouter consumer) | Indirect — AudioRouter's `get_save_data`/`load_save_data` |
| `UIFramework` (Foundation) | Parchment theme + touch feedback | `apply_parchment_panel`, `wire_touch_feedback`, `format_localized` |
| `TranslationServer` (Godot core) | Locale switching | `set_locale`, `get_loaded_locales`, `get_locale` |
| `LocaleLoader` | Locale persistence (load-modify-save of `settings.cfg`) + boot-read | `persist_locale` (ADR-0026 §D-b) |
| `TelemetrySink` | Analytics opt-in mirror | `set_opt_in`, `is_opt_in` (default OFF per `telemetry-events-v1.md` §C.1) |
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

### Defaults (as `_DEFAULT_*` consts in `settings.gd`; volume baselines from `AudioRouter`)
- Master default: 0.0 dB (slider 1.0)
- Music default: -8.0 dB (slider ~0.398)
- SFX default: -3.0 dB (slider ~0.708)
- Mute default: false
- reduce_motion default: false
- Locale default: "en"
- Telemetry opt-in default: false (privacy-first, per `telemetry-events-v1.md` §C.1)

### Modal close behavior
- All three close paths (Close button, tap-outside, Esc) pop the overlay and rely on the auto-save model — there are never unsaved changes to discard. The draft's speculative `close_on_outside_tap` / "discard changes" mode was not built; if a discard mode is ever wanted it would require introducing a staged-commit buffer (a larger change than the current thin-UI layer).

---

## H. Acceptance Criteria

**AC-30-01 — Settings overlay opens via Guild Hall gear icon** ✅ met
Tapping the gear icon while in Guild Hall calls `SceneManager.push_overlay("settings", false)` (`pause_on_open=false`). The overlay renders centered with the parchment theme and plays the modal scale-in entrance.

**AC-30-02 — All three volume sliders reflect AudioRouter state on open**
On open, each slider's position matches `db_to_slider(AudioRouter.get_<bus>_volume_db())` per §C.2. If a saved value is at -INF dB, the slider reads 0. If at 0 dB, the slider reads 1.0.

**AC-30-03 — Volume slider drag updates AudioRouter immediately**
Dragging the Master slider fires `AudioRouter.set_master_volume_db(slider_to_db(slider.value))` continuously (or on `value_changed` if throttled). AudioServer.get_bus_volume_db("Master") reflects the change within one frame.

**AC-30-04 — Mute toggle hard-overrides volume**
With Master volume at 0.0 dB, toggling mute=true causes `AudioServer.get_bus_volume_db("Master")` to read -INF (within the frame). Toggling mute=false restores to 0.0 dB.

**AC-30-05 — reduce_motion toggle persists round-trip** ✅ met
Toggle reduce_motion=true → close overlay → re-open: toggle still reads true (auto-save — no Save step). ConfigFile at `user://settings.cfg` contains `[accessibility] reduce_motion=true`.

**AC-30-06 — Reset to Defaults restores documented defaults** ✅ met (auto-save variant)
Click Reset: Master slider 1.0, Music slider ~0.398, SFX slider ~0.708, mute=false, reduce_motion=false, locale="en", telemetry=OFF. Per the auto-save model, AudioRouter / SceneManager / TelemetrySink state updates *immediately* — the original "in-memory until Save" clause is void (there is no Save button; see §C.6).

**AC-30-07 — ~~Save button persists all changes atomically~~** ⚠️ INTENTIONAL DIVERGENCE
The shipped overlay has **no Save button**. Instead, each change persists atomically through its own consumer the instant it happens (auto-save model — §C.1/§C.7): AudioRouter consumer save for volumes/mute, `SceneManager.set_reduce_motion`'s ConfigFile write, `LocaleLoader.persist_locale` for locale, `TelemetrySink.set_opt_in` for telemetry. The observable end-state of this AC — *re-launch the game → all settings restored exactly* — still holds; only the trigger (per-change vs one Save click) diverges. This is a deliberate UX simplification ratified in this reconciliation, not a gap.

**AC-30-08 — Tap-outside closes (auto-saves)** ✅ met
Tapping the dim backdrop outside the panel pops the overlay. All changes are already persisted (auto-save model — there are never "unsaved changes" to flush). Wired via `$DimBackdrop.gui_input` → `_request_close()`.

**AC-30-09 — Escape key closes (auto-saves)** ✅ met (Sprint 30)
Same close-and-persist effect as AC-30-08, triggered via the `ui_cancel` action (default Escape). `settings.gd._unhandled_input` consumes `ui_cancel` and calls `_request_close()` **only when `SceneManager.topmost_overlay_id() == "settings"`** — mirroring `pause_menu.gd` so a pause → Settings chain closes Settings first (revealing the pause menu) rather than the pause-menu handler firing underneath. The event is marked handled (`set_input_as_handled`) so `Screen._unhandled_input` does not also treat the Esc as a fresh pause request. Covered by `tests/integration/settings/settings_overlay_test.gd` Group H (topmost closes / not-topmost ignores / non-cancel ignored).

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

## J. Implementation Sequencing — SHIPPED

This section was a pre-sequenced plan; the overlay is now implemented and on `main`. Recorded here as-built (the original ~2.0d / 5-story estimate is kept for historical comparison):

1. **Story 1** — Settings overlay scene authoring at **`assets/overlays/settings/`** (`settings.tscn` + `settings.gd`): `$Panel` PanelContainer + `Panel/VBox` rows + 3 sliders + mute/reduce-motion/telemetry CheckButtons + locale OptionButton + Reset/Close buttons. Parchment theme + touch feedback + section eyebrows + modal scale-in. AC-30-14. *(Note: the predicted `assets/screens/settings_overlay/` path was NOT used — overlays live under `assets/overlays/`.)*
2. **Story 2** — Volume slider wiring: sliders → AudioRouter via the `_linear_to_db` helper on `value_changed`. AC-30-02 / AC-30-03 / AC-30-04.
3. **Story 3** — Mute + reduce_motion + locale dropdown wiring (+ telemetry opt-in, added post-draft). AC-30-05 / AC-30-13.
4. **Story 4** — Reset + close flows under the **auto-save model** (Close button / tap-outside / Esc — no Save button). AC-30-06 / AC-30-07 (diverged) / AC-30-08 / AC-30-09.
5. **Story 5** — Gating + edge cases: gear-icon disable during offline replay (AC-30-10), corruption recovery (AC-30-12), tests for ACs 30-01..30-14.
6. **Sprint 23 S23-S2 (post-draft addition)** — version readout + Quit-to-Desktop button.
7. **Sprint 30 (this reconciliation)** — AC-30-09 Esc-to-close handler + Group H tests; this spec reconciled to as-built.

---

## Notes

- Authored 2026-05-06 by post-Sprint-13-S1 close-out work (autonomous-execution session). Drafted to unblock Sprint 13 S13-S4 (`reduce_motion` Settings UI) which referenced this GDD as a hard dependency.
- All ACs are testable via the patterns documented in `tests/PATTERNS.md` (signal-driven assertions + Array spy + `_settings_cfg_path` override for test isolation).
- **Reconciled to as-built 2026-06-25 (Sprint 30):** the overlay shipped across Sprints 13/23/30. This pass aligned the spec with the code — `push_overlay` invocation, the auto-save model (no Save button), `LocaleLoader.persist_locale`, the telemetry/version/quit additions, the `assets/overlays/settings/` path, and the AC tally (14/14 covered; AC-30-07 met-as-diverged). Telemetry, version readout, and Quit-to-Desktop are specced in their own docs (`telemetry-events-v1.md` §C.1; Sprint 23 S23-S2) and are not given full AC treatment here.
