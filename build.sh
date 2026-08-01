#!/usr/bin/env bash
# Builds Aria and the Pink Star for the web: generates procedural art assets,
# then exports the HTML5 "Web" preset. Requires the `godot` CLI (Godot 4.2+)
# to be on your PATH.
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Aria and the Pink Star: web build =="

mkdir -p "$PROJECT_DIR/generated_assets"

echo "-- Generating procedural art assets --"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script scripts/procedural_art.gd

mkdir -p "$PROJECT_DIR/build/web"

echo "-- Exporting HTML5 build --"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$PROJECT_DIR/build/web/index.html"

echo "== Build complete: $PROJECT_DIR/build/web/index.html =="
