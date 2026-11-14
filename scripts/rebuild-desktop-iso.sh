#!/bin/sh
# Rebuild GROUP2-OS.iso after desktop branding changes.
# Reuses the already-extracted Ubuntu ISO when present.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

WORK="$G2_LINUX_BUILD/laptop-iso"
ISO_EXTRACT="$WORK/iso"
EDIT="$WORK/edit"
BOOTPART="$WORK/bootpart"
LINUX_OUT="$G2_LINUX_BUILD/out"
OUT_ISO="$G2_OUT/GROUP2-OS.iso"
SQUASH_DIR="$ISO_EXTRACT/casper"
LIVE_SQUASH="$SQUASH_DIR/minimal.standard.live.squashfs"

if [ ! -f "$LIVE_SQUASH" ]; then
	echo "Extracted ISO not found. Running the full laptop ISO build."
	exec sh "$G2_ROOT/scripts/06-make-laptop-iso.sh"
fi

echo_step "Preparing real Group 2 OS screens"
# Login uses the night-lake picture only. GDM draws the real password box.
python3 - <<'PY'
from pathlib import Path
from PIL import Image
src = Path("/mnt/c/Users/USER/.cursor/projects/c-Users-USER-GROUP-2-OS/assets/group2-login-background.png")
dest = Path("/mnt/c/Users/USER/GROUP 2 OS/branding/login-background.png")
if src.is_file():
    im = Image.open(src).convert("RGB")
    tw, th = 1920, 1080
    scale = max(tw / im.width, th / im.height)
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.Resampling.LANCZOS)
    left = (im.width - tw) // 2
    top = (im.height - th) // 2
    im.crop((left, top, left + tw, top + th)).save(dest, "PNG", optimize=True)
    print("login background", dest)
PY
python3 "$G2_ROOT/scripts/make-plymouth-assets.py" || true

echo_step "Applying real Group 2 OS desktop"
if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get install -y libglib2.0-bin libglib2.0-dev-bin initramfs-tools-core cpio gzip >/dev/null 2>&1 || true
fi
sudo rm -rf "$EDIT"
sudo mkdir -p "$EDIT"
sudo unsquashfs -d "$EDIT" "$LIVE_SQUASH"
sudo sh "$G2_ROOT/installer/apply-branding.sh" "$EDIT"
if command -v dconf >/dev/null 2>&1; then
	sudo dconf compile "$EDIT/etc/dconf/db/local" "$EDIT/etc/dconf/db/local.d"
	sudo dconf compile "$EDIT/etc/dconf/db/gdm" "$EDIT/etc/dconf/db/gdm.d"
fi
sudo sh "$G2_ROOT/installer/patch-gdm-theme.sh" "$EDIT" "$SQUASH_DIR/minimal.squashfs" || true
# Never rewrite this file. A changed initrd drops overlay support and
# boot stops in BusyBox.
sudo sh "$G2_ROOT/installer/patch-casper-initrd.sh" "$SQUASH_DIR" "$EDIT"

echo_step "Repacking live overlay"
NEW_LIVE="$WORK/minimal.standard.live.squashfs.new"
sudo rm -f "$NEW_LIVE"
sudo mksquashfs "$EDIT" "$NEW_LIVE" -comp zstd -Xcompression-level 1 -b 1M -noappend -no-progress
sudo mv -f "$NEW_LIVE" "$LIVE_SQUASH"

echo_step "Branding the system that gets installed on a laptop"
sudo sh "$G2_ROOT/scripts/brand-install-layer.sh"

if [ -f "$ISO_EXTRACT/boot/grub/grub.cfg" ]; then
	sudo mkdir -p "$ISO_EXTRACT/boot/grub"
	if [ -f "$G2_BRANDING/grub-background.png" ]; then
		sudo cp -f "$G2_BRANDING/grub-background.png" "$ISO_EXTRACT/boot/grub/group2-boot.png"
	fi
	# Remove any leftover fake loading screenshot from GRUB.
	sudo sed -i '/background_image \/boot\/grub\/group2-boot.png/d' "$ISO_EXTRACT/boot/grub/grub.cfg"
	sudo sed -i '/^insmod png$/d;/^insmod all_video$/d;/^insmod gfxterm$/d;/^terminal_output gfxterm$/d;/^set gfxpayload=keep$/d;/^set timeout=/d' "$ISO_EXTRACT/boot/grub/grub.cfg"
	sudo sed -i '1i set timeout=1\nset timeout_style=menu\nset menu_color_normal=white/black\nset menu_color_highlight=black/light-cyan' \
		"$ISO_EXTRACT/boot/grub/grub.cfg"
	sh "$G2_ROOT/scripts/patch-grub-cmdline.sh" "$ISO_EXTRACT"
fi
echo "Group 2 OS 1.0 - Release amd64 ($(date +%Y%m%d))" | sudo tee "$ISO_EXTRACT/.disk/info" >/dev/null
# The installer must copy the branded layer, not the plain Ubuntu layer.
sudo cp -f "$G2_ROOT/installer/overlay/casper/install-sources.yaml" \
	"$ISO_EXTRACT/casper/install-sources.yaml"

echo_step "Building GROUP2-OS.iso"
MBR_IMG="$BOOTPART/mbr_code_grub2.img"
EFI_IMG="$BOOTPART/gpt_part2_efi.img"
LINUX_ISO="$LINUX_OUT/GROUP2-OS.iso"
sudo rm -f "$LINUX_ISO"
sudo xorriso -as mkisofs -r \
	-V "GROUP2_OS" \
	-o "$LINUX_ISO" \
	--grub2-mbr "$MBR_IMG" \
	-partition_offset 16 \
	--mbr-force-bootable \
	-append_partition 2 0xef "$EFI_IMG" \
	-appended_part_as_gpt \
	-c boot.catalog \
	-b boot/grub/i386-pc/eltorito.img \
	-no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
	-eltorito-alt-boot \
	-e '--interval:appended_partition_2:::' \
	-no-emul-boot \
	"$ISO_EXTRACT"

sudo cp -f "$LINUX_ISO" "$OUT_ISO"
sudo chmod 644 "$OUT_ISO" 2>/dev/null || true
echo
echo "============================================================"
echo " Group 2 OS desktop ISO is ready"
echo "============================================================"
echo "  $OUT_ISO"
