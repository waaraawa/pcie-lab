#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

pcie_attempt=1
while [ "$pcie_attempt" -le 30 ]; do
    if ssh -i "$PCIE_SSH_KEY" -p "$PCIE_SSH_PORT" \
        -o BatchMode=yes -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${PCIE_GUEST_USER}@127.0.0.1" \
        'cloud-init status --wait; uname -r; cat /var/tmp/phase0-ready; lspci -nn -d 1234:11e8' ; then
        exit 0
    fi
    pcie_attempt=$((pcie_attempt + 1))
    sleep 2
done

printf 'Guest SSH did not become ready. Inspect %s\n' "$PCIE_SERIAL_LOG" >&2
exit 1
