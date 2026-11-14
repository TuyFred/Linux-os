#!/bin/sh
# Keep a terminal login in sync with the graphical desktop layout.
if [ -x /usr/local/bin/group2-desktop-setup ]; then
	/usr/local/bin/group2-desktop-setup
fi
