class_name TestContentType
extends GameData

## Minimal concrete subclass of GameData used exclusively by DataRegistry unit tests.
##
## GameData is [code]@abstract[/code] (Godot 4.5+) and cannot be instantiated
## directly. This concrete subclass adds no additional fields — it only exists so
## tests can call [code]TestContentType.new()[/code] and persist fixtures via
## [code]ResourceSaver.save()[/code] without adding any production content coupling.
##
## Used by: [code]tests/unit/data_registry/boot_scan_load_order_test.gd[/code]
## Do NOT reference this class from [code]src/[/code] code — test fixtures only.
