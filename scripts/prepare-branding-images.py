#!/usr/bin/env python3
"""Build Group 2 OS screen assets.

Uses the clean landscape / splash art (no painted folders, dock, or
caption bars). The four UI mockups stay in branding/raw-mockups as
design reference only.
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(r"/mnt/c/Users/USER/GROUP 2 OS")
BRANDING = ROOT / "branding"
ASSETS = Path(
    r"/mnt/c/Users/USER/.cursor/projects/c-Users-USER-GROUP-2-OS/assets"
)

CLEAN = {
    "desktop": ASSETS / "group2-desktop-wallpaper.png",
    "login": ASSETS / "group2-login-background.png",
    "boot": ASSETS / "group2-boot-background.png",
}

MOCKUPS = {
    "login": ASSETS
    / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_image-2f5af166-f775-43d7-a34d-9293c6434d9a.png",
    "desktop": ASSETS
    / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_image-accd5ba8-706d-4553-80c5-cb9bbe72f8f5.jpg",
    "boot": ASSETS
    / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_image-fa51acdc-aac8-47f5-9e7e-e225273756eb.png",
    "files": ASSETS
    / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_image-1a2d84f4-9f7f-41df-96ff-283c1bd0cae8.png",
}

TARGET = (1920, 1080)


def fit_canvas(im: Image.Image, size=TARGET, fill=(7, 20, 34)) -> Image.Image:
    """Scale image to cover the canvas, then center-crop."""
    tw, th = size
    im = im.convert("RGB")
    sw, sh = im.size
    scale = max(tw / sw, th / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def save_png(im: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, format="PNG", optimize=True)
    print(f"wrote {dest} ({im.size[0]}x{im.size[1]})")


def main() -> None:
    for key, path in CLEAN.items():
        if not path.is_file():
            raise SystemExit(f"Missing clean art for {key}: {path}")

    save_png(fit_canvas(Image.open(CLEAN["login"])), BRANDING / "login-background.png")
    save_png(fit_canvas(Image.open(CLEAN["desktop"])), BRANDING / "desktop-wallpaper.png")
    save_png(fit_canvas(Image.open(CLEAN["boot"]), fill=(2, 6, 16)), BRANDING / "boot-background.png")

    files_src = MOCKUPS["files"]
    if files_src.is_file():
        save_png(Image.open(files_src).convert("RGB"), BRANDING / "files-reference.png")

    raw = BRANDING / "raw-mockups"
    raw.mkdir(parents=True, exist_ok=True)
    for name, src in MOCKUPS.items():
        if src.is_file():
            shutil.copy2(src, raw / f"{name}-mockup{src.suffix.lower()}")
    print("Group 2 OS branding images are ready.")


if __name__ == "__main__":
    main()
