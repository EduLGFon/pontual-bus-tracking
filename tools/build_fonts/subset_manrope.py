// Subset script for the bundled typeface. Manrope (SIL OFL 1.1) is fetched
// from the upstream Google Fonts repository and subset to Latin + Latin-1
// plus the punctuation and arrows the UI uses. The variable font keeps the
// whole weight axis in one 51 KB file, so Flutter applies wght through
// FontVariation instead of shipping five statics.
// Run from the repo root: python3 tools/build_fonts/subset_manrope.py
// Requires fonttools (pip install fonttools).
import os
import subprocess
import sys
import tempfile
import urllib.request

URL = (
    "https://github.com/google/fonts/raw/main/ofl/manrope/"
    "Manrope%5Bwght%5D.ttf"
)
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "app", "assets", "fonts")

UNICODES = ",".join(
    [
        "U+0020-007E",  # basic latin
        "U+00A0-00FF",  # latin-1 supplement, includes accents of pt-BR
        "U+2013-2014",  # en dash and em dash
        "U+2018-201D",  # curly quotes
        "U+2022",  # bullet
        "U+2026",  # ellipsis
        "U+2190-2193",  # arrows used in copy
    ]
)


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "Manrope-VF.ttf")
        print("downloading Manrope variable font")
        urllib.request.urlretrieve(URL, raw)
        target = os.path.join(OUT, "Manrope.ttf")
        cmd = [
            sys.executable,
            "-m",
            "fontTools.subset",
            raw,
            "--unicodes=" + UNICODES,
            "--layout-features=tnum,kern",
            "--no-hinting",
            "--output-file=" + target,
        ]
        subprocess.run(cmd, check=True)
        size = os.path.getsize(target)
        print("wrote %s (%d bytes)" % (target, size))
        if size > 70 * 1000:
            print("warning: subset is above the 70 KB budget from UI_SPEC 4.2")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
