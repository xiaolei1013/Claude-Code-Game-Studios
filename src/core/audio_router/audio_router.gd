## AudioRouter — centralized audio routing autoload (Sprint 11 S11-S2 skeleton).
##
## Owns the gameplay-signal → bus playback translation per
## `design/gdd/audio-system.md`. Gameplay code never calls
## [code]AudioStreamPlayer.play()[/code] directly; routing happens here.
##
## Sprint 11 S11-S2 scope: SKELETON only.
##   - Public API surface declared (volume control, mute control, manual cue
##     trigger escape hatches).
##   - Signal subscription wiring to existing gameplay signals (SceneManager,
##     DungeonRunOrchestrator, HeroRoster, Economy) at [method _ready].
##   - Bus-volume-control method bodies are real (small, safe, no I/O).
##   - SFX / Music play-cue bodies are STUBS (no AudioStream resources sourced
##     yet; play_sfx / play_music return cleanly without effect).
##   - Save consumer surface (get_save_data / load_save_data) implemented with
##     defaults; volume restoration works once SaveLoadSystem load lands.
##
## Sprint 12+ extensions:
##   - Story 2: full volume API + SaveLoadSystem consumer registration round-trip.
##   - Story 3: signal handlers fire actual cue plays (UI tap chime, level-up
##     chime, etc.) once cue resources land in DataRegistry.
##   - Story 4: Music/Ambient crossfade implementation + biome-bed swap.
##   - Story 5: Music/Stinger duck envelope + reward fanfare wiring.
##   - Story 6: hydration suppression hook (audio-system.md §I.5).
##
## Governing GDD: design/gdd/audio-system.md
## Autoload rank: 16 (per ADR-0003 Amendment #5; appended after rank 15
## OfflineProgressionEngine so all gameplay-signal sources exist at our
## [method _ready] for connection).
## Story: S11-S2 (audio-system.md §K Sprint 11 minimum-viable scope)
extends Node


# ---------------------------------------------------------------------------
# Constants — bus names + cue payload schema keys
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


# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Cached top-level volume settings. Mirrors what's been written to AudioServer;
## also persisted via the get_save_data / load_save_data save consumer surface.
var _master_volume_db: float = _DEFAULT_MASTER_DB
var _music_volume_db: float = _DEFAULT_MUSIC_DB
var _sfx_volume_db: float = _DEFAULT_SFX_DB
var _master_muted: bool = _DEFAULT_MASTER_MUTED


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

## Sprint 11 S11-S2: subscribes to signal sources required by audio-system.md §F.
## Audio cue bodies are STUBs; this just wires the connections so Sprint 12+
## stories can land cue handlers without re-doing the connection plumbing.
##
## Defensive autoload-resolution per ADR-0003 §Signal SUBSCRIPTION rule —
## subscription across any rank pair is safe at _ready() time (signal objects
## exist on Node instantiation, before any _ready fires). [VERIFIED]
##
## Each connection is idempotent-guarded so re-binding (e.g., test-env) does
## not double-fire handlers.
func _ready() -> void:
	# Apply default volumes to AudioServer immediately. Settings overlay (Sprint
	# 12+) writes through set_*_volume_db, which both updates AudioServer and
	# triggers a save persist.
	_apply_to_audio_server()

	# Signal subscriptions — SceneManager (rank 8). Existing signal contract.
	if has_node("/root/SceneManager"):
		var sm: Node = get_node("/root/SceneManager")
		if sm.has_signal("screen_changed") and not sm.screen_changed.is_connected(_on_screen_changed):
			sm.screen_changed.connect(_on_screen_changed)

	# DungeonRunOrchestrator (rank 14) — state, kills, floor clears.
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

	# HeroRoster (rank 7) — level-up chime trigger.
	if has_node("/root/HeroRoster"):
		var roster: Node = get_node("/root/HeroRoster")
		if roster.has_signal("hero_leveled") and not roster.hero_leveled.is_connected(_on_hero_leveled):
			roster.hero_leveled.connect(_on_hero_leveled)

	# Economy (rank 3) — gold chime trigger (with throttle, per audio-system.md §F.2).
	if has_node("/root/Economy"):
		var econ: Node = get_node("/root/Economy")
		if econ.has_signal("gold_changed") and not econ.gold_changed.is_connected(_on_gold_changed):
			econ.gold_changed.connect(_on_gold_changed)


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

## Sprint 11 S11-S2: STUB. Sprint 12+ Story 3 implements actual cue play via
## DataRegistry.resolve("sfx", id) → AudioStreamPlayer routed to the cue's bus.
func play_sfx(_sfx_id: StringName) -> void:
	pass  # Sprint 12+ Story 3


## Sprint 11 S11-S2: STUB. Sprint 12+ Story 4 implements actual cue play +
## crossfade with the currently-playing Ambient (if any).
func play_music(_music_id: StringName, _fade_in_ms: int = 800) -> void:
	pass  # Sprint 12+ Story 4


## Sprint 11 S11-S2: STUB. Sprint 12+ Story 4 implements fade-out + queue_free.
func stop_music(_fade_out_ms: int = 800) -> void:
	pass  # Sprint 12+ Story 4


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
# Signal handlers — STUBS in Sprint 11 S11-S2; Sprint 12+ Story 3 implements
# actual cue play. Connections are wired so Story 3 lands without
# re-plumbing.
# ---------------------------------------------------------------------------

func _on_screen_changed(_new_screen_id: String, _old_screen_id: String) -> void:
	pass  # Sprint 12+ Story 3 / Story 4 (UI panel SFX + Music/Ambient crossfade)


func _on_run_state_changed(_new_state: int, _old_state: int) -> void:
	pass  # Sprint 12+ Story 4 (biome-bed swap on dungeon entry)


func _on_enemy_killed(_tier: int, _archetype: String, _advantaged: bool) -> void:
	pass  # Sprint 12+ Story 3 (tier-modulated kill chime per Formula F.1)


func _on_boss_killed(_enemy_id: String) -> void:
	pass  # Sprint 12+ Story 3 (boss kill chime — distinct sample)


func _on_floor_cleared_first_time(_floor_index: int, _biome_id: String, _losing_run: bool) -> void:
	pass  # Sprint 12+ Story 5 (floor clear fanfare + Music/Stinger with Ambient duck)


func _on_hero_leveled(_instance_id: int, _old_level: int, _new_level: int) -> void:
	pass  # Sprint 12+ Story 3 (level-up chime, paired with S10-M4 toast)


func _on_gold_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	pass  # Sprint 12+ Story 3 (gold-collected chime with anti-slot-machine throttle F.2)


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
