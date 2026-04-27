class_name MainRoot
extends Control

## MainRoot — persistent root of the always-loaded scene tree.
##
## Extends Control (not Node) so that the `theme` property exists and the
## single canonical parchment theme cascades to every Control descendant.
## (Node does not expose `theme`; only Control and Window do in Godot 4.x.
## The story spec says "MainRoot.theme = preload(...)" which requires Control.)
##
## ADR-0007: Persistent root scene architecture
## ADR-0008: Parchment theme preload cascade
##
## IMPORTANT — PROCESS MODE NOTE (ADR-0007 Risks Note 4):
## Screen children are added to ScreenContainer at runtime. ScreenContainer has
## process_mode = PROCESS_MODE_PAUSABLE (value 1), so all Screen children will pause when
## `get_tree().paused = true` is set by SceneManager. Any child node inside a
## Screen that MUST continue running during a modal overlay pause (e.g., idle
## particles, persistent counter tweens, looping background animations) MUST
## explicitly override its own process_mode to PROCESS_MODE_ALWAYS. Do not rely
## on ScreenContainer's mode cascading downward in the "always runs" direction —
## it does not; PAUSABLE freezes everything below it unless overridden.


## No public API — all scene routing flows through SceneManager (Story 002).
## Do not add business logic to this script.
func _ready() -> void:
	theme = preload("res://assets/ui/parchment_theme.tres")
