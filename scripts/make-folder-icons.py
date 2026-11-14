#!/usr/bin/env python3
"""Create Group 2 OS colored folder icons matching the Files mockup."""
from pathlib import Path

OUT = Path(r"/mnt/c/Users/USER/GROUP 2 OS/installer/overlay/usr/share/group2-os/icons")
OUT.mkdir(parents=True, exist_ok=True)

FOLDERS = {
    "folder-fred.svg": ("#3DA9FC", "#1B6BFF"),
    "folder-innocent.svg": ("#3DDC84", "#148C48"),
    "folder-armand.svg": ("#A56BFF", "#6B2EE6"),
    "folder-ineza.svg": ("#FFB347", "#E67A12"),
    "folder-gabiro.svg": ("#3FE0E8", "#1498B8"),
    "folder-aline.svg": ("#FF6BCB", "#D12E8C"),
    "folder-tajidini.svg": ("#FF8A4C", "#E24A1B"),
    "folder-projects.svg": ("#4DA3FF", "#1E5EE8"),
    "folder-documents.svg": ("#5B8CFF", "#2746D9"),
    "folder-pictures.svg": ("#4D9BFF", "#1E62E8"),
    "folder-music.svg": ("#3D8CFF", "#1A4FD9"),
    "folder-videos.svg": ("#3D7BFF", "#1A3ED9"),
    "folder-trash.svg": ("#5A6A80", "#2E3A4D"),
}


def folder_svg(c1: str, c2: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{c1}"/>
      <stop offset="1" stop-color="{c2}"/>
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="28" fill="#071422" fill-opacity="0.35"/>
  <path fill="url(#g)" d="M18 40c0-7 6-12 13-12h24l10 10h46c7 0 13 5 13 12v48c0 7-6 12-13 12H31c-7 0-13-5-13-12V40z"/>
  <path fill="#ffffff" fill-opacity="0.18" d="M31 38h66c5 0 9 4 9 9v6H22v-6c0-5 4-9 9-9z"/>
</svg>
"""


def main() -> None:
    for name, colors in FOLDERS.items():
        (OUT / name).write_text(folder_svg(*colors), encoding="utf-8")
        print("wrote", OUT / name)
    print("Group 2 OS folder icons ready.")


if __name__ == "__main__":
    main()
