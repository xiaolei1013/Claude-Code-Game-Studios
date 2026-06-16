# ADR-0024: MVP UI Icon Set — Hand-Authored Crisp Pixel PNGs (no diffusion)

## Status

Proposed

> Ratify to **Accepted** before any story depends on the icon set landing on `main`.
> Sibling to ADR-0023 (same "generate UI/HUD assets" directive); they split the
> design surface by what each tool does well — see Summary.

## Date

2026-06-16 (authored under user direction to generate HUD/UI visual assets following
the GDD + art bible; the icon half of the "Split by fit" decision, ADR-0023 being the
painterly-surface half)

## Last Verified

2026-06-16

## Decision Makers

- Author (user) — final decision; directed UI/HUD asset generation; chose "Split by fit"
- art-director — icon style vs the art bible §7 "pixel-outlined" direction (advisory)
- godot-specialist — `Button.icon` / `TextureRect` + `TEXTURE_FILTER_NEAREST` wiring (advisory)

## Summary

The MVP UI icon set (DESIGN.md §"Iconography") is **hand-authored as deterministic
crisp pixel PNGs** with Pillow's `ImageDraw` primitives — **not** diffusion-generated.

This is the deliberate counterpart to ADR-0023. There, a painterly parchment *material*
tolerates model non-determinism and antialiasing, so Gemini paints the fill. Here the
spec is the opposite: DESIGN.md mandates **"1px Slate Ink outline, *never* anti-aliased,
single solid palette fill, transparent background"** at a 16/24px canvas. A diffusion
model cannot honor "never anti-aliased / exactly these 7 colors / 1px crisp outline" at
24px — it dithers edges, drifts the palette, and softens strokes. So icons are drawn
deterministically:

- **Gemini → painterly surfaces / materials** (ADR-0023: the parchment fill).
- **`tools/asset-pipeline/compose_icons.py` (PIL) → crisp on-spec pixel glyphs** (this ADR).

`ImageDraw` is hard-edged (aliased) by default and lets us place exact palette pixels, so
the output honors DESIGN.md's *precise tokens* with zero post-processing. Everything is
rendered **directly at the 24px master** — no supersample-then-shrink, which would
re-introduce the antialiasing the spec forbids.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / asset pipeline + a thin Guild Hall wiring (`Button.icon`, `TextureRect`) |
| **Knowledge Risk** | LOW — `Button.icon`, `TextureRect`, `CanvasItem.texture_filter = TEXTURE_FILTER_NEAREST`, and lossless `Texture2D` import (`compress/mode=0`, `mipmaps/generate=false`) are stable since 4.0; no post-cutoff API surface. |
| **References Consulted** | DESIGN.md §"Iconography" (style/canvas/stroke/fill/format + the MVP icon list); `design/art/art-bible.md` §7 (pixel-outlined icons); ADR-0008 (theme cascade); ADR-0023 (sibling composed-surface ADR); Godot 4.6 `Button`/`TextureRect`/`CanvasItem` docs |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) PIL contact sheet (each icon at 6× nearest, on cream + on slate) for palette/stroke QA; (2) headful render of the real Guild Hall with the 3 chrome icons wired, over the warm tavern biome + parchment theme; (3) a wiring regression suite (`tests/integration/guild_hall/mvp_icons_wired_test.gd`) + the existing guild_hall suites green. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0008 (root theme cascade — the icons sit on themed Controls); ADR-0023 (sibling; establishes the "split UI assets by tool fit" precedent and the `assets/art/ui/` location) |
| **Supersedes** | None |
| **Enables** | An on-spec, palette-locked icon vocabulary for the HUD/chrome; the 6 authored-but-unwired icons (class + matchup) are ready to wire at their display call sites without re-authoring |
| **Blocks** | None |

## Context

### Problem Statement

DESIGN.md §"Iconography" specifies an MVP icon set but no icon assets existed; the chrome
used text glyphs (a "⚙" for settings, no coin, a text-only Dispatch button). The user
directed generating UI/HUD assets following the GDD + art bible. The §"Iconography" spec is
pixel-exact (1px Slate Ink outline, never anti-aliased, single solid palette fill), which
determines *how* the assets must be produced.

### Current State (pre-this-ADR)

- No icon assets under `assets/art/ui/`. The Guild Hall settings button showed a "⚙" text
  glyph; the gold counter was a bare `Gold: N` label; the Dispatch CTA was text-only.
- Class identity and matchup advantage/neutral/disadvantage were communicated by text only.

### Constraints

- **Pixel-exactness wins (DESIGN.md precise tokens)**: 7-color locked palette, Slate Ink
  `#2C2838` 1px outline, never anti-aliased, transparent background, one file per icon.
- **Visual direction (art bible §7)**: "pixel-outlined with fill" — a deterministic pixel
  tool matches this far better than diffusion.
- **No scaffolded-but-unwired**: the project's dominant defect class is assets that exist but
  reach no player. Anything authored must either be wired to a real call site this PR or be
  explicitly named as a deferred follow-up with its wire point.
- **Crispness under stretch**: pixel art needs `TEXTURE_FILTER_NEAREST` or it blurs.
- **PR workflow**: assets + wiring land via PR; no direct push to `main`.

## Decision

**Hand-author the 9 MVP glyph icons as crisp 24×24 RGBA pixel PNGs via
`tools/asset-pipeline/compose_icons.py` (PIL `ImageDraw`, no diffusion), import them
nearest-neighbor lossless, and wire the 3 chrome icons (coin, settings_gear,
dispatch_arrow) onto the live Guild Hall this PR; defer the 6 display icons (3 class +
3 matchup) to a named follow-up with their wire points recorded.**

### The 9 glyph icons (xp_bar excluded — see "9 vs 10")

| Icon | Fill | Glyph |
|------|------|-------|
| `coin` | Lantern Gold | disc + Slate Ink "G" guild rune |
| `settings_gear` | Slate Ink (outline-only) | cog with transparent centre |
| `dispatch_arrow` | Guild Amber | right-pointing arrow |
| `class_warrior` | Ember Rust | heater shield + boss divider |
| `class_mage` | Dusk Purple | orb-finial staff |
| `class_rogue` | Moss Sage | reverse-grip dagger |
| `matchup_advantage` | Lantern Gold | up triangle ▲ |
| `matchup_neutral` | Parchment Cream | filled dot ● |
| `matchup_disadvantage` | Dusk Purple | down triangle ▼ |

All carry the Slate Ink `#2C2838` 1px outline. Palette is the locked 7-color set (DESIGN.md /
art bible), RGBA constants duplicated at the top of `compose_icons.py`.

### Architecture

```
[ DESIGN.md §Iconography spec ]            [ asset pipeline ]                    [ Godot ]
 style=pixel-outlined, 7-color,   ──►  tools/asset-pipeline/compose_icons.py
 1px Slate Ink, never AA, 1 file/icon       (PIL ImageDraw, hard-edged,
                                             rendered DIRECTLY at 24px — no
                                             supersample, no AA)
                                                   │  writes 9 PNGs
                                                   ▼
                                        assets/art/ui/icons/<name>.png  (24×24 RGBA,
                                        + <name>.png.import             committed + imported,
                                          compress/mode=0 lossless,     uid pinned)
                                          mipmaps/generate=false
                                                   │  preload() in guild_hall.gd
                                                   ▼
   Guild Hall chrome (this PR):                              (deferred follow-up:)
     SettingsGearButton.icon = settings_gear   class_* → formation hero cards
     DispatchNavButton.icon  = dispatch_arrow  matchup_* → floor-picker matchup hints
     GoldCoinIcon TextureRect = coin
       all texture_filter = TEXTURE_FILTER_NEAREST (crisp under stretch)
       coin is MOUSE_FILTER_IGNORE (decorative; z_index ≠ input picking)
```

### Key decisions (recorded for veto)

- **24×24 single master.** DESIGN.md lists 16/24/32/48 canvases; 24px is the "button" canvas
  (the primary interactive size) and the larger of the common 16/24 pair, so it downsizes more
  gracefully than upsizing a 16px master would. Imported nearest-neighbor so runtime scaling
  stays crisp. **A dedicated 16px master per icon is a cheap follow-up** if inline downscale
  reads rough in playtest.
- **Class colors are semantic, palette-correct, and new** — warrior = Ember Rust, mage = Dusk
  Purple, rogue = Moss Sage. DESIGN.md names the class *icons* (shield/staff/dagger) but not
  their fills; these assignments are this ADR's choice and are **flagged for veto**.
- **3 wired now, 6 deferred.** The chrome icons (coin/gear/arrow) sit on stable, low-risk,
  high-visibility nodes and are wired + render-verified this PR. The 6 display icons touch
  dense dynamic display logic (per-hero formation cards, per-floor matchup hints); wiring them
  is a named follow-up to avoid a risky multi-call-site change riding on an asset PR.

### 9 vs 10

DESIGN.md's §Iconography list has 10 lines, but `xp_bar` is a `ProgressBar` `StyleBox` handled
by the theme, **not** a square icon file — so this set is 9 glyph PNGs, not 10.

## Alternatives Considered

### Alternative 1: Hand-authored crisp pixel PNGs (PIL, no diffusion) — CHOSEN

- **Pros**: Honors DESIGN.md exactly (7-color, 1px Slate Ink, never AA, transparent bg);
  fully deterministic + reproducible; tiny lossless textures; no model cost; trivially
  re-tunable (edit a grid/polygon).
- **Cons**: Manual authoring effort per icon; class fills are an authored choice (veto needed);
  a single 24px master may need a 16px sibling for the smallest sites.
- **Rejection Reason**: N/A — chosen.

### Alternative 2: Diffusion-generated icons (Gemini), like the parchment fill

- **Description**: Prompt Gemini for each icon as it does for backgrounds/portraits.
- **Cons**: Cannot honor "never anti-aliased / exact 7-color / 1px crisp outline" at 24px —
  dithered edges, palette drift, soft strokes; non-deterministic; needs heavy cleanup that
  approximates hand-authoring anyway.
- **Rejection Reason**: Fails the precise-token spec; this is exactly the surface ADR-0023's
  "split by fit" routes *away* from diffusion.

### Alternative 3: Icon font / vector glyphs

- **Description**: A custom icon font or SVG set rendered at runtime.
- **Cons**: Antialiased by nature (fights "never anti-aliased"); harder to lock to the exact
  palette per glyph; adds a font/SVG pipeline for 9 tiny static images.
- **Rejection Reason**: Antialiasing + overkill for a fixed 9-icon MVP set.

### Alternative 4: Keep text glyphs (status quo)

- **Rejection Reason**: Leaves the art bible icon direction unrealized; the user directed UI
  asset generation specifically to add this chrome.

## Consequences

### Positive

- On-spec, palette-locked icon vocabulary; the 3 chrome icons are a visible, player-facing win
  (coin on the gold counter, Slate Ink cog, Guild Amber Dispatch arrow) — addresses the
  "UI/UX not progressing" feedback.
- Fully deterministic + reproducible (`python3 tools/asset-pipeline/compose_icons.py`); the
  committed PNG and the generating code agree exactly (unlike the Gemini-fill convention where
  only the committed final is authoritative).
- Wiring is guarded by an automated regression suite, so a future silent revert of the
  `.icon`/`TextureRect` wiring (the dominant defect class) fails CI.

### Negative

- **Class fills are an authored choice**, not a DESIGN.md token — flagged for veto
  (warrior = Ember Rust, mage = Dusk Purple, rogue = Moss Sage).
- **Single 24px master.** If inline downscale to ~16px reads rough at the smallest sites, a
  16px master per icon is needed (cheap follow-up).
- **6 of 9 icons authored-but-unwired** (class + matchup). Mitigated by naming the wire points
  (formation hero cards; floor-picker matchup hints) as an explicit follow-up — they are *not*
  silently shipped as dead assets.

### Neutral

- Icons live under `assets/art/ui/icons/` (ADR-0023 established `assets/art/ui/` for UI art).
- The Guild Hall wiring is additive (sets `.icon`, adds one `TextureRect` sibling, repositions
  the gold label) — no node reparenting, so existing hard-path tests are unaffected.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 24px master blurs when downscaled to the smallest sites | MEDIUM | LOW | Nearest-filter import; add a 16px master per icon if playtest flags it |
| Class fills rejected on review | LOW | LOW | Veto-after: PR calls them out; one-line edits in `compose_icons.py` |
| The 6 deferred icons never get wired (scaffolded-but-unwired) | MEDIUM | MEDIUM | Wire points named here + in the PR body as an explicit follow-up; not "done" until wired |
| Lossy re-import softens the 1px outline | LOW | MEDIUM | `.import` pinned `compress/mode=0`, `mipmaps/generate=false`; commit the sidecar |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| Draw — chrome icons | text glyphs | 3 small textured quads (gear/arrow icon + coin rect) | <200 draw calls/frame |
| Memory — textures | 0 | 9 × 24×24 RGBA lossless (~negligible) | 256 MB mobile / 512 MB PC |
| Load | — | 3 `preload()`ed `Texture2D` on the Guild Hall | one-shot screen enter |

## Validation Criteria

- [x] `tools/asset-pipeline/compose_icons.py` writes 9 × 24×24 RGBA PNGs to
      `assets/art/ui/icons/`; each `.import` is lossless (`compress/mode=0`,
      `mipmaps/generate=false`).
- [x] PIL contact sheet (`production/qa/evidence/ui_icons_contact_sheet_20260616.png`):
      each icon at 6× nearest, on cream + on slate — palette + 1px Slate Ink stroke verified.
- [x] Headful render — real Guild Hall with the 3 chrome icons wired over the tavern biome +
      parchment theme (`production/qa/evidence/ui_icons_guild_hall_wired_20260616.png`): coin
      disc + G-rune crisp left of the gold value, Slate Ink cog, Guild Amber Dispatch arrow.
- [x] Wiring regression suite (`tests/integration/guild_hall/mvp_icons_wired_test.gd`, 5 cases)
      + existing guild_hall unit/integration suites green.
- [ ] User veto window on class fills + the 24px-single-master decision (veto-after per cadence).
- [ ] Follow-up: wire the 6 display icons (class → formation hero cards; matchup → floor-picker
      matchup hints).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|----------------------------|
| `DESIGN.md` | Design system | §"Iconography" MVP icon set | Authors 9 of the 10 lines as on-spec pixel PNGs (xp_bar is a ProgressBar StyleBox) |
| `DESIGN.md` | Design system | §"Iconography" style: 1px Slate Ink, never anti-aliased, single solid fill, transparent bg | PIL `ImageDraw` rendered directly at 24px (hard-edged, exact palette) |
| `design/art/art-bible.md` | Visual identity | §7 "pixel-outlined with fill" icons | Deterministic pixel tool matches the pixel-outlined direction |
| `DESIGN.md` | Theme cascade | §"Godot Theme implementation" (ADR-0008 canonical theme) | Icons sit on themed Controls; no new theme resource |

## Related

- Sibling: ADR-0023 (parchment panel — Gemini fill + PIL frame); same "generate UI assets"
  directive, opposite tool choice (painterly surface → diffusion; crisp icons → PIL)
- ADR-0008 (root theme cascade); art bible §7 (pixel-outlined icons)
- Tool: `tools/asset-pipeline/compose_icons.py` (PIL, no diffusion)
- Assets: `assets/art/ui/icons/{coin,settings_gear,dispatch_arrow,class_warrior,class_mage,class_rogue,matchup_advantage,matchup_neutral,matchup_disadvantage}.png` (+ `.import`)
- Wiring: `assets/screens/guild_hall/guild_hall.gd` (3 chrome icons)
- Tests: `tests/integration/guild_hall/mvp_icons_wired_test.gd`
- Evidence: `production/qa/evidence/ui_icons_contact_sheet_20260616.png`, `ui_icons_guild_hall_wired_20260616.png`
