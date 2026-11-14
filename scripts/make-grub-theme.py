#!/usr/bin/env python3
"""Group 2 OS GRUB theme: branded backdrop and a readable menu band."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/mnt/c/Users/USER/GROUP 2 OS")
THEME = ROOT / "installer/overlay/usr/share/grub/themes/group2-os"
BOOT = ROOT / "branding/boot-background.png"
THEME.mkdir(parents=True, exist_ok=True)


def font(size: int, bold: bool = False):
    path = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    )
    if Path(path).is_file():
        return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def slice_png(color, size) -> Image.Image:
    im = Image.new("RGBA", size, color)
    return im


def main() -> None:
    w, h = 1920, 1080
    if BOOT.is_file():
        base = Image.open(BOOT).convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    else:
        base = Image.new("RGB", (w, h), (5, 10, 22))
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    # Dark band where the GRUB menu sits, so the entries stay readable.
    d.rectangle((0, 560, w, 980), fill=(5, 14, 28, 210))
    d.rectangle((80, 590, w - 80, 950), outline=(90, 180, 255, 160), width=2)
    title = font(54, True)
    slogan = font(22, False)
    d.text((w // 2, 80), "GROUP 2 OS", font=title, fill=(255, 255, 255, 245), anchor="mm")
    d.text((w // 2, 140), "LEARN  •  BUILD  •  CREATE  •  TOGETHER", font=slogan, fill=(170, 210, 245, 230), anchor="mm")
    out = Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
    bg = THEME / "background.png"
    out.save(bg, "PNG")
    iso_grub = ROOT / "installer/overlay/boot/grub"
    iso_grub.mkdir(parents=True, exist_ok=True)
    out.save(iso_grub / "group2-boot.png", "PNG")
    out.save(ROOT / "branding/grub-background.png", "PNG")

    cyan = (30, 167, 255, 230)
    edge = (20, 90, 170, 255)
    # Nine-slice highlight so the selected boot line is a blue pill.
    slice_png(cyan, (8, 8)).save(THEME / "select_c.png")
    slice_png(edge, (8, 4)).save(THEME / "select_n.png")
    slice_png(edge, (8, 4)).save(THEME / "select_s.png")
    slice_png(edge, (4, 8)).save(THEME / "select_e.png")
    slice_png(edge, (4, 8)).save(THEME / "select_w.png")
    slice_png(edge, (4, 4)).save(THEME / "select_ne.png")
    slice_png(edge, (4, 4)).save(THEME / "select_nw.png")
    slice_png(edge, (4, 4)).save(THEME / "select_se.png")
    slice_png(edge, (4, 4)).save(THEME / "select_sw.png")
    print("grub theme", THEME)


if __name__ == "__main__":
    main()
