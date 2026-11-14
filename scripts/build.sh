#!/bin/sh
# Build a minimal bootable GROUP 2 OS from the linux-master kernel source.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux
require_dir "$G2_KERNEL"

echo
echo "  GROUP 2 OS  —  Linux"
echo "  LEARN • BUILD • CREATE • TOGETHER"
echo "  Kernel source: $G2_KERNEL"
echo
chmod +x "$G2_ROOT/scripts/"*.sh "$G2_ROOT/userspace/"* 2>/dev/null || true

STEP="${1:-laptop}"

case "$STEP" in
	deps)     sh "$G2_ROOT/scripts/01-install-deps.sh" ;;
	kernel)   sh "$G2_ROOT/scripts/02-build-kernel.sh" ;;
	busybox)  sh "$G2_ROOT/scripts/03-build-busybox.sh" ;;
	rootfs)   sh "$G2_ROOT/scripts/04-make-rootfs.sh" ;;
	iso)      sh "$G2_ROOT/scripts/05-make-iso.sh" ;;
	laptop)   sh "$G2_ROOT/scripts/06-make-laptop-iso.sh" ;;
	minimal)
		sh "$G2_ROOT/scripts/01-install-deps.sh"
		sh "$G2_ROOT/scripts/02-build-kernel.sh"
		sh "$G2_ROOT/scripts/03-build-busybox.sh"
		sh "$G2_ROOT/scripts/04-make-rootfs.sh"
		sh "$G2_ROOT/scripts/05-make-iso.sh"
		;;
	all)
		sh "$G2_ROOT/scripts/06-make-laptop-iso.sh"
		;;
	*)
		echo "Usage: bash scripts/build.sh [laptop|minimal|deps|kernel|busybox|rootfs|iso]"
		echo "  laptop   Installable GROUP2-OS.iso for another laptop (recommended)"
		echo "  minimal  From-source kernel + BusyBox ISO (learning / QEMU)"
		exit 1
		;;
esac
