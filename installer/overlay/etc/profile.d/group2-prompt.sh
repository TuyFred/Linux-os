# Group 2 OS terminal identity. Does not replace Bash.
if [ -n "${BASH_VERSION:-}" ] && [ -z "${GROUP2_PROMPT:-}" ]; then
	GROUP2_PROMPT=1
	export GROUP2_PROMPT
	PS1='\[\e[36m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
	if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ -z "${GROUP2_WELCOME:-}" ]; then
		GROUP2_WELCOME=1
		export GROUP2_WELCOME
		printf '\n  Welcome to Group 2 OS  ·  Version 1.0\n  LEARN • BUILD • CREATE • TOGETHER\n\n'
	fi
fi
