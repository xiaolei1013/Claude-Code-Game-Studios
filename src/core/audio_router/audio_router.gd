## AudioRouter — centralized audio routing autoload (Sprint 11 S11-S2 skeleton,
## Sprint 12 S12-M6 Stories 3-5 implementation).
##
## Owns the gameplay-signal → bus playback translation per
## `design/gdd/audio-system.md`. Gameplay code never calls
## [code]AudioStreamPlayer.play()[/code] directly; routing happens here.
##
## Sprint 11 S11-S2 scope: SKELETON only (volume API, signal wiring, save
## consumer surface).
##
## Sprint 12 S12-M6 scope (Stories 3-5):
##   - Story 3: play_sfx implementation with DataRegistry resolve + transient
##     AudioStreamPlayer lifecycle. All 7 signal handler bodies filled in.
##   - Story 4: Music/Ambient crossfade implementation + biome-bed swap on
##     DungeonRunOrchestrator.state_changed.
##   - Story 5: Music/Stinger duck envelope (F.3) + reward fanfare wiring.
##
## class_name omitted: "class_name AudioRouter" collides with the autoload
## singleton per project_godot_autoload_class_name_collision memory note
## (same pattern as FormationAssignment, OfflineProgressionEngine, Recruitment).
##
## Governing GDD: design/gdd/audio-system.md
## Autoload rank: 16 (per ADR-0003 Amendment #5; appended after rank 15
## OfflineProgressionEngine so all gameplay-signal sources exist at our
## [method _ready] for connection).
## Story: S11-S2 skeleton + S12-M6 Stories 3-5
extends Node


# ---------------------------------------------------------------------------
# Constants — bus names
# ---------------------------------------------------------------------------

## Bus names matching the audio_bus_layout.tres hierarchy. Resolved via
## [code]AudioServer.get_bus_index(name)[/code] at runtime.
const _BUS_MASTER: StringName = &"Master"
const _BUS_MUSIC: StringName = &"Music"
const _BUS_MUSIC_AMBIENT: StringName = &"Music/Ambient"
const _BUS_MUSIC_STINGER: StringName = &"Music/Stinger"
const _BUS_SFX: StringName = &"SFX"
const _BUS_SFX_UI: StringName = &"SFX/UI"
const _BUS_SFX_COMBAT: StringName = &"SFX/Combat"
const _BUS_SFX_REWARD: StringName = &"SFX/Reward"

## Default volumes per audio-system.md §C.1.
const _DEFAULT_MASTER_DB: float = 0.0
const _DEFAULT_MUSIC_DB: float = -8.0
const _DEFAULT_SFX_DB: float = -3.0
const _DEFAULT_MASTER_MUTED: bool = false

## Demo-build music mapping (local placeholder audio only — see
## design/art/demo-asset-manifest.md). Maps the music bed base-name
## (guild_hall + the 6 biome ids, after the "_bed" suffix is stripped) onto the
## demo track basenames present in assets/audio/demo/bgm_<track>.mp3. Only
## consulted when DataRegistry resolves no production music asset (ADR-0016
## silent-MVP path is unaffected). Unmapped ids use _DEMO_MUSIC_DEFAULT.
const _DEMO_MUSIC_MAP: Dictionary = {
	"guild_hall": "guild_hall",
	"forest_reach": "dungeon_run",
	"frostmire": "dark_cavern",
	"sunken_ruins": "battle",
	"whispering_crags": "dungeon_run",
	"ember_wastes": "battle",
	"hollow_stair": "dark_cavern",
	# Special beds (not biomes): boss floors + the victory/result screen.
	"boss": "boss",
	"victory": "victory",
}
const _DEMO_MUSIC_DEFAULT: String = "dungeon_run"

## Class Synergy V1.0 (Sprint 21 S21-S2 / Story 3) — live-preview detection
## chime throttle. Per `class-synergy-system.md` §C.4 + §G + AC-CS-14:
## rapid slot-toggling that fires the detection signal repeatedly within
## this window plays the chime ONCE. Default 2.0s. Same pattern as the
## gold-chime anti-spam throttle below.
const _CLASS_SYNERGY_DETECTED_THROTTLE_MS: int = 2000

## Prestige V1.0 (Sprint 21+ silent-MVP wiring) — completion fanfare throttle.
## Per `audio-system.md` §J Prestige cross-reference:
## `prestige_audio_suppress_window_seconds = 2.0`. Theoretical guard against
## back-to-back prestige emissions (UI flow is one-at-a-time, but the throttle
## hardens the audio path against future automation or test-emit bursts).
const _PRESTIGE_COMPLETED_THROTTLE_MS: int = 2000

## Gold-chime throttle window per audio-system.md §F.2 + §G.
## Designer-tunable via @export if needed; const for now per MVP scope.
const _GOLD_CHIME_THROTTLE_MS: int = 250

## Stinger duck constants per audio-system.md §F.3 + §G.
const _AMBIENT_DUCK_DB: float = -3.0
const _AMBIENT_DUCK_ATTACK_MS: int = 100
const _AMBIENT_DUCK_RELEASE_MS: int = 250

## Music crossfade default per audio-system.md §F.4 + §G.
const _MUSIC_DEFAULT_FADE_MS: int = 800

## Maps every SFX cue id from §C.2 to its target AudioServer sub-bus.
## Drives bus= assignment in play_sfx without per-cue conditionals.
## Keys are StringNames matching the §C.2 id column.
const _CUE_BUS_MAP: Dictionary = {
	&"sfx_ui_tap":                    &"SFX/UI",
	&"sfx_ui_panel_open":             &"SFX/UI",
	&"sfx_ui_panel_close":            &"SFX/UI",
	&"sfx_combat_enemy_kill":         &"SFX/Combat",
	&"sfx_combat_boss_kill":          &"SFX/Combat",
	&"sfx_combat_hero_damaged":       &"SFX/Combat",
	&"sfx_combat_advantage_chime":    &"SFX/Combat",
	&"sfx_combat_run_defeated":       &"SFX/Combat",
	&"sfx_reward_gold_collected":     &"SFX/Reward",
	&"sfx_reward_level_up_chime":     &"SFX/Reward",
	&"sfx_reward_floor_clear_fanfare":&"SFX/Reward",
	&"sfx_reward_class_unlock_fanfare":&"SFX/Reward",
	&"sfx_prestige_completed":        &"SFX/Reward",
}

## Default volume multipliers per §C.2. Keys match _CUE_BUS_MAP.
## play_sfx applies volume_mult via linear_to_db before AudioServer.
const _CUE_VOLUME_MULT_MAP: Dictionary = {
	&"sfx_ui_tap":                    1.0,
	&"sfx_ui_panel_open":             0.9,
	&"sfx_ui_panel_close":            0.9,
	&"sfx_combat_enemy_kill":         1.0,
	&"sfx_combat_boss_kill":          1.4,
	&"sfx_combat_hero_damaged":       0.7,
	&"sfx_combat_advantage_chime":    0.8,
	&"sfx_combat_run_defeated":       0.9,
	&"sfx_reward_gold_collected":     1.0,
	&"sfx_reward_level_up_chime":     1.2,
	&"sfx_reward_floor_clear_fanfare":1.4,
	&"sfx_reward_class_unlock_fanfare":1.5,
	&"sfx_prestige_completed":        1.2,
}


# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Cached top-level volume settings. Mirrors what's been written to AudioServer;
## also persisted via the get_save_data / load_save_data save consumer surface.
var _master_volume_db: float = _DEFAULT_MASTER_DB
var _music_volume_db: float = _DEFAULT_MUSIC_DB
var _sfx_volume_db: float = _DEFAULT_SFX_DB
var _master_muted: bool = _DEFAULT_MASTER_MUTED

## Throttle clock for gold-chime anti-slot-machine filter (F.2). Stores
## [method _throttle_now_ms] at the last played gold chime. Initialized to
## -_GOLD_CHIME_THROTTLE_MS ("never played") so the first chime after launch is
## never suppressed even when engine uptime is below the throttle window.
var _gold_chime_last_played_ms: int = -_GOLD_CHIME_THROTTLE_MS

## Class Synergy V1.0 (Sprint 21 S21-S2 / Story 3) — throttle clock for
## the live-preview detection chime. Same pattern as `_gold_chime_last_played_ms`
## but with a longer window (2.0s vs 0.25s) since slot-toggle is naturally
## slower than gold-event spam.
var _class_synergy_detected_last_played_ms: int = -_CLASS_SYNERGY_DETECTED_THROTTLE_MS

## Prestige V1.0 (Sprint 21+ silent-MVP wiring) — throttle clock for the
## prestige-completed fanfare. 2.0s window per audio-system.md §J.
var _prestige_completed_last_played_ms: int = -_PRESTIGE_COMPLETED_THROTTLE_MS

## Combat advantage chime (audio-system.md §C.2) — one-shot-per-run latch. The
## chime plays ONCE per dungeon run, on the first enemy kill carrying a favourable
## class-vs-biome matchup ([code]enemy_killed.advantaged == true[/code]). Re-armed
## (set false) on each ACTIVE_FOREGROUND entry in [method _on_run_state_changed].
## Combat is verdict-driven with no dispatch-time advantage signal, so the first
## advantaged kill is the earliest in-combat beat that confirms the matchup edge.
## A latch (not a throttle) because the intent is once-per-run, not rate-limiting.
var _advantage_chime_fired_this_run: bool = false

## Test seam for the throttle clock shared by the three windows above. Default
## -1 means "use real engine uptime" ([method Time.get_ticks_msec]); tests assign
## a fixed non-negative value so the 2.0s windows are deterministic. Engine
## uptime is an unreliable clock for these windows when a directory-scoped test
## run starts before uptime clears the window — the full CI suite passes (high
## uptime) while a local dir-scoped run fails (the prestige-fanfare flake).
var _throttle_now_override_ms: int = -1

## Currently-playing Ambient bed and its id. null = no bed playing.
## Tracked across crossfades so play_music can guard same-id no-ops.
var _current_ambient_player: AudioStreamPlayer = null
var _current_ambient_id: StringName = &""

## Currently-playing Stinger player. null = no stinger playing.
## Guards the non-overlap rule per §C.3.
var _current_stinger_player: AudioStreamPlayer = null

## The signed dB offset applied to the Ambient bus during a Stinger duck
## envelope (F.3). Tween targets this variable, NOT the absolute bus volume,
## so player Settings volume changes during a Stinger don't fight the duck.
var _ambient_duck_offset_db: float = 0.0

## Active duck tween (held to cancel on early Stinger end if needed).
var _duck_tween: Tween = null

## Debug / test-observable play log. Populated only in debug builds
## (OS.is_debug_build() guard). Tests assert on this array; production
## overhead is zero in release builds.
## Schema per entry: { "sfx_id": StringName, "pitch_scale": float, "volume_mult": float }
var _test_play_sfx_log: Array = []

## Headless-mode guard: set true in _ready if no audio device found.
## All play_sfx / play_music / stop_music calls short-circuit when true.
var _headless_mode: bool = false


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

## Subscribes to signal sources required by audio-system.md §F.
## Headless / no-device mode (E.1): short-circuits subscriptions.
##
## Defensive autoload-resolution per ADR-0003 §Signal SUBSCRIPTION rule —
## subscription across any rank pair is safe at _ready() time (signal objects
## exist on Node instantiation, before any _ready fires). [VERIFIED]
func _ready() -> void:
	# E.1: detect headless / no-device audio.
	# AudioServer.get_output_device_list() returns PackedStringArray of available
	# output device names. On the Dummy audio driver (headless CI, no physical
	# device), this returns an empty array.
	if AudioServer.get_output_device_list().is_empty():
		_headless_mode = true
		push_warning("[AudioRouter] No audio device found — operating in headless mode. Signal subscriptions skipped. Audio routing is a no-op.")
		# Still apply defaults (volume API still returns sane values per AC-AS-11).
		_apply_to_audio_server()
		return

	# E.10: verify bus layout loaded correctly.
	if AudioServer.get_bus_count() < 6:
		push_error("[AudioRouter] audio_bus_layout.tres is missing or malformed; expected ≥6 buses, got %d. Audio routing degrades to Master-only." % AudioServer.get_bus_count())

	# Apply default volumes to AudioServer immediately.
	_apply_to_audio_server()

	# SceneManager (rank 8) — UI panel SFX + Music/Ambient crossfade.
	if has_node("/root/SceneManager"):
		var sm: Node = get_node("/root/SceneManager")
		if sm.has_signal("screen_changed") and not sm.screen_changed.is_connected(_on_screen_changed):
			sm.screen_changed.connect(_on_screen_changed)

	# DungeonRunOrchestrator (rank 14) — state, kills, floor clears, synergy dispatch.
	if has_node("/root/DungeonRunOrchestrator"):
		var orch: Node = get_node("/root/DungeonRunOrchestrator")
		if orch.has_signal("state_changed") and not orch.state_changed.is_connected(_on_run_state_changed):
			orch.state_changed.connect(_on_run_state_changed)
		if orch.has_signal("enemy_killed") and not orch.enemy_killed.is_connected(_on_enemy_killed):
			orch.enemy_killed.connect(_on_enemy_killed)
		if orch.has_signal("boss_killed") and not orch.boss_killed.is_connected(_on_boss_killed):
			orch.boss_killed.connect(_on_boss_killed)
		if orch.has_signal("floor_cleared_first_time") and not orch.floor_cleared_first_time.is_connected(_on_floor_cleared_first_time):
			orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time)
		# S30-N1 defeat-weight: somber run-defeat sting (distinct from every victory cue).
		if orch.has_signal("run_defeated") and not orch.run_defeated.is_connected(_on_run_defeated):
			orch.run_defeated.connect(_on_run_defeated)
		# Class Synergy V1.0 — Story 3 dispatched signal subscription.
		if orch.has_signal("class_synergy_dispatched_signal") and not orch.class_synergy_dispatched_signal.is_connected(_on_class_synergy_dispatched):
			orch.class_synergy_dispatched_signal.connect(_on_class_synergy_dispatched)

	# FormationAssignment (rank 11) — Class Synergy V1.0 live-preview chime.
	if has_node("/root/FormationAssignment"):
		var fa: Node = get_node("/root/FormationAssignment")
		if fa.has_signal("class_synergy_detected_signal") and not fa.class_synergy_detected_signal.is_connected(_on_class_synergy_detected):
			fa.class_synergy_detected_signal.connect(_on_class_synergy_detected)

	# HeroRoster (rank 7) — level-up chime trigger.
	if has_node("/root/HeroRoster"):
		var roster: Node = get_node("/root/HeroRoster")
		if roster.has_signal("hero_leveled") and not roster.hero_leveled.is_connected(_on_hero_leveled):
			roster.hero_leveled.connect(_on_hero_leveled)
		# Prestige V1.0 — silent-MVP wiring per ADR-0016. AudioRouter subscribes
		# to prestige_completed_signal; play_sfx degrades to silent no-op until
		# the cue resource is sourced.
		if roster.has_signal("prestige_completed_signal") and not roster.prestige_completed_signal.is_connected(_on_prestige_completed):
			roster.prestige_completed_signal.connect(_on_prestige_completed)
		# Defeat-injury "bump" (§C.2 hero_damaged): verdict-driven combat emits no
		# per-hit damage signal, so the cue rides heroes_injured — the moment a
		# defeated run wounds the party. The emit is hydration-gated at the source
		# (HeroRoster only emits when not suppressed), so no re-check is needed here.
		if roster.has_signal("heroes_injured") and not roster.heroes_injured.is_connected(_on_heroes_injured):
			roster.heroes_injured.connect(_on_heroes_injured)

	# Economy (rank 3) — gold chime trigger (throttled per F.2).
	if has_node("/root/Economy"):
		var econ: Node = get_node("/root/Economy")
		if econ.has_signal("gold_changed") and not econ.gold_changed.is_connected(_on_gold_changed):
			econ.gold_changed.connect(_on_gold_changed)

	# FloorUnlock — the class-unlock fanfare (§C.2) has no class-unlock flow in
	# this design (classes are static content), so the cue rides biome_unlocked:
	# a genuine, rare, triumphant progression beat fitting the "reserved for
	# genuine unlocks" fanfare (the loudest single SFX in the game).
	if has_node("/root/FloorUnlock"):
		var fu: Node = get_node("/root/FloorUnlock")
		if fu.has_signal("biome_unlocked") and not fu.biome_unlocked.is_connected(_on_biome_unlocked):
			fu.biome_unlocked.connect(_on_biome_unlocked)


# ---------------------------------------------------------------------------
# Public API — volume control (called by Settings overlay in Sprint 12+)
# ---------------------------------------------------------------------------

## Sets the Master bus volume in dB and applies immediately. Persists via
## the SaveLoadSystem consumer surface on next persist trigger.
##
## ADR-0008 / audio-system.md §G.
func set_master_volume_db(db: float) -> void:
	_master_volume_db = db
	_apply_to_audio_server()


func set_music_volume_db(db: float) -> void:
	_music_volume_db = db
	_apply_to_audio_server()


func set_sfx_volume_db(db: float) -> void:
	_sfx_volume_db = db
	_apply_to_audio_server()


func get_master_volume_db() -> float:
	return _master_volume_db


func get_music_volume_db() -> float:
	return _music_volume_db


func get_sfx_volume_db() -> float:
	return _sfx_volume_db


## Sets the Master bus mute state. Mute is hard (-INF dB) per audio-system.md
## §E.5: applies immediately, no fade. Reward fanfares in progress are silenced.
func set_master_muted(muted: bool) -> void:
	_master_muted = muted
	_apply_to_audio_server()


func is_master_muted() -> bool:
	return _master_muted


# ---------------------------------------------------------------------------
# Public API — manual cue trigger (escape hatches; gameplay code uses signals)
# ---------------------------------------------------------------------------

## Resolves [param sfx_id] via DataRegistry and plays a transient
## AudioStreamPlayer routed to the cue's target bus per §C.2.
##
## [param sfx_id]: StringName key from §C.2 table. Unknown ids play nothing
##   (DataRegistry returns null → silent skip per OQ-AS-6 / E.1).
## [param pitch_scale]: AudioStreamPlayer.pitch_scale multiplier. Default 1.0.
## [param volume_mult]: linear multiplier applied as linear_to_db offset to
##   the player's volume_db. Default 1.0. Values from §C.2 are in the
##   [constant _CUE_VOLUME_MULT_MAP].
##
## Returns [code]null[/code] in headless mode; otherwise returns the transient
## [AudioStreamPlayer] child (alive only during playback, then queue_freed).
func play_sfx(sfx_id: StringName, pitch_scale: float = 1.0, volume_mult: float = 1.0) -> AudioStreamPlayer:
	if _headless_mode:
		return null

	# Debug-build play log for test observability (zero overhead in release).
	if OS.is_debug_build():
		_test_play_sfx_log.append({
			"sfx_id": sfx_id,
			"pitch_scale": pitch_scale,
			"volume_mult": volume_mult,
		})

	# DataRegistry resolve — null means asset not yet sourced (OQ-AS-6 scope).
	var stream: AudioStream = null
	if has_node("/root/DataRegistry"):
		var registry: Node = get_node("/root/DataRegistry")
		# DataRegistry.resolve takes content_type (String) + id (String).
		# Strip the "sfx_" prefix from the StringName to match asset file naming.
		var raw_id: String = str(sfx_id)
		if raw_id.begins_with("sfx_"):
			raw_id = raw_id.substr(4)
		if registry.has_method("resolve"):
			stream = _stream_from_resolved(registry.resolve("sfx", raw_id))

	if stream == null:
		# No asset yet (E.1 / OQ-AS-6) — skip play silently.
		return null

	# Determine target bus from cue map; fall back to SFX root if unknown.
	var target_bus: StringName = _CUE_BUS_MAP.get(sfx_id, _BUS_SFX)

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = target_bus
	player.pitch_scale = pitch_scale
	# Convert linear multiplier to dB offset. volume_mult=1.0 → 0 dB offset.
	player.volume_db = linear_to_db(maxf(volume_mult, 0.0001))
	add_child(player)
	player.play()
	# Queue-free when playback finishes to avoid AudioStreamPlayer leaks.
	player.finished.connect(player.queue_free)
	return player


## Extracts the playable [AudioStream] from a DataRegistry-resolved resource.
##
## Per design/gdd/audio-system.md §C.6, audio cues ship as [AudioCue] wrappers
## ([GameData] subclasses) that carry the DataRegistry [code]id[/code] and
## reference the underlying [code].wav[/code] / [code].ogg[/code] via their
## [code]stream[/code] field. (A bare AudioStream [code].tres[/code] cannot ship:
## it has no [code]id[/code], so DataRegistry's boot scan rejects it with
## ERROR_INVALID_ID — see ADR-0022. The old [code]as AudioStream[/code] cast here
## was a never-exercised silent-MVP shortcut.)
##
## Tolerant by design — never crashes, always returns a stream or null:
##   - [code]null[/code] in → [code]null[/code] out (silent skip).
##   - a bare [AudioStream] resource → returned as-is.
##   - any resource exposing a [code]stream[/code] property ([AudioCue]) →
##     its [code].stream[/code] cast to [AudioStream].
##   - anything else (e.g. a non-audio content resource) → [code]null[/code].
##
## Duck-typed on the [code]stream[/code] property so AudioRouter (engine layer)
## stays decoupled from the [AudioCue] content class (data layer).
func _stream_from_resolved(resolved: Resource) -> AudioStream:
	if resolved == null:
		return null
	if resolved is AudioStream:
		return resolved as AudioStream
	if "stream" in resolved:
		return resolved.stream as AudioStream
	return null


## Crossfades to a new Music/Ambient bed per §F.4.
##
## If [param music_id] matches the currently-playing bed, this is a no-op.
## If no bed is currently playing, starts the new bed directly at full volume.
## Otherwise, fades old out and new in over [param fade_in_ms].
func play_music(music_id: StringName, fade_in_ms: int = _MUSIC_DEFAULT_FADE_MS) -> void:
	if _headless_mode:
		return

	# No-op guard per §F.4: same id already playing.
	if music_id == _current_ambient_id and _current_ambient_player != null:
		return

	# Resolve the music stream via DataRegistry.
	var stream: AudioStream = null
	if has_node("/root/DataRegistry"):
		var registry: Node = get_node("/root/DataRegistry")
		var raw_id: String = str(music_id)
		if raw_id.begins_with("music_"):
			raw_id = raw_id.substr(6)
		# Strip trailing "_bed" or "_stinger" suffix per ADR-0006 asset-path schema:
		# asset is at assets/audio/music/<id_without_prefix>.ogg
		if registry.has_method("resolve"):
			stream = _stream_from_resolved(registry.resolve("music", raw_id))
		# Demo fallback: when DataRegistry has no music assets (production art not
		# yet delivered), try loading from assets/audio/demo/ using a name mapping
		# that strips the trailing "_bed" / "_stinger" pattern.
		# Keeps the ADR-0016 silent-MVP contract intact in the production path —
		# demo tracks only load when the demo directory and matching file exist.
		if stream == null:
			var base_name: String = raw_id.trim_suffix("_bed").trim_suffix("_stinger")
			# Map the requested bed (guild_hall + the 6 biome ids) onto the demo
			# track set so dungeon runs aren't silent. Unmapped ids fall back to
			# the generic dungeon track. See design/art/demo-asset-manifest.md.
			var track: String = _DEMO_MUSIC_MAP.get(base_name, _DEMO_MUSIC_DEFAULT)
			var demo_path: String = "res://assets/audio/demo/bgm_%s.mp3" % track
			# Use ResourceLoader.exists (NOT FileAccess.file_exists): the demo mp3
			# is an imported asset, so on an exported build the source path is
			# stripped while the import map still resolves via load(). Guarding
			# with FileAccess would be stricter than the load() that follows it.
			# Matches the project-wide ResourceLoader.exists export-safety convention.
			if ResourceLoader.exists(demo_path):
				stream = load(demo_path) as AudioStream

	# Spawn new player at -80 dB baseline (near-silence per §F.4 -∞ intent;
	# -80 avoids INF arithmetic edge cases in the Tween).
	var new_player: AudioStreamPlayer = AudioStreamPlayer.new()
	new_player.stream = stream  # null-safe: stream=null means silence
	new_player.bus = _BUS_MUSIC_AMBIENT
	new_player.volume_db = -80.0
	new_player.autoplay = false
	add_child(new_player)
	new_player.play()

	if _current_ambient_player == null:
		# No existing bed — jump straight to full volume without fade.
		new_player.volume_db = 0.0
	else:
		# Crossfade: fade out old, fade in new simultaneously.
		var old_player: AudioStreamPlayer = _current_ambient_player
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(old_player, "volume_db", -80.0, fade_in_ms / 1000.0)
		tween.tween_property(new_player, "volume_db", 0.0, fade_in_ms / 1000.0)
		# E.4: if play_music fires again mid-fade, old_player will have been
		# queue_freed by the next crossfade's finished callback; no double-free
		# because queue_free is idempotent (Godot defers to end-of-frame).
		tween.tween_callback(old_player.queue_free).set_delay(fade_in_ms / 1000.0)

	_current_ambient_player = new_player
	_current_ambient_id = music_id


## Fades out and queue_frees the current Music/Ambient bed.
## No-op if no bed is currently playing.
func stop_music(fade_out_ms: int = _MUSIC_DEFAULT_FADE_MS) -> void:
	if _headless_mode:
		return
	if _current_ambient_player == null:
		return

	var player_to_fade: AudioStreamPlayer = _current_ambient_player
	_current_ambient_player = null
	_current_ambient_id = &""

	var tween: Tween = create_tween()
	tween.tween_property(player_to_fade, "volume_db", -80.0, fade_out_ms / 1000.0)
	tween.tween_callback(player_to_fade.queue_free)


# ---------------------------------------------------------------------------
# Save consumer surface — per audio-system.md §C.7
# ---------------------------------------------------------------------------

## SaveLoadSystem-compatible save-data getter. Per Save/Load GDD canonical
## consumer contract (Pass-5A): save dict shape is
## { "master_volume_db": float, "music_volume_db": float,
##   "sfx_volume_db": float, "master_muted": bool }.
##
## Namespaced under top-level key "audio" by SaveLoadSystem (not by us).
func get_save_data() -> Dictionary:
	return {
		"master_volume_db": _master_volume_db,
		"music_volume_db": _music_volume_db,
		"sfx_volume_db": _sfx_volume_db,
		"master_muted": _master_muted,
	}


## SaveLoadSystem-compatible save-data setter. Defensive per-field defaults
## per audio-system.md §E.2 (corrupt save / missing field → defaults).
func load_save_data(d: Dictionary) -> void:
	_master_volume_db = float(d.get("master_volume_db", _DEFAULT_MASTER_DB))
	_music_volume_db = float(d.get("music_volume_db", _DEFAULT_MUSIC_DB))
	_sfx_volume_db = float(d.get("sfx_volume_db", _DEFAULT_SFX_DB))
	_master_muted = bool(d.get("master_muted", _DEFAULT_MASTER_MUTED))
	_apply_to_audio_server()


# ---------------------------------------------------------------------------
# Signal handlers — S12-M6 Stories 3-5 implementations
# ---------------------------------------------------------------------------

## §C.2 / §K Story 3: UI panel SFX on screen entry.
## AC-AS-14, AC-AS-15 are in UIFramework scope, not here.
func _on_screen_changed(new_screen_id: String, old_screen_id: String) -> void:
	# §C.2 panel-open cue: the asset (ui_panel_open) is now sourced + wrapped as an
	# AudioCue .tres (ADR-0022), so OQ-AS-6's "asset not sourced" deferral is closed
	# and the cue is wired. Fires once per screen transition — navigation is
	# user-initiated (a tap), not a signal storm, so no throttle is needed.
	# UIFramework.wire_touch_feedback still owns the per-tap chime; this layers the
	# parchment-panel whoosh as the new screen slides in. No-ops on the boot/no-op
	# transition (empty new_screen_id) and is null-safe if the cue ever unresolves.
	# volume_mult 0.9 per §C.2 / _CUE_VOLUME_MULT_MAP — the panel whoosh sits just
	# under the per-tap chime so navigation never feels louder than the tap itself.
	if new_screen_id != "":
		play_sfx(&"sfx_ui_panel_open", 1.0, 0.9)
	# §C.2 panel-close cue (ADR-0022): the mirror whoosh for the screen sliding OUT.
	# The cue id was pre-declared in _CUE_BUS_MAP / _CUE_VOLUME_MULT_MAP; its AudioCue
	# .tres now exists, closing the wiring. Fires for the OLD screen (the panel
	# folding away) — guarded on old_screen_id != "" so the boot transition (no prior
	# screen) is silent. Paired with the open whoosh above, a screen swap reads as a
	# single fold-away → unfold gesture. volume_mult 0.9 per §C.2, matching the open
	# whoosh so neither side of the swap is louder than the other. Null-safe if the
	# cue ever unresolves.
	if old_screen_id != "":
		play_sfx(&"sfx_ui_panel_close", 1.0, 0.9)
	# Music transition for non-dungeon screens handled here — return to
	# guild_hall bed whenever a non-dungeon screen appears AND we're not
	# currently in an active dungeon run. In Sprint 12+, SceneManager.screen_id
	# constants will allow a tighter screen-type guard; for now, use presence
	# of DungeonRunOrchestrator state as the guard.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	var in_dungeon: bool = false
	if orch != null and "state" in orch:
		# ACTIVE_FOREGROUND = 2 per DungeonRunState.State enum.
		in_dungeon = (orch.state == 2)

	if not in_dungeon and new_screen_id != "":
		# The victory / result screen gets the triumphant bed; every other
		# non-dungeon screen returns to the guild hall ambient. (When demo audio
		# is absent, music_victory_bed resolves to nothing and is silent — the
		# production silent-MVP path is unchanged.)
		if new_screen_id == "victory_moment":
			play_music(&"music_victory_bed")
		else:
			play_music(&"music_guild_hall_bed")


## §C.3 / §K Story 4: biome-bed swap when run state transitions.
## Per §C.3: entering ACTIVE_FOREGROUND → play biome bed; returning from
## dungeon (RUN_ENDED) → play guild hall bed.
func _on_run_state_changed(new_state: int, _old_state: int) -> void:
	# ACTIVE_FOREGROUND = 2, RUN_ENDED = 4 per DungeonRunState.State enum.
	if new_state == 2:
		# New run dispatched — re-arm the one-shot advantage chime latch so the
		# next favourable-matchup kill fires the chime once for this run.
		_advantage_chime_fired_this_run = false
		# Entering ACTIVE_FOREGROUND: a boss floor gets the boss bed; otherwise
		# the biome bed (empty biome → guild hall fallback per spec).
		if _dispatched_floor_is_boss():
			play_music(&"music_boss_bed")
			return
		var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
		var biome_id: String = ""
		if orch != null and "_dispatched_biome_id" in orch:
			biome_id = str(orch.get("_dispatched_biome_id"))
		if biome_id != "":
			play_music(StringName("music_" + biome_id + "_bed"))
		else:
			# Unknown/empty biome: fall back to guild hall bed per spec.
			play_music(&"music_guild_hall_bed")
	elif new_state == 4:
		# RUN_ENDED: return to guild hall bed. (The victory_moment screen, which
		# appears next, swaps to the victory bed in _on_screen_changed.)
		play_music(&"music_guild_hall_bed")


## True when the active run's dispatched floor is a boss floor. Resolves the
## Floor from the live run_snapshot's floor_id via BiomeDungeonDatabase. Returns
## false defensively when no run is active (run_snapshot null) or the floor can't
## be resolved — so the audio unit tests (which don't seed a run_snapshot) keep
## taking the biome-bed path. Mirrors the dungeon_run_view biome→floor lookup.
func _dispatched_floor_is_boss() -> bool:
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch == null or orch.run_snapshot == null:
		return false
	var floor_id: String = str(orch.run_snapshot.floor_id)
	if floor_id == "":
		return false
	var biome_id: String = ""
	if "_dispatched_biome_id" in orch:
		biome_id = str(orch.get("_dispatched_biome_id"))
	if biome_id == "":
		return false
	var db: Node = get_node_or_null("/root/BiomeDungeonDatabase")
	if db == null or not db.has_method("get_biome_by_id"):
		return false
	var biome: Variant = db.get_biome_by_id(biome_id)
	if biome == null or not ("dungeons" in biome) or (biome.dungeons as Array).is_empty():
		return false
	var dungeon: Variant = biome.dungeons[0]
	if dungeon == null or not ("floors" in dungeon):
		return false
	for f: Variant in dungeon.floors:
		if f != null and ("id" in f) and str(f.id) == floor_id:
			return ("is_boss_floor" in f) and bool(f.is_boss_floor)
	return false


## §F.1 / §C.2 / §K Story 3: tier-modulated kill chime per Formula F.1.
## pitch_scale(tier) = 1.0 + (3 - tier) * 0.10
## No throttle on kill chime — E.6: 5 kills in a frame produces 5 overlapping
## chimes; that is intended behavior.
func _on_enemy_killed(tier: int, _archetype: String, advantaged: bool) -> void:
	var pitch: float = 1.0 + (3 - tier) * 0.10
	play_sfx(&"sfx_combat_enemy_kill", pitch, 1.0)
	# §C.2 advantage chime — one gentle two-note rising chime per run, on the FIRST
	# advantaged kill (favourable class-vs-biome matchup). The latch prevents
	# per-kill spam (E.6 allows overlapping kill chimes, but the advantage beat is
	# a once-per-run confirmation, not per-kill). Re-armed on ACTIVE_FOREGROUND.
	# volume_mult 0.8 per §C.2 / _CUE_VOLUME_MULT_MAP — sits under the kill chime.
	if advantaged and not _advantage_chime_fired_this_run:
		_advantage_chime_fired_this_run = true
		play_sfx(&"sfx_combat_advantage_chime", 1.0, 0.8)


## §C.2 / §K Story 3: boss kill chime — distinct sample, volume_mult 1.4.
func _on_boss_killed(_enemy_id: String) -> void:
	play_sfx(&"sfx_combat_boss_kill", 1.0, 1.4)


## §C.2 hero-damaged "bump" — soft, low, non-alarming. Verdict-driven combat has
## no per-hit damage event, so this rides HeroRoster.heroes_injured: it fires once
## per defeat that wounds the party. The signal carries the list of injured ids,
## but the cue is a single party-level "ouch", so it plays once regardless of how
## many heroes were marked. volume_mult 0.7 per §C.2 — quieter than the kill chime.
func _on_heroes_injured(_instance_ids: Array, _injured_until_ms: int) -> void:
	play_sfx(&"sfx_combat_hero_damaged", 1.0, 0.7)


## §C.2 run-defeated sting (S30-N1 defeat-weight pass) — the somber, non-punishing
## counterpart to the floor-clear fanfare. Rides DungeonRunOrchestrator.run_defeated,
## firing the instant the in-flight run is lost. DELIBERATELY DISTINCT from every
## victory cue (floor_clear_fanfare / class_unlock_fanfare / level_up_chime): a low,
## soft tone at volume_mult 0.9 — fuller than the hero-damaged bump (0.7), far under
## the 1.4 fanfare — so defeat reads as a weighted setback, not a triumph and not a
## thud. A single sting, NO Stinger (the cozy tone forgives the loss). Wired-silent
## until the asset is sourced (ADR-0016 / ADR-0022): play_sfx logs the cue then
## no-ops on the null stream, exactly like the other §C.2 cues awaiting assets.
func _on_run_defeated(_floor_index: int, _biome_id: String) -> void:
	play_sfx(&"sfx_combat_run_defeated", 1.0, 0.9)


## §C.2 + §C.3 / §K Story 5: floor clear fanfare (SFX/Reward) + Stinger
## (Music/Stinger with Ambient duck).
func _on_floor_cleared_first_time(_floor_index: int, _biome_id: String, _losing_run: bool) -> void:
	play_sfx(&"sfx_reward_floor_clear_fanfare", 1.0, 1.4)
	_play_stinger(&"music_floor_clear_stinger")


## §C.2 class-unlock fanfare — the loudest single SFX, reserved for genuine
## unlocks. This design has no runtime class-unlock flow (classes are static
## content), so the cue rides FloorUnlock.biome_unlocked: unlocking a new biome
## is the rarest, most triumphant progression beat available. Biome unlocks are
## infrequent, so no throttle is needed. volume_mult 1.5 per §C.2.
func _on_biome_unlocked(_biome_id: String) -> void:
	play_sfx(&"sfx_reward_class_unlock_fanfare", 1.0, 1.5)


## §E.8 / §K Story 3: level-up chime. Guards hydration suppression flag on
## HeroRoster so chime does not fire during save-load hydration (OQ-AS-5).
## [param instance_id]: hero instance id (matches hero_leveled signal param).
func _on_hero_leveled(_instance_id: int, _old_level: int, _new_level: int) -> void:
	# E.8 hydration guard: check HeroRoster._suppress_signals.
	var roster: Node = get_node_or_null("/root/HeroRoster")
	if roster != null and "_suppress_signals" in roster and roster._suppress_signals:
		return
	play_sfx(&"sfx_reward_level_up_chime", 1.0, 1.2)


## Monotonic millisecond clock backing the three throttle windows. Returns the
## test override when set ([member _throttle_now_override_ms] >= 0), otherwise
## real engine uptime. A single seam keeps all three throttle handlers on one
## clock source and lets tests drive the windows deterministically.
func _throttle_now_ms() -> int:
	return _throttle_now_override_ms if _throttle_now_override_ms >= 0 else Time.get_ticks_msec()


## §F.2 / §E.7 / §K Story 3: gold chime with anti-slot-machine throttle.
## E.7: delta ≤ 0 is skipped (refunds, zero-delta routing events).
## F.2: throttle to ≤1 play per _GOLD_CHIME_THROTTLE_MS window.
func _on_gold_changed(_new_balance: int, delta: int, _reason: String) -> void:
	# E.7: skip refunds and zero-delta events.
	if delta <= 0:
		return
	# F.2 throttle — compare against last-played timestamp.
	var now: int = _throttle_now_ms()
	if now - _gold_chime_last_played_ms < _GOLD_CHIME_THROTTLE_MS:
		return
	_gold_chime_last_played_ms = now
	play_sfx(&"sfx_reward_gold_collected", 1.0, 1.0)


## Class Synergy V1.0 (Sprint 21 S21-S2 / Story 3) — live-preview detection
## chime handler. Throttled to ≤1 play per [constant _CLASS_SYNERGY_DETECTED_THROTTLE_MS]
## (2.0s) per AC-CS-14: rapid slot-toggling that fires the detection signal
## repeatedly within the window plays the chime ONCE.
##
## Per `class-synergy-system.md` §C.4 audio integration. The chime is a warm
## "you-found-something" cozy register cue — NOT a fanfare. Routes through
## `play_sfx` which honors the silent-MVP fallback (cue resource may be
## absent in MVP per ADR-0016; AudioRouter logs `push_warning` and continues).
##
## [param synergy_id]: the detected synergy id (one of "steel_wall",
##   "arcane_elite", "triple_threat" in V1.0 first-pass). Per FormationAssignment's
##   notify_synergy_detected contract, this is always non-empty when fired.
##   Currently the cue is the same regardless of synergy_id; V1.5+ may add
##   per-synergy variants.
func _on_class_synergy_detected(_synergy_id: String) -> void:
	# AC-CS-14: throttle to suppress rapid-toggle spam.
	var now: int = _throttle_now_ms()
	if now - _class_synergy_detected_last_played_ms < _CLASS_SYNERGY_DETECTED_THROTTLE_MS:
		return
	_class_synergy_detected_last_played_ms = now
	play_sfx(&"sfx_class_synergy_detected", 1.0, 1.0)


## Class Synergy V1.0 (Sprint 21 S21-S2 / Story 3) — dispatch-time chime
## handler. NOT throttled — DungeonRunOrchestrator's DISPATCH_DEBOUNCE_MS
## (250ms) naturally rate-limits the dispatched signal.
##
## Per `class-synergy-system.md` §C.4: a single warm sting at run start.
## NOT looped. Same cozy register as detection chime but a different cue
## resource so the dispatch beat stands distinct from the live preview.
##
## [param synergy_id]: the run's active synergy id (always non-empty per
##   the orchestrator's dispatch-time emit contract).
func _on_class_synergy_dispatched(_synergy_id: String) -> void:
	play_sfx(&"sfx_class_synergy_dispatched", 1.0, 1.0)


## Prestige V1.0 (Sprint 21+ silent-MVP wiring) — completion fanfare handler.
## Per `audio-system.md` §J Prestige cross-reference: warm sting on retirement
## action, throttled to once per [constant _PRESTIGE_COMPLETED_THROTTLE_MS]
## (2.0s). Routes through `play_sfx` which honors the silent-MVP fallback —
## the cue resource is intentionally absent in MVP per ADR-0016, so this
## handler runs to completion and plays nothing audible. When a future ADR
## supersedes ADR-0016 and the `sfx_prestige_completed.ogg` asset lands in
## `assets/audio/sfx/`, the fanfare becomes audible with no code change.
##
## [param record]: prestige record dict from HeroRoster (display_name,
##   class_id, level_at_retirement, prestige_index). Unused here — the
##   audio cue is per-event, not per-hero. UI handles the hero name.
## [param new_count]: post-retirement prestige count. Unused — same reason.
func _on_prestige_completed(_record: Dictionary, _new_count: int) -> void:
	# Hardening throttle: theoretical guard against back-to-back emissions.
	# UI flow is one prestige-at-a-time but the throttle keeps the audio path
	# defensible against future automation or test-emit bursts.
	var now: int = _throttle_now_ms()
	if now - _prestige_completed_last_played_ms < _PRESTIGE_COMPLETED_THROTTLE_MS:
		return
	_prestige_completed_last_played_ms = now
	play_sfx(&"sfx_prestige_completed", 1.0, 1.2)


# ---------------------------------------------------------------------------
# Private — Stinger playback with duck envelope (§F.3 / Story 5)
# ---------------------------------------------------------------------------

## Plays a Music/Stinger cue with the F.3 Ambient duck envelope.
##
## Non-overlap rule (§C.3): if a stinger is already playing, the new one is
## dropped with push_warning. The duck envelope is applied around the stinger
## duration: attack ramp (100 ms) + hold (stinger duration) + release (250 ms).
##
## [param stinger_id]: StringName key for the Music/Stinger cue (e.g.
##   [code]&"music_floor_clear_stinger"[/code]).
func _play_stinger(stinger_id: StringName) -> void:
	if _headless_mode:
		return

	# §C.3 non-overlap rule.
	if _current_stinger_player != null:
		push_warning("[AudioRouter] Stinger overlap dropped: %s while %s playing" % [stinger_id, _current_stinger_player.name])
		return

	# Resolve stream via DataRegistry.
	var stream: AudioStream = null
	if has_node("/root/DataRegistry"):
		var registry: Node = get_node("/root/DataRegistry")
		var raw_id: String = str(stinger_id)
		if raw_id.begins_with("music_"):
			raw_id = raw_id.substr(6)
		if registry.has_method("resolve"):
			stream = _stream_from_resolved(registry.resolve("music", raw_id))

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream  # null-safe: silence if asset missing
	player.bus = _BUS_MUSIC_STINGER
	player.name = stinger_id  # for overlap warning message above
	add_child(player)
	_current_stinger_player = player

	# F.3 attack: ramp Ambient duck offset from 0 to -3 dB over 100 ms.
	_apply_ambient_duck_envelope(_AMBIENT_DUCK_DB, _AMBIENT_DUCK_ATTACK_MS / 1000.0)
	player.play()

	# On stinger finished: release duck, queue_free player, clear tracking.
	player.finished.connect(_on_stinger_finished.bind(player))


## Called when the Stinger cue finishes. Releases the F.3 Ambient duck
## envelope over 250 ms, then queue_frees the player node.
func _on_stinger_finished(player: AudioStreamPlayer) -> void:
	_current_stinger_player = null
	# F.3 release: ramp ambient duck offset back to 0 dB over 250 ms.
	_apply_ambient_duck_envelope(0.0, _AMBIENT_DUCK_RELEASE_MS / 1000.0)
	player.queue_free()


## Tweens the Ambient bus volume offset (_ambient_duck_offset_db) to
## [param target_db] over [param duration_secs].
## Applies absolute volume as base + offset so player Settings changes
## don't fight the duck (§F.3 last paragraph).
func _apply_ambient_duck_envelope(target_db: float, duration_secs: float) -> void:
	if _duck_tween != null and _duck_tween.is_running():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_ambient_duck_offset, _ambient_duck_offset_db, target_db, duration_secs)


## Setter called by the duck envelope Tween. Writes the combined
## (base music volume + duck offset) to the Music/Ambient bus.
func _set_ambient_duck_offset(offset_db: float) -> void:
	_ambient_duck_offset_db = offset_db
	var ambient_idx: int = AudioServer.get_bus_index(_BUS_MUSIC_AMBIENT)
	if ambient_idx >= 0:
		# base_volume is the Music bus volume (relative child inherits); ambient
		# sub-bus is authored at 0 dB relative. Apply duck as absolute offset.
		AudioServer.set_bus_volume_db(ambient_idx, _ambient_duck_offset_db)


# ---------------------------------------------------------------------------
# Private — internal AudioServer apply
# ---------------------------------------------------------------------------

## Applies cached volume + mute state to AudioServer. Idempotent. Tolerates
## missing buses (test-env path with no audio_bus_layout.tres) — degrades to
## "set what we can; skip what's missing."
func _apply_to_audio_server() -> void:
	# Master bus is the only one with mute semantics; mute = -INF.
	var master_idx: int = AudioServer.get_bus_index(_BUS_MASTER)
	if master_idx >= 0:
		var effective_master_db: float = -INF if _master_muted else _master_volume_db
		AudioServer.set_bus_volume_db(master_idx, effective_master_db)
	var music_idx: int = AudioServer.get_bus_index(_BUS_MUSIC)
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, _music_volume_db)
	var sfx_idx: int = AudioServer.get_bus_index(_BUS_SFX)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, _sfx_volume_db)
