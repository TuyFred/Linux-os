# How Group 2 OS is built

This guide explains the project in simple words. Use it when you present Group 2 OS.

Group 2 OS is our operating system. It is built on Linux. We did not throw Linux away. We kept the parts that make a computer work, and we put our own name, pictures, login, desktop, and installer on top.

The finished disc is:

`build\out\GROUP2-OS.iso`

---

## 1. The idea in one picture

Think of the computer start like a path:

1. Power on
2. The boot menu opens (Group 2 OS)
3. The system loads
4. The login screen appears
5. The user types a password
6. The desktop opens, with real folders and a dock
7. If the user chooses Install, Group 2 OS is copied onto the laptop

Our job was to design those screens and connect them to a real Linux system, so the ISO can be given to another person and installed.

---

## 2. What we kept, and what we changed

We kept these things so the computer still works:

- the Linux kernel (the part that talks to the hardware)
- Wi-Fi, USB, sound, and the browser
- the package system, so programs can still be installed
- the real installer

We changed what the person sees:

- the name Group 2 OS
- the login picture
- the desktop picture
- the folders of the group members
- the dock
- the file manager look
- the terminal greeting
- the About window

We did not claim we wrote a new kernel. Group 2 OS is our system identity, built on Linux.

---

## 3. Step by step: how the ISO was made

### Step 1. Start from a working Linux desktop

We started from Ubuntu 26.04 Desktop. That already knows how to boot, connect to the internet, play sound, and install onto a laptop.

### Step 2. Design four separate screens

We did not paste one big poster onto the desktop. Each picture is a different moment:

| Screen | What the user sees | Picture file |
| --- | --- | --- |
| Login | Night lake, then a real password box | `branding\login-background.png` |
| Desktop | Rwanda landscape, logo, and flag | `branding\desktop-wallpaper.png` |
| Boot | The start of the computer | `branding\boot-background.png` |
| Files | Dark file window with colored member folders | `branding\files-reference.png` is only a reference |

The slogan is: LEARN • BUILD • CREATE • TOGETHER.

### Step 3. Put our design into the system files

The folder `installer\overlay` is our design pack. Those files are copied onto the Linux system before the ISO is built. After install, they stay on the laptop.

### Step 4. Build the disc

The scripts in `scripts` pack everything into one file, `GROUP2-OS.iso`. That file is what VirtualBox or a USB stick boots.

### Step 5. Test the disc

We boot the ISO and check three things:

1. The computer starts.
2. The login appears.
3. The desktop is Group 2 OS, not a painted picture.

The same ISO works on a real laptop, in **VirtualBox**, and in other virtual machines.

---

## 3b. How to run Group 2 OS in VirtualBox

1. Open VirtualBox → **New**
2. Type: **Linux**, Version: **Ubuntu (64-bit)**
3. Memory: **4096 MB** or more
4. Create a virtual hard disk (for Install), or use none for Try only
5. Settings → **System** → Boot order: **Optical** first, then Hard Disk
6. Settings → **Display** → Graphics Controller: **VBoxSVGA** (not VMSVGA), 3D Acceleration: **Off**, Video Memory: **128 MB**
7. Settings → **Storage** → Controller: IDE/SATA → Empty disc → choose `build\out\GROUP2-OS.iso`
8. Start the VM
9. At the Group 2 OS boot menu:
   - Normal: **Try or Install Group 2 OS**
   - If the screen is black or shows red graphics errors: **Group 2 OS (VirtualBox / safe graphics)**
10. Live password: **group2**
11. To install: open **Install Group 2 OS**, finish the steps, Restart, then set Boot order to **Hard Disk** first

**If you see “no bootable device”:** the hard disk is empty and Optical is not first — put the ISO first, or finish Install first.

**VMware / other VMs:** same ISO. If graphics fail, choose **VirtualBox / safe graphics** on the boot menu.

## 4. Which folder does which job

Open the project folder `GROUP 2 OS`. These are the folders you need to point to.

### `branding`

This is the look of Group 2 OS.

- `login-background.png` — login background
- `desktop-wallpaper.png` — desktop background
- `boot-background.png` — start picture
- `files-reference.png` — example of the file window, not the real desktop
- `members.txt` — the names of the group
- `slogan.txt` — the slogan
- `DESIGN.txt` — the rule that the four screens stay separate

When someone asks “Where is the design?”, open `branding`.

### `installer`

This is how our design is placed onto Linux.

- `apply-branding.sh` — copies our files into the system
- `overlay` — the actual Group 2 OS files (name, login, desktop, folders, terminal)

When someone asks “Where did you customize the system?”, open `installer`.

### `installer\overlay`

This is the most important folder for the explanation. Each part has a job.

| What you want to explain | File or folder |
| --- | --- |
| The name of the OS | `etc\os-release` |
| Login screen background and sign-in | `usr\share\gnome-shell\theme\group2-gdm.css` and `etc\dconf\db\gdm.d\00-group2` |
| Desktop wallpaper, dock, and dark look | `etc\dconf\db\local.d\00-group2` |
| Desktop folders and icons | `usr\local\bin\group2-desktop-setup` |
| Folders created for every new user | `etc\skel` |
| Member folder colors | `usr\share\group2-os\icons` |
| File manager colors | `etc\gtk-3.0\gtk.css` and `etc\gtk-4.0\gtk.css` |
| Terminal greeting | `etc\motd` and `etc\profile.d\group2-prompt.sh` |
| About Group 2 OS | `usr\local\bin\group2-about` |
| Install button | `usr\share\applications\group2-install.desktop` |
| What the installer copies onto the laptop | `casper\install-sources.yaml` |
| Live user name | `etc\casper.conf` |

### `scripts`

This is the workshop. These files build the ISO. You do not need to read the code. You only need to know their job.

- `06-make-laptop-iso.sh` — builds the laptop ISO
- `rebuild-desktop-iso.sh` — rebuilds after a design change
- `brand-install-layer.sh` — makes sure Install keeps Group 2 OS, not plain Ubuntu
- `rebuild-iso-only.sh` — packs the disc again
- `patch-grub-cmdline.sh` — the first menu the computer shows

### `build\out`

This is the result.

- `GROUP2-OS.iso` — the file you boot or give to someone

### `linux-master`

This is Linux source kept in the project. The working ISO does not boot a homemade kernel from this folder. The ISO uses the Linux kernel that already works with laptops, Wi-Fi, and USB. Say that honestly if someone asks.

---

## 5. How to explain each screen

### Boot

The first menu is the bootloader. Its job is to start Group 2 OS. The menu text is set in `scripts\patch-grub-cmdline.sh`.

The first seconds of the loading picture still come from the original Linux boot file. We left that file unchanged on purpose. Changing it stopped the computer with a black error screen. The desktop and login are still Group 2 OS.

### Login

The login screen is real. It is not a picture of a password box. The background is our night-lake picture. The system draws the user, the password field, and the sign-in button.

On the live disc, if a password is asked for the live user, it is `group2`.

### Desktop

The wallpaper is the Rwanda landscape. The folders on the desktop are real folders. A click opens them. The dock at the bottom is the real application dock, not a drawing.

The script that creates the folders is `group2-desktop-setup`.

### Files

The file window uses a dark theme and colored folder icons. The icons are in `usr\share\group2-os\icons`.

### Install

Install is the real Linux installer (`ubuntu-desktop-bootstrap`), with our name on the button. **All of these steps are required:**

**Step 4 — Start Group 2 OS**  
At the boot menu select **Try or Install Group 2 OS**, then open **Install Group 2 OS**.

**Step 5 — Configure the installation**  
Language, keyboard, Wi-Fi if available, installation type and optional software.

**Step 6 — Choose disk installation**  
Install alongside Windows (if supported), **or** erase disk and install Group 2 OS, **or** manual partitioning.  
**Warning:** erasing the disk permanently deletes files — back up first.

**Step 7 — Set up your account**  
Name, computer name, username, password, and time zone (for example **Kigali, Rwanda** / `Africa/Kigali`).

**Step 8 — Finish installation**  
Click **Install** → wait → **Restart** → remove USB/ISO when instructed → log in with **your** password → connect to the internet and install updates.

**Sign Out and Restart** always return to the Group 2 OS login screen (autologin is disabled). The login shows live date and time for the system time zone.

During install, the person creates their own name and password. That person is the administrator after restart. The live password `group2` is only for trying the disc.

After the first boot from the hard disk, Group 2 OS runs a small first-boot setup so the bootloader theme, login, Terminal, Switch User, Restart, and “create other user” stay working.

The member list includes **Niyonkuru Tajidini** with the other group members.

The file that tells the installer to copy our branded system is `installer\overlay\casper\install-sources.yaml`.


### About

About Group 2 OS opens a window that reads the real computer: kernel version, memory, and storage. It says the system is based on Linux. That is the honest description.

### Group 2 innovations (unique tools)

On the dock / app menu, open **Group 2 Tools**:

| Tool | What it does |
| --- | --- |
| Language / Ururimi | English or **Kinyarwanda** for all Group 2 apps |
| Group 2 Assistant | **Offline:** Group 2 OS help (install, Wi-Fi, Terminal…). **Online:** same OS help plus answers to any question (web/Wikipedia; optional OpenAI/Groq key in `~/.config/group2-os/online-api-key`). Voice: Speak / Mute / Mic |
| How Group 2 OS Was Built | Presentation guide (EN + RW) + Terminal demo |
| System Health | Self-score (e.g. 82%) + recommended actions |
| Smart System Monitor | CPU, RAM, disk, battery, network, temperature |
| One-Click Optimizer | Clear safe caches, free space |
| Security & Privacy | Firewall, updates, privacy tips |

These stay after Install. They are not stock Ubuntu apps.

To prove they work on a build machine:

```bash
bash scripts/prove-ux.sh
```

Or inside Group 2 OS Terminal: `group2-selftest`

---

## 6. A short speech you can use

“We built Group 2 OS as our own desktop system. We started from Linux so the laptop hardware still works. Then we designed four separate screens: boot, login, desktop, and files. The login is a real password screen. The desktop has real folders and a real dock. The ISO file can be started in VirtualBox or installed on another laptop. After install, the user creates their own admin account, and the Group 2 OS look stays on the computer.”

---

## 7. If someone asks a hard question

**Did you write the kernel?**  
No. Group 2 OS uses the Linux kernel. We built the system identity, the screens, and the installable disc.

**Why does the first loading second sometimes say Ubuntu?**  
That line is inside the original boot file. We kept that file so the computer can start. Everything after that is Group 2 OS.

**Where is the ISO?**  
`build\out\GROUP2-OS.iso`

**What password is the live user?**  
`group2`. After install, use the password you created yourself.
