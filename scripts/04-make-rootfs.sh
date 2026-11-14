#!/bin/sh
# Assemble the GROUP 2 OS root filesystem and initramfs.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

echo_step "Creating GROUP 2 OS filesystem"

if [ ! -x "$G2_OUT/busybox" ]; then
	echo "BusyBox is missing. Run scripts/03-build-busybox.sh first."
	exit 1
fi

rm -rf "$G2_ROOTFS"
mkdir -p "$G2_ROOTFS"

# Standard Linux filesystem layout
for d in bin sbin usr/bin usr/sbin usr/share/group2-os usr/share/backgrounds \
	etc/group2-os proc sys dev tmp run mnt opt root home lib lib64 \
	boot var/log var/tmp
do
	mkdir -p "$G2_ROOTFS/$d"
done

cp -a "$G2_OVERLAY"/. "$G2_ROOTFS"/

# BusyBox as /bin/busybox and all applets
if [ -d "$G2_BUSYBOX_SRC" ] && [ -f "$G2_BUSYBOX_SRC/Makefile" ]; then
	make -C "$G2_BUSYBOX_SRC" CONFIG_PREFIX="$G2_ROOTFS" install
fi
cp -f "$G2_OUT/busybox" "$G2_ROOTFS/bin/busybox"
chmod 755 "$G2_ROOTFS/bin/busybox"
"$G2_ROOTFS/bin/busybox" --install -s "$G2_ROOTFS" 2>/dev/null || true

# Explicit core links in case --install needs a chroot
for applet in sh ash ls cat echo mount umount hostname clear reboot poweroff halt \
	mkdir mknod chmod chown ln pwd sleep kill ps uname date dmesg \
	cp mv rm ln lsmod ifconfig ping wget tar gzip
do
	if [ ! -e "$G2_ROOTFS/bin/$applet" ]; then
		ln -sf busybox "$G2_ROOTFS/bin/$applet"
	fi
done
ln -sf /bin/busybox "$G2_ROOTFS/bin/init" 2>/dev/null || true

# GROUP 2 OS programs
install -m 0755 "$G2_USERSPACE/init"       "$G2_ROOTFS/init"
install -m 0755 "$G2_USERSPACE/init"       "$G2_ROOTFS/sbin/init"
install -m 0755 "$G2_USERSPACE/g2-login"   "$G2_ROOTFS/usr/bin/g2-login"
install -m 0755 "$G2_USERSPACE/g2-desktop" "$G2_ROOTFS/usr/bin/g2-desktop"
install -m 0755 "$G2_USERSPACE/g2-files"   "$G2_ROOTFS/usr/bin/g2-files"
install -m 0755 "$G2_USERSPACE/g2-about"   "$G2_ROOTFS/usr/bin/g2-about"
install -m 0755 "$G2_USERSPACE/g2-install" "$G2_ROOTFS/usr/bin/g2-install"
ln -sf g2-desktop "$G2_ROOTFS/usr/bin/menu"
ln -sf g2-about   "$G2_ROOTFS/usr/bin/about"
ln -sf g2-files   "$G2_ROOTFS/usr/bin/files"

# Branding
cp -f "$G2_BRANDING/ascii-boot.txt"  "$G2_ROOTFS/usr/share/group2-os/boot.txt"
cp -f "$G2_BRANDING/ascii-login.txt" "$G2_ROOTFS/usr/share/group2-os/login.txt"
cp -f "$G2_BRANDING/members.txt"     "$G2_ROOTFS/usr/share/group2-os/members.txt"
cp -f "$G2_BRANDING/slogan.txt"      "$G2_ROOTFS/usr/share/group2-os/slogan.txt"
if [ -f "$G2_BRANDING/wallpaper.jpg" ]; then
	cp -f "$G2_BRANDING/wallpaper.jpg" "$G2_ROOTFS/usr/share/backgrounds/group2-os.jpg"
	mkdir -p "$G2_ROOTFS/root/Desktop/Pictures"
	cp -f "$G2_BRANDING/wallpaper.jpg" "$G2_ROOTFS/root/Desktop/Pictures/group2-os-wallpaper.jpg"
fi

# Shared group2 home
mkdir -p "$G2_ROOTFS/home/group2/Desktop"
cp -a "$G2_ROOTFS/root/Desktop/." "$G2_ROOTFS/home/group2/Desktop/" 2>/dev/null || true

# Device nodes needed before devtmpfs
mkdir -p "$G2_ROOTFS/dev"
[ -e "$G2_ROOTFS/dev/console" ] || mknod -m 600 "$G2_ROOTFS/dev/console" c 5 1
[ -e "$G2_ROOTFS/dev/null" ]    || mknod -m 666 "$G2_ROOTFS/dev/null"    c 1 3
[ -e "$G2_ROOTFS/dev/zero" ]    || mknod -m 666 "$G2_ROOTFS/dev/zero"    c 1 5
[ -e "$G2_ROOTFS/dev/tty" ]     || mknod -m 666 "$G2_ROOTFS/dev/tty"     c 5 0
[ -e "$G2_ROOTFS/dev/tty0" ]    || mknod -m 666 "$G2_ROOTFS/dev/tty0"    c 4 0
[ -e "$G2_ROOTFS/dev/tty1" ]    || mknod -m 666 "$G2_ROOTFS/dev/tty1"    c 4 1

cat > "$G2_ROOTFS/etc/profile" << 'EOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export TERM="${TERM:-linux}"
export PS1="GROUP2-OS:\w \$ "
alias menu='g2-desktop'
alias about='g2-about'
alias files='g2-files'
[ -f /etc/motd ] && cat /etc/motd
EOF

# Initramfs image
echo_step "Packing initramfs"
(
	cd "$G2_ROOTFS"
	find . | cpio -H newc -o | gzip -9
) > "$G2_OUT/initramfs.cpio.gz"

echo "Root filesystem: $G2_ROOTFS"
echo "Initramfs:       $G2_OUT/initramfs.cpio.gz"
