#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_dir="$(cd -- "${script_dir}/../../.." && pwd)"
readonly local_dir="${PCIE_WSL_LOCAL_DIR:-${project_dir}/local/wsl}"
readonly kernel_dir="${PCIE_KERNEL_DIR:-${local_dir}/linux-6.12.101}"
readonly kernel_image="${PCIE_KERNEL_IMAGE:-${kernel_dir}/arch/x86/boot/bzImage}"
readonly initramfs_image="${PCIE_INITRAMFS_IMAGE:-${local_dir}/initramfs.cpio.gz}"
readonly gdb_address="${PCIE_GDB_ADDRESS:-127.0.0.1:1234}"

die() {
    echo "error: $*" >&2
    exit 1
}

command -v qemu-system-x86_64 >/dev/null 2>&1 ||
    die "qemu-system-x86_64 is not installed"

[[ -f "${kernel_image}" ]] || die "kernel image not found: ${kernel_image}"
[[ -f "${initramfs_image}" ]] || die "initramfs not found: ${initramfs_image}"

if [[ "${1:-}" == "--check" ]]; then
    echo "[OK] kernel image: ${kernel_image}"
    echo "[OK] initramfs image: ${initramfs_image}"
    echo "[OK] QEMU binary: $(command -v qemu-system-x86_64)"
    exit 0
fi

echo "Starting Linux 6.12.101 with QEMU EDU PCI device"
echo "  kernel : ${kernel_image}"
echo "  initrd : ${initramfs_image}"
echo "  GDB    : ${gdb_address}"
echo "  quit   : Ctrl-a, then x"

exec qemu-system-x86_64 \
    -machine q35 \
    -m 1G \
    -smp 2 \
    -kernel "${kernel_image}" \
    -initrd "${initramfs_image}" \
    -append "console=ttyS0 nokaslr rdinit=/init" \
    -device edu \
    -nographic \
    -no-reboot \
    -gdb "tcp:${gdb_address}" \
    "$@"
