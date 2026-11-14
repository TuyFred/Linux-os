#!/bin/bash
set -e
ISO="/root/group2-build/out/GROUP2-OS.iso"
MNT="/tmp/g2v"
mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount -o loop,ro "$ISO" "$MNT"
echo "=== casper squashfs ==="
ls -lh "$MNT"/casper/*.squashfs
echo "=== grub menu ==="
grep -E "menuentry|background" "$MNT"/boot/grub/grub.cfg | head -12
echo "=== live layer branding files ==="
unsquashfs -ll "$MNT"/casper/minimal.standard.live.squashfs 2>/dev/null \
  | grep -E "group2-os-desktop|group2-os-login|plymouth/themes/group2|gtk-4.0/gtk.css|folder-fred|os-release" \
  | head -30
echo "=== os-release ==="
unsquashfs -cat "$MNT"/casper/minimal.standard.live.squashfs usr/lib/os-release 2>/dev/null | head -8
echo "=== installer snap ==="
unsquashfs -ll "$MNT"/casper/minimal.standard.live.squashfs 2>/dev/null | grep "ubuntu-desktop-bootstrap_665.snap"
umount "$MNT"
echo "VERIFY_OK"
