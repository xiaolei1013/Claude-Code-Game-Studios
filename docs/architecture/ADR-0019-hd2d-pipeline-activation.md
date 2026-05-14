# ADR-0019: HD-2D Pipeline Activation (Successor to ADR-0017)

## Status

**Accepted 2026-05-14** — Sprint 19 S19-M2. ADR-0017's §Pivot Trigger #1 fired implicitly via Sprint 18 S18-N1 (tilt-shift DoF shader shipped) and ADR-0017 Amendment §A1 (warm-lantern shipped Sprint 15). Sprint 19 activates the full pipeline. ADR-0017 status flips to **Superseded by ADR-0019**.

## Date

2026-05-14

## Last Verified

2026-05-14

## Decision Makers

- Author (user) — final decision; **sign-off recorded via Sprint 19 theme selection on 2026-05-14**
- art-director — Visual Identity Anchor adherence
- creative-director — cozy register preservation across the activated pipeline
- godot-shader-specialist — composition order + performance budget
- producer — Sprint 19 scope feasibility
- technical-director — solo-mode default

## Summary

Activates the HD-2D Rendering Pipeline (GDD #26) at Vertical Slice tier per ADR-0017 §Pivot Triggers. Locks three architectural decisions that GDD #26 §C documents in detail:

1. **Layer-order contract**: `BiomeBackground (z=-1) → BackBufferCopy (z=-1) → TiltShiftDof (z=-1) → UI (z=0) → WarmLanternOverlay (z=1)`. This contract is the architectural fix for the Sprint 18 N1 UI-ghost-smear bug (tilt-shift cannot blur UI because backgrounds are captured before UI renders).
2. **Per-screen composition**: each screen instantiates its own BackBufferCopy + post-process ColorRects. NOT a MainRoot-level SubViewport pipeline. Simpler, lower memory, adequate for the project's 2D UI register.
3. **Programmatic-placeholder strategy**: Sprint 19 ships gradient ColorRect backgrounds (one per biome palette key) as internal-playtest proxies. Real product art (in-flight in a separate workstream) swaps in zero-code via BiomeBackground scene replacement.

This ADR is the successor referenced by ADR-0017's §Pivot Triggers exit clause and by GDD #26 §A activation paragraph + §I.OQ-26-7 resolution.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering (canvas_item post-process pipeline) |
| **Knowledge Risk** | LOW — uses stable Godot 4.x APIs: `BackBufferCopy` node (since 4.0), `hint_screen_texture` uniform binding (since 4.0), z_index canvas-item sort (since 3.0), full-rect anchor preset (since 3.0). All exercised by S18-N1 already-shipped tilt-shift work without API failures. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pin); GDD #26 §F dependency list; ADR-0017 (predecessor + pivot triggers); existing shader work in `assets/shaders/tilt_shift_dof.gdshader` + `assets/shaders/warm_lantern_overlay.gdshader` |
| **Post-Cutoff APIs Used** | `hint_screen_texture` (Godot 4.x replacement for 3.x `SCREEN_TEXTURE` builtin — verified working via Sprint 18 N1 ship; the 5-tilt-shift-test contract pins it) |
| **Verification Required** | Sprint 19 M5 visual playtest validates composition produces the intended diorama register. CI shader tests verify shader compilation + uniform contract + scene resolution. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0008 (parchment theme + UIFramework — UI baseline this pipeline layers above); ADR-0011 (biome resource schemas — `Biome.primary_palette_key` field) |
| **Supersedes** | ADR-0017 (HD-2D Shader Pass Deferred). ADR-0017's status flips to "Superseded by ADR-0019" upon this ADR's Acceptance. |
| **Enables** | Sprint 19 S19-M3 (BiomeBackground system implementation); Sprint 19 S19-M4 (tilt-shift re-wiring + activation); future GDD #27 VFX System composition reference; future real product art swap-in (zero-code) |
| **Blocks** | Sprint 19 M3 + M4 implementation is gated on this ADR's Accepted status |
| **Ordering Note** | Authored same-day as GDD #26 first-pass per the convergence-pact in ADR-0017 §I.OQ-26-7 ("successor ADR + full GDD authoring land together") |

## Context

ADR-0017 (2026-05-07) deferred the HD-2D shader pass to Vertical Slice tier with 4 documented pivot triggers. Two of those triggers have effectively fired:

1. **Pivot Trigger #4 (sprint capacity surplus + dev-machine profiling baseline)** fired in Sprint 15 N2: warm-lantern shader shipped at <1ms cost, documented in ADR-0017 Amendment §A1 (2026-05-14).
2. **Pivot Trigger #4 fired again** in Sprint 18 N1: tilt-shift DoF shader shipped at <4ms cost on dev hardware. ADR-0017 Amendment §A1 noted "tilt-shift still deferred"; that footnote was already obsolete at the time of writing — the shader landed in the same window.

Sprint 18 also surfaced a non-engineering issue: tilt-shift activated on UI-only screens with no background content produces a ghost-smear artifact (S18-N1 first playtest showed "Gold: 1824" rendered as a vertically smeared stack). The shader is structurally correct; the architecture it was deployed into was missing a layer. Sprint 18 mitigated by shipping `enabled = 0.0` on both Guild Hall and DungeonRunView ShaderMaterials and capturing the architecture mismatch in the Sprint 18 retro.

Sprint 19 is the architectural fix. It introduces the missing layer (BiomeBackground at z=-1) and activates the pipeline. The user explicitly selected this theme via Sprint 19 theme decision (2026-05-14): "Real biome backgrounds + activate tilt-shift" over three alternative themes (synergy V1.5, audio MVP, new mechanic).

The user is concurrently working on real product art in a separate workstream (timeline TBD). Sprint 19 must not block on real-art delivery. The programmatic-placeholder strategy is the decoupling mechanism: ship infrastructure that real art drops into with zero code changes.

## Decision

### Decision 1: Layer-Order Contract

The HD-2D pipeline composes five layers per screen:

```
z=-1, tree-position 1: BiomeBackground   (full-rect ColorRect or future sprite)
z=-1, tree-position 2: BackBufferCopy    (captures everything rendered so far at z=-1)
z=-1, tree-position 3: TiltShiftDof      (ColorRect; samples back buffer, applies blur)
z=0  (default)       : UI content        (Labels, Buttons, Panels — render sharp)
z=1                  : WarmLanternOverlay (ColorRect; amber wash over everything)
```

The contract is invariant. Reversing any pair produces a different visual register that violates the diorama fantasy in GDD #26 §B. Acceptance criteria in GDD #26 §H lock the contract via automated tests (AC-26-07, AC-26-08, AC-26-09, AC-26-10, AC-26-13).

**Why z=-1 for the post-process triplet, not z=0**: Godot's canvas_item render order is z_index ascending, then tree order within same z. UI sits at default z=0. To ensure backgrounds and the back-buffer copy fire BEFORE UI renders (so UI is not captured into the blurred output), the post-process triplet sits at z=-1. WarmLanternOverlay sits at z=1 so it composites OVER UI as well as the blurred background.

### Decision 2: Per-Screen Composition Root

The shader pass applies via per-screen in-scene composition. NOT a MainRoot-level SubViewport pipeline.

| Aspect | Per-screen | MainRoot SubViewport |
|--------|------------|----------------------|
| Memory cost | None (no extra RT) | One full-screen render target |
| Performance | 9-tap Gaussian per fragment, ~4ms on dev | Same shader cost + RT compositing cost |
| Per-screen flexibility | Each screen has its own BackBufferCopy + ShaderMaterial; can disable individually | All-or-nothing toggle |
| Implementation cost (Sprint 19) | M4: ~0.5d scene restructure | Would require new top-level scene + Camera2D pipeline + ~2d |
| Future flexibility | Add per-screen variations easily; future per-biome ShaderMaterial swap (S19-S2) is trivial | Switching to per-screen later would require a SubViewport retirement |

Per-screen wins on every axis for the project's 2D UI register. The MainRoot approach would be appropriate for a 3D game with complex render-pipeline customization (post-processing on the entire game framebuffer); it is overkill here.

### Decision 3: Programmatic-Placeholder Strategy

Sprint 19 ships BiomeBackground as a standalone scene (`assets/screens/_shared/biome_background.tscn`) + script. The script's `set_biome(biome_id)` method maps the biome's `primary_palette_key` to a ColorRect color (or, optionally per S19-N1, a 3-stop gradient shader).

**Why programmatic placeholders, not waiting for real art**:

1. **Decouples the visual-pipeline work from the asset-sourcing workstream.** Sprint 19 ships in days; real art has no committed ETA.
2. **Exercises the full pipeline correctness.** The placeholder backgrounds are visible content the tilt-shift blurs and the warm-lantern composites over. If the pipeline works on flat colors, it works on real sprites.
3. **Zero-code real-art swap.** When real backgrounds arrive, swap the `biome_background.tscn` scene's root content from a ColorRect to a Sprite2D + texture. No DRV/GuildHall scene changes, no script changes, no shader changes.
4. **Internal-playtest value.** The user explicitly stated (2026-05-14): "the 2d assets are just for better internal playtests and we are working on the real product assets." Placeholder gradients serve internal playtests sufficiently while real assets land.

### Decision 4: Activation Strategy

Sprint 19 M4 flips `enabled = 1.0` on both Guild Hall and DungeonRunView ShaderMaterial_tilt_shift sub_resources. The S18-N1 `enabled = 0.0` default is retired; the tilt-shift is active by default once a BiomeBackground exists.

Future Settings GDD #30 accessibility work may add a player-facing toggle that overrides per-scene `enabled` values. Sprint 19 does NOT add this toggle. The shader exposes the uniform; per-scene scenes control the default.

### Pivot Triggers (for future ADR-0020 reversion)

If any of the following fire, a successor ADR-0020 may revert or modify this activation:

1. **Steam Deck profiling shows tilt-shift exceeds 4ms budget on target hardware**. The 9-tap Gaussian is dev-machine measured; Steam Deck integrated GPU may behave differently.
2. **Playtest signal that the activated pipeline degrades cozy register**. If 3+ independent playtests flag the visual as "muddy" or "trying too hard," reduce blur_strength globally or revert to disabled-default per-scene.
3. **Mobile port milestone**: mobile may need 5-tap quality variant or full disable on low-end Android. Project setting `tilt_shift_quality` is the documented mitigation path (GDD #26 §E).
4. **Real art landing reveals composition incompatibility**: if real biome sprites have their own blur/atmospheric content already painted in, double-blurring may look wrong. Per-scene ShaderMaterial `enabled = 0.0` is the per-biome opt-out.

## Alternatives Considered

### Alternative 1: Wait for real art before activating

Defer Sprint 19. Wait for the user's real product art workstream to deliver biome sprites before wiring the tilt-shift.

**Rejected because**: real art has no committed timeline. The visual-pipeline work is decoupled from asset sourcing — there is no engineering reason to block. Programmatic placeholders exercise the pipeline correctness adequately. Real art swaps in zero-code when ready.

### Alternative 2: MainRoot SubViewport pipeline

Add a top-level SubViewport containing the entire game viewport. Apply post-process shaders at the SubViewport level. Cleaner architecture in principle; one shader pass covers all screens.

**Rejected because**: ~2d implementation cost vs. ~0.5d for per-screen. Adds one full-screen render target memory cost. Less flexible (cannot per-biome tune individual scenes). The per-screen approach has already proven workable via Sprint 18 N1 ship.

### Alternative 3: Keep `enabled = 0.0` by default; require explicit activation per playtest

Ship the BiomeBackground infrastructure but leave tilt-shift disabled until per-biome tuning lands (S19-S2). Activation is opt-in per scene.

**Rejected because**: the whole point of Sprint 19 is the visual lift. Default-off would mean the visual pipeline only fires on tuned biomes; untuned biomes look unchanged. The Sprint 18 N1 ghost-smear problem is fixed by the layer-order contract (Decision 1), not by keeping the shader disabled. If a future regression surfaces, per-scene `enabled = 0.0` remains available as a per-screen mitigation.

### Alternative 4: Use third-party post-processing addon (e.g., Bjarke's post-process plugin)

Several Godot 4.x addons provide pre-built tilt-shift and color-grading pipelines.

**Rejected because**: the project's tilt-shift shader is already authored, tested, and shipping (Sprint 18 N1). Adding a third-party dependency for a problem already solved adds bloat and a maintenance surface. The 5-uniform shader is the right scope for this project.

## Consequences

### Positive

1. **Visual Identity Anchor activated.** The cozy register's diorama fantasy lands across Guild Hall + DungeonRunView. Pillar 4 (HD-2D Pixel Pride) is no longer an aspirational pillar; it is a shipped pillar.
2. **Sprint 18 N1 ghost-smear architecturally prevented.** The layer-order contract makes the bug structurally impossible (tilt-shift cannot reach UI labels because they render AFTER the back-buffer capture).
3. **Real-art workstream decoupled.** External art delivery does not gate visual-pipeline shipping. When real art lands, it drops in without engineering work.
4. **Per-scene flexibility for tuning.** S19-S2 per-biome ShaderMaterial presets become a simple resource swap, not a code change.
5. **ADR-0017's pivot trigger #1 exit cleanly executed.** ADR-0017 status flips to Superseded; the deferral rationale remains historical record but no longer governs.

### Negative

1. **Programmatic gradients may feel less impressive than real art.** Internal playtests may need supplementation with Octopath references (which the user has at `~/work/godot-project/octopath{1,2}/` outside the repo) for proper "feels real" validation.
2. **One more architectural moving part.** Future contributors must understand the 5-layer z_index contract to avoid regressing. Mitigated by AC-26-08 test (TiltShiftDof.z_index < UI label z_index assertion).
3. **Scene tree complexity in DRV + GuildHall.** Both scenes now have 3 extra nodes (BiomeBackground + BackBufferCopy + TiltShiftDof) plus the existing WarmLanternOverlay. Total: 4 visual-pipeline nodes per scene. Minor cognitive overhead.

### Neutral

- The shader cost (~4ms tilt-shift + <1ms warm-lantern = ~5ms) is within the 16ms frame budget. Confirmed on dev hardware; Steam Deck profiling deferred to Sprint 19+.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Tilt-shift on Steam Deck integrated GPU exceeds 4ms budget | LOW-MED | MED | Sprint 19+ Steam Deck profiling; `tilt_shift_quality` project setting (5-tap fallback) is the documented mitigation per GDD #26 §E |
| Real art arrives with painted-in blur that conflicts with tilt-shift | LOW | LOW | Per-scene `enabled = 0.0` is the per-biome opt-out; documented in Decision 4 |
| BiomeBackground node misconfiguration in future screens | LOW | LOW | Contract test asserts `mouse_filter = MOUSE_FILTER_IGNORE` + z_index = -1 |
| Sprint 19 M4 z-order tuning takes longer than 0.5d budgeted | LOW | LOW | Already validated in Sprint 18 N1: the z_index assertion test catches the regression class instantly |

## Performance Implications

| Pass | Cost (dev hardware) | Budget (Steam Deck) | Headroom |
|------|---------------------|----------------------|-----------|
| BiomeBackground (flat ColorRect) | <0.1ms | <0.1ms | n/a |
| BiomeBackground (S19-N1 3-stop gradient shader) | <0.5ms | <1ms | n/a |
| BackBufferCopy | <0.1ms | <0.2ms | n/a |
| Tilt-shift 9-tap Gaussian | ~4ms | ≤4ms target | n/a |
| Warm-lantern vignette | <1ms | <1ms | n/a |
| **Total pipeline cost** | **~5ms** | **≤5.3ms target** | **>10ms remaining for combat + UI** |

Total cost well within 16.6ms (60fps) budget per `.claude/docs/technical-preferences.md`.

## Migration Plan

Sprint 19 M3 + M4 implement the migration:

1. **M3 (BiomeBackground system)**: author the BiomeBackground scene + script. Add to DRV + Guild Hall at z=-1 (positioned first in scene tree among z=-1 siblings). Define 7 palette presets (6 biomes + tavern). Wire DRV to call `set_biome()` on biome change.
2. **M4 (Tilt-shift re-wiring + activation)**: reposition BackBufferCopy + TiltShiftDof to z=-1 in the scene tree, AFTER BiomeBackground but BEFORE UI siblings. Flip `enabled = 1.0`. Update shader tests: replace disabled-by-default assertions with the new layer-order assertions (AC-26-07 + AC-26-08 + AC-26-13).

No save migration needed — this is purely a rendering change. No data schema change.

ADR-0017 status: flip to **Superseded by ADR-0019** in its header. Add a §Supersession note linking to this ADR.

## Validation Criteria

ADR is validated when GDD #26 acceptance criteria AC-26-01 through AC-26-15 all evidence-PASS:
- AC-26-01..06 (shader resource + scene resolution tests) → already passing from Sprint 15 N2 + Sprint 18 N1
- AC-26-07 (z_index composition order) → already passing from Sprint 18 N1; M4 updates the test
- AC-26-08 (UI sharpness guard) → NEW in M4
- AC-26-09, AC-26-10, AC-26-11, AC-26-12 (BiomeBackground contracts) → NEW in M3
- AC-26-13 (`enabled = 1.0` ship state) → NEW in M4 (replaces S18 disabled-by-default assertion)
- AC-26-14 (Sprint 19 visual playtest 5-check PASS) → M5 evidence
- AC-26-15 (mouse_filter IGNORE on all overlays) → NEW in M3 + M4

Sprint 19 M6 retro records the consolidated validation.

## GDD Requirements Addressed

- **GDD #26 §A Overview** — pipeline architecture documented; this ADR locks the architectural decisions
- **GDD #26 §C Detailed Rules** — layer-order contract codified here matches §C.1; BiomeBackground contract codified here matches §C.2
- **GDD #26 §F Dependencies** — ADR-0019 listed as a hard dependency
- **GDD #26 §G Tuning Knobs** — programmatic palette mapping table (G.3) implemented per this ADR's Decision 3
- **GDD #26 §H Acceptance Criteria** — all 15 ACs trace back to this ADR's 4 Decisions
- **GDD #26 §I.OQ-26-3** (composition root location) — Decision 2 resolves: per-screen, not MainRoot SubViewport
- **GDD #26 §I.OQ-26-7** (successor ADR scope) — this ADR is the successor; OQ-26-7 marked Resolved

## Related

- **Predecessor**: `docs/architecture/ADR-0017-hd-2d-shader-pass-deferred-to-vertical-slice.md` — superseded by this ADR
- **Concurrent GDD authoring**: `design/gdd/hd-2d-rendering-pipeline.md` (#26) — full first-pass authored in Sprint 19 S19-M1 alongside this ADR
- **Sibling shader work**: `assets/shaders/tilt_shift_dof.gdshader` (Sprint 18 N1); `assets/shaders/warm_lantern_overlay.gdshader` (Sprint 15 N2)
- **Sibling GDD**: `design/gdd/vfx-system.md` (#27, Vertical Slice tier sibling — particle effects compose with this pipeline)
- **Visual direction source**: `design/art/art-bible.md` §Visual Identity Anchor
- **Strategic context**: `design/gdd/game-concept.md` Pillar 4 HD-2D Pixel Pride + §Roadmap Vertical Slice tier
- **Performance budget**: `.claude/docs/technical-preferences.md` (Steam Deck 1280×800 60fps target)
- **Data dependency**: `design/gdd/biome-dungeon-database.md` (#22) — `Biome.primary_palette_key` field

## Sign-Off Trail

- **2026-05-14** — Accepted by user theme selection (Sprint 19 theme: "Real biome backgrounds + activate tilt-shift"). The Sprint 19 plan PR #104 records the binding decision; this ADR codifies the architectural commitments that flow from it.

The decision is reversible via successor ADR-0020 per the documented Pivot Triggers; the parchment theme stays shipped as the foundational visual baseline regardless.
