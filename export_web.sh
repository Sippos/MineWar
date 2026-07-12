#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="${LOG_DIR:-build/logs}"
EXPORT_LOG="$LOG_DIR/web-export.log"

if "$GODOT_BIN" --version 2>/dev/null | grep -qiE 'mono|\.net'; then
	echo "Refusing to export Web with Mono/.NET Godot binary: $GODOT_BIN" >&2
	exit 1
fi

mkdir -p build/web "$LOG_DIR"
rm -f build/web/index.html build/web/index.js build/web/index.wasm build/web/index.pck

set +e
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html 2>&1 | tee "$EXPORT_LOG"
export_rc=${PIPESTATUS[0]}
set -e

if (( export_rc != 0 )); then
	echo "Godot Web export exited with status $export_rc" >&2
	exit "$export_rc"
fi

# Godot can return success while logging fatal resource and script failures.
# Ignore only the known harmless warning caused by the excluded Blender source.
filtered_log="$(mktemp)"
grep -vF 'Blender path is invalid or not set, check your Editor Settings. Cannot configure blender path in headless mode.' "$EXPORT_LOG" > "$filtered_log" || true

if grep -Eiq 'SCRIPT ERROR|Parse Error|Failed loading resource|Unable to open file|Can.t open file from path|Failed to load script' "$filtered_log"; then
	echo "Godot reported fatal script/resource errors:" >&2
	grep -Ei 'SCRIPT ERROR|Parse Error|Failed loading resource|Unable to open file|Can.t open file from path|Failed to load script' "$filtered_log" >&2 || true
	rm -f "$filtered_log"
	exit 1
fi
rm -f "$filtered_log"

for output in index.html index.js index.wasm index.pck; do
	if [[ ! -s "build/web/$output" ]]; then
		echo "Missing or empty Web export artifact: build/web/$output" >&2
		exit 1
	fi
done

echo "Validated Web export created in build/web"
