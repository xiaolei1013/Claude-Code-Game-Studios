# Epic: Incomplete Skills

> **Layer**: Foundation (Layer 0)
> **GDD**: N/A -- code completion task (tracked in systems-index.md)
> **Architecture Module**: D4 Skill System -- Gameplay Layer
> **Governing ADRs**: None
> **Status**: Ready
> **Stories**: 4 stories created

## Stories

| # | Story | Type | Priority | Size | Dependencies |
|---|-------|------|----------|------|-------------|
| 001 | [Skill Code Audit](001-skill-code-audit.md) | Logic | P0 | S | None |
| 002 | [Complete Skill Implementations](002-complete-skill-implementations.md) | Logic | P0 | L | 001 |
| 003 | [Create Missing Prefabs](003-create-missing-prefabs.md) | Visual | P0 | M | 001 |
| 004 | [Skill Completion Tests](004-skill-completion-tests.md) | Logic | P0 | M | 002, 003 |

## Overview

The Incomplete Skills epic is a code-level completion task, not a full system design. The existing skill system (D4) contains 125+ skill implementations, but 15+ skills have unresolved TODOs, missing prefabs, or incomplete implementations. Specifically, skills like ArcaneRebound, IcePond, IceWall, FrostFocus, ExecutionFlow, Chain, and Multicast need TODO resolution, prefab creation, or behavior completion. This is a Layer 0 bottleneck: both the Archer Character (N1) and Combo/Synergy Expansion (E4) depend on the shared skill pool being functional. Two skills are already done; three still need prefabs (per systems-index progress tracker).

## Governing ADRs

No governing ADRs. This is a code audit and completion task that operates within the existing D4 Skill System architecture (MonoBehaviour + ScriptableObject patterns already established).

## GDD Requirements

No TR-IDs in the registry. Requirements are derived from the systems-index.md progress tracker:

| Requirement | Source | Status |
|-------------|--------|--------|
| Resolve all TODO comments in skills referenced by N1 and E4 | systems-index.md | In Progress |
| Create missing prefabs for 3 incomplete skills | systems-index.md | Not Started |
| Verify all shared skills compile and function for both Mage and (future) Archer | N1 dependency | Not Started |
| Audit E5 completion list against all 5 Mage combo skill references before E4 implementation | architecture.md W7 | Not Started |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All TODO/FIXME markers in incomplete skills resolved
- All missing prefabs created and wired
- All 125+ skills compile without errors
- Shared skills verified to not contain `MagePlayerController` casts (prerequisite for N1)
- Combo-referenced skills (E4 Mage combos) confirmed functional
- No Logic/Integration stories without passing tests

## Critical Path

```
001 Skill Code Audit (S)
 ├── 002 Complete Skill Implementations (L)  ──┐
 └── 003 Create Missing Prefabs (M)         ──┤
                                               └── 004 Skill Completion Tests (M)
```

Story 001 is the gating story -- Stories 002 and 003 can run in parallel after it completes.
Story 004 validates everything and closes the epic.
