#!/bin/bash
set -eu
ISO="/root/group2-build/out/GROUP2-OS.iso"
MNT="/tmp/g2audit"
mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount -o loop,ro "$ISO" "$MNT"
echo "=== layers ==="
unsquashfs -s "$MNT/casper/minimal.squashfs" | grep -E 'Compression|Filesystem size'
unsquashfs -s "$MNT/casper/minimal.standard.squashfs" | grep -E 'Compression|Filesystem size'
unsquashfs -s "$MNT/casper/minimal.standard.live.squashfs" | grep -E 'Compression|Filesystem size'
echo "=== install-sources.yaml ==="
sed -n '1,80p' "$MNT/casper/install-sources.yaml"
echo "=== grub ==="
grep -E 'timeout=|menuentry|linux ' "$MNT/boot/grub/grub.cfg" | head -8
echo "=== initrd os-release + zstd module ==="
rm -rf /tmp/g2ird && unmkinitramfs "$MNT/casper/initrd" /tmp/g2ird >/dev/null
grep -E '^NAME=|^PRETTY' /tmp/g2ird/etc/os-release || true
find /tmp/g2ird -name '*zstd*' -o -name 'squashfs.ko*' | head -20
echo "=== installed branding ==="
unsquashfs -ll "$MNT/casper/minimal.standard.squashfs" 2>/dev/null | grep -E 'group2-os-desktop.png|etc/os-release|gdm3/custom.conf|plymouthd.conf' | awk '{print $NF}'
echo "=== installer snap ==="
unsquashfs -ll "$MNT/casper/minimal.standard.live.squashfs" 2>/dev/null | grep ubuntu-desktop-bootstrap_665.snap | head -1
echo "=== md5check mask ==="
unsquashfs -ll "$MNT/casper/minimal.standard.live.squashfs" 2>/dev/null | grep casper-md5check | head
umount "$MNT"
echo AUDIT_OK
