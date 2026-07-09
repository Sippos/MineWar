#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"

if "$GODOT_BIN" --version 2>/dev/null | grep -qiE 'mono|\.net'; then
	echo "Refusing to export Web with Mono/.NET Godot binary: $GODOT_BIN" >&2
	exit 1
fi

mkdir -p build/web
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html
