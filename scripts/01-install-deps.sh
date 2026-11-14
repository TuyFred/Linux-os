#!/bin/sh
# Install packages needed to compile the GROUP 2 OS kernel and ISO.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

echo_step "Installing build dependencies"

if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get install -y \
		build-essential flex bison libssl-dev libelf-dev bc dwarves \
		rsync python3 kmod cpio gzip bzip2 wget xz-utils \
		grub-pc-bin grub-efi-amd64-bin grub2-common xorriso mtools \
		qemu-system-x86 squashfs-tools rsync wget aria2 ca-certificates isolinux
else
	echo "Install these packages with your distro's package manager:"
	echo "  gcc make flex bison libssl libelf bc rsync python3 cpio"
	echo "  grub xorriso qemu-system-x86"
	exit 1
fi

echo "Dependencies installed."
