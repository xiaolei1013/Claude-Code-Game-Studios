# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.
All font choices, colors, spacing, border radii, motion easing, and component
vocabulary are defined there.

Do not deviate without explicit user approval. When the design system and the
art bible (`design/art/art-bible.md`) disagree, the art bible wins on visual
direction; DESIGN.md wins on precise tokens (specific font names, hex values,
spacing tokens). The two are designed to compose.

When implementing UI code, the canonical theme cascade is `assets/ui/parchment_theme.tres`
per ADR-0008; design tokens translate to Godot Theme overrides per DESIGN.md
§"Godot Theme implementation".

## Context Management

@.claude/docs/context-management.md
