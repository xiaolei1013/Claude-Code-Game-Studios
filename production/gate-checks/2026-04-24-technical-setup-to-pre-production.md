# Gate Check — Technical Setup → Pre-Production

> **Date**: 2026-04-24
> **Target Phase**: Pre-Production
> **Current Phase**: Technical Setup
> **Review Mode**: Solo (single-developer studio)
> **Checked By**: `/gate-check` skill
> **Game**: Lantern Guild (cozy fantasy idle-clicker, Godot 4.6, GDScript)
> **Verdict**: **FAIL** — 3 blockers must be cleared before advancement

---

## Summary

Lantern Guild has strong foundational artifacts — architecture, ADRs, art bible,
engine pinning, and a passed `/architecture-review` (iteration 22g, PASS verdict)
— but three quality gates for Pre-Production are unmet: no test scaffolding
exists, no accessibility commitment is documented, and no UX pattern or HUD
specification has been started. Each blocker has a clear, bounded remediation
path (one skill invocation or one document authoring session). This report
captures the state prior to remediation so the subsequent PASS gate has an
auditable "before" snapshot.

---

## Required Artifacts

| # | Artifact | Status | Path / Notes |
|---|----------|--------|--------------|
| 1 | Engine pinned (version-locked) | ✅ | Godot 4.6 in `CLAUDE.md` + `docs/engine-reference/godot/VERSION.md` |
| 2 | Technical preferences documented | ✅ | `.claude/docs/technical-preferences.md` — populated |
| 3 | Art bible present | ✅ | `design/art/art-bible.md` — palette, typography, HUD direction, asset standards |
| 4 | ≥3 Foundation-layer ADRs | ✅ | 14 total ADRs on file (ADR-0001 through ADR-0014); 6 in Foundation layer (ADR-0003 autoload, ADR-0004 save/HMAC, ADR-0005 time, ADR-0006 data-loading, ADR-0007 scene/persist, ADR-0011 resource schemas) |
| 5 | Engine reference snapshot | ✅ | `docs/engine-reference/godot/` — VERSION.md + module notes (e.g. `modules/autoload.md`) |
| 6 | `tests/unit/` directory exists | ❌ | Directory not present |
| 7 | `tests/integration/` directory exists | ❌ | Directory not present |
| 8 | CI workflow `.github/workflows/tests.yml` | ❌ | Missing — no automated test pipeline |
| 9 | At least one example test file | ❌ | Cannot exist without (6)/(7); no GdUnit4 runner referenced |
| 10 | `architecture.md` master document | ✅ | `docs/architecture/architecture.md` — full blueprint, 22g-reviewed |
| 11 | Architecture traceability index | ⚠️ | Present as `docs/architecture/requirements-traceability.md` — skill spec expects the filename `architecture-traceability.md`. Content is complete; filename is the only divergence |
| 12 | `/architecture-review` run with verdict | ✅ | 7 iterations on file (22a–22g); 22g PASS |
| 13 | `accessibility-requirements.md` | ❌ | Not present at `design/accessibility-requirements.md` or `docs/accessibility-requirements.md` |
| 14 | `design/ux/interaction-patterns.md` | ❌ | Not present — `design/ux/` contains only `CLAUDE.md` stub |
| 15 | HUD design spec started | ❌ | No file at `design/ux/hud.md` |

**Tally**: 9/13 hard artifacts present (counting 11 as present-with-concern). 4 missing. The missing four are the three blockers (tests, accessibility, UX) plus the traceability filename Concern.

---

## Quality Checks

| Check | Status | Evidence |
|-------|--------|----------|
| ADR coverage across Foundation + Gameplay + UI layers | ✅ | 14 ADRs span autoload, save, time, data, scene, combat, economy, hero identity, replay, UI framework, resource schemas |
| Technical preferences complete (engine, language, naming, budgets, testing) | ✅ | All sections populated; routing table for engine specialists present |
| Accessibility tier committed | ❌ | No tier declared; no `accessibility-requirements.md` document exists |
| UX pattern / interaction library started | ❌ | `design/ux/` is empty of content |
| All ADRs include Engine Compatibility section | ✅ | 14/14 ADRs verified against Godot 4.6 (22g scan) |
| All ADRs reference a GDD Requirement | ✅ | 14/14 map to at least one GDD system requirement |
| All ADRs include Dependencies section (for cycle check) | ✅ | 14/14 declare upstream ADRs; 22g cross-ADR scan found no cycles |
| No deprecated Godot API usage in ADR-cited examples | ✅ | grep for `FileAccess.read_*` legacy forms, Jolt-as-2D references, pre-4.5 `@export` patterns — clean |
| Foundation-layer traceability has zero gaps | ✅ | 22g verdict: every Foundation GDD maps to ≥1 ADR, every Foundation ADR maps to ≥1 GDD |

**Tally**: 7/9 quality checks passing. The two failing checks (accessibility tier, UX patterns started) map directly to the missing artifacts.

---

## ADR Circular Dependency Check

- 14/14 ADRs declare a `Dependencies` section listing upstream ADRs they build on.
- Cross-ADR scan performed as part of architecture-review iteration 22g: no circular references detected.
- Graph is a DAG rooted at ADR-0003 (autoload) and ADR-0005 (time system) with ADR-0014 (offline replay batching) as a downstream leaf.

---

## Engine Validation

| Risk Domain | Level | Status |
|-------------|-------|--------|
| Autoload rank and boot order | HIGH | Addressed — ADR-0003 canonicalizes the rank table |
| Save serialization and HMAC | HIGH | Addressed — ADR-0004 pins envelope schema, HMAC scheme, migration path |
| Physics engine choice (Jolt→Godot-Physics-2D) | HIGH | Addressed — technical-preferences.md explicitly notes Jolt is 3D-only; 2D uses Godot's built-in physics |
| Godot 4.6 version alignment | — | All 14 ADRs target 4.6; no ADR pins an older version |
| D3D12 default on Windows (4.6 change) | LOW | Noted in VERSION.md; no ADR conflict |
| AccessKit menu coverage (4.5+) | MEDIUM | Surfaced as open question to resolve during accessibility authoring |

---

## Blockers

### Blocker 1 — Test Infrastructure Missing

**What**: No `tests/unit/` or `tests/integration/` directories, no CI workflow,
no example test file, no GdUnit4 runner scaffolding.

**Why it blocks Pre-Production**: Coding standards mandate verification-driven
development and require the CI pipeline to be a blocking gate for every PR. The
project's 80% coverage target for balance formulas and offline-progression math
cannot be tracked without the scaffold in place. Entering Pre-Production without
a test harness means stories will be written before the verification contract
they depend on exists.

**Remediation**: Run `/test-setup`. This single skill invocation creates the
directory layout, the GdUnit4 runner script, `.github/workflows/tests.yml`, and
a smoke test. Estimated time: one session.

### Blocker 2 — Accessibility Tier Not Committed

**What**: No `accessibility-requirements.md` exists. No tier is declared. No
per-feature matrix, test plan, or known-limitations list exists.

**Why it blocks Pre-Production**: ADR-0008 already locks colorblind-safe matchup
icons, a two-font-max rule, and a debug-only tap-target assertion — all of which
are accessibility features implemented without an owning document. Without a
tier commitment, future design decisions have no reference standard to adhere
to, and the project risks Pre-Production scope creep (features appearing that
demand Comprehensive-tier backfill).

**Remediation**: Author `design/accessibility-requirements.md` at Standard tier,
capturing the commitments ADR-0008 and ADR-0007 already encode and explicitly
scoping out Comprehensive/Exemplary features (screen reader in-world, full
subtitle customization, one-hand mode). Estimated time: one authoring session.

### Blocker 3 — UX Interaction Patterns and HUD Spec Missing

**What**: `design/ux/interaction-patterns.md` does not exist. `design/ux/hud.md`
does not exist. Only a stub `CLAUDE.md` lives in `design/ux/`.

**Why it blocks Pre-Production**: Pre-Production writes stories against the HUD
and its interaction contracts. Without a pattern library, every story will
re-invent button states, modal behavior, and toast rules — guaranteeing drift.
Without a HUD spec, the central gameplay screen (where the player spends most
of the session) has no information-architecture decision on record.

**Remediation**: Run `/ux-design patterns` to initialize the pattern library
with Lantern Guild's six core patterns (Primary/Secondary buttons, modal, toast,
matchup indicator, currency counter). Then run `/ux-design hud` to author the
v0.1 HUD spec covering the idle-dispatch core screen. Both can be done in a
single session; the HUD depends on the patterns existing first.

---

## Concerns (Non-Blocking)

### Concern 1 — Traceability Filename

The traceability index exists and is complete, but lives at
`docs/architecture/requirements-traceability.md` while the `/gate-check` and
`/architecture-review` skill specs reference
`docs/architecture/architecture-traceability.md`. Either rename the file or
update the skill specs to match. Not blocking — the content is authoritative —
but it creates a discoverability gap for future agent runs that glob on the
expected filename.

**Suggested resolution**: rename the file (git mv) during the next housekeeping
pass; update any inbound references in architecture.md.

---

## Chain-of-Verification

> Five independent questions, answered terse, to stress-test the verdict.

1. **Could any missing artifact be considered present under an alternate name?**
   No. `tests/` directory is absent entirely; `.github/workflows/` has no tests
   workflow; `design/accessibility-requirements.md` has no alternate at
   `docs/` or elsewhere; `design/ux/interaction-patterns.md` and `hud.md` are
   both absent.

2. **Could the accessibility commitments in ADR-0008 substitute for the
   accessibility-requirements document?** No. ADR-0008 encodes *implementation*
   decisions (colorblind icons, two-font rule, tap-target assert); the
   requirements document encodes *project-wide commitments, tier scope, and the
   test plan*. Both are needed.

3. **Does the 22g architecture-review PASS imply Pre-Production readiness?**
   No. 22g verifies architectural completeness. Pre-Production additionally
   requires test infrastructure, accessibility scope, and UX scope — none of
   which 22g evaluates.

4. **Is the filename-only divergence on the traceability file actually
   blocking?** No. Content is complete and authoritative. Treat as Concern, not
   Blocker.

5. **Could the three blockers be cleared in parallel?** Yes. `/test-setup`
   touches only `tests/` and `.github/`. Accessibility authoring touches only
   `design/accessibility-requirements.md`. UX authoring touches only
   `design/ux/`. No file conflicts.

**Verdict unchanged**: FAIL with three bounded blockers.

---

## Verdict: FAIL

**Minimum path to PASS**:

1. Run `/test-setup` → creates `tests/unit/`, `tests/integration/`,
   `.github/workflows/tests.yml`, GdUnit4 runner script, one smoke test.
2. Author `design/accessibility-requirements.md` at Standard tier (tailored
   from the template; remove sections that are N/A for a mouse+touch idle game
   with no voiced content).
3. Run `/ux-design patterns` then `/ux-design hud` → creates
   `design/ux/interaction-patterns.md` (≥1 pattern, ideally six) and
   `design/ux/hud.md` (v0.1 core-gameplay HUD spec).
4. (Concern, optional) `git mv docs/architecture/requirements-traceability.md
   docs/architecture/architecture-traceability.md` to match skill expectations.
5. Re-run `/gate-check` to confirm the transition to PASS.

---

## Suggested Next Steps

| Order | Action | Skill / Owner | Est. Effort |
|-------|--------|--------------|-------------|
| A | Scaffold test infrastructure | `/test-setup` | 1 session |
| B | Author accessibility requirements (Standard tier) | ux-designer + producer | 1 session |
| C | Author interaction pattern library + HUD v0.1 | `/ux-design patterns` then `/ux-design hud` | 1 session |
| D | (Optional) Rename traceability file to match skill spec | housekeeping | <5 min |
| E | Re-run `/gate-check` | gate-check skill | <1 session |

**Estimated elapsed time to PASS**: 2–3 focused sessions for a solo developer.

---

## Artifact Inventory (For Re-Check)

At the time of this report, the following files exist and are unchanged:

- `CLAUDE.md` (engine + standards pinned)
- `.claude/docs/technical-preferences.md`
- `.claude/docs/coordination-rules.md`
- `.claude/docs/coding-standards.md`
- `.claude/docs/context-management.md`
- `design/art/art-bible.md`
- `design/gdd/*.md` (13 system GDDs per the per-feature matrix scope)
- `design/registry/entities.yaml`
- `docs/architecture/architecture.md`
- `docs/architecture/requirements-traceability.md`
- `docs/architecture/ADR-0001-` through `ADR-0014-*.md`
- `docs/architecture/architecture-review-2026-04-22[a-g].md`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/modules/autoload.md`

Files expected to exist after remediation:

- `tests/unit/`, `tests/integration/`, `tests/gdunit4_runner.gd`, `tests/smoke_test.gd` (or equivalent)
- `.github/workflows/tests.yml`
- `design/accessibility-requirements.md`
- `design/ux/interaction-patterns.md`
- `design/ux/hud.md`

---

*End of gate check report.*
