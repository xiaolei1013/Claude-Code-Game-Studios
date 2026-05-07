# HD-2D Rendering Pipeline — GDD #26

> **Status: STUB DRAFT 2026-05-07** by post-Sprint-15-plan autonomous-execution session. **This is a Vertical Slice tier stub**, NOT a full first-pass GDD. Per Sprint 14 retro recommendation #4 ("Vertical Slice + V1.0+ GDDs ship as 2-3 section stubs"), this stub captures the system's identity + dependencies + open questions for the post-MVP authoring cycle. A full first-pass GDD is authored in Sprint 16+ when the Vertical Slice tier work begins per ADR-0017's pivot triggers.

---

## A. Overview

**HD-2D Rendering Pipeline** is the SubViewport-composed Forward+ post-process chain that delivers the project's Visual Identity Anchor (per `design/gdd/game-concept.md` §Visual Identity Anchor + Pillar 4 HD-2D Pixel Pride): pixel-art sprites layered on top of a tilt-shift depth-of-field pass + warm-lantern overlay tint. The system is the upper polish layer on top of the parchment theme (S10-M1 / S10-M2 / ADR-0008) — the parchment theme is the visual baseline that ships in MVP; HD-2D is the "Octopath-inspired" finish that ships at Vertical Slice tier per `game-concept.md` §Roadmap.

Status: **deferred to Vertical Slice tier per ADR-0017 (Accepted 2026-05-07)**. MVP ships with parchment theme only. Vertical Slice tier sprint authors a full first-pass GDD + the successor ADR + ships the shader work when any of ADR-0017's 4 pivot triggers fire.

---

## F. Dependencies (preliminary — full §F authoring deferred to Vertical Slice tier)

| System | Why | Surface used (preliminary) |
|---|---|---|
| **Godot Forward+ rendering** (engine) | Core pipeline | SubViewport composition + .gdshader post-process passes |
| **Parchment Theme + UIFramework** (#18, ADR-0008) | Visual baseline | HD-2D shader pass is additive on top of parchment Theme + UIFramework helpers; no refactor of the underlying stack |
| **Art Bible §Visual Identity Anchor** (`design/art/art-bible.md`) | Visual direction | Tilt-shift DoF + warm-lantern overlay are spec'd in the Art Bible's Visual Identity Anchor section |
| **`game-concept.md` Pillar 4 HD-2D Pixel Pride** | Strategic context | The pillar identifies HD-2D as a differentiator in the cozy fantasy idle-clicker space (per OQ-Octopath inspiration); the Vertical Slice tier is when Pillar 4 fully expresses |
| **ADR-0017** | Deferral rationale + pivot triggers | This GDD's Vertical Slice scope is gated on ADR-0017's pivot triggers firing; successor ADR + this GDD's full first-pass authoring land together |
| **Performance budget per `.claude/docs/technical-preferences.md`** | Constraint | Steam Deck native (1280×800) 60fps target; ≤16ms total frame budget |

### Reverse dependencies (preliminary)

- **VFX System** (#27) — particle effects compose with the HD-2D pipeline; Vertical Slice tier authoring of #27 references this GDD's pipeline for blend-mode + render-order coordination
- **All shipped screens** — guild_hall, dungeon_run_view, formation_assignment, recruit_screen, return_to_app_view, victory_moment, hero_detail_modal, matchup_assignment_screen — all render on top of the HD-2D pipeline once it lands; no per-screen integration work needed beyond the SubViewport composition root

---

## I. Open Questions for Vertical Slice Authoring Cycle

**OQ-26-1 — Tilt-shift DoF parameters**
Per ADR-0017 Alternative 1, tilt-shift is the riskier-but-more-distinctive pass; warm-lantern is the simpler-but-thematic pass. ADR-0017 §Decision deferred BOTH; Vertical Slice tier may ship one or both. Tilt-shift parameters (focal-distance, blur-radius, aperture-shape) need playtest tuning. **Resolution**: ship a tunable shader with `@export` parameters; iterate via screenshot evidence.

**OQ-26-2 — Warm-lantern overlay color grade specification**
Per Art Bible §Visual Identity Anchor, the cozy register's warm-lantern beat is amber-warm at low alpha. Spec the LUT or color-grade matrix. **Resolution**: Vertical Slice tier authoring derives the LUT from the parchment-theme color palette + the lantern-gold reward color (S10-M1).

**OQ-26-3 — SubViewport composition root location**
The shader pass applies via SubViewport composition. Decision: at MainRoot.tscn level (whole-game render to texture + post-process) OR at per-screen level (Control nodes opt into the post-process). **Resolution path**: MainRoot-level composition is simpler + cheaper; per-screen opt-in is more flexible. Defer to Vertical Slice tier; preliminary preference is MainRoot-level.

**OQ-26-4 — Performance budget allocation**
Steam Deck 1280×800 60fps = 16.6ms frame budget. Tilt-shift DoF typically costs 2-4ms on integrated GPUs; warm-lantern color grade costs <1ms. Combined budget allocation: ≤4ms for both. Headroom for combat-tick + UI rendering: >12ms. **Resolution**: Vertical Slice tier profiling confirms; ADR-0017 pivot trigger #4 sprint dedicates capacity.

**OQ-26-5 — Mobile platform compatibility**
Mobile GPUs (especially Apple Silicon iPad / mid-range Android) may not absorb the same shader cost. Per ADR-0017 §Pivot Triggers #3 (mobile port milestone is hard pivot trigger), mobile launch hard-gates on this. Resolution path: ship desktop with HD-2D; mobile may ship simpler or with reduced shader pass per platform-specific ProjectSettings override.

**OQ-26-6 — Reduce_motion accessibility**
Per Settings GDD #30 §C (reduce_motion accessibility flag), motion-heavy effects are clamped. Tilt-shift DoF is a static blur (no motion), so reduce_motion does NOT clamp it. Warm-lantern is a static color grade. **Resolution**: this pipeline is reduce_motion-neutral; no special handling needed.

**OQ-26-7 — Successor ADR scope**
ADR-0017's successor ADR (when a pivot trigger fires) authors the actual shader implementation decision. This stub should be expanded into a full first-pass GDD AT THE SAME TIME the successor ADR is authored so the design + technical decisions converge. **Resolution**: Vertical Slice tier sprint plans both authoring tasks together.

---

## Notes

- This is a STUB GDD per Sprint 14 retro recommendation #4 (Vertical Slice / V1.0+ GDDs ship as 2-3 section stubs). Sections A, F, and I are the load-bearing content; B/C/D/E/G/H/J are deferred to Vertical Slice tier full-pass authoring.
- Closes systems-index.md row 26 status from "Not Started" → "STUB DRAFT 2026-05-07".
- The full first-pass GDD is authored when ADR-0017's pivot triggers fire (Steam Deck access / post-launch playtest signal / mobile port milestone / sprint capacity surplus + dev-machine baseline). The successor ADR + the full GDD land together.
- Pairs with: `docs/architecture/ADR-0017-hd-2d-shader-pass-deferred-to-vertical-slice.md` (deferral rationale + pivot triggers); `design/gdd/vfx-system.md` (#27, sibling Vertical Slice tier GDD); `design/art/art-bible.md` §Visual Identity Anchor (visual direction); `design/gdd/game-concept.md` Pillar 4 + §Roadmap Vertical Slice tier scheduling.
