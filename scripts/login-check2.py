#!/usr/bin/env python3
import os, select, socket, subprocess, time

ISO = "/root/group2-build/out/GROUP2-OS.iso"
KNL = "/root/group2-build/boot-test/vmlinuz"
IRD = "/root/group2-build/boot-test/initrd"
SOCK = "/root/group2-build/boot-test/serial.sock"
try:
    os.remove(SOCK)
except FileNotFoundError:
    pass

proc = subprocess.Popen([
    "qemu-system-x86_64", "-machine", "q35,accel=kvm", "-cpu", "host",
    "-m", "3584", "-smp", "2", "-cdrom", ISO, "-kernel", KNL, "-initrd", IRD,
    "-append", "username=group2 hostname=group2-os console=ttyS0,115200n8 loglevel=3 plymouth.enable=0 ---",
    "-display", "none", "-serial", f"unix:{SOCK},server,nowait", "-no-reboot",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
end = time.time() + 30
while time.time() < end:
    try:
        sock.connect(SOCK)
        break
    except OSError:
        time.sleep(0.2)
else:
    proc.kill()
    raise SystemExit("no socket")

buf = b""

def wait(token, timeout):
    global buf
    needle = token.encode()
    stop = time.time() + timeout
    while needle not in buf and time.time() < stop:
        ready, _, _ = select.select([sock], [], [], 1)
        if ready:
            chunk = sock.recv(8192)
            if not chunk:
                break
            buf += chunk
    return needle in buf

def send(text):
    time.sleep(0.4)
    sock.sendall(text.encode())

wait("login:", 180)
send("group2\n")
print("group2_password", wait("Password:", 15))
send("group2\n")
time.sleep(2)
got_shell = wait("group2@", 25)
print("group2_shell", got_shell)
if "Login incorrect" in buf.decode("utf-8", "replace"):
    print("group2_incorrect")
if got_shell:
    send("echo SHELL=$SHELL; id; ls /home/group2/Desktop; echo CHECK_DONE\n")
    wait("CHECK_DONE", 20)
text = buf.decode("utf-8", "replace")
open("/root/group2-build/boot-test/login2.txt", "w", encoding="utf-8", errors="replace").write(text)
for line in text.splitlines():
    if any(k in line for k in ("SHELL=", "uid=", "Desktop", "CHECK_DONE", "incorrect", "nologin", "group2@")):
        print(line[:220])
proc.kill()
print("LOGIN2_DONE")
