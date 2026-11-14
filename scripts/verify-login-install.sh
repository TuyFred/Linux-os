#!/bin/bash
set -eu
G2="/mnt/c/Users/USER/GROUP 2 OS"
LIVE=/root/group2-build/laptop-iso/iso/casper/minimal.standard.live.squashfs
echo "=== ISO ==="
ls -lh "$G2/build/out/GROUP2-OS.iso"
echo "=== Key files in live squash ==="
unsquashfs -l "$LIVE" 2>/dev/null | grep -E \
  "group2-prepare-login|group2-gdm.css|group2-login-clock|g2-install|group2-os-login|Africa|custom.conf" | head -40
echo "=== Autologin off ==="
unsquashfs -cat "$LIVE" etc/gdm3/custom.conf 2>/dev/null || true
echo "VERIFY_LOGIN_INSTALL_DONE"
