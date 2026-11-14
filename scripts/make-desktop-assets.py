#!/usr/bin/env python3
"""Create real Group 2 OS desktop assets.

Wallpaper: landscape + logo + flag + member panel. No fake folders or dock.
Icons: PNG folder icons that GNOME Desktop Icons can actually use.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(r"/mnt/c/Users/USER/GROUP 2 OS")
BRANDING = ROOT / "branding"
ICON_DIR = ROOT / "installer/overlay/usr/share/group2-os/icons"
ICON_DIR.mkdir(parents=True, exist_ok=True)

MEMBERS = [
    ("Fred Tuyishime", (61, 157, 255)),
    ("Tuyishimire Innocent", (46, 204, 113)),
    ("Armand Ikirezi", (155, 89, 255)),
    ("Ineza shami Lamick", (245, 166, 35)),
    ("Gabiro Vladmir Brenn", (46, 196, 214)),
    ("Irakoze Aline", (255, 95, 162)),
    ("Niyonkuru Tajidini", (255, 138, 76)),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def folder_icon(top, bottom, glyph: str) -> Image.Image:
    s = 256
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((8, 8, 248, 248), 48, fill=(7, 20, 34, 90))
    # tab
    d.rounded_rectangle((36, 58, 118, 92), 12, fill=top)
    # body
    d.rounded_rectangle((36, 78, 220, 210), 28, fill=top)
    d.rounded_rectangle((36, 96, 220, 210), 28, fill=bottom)
    # gloss
    d.rounded_rectangle((48, 108, 208, 132), 10, fill=(255, 255, 255, 40))
    f = font(72, bold=True)
    bbox = d.textbbox((0, 0), glyph, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((s - tw) / 2, 118), glyph, font=f, fill=(255, 255, 255, 230))
    return im


def person_icon(top, bottom) -> Image.Image:
    im = folder_icon(top, bottom, "")
    d = ImageDraw.Draw(im)
    d.ellipse((102, 118, 154, 170), fill=(255, 255, 255, 240))
    d.rounded_rectangle((82, 174, 174, 214), 32, fill=(255, 255, 255, 240))
    return im


def save_icon(name: str, im: Image.Image) -> None:
    dest = ICON_DIR / name
    im.save(dest, "PNG")
    print("icon", dest)


def make_icons() -> None:
    people = {
        "folder-fred.png": ((61, 157, 255), (27, 90, 220)),
        "folder-innocent.png": ((46, 204, 113), (20, 140, 72)),
        "folder-armand.png": ((155, 89, 255), (107, 46, 230)),
        "folder-ineza.png": ((245, 166, 35), (230, 122, 18)),
        "folder-gabiro.png": ((46, 196, 214), (20, 140, 170)),
        "folder-aline.png": ((255, 95, 162), (209, 46, 140)),
        "folder-tajidini.png": ((255, 138, 76), (226, 74, 27)),
    }
    for name, colors in people.items():
        save_icon(name, person_icon(*colors))

    glyphs = {
        "folder-projects.png": (((77, 163, 255), (30, 94, 232)), "</>"),
        "folder-documents.png": (((91, 140, 255), (39, 70, 217)), "≡"),
        "folder-pictures.png": (((77, 155, 255), (30, 98, 232)), "▣"),
        "folder-music.png": (((61, 140, 255), (26, 79, 217)), "♪"),
        "folder-videos.png": (((61, 123, 255), (26, 62, 217)), "▶"),
        "folder-trash.png": (((90, 106, 128), (46, 58, 77)), "🗑"),
    }
    for name, (colors, glyph) in glyphs.items():
        save_icon(name, folder_icon(*colors, glyph))


def make_wallpaper() -> None:
    src = Path(
        r"/mnt/c/Users/USER/.cursor/projects/c-Users-USER-GROUP-2-OS/assets/group2-desktop-wallpaper.png"
    )
    if not src.is_file():
        src = BRANDING / "desktop-wallpaper.png"
    if not src.is_file():
        raise SystemExit(f"missing desktop wallpaper source")
    base = Image.open(src).convert("RGBA").resize((1920, 1080), Image.Resampling.LANCZOS)

    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # Leave the left ~260px and bottom ~90px clear for real icons and dock.
    panel = (1490, 560, 1890, 1020)
    d.rounded_rectangle(panel, 22, fill=(8, 18, 36, 168), outline=(90, 180, 255, 90), width=2)

    title = font(28, bold=True)
    body = font(18)
    d.text((1520, 578), "GROUP 2", font=title, fill=(232, 244, 255, 255))
    d.text((1758, 584), "7 Members", font=font(14), fill=(170, 200, 230, 230))

    y = 628
    for name, color in MEMBERS:
        d.ellipse((1524, y + 4, 1544, y + 24), fill=color + (255,))
        d.text((1558, y), name, font=body, fill=(236, 246, 255, 255))
        y += 42

    d.text((1520, 970), "Linux  ·  Group 2", font=font(16), fill=(180, 210, 240, 240))
    slogan = font(22, bold=True)
    text = "Together We Build A Better Future"
    bbox = d.textbbox((0, 0), text, font=slogan)
    tw = bbox[2] - bbox[0]
    d.text(((1920 - tw) / 2, 930), text, font=slogan, fill=(255, 255, 255, 210))

    out = Image.alpha_composite(base, overlay).convert("RGB")
    dest = BRANDING / "desktop-wallpaper.png"
    out.save(dest, "PNG", optimize=True)
    print("wallpaper", dest, out.size)


def make_g_logo() -> None:
    boot = BRANDING / "boot-background.png"
    if not boot.is_file():
        return
    im = Image.open(boot).convert("RGBA")
    w, h = im.size
    crop = im.crop((int(w * 0.34), int(h * 0.18), int(w * 0.66), int(h * 0.52)))
    crop = crop.resize((256, 256), Image.Resampling.LANCZOS)
    dest = ICON_DIR / "group2-g.png"
    crop.save(dest, "PNG")
    pix = ROOT / "installer/overlay/usr/share/pixmaps"
    pix.mkdir(parents=True, exist_ok=True)
    crop.save(pix / "group2-os-g.png", "PNG")
    print("logo", dest)


def main() -> None:
    make_icons()
    make_wallpaper()
    make_g_logo()
    print("Group 2 OS real desktop assets ready.")


if __name__ == "__main__":
    main()
