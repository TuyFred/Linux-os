#!/bin/bash
set -eu
ISO="/root/group2-build/out/GROUP2-OS.iso"
MNT="/tmp/g2iso"
MIN="/tmp/g2min"
STD="/tmp/g2std"
MERGED="/tmp/g2installed"
mkdir -p "$MNT" "$MIN" "$STD" "$MERGED" /tmp/g2work
umount "$MERGED" 2>/dev/null || true
umount "$STD" 2>/dev/null || true
umount "$MIN" 2>/dev/null || true
umount "$MNT" 2>/dev/null || true
mount -o loop,ro "$ISO" "$MNT"

echo "=== 1 boot files ==="
test -f "$MNT/casper/vmlinuz"
test -f "$MNT/casper/initrd"
grep -q 'Try or Install Group 2 OS' "$MNT/boot/grub/grub.cfg"
grep -q 'NAME="Group 2 OS"' <(cpio -i --to-stdout etc/os-release < "$MNT/casper/initrd" 2>/dev/null)

echo "=== 2 installer ==="
grep -q 'id: group2-os-desktop' "$MNT/casper/install-sources.yaml"
grep -q 'default: true' "$MNT/casper/install-sources.yaml"
unsquashfs -ll "$MNT/casper/minimal.standard.live.squashfs" 2>/dev/null | grep -q ubuntu-desktop-bootstrap_665.snap

echo "=== 3+4 simulated installed disk ==="
mount -o loop,ro "$MNT/casper/minimal.squashfs" "$MIN"
mount -o loop,ro "$MNT/casper/minimal.standard.squashfs" "$STD"
mount -t overlay overlay -o lowerdir="$STD:$MIN" "$MERGED"
echo "-- identity --"
grep -E '^NAME=|^PRETTY' "$MERGED/etc/os-release"
echo "-- wallpaper and login --"
test -f "$MERGED/usr/share/backgrounds/group2-os-desktop.png"
test -f "$MERGED/usr/share/backgrounds/group2-os-login.png"
grep -q 'AutomaticLoginEnable=false' "$MERGED/etc/gdm3/custom.conf"
grep -q 'Theme=group2-os' "$MERGED/etc/plymouth/plymouthd.conf"
echo "-- hardware programs kept --"
test -x "$MERGED/usr/sbin/NetworkManager"
test -x "$MERGED/usr/bin/firefox" || test -e "$MERGED/usr/bin/firefox"
test -x "$MERGED/usr/bin/pipewire"
echo "SIMULATED_INSTALL_OK"

umount "$MERGED" || true
umount "$STD" || true
umount "$MIN" || true
umount "$MNT" || true
