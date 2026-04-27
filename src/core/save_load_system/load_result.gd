class_name LoadResult
extends RefCounted

## LoadResult — typed result wrapper for save/load operations.
##
## Returned by load pipeline methods to communicate success or failure
## to callers without relying on global error state or exceptions.
##
## [code]class_name LoadResult[/code] is allowed here because this script is
## NOT an autoload — only autoload-name conflicts trigger the no-class_name rule
## (see save_load_system.gd file header for that note). LoadResult is
## instantiated by value and returned from load methods.
##
## Usage:
##   [codeblock]
##   var result: LoadResult = load_pipeline.load_envelope()
##   if result.code != LoadResult.ResultCode.OK:
##       push_error("Load failed: %s — %s" % [result.code, result.detail])
##   [/codeblock]
##
## ADR-0004 §Consumer Contract, TR-save-load-055

## Canonical result codes for all load operations.
##
## Exactly 7 values per TR-save-load-055. Tests assert the exact count and names.
##
## ADR-0004 §Consumer Contract, TR-save-load-055
enum ResultCode {
	## Load completed successfully. [member detail] may carry advisory info.
	OK,
	## No save file found at the expected path. Treat as first-launch (Story 007).
	ERR_FILE_ABSENT,
	## HMAC or timestamp check failed — save envelope may have been tampered.
	## See [signal SaveLoadSystem.tamper_detected_on_load] (Story 013).
	ERR_TAMPER_SUSPECTED,
	## DataRegistry was not in READY state when the load pipeline ran.
	## The consumer hydration loop requires content definitions to be available.
	ERR_REGISTRY_UNAVAILABLE,
	## Both primary and backup save slots are unreadable or corrupt.
	## Triggers [signal SaveLoadSystem.corrupt_both_acknowledged] (Story 007).
	ERR_CORRUPT_BOTH,
	## The save envelope's schema version does not match the current version.
	## Triggers the migration pipeline (Story 009+).
	ERR_SCHEMA_MISMATCH,
	## Filesystem I/O error during read (e.g. FileAccess returned error).
	## [member detail] carries the [enum Error] code as a string.
	ERR_IO,
}

## The result code for this load operation.
##
## Always check this field before reading any envelope data.
## Default is [enum ResultCode.OK] so callers that construct a result for a
## known-good path do not need to set it explicitly.
##
## TR-save-load-055
var code: ResultCode = ResultCode.OK

## Optional human-readable detail string for diagnostics and logging.
##
## For error codes: carries the file path, I/O error value, or schema version
## mismatch details. For OK: may carry the save slot used ("primary" / "backup").
## Empty string means no additional detail is available.
##
## TR-save-load-055
var detail: String = ""
