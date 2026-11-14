#!/bin/sh
# Create an installable GROUP2-OS.iso for another laptop.
# Starts from official Ubuntu Desktop (drivers + installer + Firefox),
# then applies GROUP 2 wallpaper, login, folders, and branding.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux

UBUNTU_VER="${UBUNTU_VER:-26.04.1}"
UBUNTU_ISO_NAME="ubuntu-${UBUNTU_VER}-desktop-amd64.iso"
if [ -z "${UBUNTU_ISO_URL:-}" ]; then
	if [ "$UBUNTU_VER" = "26.04.1" ]; then
		UBUNTU_ISO_URL="https://releases.ubuntu.com/26.04/${UBUNTU_ISO_NAME}"
	else
		UBUNTU_ISO_URL="https://releases.ubuntu.com/${UBUNTU_VER}/${UBUNTU_ISO_NAME}"
	fi
fi
CACHE="$G2_BUILD/iso-cache"
# Work on a native Linux filesystem to avoid NTFS permission errors
WORK="$G2_LINUX_BUILD/laptop-iso"
ISO_EXTRACT="$WORK/iso"
EDIT="$WORK/edit"
BOOTPART="$WORK/bootpart"
LINUX_OUT="$G2_LINUX_BUILD/out"
OUT_ISO="$G2_OUT/GROUP2-OS.iso"   # final Windows-accessible path

echo_step "GROUP 2 OS laptop installer ISO"
echo "This builds a USB-installable desktop OS for another laptop."
echo "Base: Ubuntu ${UBUNTU_VER} Desktop (kernel, drivers, installer kept)"
echo "Identity: GROUP 2 OS wallpaper, login, members, folders"
echo

# Check space on the Linux build filesystem (not Windows /mnt/c)
mkdir -p "$G2_LINUX_BUILD"
avail_kb=$(df -k "$G2_LINUX_BUILD" | awk 'NR==2 {print $4}')
if [ "${avail_kb:-0}" -lt 25000000 ]; then
	echo "Need about 25 GB free disk space on $G2_LINUX_BUILD"
	df -h "$G2_LINUX_BUILD"
	echo "Free some space, then run this script again."
	exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get install -y squashfs-tools xorriso rsync wget aria2 ca-certificates \
		grub-pc-bin grub-efi-amd64-bin mtools isolinux dconf-cli libglib2.0-bin
fi

mkdir -p "$CACHE" "$WORK" "$G2_OUT" "$LINUX_OUT"
ISO_FILE="$CACHE/$UBUNTU_ISO_NAME"

if [ ! -f "$ISO_FILE" ]; then
	echo_step "Downloading Ubuntu Desktop ISO (~6 GB)"
	echo "URL: $UBUNTU_ISO_URL"
	if command -v aria2c >/dev/null 2>&1; then
		aria2c --continue=true --max-connection-per-server=16 \
			--split=16 --min-split-size=4M --file-allocation=none \
			--dir="$CACHE" --out="$UBUNTU_ISO_NAME.partial" \
			"$UBUNTU_ISO_URL"
	else
		wget -c -O "$ISO_FILE.partial" "$UBUNTU_ISO_URL"
	fi
	mv "$ISO_FILE.partial" "$ISO_FILE"
fi

echo_step "Extracting ISO (UEFI + BIOS boot files)"
sudo rm -rf "$WORK"
sudo mkdir -p "$ISO_EXTRACT" "$BOOTPART"
sudo xorriso -osirrox on -indev "$ISO_FILE" \
	-extract_boot_images "$BOOTPART" \
	-extract / "$ISO_EXTRACT" \
	2>&1 | grep -v "Cannot change\|Operation not permitted\|SORRY\|FAILURE.*chmod\|FAILURE.*timestamp" || true

echo_step "Unpacking Ubuntu 26.04 live overlay"
sudo rm -rf "$EDIT"
sudo mkdir -p "$EDIT"

SQUASH_DIR=""
if [ -d "$ISO_EXTRACT/casper" ]; then
	SQUASH_DIR="$ISO_EXTRACT/casper"
elif [ -d "$ISO_EXTRACT/live" ]; then
	SQUASH_DIR="$ISO_EXTRACT/live"
else
	echo "Could not find casper/ or live/ in the Ubuntu ISO."
	exit 1
fi

# Resolute Desktop uses real layered files. Never merge or delete them:
#   minimal.squashfs -> minimal.standard.squashfs -> minimal.standard.live.squashfs
# Customize only the top live overlay so snap seed data, whiteouts, ownership,
# permissions, and the Ubuntu installer remain valid.
for required in minimal.squashfs minimal.standard.squashfs minimal.standard.live.squashfs; do
	if [ ! -f "$SQUASH_DIR/$required" ]; then
		echo "Ubuntu 26.04 layer is missing: $SQUASH_DIR/$required"
		exit 1
	fi
done

LIVE_SQUASH="$SQUASH_DIR/minimal.standard.live.squashfs"
sudo unsquashfs -d "$EDIT" "$LIVE_SQUASH"
if [ ! -f "$EDIT/var/lib/snapd/snaps/ubuntu-desktop-bootstrap_665.snap" ]; then
	echo "The original Ubuntu live layer is incomplete: installer snap is missing."
	exit 1
fi

echo_step "Applying Group 2 OS branding"
sudo sh "$G2_ROOT/installer/apply-branding.sh" "$EDIT"

# Compile dconf directly from the overlay keyfiles. This does not require a
# fragile chroot into an incomplete delta layer.
if command -v dconf >/dev/null 2>&1; then
	sudo dconf compile "$EDIT/etc/dconf/db/local" "$EDIT/etc/dconf/db/local.d"
	sudo dconf compile "$EDIT/etc/dconf/db/gdm" "$EDIT/etc/dconf/db/gdm.d"
fi
sudo sh "$G2_ROOT/installer/patch-gdm-theme.sh" "$EDIT" "$SQUASH_DIR/minimal.squashfs" || true

echo_step "Repacking Group 2 OS live overlay"
NEW_LIVE="$WORK/minimal.standard.live.squashfs.new"
sudo rm -f "$NEW_LIVE"
sudo mksquashfs "$EDIT" "$NEW_LIVE" -comp zstd -Xcompression-level 1 -b 1M -noappend -no-progress
sudo unsquashfs -s "$NEW_LIVE" >/dev/null
sudo mv -f "$NEW_LIVE" "$LIVE_SQUASH"

echo_step "Branding boot menu"
for grub in \
	"$ISO_EXTRACT/boot/grub/grub.cfg" \
	"$ISO_EXTRACT/EFI/boot/grub.cfg" \
	"$ISO_EXTRACT/boot/grub/loopback.cfg"
do
	if [ -f "$grub" ]; then
		sudo sed -i \
			-e 's/Try or Install Ubuntu/Try or Install Group 2 OS/g' \
			-e 's/Install Ubuntu/Install Group 2 OS/g' \
			-e 's/Ubuntu (safe graphics)/Group 2 OS (safe graphics)/g' \
			-e 's/menuentry "Ubuntu"/menuentry "Group 2 OS"/g' \
			"$grub"
	fi
done

if [ -f "$G2_ROOT/installer/overlay/casper/install-sources.yaml" ]; then
	sudo cp -f "$G2_ROOT/installer/overlay/casper/install-sources.yaml" \
		"$ISO_EXTRACT/casper/install-sources.yaml"
fi
if [ -f "$ISO_EXTRACT/.disk/info" ]; then
	echo "Group 2 OS 1.0 - Release amd64 ($(date +%Y%m%d))" | sudo tee "$ISO_EXTRACT/.disk/info" >/dev/null
fi
if [ -f "$ISO_EXTRACT/README.diskdefines" ]; then
	sudo sed -i 's/Ubuntu/GROUP 2 OS/g' "$ISO_EXTRACT/README.diskdefines" || true
fi

echo_step "Building bootable GROUP2-OS.iso"
# Copy separate desktop and boot assets. Reference screenshots are never used.
if [ -f "$G2_BRANDING/desktop-wallpaper.png" ]; then
	sudo mkdir -p "$ISO_EXTRACT/group2"
	sudo cp -f "$G2_BRANDING/desktop-wallpaper.png" "$ISO_EXTRACT/group2/desktop-wallpaper.png"
fi
if [ -f "$G2_BRANDING/grub-background.png" ]; then
	sudo mkdir -p "$ISO_EXTRACT/boot/grub"
	sudo cp -f "$G2_BRANDING/grub-background.png" "$ISO_EXTRACT/boot/grub/group2-boot.png"
fi
if [ -f "$ISO_EXTRACT/boot/grub/grub.cfg" ]; then
	sudo sed -i '/background_image \/boot\/grub\/group2-boot.png/d' "$ISO_EXTRACT/boot/grub/grub.cfg" || true
fi

# Refresh media checksums after modifying the live layer and branding assets.
(
	cd "$ISO_EXTRACT"
	sudo find . -type f ! -name md5sum.txt -print0 \
		| sudo sort -z \
		| sudo xargs -0 md5sum \
		| sudo tee md5sum.txt >/dev/null
)

MBR_IMG=""
EFI_IMG=""
if [ -f "$BOOTPART/mbr_code_grub2.img" ]; then
	MBR_IMG="$BOOTPART/mbr_code_grub2.img"
fi
if [ -f "$BOOTPART/gpt_part2_efi.img" ]; then
	EFI_IMG="$BOOTPART/gpt_part2_efi.img"
fi
# 7z/xorriso bootpart names used by some Ubuntu ISOs
if [ -z "$MBR_IMG" ]; then
	for f in "$BOOTPART"/mbr*.img "$BOOTPART"/1-Boot-NoEmul.img; do
		[ -f "$f" ] && MBR_IMG="$f" && break
	done
fi
if [ -z "$EFI_IMG" ]; then
	for f in "$BOOTPART"/gpt_part2_efi.img "$BOOTPART"/2-Boot-NoEmul.img; do
		[ -f "$f" ] && EFI_IMG="$f" && break
	done
fi

XORRISO_REPORT=$(xorriso -indev "$ISO_FILE" -report_el_torito as_mkisofs 2>/dev/null || true)
echo "$XORRISO_REPORT" > "$WORK/xorriso-flags.txt"

LINUX_ISO="$LINUX_OUT/GROUP2-OS.iso"
sudo rm -f "$LINUX_ISO"
if [ -n "$MBR_IMG" ] && [ -n "$EFI_IMG" ]; then
	sudo xorriso -as mkisofs -r \
		-V "GROUP2_OS" \
		-o "$LINUX_ISO" \
		--grub2-mbr "$MBR_IMG" \
		-partition_offset 16 \
		--mbr-force-bootable \
		-append_partition 2 0xef "$EFI_IMG" \
		-appended_part_as_gpt \
		-c boot.catalog \
		-b boot/grub/i386-pc/eltorito.img \
		-no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
		-eltorito-alt-boot \
		-e '--interval:appended_partition_2:::' \
		-no-emul-boot \
		"$ISO_EXTRACT"
else
	echo "Could not extract original boot images; using grub-mkrescue fallback."
	sudo grub-mkrescue -o "$LINUX_ISO" "$ISO_EXTRACT" -- -volid "GROUP2_OS"
fi

echo_step "Copying GROUP2-OS.iso to Windows build folder"
sudo cp -f "$LINUX_ISO" "$OUT_ISO"
sudo chmod 644 "$OUT_ISO" 2>/dev/null || true

echo
echo "============================================================"
echo " GROUP 2 OS laptop image is ready"
echo "============================================================"
echo "  $OUT_ISO"
echo
echo "Put it on a USB stick with Rufus (Windows):"
echo "  1. Insert a USB stick (8 GB or larger). This erases the USB stick."
echo "  2. Open Rufus -> SELECT the ISO above"
echo "  3. Partition scheme: GPT"
echo "  4. Target: UEFI"
echo "  5. Click START"
echo
echo "On the other laptop:"
echo "  1. Plug in the USB stick"
echo "  2. Power on and press F12 / F10 / Esc / F2 (boot menu)"
echo "  3. Boot from USB"
echo "  4. Choose: Try or Install GROUP 2 OS"
echo "  5. Click Install and follow the screens"
echo
echo "Test in QEMU first (optional):"
echo "  qemu-system-x86_64 -m 2048 -cdrom \"$OUT_ISO\" -boot d -enable-kvm"
echo
