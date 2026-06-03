# Demo Asset Manifest

*Status: Active placeholder pass — demo builds only*
*IP notice: All assets below are derivative of Square Enix copyrighted material (Octopath Traveler 1 & 2). LOCAL DEMO USE ONLY. Never commit assembled assets. Never distribute. Replace with original art before any public or commercial release.*

---

## How to set up

```bash
# 0. (one time, only if the source folders still have Chinese names)
python3 tools/rename-octopath-dirs.py  # 八方旅人{1,2}/ → octopath{1,2}/ + English subdirs

# 1. assemble demo assets
pip install pillow                     # required for sprite sheet assembly
python3 tools/demo-asset-setup.py      # assembles all demo assets
# assets/art/demo/ and assets/audio/demo/ are gitignored — local only
```

The source assets must live at `assets/octopath1/` and `assets/octopath2/` with English subdir names. `rename-octopath-dirs.py` is idempotent — safe to re-run after a fresh asset drop.

Dry-run mode (see what will happen without writing files):
```bash
python3 tools/demo-asset-setup.py --dry-run
```

---

## Hero sprite mapping

Source paths are under `assets/octopath1/heroes/` (English slugs produced by `tools/rename-octopath-dirs.py`).

| Lantern Guild class | OT1 character | OT1 source folder | Rationale |
|---|---|---|---|
| `warrior` | Olberic | `heroes/olberic/Olberic Warrior Base` | Knight + shield + sword — direct silhouette match |
| `mage` | Cyrus | `heroes/cyrus/Cyrus Scholar Base` | Staff + robes — vertical accent matches §3 Mage silhouette |
| `rogue` | Therion | `heroes/therion/Therion Thief Base` | Hood + dagger — asymmetric lean matches §3 Rogue |
| `cleric` | Ophilia | `heroes/ophilia/Ophilia Cleric Base` | Lantern implement — matches §5 Cleric raised-luminous-object rule |
| `archer` | H'aanit | `heroes/haanit/Haanit Hunter Base` | Bow at draw — horizontal extension matches §3 Ranger/Archer |
| `berserker` | Primrose | `heroes/primrose/Primrose Dancer Base` | Dynamic expressive movement; closest available energy match |
| `paladin` | Alfyn | `heroes/alfyn/Alfyn Apothecary Base` | Support/healer archetype; warm design palette |
| *(spare)* | Tressa | `heroes/tressa/Tressa Merchant Base` | Available for next Lantern Guild class (Tactician?) |

**Output per class** (gitignored at `assets/art/demo/heroes/[class]/`):
- `hero_[class]_idle.png` — 4-frame horizontal sprite sheet (centered in max-bounding-box canvas)
- `hero_[class]_portrait_sm.png` — 48×48 nearest-neighbor still from frame 001

**Resolution note:** OT1 sprites are ~20-54px wide × 25-44px tall (variable per frame). The art bible targets 32×48 for in-scene hero sprites (§8.3.2). The demo sheets are pixel-exact from the source — no scaling. Production art must be drawn to the §8.3.2 spec.

---

## Audio mapping

| Demo filename | OT1 source track | Game state |
|---|---|---|
| `bgm_main_theme.mp3` | `1-01 Octopath Traveler –Main Theme–.mp3` | Title / boot |
| `bgm_guild_hall.mp3` | `1-11 The Flatlands.mp3` | Guild Hall (idle loop) |
| `bgm_dungeon_run.mp3` | `2-11 Battle I.mp3` | Dungeon run (watching auto-combat) |
| `bgm_battle.mp3` | `3-01 Battle II.mp3` | Deeper dungeon floors |
| `bgm_dark_cavern.mp3` | `2-10 Dark Caverns.mp3` | Thornwood Depths / late-game biomes |
| `bgm_boss.mp3` | `2-24 Decisive Battle I.mp3` | Floor 5 boss encounters |
| `bgm_cleric_theme.mp3` | `1-02 Ophilia, the Cleric.mp3` | Recruit/detail screen ambiance |
| `bgm_victory.mp3` | `2-06 How Amusing!.mp3` | Victory / unlock moment |

**AudioRouter wiring:** Set `ADR-0016 pivot trigger = "playtest reaches 3+ sessions"`. Until then AudioRouter is silent-MVP. Swap in demo tracks by setting `AudioRouter._track_overrides` or by temporarily hardcoding paths in `audio_router.gd` behind a `OS.has_feature("demo")` guard. **Revert before main-branch merge.**

---

## VFX mapping (from OT2 extracted images)

| Demo filename | OT2 source | Suggested use |
|---|---|---|
| `vfx_bubble_a.png` | `images/Effect/Fx_Tx_Bubble_A.png` | Water/magic particle base texture |
| `vfx_aura_a.png` | `images/Effect/FxTX_Aura_A.png` | Cleric/paladin glow aura |
| `vfx_batwing_a.png` | `images/Effect/FxTX_Batwing_A.png` | Enemy death / dark spell effects |

**Note on OT2 zips:** The BGM1/BGM2 zips (`octopath2/octopath2_bgm1.zip`, `_bgm2.zip`) are 1.9 GB and 2.3 GB — do not extract unless necessary. The VFX textures above are already extracted at `assets/octopath2/images/Effect/`.

---

## Enemy / background placeholder strategy

**No directly usable dungeon backgrounds in OT1.** Only the world-map image exists (`assets/octopath1/map/World Map Background.png`). For demo builds:
- **Biome backgrounds** — use `BiomeBackground.set_biome("guild_hall_tavern")` on all screens (shipped placeholder behavior from Sprint 22)
- **Enemy sprites** — the enemy archive at `assets/octopath1/extras/enemies_pack/enemies/` contains OT1 enemy sprites (organized by type: bosses, bugs, golems, undead, etc.); run through the same assembly script pattern if needed for a combat demo. Not included in the default setup pass.

---

## Production replacement checklist

When handing off to production art:

| Demo asset | Production spec | Art bible section |
|---|---|---|
| Hero idle sprite sheets | 32×48 source, 4-6 frames, horizontal strip | §8.3.2 |
| Hero portrait_sm | 48×48 source, pixel-art detail | §8.3.3 |
| Hero portrait_lg | 96×96 source, separate deliverable | §8.3.3 |
| BGM tracks | Original compositions; ogg preferred for Godot | ADR-0016 |
| VFX textures | 16×16 sprite sheets, additive blend, premult alpha | §8.2.3 |

All production assets must follow §8 (naming, format, import settings, resolution).

---

*Last updated: 2026-06-03. Script: `tools/demo-asset-setup.py`.*
