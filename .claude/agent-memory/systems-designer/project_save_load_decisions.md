---
name: Save/Load System Design Decisions
description: Locked design choices for GDD #3 — format, anti-tamper scope, fallback policy, state machine, and security-engineer boundary
type: project
---

**File**: `design/gdd/save-load-system.md` — Sections C/D/E/G written 2026-04-19. Sections A/B/F/H pending.

**Locked choices**:
- Binary envelope: 32-byte header ("LGLD" magic + version uint16 + slot uint8) + JSON payload + 32-byte HMAC-SHA256 footer
- JSON payload (not Godot binary Resource) — debuggable, diffable, no ResourceLoader re-entanglement
- Atomic write: write-temp → flush → rename; iOS/Android needs copy-then-delete fallback (no atomic rename)
- Serialization contract: all consumers expose `save_to_dict() -> Dictionary` and `load_from_dict(data: Dictionary) -> void`
- Single save slot MVP (`user://save_slot_1.dat` + `.dat.bak`); multi-slot via `save_slot_path(slot)` helper
- Failure policy: try `.bak`, then fresh start with modal (never silent new-game)
- Anti-tamper: security-engineer owns HMAC key/derivation; this GDD only calls the module as a black box
- `flag_suspicious_timestamp` escalation: MVP = warn-only toast (not save-lock); revisit V1.0 based on telemetry
- Data Loading ERROR on launch → immediately CORRUPT state (do not load with null references)
- `future_version_save_policy` default: `REFUSE_AND_ALERT` (not best-effort)
- `corruption_fallback_policy` default: `TRY_BAK_THEN_NEW`

**State machine**: UNLOADED → LOADING → READY ↔ PERSISTING; LOADING → CORRUPT; LOADING → MIGRATION → READY

**Why**: Save corruption = maximum Pillar 1 violation. Every design choice above exists to ensure the player either gets their save or gets a clear explanation. Silent data loss is the only unacceptable outcome.

**How to apply**: When authoring dependent GDDs (Economy, Hero Roster, Floor Unlock), always include `save_to_dict()` / `load_from_dict()` in their serialization contracts. Never let a consumer own its own persistence path.
