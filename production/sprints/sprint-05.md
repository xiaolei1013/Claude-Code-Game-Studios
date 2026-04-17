# Sprint 5 -- 2026-04-17 to 2026-05-01

## Sprint Goal

Complete Archer combos + Discovery UI, wire combo system into live game (scene-attach), and close 2 gate-check documentation gaps. Combo-synergy goes from 4/9 to 7/9.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Owner: Xiaolei (all tasks)
- Sprint 4 velocity: 4 Must Have stories / 8 est. days delivered ahead of schedule

## Tasks

### Must Have (Critical Path) -- 6.5 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| INFRA-001 | Scene-attach: ComboRegistry + ComboDiscoveryTracker | E4 Combo | 0.5 | E4-002, E4-008 (done) | Both MonoBehaviours on scene root, Inspector refs wired (_database, _comboRegistry). Combo effects fire in Play mode. Clears Sprint 4 carried conditions 1-3. |
| E4-004 | Archer Combo Effects (6) | E4 Combo | 3.5 | E4-001, E4-002 (done); soft: N1-006 (done) | 6 concrete ComboEffect SO subclasses for Archer. Unit tests pass. TR-combo-002. |
| E4-006 | Combo Discovery UI | E4 Combo | 2.0 | E4-002 (done) | Gold text flash (Cinzel font, center screen, 2s fade) + distinct SFX on discovery. TR-combo-005. |
| DD-001 | Draft design/difficulty-curve.md | Quality | 0.5 | None | Target death rate per wave, run length, win-rate bands per difficulty. Closes gate-check gap #7. |

**Must Have Total: 6.5 days** -- within 8-day capacity.

### Should Have (Start if Capacity Allows) -- 7 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E4-005 | Universal Combo Effects (7) | E4 Combo | 4.0 | E4-001, E4-002 (done) | 7 concrete Universal-combo ComboEffect SOs. Broadest effect set. |
| PT-001 | New-player experience playtest | Quality | 1.0 | -- | 1 session with someone who has never seen Trizzle; 2-min comprehension check; logged at `production/playtests/new-player-2026-04-XX.md`. Closes gate-check gap #9. |
| E3-006 | Ability Template -- Shield Phase | E3 Boss | 2.0 | E3-001 (done) | Sprint 3 Should-Have carryover. Unblocks E3-008 (boss prefabs). |

### Nice to Have (Defer to Sprint 6) -- 6+ days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E4-007 | ComboDatabase Population | E4 Combo | 2.0 | E4-003, E4-004, E4-005 | All 18 ComboDefinition entries authored in ComboDatabase.asset. Requires all 3 effect sets done. |
| E3-007 | Ability Template -- Rain of Fire | E3 Boss | 2.0 | E3-001 (done) | Sprint 3 Nice-to-Have carryover. Unblocks E3-008. |
| E3-008 | Boss Prefab Configuration | E3 Boss | 2.0 | E3-001, abilities done | Production boss prefabs with phase configs. Unblocks E3-004 Ground Slam playtest (Sprint 3 carry). |
| E4-009 | Combo System Tests | E4 Combo | 2.0 | E4-001-005, E4-007 | Full integration suite: discovery, activation, deactivation across run boundaries, boss-immune executioner, 5-hit elemental storm. |

## Carryover from Sprint 4

| Task | Reason | New Estimate / Disposition |
|------|--------|---------------------------|
| Scene-attach (PR #118) | Infrastructure task deferred during E4-003/008 | Now INFRA-001, Must Have in Sprint 5 (0.5 days) |
| E4-003 AoE playtest | Gated on scene-attach | Auto-resolves when INFRA-001 done; verify in Sprint 5 |
| E4-008 live quit/reload | Gated on scene-attach | Auto-resolves when INFRA-001 done; verify in Sprint 5 |
| E3-004 Ground Slam playtest | Sprint 3 carry, gated on E3-008 (boss prefab config) | Still deferred -- E3-008 is Nice to Have this sprint |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Archer combo effects expose API gaps (same as E4-003 pattern) | MEDIUM | MEDIUM | E4-003 established the pattern -- 6 archer effects follow same base class. ADR-0003 Amendment covers API reality. |
| Scene-attach triggers unexpected bugs in live Play mode | MEDIUM | LOW | Combo effects are unit-tested in isolation. Scene-attach is a wiring task, not new logic. |
| E4-005 Universal combos don't fit in capacity | HIGH | LOW | Scoped as Should Have -- clean deferral to Sprint 6 if not pulled. |
| PT-001 requires scheduling external playtester | MEDIUM | LOW | Start recruiting this week. Even informal testing counts. |
| Combo Discovery UI font/SFX assets missing | LOW | MEDIUM | Check Cinzel font import and SFX library before starting E4-006. |

## Dependencies on External Factors

- INFRA-001 requires Unity Editor open with the game scene loaded (scene-level work, not code-only)
- PT-001 needs a real person unfamiliar with the game -- schedule this week
- E4-006 depends on Cinzel font asset imported in Unity + a discovery SFX clip authored or sourced

## Sprint Schedule (Recommended Execution Order)

```
Day 1:    INFRA-001 (scene-attach) + DD-001 (difficulty curve doc) -- quick wins, unblock carried conditions
Day 2-4:  E4-004 (Archer Combo Effects) -- biggest Must Have, 6 effects
Day 5-6:  E4-006 (Combo Discovery UI) -- user-facing combo feedback
Day 7-8:  Buffer / E4-005 Universal Combos or PT-001 playtest
Day 9-10: Buffer / E3-006 Shield Phase
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and verified
- [ ] Scene-attach verified: combos fire in Play mode + discovery persists across quit/reload
- [ ] Archer combo effects have passing unit tests
- [ ] Discovery UI flash visible on combo discovery in Play mode
- [ ] `design/difficulty-curve.md` exists with target curves
- [ ] QA plan exists (`production/qa/qa-plan-sprint-05.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## Notes

- **Gate-check alignment**: This sprint targets combo-synergy 4/9 -> 7/9 per gate-check 2026-04-16 minimal path. 2 remaining combo stories (E4-007, E4-009) carry to Sprint 6.
- **Carried condition resolution**: INFRA-001 on Day 1 unblocks the 3 Sprint 4 carried conditions (scene-attach, AoE playtest, live quit/reload). Verify all 3 immediately after wiring.
- **Scope check**: Run `/scope-check combo-synergy` before starting E4-004.
- **E3-004 Ground Slam**: Still deferred pending E3-008 (Nice to Have). No change from Sprint 4.
