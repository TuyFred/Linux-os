#!/bin/bash
set -eu
G2="/mnt/c/Users/USER/GROUP 2 OS"
LIVE=/root/group2-build/laptop-iso/iso/casper/minimal.standard.live.squashfs
echo "=== ISO ==="
ls -lh "$G2/build/out/GROUP2-OS.iso"
echo "=== Assistant files ==="
unsquashfs -l "$LIVE" 2>/dev/null | grep -E "assistant_ui|gemini_backend|group2-gemini|group2-assistant" | head -20
echo "=== Key file mode (contents hidden) ==="
unsquashfs -ll "$LIVE" etc/group2-os/secrets/gemini-api-key 2>/dev/null | awk '{print $1, $NF}'
python3 - <<'PY'
from pathlib import Path
p=Path("/etc/group2-os/secrets/gemini-api-key")
print("host key present", p.is_file())
PY
# Confirm backend selftest still passes using the packaged module path via the project copy
python3 "$G2/installer/overlay/usr/local/lib/group2/gemini_backend.py" --selftest
echo VERIFY_ASSISTANT_DONE
