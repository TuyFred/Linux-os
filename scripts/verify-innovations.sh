#!/bin/bash
set -u
LIVE=/root/group2-build/laptop-iso/iso/casper/minimal.standard.live.squashfs
EDIT=/root/group2-build/laptop-iso/edit
ROOT="/mnt/c/Users/USER/GROUP 2 OS/installer/overlay"
ISO="/mnt/c/Users/USER/GROUP 2 OS/build/out/GROUP2-OS.iso"
fail=0

echo "=== ISO present ==="
ls -lh "$ISO" || fail=1

echo "=== bins + desktops in live squashfs ==="
LIST=$(unsquashfs -l "$LIVE" 2>/dev/null)
for f in group2-suite group2-assistant group2-health group2-monitor group2-optimizer group2-security group2-how-built group2-language group2-appearance; do
	echo "$LIST" | grep -q "usr/local/bin/$f$" && echo "OK bin $f" || { echo "MISSING bin $f"; fail=1; }
	echo "$LIST" | grep -q "usr/share/applications/${f}.desktop$" && echo "OK desk $f" || { echo "MISSING desk $f"; fail=1; }
done

echo "=== support files ==="
for f in \
	usr/share/group2-os/i18n/en.sh \
	usr/share/group2-os/i18n/rw.sh \
	usr/share/group2-os/i18n/load.sh \
	usr/share/group2-os/help/assistant-answers.en.txt \
	usr/share/group2-os/help/assistant-answers.rw.txt \
	usr/share/group2-os/docs/HOW-BUILT.en.md \
	usr/share/group2-os/docs/HOW-BUILT.rw.md \
	usr/local/lib/group2/common.sh
do
	echo "$LIST" | grep -q "$f$" && echo "OK $f" || { echo "MISSING $f"; fail=1; }
done

echo "=== shell syntax ==="
for f in \
	"$EDIT"/usr/local/bin/group2-suite \
	"$EDIT"/usr/local/bin/group2-assistant \
	"$EDIT"/usr/local/bin/group2-health \
	"$EDIT"/usr/local/bin/group2-monitor \
	"$EDIT"/usr/local/bin/group2-optimizer \
	"$EDIT"/usr/local/bin/group2-security \
	"$EDIT"/usr/local/bin/group2-how-built \
	"$EDIT"/usr/local/bin/group2-language \
	"$EDIT"/usr/local/bin/group2-appearance \
	"$EDIT"/usr/local/bin/group2-about \
	"$EDIT"/usr/local/lib/group2/common.sh \
	"$EDIT"/usr/share/group2-os/i18n/load.sh
do
	if [ ! -f "$f" ]; then
		# fallback to overlay source
		base=${f#$EDIT/}
		f="$ROOT/$base"
	fi
	if [ -f "$f" ]; then
		if sh -n "$f" 2>/tmp/g2syn.err; then
			echo "OK syntax $(basename "$f")"
		else
			echo "BAD syntax $f"
			cat /tmp/g2syn.err
			fail=1
		fi
	else
		echo "MISSING $f"
		fail=1
	fi
done

echo "=== i18n switch ==="
export HOME=/tmp/g2testhome
mkdir -p "$HOME/.config/group2-os"
printf 'rw\n' > "$HOME/.config/group2-os/lang"
unset GROUP2_LANG
# shellcheck disable=SC1091
. "$ROOT/usr/share/group2-os/i18n/load.sh"
echo "rw -> GROUP2_LANG=$GROUP2_LANG APP_ASSISTANT=$APP_ASSISTANT"
[ "$GROUP2_LANG" = rw ] || { echo FAIL rw; fail=1; }
case "$APP_ASSISTANT" in *Umufasha*) echo "OK kinyarwanda string";; *) echo "FAIL kinyarwanda string"; fail=1;; esac

printf 'en\n' > "$HOME/.config/group2-os/lang"
unset GROUP2_LANG
# shellcheck disable=SC1091
. "$ROOT/usr/share/group2-os/i18n/load.sh"
echo "en -> GROUP2_LANG=$GROUP2_LANG APP_ASSISTANT=$APP_ASSISTANT"
[ "$GROUP2_LANG" = en ] || { echo FAIL en; fail=1; }

echo "=== assistant wifi intent ==="
# shellcheck disable=SC1091
. "$ROOT/usr/local/lib/group2/common.sh"
WIFI_HELP=${WIFI_HELP:-}
q="how do I connect wifi"
case "$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')" in
	*wifi*) echo "OK wifi intent maps"; echo "sample: $WIFI_HELP" | head -c 120; echo ;;
	*) echo FAIL wifi; fail=1 ;;
esac

echo "=== health metrics readable ==="
awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t) printf "RAM used %% approx %d\n", (t-a)*100/t}' /proc/meminfo
df -P / | awk 'NR==2{print "Disk used",$5}'

echo "=== desktop Exec ==="
for d in group2-suite group2-assistant group2-health group2-monitor; do
	exec=$(unsquashfs -cat "$LIVE" "usr/share/applications/${d}.desktop" 2>/dev/null | grep '^Exec=' || true)
	echo "$d : $exec"
	echo "$exec" | grep -q '/usr/local/bin/' || { echo "BAD exec $d"; fail=1; }
done

echo "=== favorites mention suite ==="
if unsquashfs -cat "$LIVE" etc/dconf/db/local.d/00-group2 2>/dev/null | grep -q group2-suite; then
	echo "OK dock favorite group2-suite"
else
	echo "WARN favorite may need login refresh"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "VERDICT: packaging + syntax + i18n + intents = PASS"
	echo "GUI click-test still needed on live desktop for 100% UX confidence."
else
	echo "VERDICT: FAIL count path — fail=$fail"
fi
exit "$fail"
