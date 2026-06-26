# GdUnit4 — the parchment theme's default font must render CJK (no tofu) for zh_CN.
#
# ADR-0027: zh_CN ships by setting the theme's default_font to Noto Sans CJK SC.
# This is the deterministic "no tofu boxes" guard — it loads the live theme
# resource and asserts its default face actually carries the CJK glyphs the
# zh_CN column uses, complementing the human screenshot check. If someone removes
# default_font or swaps in a Latin-only face, Chinese would silently render as
# boxes (□); this fails CI instead of shipping it to a Chinese player.
extends GdUnitTestSuite

const THEME_PATH: String = "res://assets/ui/parchment_theme.tres"
const CSV_PATH: String = "res://assets/locale/en.csv"
const LOCALE_CODE: String = "zh_CN"

# CJK Unified Ideographs block. The coverage test derives its glyph set from the
# LIVE zh_CN column filtered to this range, so it tracks the shipped translations
# (and any native-reviewer rewording) rather than a hard-coded specimen. Emoji
# (e.g. 🔒), full-width punctuation, and Latin are deliberately excluded: they
# render via the same fallback path for en/de and are not the CJK "tofu" risk this
# suite owns (Noto Sans CJK does not even contain emoji — asserting it would false-fail).
const CJK_IDEOGRAPH_LO: int = 0x4E00
const CJK_IDEOGRAPH_HI: int = 0x9FFF


func test_parchment_theme_defines_a_default_font() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_object(theme).override_failure_message(
		"parchment_theme.tres failed to load as a Theme at %s" % THEME_PATH
	).is_not_null()
	assert_object(theme.default_font).override_failure_message(
		"parchment_theme.tres has no default_font — zh_CN (and all text) would fall back to the engine Latin-only font (ADR-0027)."
	).is_not_null()


# Every CJK ideograph that actually appears in the live zh_CN column. Reading the
# column here (rather than reusing the sibling locale suite's full row-parser) keeps
# the guard self-contained and purpose-specific — it needs codepoints, not rows.
func _zh_cn_ideographs() -> PackedInt32Array:
	var seen: Dictionary = {}
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return PackedInt32Array()
	var header: PackedStringArray = f.get_csv_line()
	var zi: int = header.find(LOCALE_CODE)
	if zi != -1:
		while not f.eof_reached():
			var row: PackedStringArray = f.get_csv_line()
			if zi >= row.size():
				continue
			var value: String = row[zi]
			for i in value.length():
				var cp: int = value.unicode_at(i)
				if cp >= CJK_IDEOGRAPH_LO and cp <= CJK_IDEOGRAPH_HI:
					seen[cp] = true
	f.close()
	var out: PackedInt32Array = PackedInt32Array()
	for cp: int in seen:
		out.append(cp)
	return out


func test_parchment_default_font_covers_every_zh_cn_ideograph() -> void:
	# The real "no tofu" invariant: every Chinese character a zh_CN player will see
	# must exist in the default face. Derived from the live column, so it never drifts
	# from the shipped translations (ADR-0027).
	var theme: Theme = load(THEME_PATH) as Theme
	var font: Font = theme.default_font
	assert_object(font).is_not_null()
	var glyphs: PackedInt32Array = _zh_cn_ideographs()
	assert_int(glyphs.size()).override_failure_message(
		"found no CJK ideographs in the %s column of %s — cannot verify coverage" % [LOCALE_CODE, CSV_PATH]
	).is_greater(0)
	var missing: Array[String] = []
	for cp in glyphs:
		if not font.has_char(cp):
			missing.append(char(cp))
	assert_int(missing.size()).override_failure_message(
		"default_font is missing %d CJK glyph(s) used by zh_CN: %s — these would render as tofu (ADR-0027)." % [missing.size(), str(missing)]
	).is_equal(0)


func test_parchment_default_font_still_covers_latin() -> void:
	# The CJK font must not have cost Latin coverage. Noto Sans CJK SC includes
	# Latin (its glyphs are the prior engine default's Noto Sans design), so en/de
	# and all UI chrome keep rendering.
	var theme: Theme = load(THEME_PATH) as Theme
	var font: Font = theme.default_font
	var latin: String = "Az0"
	for i in latin.length():
		assert_bool(font.has_char(latin.unicode_at(i))).override_failure_message(
			"default_font missing basic Latin glyph '%s' — Latin/UI text would break (ADR-0027)." % latin[i]
		).is_true()
