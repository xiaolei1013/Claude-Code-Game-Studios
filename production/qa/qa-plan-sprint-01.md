# QA Plan — Sprint 1

**Sprint**: 1 (2026-04-08 to 2026-04-22)
**Sprint Goal**: Establish IDifficultyProvider foundation + audit incomplete skills
**QA Lead**: Claude (qa-lead agent)
**Generated**: 2026-04-08

---

## Story Classification

Stories are classified by the test evidence taxonomy in `.claude/docs/coding-standards.md`.
BLOCKING gates must have passing evidence before a story is marked Done.
ADVISORY gates must have documented evidence (report, screenshot, or smoke-check record).

| Story | Name | Type | Test Evidence Required | Gate Level |
|-------|------|------|------------------------|------------|
| E2-001 | IDifficultyProvider Interface & Campaign Provider | Logic | Unit tests — all 7 interface properties, null-config error path, provider switch | BLOCKING |
| E2-002 | Normal & Hard Config Presets | Config/Data | Smoke check — Inspector values match GDD table exactly | ADVISORY |
| E2-003 | Enemy Stat Scaling Integration | Integration | Integration tests — EnemyController reads from provider on Normal and Hard; regression against demo behavior | BLOCKING |
| E2-004 | Enemy Count Scaling | Logic | Unit tests — Ceil formula at ≥3 wave sizes, boss exemption, Normal identity | BLOCKING |
| E5-001 | Skill Code Audit | Config/Data | Audit report at `production/epics/incomplete-skills/audit-report.md` with all three category tables | ADVISORY |
| E5-002 | Complete Skill Implementations | Logic | Unit tests — each fixed skill activates without exception; grep assertion of zero TODO/FIXME in skill directory | BLOCKING |

**Priority note**: E2-004 and E5-002 are Should Have stories and may not land in Sprint 1. Their BLOCKING gates apply as soon as implementation begins — they cannot be marked Done without passing evidence regardless of sprint.

---

## Test Cases per Story

### E2-001: IDifficultyProvider Interface & Campaign Provider

**Story type**: Logic (new interface + MonoBehaviour + SO class)
**Test path**: `tests/unit/difficulty/`
**Naming convention**: `DifficultyProviderTests.cs` (or engine-appropriate file per project test framework)

#### Unit Tests

1. `test_campaign_provider_returns_normal_multipliers`
   - Setup: Instantiate `CampaignDifficultyProvider` with a test `DifficultyConfig` SO loaded with Normal values (StatMultiplierMin=1.0, StatMultiplierMax=1.2, EnemyCountMultiplier=1.0, HealDropMultiplier=1.0, PacingMultiplier=1.0, RewardMultiplier=1.0).
   - Assert: All 6 float properties return exactly the SO values. No rounding, no defaults.
   - Rationale: Verifies the delegation chain — provider reads from SO, not from hardcoded fallbacks.

2. `test_campaign_provider_returns_hard_multipliers`
   - Setup: Same provider with Hard config SO (StatMultiplierMin=1.2, StatMultiplierMax=1.5, EnemyCountMultiplier=1.25, HealDropMultiplier=0.5, PacingMultiplier=0.75, RewardMultiplier=2.0).
   - Assert: All 6 float properties match GDD Hard column exactly (per ADR-0001 Validation Criteria).
   - Rationale: Ensures no property delegates to the wrong field.

3. `test_campaign_provider_boss_exempt_always_true`
   - Setup: Instantiate `CampaignDifficultyProvider` with any config (Normal or Hard).
   - Assert: `IsBossExemptFromCount` returns `true` regardless of config values.
   - Rationale: Story AC explicitly requires this to always return `true`; it must not be data-driven.

4. `test_campaign_provider_null_config_logs_error`
   - Setup: Instantiate `CampaignDifficultyProvider` without assigning `_config` (null reference).
   - Assert: `Awake()` logs a descriptive error (not a null reference exception that crashes). The error message must contain enough context to identify the misconfigured scene object.
   - Rationale: Story AC and ADR-0001 require a null-check with a descriptive error, not a silent NullReferenceException.

5. `test_game_manager_active_provider_initialized_on_awake`
   - Setup: Enter Play Mode with a GameManager that has a `CampaignDifficultyProvider` with Normal config attached.
   - Assert: `GameManager.Instance.ActiveDifficultyProvider` is not null after `Awake()` completes.
   - Assert: `GameManager.Instance.ActiveDifficultyProvider.StatMultiplierMin == 1.0f` (Normal preset).
   - Rationale: Story AC and ADR-0001 require `ActiveDifficultyProvider` to be non-null during gameplay.

6. `test_set_difficulty_provider_switches_active`
   - Setup: Start with Normal provider active. Create a Hard `CampaignDifficultyProvider`. Call `GameManager.SetDifficultyProvider(hardProvider)`.
   - Assert: `GameManager.Instance.ActiveDifficultyProvider.StatMultiplierMin == 1.2f` (Hard value).
   - Assert: `GameManager.Instance.ActiveDifficultyProvider.EnemyCountMultiplier == 1.25f`.
   - Rationale: Verifies the provider switch path that Story 008 (Hard Mode Unlock) will use.

**Evidence file**: `tests/unit/difficulty/DifficultyProviderTests.cs` (or `test_difficulty_provider.gd` if project migrates to Godot — see CLAUDE.md for current engine config).

---

### E2-002: Normal & Hard Config Presets

**Story type**: Config/Data (ScriptableObject asset creation)
**Test path**: `production/qa/evidence/smoke-e2-002-[date].md`

#### Smoke Check Steps

Tester opens each asset in the Unity Inspector and verifies field values against the GDD table. No code changes — read-only verification.

**Normal preset** (`DifficultyConfig_Normal.asset`):

| Field | Expected | Pass Condition |
|-------|----------|----------------|
| StatMultiplierMin | 1.0 | Inspector shows exactly 1 |
| StatMultiplierMax | 1.2 | Inspector shows exactly 1.2 |
| EnemyCountMultiplier | 1.0 | Inspector shows exactly 1 |
| HealDropMultiplier | 1.0 | Inspector shows exactly 1 |
| PacingMultiplier | 1.0 | Inspector shows exactly 1 |
| RewardMultiplier | 1.0 | Inspector shows exactly 1 |

**Hard preset** (`DifficultyConfig_Hard.asset`):

| Field | Expected | Pass Condition |
|-------|----------|----------------|
| StatMultiplierMin | 1.2 | Inspector shows exactly 1.2 |
| StatMultiplierMax | 1.5 | Inspector shows exactly 1.5 |
| EnemyCountMultiplier | 1.25 | Inspector shows exactly 1.25 |
| HealDropMultiplier | 0.5 | Inspector shows exactly 0.5 |
| PacingMultiplier | 0.75 | Inspector shows exactly 0.75 |
| RewardMultiplier | 2.0 | Inspector shows exactly 2 |

**Wiring check**: Open the GameManager scene object. Inspect `CampaignDifficultyProvider._config`. Verify it references `DifficultyConfig_Normal.asset` (not Hard, not null).

**Live edit check**: Change `StatMultiplierMin` in Normal asset to 0.9, enter Play Mode, verify in a debug log that `ActiveDifficultyProvider.StatMultiplierMin == 0.9f`. Revert before committing. This satisfies GDD AC 9.

**Evidence to produce**: Screenshot of both Inspector panels with values visible. Save to `production/qa/evidence/smoke-e2-002-[date].png`.

---

### E2-003: Enemy Stat Scaling Integration

**Story type**: Integration (EnemyController reads from IDifficultyProvider via GameManager)
**Test path**: `tests/unit/difficulty/` (story file specifies `tests/unit/difficulty/` even though these are integration tests — follow the story file's declared path)

#### Integration Tests

1. `test_enemy_stats_scale_with_normal_provider`
   - Setup: Set `GameManager.ActiveDifficultyProvider` to a Normal `CampaignDifficultyProvider` (StatMultiplierMin=1.0, StatMultiplierMax=1.2). Spawn an enemy with known base stats (use a fixed test `EnemyData` SO with baseStat=100.0 for each attribute).
   - Assert: After `InitAttributes()`, each of the 8 attributes (Health, Attack, AttackRange, MoveSpeed, Defense, CriticalChance, CriticalDamageMultiplier, AbilityInterval) is in the range [100.0, 120.0].
   - Note: `Random.Range` is non-deterministic. Assert `finalStat >= 100.0f && finalStat <= 120.0f`, not an exact value. Do NOT seed Random in the test — the formula validity is what we are testing, not the random output.
   - Rationale: Integration path — provider exists, GameManager returns it, EnemyController reads it.

2. `test_enemy_stats_scale_with_hard_provider`
   - Setup: Set provider to Hard config (StatMultiplierMin=1.2, StatMultiplierMax=1.5). Same test enemy with baseStat=100.0.
   - Assert: Each of the 8 attributes is in the range [120.0, 150.0].
   - Rationale: Confirms the Hard multiplier range is applied, not Normal.

3. `test_normal_identical_to_demo_regression`
   - This is GDD Acceptance Criterion 1 and sprint Definition of Done requirement.
   - Method: Run existing `EnemyController` / combat tests that were passing before E2-003 implementation. All must still pass with zero modifications.
   - Assert: Test suite pass count for `EnemyController`-related tests is identical before and after E2-003 changes.
   - Evidence: CI output (or manual test run log) showing all pre-existing EnemyController tests pass. Save to `production/qa/evidence/regression-e2-003-[date].txt`.

4. `test_enemy_controller_does_not_cache_provider`
   - Setup: Initialize enemy with Normal provider. Switch `GameManager.ActiveDifficultyProvider` to Hard. Call `InitAttributes()` again.
   - Assert: The second call returns stats in the Hard range [1.2-1.5x], not the Normal range.
   - Rationale: ADR-0001 Implementation Guideline 5 forbids caching the provider at Awake. This test catches a caching regression.

5. `test_enemy_controller_no_enum_checks`
   - Method: Grep `EnemyController.cs` for `LevelDifficulty`, `DifficultyEnum`, `switch.*difficulty`, and `if.*Hard` patterns.
   - Assert: Zero matches in `InitAttributes()` and `ApplyRandomVariation()` code paths.
   - Rationale: Story AC requires no direct enum checks remain after migration.

---

### E2-004: Enemy Count Scaling

**Story type**: Logic (SpawnManager formula + boss exemption rule)
**Test path**: `tests/unit/difficulty/`

#### Unit Tests

1. `test_count_scaling_ceil_wave_of_1`
   - Input: baseCount=1, multiplier=1.25.
   - Assert: `Mathf.CeilToInt(1 * 1.25f) == 2`.
   - Rationale: GDD Edge Case 1 — a solo enemy becomes a pair on Hard. This is the most counterintuitive case and must be explicitly verified.

2. `test_count_scaling_ceil_wave_of_4`
   - Input: baseCount=4, multiplier=1.25.
   - Assert: `Mathf.CeilToInt(4 * 1.25f) == 5`.
   - Rationale: GDD AC 4 specifies exactly this case as the acceptance criterion.

3. `test_count_scaling_ceil_wave_of_7`
   - Input: baseCount=7, multiplier=1.25.
   - Assert: `Mathf.CeilToInt(7 * 1.25f) == 9`.
   - Rationale: GDD formula example. Verifies no off-by-one from incorrect floor/round usage.

4. `test_count_scaling_normal_preserves_base`
   - Input: Any baseCount (test with 1, 4, 7), multiplier=1.0.
   - Assert: scaledCount == baseCount for all inputs.
   - Rationale: Normal must behave identically to pre-difficulty-system behavior.

5. `test_boss_exempt_from_count_scaling`
   - Setup: Create a `SpawnItemInfo` where `EnemyData.IsBoss == true`, baseCount=1, provider returns `IsBossExemptFromCount == true` and EnemyCountMultiplier=1.25.
   - Assert: Spawned count == 1 (not 2).
   - Rationale: GDD AC 8 and Edge Case 3. This is explicitly tested because `Ceil(1 * 1.25) = 2` would incorrectly produce two bosses without the exemption.

6. `test_boss_detection_uses_enemy_data_not_tag`
   - Method: Grep `SpawnManager.cs` (or equivalent spawn loop file) for `.tag`, `.CompareTag`, `"Boss"`, and `"boss"` string literals in the count-scaling code path.
   - Assert: Zero tag/string matches. Boss detection must go through `EnemyData.IsBoss` (per R-022, F-007).
   - Rationale: Rule violation — string-based boss detection is a control manifest violation and a fragile pattern.

7. `test_spawn_reads_provider_not_enum`
   - Method: Grep `SpawnManager.cs` for `LevelDifficulty`, `DifficultyEnum`, and `switch.*difficulty` patterns in the spawn count logic.
   - Assert: Zero matches.
   - Rationale: F-001 — no direct enum checks in consumers.

---

### E5-001: Skill Code Audit

**Story type**: Config/Data (audit output — no code changes)
**Evidence path**: `production/epics/incomplete-skills/audit-report.md`

#### Smoke Check for Audit Completeness

The audit report is both the deliverable and the test evidence. QA verifies the report is complete and accurate by re-running the grep commands.

1. **Report structure check**: Open `production/epics/incomplete-skills/audit-report.md`. Verify it contains three distinct category tables: Category A (Code TODOs), Category B (Missing Prefabs), Category C (MagePlayerController Casts).

2. **TODO count verification**:
   - Re-run: `grep -ri "TODO\|FIXME\|HACK\|placeholder\|not implemented\|incomplete" Assets/Trizzle/Scripts/Character/Skill/ --include="*.cs" -l | wc -l`
   - Assert: File count reported in Category A matches or is within ±1 of this grep result (report may exclude Mage-exclusive files if pre-classified).
   - Known floor: at least 10 files based on story pre-scan.

3. **MagePlayerController count verification**:
   - Re-run: `grep -rl "MagePlayerController" Assets/Trizzle/Scripts/Character/Skill/ --include="*.cs" | wc -l`
   - Assert: File count in Category C matches this grep result.
   - Known floor: at least 30 files based on story pre-scan.

4. **Missing prefab verification**:
   - Verify Category B lists at minimum: `iceWallPrefab` (IceWallSkill), `iciclePrefab` (IcePondSkill), `icePondPrefab` (IcePondSkill).
   - Assert: For each Category B entry, confirm the referenced prefab path does not exist in `Assets/Trizzle/Prefabs/Skills/`.

5. **Shared-vs-exclusive classification**: Verify Category C entries each have a `Shared / Mage-exclusive` column populated. This is required for E5-002 to scope the refactor work.

**Evidence**: Audit report at `production/epics/incomplete-skills/audit-report.md`. No separate screenshot required.

---

### E5-002: Complete Skill Implementations

**Story type**: Logic (10 files with TODO/placeholder + up to 30 files with cast refactoring)
**Test path**: `tests/unit/skills/` (per sprint plan and coding standards)
**Note**: Story file lists path as `Assets/Trizzle/Tests/Character/Skill/` — use whichever location already exists for the 106 existing skill tests. QA will accept evidence from either path as long as the test runner resolves them.

#### Unit Tests

1. `test_all_fixed_skills_activate_without_exception`
   - Setup: For each skill file modified by E5-002, instantiate the skill and call its `Activate()` (or equivalent entry point).
   - Assert: No exceptions thrown. No `NotImplementedException`. No `NullReferenceException` from placeholder stubs.
   - This test is parameterized — one test case per fixed skill. If 10 skills are fixed in Part 1, 10 test cases. If 30 are refactored in Part 2, add 30 more.
   - Rationale: A skill that activates without crashing is the minimum bar for "implemented." This test catches the common pattern of placeholder bodies that `throw new NotImplementedException()` or return early with a log message.

2. `test_cursebreaker_debuff_detection_not_hardcoded`
   - Setup: Put `CurseBreakerSkill` subject into a state where `StateMachine` reports a debuff active. Call `HasDebuff()` and `HasAnyDebuff()`.
   - Assert: Returns `true` (not the hardcoded `false` from the placeholder).
   - Setup 2: Put subject into a state with no debuffs. Assert `HasDebuff()` and `HasAnyDebuff()` return `false`.
   - Rationale: Story AC calls this out explicitly — this is the most specific testable behavior in Category A.

3. `test_bloodbond_uses_damage_calculator`
   - Setup: Wire `BloodBondSkill` with a mock/stub `DamageCalculator` and `Health` system. Trigger the skill's damage path.
   - Assert: `DamageCalculator.Calculate()` (or equivalent) is called — not a hardcoded return value.
   - Assert: `Health.Heal()` (or equivalent) is called for the healing component.
   - Rationale: Story AC requires BloodBondSkill to use real system integrations, not placeholder values.

4. `test_no_mage_controller_casts_in_shared_skills`
   - Method: From the audit report Category C, take the list of shared (non-Mage-exclusive) skill files. Grep each for `MagePlayerController`.
   - Assert: Zero matches across all shared skill files post-E5-002.
   - Rationale: This is a grep-based regression check. If any shared skill still casts to `MagePlayerController`, the Archer character (N1) will break at runtime.

5. `test_all_106_existing_skill_tests_still_pass`
   - Run the full existing skill test suite (106 test files as stated in story).
   - Assert: Pass count == 106 (or the count at the time E5-002 begins). Zero regressions.
   - Evidence: CI output or manual test run saved to `production/qa/evidence/regression-e5-002-[date].txt`.
   - Rationale: Story AC explicitly requires existing tests pass after modifications.

6. `test_zero_todo_fixme_in_skill_directory` (post-E5-002 completion only)
   - Method: Grep `Assets/Trizzle/Scripts/Character/Skill/` for `TODO`, `FIXME`, `HACK`, `placeholder`, `not implemented` (case-insensitive).
   - Assert: Zero matches.
   - Rationale: Story AC requires all placeholders resolved. This grep is the definitive evidence.
   - **Important**: This test only applies when E5-002 is marked complete. Do not run it while the story is in progress.

---

## Regression Risks

The following areas carry regression risk from Sprint 1 work. Each has a corresponding test or verification step above.

| Area | Risk | Trigger Story | Regression Test |
|------|------|---------------|-----------------|
| Existing enemy behavior | Stat scaling source changes could silently alter Normal-difficulty balance | E2-003 | `test_normal_identical_to_demo_regression` + all pre-existing EnemyController tests |
| Existing skill system | 30+ files modified for cast refactoring — any broken import chain causes compile failure | E5-002 | `test_all_106_existing_skill_tests_still_pass` |
| GameManager singleton | Adding `ActiveDifficultyProvider` property + `SetDifficultyProvider()` method touches a widely-used singleton | E2-001 | `test_game_manager_active_provider_initialized_on_awake`; full compile check with zero warnings |
| Provider caching | Consumer that caches provider at Awake will ignore mid-session provider switch (affects Hard Mode Unlock, Story 008) | E2-003 | `test_enemy_controller_does_not_cache_provider` |
| Boss spawn behavior | Boss exemption logic missing or incorrectly conditioned produces two-boss rooms on Hard | E2-004 | `test_boss_exempt_from_count_scaling` |
| Unity 6 domain reload | ScriptableObject serialization could differ from Unity LTS — float values may reset on domain reload | E2-001, E2-002 | Smoke check step: verify SO values persist after domain reload (enter/exit Play Mode) |

---

## ADR-0001 Acceptance Gate

ADR-0001 must be Accepted (not Proposed) before E2-001 implementation begins. This is an explicit sprint blocker recorded in `sprint-01.md`.

QA action: Before signing off E2-001, verify `docs/architecture/ADR-0001.md` (or equivalent path) has `Status: Accepted`. If still Proposed on Day 1, flag as a sprint blocker.

ADR-0001 Validation Criteria (from story file) to be confirmed by E2-001 unit tests:

- `CampaignDifficultyProvider` with Hard config returns `EnemyCountMultiplier == 1.25`
- `CampaignDifficultyProvider` with Hard config returns `HealDropMultiplier == 0.5`
- `CampaignDifficultyProvider` with Hard config returns `RewardMultiplier == 2.0`

These are all covered by `test_campaign_provider_returns_hard_multipliers`.

---

## Open QA Risks and Flags

### Flag 1 — E5-001 story type ambiguity

E5-001 is classified as `Logic` in the story file header but the test evidence section lists it as `Config/Data (audit output)`. The audit produces a report with no runnable code. This QA plan treats it as **Config/Data with ADVISORY gate**, consistent with the evidence type (an audit report is not a unit test). If the producer or technical director disagrees, this classification should be resolved before sprint review.

### Flag 2 — E5-002 test path conflict

Story file `002-complete-skill-implementations.md` declares test path `Assets/Trizzle/Tests/Character/Skill/`, while the sprint plan and coding standards specify `tests/unit/skills/`. QA will accept evidence from either path. Whichever path exists for the 106 existing tests should be used for new tests added by E5-002. Resolve this before writing new test files.

### Flag 3 — E2-003 story-declared type vs. evidence type

Story file declares E2-003 type as `Integration` but lists the test path as `tests/unit/difficulty/` (same as unit tests). The tests themselves verify multi-system behavior (EnemyController + GameManager + IDifficultyProvider). This QA plan classifies them as Integration tests with BLOCKING gate regardless of which directory they live in. The blocking gate applies.

### Flag 4 — ICharacterClass availability for E5-002

Story `002-complete-skill-implementations.md` notes that `ICharacterClass` "may need to be created if not yet implemented." If this interface does not exist in `Assets/Trizzle/Scripts/Character/` when E5-002 begins, the refactor scope expands. The audit (E5-001) should confirm its existence or absence. QA will flag E5-002 as partially blocked if `ICharacterClass` is missing and needs to be designed before the story can complete.

### Flag 5 — EnemyData.IsBoss field existence

Story `004-enemy-count-scaling.md` notes `IsBoss` field may need to be added to `EnemyData` and may require coordination with the Boss Phase System epic (E3). If `EnemyData.IsBoss` does not exist when E2-004 begins, the story must add it or block on E3. QA will flag `test_boss_exempt_from_count_scaling` as CANNOT VERIFY until the field exists.

---

## Pass Criteria

Sprint 1 passes QA when all of the following are true:

**BLOCKING gates (must pass):**
- [ ] E2-001: All 6 unit tests exist in `tests/unit/difficulty/` and pass in the project test runner
- [ ] E2-003: All 4 integration tests exist and pass; regression evidence file saved to `production/qa/evidence/`
- [ ] E2-004: All 7 unit tests exist and pass (applies when E2-004 is marked complete)
- [ ] E5-002: All 6 unit tests exist and pass; 106 existing skill tests pass (applies when E5-002 is marked complete)

**ADVISORY gates (must be documented):**
- [ ] E2-002: Smoke check record saved to `production/qa/evidence/smoke-e2-002-[date].md` with Inspector screenshots
- [ ] E5-001: Audit report exists at `production/epics/incomplete-skills/audit-report.md` with all three category tables populated and grep-verifiable counts

**Sprint Definition of Done (from sprint plan):**
- [ ] ADR-0001 status is `Accepted`
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1
- [ ] No S1 (crash) or S2 (gameplay-breaking) bugs in delivered features
- [ ] Normal difficulty behavior confirmed identical to current demo build (regression evidence on file)
- [ ] Design documents updated for any deviations from GDD

**If E2-004 or E5-002 do not complete in Sprint 1**: Their BLOCKING gates carry over to Sprint 2. They cannot be marked Done in any sprint without passing test evidence.
