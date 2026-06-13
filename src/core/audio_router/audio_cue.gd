class_name AudioCue
extends GameData

## AudioCue — DataRegistry-indexable wrapper for a single playable audio asset.
##
## Lantern Guild's audio cues (SFX + music beds/stingers) ship as [code].tres[/code]
## files under [code]assets/data/sfx/[/code] and [code]assets/data/music/[/code] so
## the DataRegistry boot scan (ADR-0006) can index them by [member GameData.id] and
## AudioRouter can resolve them by cue id.
##
## [b]Why a wrapper and not a bare AudioStream .tres?[/b]
## DataRegistry's boot scan requires every content resource to expose a non-empty
## snake_case [member GameData.id] (see [code]DataRegistry._extract_resource_id()[/code]);
## a bare [AudioStreamWAV] / [AudioStreamOggVorbis] has no [code]id[/code], so it would
## fail boot integrity with [code]ERROR_INVALID_ID[/code] and drop the whole audio
## category into the ERROR state. AudioCue extends [GameData] to carry the id and
## references the underlying stream via [member stream]. This corrects the
## (never-exercised, incorrect) "drop a bare AudioStream .tres, no code change"
## migration note in ADR-0016. See ADR-0022.
##
## [b]Authoring[/b] (per design/gdd/audio-system.md §C.6):
##   [code]assets/data/sfx/<id>.tres[/code]   → AudioCue wrapping a 44.1kHz .wav
##   [code]assets/data/music/<id>.tres[/code] → AudioCue wrapping an .ogg (Vorbis Q5)
## The [member id] is the cue id WITHOUT the AudioRouter prefix — e.g. the cue
## [code]&"sfx_ui_tap"[/code] resolves to [code]assets/data/sfx/ui_tap.tres[/code]
## (id [code]"ui_tap"[/code]); [code]&"music_guild_hall_bed"[/code] resolves to
## [code]assets/data/music/guild_hall_bed.tres[/code] (id [code]"guild_hall_bed"[/code]).
##
## [b]Usage:[/b]
##   [codeblock]
##   var cue: AudioCue = DataRegistry.resolve("sfx", "ui_tap")
##   player.stream = cue.stream
##   [/codeblock]
##
## ADR-0022: AI-generated audio sourcing (supersedes ADR-0016 silent-MVP).
## ADR-0006: DataRegistry boot-scan pattern.
## GDD: design/gdd/audio-system.md §C.6 (asset path convention).

## The underlying playable audio stream — an imported [code].wav[/code] for SFX,
## an [code].ogg[/code] for music. AudioRouter assigns this to the transient
## [AudioStreamPlayer]'s [code]stream[/code] and routes it to the cue's target bus.
## Should never be [code]null[/code] in shipped content; AudioRouter null-skips
## defensively if it is (treated as "asset not yet sourced").
@export var stream: AudioStream = null
