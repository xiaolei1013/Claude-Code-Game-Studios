# Epic: Save/Load System

> **Layer**: Foundation
> **GDD**: `design/gdd/save-load-system.md`
> **Architecture Module**: `SaveLoadSystem` (autoload rank 2)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories save-load-system`

## Overview

Implements the project's authoritative persist/hydrate layer. Owns the 44-byte
save envelope (MAGIC + VERSION + FLAGS + PAYLOAD_LENGTH), XOR-masked UTF-8 JSON
payload, and 32-byte HMAC-SHA256 tamper seal per ADR-0004. Orchestrates
consumers via a hardcoded 6-entry `CONSUMER_PATHS` registry (Economy, HeroRoster,
FloorUnlock, FormationAssignment, Recruitment, DungeonRunOrchestrator) resolved
per-call through `get_node_or_null` — references never cached. Exposes the
heartbeat partial-envelope path that refines the full-state contract for
TickSystem-driven 60s saves (≤512 bytes), a graceful-exit full-state persist
(`NOTIFICATION_WM_CLOSE_REQUEST`), and an N=2 key rotation with immediate
re-persist on `keys[1]` fallback. All saves validate in fixed order
(MAGIC → VERSION → HMAC) with DoS-safe buffer allocation using
`file_length - 44`, not PAYLOAD_LENGTH. `_meta` namespace is owned
exclusively by this system and never read or written by consumers.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Autoload Rank Table Canonical | SaveLoadSystem is rank 2; consumers resolved per-call via `get_node_or_null` with explicit nil-check; no cached refs | LOW |
| ADR-0004: Save Envelope + HMAC Scheme | Fixed envelope layout, XOR-mask with SHA-256-derived key, from-scratch HMAC-SHA256 GDScript wrapper (7 RFC 4231 test vectors BLOCKING), multi-part key derivation with N=2 build-version rotation | **HIGH** — FileAccess `store_*` bool returns (4.4+), `HashingContext.HASH_SHA256`, GDScript HMAC from scratch |
| ADR-0005: Time System Dual-Clock Contract | `request_heartbeat_persist(time_fields: Dictionary)` partial-envelope path writes only `{t_last_persist, t_session_high_water, sim_tick_counter}` | MEDIUM — no new API risk here; coordination contract only |
| ADR-0007: Scene Transition + Persist Coupling | `scene_boundary_persist(reason)` fires before `dungeon_run_view` and after `victory_moment`; `save_failed` aborts transitions (hard-stop) with cozy "Try Again / Stay Here" modal | MEDIUM — coordination contract |
| ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema | RunSnapshot is a persist payload in the Orchestrator consumer contract; orphan-hero recovery triggers `run_snapshot_discarded_orphan` + Economy refund | MEDIUM |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-save-load-001..060`) | **60** |
| Covered by Accepted ADR | ~57 |
| Partial | ~3 |
| Gap | ~0 (minor UX/debug items routable to direct stories) |

Full per-TR detail: `docs/architecture/requirements-traceability.md` §Foundation Layer
and `docs/architecture/tr-registry.yaml` (filter by `TR-save-load-*`).

Gap items route to direct stories (UX polish + debug surfaces); no ADR work required before story authoring.

## Engine Compatibility Notes

Verify during story implementation (Godot 4.6, see `docs/engine-reference/godot/`):
- `FileAccess.store_buffer()` / `store_8()` / `store_16()` / `store_32()` return `bool` in 4.4+ — asserted per ADR-0004 Rule 22
- `HashingContext` with `HashingContext.HASH_SHA256` — verified in `docs/engine-reference/godot/current-best-practices.md`
- `DirAccess.rename()` atomicity on iOS/Android — fallback uses `.commit` marker (ADR-0004 Rule 11)
- HMAC-SHA256 GDScript implementation MUST pass all 7 RFC 4231 §4.2–4.8 test vectors bit-exactly (AC-SL-HMAC-01 BLOCKING)

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/save-load-system.md` are verified (AC-SL-01..13 + AC-SL-HMAC-01 + AC-SL-TAMPER-01..05)
- All Logic stories have passing test files in `tests/unit/save_load/`
- All Integration stories have passing test files in `tests/integration/save_load/` (round-trip, tamper detection, key rotation, heartbeat idempotency, orphan-hero recovery)
- HMAC-SHA256 implementation passes all 7 RFC 4231 test vectors (BLOCKING gate)
- Save persist time <10ms p95 PC / <50ms p95 mobile; save load <50ms PC / <100ms mobile; save file <20KB MVP
- No identifier in SaveLoadSystem or HMAC fragment autoloads contains "key"/"secret"/"hmac" (CI grep enforced)
- Visual/Feel stories (save-failed cozy modal copy) have evidence docs with sign-off in `tests/evidence/`

## Next Step

Run `/create-stories save-load-system` to break this epic into implementable stories.
