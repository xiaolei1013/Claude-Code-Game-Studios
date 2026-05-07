# ADR-0017: HD-2D Shader Pass Deferred to Vertical Slice Tier (Honor Original game-concept.md Fallback)

## Status

**Proposed (PENDING USER SIGN-OFF)** — this ADR was authored autonomously; per `production/review-mode.txt = solo` it can ship as Accepted, but the decision touches the project's Visual Identity Anchor and per Sprint 13 retrospective recommendation this class of binding decision benefits from explicit user input. Sprint 14 S14-M5 is BLOCKED until the user reviews and either Accepts this ADR (HD-2D deferred) or rejects it in favor of attempting the shader pass on dev-machine profiling.

## Date

2026-05-07 (authored as the Sprint 14 S14-M5 fallback per the ADR-0016 silent-MVP precedent)

## Last Verified

2026-05-07

## Decision Makers

- Author (user) — final decision; **sign-off required**
- art-director — Visual Identity Anchor adherence (lead consult)
- creative-director — cozy register vs. visual fidelity trade-off
- godot-shader-specialist — Forward+ pipeline + Steam Deck performance constraints
- producer — Sprint 14 capacity vs. external hardware dependency
- technical-director — solo-mode default per `production/review-mode.txt`

## Summary

Locks the HD-2D shader pass (tilt-shift DoF + warm-lantern overlay per Art Bible §Visual Identity Anchor) as **deferred to Vertical Slice tier (post-MVP)** — honoring the original `design/gdd/game-concept.md` §Risks fallback path that Sprint 14 S14-M5 implicitly contradicted by promoting the shader pass to pre-MVP polish. MVP ships with parchment theme alone (the existing visual bar shipped via S10-M1 / S10-M2). Three pivot triggers authorize an earlier landing if circumstances change.

This ADR is more contentious than ADR-0016 (audio silent-MVP) because HD-2D is part of the project's Visual Identity Anchor and the cozy register's "sensory pleasure" pillar (game-concept.md MDA Sensation = 3/5). Unlike audio (which degrades silently), the absence of HD-2D shader is visible to every player every frame. The mitigation is that the **parchment theme already ships** (S10-M1 + S10-M2 Theme + UIFramework wires it into every screen) — HD-2D is the upper polish layer on top of an existing acceptable visual foundation.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering (Forward+ pipeline + post-process shaders) — content-deferral decision; no engine API decision |
| **Knowledge Risk** | LOW (no API choices made; the deferred work would have used SubViewport composition + custom .gdshader, both stable since Godot 4.0) |
| **References Consulted** | `design/gdd/game-concept.md` §Risks ("HD-2D rendering fidelity" fallback) + §Roadmap (Vertical Slice tier + HD-2D shader pass row); `design/art/art-bible.md` §Visual Identity Anchor; `production/sprints/sprint-14.md` S14-M5 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None for the deferred path. If a pivot trigger fires, the successor ADR + implementation must verify Steam Deck native (1280×800) 60fps performance per `.claude/docs/technical-preferences.md`. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Sprint 14 closure with 2/5 Must Haves DONE + S14-M5 explicitly deferred (no false "incomplete" signal); Vertical Slice tier HD-2D shader pass (when it lands, references this ADR as the deferral rationale) |
| **Blocks** | Sprint 14 S14-M5 implementation is BLOCKED on this ADR's status. If Accepted: S14-M5 closes via this ADR. If Rejected: S14-M5 attempts dev-machine profiling implementation. |
| **Ordering Note** | Modeled on ADR-0016 (audio silent-MVP) — same defensible-default ADR pattern: cheapest path with documented pivot triggers; future-proof against a successor ADR landing the deferred work without code-architecture debt |

## Context

### Problem Statement

`production/sprints/sprint-14.md` S14-M5 schedules an HD-2D visual polish pass — tilt-shift depth-of-field OR warm-lantern overlay — as a Sprint 14 Must Have, with the constraint that performance must be verified at Steam Deck native (1280×800) 60fps. The Steam Deck profiling hardware is not available to the project; the autonomous session cannot validate the performance budget. Without that validation, shipping a shader pass risks introducing a frame-time regression that surfaces only on the target platform, post-launch.

`design/gdd/game-concept.md` §Risks already documents the fallback explicitly:

> **HD-2D rendering fidelity** — achieving the Octopath-inspired look with pixel sprites requires custom shader work (tilt-shift blur, lighting overlays) that may slip MVP scope. **Fallback: crisp pixel art without HD-2D shader layer for MVP, add shader polish in Vertical Slice tier.**

And the milestones table on line 274 of game-concept.md schedules HD-2D shader pass for the Vertical Slice tier (post-MVP). Sprint 14's S14-M5 implicitly contradicts this scheduling — without explanation in the sprint-14.md authoring notes.

### Current State

- **Parchment theme** (S10-M1 / S10-M2): canonical Theme.tres at `assets/ui/parchment_theme.tres` with 4 panel/overlay StyleBoxFlats, 4 button-state StyleBoxFlats, parchment-grain background, slate-ink typography, lantern-gold reward color. Wired into every shipped screen via UIFramework.apply_parchment_panel + Control theme inheritance. This IS the current visual bar.
- **No HD-2D shader assets exist**. `assets/shaders/` directory is empty. No tilt-shift DoF post-process; no warm-lantern overlay; no SubViewport composition. The Forward+ pipeline runs with default Godot 4.6 settings.
- **Performance budget**: per `.claude/docs/technical-preferences.md`, target is 60fps PC + Steam Deck native (1280×800). Current empirical performance is well within budget on dev-machine (macOS Forward+ Metal); no Steam Deck measurement exists.
- **playtest-04 verdict** (2026-05-05, post-Sprint-9 polish): PASS WITH NOTES. Pillar 2 (cozy register) = 3/5 — clears the gate-blocking bar. The playtest did NOT flag missing HD-2D as an issue; the parchment theme alone was sufficient for the cozy register at the playtest level.

### Constraints

- **Hardware access**: Steam Deck (or equivalent profiling rig) is not available. The autonomous session cannot validate frame-time on the constrained platform.
- **Solo-mode review**: per `production/review-mode.txt = solo`, no shader-specialist or art-director human is in the loop for autonomous decisions.
- **Visual Identity Anchor**: HD-2D pixel pride is **Pillar 4** of the four Game Concept pillars (Tactical Foresight / Cozy Pacing / Pixel Pride / Vindicated Patience). Deferring the shader pass means MVP ships with Pillar 4 partially expressed (parchment theme + pixel sprites only; no shader polish).
- **Sprint 14 calibration**: per Sprint 12 + 13 retros, no pre-emptive buffer remains. Adding S14-M5 implementation work without hardware validation is genuinely risky.

### Requirements

- **Functional**: MVP ships with a coherent visual identity. Parchment theme alone meets the bar per playtest-04 evidence.
- **Performance**: 60fps PC + Steam Deck native target. Without HD-2D shader, the budget has substantial headroom (parchment theme is a typical 2D Forward+ workload).
- **Compatibility**: Pivot to HD-2D in Vertical Slice tier should not require refactoring shipped screens. SubViewport composition + post-process shaders are additive — they don't require the underlying scene tree to change.
- **Roadmap fidelity**: defer to Vertical Slice tier per game-concept.md §Roadmap original schedule; do not introduce roadmap drift.

## Decision

**Defer HD-2D shader pass to Vertical Slice tier (post-MVP)** per the existing `game-concept.md` §Risks fallback. Sprint 14 S14-M5 is closed via this ADR — no shader pass ships in MVP. MVP visual bar is parchment theme + pixel sprites (current state).

### Architecture

```
[ MVP visual stack ]                   [ This ADR's deferral ]              [ Vertical Slice tier — successor ADR ]
                                       
+----------------+                                                          +-------------------------+
| pixel sprites  |                                                          | pixel sprites           |
+----------------+                                                          +-------------------------+
| parchment theme|  ─── ship (S10-M1)        ─── (no shader layer) ──►      | parchment theme         |
+----------------+                                                          +-------------------------+
| (no HD-2D)     |                                                          | + tilt-shift DoF (.gdshader)
+----------------+                                                          | + warm-lantern overlay  |
                                                                            +-------------------------+
                                                                            
                                                                            (additive — does not refactor
                                                                             the underlying parchment stack)
```

### Key Interfaces

```
# This ADR introduces NO new interfaces. The deferral is a non-decision at
# the code level — no shader files, no SubViewport composition, no .gdshader
# resources. The successor ADR (when a pivot trigger fires) introduces:
#
#   - assets/shaders/tilt_shift_dof.gdshader (Forward+ post-process)
#   - assets/shaders/warm_lantern_overlay.gdshader (color-grade pass)
#   - SubViewport composition wiring at the root scene tree level
#   - Profile budget: ≤16ms frame time on Steam Deck native 1280×800

# The shipping codebase has no shader_pass-related code today, so this
# ADR is purely a deferral decision — no migration required for adoption.
```

### Implementation Guidelines

For the **deferred-to-Vertical-Slice path** (this ADR):
- Do NOT author shader files in `assets/shaders/` for MVP scope.
- Do NOT introduce SubViewport composition at the root scene tree level.
- Do NOT change the Forward+ rendering pipeline defaults.
- DO continue investing in parchment theme polish (S10-M1 / S10-M2 patterns) — that's the visual bar MVP ships with.
- DO continue authoring shipped screens against the parchment theme (Theme.tres + UIFramework helpers).
- DO update `production/sprints/sprint-14.md` S14-M5 to "DONE — DEFERRED to Vertical Slice via ADR-0017" once this ADR is Accepted.

For the **pivot path** (when a successor ADR is authored):
- Place shader files at `assets/shaders/<effect>.gdshader` per coding-standards naming.
- Wire SubViewport composition at MainRoot.tscn level (or per-screen if the Visual Identity Anchor calls for per-context overlay).
- Author Steam Deck profiling test on real hardware OR equivalent rig.
- The successor ADR includes a "Performance Budget" section with measured frame-time numbers from the target platform.
- Run the existing screen tests + add a per-shader smoke test (resource loads, applies to surface, no shader compilation errors).

### Pivot Triggers

The successor ADR is authored when **any one** of the following triggers fires:

1. **Steam Deck (or equivalent profiling rig) hardware access lands**. Without measured frame-time on the target platform, performance budget cannot be verified. When hardware is available, schedule a Sprint 15+ Must Have to author the shader pass + measure.
2. **Post-launch playtest signal**: 3+ independent playtest reports flag the visual presentation as feeling flat or disconnected from the cozy/HD-2D promise. Captured via `production/playtests/`. The playtest-04 baseline (Pillar 2 = 3/5 with parchment-only) is the "good enough for MVP" floor; if subsequent playtests degrade or new players consistently expect more visual polish, pivot.
3. **Mobile port milestone**: similar to ADR-0016 audio pivot trigger #3 — mobile pixel-art games ship with shader polish on competitive titles. Mobile launch is a hard pivot trigger (sourcing must land before mobile launch).
4. **Sprint capacity surplus + dev-machine profiling baseline**: a sprint where Must Have + Should Have backlog drains in <5 days AND a shader-specialist agent run produces a tilt-shift OR warm-lantern shader at <2ms frame-time impact on macOS dev box (the cheapest profiling proxy we have for Steam Deck). This is the cheapest pivot path; ~1.5d sprint scope.

When ANY trigger fires, the next sprint plan opens a new Must Have to author the successor ADR + execute the shader pass implementation. This ADR's status flips to "Superseded by ADR-NNNN".

## Alternatives Considered

### Alternative 1: Ship HD-2D on dev-machine profiling alone (no Steam Deck verification)

- **Description**: Author the tilt-shift OR warm-lantern shader; verify ≤16ms frame-time on macOS dev box; ship to MVP Steam build with the unverified Steam Deck cost.
- **Pros**: Honors the Sprint 14 plan; visual identity fidelity ships in MVP; player gets the full Pillar 4 experience day-one.
- **Cons**: Steam Deck performance is unverified. macOS Forward+ on Metal is a poor proxy for Steam Deck Linux Vulkan — the GPU/driver/thermal envelope is different. A frame-time regression on Steam Deck would surface only post-launch, on a platform a meaningful slice of the player base uses (Steam Deck verified games are a Steam discovery vector).
- **Estimated Effort**: 1.5d shader authoring + 0.25d dev-machine profiling.
- **Rejection Reason**: Performance verification is non-negotiable for the constrained platform. Without Steam Deck access, this alternative ships unverified perf on a target-platform that's part of `.claude/docs/technical-preferences.md`'s explicit budget. Defer until verification is possible.

### Alternative 2: Ship a cheaper effect (e.g., color-grade only, no DoF)

- **Description**: Author only the warm-lantern overlay (a color-grade post-process) — much cheaper than tilt-shift DoF; ~1ms cost on most GPUs. Skip the tilt-shift entirely.
- **Pros**: Lower performance risk; honors part of the Visual Identity Anchor; visible to player.
- **Cons**: Still requires Steam Deck verification at some point. Half-measure that doesn't land the full HD-2D promise. Authoring + wiring SubViewport composition for ONE effect is similar effort to authoring it for both.
- **Estimated Effort**: 0.75d shader authoring + 0.25d dev-machine profiling.
- **Rejection Reason**: Half-measures fragment the project's roadmap fidelity (game-concept.md schedules a coherent shader pass, not partial). Defer the full pass until both effects can land together.

### Alternative 3: Defer to V1.0 prestige tier (further than Vertical Slice)

- **Description**: Push HD-2D shader pass past Vertical Slice tier to V1.0 prestige.
- **Pros**: Reduces scope pressure further; aligns with cozy register's slow-burn polish cadence.
- **Cons**: Vertical Slice tier IS the polish tier per game-concept.md §Roadmap. Pushing past Vertical Slice contradicts the documented schedule and would require a roadmap-drift ADR. Vertical Slice is also the "more visual polish" tier — deferring HD-2D past it leaves Vertical Slice without any shader work.
- **Estimated Effort**: 0d (further deferral).
- **Rejection Reason**: Excessive deferral; contradicts game-concept.md §Roadmap.

### Alternative 4: Defer to Vertical Slice per game-concept.md §Risks (chosen)

- **Description**: Honor the existing fallback path. MVP ships with parchment theme alone. Vertical Slice tier lands the shader pass per the original roadmap.
- **Pros**: Aligns with documented project plan; zero MVP scope cost; pivot is a content patch (no architectural drift); playtest-04 evidence already validates parchment-only as a 3/5 cozy register that clears the gate.
- **Cons**: MVP loses the upper polish layer of Pillar 4. Player experience is "good but not finished" on the visual front.
- **Estimated Effort**: 0d.
- **Rejection Reason**: N/A — chosen.

## Consequences

### Positive

- **Sprint 14 closure unblocked**: S14-M5 closes via this ADR (when Accepted) — no false "incomplete Must Have" signal blocking sprint retro.
- **Roadmap fidelity preserved**: game-concept.md §Roadmap (HD-2D shader pass in Vertical Slice tier) is honored, not contradicted.
- **Performance risk eliminated for MVP**: no unverified shader work ships to Steam Deck users.
- **Pivot is cheap**: Vertical Slice tier sprint authors the successor ADR + lands the shaders without any MVP code refactoring (additive change).
- **Playtest-04 evidence supports the bar**: Pillar 2 (cozy register) clears the gate at 3/5 with parchment theme alone. Existing visual quality is acceptable for MVP.
- **Aligns with Sprint 13 retro recommendation**: explicit defensible-default ADR for hardware-blocked work, modeled on ADR-0016 (silent-MVP audio).

### Negative

- **MVP visual identity is partial**: Pillar 4 (HD-2D Pixel Pride) ships with pixel art + parchment theme but no tilt-shift / warm-lantern overlay. Players who expect full Octopath-style HD-2D from screenshots / marketing will see a less-polished product than the marketing pitch.
- **Marketing alignment risk**: if marketing copy emphasizes "HD-2D" or "Octopath-inspired", MVP screenshots may underdeliver against the pitch. Mitigation: align marketing copy with shipped state until pivot lands ("HD-2D-inspired pixel art" rather than "full HD-2D shader treatment").
- **Vertical Slice tier loads up**: Vertical Slice (post-MVP) gets HD-2D shader pass + class tier system + 2nd biome content per game-concept.md §Roadmap. The shader pass alone is ~1.5-2d of work; Vertical Slice scope budget should reflect this.
- **Steam Deck "Verified" badge harder to earn**: Steam Deck Verified requires consistent 60fps; without dedicated profiling pass, MVP build may launch as "Playable" rather than "Verified" until Vertical Slice tier work lands the shader + measures.

### Neutral

- **Existing parchment theme infrastructure**: S10-M1 / S10-M2 Theme.tres + UIFramework helpers continue to ship unchanged.
- **Rendering pipeline**: Forward+ default unchanged.
- **Audio polish path** (ADR-0016): independent decision; this ADR does not affect audio.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Marketing materials emphasize HD-2D and MVP underdelivers | MEDIUM | MEDIUM | Align marketing copy with shipped state; emphasize "HD-2D-inspired" rather than full shader treatment. Defer marketing finalization until pivot trigger fires. |
| Player reviews flag missing visual polish as a complaint | MEDIUM | LOW (recoverable via Vertical Slice patch) | Pivot trigger #2; track via `production/playtests/` + Steam reviews post-launch. |
| Vertical Slice scope balloons because HD-2D + class tier + 2nd biome compete for capacity | MEDIUM | MEDIUM | Vertical Slice sprint planning should explicitly budget HD-2D as 1.5-2d; if capacity tight, prioritize HD-2D over the second biome (visual fidelity > content volume per Pillar 4). |
| Steam Deck access never lands during MVP-to-V1.0 timeline | LOW | LOW (the dev-machine profiling pivot trigger #4 is the fallback fallback) | Pivot trigger #4 covers this case; AI-shader-specialist agent + macOS profiling is a viable cheapest path. |

## Performance Implications

| Metric | Before | Expected After (this ADR — deferral) | Budget |
|--------|--------|---------------------------------------|--------|
| CPU (frame time) | Current parchment-theme baseline (well under budget) | Unchanged | 16.6ms (60fps) |
| GPU (frame time) | Current Forward+ default | Unchanged | 16.6ms (60fps) |
| Memory | 0 KB (no shader resources) | Unchanged | 256 MB (mobile) / 512 MB (PC) |
| Load Time | Current (no shader compilation) | Unchanged | N/A |

Successor ADR (Vertical Slice tier shader pass) must measure on Steam Deck and budget ≤2ms total cost across both effects (tilt-shift + warm-lantern combined) to leave headroom for combat-tick + UI rendering.

## Migration Plan

This ADR documents the decision to NOT ship HD-2D shader work in MVP. No code migration is required for adoption.

**Migration applies only to the successor ADR** (when a pivot trigger fires):

1. **Successor ADR authored** at `docs/architecture/ADR-NNNN-hd-2d-shader-pass-vertical-slice.md`. Status: Proposed.
2. **Steam Deck (or equivalent rig) profiling baseline established** — current frame-time on parchment-only build at 1280×800 60fps.
3. **Tilt-shift DoF shader authored** at `assets/shaders/tilt_shift_dof.gdshader`. Per-effect frame-time measured.
4. **Warm-lantern overlay shader authored** at `assets/shaders/warm_lantern_overlay.gdshader`. Per-effect frame-time measured.
5. **SubViewport composition wired** at MainRoot.tscn level (or per-screen if Visual Identity Anchor calls for it).
6. **Combined frame-time measured** on Steam Deck; ≤16.6ms target verified.
7. **Manual screenshot evidence** committed: before/after on guild_hall + dungeon_run_view + return_to_app screens.
8. **Successor ADR status flips** to Accepted; this ADR's status flips to "Superseded by ADR-NNNN".
9. **`game-concept.md` §Roadmap** reflects the landing (no change to text — Vertical Slice tier already lists "+ HD-2D shader pass").

**Rollback plan**: if the successor ADR's shader pass introduces frame-time regressions on Steam Deck or visual artifacts in playtest, delete the SubViewport composition + shader resources. Parchment theme degrades to current MVP state. This ADR re-applies. No code refactor needed.

## Validation Criteria

- [x] `game-concept.md` §Risks fallback path is honored (HD-2D deferred to Vertical Slice per the documented schedule).
- [x] No new code changes ship for HD-2D in MVP scope.
- [x] Parchment theme + UIFramework infrastructure continues to ship unchanged.
- [x] No shader files exist in `assets/shaders/` (verifies the deferral).
- [ ] **PENDING USER SIGN-OFF**: status flips from Proposed to Accepted after user reviews and approves.
- [ ] Sprint 14 retro accounts for S14-M5 as DONE-VIA-DEFERRAL (separate from DONE-VIA-IMPLEMENTATION).
- [ ] Pivot trigger checklist captured in `production/sprints/sprint-15.md` (or successor) when Sprint 15 plan is authored — track the four triggers per sprint cycle.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|---------------------------|
| `design/gdd/game-concept.md` | Project pillar | §Risks "HD-2D rendering fidelity" + fallback "crisp pixel art without HD-2D shader layer for MVP, add shader polish in Vertical Slice tier" | This ADR formalizes the fallback as a binding decision rather than an implicit fallback |
| `design/gdd/game-concept.md` | Project roadmap | §Roadmap Vertical Slice tier "+ HD-2D shader pass" | This ADR honors the original schedule by explicitly NOT pre-promoting the work to MVP |
| `design/art/art-bible.md` | Art Bible | §Visual Identity Anchor (HD-2D pixel pride) | This ADR partially satisfies Pillar 4 — pixel sprites + parchment theme ship; HD-2D shader polish defers to Vertical Slice |
| `production/sprints/sprint-14.md` | Sprint plan | S14-M5 HD-2D visual polish pass | This ADR closes S14-M5 as DEFERRED. Sprint 14 retro accounts for this as a documented deferral, not an incomplete Must Have. |

## Related

- **Modeled on**: `docs/architecture/ADR-0016-audio-asset-sourcing-silent-mvp.md` — same defensible-default ADR pattern (cheapest path with documented pivot triggers; future-proof against successor ADR landing the deferred work).
- **Honors**: `design/gdd/game-concept.md` §Risks fallback path (pre-existing project plan).
- **Defers to**: future Vertical Slice tier sprint (post-MVP) — successor ADR will reference this as the deferral rationale.
- **Visual Identity Anchor source**: `design/art/art-bible.md` §Visual Identity Anchor + `design/gdd/game-concept.md` Pillar 4.
- **Empirical baseline**: `production/playtests/playtest-04-post-sprint-9-polish-2026-05-05.md` Pillar 2 = 3/5 (parchment-only sufficient for MVP cozy register).
- **Tests**: no test files added or modified by this ADR — the deferral is a non-decision at the code level.

---

## ⚠️ User Sign-Off Required

This ADR is currently **Proposed**. Sprint 14 S14-M5 is BLOCKED on this ADR's status per the docs/CLAUDE.md rule "stories referencing a Proposed ADR are auto-blocked".

**To accept** (HD-2D deferred to Vertical Slice tier):
1. Read this ADR's Decision + Consequences sections.
2. Confirm the trade-off (Pillar 4 partial in MVP) is acceptable.
3. Update Status from "Proposed (PENDING USER SIGN-OFF)" to "Accepted" with the date.
4. Update `production/sprints/sprint-14.md` S14-M5 to "DONE — deferred via ADR-0017".

**To reject** (attempt HD-2D shader pass on dev-machine profiling alone):
1. Update Status to "Rejected — see Sprint 14 retro" with rationale.
2. Re-open S14-M5; schedule shader-specialist agent run for tilt-shift OR warm-lantern.
3. Accept the unverified Steam Deck performance risk; mitigate with post-launch profiling.

**To defer the decision** (remain Proposed):
- Sprint 14 closes with S14-M5 BLOCKED. Sprint 15 plan inherits the unresolved decision.
