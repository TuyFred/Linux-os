#!/bin/sh
# Append Group 2 OS GDM CSS to Ubuntu's gnome-shell theme gresource.
# Usage: patch-gdm-theme.sh EDIT_ROOT [minimal.squashfs]
set -eu

EDIT=${1:?usage: patch-gdm-theme.sh EDIT_ROOT [minimal.squashfs]}
MINIMAL=${2:-}
CSS_ADD="$EDIT/usr/share/gnome-shell/theme/group2-gdm.css"
if [ ! -f "$CSS_ADD" ]; then
	echo "No Group 2 GDM CSS at $CSS_ADD"
	exit 0
fi

if ! command -v gresource >/dev/null 2>&1; then
	echo "gresource not installed; GDM wallpaper still applies without CSS."
	exit 0
fi
if ! command -v glib-compile-resources >/dev/null 2>&1; then
	echo "glib-compile-resources not installed; GDM wallpaper still applies without CSS."
	exit 0
fi

WORKDIR=$(mktemp -d)
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

GRES=""
for candidate in \
	"$EDIT/usr/share/gnome-shell/gnome-shell-theme.gresource" \
	"$EDIT/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource" \
	"$EDIT/usr/share/gnome-shell/theme/Yaru-dark/gnome-shell-theme.gresource"
do
	if [ -f "$candidate" ]; then
		GRES=$candidate
		break
	fi
done

if [ -z "$GRES" ] && [ -n "$MINIMAL" ] && [ -f "$MINIMAL" ]; then
	unsquashfs -n -d "$WORKDIR/base" "$MINIMAL" \
		usr/share/gnome-shell/gnome-shell-theme.gresource \
		usr/share/gnome-shell/theme 2>/dev/null || true
	GRES=$(find "$WORKDIR/base" -name 'gnome-shell-theme.gresource' 2>/dev/null | head -n 1 || true)
fi

if [ -z "$GRES" ] || [ ! -f "$GRES" ]; then
	echo "Could not find gnome-shell-theme.gresource; login wallpaper still applies."
	exit 0
fi

echo "Patching GDM theme: $GRES"
mkdir -p "$WORKDIR/theme"
CSS_PATH=""
for res in $(gresource list "$GRES"); do
	rel=${res#/org/gnome/shell/theme/}
	rel=${rel#/}
	out="$WORKDIR/theme/$rel"
	mkdir -p "$(dirname "$out")"
	gresource extract "$GRES" "$res" > "$out" || true
	case "$rel" in
		gnome-shell.css|gdm.css|gdm3.css)
			CSS_PATH=$out
			;;
	esac
done

if [ -z "$CSS_PATH" ]; then
	CSS_PATH="$WORKDIR/theme/gnome-shell.css"
	: > "$CSS_PATH"
fi
# Refresh the login look instead of stacking another copy.
if grep -q 'Group 2 OS login' "$CSS_PATH" 2>/dev/null; then
	sed -i '/Group 2 OS login/,$d' "$CSS_PATH"
fi
printf '\n/* ---- Group 2 OS login ---- */\n' >> "$CSS_PATH"
cat "$CSS_ADD" >> "$CSS_PATH"

{
	echo '<?xml version="1.0" encoding="UTF-8"?>'
	echo '<gresources>'
	echo '  <gresource prefix="/org/gnome/shell/theme">'
	find "$WORKDIR/theme" -type f | sort | while read -r f; do
		name=${f#"$WORKDIR/theme/"}
		echo "    <file>$name</file>"
	done
	echo '  </gresource>'
	echo '</gresources>'
} > "$WORKDIR/gnome-shell-theme.gresource.xml"

( cd "$WORKDIR/theme" && glib-compile-resources \
	--sourcedir="$WORKDIR/theme" \
	--target="$WORKDIR/gnome-shell-theme.gresource" \
	"$WORKDIR/gnome-shell-theme.gresource.xml" )

mkdir -p "$EDIT/usr/share/gnome-shell"
cp -f "$WORKDIR/gnome-shell-theme.gresource" \
	"$EDIT/usr/share/gnome-shell/gnome-shell-theme.gresource"
# Also replace the original path if it lived under theme/
if [ "${GRES#*$EDIT}" != "$GRES" ]; then
	cp -f "$WORKDIR/gnome-shell-theme.gresource" "$GRES" 2>/dev/null || true
fi
echo "GDM theme patched with Group 2 OS login CSS."
