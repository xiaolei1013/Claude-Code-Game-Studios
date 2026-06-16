# ADR-0023: Parchment Panel Surface — Static PNG 9-patch Texture (resolves OQ-DS-02)

## Status

Proposed

> Ratify to **Accepted** before the textured `parchment_theme.tres` lands on `main`.
> On acceptance, flip DESIGN.md OQ-DS-02 to "RESOLVED → ADR-0023" (already pointed).

## Date

2026-06-16 (authored under user direction to generate HUD/UI visual assets following
the GDD + art bible; resolves the long-standing OQ-DS-02 panel-surface question)

## Last Verified

2026-06-16

## Decision Makers

- Author (user) — final decision; directed UI/HUD asset generation and provided Gemini API access
- art-director — parchment-material fit vs the art bible's "ink-and-parchment" direction (advisory)
- technical-director — 9-patch safety + theme-cascade integration (the StyleBoxTexture wiring)
- godot-specialist — StyleBoxTexture vs StyleBoxFlat capability boundary (advisory)

## Summary

Resolves **OQ-DS-02** (DESIGN.md §Open Questions): *"is the panel background a solid color
(`#EDE0C4`), a procedural noise overlay, or a static PNG texture?"* → **a static PNG texture**,
wired as a Godot `StyleBoxTexture` 9-patch.

The texture is **composed**, not generated whole: the image model (Gemini) reliably paints a
warm painterly parchment *material* but cannot produce a 9-patch-safe *frame* (it bows the edges
into a pillow/cushion shape and paints opaque near-white corners). A `StyleBoxTexture` 9-patch
needs STRAIGHT edges (the edge slices stretch along their axis — a bowed edge smears) and
TRANSPARENT outside-corners (so panels read as rounded on any background). So the work is split
by what each tool does well:

- **Gemini → the painterly parchment grain/warmth (the FILL).**
- **`tools/asset-pipeline/compose_ui_panel.py` (PIL) → a deterministic crisp ink frame with
  rounded, transparent corners (the GEOMETRY), at the DESIGN.md panel tokens.**

This honors DESIGN.md's *precise tokens* (Slate Ink `#2C2838` border, `radius-panel` 6px) AND the
art bible's *visual direction* (a real parchment texture, not a flat fill) without either
overriding the other.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Theme + asset pipeline (no gameplay code) |
| **Knowledge Risk** | LOW — `StyleBoxTexture`, 9-patch `texture_margin_*`, `Theme` `type_variation`, and lossless `Texture2D` import (`compress/mode=0`, `mipmaps/generate=false`) are stable since 4.0; no post-cutoff API surface. |
| **References Consulted** | DESIGN.md §"Panel style", §"Component vocabulary → Panel", §"Godot Theme implementation", §Open Questions (OQ-DS-02); `design/art/art-bible.md` (parchment direction); ADR-0008 (theme cascade); ADR-0020 (theme-skin direction); Godot 4.6 `StyleBoxTexture` docs |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Headful render of the §96 Return-to-App `SummaryPanel` (ParchmentPanel) over the warm tavern backdrop AND a default `PanelContainer` over a dark dungeon biome (`ember_wastes`) — both saved to `production/qa/evidence/`. Theme-load + biome_background unit suites green. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0008 (root theme cascade — `parchment_theme.tres` is the single canonical Theme; only Control/Window ancestors propagate it); ADR-0020 (theme-skin direction) |
| **Supersedes** | None (refines DESIGN.md §"Panel style" from StyleBoxFlat toward StyleBoxTexture — see Consequences) |
| **Enables** | Painterly parchment warmth on every generic Panel/PanelContainer + the ParchmentPanel variation, game-wide; future per-variant textures (ledger-row, modal) on the same compose recipe |
| **Blocks** | None |

## Context

### Problem Statement

DESIGN.md left OQ-DS-02 open: the art bible calls for a "parchment texture" but the panel
background had only ever been a flat `StyleBoxFlat` (solid `#EDE0C4` + 1px border + subtle ink
drop shadow). The user directed generating UI/HUD assets following the GDD + art bible, which
forces the OQ-DS-02 decision: solid color (status quo), procedural noise overlay, or a static
PNG texture.

### Current State (pre-this-ADR)

- `assets/ui/parchment_theme.tres` backed `panel_default` (all generic Panel/PanelContainer) and
  the `panel_parchment` (`ParchmentPanel`) variation with **`StyleBoxFlat`** sub-resources:
  flat `#EDE0C4`, `border_width=1`, `border_color=#2C2838`, `corner_radius=6`, a soft shadow.
- `ParchmentPanel` is applied via `UIFramework.apply_parchment_panel(panel)` on the §96
  Return-to-App `SummaryPanel` and `formation_assignment` (`src/ui/ui_framework.gd`).
- No parchment *texture* existed anywhere; the art bible's parchment direction was unrealized.

### Constraints

- **9-patch safety**: edges must be straight (stretch cleanly) and outside-corners transparent
  (panels rounded on any background) — the raw Gemini output satisfies neither.
- **Precise tokens win (DESIGN.md)**: Slate Ink `#2C2838`, `radius-panel` 6px must be exact.
- **Visual direction wins (art bible)**: a real parchment material, not a flat fill.
- **Pipeline hygiene**: the core `generate.py` stays stdlib-only; PIL is an explicit dep of the
  optional `compose_ui_panel.py` post-step only. Raw model output must not spawn Godot `.import`
  sidecars.
- **PR workflow**: assets + theme land via PR; no direct push to `main`.

## Decision

**OQ-DS-02 → static PNG 9-patch texture, composed (Gemini fill + PIL ink frame), wired into
`parchment_theme.tres` as `StyleBoxTexture` on both `panel_default` and `panel_parchment`.**

### Architecture

```
[ Gemini ]                         [ asset pipeline ]                          [ Godot ]
 manifests/full.json (images.ui)  ──► tools/asset-pipeline/sources/            (raws are
   id=ui_panel_parchment,              ui_panel_parchment_src.png   ◄── .gdignore  Godot-ignored:
   style=ui, 512x512  ──────────►      (raw painterly parchment FILL, pillowy)    no .import)
                                              │
                  compose_ui_panel.py (PIL)   │  centre-crop 0.60 → 256px fill
                  ─────────────────────────►  ▼  + rounded transparent mask (BOX downscale)
                                          assets/art/ui/ui_panel_parchment.png    + ink frame
                                          (256×256 RGBA, committed + imported)     (Slate Ink)
                                              │  uid://dxbbhee8ph068, compress=0 lossless
                                              ▼
   parchment_theme.tres  ── StyleBoxTexture { texture=ExtResource(parchment),
                                              texture_margin_*=14, content_margin_* kept }
                              ├── panel_default     (all generic Panel/PanelContainer)
                              └── panel_parchment    (ParchmentPanel variation)
                                              │  cascades via root theme (ADR-0008)
                                              ▼
                         every panel renders the painterly parchment 9-patch
```

### Key tokens (baked into the PNG by `compose_ui_panel.py`)

| Token | Value | Source |
|-------|-------|--------|
| Border color | Slate Ink `#2C2838` = `(44,40,56)` | DESIGN.md (replaces black everywhere) |
| Corner radius | 6px (`radius-panel`) | DESIGN.md §Border radius |
| Border thickness | **2px** (painted ink frame) | This ADR — see Consequences (was 1px in StyleBoxFlat) |
| 9-patch margin | `texture_margin_* = 14px` (≥ radius+border) | Set in `.tres`; corners stay fixed, centre/edges stretch |
| Texture size | 256×256 RGBA, lossless | `compose_ui_panel.py` `SIZE`; `compress/mode=0` |

### Implementation Guidelines

- Regenerating the raw (manifest `images.ui`) writes to the Godot-ignored `sources/` dir; the
  **committed** final under `assets/art/ui/` is authoritative (Gemini is non-deterministic, so we
  commit the composed output, not the raw — consistent with the project's commit-finals convention).
- Re-compose with `python3 tools/asset-pipeline/compose_ui_panel.py [SRC] [OUT]` (PIL required).
- Commit the `.png` + its `.import` + (if present) `.uid` together (project `.uid` rule).
- Both `Image.BOX` downscales (mask + frame) are deliberate — area-average avoids the LANCZOS
  ringing that left a faint light fringe on the extreme outside-corner pixel.

## Alternatives Considered

### Alternative 1: Composed static PNG (Gemini fill + PIL ink frame) — CHOSEN

- **Pros**: Realizes the art bible parchment direction; exact DESIGN.md ink/ radius tokens via the
  PIL frame; 9-patch-safe (straight edges, transparent corners); crisp at any panel size; lossless
  import; reproducible recipe; no shader cost.
- **Cons**: Loses the StyleBoxFlat vector drop shadow; 2px painted border (vs DESIGN.md 1px);
  Gemini non-determinism means the committed final — not the manifest prompt — is the source of truth.
- **Rejection Reason**: N/A — chosen.

### Alternative 2: Raw Gemini texture wired directly

- **Description**: Drop the model's 512px parchment straight into a StyleBoxTexture.
- **Cons**: Pillowy/bowed edges smear under 9-patch edge-stretch; opaque near-white corners read as
  square nubs on any non-cream background. Not 9-patch-safe.
- **Rejection Reason**: Fails the straight-edge + transparent-corner requirement.

### Alternative 3: Procedural noise overlay (shader) — the third OQ-DS-02 option

- **Description**: A runtime parchment-grain shader over a flat fill.
- **Cons**: Adds a per-panel shader pass (HD-2D shader work is deferred per ADR-0017); harder to
  match the art bible's hand-painted warmth than a painted texture; more runtime cost for a static
  surface.
- **Rejection Reason**: Cost + ADR-0017 deferral; a static texture is the lighter, art-faithful fit.

### Alternative 4: Keep flat StyleBoxFlat (status quo)

- **Rejection Reason**: Leaves the art bible parchment direction unrealized; the user directed UI
  asset generation specifically to add this warmth.

## Consequences

### Positive

- Painterly parchment warmth on **every** panel game-wide (both `panel_default` and the
  `ParchmentPanel` variation) — directly addresses "UI/UX not progressing" feedback with a visible win.
- Art bible visual direction (real parchment) AND DESIGN.md precise tokens (Slate Ink, 6px radius)
  both honored — the split-by-tool recipe needs no override of either.
- 9-patch renders crisp corners at any panel size; lossless import (`compress/mode=0`,
  `mipmaps/generate=false`) keeps the thin ink frame sharp.
- Verified by headful render on both a warm (tavern) and a dark (ember_wastes) background.

### Negative

- **Drop shadow lost.** `StyleBoxTexture` has no vector shadow (StyleBoxFlat-only). Panel/background
  separation now relies on the ink border + tonal contrast. Renders read cleanly on warm and dark
  backgrounds, but DESIGN.md §"Panel style" + the `modal` variant ("1px Slate Ink + drop shadow")
  must be read in conjunction with this ADR. A soft shadow could later be **baked into the texture's
  transparent margin** if separation proves weak in playtest (future enhancement, not MVP).
- **2px painted border** vs DESIGN.md's documented 1px — a deliberate compensation for the lost
  shadow (retains edge definition). A precise-token deviation, recorded here for veto.
- The committed PNG (not the manifest prompt) is authoritative due to model non-determinism.

### Neutral

- `content_margin_*` (inner padding) is preserved from the prior StyleBoxFlat (12/10 default;
  18/14 parchment) — text layout unchanged.
- Theme sub-resource ids kept stable → no reference churn; `load_steps` +1 (the ext_resource only).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Shadow loss weakens panel separation on busy backgrounds | MEDIUM | LOW | Ink border + contrast verified on warm + dark renders; bake a margin shadow later if playtest flags it |
| 2px border reads heavier than the art bible intends | LOW | LOW | Veto-after: PR calls it out; trivial to re-compose at `BORDER=1` |
| Re-running the manifest overwrites the composed final | LOW | MEDIUM | Raw routes to Godot-ignored `sources/`; final under `assets/art/ui/` is separate + committed |
| Lossy re-import blurs the thin ink frame | LOW | MEDIUM | `.import` pinned to `compress/mode=0` lossless, `mipmaps/generate=false`; commit the sidecar |

## Performance Implications

| Metric | Before (StyleBoxFlat) | Expected After (StyleBoxTexture) | Budget |
|--------|-----------------------|----------------------------------|--------|
| Draw — per panel | vector fill+border+shadow | one 9-patch textured quad | <200 draw calls/frame |
| Memory — texture | 0 | one 256×256 RGBA lossless (~shared across all panels) | 256 MB mobile / 512 MB PC |
| Load — theme | preload `.tres` | + one `Texture2D` ext_resource | one-shot boot |

## Validation Criteria

- [x] Composed `assets/art/ui/ui_panel_parchment.png` (256×256 RGBA): opaque warm cream centre,
      genuine antialiased transparent rounded corners, ~2px Slate Ink frame on straight edges.
- [x] `.import` is lossless (`compress/mode=0`, `mipmaps/generate=false`); `uid://dxbbhee8ph068`.
- [x] `parchment_theme.tres` `panel_default` + `panel_parchment` are `StyleBoxTexture` with the
      parchment ext_resource and `texture_margin_* = 14`; theme-load verified headlessly.
- [x] Headful render — §96 Return-to-App `SummaryPanel` over the tavern backdrop: gold header +
      all dark Slate-Ink rows legible (`ui_panel_parchment_return_to_app_20260616.png`).
- [x] Headful render — default `PanelContainer` over dark `ember_wastes`: rounded transparent
      corners + ink border read cleanly, body text legible (`ui_panel_default_dark_20260616.png`).
- [ ] Theme + `biome_background` unit suites re-run green after the change.
- [ ] User veto window on shadow-loss + 2px border (veto-after per the operating cadence).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|----------------------------|
| `DESIGN.md` | Design system | OQ-DS-02 (panel-surface implementation) | Resolves → static PNG 9-patch texture |
| `DESIGN.md` | Design system | §"Panel style" Slate Ink `#2C2838` border, `radius-panel` 6px | Baked into the PIL ink frame at exact tokens |
| `design/art/art-bible.md` | Visual identity | "ink-and-parchment" parchment-texture direction | Painterly Gemini fill realizes the parchment material |
| `DESIGN.md` | Theme cascade | §"Godot Theme implementation" (ADR-0008 canonical theme) | Wired into the single `parchment_theme.tres`; no new resource |

## Related

- Refines: DESIGN.md §"Panel style (StyleBoxFlat)" — panels now StyleBoxTexture; OQ-DS-02 resolved
- ADR-0008 (root theme cascade); ADR-0020 (theme-skin direction); ADR-0017 (HD-2D shader deferral — why not a noise shader)
- Asset: `assets/art/ui/ui_panel_parchment.png` (+ `.import`); theme: `assets/ui/parchment_theme.tres`
- Pipeline: `tools/asset-pipeline/compose_ui_panel.py` (new compose step); `manifests/full.json` (`images.ui`); `tools/asset-pipeline/sources/` (Godot-ignored raws)
- Evidence: `production/qa/evidence/ui_panel_parchment_return_to_app_20260616.png`, `ui_panel_default_dark_20260616.png`
