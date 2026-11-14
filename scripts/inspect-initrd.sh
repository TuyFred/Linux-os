#!/bin/bash
set -e
INITRD="/root/group2-build/laptop-iso/iso/casper/initrd"
echo "=== file ==="
file "$INITRD"
echo "=== size ==="
ls -lh "$INITRD"
echo "=== unmkinitramfs dirs ==="
rm -rf /tmp/g2-initrd
unmkinitramfs "$INITRD" /tmp/g2-initrd
find /tmp/g2-initrd -maxdepth 2 -type d | head -40
echo "=== plymouth conf ==="
find /tmp/g2-initrd -name 'plymouthd.conf' -o -name 'default.plymouth' -o -name 'ubuntu-text.plymouth' | head
echo "=== theme name ==="
grep -R "Theme=" /tmp/g2-initrd --include='plymouthd.conf' 2>/dev/null || true
ls /tmp/g2-initrd/main/usr/share/plymouth/themes 2>/dev/null || ls /tmp/g2-initrd/usr/share/plymouth/themes 2>/dev/null || true
