# Story 007: Economy + Combat consumer wiring

> **Epic**: matchup-resolver
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md` + `design/gdd/economy.md` + `design/gdd/combat-resolution.md`
**Requirements**: TR-matchup-resolver-027, 028

**Governing ADR**: ADR-0009 + ADR-0010 (Combat Resolver Snapshot) + ADR-0013 (Economy single-source-of-truth)
**Decision Summary**: Economy applies `MATCHUP_GOLD_MULTIPLIER = 1.5` (from `economy_config.tres`) to `kill_bonus` when `is_matchup_advantaged == true`. Combat Resolution scales per-enemy throughput via `MATCHUP_THROUGHPUT_FACTOR_ADV` (boost) and `MATCHUP_THROUGHPUT_FACTOR_DIS` (decay) using the resolver's `is_advantaged`. The resolver itself knows zero gold values; coupling lives in the consumers.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `MATCHUP_GOLD_MULTIPLIER` lives ONLY in `economy_config.tres` and is read by Economy. Resolver source grep returns zero hits for the constant. — TR-027
- Required: `MATCHUP_THROUGHPUT_FACTOR_ADV` / `MATCHUP_THROUGHPUT_FACTOR_DIS` live ONLY in combat config. — TR-028
- Required: Economy's per-kill bonus formula reads `is_matchup_advantaged` from the orchestrator's signal payload, NOT from a direct resolver call. — TR-027

---

## Acceptance Criteria

- [ ] TR-027: Economy's `enemy_killed` signal handler applies `MATCHUP_GOLD_MULTIPLIER` when `is_matchup_advantaged == true`. Source grep on `matchup_resolver/` files for `MATCHUP_GOLD_MULTIPLIER` → zero hits.
- [ ] TR-027: Boundary test — bonus on advantaged kill > bonus on neutral kill by exactly the multiplier ratio (1.5×).
- [ ] TR-028: Combat Resolution applies `MATCHUP_THROUGHPUT_FACTOR_ADV` to enemy DPS reduction when advantaged; `MATCHUP_THROUGHPUT_FACTOR_DIS` (penalty) when not.
- [ ] TR-028: Source grep on `matchup_resolver/` files for `MATCHUP_THROUGHPUT_FACTOR_*` → zero hits.

---

## Implementation Notes

This is a multi-system integration story. The actual code changes land in:
- **Economy** (`src/core/economy/economy.gd`): consume `enemy_killed` signal from orchestrator; apply `MATCHUP_GOLD_MULTIPLIER` from `_config`. (Cross-epic — flag for economy backlog.)
- **Combat Resolution** (`src/gameplay/combat/`): scale per-enemy DPS by the throughput factor. (Cross-epic — flag for combat-resolution backlog.)

The matchup-resolver epic itself adds NO code for this story — it adds tests that verify the consumer-side wiring satisfies the resolver's contract.

```gdscript
# tests/integration/matchup_resolver/economy_consumer_test.gd
func test_advantaged_kill_yields_1_5x_gold_bonus() -> void:
    var pre_gold := Economy.get_gold()
    DungeonRunOrchestrator.enemy_killed.emit(1, false)  # neutral
    var neutral_delta := Economy.get_gold() - pre_gold
    var pre := Economy.get_gold()
    DungeonRunOrchestrator.enemy_killed.emit(1, true)  # advantaged
    var advantaged_delta := Economy.get_gold() - pre
    assert_int(advantaged_delta).is_equal(int(neutral_delta * 1.5))
```

---

## Out of Scope

- The actual Economy.gold-bonus code change (lives in economy epic).
- The actual Combat throughput-factor code change (lives in combat-resolution epic).
- This story tracks the cross-epic coordination — Sprint 7+ will wire it.

---

## QA Test Cases

- **TR-027 multiplier ratio**: advantaged kill gold delta == neutral kill gold delta × 1.5
- **TR-027 resolver-doesn't-know-gold**: source grep `src/core/matchup_resolver/` for `MATCHUP_GOLD_MULTIPLIER` → 0 hits
- **TR-028 throughput delta**: combat per-enemy DPS reduction with `is_advantaged=true` > reduction with `is_advantaged=false`
- **TR-028 resolver-doesn't-know-throughput**: source grep `src/core/matchup_resolver/` for `MATCHUP_THROUGHPUT_FACTOR` → 0 hits

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/matchup_resolver/economy_and_combat_consumer_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002-006 (resolver + integration); economy epic (consumer wiring); combat-resolution epic (consumer wiring)
- Unlocks: Vertical Slice gold-flow validation
