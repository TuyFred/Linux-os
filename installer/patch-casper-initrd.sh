#!/bin/sh
# Do not rewrite casper/initrd.
# Casper loads the live disk with: modprobe -b overlay
# If that module is missing, boot stops in BusyBox:
#   /cow format specified as 'overlay' and no support found
# Rebuilding the boot image, or appending files after it, makes the
# kernel skip that module. Ubuntu's original initrd must stay byte-identical.
set -eu

CASPER=${1:?usage: patch-casper-initrd.sh CASPER_DIR EDIT_ROOT}
INITRD="$CASPER/initrd"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ORIG_ISO="$ROOT/build/iso-cache/ubuntu-26.04.1-desktop-amd64.iso"
STOCK="$CASPER/initrd.ubuntu-stock"

if [ ! -f "$ORIG_ISO" ]; then
	echo "Ubuntu ISO cache is missing; leaving the current boot image alone."
	exit 0
fi

echo "Restoring the original boot image so overlay can load."
rm -f "$STOCK"
xorriso -osirrox on -indev "$ORIG_ISO" -extract /casper/initrd "$STOCK" >/dev/null
if [ ! -s "$STOCK" ]; then
	echo "Could not read Ubuntu's boot image."
	exit 1
fi
cp -f "$STOCK" "$INITRD"
rm -f "$STOCK"
echo "Boot image matches Ubuntu. Overlay support is intact."
