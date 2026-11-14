#!/bin/bash
# GROUP 2 OS — Definitive ISO Rebuild
# Fixes: Ubuntu 26.04 casper requires 3 separate squashfs layers (fsimage-layered).
# Our existing minimal.squashfs (3.7 GB, full branded system) is kept as the base.
# Two thin overlay squashfs files are created for the missing layers.
set -e

BUILD="/root/group2-build"
CASPER="$BUILD/laptop-iso/iso/casper"
ISO="$BUILD/laptop-iso/iso"
BOOTPART="$BUILD/laptop-iso/bootpart"
LINUX_OUT="$BUILD/out"
WIN_OUT="/mnt/c/Users/USER/GROUP 2 OS/build/out/GROUP2-OS.iso"
G2_ROOT="/mnt/c/Users/USER/GROUP 2 OS"
G2_BRANDING="$G2_ROOT/branding"

sep() { echo ""; echo "============================================================"; echo " GROUP 2 OS  |  $1"; echo "============================================================"; }

mkdir -p "$LINUX_OUT"

sep "DIAGNOSIS"
echo "Current casper directory:"
ls -lh "$CASPER/"*.squashfs 2>/dev/null || echo "(no squashfs files)"
echo ""
echo "Required layers for Ubuntu 26.04 casper (fsimage-layered):"
echo "  [1] minimal.squashfs             — base system layer"
echo "  [2] minimal.standard.squashfs    — standard desktop layer"
echo "  [3] minimal.standard.live.squashfs — live session layer"
echo ""
echo "install-sources.yaml type: fsimage-layered"
echo "  -> casper REQUIRES all parent layers to exist"
echo "  -> missing layers cause BusyBox dropin"

sep "Step 1: Verify base layer (minimal.squashfs)"
if [ ! -f "$CASPER/minimal.squashfs" ]; then
    echo "ERROR: minimal.squashfs is missing! Cannot continue."
    exit 1
fi
SQUASH_SIZE=$(du -sh "$CASPER/minimal.squashfs" | cut -f1)
echo "OK: minimal.squashfs exists ($SQUASH_SIZE) — our full GROUP 2 OS system"
echo "Verifying squashfs integrity..."
unsquashfs -s "$CASPER/minimal.squashfs" > /tmp/squash-info.txt 2>&1
grep -E "^(Filesystem|Inodes|Block|Compression)" /tmp/squash-info.txt || true
echo "Squashfs is valid."

sep "Step 2: Create missing overlay layers"
# These are thin squashfs layers that sit on top of minimal.squashfs in overlayfs.
# They are intentionally sparse — casper needs them to EXIST to resolve the layer
# chain defined in install-sources.yaml (fsimage-layered type).
# An empty upper overlayfs layer is fully valid and contributes nothing,
# allowing the full GROUP 2 OS system from minimal.squashfs to show through.

OVERLAY_WORK="/tmp/g2-overlay-layer"
rm -rf "$OVERLAY_WORK"
mkdir -p "$OVERLAY_WORK/etc"

# Write a GROUP 2 identity marker into each overlay layer
cat > "$OVERLAY_WORK/etc/group2-layer" << 'EOF'
GROUP 2 OS — Linux | LEARN • BUILD • CREATE • TOGETHER
This overlay layer is part of the GROUP 2 OS fsimage-layered structure.
Base system lives in minimal.squashfs.
EOF

# Layer 2: minimal.standard.squashfs
if [ ! -f "$CASPER/minimal.standard.squashfs" ]; then
    echo "Creating minimal.standard.squashfs overlay layer..."
    mksquashfs "$OVERLAY_WORK" "$CASPER/minimal.standard.squashfs" \
        -noappend -comp xz -no-progress 2>/dev/null
    echo "  OK: $(du -sh $CASPER/minimal.standard.squashfs)"
else
    echo "OK: minimal.standard.squashfs already exists"
fi

# Layer 3: minimal.standard.live.squashfs  
LIVE_WORK="/tmp/g2-live-layer"
rm -rf "$LIVE_WORK"
mkdir -p "$LIVE_WORK/etc"

cat > "$LIVE_WORK/etc/group2-live-layer" << 'EOF'
GROUP 2 OS — Live Session Layer
LEARN • BUILD • CREATE • TOGETHER
EOF

if [ ! -f "$CASPER/minimal.standard.live.squashfs" ]; then
    echo "Creating minimal.standard.live.squashfs overlay layer..."
    mksquashfs "$LIVE_WORK" "$CASPER/minimal.standard.live.squashfs" \
        -noappend -comp xz -no-progress 2>/dev/null
    echo "  OK: $(du -sh $CASPER/minimal.standard.live.squashfs)"
else
    echo "OK: minimal.standard.live.squashfs already exists"
fi

sep "Step 3: Update install-sources.yaml"
# Update sizes to match our actual squashfs
SQUASH_BYTES=$(du -sb "$CASPER/minimal.squashfs" | cut -f1)
cat > "$ISO/casper/install-sources.yaml" << YAML
kernel:
  default: linux-generic-hwe-24.04
sources:
- default: true
  description:
    en: GROUP 2 OS Desktop — LEARN BUILD CREATE TOGETHER
  id: group2-os-desktop
  locale_support: langpack
  name:
    en: GROUP 2 OS Desktop
  path: minimal.squashfs
  size: ${SQUASH_BYTES}
  type: fsimage-layered
  variant: desktop
  variations:
    minimal:
      path: minimal.squashfs
      size: ${SQUASH_BYTES}
version: 2
YAML
echo "install-sources.yaml updated with GROUP 2 OS identity and correct layer path."

sep "Step 4: Verify all 3 squashfs layers"
ALL_OK=true
for sq in minimal.squashfs minimal.standard.squashfs minimal.standard.live.squashfs; do
    if [ -f "$CASPER/$sq" ]; then
        SIZE=$(du -sh "$CASPER/$sq" | cut -f1)
        echo "  [OK] $sq  ($SIZE)"
    else
        echo "  [MISSING] $sq"
        ALL_OK=false
    fi
done
if [ "$ALL_OK" = false ]; then
    echo "ERROR: One or more squashfs files are missing. Cannot continue."
    exit 1
fi

sep "Step 5: Update filesystem manifests"
# Update filesystem.size with the correct byte count of the full system
du -sx --block-size=1 / 2>/dev/null | cut -f1 | tee "$CASPER/filesystem.size" >/dev/null || \
    echo "$SQUASH_BYTES" > "$CASPER/filesystem.size"
echo "filesystem.size updated."

sep "Step 6: Fix GRUB boot menu"
for grub in \
    "$ISO/boot/grub/grub.cfg" \
    "$ISO/EFI/boot/grub.cfg" \
    "$ISO/boot/grub/loopback.cfg"
do
    [ -f "$grub" ] || continue
    # Remove any incorrect layerfs-path (casper discovers layers from install-sources.yaml)
    sed -i 's| layerfs-path=[^ "]*||g' "$grub"
    # Ensure GROUP 2 OS branding in menu
    sed -i 's|Try or Install Ubuntu|Try or Install GROUP 2 OS|g' "$grub"
    sed -i 's|Install Ubuntu|Install GROUP 2 OS|g' "$grub"
    sed -i 's|Ubuntu (safe graphics)|GROUP 2 OS (safe graphics)|g' "$grub"
    sed -i 's|menuentry "Ubuntu"|menuentry "GROUP 2 OS"|g' "$grub"
    echo "  Fixed: $grub"
done

# Show what the grub.cfg looks like now
echo ""
echo "grub.cfg (first menuentry):"
grep -A4 'menuentry' "$ISO/boot/grub/grub.cfg" | head -10

sep "Step 7: Rebuild GROUP2-OS.iso"
echo "Finding boot images..."
MBR_IMG=""
EFI_IMG=""
for f in "$BOOTPART/mbr_code_grub2.img" "$BOOTPART/mbr_code.img" "$BOOTPART"/mbr*.img; do
    [ -f "$f" ] && MBR_IMG="$f" && break
done
for f in "$BOOTPART/gpt_part2_efi.img" "$BOOTPART/2-Boot-NoEmul.img" "$BOOTPART"/gpt*.img; do
    [ -f "$f" ] && EFI_IMG="$f" && break
done

if [ -z "$MBR_IMG" ] || [ -z "$EFI_IMG" ]; then
    echo "Available boot images:"
    ls "$BOOTPART/"
    echo "ERROR: Cannot find MBR or EFI boot images."
    exit 1
fi
echo "  MBR: $MBR_IMG"
echo "  EFI: $EFI_IMG"

rm -f "$LINUX_OUT/GROUP2-OS.iso"
echo "Building ISO (xorriso)..."
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

sep "Step 8: Verify ISO contents"
echo "Mounting ISO to verify casper layer structure..."
mkdir -p /tmp/g2-verify
mount -o loop "$LINUX_OUT/GROUP2-OS.iso" /tmp/g2-verify 2>/dev/null || \
    mount -o loop,ro "$LINUX_OUT/GROUP2-OS.iso" /tmp/g2-verify

echo "ISO casper directory:"
ls -lh /tmp/g2-verify/casper/*.squashfs 2>/dev/null
echo ""
echo "grub.cfg in ISO:"
grep -A3 'menuentry' /tmp/g2-verify/boot/grub/grub.cfg | head -10
echo ""
echo "install-sources.yaml in ISO:"
head -10 /tmp/g2-verify/casper/install-sources.yaml
umount /tmp/g2-verify

sep "Step 9: Copy to Windows"
cp -f "$LINUX_OUT/GROUP2-OS.iso" "$WIN_OUT"
ls -lh "$WIN_OUT"

echo ""
echo "============================================================"
echo "  GROUP 2 OS — FIXED ISO IS READY"
echo "============================================================"
echo ""
echo "  File: $WIN_OUT"
echo ""
echo "  Layer structure (correct for Ubuntu 26.04 casper):"
echo "  [1] minimal.squashfs             → GROUP 2 OS full system"
echo "  [2] minimal.standard.squashfs    → thin GROUP 2 overlay"
echo "  [3] minimal.standard.live.squashfs → thin live overlay"
echo ""
echo "  In VirtualBox: Settings → System → Enable EFI → Start"
echo "  Choose: Try or Install GROUP 2 OS"
echo ""
echo "  WHY THIS FAILED BEFORE:"
echo "  The previous build merged all layers into ONE minimal.squashfs"
echo "  and deleted minimal.standard.squashfs + minimal.standard.live.squashfs."
echo "  Ubuntu 26.04 casper (fsimage-layered) requires ALL 3 layers to exist."
echo "  Without them, casper drops into the BusyBox emergency shell."
echo ""
echo "  WHAT WAS FIXED:"
echo "  - Created minimal.standard.squashfs (required overlay layer)"
echo "  - Created minimal.standard.live.squashfs (required live layer)"
echo "  - Updated install-sources.yaml with GROUP 2 OS identity"
echo "  - Verified full 3-layer squashfs chain in rebuilt ISO"
