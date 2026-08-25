#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

ssh -i "$PCIE_SSH_KEY" -p "$PCIE_SSH_PORT" \
    -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${PCIE_GUEST_USER}@127.0.0.1" 'sudo systemctl poweroff'

pcie_attempt=1
while [ "$pcie_attempt" -le 20 ]; do
    if [ ! -f "$PCIE_QEMU_PID" ]; then
        qemu-img check "$PCIE_GUEST_OVERLAY"
        exit 0
    fi
    pcie_attempt=$((pcie_attempt + 1))
    sleep 1
done

printf 'Guest requested poweroff, but QEMU still appears active.\n' >&2
exit 1
