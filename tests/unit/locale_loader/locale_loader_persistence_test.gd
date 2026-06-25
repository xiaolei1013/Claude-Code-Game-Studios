# Locale persistence coverage for LocaleLoader (ADR-0026 §C.5 / D-b,
# Settings GDD #30 §C.5). Closes ADR-0026 "Verification Required" item (4):
# "persistence round-trip test with a user:// path override".
#
# Surface under test (src/core/locale_loader/locale_loader.gd):
#   - _apply_persisted_locale()  — boot-read: switch to the persisted locale if
#                                   it is currently loaded; else keep default.
#   - persist_locale(locale_id)  — load-modify-save write of
#                                   [locale]/active_locale, preserving unrelated
#                                   sections in the SHARED user://settings.cfg.
#
# Isolation strategy (mirrors reduce_motion_clamp_test.gd, the canonical
# path-override pattern):
#   - A FRESH non-autoload LocaleLoader instance with _settings_cfg_path pointed
#     at a unique per-run temp file. Not added to the tree, so _ready()'s CSV
#     load + global registration never fire; the persistence methods are driven
#     directly.
#   - Both methods mutate global TranslationServer locale, so the live locale is
#     snapshot/restored around every test. A synthetic second locale ("eo") is
#     registered so a SWITCH is observable (en is always loaded, so persisting
#     en alone could not distinguish a switch from a no-op).
extends GdUnitTestSuite

const LocaleLoaderScript = preload("res://src/core/locale_loader/locale_loader.gd")

## Distinct, throwaway locale used to prove a real switch occurred. Not a real
## CSV column — registered/removed per test purely as a probe.
const PROBE_LOCALE: String = "eo"

var _orig_locale: String = ""
var _test_cfg_path: String = ""
var _probe_translation: Translation = null


func before_test() -> void:
	_orig_locale = TranslationServer.get_locale()
	# Unique per-run temp path (ticks) so concurrent/successive runs never share
	# a settings file. Never the real user://settings.cfg.
	_test_cfg_path = "user://test_%d_locale_persist.cfg" % Time.get_ticks_msec()
	# Register a distinct loaded locale so _apply_persisted_locale switching to
	# it is observable against the always-present "en".
	_probe_translation = Translation.new()
	_probe_translation.locale = PROBE_LOCALE
	_probe_translation.add_message(&"__persist_probe__", &"probo")
	TranslationServer.add_translation(_probe_translation)


func after_test() -> void:
	if _probe_translation != null:
		TranslationServer.remove_translation(_probe_translation)
		_probe_translation = null
	TranslationServer.set_locale(_orig_locale)
	if FileAccess.file_exists(_test_cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_cfg_path))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Fresh, non-autoload LocaleLoader with an isolated settings path. Deliberately
## NOT added to the tree (so _ready does not fire); the persistence methods are
## exercised directly.
func _make_loader() -> Node:
	var loader: Node = LocaleLoaderScript.new()
	loader._settings_cfg_path = _test_cfg_path
	auto_free(loader)
	return loader


## Writes a value at [locale]/active_locale in the temp cfg.
func _write_active_locale(value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(
		LocaleLoaderScript.SETTINGS_LOCALE_SECTION,
		LocaleLoaderScript.SETTINGS_LOCALE_KEY,
		value
	)
	var err: Error = cfg.save(_test_cfg_path)
	assert_int(err).is_equal(OK)


# ===========================================================================
# Group A — _apply_persisted_locale (boot-read)
# ===========================================================================

func test_apply_persisted_locale_switches_to_loaded_locale() -> void:
	# Arrange — a valid, currently-loaded locale is persisted; baseline is en.
	_write_active_locale(PROBE_LOCALE)
	TranslationServer.set_locale("en")
	var loader: Node = _make_loader()

	# Act
	loader._apply_persisted_locale()

	# Assert — the boot-read overrode the default with the persisted locale.
	assert_str(TranslationServer.get_locale()).starts_with(PROBE_LOCALE)


func test_apply_persisted_locale_ignores_unloaded_locale() -> void:
	# Arrange — a locale that is NOT loaded must be ignored (default kept).
	_write_active_locale("zz")
	TranslationServer.set_locale("en")
	var loader: Node = _make_loader()

	# Act
	loader._apply_persisted_locale()

	# Assert — unchanged; the bogus locale did not take.
	assert_str(TranslationServer.get_locale()).starts_with("en")


func test_apply_persisted_locale_missing_file_keeps_current() -> void:
	# Arrange — temp cfg never written (first-launch path). Must be silent.
	TranslationServer.set_locale("en")
	var loader: Node = _make_loader()

	# Act
	loader._apply_persisted_locale()

	# Assert — default stands, no crash.
	assert_str(TranslationServer.get_locale()).starts_with("en")


func test_apply_persisted_locale_ignores_non_string_value() -> void:
	# Arrange — a non-String value is type-guarded (regression: ConfigFile
	# get_value returns its default ONLY on a MISSING key, not a wrong-typed
	# present one, so an int would otherwise slip through).
	_write_active_locale(42)
	TranslationServer.set_locale("en")
	var loader: Node = _make_loader()

	# Act
	loader._apply_persisted_locale()

	# Assert — wrong type rejected; default kept.
	assert_str(TranslationServer.get_locale()).starts_with("en")


# ===========================================================================
# Group B — persist_locale (write)
# ===========================================================================

func test_persist_locale_writes_active_locale() -> void:
	# Arrange
	var loader: Node = _make_loader()

	# Act
	loader.persist_locale(PROBE_LOCALE)

	# Assert — the key round-trips back from disk.
	var cfg := ConfigFile.new()
	assert_int(cfg.load(_test_cfg_path)).is_equal(OK)
	var stored: Variant = cfg.get_value(
		LocaleLoaderScript.SETTINGS_LOCALE_SECTION,
		LocaleLoaderScript.SETTINGS_LOCALE_KEY,
		""
	)
	assert_str(stored).is_equal(PROBE_LOCALE)


func test_persist_locale_preserves_unrelated_sections() -> void:
	# Arrange — pre-seed the SHARED file with SceneManager's accessibility key.
	var seed := ConfigFile.new()
	seed.set_value("accessibility", "reduce_motion", true)
	assert_int(seed.save(_test_cfg_path)).is_equal(OK)
	var loader: Node = _make_loader()

	# Act — load-modify-save must NOT clobber [accessibility].
	loader.persist_locale(PROBE_LOCALE)

	# Assert — both keys coexist after the write.
	var cfg := ConfigFile.new()
	assert_int(cfg.load(_test_cfg_path)).is_equal(OK)
	assert_str(cfg.get_value(
		LocaleLoaderScript.SETTINGS_LOCALE_SECTION,
		LocaleLoaderScript.SETTINGS_LOCALE_KEY, "")).is_equal(PROBE_LOCALE)
	assert_bool(cfg.get_value("accessibility", "reduce_motion", false)).is_true()


func test_persist_locale_empty_id_is_noop() -> void:
	# Arrange
	var loader: Node = _make_loader()

	# Act — an empty id must not create or write the file.
	loader.persist_locale("")

	# Assert — nothing persisted.
	assert_bool(FileAccess.file_exists(_test_cfg_path)).is_false()


# ===========================================================================
# Group C — end-to-end round-trip (write → fresh boot-read)
# ===========================================================================

func test_persist_then_apply_round_trip_restores_locale() -> void:
	# Arrange — start at en, persist the probe locale via one instance.
	TranslationServer.set_locale("en")
	var writer: Node = _make_loader()
	writer.persist_locale(PROBE_LOCALE)

	# Act — a SECOND instance (same temp cfg) performs the boot-read, as a real
	# restart would.
	var booter: Node = _make_loader()
	booter._apply_persisted_locale()

	# Assert — the persisted choice survived the round-trip.
	assert_str(TranslationServer.get_locale()).starts_with(PROBE_LOCALE)
