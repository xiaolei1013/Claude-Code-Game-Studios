#!/usr/bin/env python3
"""Lantern Guild asset-generation driver.

Reads a manifest (default: manifests/pilot.json) and generates audio (ElevenLabs)
+ images (Gemini), then authors AudioCue .tres wrappers for audio. Stdlib-only.

Usage:
    python3 tools/asset-pipeline/generate.py --dry-run            # plan, no API calls, no keys needed
    python3 tools/asset-pipeline/generate.py                      # generate the whole pilot manifest
    python3 tools/asset-pipeline/generate.py --only sfx           # one section
    python3 tools/asset-pipeline/generate.py --manifest manifests/full.json

Sections: audio (sfx, music), images (backgrounds, portraits, enemy_sprites, class_sprites, class_action_sprites, vfx, ui).

NOTE: endpoint/param details for the ElevenLabs Music API and the Gemini image
model are best-effort and may need a one-line tweak on first real run (we can't
test them without keys). The dry-run validates manifest + paths + prompts.
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from functools import cache
from pathlib import Path

import _common as C

ELEVENLABS_SFX_URL = "https://api.elevenlabs.io/v1/sound-generation"
ELEVENLABS_MUSIC_URL = "https://api.elevenlabs.io/v1/music"

# Two Google image surfaces, chosen by the key's shape (not its env-var name):
#   * Gemini Developer API — keys start "AIza".
#   * Vertex AI express mode — keys start "AQ." (or a gcloud OAuth token "ya29.").
# Both accept the credential via the x-goog-api-key header and return the same
# generateContent response shape (candidates[].content.parts[].inlineData).
GEMINI_DEV_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
VERTEX_EXPRESS_URL = "https://aiplatform.googleapis.com/v1beta1/publishers/google/models/{model}:generateContent"


def _is_vertex_key(api_key: str) -> bool:
    """True if the Google credential targets Vertex AI express, not the Gemini Developer API.

    Vertex express keys start "AQ."; gcloud OAuth access tokens start "ya29.".
    Gemini Developer API keys start "AIza" and use the generativelanguage host.
    """
    return api_key.startswith("AQ.") or api_key.startswith("ya29.")


def _partial_path(out: Path) -> Path:
    """Sibling temp path for an atomic-swap write that KEEPS the real media suffix.

    ffmpeg picks its output muxer from the filename extension, so the temp must
    end in the true suffix (`ui_tap.partial.wav`, not `ui_tap.wav.partial`) — a
    bare `.partial` tail leaves ffmpeg unable to choose a container and the write
    fails before any bytes land. `--skip-existing` only ever inspects the
    canonical path, so a stray `.partial.<ext>` is never mistaken for a finished
    asset (and the finally-block unlinks it regardless).
    """
    return out.with_name(f"{out.stem}.partial{out.suffix}")


# ---------------------------------------------------------------------------
# Audio — ElevenLabs
# ---------------------------------------------------------------------------

def _pcm_rate(fmt: str) -> int:
    # "pcm_44100" -> 44100; default 44100.
    try:
        return int(fmt.split("_")[-1])
    except (ValueError, IndexError):
        return 44100


def gen_sfx(entry: dict, keys: dict) -> None:
    out_wav = C.repo_path(entry["out_wav"])
    fmt = keys["ELEVENLABS_SFX_OUTPUT_FORMAT"]
    url = f"{ELEVENLABS_SFX_URL}?output_format={fmt}"
    headers = {"xi-api-key": keys["ELEVENLABS_API_KEY"]}
    payload = {
        "text": entry["prompt"],
        "duration_seconds": float(entry.get("duration_seconds", 1.0)),
        "prompt_influence": float(entry.get("prompt_influence", 0.3)),
    }
    status, data, _ = C.http_post_json_with_retry(url, headers, payload, label=entry["id"])
    if status != 200:
        raise RuntimeError(f"ElevenLabs SFX {entry['id']} -> HTTP {status}: {data[:300]!r}")

    C.ensure_parent(out_wav)
    # Write to a sibling .partial then atomically swap into place (both branches):
    # a crash mid-write leaves only .partial, never a truncated .wav at the
    # canonical path that a later --skip-existing run would treat as done.
    part = _partial_path(out_wav)
    if fmt.startswith("pcm_"):
        # ElevenLabs sound-generation returns 16-bit LE *stereo* PCM (verified:
        # pcm_44100 byte counts match 44.1kHz × 2ch exactly). Wrap with 2 channels
        # — a mono header reads 2× long and plays the interleaved samples garbled.
        # NOTE: this yields a STEREO wav; prefer the mp3 default for the ADR's mono
        # target (ffmpeg downmixes below; the wave module can't — no audioop in 3.13+).
        try:
            with wave.open(str(part), "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(_pcm_rate(fmt))
                w.writeframes(data)
            part.replace(out_wav)
        finally:
            part.unlink(missing_ok=True)
    else:
        # mp3/other — write raw, then transcode to a deterministic mono 44.1kHz
        # 16-bit WAV (ADR-0022 §C.6) via ffmpeg, which reads the true channel/rate
        # from the container. try/finally so a transcode failure doesn't leave the
        # .raw_audio temp or .partial behind (mirrors gen_music's temp cleanup).
        tmp = out_wav.with_suffix(".raw_audio")
        tmp.write_bytes(data)
        try:
            _ffmpeg(["-i", str(tmp), "-ar", "44100", "-ac", "1", str(part)])
            part.replace(out_wav)
        finally:
            tmp.unlink(missing_ok=True)
            part.unlink(missing_ok=True)
    C.log(f"  ✓ SFX  {entry['id']:<22} -> {entry['out_wav']}  ({len(data)} bytes)")


def gen_music(entry: dict, keys: dict) -> None:
    out_ogg = C.repo_path(entry["out_ogg"])
    fmt = keys["ELEVENLABS_MUSIC_OUTPUT_FORMAT"]
    url = f"{ELEVENLABS_MUSIC_URL}?output_format={fmt}"
    headers = {"xi-api-key": keys["ELEVENLABS_API_KEY"]}
    payload = {
        "prompt": entry["prompt"],
        "music_length_ms": int(entry.get("music_length_ms", 30000)),
    }
    status, data, _ = C.http_post_json_with_retry(url, headers, payload, label=entry["id"], timeout=300)
    if status != 200:
        raise RuntimeError(f"ElevenLabs music {entry['id']} -> HTTP {status}: {data[:300]!r}")

    # Transcode the returned mp3 to .ogg (Vorbis ~Q5 stereo per §C.6) via ffmpeg.
    C.ensure_parent(out_ogg)
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tf:
        tf.write(data)
        tmp_mp3 = tf.name
    # Atomic swap: a crash mid-transcode leaves .partial, never a truncated .ogg
    # at the canonical path that a later --skip-existing run would treat as done.
    part = _partial_path(out_ogg)
    try:
        _ffmpeg(["-i", tmp_mp3, *_vorbis_encoder_args(), str(part)])
        part.replace(out_ogg)
    finally:
        Path(tmp_mp3).unlink(missing_ok=True)
        part.unlink(missing_ok=True)
    C.log(f"  ✓ MUSIC {entry['id']:<21} -> {entry['out_ogg']}  ({len(data)} bytes mp3 -> ogg)")


@cache
def _vorbis_encoder_args() -> list[str]:
    """ffmpeg args to encode Ogg Vorbis, preferring libvorbis but falling back to
    the native (experimental) `vorbis` encoder when the build lacks libvorbis.

    Some ffmpeg builds (incl. this project's Homebrew ffmpeg 8.1) ship without
    libvorbis. The native encoder is lower quality but always available, requires
    `-strict -2`, and still yields a Godot-importable AudioStreamOggVorbis with
    gapless looping — the right target for a loopable music bed (mp3 has frame
    padding that breaks seamless loops; Godot has no Opus-in-Ogg importer).

    @cache: the available encoders don't change within a run, so probe ffmpeg once
    (not once per music bed — 10× the subprocess spawns at full-bank scale).
    """
    try:
        enc = subprocess.run(
            ["ffmpeg", "-hide_banner", "-encoders"],
            capture_output=True, text=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        enc = ""
    if "libvorbis" in enc:
        return ["-c:a", "libvorbis", "-q:a", "5"]
    return ["-c:a", "vorbis", "-strict", "-2", "-q:a", "5"]


def _ffmpeg(args: list[str]) -> None:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg not found on PATH — required for music transcode.")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], check=True)


# ---------------------------------------------------------------------------
# Images — Gemini
# ---------------------------------------------------------------------------

def gen_image(entry: dict, keys: dict) -> None:
    out = C.repo_path(entry["out"])
    model = keys["GEMINI_IMAGE_MODEL"]
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", model):
        # `model` is interpolated into the request URL path — keep it a bare
        # model identifier so a malformed config value can't rewrite the URL.
        raise RuntimeError(f"unsafe GEMINI_IMAGE_MODEL {model!r}: expected a bare model id.")
    api_key = keys["GEMINI_API_KEY"]
    url_tmpl = VERTEX_EXPRESS_URL if _is_vertex_key(api_key) else GEMINI_DEV_URL
    url = url_tmpl.format(model=model)
    # A gcloud OAuth access token ("ya29.") is NOT an API key: Vertex rejects it
    # in x-goog-api-key and requires Bearer auth. Express keys ("AQ.") and Gemini
    # Developer keys ("AIza") authenticate via x-goog-api-key as usual.
    if api_key.startswith("ya29."):
        headers = {"Authorization": f"Bearer {api_key}"}
    else:
        headers = {"x-goog-api-key": api_key}

    # Isolated assets (vfx/icons/portraits/sprites) get the asset prefix + a flat
    # chroma background we key to alpha in post; scenes get the diorama prefix.
    # `style:"ui"` opts into the flat surface-texture prefix (parchment sheets,
    # button fills) — these stay OPAQUE (isolated:false), so post-process scales
    # them to size without colour-keying, exactly like a scene backdrop.
    isolated = bool(entry.get("isolated", False))
    if entry.get("style") == "ui":
        prefix = C.STYLE_PREFIX_UI
    else:
        prefix = C.STYLE_PREFIX_ISOLATED if isolated else C.STYLE_PREFIX_SCENE
    full_prompt = prefix + entry["prompt"]
    # No size hint in the prompt — Flash-Image ignores it (always ~1024²); we
    # downscale to `entry["size"]` deterministically in _postprocess_image.

    # An image-capable model must be told to emit an IMAGE part, not just TEXT.
    # Vertex requires an explicit content role ("user"/"model"); omitting it 400s
    # with "Please use a valid role".
    gen_cfg: dict = {"responseModalities": ["TEXT", "IMAGE"]}
    aspect = entry.get("aspect_ratio")
    if aspect:
        # Best-effort: ask the model to COMPOSE for this ratio (still returns
        # ~1024², but framed for it); post-process crops to the exact pixels.
        gen_cfg["imageConfig"] = {"aspectRatio": aspect}
    payload = {
        "contents": [{"role": "user", "parts": [{"text": full_prompt}]}],
        "generationConfig": gen_cfg,
    }

    status, data, _ = C.http_post_json_with_retry(url, headers, payload, label=entry["id"], timeout=180)
    if status != 200:
        raise RuntimeError(f"Gemini image {entry['id']} -> HTTP {status}: {data[:300]!r}")

    resp = json.loads(data.decode("utf-8"))
    png = _extract_inline_image(resp)
    if png is None:
        raise RuntimeError(f"Gemini image {entry['id']}: no inline image in response{_block_reason(resp)}.")
    C.ensure_parent(out)
    processed = _postprocess_image(png, out, isolated=isolated, size=entry.get("size", ""))
    tail = " → keyed+scaled" if processed else ""
    C.log(f"  ✓ IMG  {entry['id']:<22} -> {entry['out']}  ({len(png)} bytes raw{tail})")


def _parse_size(size: str) -> tuple[int, int] | None:
    """'1920x1080' -> (1920, 1080); None if absent/malformed."""
    m = re.fullmatch(r"\s*(\d+)\s*[xX]\s*(\d+)\s*", size or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


def _png_dims(path: Path) -> tuple[int, int] | None:
    """Read (width, height) from a PNG IHDR; None if not a readable PNG."""
    try:
        head = path.read_bytes()[:24]
    except OSError:
        return None
    if head[:8] != b"\x89PNG\r\n\x1a\n" or len(head) < 24:
        return None
    return struct.unpack(">II", head[16:24])


def _should_skip(entry: dict, parent: str, out_key: str) -> bool:
    """For --skip-existing: True only when the output already exists AS A REAL ASSET.

    Audio: any existing file at the path counts — a generated wav/ogg is the only
    thing that writes there. Images: the gitignored demo-IP placeholders live at
    the SAME paths as the real art (assets/art/classes|enemies/<id>/...), so mere
    existence is not enough — a placeholder is tiny (e.g. 96×96). We skip only when
    the on-disk PNG already matches the manifest's target dimensions; a mismatch
    means 'still a placeholder' and the asset is (re)generated, overwriting it
    (overwrite, not delete — a mid-batch failure leaves the placeholder as a fallback).
    """
    out_rel = entry.get(out_key, "")
    if not out_rel:
        return False
    path = C.repo_path(out_rel)
    if not path.exists():
        return False
    if parent != "images":
        return True
    target = _parse_size(entry.get("size", ""))
    dims = _png_dims(path)
    if target is None or dims is None:
        return True  # can't compare dimensions — treat existence as done
    return dims == target


def _detect_bg_color(src_png: str) -> str | None:
    """Sample the four corners of the model's output; return the backdrop colour
    as 'RRGGBB' when they agree (flat, uniform backdrop), else None.

    Gemini Flash-Image ignores a requested key COLOUR — it repaints a muted
    backdrop of its own choosing — so we detect the colour it actually produced
    rather than assuming one. None means the corners disagree (the subject bleeds
    to an edge, or the backdrop has a gradient/vignette); keying then would eat
    subject pixels, so the caller leaves the asset opaque for manual cutout.
    """
    dims = _png_dims(Path(src_png))
    if dims is None:  # unreadable/not-a-PNG — can't sample corners, leave opaque
        return None
    w, h = dims
    box = max(8, min(w, h) // 64)  # ~16px on a 1024² image
    corners = [(0, 0), (w - box, 0), (0, h - box), (w - box, h - box)]
    means: list[tuple[float, float, float]] = []
    for x, y in corners:
        try:
            out = subprocess.run(
                ["ffmpeg", "-v", "error", "-i", src_png,
                 "-vf", f"crop={box}:{box}:{x}:{y}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                capture_output=True, check=True,
            ).stdout
        except (OSError, subprocess.CalledProcessError):
            # ffmpeg missing or refused this PNG — honour the docstring's "None
            # means leave opaque" contract instead of aborting the whole asset.
            return None
        n = len(out) // 3
        if n == 0:
            return None
        means.append((sum(out[0::3]) / n, sum(out[1::3]) / n, sum(out[2::3]) / n))
    # Corners must agree per channel, else the backdrop isn't a flat keyable colour.
    for ch in range(3):
        vals = [m[ch] for m in means]
        if max(vals) - min(vals) > 26:
            return None
    r, g, b = (round(sum(m[ch] for m in means) / len(means)) for ch in range(3))
    return f"{r:02X}{g:02X}{b:02X}"


def _postprocess_image(png: bytes, out: Path, *, isolated: bool, size: str) -> bool:
    """Key the detected background to alpha (isolated assets) and/or downscale.

    Gemini returns an opaque ~1024² RGB PNG. For isolated assets we auto-detect
    the flat backdrop colour (corner sampling) and colorkey it to real alpha; for
    every asset with a `size` we scale to the target. With neither applicable the
    raw PNG is written unchanged. Uses ffmpeg (already required for audio) to keep
    the Python side stdlib-only. Returns True if ffmpeg post-processing ran.
    """
    dims = _parse_size(size)
    # Write to a sibling .partial then atomically swap in (mirrors gen_sfx/gen_music):
    # a crash mid-ffmpeg or mid-write leaves only .partial, never a truncated PNG
    # that --skip-existing would later mistake for a finished, correctly-sized asset.
    part = _partial_path(out)
    if not isolated and dims is None:
        part.write_bytes(png)  # opaque, native size — nothing to do
        part.replace(out)
        return False

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tf:
        tf.write(png)
        tmp_in = tf.name
    try:
        filters: list[str] = []
        if isolated:
            bg = _detect_bg_color(tmp_in)
            if bg:
                # Key the backdrop the model ACTUALLY painted. similarity 0.14
                # catches dither/AA noise without eating subject pixels; blend
                # 0.10 softens the cutout edge.
                filters.append(f"colorkey=0x{bg}:0.14:0.10")
                filters.append("format=rgba")
            else:
                C.log(f"  …  {out.name}: backdrop not flat/uniform — left opaque (manual cutout needed)")
        if dims is not None:
            w, h = dims
            if isolated:
                # square subject -> square target: plain scale, no distortion.
                filters.append(f"scale={w}:{h}:flags=lanczos")
            else:
                # scene -> exact target without stretching: fill then centre-crop.
                filters.append(f"scale={w}:{h}:force_original_aspect_ratio=increase:flags=lanczos")
                filters.append(f"crop={w}:{h}")
        if not filters:  # isolated, no size, backdrop not keyable -> raw passthrough
            part.write_bytes(png)
            part.replace(out)
            return False
        _ffmpeg(["-i", tmp_in, "-vf", ",".join(filters), "-frames:v", "1", str(part)])
        part.replace(out)
    finally:
        Path(tmp_in).unlink(missing_ok=True)
        part.unlink(missing_ok=True)  # no-op after a successful replace
    return True


def _extract_inline_image(resp: dict) -> bytes | None:
    for cand in resp.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            blob = part.get("inlineData") or part.get("inline_data")
            if blob and blob.get("data"):
                return base64.b64decode(blob["data"])
    return None


def _block_reason(resp: dict) -> str:
    """Surface WHY a 200 response carried no image. Safety/prohibited blocks
    return HTTP 200 with no inline data, so a bare 'no image' hides the cause —
    and the call was still billed. Returns a ' (…)' suffix for the error message,
    or '' when no block signal is present."""
    bits: list[str] = []
    block = resp.get("promptFeedback", {}).get("blockReason")
    if block:
        bits.append(f"promptFeedback.blockReason={block}")
    for cand in resp.get("candidates", []):
        fr = cand.get("finishReason")
        if fr and fr not in ("STOP", "MAX_TOKENS"):
            bits.append(f"finishReason={fr}")
    return f" ({'; '.join(bits)})" if bits else ""


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def _author_tres_for_audio(manifest: dict, only: str | None = None) -> None:
    """After audio files exist + are imported, author the AudioCue .tres wrappers.

    Honours --only: `--only sfx` / `--only music` authors wrappers for just that
    section, matching the run that generated the audio. Without this, a partial
    run would emit .tres cues pointing at audio that was never generated/imported
    (a stray or null-stream cue waiting to be committed).
    """
    from author_audio_tres import author_audio_tres, res_path

    # sfx point at .wav, music at .ogg; the .tres-authoring body is otherwise identical.
    for section, out_key in (("sfx", "out_wav"), ("music", "out_ogg")):
        if not _wanted(section, "audio", only):
            continue
        for entry in manifest.get("audio", {}).get(section, []):
            entry_id = entry.get("id")
            out_tres = entry.get("out_tres")
            stream_out = entry.get(out_key)
            # Skip a malformed entry instead of KeyError-aborting the whole pass —
            # one bad row shouldn't strand the .tres wrappers for every other cue.
            if not entry_id or not out_tres or not stream_out:
                C.log(f"  …  .tres skipped for {entry.get('id', '?')}: missing id/out_tres/{out_key}")
                continue
            author_audio_tres(C.repo_path(out_tres), entry_id, res_path(stream_out))
            C.log(f"  ✓ .tres {entry_id:<21} -> {out_tres}")


# Single source of truth for the 6 asset sections. Each row:
#   (section, parent, handler, dry_run_formatter, out_key)
# `parent` doubles as the manifest top-level key ("audio"/"images") AND the
# --only group name, so both dry_run() and run() iterate this one table instead
# of repeating the section list (and the inverse of its --only gate) twice.
# `out_key` is the manifest field holding the primary output path — used by
# --skip-existing to detect an already-generated asset.

def _fmt_sfx(it: dict) -> str:
    return f"  - {it['id']:<20} -> {it['out_wav']}  ({it.get('duration_seconds','?')}s)\n      “{it['prompt'][:90]}…”"


def _fmt_music(it: dict) -> str:
    return f"  - {it['id']:<20} -> {it['out_ogg']}  ({it.get('music_length_ms','?')}ms)\n      “{it['prompt'][:90]}…”"


def _fmt_image(it: dict) -> str:
    return f"  - {it['id']:<20} -> {it['out']}  ({it.get('size','?')})"


_SECTIONS = [
    # (section,         parent,   handler,   formatter,   out_key)
    ("sfx",            "audio",  gen_sfx,   _fmt_sfx,    "out_wav"),
    ("music",          "audio",  gen_music, _fmt_music,  "out_ogg"),
    ("backgrounds",    "images", gen_image, _fmt_image,  "out"),
    ("portraits",      "images", gen_image, _fmt_image,  "out"),
    ("enemy_sprites",  "images", gen_image, _fmt_image,  "out"),
    ("class_sprites",  "images", gen_image, _fmt_image,  "out"),
    ("class_action_sprites", "images", gen_image, _fmt_image, "out"),
    ("vfx",            "images", gen_image, _fmt_image,  "out"),
    ("ui",             "images", gen_image, _fmt_image,  "out"),
]

# Which API credential each manifest parent needs. Used to require ONLY the
# key(s) for the sections actually in scope, so `--only sfx`/`--only music`
# doesn't demand a Gemini key (and `--only images` doesn't demand an ElevenLabs
# key). A full run — no --only — needs both.
_PARENT_KEY = {"audio": "ELEVENLABS_API_KEY", "images": "GEMINI_API_KEY"}


def _wanted(section: str, parent: str, only: str | None) -> bool:
    """True if --only admits this section (None = all sections)."""
    return only is None or only in (section, parent)


def dry_run(manifest: dict, only: str | None) -> None:
    C.log("DRY RUN — no API calls, no files written.\n")
    total = 0
    for section, parent, _handler, fmt, _out_key in _SECTIONS:
        if not _wanted(section, parent, only):
            continue
        items = manifest.get(parent, {}).get(section, [])
        if not items:
            continue
        C.log(f"[{section}] {len(items)} asset(s):")
        for it in items:
            total += 1
            C.log(fmt(it))
        C.log("")

    C.log(f"Total: {total} asset(s) would be generated.")
    C.log("NOTE: assets/art/classes/ and assets/art/enemies/ are gitignored as demo")
    C.log("      placeholders — committing real art there needs the .gitignore lines removed.")


def run(manifest: dict, only: str | None, keys: dict, skip_existing: bool = False) -> int:
    # Sections run sequentially — fine for the pilot (6 assets). For the full
    # bank (~70 calls) consider a bounded ThreadPoolExecutor with a rate-limit
    # semaphore (ElevenLabs ~few req/s, Gemini ~req/min); kept serial here to
    # stay simple and avoid tripping provider rate limits during review.
    # Per-asset isolation: the music + image endpoints are best-effort, so a
    # failure on one asset is logged and the rest of the batch still runs.
    # --skip-existing skips any asset whose output already exists: it protects
    # already-approved assets from non-deterministic regeneration and makes a
    # large batch resumable after a timeout/crash (re-run picks up where it left).
    failures: list[str] = []
    for section, parent, handler, _fmt, out_key in _SECTIONS:
        if not _wanted(section, parent, only):
            continue
        for entry in manifest.get(parent, {}).get(section, []):
            asset_id = entry.get("id", "?")
            if skip_existing and _should_skip(entry, parent, out_key):
                C.log(f"  ⏭  SKIP {section}/{asset_id:<18} (exists)")
                continue
            try:
                handler(entry, keys)
            except Exception as e:  # noqa: BLE001 — surface, don't abort the batch
                failures.append(f"{section}/{asset_id}: {e}")
                C.log(f"  ✗ FAIL {section}/{asset_id}: {e}")

    # The audio next-step reminder is a function of whether audio was IN SCOPE
    # for this run (what was asked for) — derived from _SECTIONS, the file's
    # source of truth for structure — not of whether a call happened to succeed.
    # .tres wrappers are authored separately AFTER Godot imports the audio files
    # (ResourceLoader needs the .import sidecar): run --author-tres once imported.
    audio_in_scope = any(
        _wanted(section, parent, only) and manifest.get(parent, {}).get(section)
        for section, parent, _h, _f, _ok in _SECTIONS
        if parent == "audio"
    )
    if audio_in_scope:
        C.log("\nNext step for audio: import the generated .wav/.ogg in Godot, then run "
              "with --author-tres to write the AudioCue .tres wrappers.")

    if failures:
        C.log(f"\n{len(failures)} asset(s) FAILED:")
        for f in failures:
            C.log(f"  - {f}")
        return 1
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Lantern Guild asset generation")
    ap.add_argument("--manifest", default=str(Path(__file__).parent / "manifests" / "pilot.json"))
    ap.add_argument("--only", choices=["audio", "images", "sfx", "music", "backgrounds", "portraits", "enemy_sprites", "class_sprites", "vfx", "ui"])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--author-tres", action="store_true", help="Only author AudioCue .tres wrappers (run after audio is imported).")
    ap.add_argument("--skip-existing", action="store_true", help="Skip assets whose output file already exists (protects approved assets; makes a large batch resumable).")
    args = ap.parse_args(argv)

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    keys = load_and_report_keys()

    if args.dry_run:
        dry_run(manifest, args.only)
        return 0

    if args.author_tres:
        _author_tres_for_audio(manifest, args.only)
        return 0

    # Require only the credential(s) for the sections actually in scope: an
    # audio-only run (--only sfx/music/audio) needs just the ElevenLabs key, an
    # image-only run just the Gemini key, a full run both. Mirrors run()'s own
    # _wanted() gating so the requirement matches what will actually be called.
    required = sorted({
        _PARENT_KEY[parent]
        for _section, parent, *_rest in _SECTIONS
        if _wanted(_section, parent, args.only)
    })
    missing = [k for k in required if not keys[k]]
    if missing:
        C.log(f"\nERROR: missing keys: {', '.join(missing)}.")
        C.log("Add them to .secrets/keys.env (see .secrets/keys.env.example) or export them, then re-run.")
        C.log("(Use --dry-run to validate the manifest without keys.)")
        return 2

    return run(manifest, args.only, keys, skip_existing=args.skip_existing)


def load_and_report_keys() -> dict:
    keys = C.load_keys()
    C.log("API key status:")
    C.log(C.key_status(keys))
    C.log("")
    return keys


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
