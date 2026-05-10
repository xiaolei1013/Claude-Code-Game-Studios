# US-010 (test-coverage-backfill epic): LocaleLoader autoload coverage.
#
# Audit observation: src/core/locale_loader/locale_loader.gd has ZERO functions
# matching the epic's public-surface predicate `^func [a-z]` — _ready and
# _load_csv_file are both underscore-prefixed (Godot lifecycle / private
# helper). FR-2 ("EVERY public function ... has at least one happy-path test")
# is therefore vacuously satisfied.
#
# However, the autoload's BOOT BEHAVIOR is observable and load-bearing:
#   - SUPPORTED_LOCALE_FILES drives which CSVs get loaded.
#   - _ready() registers a Translation per locale column with TranslationServer.
#   - _ready() sets TranslationServer.locale to DEFAULT_LOCALE so tr() resolves
#     to translated strings for any subsequent autoload's screen logs.
#
# Prior to this suite, no dedicated unit test existed for LocaleLoader — only
# transitive references from formation_assignment_screen_test.gd and
# class_synergy_audio_test.gd that exercise tr() for unrelated assertions.
# This suite locks in:
#   Group A — Constant table (catches drift / typos / file-disk mismatch)
#   Group B — Autoload registration (script identity at /root/LocaleLoader)
#   Group C — Boot side effects (Translation registered + tr() resolves a
#             known key from en.csv)
#
# Pattern reference: tests/unit/audio_router/audio_router_skeleton_test.gd
# (autoload identity + observable side effects via shared autoload tree).
extends GdUnitTestSuite

const LocaleLoaderScript = preload("res://src/core/locale_loader/locale_loader.gd")


# ===========================================================================
# Group A — Constant table
# ===========================================================================

func test_locale_loader_locale_dir_path_is_res_assets_locale() -> void:
	# Arrange / Act — script-level constant; no instance needed.
	var path: String = LocaleLoaderScript.LOCALE_DIR_PATH

	# Assert
	assert_str(path).is_equal("res://assets/locale")


func test_locale_loader_default_locale_is_en() -> void:
	assert_str(LocaleLoaderScript.DEFAULT_LOCALE).is_equal("en")


func test_locale_loader_supported_locale_files_contains_en_csv() -> void:
	# en.csv is the project's only shipped locale as of S9-M3; this assertion
	# is the lockstep guard for Recruitment-pool / formation-screen tests that
	# rely on tr() resolving against the EN catalog.
	var files: Array[String] = LocaleLoaderScript.SUPPORTED_LOCALE_FILES
	assert_bool(files.has("en.csv")).is_true()


func test_locale_loader_supported_locale_files_size_matches_canonical_one() -> void:
	# Canonical S9-M3 spec: exactly one locale file (en.csv). Adding a new
	# locale requires both the CSV and a lockstep update to this assertion.
	var files: Array[String] = LocaleLoaderScript.SUPPORTED_LOCALE_FILES
	assert_int(files.size()).is_equal(1)


func test_locale_loader_supported_locale_files_all_exist_on_disk() -> void:
	# Catches drift between SUPPORTED_LOCALE_FILES and the assets/locale/
	# directory. Without this, a typo in the constant would silently push
	# warnings at boot and leave tr() unresolved — visible only via UI tests.
	for filename: String in LocaleLoaderScript.SUPPORTED_LOCALE_FILES:
		var full_path: String = LocaleLoaderScript.LOCALE_DIR_PATH + "/" + filename
		assert_bool(FileAccess.file_exists(full_path)).override_failure_message(
			"SUPPORTED_LOCALE_FILES references '%s' but the file does not exist at '%s'" % [filename, full_path]
		).is_true()


# ===========================================================================
# Group B — Autoload registration
# ===========================================================================

func test_locale_loader_autoload_resolves_at_root() -> void:
	# Arrange / Act
	var loader: Node = get_tree().root.get_node_or_null("LocaleLoader")

	# Assert
	assert_object(loader).is_not_null()


func test_locale_loader_autoload_uses_locale_loader_script() -> void:
	var loader: Node = get_tree().root.get_node_or_null("LocaleLoader")
	assert_object(loader).is_not_null()
	assert_bool(loader.get_script() == LocaleLoaderScript).is_true()


# ===========================================================================
# Group C — Boot side effects (Translation registered + tr() resolves)
# ===========================================================================

func test_locale_loader_boot_registers_en_in_translation_server_loaded_locales() -> void:
	# After _ready() ran at boot, TranslationServer should report "en" among
	# its loaded locales (per add_translation in _load_csv_file). This is the
	# stable observable side effect even if a later test mutates the active
	# locale via TranslationServer.set_locale() — loaded_locales is the
	# accumulated registration set, not the live-active locale.
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	assert_bool(loaded.has("en")).override_failure_message(
		"TranslationServer.get_loaded_locales() = %s; expected to contain 'en' after LocaleLoader boot" % str(loaded)
	).is_true()


func test_locale_loader_boot_makes_tr_resolve_known_en_key() -> void:
	# End-to-end boot success: tr() for a key present in en.csv must resolve
	# to its translated value, not pass through the key. This is the same
	# probe pattern used by prestige_v1_story3_logic_test.gd line 281 to
	# detect the "TranslationServer never loaded en.csv" failure mode.
	#
	# Chosen key: formation_assignment_instructional_header — a stable S9-M3
	# entry that already appears in formation_assignment_screen_test.gd line
	# 630 as a load-bearing translated value, so the contract is doubly
	# anchored: this test fails fast if the EN catalog goes missing.
	var resolved: String = tr("formation_assignment_instructional_header")

	# Assert — value is the translated string, not the key passthrough.
	assert_str(resolved).is_not_equal("formation_assignment_instructional_header").override_failure_message(
		"tr() returned the key — LocaleLoader did not register en.csv translation at boot"
	)
	assert_str(resolved).is_equal("Send your guild to:")
