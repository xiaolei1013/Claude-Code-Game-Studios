# Story: Archer VFX & Animation

> **Epic**: archer-character
> **Type**: Visual
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-archer-009 (DraftRunController filters draft options by class compatibility using CanApplyUpgrade() against player collected skills)
**ADR Reference**: ADR-0005 -- Architecture Diagram (ArrowShotSkill, DodgeRollSkill with VFX), GDD Code Changes item 9 (arrow projectile prefab and dodge roll animation/VFX)
**Control Manifest Rules**: F-017 (MonoBehaviour + SO + interface only), F-018 (no platform-specific gameplay logic in VFX -- platform divergence only in Scenes/PC/ and Scenes/Mobile/)

## Description

Create the visual assets for the Archer character: arrow projectile prefab with proper VFX, dodge roll animation and VFX, and Archer character visual placeholder. This story replaces all programmer-art placeholders from stories 003 and 004 with production-quality visuals.

**Assets to create:**

### Arrow Projectile
1. **`ArrowProjectile.prefab`** -- Production-quality arrow projectile in `Assets/Trizzle/Prefabs/Projectiles/`
   - Arrow mesh/sprite with clear directional indicator
   - Trail VFX (subtle, not distracting from gameplay clarity)
   - Impact VFX on enemy hit (brief particle burst)
   - Destroy VFX on wall/obstacle hit
   - Must match projectile speed 18 visually (no visual lag behind the collider)

### Dodge Roll
2. **Dodge Roll Animation** -- Roll animation for the Archer character model
   - Smooth directional roll animation (forward, side, diagonal)
   - Animation duration matches roll travel time (`dodgeDistance / rollSpeed`)
   - Clear visual feedback for i-frame window (e.g., ghost/transparency effect during 0.2s)
   - Landing recovery pose

3. **Dodge Roll VFX** -- Visual effects for the roll
   - Dust/wind trail during roll movement
   - Brief flash or ghost effect during i-frame window (communicates invulnerability to player)
   - Afterimage skill (006) spawns a separate decoy entity -- this story provides the base roll VFX only

### Archer Character Visual
4. **Archer character model/sprite** -- Placeholder or production visual for the Archer
   - Must be visually distinct from Mage at a glance (different silhouette, color palette)
   - Minimum animation set per GDD Open Question 2: idle, run, arrow shot, dodge roll, death, hit reaction (6 animations)
   - Character select screen visual for `CharacterDatabase` entry

**Visual quality targets:**
- Arrow projectile must feel "snappy" at speed 18 (GDD Player Fantasy: precision and speed)
- Dodge roll must feel "reactive" -- instant visual response on input
- I-frame visual feedback is critical for player readability -- players must see when they are invulnerable
- All VFX must maintain 60 FPS on PC, 30 FPS on mobile (G-001)

## Acceptance Criteria

- [ ] Arrow projectile prefab has mesh/sprite, trail VFX, and impact VFX
- [ ] Arrow projectile visual tracks the collider at speed 18 (no visual lag)
- [ ] Dodge roll animation plays during roll movement in correct direction
- [ ] I-frame window has clear visual feedback (ghost/transparency or flash effect)
- [ ] Archer character is visually distinct from Mage at a glance
- [ ] Minimum 6 animations present: idle, run, arrow shot, dodge roll, death, hit reaction
- [ ] Character select screen shows Archer visual
- [ ] All VFX maintain 60 FPS on PC (no frame drops from particle overdraw)
- [ ] GDD Acceptance Criterion 1 (visual component): "Archer has visual in all 11 locales" (character select screen)

## Test Evidence

**Type**: Visual -- Screenshot + Lead Sign-off
**Path**: `production/qa/evidence/`

- Screenshot: Arrow projectile in-flight with trail VFX visible
- Screenshot: Arrow impact VFX on enemy hit
- Screenshot: Dodge roll mid-animation with i-frame visual effect active
- Screenshot: Archer character on character select screen alongside Mage
- Screenshot: Archer idle, run, and attack animations in gameplay
- Lead sign-off required on visual quality and gameplay clarity

## Dependencies

- **Blocked by**: 003-arrow-shot-skill (ArrowShotSkill and placeholder projectile must exist), 004-dodge-roll-skill (DodgeRollSkill must exist for dodge VFX integration)
- **Blocks**: None -- this is a polish story; gameplay is functional without production VFX

## Engine Notes

Uses Unity's particle system, animation system (Animator/AnimationController), and material/shader system -- all stable APIs. VFX should follow existing Fireball/DashSkill VFX patterns for consistency. Verify that the existing animation rig (if shared with Mage) supports archer-specific animations, or confirm a separate rig is needed. Mobile platform VFX may need reduced particle counts -- check existing mobile VFX patterns.
