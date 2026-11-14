#!/bin/sh
# Boot the Group 2 OS ISO under KVM and record whether casper reaches userspace.
set -eu
ISO=/root/group2-build/out/GROUP2-OS.iso
TEST=/root/group2-build/boot-test
KNL=$TEST/vmlinuz
IRD=$TEST/initrd
LOG=$TEST/boot.log
mkdir -p "$TEST"
xorriso -osirrox on -indev "$ISO" \
	-extract /casper/vmlinuz "$KNL" \
	-extract /casper/initrd "$IRD" >/dev/null
if [ ! -s "$KNL" ] || [ ! -s "$IRD" ]; then
	echo "Missing kernel or initrd"
	exit 1
fi
rm -f "$LOG"
echo "Starting live boot test"
timeout 180 qemu-system-x86_64 \
	-machine q35,accel=kvm \
	-cpu host \
	-m 3584 -smp 2 \
	-cdrom "$ISO" \
	-kernel "$KNL" \
	-initrd "$IRD" \
	-append "username=group2 hostname=group2-os console=ttyS0,115200n8 loglevel=4 systemd.show_status=true plymouth.enable=0 ---" \
	-display none \
	-serial file:"$LOG" \
	-no-reboot \
	-netdev user,id=n0 \
	-device virtio-net-pci,netdev=n0 \
	|| true
echo "BOOT_TEST_ENDED"
echo "=== markers ==="
grep -a -E 'no support found|BusyBox|Group 2 OS|gdm|GNOME Display|Reached target|login:|Kernel panic|Unable to find a medium|failed to fill' "$LOG" | tail -40 || true
echo "=== log tail ==="
tail -30 "$LOG" || true
