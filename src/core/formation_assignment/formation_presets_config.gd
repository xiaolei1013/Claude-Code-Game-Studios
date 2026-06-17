class_name FormationPresetsConfig
extends GameData

## FormationPresetsConfig — single source of truth for Formation Presets
## (GDD #33 / formation-presets.md) tuning knobs.
##
## All design-tunable constants live here as [code]@export[/code] fields,
## loaded at startup from
## [code]assets/data/config/formation_presets_config.tres[/code] via
## [DataRegistry]. No preset limit is hardcoded in [FormationAssignment] —
## the autoload resolves this resource and falls back to its own
## [code]_FALLBACK_*[/code] safe defaults if resolution fails.
##
## Usage:
## [codeblock]
## var cfg := DataRegistry.resolve("config", "formation_presets_config") as FormationPresetsConfig
## [/codeblock]
##
## Call [method _validate] after any programmatic mutation to verify schema
## constraints. The method returns an empty array on a valid instance.
##
## ADR-0011: Resource schema + per-resource [method _validate] pattern.
## ADR-0013: Single-source-of-truth tuning knobs; no hardcoded limits.
## ADR-0006: DataRegistry boot-scan loads this file from assets/data/config/.
##
## NOTE: [member id] and [member display_name] are inherited from [GameData].
## Do NOT redeclare them here.
##
## design/gdd/formation-presets.md §G (Tuning Knobs).

## Hard cap on saved presets per player (formation-presets.md §C.2 + §G).
##
## Larger = more flexibility; smaller = forces curation. 6 is "a small
## handful" per the cozy register (§B). Reaching the cap surfaces a defensive
## toast on Save attempt; no silent overwrite, no auto-rotation.
## Safe range: 3–12. Default 6 per §G.
@export_range(3, 12) var MAX_PRESETS_PER_PLAYER: int = 6

## Maximum player-chosen preset name length, in characters (§C.1 + §G).
##
## Below 16 → players can't fit short biome names; above 64 → UI truncation
## issues. Names longer than this are truncated (not rejected) per §C.5 step 1.
## Safe range: 16–64. Default 32 per §G.
@export_range(16, 64) var PRESET_NAME_MAX_LENGTH: int = 32

## Cap on missing-hero toasts surfaced per recall (§C.4 + §G).
##
## A preset can reference at most [code]formation_size()[/code] heroes (= 3 in
## MVP), so the default 3 matches the formation size. Caps toast spam if many
## referenced heroes were dismissed/prestiged since the preset was saved.
## Safe range: 1–10. Default 3 per §G.
@export_range(1, 10) var RECALL_MISSING_HERO_TOAST_CAP: int = 3

## Which button is default-focused in the delete-confirmation modal (§C.6 + §G).
##
## Cozy register: the destructive default is the SAFE one ("cancel"). Don't
## change to "confirm" without a playtest signal. Allowed values: "cancel",
## "confirm". Default "cancel" per §G.
@export_enum("cancel", "confirm") var DELETE_CONFIRMATION_DEFAULT_FOCUS: String = "cancel"


## Validates all schema constraints for this FormationPresetsConfig instance.
##
## Returns an empty [Array][String] if the instance is valid; returns a
## non-empty list of human-readable violation strings if any constraint fails.
##
## Called by tests and by DataRegistry's per-type validator dispatch (ADR-0011).
## An empty return == OK.
##
## Enforced constraints:
##   1. [member MAX_PRESETS_PER_PLAYER] >= 1 (a cap of 0 would make Save always
##      fail — a soft-lock of the feature)
##   2. [member PRESET_NAME_MAX_LENGTH] >= 1 (a max of 0 would reject every name)
##   3. [member RECALL_MISSING_HERO_TOAST_CAP] >= 0 (0 = suppress all missing-hero
##      toasts; still valid)
##   4. [member DELETE_CONFIRMATION_DEFAULT_FOCUS] is one of "cancel" / "confirm"
##
## ADR-0011 §Decision — per-resource _validate() pattern.
func _validate() -> Array[String]:
	var errors: Array[String] = []

	# Constraint 1: MAX_PRESETS_PER_PLAYER >= 1
	if MAX_PRESETS_PER_PLAYER < 1:
		errors.append(
			"MAX_PRESETS_PER_PLAYER must be >= 1 (a cap of 0 makes Save always fail); got %d"
			% MAX_PRESETS_PER_PLAYER
		)

	# Constraint 2: PRESET_NAME_MAX_LENGTH >= 1
	if PRESET_NAME_MAX_LENGTH < 1:
		errors.append(
			"PRESET_NAME_MAX_LENGTH must be >= 1 (a max of 0 rejects every name); got %d"
			% PRESET_NAME_MAX_LENGTH
		)

	# Constraint 3: RECALL_MISSING_HERO_TOAST_CAP >= 0
	if RECALL_MISSING_HERO_TOAST_CAP < 0:
		errors.append(
			"RECALL_MISSING_HERO_TOAST_CAP must be >= 0; got %d"
			% RECALL_MISSING_HERO_TOAST_CAP
		)

	# Constraint 4: DELETE_CONFIRMATION_DEFAULT_FOCUS in {"cancel", "confirm"}
	if DELETE_CONFIRMATION_DEFAULT_FOCUS != "cancel" and DELETE_CONFIRMATION_DEFAULT_FOCUS != "confirm":
		errors.append(
			"DELETE_CONFIRMATION_DEFAULT_FOCUS must be \"cancel\" or \"confirm\"; got \"%s\""
			% DELETE_CONFIRMATION_DEFAULT_FOCUS
		)

	return errors
