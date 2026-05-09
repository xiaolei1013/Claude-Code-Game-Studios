#!/usr/bin/env bash
# Lantern Guild RC build pipeline — Sprint 19 S19-M5 scaffold.
#
# Wraps Godot's headless export against `export_presets.cfg`. Targets the three
# MVP platforms: Linux x86_64 (Steam Deck primary), Windows Desktop, macOS
# universal. Per-platform export templates must be installed via the Godot
# editor's "Manage Export Templates" dialog before this script can produce a
# binary.
#
# Usage:
#   tools/build/build.sh [linux|windows|macos|all]
#
#   linux    — Steam Deck primary target; produces build/linux/*
#   windows  — Windows x86_64 desktop; produces build/windows/*
#   macos    — macOS universal binary; produces build/macos/*
#   all      — runs all three sequentially
#
# Defaults to `linux` when invoked with no argument.
#
# Environment variables:
#   GODOT_BIN   — path to the Godot 4.6+ binary (defaults to the macOS mono app)
#   BUILD_MODE  — "release" (default) or "debug" (passes --export-debug)
#
# Exit codes:
#   0  — success
#   1  — Godot binary missing
#   2  — export_presets.cfg missing
#   3  — preset build failed
#   4  — invalid argument
#
# CI integration: this script is callable from `.github/workflows/` once a
# build-templates-installed runner is provisioned. Local invocation requires
# the running user to have set up export templates via the editor first.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
BUILD_MODE="${BUILD_MODE:-release}"
TARGET="${1:-linux}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

if [[ ! -x "$GODOT_BIN" ]]; then
    echo "[build.sh] ERROR: Godot binary not found or not executable: $GODOT_BIN" >&2
    echo "[build.sh] Set GODOT_BIN to the Godot 4.6+ executable path." >&2
    exit 1
fi

if [[ ! -f "$REPO_ROOT/export_presets.cfg" ]]; then
    echo "[build.sh] ERROR: export_presets.cfg missing in repo root." >&2
    exit 2
fi

GODOT_VERSION=$("$GODOT_BIN" --version 2>&1 | head -1)
echo "[build.sh] Godot: $GODOT_VERSION"
echo "[build.sh] Build mode: $BUILD_MODE"
echo "[build.sh] Target: $TARGET"

# ---------------------------------------------------------------------------
# Per-target export
# ---------------------------------------------------------------------------

if [[ "$BUILD_MODE" == "debug" ]]; then
    EXPORT_FLAG="--export-debug"
else
    EXPORT_FLAG="--export-release"
fi

run_export() {
    local preset_name="$1"
    local output_path="$2"
    local platform_label="$3"

    echo ""
    echo "[build.sh] Building $platform_label preset='$preset_name' → $output_path"
    mkdir -p "$(dirname "$output_path")"

    if ! "$GODOT_BIN" --headless --path "$REPO_ROOT" \
            "$EXPORT_FLAG" "$preset_name" "$output_path" 2>&1; then
        echo "[build.sh] ERROR: $platform_label export failed." >&2
        return 3
    fi

    if [[ ! -e "$output_path" ]]; then
        echo "[build.sh] ERROR: $platform_label export produced no artifact at $output_path." >&2
        return 3
    fi

    local size
    size=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null || echo "?")
    echo "[build.sh] $platform_label artifact: $output_path ($size bytes)"
}

case "$TARGET" in
    linux)
        run_export "Linux/SteamDeck" \
            "$REPO_ROOT/build/linux/lantern_guild_steamdeck.x86_64" \
            "Linux Steam Deck"
        ;;
    windows)
        run_export "Windows Desktop" \
            "$REPO_ROOT/build/windows/lantern_guild.exe" \
            "Windows Desktop"
        ;;
    macos)
        run_export "macOS" \
            "$REPO_ROOT/build/macos/lantern_guild.app" \
            "macOS"
        ;;
    all)
        run_export "Linux/SteamDeck" \
            "$REPO_ROOT/build/linux/lantern_guild_steamdeck.x86_64" \
            "Linux Steam Deck"
        run_export "Windows Desktop" \
            "$REPO_ROOT/build/windows/lantern_guild.exe" \
            "Windows Desktop"
        run_export "macOS" \
            "$REPO_ROOT/build/macos/lantern_guild.app" \
            "macOS"
        ;;
    *)
        echo "[build.sh] ERROR: invalid target '$TARGET'. Use linux|windows|macos|all." >&2
        exit 4
        ;;
esac

echo ""
echo "[build.sh] Done."
