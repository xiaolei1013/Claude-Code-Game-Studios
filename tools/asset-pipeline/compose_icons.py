#!/usr/bin/env python3
"""Hand-author the MVP UI icon set as crisp on-spec pixel PNGs (NO diffusion).

DESIGN.md "Iconography" mandates: pixel-outlined-with-fill, 1px Slate Ink
outline at native canvas, *never anti-aliased*, single solid palette fill per
icon, transparent background, one file per icon at 1x (upscaled at runtime).

Diffusion models cannot honor "never anti-aliased / exact 7-color palette / 1px
crisp outline" at a 24px canvas, so every icon here is drawn deterministically
with Pillow's ImageDraw primitives (which are hard-edged / aliased by default)
plus explicit per-pixel placement for glyph detail. No supersample-then-shrink
(that would introduce AA): everything is rendered directly at the 24px master.

Master size: 24x24 (the DESIGN.md "button" canvas — the primary interactive
size and the larger of the common 16/24 pair). Imported nearest-neighbor so
runtime scaling stays crisp. A dedicated 16px master per icon is a cheap
follow-up if inline downscale reads rough in playtest.

The 9 glyph icons (xp_bar is a ProgressBar StyleBox, not a square icon, and is
handled by the theme — hence 9 here, not the 10 DESIGN.md lines):
  coin, settings_gear, dispatch_arrow,
  class_warrior, class_mage, class_rogue,
  matchup_advantage, matchup_neutral, matchup_disadvantage

Usage:
  python3 tools/asset-pipeline/compose_icons.py            # write all 9 icons
  python3 tools/asset-pipeline/compose_icons.py --sheet    # + QA contact sheet

ADR-0024 (parchment-panel sibling): static hand-authored pixel PNGs.
"""
from __future__ import annotations

import argparse
import os
from PIL import Image, ImageDraw

# --- Locked 7-color palette (DESIGN.md / art-bible), RGBA -------------------
GUILD_AMBER = (200, 135, 42, 255)      # C8872A
LANTERN_GOLD = (242, 184, 59, 255)     # F2B83B
PARCHMENT_CREAM = (237, 224, 196, 255)  # EDE0C4
DUSK_PURPLE = (91, 74, 114, 255)       # 5B4A72
MOSS_SAGE = (122, 140, 94, 255)        # 7A8C5E
EMBER_RUST = (168, 76, 47, 255)        # A84C2F
SLATE_INK = (44, 40, 56, 255)          # 2C2838 (replaces black)
CLEAR = (0, 0, 0, 0)

S = 24  # master canvas (square)

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
OUT_DIR = os.path.join(_ROOT, "assets", "art", "ui", "icons")
SHEET_PATH = os.path.join(
    _ROOT, "production", "qa", "evidence", "ui_icons_contact_sheet_20260616.png"
)


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (S, S), CLEAR)
    return img, ImageDraw.Draw(img)


def _stamp(d: ImageDraw.ImageDraw, grid: list[str], ox: int, oy: int,
           color: tuple) -> None:
    """Paint a string-grid glyph ('X' = color, anything else = skip)."""
    for gy, row in enumerate(grid):
        for gx, ch in enumerate(row):
            if ch == "X":
                d.point((ox + gx, oy + gy), fill=color)


# --- coin: Lantern Gold disc, Slate Ink outline + centred G-rune -----------
def coin() -> Image.Image:
    img, d = _canvas()
    d.ellipse([2, 2, 21, 21], fill=LANTERN_GOLD, outline=SLATE_INK, width=1)
    # Blocky 7x7 "G" rune (the guild mark), centred on the 20px disc.
    g_rune = [
        ".XXXXX.",
        "X.....X",
        "X......",
        "X..XXX.",
        "X....X.",
        "X.....X",
        ".XXXXX.",
    ]
    _stamp(d, g_rune, 8, 8, SLATE_INK)
    return img


# --- settings_gear: solid Slate Ink cog with a transparent centre ----------
def settings_gear() -> Image.Image:
    img, d = _canvas()
    # Orthogonal teeth.
    d.rectangle([10, 1, 13, 5], fill=SLATE_INK)     # top
    d.rectangle([10, 18, 13, 22], fill=SLATE_INK)   # bottom
    d.rectangle([1, 10, 5, 13], fill=SLATE_INK)     # left
    d.rectangle([18, 10, 22, 13], fill=SLATE_INK)   # right
    # Diagonal teeth (3x3 blocks near the 45-degree corners).
    for cx, cy in [(4, 4), (19, 4), (4, 19), (19, 19)]:
        d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=SLATE_INK)
    # Cog body, then punch a transparent centre hole.
    d.ellipse([3, 3, 20, 20], fill=SLATE_INK)
    d.ellipse([8, 8, 15, 15], fill=CLEAR)
    return img


# --- dispatch_arrow: right-pointing Guild Amber arrow, Slate Ink outline ----
def dispatch_arrow() -> Image.Image:
    img, d = _canvas()
    arrow = [
        (3, 9), (12, 9), (12, 5), (21, 11),
        (21, 12), (12, 18), (12, 14), (3, 14),
    ]
    d.polygon(arrow, fill=GUILD_AMBER, outline=SLATE_INK, width=1)
    return img


# --- class_warrior: heater shield, Ember Rust fill + Slate Ink outline ------
def class_warrior() -> Image.Image:
    img, d = _canvas()
    shield = [(4, 4), (20, 4), (20, 11), (12, 21), (4, 11)]
    d.polygon(shield, fill=EMBER_RUST, outline=SLATE_INK, width=1)
    d.line([(12, 5), (12, 18)], fill=SLATE_INK, width=1)  # boss divider
    return img


# --- class_mage: orb-finial staff, Dusk Purple orb + Slate Ink shaft --------
def class_mage() -> Image.Image:
    img, d = _canvas()
    d.rectangle([11, 9, 13, 21], fill=SLATE_INK, outline=SLATE_INK)  # shaft
    d.ellipse([7, 2, 17, 12], fill=DUSK_PURPLE, outline=SLATE_INK, width=1)  # finial
    d.point((12, 6), fill=PARCHMENT_CREAM)  # tiny glint
    return img


# --- class_rogue: reverse-grip dagger (blade down), Moss Sage + Slate Ink ---
def class_rogue() -> Image.Image:
    img, d = _canvas()
    blade = [(10, 6), (14, 6), (14, 16), (12, 21), (10, 16)]
    d.polygon(blade, fill=MOSS_SAGE, outline=SLATE_INK, width=1)
    d.rectangle([6, 5, 18, 6], fill=SLATE_INK)   # crossguard
    d.rectangle([11, 2, 13, 5], fill=SLATE_INK)  # grip (held reverse)
    return img


# --- matchup_advantage: up triangle, Lantern Gold + Slate Ink outline -------
def matchup_advantage() -> Image.Image:
    img, d = _canvas()
    d.polygon([(12, 3), (21, 20), (3, 20)], fill=LANTERN_GOLD,
              outline=SLATE_INK, width=1)
    return img


# --- matchup_neutral: filled dot, Parchment Cream + Slate Ink outline -------
def matchup_neutral() -> Image.Image:
    img, d = _canvas()
    d.ellipse([4, 4, 19, 19], fill=PARCHMENT_CREAM, outline=SLATE_INK, width=1)
    return img


# --- matchup_disadvantage: down triangle, Dusk Purple + Slate Ink outline ---
def matchup_disadvantage() -> Image.Image:
    img, d = _canvas()
    d.polygon([(3, 4), (21, 4), (12, 21)], fill=DUSK_PURPLE,
              outline=SLATE_INK, width=1)
    return img


ICONS = {
    "coin": coin,
    "settings_gear": settings_gear,
    "dispatch_arrow": dispatch_arrow,
    "class_warrior": class_warrior,
    "class_mage": class_mage,
    "class_rogue": class_rogue,
    "matchup_advantage": matchup_advantage,
    "matchup_neutral": matchup_neutral,
    "matchup_disadvantage": matchup_disadvantage,
}


def _contact_sheet(rendered: dict[str, Image.Image]) -> None:
    """QA-only: each icon at 6x nearest-neighbour, on cream and on slate."""
    scale = 6
    cell = S * scale
    pad = 8
    cols = len(rendered)
    sheet_w = cols * cell + (cols + 1) * pad
    sheet_h = 2 * cell + 3 * pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (60, 55, 75, 255))
    for col, (name, im) in enumerate(rendered.items()):
        big = im.resize((cell, cell), Image.NEAREST)
        x = pad + col * (cell + pad)
        cream = Image.new("RGBA", (cell, cell), PARCHMENT_CREAM)
        cream.alpha_composite(big)
        sheet.alpha_composite(cream, (x, pad))
        slate = Image.new("RGBA", (cell, cell), SLATE_INK)
        slate.alpha_composite(big)
        sheet.alpha_composite(slate, (x, pad + cell + pad))
    os.makedirs(os.path.dirname(SHEET_PATH), exist_ok=True)
    sheet.save(SHEET_PATH)
    print(f"  QA sheet -> {os.path.relpath(SHEET_PATH, _ROOT)} "
          f"({sheet.width}x{sheet.height})")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sheet", action="store_true",
                    help="also write a QA contact sheet to production/qa/evidence/")
    args = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    rendered: dict[str, Image.Image] = {}
    for name, fn in ICONS.items():
        im = fn()
        rendered[name] = im
        path = os.path.join(OUT_DIR, f"{name}.png")
        im.save(path)
        print(f"  {name:22s} -> {os.path.relpath(path, _ROOT)} ({im.width}x{im.height})")
    print(f"Wrote {len(rendered)} icons to {os.path.relpath(OUT_DIR, _ROOT)}/")

    if args.sheet:
        _contact_sheet(rendered)


if __name__ == "__main__":
    main()
