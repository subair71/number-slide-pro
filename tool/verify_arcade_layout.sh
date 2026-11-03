#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Layout check failed at line $LINENO" >&2' ERR

# Render the actual Android screen without writing scores to the live leaderboard.
if [[ -n "${PLAY_RELEASE_APK:-}" ]]; then
  # Capture this exact release without sending screenshot-run scores to live Firebase.
  adb shell cmd connectivity airplane-mode enable
  adb shell svc wifi disable
  adb shell svc data disable
  adb install -r "$PLAY_RELEASE_APK"
else
  flutter build apk --debug --dart-define=FIREBASE_EMULATORS=true
  adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
fi
package=com.bilvok.numberslidepro
adb shell pm clear "$package" >/dev/null
adb shell wm size "${CAPTURE_RESOLUTION:-390x1168}"
adb shell wm density "${CAPTURE_DENSITY:-160}"
if [[ -n "${PLAY_RELEASE_APK:-}" ]]; then
  adb shell settings put secure sysui_demo_allowed 1
  adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
  adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
  adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
fi
adb shell wm size
adb shell wm density
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
python3 tool/capture_stitch_screens.py
wait_for_label 'Tile'
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

# Rotation swaps the hardware framebuffer dimensions, even with a custom display size.
framebuffer_sizes = set()
for path in sorted(Path("arcade-previews").glob("*.png")):
    with path.open("rb") as png:
        header = png.read(24)
    assert header.startswith(b"\x89PNG\r\n\x1a\n"), path.name
    size = unpack(">II", header[16:24])
    assert min(size) > 0, (path.name, size)
    framebuffer_sizes.add(tuple(sorted(size)))
    assert (size[0] > size[1]) == ("landscape" in path.name), (path.name, size)
    print(f"{path.name}: {size[0]} x {size[1]}")
assert len(framebuffer_sizes) == 1, framebuffer_sizes
PY
