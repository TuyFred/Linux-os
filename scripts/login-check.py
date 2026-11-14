#!/usr/bin/env python3
"""Boot the live ISO and check the serial login, shell, and desktop folders."""
import os
import select
import socket
import subprocess
import time

ISO = "/root/group2-build/out/GROUP2-OS.iso"
KNL = "/root/group2-build/boot-test/vmlinuz"
IRD = "/root/group2-build/boot-test/initrd"
SOCK = "/root/group2-build/boot-test/serial.sock"
LOG = "/root/group2-build/boot-test/login-check.log"

for path in (SOCK, LOG):
    try:
        os.remove(path)
    except FileNotFoundError:
        pass

cmd = [
    "qemu-system-x86_64",
    "-machine", "q35,accel=kvm",
    "-cpu", "host",
    "-m", "3584",
    "-smp", "2",
    "-cdrom", ISO,
    "-kernel", KNL,
    "-initrd", IRD,
    "-append", "console=ttyS0,115200n8 loglevel=3 plymouth.enable=0 ---",
    "-display", "none",
    "-serial", f"unix:{SOCK},server,nowait",
    "-no-reboot",
    "-netdev", "user,id=n0",
    "-device", "virtio-net-pci,netdev=n0",
]
proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
deadline = time.time() + 240
while time.time() < deadline:
    try:
        sock.connect(SOCK)
        break
    except (FileNotFoundError, ConnectionRefusedError):
        time.sleep(0.2)
else:
    proc.kill()
    raise SystemExit("serial socket never opened")

buf = b""
log = open(LOG, "wb")


def read_until(token, timeout):
    global buf
    end = time.time() + timeout
    needle = token.encode()
    while needle not in buf and time.time() < end:
        ready, _, _ = select.select([sock], [], [], 1)
        if not ready:
            continue
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
        log.write(chunk)
        log.flush()
    return needle in buf


def send(text):
    sock.sendall(text.encode())


ok = read_until("login:", 220)
print("saw_login", ok)
if not ok:
    proc.kill()
    raise SystemExit("no login prompt")

send("group2\n")
got_pw = read_until("assword", 20)
print("group2_password_prompt", got_pw)
if got_pw:
    send("group2\n")
    logged = read_until("$", 20) or read_until("#", 5)
    print("group2_shell", logged)
    if logged:
        send("echo SHELL=$SHELL; getent passwd group2; ls -d \"$HOME/Desktop\"/* 2>/dev/null | head -20; echo CHECK_DONE\n")
        read_until("CHECK_DONE", 20)
        send("exit\n")
        read_until("login:", 20)

send("ubuntu\n")
got_pw2 = read_until("assword", 20)
print("ubuntu_password_prompt", got_pw2)
if got_pw2:
    send("group2\n")
    logged2 = read_until("$", 20) or read_until("#", 5)
    print("ubuntu_shell", logged2)
    if logged2:
        send("echo SHELL=$SHELL; id; ls -d \"$HOME/Desktop\"/* 2>/dev/null | head -20; echo CHECK_DONE\n")
        read_until("CHECK_DONE", 20)

print("--- captured ---")
text = buf.decode("utf-8", "replace")
for line in text.splitlines():
    if any(k in line for k in ("SHELL=", "Desktop", "group2:", "ubuntu:", "uid=", "CHECK_DONE", "nologin", "incorrect")):
        print(line)
proc.kill()
print("LOGIN_CHECK_DONE")
