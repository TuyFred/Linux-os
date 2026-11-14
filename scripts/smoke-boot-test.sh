#!/bin/bash
set -u
ISO=/root/group2-build/out/GROUP2-OS.iso
MNT=/tmp/g2-iso-mnt
LOG=/tmp/g2-boot.log
ERR=/tmp/g2-qemu.err
rm -f "$LOG" "$ERR"
mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount -o loop,ro "$ISO" "$MNT"
# Direct kernel boot so serial console works (same casper layers as the menu).
timeout 150 qemu-system-x86_64 \
  -enable-kvm -m 3072 -smp 2 \
  -nographic \
  -cdrom "$ISO" \
  -kernel "$MNT/casper/vmlinuz" \
  -initrd "$MNT/casper/initrd" \
  -append "boot=casper username=group2 hostname=group2-os quiet splash loglevel=0 systemd.show_status=false console=ttyS0 ---" \
  -no-reboot >"$LOG" 2>"$ERR" || true
umount "$MNT" 2>/dev/null || true
echo "==== BOOT LOG TAIL ===="
tail -n 100 "$LOG" || true
echo "==== KEY MATCHES ===="
grep -E "Group 2 OS|Welcome|gdm|GDM|graphical.target|Reached target|login|Started |Failed |nologin|BusyBox|overlay|Ubuntu" "$LOG" | tail -50 || true
echo "==== DONE ===="
