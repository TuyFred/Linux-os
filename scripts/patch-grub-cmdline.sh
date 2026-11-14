#!/bin/sh
# Group 2 OS GRUB for the live ISO.
# VirtualBox: use VBoxSVGA (not VMSVGA). If graphics fail, pick "VirtualBox / safe graphics".
set -eu
ISO_EXTRACT=${1:?usage: patch-grub-cmdline.sh ISO_EXTRACT}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
THEME_SRC="$SCRIPT_DIR/../installer/overlay/usr/share/grub/themes/group2-os"
if [ -d "$THEME_SRC" ]; then
	mkdir -p "$ISO_EXTRACT/boot/grub/themes/group2-os"
	cp -f "$THEME_SRC"/* "$ISO_EXTRACT/boot/grub/themes/group2-os/" 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/../installer/overlay/boot/grub/group2-boot.png" ]; then
	cp -f "$SCRIPT_DIR/../installer/overlay/boot/grub/group2-boot.png" \
		"$ISO_EXTRACT/boot/grub/group2-boot.png"
fi
python3 - "$ISO_EXTRACT" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
normal = (
    "username=group2 hostname=group2-os "
    "quiet splash loglevel=0 systemd.show_status=false"
)
# nomodeset works in VirtualBox, VMware, and other VMs when the screen stays black.
safe = (
    "username=group2 hostname=group2-os "
    "nomodeset quiet splash loglevel=0 systemd.show_status=false"
)
efi_tail = """
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
    exit 1
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
fi
"""
cfg = f"""set timeout=8
set default=0
set timeout_style=menu
if loadfont unicode ; then
  set gfxmode=auto
  insmod all_video
  insmod gfxterm
  insmod png
  terminal_output gfxterm
fi
if [ -f /boot/grub/themes/group2-os/theme.txt ]; then
  insmod gfxmenu
  set theme=/boot/grub/themes/group2-os/theme.txt
elif background_image /boot/grub/group2-boot.png ; then
  set color_normal=white/black
  set color_highlight=black/cyan
else
  set menu_color_normal=white/black
  set menu_color_highlight=black/cyan
fi

menuentry "Try or Install Group 2 OS" {{
    set gfxpayload=keep
    linux  /casper/vmlinuz {normal} ---
    initrd /casper/initrd
}}
menuentry "Group 2 OS (VirtualBox / safe graphics)" {{
    set gfxpayload=keep
    linux  /casper/vmlinuz {safe} ---
    initrd /casper/initrd
}}
{efi_tail}
"""
loop = f"""
menuentry "Try or Install Group 2 OS" {{
    set gfxpayload=keep
    linux  /casper/vmlinuz {normal} ---
    initrd /casper/initrd
}}
menuentry "Group 2 OS (VirtualBox / safe graphics)" {{
    set gfxpayload=keep
    linux  /casper/vmlinuz {safe} ---
    initrd /casper/initrd
}}
"""
changed = 0
for path in root.rglob("*"):
    if not path.is_file():
        continue
    if path.name not in {"grub.cfg", "loopback.cfg"}:
        continue
    text = path.read_text(errors="replace")
    if "/casper/vmlinuz" not in text and path.name == "grub.cfg":
        # Still rewrite our known live menu.
        pass
    new = loop if path.name == "loopback.cfg" else cfg
    if new != text:
        path.write_text(new)
        changed += 1
        print("updated", path)
print("grub files updated:", changed)
PY
