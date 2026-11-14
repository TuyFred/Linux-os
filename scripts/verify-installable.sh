#!/bin/bash
set -e
ISO="/root/group2-build/out/GROUP2-OS.iso"
MNT="/tmp/g2inst"
mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount -o loop,ro "$ISO" "$MNT"
LIVE="$MNT/casper/minimal.standard.live.squashfs"
STD="$MNT/casper/minimal.standard.squashfs"
MIN="$MNT/casper/minimal.squashfs"

echo "=== installed system identity ==="
unsquashfs -cat "$STD" etc/os-release 2>/dev/null | head -4
echo "=== wallpaper and login on installed layer ==="
unsquashfs -ll "$STD" 2>/dev/null | grep -E 'group2-os-desktop.png|group2-os-login.png|gdm3/custom.conf|group2-desktop-setup' | awk '{print $NF}'
echo "=== no automatic login ==="
unsquashfs -cat "$STD" etc/gdm3/custom.conf 2>/dev/null
echo "=== installer snap still in live layer ==="
unsquashfs -ll "$LIVE" 2>/dev/null | grep 'ubuntu-desktop-bootstrap_665.snap' | head -1
echo "=== hardware software kept in base ==="
unsquashfs -ll "$MIN" 2>/dev/null | grep -E '/usr/sbin/NetworkManager$|/usr/bin/firefox$|/usr/bin/pipewire$|/usr/bin/pulseaudio$' | awk '{print $NF}'
echo "=== grub ==="
grep -E 'menuentry|linux ' "$MNT/boot/grub/grub.cfg" | head -4
umount "$MNT"
echo VERIFY_OK
