# HD-2D Rendering Pipeline — GDD #26

> **Status: APPROVED 2026-05-14** by Sprint 19 S19-M1. Expands the Sprint 15 STUB DRAFT
> into a full first-pass GDD with all 8 required sections. Sprint 19 is the Vertical
> Slice tier activation per ADR-0017 §Pivot Triggers #1 (N1 shader shipped Sprint 18).
> Successor ADR-0019 authored alongside in Sprint 19 S19-M2.

---

## A. Overview

**HD-2D Rendering Pipeline** is the canvas-item post-process chain that delivers the
project's Visual Identity Anchor (per `design/gdd/game-concept.md` §Visual Identity
Anchor + Pillar 4 HD-2D Pixel Pride): biome-flavored background content layered with a
tilt-shift depth-of-field pass and a warm-lantern overlay tint, with the game's UI
rendered sharp on top. The system is the upper polish layer on top of the parchment
theme (S10-M1 / S10-M2 / ADR-0008) — parchment is the visual baseline that ships in
MVP; HD-2D is the "Octopath-inspired" finish that ships at Vertical Slice tier per
`game-concept.md` §Roadmap.

**Sprint 19 activates the pipeline** with programmatic biome backgrounds (gradient
ColorRects keyed to each biome's `primary_palette_key`) as internal-playtest proxies.
Real product art (in-flight in a separate workstream) drops in later as a zero-code
BiomeBackground scene swap.

**Pipeline at activation (Sprint 19)**:

```
Scene tree                         Render order (z_index ascending)
─────────────────                  ──────────────────────────────────
ScreenRoot (Control, z=0)          1. BiomeBackground       (z=-1)
├── BiomeBackground   (z=-1)       2. BackBufferCopy        (z=-1, after BB in tree)
├── BackBufferCopy    (z=-1)       3. TiltShiftDof          (z=-1, blurs captured BB)
├── TiltShiftDof      (z=-1)       4. UI content            (z=0, sharp)
├── [UI content]      (z=0)        5. WarmLanternOverlay    (z=1, amber wash on top)
└── WarmLanternOverlay (z=1)
```

This layer-order contract is the architectural fix for the Sprint 18 N1 ghost-smear
bug (tilt-shift blurring UI text): backgrounds must exist BELOW the BackBufferCopy,
not above it.

---

## B. Player Fantasy

**Intended feeling**: *"I'm looking at a hand-painted diorama by lantern-light."*

The HD-2D pipeline converts what is structurally a UI-heavy idle clicker into a visual
artifact the player would screenshot and share. The cozy register (per
`design/gdd/game-concept.md` Pillar 4) lives in three composed visual beats:

1. **The biome background sets place.** The player knows whether they're in the
   moss-and-amber Forest Reach, the ochre-and-purple Sunken Ruins, or the
   ember-and-charcoal Ember Wastes from the background tone alone — before they read
   any text. The palette telegraphs threat-flavor (warm amber = cozy onboarding;
   cooler purples = harder content; embered reds = elite-tier biomes).
2. **The tilt-shift miniaturizes the world.** The diorama-on-a-tabletop register
   tells the player *"this is a curated experience, not a generic procedural
   clicker."* The horizontal sharp band keeps the focal action readable while the
   periphery softens into painterly suggestion. The world feels small enough to
   hold in your hands.
3. **The warm-lantern wash sets time and intimacy.** The amber corner vignette
   reads as evening light through a tavern lantern. The player is told, without
   words, *"you're inside a warm place; the dungeons are out there in the dark."*
   This is the visual signature of the cozy register — the opposite of the
   high-contrast urgency of action games.

**Anti-fantasy**: This pipeline must NOT feel "filtered" in the Instagram sense.
Each pass is in service of the diorama register; if a pass starts feeling like a
stuck color grade, the tuning knobs in §G are how it gets corrected — not by removing
the pipeline.

---

## C. Detailed Rules

### C.1 The Layer-Order Contract

The five rendering layers, in render order:

| Layer | z_index | Role | Mouse_filter |
|-------|---------|------|--------------|
| BiomeBackground | -1 | Per-biome palette ColorRect or sprite | IGNORE (2) |
| BackBufferCopy | -1 (after BiomeBackground in tree) | Captures captured pixels for tilt-shift sampling | n/a |
| TiltShiftDof | -1 (after BackBufferCopy in tree) | Reads back buffer, applies vertical Gaussian blur with focal band | IGNORE (2) |
| UI content | 0 (default) | Labels, buttons, panels — must render sharp | PASS (1) or STOP (0) |
| WarmLanternOverlay | 1 | Amber corner vignette over everything | IGNORE (2) |

**Rule C.1.1**: BiomeBackground, BackBufferCopy, and TiltShiftDof all share `z_index = -1`.
Their render order within that z layer is determined by **scene tree position** (Godot
canvas_item sort: same z → tree order ascending). The required tree order is
BiomeBackground → BackBufferCopy → TiltShiftDof.

**Rule C.1.2**: UI content stays at default z (0). It MUST render sharp. The
TiltShiftDof's `screen_texture` sampler reads the back buffer captured by the
BackBufferCopy — which was captured BEFORE UI rendered. Therefore tilt-shift cannot
blur UI even if its ColorRect overlaps UI screen-space.

**Rule C.1.3**: WarmLanternOverlay z_index MUST be greater than UI z_index. Default
WarmLanternOverlay z_index = 1. It composites over everything: BiomeBackground (via the
already-blurred screen) + UI text — both get the amber corner vignette.

**Rule C.1.4**: mouse_filter on overlay ColorRects (BiomeBackground, TiltShiftDof,
WarmLanternOverlay) MUST be `MOUSE_FILTER_IGNORE` (value 2). These nodes are visual
only; they must not intercept input.

### C.2 BiomeBackground Node Contract

`BiomeBackground` is a Godot scene (`assets/screens/_shared/biome_background.tscn`) +
script that exposes:

```gdscript
class_name BiomeBackground extends ColorRect

## Sets the visual palette by biome_id. Looks up the palette key from the
## biome's DataRegistry resource and applies the matching gradient preset.
func set_biome(biome_id: String) -> void: ...

## Returns the current biome_id (or empty string if not set).
func get_biome() -> String: ...

signal biome_changed(old_biome_id: String, new_biome_id: String)
```

**Rule C.2.1**: BiomeBackground anchors at full-rect (anchors_preset = 15), sized
to fill the parent screen. Window resize is automatic via the anchor system; no
explicit handling required.

**Rule C.2.2**: BiomeBackground accepts six palette presets in MVP (Sprint 19):
`forest_reach`, `whispering_crags`, `sunken_ruins`, `hollow_stair`, `ember_wastes`,
`frostmire`. A seventh preset, `guild_hall_tavern`, ships for the Guild Hall screen
(non-biome but uses the same node contract).

**Rule C.2.3**: When `set_biome(biome_id)` is called with an unknown id, the node
falls back to `forest_reach` palette and emits a `push_warning`. Combat dispatch
should not silently render the wrong biome — but it also should not crash on missing
data.

### C.3 Tilt-Shift Activation Guard

The tilt-shift shader exposes an `enabled` uniform (float, 0.0 or 1.0). When
`enabled = 0.0`, the fragment shader short-circuits to a single texture tap
(`COLOR = texture(screen_texture, SCREEN_UV)`) — effectively transparent
(see §D.2 for the math).

**Rule C.3.1**: Sprint 19 ships `enabled = 1.0` on both Guild Hall and DungeonRunView
ShaderMaterial_tilt_shift sub_resources, replacing the disabled-by-default state from
Sprint 18.

**Rule C.3.2**: If a future regression causes UI ghost-smear (the Sprint 18 N1 bug),
the immediate mitigation is to flip `enabled = 0.0` on the affected scene's
ShaderMaterial. The shader infrastructure remains intact; the visual effect is
suppressed pending architecture fix.

### C.4 Composition Order Invariant

The composition produces this visual stack from back to front:

1. Biome palette (background tone)
2. Blurred biome palette (via tilt-shift sampling the back buffer)
3. Sharp UI (labels, buttons, panels)
4. Warm-lantern amber vignette over everything

The user perceives the blurred background BEHIND sharp UI WITH a warm vignette ON TOP.
The composition order is invariant — reversing any pair (warm-lantern under tilt-shift,
UI under tilt-shift, etc.) produces a different visual register that violates the
diorama fantasy in §B.

---

## D. Formulas

### D.1 Tilt-Shift Per-Fragment Blur Radius

The shader computes a per-fragment blur radius based on the fragment's vertical
distance from the focus band:

```
dy = |UV.y - focus_y|
ramp = smoothstep(0.0, falloff_softness, dy - focus_height)
radius = ramp × blur_strength × enabled
```

Where:

| Variable | Type | Domain | Default | Description |
|----------|------|--------|---------|-------------|
| `UV.y` | float | [0,1] | n/a | Fragment vertical UV coord |
| `focus_y` | uniform float | [0,1] | 0.5 | Vertical center of the sharp focus band |
| `focus_height` | uniform float | [0, 0.5] | 0.2 | Half-height of fully-sharp region |
| `falloff_softness` | uniform float | [0.01, 1.0] | 0.25 | Soft ramp width from sharp → max blur |
| `blur_strength` | uniform float | [0, 0.05] | 0.015 | Max blur sample offset in UV space |
| `enabled` | uniform float | {0.0, 1.0} | 1.0 | Master activation toggle |

**Boundary behavior**:
- When `dy ≤ focus_height`: `ramp = 0` → `radius = 0` → fragment is sharp (single tap).
- When `dy ≥ focus_height + falloff_softness`: `ramp = 1` → `radius = blur_strength × enabled` (max).
- In between: smoothstep produces a smooth cubic ramp.

**Example calculation** (focus_y=0.5, focus_height=0.2, falloff_softness=0.25, blur_strength=0.015):

| UV.y | dy | dy - focus_height | ramp | radius (enabled=1.0) |
|------|------|-----|------|--------|
| 0.50 | 0.00 | -0.20 | 0.000 | 0.0000 (sharp) |
| 0.55 | 0.05 | -0.15 | 0.000 | 0.0000 (sharp) |
| 0.70 | 0.20 | 0.00 | 0.000 | 0.0000 (sharp band edge) |
| 0.80 | 0.30 | 0.10 | 0.352 | 0.0053 (soft blur) |
| 0.95 | 0.45 | 0.25 | 1.000 | 0.0150 (max blur) |
| 1.00 | 0.50 | 0.30 | 1.000 | 0.0150 (max blur, clamped) |

### D.2 Tilt-Shift 9-Tap Gaussian

For fragments where `radius > 0.0001`, the shader samples 9 taps along the Y axis:

```
COLOR = Σᵢ₌₀⁸ texture(screen_texture, SCREEN_UV + vec2(0.0, OFFSETS[i] × radius)) × WEIGHTS[i]
```

Where:

```
OFFSETS = [-4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0]
WEIGHTS = [0.05, 0.09, 0.12, 0.15, 0.18, 0.15, 0.12, 0.09, 0.05]  // Σ = 1.00, σ ≈ 1.5
```

For fragments where `radius ≤ 0.0001`, the shader short-circuits to a single tap:

```
COLOR = texture(screen_texture, SCREEN_UV)
```

The short-circuit avoids 8 redundant texture samples on fragments inside the sharp band
— typically 30-50% of screen fragments take this path.

### D.3 Per-Biome Tilt-Shift Parameter Defaults

S19-S2 ships per-biome tuned presets. Sprint 19 M3 defaults all biomes to:
`(focus_y=0.5, focus_height=0.2, falloff_softness=0.25, blur_strength=0.015, enabled=1.0)`.
S19-S2 may adjust per biome based on M5 playtest signal.

Recommended adjustment direction (subject to S2 playtest tuning):

| Biome | Visual feel | focus_y | blur_strength | Reason |
|-------|-------------|---------|---------------|--------|
| forest_reach | Open canopy | 0.5 | 0.012 | Shallow DoF; world feels accessible |
| whispering_crags | Misty heights | 0.55 | 0.018 | Slightly lower focus, more atmospheric blur |
| sunken_ruins | Underwater dim | 0.5 | 0.020 | Deeper DoF emphasizes "lost place" |
| hollow_stair | Underground | 0.5 | 0.022 | Deepest DoF; oppressive enclosure |
| ember_wastes | Volcanic | 0.5 | 0.016 | Moderate; ember-haze register |
| frostmire | Frozen | 0.5 | 0.018 | Slightly deeper; cold-fog register |

### D.4 Warm-Lantern Vignette (Sprint 15 N2, reference)

The warm-lantern shader's per-fragment alpha mask (already shipped):

```
centered = UV - vec2(0.5)
d = length(centered) × 2.0
mask = smoothstep(vignette_radius, vignette_radius + vignette_softness, d)
COLOR.a = mask × intensity × warm_color.a
```

Default: `vignette_radius=0.55, vignette_softness=0.45, intensity=0.35`. Center fully
transparent; corners receive subtle amber warmth at α≈0.35.

---

## E. Edge Cases

| Case | What happens | Why |
|------|--------------|-----|
| **No BiomeBackground in scene** | TiltShiftDof samples a transparent back buffer; output is transparent; only UI + WarmLanternOverlay visible. | The pipeline degrades gracefully — missing layers produce missing visuals, not crashes. |
| **`set_biome("unknown_id")`** | Falls back to `forest_reach` preset + emits `push_warning`. | Sprint 19 ships 6 biomes; future biomes added to the registry need a matching palette preset, but a missing one must not crash the scene. |
| **`set_biome("")` (empty string)** | Treated as unknown; falls back to `forest_reach`. | Defensive — caller may pass empty during scene transition. |
| **BiomeBackground swapped mid-frame** | One frame may show the old palette; next frame shows new. No flicker beyond 1 frame. | Acceptable — biome transitions are deliberate user actions, not high-frequency events. |
| **Window resize (Steam Deck rotates / desktop maximizes)** | All overlay ColorRects re-anchor automatically via `anchors_preset = 15`. No special handling. | Anchored full-rect is the standard Godot pattern; tested via Sprint 18 shader tests' scene loading. |
| **Reduce-motion accessibility flag enabled** | Tilt-shift remains active; warm-lantern remains active. Neither effect involves temporal motion. | Per Settings GDD #30 §C, reduce_motion clamps motion-heavy effects (animations, tweens). A static blur and static color grade do not qualify. The pipeline is reduce_motion-neutral. |
| **Mobile platform (low-end Android)** | Possible regression: 9-tap Gaussian may dip below 60fps. | Sprint 19 ships desktop-only; mobile re-profiling is a Sprint 19+ scope (V1.5 mobile port milestone per ADR-0017 §Pivot Trigger #3). Project setting `tilt_shift_quality` may be added to switch to 5-tap on mobile. |
| **`enabled = 0.0` set at runtime** | Shader short-circuits to single-tap pass-through; BiomeBackground renders as-is, no blur. | The disabled state is a safe fallback during regression mitigation. |
| **Multiple BiomeBackground nodes in scene (misconfiguration)** | The last one in tree order at z=-1 wins (Godot canvas_item rule). | Document the contract: 1 BiomeBackground per scene. Tests verify the singleton invariant. |
| **WarmLanternOverlay z_index accidentally set to 0 or negative** | Lantern wash renders below or beside UI instead of on top. Visible regression: corners feel unfinished. | Sprint 19 tests assert `WarmLanternOverlay.z_index > UI_label.z_index`. |
| **BiomeBackground swapped via `set_biome()` during dispatch** | Underlying biome data does not change mid-run (per ADR-0001 mid-run immutability); the visual swap would only happen between runs. | Caller responsibility — DRV reads `run_snapshot.biome_id` once at entry, not per tick. |

---

## F. Dependencies

| System | Why | Surface used |
|--------|-----|--------------|
| **Godot 4.6 Forward+ rendering** | Engine substrate | canvas_item shaders, BackBufferCopy node, `hint_screen_texture` sampler binding, z_index sort, anchor system |
| **Parchment Theme + UIFramework** (#18, ADR-0008) | UI visual baseline | UI text/buttons render sharp at z=0 above the tilt-shift output; parchment theme styling unchanged |
| **Biome & Dungeon Database** (#22) | Biome identity + palette key | `Biome.primary_palette_key` field → BiomeBackground preset lookup |
| **Floor Unlock System** (#10) | Biome switch signals | Emits `current_biome_changed(biome_id)` when player navigates biomes; DRV calls `BiomeBackground.set_biome()` in response |
| **Dungeon Run Orchestrator** (#13) | Biome context | `run_snapshot.biome_id` is the source of truth during a dispatched run; DRV reads it on entry |
| **DataRegistry** | Biome resource resolution | `DataRegistry.resolve("biomes", biome_id)` returns the Biome resource for palette lookup |
| **Art Bible** (`design/art/art-bible.md`) §Visual Identity Anchor | Visual direction | Tilt-shift focus_y placement, warm-lantern amber tone, biome palette keys |
| **`game-concept.md` Pillar 4 HD-2D Pixel Pride** | Strategic context | Diorama fantasy + cozy register positioning |
| **ADR-0017** | Deferral rationale + pivot triggers | Sprint 19 activates per Pivot Trigger #1 (N1 shader shipped Sprint 18) |
| **ADR-0019** (this sprint, S19-M2) | Activation decision | Layer-order contract + BiomeBackground node contract + programmatic-placeholder strategy |
| **Settings GDD #30** §C reduce_motion | Accessibility | Pipeline is reduce_motion-neutral; no clamping needed |
| **Performance budget per `.claude/docs/technical-preferences.md`** | Constraint | Steam Deck 1280×800 60fps; tilt-shift ≤4ms per OQ-26-4 |

### Reverse dependencies

- **VFX System** (#27, sibling Vertical Slice tier GDD) — particle effects compose with the HD-2D pipeline; #27 references this GDD's layer-order contract for blend-mode + render-order coordination.
- **All shipped screens** — guild_hall, dungeon_run_view, formation_assignment, recruit_screen, return_to_app_view, victory_moment, hero_detail_modal, matchup_assignment_screen — render at z=0 above this pipeline. Sprint 19 wires GuildHall + DungeonRunView; remaining screens wire opportunistically when touched.

---

## G. Tuning Knobs

### G.1 Tilt-Shift Shader Uniforms (per ShaderMaterial)

| Uniform | Type | Safe range | Default | Gameplay aspect |
|---------|------|-----------|---------|-----------------|
| `focus_y` | float | [0.0, 1.0] | 0.5 | Vertical placement of sharp band. 0.5 = middle; 0.6 = lower (action sits lower); 0.4 = upper. |
| `focus_height` | float | [0.05, 0.5] | 0.2 | Size of sharp band. Larger = more of screen sharp; smaller = more diorama feel. |
| `blur_strength` | float | [0.0, 0.05] | 0.015 | Max blur intensity at screen edges. 0.0 = no blur; 0.05 = soup. >0.04 starts looking artificial. |
| `falloff_softness` | float | [0.05, 1.0] | 0.25 | Ramp width from sharp to max blur. Smaller = harder edge; larger = painterly gradient. |
| `enabled` | float | {0.0, 1.0} | 1.0 | Runtime activation. Bind to settings or accessibility flag. 0.0 = pass-through. |

### G.2 Warm-Lantern Shader Uniforms (per ShaderMaterial — Sprint 15 N2)

| Uniform | Type | Safe range | Default | Gameplay aspect |
|---------|------|-----------|---------|-----------------|
| `warm_color` | vec4 | RGBA | (1.0, 0.65, 0.35, 1.0) | Vignette tint. Default = lantern-gold from parchment palette. |
| `vignette_radius` | float | [0.0, 1.0] | 0.55 | Inner radius (center-out) below which no warmth applied. |
| `vignette_softness` | float | [0.0, 1.0] | 0.45 | Soft falloff from inner radius outward. |
| `intensity` | float | [0.0, 1.0] | 0.35 | Final vignette opacity multiplier. >0.6 starts feeling oppressive. |

### G.3 BiomeBackground Palette Mapping (per biome — Sprint 19 M3)

| biome_id | primary_palette_key | Preset colors (approximate) |
|----------|---------------------|-----------------------------|
| `forest_reach` | `moss_sage_guild_amber` | Moss green → sage → amber gradient |
| `whispering_crags` | `grey_teal_mist` | Cool grey → teal → mist white |
| `sunken_ruins` | `ochre_dusk_purple` | Ochre → dusk purple → deep wine |
| `hollow_stair` | `grey_bone_charcoal` | Bone white → grey → charcoal black |
| `ember_wastes` | `ember_rust_charcoal` | Rust orange → ember red → charcoal |
| `frostmire` | `ice_blue_slate` | Ice blue → slate grey → frostbite white |
| `guild_hall_tavern` (non-biome) | `tavern_warm_amber` | Tavern amber → warm wood → dim lantern |

Palette key strings MUST match `design/art/art-bible.md` §4 color system entries. Art
Bible is authoritative for the precise RGB values; this GDD specifies the directional
register.

### G.4 Activation Source of Truth

ShaderMaterial sub_resources in scene `.tscn` files are the authoritative source for
`enabled` values. There is no autoload toggle in Sprint 19; future Settings GDD #30
work may add a `disable_hd2d_pipeline` accessibility flag that overrides per-scene
`enabled` values, but Sprint 19 ships with per-scene control only.

---

## H. Acceptance Criteria

| AC ID | Criterion | Evidence type |
|-------|-----------|---------------|
| AC-26-01 | Tilt-shift shader loads as a Shader resource at `res://assets/shaders/tilt_shift_dof.gdshader`. | Unit test (shipped S18-N1) |
| AC-26-02 | Tilt-shift shader exposes the 5 contract uniforms + the `hint_screen_texture` binding. | Unit test (shipped S18-N1) |
| AC-26-03 | Warm-lantern shader loads as a Shader resource at `res://assets/shaders/warm_lantern_overlay.gdshader`. | Unit test (shipped S15-N2) |
| AC-26-04 | Warm-lantern shader exposes the 4 contract uniforms (warm_color, vignette_radius, vignette_softness, intensity). | Unit test (shipped S15-N2) |
| AC-26-05 | Guild Hall scene resolves both shader resources via ExtResource references. | Unit test (shipped S15-N2 + S18-N1) |
| AC-26-06 | DungeonRunView scene resolves both shader resources via ExtResource references. | Unit test (shipped S18-N1; extended Sprint 19 M3 for warm-lantern) |
| AC-26-07 | TiltShiftDof.z_index < WarmLanternOverlay.z_index in both Guild Hall and DungeonRunView (composition order invariant from §C.4). | Unit test (shipped S18-N1; updated Sprint 19 M4) |
| AC-26-08 | TiltShiftDof.z_index < (lowest UI-label z_index) in both Guild Hall and DungeonRunView (UI sharpness guard). | Unit test (NEW Sprint 19 M4) |
| AC-26-09 | BiomeBackground node exists in DungeonRunView at z_index = -1. | Unit test (NEW Sprint 19 M3) |
| AC-26-10 | BiomeBackground node exists in Guild Hall at z_index = -1 with `guild_hall_tavern` palette preset. | Unit test (NEW Sprint 19 M3) |
| AC-26-11 | BiomeBackground exposes `set_biome(biome_id: String)` method that updates the visible palette. | Unit test (NEW Sprint 19 M3) |
| AC-26-12 | BiomeBackground accepts 7 palette keys (6 biomes + `guild_hall_tavern`) and falls back to `forest_reach` on unknown. | Unit test (NEW Sprint 19 M3) |
| AC-26-13 | Tilt-shift `enabled = 1.0` in both Guild Hall and DungeonRunView ShaderMaterial sub_resources (replaces S18 disabled-by-default state). | Unit test (NEW Sprint 19 M4) |
| AC-26-14 | Sprint 19 visual playtest PASS: diorama register perceptible, no UI ghost-smear, warm-lantern composes correctly, gradients read as biome-flavored, perf budget holds. | Playtest doc (Sprint 19 M5) |
| AC-26-15 | Mouse/tap input on UI elements unaffected by overlay ColorRects (BiomeBackground, TiltShiftDof, WarmLanternOverlay all use `mouse_filter = MOUSE_FILTER_IGNORE`). | Manual smoke check + unit test asserting `mouse_filter = 2` on all three nodes |

---

## I. Resolved Open Questions

The Sprint 15 stub flagged 7 open questions (OQ-26-1 through OQ-26-7). Sprint 19
resolves them inline:

- **OQ-26-1 — Tilt-shift parameters** → **Resolved.** §G.1 specifies the 5 uniforms with safe ranges and defaults; §D.3 specifies per-biome adjustment directions for S19-S2 tuning.
- **OQ-26-2 — Warm-lantern color grade** → **Resolved (Sprint 15 N2).** §G.2 specifies the 4 uniforms; default `warm_color` is `(1.0, 0.65, 0.35, 1.0)` matching the parchment-theme lantern-gold reward color.
- **OQ-26-3 — Composition root location** → **Resolved as per-screen.** Sprint 19 wires GuildHall + DungeonRunView via in-scene BackBufferCopy + ColorRect overlays. MainRoot-level SubViewport composition is NOT used — per-screen overlay is simpler, lower memory, and adequate for the project's 2D UI register. Documented in ADR-0019.
- **OQ-26-4 — Performance budget** → **Resolved.** Tilt-shift 9-tap Gaussian budgeted at ≤4ms; warm-lantern at <1ms; combined ≤5ms; leaves >11ms for combat-tick + UI rendering. Sprint 19 M5 playtest validates on dev hardware; Steam Deck profiling deferred to Sprint 19+ when hardware access is available.
- **OQ-26-5 — Mobile compatibility** → **Deferred.** Sprint 19 ships desktop-only. Mobile re-profiling is a Sprint 19+ scope; ADR-0017 §Pivot Trigger #3 (mobile port milestone) is the gate. Project setting `tilt_shift_quality` may be added later to switch to 5-tap.
- **OQ-26-6 — Reduce-motion accessibility** → **Resolved.** Both effects are temporally static; reduce_motion does NOT clamp. §E documents the rationale.
- **OQ-26-7 — Successor ADR** → **Resolved.** ADR-0019 (Sprint 19 S19-M2) authored as successor to ADR-0017. Records the activation decision + layer-order contract + BiomeBackground node contract.

---

## Notes

- This GDD's `STUB DRAFT` → `APPROVED` transition closes the systems-index.md row 26 status transition for Sprint 19. Update `design/gdd/systems-index.md` accordingly in M3.
- Pairs with: `docs/architecture/ADR-0017-hd-2d-shader-pass-deferred-to-vertical-slice.md` (predecessor); `docs/architecture/ADR-0019-hd2d-pipeline-activation.md` (this sprint's M2 successor); `design/gdd/vfx-system.md` (#27, sibling Vertical Slice tier GDD); `design/art/art-bible.md` §Visual Identity Anchor (visual direction); `design/gdd/game-concept.md` Pillar 4 + §Roadmap Vertical Slice tier scheduling.
- The Sprint 18 N1 tilt-shift shader file (`assets/shaders/tilt_shift_dof.gdshader`) is the canonical implementation reference for §D's formulas — the GDD documents the intent; the shader documents the math in GLSL.
