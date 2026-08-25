#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

pcie_module=${PCIE_MODULE_OUTPUT}/phase0_sanity.ko
pcie_validation_log=${PCIE_PHASE0_DIR}/module-validation.log

if [ ! -f "$pcie_module" ]; then
    printf 'Missing %s; run build-module.sh first.\n' "$pcie_module" >&2
    exit 1
fi

scp -i "$PCIE_SSH_KEY" -P "$PCIE_SSH_PORT" \
    -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$pcie_module" "${PCIE_GUEST_USER}@127.0.0.1:/tmp/phase0_sanity.ko"

ssh -i "$PCIE_SSH_KEY" -p "$PCIE_SSH_PORT" \
    -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${PCIE_GUEST_USER}@127.0.0.1" \
    'set -eu
     printf "guest kernel: "; uname -r
     printf "module vermagic: "; modinfo -F vermagic /tmp/phase0_sanity.ko
     sudo insmod /tmp/phase0_sanity.ko
     test -d /sys/module/phase0_sanity
     sudo rmmod phase0_sanity
     test ! -d /sys/module/phase0_sanity
     sudo dmesg | grep "phase0_sanity:" | tail -n 2' \
    > "$pcie_validation_log"

cat "$pcie_validation_log"
