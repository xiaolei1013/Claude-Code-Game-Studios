# Lantern Guild — RC Build Pipeline

Sprint 19 S19-M5 scaffold. Wraps Godot's headless export against `export_presets.cfg` to produce per-platform binary artifacts.

## Quick start

```bash
# Default (Linux Steam Deck target):
tools/build/build.sh

# Explicit target:
tools/build/build.sh linux
tools/build/build.sh windows
tools/build/build.sh macos
tools/build/build.sh all
```

Artifacts land under `build/<platform>/`.

## Prerequisites

### 1. Godot 4.6+ Mono binary

The build script uses `GODOT_BIN` (defaults to `/Applications/Godot_mono.app/Contents/MacOS/Godot`). Override per-invocation:

```bash
GODOT_BIN=/opt/godot/godot_v4.6.1-stable_mono_linux.x86_64 tools/build/build.sh linux
```

Project pinned to **Godot 4.6.1.stable.mono.official** per `docs/engine-reference/godot/VERSION.md`.

### 2. Export templates installed

This is the most common omission. The script will fail at the export step if templates aren't present.

**To install:**

1. Open the project in the Godot editor.
2. `Editor → Manage Export Templates…`
3. Click `Download and Install`.
4. Verify `~/Library/Application Support/Godot/export_templates/4.6.1.stable.mono/` (macOS) or platform equivalent now contains `linux_release.x86_64`, `windows_release_x86_64.exe`, etc.

The `.tpz` archive can also be hand-installed from https://godotengine.org/download/.

### 3. Build directory writable

The script creates `build/<platform>/` directories at the repo root. Ensure the working tree is clean enough that `build/` doesn't shadow tracked files. The `.gitignore` already excludes `build/`.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `GODOT_BIN` | `/Applications/Godot_mono.app/Contents/MacOS/Godot` | Path to Godot binary. |
| `BUILD_MODE` | `release` | `release` or `debug`. Debug builds keep stack traces and the editor console; release builds strip both. |

## Per-platform notes

### Linux (Steam Deck primary target)

- Architecture: `x86_64`
- Texture format: `s3tc_bptc=true` (Steam Deck supports BPTC; ETC2/ASTC is mobile-only).
- Output: `build/linux/lantern_guild_steamdeck.x86_64`
- Recommended verification: copy artifact to a Steam Deck, run from terminal, confirm 60 fps stable at 1280×800 native per technical-preferences.md.

### Windows Desktop

- Architecture: `x86_64`
- Codesign: NOT enabled in this scaffold. Cert-prep work belongs to a later Sprint 20+ release-manager pass.
- Output: `build/windows/lantern_guild.exe`

### macOS

- Architecture: `universal` (Intel + Apple Silicon)
- Bundle ID: `com.claudecodegamestudios.lanternguild`
- Codesign + notarization: NOT enabled in this scaffold. Required for distribution outside Mac App Store; belongs to release-manager scope.
- Output: `build/macos/lantern_guild.app`

## CI integration (future)

This script is callable from a GitHub Actions workflow once a build-templates-pre-installed runner is provisioned. Sketch:

```yaml
- name: Setup Godot + templates
  run: ./.github/workflows/scripts/install-godot-templates.sh
- name: Build Linux Steam Deck artifact
  run: tools/build/build.sh linux
- name: Upload artifact
  uses: actions/upload-artifact@v4
  with:
    name: lantern_guild_steamdeck
    path: build/linux/
```

The `install-godot-templates.sh` helper is **not yet authored** — Sprint 20+ scope when the cert-prep + RC release workflow lands.

## Sprint 19 S19-M5 status

This scaffold closes the **doable autonomous portion** of S19-M5. Acceptance criterion was "produces a Steam-Deck-target build artifact from main" — this scaffold provides the harness; running it requires:

1. Export templates installed (manual step, requires editor)
2. `tools/build/build.sh linux` invocation
3. Visual verification of artifact runnability on Steam Deck hardware

Steps 1-3 are gated on hardware + editor-driven setup that doesn't run in the autonomous loop. The scaffold is verified at the syntax level (`bash -n tools/build/build.sh`); end-to-end binary verification belongs to the next real-time real-hardware session.

## Exclusions

`export_presets.cfg::exclude_filter` strips the following from shipped binaries:

- `tests/*` — gdunit4 test suites + fixtures
- `prototypes/*` — throwaway prototyping artifacts
- `.claude/*` — Claude Code agent + skill definitions
- `production/*` — sprint plans, epics, session state, QA evidence

Inclusion of these would inflate the binary by several megabytes and leak development artifacts to players.

## Troubleshooting

- **"export-template not found"** — install via Godot editor (see Prerequisites #2).
- **"export_presets.cfg missing"** — you've moved or deleted the file. It must live at the repo root.
- **"GODOT_BIN not found"** — set the env var to your local Godot 4.6+ binary path.
- **Build artifact runs but crashes on launch** — likely missing dependencies; check Godot's stderr output. Steam Deck-specific: confirm Vulkan is available (`vulkaninfo`).
