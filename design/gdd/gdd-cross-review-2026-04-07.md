# Cross-GDD Review Report

**Date**: 2026-04-07
**GDDs Reviewed**: 6 system GDDs + game-concept + systems-index
**Systems Covered**: E2 Difficulty, N1 Archer, E3 Boss Phases, E4 Combos, E1 Room Content, N2 Endless
**Verdict**: FAIL → PASS (after blocking fixes applied)

---

## Consistency Issues

### Blocking (resolved)

B1 — **Endless boss phases** (E3, N2): N2 hardcoded all bosses as 2-phase. E3 defines 3-phase for rooms 6-10. **Fix**: N2 updated — Endless bosses are always 2-phase (simpler for survival mode). Noted in N2 edge cases.

B2 — **SpawnManager pacing ownership** (E2, N2): Both define pacing multipliers with no interface boundary. **Fix**: Both GDDs updated with explicit config routing note.

B3 — **Endless 3.0x stat scaling unvalidated** (N2): No player DPS output range defined at wave 50. **Fix**: Kill-time validation note added to N2 Formulas.

### Warnings

W1 — Dependency direction inverted between N1 and E4
W2 — E3 uses hedging language ("may") for N2 dependency; N2 treats it as hard
W3 — E1 places E4 in Upstream table; correct direction is E4 → E1
W4 — E1 waveCount formula gives 7 for Room 10; table says 6
W5 — Trap-kill OnKill exclusion rule authored in E1, should be in E4
W6 — E3 references DragonEnemyController; no Dragon in any other GDD
W7 — E4 Mage combo skills not validated against E5 completion list
W8 — N1 Archer DPS formula ignores enemy Defense scaling from E2
W9 — 20% clear-time parity AC exists for Normal only; Hard parity untested
W10 — Phase transition wipes poison stacks — undocumented intent
W11 — Archer combat attention budget hits 6 on Hard
W12 — Hard 2x rewards + missing gem sink definition
W13 — Room 10 Hard combined pressure is super-linear; needs playtest milestone

---

## Game Design Issues

### Blocking (resolved)

B4 — **Elemental Storm degenerate combo** (E4): Burn + Freeze = permanent +30% all damage with no cap. **Fix**: E4 updated — 5-hit application limit per trigger.

B5 — **Session length vs Pillar 3** (E1, game-concept): Full Hard run = 50-60 min, conflicts with "15-30 min sessions" pillar. **Fix**: game-concept.md clarified — pillar applies to individual rooms, not full campaign runs.

### Warnings

W14 — Archer attention budget reaches 5-6 concurrent active systems on Hard
W15 — Phase transition wipes poison stacks — intentionality unclear
W16 — Hard 2x rewards may create dominant farming strategy without defined gem sink
W17 — Room 10 Hard combined pressure needs explicit playtest gate

### Info

I1 — Two progression loops (draft + unlock) are well-delineated, no competition
I2 — Wave count formula off-by-one for Room 10 (formula: 7, table: 6)
I3 — Combo flash vs draft panel Z-order undefined
I4 — discoveredFlag sets precedent for cross-run accumulation

---

## Cross-System Scenario Issues

### Scenario 1: Elite kill + combo activation + draft

Systems: D1 Combat + E4 Combos + D7 Draft
Finding (INFO): Combo flash (2s) could overlap draft panel UI. No Z-order rule defined.

### Scenario 2: Boss phase transition with active status effects

Systems: E3 Boss + D3 Status Effects + E4 Combos
Finding (WARNING): Stagger clears all debuffs including Poison stacks from Venom/Plague Volley combos. Significant DPS loss for poison builds. Intent undocumented.

### Scenario 3: Endless wave 25 with stacked combos

Systems: N2 Endless + E4 Combos + N1 Archer
Finding (WARNING): Quickdraw + Counter Roll + Rapid Assault creates ~18x DPS window post-dodge. Performance concern with 16+ poisoned enemies on mobile. Kill-time at 2.0x stats needs numerical validation.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| All 5 blocking GDDs | Fixes applied inline | Consistency + Design | Resolved |
| E1 room-content.md | waveCount formula off-by-one | Consistency | Low |
| E4 combo-synergy.md | Trap-kill OnKill rule should be authored here | Consistency | Low |
| E3 boss-phase.md | DragonEnemyController reference may be stale | Consistency | Low |
