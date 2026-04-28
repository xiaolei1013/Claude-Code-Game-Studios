extends Node

## LocaleLoader — Foundation autoload that loads locale CSVs at boot and
## registers their messages with [TranslationServer].
##
## Sprint 9 S9-M2/M3 polish: previously [code]tr("foo")[/code] returned the
## raw key string because no Translation resource was registered. This
## autoload reads [code]res://assets/locale/[locale].csv[/code] for each
## supported locale and constructs in-memory [Translation] resources
## programmatically — no Godot editor import step required, no
## [code].translation[/code] artefacts on disk.
##
## CSV format (UTF-8, header row required):
##   keys,en[,fr,...]
##   key1,"Translation 1","Traduction 1"
##   key2,Translation 2,Traduction 2
##
## - First column is the message key (snake_case_lookup_string).
## - Subsequent columns are locale codes; one [Translation] is built per column.
## - Quoted fields are unwrapped; embedded commas inside quotes are preserved.
## - Empty cells are skipped (no message added for that locale's key).
##
## Why programmatic loading vs Godot's CSV import?
## - Headless agents and CI environments do not have an editor pass to
##   regenerate [code].translation[/code] artefacts when the CSV changes.
## - Programmatic loading reads the source CSV directly at boot; the CSV is
##   authoritative.
## - Designers and translators can still edit the CSV in any editor; no
##   round-trip through the Godot editor is required.
##
## Registered AFTER [code]RuntimeLocaleGuard[/code] but BEFORE [code]TickSystem[/code]
## in [code]project.godot[/code] so that [code]tr()[/code] returns translated
## strings for any subsequent autoload's [code]_ready()[/code] log messages or
## screen-level UI initialisation.
##
## Sprint 9 S9-M3 (locale CSV authoring) — sprint-9.md S9-M3 row.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Path to the locale source directory. All [code]*.csv[/code] files matching
## the project's expected locale set are loaded at boot.
const LOCALE_DIR_PATH: String = "res://assets/locale"

## Default locale used at boot. Changed via
## [method TranslationServer.set_locale] elsewhere if the player picks a
## different language at runtime.
const DEFAULT_LOCALE: String = "en"

## Supported locale CSV filenames. Add a new locale here when its CSV exists
## under [code]assets/locale/[/code]. Explicit list (not directory glob) keeps
## the loader deterministic and avoids accidental load of stray files.
##
## Declared as [code]Array[String][/code] (not [PackedStringArray]) because
## GDScript [code]const[/code] expressions cannot call constructors —
## [code]PackedStringArray([...])[/code] is a constructor invocation.
const SUPPORTED_LOCALE_FILES: Array[String] = [
	"en.csv",
]


# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

## Loads each supported locale CSV and registers a [Translation] per locale
## column. Sets [member TranslationServer.locale] to [const DEFAULT_LOCALE]
## after registration so [code]tr()[/code] resolves to the default language.
##
## Idempotent within a single boot: [code]_ready[/code] is invoked exactly
## once per autoload by the Godot runtime.
func _ready() -> void:
	for filename in SUPPORTED_LOCALE_FILES:
		var path: String = LOCALE_DIR_PATH + "/" + filename
		_load_csv_file(path)
	TranslationServer.set_locale(DEFAULT_LOCALE)


# ---------------------------------------------------------------------------
# CSV loading
# ---------------------------------------------------------------------------

## Reads a single locale CSV file at [param path] and registers one
## [Translation] resource per locale column found in the header row.
##
## The CSV is parsed with [method FileAccess.get_csv_line] which handles
## RFC-4180-style quoting. The first column is treated as the message key
## (untranslated); each subsequent column is a separate locale.
##
## On any read or format error, emits [method push_warning] and returns
## without registering anything for that file (other locale files continue
## to load).
func _load_csv_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err: int = FileAccess.get_open_error()
		push_warning("[LocaleLoader] Could not open %s (err=%d) — skipping." % [path, err])
		return

	# Header — first row defines the locale columns.
	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2:
		push_warning("[LocaleLoader] %s missing locale columns (need 'keys,<locale>'+) — skipping." % path)
		file.close()
		return
	if header[0] != "keys":
		push_warning("[LocaleLoader] %s first column should be 'keys' (got '%s') — skipping." % [path, header[0]])
		file.close()
		return

	# Build one Translation per locale column.
	var translations: Array[Translation] = []
	for i in range(1, header.size()):
		var t: Translation = Translation.new()
		t.locale = header[i]
		translations.append(t)

	# Body — each row is "key,en_value[,fr_value,...]".
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0] == ""):
			continue  # blank line — skip
		if row.size() < 2:
			push_warning("[LocaleLoader] %s row missing values: %s — skipping." % [path, str(row)])
			continue
		var key: String = row[0]
		if key == "":
			continue
		for i in range(1, row.size()):
			if i - 1 >= translations.size():
				break  # row has more columns than header — ignore extras
			var value: String = row[i]
			if value == "":
				continue  # blank cell — leave key untranslated for this locale
			translations[i - 1].add_message(key, value)

	file.close()

	# Register all built translations with the global TranslationServer.
	for t in translations:
		TranslationServer.add_translation(t)
