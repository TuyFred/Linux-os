#!/bin/bash
set -e
ISO="/root/group2-build/out/GROUP2-OS.iso"
MNT="/tmp/g2v2"
mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount -o loop,ro "$ISO" "$MNT"

echo "=== ISO size ==="
ls -lh /mnt/c/Users/USER/GROUP\ 2\ OS/build/out/GROUP2-OS.iso

echo "=== required squashfs layers ==="
ls -lh "$MNT"/casper/minimal.squashfs "$MNT"/casper/minimal.standard.squashfs "$MNT"/casper/minimal.standard.live.squashfs "$MNT"/casper/initrd "$MNT"/casper/vmlinuz

echo "=== grub first lines ==="
head -n 20 "$MNT"/boot/grub/grub.cfg

echo "=== plymouth files in live layer ==="
unsquashfs -ll "$MNT"/casper/minimal.standard.live.squashfs 2>/dev/null \
  | grep -E "plymouth/themes/group2-os/|os-release|group2-os-login|group2-os-desktop|ubuntu-desktop-bootstrap_665" \
  | awk '{print $NF}'

echo "=== plymouth script has refresh (real bar) ==="
unsquashfs -cat "$MNT"/casper/minimal.standard.live.squashfs usr/share/plymouth/themes/group2-os/group2-os.script 2>/dev/null \
  | grep -E "SetRefreshFunction|Loading system|Image.Text" | head

echo "=== os-release ==="
unsquashfs -cat "$MNT"/casper/minimal.standard.live.squashfs usr/lib/os-release 2>/dev/null | head -3

echo "=== initrd file type ==="
file "$MNT"/casper/initrd

umount "$MNT"
echo "VERIFY_OK"
