# ADR-0022: Audio Asset Sourcing — AI-Generated Bank (supersedes ADR-0016 Silent MVP)

## Status

Proposed

> Ratify to **Accepted** before the generated `.tres` cues land on `main`.
> On acceptance, flip ADR-0016 Status to "Superseded by ADR-0022".

## Date

2026-06-13 (authored to close the ADR-0016 pivot under user direction to source audio)

## Last Verified

2026-06-13

## Decision Makers

- Author (user) — final decision; provided ElevenLabs API access and directed audio + visual asset generation
- audio-director — cozy-register fit of the generated bank (advisory)
- technical-director — AudioCue wrapper + resolve-path correction (the code change ADR-0016 missed)
- producer — scope: generation runs as a pilot-first batch (validate quality + cost before scaling)

## Summary

Fires **ADR-0016 pivot trigger #4** (free/low-tier AI-generation pathway is technically
viable) under direct user direction: source the Lantern Guild audio bank — 14 SFX cues
+ 10 music beds/stingers per `design/gdd/audio-system.md` §C — as **AI-generated assets
via ElevenLabs** (`/v1/sound-generation` for SFX, `/v1/music` for beds). AudioRouter flips
from wired-but-silent (ADR-0016) to audibly playing.

Critically, this ADR also **corrects a latent error in ADR-0016's migration plan**.
ADR-0016 §Migration Plan claimed the pivot was "a pure content patch (no code change)":
drop a bare `AudioStream` `.tres` at the §C.6 path and DataRegistry's boot scan picks it
up. That is **false** and was never exercised (both `assets/data/sfx/` and
`assets/data/music/` shipped empty). DataRegistry's boot scan requires every content
resource to expose a non-empty snake_case `id` (`_extract_resource_id()`); a bare
`AudioStreamWAV` / `AudioStreamOggVorbis` has no `id`, so it fails boot integrity with
`ERROR_INVALID_ID` and drops the whole audio category into the ERROR state. Conversely,
`play_sfx` / `play_music` cast the resolved resource `as AudioStream`, which cannot read an
`id`-carrying wrapper. The two requirements collided.

This ADR resolves the collision with a minimal, GDD-aligned code change (the `AudioCue`
wrapper described in `audio-system.md` §C.6 but never implemented), so the generated assets
actually load and play.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Audio / Asset pipeline + a minimal core-autoload code correction |
| **Knowledge Risk** | LOW — `AudioStreamPlayer`, `AudioStreamWAV`, `AudioStreamOggVorbis`, `ResourceSaver`/`ResourceLoader`, and custom `Resource` subclasses are stable since 4.0; no post-cutoff API surface. The `.import` step for `.wav`/`.ogg` is the standard Godot importer. |
| **References Consulted** | `design/gdd/audio-system.md` §C.2/§C.3/§C.6/§H; `src/core/data_registry/data_registry.gd` (`_load_category`, `_extract_resource_id`); `src/core/audio_router/audio_router.gd` (`play_sfx`/`play_music`/`play_stinger`); ADR-0016; ADR-0006; ADR-0011 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Boot scan + resolve path validated headlessly via `tests/unit/audio_router/audio_cue_resolve_test.gd` (7/7 pass, no asset import needed). Audible smoke (≥3 cues) required after the first real `.wav`/`.ogg` are imported. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (DataRegistry boot-scan `.tres`-only pattern); ADR-0011 (GameData resource schemas) |
| **Supersedes** | ADR-0016 (Audio Asset Sourcing — Silent MVP). On acceptance, ADR-0016 Status → "Superseded by ADR-0022". |
| **Enables** | Audible AudioRouter; future per-cue mixing/ducking work; mobile-port audio parity (ADR-0016 pivot trigger #3) |
| **Blocks** | None |

## Context

### Problem Statement

The user directed sourcing of the full audio bank (and visual art) via AI generation,
providing ElevenLabs API access. This fires ADR-0016 pivot trigger #4. Two things must
happen: (1) author the assets, and (2) make DataRegistry + AudioRouter actually load and
play them — which ADR-0016 incorrectly assumed needed no code.

### Current State

- **AudioRouter** (`src/core/audio_router/audio_router.gd`): autoload; subscribes to gameplay
  signals; `play_sfx` / `play_music` / `play_stinger` resolve cues via
  `DataRegistry.resolve("sfx"|"music", raw_id)`. **Pre-this-ADR** each cast the result
  `as AudioStream` and null-skipped (silent path). A demo-MP3 fallback exists for music only.
- **DataRegistry** (`src/core/data_registry/data_registry.gd`): boot scan loads `.tres` only;
  `_extract_resource_id()` returns `res.id` if the property exists else `""`; an empty id
  transitions the registry to `ERROR_INVALID_ID`. `assets/data/sfx/` + `assets/data/music/`
  are empty (`.gitkeep` only).
- **No `AudioCue` class existed** — the `audio-system.md` §C.6 "wrapper that carries the id
  and references the stream" was specified but never implemented.

### Constraints

- **Pilot-first**: generate ~6 sample assets, review quality + actual API cost, then scale
  (user-locked decision).
- **No wasted spend**: the `.tres` shape must be validated before mass-generating audio.
  (Met: `audio_cue_resolve_test.gd` validates the load/resolve/extract path with an in-memory
  stream — zero API spend.)
- **Licensing**: generated-audio ownership/commercial-use rights depend on the ElevenLabs
  plan tier. The user, as account holder, confirms the tier permits commercial game use and
  redistribution of the generated waveform. Captured in §Risks.
- **PR workflow**: no direct push to `main`; assets + code land via PR.

### Requirements

- **Functional**: `DataRegistry.resolve("sfx"|"music", id)` returns a resource from which
  AudioRouter can obtain a playable `AudioStream`; AudioRouter routes it to the cue's bus per
  §C.2. Silent skip is preserved for missing/malformed cues.
- **Compatibility**: existing AudioRouter tests (signal routing, volume round-trip, throttle)
  continue to pass unchanged — they assert routing/logging, not resolution.
- **Testability**: the load/resolve/extract path has automated coverage that needs no
  imported audio file (so it runs in headless CI deterministically).

## Decision

**Source the audio bank as AI-generated assets (ElevenLabs), and implement the `AudioCue`
wrapper so they load and play.**

### Architecture

```
[ ElevenLabs API ]                 [ asset tree ]                         [ runtime ]
 /v1/sound-generation  ──► assets/audio/sfx/<id>.wav  ──┐
 /v1/music             ──► assets/audio/music/<id>.ogg ─┤ imported (.import sidecar)
                                                        │
                            assets/data/sfx/<id>.tres   │  AudioCue { id, stream=ExtResource(.wav) }
                            assets/data/music/<id>.tres ─┘  AudioCue { id, stream=ExtResource(.ogg) }
                                       │
                                       ▼
   DataRegistry boot scan ── _extract_resource_id() reads AudioCue.id ✔ (no ERROR_INVALID_ID)
                                       │  resolve("sfx"|"music", id) → AudioCue
                                       ▼
   AudioRouter.play_sfx/play_music ── _stream_from_resolved(cue) → cue.stream (AudioStream)
                                       ▼  routed to §C.2 target bus → plays audibly
```

### Key Interfaces

```gdscript
# NEW — src/core/audio_router/audio_cue.gd
class_name AudioCue
extends GameData            # inherits id + display_name
@export var stream: AudioStream = null

# CHANGED — src/core/audio_router/audio_router.gd
# play_sfx / play_music / play_stinger resolve sites now read the wrapper's stream
# (duck-typed on the `stream` property, so the engine layer stays decoupled from
#  the AudioCue content class; also tolerates a bare AudioStream or returns null):
func _stream_from_resolved(resolved: Resource) -> AudioStream:
    if resolved == null: return null
    if resolved is AudioStream: return resolved
    if "stream" in resolved: return resolved.stream as AudioStream
    return null
#   stream = _stream_from_resolved(registry.resolve("sfx", raw_id))   # was: ... as AudioStream
```

### Implementation Guidelines

- `.tres` `id` is the cue id **without** the AudioRouter prefix: `&"sfx_ui_tap"` →
  `assets/data/sfx/ui_tap.tres` (id `ui_tap`); `&"music_guild_hall_bed"` →
  `assets/data/music/guild_hall_bed.tres` (id `guild_hall_bed`). Ids must be snake_case
  (DataRegistry rejects otherwise).
- SFX `.wav` 44.1kHz 16-bit (mono UI/Combat, stereo Reward); music `.ogg` Vorbis ~Q5 stereo
  per §C.6. Loop points set on beds via the Godot import dialog / import metadata.
- The generation pipeline (`tools/asset-pipeline/`) writes the raw `.wav`/`.ogg` and authors
  the wrapper `.tres`. Godot must import the new audio (generates `.import` sidecars) — commit
  the `.wav`/`.ogg` + `.import` + `.tres` + `.uid` together (per the project's `.uid` rule).
- Keep `_headless_mode` and the demo-MP3 music fallback intact.

## Alternatives Considered

### Alternative 1: `AudioCue` wrapper (GameData subclass) — CHOSEN

- **Description**: A `Resource` subclass extending `GameData` (so it has `id`) with a `stream`
  field referencing the imported `.wav`/`.ogg`. AudioRouter reads `.stream`.
- **Pros**: Matches `audio-system.md` §C.6's stated design; minimal change (one new 1-field
  class + a 4-line resolve helper); no DataRegistry change; existing tests unaffected;
  validated headlessly without asset import.
- **Cons**: A genuine (small) code change — so ADR-0016's "no code change" promise was wrong.
- **Rejection Reason**: N/A — chosen.

### Alternative 2: Special-case audio in DataRegistry (index bare AudioStream by filename)

- **Description**: Teach `_extract_resource_id()` to fall back to the filename stem for the
  `sfx`/`music` categories, letting bare `AudioStreamWAV`/`OggVorbis` `.tres` index directly.
- **Pros**: No wrapper class; closest to ADR-0016's "drop a bare stream" intent.
- **Cons**: Special-cases a core invariant (every content resource carries an explicit `id`)
  for two categories; still needs `play_*` to stop casting `as AudioStream` for the
  filename-keyed path; muddies ADR-0006. More surface, less clarity than a 1-field wrapper.
- **Rejection Reason**: Violates the uniform `GameData.id` contract for marginal benefit.

### Alternative 3: License a royalty-free pack instead of AI generation

- **Description**: ADR-0016 Alternative 2 (Path B). Buy a cozy/fantasy pack, cherry-pick cues.
- **Pros**: Human-authored consistency.
- **Cons**: Budget approval; cue-fit is approximate; the user has directed AI generation and
  provided API access. Still needs the same `AudioCue` wrapper to load.
- **Rejection Reason**: Superseded by the user's direction; the wrapper is needed regardless.

## Consequences

### Positive

- AudioRouter is audible: the cozy register (`audio-system.md` §B) gains its audio dimension.
- The latent `ERROR_INVALID_ID` boot trap (a bare audio `.tres` would have crashed the audio
  category) is closed and regression-tested.
- The `.tres` shape is proven before any ElevenLabs spend — pilot-first, no wasted cost.
- Existing AudioRouter tests pass unchanged; one new test suite adds load/resolve coverage.

### Negative

- ADR-0016's "pure content patch" promise is retracted — this required code. Documented here.
- Real `.wav`/`.ogg` still need a one-time Godot import (`.import` sidecars) — a manual/CI
  editor step, subject to the known import-regeneration gotchas; commit the sidecars.

### Neutral

- DataRegistry `sfx`/`music` categories, AudioRouter rank, bus layout, Settings schema:
  unchanged.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ElevenLabs plan tier does not grant commercial/redistribution rights for generated audio | MEDIUM | HIGH | User (account holder) confirms tier ToS before assets land; record the tier + ToS link in this ADR on acceptance. Rollback = delete the `.tres` (AudioRouter degrades to silent per ADR-0016). |
| Generated cues miss the cozy register | MEDIUM | LOW | Pilot-first: review ~6 samples before scaling; regenerate cheaply. |
| New `.wav`/`.ogg` fail to import or import stale (known Godot gotcha) | MEDIUM | MEDIUM | Import via GUI editor boot; verify `.import` sidecars exist + commit them; audible smoke of ≥3 cues. |
| Bit-depth/loop metadata wrong on beds (clicks at loop point) | LOW | LOW | Set loop mode in import dialog; audible smoke per bed. |

## Performance Implications

| Metric | Before (silent) | Expected After | Budget |
|--------|-----------------|----------------|--------|
| CPU — cue dispatch | ~1µs (no-op) | ~ small constant (stream assign + bus route) | <16ms frame |
| Memory — audio footprint | 0 KB | sum of imported `.wav`/`.ogg` (target: SFX small; beds streamed) | 256 MB mobile / 512 MB PC |
| Load — DataRegistry boot scan sfx/music | <1ms (empty) | <few ms (≤24 small `.tres`) | one-shot boot |

## Migration Plan

1. **Accept this ADR**; flip ADR-0016 → "Superseded by ADR-0022".
2. **Land the code** (this branch): `audio_cue.gd` + `_stream_from_resolved` + the new test.
3. **Generate pilot** (~6 cues) via `tools/asset-pipeline/`; review quality + cost.
4. **Author `.tres`** wrappers + import `.wav`/`.ogg`; commit assets + `.import` + `.uid`.
5. **Audible smoke**: launch the game; verify ≥3 cues play (e.g. `ui_tap`, `guild_hall_bed`,
   a floor-clear stinger) per `audio-system.md` §H.
6. **Scale** to the full 14 SFX + 10 music bank.
7. **Update** `design/gdd/game-concept.md` §Audio Needs row to reflect non-silent state.

**Rollback**: delete the audio `.tres` from `assets/data/sfx|music/`; AudioRouter degrades to
silent-MVP. The `AudioCue` class + resolve helper are inert with no cues present (resolve →
null → silent skip), so they may stay.

## Validation Criteria

- [x] `AudioCue extends GameData` with `id` (inherited) + `stream`; no `class_name` collision.
- [x] DataRegistry indexes an `AudioCue` `.tres` for `sfx` and `music` without ERROR_INVALID_ID
      (`audio_cue_resolve_test.gd` — 7/7 pass, headless, no asset import).
- [x] `_stream_from_resolved` returns the inner stream for AudioCue, the stream itself for a
      bare AudioStream, and null (no crash) otherwise.
- [ ] Existing AudioRouter suites (`audio_router_signal_handlers_test.gd`, `n1_mvp_contract_test.gd`,
      `class_synergy_audio_test.gd`, `stop_music_test.gd`, `volume_persistence_round_trip_test.gd`)
      re-run green after the change. *(Pending full-suite re-run.)*
- [ ] Pilot batch reviewed for cozy-register fit + actual cost before scaling.
- [ ] Audible smoke of ≥3 cues against a built/run game.
- [ ] ElevenLabs tier commercial/redistribution rights confirmed + recorded here.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|----------------------------|
| `design/gdd/audio-system.md` | Audio | §C.2 SFX taxonomy + §C.3 music cue plan | Decides AI generation as the sourcing pathway for all 14 SFX + 10 music cues |
| `design/gdd/audio-system.md` | Audio | §C.6 asset-path + wrapper convention | Implements the `AudioCue` wrapper the §C.6 convention describes but that was never built |
| `design/gdd/audio-system.md` | Audio | §H acceptance criteria (audible cues) | Makes cues audible (resolve → stream → bus); audible smoke is a §Migration step |
| `design/gdd/settings-options-accessibility.md` | Settings/Audio | volume sliders + mute | Sliders gain audible effect; schema unchanged |
| `design/gdd/game-concept.md` | Pillar | §Audio Needs row | Flips silent-MVP → AI-generated audio (a §Migration deliverable) |

## Related

- Supersedes: `docs/architecture/ADR-0016-audio-asset-sourcing-silent-mvp.md`
- ADR-0006 (DataRegistry boot-scan `.tres`-only); ADR-0011 (GameData schemas)
- Code: `src/core/audio_router/audio_cue.gd` (new); `src/core/audio_router/audio_router.gd`
  (`_stream_from_resolved` + resolve sites); `src/core/data_registry/data_registry.gd`
  (`_extract_resource_id` — unchanged, now satisfied by AudioCue)
- Tests: `tests/unit/audio_router/audio_cue_resolve_test.gd` (new)
- Pipeline: `tools/asset-pipeline/` (generation scripts + manifests)
