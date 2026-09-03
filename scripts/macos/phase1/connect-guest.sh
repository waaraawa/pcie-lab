#!/bin/sh
# Open an interactive SSH shell in the Intel macOS Phase 1 guest.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

. "${script_dir}/config.sh"

if [ ! -f "$PCIE_SSH_KEY" ]; then
	printf 'error: SSH key not found: %s\n' "$PCIE_SSH_KEY" >&2
	printf 'Run scripts/macos/phase1/prepare-vm.sh first.\n' >&2
	exit 1
fi

exec ssh \
	-i "$PCIE_SSH_KEY" \
	-p "$PCIE_SSH_PORT" \
	-o BatchMode=yes \
	-o ConnectTimeout=5 \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	"${PCIE_GUEST_USER}@127.0.0.1"
