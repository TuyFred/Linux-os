#!/usr/bin/env python3
"""Write folder-tajidini.png next to the other Group 2 OS folder icons."""
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("Pillow is required")

OUT = Path("/mnt/c/Users/USER/GROUP 2 OS/installer/overlay/usr/share/group2-os/icons")
OUT.mkdir(parents=True, exist_ok=True)

s = 256
im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
top = (255, 138, 76, 255)
bottom = (226, 74, 27, 255)
d.rounded_rectangle((8, 8, 248, 248), 48, fill=(7, 20, 34, 90))
d.rounded_rectangle((36, 58, 118, 92), 12, fill=top)
d.rounded_rectangle((36, 78, 220, 210), 28, fill=top)
d.rounded_rectangle((36, 96, 220, 210), 28, fill=bottom)
d.rounded_rectangle((48, 108, 208, 132), 10, fill=(255, 255, 255, 40))
d.ellipse((102, 118, 154, 170), fill=(255, 255, 255, 240))
d.rounded_rectangle((82, 174, 174, 214), 32, fill=(255, 255, 255, 240))
dest = OUT / "folder-tajidini.png"
im.save(dest, "PNG")
print("icon", dest)
