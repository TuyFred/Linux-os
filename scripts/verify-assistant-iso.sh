#!/bin/bash
set -eu
G2="/mnt/c/Users/USER/GROUP 2 OS"
echo "=== ISO ==="
ls -lh "$G2/build/out/GROUP2-OS.iso"
ls -lh /root/group2-build/out/GROUP2-OS.iso 2>/dev/null || true
echo "=== Assistant in live squash ==="
unsquashfs -l /root/group2-build/laptop-iso/iso/casper/minimal.standard.live.squashfs 2>/dev/null \
  | grep -E "assistant_engine|group2-assistant|assistant-answers" | head -30
echo "=== Engine selftest ==="
python3 "$G2/installer/overlay/usr/local/lib/group2/assistant_engine.py" --selftest
echo "=== Sample install answer ==="
python3 "$G2/installer/overlay/usr/local/lib/group2/assistant_engine.py" "how do I install" | head -15
echo "VERIFY_DONE"
