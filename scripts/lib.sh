#!/bin/sh
# Shared paths for GROUP 2 OS build scripts.
# Works from WSL or a native Linux machine.

if [ -z "${G2_ROOT:-}" ]; then
	SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
	G2_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
fi

export G2_ROOT
export G2_KERNEL="$G2_ROOT/linux-master/linux-master"
export G2_BRANDING="$G2_ROOT/branding"
export G2_CONFIGS="$G2_ROOT/configs"
export G2_USERSPACE="$G2_ROOT/userspace"
export G2_OVERLAY="$G2_ROOT/rootfs-overlay"
export G2_ISO_OVERLAY="$G2_ROOT/iso-overlay"
export G2_BUILD="$G2_ROOT/build"
export G2_ROOTFS="$G2_BUILD/rootfs"
export G2_BUSYBOX_SRC="$G2_BUILD/busybox-src"
export G2_ISO_ROOT="$G2_BUILD/iso-root"
export G2_OUT="$G2_BUILD/out"
export G2_ISO="$G2_OUT/GROUP2-OS.iso"

# Laptop ISO build must happen on a Linux-native filesystem
# (xorriso/chmod fail on Windows NTFS /mnt/c).
# Use /root/group2-build which lives on the large WSL virtual disk (not tmpfs).
export G2_LINUX_BUILD="${G2_LINUX_BUILD:-/root/group2-build}"
export G2_BUSYBOX_VER="${G2_BUSYBOX_VER:-1.36.1}"
export G2_JOBS="${G2_JOBS:-$(nproc 2>/dev/null || echo 2)}"

mkdir -p "$G2_BUILD" "$G2_OUT"

require_linux() {
	if [ "$(uname -s)" != "Linux" ]; then
		echo "GROUP 2 OS must be compiled on Linux."
		echo "This computer is running Windows without a Linux build environment."
		echo
		echo "Next step: install WSL, then rebuild."
		echo "  1. Open PowerShell as Administrator"
		echo "  2. Run:  wsl --install -d Ubuntu"
		echo "  3. Restart Windows"
		echo "  4. Open Ubuntu and run:"
		echo "       cd \"/mnt/c/Users/USER/GROUP 2 OS\""
		echo "       bash scripts/build.sh laptop"
		exit 1
	fi
}

require_dir() {
	if [ ! -d "$1" ]; then
		echo "Missing required directory: $1"
		exit 1
	fi
}

echo_step() {
	echo
	echo "============================================================"
	echo " GROUP 2 OS  |  $*"
	echo "============================================================"
}
