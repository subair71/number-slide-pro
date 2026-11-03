#!/usr/bin/env bash
set -euo pipefail

# Render the actual Android screen without writing scores to the live leaderboard.
flutter build apk --debug --dart-define=FIREBASE_EMULATORS=true
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
package=com.bilvok.numberslidepro
adb shell pm clear "$package" >/dev/null
adb shell wm size 780x1688
adb shell wm density 320
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell am start -W -n "$package/.MainActivity" >/dev/null
mkdir -p arcade-previews
layout=$(mktemp)
trap 'rm -f "$layout"' EXIT

wait_for_label() {
  for ((attempt=0; attempt<25; attempt++)); do
    if adb shell uiautomator dump /sdcard/arcade-layout.xml >/dev/null 2>&1 &&
       adb exec-out cat /sdcard/arcade-layout.xml > "$layout" &&
       grep -q "$1" "$layout"; then
      return
    fi
    sleep 1
  done
  echo "Game label did not appear: $1" >&2
  exit 1
}

wait_for_label 'Tile 15'
adb exec-out screencap -p > arcade-previews/portrait-4x4.png
wait_for_label '5 by 5 grid'
python3 - "$layout" <<'PY'
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

node = next(n for n in ET.parse(sys.argv[1]).iter("node") if "5 by 5 grid" in n.get("content-desc", ""))
x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.attrib["bounds"]))
subprocess.run(["adb", "shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2)], check=True)
PY
wait_for_label 'Tile 24'
adb exec-out screencap -p > arcade-previews/portrait-5x5.png
adb shell settings put system user_rotation 1
sleep 2
wait_for_label 'Tile 24'
adb exec-out screencap -p > arcade-previews/landscape-5x5.png
python3 - <<'PY'
from pathlib import Path
from struct import unpack

for path in sorted(Path("arcade-previews").glob("*.png")):
    with path.open("rb") as png:
        header = png.read(24)
    assert header.startswith(b"\x89PNG\r\n\x1a\n"), path.name
    size = unpack(">II", header[16:24])
    expected = (1688, 780) if "landscape" in path.name else (780, 1688)
    assert size == expected, (path.name, size, expected)
    print(f"{path.name}: {size[0]} x {size[1]}")
PY
