"""Prepare en-US Play listing files and verify unframed release screenshots."""
from pathlib import Path
from io import BytesIO
import shutil
import xml.etree.ElementTree as ET

import cairosvg
from PIL import Image, ImageDraw, ImageFont

out = Path("play-package/listing/en-US")
images = out / "images"
phones = images / "phoneScreenshots"
phones.mkdir(parents=True, exist_ok=True)
for name, limit in (("title", 30), ("short_description", 80), ("full_description", 4000)):
    source = Path("play/listing/en-US") / (name + ".txt")
    assert 0 < len(source.read_text().strip()) <= limit, name
    shutil.copy(source, out / source.name)
shutil.copy("play/listing/en-US/release-notes.txt", out / "release-notes.txt")
shutil.copy("assets/privacy_policy.txt", out / "privacy-policy.txt")

screens = ["portrait-4x4", "portrait-theme-vault", "portrait-5x5", "portrait-run-results", "portrait-run-rewards"]
for order, screen in enumerate(screens, start=1):
    with Image.open(Path("arcade-previews") / (screen + ".png")) as source:
        assert source.size == (1080, 1920), (screen, source.size)
        source.convert("RGB").save(phones / f"{order:02d}-{screen}.png", optimize=True)

android = "{http://schemas.android.com/apk/res/android}"
vector = ET.parse("android/app/src/main/res/drawable/number_slide_mark.xml")
svg = ET.Element("svg", xmlns="http://www.w3.org/2000/svg", viewBox="0 0 108 108", width="512", height="512")
for path in vector.findall("path"):
    ET.SubElement(svg, "path", fill=path.get(android + "fillColor"), d=path.get(android + "pathData"))
render = cairosvg.svg2png(bytestring=ET.tostring(svg), output_width=512, output_height=512)
Image.open(BytesIO(render)).convert("RGBA").save(images / "icon.png", optimize=True)

# Compose the header as vector-style art in the game's actual palette and typeface.
scale = 2
canvas = Image.new("RGB", (1024 * scale, 500 * scale))
draw = ImageDraw.Draw(canvas)
def box(coords): return tuple(round(n * scale) for n in coords)
def font(size):
    face = ImageFont.truetype("assets/fonts/Fredoka.ttf", size * scale)
    axes = face.get_variation_axes()
    face.set_variation_by_axes([min(a["maximum"], 665) if a["name"] == b"Weight" else a["default"] for a in axes])
    return face
for x in range(canvas.width):
    t = x / (canvas.width - 1)
    draw.line((x, 0, x, canvas.height), fill=(round(20+16*t), round(17+6*t), round(53+28*t)))
for y in range(15, 500, 22):
    for x in range(13, 1024, 24):
        color = "#425078" if (x + y) % 5 else "#69365F"
        draw.ellipse(box((x, y, x+1.5, y+1.5)), fill=color)
draw.text(box((102, 132)), "NUMBER", font=font(81), fill="#F4F2FF")
draw.text(box((102, 224)), "SLIDE PRO", font=font(81), fill="#65EDFF")
for i, value in enumerate((1, 2, 3, 4, 5, 6, 7, 0, 8)):
    x, y = 613 + (i % 3)*83, 111 + (i // 3)*83
    draw.rounded_rectangle(box((x,y,x+77,y+77)), radius=12*scale,
                           fill="#121831" if value == 0 else "#5132B2",
                           outline="#1A7486" if value == 0 else "#8D80FC", width=2*scale)
    if value:
        draw.text(box((x+39, y+37)), str(value), anchor="mm", font=font(40), fill="#F8F5FF")
canvas.resize((1024, 500), Image.Resampling.LANCZOS).save(images / "featureGraphic.png", optimize=True)
assert (images / "icon.png").stat().st_size <= 1024**2
for p in phones.glob("*.png"):
    assert p.stat().st_size < 8*1024**2
print("Validated", len(screens), "1080 x 1920 phone screenshots, icon, feature graphic and listing text.")
