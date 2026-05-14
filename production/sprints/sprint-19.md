# Sprint 19 — 2026-05-14 to 2026-05-27 (10 working days)

> **Status: Day-0 plan authored 2026-05-14**, same-day close of Sprint 18. Sixth
> consecutive same-day-compressed sprint (Sprint 14→15→16→17→18→19). Solo review mode.

## Sprint Goal

**Ship the HD-2D first visual pass: programmatic biome backgrounds + activated tilt-shift
DoF, validating the diorama register before real product art lands.**

Sprint 18 shipped the tilt-shift shader (S18-N1) but disabled it by default — the
playtest revealed it blurred UI text because there was no background content to blur.
Sprint 19 fixes the architecture: adds biome-palette-keyed background layers at z=-1,
restructures the scene trees so tilt-shift blurs backgrounds (not UI), and activates the
full HD-2D stack. Programmatic gradient backgrounds serve as internal-playtest proxies;
real product art (in-flight in a separate workstream) drops in later with zero code changes.

This is the Vertical Slice tier activation of ADR-0017's deferred HD-2D pipeline. Per
ADR-0017 §Pivot Triggers, the N1 shader shipping in Sprint 18 is pivot trigger #1.
ADR-0019 (this sprint's M2) records the activation decision.

**Definition of Sprint 19 success**: (a) GDD #26 expanded from stub to full 8 sections;
(b) BiomeBackground node renders correct palette for all 6 biomes + Guild Hall tavern
preset; (c) tilt-shift blurs BiomeBackground but NOT UI labels/buttons, verified by
screenshot + updated tests; (d) WarmLanternOverlay composites correctly on top; (e)
Sprint 19 playtest PASS on all 5 visual checks.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: M1 (GDD authoring, 0.5d) + M2 (ADR-0019, 0.25d) add 0.75d design
overhead. Core implementation (M3 + M4) is 1.5d. Playtest is load-bearing visual gate —
Sprint 18 N1 proved that shader-plus-wrong-content cannot be caught by automated tests
alone. Reserve the 0.5d M5 playtest and do not skip it.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|--------------|---------------------|
| S19-M1 | **HD-2D GDD #26 first-pass authoring** — expand the 3-section STUB DRAFT to all 8 required GDD sections. §Detailed Rules: layer-order contract (z=-1 BiomeBackground → BackBufferCopy → TiltShiftDof; z=0 UI; z=1 WarmLanternOverlay), BackBufferCopy positioning rule, BiomeBackground node contract. §Formulas: per-biome tilt-shift parameter defaults. §Edge Cases: reduce-motion neutral (tilt-shift is a static blur; not clamped by reduce_motion), mobile fallback (simplified pass on low-end GPU). §Tuning Knobs: focus_y, blur_strength, falloff_softness per-biome. §AC: testable acceptance criteria for the full stack. | game-designer + claude-code | 0.5d | none | GDD #26 has all 8 required sections; status changes from `STUB DRAFT` → `APPROVED` |
| S19-M2 | **ADR-0019 — HD-2D pipeline activation (successor to ADR-0017)** — records the Vertical Slice tier activation. Documents: layer-order decision, BiomeBackground node contract, programmatic-placeholder strategy, performance budget allocations (tilt-shift ≤4ms per OQ-26-4), and the explicit decision not to wait for real product art before activating the pipeline. Closes ADR-0017's "successor ADR" open item (OQ-26-7). | claude-code | 0.25d | M1 | `docs/architecture/ADR-0019-hd2d-pipeline-activation.md` committed |
| S19-M3 | **Biome background system** — `BiomeBackground` ColorRect scene/script: full-rect, z_index=-1, driven by a `biome_id` string set at runtime. Ships 6 gradient presets keyed to biome `primary_palette_key` from GDD #22: forest_reach (moss-sage-amber), whispering_crags (grey-teal), sunken_ruins (ochre-dusk-purple), hollow_stair (grey-bone-charcoal), ember_wastes (ember-rust-charcoal), frostmire (ice-blue-slate). Guild Hall gets a tavern-warm amber preset. BiomeBackground is a standalone scene/script: real sprites swap in by changing the scene's root content — zero DRV/GuildHall scene edits needed. | godot-gdscript-specialist | 1.0d | M1 | BiomeBackground renders correct palette per biome_id; Guild Hall renders tavern preset; z_index=-1 confirmed by contract test; DRV swaps background on biome_id assignment; 7 contract tests (6 biomes + tavern) pin the palette mapping |
| S19-M4 | **Tilt-shift re-wiring + activation** — restructure DRV + Guild Hall scene trees: (1) move BackBufferCopy from z=0 tree-end to z=-1 position in tree AFTER BiomeBackground; (2) move TiltShiftDof ColorRect to z=-1 AFTER BackBufferCopy; (3) confirm all UI content remains at z=0 (sharp); (4) flip `shader_parameter/enabled = 1.0` in both ShaderMaterial_tilt_shift sub_resources; (5) tune focus_y, blur_strength, falloff_softness per scene based on playtest signal. Update tests: remove disabled-by-default assertions; add enabled-with-correct-architecture assertions (enabled=1.0 in scene, TiltShiftDof z_index < UI label z_index). | godot-shader-specialist | 0.5d | M3 | Tilt-shift blurs BiomeBackground content; UI labels render sharp; WarmLanternOverlay renders on top of tilt-shift output; no SHADER ERROR in Godot headless run; updated test suite passes |
| S19-M5 | **Sprint 19 playtest — HD-2D visual validation** — run Guild Hall + dispatch a Forest Reach dungeon run. Validate: (a) diorama register is perceptible (biome background visible through tilt-shift blur), (b) no UI text ghost-smear (the Sprint 18 N1 bug is gone), (c) warm-lantern overlay composites correctly on top of blurred background, (d) gradient backgrounds read as biome-flavored in the cozy register, (e) no visible performance drop at 1280×800 (Steam Deck target). | xiaolei (human) | 0.5d | M4 | `production/playtests/playtest-11-hd2d-visual-2026-05-14.md` committed with verdict on all 5 checks |
| S19-M6 | **Sprint 19 retrospective** | producer + claude-code | 0.25d | M5 | Retro doc committed; sprint-status.yaml all Must Haves marked done |

**Must Have total**: 3.0 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S19-S1 | **Scaffolded-but-unwired audit** (Sprint 18 retro action #1 — highest-priority process improvement). The dominant bug class on this project: feature LOOKS wired in code but a constant is hardcoded, a step is deferred-and-never-landed, or a helper method is declared but never called. Grep for: `# provisional`, `# MVP`, `# stub`, `# placeholder`, `= 1.0  #`, snapshot fields never written outside `_init`, helper methods with no callers. Produce a report of suspects; fix any confirmed ghosts with regression tests. | claude-code | 0.25d | none | Audit report `production/sprint-19-scaffolds-audit.md` committed; confirmed ghosts fixed + regression-tested; zero known `# provisional` placeholders remain in non-test code |
| S19-S2 | **Per-biome tilt-shift parameter presets** — each biome gets a distinct ShaderMaterial sub_resource with tuned focus_y, blur_strength, and falloff_softness. Deep/underground biomes (hollow_stair, frostmire, sunken_ruins) get deeper DoF (wider blur); above-ground biomes (forest_reach, whispering_crags, ember_wastes) get shallower DoF. DRV swaps material on biome_id change. | godot-shader-specialist | 0.5d | M4 + M5 playtest signal | Pull in if M4 + S1 complete cleanly; defer if M5 playtest requests different tuning first |

**Should Have total**: 0.75 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S19-N1 | **BiomeBackground 3-stop gradient shader** — replace flat ColorRect biome backgrounds with a canvas_item shader: three configurable color uniforms (sky_tone, midground_tone, ground_tone) blended linearly. Richer visual than flat color; still no external art needed. Palette keys mapped to RGB triples via GDScript lookup table in BiomeBackground script. | godot-shader-specialist | 0.5d | Pull in only if M+S completes and M5 playtest signals "gradients feel too flat" |

**Nice to Have total**: 0.5 days

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| None | Sprint 18 closed with zero deferred items | — |

## Risks

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| BackBufferCopy z-sort doesn't capture BiomeBackground cleanly after M4 restructure | LOW | MED | Validate in Godot editor immediately after M4 scene restructure — don't wait for M5 playtest. The fix is precise z_index tuning or tree reordering (max 1h). |
| UI text accidentally blurred after tilt-shift re-activation (repeat of S18-N1 bug) | LOW | MED | M4's test update explicitly pins that TiltShiftDof.z_index < UI-label.z_index. Catch in M4 automated tests before M5 human playtest. |
| Programmatic gradients too placeholder for meaningful "diorama" visual impression | LOW | LOW | Even a flat colored background exercises the pipeline correctness. N1 gradient shader available if more realism needed; Octopath reference sprites can be used locally for internal playtest without committing them. |
| Real product art arrives mid-sprint and requires new import work | LOW | LOW | BiomeBackground scene is designed for zero-code art swap; importing real art would be a 15-min scene edit at most. No sprint risk. |

## Dependencies on External Factors

- **Real product art assets** (user's external workstream, no ETA) — Sprint 19 ships the infrastructure that real assets drop into. Sprint 19 does not gate on real assets.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and reviewed
- [ ] GDD #26 status = APPROVED, all 8 sections authored
- [ ] ADR-0019 committed
- [ ] BiomeBackground renders correct palette for all 6 biomes + Guild Hall tavern preset
- [ ] Tilt-shift blurs BiomeBackground, NOT UI labels/buttons (verified by screenshot in playtest doc + updated automated tests)
- [ ] WarmLanternOverlay composites correctly on top of tilt-shift output (z_index chain verified)
- [ ] Sprint 19 playtest PASS on all 5 visual checks
- [ ] Scaffolded-but-unwired audit completed (S19-S1)
- [ ] sprint-status.yaml updated with all story statuses; retro committed
- [ ] No S1 or S2 bugs in delivered features

## Notes

- **Visual-correctness test gap is accepted** (per Sprint 18 retro action #4): automated tests verify "wiring is correct"; they cannot verify "looks right on current content." The M5 playtest is the visual-correctness gate. Do not skip it.
- **Sprint 18 N1 lesson baked into M4**: the test update in M4 explicitly adds a check that `TiltShiftDof.z_index < UI_label.z_index`. This is the architectural guard that prevents the ghost-smear regression.
- **ADR-0019 scope check**: Sprint 19 adds ADR-0019 — the 19th ADR. The Sprint 18 plan flagged `/architecture-review` before Sprint 20 as a healthy hygiene checkpoint. Note for Sprint 20 planning.
