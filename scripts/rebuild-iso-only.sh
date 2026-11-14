#!/bin/sh
# Rebuild the ISO after installer metadata changes. Does not unpack squashfs.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

WORK="$G2_LINUX_BUILD/laptop-iso"
ISO_EXTRACT="$WORK/iso"
BOOTPART="$WORK/bootpart"
LINUX_ISO="$G2_LINUX_BUILD/out/GROUP2-OS.iso"
OUT_ISO="$G2_OUT/GROUP2-OS.iso"

sudo cp -f "$G2_ROOT/installer/overlay/casper/install-sources.yaml" \
	"$ISO_EXTRACT/casper/install-sources.yaml"
sh "$G2_ROOT/scripts/patch-grub-cmdline.sh" "$ISO_EXTRACT"
echo "Group 2 OS 1.0 - Release amd64 ($(date +%Y%m%d))" | sudo tee "$ISO_EXTRACT/.disk/info" >/dev/null

echo_step "Building GROUP2-OS.iso"
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
echo "Group 2 OS desktop ISO is ready"
echo "  $OUT_ISO"
