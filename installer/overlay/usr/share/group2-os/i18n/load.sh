#!/bin/sh
# Load Group 2 OS language: en or rw (Kinyarwanda).
G2_I18N_DIR=/usr/share/group2-os/i18n
if [ ! -f "$G2_I18N_DIR/en.sh" ]; then
	# When sourced from the project overlay during tests.
	if [ -n "${BASH_SOURCE:-}" ]; then
		G2_I18N_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
	elif [ -f "./en.sh" ]; then
		G2_I18N_DIR=$(pwd)
	fi
fi
mkdir -p "${HOME:-/tmp}/.config/group2-os" 2>/dev/null || true
if [ -z "${GROUP2_LANG:-}" ]; then
	if [ -f "${HOME:-}/.config/group2-os/lang" ]; then
		GROUP2_LANG=$(tr -d ' \r\n' < "${HOME}/.config/group2-os/lang")
	elif [ -f /etc/group2-os/lang ]; then
		GROUP2_LANG=$(tr -d ' \r\n' < /etc/group2-os/lang)
	else
		case "${LANG:-}:${LC_MESSAGES:-}" in
			rw*|RW*|*:rw*|*:RW*) GROUP2_LANG=rw ;;
			*) GROUP2_LANG=en ;;
		esac
	fi
fi
case "$GROUP2_LANG" in
	rw|RW|kin|kinyarwanda) GROUP2_LANG=rw ;;
	*) GROUP2_LANG=en ;;
esac
export GROUP2_LANG
# shellcheck disable=SC1090
. "$G2_I18N_DIR/$GROUP2_LANG.sh"
t() {
	eval "printf '%s' \"\${$1:-$1}\""
}
