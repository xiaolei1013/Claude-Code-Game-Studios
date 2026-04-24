# Epic: Tick System

> **Layer**: Foundation
> **GDD**: `design/gdd/game-time-and-tick.md`
> **Architecture Module**: `TickSystem` (autoload rank 0)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: 11 defined (all Ready)

## Overview

Implements the authoritative dual-clock subsystem for Lantern Guild per
ADR-0005: an integer-accumulator Sim Clock that emits `tick_fired` at
20 Hz (`TICKS_PER_SECOND = 20`, `_TICK_INTERVAL_SECONDS = 0.05`) synchronously
inside `_process(delta)`, and a Wall Clock read from
`int(Time.get_unix_time_from_system())` at exactly one call site (the
TickSystem boundary). Foreground-only emission — freezes on background entry
via `NOTIFICATION_APPLICATION_PAUSED`/`RESUMED` (mobile) and
`NOTIFICATION_WM_WINDOW_FOCUS_OUT`/`IN` (desktop), preserving accumulator
residual across pause. Emits `offline_elapsed_seconds(seconds, cap_reached)`
exactly once per cold launch (in-process flag, never re-fires on BG↔FG
cycles). Provides `flag_suspicious_timestamp_emitted(prev_ts, curr_ts)` for
tamper detection on backwards time jumps. Debug-only methods
(`debug_set_unix_time`, `debug_clear_unix_time`) runtime-gate on
`OS.is_debug_build()`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Autoload Rank Table Canonical | TickSystem is rank 0 (first autoload); signal subscription across ranks at `_ready()` is safe per Claim 1 [VERIFIED]; state reads at `_ready()` restricted to M < N | LOW |
| ADR-0005: Time System Dual-Clock Contract | `tick_fired` synchronous emission (never `call_deferred`, never via `Timer`); integer accumulator with residual preservation; one-shot `offline_elapsed_seconds`; wall clock read at single call site; heartbeat partial-envelope path | **MEDIUM** — `NOTIFICATION_APPLICATION_PAUSED`/`RESUMED`, `NOTIFICATION_WM_WINDOW_FOCUS_*`, `NOTIFICATION_WM_CLOSE_REQUEST`, `Time.get_unix_time_from_system` (all verified in `current-best-practices.md`) |
| ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema | Offline replay path bypasses `tick_fired` — OfflineProgressionEngine calls `consumer.compute_offline_batch(n)` directly; `tick_fired` never emits during replay (CI enforcement) | LOW |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-time-001..036`) | **36** |
| Covered by Accepted ADR | ~35 |
| Partial | ~1 |
| Gap | 0 (AC-TICK-10 dual-budget clarification landed via Pass-ADR-0014-SYNC) |

Full per-TR detail: `docs/architecture/requirements-traceability.md` §Foundation Layer and `docs/architecture/tr-registry.yaml` (filter by `TR-time-*`).

## Engine Compatibility Notes

Verify during story implementation (Godot 4.6):
- `Time.get_unix_time_from_system()` returns float seconds — cast to int64 exactly once at TickSystem boundary
- Platform-notification coverage for BG/FG transitions is desktop + mobile only; Steam Deck inherits desktop path
- `_process(delta)` synchronous emission — no Godot `Timer` node (drift risk); no `call_deferred` on `tick_fired` (ordering invariant)
- `flag_suspicious_timestamp_emitted` fires once per launch on the session-scoped private bool's false→true transition — distinct from the public signal

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-time-and-tick.md` are verified (AC-TICK-01..11)
- All Logic stories have passing test files in `tests/unit/tick_system/` (accumulator residual preservation, tick-count determinism, backwards-time-jump flag)
- All Integration stories have passing test files in `tests/integration/tick_system/` (BG/FG cycle, heartbeat partial-envelope request, `offline_elapsed_seconds` one-shot invariant)
- Per-tick dispatch budget <1ms PC / <5ms mobile (AC-TICK-09 ADVISORY)
- Offline replay 576k-tick worst case completes <500ms on min-spec mobile (AC-TICK-10 BLOCKING)
- Heartbeat envelope size ≤512 bytes (AC-TICK-11 BLOCKING)
- `tick_fired` never emits during offline replay (CI grep assertion per ADR-0005)
- No `Time.get_unix_time_from_system()` calls outside TickSystem (CI grep per ADR-0005)

## Stories

| # | Story | Type | Status | Governing ADR |
|---|---|---|---|---|
| 001 | TickSystem autoload skeleton | Logic | Ready | ADR-0005 (+ ADR-0003) |
| 002 | Integer accumulator and `tick_fired` synchronous emission | Logic | Ready | ADR-0005 |
| 003 | `_process(delta)` forbidden-as-economy-input and wall-clock single call site | Logic | Ready | ADR-0005 |
| 004 | Platform BG/FG notifications and tick-emission pause with residual preservation | Integration | Ready | ADR-0005 |
| 005 | First-launch bootstrap and `offline_elapsed_seconds` one-shot emission | Integration | Ready | ADR-0005 |
| 006 | Formula D.2 — offline elapsed + forward clamp + rewind tolerance + int64 overflow | Logic | Ready | ADR-0005 |
| 007 | Suspicious-timestamp flag + signal emission + log string | Logic | Ready | ADR-0005 |
| 008 | Heartbeat persist coupling + Save/Load writer surface | Integration | Ready | ADR-0005 (+ ADR-0004) |
| 009 | Offline replay coordination — `tick_fired` suppression + signal ordering invariant | Integration | Ready | ADR-0005, ADR-0014 |
| 010 | Debug-only mock clock + `debug_emit_suspicious_timestamp` + runtime gate | Logic | Ready | ADR-0005 |
| 011 | Performance verification — per-tick dispatch + offline replay budget + heartbeat envelope size | Integration (Performance) | Ready | ADR-0005 (+ ADR-0014) |

**Dependency chain**: 001 → 002 → {003, 004} → {005 via 003, 008 via 004} → {006 via 005, 009 via 005} → 007 → 010 → 011. Stories 003 and 004 are parallelizable once 002 is done.

## Next Step

Run `/create-stories tick-system` to break this epic into implementable stories.
