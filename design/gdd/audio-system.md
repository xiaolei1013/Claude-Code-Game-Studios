# Audio System

**Status**: Authored (Sprint 10 S10-M3 — first design pass)
**Layer**: Core
**Owners**: audio-director (creative direction) + game-designer (signal mapping) + technical-artist (mix + asset pipeline)
**Last Verified**: 2026-05-05

---

## A. Overview

The Audio System is the project's centralized music + SFX router. It is a **non-gameplay-owning** subsystem: it consumes signals already emitted by other systems (`HeroRoster.hero_leveled`, `DungeonRunOrchestrator.floor_cleared_first_time`, `Economy.gold_changed`, `SceneManager.screen_changed`, etc.) and translates them into bus playback events. Gameplay code never calls `AudioStreamPlayer.play()` directly; routing happens at one well-defined place (`AudioRouter`, an autoload Node) so the audio mix can be tuned, muted, A/B'd, or completely swapped without touching gameplay logic.

The system mixes within a tight cozy register: low-volume warm music beds, sparse stingers at reward moments, very quiet UI feedback. The governing rule is "you should be able to leave the game on as background while doing chores" — total RMS level stays low and no element is ever startling. Reward stingers and level-up chimes are the loudest things in the mix, by design — they are the only audio that asks for attention.

This GDD codifies the bus hierarchy, signal-to-cue mapping, asset format standards, mix levels, and the signal-subscription contract that gameplay systems honor. Implementation lands in Sprint 11+ alongside the audio-system epic.

---

## B. Player Fantasy

The player fantasy that audio serves is **"a quiet workshop where small good things happen on a regular schedule"**. Audio sits underneath the visual register (parchment ledger + warm pixel-art) and reinforces it through three feel-states:

1. **Ambient warmth (Guild Hall + dungeon ambience)**. A low, slow loop plays under the player's primary read of the screen. The player may not consciously notice it. If muted, the screens feel "too clinical" — the loop is doing emotional work invisibly. The Guild Hall loop has a gentle hearth-and-paper character (low-mid frequencies, no rhythmic content, no melody hooks); the per-biome dungeon loops swap to biome-appropriate ambient beds (Forest Reach: woodland night with distant water; Sunken Ruins: stone dripping, faint wind through arches; etc.).
2. **Confirmations (UI taps, gold-collected, kill-chime)**. Every meaningful player input gets a short, low-volume, clean tone. These confirmations are felt before they are heard — the goal is "satisfying receipt" without "soundboard-toy bounciness". Per Art Bible §7 Animation Feel: "stately with warm snappiness, not bouncy". Audio inherits this constraint.
3. **Reward fanfares (level-up chime, floor-clear stinger, class-unlock fanfare)**. The audio system's loudest moments. These earn their volume by being rare and meaningful — first-ever floor clear, level-up, class unlock. Per Pillar 3 ("Visible, Honest Progression Without Pressure"), the fanfare confirms a milestone without manufacturing urgency. The reward stinger has a clear "settled" tail — it ends; it does not pulse, repeat, or escalate.

Anti-patterns explicitly rejected:
- **No 4X-style escalating victory orchestra**. Reward stingers are 2–4 second cues, not 15-second cinematic builds.
- **No idle-game slot-machine "ka-ching" loops**. Gold collection plays once per collect event, not per coin.
- **No combat soundtrack**. Auto-combat is watched, not driven; a combat soundtrack with stingers per kill would conflict with Pillar 4 (no rhythm-driven gameplay).
- **No silence as default**. A muted-by-default state would teach players that audio is optional/decorative. Default volumes are low but on; players opt into mute via Settings.

---

## C. Detailed Rules

### C.1 Bus hierarchy

Single canonical bus layout authored to `assets/audio/audio_bus_layout.tres` and pointed at by `project.godot → audio/buses/default_bus_layout`:

```
Master (default)
  ├── Music
  │     ├── Ambient   (Guild Hall + biome music beds — looping)
  │     └── Stinger   (one-shot reward cues — non-looping, ducks Ambient -3 dB during play)
  └── SFX
        ├── UI        (tap_click, panel_open, panel_close — every interactive Control surface)
        ├── Combat    (enemy_kill, boss_kill, hero_damaged, formation_strength_advantage_chime)
        └── Reward    (gold_collected, floor_clear_fanfare, level_up_chime, class_unlock_fanfare)
```

**Why two-tier under each top bus**: separates content-by-purpose so a single mix tuning pass can boost UI clicks without affecting kill-chimes, or duck Ambient under Stinger without affecting SFX. Gives the audio-director three knobs (Master, top-level, sub-bus) before reaching individual cues.

**Bus default volumes** (dB relative to 0 = unity gain):

| Bus | Default | Player-Override Range | Notes |
|---|---|---|---|
| Master | 0 dB | -∞ to 0 dB (mute possible) | Settings volume slider |
| Music | -8 dB | -∞ to +6 dB | Quieter than SFX by design — beds are background |
| Music/Ambient | 0 dB (relative) | — | Sub-bus tuning only |
| Music/Stinger | +2 dB (relative) | — | Reward cues stand out vs ambient bed |
| SFX | -3 dB | -∞ to +6 dB | Settings slider |
| SFX/UI | -2 dB (relative) | — | Tap clicks; quietest sub-bus |
| SFX/Combat | 0 dB (relative) | — | Kill chimes; baseline |
| SFX/Reward | +3 dB (relative) | — | Reward chimes audible above SFX baseline |

The Master/Music/SFX three-knob pattern is the only player-facing audio control. Sub-bus levels are designer-only (audio-bus-layout.tres baked).

### C.2 SFX taxonomy

Each SFX has a stable id (StringName), a target sub-bus, and a default volume multiplier. The id maps to an `AudioStream` resource via `assets/audio/sfx/<id>.ogg`. Asset-loading is handled by `DataRegistry` via the standard category-scan pattern (see ADR-0006); audio-system does not invent its own resource cache.

| Id | Bus | Default Vol Mult | Trigger Signal | Notes |
|---|---|---|---|---|
| `&"sfx_ui_tap"` | SFX/UI | 1.0 | `Control.gui_input` (mouse-down / touch-down) — wired by `UIFramework.wire_touch_feedback` | Plays on every interactive Control tap. Single short tone (~80 ms attack, ~120 ms tail). |
| `&"sfx_ui_panel_open"` | SFX/UI | 0.9 | `SceneManager.screen_changed` (new screen on_enter) | Soft "paper unfolding" texture. ~300 ms. |
| `&"sfx_ui_panel_close"` | SFX/UI | 0.9 | `SceneManager.screen_changed` (old screen on_exit) | Mirrors panel_open. ~250 ms. |
| `&"sfx_combat_enemy_kill"` | SFX/Combat | 1.0 | `DungeonRunOrchestrator.enemy_killed(tier, archetype, advantaged)` | Tier-modulated pitch (lower tier = brighter; see Formula F.1). |
| `&"sfx_combat_boss_kill"` | SFX/Combat | 1.4 | `DungeonRunOrchestrator.boss_killed(enemy_id)` | Distinct from enemy_kill — heavier tail, includes brief Stinger duck. |
| `&"sfx_combat_hero_damaged"` | SFX/Combat | 0.7 | `DungeonRunOrchestrator.hero_damaged(hero_id, hp_remaining)` (Sprint 11+ — signal not yet emitted) | Quieter than kill chime; "bump" not "thud". |
| `&"sfx_combat_advantage_chime"` | SFX/Combat | 0.8 | `DungeonRunOrchestrator.matchup_advantage_revealed(formation_strength)` (Sprint 12+ for formation-strength reveal) | Plays once per dispatch when advantage > 1.0. |
| `&"sfx_combat_run_defeated"` | SFX/Combat | 0.9 | `DungeonRunOrchestrator.run_defeated(floor_index, biome_id)` (S30-N1 wired) | Somber, non-punishing run-defeat sting. Distinct from every victory cue; low/soft "driven back" tone, not a thud. Wired-silent until asset sourced (ADR-0016/0022). |
| `&"sfx_reward_gold_collected"` | SFX/Reward | 1.0 | `Economy.gold_changed(new_balance, delta, reason)` where `delta > 0` | Plays once per gold-add event. Coin-purse texture; warm not metallic. |
| `&"sfx_reward_level_up_chime"` | SFX/Reward | 1.2 | `HeroRoster.hero_leveled(id, old_level, new_level)` (S10-M4 wired) | Single bell-like tone with warm tail. ~600 ms. Pairs with the level-up toast (S10-M4). |
| `&"sfx_reward_floor_clear_fanfare"` | SFX/Reward | 1.4 | `DungeonRunOrchestrator.floor_cleared_first_time(floor_index, biome_id, losing_run)` | Multi-note phrase ~1.5 s. The audio's most ceremonial moment per dispatch. |
| `&"sfx_reward_class_unlock_fanfare"` | SFX/Reward | 1.5 | `HeroClassDatabase.class_unlocked(class_id)` (Sprint 12+ — class unlock flow not yet implemented) | Loudest single SFX in the game. Reserved for genuine unlocks. |

**Mute-when-not-meaningful rule**: any SFX whose triggering signal fires more than once per ~250 ms must be filtered to one playback per window. Concretely: `Economy.gold_changed` fires per kill in a multi-kill tick; `sfx_reward_gold_collected` plays at most once per ~250 ms via `AudioRouter._gold_chime_throttle` (see Formula F.2). This keeps tick-busy combat from sounding like a slot machine.

### C.3 Music cue plan

Music layers below SFX. The Music bus has two sub-buses:

- **Ambient** (looping bed) — exactly one stream playing at any time. Crossfade transitions between beds when SceneManager swaps screens or DungeonRunOrchestrator changes biome.
- **Stinger** (one-shot) — fires on rare reward moments: floor_cleared_first_time and class_unlock. The Stinger cue ducks Ambient by -3 dB for the Stinger's duration + 250 ms tail, then unducks. **The Reward SFX cues (under SFX/Reward) are separate from Music/Stinger** — Reward SFX is the immediate confirmation; Stinger is the longer-tail ceremonial layer that may or may not play depending on the rarity of the moment.

| Music Cue Id | Bus | Trigger | Crossfade | Notes |
|---|---|---|---|---|
| `&"music_guild_hall_bed"` | Music/Ambient | `SceneManager.screen_changed` to any non-dungeon screen | 800 ms in / 800 ms out | Default state when not in a dungeon run. |
| `&"music_forest_reach_bed"` | Music/Ambient | `DungeonRunOrchestrator.state_changed` to ACTIVE_FOREGROUND with `_dispatched_biome_id == "forest_reach"` | 800 ms in (cross-fade with whatever was playing) / 800 ms out (back to guild_hall on RUN_ENDED auto-route) | Quiet woodland-night bed. |
| `&"music_sunken_ruins_bed"` | Music/Ambient | Same pattern, `biome_id == "sunken_ruins"` | 800 ms / 800 ms | Sprint 12+ — biome not yet implemented. |
| `&"music_ember_cavern_bed"` | Music/Ambient | `biome_id == "ember_cavern"` | 800 ms / 800 ms | Sprint 12+. |
| `&"music_thornwood_depths_bed"` | Music/Ambient | `biome_id == "thornwood_depths"` | 800 ms / 800 ms | Sprint 12+. |
| `&"music_arcane_spire_bed"` | Music/Ambient | `biome_id == "arcane_spire"` | 800 ms / 800 ms | Sprint 12+. |
| `&"music_floor_clear_stinger"` | Music/Stinger | `DungeonRunOrchestrator.floor_cleared_first_time` | None — one-shot, ducks Ambient | Plays alongside `sfx_reward_floor_clear_fanfare`; the SFX is the punch, the Stinger is the warmth-continuation. Total duration ~3 s (1.5 s body + 1.5 s tail). |
| `&"music_class_unlock_stinger"` | Music/Stinger | `HeroClassDatabase.class_unlocked` (Sprint 12+) | None | The most ceremonial audio in the game. ~5 s. |

**Music transition rule** — when an Ambient cue's trigger fires while another Ambient cue is already playing, AudioRouter cross-fades over 800 ms (linear). This is **independent of the SceneManager's 150 ms standard visual transition** because audio benefits from a longer fade — abrupt music cuts are jarring even when the visual transition is appropriate. The 800 ms music fade outlasts visual transitions; the new bed reaches full volume after the new screen is fully visible.

**Stinger non-overlap rule** — only one Music/Stinger cue plays at a time. If a second Stinger trigger fires while one is already playing, the second is dropped (logged as `push_warning("[AudioRouter] Stinger overlap dropped: %s while %s playing")`). MVP gameplay rarely produces back-to-back Stingers; this is a defensive guard.

### C.4 Integration surface — `AudioRouter` autoload

`AudioRouter` is a Node autoload registered after `DataRegistry` and after `Economy` / `HeroRoster` / `DungeonRunOrchestrator` in the rank table (so it can subscribe to their signals at `_ready()`). Pattern matches the existing autoload pattern — non-gameplay-owning, signal-driven, stateless aside from per-cue throttle clocks and the currently-playing-Ambient handle.

**Public API** (called from gameplay code only when the signal-driven path is insufficient — e.g., Settings overlay volume slider):

```gdscript
class_name AudioRouter extends Node

# Volume control (called by Settings overlay)
func set_master_volume_db(db: float) -> void
func set_music_volume_db(db: float) -> void
func set_sfx_volume_db(db: float) -> void
func get_master_volume_db() -> float
func get_music_volume_db() -> float
func get_sfx_volume_db() -> float

# Mute control (called by Settings overlay)
func set_master_muted(muted: bool) -> void
func is_master_muted() -> bool

# Manual cue trigger (escape hatch — gameplay code should NOT call these
# routinely; they exist for one-off cinematic moments where signal-driven
# routing isn't appropriate — e.g., a cutscene that needs precise stinger timing)
func play_sfx(sfx_id: StringName) -> void
func play_music(music_id: StringName, fade_in_ms: int = 800) -> void
func stop_music(fade_out_ms: int = 800) -> void
```

**Private signal subscriptions** wired in `AudioRouter._ready()` after autoload resolution:

```gdscript
func _ready() -> void:
    SceneManager.screen_changed.connect(_on_screen_changed)
    DungeonRunOrchestrator.state_changed.connect(_on_run_state_changed)
    DungeonRunOrchestrator.enemy_killed.connect(_on_enemy_killed)
    DungeonRunOrchestrator.boss_killed.connect(_on_boss_killed)
    DungeonRunOrchestrator.floor_cleared_first_time.connect(_on_floor_cleared_first_time)
    HeroRoster.hero_leveled.connect(_on_hero_leveled)
    Economy.gold_changed.connect(_on_gold_changed)
    # Volume restoration: SaveLoadSystem will call our load_save_data(d)
    # after our _ready() returns, per Save/Load GDD's consumer-discovery
    # ordering. Defaults apply transiently between _ready() return and
    # load_save_data invocation; first frame may render at defaults briefly
    # — acceptable given audio is not yet routing any cues at boot.
```

This is the **only place in the codebase that calls `AudioServer.*` methods or instantiates `AudioStreamPlayer` nodes for routing**. UI code, gameplay code, and screens NEVER play audio directly — they fire the signals they already fire (or, in Sprint 11+ for new signals like `hero_damaged`, declare new ones), and AudioRouter handles the rest.

**Why autoload over static helper** (vs the UIFramework non-autoload pattern): AudioRouter holds per-frame state (currently-playing Ambient handle, throttle timers, persistent volume settings). Static helpers without state can't keep this. UIFramework is stateless — pure utility — so it's a static class_name. AudioRouter is signal-driven + has per-instance state — so it's an autoload Node. The distinction is intentional and matches ADR-0008's reasoning for non-autoload UIFramework.

### C.5 Integration with screens

Screens DO NOT subscribe to audio signals or call AudioRouter directly. The pattern is:

1. Screen `on_enter()` — does its own gameplay-signal connections (per ADR-0007 lifecycle).
2. AudioRouter `_ready()` — already subscribed to the same gameplay signals.
3. When a gameplay signal fires (e.g., `HeroRoster.hero_leveled`), both the screen handler (toast) AND the AudioRouter handler (level-up chime) fire in parallel. Godot signal connections are independent; ordering is not guaranteed but neither handler depends on the other.

The level-up flow as the canonical example (S10-M4 already wires the screen half; AudioRouter handler arrives in Sprint 11):

```
DungeonRunOrchestrator._grant_stub_levels_to_formation()
    → HeroRoster.set_hero_level(id, lv)
        → emit hero_leveled(id, old, new)
            → DungeonRunView._on_hero_leveled        # creates toast Label, fades after 3s
            → AudioRouter._on_hero_leveled           # plays sfx_reward_level_up_chime
```

Two handlers, one signal. Neither knows about the other. The system stays loosely coupled; muting audio doesn't break the toast; hiding the toast doesn't break the chime.

### C.6 Asset standards

| Concern | Standard | Rationale |
|---|---|---|
| **SFX format** | `.wav` 44.1 kHz 16-bit mono (UI/Combat) or stereo (Reward) | No format conversion at runtime; predictable load time. Mono UI/Combat keeps memory low. |
| **Music format** | `.ogg` Vorbis quality 5 (~96 kbps), stereo, 44.1 kHz | Compressed for size; Godot's OGG decoder is robust. Q5 is the cozy-ambient sweet spot — higher quality is wasted under -8 dB. |
| **SFX duration** | ≤ 1500 ms (UI ≤ 300 ms, Combat ≤ 800 ms, Reward ≤ 1500 ms) | Keeps each cue distinct; longer SFX overlap and muddy the mix. |
| **Music duration** | Beds: 60–180 s loops; Stingers: ≤ 5 s | Loop length avoids obvious repetition without bloating asset size. |
| **Loop point** | Music beds: zero-crossing seamless loops authored at source (no Godot loop-fade hack) | Loop pop is the most common cozy-game audio fail. |
| **Headroom** | -6 dB peak; -16 dB integrated LUFS for music beds; -10 dB integrated LUFS for SFX | Prevents clipping when multiple cues stack; matches mobile-target loudness norms. |
| **Asset path** | `assets/data/sfx/<id_without_prefix>.tres` (wrapping the `.wav` stream), `assets/data/music/<id_without_prefix>.tres` (wrapping the `.ogg` stream) | DataRegistry category scan pattern (ADR-0006) — `DataRegistry.resolve("sfx", "ui_tap")` returns the `AudioStream` resource. The `.tres` carries the `id` field DataRegistry indexes by; the wrapped `.wav` / `.ogg` lives anywhere under `assets/audio/` (binary asset storage, not the indexed-content path). Pattern matches biomes / classes / dungeons category convention. |
| **Audio bus layout** | `assets/audio/audio_bus_layout.tres` — single canonical resource | Mirrors the parchment_theme.tres pattern: one source of truth for mix. Tuned by audio-director, version-controlled, diff-friendly. |
| **Mobile size budget** | Combined audio ≤ 8 MB at MVP (1 Guild Hall bed + 1 Forest Reach bed + ~10 SFX) | Matches mobile-port readiness target — small audio footprint keeps APK / IPA size manageable. |

### C.7 Volume persistence + Settings integration

Master / Music / SFX volumes persist via the SaveLoadSystem **consumer pattern** (per Save/Load GDD's canonical contract — each save-aware autoload implements `get_save_data() -> Dictionary` and `load_save_data(d: Dictionary) -> void`; SaveLoadSystem composes the top-level dict by namespacing each consumer's payload under its node name). AudioRouter is a save consumer at top-level key `"audio"`:

```gdscript
# AudioRouter — save-consumer surface
func get_save_data() -> Dictionary:
    return {
        "master_volume_db": _master_volume_db,
        "music_volume_db": _music_volume_db,
        "sfx_volume_db": _sfx_volume_db,
        "master_muted": _master_muted,
    }

func load_save_data(d: Dictionary) -> void:
    _master_volume_db = float(d.get("master_volume_db", 0.0))
    _music_volume_db  = float(d.get("music_volume_db", -8.0))
    _sfx_volume_db    = float(d.get("sfx_volume_db", -3.0))
    _master_muted     = bool(d.get("master_muted", false))
    _apply_to_audio_server()
```

The composed save dict has shape `{ "audio": { master_volume_db: ..., music_volume_db: ..., sfx_volume_db: ..., master_muted: ... }, ... }` — the `"audio"` namespace is AudioRouter's consumer slot, not a flat top-level "settings" category. (Defaults: Master 0.0 dB, Music -8.0 dB, SFX -3.0 dB, master_muted false.)

`AudioRouter._apply_to_audio_server()` (called both from `load_save_data` and from `set_*_volume_db` API calls) writes via `AudioServer.set_bus_volume_db`. Settings-overlay sliders write through `AudioRouter.set_*_volume_db` which both updates `AudioServer` AND triggers a SaveLoadSystem persist via `request_full_persist("audio_settings_changed")` (see Save/Load GDD). No silent drift — what the slider shows is what the bus actually plays at AND what gets saved.

**Add AudioRouter as a save consumer in Sprint 11**: per Save/Load GDD's consumer-discovery contract, AudioRouter must register with SaveLoadSystem before its first `request_full_persist` call. The autoload-rank ADR-0003 amendment (OQ-AS-1) places AudioRouter after SaveLoadSystem so the registration timing works.

---

## D. Formulas

### F.1 Tier-modulated kill SFX pitch

`sfx_combat_enemy_kill` plays at the same volume regardless of tier, but pitch is modulated to communicate the kill weight:

```
pitch_scale(tier) = 1.0 + (3 - tier) * 0.10
```

Examples:
- Tier 1 (small enemy): pitch_scale = 1.0 + 0.20 = 1.20 (brighter; "ping")
- Tier 2: 1.10
- Tier 3 (mid): 1.00 (neutral baseline)
- Tier 4: 0.90 (slightly lower)
- Tier 5 (boss-tier non-boss): 0.80 (heavier; "thud")

Rationale — pitch substitutes for distinct per-tier samples in MVP scope. Same .wav, varied AudioStreamPlayer.pitch_scale, gives the player a felt difference between killing a low-tier mob and a high-tier mob without needing 5 sample variants. Sprint 12+ may replace with distinct samples per tier.

Bosses use `sfx_combat_boss_kill` (a separate sample), not pitch-modulated `sfx_combat_enemy_kill`.

### F.2 Gold-chime throttle (anti-slot-machine)

Per C.2 the `Economy.gold_changed` signal fires per kill in a multi-kill tick. Naive routing would produce a slot-machine-like ka-ching loop. Throttle:

```
throttle_window_ms = 250
last_played_at_ms = AudioRouter._gold_chime_last_played_ms

if (now_ms - last_played_at_ms) >= throttle_window_ms:
    play sfx_reward_gold_collected
    AudioRouter._gold_chime_last_played_ms = now_ms
else:
    drop (do not play, do not queue)
```

Result: at 20 Hz combat tick rate (TickSystem default), kills can fire `gold_changed` up to 20 times per second; the chime plays at most 4 times per second (1 / 250 ms). The dropped chimes are never heard, but the gold counter still updates correctly because Economy's signal is independent of the chime.

### F.3 Stinger duck of Ambient

When a Music/Stinger cue plays, Music/Ambient's bus volume_db drops by -3 dB linearly over 100 ms, holds for the Stinger duration, then ramps back up linearly over 250 ms after the Stinger ends. Total ducking envelope: 100 ms attack + Stinger duration + 250 ms release.

```
duck_envelope:
  t = 0:                          ambient_offset = 0 dB
  t = 0..100 ms:                  ambient_offset = lerp(0, -3, t/100)
  t = 100 ms..stinger_end:        ambient_offset = -3 dB
  t = stinger_end..stinger_end+250: ambient_offset = lerp(-3, 0, (t-stinger_end)/250)
```

Implemented via `Tween` on `AudioServer.set_bus_volume_db("Music/Ambient", base + offset)`. The tween targets a stored offset variable (not the absolute volume) so player Settings volume changes during a Stinger don't fight the duck envelope.

### F.4 Music crossfade

Music/Ambient bed crossfade is an exclusive transition — exactly one bed plays at any time, but during the 800 ms transition both cues are routing to bus simultaneously with complementary fade envelopes:

```
crossfade(old_bed, new_bed, duration_ms = 800):
  spawn new AudioStreamPlayer for new_bed at volume_db = -inf
  Tween over duration_ms:
    old_bed.volume_db: 0 → -inf (linear in dB → exponential fade)
    new_bed.volume_db: -inf → 0
  on Tween complete:
    queue_free old_bed's AudioStreamPlayer
```

The two AudioStreamPlayers route through the same Music/Ambient sub-bus; the bus volume itself is unchanged during crossfade. This avoids a "dip-to-silence" gap that a single-stream stop-then-start would produce.

---

## E. Edge Cases

### E.1 No audio device / headless mode
On platforms without an audio device (CI, headless test runs, edge-case Linux configurations), Godot's `AudioServer` initializes with a dummy backend. `AudioRouter` MUST NOT crash or block in this case — bus volume changes and play() calls are no-ops. The autoload `_ready()` should detect this via `AudioServer.get_device_list().is_empty()` and short-circuit signal subscriptions; if the audio device appears later (USB plug-in), AudioRouter does NOT auto-resubscribe (a restart is required, documented as expected behavior in §H AC).

### E.2 Save corruption on volume settings
If any field in AudioRouter's consumer save payload is missing or NaN during `load_save_data()`, AudioRouter falls back to defaults (Master 0, Music -8, SFX -3, master_muted false). A `push_warning` is logged. The corrupt save handler in SaveLoadSystem (per ADR-0004) handles full-save corruption; this is a per-field defensive path. Each `d.get("field", default)` call in `load_save_data` makes the per-field defensive path explicit.

### E.3 Stinger fires during another Stinger
Per C.3 non-overlap rule: drop the second trigger with a `push_warning`. MVP gameplay should never produce this; it's a defensive guard for future multi-event-per-tick designs.

### E.4 Ambient trigger fires repeatedly during transition
If `SceneManager.screen_changed` fires twice within 800 ms (cancel-mid-transition path), the second trigger CANCELS the first crossfade Tween and starts a fresh crossfade from the current intermediate volume. This avoids the "queue-of-pending-crossfades" anti-pattern and matches the SceneManager's TRANSITIONING-queue-overwrite behavior (ADR-0007).

### E.5 Player mutes during a Stinger or fanfare
The mute toggle hard-stops the Master bus volume_db at `-INF` immediately (no fade). Reward fanfares already in progress are silenced mid-cue. This is the intended UX — when the player mutes, they expect immediate silence; deferring mute until the current Stinger finishes would feel sluggish.

### E.6 Combat tick produces 5+ kills in one frame
The kill chime is per-event (no throttle), so 5 kills produces 5 overlapping chimes. This is acceptable and intended — heavy combat moments SHOULD sound busy. The gold-chime throttle (Formula F.2) prevents the sympathetic gold-add cascade from compounding the busy moment further. If playtest reveals 5-kill ticks sound chaotic, raise the per-tier kill chime sample's tail-attenuation, NOT a kill-chime throttle (throttle would mute kill feedback).

### E.7 Gold-changed fires with delta = 0 or negative
`sfx_reward_gold_collected` fires only when `delta > 0`. Refunds (negative delta) and zero-delta routing events (e.g., persistence callbacks) do NOT play the chime. This is enforced in `AudioRouter._on_gold_changed`.

### E.8 Hero leveled but signal fires on save-load hydration
`HeroRoster.hero_leveled` fires during save-load hydration when not suppressed (per ADR-0004 + hero-roster GDD). The chime should NOT play in that case — hydration is a state restore, not a player-felt level-up. AudioRouter checks `HeroRoster._suppress_signals` (or a dedicated `is_hydrating` flag if added) and skips the chime when hydrating. Sprint 11 audio-system epic implementation must verify the suppression hook lands cleanly.

### E.9 First-launch (no save data yet)
On first launch, `SaveLoadSystem` reports no settings save; AudioRouter applies all defaults from C.1. The Settings overlay's slider initial values match the defaults exactly. After the player adjusts and exits Settings, persistence kicks in.

### E.10 Audio bus layout file missing
If `assets/audio/audio_bus_layout.tres` is missing at boot, Godot's AudioServer falls back to a single-Master-bus default layout. `AudioRouter._ready()` detects bus count < 6 (the expected hierarchy) and logs `push_error("[AudioRouter] audio_bus_layout.tres is missing or malformed; expected ≥6 buses, got %d. Audio routing degrades to Master-only.")`. All cues route to Master; mix is not as designed but the game runs.

---

## F. Dependencies

### Hard dependencies (audio-system requires these to function)

| System | Why | Surface used |
|---|---|---|
| `DataRegistry` (ADR-0006) | Loads SFX + Music resources on the same boot-scan path as other content | `DataRegistry.resolve("sfx", id)` + `DataRegistry.resolve("music", id)` |
| `SaveLoadSystem` (ADR-0004) | Persists volume settings + mute state | AudioRouter consumer pattern: `get_save_data` / `load_save_data` per Save/Load GDD canonical contract; namespaced under top-level key `"audio"` (C.7) |
| Godot `AudioServer` | Bus volume control + AudioStreamPlayer routing | `set_bus_volume_db`, `get_bus_index` |

### Signal-source dependencies (audio-system subscribes to)

| Signal | Source | Purpose |
|---|---|---|
| `screen_changed(new_screen_id: String, old_screen_id: String)` | SceneManager | Trigger Music/Ambient crossfades; UI panel SFX |
| `state_changed(new_state, old_state)` | DungeonRunOrchestrator | Detect dungeon entry → biome music swap |
| `enemy_killed(tier, archetype, advantaged)` | DungeonRunOrchestrator | Tier-modulated kill chime |
| `boss_killed(enemy_id)` | DungeonRunOrchestrator | Boss kill chime |
| `floor_cleared_first_time(floor_index, biome_id, losing_run)` | DungeonRunOrchestrator | Floor clear fanfare + Music/Stinger |
| `hero_leveled(id, old_level, new_level)` | HeroRoster | Level-up chime (paired with S10-M4 toast) |
| `gold_changed(new_balance: int, delta: int, reason: String)` | Economy | Gold chime (throttled per F.2). Three-arg signature; `reason` is the Economy emit-reason string (e.g., `"add_gold"` for kill attribution). |
| `class_unlocked(class_id)` | HeroClassDatabase (Sprint 12+) | Class unlock fanfare + Music/Stinger |
| `hero_damaged(hero_id, hp_remaining)` | DungeonRunOrchestrator (Sprint 11+) | Hero-damaged "bump" SFX |
| `matchup_advantage_revealed(formation_strength)` | DungeonRunOrchestrator (Sprint 12+) | Advantage chime on dispatch |
| `run_defeated(floor_index, biome_id)` | DungeonRunOrchestrator | Somber run-defeat sting (S30-N1) |

### Soft dependencies (audio-system enhances these but is not required)

- `UIFramework.wire_touch_feedback` — fires SFX/UI tap chime when wired control receives a tap. Not strictly required (the chime can fire from a separate tap-detection path) but the existing UIFramework hook is the natural integration point.

### Reverse dependencies (systems that depend on audio-system)

- **None at runtime** — audio is a sink, not a source. Gameplay continues correctly with audio entirely muted.
- **Settings overlay** — depends on AudioRouter's volume API. Implemented in Sprint 12 alongside the Settings UX work.

### V1.0 progression-layer cue additions (added 2026-05-09)

Both V1.0 progression-layer systems add cues and signal subscriptions:

- **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) — adds 2 new cues: `sfx_class_synergy_detected` (live preview at slot edit) + `sfx_class_synergy_dispatched` (warm sting at run start with active synergy). Subscribes to 2 new signals declared on FormationAssignment + DungeonRunOrchestrator: `class_synergy_detected_signal(synergy_id)` + `class_synergy_dispatched_signal(synergy_id, run_id)`. Throttle: `class_synergy_audio_suppress_window_seconds = 2.0` (per F.2 throttle pattern). Per `class-synergy-system.md` §C.4 + §F.
- **Prestige System** (#31, V1.0 first-pass 2026-05-09) — adds 2 new cues: `sfx_prestige_completed` (warm sting on retirement action) + `sfx_hall_card_revealed` (subtle parchment-rustle on Hall first-open). Subscribes to `prestige_completed_signal(record, new_count)` declared on HeroRoster. Throttle: `prestige_audio_suppress_window_seconds = 2.0`. Per `prestige-system.md` §C.2 + §F.

Both V1.0 cue additions follow the existing F.2 throttle pattern and respect the cozy-register no-overlap policy. The 4 net-new cues bring the total V1.0 audio surface to (current MVP cue count + 4); CSV taxonomy update is a Sprint 22+ implementation epic line item.

---

## G. Tuning Knobs

All tuning values are designer-facing and live in either `audio_bus_layout.tres` (mix levels) or as exported `@export` fields on `AudioRouter` (timing constants). No hardcoded magic numbers in the routing logic.

### Mix knobs (audio_bus_layout.tres)

| Knob | Default | Range | Where to tune |
|---|---|---|---|
| Master.volume_db | 0 dB | -∞ to 0 | Bus layout |
| Music.volume_db | -8 dB | -24 to +6 | Bus layout |
| Music/Ambient.volume_db | 0 dB (rel) | -12 to +6 | Bus layout |
| Music/Stinger.volume_db | +2 dB (rel) | -6 to +6 | Bus layout |
| SFX.volume_db | -3 dB | -24 to +6 | Bus layout |
| SFX/UI.volume_db | -2 dB (rel) | -12 to +6 | Bus layout |
| SFX/Combat.volume_db | 0 dB (rel) | -6 to +6 | Bus layout |
| SFX/Reward.volume_db | +3 dB (rel) | -6 to +6 | Bus layout |

### Timing knobs (AudioRouter @export)

| Knob | Default | Range | Notes |
|---|---|---|---|
| `music_crossfade_ms` | 800 | [200, 2000] | Music/Ambient bed transitions |
| `stinger_duck_attack_ms` | 100 | [50, 300] | Ambient duck-down envelope (F.3) |
| `stinger_duck_release_ms` | 250 | [100, 600] | Ambient duck-up envelope (F.3) |
| `stinger_duck_offset_db` | -3.0 | [-12, 0] | How much Ambient ducks during Stinger |
| `gold_chime_throttle_ms` | 250 | [100, 1000] | F.2 anti-slot-machine throttle |

### Per-cue volume multipliers

Per-cue `volume_mult` values listed in C.2 + C.3 are designer-tunable as `@export`-d Resource properties on each cue's metadata. Default values come from this GDD; tuning is done via Inspector pass without recompile.

### Player-facing knobs (Settings overlay sliders)

| Slider | Range | Default | Persisted |
|---|---|---|---|
| Master | -∞ to 0 dB | 0 dB | yes (AudioRouter consumer save: `audio.master_volume_db`) |
| Music | -∞ to +6 dB | -8 dB | yes (AudioRouter consumer save: `audio.music_volume_db`) |
| SFX | -∞ to +6 dB | -3 dB | yes (AudioRouter consumer save: `audio.sfx_volume_db`) |
| Mute (Master) | toggle | off | yes (AudioRouter consumer save: `audio.master_muted`) |

The Settings overlay slider UI is owned by Settings GDD #30 (V1.0 accessibility scope). MVP exposes the API; the slider UI is post-MVP polish.

---

## H. Acceptance Criteria

**AC-AS-01 — Bus hierarchy boots correctly**
At cold boot in a fresh project, `AudioServer.get_bus_count()` returns ≥6 (Master, Music, Music/Ambient, Music/Stinger, SFX + 3 sub-buses). Bus parent indices match the C.1 hierarchy. `audio_bus_layout.tres` is the source.

**AC-AS-02 — All SFX cues defined in C.2 are routable**
For each SFX id in C.2, `DataRegistry.resolve("sfx", id_without_prefix)` returns a non-null `AudioStream`. CI test enforces presence by iterating the C.2 table and asserting resolution.

**AC-AS-03 — All Music cues defined in C.3 are routable**
For each Music id in C.3, `DataRegistry.resolve("music", id_without_prefix)` returns a non-null `AudioStream`. CI test enforces.

**AC-AS-04 — AudioRouter subscribes to required signals at boot**
Post-`_ready()`, `is_connected` returns true for each signal listed in §F (Signal-source dependencies). Disconnect on shutdown is not enforced (autoload lifetime is process lifetime).

**AC-AS-05 — Level-up chime fires once per `HeroRoster.hero_leveled` non-hydration event**
When `HeroRoster.set_hero_level(id, level + 1)` is called outside hydration, `AudioRouter._on_hero_leveled` plays `sfx_reward_level_up_chime` exactly once. During hydration (load_save_data), the chime is suppressed.

**AC-AS-06 — Gold chime throttles to ≤4 per second**
A burst of 20 `gold_changed(delta=1)` emissions within 1 second produces ≤4 actual `sfx_reward_gold_collected` plays (per F.2 throttle). The Economy gold counter still increments correctly to +20.

**AC-AS-07 — Music/Ambient crossfades on biome change**
Calling `DungeonRunOrchestrator.dispatch(formation, 1, "forest_reach")` with the Guild Hall bed playing causes the Forest Reach bed to crossfade in over 800 ms; old bed is queue_freed after the fade. Verified via `AudioServer.set_bus_volume_db` Tween presence + bus playing-stream count timeline.

**AC-AS-08 — Stinger ducks Ambient by -3 dB**
During a Music/Stinger cue, `AudioServer.get_bus_volume_db("Music/Ambient")` measured at the Stinger midpoint is base_volume - 3.0 (±0.1 dB). Pre-Stinger and post-Stinger+release, the bus returns to base_volume.

**AC-AS-09 — Volume settings persist round-trip**
`AudioRouter.set_master_volume_db(-12)` followed by `SaveLoadSystem.request_full_persist("audio_settings_changed")`, app restart, SaveLoadSystem load + `AudioRouter.load_save_data(d)` invocation results in `AudioServer.get_bus_volume_db("Master") == -12` (±0.01 dB). Defaults apply only on first launch / corrupt save / per-field corruption (defaults applied via `d.get("master_volume_db", 0.0)` fallback).

**AC-AS-10 — Mute is immediate**
`AudioRouter.set_master_muted(true)` causes `AudioServer.get_bus_volume_db("Master")` to read `-INF` (or platform's effective minimum) within 1 frame. Reward fanfares in progress are silenced mid-cue.

**AC-AS-11 — No audio device path does not crash**
Booting with `AUDIO_DRIVER=Dummy` (Godot's headless audio driver) succeeds without errors. AudioRouter degrades to no-op for all play calls. Volume API still returns reasonable values (the persisted dB values, not -INF).

**AC-AS-12 — Audio bus layout missing handled gracefully**
With `assets/audio/audio_bus_layout.tres` absent, boot succeeds with a `push_error` logged and audio routing degrades to Master-only. No crash.

**AC-AS-13 — Tier-modulated kill chime pitch matches Formula F.1**
For each tier 1..5, an `enemy_killed(tier, …)` signal results in a `sfx_combat_enemy_kill` play with `pitch_scale == 1.0 + (3 - tier) * 0.10` (±0.001).

**AC-AS-14 — UI tap chime fires once per Control tap**
A wired Control (via `UIFramework.wire_touch_feedback`) receiving a single mouse-button-down event produces exactly one `sfx_ui_tap` play. Touch events route identically.

**AC-AS-15 — UI tap chime does not double-fire on Button.pressed**
Buttons fire BOTH `gui_input` (on press) AND `pressed` (on release). The chime is wired to `gui_input` only. A complete tap produces exactly one chime, not two.

---

## I. Open Questions & ADR Candidates

Per Sprint 10 risk-register guidance ("Treat as expected — surface ADR candidates IN the GDD; defer ADR authoring to Sprint 11 unless one is gating"), this section lists ADR candidates produced by the audio-system design pass. None are gating Production; all are Sprint 11+ implementation-stage decisions.

**OQ-AS-1 — `AudioRouter` autoload registration order — RESOLVED 2026-05-05 (S11-S2)**
~~AudioRouter must subscribe to signals from DungeonRunOrchestrator, HeroRoster, Economy, SceneManager. ADR-0003 rank table currently has no entry for AudioRouter. Sprint 11 candidate: append AudioRouter to ADR-0003 amendment, ranking AFTER DungeonRunOrchestrator (the latest gameplay autoload) so subscriptions land cleanly. Alternative: defer subscription via `call_deferred("_subscribe_to_signals")` from `_ready()` so rank order matters less. Decide during Sprint 11 implementation; both options are workable.~~

**Resolution**: Option (a) selected — AudioRouter appended at rank 16 (after rank 15 OfflineProgressionEngine). See ADR-0003 Amendment #5 (2026-05-05). Rank choice keeps the signal-source autoloads strictly visible in `/root/` at AudioRouter's `_ready()` time so the defensive `has_node("/root/SourceAutoload")` guards always succeed in production. ~~Sprint 12+ Story 2 owns the `SaveLoadSystem.CONSUMER_PATHS` lockstep edit when consumer-discovery body is implemented (currently STUB per Story 007 deferral).~~ **CONSUMER_PATHS lockstep edit completed Sprint 11 S11-S3 (2026-05-05) post-Story-007a** — `/root/AudioRouter` is now entry index 6 (last) in `SaveLoadSystem.CONSUMER_PATHS`. AC-AS-09 round-trip is wired end-to-end.

**OQ-AS-2 — Stinger overlap policy: drop vs. queue vs. crossfade**
C.3 specifies drop-on-overlap. Alternative is queue (play next when current finishes) or fast-crossfade (cut current at -3 dB and bring in new). MVP gameplay rarely produces back-to-back Stingers so drop is sufficient. If post-launch live-ops content (e.g., milestone events with chained reward stingers) reveals overlap as a real case, revisit. Sprint 11 ships drop-on-overlap; Sprint 12+ may revisit.

**OQ-AS-3 — Persistence schema location: settings vs. game-state**
**RESOLVED 2026-05-05** by post-authoring `/design-review` pass: Save/Load GDD's canonical contract is per-consumer `get_save_data` / `load_save_data` (NOT a flat top-level "settings" category as the original Pass-1 draft assumed). C.7 has been rewritten to register AudioRouter as a save consumer namespaced under top-level key `"audio"`. The Save/Load GDD's consumer-discovery hardcoded-ordered-autoload-list pattern (per Pass-5A) handles registration; AudioRouter's autoload rank in OQ-AS-1 places it after SaveLoadSystem so the registration order is correct. No further reconciliation required.

**OQ-AS-4 — Per-screen audio overrides**
Future screens (e.g., Victory Moment) may want to override Music/Ambient temporarily for a longer cinematic stinger. AudioRouter currently has no per-screen override API. Sprint 12+ can add `AudioRouter.push_audio_context(name)` / `pop_audio_context()` if needed; MVP doesn't need it.

**OQ-AS-5 — Hydration suppression hook**
E.8 requires AudioRouter to suppress the level-up chime during save-load hydration. HeroRoster's `_suppress_signals` flag is internal. Sprint 11 should either (a) add a public `HeroRoster.is_hydrating` getter, or (b) have AudioRouter subscribe to a `SaveLoadSystem.hydration_started` / `hydration_complete` signal and gate cues based on that. Option (b) is cleaner because it scales — Audio is one of many systems that may want to suppress side-effects during hydration. Sprint 11 ADR candidate.

**OQ-AS-6 — Audio asset sourcing — RESOLVED 2026-05-07 (S14-M1)**
~~This GDD specifies cue ids and standards but does not source the actual `.wav` / `.ogg` files. Audio asset sourcing (commission vs. license vs. AI-generated under license) is a Sprint 12+ pre-Polish art/audio sourcing pass. Until assets land, AudioRouter routes correctly but cues play silence (the resolve returns null → AudioStreamPlayer skips play). MVP still ships and runs.~~

**Resolution**: `docs/architecture/ADR-0016-audio-asset-sourcing-silent-mvp.md` locks the **silent-MVP path** — no `.wav` / `.ogg` files ship in MVP; AudioRouter remains wired-but-silent. Four documented pivot triggers (post-launch playtest signal · ≥$200 budget approval · mobile port milestone · sprint capacity surplus enabling AI-generation) authorize a successor ADR when any one fires. The GDD's spec (C.2 / C.3 cue taxonomy + music plan) is preserved unchanged for future non-silent pivot — pivot is a content patch, not a code change. `game-concept.md` §Audio Needs row updated to reference ADR-0016.

**OQ-AS-7 — Combat-music ramp on heavy ticks**
Late-game playtest may reveal that pure-ambient music under heavy combat ticks (4–5 kills per second producing 4–5 chimes) feels under-mixed. A subtle "combat intensity" bus modulation (Music/Ambient tilts +1 dB during dispatched-state, neutral otherwise) is a Sprint 13+ polish candidate. NOT a real combat soundtrack — just a 1 dB warmth shift to anchor the mix. Out of MVP scope.

**OQ-AS-8 — Audio accessibility**
V1.0 Accessibility GDD #30 will cover full audio accessibility (subtitles for stingers, visual indicators for kill chimes for hard-of-hearing players, etc.). MVP's mute toggle satisfies the minimum bar (game playable with audio off — no audio-only information). Subtitled stingers + visual SFX cue indicators are Sprint 14+ work.

---

## J. Cross-System Cross-Reference

This GDD's signal subscriptions touch nine other systems. Cross-references for review:

- `scene-screen-manager.md` §C.6 — touch feedback (1.05× scale, 80 ms): Audio's UI tap chime SHOULD fire on the same `gui_input` event the touch feedback wires. Implementation note for Sprint 11: AudioRouter MAY hook the same `UIFramework.wire_touch_feedback` callable bind path; decide during impl.
- `dungeon-run-orchestrator.md` — signals consumed: `state_changed`, `enemy_killed`, `boss_killed`, `floor_cleared_first_time`. Confirmed all four exist (Sprint 8 work).
- `hero-roster.md` — signal consumed: `hero_leveled`. Confirmed (Sprint 8 + S10-M4 wire).
- `economy-system.md` — signal consumed: `gold_changed`. Confirmed.
- `save-load-system.md` — settings persistence schema (C.7). Reconciliation needed in Sprint 11.
- `data-loading.md` — DataRegistry category-scan pattern for `sfx/` and `music/` directories. Sprint 11 must register these categories per ADR-0006.
- `art-bible.md` §7 Animation Feel — the "stately with warm snappiness" directive applies to audio: SFX timings must match (UI ≤300 ms total, Reward ≤1500 ms total). This GDD's C.6 duration cells respect that.
- `game-concept.md` §Audio Needs — "MVP: silent (per ADR-0016); V1.0+: ambient dungeon loops, UI tap feedback, low-key fanfare for unlocks". This GDD's scope matches the V1.0+ brief; MVP ships silent per the resolved sourcing decision (OQ-AS-6 above).

---

## K. Implementation Sequencing (Sprint 11 candidate)

This GDD describes the full design surface. Sprint 11 implementation should sequence as:

1. **Story 1 (~0.5d)** — `AudioRouter` autoload skeleton + bus layout authoring + ADR-0003 amendment (OQ-AS-1).
2. **Story 2 (~0.5d)** — Volume API + Settings persistence round-trip (AC-AS-09).
3. **Story 3 (~0.5d)** — Subscribe to existing signals (state_changed, enemy_killed, boss_killed, floor_cleared_first_time, hero_leveled, gold_changed). Wire UI tap chime via UIFramework hook.
4. **Story 4 (~0.5d)** — Music/Ambient crossfade implementation + biome-bed swap on dispatch.
5. **Story 5 (~0.5d)** — Music/Stinger duck envelope (F.3) + reward fanfare wiring.
6. **Story 6 (~0.25d)** — Hydration suppression hook (OQ-AS-5) + persistence integration.
7. **Story 7 (~0.25d)** — Tests for all 15 ACs.
8. **Asset placeholder** — silent .ogg / .wav stubs at the canonical paths so the resolve path doesn't fail. Real assets ship in Sprint 12+.

Total Sprint 11 audio implementation: ~3.0 days. Matches the original Sprint 10 S10-S1 estimate (Should Have, 1.0d) being too small; Sprint 11 should budget ~3.0d for full implementation including tests.

Alternative Sprint 11 minimum-viable scope (if save-persist workstream consumes most of the sprint): Stories 1–3 + asset placeholders (~1.5d) — gets AudioRouter live with UI tap + level-up chime + biome music swap. Stories 4–7 push to Sprint 12 polish. The 1.5d MVP gets the felt-progression-moment audio (S10-M4 chime pairing) and the cozy ambient bed online — the highest player-facing value.
