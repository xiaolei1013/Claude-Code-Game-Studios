# PR2 (i18n string extraction, ADR-0026 decision D-d): pseudolocale QA gate.
#
# LocaleLoader can synthesize a debug-only "en_XA" pseudolocale from the en
# column when LANTERN_PSEUDOLOCALE=1. Switching to it in QA surfaces (a)
# unextracted hardcoded English (renders as plain ASCII letters) and (b)
# layouts that cannot absorb ~40% text expansion (a clipped close-bracket).
#
# These tests lock the transform contract and prove the pseudolocale NEVER
# ships in a normal boot (no env var) — the safety property that keeps it out
# of player builds. The enabled-boot path is exercised manually via a
# `LANTERN_PSEUDOLOCALE=1` launch (documented in ADR-0026) rather than here, to
# avoid mutating the process-global TranslationServer across the suite.
extends GdUnitTestSuite

const LocaleLoaderScript = preload("res://src/core/locale_loader/locale_loader.gd")


# ===========================================================================
# Group A — pseudo_transform (pure static; no engine state)
# ===========================================================================

func test_pseudo_transform_wraps_in_pseudolocale_brackets() -> void:
	var result: String = LocaleLoaderScript.pseudo_transform("Recruit")
	assert_str(result).starts_with(LocaleLoaderScript.PSEUDO_BRACKET_OPEN)
	assert_str(result).ends_with(LocaleLoaderScript.PSEUDO_BRACKET_CLOSE)


func test_pseudo_transform_accents_every_ascii_letter() -> void:
	# No plain ASCII letter from the source may survive — that is what makes an
	# unextracted literal visually obvious when the pseudolocale is active.
	var result: String = LocaleLoaderScript.pseudo_transform("Recruit")
	for plain: String in ["R", "e", "c", "r", "u", "i", "t"]:
		assert_bool(result.contains(plain)).override_failure_message(
			"pseudo_transform left plain ASCII '%s' in %s" % [plain, result]
		).is_false()


func test_pseudo_transform_preserves_percent_d_specifier() -> void:
	# %d must survive verbatim — accenting the 'd' would corrupt the specifier
	# and crash the later `str % args` in UIFramework.format_localized.
	var result: String = LocaleLoaderScript.pseudo_transform("Gold: %d")
	assert_str(result).contains("%d")


func test_pseudo_transform_preserves_percent_s_specifier() -> void:
	var result: String = LocaleLoaderScript.pseudo_transform("Hello %s")
	assert_str(result).contains("%s")


func test_pseudo_transform_preserves_escaped_percent() -> void:
	var result: String = LocaleLoaderScript.pseudo_transform("100 %% done")
	assert_str(result).contains("%%")


func test_pseudo_transform_preserves_float_specifier() -> void:
	# guild_hall.gd uses "×%.2f" for the prestige multiplier; the %.2f token
	# must pass through so format_localized's `% value` stays valid.
	var result: String = LocaleLoaderScript.pseudo_transform("×%.2f")
	assert_str(result).contains("%.2f")


func test_pseudo_transform_preserves_bbcode_tag_run() -> void:
	# RichText markup must keep working under the pseudolocale.
	var result: String = LocaleLoaderScript.pseudo_transform("[b]Boss[/b]")
	assert_str(result).contains("[b]")
	assert_str(result).contains("[/b]")


func test_pseudo_transform_pads_to_surface_expansion() -> void:
	# Result is longer than the source so layouts that cannot absorb German-
	# scale (~40%) expansion overflow visibly.
	var source: String = "Send your guild to:"
	var result: String = LocaleLoaderScript.pseudo_transform(source)
	assert_int(result.length()).is_greater(source.length())


func test_pseudo_transform_handles_empty_string() -> void:
	var result: String = LocaleLoaderScript.pseudo_transform("")
	assert_str(result).is_equal(
		LocaleLoaderScript.PSEUDO_BRACKET_OPEN + LocaleLoaderScript.PSEUDO_BRACKET_CLOSE
	)


# ===========================================================================
# Group B — build_pseudolocale (pure; registers nothing)
# ===========================================================================

func test_build_pseudolocale_sets_en_xa_locale() -> void:
	var pseudo: Translation = LocaleLoaderScript.build_pseudolocale({"greeting": "Hello"})
	assert_str(pseudo.locale).is_equal(LocaleLoaderScript.PSEUDO_LOCALE)


func test_build_pseudolocale_transforms_every_value() -> void:
	var pseudo: Translation = LocaleLoaderScript.build_pseudolocale({"greeting": "Hello"})
	var translated: String = String(pseudo.get_message(&"greeting"))
	assert_str(translated).is_not_equal("Hello")
	assert_str(translated).starts_with(LocaleLoaderScript.PSEUDO_BRACKET_OPEN)


func test_build_pseudolocale_maps_all_keys() -> void:
	var pseudo: Translation = LocaleLoaderScript.build_pseudolocale(
		{"greeting": "Hello", "farewell": "Bye"}
	)
	# Both keys were added, so each resolves to a transformed (non-source) value.
	assert_str(String(pseudo.get_message(&"greeting"))).is_not_equal("Hello")
	assert_str(String(pseudo.get_message(&"farewell"))).is_not_equal("Bye")


# ===========================================================================
# Group C — never ships by default (safety property)
# ===========================================================================

func test_pseudolocale_absent_from_loaded_locales_on_normal_boot() -> void:
	# The live LocaleLoader autoload booted WITHOUT LANTERN_PSEUDOLOCALE=1 (the
	# test runner sets no such env var), so en_XA must not be registered. This
	# is the guard that keeps the pseudolocale out of player builds.
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	assert_bool(loaded.has(LocaleLoaderScript.PSEUDO_LOCALE)).override_failure_message(
		"en_XA leaked into a normal boot: get_loaded_locales() = %s" % str(loaded)
	).is_false()


func test_pseudolocale_disabled_by_default_on_fresh_instance() -> void:
	# A freshly constructed loader (not added to the tree, so _ready has not
	# run) defaults to disabled — synthesis is strictly opt-in.
	var loader: Node = auto_free(LocaleLoaderScript.new())
	assert_bool(loader.pseudolocale_enabled).is_false()
