#!/bin/bash
set -eu
export G2_ROOT="/mnt/c/Users/USER/GROUP 2 OS"
cd "$G2_ROOT"
echo "ROOT=$G2_ROOT"
pwd
bash scripts/rebuild-desktop-iso.sh
