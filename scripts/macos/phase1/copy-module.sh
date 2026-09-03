#!/bin/sh
# Copy the built EDU module into the Intel macOS Phase 1 guest.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

. "${script_dir}/config.sh"

pcie_module=${PCIE_MODULE_OUTPUT}/edu_pci.ko
pcie_guest_module=/tmp/edu_pci.ko

if [ ! -f "$pcie_module" ]; then
	printf 'error: EDU module not found: %s\n' "$pcie_module" >&2
	printf 'Run scripts/macos/phase1/build-module.sh first.\n' >&2
	exit 1
fi

if [ ! -f "$PCIE_SSH_KEY" ]; then
	printf 'error: SSH key not found: %s\n' "$PCIE_SSH_KEY" >&2
	printf 'Run scripts/macos/phase1/prepare-vm.sh first.\n' >&2
	exit 1
fi

scp \
	-i "$PCIE_SSH_KEY" \
	-P "$PCIE_SSH_PORT" \
	-o BatchMode=yes \
	-o ConnectTimeout=5 \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	"$pcie_module" \
	"${PCIE_GUEST_USER}@127.0.0.1:${pcie_guest_module}"

printf '[OK] copied EDU module to guest: %s\n' "$pcie_guest_module"
