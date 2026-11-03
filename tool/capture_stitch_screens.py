"""Capture the actual shop and completion routes from the Android preview emulator."""
from collections import deque
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

DEST = Path("arcade-previews")


def adb(*args):
    return subprocess.check_output(["adb", *map(str, args)])


def nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/stitch-layout.xml")
    return list(ET.fromstring(adb("exec-out", "cat", "/sdcard/stitch-layout.xml")).iter("node"))


def centre(node):
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
    return ((x1+x2)//2, (y1+y2)//2)


def label(node):
    return (node.get("content-desc") or node.get("text") or "").strip()


def find(text, *, tap=False):
    for _ in range(8):
        for node in nodes():
            if text.casefold() in label(node).casefold():
                if tap:
                    adb("shell", "input", "tap", *centre(node))
                    time.sleep(.35)
                return
        time.sleep(.4)
    raise RuntimeError("Missing Android element: " + text)


def screenshot(name):
    (DEST / name).write_bytes(adb("exec-out", "screencap", "-p"))


find("shop", tap=True)
find("THEME VAULT")
screenshot("portrait-theme-vault.png")
find("Close vault", tap=True)
find("3 by 3 grid", tap=True)
find("Tile 8")
positions = {}
for node in nodes():
    match = re.fullmatch(r"Tile (\d+)", label(node))
    if match:
        positions[int(match[1])] = centre(node)
assert set(positions) == set(range(1, 9)), positions
xs = sorted({v[0] for v in positions.values()})
ys = sorted({v[1] for v in positions.values()})
assert len(xs) == len(ys) == 3, positions
cells = [0] * 9
for n, (x, y) in positions.items():
    cells[ys.index(y)*3 + xs.index(x)] = n
start, goal = tuple(cells), tuple(range(1, 9)) + (0,)
toward = {goal: None}
pending = deque([goal])
while start not in toward:
    state = pending.popleft()
    gap = state.index(0)
    for p in range(9):
        if abs(gap//3-p//3) + abs(gap%3-p%3) != 1:
            continue
        board = list(state)
        board[gap], board[p] = board[p], board[gap]
        prev = tuple(board)
        if prev not in toward:
            toward[prev] = state
            pending.append(prev)
state = start
commands = []
while state != goal:
    nxt = toward[state]
    p = nxt.index(0)
    commands.append(f"input tap {xs[p%3]} {ys[p//3]}; sleep 0.23")
    state = nxt
if not commands:
    # A legal shuffle can rarely finish solved. Move one tile out and back.
    commands = [f"input tap {xs[1]} {ys[2]}; sleep 0.3", f"input tap {xs[2]} {ys[2]}"]
adb("shell", "; ".join(commands))
find("HARMONIC ALIGNMENT")
screenshot("portrait-run-results.png")
for _ in range(2):
    # Touch coordinates above were returned by UIAutomator in logical-display pixels.
    adb("shell", "input", "swipe", xs[1], ys[-1], xs[1], max(24, ys[0]//3), 320)
    time.sleep(.4)
screenshot("portrait-run-rewards.png")
adb("shell", "input", "keyevent", 4)
time.sleep(.7)

# A maintainer can request an inline diagnostic for the two isolated emulator screens.
# Normal runs only store the PNG artifacts.
if "[review previews]" in subprocess.check_output(["git", "log", "-1", "--format=%s"], text=True):
    import base64
    from io import BytesIO
    from PIL import Image

    sheet = Image.new("RGB", (900, 600))
    for i, name in enumerate(("portrait-theme-vault.png", "portrait-run-results.png", "portrait-run-rewards.png")):
        with Image.open(DEST / name) as img:
            img.thumbnail((300, 600))
            sheet.paste(img.convert("RGB"), (300*i, 0))
    encoded = BytesIO()
    sheet.save(encoded, format="JPEG", quality=83)
    print("::group::Emulator screen thumbnails")
    print("STITCH_PREVIEW_JPEG=" + base64.b64encode(encoded.getvalue()).decode("ascii"))
    print("::endgroup::")
