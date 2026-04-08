# Architecture Review Report — Trizzle / Shadow Quest v1.0

| Field | Value |
|-------|-------|
| **Review Date** | 2026-04-08 |
| **Reviewer** | Technical Director (Claude) |
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **GDDs Reviewed** | 6 (E2 Difficulty, N1 Archer, E3 Boss Phases, E4 Combos, E1 Room Content, N2 Endless) |
| **ADRs Reviewed** | 7 (ADR-0001 through ADR-0007) |
| **Architecture Doc** | `docs/architecture/architecture.md` (Draft) |
| **Systems Index** | `design/gdd/systems-index.md` |
| **TR Registry** | `docs/architecture/tr-registry.yaml` (74 entries) |

---

## Verdict

**CONCERNS** — Architecture is structurally sound and the ADR set is comprehensive for a solo-developer v1.0 scope. No blocking issues prevent implementation. Three action items require resolution before first sprint stories are written to Ready.

### Action Items

| # | Action | Priority | Blocking? | Owner |
|---|--------|----------|-----------|-------|
| 1 | **Accept ADR-0001 before any other ADR** — ADR-0002, ADR-0006, and ADR-0007 all depend on `IDifficultyProvider` being stable. ADR-0001 is currently Proposed. It must reach Accepted before E2 implementation stories or any dependent ADR can be promoted. | P0 | Yes — blocks all E2 and downstream stories | TD + xiaolei |
| 2 | **Resolve SpawnManager coordination warning** — ADR-0002 step 7 says SpawnManager detects `waveNumber % 5 == 0` for Endless draft trigger, but ADR-0007 says `EndlessSessionController.WaveLoop()` calls `DraftRunController.ShowDraft()` directly at wave % 5. These are two different ownership models for the same behavior. Resolve which component owns draft trigger timing in Endless before E1/N2 stories are written. | P1 | Advisory — causes confusion during implementation if not resolved | TD |
| 3 | **BossConfig type inconsistency** — ADR-0004 defines boss data as `BossPhase` structs directly on `BossController` prefabs (no separate `BossConfig` ScriptableObject), while ADR-0006 references `RoomConfig.BossConfig` as a ScriptableObject, and ADR-0007's `EndlessWaveConfig` holds `BossConfig[5]`. The type `BossConfig` is used by ADR-0002, ADR-0006, and ADR-0007 but never formally defined with a schema. Add a one-paragraph clarification to ADR-0004 (or a new mini-ADR) specifying whether `BossConfig` is a SO asset referencing a `BossController` prefab, or the prefab itself. | P1 | Advisory — blocks E1 story authoring for boss assignment fields | TD |

---

## 1. Technical Requirements Summary

74 technical requirements were extracted from 6 GDDs and registered in `docs/architecture/tr-registry.yaml`.

| System | GDD | TR Count | Key Themes |
|--------|-----|----------|------------|
| E2 Difficulty | `difficulty-system.md` | 11 | IDifficultyProvider interface, 6 multipliers in SO, unlock gating, boss exemption, Endless independence |
| N1 Archer | `archer-character.md` | 12 | ArcherPlayerController subclass, ICharacterClass interface, DashSkill cast refactor, 7 exclusive skills, class-filtered drafts |
| E3 Boss Phases | `boss-phase-system.md` | 14 | BossController subclass, Health.OnDamaged phase checks, multi-threshold skip, stagger state, isBoss flag, 4 ability templates, IBossPhaseController |
| E4 Combos | `combo-synergy-expansion.md` | 12 | ComboEffect abstract SO, 18 effects, 4 trigger conditions via events, discoveredFlag persistence, Executioner boss immunity, Elemental Storm 5-hit cap |
| E1 Room Content | `room-content.md` | 11 | RoomConfig SO per room, 5 archetypes as enum, Normal-only authoring, wave composition per-wave, trap coverage limits, deterministic replay |
| N2 Endless | `endless-mode.md` | 14 | EndlessDifficultyConfig, 3 wave formulas, draft every 5 waves, boss cycle every 10, 30x30 arena, LevelStats persistence, no mid-run save |
| **Total** | | **74** | |

All 74 TRs are assigned stable IDs in `TR-[system]-NNN` format and are marked `status: active`.

---

## 2. Traceability Matrix Summary

Each TR was evaluated for ADR coverage: does at least one ADR's "GDD Requirements Addressed" table or Decision section directly address the requirement?

| Coverage Level | Count | Details |
|----------------|-------|---------|
| **Fully Covered** | 70 | Requirement is directly addressed by one or more ADR Decision sections, with explicit mapping in the ADR's GDD Requirements Addressed table |
| **Partially Covered** | 3 | Requirement is referenced by an ADR but implementation detail is deferred to story-level |
| **Gap** | 1 | No ADR directly addresses the requirement |

### Partially Covered Requirements

| TR ID | Requirement | ADR Reference | Gap |
|-------|-------------|---------------|-----|
| TR-archer-010 | Afterimage decoy: 1 HP, 2s duration, draws enemy aggro, destroyed by any hit | ADR-0005 lists it in skill table but defers implementation to N1 story level | Decoy aggro targeting integration with BehaviourTree (D5) not architecturally specified |
| TR-room-009 | Room clear time targets: Room 1 ~105s, Room 10 ~240s | ADR-0006 addresses room data schema but clear time is a balance/QA concern, not an architecture concern | Appropriate — balance validation, not architecture |
| TR-room-004 | Minimum arena size: 20x20 (Swarm), 30x20 (Gauntlet), 25x25 (Arena) | ADR-0006 defines RoomConfig schema but arena size is a scene-level constraint, not serialized in RoomConfig | Could add a validation field to RoomConfig if desired |

### Gap Requirement

| TR ID | Requirement | Impact | Recommended Resolution |
|-------|-------------|--------|----------------------|
| TR-boss-008 | 5 unique bosses: Stone Guardian (melee), Dark Sorcerer (ranged), Necromancer (summoner), War Chief (tank), Lich King (all-rounder) | LOW — this is a content design requirement, not an architecture decision. Each boss is a `BossController` prefab configured in the Inspector. | No ADR needed. Covered by E3 implementation stories using the BossController pattern established in ADR-0004. The architecture provides the framework; the content fills it. |

**Assessment**: The traceability coverage is strong. All architecture-level requirements are covered. The partial coverages and single gap are appropriately content-level concerns that do not need ADR treatment.

---

## 3. Cross-ADR Conflict Detection

### Blocking Conflicts: 0

No two ADRs make contradictory decisions. The dependency chain is clean and acyclic.

### Coordination Warnings: 2

#### Warning 1: Endless Draft Trigger Ownership (ADR-0002 vs ADR-0007)

**ADR-0002** (SpawnManager Mode Routing), Implementation Guideline #7:
> "SpawnManager is responsible for detecting `waveNumber % 5 == 0` in Endless mode and firing the draft event."

**ADR-0007** (Endless Mode Integration), EndlessSessionController.WaveLoop():
> `if (_waveNumber % 5 == 0): DraftRunController.Instance.ShowDraft()`

These define two different owners for the same behavior. ADR-0002 says SpawnManager owns draft trigger timing; ADR-0007 says EndlessSessionController owns it. Both are internally consistent but cannot both be correct.

**Recommended Resolution**: ADR-0007 is the later, more specific ADR and its `EndlessSessionController` pattern is better separation of concerns. SpawnManager should not own Endless session logic (this is explicitly why ADR-0007 rejected "Alternative 1: Extend SpawnManager to own Endless session logic"). Update ADR-0002 Implementation Guideline #7 to remove the draft-trigger responsibility from SpawnManager and note that Endless session coordination is delegated to `EndlessSessionController` per ADR-0007.

**Impact if unresolved**: Implementation confusion. A programmer reading ADR-0002 would add draft-trigger logic to SpawnManager; a programmer reading ADR-0007 would add it to EndlessSessionController. Both implementations would fire the draft screen.

#### Warning 2: BossConfig Type Definition Gap (ADR-0004 vs ADR-0002/0006/0007)

**ADR-0004** defines boss phase data as `BossPhase` structs serialized directly on `BossController` prefabs. It does not define a standalone `BossConfig` ScriptableObject type.

**ADR-0002** declares `IWaveProvider.GetBossConfig()` returning `BossConfig`.
**ADR-0006** declares `RoomConfig.BossConfig` as a serialized reference to a `BossConfig` type.
**ADR-0007** declares `EndlessWaveConfig.BossCycle` as `BossConfig[5]`.

The `BossConfig` type is used across three ADRs but its schema is never formally defined. From context, it likely means "a reference to a BossController prefab" — but this should be stated explicitly.

**Recommended Resolution**: Add a short section to ADR-0004 defining `BossConfig` as either:
- (a) A lightweight ScriptableObject that holds a reference to a `BossController` prefab (plus metadata like display name), or
- (b) A direct prefab reference (in which case `RoomConfig.BossConfig` is typed as `GameObject` or `BossController`).

Option (a) is recommended: it allows boss metadata (name, icon, phase count) to be inspectable without loading the full prefab, and it gives `EndlessWaveConfig.BossCycle[5]` a clean array of SO references rather than prefab references.

**Impact if unresolved**: Story authors for E1 (room boss assignment) and N2 (boss cycle) will need to guess the type, potentially creating incompatible implementations.

---

## 4. ADR Implementation Order (Topologically Sorted)

The following order respects all declared `Depends On` relationships across the 7 ADRs.

```
Phase 0 — Foundation (no dependencies)
  ADR-0001: DifficultyConfig as Interface .............. [Proposed → ACCEPT FIRST]
  ADR-0003: ComboEffect ScriptableObject Architecture .. [Proposed]
  ADR-0004: BossController Phase System ................ [Proposed]
  ADR-0005: Archer Class Extension Strategy ............ [Accepted]

Phase 1 — Depends on ADR-0001
  ADR-0002: SpawnManager Mode Routing .................. [Proposed, depends on ADR-0001]

Phase 2 — Depends on ADR-0001 + ADR-0002
  ADR-0006: Room Content Data Pipeline ................. [Proposed, depends on ADR-0001 + ADR-0002]
  ADR-0007: Endless Mode Integration ................... [Proposed, depends on ADR-0001 + ADR-0002]
```

**Notes:**
- ADR-0003, ADR-0004, and ADR-0005 have no upstream ADR dependencies and can be Accepted independently of each other and of ADR-0001.
- ADR-0005 is already Accepted. No action needed.
- ADR-0001 is the critical-path bottleneck. It must be Accepted before ADR-0002 can be promoted, and ADR-0002 must be Accepted before ADR-0006 or ADR-0007 can be promoted.
- Within a phase, ADRs can be Accepted in any order or simultaneously.

**Recommended acceptance sequence:**
1. Accept ADR-0001 (unblocks everything)
2. Accept ADR-0003 and ADR-0004 in parallel (unblocks E3 and E4 stories)
3. Accept ADR-0002 (unblocks E1 and N2 stories)
4. Accept ADR-0006 and ADR-0007 in parallel (unblocks room authoring and Endless implementation)

---

## 5. Engine Compatibility

All 7 ADRs include an Engine Compatibility section. Summary assessment:

| ADR | Knowledge Risk | Post-Cutoff APIs Used | Verdict |
|-----|---------------|----------------------|---------|
| ADR-0001 | HIGH (Unity 6 series) | None — MonoBehaviour, ScriptableObject, C# interface | CLEAN |
| ADR-0002 | HIGH (Unity 6 series) | None — MonoBehaviour, ScriptableObject, C# interface, coroutines | CLEAN |
| ADR-0003 | HIGH (Unity 6 series) | None — ScriptableObject, C# abstract class, C# events | CLEAN |
| ADR-0004 | HIGH (Unity 6 series) | None — MonoBehaviour, ScriptableObject, coroutines, serialized structs | CLEAN |
| ADR-0005 | HIGH (Unity 6 series) | None — MonoBehaviour inheritance, C# interface | CLEAN |
| ADR-0006 | HIGH (Unity 6 series) | None — ScriptableObject, SerializeField, CreateAssetMenu, List<T> | CLEAN |
| ADR-0007 | HIGH (Unity 6 series) | None — MonoBehaviour, ScriptableObject, coroutines, C# interface | CLEAN |

**Assessment**: All ADRs explicitly avoided post-cutoff Unity APIs. Every decision uses patterns stable since Unity 2019-2020 LTS (MonoBehaviour, ScriptableObject, C# interfaces, coroutines, serialized structs). The HIGH knowledge risk rating is appropriate caution given the Unity 6 engine version, but the actual risk to these specific decisions is LOW because no post-cutoff APIs are used.

**Verification items** (consolidated from all ADRs):
1. Confirm ScriptableObject serialization of concrete providers survives play-mode enter/exit in Unity 6000.3.11f1
2. Confirm `[System.Serializable]` structs with `List<T>` serialize correctly in Inspector under Unity 6000.3.11f1
3. Confirm coroutine-based timing (WaitForSeconds, WaitUntil) is not affected by new frame scheduling in Unity 6.0+
4. Confirm `[CreateAssetMenu]` workflow for nested SO types in Unity 6000.3.11f1
5. Confirm `PlayerController` base class is not sealed (required for ADR-0005 subclassing)

---

## 6. Architecture Document Coverage

The master architecture document (`docs/architecture/architecture.md`) was cross-referenced against all 7 ADRs.

| Architecture Doc Section | ADR Coverage | Status |
|--------------------------|-------------|--------|
| Section 1: Engine Knowledge Gap | All ADRs include Engine Compatibility | Covered |
| Section 2: Technical Requirements Baseline | TR Registry (62 entries) | Covered |
| Section 3: System Layer Map | ADR layer assignments match | Covered |
| Section 4: Module Ownership Map | All 6 modules have corresponding ADRs | Covered |
| Section 5: Data Flow Scenarios | 5 scenarios match ADR decision sections | Covered |
| Section 6.1: IDifficultyProvider | ADR-0001 | Covered |
| Section 6.2: IBossPhaseController | ADR-0004 | Covered |
| Section 6.3: IComboRegistry | ADR-0003 | Covered |
| Section 6.4: ICharacterClass | ADR-0005 | Covered |
| Section 7: ADR Audit | All 7 required ADRs written | Covered |
| Section 8: Architecture Principles P1-P5 | All ADRs reference principles and demonstrate compliance | Covered |
| Section 9: Cross-GDD Integration Issues | W1, W6, W7, W8, W11/W14, W12, B4 all addressed in relevant ADRs | Covered |
| Section 10: Open Questions A1-A4 | A1 resolved by ADR-0002, A2 by ADR-0004, A3 by ADR-0003, A4 by ADR-0007 | Covered |
| Appendix A: Dependency Graph | Matches ADR dependency chains | Covered |
| Appendix B: Performance Risk Register | All 5 risks addressed by corresponding ADR Performance Implications sections | Covered |

**Assessment**: Full coverage. Every section of the architecture document has corresponding ADR coverage. The architecture document and ADR set form a coherent whole.

---

## 7. ADR Quality Assessment

| ADR | Status | Alternatives | Risks | Migration | Validation | Quality |
|-----|--------|-------------|-------|-----------|------------|---------|
| ADR-0001 | Proposed | 3 considered, well-rejected | 4 risks with mitigations | 11-step incremental | 9 criteria | HIGH |
| ADR-0002 | Proposed | 3 considered, well-rejected | 5 risks with mitigations | 7-step incremental | 7+ criteria | HIGH |
| ADR-0003 | Proposed | 3 considered, well-rejected | 5 risks with mitigations | 9-step incremental | 11 criteria | HIGH |
| ADR-0004 | Proposed | 3 considered, well-rejected | 4 risks with mitigations | 6-step incremental | 11 criteria | HIGH |
| ADR-0005 | Accepted | 3 considered, well-rejected | 4 risks with mitigations | 4-story sequenced | 5 criteria | HIGH |
| ADR-0006 | Proposed | 3 considered, well-rejected | 4 risks with mitigations | 10-step incremental | 9 criteria | HIGH |
| ADR-0007 | Proposed | 3 considered, well-rejected | 5 risks with mitigations | 8-step incremental | 10 criteria | HIGH |

All ADRs follow the project template consistently. Each includes Engine Compatibility, ADR Dependencies, GDD Requirements Addressed, Performance Implications, Migration Plan, and Validation Criteria. The alternatives-considered sections provide genuine analysis of rejected approaches with clear rejection reasoning tied to architecture principles.

---

## 8. Performance Budget Compliance

| Budget Item | Source | ADR Assessment | Status |
|-------------|--------|---------------|--------|
| Frame time < 16.6ms PC | Architecture doc Appendix B | All ADRs avoid per-frame overhead; event-driven patterns throughout | Compliant |
| Frame time < 33ms mobile | N2 edge case #5 | Enemy count at wave 30 (19 enemies) flagged; existing pooling handles it | Compliant with monitoring |
| Combo overhead < 0.5ms/frame | Architecture doc Appendix B | ADR-0003: event subscription, no polling; estimated < 0.05ms/frame | Compliant |
| Boss VFX < 2ms render | Architecture doc Appendix B | ADR-0004: one-shot VFX instantiation per transition | Compliant |
| Zero GC allocation in hot paths | ADR-0001, ADR-0003 | TriggerContext is stack-allocated struct; WaveData is struct; no lambdas in OnTrigger | Compliant |

---

## 9. Risk Summary

| Risk Category | Count | Highest Impact |
|---------------|-------|---------------|
| Null reference guards | 6 across ADRs | HIGH — mitigated by Awake() defaults and Debug.Assert |
| Ordering dependencies (SetWave before Spawn) | 3 across ADRs | MEDIUM — mitigated by code comments and unit tests |
| ScriptableObject state leaks in Editor | 2 (ADR-0003, ADR-0004) | LOW — Editor-only, mitigated by Activate()/Deactivate() guards |
| Cross-ADR coordination | 2 warnings (see Section 3) | MEDIUM — resolvable by ADR amendment |
| DragonEnemyController migration debt | 1 (ADR-0004, W6) | LOW — tech debt, not blocking |

No HIGH-impact unmitigated risks exist. All identified risks have documented mitigations in their respective ADRs.

---

## 10. Recommendations

1. **Immediate**: Accept ADR-0001. This is the single highest-priority action; it unblocks the entire dependency chain.
2. **Before sprint planning**: Resolve the two coordination warnings (draft trigger ownership, BossConfig type definition) via targeted ADR amendments.
3. **During implementation**: Verify the 5 Unity 6 engine-compatibility items listed in Section 5 during the first implementation story for each ADR.
4. **Ongoing**: Use the TR Registry (`tr-registry.yaml`) as the source of truth for story-to-requirement traceability. Each implementation story should reference its TR IDs.

---

*Report generated by Technical Director agent. Next review scheduled after ADR acceptance pass.*
