# Asset Generation Pipeline

Manifest-driven generation of Lantern Guild's audio (ElevenLabs) and visual art
(Google Gemini), anchored to the GDDs, `DESIGN.md`, and `design/art/art-bible.md`.

Stdlib-only Python — no `pip install`. Requires **ffmpeg** on PATH for music
transcode (mp3 → ogg). Verified present locally: ffmpeg 8.1, Python 3.14.

> See `docs/architecture/ADR-0022-audio-asset-sourcing-ai-generated.md` for the
> decision record (AI-generated assets supersede ADR-0016 "Silent MVP") and the
> audio-wiring correction it documents.

---

## TL;DR

```bash
# 1. Validate the plan — NO keys, NO API calls, NO spend:
python3 tools/asset-pipeline/generate.py --dry-run

# 2. Provide keys (gitignored; never committed):
cp .secrets/keys.env.example .secrets/keys.env
$EDITOR .secrets/keys.env        # paste ELEVENLABS_API_KEY + GEMINI_API_KEY

# 3. Generate the pilot batch (6 assets across all 4 categories):
python3 tools/asset-pipeline/generate.py

# 4. Import the new audio in Godot so it gets .import sidecars, then:
python3 tools/asset-pipeline/generate.py --author-tres
```

Run the **pilot first**, review quality + actual API cost, *then* scale to the
full bank by pointing `--manifest` at a larger manifest.

---

## Files

| File | Role |
|---|---|
| `_common.py` | Keys, HTTP (urllib), palette/style constants, repo paths. Keys are length-checked only — never printed. |
| `generate.py` | Driver. Reads a manifest, calls the APIs, writes assets. `--dry-run`, `--only`, `--author-tres`. |
| `author_audio_tres.py` | Writes `AudioCue` `.tres` wrappers so DataRegistry can resolve generated audio (see "Audio wiring"). |
| `manifests/pilot.json` | The 6-asset pilot batch. Each entry carries its prompt + output path(s). |

## Key handling (security)

- Keys live in `.secrets/keys.env` (gitignored) **or** the environment **or**
  `.claude/settings.local.json` `env` block (also gitignored).
- Resolution order per key: `os.environ` first, then `.secrets/keys.env`.
- The pipeline reports only `SET (len N)` / `UNSET` — it **never** prints, logs,
  or commits a key value.
- `--dry-run` needs no keys at all.

## Sections & flags

`generate.py` understands these manifest sections:

- **audio**: `sfx` (ElevenLabs `/v1/sound-generation` → PCM → WAV via `wave`),
  `music` (`/v1/music` → mp3 → ogg via ffmpeg)
- **images**: `backgrounds`, `portraits`, `enemy_sprites`, `vfx`
  (Gemini `generateContent` → base64 PNG)

`--only <section>` runs one section (`audio`, `images`, or a leaf like `sfx`,
`backgrounds`). `--manifest <path>` selects a different manifest.

## Audio wiring (the part that bites)

Generated `.wav`/`.ogg` files are **not** directly resolvable by `DataRegistry`.
Per ADR-0022:

1. `DataRegistry` boot-scan rejects any content `.tres` without an `id` field —
   a bare `AudioStream` resource has none, so it would boot the registry into an
   ERROR state. (ADR-0016's "drop a bare AudioStream, no code change" migration
   note was **wrong**; ADR-0022 carries the correction.)
2. So each cue ships as an **`AudioCue`** (`GameData` subclass at
   `src/core/audio_router/audio_cue.gd`) `.tres` carrying the `id` +
   referencing the imported audio via `stream`. `AudioRouter` reads `.stream`
   through `_stream_from_resolved()`.
3. The `ExtResource` reference only binds once Godot has **imported** the audio
   (i.e. the `.wav`/`.ogg` has a `.import` sidecar). So the order is:
   **generate audio → import in Godot → `--author-tres`**.

`id` convention: the cue id is the `play_sfx`/`play_music` argument **without**
the `sfx_`/`music_` prefix. `play_sfx("sfx_ui_tap")` → cue id `ui_tap` →
`assets/data/sfx/ui_tap.tres` → stream `assets/audio/sfx/ui_tap.wav`.

Commit the `.import` sidecars alongside the audio + `.tres` in the same PR
(known Godot `.uid`/`.import` sidecar-tracking gotcha).

## Wiring status by asset category

Generating a file is not the same as the game *reading* it. Current consumer status:

| Category | Consumed by | Status |
|---|---|---|
| **SFX / music** | `AudioRouter` → `DataRegistry` (`assets/data/sfx\|music/<id>.tres`) | ✅ **Wired** — AudioCue resolve path lands this PR. |
| **Class portraits** | `ClassPortraitFactory` → `assets/art/classes/<id>/portrait.png` | ✅ Wired (path-exact) — but the dir is **gitignored** (see below). |
| **Enemy sprites** | `EnemySpriteFactory` → `assets/art/enemies/<id>/sprite.png` | ⚠️ Wired as a **single still** — the factory does **not** slice frames, so a 4-frame strip renders squashed. Animation needs `hframes` slicing added to the factory first. |
| **Biome backgrounds** | `BiomeBackground` (procedural `ColorRect`, hardcoded palette) | ❌ **Not wired** — nothing loads a background PNG. Needs a `ColorRect`→`Sprite2D`/`TextureRect` swap. Review-only. |
| **VFX particle textures** | `dungeon_run_view.gd` `VFX_BURST_TEXTURE_PATH` → `assets/art/demo/vfx/vfx_aura_a.png` | ❌ **Not wired** to the manifest path — the consumer loads a different (gitignored) file. Review-only until repointed. |

Audio is the only category that's fully land-ready this PR. The image categories
generate for **quality/style review**; backgrounds and VFX additionally need a
small wiring change before the generated file is read in-game.

## Gitignore caveat for art

`assets/art/classes/` and `assets/art/enemies/` are currently **gitignored** as
demo-IP placeholders. Committing real generated art to those paths requires
removing the matching `.gitignore` lines first — `generate.py --dry-run` prints
this reminder. Backgrounds (`assets/art/backgrounds/`) and VFX
(`assets/vfx/particles/`) are not gitignored.

## Known rough edges

- **ElevenLabs Music + Gemini image** endpoint/param shapes are best-effort and
  may need a one-line tweak on first real run (can't be tested without keys).
  The dry-run validates manifest + paths + prompts, not the live API contract.
- **Sprite strips**: Gemini is unreliable at clean, evenly-spaced animation
  frames. Expect manual reslicing of `enemy_sprites` strips to N×(cell) frames.
- **Audio import regeneration**: Godot won't always regenerate import output for
  changed-content/same-path assets — see the demo-asset import gotcha. If a
  re-generated file doesn't take, delete the compiled output + re-import.
