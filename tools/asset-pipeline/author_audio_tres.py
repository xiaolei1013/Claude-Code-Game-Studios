"""Authors an AudioCue .tres wrapper for a generated audio file.

Per ADR-0022, audio cues ship as `AudioCue` (GameData subclass) `.tres` files that
carry the DataRegistry `id` and reference the imported `.wav`/`.ogg` via `stream`.
DataRegistry boot-scan rejects a bare AudioStream .tres (no `id`), so the wrapper
is mandatory.

IMPORTANT: the referenced `.wav`/`.ogg` must already be IMPORTED by Godot (have a
`.import` sidecar) before the .tres will resolve at runtime — ResourceLoader can't
bind an un-imported AudioStream ExtResource. Generate audio first, import via the
Godot editor (or `godot --import`), then author the .tres.
"""

from __future__ import annotations

from pathlib import Path

AUDIO_CUE_SCRIPT = "res://src/core/audio_router/audio_cue.gd"

_TEMPLATE = '''[gd_resource type="Resource" script_class="AudioCue" load_steps=3 format=3]

[ext_resource type="Script" path="{script}" id="1_cue"]
[ext_resource type="AudioStream" path="{stream}" id="2_stream"]

[resource]
script = ExtResource("1_cue")
id = "{id}"
display_name = "{display}"
stream = ExtResource("2_stream")
'''


def _tres_escape(s: str) -> str:
    """Escape a value for a Godot .tres double-quoted string field.

    A raw quote or newline in `cue_id`/`display_name`/`stream_res_path` would
    otherwise break out of the field and corrupt the resource structure. (A bad
    `id` is still caught by DataRegistry's snake_case boot validation — this just
    keeps the .tres well-formed so that validation, not a parse error, reports it.)
    """
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", " ")


def author_audio_tres(out_tres: Path, cue_id: str, stream_res_path: str, display_name: str | None = None) -> None:
    """Write an AudioCue .tres at `out_tres` wrapping `stream_res_path`.

    `stream_res_path` must be a res:// path to the imported audio file
    (e.g. "res://assets/audio/sfx/ui_tap.wav").
    `cue_id` is the DataRegistry id (snake_case, WITHOUT the sfx_/music_ prefix).
    """
    out_tres.parent.mkdir(parents=True, exist_ok=True)
    text = _TEMPLATE.format(
        script=AUDIO_CUE_SCRIPT,
        stream=_tres_escape(stream_res_path),
        id=_tres_escape(cue_id),
        display=_tres_escape(display_name or cue_id),
    )
    out_tres.write_text(text, encoding="utf-8")


def res_path(repo_relative: str) -> str:
    """Convert a repo-relative path (e.g. assets/audio/sfx/ui_tap.wav) to res://."""
    return "res://" + repo_relative.lstrip("/")
