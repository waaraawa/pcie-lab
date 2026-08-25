#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

for pcie_required_file in "$PCIE_GUEST_OVERLAY" "$PCIE_SEED_ISO" "$PCIE_SSH_KEY"; do
    if [ ! -f "$pcie_required_file" ]; then
        printf 'Missing %s; run prepare-vm.sh first.\n' "$pcie_required_file" >&2
        exit 1
    fi
done

if [ -f "$PCIE_QEMU_PID" ] && kill -0 "$(cat "$PCIE_QEMU_PID")" 2>/dev/null; then
    printf 'QEMU is already running with PID %s.\n' "$(cat "$PCIE_QEMU_PID")" >&2
    exit 1
fi

if lsof -nP -iTCP:"$PCIE_SSH_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'TCP port %s is already in use. Override PCIE_SSH_PORT.\n' "$PCIE_SSH_PORT" >&2
    exit 1
fi

qemu-system-x86_64 \
    -name pcie-phase0 \
    -machine q35,accel=hvf \
    -cpu host \
    -smp 2 \
    -m 2048 \
    -display none \
    -serial "file:${PCIE_SERIAL_LOG}" \
    -monitor "unix:${PCIE_QEMU_MONITOR},server=on,wait=off" \
    -drive "file=${PCIE_GUEST_OVERLAY},format=qcow2,if=virtio" \
    -drive "file=${PCIE_SEED_ISO},format=raw,media=cdrom,readonly=on" \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${PCIE_SSH_PORT}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -device edu \
    -no-reboot \
    -daemonize \
    -pidfile "$PCIE_QEMU_PID"

printf 'QEMU started with PID %s.\n' "$(cat "$PCIE_QEMU_PID")"
printf 'Run wait-for-guest.sh before using the guest.\n'
