"""Extract the owner's exact right-hand mascot. Never redraw the silhouette or folds.

Usage: python scripts/extract-brain-assets.py <owner comparison PNG>
Only the eye/mouth areas are cleared on expression layers; the normal asset keeps every pixel.
"""
import json
from pathlib import Path
import sys
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(sys.argv[1]).convert("RGBA")
assert source.size == (960, 420), "Expected the owner's comparison image"
# Maps the original eye centers (668,234)/(773,234) to (140,168)/(224,168).
exact = source.crop((493, 24, 948, 399))
pixels = exact.load()
for y in range(exact.height):
    for x in range(exact.width):
        if pixels[x, y][:3] == (0, 0, 0):
            pixels[x, y] = (0, 0, 0, 0)

assets = root / "apps/ios/BrainArt/Assets.xcassets"
windows = root / "apps/windows-companion/Watch/Assets"
windows.mkdir(parents=True, exist_ok=True)
assets.mkdir(parents=True, exist_ok=True)
(assets / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}))

def save(name, image):
    folder = assets / (name + ".imageset")
    folder.mkdir(exist_ok=True)
    image.save(folder / (name + ".png"))
    image.save(windows / (name + ".png"))
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": name + ".png", "idiom": "universal"}],
        "info": {"version": 1, "author": "xcode"}}))

save("BrainExact", exact)
exact.save(root / "docs/design/brain-mascot-exact.png")
body = exact.copy()
for left, top, right, bottom in [(650, 214, 688, 257), (754, 214, 793, 257), (693, 270, 749, 302)]:
    for sy in range(top, bottom):
        # Both sides of each feature are flat original body color at this row.
        color = source.getpixel((left - 3, sy))
        for sx in range(left, right):
            body.putpixel((sx - 493, sy - 24), color)

palette = [(0xF9BAD2, 0xF1A2C1, 0xE597B8), (0xF7B4C8, 0xEC9DB6, 0xDF8FAA),
           (0xF0A0AA, 0xDA7888, 0xCE6C7C), (0xD6A696, 0xBC8476, 0xB2786C),
           (0xBAAA82, 0xA08E68, 0x968260), (0x989E76, 0x7E845E, 0x747A58)]
def rgb(value):
    return (value >> 16, (value >> 8) & 255, value & 255)
for stage, colors in enumerate(palette):
    image = body.copy()
    if stage >= 2:
        # Exterior sparkles belong only to fresh/sleepy moods, as in both original renderers.
        for left, top, right, bottom in [(558, 75, 594, 116), (862, 92, 900, 132), (870, 294, 898, 328)]:
            image.paste((0, 0, 0, 0), (left - 493, top - 24, right - 493, bottom - 24))
    if stage >= 3:
        # Gloss is an expression-layer detail. BrainExact remains untouched.
        for y in range(image.height):
            for x in range(image.width):
                r, g, b, a = image.getpixel((x, y))
                if a and r >= 248 and g > 205 and b > 228:
                    image.putpixel((x, y), (*rgb(palette[0][0]), a))
    replacements = dict(zip(map(rgb, palette[0]), map(rgb, colors)))
    image.putdata([(*replacements.get(p[:3], p[:3]), p[3]) for p in image.get_flattened_data()])
    save("BrainBody" + str(stage), image)

print("Extracted exact mascot and six expression layers for both apps.")
