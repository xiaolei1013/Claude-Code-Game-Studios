---
name: Lantern Guild — Project UX Profile
description: Core UX constraints, session pattern, and platform targets for Lantern Guild idle-clicker
type: project
---

Lantern Guild is a cozy fantasy idle-clicker on Godot 4.6. Steam primary (MVP), iOS/Android post-launch.

**Session pattern**: 2-4x daily, 2-5 minute sessions. Core UX moment is the first 30 seconds after reopening — player must immediately see away rewards with zero friction.

**Input**: Mouse primary (PC), full touch parity required from MVP. No hover-only, no right-click-only, no gamepad.

**Platform targets**: PC Steam, Steam Deck (1280x800 60fps), iOS, Android.

**No fail state**: pure progression, losses return partial loot + class hint.

**Primary actions**: collect accumulated rewards, recruit/level heroes, assign class formations to dungeons.

**Art direction in progress**: "Lantern-Lit Pixel Diorama" — warm ambers/dusk/gold palette, diegetic UI (paper textures, illuminated-manuscript accents), pixel iconography, stately/bouncy animation, 1-2 fonts + hand-lettered accent.

**Key UX conflicts flagged**:
- Paper/parchment textures risk hiding reward numbers (contrast failure)
- Stately animations conflict with fast reward reveal (must complete within 300ms)
- Hand-lettered fonts must not be used for numeric/status text
- Warm palette (amber/gold) cannot be sole differentiator for positive/negative states — shape+label required

**Why**: Art bible authoring session; UX constraints needed before art director finalizes visual direction.

**How to apply**: Reference these constraints whenever evaluating UI mockups, HUD layouts, or animation specs for this project.
