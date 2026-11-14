#!/bin/sh
# Create a bootable GROUP2-OS.iso using GRUB.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

echo_step "Creating GROUP2-OS.iso"

if [ ! -f "$G2_OUT/vmlinuz" ]; then
	echo "Kernel is missing. Run scripts/02-build-kernel.sh first."
	exit 1
fi
if [ ! -f "$G2_OUT/initramfs.cpio.gz" ]; then
	echo "Initramfs is missing. Run scripts/04-make-rootfs.sh first."
	exit 1
fi

rm -rf "$G2_ISO_ROOT"
mkdir -p "$G2_ISO_ROOT/boot/grub"
cp -a "$G2_ISO_OVERLAY"/. "$G2_ISO_ROOT"/
cp -f "$G2_OUT/vmlinuz" "$G2_ISO_ROOT/boot/vmlinuz"
cp -f "$G2_OUT/initramfs.cpio.gz" "$G2_ISO_ROOT/boot/initramfs.cpio.gz"
cp -f "$G2_BRANDING/wallpaper.jpg" "$G2_ISO_ROOT/boot/wallpaper.jpg" 2>/dev/null || true

if ! command -v grub-mkrescue >/dev/null 2>&1; then
	echo "grub-mkrescue is not installed. Run scripts/01-install-deps.sh"
	exit 1
fi

grub-mkrescue -o "$G2_ISO" "$G2_ISO_ROOT" \
	-- -volid "GROUP2_OS"

echo
echo "Bootable image ready:"
echo "  $G2_ISO"
echo
echo "Test with:"
echo "  qemu-system-x86_64 -m 1024 -cdrom \"$G2_ISO\" -boot d"
echo
echo "Or copy GROUP2-OS.iso to a USB tool (Rufus, balenaEtcher) and boot a laptop."
