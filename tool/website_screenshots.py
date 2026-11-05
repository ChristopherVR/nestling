"""Makes the phone screenshots on the website (site/images) from the renders.

From the repository root (needs Pillow; the fonts step also needs fontTools
and Windows' Segoe UI):

    python tool/website_screenshots.py fonts
    flutter test --run-skipped --tags preview test/ui_preview_test.dart \
        --plain-name website
    python tool/website_screenshots.py

`fonts` writes build/preview-fonts/roboto-*.ttf: Flutter's Roboto with the
arrows (U+2190, U+2192) copied in from Segoe UI. Flutter's test renderer
has no font fallback, so without them "3.3 → 6.5 kg" shows a box. The
preview tests use these fonts when they exist.

Without arguments, converts build/preview/web-*.png (or PREVIEW_OUT) to
site/images/<name>.webp, and the camera guide images listed in CAMERA
(docs/images/camera, rendered by test/camera_preview_test.dart) to
site/images/camera-<name>.webp.
"""

import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = pathlib.Path(os.environ.get('PREVIEW_OUT', ROOT / 'build' / 'preview'))
TARGET = ROOT / 'site' / 'images'
FONTS = ROOT / 'build' / 'preview-fonts'
CAMERA = {'02-path': 'path', '12-done': 'done'}


def fonts() -> int:
    from fontTools import subset
    from fontTools.merge import Merger
    from fontTools.ttLib import TTFont

    flutter = pathlib.Path(
        os.environ.get('FLUTTER_ROOT', r'D:\Development\tools\flutter'))
    material = flutter / 'bin' / 'cache' / 'artifacts' / 'material_fonts'
    windir = pathlib.Path(os.environ.get('WINDIR', r'C:\Windows'))
    FONTS.mkdir(parents=True, exist_ok=True)
    for weight, segoe in [('regular', 'segoeui.ttf'),
                          ('medium', 'seguisb.ttf'),
                          ('bold', 'segoeuib.ttf')]:
        arrows = TTFont(windir / 'Fonts' / segoe)
        options = subset.Options()
        options.layout_features = []
        options.name_IDs = ['*']
        options.notdef_outline = True
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=[0x2190, 0x2192])
        subsetter.subset(arrows)
        part = FONTS / f'arrows-{weight}.ttf'
        arrows.save(part)
        out = FONTS / f'roboto-{weight}.ttf'
        Merger().merge([str(material / f'roboto-{weight}.ttf'), str(part)]).save(out)
        part.unlink()
        print(f'wrote {out.relative_to(ROOT)}')
    return 0


def convert() -> int:
    from PIL import Image

    shots = sorted(SOURCE.glob('web-*.png'))
    if not shots:
        print(f'No web-*.png renders in {SOURCE}', file=sys.stderr)
        return 1
    TARGET.mkdir(parents=True, exist_ok=True)
    for png in shots:
        name = png.stem.removeprefix('web-')
        out = TARGET / f'{name}.webp'
        Image.open(png).convert('RGB').save(out, 'WEBP', quality=88, method=6)
        print(f'{png.name} -> {out.relative_to(ROOT)}')
    for source, name in CAMERA.items():
        png = ROOT / 'docs' / 'images' / 'camera' / f'{source}.png'
        out = TARGET / f'camera-{name}.webp'
        Image.open(png).convert('RGB').save(out, 'WEBP', quality=88, method=6)
        print(f'{png.relative_to(ROOT)} -> {out.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(fonts() if sys.argv[1:] == ['fonts'] else convert())
