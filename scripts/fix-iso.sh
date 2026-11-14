#!/bin/bash
# Fix GROUP2-OS.iso: rename squashfs to minimal.squashfs, fix grub, rebuild ISO.
set -e

CASPER="/root/group2-build/laptop-iso/iso/casper"
ISO="/root/group2-build/laptop-iso/iso"
BOOTPART="/root/group2-build/laptop-iso/bootpart"
LINUX_OUT="/root/group2-build/out"
WIN_OUT="/mnt/c/Users/USER/GROUP 2 OS/build/out/GROUP2-OS.iso"

mkdir -p "$LINUX_OUT"

echo ""
echo "============================================================"
echo " GROUP 2 OS  |  Step 1: Fix squashfs filename"
echo "============================================================"
if [ -f "$CASPER/filesystem.squashfs" ] && [ ! -f "$CASPER/minimal.squashfs" ]; then
    mv "$CASPER/filesystem.squashfs" "$CASPER/minimal.squashfs"
    echo "Renamed: filesystem.squashfs -> minimal.squashfs"
elif [ -f "$CASPER/minimal.squashfs" ]; then
    echo "OK: minimal.squashfs already exists"
else
    echo "ERROR: No squashfs found in $CASPER"
    ls "$CASPER/"
    exit 1
fi
ls -lh "$CASPER/"*.squashfs

echo ""
echo "============================================================"
echo " GROUP 2 OS  |  Step 2: Fix boot menu (grub)"
echo "============================================================"
for grub in \
    "$ISO/boot/grub/grub.cfg" \
    "$ISO/EFI/boot/grub.cfg" \
    "$ISO/boot/grub/loopback.cfg"
do
    [ -f "$grub" ] || continue
    sed -i 's|layerfs-path=[^ "]*|layerfs-path=minimal.squashfs|g' "$grub"
    sed -i 's|Try or Install Ubuntu|Try or Install GROUP 2 OS|g' "$grub"
    sed -i 's|Install Ubuntu|Install GROUP 2 OS|g' "$grub"
    sed -i 's|Ubuntu (safe graphics)|GROUP 2 OS (safe graphics)|g' "$grub"
    echo "Fixed: $grub"
done

echo ""
echo "============================================================"
echo " GROUP 2 OS  |  Step 3: Rebuild ISO"
echo "============================================================"
MBR_IMG=""
EFI_IMG=""
for f in "$BOOTPART/mbr_code_grub2.img" "$BOOTPART/mbr_code.img"; do
    [ -f "$f" ] && MBR_IMG="$f" && break
done
for f in "$BOOTPART/gpt_part2_efi.img" "$BOOTPART/2-Boot-NoEmul.img"; do
    [ -f "$f" ] && EFI_IMG="$f" && break
done

if [ -z "$MBR_IMG" ] || [ -z "$EFI_IMG" ]; then
    echo "Boot images:"
    ls "$BOOTPART/"
    echo "ERROR: Could not find MBR or EFI boot images"
    exit 1
fi
echo "MBR: $MBR_IMG"
echo "EFI: $EFI_IMG"

rm -f "$LINUX_OUT/GROUP2-OS.iso"
xorriso -as mkisofs -r \
    -V "GROUP2_OS" \
    -o "$LINUX_OUT/GROUP2-OS.iso" \
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
    "$ISO"

echo ""
echo "============================================================"
echo " GROUP 2 OS  |  Step 4: Copy to Windows"
echo "============================================================"
cp -f "$LINUX_OUT/GROUP2-OS.iso" "$WIN_OUT"
ls -lh "$WIN_OUT"

echo ""
echo "============================================================"
echo " GROUP 2 OS laptop image is ready (FIXED)"
echo "============================================================"
echo "  $WIN_OUT"
echo ""
echo "Flash to USB with Rufus, then boot the other laptop."
