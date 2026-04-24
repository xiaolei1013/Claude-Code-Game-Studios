@abstract
class_name GameData
extends Resource

## Abstract base for all data-driven content resources in Lantern Guild.
##
## Concrete content types (HeroClass, EnemyData, Biome, Dungeon, Floor)
## extend this class and inherit the [member id] and [member display_name]
## fields without redeclaring them.
##
## Designers MUST NOT create a [code]GameData.tres[/code] directly — use the
## concrete subclasses. The [code]@abstract[/code] annotation (Godot 4.5+)
## prevents direct instantiation and produces an editor error if attempted.
##
## ADR-0006, ADR-0011.

## Stable, snake_case identifier unique within its content type.
## Set by the designer once; treated as immutable after initial authoring.
## Example: [code]"class_warrior"[/code], [code]"enemy_goblin_bruiser"[/code].
@export var id: String = ""

## Human-readable name shown in UI and editor inspector.
## May be localized at runtime via the TranslationServer.
@export var display_name: String = ""
