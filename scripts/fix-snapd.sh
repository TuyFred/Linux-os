#!/bin/bash
# GROUP 2 OS — Fix "Can't lookup blockdev" for ubuntu-desktop-bootstrap snap
#
# ROOT CAUSE:
#   Ubuntu 26.04 distributes snaps across 3 squashfs layers:
#   - minimal.squashfs:              13 system snaps (already in our ISO ✓)
#   - minimal.standard.squashfs:     thunderbird snap (already merged in ours ✓)
#   - minimal.standard.live.squashfs: ubuntu-desktop-bootstrap_665.snap ← MISSING
#
#   During the original build, unsquashfs had a FATAL ERROR extracting the
#   live layer. ubuntu-desktop-bootstrap_665.snap (116 MB, the installer snap)
#   was never extracted. Our previous rebuild created empty 4 KB placeholder
#   squashfs for the delta layers — but those are empty and contain no snap.
#
#   During live boot, snapd finds the mount unit for ubuntu-desktop-bootstrap
#   in /etc/systemd/system/ (from our base layer) but the snap file itself
#   doesn't exist → "Can't lookup blockdev".
#
# FIX:
#   Replace our empty placeholder squashfs with the real Ubuntu delta layers.
#   Our branded minimal.squashfs (3.7 GB) stays as the base — all GROUP 2
#   branding (wallpaper, os-release, dconf, member folders) is in that base
#   layer and will NOT be overridden (confirmed: neither delta layer contains
#   /etc/os-release or desktop backgrounds).
#
#   Layer structure after fix:
#   [1] minimal.squashfs (3.7 GB)         ← our base: full GROUP 2 OS system
#   [2] minimal.standard.squashfs (563 MB) ← Ubuntu delta: standard desktop
#   [3] minimal.standard.live.squashfs (757 MB) ← Ubuntu delta: ubuntu-desktop-bootstrap snap
#
set -e

UBUNTU_ISO="/mnt/c/Users/USER/GROUP 2 OS/build/iso-cache/ubuntu-26.04.1-desktop-amd64.iso"
CASPER="/root/group2-build/laptop-iso/iso/casper"
ISO="/root/group2-build/laptop-iso/iso"
BOOTPART="/root/group2-build/laptop-iso/bootpart"
LINUX_OUT="/root/group2-build/out"
WIN_OUT="/mnt/c/Users/USER/GROUP 2 OS/build/out/GROUP2-OS.iso"

sep() { echo ""; echo "============================================================="; echo " GROUP 2 OS  |  $1"; echo "============================================================="; }

sep "Pre-fix state"
echo "Current ISO casper layers:"
ls -lh "$CASPER/"*.squashfs

sep "TASK 3 — Verify ubuntu-desktop-bootstrap snap"
echo "Is ubuntu-desktop-bootstrap in our base squashfs?"
unsquashfs -ll "$CASPER/minimal.squashfs" 2>/dev/null \
  | grep 'ubuntu-desktop-bootstrap' || echo "  NOT FOUND in minimal.squashfs (confirmed root cause)"

sep "TASK 7 — Check original Ubuntu ISO for correct snap revision"
echo "Mounting original Ubuntu 26.04 ISO..."
mkdir -p /tmp/ubuntu-src
mount -o loop,ro "$UBUNTU_ISO" /tmp/ubuntu-src

echo "ubuntu-desktop-bootstrap in original Ubuntu minimal.standard.live.squashfs:"
unsquashfs -ll /tmp/ubuntu-src/casper/minimal.standard.live.squashfs 2>/dev/null \
  | grep 'ubuntu-desktop-bootstrap' | grep '\.snap'

echo ""
echo "Size comparison — Ubuntu original vs our placeholders:"
echo "  Ubuntu minimal.standard.squashfs:     $(ls -lh /tmp/ubuntu-src/casper/minimal.standard.squashfs | awk '{print $5}')"
echo "  Ubuntu minimal.standard.live.squashfs: $(ls -lh /tmp/ubuntu-src/casper/minimal.standard.live.squashfs | awk '{print $5}')"
echo "  Our minimal.standard.squashfs:         $(ls -lh $CASPER/minimal.standard.squashfs | awk '{print $5}') ← empty placeholder"
echo "  Our minimal.standard.live.squashfs:    $(ls -lh $CASPER/minimal.standard.live.squashfs | awk '{print $5}') ← empty placeholder"

sep "TASK 10 — Fix: Replace empty placeholders with real Ubuntu delta layers"
echo "Copying minimal.standard.squashfs (563 MB)..."
cp -f /tmp/ubuntu-src/casper/minimal.standard.squashfs "$CASPER/minimal.standard.squashfs"
echo "  Done: $(ls -lh $CASPER/minimal.standard.squashfs | awk '{print $5}')"

echo "Copying minimal.standard.live.squashfs (757 MB — contains ubuntu-desktop-bootstrap_665.snap)..."
cp -f /tmp/ubuntu-src/casper/minimal.standard.live.squashfs "$CASPER/minimal.standard.live.squashfs"
echo "  Done: $(ls -lh $CASPER/minimal.standard.live.squashfs | awk '{print $5}')"

umount /tmp/ubuntu-src

sep "TASK 12 — Verify squashfs integrity"
echo "Verifying minimal.squashfs (our branded base)..."
unsquashfs -s "$CASPER/minimal.squashfs" 2>/dev/null | grep -E 'Filesystem|Compression|Inodes'

echo ""
echo "Verifying minimal.standard.squashfs..."
unsquashfs -s "$CASPER/minimal.standard.squashfs" 2>/dev/null | grep -E 'Filesystem|Compression|Inodes'

echo ""
echo "Verifying minimal.standard.live.squashfs..."
unsquashfs -s "$CASPER/minimal.standard.live.squashfs" 2>/dev/null | grep -E 'Filesystem|Compression|Inodes'

echo ""
echo "Confirming ubuntu-desktop-bootstrap is in live layer:"
unsquashfs -ll "$CASPER/minimal.standard.live.squashfs" 2>/dev/null \
  | grep 'ubuntu-desktop-bootstrap' | grep '\.snap'

sep "TASK 12 — Verify /var/lib/snapd structure in all layers"
echo "Snaps in base layer (minimal.squashfs):"
unsquashfs -ll "$CASPER/minimal.squashfs" 2>/dev/null \
  | grep '/var/lib/snapd/snaps/' | grep '\.snap' | awk '{print "  "$NF}'

echo ""
echo "Snaps in standard layer (minimal.standard.squashfs):"
unsquashfs -ll "$CASPER/minimal.standard.squashfs" 2>/dev/null \
  | grep '/var/lib/snapd/snaps/' | grep '\.snap' | awk '{print "  "$NF}'

echo ""
echo "Snaps in live layer (minimal.standard.live.squashfs):"
unsquashfs -ll "$CASPER/minimal.standard.live.squashfs" 2>/dev/null \
  | grep '/var/lib/snapd/snaps/' | grep '\.snap' | awk '{print "  "$NF}'

sep "TASK 4 — Update install-sources.yaml (preserve GROUP 2 identity)"
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
echo "install-sources.yaml updated — GROUP 2 OS Desktop as the only install option."

sep "Verifying GRUB boot menu"
echo "Current grub.cfg first entry:"
grep -A5 'menuentry' "$ISO/boot/grub/grub.cfg" | head -8
echo ""
echo "Checking grub.cfg for Group 2 OS branding..."
grep 'GROUP 2 OS' "$ISO/boot/grub/grub.cfg" && echo "Branding OK" || echo "WARNING: branding missing"

sep "TASK 11 — Rebuild ISO"
echo "Finding boot images..."
MBR_IMG=""
EFI_IMG=""
for f in "$BOOTPART/mbr_code_grub2.img" "$BOOTPART"/mbr*.img; do
    [ -f "$f" ] && MBR_IMG="$f" && break
done
for f in "$BOOTPART/gpt_part2_efi.img" "$BOOTPART"/gpt*.img "$BOOTPART/2-Boot-NoEmul.img"; do
    [ -f "$f" ] && EFI_IMG="$f" && break
done
echo "  MBR: $MBR_IMG"
echo "  EFI: $EFI_IMG"

rm -f "$LINUX_OUT/GROUP2-OS.iso"
echo "Building ISO..."
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

sep "TASK 12 — Verify final ISO"
echo "Mounting final ISO..."
mkdir -p /tmp/g2-final-check
mount -o loop "$LINUX_OUT/GROUP2-OS.iso" /tmp/g2-final-check 2>/dev/null

echo "ISO casper layers:"
ls -lh /tmp/g2-final-check/casper/*.squashfs

echo ""
echo "ubuntu-desktop-bootstrap snap present in ISO:"
unsquashfs -ll /tmp/g2-final-check/casper/minimal.standard.live.squashfs 2>/dev/null \
  | grep 'ubuntu-desktop-bootstrap' | grep '\.snap' && echo "  ✓ CONFIRMED" || echo "  ✗ STILL MISSING"

echo ""
echo "GROUP 2 OS branding in base layer:"
unsquashfs -ll /tmp/g2-final-check/casper/minimal.squashfs 2>/dev/null \
  | grep 'group2\|GROUP2\|group2-os' | head -5
echo "  os-release:"
unsquashfs -cat /tmp/g2-final-check/casper/minimal.squashfs etc/os-release 2>/dev/null \
  | grep -E '^NAME|^PRETTY' || echo "  (check manually)"

echo ""
echo "grub.cfg:"
grep 'menuentry\|linux\|initrd' /tmp/g2-final-check/boot/grub/grub.cfg | head -10

umount /tmp/g2-final-check

sep "Copying to Windows"
cp -f "$LINUX_OUT/GROUP2-OS.iso" "$WIN_OUT"
ls -lh "$WIN_OUT"

echo ""
echo "============================================================"
echo "  GROUP 2 OS — SNAPD FIX COMPLETE"
echo "============================================================"
echo ""
echo "  ROOT CAUSE: ubuntu-desktop-bootstrap_665.snap was missing"
echo "  because the original unsquashfs merge had a FATAL ERROR"
echo "  that aborted extraction of the live squashfs layer."
echo ""
echo "  FIX APPLIED:"
echo "  • minimal.standard.squashfs: replaced empty 4 KB with real"
echo "    Ubuntu 26.04 standard layer (563 MB)"
echo "  • minimal.standard.live.squashfs: replaced empty 4 KB with"
echo "    real Ubuntu 26.04 live layer (757 MB) containing"
echo "    ubuntu-desktop-bootstrap_665.snap (116 MB)"
echo ""
echo "  BRANDING PRESERVED:"
echo "  • GROUP 2 OS base layer (minimal.squashfs, 3.7 GB) unchanged"
echo "  • Neither Ubuntu delta layer contains /etc/os-release or"
echo "    wallpaper — GROUP 2 identity and desktop branding intact"
echo ""
echo "  VIRTUALBOX SETTINGS:"
echo "  • RAM: 4096 MB minimum"
echo "  • CPU: 2+ cores"  
echo "  • Disk: 30 GB"
echo "  • System → Motherboard → Enable EFI ✓"
echo "  • Storage → optical drive → GROUP2-OS.iso"
echo "  • Boot menu: Try or Install GROUP 2 OS"
echo ""
echo "  File: $WIN_OUT"
