#!/bin/sh
# Download and statically compile BusyBox for GROUP 2 OS userspace.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

echo_step "Building BusyBox $G2_BUSYBOX_VER"

mkdir -p "$G2_BUILD"
ARCHIVE="busybox-${G2_BUSYBOX_VER}.tar.bz2"
URL="https://busybox.net/downloads/$ARCHIVE"

if [ ! -d "$G2_BUSYBOX_SRC" ]; then
	if [ ! -f "$G2_BUILD/$ARCHIVE" ]; then
		wget -O "$G2_BUILD/$ARCHIVE" "$URL"
	fi
	tar -C "$G2_BUILD" -xjf "$G2_BUILD/$ARCHIVE"
	mv "$G2_BUILD/busybox-${G2_BUSYBOX_VER}" "$G2_BUSYBOX_SRC"
fi

cd "$G2_BUSYBOX_SRC"
make defconfig
# Static binary so the initramfs does not need glibc
if grep -q '^# CONFIG_STATIC is not set' .config; then
	sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
elif ! grep -q '^CONFIG_STATIC=y' .config; then
	echo 'CONFIG_STATIC=y' >> .config
fi
# Login/getty helpers
sed -i 's/^# CONFIG_LOGIN is not set/CONFIG_LOGIN=y/' .config || true
sed -i 's/^# CONFIG_GETTY is not set/CONFIG_GETTY=y/' .config || true

yes "" | make oldconfig
make -j"$G2_JOBS"
make busybox

if [ ! -x "$G2_BUSYBOX_SRC/busybox" ]; then
	echo "BusyBox build failed."
	exit 1
fi

cp -f "$G2_BUSYBOX_SRC/busybox" "$G2_OUT/busybox"
echo "BusyBox: $G2_OUT/busybox"
