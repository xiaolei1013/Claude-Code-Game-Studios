#!/usr/bin/env python3
"""
demo-asset-setup.py — Assemble Octopath Traveler placeholder assets for demo builds.

Usage:
    python3 tools/demo-asset-setup.py [--dry-run]

What it does:
  1. Reads individual animation frames from assets/octopath1/
  2. Assembles 4-frame idle sprite sheets per hero class (horizontal strip)
  3. Generates 48×48 portrait stills from the first idle frame
  4. Copies selected BGM tracks to assets/audio/demo/
  5. Copies VFX textures from assets/octopath2/ to assets/art/demo/vfx/

Output structure (gitignored — local only):
    assets/art/demo/heroes/[class]/
        hero_[class]_idle.png          # 4-frame horizontal idle strip
        hero_[class]_portrait_sm.png   # 48×48 standing portrait

    assets/audio/demo/
        bgm_guild_hall.mp3
        bgm_dungeon_run.mp3
        bgm_battle.mp3
        bgm_boss.mp3
        bgm_dark_cavern.mp3
        bgm_main_theme.mp3

    assets/art/demo/vfx/
        (selected OT2 VFX textures, renamed)

IP notice: All output assets are derivative of Square Enix copyrighted material.
           LOCAL DEMO USE ONLY. Never commit or distribute.
           Replace with original art before any public release.
"""

import hashlib
import os
import re
import sys
import shutil
from pathlib import Path

DRY_RUN = "--dry-run" in sys.argv
ROOT = Path(__file__).parent.parent

SRC_OT1 = ROOT / "assets" / "octopath1"
SRC_OT2 = ROOT / "assets" / "octopath2"
DST_HEROES = ROOT / "assets" / "art" / "demo" / "heroes"
DST_AUDIO = ROOT / "assets" / "audio" / "demo"
DST_VFX = ROOT / "assets" / "art" / "demo" / "vfx"

# Enemy sprite assembly — the Octopath enemy archive (organized by creature type)
# mapped onto the game's 34 enemy .tres by theme. Output goes to the production
# path EnemyData.sprite_path references (assets/art/enemies/<id>/sprite.png),
# gitignored as IP placeholders.
ENEMY_ARCHIVE = SRC_OT1 / "extras" / "enemies_pack" / "enemies"
ENEMY_TRES_DIR = ROOT / "assets" / "data" / "enemies"
DST_ENEMIES = ROOT / "assets" / "art" / "enemies"
ENEMY_THUMB_MAX = 96  # longest-edge cap after alpha-crop (keeps thumbnails light)

# Keyword (in enemy id) → source creature-type folder. First match wins, so
# order specific themes before generic ones. is_boss short-circuits to "bosses".
ENEMY_KEYWORD_FOLDERS = [
    (("root", "moss", "vine", "thorn", "bloom", "druid", "sprout", "bram"), "plants"),
    (("grub", "moth", "glow", "beetle", "acarid", "hive"), "bugs"),
    (("eel", "serpent", "coral", "tide", "deep", "drowned", "abyss", "shell", "husk", "brine", "mire"), "sea_creatures"),
    (("revenant", "wraith", "hollow", "marrow", "thrall", "pilgrim", "winter", "bone", "skull", "grave", "echo"), "undead"),
    (("djinn", "cinder", "ash", "frost", "glasswind", "windborne", "kiln", "ember", "flame", "spark", "icebound"), "elementals"),
    (("titan", "colossus", "obsidian", "iron", "stone", "crag", "spire", "golem", "silent", "stoneback"), "golems"),
    (("boar", "jackal", "hound", "wolf", "beast", "stag", "elder"), "mammals"),
    (("hunter", "born", "wing", "feather", "raptor"), "birds"),
    (("warden", "knight", "judge", "chorister", "step", "witch", "lamplit"), "humans"),
]
# Archetype fallback when no keyword matches.
ENEMY_ARCHETYPE_FOLDERS = {
    "swarm": "bugs", "bruiser": "mammals", "armored": "golems",
    "skirmisher": "birds", "caster": "undead",
}

# ---------------------------------------------------------------------------
# Class → Octopath character mapping
# ---------------------------------------------------------------------------
# 7 Lantern Guild classes mapped to OT1's 8 characters.
# Tressa (Merchant) is held as a spare for future class additions.
#
# Source folder format: assets/octopath1/heroes/[char_dir]/[CharName Base]/001.png
# We pick the "Base" class folder (the character's default class visual).
# char_dir values are the English slugs produced by tools/rename-octopath-dirs.py.
CLASS_MAP = {
    "warrior": {
        "char_dir": "olberic",
        "base_folder": "Olberic Warrior Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "Olberic — Knight/Warrior archetype. Shield+sword silhouette.",
    },
    "mage": {
        "char_dir": "cyrus",
        "base_folder": "Cyrus Scholar Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "Cyrus — Scholar archetype. Staff + robes.",
    },
    "rogue": {
        "char_dir": "therion",
        "base_folder": "Therion Thief Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "Therion — Thief archetype. Hood + dagger.",
    },
    "cleric": {
        "char_dir": "ophilia",
        "base_folder": "Ophilia Cleric Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "Ophilia — Cleric archetype. Lantern implement.",
    },
    "archer": {
        "char_dir": "haanit",
        "base_folder": "Haanit Hunter Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "H'aanit — Hunter archetype. Bow.",
    },
    "berserker": {
        "char_dir": "primrose",
        "base_folder": "Primrose Dancer Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "Primrose — Dynamic/expressive movement reads as berserker energy.",
    },
    "paladin": {
        "char_dir": "alfyn",
        "base_folder": "Alfyn Apothecary Base",
        "frames": ["001.png", "002.png", "003.png", "004.png"],
        "note": "Alfyn — Support/healer archetype.",
    },
}

# Spare: Tressa (Merchant) — available for future class additions.
SPARE = {
    "char_dir": "tressa",
    "base_folder": "Tressa Merchant Base",
    "note": "Tressa (Merchant) — spare; maps to a future Lantern Guild class.",
}

# ---------------------------------------------------------------------------
# BGM mapping: game state → source track filename
# ---------------------------------------------------------------------------
BGM_MAP = {
    "bgm_main_theme.mp3": "1-01 Octopath Traveler –Main Theme–.mp3",
    "bgm_guild_hall.mp3": "1-11 The Flatlands.mp3",
    "bgm_dungeon_run.mp3": "2-11 Battle I.mp3",
    "bgm_battle.mp3": "3-01 Battle II.mp3",
    "bgm_dark_cavern.mp3": "2-10 Dark Caverns.mp3",
    "bgm_boss.mp3": "2-24 Decisive Battle I.mp3",
    "bgm_cleric_theme.mp3": "1-02 Ophilia, the Cleric.mp3",
    "bgm_victory.mp3": "2-06 How Amusing!.mp3",
}

# ---------------------------------------------------------------------------
# VFX: OT2 pre-extracted effects to copy
# ---------------------------------------------------------------------------
VFX_MAP = {
    "vfx_bubble_a.png": "images/Effect/Fx_Tx_Bubble_A.png",
    "vfx_aura_a.png": "images/Effect/FxTX_Aura_A.png",
    "vfx_batwing_a.png": "images/Effect/FxTX_Batwing_A.png",
}


def log(msg):
    prefix = "[DRY RUN] " if DRY_RUN else ""
    print(f"{prefix}{msg}")


def mkdir(path):
    if not DRY_RUN:
        path.mkdir(parents=True, exist_ok=True)
    else:
        log(f"mkdir -p {path}")


def copy_file(src, dst):
    if not src.exists():
        print(f"  SKIP (not found): {src}")
        return False
    if not DRY_RUN:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    log(f"  COPY {src.name} → {dst}")
    return True


# ---------------------------------------------------------------------------
# Sprite sheet assembly
# ---------------------------------------------------------------------------
def assemble_sprite_sheet(class_name, cfg):
    """
    Assemble a horizontal 4-frame idle sprite sheet for one hero class.
    Requires Pillow (pip install pillow). Falls back to copying frame 001
    individually if Pillow is unavailable.
    """
    src_base = SRC_OT1 / "heroes" / cfg["char_dir"] / cfg["base_folder"]
    if not src_base.exists():
        # Try alternate folder name patterns (some folders append "Base" differently)
        candidates = list((SRC_OT1 / "heroes" / cfg["char_dir"]).glob("*Base*"))
        if candidates:
            src_base = candidates[0]
            log(f"  Using alternate folder: {src_base.name}")
        else:
            print(f"  SKIP {class_name}: source folder not found: {src_base}")
            return

    frames = [src_base / f for f in cfg["frames"] if (src_base / f).exists()]
    if not frames:
        print(f"  SKIP {class_name}: no frames found in {src_base}")
        return

    dst_dir = DST_HEROES / class_name
    dst_idle = dst_dir / f"hero_{class_name}_idle.png"
    dst_portrait = dst_dir / f"hero_{class_name}_portrait_sm.png"

    try:
        from PIL import Image

        imgs = [Image.open(f) for f in frames]
        # Find bounding box: use the max width and height so no frame is clipped.
        max_w = max(im.width for im in imgs)
        max_h = max(im.height for im in imgs)
        # Pad to a power-of-2-friendly size (nearest multiple of 4 at minimum).
        canvas_w = max_w
        canvas_h = max_h

        sheet = Image.new("RGBA", (canvas_w * len(imgs), canvas_h), (0, 0, 0, 0))
        for i, im in enumerate(imgs):
            # Center each frame in the canvas cell.
            x = i * canvas_w + (canvas_w - im.width) // 2
            y = (canvas_h - im.height) // 2
            sheet.paste(im, (x, y))

        if not DRY_RUN:
            mkdir(dst_dir)
            sheet.save(dst_idle)
        log(f"  SHEET {class_name}: {len(imgs)} frames @ {canvas_w}×{canvas_h} → {dst_idle.name}")

        # Portrait: first frame resized to 48×48 nearest-neighbor (demo dir)
        # and 96×96 (production path ClassPortraitFactory reads from).
        portrait_48 = imgs[0].resize((48, 48), Image.NEAREST)
        portrait_96 = imgs[0].resize((96, 96), Image.NEAREST)
        if not DRY_RUN:
            portrait_48.save(dst_portrait)
        log(f"  PORTRAIT {class_name}: {dst_portrait.name}")

        # Also write to the production paths the game already references.
        # HeroClass.tres → portrait_path = "assets/art/classes/[id]/portrait.png"
        # HeroClass.tres → sprite_path   = "assets/art/classes/[id]/sprite.png"
        # assets/art/classes/ is gitignored (IP placeholders) — see .gitignore.
        prod_dir = ROOT / "assets" / "art" / "classes" / class_name
        prod_portrait = prod_dir / "portrait.png"
        prod_sprite = prod_dir / "sprite.png"
        if not DRY_RUN:
            prod_dir.mkdir(parents=True, exist_ok=True)
            portrait_96.save(prod_portrait)
            sheet.save(prod_sprite)
        log(f"  PROD portrait: assets/art/classes/{class_name}/portrait.png (96×96)")
        log(f"  PROD sprite:   assets/art/classes/{class_name}/sprite.png (sheet)")

    except ImportError:
        # Pillow not installed — fall back to plain copy of frame 001.
        log(f"  Pillow not available; copying frame 001 only for {class_name}")
        copy_file(frames[0], dst_idle)
        copy_file(frames[0], dst_portrait)


# ---------------------------------------------------------------------------
# Enemy sprite assembly
# ---------------------------------------------------------------------------
def _stable_index(key, n):
    """Deterministic index in [0, n) from a string key (PYTHONHASHSEED-safe)."""
    if n <= 0:
        return 0
    return int(hashlib.md5(key.encode()).hexdigest(), 16) % n


def _parse_enemy_tres(path):
    """Extract id / archetype / biome / is_boss from an enemy .tres (regex-light)."""
    txt = path.read_text(encoding="utf-8", errors="ignore")

    def grab(field, default=""):
        m = re.search(rf'^{field}\s*=\s*"?([^"\n]+)"?', txt, re.M)
        return m.group(1).strip() if m else default

    return {
        "id": grab("id"),
        "archetype": grab("archetype"),
        "biome": grab("biome"),
        "is_boss": grab("is_boss", "false").lower() == "true",
    }


def _enemy_folder(enemy):
    """Pick the source creature-type folder for an enemy by theme."""
    name = enemy["id"].lower()
    if enemy["is_boss"]:
        return "bosses"
    for keys, folder in ENEMY_KEYWORD_FOLDERS:
        if any(k in name for k in keys):
            return folder
    return ENEMY_ARCHETYPE_FOLDERS.get(enemy["archetype"], "misc")


def _crop_main_figure(im):
    """Crop a multi-figure enemy sheet down to its single largest creature.

    The Octopath enemy art packs several frames/creatures horizontally with
    transparent gaps between them. Showing the whole sheet in a thumbnail yields
    a row of tiny figures, so we isolate ONE: scan column alpha-occupancy, split
    into runs (merging within-creature gaps smaller than ~6% of the height), pick
    the WIDEST run (the main creature, not a stray sliver), then tight-crop it.
    """
    w, h = im.size
    px = im.getchannel("A").load()
    occ = [any(px[x, y] > 8 for y in range(0, h, 3)) for x in range(w)]
    if not any(occ):
        return im  # fully transparent — leave as-is

    min_gap = max(8, round(h * 0.06))
    runs = []
    start = None
    end = 0
    gap = 0
    for x in range(w):
        if occ[x]:
            if start is None:
                start = x
            end = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap > min_gap:
                runs.append((start, end))
                start = None
    if start is not None:
        runs.append((start, end))
    if not runs:
        return im

    x0, x1 = max(runs, key=lambda r: r[1] - r[0])
    band = im.crop((x0, 0, x1 + 1, h))
    bb = band.getbbox()
    return band.crop(bb) if bb else band


def assemble_enemy_sprites():
    """One demo sprite per enemy .tres: theme-map to a source folder, pick a
    deterministic sprite, alpha-crop + downscale, write to the production path."""
    if not ENEMY_ARCHIVE.exists():
        print(f"  SKIP enemies: archive not found at {ENEMY_ARCHIVE}")
        return
    tres_files = sorted(ENEMY_TRES_DIR.glob("*.tres"))
    if not tres_files:
        print(f"  SKIP enemies: no .tres in {ENEMY_TRES_DIR}")
        return
    try:
        from PIL import Image
    except ImportError:
        log("  Pillow not available; skipping enemy sprites (pip install pillow).")
        return

    # Index source pngs per folder once (case-insensitive .png / .PNG).
    folder_files = {}
    for d in sorted(ENEMY_ARCHIVE.iterdir()):
        if d.is_dir():
            pngs = sorted(f for f in d.iterdir() if f.suffix.lower() == ".png")
            if pngs:
                folder_files[d.name] = pngs

    assembled = 0
    for tres in tres_files:
        enemy = _parse_enemy_tres(tres)
        if not enemy["id"]:
            continue
        folder = _enemy_folder(enemy)
        pngs = folder_files.get(folder) or folder_files.get("misc")
        if not pngs:
            pngs = next(iter(folder_files.values()), [])
        if not pngs:
            continue
        src = pngs[_stable_index(enemy["id"], len(pngs))]

        dst_dir = DST_ENEMIES / enemy["id"]
        dst = dst_dir / "sprite.png"
        if not DRY_RUN:
            im = Image.open(src).convert("RGBA")
            im = _crop_main_figure(im)  # isolate one creature from the sheet
            im.thumbnail((ENEMY_THUMB_MAX, ENEMY_THUMB_MAX), Image.NEAREST)
            mkdir(dst_dir)
            im.save(dst)
        assembled += 1
        log(f"  ENEMY {enemy['id']}: {folder}/{src.name} -> {dst.relative_to(ROOT)}")
    log(f"  {assembled} enemy sprite(s) assembled (gitignored at assets/art/enemies/).")


def main():
    log("=== Lantern Guild demo asset setup ===")
    log(f"Source OT1: {SRC_OT1}")
    log(f"Source OT2: {SRC_OT2}")
    log(f"Output:     {DST_HEROES.parent.parent}")
    print()

    if not SRC_OT1.exists():
        print(f"ERROR: OT1 source not found at {SRC_OT1}")
        print("       Place the OT1 assets at assets/octopath1/ "
              "(run tools/rename-octopath-dirs.py if they have Chinese names)")
        sys.exit(1)

    # 1. Hero sprite sheets
    log("--- Hero sprite sheets ---")
    for class_name, cfg in CLASS_MAP.items():
        assemble_sprite_sheet(class_name, cfg)
    print()

    # 2. BGM
    log("--- BGM tracks ---")
    bgm_src = SRC_OT1 / "BGM"
    for dst_name, src_name in BGM_MAP.items():
        copy_file(bgm_src / src_name, DST_AUDIO / dst_name)
    print()

    # 3. VFX from OT2
    if SRC_OT2.exists():
        log("--- VFX textures (OT2) ---")
        for dst_name, rel_src in VFX_MAP.items():
            copy_file(SRC_OT2 / rel_src, DST_VFX / dst_name)
    else:
        log("OT2 source not found — skipping VFX.")
    print()

    # 4. Enemy sprites (archive → per-enemy demo sprite at the production path)
    log("--- Enemy sprites ---")
    assemble_enemy_sprites()
    print()

    log("=== Done ===")
    log("Output assets are gitignored (assets/art/demo/, assets/audio/demo/, "
        "assets/art/classes/, assets/art/enemies/).")
    log("See design/art/demo-asset-manifest.md for the full mapping.")
    log("Install Pillow for sprite sheet assembly: pip install pillow")


if __name__ == "__main__":
    main()
