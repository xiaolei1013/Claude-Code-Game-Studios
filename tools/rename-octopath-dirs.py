#!/usr/bin/env python3
"""
rename-octopath-dirs.py — Rename CJK-named Octopath asset directories to English.

One-time migration (idempotent + re-runnable): renames the Chinese-named
reference-asset directories under assets/ to predictable English paths so the
demo tooling and any future asset work use ASCII paths. The deeper levels
(character class folders, NPC/enemy names, the extras/ subtrees) are already
English and are left untouched.

Usage:
    python3 tools/rename-octopath-dirs.py [--dry-run]

The asset directories are gitignored — this only touches local files, never git.
Run tools/demo-asset-setup.py afterwards to regenerate demo assets from the new
paths.
"""

import os
import sys
from pathlib import Path

DRY_RUN = "--dry-run" in sys.argv
ASSETS = Path(__file__).parent.parent / "assets"

# Ordered PARENT-FIRST so each rename targets an already-renamed parent path.
# (old_relative_to_assets, new_relative_to_assets)
DIR_RENAMES = [
    # 1. Top-level series folders → octopath{1,2} (matches the .gitignore glob).
    ("八方旅人1", "octopath1"),
    ("八方旅人2", "octopath2"),

    # 2. octopath1 structural dirs.
    ("octopath1/玩家", "octopath1/heroes"),
    ("octopath1/其它", "octopath1/portraits"),
    ("octopath1/地图", "octopath1/map"),
    ("octopath1/敌人&BOSS", "octopath1/enemies_boss"),
    ("octopath1/补充存档（不足这里可以找找）", "octopath1/extras"),
    ("octopath1/音效", "octopath1/audio"),

    # 3. Hero character dirs → character slug (matches demo-asset-setup CLASS_MAP).
    ("octopath1/heroes/战士：欧贝利克", "octopath1/heroes/olberic"),
    ("octopath1/heroes/学者：赛拉斯", "octopath1/heroes/cyrus"),
    ("octopath1/heroes/盗贼：提里昂", "octopath1/heroes/therion"),
    ("octopath1/heroes/神官：奥菲莉亚", "octopath1/heroes/ophilia"),
    ("octopath1/heroes/猎人：汉伊特", "octopath1/heroes/haanit"),
    ("octopath1/heroes/舞女：普里姆萝斯", "octopath1/heroes/primrose"),
    ("octopath1/heroes/药师：阿芬", "octopath1/heroes/alfyn"),
    ("octopath1/heroes/商人：特蕾莎", "octopath1/heroes/tressa"),

    # 4. extras packs.
    ("octopath1/extras/八方敌人敌人20241018", "octopath1/extras/enemies_pack"),
    ("octopath1/extras/八方旅人npc动物等20241018", "octopath1/extras/npc_animals_pack"),

    # 5. audio subdirs.
    ("octopath1/audio/角色语音（日语版）", "octopath1/audio/voice_jp"),
    ("octopath1/audio/角色语音（英文版）", "octopath1/audio/voice_en"),
    ("octopath1/audio/音效", "octopath1/audio/sfx"),
    ("octopath1/audio/sfx/Ambient Sounds氛围音", "octopath1/audio/sfx/ambient"),
    ("octopath1/audio/sfx/Battle Sound Effects战斗音效", "octopath1/audio/sfx/battle"),
    ("octopath1/audio/sfx/Cutscene Sound Effects过场音效", "octopath1/audio/sfx/cutscene"),
    ("octopath1/audio/sfx/Enemies敌人音效", "octopath1/audio/sfx/enemies"),
    ("octopath1/audio/sfx/Environmental Sound Effects环境音效", "octopath1/audio/sfx/environmental"),
    ("octopath1/audio/sfx/System Sound Effects系统音效", "octopath1/audio/sfx/system"),

    # 6. octopath2 images + deeper CJK subdirs.
    ("octopath2/图片", "octopath2/images"),
    ("octopath2/images/Character/PC (未分文件夹)", "octopath2/images/Character/PC_unsorted"),
    ("octopath2/images/Environment/建筑", "octopath2/images/Environment/buildings"),
    ("octopath2/images/Enemy/敌人icon", "octopath2/images/Enemy/enemy_icons"),
]

# Chinese-named files (the OT2 archive zips).
FILE_RENAMES = [
    ("octopath2/PC-八方旅人2BGM1.zip", "octopath2/octopath2_bgm1.zip"),
    ("octopath2/PC-八方旅人2BGM2.zip", "octopath2/octopath2_bgm2.zip"),
    ("octopath2/PC-八方旅人2图片_20250321_164023.zip", "octopath2/octopath2_images.zip"),
    ("octopath2/PC-八方旅人2敌人音效和环境音.zip", "octopath2/octopath2_enemy_sfx_environment.zip"),
]


def rename(old_rel, new_rel):
    old = ASSETS / old_rel
    new = ASSETS / new_rel
    if not old.exists():
        if new.exists():
            print(f"  OK (already renamed): {new_rel}")
        else:
            print(f"  SKIP (source missing): {old_rel}")
        return
    if new.exists():
        print(f"  WARN: target exists, not overwriting: {new_rel}")
        return
    if DRY_RUN:
        print(f"  [DRY] {old_rel}  →  {new_rel}")
    else:
        os.rename(old, new)
        print(f"  {old_rel}  →  {new_rel}")


def main():
    mode = "[DRY RUN] " if DRY_RUN else ""
    print(f"{mode}=== Rename CJK Octopath dirs → English ===")
    print(f"Assets root: {ASSETS}\n")

    print("--- Directories (parent-first) ---")
    for old_rel, new_rel in DIR_RENAMES:
        rename(old_rel, new_rel)

    print("\n--- Files (OT2 zips) ---")
    for old_rel, new_rel in FILE_RENAMES:
        rename(old_rel, new_rel)

    print("\n=== Done ===")
    print("Run: python3 tools/demo-asset-setup.py   (regenerates demo assets from English paths)")


if __name__ == "__main__":
    main()
