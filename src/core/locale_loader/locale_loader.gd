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
# Pseudolocalization (debug / QA only — never shipped to players)
# ---------------------------------------------------------------------------

## Synthetic QA locale code. When pseudolocalization is enabled, a [Translation]
## under this locale is built from the [const DEFAULT_LOCALE] column by running
## every value through [method pseudo_transform]. Switching to it in the
## Settings language menu surfaces two whole classes of i18n bug at a glance:
## [br]- Any string that renders as plain unaccented English was never routed
##   through [code]tr()[/code] / [code]format_localized[/code] (a hardcoded literal).
## [br]- Any clipped closing bracket reveals a layout that cannot fit
##   ~40%-longer text (the German expansion budget DESIGN.md is calibrated for).
const PSEUDO_LOCALE: String = "en_XA"

## Environment variable that gates pseudolocale synthesis. Read once in
## [method _ready]; set [code]LANTERN_PSEUDOLOCALE=1[/code] when launching the
## game for translation-completeness QA. Absent in player builds, so the
## pseudolocale is never registered there. Opt-in even in debug builds — a
## plain debug launch shows normal English.
const PSEUDO_ENABLE_ENV_VAR: String = "LANTERN_PSEUDOLOCALE"

## Fraction of filler appended to every pseudolocalized string. 0.4 ⇒ ~40%
## longer, matching the German text-expansion budget DESIGN.md's type scale is
## calibrated for, so layout overflow shows up in the pseudolocale first.
const PSEUDO_PAD_RATIO: float = 0.4

## Brackets wrapped around every pseudolocalized string. A missing closing
## bracket at the end of an on-screen string is the visible tell that the UI
## truncated the (deliberately longer) text.
const PSEUDO_BRACKET_OPEN: String = "⟦"
const PSEUDO_BRACKET_CLOSE: String = "⟧"

## ASCII letter → accented look-alike map for [method pseudo_transform]. Every
## Latin letter is remapped so untranslated passthrough text stands out; all
## other characters (digits, punctuation, whitespace) are left untouched.
const PSEUDO_ACCENT_MAP: Dictionary = {
	"a": "á", "b": "ƀ", "c": "ç", "d": "ð", "e": "é", "f": "ƒ", "g": "ǵ",
	"h": "ĥ", "i": "í", "j": "ĵ", "k": "ķ", "l": "ĺ", "m": "ḿ", "n": "ń",
	"o": "ó", "p": "ṕ", "q": "ǫ", "r": "ŕ", "s": "ŝ", "t": "ţ", "u": "ú",
	"v": "ṽ", "w": "ŵ", "x": "ẋ", "y": "ý", "z": "ż",
	"A": "Á", "B": "Ɓ", "C": "Ç", "D": "Ð", "E": "É", "F": "Ƒ", "G": "Ǵ",
	"H": "Ĥ", "I": "Í", "J": "Ĵ", "K": "Ķ", "L": "Ĺ", "M": "Ḿ", "N": "Ń",
	"O": "Ó", "P": "Ṕ", "Q": "Ǫ", "R": "Ŕ", "S": "Ŝ", "T": "Ţ", "U": "Ú",
	"V": "Ṽ", "W": "Ŵ", "X": "Ẋ", "Y": "Ý", "Z": "Ż",
}

## Set at boot from [const PSEUDO_ENABLE_ENV_VAR]. Exposed as a member (not a
## local) so unit tests can drive [method _load_csv_file] with synthesis on
## without depending on the process environment.
var pseudolocale_enabled: bool = false


# ---------------------------------------------------------------------------
# Locale persistence (Settings GDD #30 §C.5 / ADR-0026 §C.5, D-b)
# ---------------------------------------------------------------------------

## ConfigFile section + key under which the player's chosen locale persists,
## per Settings GDD #30 §C.5 and ADR-0026 §C.5. The boot-read
## ([method _apply_persisted_locale]) and the write ([method persist_locale])
## both address exactly this section/key.
const SETTINGS_LOCALE_SECTION: String = "locale"
const SETTINGS_LOCALE_KEY: String = "active_locale"

## Path to the persisted-settings ConfigFile. This is the SAME file
## SceneManager persists [code][accessibility]/reduce_motion[/code] into, so
## every write here is load-modify-save (see [method persist_locale]) to avoid
## clobbering unrelated sections.
##
## Overridable by tests: assign before the autoload's [method _ready] runs (or
## before calling the persistence methods on a fresh instance) so
## locale-persistence specs isolate from the real
## [code]user://settings.cfg[/code]. Mirrors SceneManager's
## [code]_settings_cfg_path[/code] — the canonical path-override pattern.
var _settings_cfg_path: String = "user://settings.cfg"


# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

## Loads each supported locale CSV and registers a [Translation] per locale
## column. Sets [member TranslationServer.locale] to [const DEFAULT_LOCALE]
## after registration so [code]tr()[/code] resolves to the default language.
##
## When [code]LANTERN_PSEUDOLOCALE=1[/code] is set in the environment, a
## debug-only [const PSEUDO_LOCALE] pseudolocale is also synthesized from the
## default-locale column (see [method build_pseudolocale]).
##
## Idempotent within a single boot: [code]_ready[/code] is invoked exactly
## once per autoload by the Godot runtime.
func _ready() -> void:
	pseudolocale_enabled = OS.get_environment(PSEUDO_ENABLE_ENV_VAR) == "1"
	for filename in SUPPORTED_LOCALE_FILES:
		var path: String = LOCALE_DIR_PATH + "/" + filename
		_load_csv_file(path)
	TranslationServer.set_locale(DEFAULT_LOCALE)
	# Apply the player's persisted locale (if any) OVER the default just set.
	# Owned here rather than in Settings because LocaleLoader already owns the
	# boot-time set_locale and is a boot autoload — a Settings screen cannot run
	# before boot, so the read cannot live there (ADR-0026 D-b). Settings only
	# triggers the write, via [method persist_locale].
	_apply_persisted_locale()


# ---------------------------------------------------------------------------
# Locale persistence
# ---------------------------------------------------------------------------

## Reads the player's persisted locale from [member _settings_cfg_path] and, if
## it names a currently-loaded locale, switches [TranslationServer] to it.
## Called from [method _ready] AFTER [code]set_locale(DEFAULT_LOCALE)[/code], so
## a valid persisted choice overrides the default while an absent or invalid one
## leaves the default in place.
##
## Robustness (a broken settings file must never brick localization at boot):
## [br]- A missing file is the expected first-launch path — silent, no warning.
## [br]- Any other load error warns once and keeps the default locale.
## [br]- A present-but-non-[String] value is type-guarded:
##   [method ConfigFile.get_value] returns the supplied default ONLY when the
##   key is ABSENT, not when it is present with the wrong type, so a stored
##   non-string would otherwise slip through.
## [br]- A locale not in [method TranslationServer.get_loaded_locales] is
##   ignored (e.g. a save naming a locale a later build dropped).
func _apply_persisted_locale() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(_settings_cfg_path)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning("[LocaleLoader] _apply_persisted_locale: could not parse %s (err=%d); default locale kept." % [_settings_cfg_path, err])
		return
	var raw: Variant = cfg.get_value(SETTINGS_LOCALE_SECTION, SETTINGS_LOCALE_KEY, "")
	if typeof(raw) != TYPE_STRING:
		return
	# An empty id (the absent-key default) is never a loaded locale, so the
	# membership test alone correctly leaves the default in place.
	var active: String = raw
	if active != "" and active in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(active)


## Persists [param locale_id] as the player's chosen locale to
## [member _settings_cfg_path]. Called by the Settings overlay's
## [code]_on_locale_selected[/code] (ADR-0026 D-b: Settings triggers the write;
## the boot-read in [method _apply_persisted_locale] is owned here so it runs
## before any screen exists).
##
## Load-modify-save: the file is shared with SceneManager's
## [code][accessibility]/reduce_motion[/code], so existing contents are loaded
## first and only [code][locale]/active_locale[/code] is set — unrelated
## sections are preserved. A save failure warns but does not raise: the
## in-memory [method TranslationServer.set_locale] has already applied, so only
## cross-restart persistence is lost, not the current switch.
func persist_locale(locale_id: String) -> void:
	if locale_id == "":
		return  # Defensive: never persist an empty locale id.
	var cfg := ConfigFile.new()
	# Load existing contents to preserve unrelated sections; a missing file is
	# the normal first-write case. Any other read error is surfaced, but we
	# still write so the player's choice is not silently dropped.
	var load_err: Error = cfg.load(_settings_cfg_path)
	if load_err != OK and load_err != ERR_FILE_NOT_FOUND:
		push_warning("[LocaleLoader] persist_locale: could not read %s before write (err=%d); unrelated settings keys may be overwritten." % [_settings_cfg_path, load_err])
	cfg.set_value(SETTINGS_LOCALE_SECTION, SETTINGS_LOCALE_KEY, locale_id)
	var save_err: Error = cfg.save(_settings_cfg_path)
	if save_err != OK:
		push_warning("[LocaleLoader] persist_locale: failed to persist locale '%s' to %s (err=%d)." % [locale_id, _settings_cfg_path, save_err])


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

	# When pseudolocalization is enabled, accumulate the default-locale column
	# here and synthesize the en_XA pseudolocale after the scan. Skipped
	# entirely in normal runs (pseudolocale_enabled is false), so there is no
	# cost on the player boot path.
	var pseudo_source: Dictionary = {}

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
			if pseudolocale_enabled and translations[i - 1].locale == DEFAULT_LOCALE:
				pseudo_source[key] = value

	file.close()

	# Register all built translations with the global TranslationServer.
	for t in translations:
		TranslationServer.add_translation(t)

	# Register the debug-only pseudolocale synthesized from this file's
	# default-locale column (no-op unless LANTERN_PSEUDOLOCALE=1).
	if pseudolocale_enabled and not pseudo_source.is_empty():
		TranslationServer.add_translation(build_pseudolocale(pseudo_source))


# ---------------------------------------------------------------------------
# Pseudolocalization helpers
# ---------------------------------------------------------------------------

## Builds the [const PSEUDO_LOCALE] [Translation] from a [param source_messages]
## map of [code]key → default-locale value[/code] by running every value
## through [method pseudo_transform]. Pure: it constructs and returns the
## resource but registers nothing with [TranslationServer], so it is safe to
## call from unit tests without mutating global locale state.
##
## [codeblock]
## var pseudo := LocaleLoader.build_pseudolocale({"greeting": "Hello"})
## pseudo.locale                   # "en_XA"
## pseudo.get_message(&"greeting")  # e.g. "⟦Ĥéĺĺö··⟧"
## [/codeblock]
static func build_pseudolocale(source_messages: Dictionary) -> Translation:
	var pseudo: Translation = Translation.new()
	pseudo.locale = PSEUDO_LOCALE
	for key: Variant in source_messages:
		pseudo.add_message(StringName(key), StringName(pseudo_transform(String(source_messages[key]))))
	return pseudo


## Transforms [param source] into its pseudolocalized form: every Latin letter
## is replaced with an accented look-alike (so any plain-English passthrough is
## obvious), the whole string is wrapped in [const PSEUDO_BRACKET_OPEN] /
## [const PSEUDO_BRACKET_CLOSE], and ~[const PSEUDO_PAD_RATIO] filler is
## appended to surface layout overflow.
##
## [code]%[/code]-format specifiers ([code]%s[/code], [code]%d[/code],
## [code]%%[/code], …) are copied through verbatim — accenting the conversion
## letter would corrupt the specifier and crash the later [code]str % args[/code]
## in [method UIFramework.format_localized]. BBCode-style [code][tag][/code]
## runs are likewise passed through so rich-text markup keeps working.
##
## [codeblock]
## pseudo_transform("Recruit")   # "⟦Ŕéçŕúíţ···⟧"
## pseudo_transform("Gold: %d")  # "⟦Ǵóĺð: %d····⟧"  (%d preserved)
## pseudo_transform("×%.2f")     # "⟦×%.2f··⟧"       (multi-char %.2f preserved)
## [/codeblock]
static func pseudo_transform(source: String) -> String:
	var transformed: String = ""
	var i: int = 0
	var length: int = source.length()
	while i < length:
		var ch: String = source[i]
		# Preserve a whole %-format specifier verbatim (e.g. %s, %d, %%, %.2f,
		# %05d). The conversion is `%`, then either a literal `%` or any run of
		# flag/width/precision characters ([-+ #0-9.*]) followed by one
		# conversion letter. Accenting any of those characters would corrupt the
		# specifier and crash the later `str % args` in format_localized — so the
		# entire run is copied through, not just the first character after `%`.
		if ch == "%" and i + 1 < length:
			var spec: String = "%"
			var j: int = i + 1
			if source[j] == "%":
				spec += "%"
				j += 1
			else:
				while j < length and "-+ #0123456789.*".contains(source[j]):
					spec += source[j]
					j += 1
				if j < length:
					spec += source[j]  # the conversion letter (d, s, f, …)
					j += 1
			transformed += spec
			i = j
			continue
		# Preserve BBCode-style tag runs verbatim (e.g. [b], [color=#fff]).
		if ch == "[":
			var close: int = source.find("]", i)
			if close != -1:
				transformed += source.substr(i, close - i + 1)
				i = close + 1
				continue
		transformed += String(PSEUDO_ACCENT_MAP.get(ch, ch))
		i += 1
	var pad_length: int = int(ceil(length * PSEUDO_PAD_RATIO))
	return PSEUDO_BRACKET_OPEN + transformed + "·".repeat(pad_length) + PSEUDO_BRACKET_CLOSE
