# Sprint 4 -- 2026-04-15 to 2026-04-29

## Sprint Goal

Lay the combo-synergy foundation (ComboDefinition schema, ComboEffect base class, Mage combo set) and persist discovery -- unblocking concrete effect work in Sprint 5 while beginning to close the Polish-gate playtest gap.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Owner: Xiaolei (all tasks)
- Sprint 3 velocity: 4 Must Have stories / 9 est. days delivered ahead of schedule

## Tasks

### Must Have (Critical Path) -- 8 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E4-001 | Extend ComboDefinition | E4 Combo | 2.0 | None | ComboDefinition adds comboCategory, triggerCondition, triggerEffect SO ref, discoveredFlag fields. Existing 5 Mage pairs migrate cleanly. TR-combo-012, ADR-0003 compliant. |
| E4-002 | ComboEffect Base Class | E4 Combo | 2.0 | E4-001 | Abstract ScriptableObject with Activate(PlayerController), Deactivate(), OnTrigger(TriggerContext). TriggerContext is a readonly struct (zero heap). Unit tests pass. TR-combo-001, TR-combo-003, TR-combo-011, ADR-0003 compliant. |
| E4-003 | Mage Combo Effects (5) | E4 Combo | 3.0 | E4-001, E4-002 | 5 concrete ComboEffect SO subclasses: Burn/Freeze triggers Elemental Storm (5-hit cap), Executioner (boss-immune), etc. Unit tests pass. TR-combo-002, TR-combo-008, TR-combo-009. |
| E4-008 | Discovery Persistence | E4 Combo | 1.0 | E4-002 | discoveredFlag persists per-combo in save data; survives run end / game restart. TR-combo-006, TR-combo-007 compliant. |

**Must Have Total: 8 days** -- on capacity.

### Should Have (Start if Capacity Allows) -- 6.5 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E4-004 | Archer Combo Effects (6) | E4 Combo | 3.5 | E4-001, E4-002; soft: N1-006 (done) | 6 concrete Archer-combo ComboEffect SOs. Reuses OnSkillUse / OnKill triggers. Unit tests pass. |
| E4-006 | Combo Discovery UI | E4 Combo | 2.0 | E4-002 | Gold text flash (Cinzel, center, 2s fade) + distinct SFX on discovery. Off critical path, parallelizable. TR-combo-005. |
| PT-001 | New-player experience playtest | Quality | 1.0 | -- | 1 session with someone who has never seen Trizzle; 2-min comprehension check; logged at `production/playtests/new-player-2026-04-XX.md`. Closes Gate-check gap #9. |
| DD-001 | Draft `design/difficulty-curve.md` | Quality | 0.5 | -- | Minimal doc: target death rate per wave, run length, win-rate bands. Closes Gate-check gap #7. |

### Nice to Have (Defer to Sprint 5) -- 12+ days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E4-005 | Universal Combo Effects (7) | E4 Combo | 4.0 | E4-001, E4-002; soft: E3 | 7 concrete Universal-combo ComboEffect SOs. Broadest effect set. |
| E4-007 | ComboDatabase Population | E4 Combo | 2.0 | E4-003, E4-004, E4-005 | All 18 ComboDefinition entries authored in ComboDatabase.asset. |
| E4-009 | Combo System Tests | E4 Combo | 2.0 | E4-001--005, 007 | Integration suite: discovery, activation, deactivation across run boundaries, boss-immune executioner, 5-hit elemental storm. |
| E3-006 | Ability -- Shield Phase | E3 Boss | 2.0 | E3-001 (done) | Sprint 3 Should-Have carryover. Unblocks E3-008 (boss prefabs). |
| E3-007 | Ability -- Rain of Fire | E3 Boss | 2.0 | E3-001 (done) | Sprint 3 Should-Have carryover. Unblocks E3-008. |

## Carryover from Sprint 3

| Task | Reason | New Estimate / Disposition |
|------|--------|---------------------------|
| E3-004 Ground Slam manual playtest | Blocked on E3-008 (no production boss prefab exists yet) | Tracked as condition on Sprint 3 sign-off; remains deferred this sprint |
| E3-006 Shield Phase | Should-Have not pulled in Sprint 3 | Nice-to-Have Sprint 4 |
| E3-007 Rain of Fire | Should-Have not pulled in Sprint 3 | Nice-to-Have Sprint 4 |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ComboDefinition migration breaks existing 5 Mage pairs | MEDIUM | MEDIUM | E4-001 includes migration test -- verify old pairs load before touching ComboRegistry. Add golden-data fixture. |
| E4-003 exposes PlayerController API gaps for combo activation | MEDIUM | MEDIUM | First concrete implementation is the smoke test. If gaps found, scope a small API-extension substory rather than inflating E4-003. |
| ADR-0003 status not Accepted | LOW | HIGH | Verify before sprint start. If Proposed, run `/architecture-decision` first. |
| Playtest finds fundamental readability problem mid-sprint | LOW | HIGH | Note and park -- don't derail combo work. Defer remediation to Sprint 5 scoping. |
| Performance budget violated once all 18 effects active | LOW | MEDIUM | E4-002 includes a microbench; re-run after E4-003 to catch early. ADR-0003 estimates < 0.05ms. |

## Dependencies on External Factors

- ADR-0003 must be **Accepted** before E4-001 starts (verify in repo)
- E4-003 depends on PlayerController status effect API (Burn, Freeze) -- already shipped in Sprint 1
- PT-001 needs a real person unfamiliar with the game -- schedule this week

## Sprint Schedule (Recommended Execution Order)

```
Day 1-2:  E4-001 (Extend ComboDefinition) -- foundation
Day 3-4:  E4-002 (ComboEffect Base Class) -- foundation
Day 5-7:  E4-003 (Mage Combo Effects) -- first concrete set, smoke-tests the base class
Day 8:    E4-008 (Discovery Persistence) -- off-critical-path quick win
Day 9-10: Buffer / E4-004 Archer Combos or PT-001 playtest
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and verified
- [ ] ComboEffect base class + Mage effects have passing unit tests
- [ ] Existing 5 Mage combo pairs still load after ComboDefinition migration
- [ ] Discovery persists across run end and game restart
- [ ] QA plan exists (`production/qa/qa-plan-sprint-04.md`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS
- [ ] No S1 or S2 bugs in delivered features
- [ ] ADR-0003 validation criteria all passing
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## Notes

- **Gate-check alignment**: This sprint begins the combo-synergy epic (0/9 -> 4/9 minimum) per `/gate-check 2026-04-14` recommendation. Three sprints at this pace should close the epic.
- **Scope check**: Run `/scope-check combo-synergy` before starting E4-001.
- **Sprint 3 condition**: E3-004 Ground Slam manual playtest remains deferred pending E3-008 (boss prefabs). No change this sprint.
