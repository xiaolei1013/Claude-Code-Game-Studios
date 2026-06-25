# GdUnit4 test suite — German (de) locale column in assets/locale/en.csv.
#
# ADR-0026 decisions exercised here:
#   - D-a: German ships as a `de` COLUMN in en.csv (not a separate file), so the
#     generic per-column loader registers it with no loader code change.
#   - D-e: there is NO per-key de→en fallback. An empty de cell renders blank to
#     the player, so EVERY key must carry a non-empty de value.
#   - D-c: German is best-effort, needs-native-review. Therefore this suite
#     asserts STRUCTURE (coverage + format-specifier parity), never exact German
#     wording — a native reviewer must be free to refine the text without
#     breaking CI.
#
# The load-bearing test is the format-specifier parity check. GDScript's `%`
# operator is positional and FATALLY aborts when a format string's specifiers
# don't match the supplied args (see the project's %-format gotcha). If a de
# translation drops, adds, or reorders a %s/%d/%.2f relative to en, then under
# locale=de a `format_str % args` call mis-formats or hard-crashes at runtime.
# This suite catches that at CI time instead of in a German player's session.
extends GdUnitTestSuite

const CSV_PATH: String = "res://assets/locale/en.csv"

# Matches a printf-style conversion specifier OR a literal "%%" escape.
# Flag class is [-+0#] WITHOUT space: a space after "%" (as in the literal
# "+25% gold" synergy strings) must NOT be read as a space-flag specifier, or
# en "% gold" vs de "% Gold" would diverge ("%g" vs "%G") and fail parity
# spuriously. Real format strings use only bare %s / %d / %.2f.
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

func test_locale_de_specifier_extractor_recognizes_real_and_literal_percent() -> void:
	# Real specifiers are found, in order.
	assert_array(_format_specifiers("%s reached level %d!")).is_equal(["%s", "%d"])
	# Precision specifiers (the prestige multiplier ×%.2f) are matched whole.
	assert_array(_format_specifiers("×%.2f")).is_equal(["%.2f"])
	# Literal "% word" (synergy effect strings) is NOT a specifier — even when
	# the following word starts with a conversion letter (g/G/X...).
	assert_array(_format_specifiers("+25% gold vs bruisers")).is_equal([])
	assert_array(_format_specifiers("+25% Gold gegen Schläger")).is_equal([])
	# "%%" escape is recognized as the literal-percent token.
	assert_array(_format_specifiers("100%% done")).is_equal(["%%"])


# ===========================================================================
# Group B — CSV structure + boot registration (ADR-0026 D-a)
# ===========================================================================

func test_locale_de_column_present_in_en_csv_header() -> void:
	var rows: Array = _load_csv_rows()
	assert_int(rows.size()).override_failure_message(
		"en.csv parsed empty or header-only at %s" % CSV_PATH
	).is_greater(1)
	var header: PackedStringArray = rows[0]
	assert_int(_col_index(header, "de")).override_failure_message(
		"en.csv header = %s; expected a 'de' column (ADR-0026 D-a)" % str(header)
	).is_greater_equal(0)


func test_locale_de_registered_in_translation_server_loaded_locales() -> void:
	# The generic per-column loader builds one Translation per header column at
	# boot, so the de column must surface in get_loaded_locales() with no loader
	# change — this is what lights up the Settings locale dropdown (>=2 locales).
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	assert_bool(loaded.has("de")).override_failure_message(
		"get_loaded_locales() = %s; expected 'de' after LocaleLoader boot (ADR-0026 D-a)" % str(loaded)
	).is_true()


# ===========================================================================
# Group C — Coverage (ADR-0026 D-e: no de→en fallback → every cell non-empty)
# ===========================================================================

func test_locale_de_every_key_has_nonempty_value() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var di: int = _col_index(header, "de")
	assert_int(ki).is_greater_equal(0)
	assert_int(di).is_greater_equal(0)
	var missing: Array[String] = []
	for r in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		var blank: bool = di >= row.size() or row[di] == ""
		if blank:
			missing.append(row[ki] if ki < row.size() else "<row %d>" % r)
	assert_int(missing.size()).override_failure_message(
		"ADR-0026 D-e: no per-key de->en fallback, so every key needs a non-empty de cell. Missing: %s" % str(missing)
	).is_equal(0)


# ===========================================================================
# Group D — de is genuinely translated across the column, not an en copy
# ===========================================================================

func test_locale_de_column_is_genuinely_translated_not_en_copy() -> void:
	# Whole-column guard against a de column left as an en copy (a generator bug,
	# or a partial / forgotten translation). MOST rows must differ from en. Exact
	# German wording is intentionally NOT pinned: German is best-effort
	# needs-native-review (ADR-0026 D-c) and a reviewer may reword freely — that
	# only ever increases divergence, so this floor survives it.
	#
	# A minority of cells legitimately equal en — brand ("Lantern Guild"),
	# German-identical cognates ("Bronze"/"Gold"/"Audio"), and symbol/format-only
	# values ("×%.2f", "%d dB", "-INF"). The real ratio is ~0.92, so a 0.6 floor
	# sits well above a wholesale copy (0.0) or a half-translated column (≤0.5)
	# yet clears the legitimate-identical minority with wide margin.
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var ei: int = _col_index(header, "en")
	var di: int = _col_index(header, "de")
	var total: int = 0
	var differ: int = 0
	var dispatch_differs: bool = false
	for r in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		if ei >= row.size() or di >= row.size():
			continue
		total += 1
		if row[di] != row[ei]:
			differ += 1
		if ki < row.size() and row[ki] == "dispatch_button":
			dispatch_differs = row[di] != row[ei]
	assert_int(total).is_greater(0)
	# differ/total >= 0.6  <=>  differ*5 >= total*3 (integer math, no float assert).
	assert_int(differ * 5).override_failure_message(
		"de differs from en in only %d/%d rows; expected >= 60%%. A near-en-identical de column means it was copied, not translated." % [differ, total]
	).is_greater_equal(total * 3)
	# Concrete anchor: a core prose button must be among the translated rows
	# (also proves key lookup + the differ check work on a known row).
	assert_bool(dispatch_differs).override_failure_message(
		"dispatch_button de must differ from en (plain prose: en 'Dispatch' -> de 'Entsenden')"
	).is_true()


# ===========================================================================
# Group E — Format-specifier parity (the %-fatal safety net)
# ===========================================================================

func test_locale_de_format_specifier_parity_with_en() -> void:
	var rows: Array = _load_csv_rows()
	var header: PackedStringArray = rows[0]
	var ki: int = _col_index(header, "keys")
	var ei: int = _col_index(header, "en")
	var di: int = _col_index(header, "de")
	assert_int(ki).is_greater_equal(0)
	assert_int(ei).is_greater_equal(0)
	assert_int(di).is_greater_equal(0)
	var offenders: Array[String] = []
	for r in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		if ei >= row.size() or di >= row.size():
			continue
		# GDScript `%` is positional, so the ORDERED specifier list must match.
		var en_specs: Array[String] = _format_specifiers(row[ei])
		var de_specs: Array[String] = _format_specifiers(row[di])
		if en_specs != de_specs:
			offenders.append("%s: en=%s de=%s" % [row[ki], str(en_specs), str(de_specs)])
	assert_int(offenders.size()).override_failure_message(
		"Format-specifier parity failed: a de string dropped/added/reordered a %%-specifier vs en, so `str %% args` would mis-format or fatally abort under locale=de. Offenders: %s" % str(offenders)
	).is_equal(0)
