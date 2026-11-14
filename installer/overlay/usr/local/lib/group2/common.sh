#!/bin/sh
# Shared helpers for Group 2 OS innovation apps.
set -u
if [ -f /usr/share/group2-os/i18n/load.sh ]; then
	. /usr/share/group2-os/i18n/load.sh
elif [ -f /usr/local/lib/group2/../share/group2-os/i18n/load.sh ]; then
	. /usr/local/lib/group2/../share/group2-os/i18n/load.sh
fi

g2_zenity() {
	if command -v zenity >/dev/null 2>&1; then
		zenity "$@"
		return $?
	fi
	return 1
}

g2_speak_state() {
	f="${HOME:-/tmp}/.config/group2-os/voice-muted"
	mkdir -p "${HOME:-/tmp}/.config/group2-os" 2>/dev/null || true
	[ -f "$f" ] && echo muted || echo on
}

g2_set_mute() {
	mkdir -p "${HOME:-/tmp}/.config/group2-os" 2>/dev/null || true
	if [ "$1" = muted ]; then
		touch "${HOME}/.config/group2-os/voice-muted"
	else
		rm -f "${HOME}/.config/group2-os/voice-muted"
	fi
}

g2_speak() {
	text=$1
	[ -n "$text" ] || return 0
	if [ "$(g2_speak_state)" = muted ]; then
		return 0
	fi
	# Prefer espeak-ng; Kinyarwanda voice may fall back to English voice with text.
	if command -v espeak-ng >/dev/null 2>&1; then
		if [ "${GROUP2_LANG:-en}" = rw ]; then
			printf '%s' "$text" | espeak-ng -v rw+f3 -s 140 2>/dev/null || \
				printf '%s' "$text" | espeak-ng -v en -s 145 2>/dev/null || true
		else
			printf '%s' "$text" | espeak-ng -v en -s 145 2>/dev/null || true
		fi
		return 0
	fi
	if command -v espeak >/dev/null 2>&1; then
		printf '%s' "$text" | espeak -s 145 2>/dev/null || true
		return 0
	fi
	if command -v spd-say >/dev/null 2>&1; then
		spd-say "$text" 2>/dev/null || true
	fi
}

g2_info() {
	title=$1
	body=$2
	if g2_zenity --info --title="$title" --width=520 --height=320 --text="$body" 2>/dev/null; then
		return 0
	fi
	printf '%s\n\n%s\n' "$title" "$body"
}

g2_question_box() {
	title=$1
	prompt=$2
	if g2_zenity --entry --title="$title" --width=520 --text="$prompt" 2>/dev/null; then
		return 0
	fi
	printf '%s' "" 
}
