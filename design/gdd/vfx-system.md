# VFX System (Particles) — GDD #27

> **Status: STUB DRAFT 2026-05-07** by post-Sprint-15-plan autonomous-execution session. **This is a Vertical Slice tier stub**, NOT a full first-pass GDD. Per Sprint 14 retro recommendation #4, this stub captures the system's identity + dependencies + open questions for the post-MVP authoring cycle. A full first-pass GDD is authored in Sprint 16+ when the Vertical Slice tier work begins.

---

## A. Overview

**VFX System (Particles)** is the GPU-particle layer that adds expressive moments to the cozy fantasy idle-clicker — gold-coin-burst on kill, parchment-shimmer on level-up, lantern-glow on floor-clear, recruit-flame on hero acquisition. The system is purely additive on top of the parchment theme (S10-M1) + the eventual HD-2D Rendering Pipeline (#26). It does NOT drive gameplay; it amplifies player feedback to player-facing events.

Status: **deferred to Vertical Slice tier per `game-concept.md` §Roadmap**. MVP ships with parchment theme + UIFramework touch-feedback (1.05× pulse) only; particle VFX is the upper polish layer that lands at Vertical Slice tier alongside HD-2D shader pass (#26).

---

## F. Dependencies (preliminary — full §F authoring deferred to Vertical Slice tier)

| System | Why | Surface used (preliminary) |
|---|---|---|
| **Godot GPUParticles2D + CPUParticles2D** (engine) | Core particle infrastructure | Particle systems instanced per-event; texture atlases; lifecycle managed via emit + auto-free pattern |
| **HD-2D Rendering Pipeline** (#26) | Composition target | VFX particles composite into the HD-2D pipeline's render path; sibling Vertical Slice tier work |
| **AudioRouter** (#28) | Audio-VFX synchronization | Per-event VFX fires alongside the corresponding audio cue; AudioRouter's signal subscriptions are the canonical event source per audio-system.md |
| **DungeonRunOrchestrator** (#13) | Signal sources | `enemy_killed`, `boss_killed`, `floor_cleared_first_time` signals trigger gold-burst / boss-kill-burst / lantern-glow VFX |
| **HeroRoster** (#9) | Signal sources | `hero_recruited`, `hero_leveled` signals trigger recruit-flame / level-up-shimmer VFX |
| **Economy** (#5) | Signal sources | `gold_changed` signal triggers gold-counter pulse VFX (visual + audio paired with `reason="kill"` / `reason="level_up"` / `reason="floor_clear"` per Economy §F) |
| **Settings GDD #30 reduce_motion accessibility** | Constraint | reduce_motion = true clamps all particle VFX to instant snap-replacement (no fade, no motion); cozy register precedent |

### Reverse dependencies (preliminary)

- **All shipped screens** — VFX particle systems instance from screen-side handlers when the relevant signals fire; no autoload-side per-particle code needed
- **Audio System** (#28) — VFX timings are synchronized with audio cue timings per audio-system.md §F.1 (tier-modulated kill SFX pitch) + §F.3 (Stinger duck) so the visual + audio land together

---

## I. Open Questions for Vertical Slice Authoring Cycle

**OQ-27-1 — Particle system per event taxonomy**
Cozy register events that may want VFX:
- `enemy_killed` (per-tier color: tier 1 dim, tier 5 vivid amber-warm) — gold-coin-burst sized by tier
- `boss_killed` — slightly more dramatic burst with a single warm-flash + parchment-shimmer
- `floor_cleared_first_time` — lantern-glow that crosses the screen (frontier fantasy beat per Floor Unlock §B)
- `hero_recruited` — recruit-flame on the new hero's RecruitScreen entry
- `hero_leveled` — parchment-shimmer on the leveled hero's portrait + amber pulse on dungeon_run_view toast
- `gold_changed` (reason="recruit" / "level_up" / "floor_clear") — counter pulse on Guild Hall + Recruit Screen + dungeon_run_view gold counters
**Resolution path**: Vertical Slice tier authoring inventories the events + designs per-event VFX timing (≤300ms for frequent events; ≤1500ms for rare ceremonial events) per Art Bible §7 Animation Feel.

**S30-N2 resolution (2026-06-25) — orphan demo textures retired, not wired**: the demo textures `vfx_aura_a` / `vfx_bubble_a` / `vfx_batwing_a` (gitignored, local-only under `assets/art/demo/vfx/`, derived from the octopath2 demo pack) are **retired**. They map to none of the cozy-register events above (gold-burst / parchment-shimmer / lantern-glow / recruit-flame / counter-pulse), and their dark-aura / batwing tone is off-register for this game's warm-parchment identity — wiring them would require designing a net-new VFX event, which is out of scope for an asset-cleanup follow-up. No `VfxKit` consumer is designed for them. The octopath2 source effects remain available locally should a consumer ever be designed; until then they stay outside the wired event taxonomy. Local demo copies removed so no unused-asset ambiguity remains. (These assets were never repo-tracked — `assets/art/demo/` and `assets/octopath*/` are both gitignored — so this is a decision record, not a tracked-file deletion.)

**OQ-27-2 — Particle authoring pipeline**
Particle textures + animation curves authored via Godot editor (CPUParticles2D / GPUParticles2D resources at `assets/vfx/<event>.tres` with associated texture atlases at `assets/vfx/<event>.png`). Or external tool (Aseprite for textures + Godot for system tuning)? **Resolution**: defer to Vertical Slice tier; preliminary preference is Godot-editor-authored (avoids tool sprawl).

**OQ-27-3 — Reduce_motion clamp behavior**
Per Settings GDD #30, reduce_motion = true should clamp particle VFX. Options: (a) snap-replace (no particle emission; instant text/value change); (b) static fade (alpha 0 → 1 instant; no motion); (c) reduced-emission (1-2 particles instead of 20+, no continuous motion). **Resolution path**: snap-replace is simplest + most accessible. Vertical Slice tier authoring locks the choice via accessibility-specialist consultation.

**OQ-27-4 — Performance budget per VFX event**
GPUParticles2D systems on integrated GPUs (Steam Deck) cost ~0.5-2ms per active system depending on particle count. With 5+ VFX systems active concurrently (peak: a 5-kill combat tick triggers 5 gold-bursts simultaneously), budget: ≤5ms. **Resolution**: Vertical Slice tier profiling confirms; throttle particle system instantiation if peak-concurrency exceeds a tunable threshold.

**OQ-27-5 — Audio + VFX tight coupling**
Audio cues (per audio-system.md) and VFX particles often paired (kill chime + gold-burst). The cleanest authoring pattern: a shared "FeedbackEvent" emit that fires both. ADR-candidate for Vertical Slice tier — when the VFX layer + AudioRouter are both real, evaluate whether a unifying coordinator is needed or whether subscribing to the same source signal independently is sufficient. **Resolution path**: independent-subscriber pattern is simpler; defer ADR until empirical drift surfaces.

**OQ-27-6 — Mobile platform considerations**
Per HD-2D Pipeline GDD #26 OQ-26-5, mobile GPUs may not absorb the same particle cost. Mobile launch may ship reduced-VFX OR a per-platform ProjectSettings override that disables VFX entirely. Resolution: defer to mobile port milestone; ship desktop with full VFX, mobile reads a Settings.vfx_quality enum (off / low / high) per V1.0+ Settings expansion.

**OQ-27-7 — Successor scope: full first-pass GDD timing**
This stub authoring cycle deferred a full first-pass GDD. The full GDD is authored when Vertical Slice tier sprint begins per `game-concept.md` §Roadmap. Pairs with #26 HD-2D Pipeline full first-pass authoring (sibling Vertical Slice tier GDD). **Resolution**: Vertical Slice tier sprint plans both authoring tasks together.

---

## Notes

- STUB GDD per Sprint 14 retro recommendation #4. Sections A, F, and I are the load-bearing content; B/C/D/E/G/H/J are deferred to Vertical Slice tier full-pass authoring.
- Closes systems-index.md row 27 status from "Not Started" → "STUB DRAFT 2026-05-07".
- Pairs with: #26 HD-2D Rendering Pipeline (sibling Vertical Slice tier GDD); audio-system.md §F (audio-VFX synchronization); Art Bible §7 Animation Feel (timing + register direction); Settings GDD #30 §C (reduce_motion clamp contract).
- The full first-pass GDD is authored when the Vertical Slice tier sprint begins. Until then, this stub serves as the design-coverage placeholder + dependency declaration for downstream GDDs that need to reference VFX behavior.
