#!/bin/sh
# Restore original Ubuntu initrd, inject Group 2 OS Plymouth, rebuild ISO only.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

WORK="$G2_LINUX_BUILD/laptop-iso"
ISO_EXTRACT="$WORK/iso"
EDIT="$WORK/edit"
BOOTPART="$WORK/bootpart"
SQUASH_DIR="$ISO_EXTRACT/casper"
LINUX_OUT="$G2_LINUX_BUILD/out"
OUT_ISO="$G2_OUT/GROUP2-OS.iso"
ORIG_ISO="$G2_BUILD/iso-cache/ubuntu-26.04.1-desktop-amd64.iso"

echo_step "Restoring original casper initrd"
# Do not append branding here. That made overlay support disappear.
sudo sh "$G2_ROOT/installer/patch-casper-initrd.sh" "$SQUASH_DIR" "$EDIT"

echo_step "Building GROUP2-OS.iso"
LINUX_ISO="$LINUX_OUT/GROUP2-OS.iso"
sudo rm -f "$LINUX_ISO"
sudo xorriso -as mkisofs -r \
	-V "GROUP2_OS" \
	-o "$LINUX_ISO" \
	--grub2-mbr "$BOOTPART/mbr_code_grub2.img" \
	-partition_offset 16 \
	--mbr-force-bootable \
	-append_partition 2 0xef "$BOOTPART/gpt_part2_efi.img" \
	-appended_part_as_gpt \
	-c boot.catalog \
	-b boot/grub/i386-pc/eltorito.img \
	-no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
	-eltorito-alt-boot \
	-e '--interval:appended_partition_2:::' \
	-no-emul-boot \
	"$ISO_EXTRACT"
sudo cp -f "$LINUX_ISO" "$OUT_ISO"
echo " Group 2 OS desktop ISO is ready"
echo "  $OUT_ISO"
