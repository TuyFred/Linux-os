#!/bin/sh
# Compile the Linux kernel from linux-master with GROUP 2 OS branding.
set -eu
. "$(dirname "$0")/lib.sh"
require_linux
require_dir "$G2_KERNEL"

echo_step "Building Linux kernel from source"
echo "Kernel tree: $G2_KERNEL"
echo "Jobs:        $G2_JOBS"

cd "$G2_KERNEL"

if [ ! -f .config ]; then
	echo "Creating x86_64 defconfig..."
	make ARCH=x86_64 defconfig
fi

if [ -f "$G2_CONFIGS/kernel-group2.fragment" ]; then
	echo "Merging GROUP 2 OS kernel branding..."
	bash ./scripts/kconfig/merge_config.sh -m .config "$G2_CONFIGS/kernel-group2.fragment"
	make ARCH=x86_64 olddefconfig
fi

make ARCH=x86_64 -j"$G2_JOBS" bzImage

KERNEL_IMAGE="$G2_KERNEL/arch/x86/boot/bzImage"
if [ ! -f "$KERNEL_IMAGE" ]; then
	echo "Kernel build finished but bzImage was not found."
	exit 1
fi

mkdir -p "$G2_OUT"
cp -f "$KERNEL_IMAGE" "$G2_OUT/vmlinuz"
echo "Kernel image: $G2_OUT/vmlinuz"
make -C "$G2_KERNEL" ARCH=x86_64 -s kernelrelease
echo "Kernel release: $(make -C "$G2_KERNEL" ARCH=x86_64 -s kernelrelease)"
