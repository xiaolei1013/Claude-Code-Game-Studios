# Adoption Plan

> **Generated**: 2026-04-07
> **Project phase**: Production (inferred)
> **Engine**: Unity 6000.3.11f1
> **Template version**: v1.0-beta

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Step 1: Fix Blocking Gaps

### 1a. systems-index.md — parenthetical status value

**Problem**: E5 (Incomplete Skills) has status `"Code Fixed (3 need prefabs)"` which
contains parentheses. `/gate-check`, `/create-stories`, and `/architecture-review`
use exact-string matching on status values and will break.

**Fix**: Change `Code Fixed (3 need prefabs)` → `In Progress`
Move the detail to a note column or inline comment.

Also fix non-standard values in the "Already Implemented" table: `"Done"` → `"Approved"`
(closest valid equivalent for shipped systems).

**Time**: 5 min
- [ ] E5 status changed to `In Progress`
- [ ] "Done" values changed to `Approved` in Already Implemented table

---

## Step 2: Fix High-Priority Gaps

### 2a. Create game-concept.md

**Problem**: `design/gdd/game-concept.md` does not exist. Many pipeline skills
(`/map-systems`, `/brainstorm`, `/gate-check`, `/review-all-gdds`) reference
it as the game identity source.

**Fix**: Run `/brainstorm` with the existing concept to formalize it, OR manually
author a game concept doc using the existing systems-index header and Trizzle
CLAUDE.md as source material.

**Time**: 30 min (manual) or 1 session (`/brainstorm` guided)
- [ ] `design/gdd/game-concept.md` created

### 2b. Create Architecture Decision Records

**Problem**: 0 ADRs exist. The architecture pipeline (`/architecture-review`,
`/create-control-manifest`, `/create-stories`) cannot function without them.

**Fix**: Run `/create-architecture` to produce the master architecture blueprint,
then `/architecture-decision` for each key technical decision. Key candidates
from the existing codebase:
- Singleton manager pattern (46 managers)
- ScriptableObject data layer
- PC/Mobile platform separation
- Component-based architecture
- BehaviourTree AI system (NodeCanvas)

**Time**: 2-3 sessions
- [ ] `/create-architecture` run
- [ ] ADRs created for key decisions

### 2c. Bootstrap TR registry

**Problem**: `tr-registry.yaml` exists but is empty (template only). No stable
requirement IDs are registered, so stories can't reference them.

**Fix**: Run `/architecture-review` — it reads GDDs and ADRs, then populates
the TR registry with stable IDs.

**Time**: 1 session (depends on ADRs existing first — do Step 2b first)
- [ ] `tr-registry.yaml` populated with real entries

### 2d. Create control manifest

**Problem**: `docs/architecture/control-manifest.md` does not exist. Stories
embed the manifest version for staleness checking.

**Fix**: Run `/create-control-manifest` (requires ADRs to exist first).

**Time**: 30 min
- [ ] `docs/architecture/control-manifest.md` created

---

## Step 3: Bootstrap Infrastructure

### 3a. Set authoritative project stage
Run `/gate-check Production` (or appropriate phase).
**Time**: 5 min
- [ ] `production/stage.txt` written

### 3b. Create sprint tracking
Run `/sprint-plan` to create the first sprint plan and `sprint-status.yaml`.
**Time**: 30 min
- [ ] `production/sprint-status.yaml` created
- [ ] First sprint plan written

---

## Step 4: Medium-Priority Gaps

### 4a. Normalize systems-index status values

**Problem**: "Already Implemented" table uses `"Done"` which is not in the valid
status set. While these rows aren't actively processed by pipeline skills,
consistency prevents future issues.

**Fix**: Replace `Done` → `Approved` in all "Already Implemented" rows.
(This is combined with Step 1a if done at the same time.)

**Time**: 5 min (combined with Step 1a)
- [ ] All status values use valid set

---

## What to Expect from Existing Stories

No stories exist yet — this section will apply once stories are created via
`/create-stories`. Stories generated after the TR registry and control manifest
are in place will automatically include TR-IDs and manifest version stamps.

---

## Recommended Order

The dependency chain is:
1. Fix systems-index (Step 1a) — unblocks pipeline skills
2. Create game-concept.md (Step 2a) — unblocks `/review-all-gdds` and `/gate-check`
3. Create architecture + ADRs (Step 2b) — unblocks everything downstream
4. Run `/architecture-review` (Step 2c) — populates TR registry
5. Run `/create-control-manifest` (Step 2d) — creates layer rules
6. Set stage + create sprint (Step 3) — enables tracking
7. Design remaining 5 systems (E4, E1, N2, N3, E5 prefab work)
8. `/create-epics` → `/create-stories` → `/sprint-plan`

---

## Re-run

Run `/adopt` again after completing Steps 1-2 to verify all blocking and high
gaps are resolved.
