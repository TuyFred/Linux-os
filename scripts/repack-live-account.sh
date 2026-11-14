#!/bin/sh
set -eu
. "$(dirname "$0")/lib.sh"
require_linux
EDIT="$G2_LINUX_BUILD/laptop-iso/edit"
LIVE="$G2_LINUX_BUILD/laptop-iso/iso/casper/minimal.standard.live.squashfs"
OVERLAY="$G2_ROOT/installer/overlay"
if [ ! -d "$EDIT" ]; then
	echo "Live edit tree missing"
	exit 1
fi
install -m 0755 "$OVERLAY/usr/local/bin/group2-fix-live-user" \
	"$EDIT/usr/local/bin/group2-fix-live-user"
install -m 0755 "$OVERLAY/usr/local/bin/group2-prepare-login" \
	"$EDIT/usr/local/bin/group2-prepare-login"
install -m 0755 "$OVERLAY/usr/local/bin/group2-terminal" \
	"$EDIT/usr/local/bin/group2-terminal"
install -m 0755 "$OVERLAY/usr/local/bin/group2-firstboot" \
	"$EDIT/usr/local/bin/group2-firstboot"
install -m 0755 "$OVERLAY/usr/local/bin/group2-appearance" \
	"$EDIT/usr/local/bin/group2-appearance"
install -m 0755 "$OVERLAY/usr/local/bin/group2-assistant" \
	"$EDIT/usr/local/bin/group2-assistant"
install -m 0755 "$OVERLAY/usr/local/bin/group2-health" \
	"$EDIT/usr/local/bin/group2-health"
install -m 0755 "$OVERLAY/usr/local/bin/group2-monitor" \
	"$EDIT/usr/local/bin/group2-monitor"
install -m 0755 "$OVERLAY/usr/local/bin/group2-optimizer" \
	"$EDIT/usr/local/bin/group2-optimizer"
install -m 0755 "$OVERLAY/usr/local/bin/group2-security" \
	"$EDIT/usr/local/bin/group2-security"
install -m 0755 "$OVERLAY/usr/local/bin/group2-how-built" \
	"$EDIT/usr/local/bin/group2-how-built"
install -m 0755 "$OVERLAY/usr/local/bin/group2-language" \
	"$EDIT/usr/local/bin/group2-language"
install -m 0755 "$OVERLAY/usr/local/bin/group2-suite" \
	"$EDIT/usr/local/bin/group2-suite"
install -m 0755 "$OVERLAY/usr/local/bin/group2-selftest" \
	"$EDIT/usr/local/bin/group2-selftest"
mkdir -p "$EDIT/usr/local/lib/group2" "$EDIT/usr/share/group2-os/i18n" \
	"$EDIT/usr/share/group2-os/help" "$EDIT/usr/share/group2-os/docs"
install -m 0644 "$OVERLAY/usr/local/lib/group2/common.sh" \
	"$EDIT/usr/local/lib/group2/common.sh"
cp -a "$OVERLAY/usr/share/group2-os/i18n/." "$EDIT/usr/share/group2-os/i18n/"
cp -a "$OVERLAY/usr/share/group2-os/help/." "$EDIT/usr/share/group2-os/help/"
cp -a "$OVERLAY/usr/share/group2-os/docs/." "$EDIT/usr/share/group2-os/docs/" 2>/dev/null || true
install -m 0644 "$OVERLAY/usr/local/lib/group2/assistant_engine.py" \
	"$EDIT/usr/local/lib/group2/assistant_engine.py" 2>/dev/null || \
	cp -f "$OVERLAY/usr/local/lib/group2/assistant_engine.py" "$EDIT/usr/local/lib/group2/assistant_engine.py"
chmod 644 "$EDIT/usr/local/lib/group2/assistant_engine.py" 2>/dev/null || true
if [ -f "$G2_ROOT/HOW-GROUP2-OS-IS-BUILT.md" ]; then
	cp -f "$G2_ROOT/HOW-GROUP2-OS-IS-BUILT.md" "$EDIT/usr/share/group2-os/docs/HOW-BUILT.en.md"
fi
for desk in group2-appearance group2-suite group2-assistant group2-health \
	group2-monitor group2-optimizer group2-security group2-how-built group2-language; do
	[ -f "$OVERLAY/usr/share/applications/${desk}.desktop" ] && \
		install -m 0644 "$OVERLAY/usr/share/applications/${desk}.desktop" \
			"$EDIT/usr/share/applications/${desk}.desktop"
done
install -m 0644 "$OVERLAY/usr/share/applications/group2-appearance.desktop" \
	"$EDIT/usr/share/applications/group2-appearance.desktop"
mkdir -p "$EDIT/etc/systemd/system/gdm.service.d" \
	"$EDIT/etc/systemd/system/gdm3.service.d"
install -m 0644 "$OVERLAY/etc/systemd/system/gdm.service.d/group2-login.conf" \
	"$EDIT/etc/systemd/system/gdm.service.d/group2-login.conf"
install -m 0644 "$OVERLAY/etc/systemd/system/gdm3.service.d/group2-login.conf" \
	"$EDIT/etc/systemd/system/gdm3.service.d/group2-login.conf"
install -m 0755 "$OVERLAY/usr/local/bin/group2-desktop-setup" \
	"$EDIT/usr/local/bin/group2-desktop-setup"
mkdir -p "$EDIT/usr/share/applications" "$EDIT/etc/profile.d" "$EDIT/usr/local/bin" \
	"$EDIT/etc/systemd/system" "$EDIT/etc/polkit-1/rules.d"
install -m 0755 "$OVERLAY/usr/local/bin/group2-about" \
	"$EDIT/usr/local/bin/group2-about"
if [ -f "$G2_ROOT/userspace/g2-install" ]; then
	install -m 0755 "$G2_ROOT/userspace/g2-install" "$EDIT/usr/local/bin/g2-install"
fi
install -m 0644 "$OVERLAY/usr/share/applications/group2-about.desktop" \
	"$EDIT/usr/share/applications/group2-about.desktop"
install -m 0644 "$OVERLAY/usr/share/applications/group2-terminal.desktop" \
	"$EDIT/usr/share/applications/group2-terminal.desktop"
install -m 0644 "$OVERLAY/usr/share/applications/group2-install.desktop" \
	"$EDIT/usr/share/applications/group2-install.desktop"
install -m 0644 "$OVERLAY/etc/systemd/system/group2-live-user.service" \
	"$EDIT/etc/systemd/system/group2-live-user.service"
install -m 0644 "$OVERLAY/etc/systemd/system/group2-fix-shell.service" \
	"$EDIT/etc/systemd/system/group2-fix-shell.service"
install -m 0644 "$OVERLAY/etc/systemd/system/group2-firstboot.service" \
	"$EDIT/etc/systemd/system/group2-firstboot.service"
install -m 0644 "$OVERLAY/etc/polkit-1/rules.d/49-group2-session.rules" \
	"$EDIT/etc/polkit-1/rules.d/49-group2-session.rules"
install -m 0644 "$OVERLAY/etc/profile.d/group2-prompt.sh" \
	"$EDIT/etc/profile.d/group2-prompt.sh"
install -m 0644 "$OVERLAY/etc/motd" "$EDIT/etc/motd"
if ! grep -q group2-prompt.sh "$EDIT/etc/bash.bashrc" 2>/dev/null; then
	printf '\n[ -f /etc/profile.d/group2-prompt.sh ] && . /etc/profile.d/group2-prompt.sh\n' \
		>> "$EDIT/etc/bash.bashrc"
fi
if [ -f "$G2_ROOT/userspace/g2-install" ]; then
	install -m 0755 "$G2_ROOT/userspace/g2-install" "$EDIT/usr/local/bin/g2-install"
fi
cp -f "$OVERLAY/etc/dconf/db/local.d/00-group2" "$EDIT/etc/dconf/db/local.d/00-group2"
if command -v dconf >/dev/null 2>&1; then
	dconf compile "$EDIT/etc/dconf/db/local" "$EDIT/etc/dconf/db/local.d" || true
fi
install -m 0644 "$OVERLAY/etc/systemd/system/group2-live-user.service" \
	"$EDIT/etc/systemd/system/group2-live-user.service"
mkdir -p "$EDIT/etc/modules-load.d"
install -m 0644 "$OVERLAY/etc/modules-load.d/fuse.conf" \
	"$EDIT/etc/modules-load.d/fuse.conf"
rm -rf "$EDIT/etc/systemd/system/gdm.service.d" \
	"$EDIT/etc/systemd/system/gdm3.service.d" \
	"$EDIT/etc/systemd/system/display-manager.service.d"
for f in \
	"$EDIT/usr/local/bin/group2-fix-live-user" \
	"$EDIT/usr/local/bin/group2-desktop-setup" \
	"$EDIT/usr/local/bin/group2-about" \
	"$EDIT/etc/profile.d/group2-prompt.sh" \
	"$EDIT/etc/systemd/system/group2-live-user.service" \
	"$EDIT/etc/modules-load.d/fuse.conf"
do
	sed -i 's/\r$//' "$f"
done
if [ -f "$EDIT/etc/bash.bashrc" ] && ! grep -q group2-prompt.sh "$EDIT/etc/bash.bashrc"; then
	printf '\n[ -f /etc/profile.d/group2-prompt.sh ] && . /etc/profile.d/group2-prompt.sh\n' \
		>> "$EDIT/etc/bash.bashrc"
fi
mkdir -p "$EDIT/etc/sudoers.d"
chown root:root "$EDIT/etc/sudoers.d" "$EDIT/etc/sudoers.d/"* "$EDIT/etc/sudoers" 2>/dev/null || true
chmod 755 "$EDIT/etc/sudoers.d"
chmod 440 "$EDIT/etc/sudoers.d/"* "$EDIT/etc/sudoers" 2>/dev/null || true
if command -v dconf >/dev/null 2>&1 && [ -d "$EDIT/etc/dconf/db/local.d" ]; then
	cp -f "$G2_ROOT/installer/overlay/etc/dconf/db/local.d/00-group2" \
		"$EDIT/etc/dconf/db/local.d/00-group2"
	dconf compile "$EDIT/etc/dconf/db/local" "$EDIT/etc/dconf/db/local.d" || true
fi
# Member lists, desktop folders, and folder icons (including Niyonkuru Tajidini).
sh "$G2_ROOT/installer/apply-branding.sh" "$EDIT"
MINIMAL="$G2_LINUX_BUILD/laptop-iso/iso/casper/minimal.squashfs"
sh "$G2_ROOT/installer/patch-gdm-theme.sh" "$EDIT" "$MINIMAL" || true
for f in \
	"$EDIT/usr/local/bin/group2-prepare-login" \
	"$EDIT/usr/local/bin/group2-fix-live-user" \
	"$EDIT/usr/local/bin/group2-desktop-setup" \
	"$EDIT/usr/local/bin/group2-about" \
	"$EDIT/etc/profile.d/group2-prompt.sh" \
	"$EDIT/etc/systemd/system/group2-live-user.service" \
	"$EDIT/etc/modules-load.d/fuse.conf"
do
	sed -i 's/\r$//' "$f" 2>/dev/null || true
done
NEW="$G2_LINUX_BUILD/laptop-iso/minimal.standard.live.squashfs.new"
rm -f "$NEW"
mksquashfs "$EDIT" "$NEW" -comp zstd -Xcompression-level 1 -b 1M -noappend -no-progress
mv -f "$NEW" "$LIVE"
STD_EDIT="$G2_LINUX_BUILD/laptop-iso/standard-edit"
STD="$G2_LINUX_BUILD/laptop-iso/iso/casper/minimal.standard.squashfs"
if [ -d "$STD_EDIT" ]; then
	echo "Copying Group 2 OS identity into the installed layer"
	sh "$G2_ROOT/installer/apply-branding.sh" "$STD_EDIT"
	sh "$G2_ROOT/installer/patch-gdm-theme.sh" "$STD_EDIT" "$MINIMAL" || true
	mkdir -p "$STD_EDIT/usr/local/bin" "$STD_EDIT/usr/share/applications" "$STD_EDIT/etc/profile.d"
	install -m 0755 "$EDIT/usr/local/bin/group2-about" "$STD_EDIT/usr/local/bin/group2-about"
	install -m 0644 "$EDIT/usr/share/applications/group2-about.desktop" \
		"$STD_EDIT/usr/share/applications/group2-about.desktop"
	install -m 0644 "$EDIT/etc/motd" "$STD_EDIT/etc/motd"
	install -m 0644 "$EDIT/etc/profile.d/group2-prompt.sh" "$STD_EDIT/etc/profile.d/group2-prompt.sh"
	if [ -f "$STD_EDIT/etc/bash.bashrc" ] && ! grep -q group2-prompt.sh "$STD_EDIT/etc/bash.bashrc"; then
		printf '\n[ -f /etc/profile.d/group2-prompt.sh ] && . /etc/profile.d/group2-prompt.sh\n' \
			>> "$STD_EDIT/etc/bash.bashrc"
	fi
	STD_NEW="$G2_LINUX_BUILD/laptop-iso/minimal.standard.squashfs.new"
	rm -f "$STD_NEW"
	mksquashfs "$STD_EDIT" "$STD_NEW" -comp zstd -Xcompression-level 1 -b 1M -noappend -no-progress
	mv -f "$STD_NEW" "$STD"
fi
sh "$G2_ROOT/scripts/rebuild-iso-only.sh"
