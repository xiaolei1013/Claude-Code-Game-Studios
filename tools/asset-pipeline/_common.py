"""Shared helpers for the Lantern Guild asset-generation pipeline.

Key handling, HTTP, palette/style constants, and repo-path resolution. Uses only
the Python standard library (no pip install needed) so the pipeline runs from a
clean checkout. API keys are read for SET/UNSET + length checks only — their
values are never printed or logged.

See tools/asset-pipeline/README.md and docs/architecture/ADR-0022-*.md.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# Repo paths
# ---------------------------------------------------------------------------

# tools/asset-pipeline/_common.py -> repo root is two parents up.
REPO_ROOT = Path(__file__).resolve().parents[2]
SECRETS_ENV = REPO_ROOT / ".secrets" / "keys.env"
DOTENV = REPO_ROOT / ".env"  # repo-root .env (gitignored) — the user's keys live here.


# ---------------------------------------------------------------------------
# Lantern Guild visual identity (DESIGN.md / design/art/art-bible.md)
# ---------------------------------------------------------------------------

# The locked palette lives in DESIGN.md; it is inlined (named + hex) directly in
# the prompt prefixes below because the image model reads the prompt text. A
# separate palette constant would only drift from the strings that matter.

# Two prompt prefixes. The pilot proved a single scene-rich prefix overwhelms
# isolated-asset subjects (asked for one particle, got a whole village diorama),
# so backgrounds/scenes and isolated assets (vfx, icons, portraits, sprites) get
# different prefixes. Per-asset prompts carry the subject; keep both terse.

# Backgrounds / full-scene dioramas — rich, atmospheric, fills the frame.
STYLE_PREFIX_SCENE = (
    "Lantern-Lit Pixel Diorama, HD-2D cozy fantasy. Warm hand-painted pixel-art "
    "look with soft lantern glow and gentle tilt-shift depth. Locked palette: "
    "Guild Amber #C8872A, Lantern Gold #F2B83B, Parchment Cream #EDE0C4, "
    "Dusk Purple #5B4A72, Moss Sage #7A8C5E, Ember Rust #A84C2F, Slate Ink "
    "#2C2838. No text, no watermark, no UI chrome. "
)

# Isolated assets — single centred object on a flat, uniform backdrop that the
# post-process auto-detects (corner sampling) and keys to alpha. Flash-Image
# IGNORES a requested key colour (it repaints a muted backdrop of its own
# choosing) but reliably honours "flat & uniform", which is all the keyer needs.
# "ONE object only / no extra objects" is load-bearing: without it the model
# illustrates the game concept (asked for a gold-spark particle, drew a treasure
# chest). Short and asset-focused so the subject wins.
STYLE_PREFIX_ISOLATED = (
    "Single game asset, ONE object only — no extra objects, no scene — centred "
    "and filling most of the frame, on a perfectly FLAT, UNIFORM, plain "
    "solid-colour backdrop with no gradient, no vignette, no scenery, no ground "
    "plane, no cast shadow and no border. Warm hand-painted cozy-fantasy "
    "pixel-art look with soft lantern glow. Locked palette for the SUBJECT: "
    "Guild Amber #C8872A, Lantern Gold #F2B83B, Parchment Cream #EDE0C4, "
    "Dusk Purple #5B4A72, Moss Sage #7A8C5E, Ember Rust #A84C2F, Slate Ink "
    "#2C2838. No text, no watermark, no UI frame. "
)


# ---------------------------------------------------------------------------
# API keys
# ---------------------------------------------------------------------------

def _parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        out[key.strip()] = val.strip().strip('"').strip("'")
    return out


def load_keys() -> dict[str, str]:
    """Return a dict of pipeline config/keys.

    Resolution per key: os.environ first, then `.secrets/keys.env`, then the
    repo-root `.env`. `pick` accepts several names so a single canonical key can
    be supplied under any of its accepted aliases (e.g. the Google image key may
    arrive as GEMINI_API_KEY, GOOGLE_API_KEY, or VERTEX_API_KEY).
    Empty strings are treated as unset.
    """
    secrets_vals = _parse_env_file(SECRETS_ENV)
    dotenv_vals = _parse_env_file(DOTENV)

    def pick(*names: str, default: str = "") -> str:
        for name in names:
            v = (os.environ.get(name) or secrets_vals.get(name) or dotenv_vals.get(name) or "").strip()
            if v:
                return v
        return default

    return {
        "ELEVENLABS_API_KEY": pick("ELEVENLABS_API_KEY"),
        # AQ.-prefixed VERTEX_API_KEY (Vertex AI express) and AIza-prefixed
        # GEMINI/GOOGLE keys are interchangeable as the Google image credential;
        # generate.py picks the endpoint from the key shape, not the name.
        "GEMINI_API_KEY": pick("GEMINI_API_KEY", "GOOGLE_API_KEY", "VERTEX_API_KEY"),
        "GEMINI_IMAGE_MODEL": pick("GEMINI_IMAGE_MODEL", default="gemini-2.5-flash-image"),
        # mp3 (not pcm) by default: ElevenLabs sound-generation returns *stereo*
        # PCM with no header, so raw pcm can't be reliably downmixed to the ADR's
        # mono target (Python 3.13+ removed audioop). mp3 carries channel/rate
        # metadata, so ffmpeg transcodes it to a correct mono 44.1kHz WAV.
        "ELEVENLABS_SFX_OUTPUT_FORMAT": pick("ELEVENLABS_SFX_OUTPUT_FORMAT", default="mp3_44100_128"),
        "ELEVENLABS_MUSIC_OUTPUT_FORMAT": pick("ELEVENLABS_MUSIC_OUTPUT_FORMAT", default="mp3_44100_128"),
    }


def key_status(keys: dict[str, str]) -> str:
    """Human-readable SET/UNSET + length summary — never reveals the value."""
    lines = []
    for name in ("ELEVENLABS_API_KEY", "GEMINI_API_KEY"):
        v = keys.get(name, "")
        lines.append(f"  {name}: {'SET (len ' + str(len(v)) + ')' if v else 'UNSET'}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# HTTP (stdlib)
# ---------------------------------------------------------------------------

def http_post(url: str, headers: dict[str, str], body: bytes, timeout: int = 180) -> tuple[int, bytes, dict]:
    """POST raw bytes. Returns (status, response_bytes, response_headers).

    Raises on network errors; HTTP error responses are returned with their
    status + body so callers can surface the API's message.
    """
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read(), dict(resp.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers or {})


def http_post_json(url: str, headers: dict[str, str], payload: dict, timeout: int = 180) -> tuple[int, bytes, dict]:
    h = dict(headers)
    h.setdefault("Content-Type", "application/json")
    return http_post(url, h, json.dumps(payload).encode("utf-8"), timeout=timeout)


# Statuses worth retrying: 429 (rate limit — Vertex express RESOURCE_EXHAUSTED
# *and* ElevenLabs burst throttling, both per-minute windows that clear on their
# own) and the transient 5xx the backends return under load. A flat 4xx
# (400/401/403) is a request/credential bug — backing off wouldn't change it.
RETRYABLE_STATUS = frozenset({429, 500, 503})


def http_post_json_with_retry(url: str, headers: dict[str, str], payload: dict, *, label: str,
                              timeout: int = 180, max_attempts: int = 6, base_delay: int = 20) -> tuple[int, bytes, dict]:
    """POST JSON, backing off and retrying on transient rate-limit / 5xx statuses.

    Shared by every generator: a serial bank of 40+ images trips Vertex's
    RESOURCE_EXHAUSTED, and the ElevenLabs SFX/music endpoints throttle the same
    way under burst. Honours a Retry-After header when present, else exponential
    backoff (base_delay → 2× → … 120s cap). Returns the final (status, body,
    headers); the caller still handles a terminal non-200 so one exhausted asset
    doesn't abort the batch. A retried 429/5xx returns no media, so it costs no
    API credits — retrying is free resilience.
    """
    delay = base_delay
    for attempt in range(1, max_attempts + 1):
        status, data, resp_headers = http_post_json(url, headers, payload, timeout=timeout)
        if status not in RETRYABLE_STATUS or attempt == max_attempts:
            return status, data, resp_headers
        wait = delay
        retry_after = resp_headers.get("Retry-After") or resp_headers.get("retry-after")
        if retry_after:
            try:
                wait = max(wait, int(float(retry_after)))
            except ValueError:
                pass
        log(f"  ⏳ {label}: HTTP {status} (rate-limited) — backoff {wait}s (attempt {attempt}/{max_attempts - 1})")
        time.sleep(wait)
        delay = min(delay * 2, 120)
    return status, data, resp_headers  # pragma: no cover (loop always returns above)


# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

def repo_path(rel: str) -> Path:
    """Resolve a manifest-relative output path under REPO_ROOT, rejecting escapes.

    Output paths come from the manifest JSON. A bare ``REPO_ROOT / rel`` would
    write anywhere on disk if ``rel`` were absolute (``Path`` drops the base on
    an absolute right operand) or contained ``../`` segments. Resolving and then
    checking containment keeps every generated file inside the repo.
    Raises ValueError if the path escapes the repo root.
    """
    resolved = (REPO_ROOT / rel).resolve()
    if not resolved.is_relative_to(REPO_ROOT):
        raise ValueError(f"output path escapes repo root: {rel!r}")
    return resolved


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)
