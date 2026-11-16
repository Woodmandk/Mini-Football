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
# iPhone: Godot asks bbFit (web/net.js) for the page size and the touch position, so a phone held upright plays turned on its side
python3 - ../3d/index.js <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
for a, b in [
    ("width=window.innerWidth*scale;height=window.innerHeight*scale", "width=bbFit.w()*scale;height=bbFit.h()*scale"),
    ("computePosition:function(evt,rect){const canvas=GodotConfig.canvas;const rw=canvas.width/rect.width;const rh=canvas.height/rect.height;const x=(evt.clientX-rect.x)*rw;const y=(evt.clientY-rect.y)*rh;return[x,y]}",
     "computePosition:function(evt,rect){return bbFit.pos(evt,rect,GodotConfig.canvas)}"),
]:
    if a not in s:
        sys.exit("build.sh: index.js patch not found: " + a[:40])
    s = s.replace(a, b)
open(p, "w").write(s)
PY
cp web/net.js ../3d/net.js
cp web/sw.js ../3d/sw.js
cp web/manifest.webmanifest ../3d/manifest.webmanifest
cp version.txt ../3d/version.txt
