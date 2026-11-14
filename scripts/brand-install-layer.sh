#!/bin/sh
# Put Group 2 OS branding into the filesystem that the installer copies
# onto a laptop. The live overlay is only for "Try". After Install, Ubuntu
# uses minimal.squashfs + minimal.standard.squashfs.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

ORIG_ISO="$G2_BUILD/iso-cache/ubuntu-26.04.1-desktop-amd64.iso"
WORK="$G2_LINUX_BUILD/laptop-iso"
SQUASH_DIR="$WORK/iso/casper"
STD="$SQUASH_DIR/minimal.standard.squashfs"
EDIT="$WORK/standard-edit"
SRC="$WORK/minimal.standard.orig.squashfs"

if [ ! -f "$ORIG_ISO" ]; then
	echo "Original Ubuntu ISO is missing: $ORIG_ISO"
	exit 1
fi

echo_step "Branding the installable Group 2 OS layer"
sudo rm -rf "$EDIT"
sudo mkdir -p "$EDIT" "$(dirname "$SRC")"
sudo xorriso -osirrox on -indev "$ORIG_ISO" \
	-extract /casper/minimal.standard.squashfs "$SRC" >/dev/null
sudo unsquashfs -d "$EDIT" "$SRC"
sudo sh "$G2_ROOT/installer/apply-branding.sh" "$EDIT"
if command -v dconf >/dev/null 2>&1; then
	sudo dconf compile "$EDIT/etc/dconf/db/local" "$EDIT/etc/dconf/db/local.d"
	sudo dconf compile "$EDIT/etc/dconf/db/gdm" "$EDIT/etc/dconf/db/gdm.d"
fi
sudo sh "$G2_ROOT/installer/patch-gdm-theme.sh" "$EDIT" "$SQUASH_DIR/minimal.squashfs" || true

if [ ! -f "$EDIT/usr/share/backgrounds/group2-os-desktop.png" ]; then
	echo "Install layer is missing the Group 2 OS wallpaper."
	exit 1
fi
if [ ! -f "$EDIT/etc/os-release" ]; then
	echo "Install layer is missing Group 2 OS identity."
	exit 1
fi
NEW="$WORK/minimal.standard.squashfs.new"
sudo rm -f "$NEW"
sudo mksquashfs "$EDIT" "$NEW" -comp zstd -Xcompression-level 1 -b 1M -noappend -no-progress
sudo unsquashfs -s "$NEW" >/dev/null
sudo mv -f "$NEW" "$STD"
echo "Installable layer branded: $STD"
