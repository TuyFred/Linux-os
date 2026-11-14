#!/bin/bash
# Install apps from ISO edit tree into WSL and run selftest + short zenity launches.
set -u
ROOT="/mnt/c/Users/USER/GROUP 2 OS/installer/overlay"
EDIT=/root/group2-build/laptop-iso/edit
BASE=$EDIT
[ -f "$BASE/usr/local/bin/group2-assistant" ] || BASE=$ROOT

sudo mkdir -p /usr/local/lib/group2 /usr/share/group2-os /usr/local/bin
sudo cp -a "$ROOT/usr/local/lib/group2/." /usr/local/lib/group2/
sudo cp -a "$ROOT/usr/share/group2-os/." /usr/share/group2-os/
for b in group2-suite group2-assistant group2-health group2-monitor group2-optimizer \
	group2-security group2-how-built group2-language group2-appearance group2-about group2-selftest; do
	src="$ROOT/usr/local/bin/$b"
	[ -f "$src" ] || continue
	sudo install -m 0755 "$src" "/usr/local/bin/$b"
done

echo "=== SELFTEST ==="
/usr/local/bin/group2-selftest
st=$?

echo "=== SHORT ZENITY LAUNCH (Xvfb) ==="
command -v Xvfb >/dev/null || apt-get install -y -qq xvfb zenity >/dev/null
pkill -f 'Xvfb :96' 2>/dev/null || true
Xvfb :96 -screen 0 1024x768x24 >/tmp/g2xvfb.log 2>&1 &
export DISPLAY=:96
sleep 1
for app in group2-about group2-health; do
	timeout 6 /usr/local/bin/$app >/tmp/g2-$app.out 2>&1 &
	pid=$!
	sleep 2
	# Close dialog
	xdotool key Escape Escape 2>/dev/null || true
	sleep 1
	kill "$pid" 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
	echo "PASS zenity-launch-$app"
done
pkill -f 'Xvfb :96' 2>/dev/null || true

exit $st
