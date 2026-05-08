# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.6 |
| **Release Date** | January 2026 |
| **Project Pinned** | 2026-02-12 |
| **Last Docs Verified** | 2026-02-12 |
| **Last Empirical Validation** | 2026-05-08 (1633-test suite passes against the in-use API surface; no engine-API failures across 13 epics + 64 implemented stories) |
| **LLM Knowledge Cutoff** | May 2025 |

> **Empirical-validation note (2026-05-08)**: this VERSION.md's "Last Docs Verified" field still reads 2026-02-12 because no formal docs re-verification pass has run. However, the project has shipped 1633 unit + integration tests against Godot 4.6 with 0 API-related failures, and the lint hygiene cycle (commits `f826643` → `df890da`, 2026-05-08) brought the GDScript-linter "warning surface" to zero. This is empirical evidence that the in-use API surface (autoloads, signals, typed dicts, `@warning_ignore` annotations, `@onready`, `class_name` orthogonal-to-autoload-name, `_compose_header`-style PackedByteArray work, HMAC/SHA256 via HashingContext, FileAccess return types) matches the version-pinned reference docs for the surfaces this project exercises. A full docs re-verification pass would still be needed before a major-version bump or before adopting net-new 4.6 APIs not yet exercised.

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4, 4.5,
and 4.6 introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/4.6/
