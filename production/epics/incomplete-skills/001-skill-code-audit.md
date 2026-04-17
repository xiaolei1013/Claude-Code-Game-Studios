# Story: Skill Code Audit

> **Epic**: incomplete-skills
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: N/A -- code audit task derived from systems-index.md progress tracker ("15+ skills need TODO resolution")
**ADR Reference**: ADR-0005 (Accepted) -- R-004 (shared skills must cast to ICharacterClass or PlayerController, never MagePlayerController), F-010 (no MagePlayerController casts in shared skill code)
**Control Manifest Rules**: R-004, F-010, F-017 (no new architectural paradigms)

## Description

Perform a systematic audit of all 121 skill implementation files to produce a complete catalog of incomplete work. This is the planning story -- no code changes, only a categorized inventory that Story 002 and Story 003 will consume as their work list.

**Audit scope:**

1. **Grep all skill files** in `Assets/Trizzle/Scripts/Character/Skill/` for `TODO`, `FIXME`, `HACK`, `placeholder`, `not implemented`, and `incomplete` (case-insensitive). Known results from initial scan: **10 files, 24 occurrences** across:
   - `Support/ArcaneReboundSkill.cs` -- 2 TODOs (StateCategory.SpellReflection, damage system reflection integration)
   - `Support/ExecutionFlowSkill.cs` -- 1 TODO (skill system integration)
   - `Upgrade/FrostFocusSkill.cs` -- 2 TODOs (status effect system integration, VFX/SFX)
   - `Defense/IceWallSkill.cs` -- 2 TODOs (iceWallPrefab BoxCollider setup, targeting/input integration)
   - `Defense/IcePondSkill.cs` -- 3 TODOs (icePondPrefab SphereCollider setup, targeting/input integration, iciclePrefab)
   - `Defense/LightningShieldSkill.cs` -- 2 placeholders (area-of-effect lightning, chain lightning)
   - `Defense/FrostArmorSkill.cs` -- 1 placeholder (area-of-effect frost)
   - `Condition/GuardianCallSkill.cs` -- 1 placeholder (collision system integration)
   - `Condition/CurseBreakerSkill.cs` -- 5 placeholders (debuff detection, status effect system checks)
   - `Condition/BloodBondSkill.cs` -- 5 placeholders (enemy system integration, damage calculation, healing, VFX)

2. **Grep all skill files** for `MagePlayerController` casts. Known results: **30 files** contain direct `MagePlayerController` references. Per F-010 and R-004, shared skills must cast to `PlayerController` or `ICharacterClass` to support the Archer character (N1). Catalog which of these 30 files are shared skills vs. Mage-exclusive skills.

3. **Cross-reference prefab references** against `Assets/Trizzle/Prefabs/Skills/` to identify skills that reference prefabs that do not exist. Known results: IceWall (missing `iceWallPrefab`), IcePond (missing `iciclePrefab` and `icePondPrefab`), GuardianCall (missing `minionPrefab` -- though enemy prefabs exist, no dedicated skill-spawned minion prefab exists).

4. **Produce the audit report** as a categorized table in `production/epics/incomplete-skills/audit-report.md`:
   - **Category A: Code TODOs** -- skills needing logic fixes (feed into Story 002)
   - **Category B: Missing Prefabs** -- skills needing prefab creation (feed into Story 003)
   - **Category C: MagePlayerController Casts** -- skills needing cast refactoring for N1 compatibility (feed into Story 002)
   - For each entry: file path, line numbers, issue description, severity (blocking vs. advisory), estimated sub-task size (XS/S/M)

**Out of scope:** This story does not fix any code. It produces the work list.

## Acceptance Criteria

- [ ] All 121 skill files in `Assets/Trizzle/Scripts/Character/Skill/` scanned for TODO/FIXME/HACK/placeholder/incomplete patterns
- [ ] All skill files scanned for `MagePlayerController` casts (F-010 violations)
- [ ] All prefab references cross-referenced against existing prefab files in `Assets/Trizzle/Prefabs/Skills/`
- [ ] Audit report written to `production/epics/incomplete-skills/audit-report.md`
- [ ] Each entry categorized as Code TODO, Missing Prefab, or MagePlayerController Cast
- [ ] Each entry includes: file path, line number(s), issue description, severity, estimated size
- [ ] Audit report totals match or exceed known counts: 10 TODO files, 30 MagePlayerController files, 3 missing-prefab skills
- [ ] Audit report identifies which MagePlayerController-cast skills are shared vs. Mage-exclusive (to scope Story 002)

## Test Evidence

**Type**: Config/Data (audit output)
**Path**: `production/epics/incomplete-skills/audit-report.md`

- Smoke check: audit report exists and contains all three category tables
- Verification: re-run grep commands and confirm counts match report totals

## Dependencies

- **Blocked by**: None -- this is the first E5 story
- **Blocks**: 002-complete-skill-implementations (consumes Category A + C), 003-create-missing-prefabs (consumes Category B), 004-skill-completion-tests (needs audit to define test scope)

## Engine Notes

This is a read-only audit task. No Unity API usage. The grep patterns and file paths are stable across Unity versions.
