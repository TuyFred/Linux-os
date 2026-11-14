#!/bin/sh
# Apply GROUP 2 OS identity onto an extracted Ubuntu/Linux root filesystem.
# Usage: apply-branding.sh /path/to/edit-root
set -eu

EDIT=${1:?usage: apply-branding.sh EDIT_ROOT}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BRANDING="$ROOT/branding"
OVERLAY="$ROOT/installer/overlay"

if [ ! -d "$EDIT" ]; then
	echo "Edit root not found: $EDIT"
	exit 1
fi

mkdir -p \
	"$EDIT/etc/group2-os" \
	"$EDIT/etc/skel/Desktop" \
	"$EDIT/etc/skel/.config/gtk-3.0" \
	"$EDIT/etc/skel/.config/gtk-4.0" \
	"$EDIT/usr/share/backgrounds" \
	"$EDIT/usr/share/gnome-background-properties" \
	"$EDIT/usr/share/group2-os/icons" \
	"$EDIT/usr/share/pixmaps" \
	"$EDIT/usr/share/plymouth/themes/group2-os" \
	"$EDIT/etc/dconf/db/local.d" \
	"$EDIT/etc/dconf/db/gdm.d" \
	"$EDIT/etc/dconf/profile" \
	"$EDIT/etc/profile.d" \
	"$EDIT/usr/local/bin" \
	"$EDIT/usr/share/glib-2.0/schemas"

cp -a "$OVERLAY"/. "$EDIT"/

if [ -f "$ROOT/userspace/g2-install" ]; then
	install -m 0755 "$ROOT/userspace/g2-install" "$EDIT/usr/local/bin/g2-install"
fi
chmod 755 "$EDIT/etc/profile.d/group2-setup.sh" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-desktop-setup" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-about" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-fix-live-user" 2>/dev/null || true
chmod 440 "$EDIT/etc/sudoers.d/group2-fix" 2>/dev/null || true
mkdir -p "$EDIT/etc/systemd/system/multi-user.target.wants"
ln -sfn ../group2-live-user.service \
	"$EDIT/etc/systemd/system/multi-user.target.wants/group2-live-user.service"
mkdir -p "$EDIT/etc/systemd/system/graphical.target.wants"
ln -sfn ../group2-fix-shell.service \
	"$EDIT/etc/systemd/system/graphical.target.wants/group2-fix-shell.service"
ln -sfn ../group2-firstboot.service \
	"$EDIT/etc/systemd/system/multi-user.target.wants/group2-firstboot.service"
ln -sfn ../group2-gemini.service \
	"$EDIT/etc/systemd/system/multi-user.target.wants/group2-gemini.service"
# Gemini key is backend-only. The desktop UI never receives it.
if [ -f "$ROOT/installer/secrets/gemini-api-key" ]; then
	mkdir -p "$EDIT/etc/group2-os/secrets"
	install -m 600 "$ROOT/installer/secrets/gemini-api-key" \
		"$EDIT/etc/group2-os/secrets/gemini-api-key"
fi
# Do not hook this into GDM. Running it there printed usermod on the console.
# Do not read the whole ISO at boot. That check makes startup look stuck.
mkdir -p "$EDIT/etc/systemd/system"
ln -sfn /dev/null "$EDIT/etc/systemd/system/casper-md5check.service"
mkdir -p "$EDIT/etc/skel/.config/autostart"
if [ -f "$EDIT/etc/xdg/autostart/group2-desktop.desktop" ]; then
	cp -f "$EDIT/etc/xdg/autostart/group2-desktop.desktop" \
		"$EDIT/etc/skel/.config/autostart/group2-desktop.desktop"
fi

# Each mockup is a different screen. Never copy the combined 4-panel image.
mkdir -p "$EDIT/usr/share/backgrounds/group2-os"
if [ -f "$BRANDING/desktop-wallpaper.png" ]; then
	cp -f "$BRANDING/desktop-wallpaper.png" "$EDIT/usr/share/backgrounds/group2-os-desktop.png"
	cp -f "$BRANDING/desktop-wallpaper.png" "$EDIT/usr/share/backgrounds/group2-os/group2-os-desktop.png"
	mkdir -p "$EDIT/etc/skel/Desktop/Pictures" "$EDIT/etc/skel/Pictures"
	cp -f "$BRANDING/desktop-wallpaper.png" "$EDIT/etc/skel/Desktop/Pictures/group2-os-wallpaper.png"
	cp -f "$BRANDING/desktop-wallpaper.png" "$EDIT/etc/skel/Pictures/group2-os-wallpaper.png"
fi
# Refresh designed login wallpaper (welcome chrome; real GDM draws password / Sign In).
if command -v python3 >/dev/null 2>&1 && [ -f "$ROOT/scripts/make-login-screen.py" ]; then
	python3 "$ROOT/scripts/make-login-screen.py" 2>/dev/null || true
fi
if [ -f "$BRANDING/login-background.png" ]; then
	cp -f "$BRANDING/login-background.png" "$EDIT/usr/share/backgrounds/group2-os-login.png"
	cp -f "$BRANDING/login-background.png" "$EDIT/usr/share/backgrounds/group2-os/group2-os-login.png"
fi
mkdir -p "$EDIT/usr/share/pixmaps"
if [ -f "$BRANDING/group2-os-logo.png" ]; then
	cp -f "$BRANDING/group2-os-logo.png" "$EDIT/usr/share/pixmaps/group2-os.png"
fi
# Default time zone for login clock (installer can still change it).
if [ -f "$EDIT/usr/share/zoneinfo/Africa/Kigali" ] || [ -f /usr/share/zoneinfo/Africa/Kigali ]; then
	echo 'Africa/Kigali' > "$EDIT/etc/timezone"
	if [ -f "$EDIT/usr/share/zoneinfo/Africa/Kigali" ]; then
		ln -sfn /usr/share/zoneinfo/Africa/Kigali "$EDIT/etc/localtime" 2>/dev/null || true
	fi
fi
# Login clock extension (live date/time under the design).
chmod 644 "$EDIT/usr/share/gnome-shell/extensions/group2-login-clock@group2-os/"* 2>/dev/null || true
if [ -f "$BRANDING/boot-background.png" ]; then
	cp -f "$BRANDING/boot-background.png" "$EDIT/usr/share/backgrounds/group2-os/group2-os-boot.png"
fi
if [ -f "$BRANDING/wallpaper.jpg" ]; then
	cp -f "$BRANDING/wallpaper.jpg" "$EDIT/usr/share/backgrounds/group2-os/group2-os-light.png"
elif [ -f "$BRANDING/grub-background.png" ]; then
	cp -f "$BRANDING/grub-background.png" "$EDIT/usr/share/backgrounds/group2-os/group2-os-light.png"
fi
if [ -f "$EDIT/usr/share/plymouth/themes/group2-os/logo.png" ]; then
	cp -f "$EDIT/usr/share/plymouth/themes/group2-os/logo.png" \
		"$EDIT/usr/share/pixmaps/group2-os.png"
	cp -f "$EDIT/usr/share/plymouth/themes/group2-os/logo.png" \
		"$EDIT/usr/share/pixmaps/ubuntu-logo.png"
	cp -f "$EDIT/usr/share/plymouth/themes/group2-os/logo.png" \
		"$EDIT/usr/share/pixmaps/ubuntu-logo-icon.png"
fi
# Plymouth uses logo.png + a real progress bar. Do not copy the mockup screenshot.
mkdir -p "$EDIT/usr/share/plymouth/themes"
cp -f "$EDIT/usr/share/plymouth/themes/group2-os/group2-os.plymouth" \
	"$EDIT/usr/share/plymouth/themes/default.plymouth" 2>/dev/null || true
if [ -f "$EDIT/usr/share/plymouth/themes/group2-os/logo.png" ]; then
	cp -f "$EDIT/usr/share/plymouth/themes/group2-os/logo.png" \
		"$EDIT/usr/share/pixmaps/group2-login-logo.png"
fi
if [ -f "$BRANDING/files-reference.png" ]; then
	cp -f "$BRANDING/files-reference.png" "$EDIT/usr/share/group2-os/files-reference.png"
fi

if [ -f "$BRANDING/members.txt" ]; then
	cp -f "$BRANDING/members.txt" "$EDIT/etc/group2-os/members.txt"
	cp -f "$BRANDING/members.txt" "$EDIT/usr/share/group2-os/members.txt"
fi
if [ -f "$BRANDING/slogan.txt" ]; then
	cp -f "$BRANDING/slogan.txt" "$EDIT/etc/group2-os/slogan.txt"
fi
if [ -f "$BRANDING/ascii-boot.txt" ]; then
	cp -f "$BRANDING/ascii-boot.txt" "$EDIT/usr/share/group2-os/boot.txt"
fi
if [ -f "$BRANDING/ascii-login.txt" ]; then
	cp -f "$BRANDING/ascii-login.txt" "$EDIT/usr/share/group2-os/login.txt"
fi
if [ -f "$BRANDING/DESIGN.txt" ]; then
	cp -f "$BRANDING/DESIGN.txt" "$EDIT/usr/share/group2-os/DESIGN.txt"
fi

# Desktop folders for every new user (live session and installed system)
for name in \
	"Fred Tuyishime" \
	"Tuyishimire Innocent" \
	"Armand Ikirezi" \
	"Ineza shami Lamick" \
	"Gabiro Vladmir Brenn" \
	"Irakoze Aline" \
	"Niyonkuru Tajidini" \
	"Projects" \
	"Documents" \
	"Pictures" \
	"Music" \
	"Videos" \
	"Trash"
do
	mkdir -p "$EDIT/etc/skel/Desktop/$name"
done

printf 'Fred Tuyishime\n' > "$EDIT/etc/skel/Desktop/Fred Tuyishime/README.txt"
printf 'Tuyishimire Innocent\n' > "$EDIT/etc/skel/Desktop/Tuyishimire Innocent/README.txt"
printf 'Armand Ikirezi\n' > "$EDIT/etc/skel/Desktop/Armand Ikirezi/README.txt"
printf 'Ineza shami Lamick\n' > "$EDIT/etc/skel/Desktop/Ineza shami Lamick/README.txt"
printf 'Gabiro Vladmir Brenn\n' > "$EDIT/etc/skel/Desktop/Gabiro Vladmir Brenn/README.txt"
printf 'Irakoze Aline\n' > "$EDIT/etc/skel/Desktop/Irakoze Aline/README.txt"
printf 'Niyonkuru Tajidini\n' > "$EDIT/etc/skel/Desktop/Niyonkuru Tajidini/README.txt"

# Keep Ubuntu's passwd/shadow. Only replace identity files.
chmod 644 "$EDIT/etc/os-release" "$EDIT/etc/lsb-release" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-prepare-login" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-terminal" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-fix-live-user" 2>/dev/null || true
# Stock Terminal icons still open our bash wrapper.
if [ -f "$EDIT/usr/share/applications/org.gnome.Terminal.desktop" ]; then
	sed -i 's|^Exec=.*|Exec=/usr/local/bin/group2-terminal|' \
		"$EDIT/usr/share/applications/org.gnome.Terminal.desktop" 2>/dev/null || true
fi
if [ -f "$EDIT/usr/share/applications/org.gnome.Console.desktop" ]; then
	sed -i 's|^Exec=.*|Exec=/usr/local/bin/group2-terminal|' \
		"$EDIT/usr/share/applications/org.gnome.Console.desktop" 2>/dev/null || true
fi
if [ -f "$EDIT/etc/adduser.conf" ]; then
	if grep -q '^#*DSHELL=' "$EDIT/etc/adduser.conf" 2>/dev/null; then
		sed -i 's|^#*DSHELL=.*|DSHELL=/bin/bash|' "$EDIT/etc/adduser.conf" 2>/dev/null || true
	else
		printf '\nDSHELL=/bin/bash\n' >> "$EDIT/etc/adduser.conf"
	fi
fi
# GRUB theme font so the installed bootloader looks like Group 2 OS.
if [ -d "$EDIT/usr/share/grub/themes/group2-os" ]; then
	for font in /usr/share/grub/unicode.pf2 "$EDIT/usr/share/grub/unicode.pf2"; do
		if [ -f "$font" ]; then
			cp -f "$font" "$EDIT/usr/share/grub/themes/group2-os/unicode.pf2"
			break
		fi
	done
fi
chmod 755 "$EDIT/usr/local/bin/group2-firstboot" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-appearance" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/bin/group2-assistant" \
	"$EDIT/usr/local/bin/group2-health" \
	"$EDIT/usr/local/bin/group2-monitor" \
	"$EDIT/usr/local/bin/group2-optimizer" \
	"$EDIT/usr/local/bin/group2-security" \
	"$EDIT/usr/local/bin/group2-how-built" \
	"$EDIT/usr/local/bin/group2-language" \
	"$EDIT/usr/local/bin/group2-suite" \
	"$EDIT/usr/local/bin/group2-accounts" 2>/dev/null || true
chmod 755 "$EDIT/usr/local/sbin/group2-account-helper" 2>/dev/null || true
# Windows checkouts can leave CR characters that stop a desktop script from opening.
find "$EDIT/usr/local/bin" "$EDIT/usr/local/sbin" "$EDIT/usr/share/applications" \
	"$EDIT/usr/local/lib/group2" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true
chmod 644 "$EDIT/usr/local/lib/group2/common.sh" \
	"$EDIT/usr/local/lib/group2/assistant_engine.py" 2>/dev/null || true
# English presentation guide from the project (keep in sync).
if [ -f "$ROOT/HOW-GROUP2-OS-IS-BUILT.md" ]; then
	mkdir -p "$EDIT/usr/share/group2-os/docs"
	cp -f "$ROOT/HOW-GROUP2-OS-IS-BUILT.md" "$EDIT/usr/share/group2-os/docs/HOW-BUILT.en.md"
fi
# Prefer speech synthesis when the layer has packages; ensure wrapper exists.
true

mkdir -p "$EDIT/etc/alternatives"
ln -sfn /usr/share/plymouth/themes/group2-os/group2-os.plymouth \
	"$EDIT/etc/alternatives/default.plymouth"
if command -v dconf >/dev/null 2>&1; then
	dconf compile "$EDIT/etc/dconf/db/gdm" "$EDIT/etc/dconf/db/gdm.d" || true
	dconf compile "$EDIT/etc/dconf/db/local" "$EDIT/etc/dconf/db/local.d" || true
fi
if command -v glib-compile-schemas >/dev/null 2>&1; then
	glib-compile-schemas "$EDIT/usr/share/glib-2.0/schemas" 2>/dev/null || true
fi

echo "GROUP 2 branding applied to $EDIT"
