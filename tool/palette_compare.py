"""Side-by-side comparison of the palette candidates.

Render the screens first:

    flutter test --run-skipped --tags preview test/ui_preview_test.dart \
        --plain-name palette

then run `python tool/palette_compare.py [preview dir]`. For every screen it
writes build/preview/compare/<screen>.png: one column per palette (current
first), light on the top row and dark below, each labelled.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

VARIANTS = [
    ("current", "Current (Slate)"),
    ("tide", "A. Tide"),
    ("marigold", "B. Marigold"),
    ("sky", "C. Sky"),
]
SCREENS = ["today", "history", "feed-sheet", "habits", "settings"]
GAP = 24
LABEL = 56
SCALE = 0.75


def font(size):
    for name in ["segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/preview")
    out = root / "compare"
    out.mkdir(parents=True, exist_ok=True)
    title = font(26)
    for screen in SCREENS:
        rows = []
        for suffix in ["", "-dark"]:
            row = []
            for variant, _ in VARIANTS:
                path = root / "palette" / variant / f"{screen}{suffix}.png"
                img = Image.open(path).convert("RGB")
                size = (round(img.width * SCALE), round(img.height * SCALE))
                row.append(img.resize(size, Image.LANCZOS))
            rows.append(row)
        w, h = rows[0][0].size
        cols = len(VARIANTS)
        sheet = Image.new(
            "RGB",
            (GAP + cols * (w + GAP), LABEL + len(rows) * (h + GAP)),
            (236, 236, 236),
        )
        draw = ImageDraw.Draw(sheet)
        for c, (_, label) in enumerate(VARIANTS):
            x = GAP + c * (w + GAP)
            draw.text((x, 14), label, fill=(30, 30, 30), font=title)
            for r, row in enumerate(rows):
                sheet.paste(row[c], (x, LABEL + r * (h + GAP)))
        sheet.save(out / f"{screen}.png", optimize=True)
        print(out / f"{screen}.png")


if __name__ == "__main__":
    main()
