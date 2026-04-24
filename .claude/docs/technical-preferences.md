# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Forward+ (2D; Vulkan on desktop, Metal on macOS, D3D12 on Windows per 4.6 default)
- **Physics**: Godot 2D physics (Jolt is 3D-only — not applicable for this project)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam) primary; Steam Deck supported; Mobile (iOS/Android) post-launch
- **Input Methods**: Mouse (primary), Touch (mobile parity target), Keyboard (shortcuts only)
- **Primary Input**: Mouse — tap/click on roster, dungeon cards, recruit buttons
- **Gamepad Support**: None — idle game UX is click/tap-driven; Steam Deck users use the trackpad/touchscreen
- **Touch Support**: Full — every interaction must work with a single finger tap (no hover, no right-click, no drag-precision requirements)
- **Platform Notes**: No hover-only interactions. No right-click-exclusive actions. Tap targets ≥44×44 logical pixels for mobile parity. Steam Deck target: 1280×800 native, 60fps stable. Portrait-capable layouts keep mobile port cheap.

## Naming Conventions

- **Classes**: PascalCase (e.g., `HeroRoster`, `DungeonRun`)
- **Variables**: snake_case (e.g., `current_gold`, `active_formation`)
- **Signals/Events**: snake_case past tense (e.g., `hero_recruited`, `dungeon_cleared`, `offline_rewards_collected`)
- **Files**: snake_case matching class (e.g., `hero_roster.gd`, `dungeon_run.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `HeroRoster.tscn`, `DungeonRun.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_ROSTER_SIZE`, `DEFAULT_OFFLINE_CAP_HOURS`)

## Performance Budgets

<!-- Reasonable defaults for a 2D pixel-art idle game targeting PC + Mobile. -->
<!-- Revisit when hitting a real performance issue or when mobile port work begins. -->

- **Target Framerate**: 60fps on PC and mobile; idle screens may drop to 30fps when backgrounded to save battery
- **Frame Budget**: 16.6ms (60fps). Idle nature means we're never CPU-bound — the budget is almost entirely UI rendering.
- **Draw Calls**: <200 per frame (generous for 2D; real target is well under this for battery life on mobile)
- **Memory Ceiling**: 512 MB RAM on PC, 256 MB on mobile. Idle games should feel light.

## Testing

- **Framework**: GdUnit4 (CI runner already referenced in coding-standards.md as `gdunit4_runner.gd`)
- **Minimum Coverage**: 80% for balance formulas and offline-progression math (these are the project's highest-risk logic)
- **Required Tests**: Offline progression math (authoritative source of player-perceived fairness), class-vs-biome matchup resolution, save/load round-trip integrity, roster state transitions

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources — needed for HD-2D tilt-shift/lantern-lighting shader pass)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only — unlikely needed for this project)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for the HD-2D visual pass (tilt-shift depth-of-field, warm-light overlays per Visual Identity Anchor). Invoke GDExtension specialist only if native extensions become needed (not expected in MVP).

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
