# Epic: Combat Resolution

> **Layer**: Feature
> **GDD**: `design/gdd/combat-resolution.md`
> **Architecture Module**: `CombatResolver` (`extends RefCounted`, stateless DI service)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combat-resolution`

## Overview

Combat Resolution is the **stateless math kernel** that turns a formation
+ floor + tick-range into a deterministic stream of `KillEvent` and
`CombatTickEvents` records. It owns no run state — that lives in the
Dungeon Run Orchestrator (Feature epic) — and exposes two pure-function
entry points: `emit_events_in_range(snapshot, tick_lo, tick_hi)` for
foreground cadence and `compute_offline_batch(snapshot, batch)` for
deterministic offline replay.

Per ADR-0010, the resolver maintains parity between foreground and offline
paths — every `KillEvent` produced foreground is byte-equal to the same
event produced offline given the same inputs. The HP/speed/attack formulas
operate in integer arithmetic with `ceili()` / `floori()` (Godot 4.6
integer-returning variants) to prevent float drift.

Implements Pillar 1 (deterministic offline math) + Pillar 3 (matchup-driven
kill cadence is the load-bearing economic hook). Pillar 2's HP-as-identity
is structurally present (`hp_bonus_factor`) but **MVP-invisible by design**
— the factor saturates at 1.0 for every naturally-constructable MVP
formation; Pillar 2's mechanical payoff is V1.0-deferred (Pass 3C lock).

Per ADR-0003 Amendment #3, the resolver is **NOT** an autoload — instantiated
via lazy-default-with-public-setters DI seam (`set_combat_resolver(spy)`
BEFORE `_ready()` for tests; `DefaultCombatResolver.new()` lazy in
production).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010: Combat Resolver Snapshot + Parity | `CombatResolver extends RefCounted`; pure functions; `emit_events_in_range` + `compute_offline_batch` parity; integer arithmetic with `ceili`/`floori` | MEDIUM |
| ADR-0009: Matchup Resolver DI | Combat consumes MatchupResolver as a constructor-injected dependency; matchup `bool` flips Economy's 1.0→1.5 kill bonus | LOW |
| ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema | `CombatRunSnapshot` is the persist payload; offline batches are deterministic given snapshot + tick range | MEDIUM |
| ADR-0003 Amendment #3: Autoload `_init` Zero-Arg | Combat NOT an autoload; DI seam via `set_combat_resolver(spy)` | LOW |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-combat-001..032`) | 32 |
| Covered by Accepted ADR | ~all (ADR-0010 + ADR-0009 + ADR-0014) |
| Deferred to Orchestrator | AC-COMBAT-07b LOSING gold attribution (Orchestrator-side); AC-COMBAT-09b once-per-dispatch idempotency (Orchestrator-side) |

## Engine Compatibility Notes (Godot 4.6)

- `ceili()` / `floori()` are Godot 4.6 integer-returning variants — confirmed via `docs/engine-reference/godot/`
- `RefCounted` lifetime — never `.free()` resolver or event records
- KillEvent / CombatTickEvents / CombatBatchResult / CombatRunSnapshot ALL implement `equals()` per Pass 1 mechanical revision (unblocks AC-01 field-equality tests)
- Determinism: zero floating-point intermediate state; fixed RNG seed if any randomness is added (none in MVP)

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`
- All Combat-side ACs from `design/gdd/combat-resolution.md` verified (Orchestrator-side deferred ACs tracked in dungeon-run-orchestrator epic)
- `tests/unit/combat_resolution/` covers the 5-floor weighted-sum calibration table at line-exact integer parity
- `tests/integration/combat_resolution/` exercises foreground/offline parity: 1000-tick foreground emission == 5×200-tick offline batches == 1×1000-tick offline batch (byte-exact KillEvent stream)
- All formulas operate in integer arithmetic — no float intermediates
- Spy-subclass test pattern works for both `MatchupResolver` injection AND for parity testing

## Stories

Not yet created. Run `/create-stories combat-resolution` to author. **Note**:
Combat depends on hero-roster (`HeroInstance` records as snapshot input) and
matchup-resolver (DI dependency). Implement those first, OR stub them via
spy subclasses for parallel work.

## Next Step

`/create-stories combat-resolution`. This is the deterministic math kernel
the Vertical Slice's dungeon-run loop calls every tick.
