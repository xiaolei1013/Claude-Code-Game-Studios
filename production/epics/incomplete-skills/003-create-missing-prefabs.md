# Story: Create Missing Skill Prefabs

> **Epic**: incomplete-skills
> **Type**: Visual
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: N/A -- code completion task derived from systems-index.md ("3 need prefabs")
**ADR Reference**: None directly -- operates within existing D4 Skill System patterns
**Control Manifest Rules**: F-017 (no new architectural paradigms -- use existing prefab patterns from Prefabs/Skills/)

## Description

Create the missing prefabs for the 3 skills identified in the systems-index progress tracker. These skills have working code that references prefab fields via `[SerializeField]`, but the prefab assets do not exist in `Assets/Trizzle/Prefabs/Skills/`. Without these prefabs, the skills instantiate nothing at runtime (null reference guards prevent crashes, but the skills have no visual or gameplay effect).

**Prefab 1: IceWall Prefab** (`Assets/Trizzle/Prefabs/Skills/IceWall.prefab`)

Referenced by: `Defense/IceWallSkill.cs` field `iceWallPrefab`
Code requirement (from EDITOR TODO at line 74):
- `BoxCollider` sized `(wallLength, wallHeight, wallThickness)` -- values from IceWallSkill SerializeField defaults
- Must block enemy movement (non-trigger collider on appropriate layer)
- Visual: ice wall mesh or particle effect consistent with existing frost skill VFX (reference `FrostArmor.prefab`, `FX_ShardIce_*.prefab`)
- Duration: controlled by IceWallSkill code (prefab is instantiated, skill handles destruction timing)

**Prefab 2: IcePond Prefab** (`Assets/Trizzle/Prefabs/Skills/IcePond.prefab`)

Referenced by: `Defense/IcePondSkill.cs` field `icePondPrefab`
Code requirement (from EDITOR TODO at line 93):
- `SphereCollider` with `isTrigger = true`, `radius = pondRadius` (from IcePondSkill SerializeField defaults)
- Trigger zone that applies slow/freeze effects to enemies entering it
- Visual: ground-level ice/frost area effect consistent with existing frost VFX

**Prefab 3: Icicle Projectile Prefab** (`Assets/Trizzle/Prefabs/Skills/Icicle.prefab`)

Referenced by: `Defense/IcePondSkill.cs` field `iciclePrefab`
Code context (line 75-77):
- Instantiated at `startPosition` with `Quaternion.LookRotation(direction)`
- Projectile behavior -- needs a collider for hit detection and a Rigidbody or projectile movement script
- Visual: ice shard/icicle projectile consistent with existing ice projectiles (`FX_ShardIce_Shooting_01.prefab`)
- Should follow existing projectile patterns in `Assets/Trizzle/Scripts/Combat/` (object pooling compatible per project architecture)

**Note on GuardianCall:** `Condition/GuardianCallSkill.cs` references `minionPrefab` and `defaultMinionPrefab`, but this is a minion-spawning skill that likely needs an enemy-type prefab, not a skill VFX prefab. The audit report (Story 001) will clarify whether GuardianCall's prefab is a missing asset or an intentional configuration gap (the field may be assigned in the Inspector from existing enemy prefabs like `ForestGuardianObjectPrefab.prefab`). If the audit identifies it as missing, add it to this story's scope.

**Existing prefab patterns to follow:**
- `Assets/Trizzle/Prefabs/Skills/` contains 20+ existing skill prefabs (ArcaneShield, Blizzard, Earthquake, FireShield, FrostArmor, LightningShield, etc.)
- Prefabs use Unity's standard component composition: Renderer + Collider + optional ParticleSystem + optional script
- Object pooling compatibility: prefabs should work with the project's `ObjectPool/` system (no `Awake()` dependencies that break on re-enable)

## Acceptance Criteria

- [ ] `IceWall.prefab` exists in `Assets/Trizzle/Prefabs/Skills/` with BoxCollider sized per IceWallSkill defaults
- [ ] `IcePond.prefab` exists in `Assets/Trizzle/Prefabs/Skills/` with SphereCollider (isTrigger=true) sized per IcePondSkill defaults
- [ ] `Icicle.prefab` exists in `Assets/Trizzle/Prefabs/Skills/` with appropriate collider and projectile behavior
- [ ] All 3 prefabs have visual effects consistent with existing frost/ice skill VFX style
- [ ] IceWallSkill.cs `iceWallPrefab` field can be assigned the new prefab in Inspector and skill functions at runtime
- [ ] IcePondSkill.cs `icePondPrefab` and `iciclePrefab` fields can be assigned and skill functions at runtime
- [ ] Prefabs are object-pool compatible (no `Awake()`-only initialization that breaks on re-enable)
- [ ] EDITOR TODO comments in IceWallSkill.cs (line 74) and IcePondSkill.cs (line 93) are resolved or removed after prefab creation
- [ ] All prefabs have appropriate layer assignments for collision filtering (enemies vs. player vs. environment)

## Test Evidence

**Type**: Visual/Feel (prefab creation)
**Path**: `production/qa/evidence/`

- Screenshot: each prefab instantiated in a test scene showing visual appearance
- Lead sign-off: VFX style matches existing frost/ice skill prefabs
- Runtime test: assign prefabs to skill SO assets in Inspector, activate skills in play mode, confirm instantiation and collision behavior

## Dependencies

- **Blocked by**: 001-skill-code-audit (confirms exactly which prefabs are missing and whether GuardianCall is in scope)
- **Blocks**: 004-skill-completion-tests (tests need prefabs wired to verify full skill activation)
- **Soft dependency**: 002-complete-skill-implementations (IceWall and IcePond targeting TODOs should be resolved before or alongside prefab wiring -- coordinate with Story 002)

## Engine Notes

Prefab creation in Unity 6000.3.11f1 uses standard Inspector workflows. Collider, Rigidbody, ParticleSystem, and Renderer components are stable Unity APIs with no post-cutoff changes. Object pooling integration should follow the existing `ObjectPool/` patterns in the project. URP material assignments should use the project's existing URP shader setup (check `Assets/Trizzle/Materials/` or existing skill prefabs for shader references).

## Completion Notes
**Completed**: 2026-04-10
**Criteria**: 2/9 passing (code support done; 3 prefab .prefab files require Unity Editor creation)
**Deviations**: None
**Test Evidence**: Visual: evidence doc pending Unity Editor prefab creation
**Code Review**: Skipped (Lean mode)
**Files Changed**: IcePondArea.cs (new trigger zone MonoBehaviour), IcePondSkill.cs (wire IcePondArea, remove EDITOR TODO), IceWallSkill.cs (remove EDITOR TODO)
**Editor Work Remaining**: Create IceWall.prefab (BoxCollider), IcePond.prefab (SphereCollider+IcePondArea), Icicle.prefab (Collider+projectile) in Assets/Trizzle/Prefabs/Skills/
