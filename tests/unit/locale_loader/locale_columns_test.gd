# GdUnit4 — structural battery over EVERY translated locale column in en.csv.
#
# Supersedes the per-locale twins (locale_de_column_test.gd + locale_zh_column_test.gd):
# at 12 locales the Rule-of-Three has fired (cf. tests/helpers/class_registration_test_helper.gd).
# This suite AUTO-DISCOVERS the locale columns from the header (everything except
# `keys` and `en`) and runs the battery on each, so adding a CSV column needs almost
# no new test code — mirroring the loader's own generality (LocaleLoader builds one
# Translation per column). The ONE per-locale bookkeeping is EXPECTED_TRANSLATED_LOCALES
# below, which pins the shipped set so a silently-dropped column fails CI.
#
# ADR-0026 decisions exercised: D-a (locales ship as en.csv COLUMNS, registered by the
# generic per-column loader), D-e (no per-key fallback -> every cell non-empty), D-c
# (translations are best-effort needs-native-review -> assert STRUCTURE, never wording).
# ADR-0028 (the full 12-locale set + single SC font + es_MX-not-es_419).
#
# The load-bearing test is %-specifier parity. GDScript's `%` is positional; when a
# format string's specifiers don't match the args, Godot 4.6's runtime path (tr()-loaded
# strings) renders the RAW format string and logs a "String formatting error" — the
# player sees a literal `%s`/`%d`, not a crash (the fatal abort is the parse-time
# const-folded path, which tr() strings never hit). Garbled localized UI is still a real
# defect, so parity stays a blocking gate; this catches it at CI time for ALL locales.
extends GdUnitTestSuite

const CSV_PATH: String = "res://assets/locale/en.csv"

# The shipped translated locales (everything except `keys`/`en`). Pinned so a dropped,
# renamed, or typo'd column fails CI — the auto-discovery battery alone would silently
# iterate fewer columns. Adding a locale = add its code here (the only per-locale edit).
# NB: Latin American Spanish is es_MX, NOT es_419 — Godot 4.6 standardizes es_419 -> es
# (ADR-0028 Decision 2).
const EXPECTED_TRANSLATED_LOCALES: Array = [
	"de", "zh_CN", "fr", "zh_TW", "ja", "ko", "es", "es_MX", "pt_PT", "pt_BR", "ru",
]

# Regional variant pairs that MUST stay distinct columns (ADR-0028 Decision 2). A
# future edit collapsing one onto the other (e.g. es_MX back to es) is caught here.
const SIBLING_PAIRS: Array = [["es", "es_MX"], ["pt_PT", "pt_BR"], ["zh_CN", "zh_TW"]]

# A printf conversion OR a literal "%%". Flag class [-+0#] WITHOUT space so a literal
# "% " (e.g. "+25% gold") is not read as a specifier.
const SPEC_PATTERN: String = "%%|%[-+0#]*[0-9]*(\\.[0-9]+)?[sdcoxXeEfgGv]"

# Below this en-divergence ratio a column reads as an en copy, not a translation.
# Real ratios are ~0.9-1.0 (only brand/symbol/format cells legitimately equal en).
const MIN_TRANSLATED_RATIO_NUM: int = 3
const MIN_TRANSLATED_RATIO_DEN: int = 5

var _spec_re: RegEx = null


# --- helpers ---------------------------------------------------------------

func _load_csv_rows() -> Array:
	var rows: Array = []
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return rows
	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		if line.size() == 1 and line[0] == "":
			continue
		rows.append(line)
	f.close()
	return rows


# Header columns that are translated locales: everything except `keys` and `en`.
# Returns [code, column_index] pairs so callers can index rows directly.
func _translated_locales(header: PackedStringArray) -> Array:
	var out: Array = []
	for i in header.size():
		var code: String = header[i]
		if code != "keys" and code != "en":
			out.append([code, i])
	return out


func _col_index(header: PackedStringArray, name: String) -> int:
	for i in header.size():
		if header[i] == name:
			return i
	return -1


func _format_specifiers(text: String) -> Array[String]:
	if _spec_re == null:
		_spec_re = RegEx.new()
		_spec_re.compile(SPEC_PATTERN)
	var out: Array[String] = []
	for m in _spec_re.search_all(text):
		out.append(m.get_string())
	return out


# ===========================================================================
# Group A — extractor self-check (keeps the parity test from passing vacuously)
# ===========================================================================

func test_specifier_extractor_recognizes_real_and_literal_percent() -> void:
	assert_array(_format_specifiers("%s reached level %d!")).is_equal(["%s", "%d"])
	assert_array(_format_specifiers("×%.2f")).is_equal(["%.2f"])
	# Literal "% word" (synergy effect strings) is NOT a specifier, in any script.
	assert_array(_format_specifiers("+25% gold vs bruisers")).is_equal([])
	assert_array(_format_specifiers("对斗士 +25% 金币")).is_equal([])
	assert_array(_format_specifiers("100%% done")).is_equal(["%%"])


# ===========================================================================
# Group B — discovery + the pinned set + boot registration (ADR-0026 D-a)
# ===========================================================================

func test_expected_translated_locale_set_present() -> void:
	# Pin the shipped set: a dropped/renamed/typo'd column fails here even though the
	# auto-discovery battery below would silently iterate fewer columns and stay green.
	var rows: Array = _load_csv_rows()
	assert_int(rows.size()).override_failure_message("en.csv parsed empty at %s" % CSV_PATH).is_greater(1)
	var discovered: Array[String] = []
	for pair in _translated_locales(rows[0]):
		discovered.append(pair[0])
	discovered.sort()
	var expected: Array = EXPECTED_TRANSLATED_LOCALES.duplicate()
	expected.sort()
	assert_array(discovered).override_failure_message(
		"locale column set drifted: discovered %s vs expected %s (dropped/added/renamed column?)" % [str(discovered), str(expected)]
	).is_equal(expected)


func test_every_translated_locale_column_is_registered_in_translation_server() -> void:
	# The generic per-column loader registers one Translation per header column at boot,
	# so every translated column must surface in get_loaded_locales() with no loader change.
	# (This is what caught es_419 -> es collapsing in Godot 4.6 — see ADR-0028.)
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	var rows: Array = _load_csv_rows()
	var missing: Array[String] = []
	for pair in _translated_locales(rows[0]):
		var code: String = pair[0]
		if not loaded.has(code):
			missing.append(code)
	assert_array(missing).override_failure_message(
		"get_loaded_locales() = %s; these en.csv columns did not register (loader/locale-code issue): %s"
		% [str(loaded), str(missing)]
	).is_empty()


# ===========================================================================
# Group C — coverage: no per-key fallback -> every cell non-empty (ADR-0026 D-e)
# ===========================================================================

func test_every_translated_locale_has_nonempty_value_for_every_key() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var offenders: Array[String] = []
	for pair in _translated_locales(header):
		var code: String = pair[0]
		var ci: int = pair[1]
		for r in range(1, rows.size()):
			var row: PackedStringArray = rows[r]
			if ci >= row.size() or row[ci] == "":
				var key: String = (row[ki] if ki >= 0 and ki < row.size() else "<row %d>" % r)
				offenders.append("%s:%s" % [code, key])
	assert_array(offenders).override_failure_message(
		"ADR-0026 D-e: no per-key fallback, so every locale cell must be non-empty. Empty: %s" % str(offenders)
	).is_empty()


# ===========================================================================
# Group D — each column is genuinely translated, and siblings stay distinct
# ===========================================================================

func test_every_translated_locale_diverges_from_en() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var ei: int = _col_index(header, "en")
	assert_int(ei).is_greater_equal(0)
	var failures: Array[String] = []
	for pair in _translated_locales(header):
		var code: String = pair[0]
		var ci: int = pair[1]
		var total: int = 0
		var differ: int = 0
		var dispatch_differs: bool = false
		for r in range(1, rows.size()):
			var row: PackedStringArray = rows[r]
			if ei >= row.size() or ci >= row.size():
				continue
			total += 1
			if row[ci] != row[ei]:
				differ += 1
			if ki >= 0 and ki < row.size() and row[ki] == "dispatch_button":
				dispatch_differs = row[ci] != row[ei]
		# differ/total >= 3/5, integer math (no float assert).
		if total == 0 or differ * MIN_TRANSLATED_RATIO_DEN < total * MIN_TRANSLATED_RATIO_NUM:
			failures.append("%s diverges in only %d/%d rows (< 60%%) — looks copied, not translated" % [code, differ, total])
		if not dispatch_differs:
			failures.append("%s: dispatch_button must differ from en ('Dispatch')" % code)
	assert_array(failures).override_failure_message(
		"genuine-translation check failed: %s" % str(failures)
	).is_empty()


func test_regional_sibling_variants_are_distinct() -> void:
	# es vs es_MX, pt_PT vs pt_BR, zh_CN vs zh_TW must NOT be identical columns — the
	# whole point of shipping the regional variants (ADR-0028 Decision 2). A future edit
	# collapsing one onto the other (e.g. es_MX back onto es) is caught here.
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var failures: Array[String] = []
	for pair in SIBLING_PAIRS:
		var ai: int = _col_index(header, pair[0])
		var bi: int = _col_index(header, pair[1])
		if ai < 0 or bi < 0:
			failures.append("%s/%s: a sibling column is missing" % [pair[0], pair[1]])
			continue
		var diff: int = 0
		for r in range(1, rows.size()):
			var row: PackedStringArray = rows[r]
			if ai < row.size() and bi < row.size() and row[ai] != row[bi]:
				diff += 1
		if diff == 0:
			failures.append("%s and %s are identical across all rows (a collapsed variant)" % [pair[0], pair[1]])
	assert_array(failures).override_failure_message(
		"regional sibling distinctness failed: %s" % str(failures)
	).is_empty()


# ===========================================================================
# Group E — %-specifier parity vs en (the format-safety net), all locales
# ===========================================================================

func test_every_translated_locale_has_format_specifier_parity_with_en() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var ei: int = _col_index(header, "en")
	assert_int(ei).is_greater_equal(0)
	var offenders: Array[String] = []
	for pair in _translated_locales(header):
		var code: String = pair[0]
		var ci: int = pair[1]
		for r in range(1, rows.size()):
			var row: PackedStringArray = rows[r]
			if ei >= row.size() or ci >= row.size():
				continue
			var en_specs: Array[String] = _format_specifiers(row[ei])
			var loc_specs: Array[String] = _format_specifiers(row[ci])
			if en_specs != loc_specs:
				var key: String = (row[ki] if ki >= 0 and ki < row.size() else "<row %d>" % r)
				offenders.append("%s/%s: en=%s loc=%s" % [code, key, str(en_specs), str(loc_specs)])
	assert_array(offenders).override_failure_message(
		"%%-specifier parity failed (renders the raw format string / garbled UI under that locale): %s" % str(offenders)
	).is_empty()
