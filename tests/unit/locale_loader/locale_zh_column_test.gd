# GdUnit4 test suite — Simplified Chinese (zh_CN) locale column in assets/locale/en.csv.
#
# ADR-0026 (localization) + ADR-0027 (CJK font identity) decisions exercised here:
#   - D-a: zh_CN ships as a `zh_CN` COLUMN in en.csv (not a separate file), so the
#     generic per-column loader registers it with no loader code change — exactly
#     as the `de` column does (see locale_de_column_test.gd).
#   - D-e: there is NO per-key zh->en fallback. An empty zh cell renders blank to
#     the player, so EVERY key must carry a non-empty zh_CN value.
#   - D-c: translations are best-effort, needs-native-review. This suite asserts
#     STRUCTURE (coverage + format-specifier parity), never exact wording — a
#     native reviewer must be free to refine the Chinese without breaking CI.
#
# This suite is the CJK twin of locale_de_column_test.gd. The load-bearing test is
# the format-specifier parity check: GDScript's `%` operator is positional and
# FATALLY aborts when a format string's specifiers don't match the supplied args
# (the project's %-format gotcha). If a zh translation drops, adds, or reorders a
# %s/%d/%.2f relative to en, then under locale=zh_CN a `format_str % args` call
# mis-formats or hard-crashes. This catches that at CI time, not in a player's
# session. (Font coverage — that the glyphs actually render rather than tofu — is
# guarded deterministically by tests/integration/theme/parchment_theme_cjk_font_test.gd;
# this suite owns CSV structure + %-parity.)
#
# REUSE / Rule-of-Three: this suite is an intentional near-twin of
# locale_de_column_test.gd (shared helpers _load_csv_rows / _col_index /
# _format_specifiers + the five Group A-E shapes). At N=2 locales the duplication
# is the project's documented idiom — cf. tests/helpers/class_registration_test_helper.gd,
# which was factored only at N=3. When a 3rd locale lands, hoist the shared parts
# into a STATIC helper `tests/helpers/locale_csv_test_helper.gd` (not a base class:
# a GdUnitTestSuite subclass defining test_* would be discovered and run as its own
# locale-less, vacuously-failing suite).
extends GdUnitTestSuite

const CSV_PATH: String = "res://assets/locale/en.csv"
const LOCALE_CODE: String = "zh_CN"

# Matches a printf-style conversion specifier OR a literal "%%" escape. Flag class
# is [-+0#] WITHOUT space, so a literal "% " (as in "+25% gold" / "+5% more") is
# NOT read as a space-flag specifier. Identical to the de suite's pattern.
const SPEC_PATTERN: String = "%%|%[-+0#]*[0-9]*(\\.[0-9]+)?[sdcoxXeEfgGv]"

var _spec_re: RegEx = null


# --- helpers ---------------------------------------------------------------

# Parses en.csv via Godot's RFC-4180 CSV reader (the same FileAccess.get_csv_line
# path the loader uses), so quoted fields with embedded commas resolve to single
# columns. Returns rows as Array[PackedStringArray]; row 0 is the header.
func _load_csv_rows() -> Array:
	var rows: Array = []
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return rows
	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		# A trailing newline yields a lone empty field — skip it.
		if line.size() == 1 and line[0] == "":
			continue
		rows.append(line)
	f.close()
	return rows


func _col_index(header: PackedStringArray, name: String) -> int:
	for i in header.size():
		if header[i] == name:
			return i
	return -1


# Ordered list of printf specifiers in `text` ("%%" escapes included).
func _format_specifiers(text: String) -> Array[String]:
	if _spec_re == null:
		_spec_re = RegEx.new()
		_spec_re.compile(SPEC_PATTERN)
	var out: Array[String] = []
	for m in _spec_re.search_all(text):
		out.append(m.get_string())
	return out


# ===========================================================================
# Group A — Extractor self-check (keeps the parity test from passing vacuously)
# ===========================================================================

func test_locale_zh_specifier_extractor_recognizes_real_and_literal_percent() -> void:
	# Real specifiers are found, in order.
	assert_array(_format_specifiers("%s reached level %d!")).is_equal(["%s", "%d"])
	# Precision specifiers (the prestige multiplier ×%.2f) are matched whole.
	assert_array(_format_specifiers("×%.2f")).is_equal(["%.2f"])
	# Literal "% word" (synergy effect strings) is NOT a specifier — even when the
	# following character is a CJK glyph or a space.
	assert_array(_format_specifiers("对斗士 +25% 金币")).is_equal([])
	assert_array(_format_specifiers("+25% gold vs bruisers")).is_equal([])
	# "%%" escape is recognized as the literal-percent token.
	assert_array(_format_specifiers("100%% done")).is_equal(["%%"])


# ===========================================================================
# Group B — CSV structure + boot registration (ADR-0026 D-a)
# ===========================================================================

func test_locale_zh_column_present_in_en_csv_header() -> void:
	var rows: Array = _load_csv_rows()
	assert_int(rows.size()).override_failure_message(
		"en.csv parsed empty or header-only at %s" % CSV_PATH
	).is_greater(1)
	var header: PackedStringArray = rows[0]
	assert_int(_col_index(header, LOCALE_CODE)).override_failure_message(
		"en.csv header = %s; expected a '%s' column (ADR-0026 D-a / ADR-0027)" % [str(header), LOCALE_CODE]
	).is_greater_equal(0)


func test_locale_zh_registered_in_translation_server_loaded_locales() -> void:
	# The generic per-column loader builds one Translation per header column at
	# boot, so the zh_CN column must surface in get_loaded_locales() with no loader
	# change — this is what lights up the Settings locale dropdown as a third locale.
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	assert_bool(loaded.has(LOCALE_CODE)).override_failure_message(
		"get_loaded_locales() = %s; expected '%s' after LocaleLoader boot (ADR-0026 D-a)" % [str(loaded), LOCALE_CODE]
	).is_true()


# ===========================================================================
# Group C — Coverage (ADR-0026 D-e: no zh->en fallback → every cell non-empty)
# ===========================================================================

func test_locale_zh_every_key_has_nonempty_value() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var zi: int = _col_index(header, LOCALE_CODE)
	assert_int(ki).is_greater_equal(0)
	assert_int(zi).is_greater_equal(0)
	var missing: Array[String] = []
	for r in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		var blank: bool = zi >= row.size() or row[zi] == ""
		if blank:
			missing.append(row[ki] if ki < row.size() else "<row %d>" % r)
	assert_int(missing.size()).override_failure_message(
		"ADR-0026 D-e: no per-key zh->en fallback, so every key needs a non-empty zh_CN cell. Missing: %s" % str(missing)
	).is_equal(0)


# ===========================================================================
# Group D — zh is genuinely translated across the column, not an en copy
# ===========================================================================

func test_locale_zh_column_is_genuinely_translated_not_en_copy() -> void:
	# Whole-column guard against a zh column left as an en copy (a generator bug or
	# a forgotten translation). MOST rows must differ from en. Exact wording is NOT
	# pinned: zh is best-effort needs-native-review (ADR-0026 D-c) and a reviewer
	# may reword freely — that only ever increases divergence, so this floor holds.
	#
	# A small minority of cells legitimately equal en — brand ("Lantern Guild") and
	# symbol/format-only values ("×%.2f", "%d dB", "-INF"). zh's real divergence is
	# ~0.98 (only 4/181 identical), so the 0.6 floor (shared with the de suite)
	# clears that minority with very wide margin while still failing a wholesale
	# copy (0.0) or a half-translated column (<=0.5).
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var ei: int = _col_index(header, "en")
	var zi: int = _col_index(header, LOCALE_CODE)
	var total: int = 0
	var differ: int = 0
	var dispatch_differs: bool = false
	for r in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		if ei >= row.size() or zi >= row.size():
			continue
		total += 1
		if row[zi] != row[ei]:
			differ += 1
		if ki < row.size() and row[ki] == "dispatch_button":
			dispatch_differs = row[zi] != row[ei]
	assert_int(total).is_greater(0)
	# differ/total >= 0.6  <=>  differ*5 >= total*3 (integer math, no float assert).
	assert_int(differ * 5).override_failure_message(
		"zh differs from en in only %d/%d rows; expected >= 60%%. A near-en-identical zh column means it was copied, not translated." % [differ, total]
	).is_greater_equal(total * 3)
	# Concrete anchor: a core prose button must be among the translated rows (also
	# proves key lookup + the differ check work on a known row).
	assert_bool(dispatch_differs).override_failure_message(
		"dispatch_button zh must differ from en (plain prose: en 'Dispatch' -> zh '派遣')"
	).is_true()


# ===========================================================================
# Group E — Format-specifier parity (the %-fatal safety net)
# ===========================================================================

func test_locale_zh_format_specifier_parity_with_en() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var ei: int = _col_index(header, "en")
	var zi: int = _col_index(header, LOCALE_CODE)
	assert_int(ki).is_greater_equal(0)
	assert_int(ei).is_greater_equal(0)
	assert_int(zi).is_greater_equal(0)
	var offenders: Array[String] = []
	for r in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		if ei >= row.size() or zi >= row.size():
			continue
		# GDScript `%` is positional, so the ORDERED specifier list must match.
		var en_specs: Array[String] = _format_specifiers(row[ei])
		var zh_specs: Array[String] = _format_specifiers(row[zi])
		if en_specs != zh_specs:
			offenders.append("%s: en=%s zh=%s" % [row[ki], str(en_specs), str(zh_specs)])
	assert_int(offenders.size()).override_failure_message(
		"Format-specifier parity failed: a zh string dropped/added/reordered a %%-specifier vs en, so `str %% args` would mis-format or fatally abort under locale=zh_CN. Offenders: %s" % str(offenders)
	).is_equal(0)
