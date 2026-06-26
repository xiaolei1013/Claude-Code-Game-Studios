# GdUnit4 — the parchment theme's default font must render EVERY shipped locale's
# glyphs (no tofu). Covers all non-ASCII scripts present in en.csv: CJK ideographs +
# Kana + Hangul (zh_CN / zh_TW / ja / ko), Cyrillic (ru), and accented Latin
# (fr / es / es_MX / pt_PT / pt_BR / de). This is the deterministic "no tofu boxes"
# guard — it loads the live theme and asserts its default face carries the glyphs the
# locale columns actually use, complementing the human eyeball check. If someone
# removes default_font or swaps in a Latin-only face, non-Latin locales would silently
# render as boxes (□); this fails CI instead.
#
# ADR-0027 (Noto Sans CJK SC as default_font) + ADR-0028 (the 12-locale set, all on
# that single face). File name is historical (was zh_CN-only); it now guards all locales.
extends GdUnitTestSuite

const THEME_PATH: String = "res://assets/ui/parchment_theme.tres"
const CSV_PATH: String = "res://assets/locale/en.csv"

# Unicode ranges for the scripts that would render as tofu on a Latin-ASCII-only font
# — the actual coverage risk. Glyphs are derived per-locale from the LIVE columns, so
# the guard tracks shipped text and any native-reviewer rewording. Includes CJK symbols
# & full-width punctuation (。、：！（） — CJK-exclusive; en/de never use them, so the
# default font must carry them directly, not via a shared fallback). Deliberately
# EXCLUDES only emoji (e.g. 🔒 — also present in en, and absent from Noto Sans CJK, so
# asserting it would false-fail) and plain ASCII.
const SCRIPT_RANGES: Array = [
	[0x00C0, 0x024F],  # Latin-1 Supplement + Latin Extended-A/B (é ñ ç ã ü à ...)
	[0x0400, 0x04FF],  # Cyrillic (ru)
	[0x3000, 0x303F],  # CJK Symbols & Punctuation (。 、 「 」 …)
	[0x3040, 0x30FF],  # Hiragana + Katakana (ja)
	[0x3400, 0x4DBF],  # CJK Unified Ideographs Extension A
	[0x4E00, 0x9FFF],  # CJK Unified Ideographs (zh_CN / zh_TW / ja kanji / ko hanja)
	[0xAC00, 0xD7A3],  # Hangul syllables (ko)
	[0xFF00, 0xFFEF],  # Halfwidth/Fullwidth Forms (： ！ （ ） full-width digits)
]


func _in_script_range(cp: int) -> bool:
	for pair in SCRIPT_RANGES:
		if cp >= pair[0] and cp <= pair[1]:
			return true
	return false


# Every in-script-range glyph that actually appears across ALL translated locale
# columns (header minus `keys`/`en`) of the live en.csv. Self-contained read — it
# needs codepoints, not the locale suite's parsed rows.
func _shipped_script_glyphs() -> PackedInt32Array:
	var seen: Dictionary = {}
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return PackedInt32Array()
	var header: PackedStringArray = f.get_csv_line()
	var cols: Array[int] = []
	for i in header.size():
		if header[i] != "keys" and header[i] != "en":
			cols.append(i)
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		for ci in cols:
			if ci >= row.size():
				continue
			var value: String = row[ci]
			for i in value.length():
				var cp: int = value.unicode_at(i)
				if _in_script_range(cp):
					seen[cp] = true
	f.close()
	var out: PackedInt32Array = PackedInt32Array()
	for cp: int in seen:
		out.append(cp)
	return out


func test_parchment_theme_defines_a_default_font() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_object(theme).override_failure_message(
		"parchment_theme.tres failed to load as a Theme at %s" % THEME_PATH
	).is_not_null()
	assert_object(theme.default_font).override_failure_message(
		"parchment_theme.tres has no default_font — non-Latin locales would fall back to a Latin-only font (ADR-0027/0028)."
	).is_not_null()


func test_parchment_default_font_covers_every_shipped_locale_glyph() -> void:
	# The real "no tofu" invariant across all locales: every CJK / Kana / Hangul /
	# Cyrillic / accented-Latin glyph a player will see must exist in the default face.
	# Derived from the live columns, so it never drifts from the shipped translations.
	var theme: Theme = load(THEME_PATH) as Theme
	var font: Font = theme.default_font
	assert_object(font).is_not_null()
	var glyphs: PackedInt32Array = _shipped_script_glyphs()
	assert_int(glyphs.size()).override_failure_message(
		"found no in-script-range glyphs across the locale columns of %s — cannot verify coverage" % CSV_PATH
	).is_greater(0)
	var missing: Array[String] = []
	for cp in glyphs:
		if not font.has_char(cp):
			missing.append(char(cp))
	assert_int(missing.size()).override_failure_message(
		"default_font is missing %d shipped-locale glyph(s): %s — these would render as tofu (ADR-0028)." % [missing.size(), str(missing)]
	).is_equal(0)


func test_parchment_default_font_still_covers_latin() -> void:
	# The CJK font must not have cost basic Latin coverage (Noto Sans CJK SC includes
	# Latin — its glyphs are the engine default's Noto Sans design), so en + the
	# Latin-script locales and all UI chrome keep rendering.
	var theme: Theme = load(THEME_PATH) as Theme
	var font: Font = theme.default_font
	var latin: String = "Az0"
	for i in latin.length():
		assert_bool(font.has_char(latin.unicode_at(i))).override_failure_message(
			"default_font missing basic Latin glyph '%s' — Latin/UI text would break." % latin[i]
		).is_true()
