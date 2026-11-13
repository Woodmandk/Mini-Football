#!/bin/sh
# Builds the web version of the 3D prototype into ../3d (served by GitHub Pages at /3d/).
# Needs Godot 4.4.1 and its web export templates; set GODOT to the editor binary.
set -e
cd "$(dirname "$0")"
G=${GODOT:-godot}
V="v$(TZ=Europe/Copenhagen date "+%d.%m %H:%M")"
printf '%s' "$V" > version.txt
"$G" --headless --import >/dev/null 2>&1 || true
"$G" --headless --export-release "Web" ../3d/index.html
cp web/net.js ../3d/net.js
cp web/sw.js ../3d/sw.js
cp web/manifest.webmanifest ../3d/manifest.webmanifest
cp version.txt ../3d/version.txt
