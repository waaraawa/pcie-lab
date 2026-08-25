#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

pcie_bzimage=$PCIE_DEBUG_BZIMAGE
pcie_vmlinux=$PCIE_DEBUG_VMLINUX

for pcie_required_file in "$PCIE_GUEST_OVERLAY" "$PCIE_SEED_ISO" "$PCIE_SSH_KEY" "$pcie_bzimage" "$pcie_vmlinux"; do
    if [ ! -f "$pcie_required_file" ]; then
        printf 'Missing %s; prepare the VM and build the debug kernel first.\n' "$pcie_required_file" >&2
        exit 1
    fi
done

if [ -f "$PCIE_QEMU_PID" ] && kill -0 "$(cat "$PCIE_QEMU_PID")" 2>/dev/null; then
    printf 'QEMU is already running with PID %s.\n' "$(cat "$PCIE_QEMU_PID")" >&2
    exit 1
fi

if lsof -nP -iTCP:"$PCIE_SSH_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'SSH port %s is already in use.\n' "$PCIE_SSH_PORT" >&2
    exit 1
fi

if lsof -nP -iTCP:"$PCIE_GDB_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'GDB port %s is already in use.\n' "$PCIE_GDB_PORT" >&2
    exit 1
fi

qemu-system-x86_64 \
    -name pcie-phase0-debug \
    -machine q35,accel=hvf \
    -cpu host \
    -smp 2 \
    -m 2048 \
    -display none \
    -serial "file:${PCIE_DEBUG_SERIAL_LOG}" \
    -monitor "unix:${PCIE_QEMU_MONITOR},server=on,wait=off" \
    -kernel "$pcie_bzimage" \
    -append 'root=LABEL=cloudimg-rootfs ro console=ttyS0 nokaslr' \
    -drive "file=${PCIE_GUEST_OVERLAY},format=qcow2,if=virtio" \
    -drive "file=${PCIE_SEED_ISO},format=raw,media=cdrom,readonly=on" \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${PCIE_SSH_PORT}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -device edu \
    -gdb "tcp:127.0.0.1:${PCIE_GDB_PORT}" \
    -S \
    -no-reboot \
    -daemonize \
    -pidfile "$PCIE_QEMU_PID"

printf 'Debug VM is paused at reset with PID %s.\n' "$(cat "$PCIE_QEMU_PID")"
printf 'Run test-gdb.sh to connect, break at start_kernel, and continue.\n'
