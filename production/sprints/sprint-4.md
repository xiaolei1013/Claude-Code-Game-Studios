# Sprint 4 — 2026-06-08 to 2026-06-19

> **Generated**: 2026-04-25 by `/sprint-plan` (autonomous; solo review mode)
> **Status**: Complete (elapsed; closed by sprint-5 kickoff. Sprint plan retained for historical audit.)
> **Engine**: Godot 4.6 (pinned 2026-02-12)

## Sprint Goal

Land the **SaveLoadSystem Foundation epic core (Stories 001–004)** — autoload
skeleton + envelope binary layout + XOR mask + HMAC-SHA256 conformance — to
fill the rank-2 hole and unblock Economy's `get_save_data` / `load_save_data`
cross-system testing. Pair with deferred UX specs (S3-S1 + S3-S2 carryover) to
clear remaining Sprint 3 Should-Have backlog.

## Capacity

- Total: 10 working days × 2 effective hours/day = 20 effective hours
- Buffer (20%): 4 h reserved for unplanned work / HMAC verification fiddliness
- Available: 16 h for new stories
- Sprint 1+2+3 baseline: ~20 h delivered per sprint (compressed in solo runs)

## Tasks

### Must Have (Critical Path)

| ID | Task | Story File | Type | Est. (h) | Depends On | ADR(s) |
|----|------|-----------|------|----------|-----------|--------|
| S4-M1 | UX spec: main menu (Sprint 3 S3-S1 carryover) | `design/ux/main-menu.md` (TBA via `/ux-design main-menu`) | UI (spec) | 1.5 | None | n/a (design doc) |
| S4-M2 | UX spec: pause menu (Sprint 3 S3-S2 carryover) | `design/ux/pause-menu.md` (TBA via `/ux-design pause-menu`) | UI (spec) | 1.5 | None | n/a (design doc) |
| S4-M3 | SaveLoadSystem autoload skeleton + state machine | [`save-load-system/story-001`](../epics/save-load-system/story-001-autoload-skeleton-and-state-machine.md) | Logic | 2 | Sprint 1 (TickSystem, DataRegistry already in place at ranks 0+1) | ADR-0003, ADR-0004 |
| S4-M4 | Save envelope binary layout | [`save-load-system/story-002`](../epics/save-load-system/story-002-save-envelope-binary-layout.md) | Logic | 3 | S4-M3 | ADR-0004 |
| S4-M5 | XOR mask derivation | [`save-load-system/story-003`](../epics/save-load-system/story-003-xor-mask-derivation.md) | Logic | 2 | S4-M4 | ADR-0004 |
| S4-M6 | HMAC-SHA256 RFC 4231 conformance | [`save-load-system/story-004`](../epics/save-load-system/story-004-hmac-sha256-rfc4231-conformance.md) | Logic | 4 | S4-M5 | ADR-0004 |

**Must Have total**: 14 h. Save-load chain M3→M4→M5→M6 is sequential; UX specs (M1+M2) parallelizable.

### Should Have

| ID | Task | Story File | Type | Est. (h) | Depends On |
|----|------|-----------|------|----------|-----------|
| S4-S1 | SaveLoadSystem HMAC key derivation + rotation | [`save-load-system/story-005`](../epics/save-load-system/story-005-hmac-key-derivation-and-rotation.md) | Logic | 3 | S4-M6 |
| S4-S2 | hero-class-database `stat_at_level` helper (Sprint 2/3 carryover S2-S2 / S3-S3) | [`hero-class-database/story-004`](../epics/hero-class-database/story-004-stat-at-level-helper.md) | Logic | 2 | S2-M5 (HeroClass — done) |

**Should Have total**: 5 h

### Nice to Have (Stretch)

| ID | Task | Story File | Type | Est. (h) | Depends On |
|----|------|-----------|------|----------|-----------|
| S4-N1 | Matchup-resolver GDD revision (prototype-finding propagation) — visualize matchup multiplier as named effectiveness (Weak/Even/Strong) + per-hero glow | `design/quick-specs/matchup-visualization-revision.md` (TBA via `/quick-design`) | UI (spec) | 1.5 | None |
| S4-N2 | Dungeon-run-orchestrator GDD revision (prototype-finding propagation) — enemy representation in dungeon view | `design/quick-specs/dungeon-enemy-visualization.md` (TBA via `/quick-design`) | UI (spec) | 1.5 | None |
| S4-N3 | hero-class-database `is_class_counter` helper (Sprint 2/3 carryover S2-N1 / S3-N2) | [`hero-class-database/story-006`](../epics/hero-class-database/story-006-is-class-counter.md) | Logic | 1 | S2-M5 (HeroClass — done) |

**Nice to Have total**: 4 h

**Sprint scope**: 23 h max ceiling vs 20 h delivery target. Must Have is contractual.

## Carryover from Sprint 3

| Task | Sprint 3 Status | Reason | New Estimate |
|------|------|--------|-------------|
| S3-S1 main-menu UX spec | Should Have, NOT STARTED | Foundational for Sprint 4-5 UI work; no longer parallelizable with Vertical Slice work | 1.5 h — promoted to Sprint 4 Must |
| S3-S2 pause-menu UX spec | Should Have, NOT STARTED | Same as S3-S1 | 1.5 h — promoted to Sprint 4 Must |
| S3-S3 stat_at_level | Should Have, NOT STARTED | Helper consumed by Combat Feature epic; Sprint 5 candidate | 2 h — Should |
| S3-N1 HeroClass schema validation | Nice to Have, NOT STARTED | Content safety net | NOT in Sprint 4 — Sprint 5 candidate |
| S3-N2 is_class_counter | Nice to Have, NOT STARTED | Helper consumed by Matchup Resolver Feature epic | 1 h — Nice (stretch) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **S4-M6 HMAC-SHA256 RFC 4231 conformance** is the HIGHEST single-story risk in the project — ADR-0004 calls "HMAC from scratch" out as HIGH RISK | HIGH | HIGH | Use Godot 4.6's built-in `HashingContext` (SHA256-capable) wherever possible. RFC 4231 has documented test vectors; verify against them as part of the story's QA Test Cases. If implementation slips beyond 6h, descope S4-S1 (HMAC key rotation) into Sprint 5 rather than cutting Must Have. |
| Save-load envelope binary layout (S4-M4) is non-trivial — endianness, alignment, magic-number framing per ADR-0004 | MEDIUM | MEDIUM | Story 002's QA Test Cases include byte-exact verification fixtures. Use `PackedByteArray` operations + explicit endianness markers; verify on both desktop and Steam Deck targets. |
| Sequential save-load chain (M3→M4→M5→M6) — single-slip cascades | MEDIUM | MEDIUM | Tackle M3 + M4 in week 1 (no risk) and M5 + M6 in week 2. If M6 slips, ship Must up to M5 and roll M6 to Sprint 5 first. |
| UX specs (S4-M1, M2) require interaction-pattern decisions that may surface needs for new patterns in `interaction-patterns.md` library | LOW | LOW | Pre-existing library is initialized; spec authors append patterns as needed. Sprint 4's UX specs are foundational and unlikely to need exotic interactions. |
| Vertical Slice still missing post-Sprint-4 — gate stays FAIL | HIGH | LOW (expected) | Sprint 4 explicitly does not target the gate; closing it is Sprint 5-6 work after HeroRoster + Recruitment + Combat + Matchup + Orchestrator + Vertical-Slice harness land. |
| TD-007 (matchup placeholder) deferred until V1.0 — stays open | LOW | LOW | Park; not blocking. |

## Dependencies on External Factors

- All needed Foundation infrastructure landed in Sprint 1+2+3
- ADR-0004 (Save Envelope + HMAC Scheme) Accepted; covers S4-M3 through S4-S1
- No external blockers
- Audio system (ADR-C03 + GDD) remains BLOCKED — out of Sprint 4 scope

## Definition of Done for Sprint 4

- [ ] All Must Have stories closed via `/story-done` with passing tests
- [ ] All Logic stories have unit tests in `tests/unit/save_load_system/` (per file naming convention)
- [ ] **HMAC-SHA256 RFC 4231 test vectors** explicitly verified in S4-M6 test (use the canonical RFC 4231 test cases — 7 documented vectors)
- [ ] UX specs S4-M1 + S4-M2 pass `/ux-review` (verdict APPROVED or NEEDS REVISION accepted)
- [ ] Smoke check passes (`/smoke-check sprint`) — SaveLoadSystem registers as autoload at rank 2; DataRegistry stays in READY (TD-006 invariant preserved)
- [ ] QA sign-off APPROVED or APPROVED WITH CONDITIONS via `/team-qa sprint`
- [ ] No S1/S2 bugs in delivered features
- [ ] Sprint retrospective in `production/retrospectives/sprint-4.md`
- [ ] Cross-system: Economy's `get_save_data` / `load_save_data` (Sprint 2 Story 012 — currently blocked) becomes implementable once S4-S1 lands; document this hand-off explicitly

## What Sprint 4 deliberately does NOT include (rationale)

- **Vertical Slice playable build** — requires HeroRoster + Recruitment + Combat + Matchup Resolver + DungeonRunOrchestrator (Feature-layer epics not yet decomposed). Sprint 5-6 territory. Gate stays FAIL through Sprint 4.
- **Save-load Stories 006-015** — file I/O, atomic writes, schema migration, error recovery, perf verification. Sprint 5 dedicated continuation.
- **Scene-manager Foundation epic stories** (10 stories not yet implemented) — Sprint 5-6 candidate; UI runtime depends on scene-manager but Sprint 4 only authors UX *specs*, not runtime UI.
- **Audio system epic** — GDD + ADR-C03 unauthored; Sprint 6+ candidate.
- **Character visual profiles** for 3 MVP classes — Sprint 5-6 art-spec work.
- **`scope-check` review of Sprint 4** — clean run expected since all stories trace to existing epics; if scope creep emerges mid-sprint, run `/scope-check save-load-system`.

## QA Plan

✅ **QA Plan**: [`../qa/qa-plan-sprint-4-2026-04-25.md`](../qa/qa-plan-sprint-4-2026-04-25.md)

Type breakdown: 7 Logic + 4 UI (specs only) = 11 deliverables. ~70 new test cases projected (12 + 10 + 6 + 12 + 6 + 15 + 8 ≈ 69). RFC 4231's 7 canonical HMAC-SHA256 test vectors embedded explicitly in S4-M6's test file. Zero playtest sessions required (no playable surface yet).

Heavy automated coverage on the save-load chain. Light manual QA: 4 UX-spec sign-offs + smoke check + 1 paranoid hand-checked RFC vector for S4-M6.

## Scope Check

> If stories are added beyond the original epic scope during sprint execution
> (likely candidate: any expansion needed in `save-load-system` after the
> first few stories surface architectural friction), run
> `/scope-check save-load-system` before implementation continues.

## Reference

- Previous sprint: [`sprint-3.md`](sprint-3.md) — 8/8 Must Have closed 2026-04-25, APPROVED WITH CONDITIONS (TD-007 attached)
- Sprint 3 sign-off: [`../qa/qa-signoff-sprint-3-2026-04-25.md`](../qa/qa-signoff-sprint-3-2026-04-25.md)
- Sprint 3 smoke check: [`../qa/smoke-2026-04-25-sprint3.md`](../qa/smoke-2026-04-25-sprint3.md)
- Gate-check (post-Sprint-3, 2026-04-25): FAIL — Vertical Slice still missing; Sprint 4 doesn't target the gate
- Save-load epic: [`../epics/save-load-system/EPIC.md`](../epics/save-load-system/EPIC.md) — 15 stories (4 in Sprint 4 Must + 1 Should = 5/15 covered)
- Sprint status (machine-readable): [`../sprint-status.yaml`](../sprint-status.yaml)
