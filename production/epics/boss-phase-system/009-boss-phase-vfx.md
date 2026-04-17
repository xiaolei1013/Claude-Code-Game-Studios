# Story: Boss Phase VFX

> **Epic**: boss-phase-system
> **Type**: Visual
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-boss-004 (stagger state plays VFX during phase transition)
**ADR Reference**: ADR-0004 -- Decision section (TransitionVFX field on BossPhase struct; instantiated during stagger coroutine), Performance Implications (Rain of Fire + transition VFX combined < 2ms render)
**Control Manifest Rules**: None directly -- VFX is presentation layer, not logic

## Description

Create the visual effects that communicate boss phase transitions to the player. These VFX are the "cinematic beat" from the Player Fantasy -- the moment the player sees the boss shift should feel dramatic and readable.

**VFX to create:**

1. **Stagger Animation** -- Boss-specific stagger reaction when a phase transition triggers:
   - Brief recoil/stun animation (0.5s duration, matching stagger window)
   - Should read as "the boss is hurt and transforming" -- not just standing still invulnerably
   - Can be a generic stagger animation shared across bosses, or per-boss if time allows

2. **Phase Transition VFX** -- Particle effect played at boss position during stagger:
   - Energy burst / shockwave expanding outward from boss
   - Color-coded per phase (e.g., Phase 2 = orange/aggressive, Phase 3 = red/desperate)
   - Duration: ~0.5s, matching stagger window. Should not linger after transition completes.
   - Must be visible against all room backgrounds (high contrast)

3. **Phase-Shift Visual Cue** -- Persistent visual change on the boss after transitioning:
   - Subtle aura, color shift, or particle trail that persists for the remainder of the phase
   - Communicates "this boss is now in an enraged/different state" at a glance
   - Phase 2: warm glow (orange/yellow). Phase 3: intense glow (red/dark)
   - Must not obscure the boss's attack telegraphs or hitbox

4. **Shield VFX** (for ShieldPhaseAbility):
   - Persistent shield bubble around boss while shield is active
   - Crack effect on each hit (progressive damage visible)
   - Shatter effect when shield breaks
   - Shield must be visually distinct from stagger invulnerability (player needs to know "attack this" vs "wait this out")

**Performance budget:**
- All boss VFX combined must stay under 2ms render time (ADR-0004 Performance Implications)
- Target: 50-100 particles per transition burst, 10-20 particles for persistent aura
- Mobile-compatible particle counts

## Acceptance Criteria

- [ ] Stagger animation plays on boss during 0.5s transition window
- [ ] Phase transition VFX (energy burst) plays at boss position and is visible against room backgrounds
- [ ] Phase-shift visual cue persists after transition (aura/glow indicates current phase)
- [ ] Phase 2 and Phase 3 visual cues are visually distinct from each other
- [ ] Shield VFX is visually distinct from stagger invulnerability
- [ ] Shield crack VFX plays on each hit; shield shatter VFX plays on break
- [ ] All VFX render within 2ms budget combined (profiler verification)
- [ ] VFX are compatible with mobile rendering target
- [ ] VFX prefabs are referenced in BossPhase.TransitionVFX fields on boss prefabs

## Test Evidence

**Type**: Visual (Screenshot + Lead Sign-off)
**Path**: `production/qa/evidence/`

- Screenshot: Phase 2 transition VFX on Stone Guardian (stagger + energy burst)
- Screenshot: Phase 3 transition VFX on Lich King (different color/intensity from Phase 2)
- Screenshot: Shield VFX active on Lich King (bubble visible)
- Screenshot: Shield crack VFX after 2 hits (progressive damage)
- Screenshot: Shield shatter VFX on break
- Profiler screenshot: VFX render time < 2ms during phase transition
- Lead sign-off: Visual quality meets project bar

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (TransitionVFX field must exist on BossPhase), 002-stagger-state-phase-transition (stagger coroutine instantiates VFX)
- **Blocks**: None (VFX can be added to prefabs after initial configuration; Story 008 can use placeholders)
- **Soft dependency**: 006-ability-shield-phase (shield VFX referenced by ShieldPhaseAbility)

## Engine Notes

Unity particle system (Shuriken) or VFX Graph. Project uses URP -- ensure VFX are URP-compatible. Existing VFX in the project (spell effects, enemy deaths) can serve as reference for style and performance budget. If using VFX Graph, verify compatibility with Unity 6000.3.11f1 and mobile target.
