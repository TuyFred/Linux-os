#!/bin/sh
set -eu
ISO="/mnt/c/Users/USER/GROUP 2 OS/build/out/GROUP2-OS.iso"
UBU="/mnt/c/Users/USER/GROUP 2 OS/build/iso-cache/ubuntu-26.04.1-desktop-amd64.iso"
WORK=/tmp/g2-test
rm -rf "$WORK"
mkdir -p "$WORK"
echo "=== extract casper listing ==="
xorriso -osirrox on -indev "$ISO" -ls /casper 2>/dev/null | awk '{print $NF, $5}' 
echo "=== original linux line ==="
xorriso -osirrox on -indev "$UBU" -extract /boot/grub/grub.cfg "$WORK/ubuntu-grub.cfg" >/dev/null
grep -n 'linux' "$WORK/ubuntu-grub.cfg" | head -20
echo "=== our linux line ==="
xorriso -osirrox on -indev "$ISO" -extract /boot/grub/grub.cfg "$WORK/ours-grub.cfg" >/dev/null
grep -n 'linux' "$WORK/ours-grub.cfg" | head -20
echo "=== install-sources ==="
xorriso -osirrox on -indev "$ISO" -extract /casper/install-sources.yaml "$WORK/install-sources.yaml" >/dev/null
cat "$WORK/install-sources.yaml"
echo "=== initrd hash ==="
xorriso -osirrox on -indev "$ISO" -extract /casper/initrd "$WORK/initrd" >/dev/null
xorriso -osirrox on -indev "$UBU" -extract /casper/initrd "$WORK/ubuntu-initrd" >/dev/null
sha256sum "$WORK/initrd" "$WORK/ubuntu-initrd"
if cmp -s "$WORK/initrd" "$WORK/ubuntu-initrd"; then
	echo "INITRD_MATCH=yes"
else
	echo "INITRD_MATCH=no"
fi
echo "=== live account script ==="
unsquashfs -cat "$WORK/../group2-build-live" >/dev/null 2>&1 || true
LIVE=/root/group2-build/laptop-iso/iso/casper/minimal.standard.live.squashfs
STD=/root/group2-build/laptop-iso/iso/casper/minimal.standard.squashfs
if [ ! -f "$LIVE" ]; then
	xorriso -osirrox on -indev "$ISO" -extract /casper/minimal.standard.live.squashfs "$WORK/live.squashfs" >/dev/null
	LIVE="$WORK/live.squashfs"
fi
if [ ! -f "$STD" ]; then
	STD="$WORK/std.squashfs"
	xorriso -osirrox on -indev "$ISO" -extract /casper/minimal.standard.squashfs "$STD" >/dev/null
fi
echo "-- live fix --"
unsquashfs -cat "$LIVE" usr/local/bin/group2-fix-live-user 2>/dev/null | grep -n 'chage\|NOPASSWD\|Username' | head
echo "-- install layer os-release --"
unsquashfs -cat "$STD" etc/os-release 2>/dev/null | head -5
echo "-- gdm autologin --"
unsquashfs -cat "$STD" etc/gdm3/custom.conf 2>/dev/null | grep AutomaticLogin || true
echo "-- bootstrap snap in live --"
unsquashfs -ll "$LIVE" 2>/dev/null | grep -F 'ubuntu-desktop-bootstrap' | head
echo "=== kernel squashfs zstd ==="
xorriso -osirrox on -indev "$ISO" -extract /casper/vmlinuz "$WORK/vmlinuz" >/dev/null
if grep -a -q 'CONFIG_SQUASHFS_ZSTD=y' "$WORK/vmlinuz"; then
	echo "KERNEL_ZSTD=yes"
else
	echo "KERNEL_ZSTD=not_in_image_strings"
fi
echo "DONE"
