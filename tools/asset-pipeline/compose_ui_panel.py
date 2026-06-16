#!/usr/bin/env python3
"""Compose a Godot 9-patch panel texture from a Gemini-generated parchment fill.

The image model reliably paints a warm painterly parchment *material* but cannot
produce a clean, 9-patch-safe frame: it bows the edges (pillow/cushion shape) and
paints opaque near-white corners. A Godot ``StyleBoxTexture`` 9-patch needs
STRAIGHT edges (the edge slices stretch along their axis — a bowed edge smears)
and TRANSPARENT outside-corners (so panels read as rounded on any background).

So we split the work by what each tool does well:

  * Gemini  -> the painterly parchment grain/warmth (the FILL).
  * this    -> a deterministic crisp ink frame with rounded, transparent corners
               (the GEOMETRY), at the exact DESIGN.md panel tokens.

This keeps DESIGN.md's *precise* tokens (Slate Ink #2C2838 border, 6 px radius,
2 px thickness) AND the art bible's *visual direction* (a real parchment texture)
without either overriding the other — and it resolves OQ-DS-02 toward "static PNG
texture". See docs/architecture/ADR-0023 and the matching DESIGN.md note.

Input  : a raw parchment PNG under tools/asset-pipeline/sources/ (Godot-ignored
         via .gdignore, so raws never spawn .import sidecars).
Output : an RGBA PNG under assets/art/ui/ — the wired 9-patch (committed + imported).

Set the StyleBoxTexture's four texture_margins to ``MARGIN`` (px) so the rounded
corners stay fixed while the centre/edges stretch.

Requires Pillow (an explicit dep of THIS optional post-step only — the core
generate.py pipeline remains stdlib-only)::

    python3 tools/asset-pipeline/compose_ui_panel.py [SRC.png] [OUT.png]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]

# --- DESIGN.md panel tokens (see DESIGN.md §"Panel style") ------------------
SLATE_INK = (44, 40, 56, 255)  # #2C2838 — replaces black everywhere
SIZE = 256                     # output texture px (square)
RADIUS = 6                     # corner radius px (DESIGN.md panel token)
BORDER = 2                     # ink border thickness px (ParchmentPanel/HeroCard variant)
MARGIN = 14                    # 9-patch texture_margin px (>= RADIUS + BORDER); set in the .tres
CROP_FRAC = 0.60               # centre crop of the raw — drops the model's pillowy painted edge
SS = 4                         # supersample factor for crisp antialiased mask + frame

DEFAULT_SRC = "tools/asset-pipeline/sources/ui_panel_parchment_src.png"
DEFAULT_OUT = "assets/art/ui/ui_panel_parchment.png"


def _rounded_mask(size: int, radius: int, ss: int) -> Image.Image:
    """Antialiased rounded-rect alpha (L) at ``size`` px, supersampled by ``ss``."""
    big = size * ss
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=radius * ss, fill=255)
    # BOX (area-average) on an exact-integer downscale: clean antialiasing with no
    # LANCZOS overshoot, so the outside-corner alpha lands cleanly on 0 (no fringe).
    return mask.resize((size, size), Image.BOX)


def _ink_frame(size: int, radius: int, border: int, ink, ss: int) -> Image.Image:
    """Crisp ink ring (RGBA): a filled rounded silhouette with the interior punched
    out, so the outer edge aligns exactly with the panel silhouette."""
    big = size * ss
    frame = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, big - 1, big - 1], radius=radius * ss, fill=ink)
    b = border * ss
    inner_r = max(1, radius * ss - b)
    d.rounded_rectangle([b, b, big - 1 - b, big - 1 - b], radius=inner_r, fill=(0, 0, 0, 0))
    return frame.resize((size, size), Image.BOX)


def compose(src_path: Path, out_path: Path) -> None:
    src = Image.open(src_path).convert("RGB")
    w, h = src.size
    # Centre-crop to drop any pillowy painted border the model added, keep clean grain.
    cw, ch = int(w * CROP_FRAC), int(h * CROP_FRAC)
    left, top = (w - cw) // 2, (h - ch) // 2
    fill = src.crop((left, top, left + cw, top + ch)).resize((SIZE, SIZE), Image.LANCZOS)

    panel = fill.convert("RGBA")
    panel.putalpha(_rounded_mask(SIZE, RADIUS, SS))                       # rounded silhouette
    panel = Image.alpha_composite(panel, _ink_frame(SIZE, RADIUS, BORDER, SLATE_INK, SS))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    panel.save(out_path)
    print(
        f"composed {out_path.relative_to(REPO)}  "
        f"({SIZE}x{SIZE} RGBA  radius={RADIUS}  border={BORDER}  margin={MARGIN})",
        file=sys.stderr,
    )


if __name__ == "__main__":
    src = REPO / (sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC)
    out = REPO / (sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT)
    compose(src, out)
