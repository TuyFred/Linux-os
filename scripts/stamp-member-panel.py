#!/usr/bin/env python3
"""Redraw the desktop member panel so all 7 names are listed."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/mnt/c/Users/USER/GROUP 2 OS")
DEST = ROOT / "branding" / "desktop-wallpaper.png"

MEMBERS = [
    ("Fred Tuyishime", (61, 157, 255)),
    ("Tuyishimire Innocent", (46, 204, 113)),
    ("Armand Ikirezi", (155, 89, 255)),
    ("Ineza shami Lamick", (245, 166, 35)),
    ("Gabiro Vladmir Brenn", (46, 196, 214)),
    ("Irakoze Aline", (255, 95, 162)),
    ("Niyonkuru Tajidini", (255, 138, 76)),
]


def font(size: int, bold: bool = False):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main() -> None:
    if not DEST.is_file():
        raise SystemExit(f"missing {DEST}")
    base = Image.open(DEST).convert("RGBA")
    if base.size != (1920, 1080):
        base = base.resize((1920, 1080), Image.Resampling.LANCZOS)
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    # Cover the old 6-name panel and write all 7 names.
    d.rounded_rectangle((1488, 548, 1892, 1032), 24, fill=(6, 16, 32, 255))
    d.rounded_rectangle((1490, 550, 1890, 1030), 22, fill=(8, 18, 36, 230), outline=(90, 180, 255, 160), width=2)
    d.text((1520, 568), "GROUP 2", font=font(28, True), fill=(232, 244, 255, 255))
    d.text((1758, 574), "7 Members", font=font(14), fill=(170, 200, 230, 230))
    y = 620
    body = font(18)
    for name, color in MEMBERS:
        d.ellipse((1524, y + 4, 1544, y + 24), fill=color + (255,))
        d.text((1558, y), name, font=body, fill=(236, 246, 255, 255))
        y += 40
    d.text((1520, 980), "Linux  ·  Group 2", font=font(16), fill=(180, 210, 240, 240))
    out = Image.alpha_composite(base, overlay).convert("RGB")
    out.save(DEST, "PNG", optimize=True)
    print("wallpaper", DEST, out.size)


if __name__ == "__main__":
    main()
