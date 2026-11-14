#!/bin/sh
# Make the live ISO start and run faster without removing hardware support.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

WORK="$G2_LINUX_BUILD/laptop-iso"
ISO_EXTRACT="$WORK/iso"
SQUASH_DIR="$ISO_EXTRACT/casper"
BOOTPART="$WORK/bootpart"
LINUX_OUT="$G2_LINUX_BUILD/out"
OUT_ISO="$G2_OUT/GROUP2-OS.iso"

fast_pack() {
	src=$1
	dest=$2
	echo "  packing $(basename "$dest") with fast zstd"
	sudo mksquashfs "$src" "$dest" -comp zstd -Xcompression-level 1 -b 1M -noappend -no-progress
}

echo_step "Turning off the slow full-ISO check"
LIVE_EDIT="$WORK/edit"
if [ ! -f "$LIVE_EDIT/usr/share/backgrounds/group2-os-desktop.png" ]; then
	sudo rm -rf "$LIVE_EDIT"
	sudo unsquashfs -d "$LIVE_EDIT" "$SQUASH_DIR/minimal.standard.live.squashfs"
fi
sudo mkdir -p "$LIVE_EDIT/etc/systemd/system"
sudo ln -sfn /dev/null "$LIVE_EDIT/etc/systemd/system/casper-md5check.service"
sudo rm -f "$LIVE_EDIT/etc/systemd/system/multi-user.target.wants/casper-md5check.service"
LIVE_NEW="$WORK/live.zstd.squashfs"
sudo rm -f "$LIVE_NEW"
fast_pack "$LIVE_EDIT" "$LIVE_NEW"
sudo mv -f "$LIVE_NEW" "$SQUASH_DIR/minimal.standard.live.squashfs"

echo_step "Repacking desktop layer for faster reading"
STD_EDIT="$WORK/standard-edit"
if [ ! -f "$STD_EDIT/usr/share/backgrounds/group2-os-desktop.png" ]; then
	sudo rm -rf "$STD_EDIT"
	sudo unsquashfs -d "$STD_EDIT" "$SQUASH_DIR/minimal.standard.squashfs"
fi
STD_NEW="$WORK/standard.zstd.squashfs"
sudo rm -f "$STD_NEW"
fast_pack "$STD_EDIT" "$STD_NEW"
sudo mv -f "$STD_NEW" "$SQUASH_DIR/minimal.standard.squashfs"

echo_step "Repacking base system for faster reading"
MIN_EDIT="$WORK/minimal-edit"
sudo rm -rf "$MIN_EDIT"
sudo unsquashfs -d "$MIN_EDIT" "$SQUASH_DIR/minimal.squashfs"
MIN_NEW="$WORK/minimal.zstd.squashfs"
sudo rm -f "$MIN_NEW"
fast_pack "$MIN_EDIT" "$MIN_NEW"
sudo mv -f "$MIN_NEW" "$SQUASH_DIR/minimal.squashfs"
sudo rm -rf "$MIN_EDIT"

if [ -f "$ISO_EXTRACT/boot/grub/grub.cfg" ]; then
	sudo sed -i 's/^set timeout=.*/set timeout=1/' "$ISO_EXTRACT/boot/grub/grub.cfg"
	sudo sed -i 's|quiet splash loglevel=0|quiet splash loglevel=0 mitigations=off|' \
		"$ISO_EXTRACT/boot/grub/grub.cfg" || true
fi
# mitigations=off makes a school demo faster but weakens security. Keep it off.
sudo sed -i 's|mitigations=off||g' "$ISO_EXTRACT/boot/grub/grub.cfg" || true
if [ -f "$ISO_EXTRACT/md5sum.txt" ]; then
	sudo rm -f "$ISO_EXTRACT/md5sum.txt"
fi

echo_step "Building faster GROUP2-OS.iso"
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
echo
echo "============================================================"
echo " Faster Group 2 OS ISO is ready"
echo "============================================================"
echo "  $OUT_ISO"
