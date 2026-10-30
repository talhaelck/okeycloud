"""Downloads the UI fonts (SIL Open Font License 1.1, from the google/fonts repository), checks that every one has the
Turkish letters and the glyphs the game writes, and copies the good ones into assets/fonts/ with their licence files.

    python -I tools/fetch_fonts.py

Downloads go to raw/fonts/ (ignored by git). A font that lacks a needed glyph is reported and not copied.
Needs fontTools: pip install fonttools
"""
import pathlib
import shutil
import sys
import urllib.request

from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "raw" / "fonts"
OUT = ROOT / "assets" / "fonts"
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"

# family folder -> files. What each one is for is in assets/CREDITS.md and scripts/ui/kahve_theme.gd.
FONTS = {
    "alfaslabone": ["AlfaSlabOne-Regular.ttf"],
    "bungee": ["Bungee-Regular.ttf"],
    "rubik": ["Rubik[wght].ttf"],
    "patrickhand": ["PatrickHand-Regular.ttf"],
    "caveat": ["Caveat[wght].ttf"],
}

# What every font must have: the Turkish alphabet (both cases, with the dotted and dotless i), digits, punctuation.
NEEDED = "ĞğİıŞşÇçÖöÜüABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?'\"()[]/+-×·%#&*…"
# Nice to have; the UI draws its own icons for what a font lacks (arrows, ticks, dots), so these are only reported.
OPTIONAL = "−→←↺✓●"


def fetch(url: str, path: pathlib.Path) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(url.replace("[", "%5B").replace("]", "%5D"), timeout=60) as response:
            path.write_bytes(response.read())
        return True
    except Exception as error:  # noqa: BLE001 - report and carry on with the other fonts
        print("  could not download", url, error)
        return False


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    for family, files in FONTS.items():
        print(family)
        licence = RAW / family / "OFL.txt"
        if not licence.exists():
            fetch(BASE + family + "/OFL.txt", licence)
        for name in files:
            path = RAW / family / name
            if not path.exists() and not fetch(BASE + family + "/" + name, path):
                failed += 1
                continue
            font = TTFont(str(path))
            cmap = font.getBestCmap()
            missing = [ch for ch in NEEDED if ord(ch) not in cmap]
            extras = [ch for ch in OPTIONAL if ord(ch) not in cmap]
            if extras:
                print("  (%s has no %s)" % (name, ascii("".join(extras))))
            if missing:
                print("  %s lacks %s: not copied" % (name, ascii("".join(missing))))
                failed += 1
                continue
            target = OUT / name.replace("[wght]", "-Variable")
            shutil.copyfile(path, target)
            print("  ok %s -> %s (%d glyphs, %.0f KB)" % (name, target.relative_to(ROOT), len(cmap), target.stat().st_size / 1024))
        if licence.exists():
            shutil.copyfile(licence, OUT / ("OFL-%s.txt" % family))
    print("done, %d problems" % failed)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
