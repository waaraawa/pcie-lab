#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

mkdir -p "$PCIE_PHASE0_DIR" "$PCIE_SEED_DIR" "$PCIE_MODULE_OUTPUT"

if [ ! -f "$PCIE_GUEST_IMAGE" ]; then
    curl -fL --retry 2 -o "$PCIE_GUEST_IMAGE" "$PCIE_GUEST_IMAGE_URL"
fi

pcie_actual_sha=$(shasum -a 256 "$PCIE_GUEST_IMAGE" | awk '{print $1}')
if [ "$pcie_actual_sha" != "$PCIE_GUEST_IMAGE_SHA256" ]; then
    printf 'Guest image checksum mismatch.\nExpected: %s\nActual:   %s\n' \
        "$PCIE_GUEST_IMAGE_SHA256" "$pcie_actual_sha" >&2
    exit 1
fi

if [ ! -f "$PCIE_GUEST_OVERLAY" ]; then
    qemu-img create -f qcow2 -F qcow2 -b "$PCIE_GUEST_IMAGE" "$PCIE_GUEST_OVERLAY"
fi

if [ -f "$PCIE_SEED_ISO" ] && [ ! -f "$PCIE_SSH_KEY" ]; then
    printf 'Seed ISO exists but its SSH private key is missing.\n' >&2
    printf 'Use a new PCIE_PHASE0_DIR or deliberately recreate both artifacts.\n' >&2
    exit 1
fi

if [ ! -f "$PCIE_SSH_KEY" ]; then
    ssh-keygen -q -t ed25519 -N '' -C pcie-phase0-ephemeral -f "$PCIE_SSH_KEY"
fi

pcie_public_key=$(cat "${PCIE_SSH_KEY}.pub")

if [ ! -f "$PCIE_SEED_ISO" ]; then
    cat > "$PCIE_SEED_DIR/user-data" <<EOF
#cloud-config
hostname: pcie-lab
manage_etc_hosts: true
users:
  - name: ${PCIE_GUEST_USER}
    gecos: PCIe Lab User
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ${pcie_public_key}
ssh_pwauth: false
disable_root: true
package_update: false
package_upgrade: false
runcmd:
  - [sh, -c, "printf 'phase0-ready\\n' > /var/tmp/phase0-ready"]
EOF

    cat > "$PCIE_SEED_DIR/meta-data" <<EOF
instance-id: pcie-phase0-20260805
local-hostname: pcie-lab
EOF

    hdiutil makehybrid -o "$PCIE_SEED_ISO" "$PCIE_SEED_DIR" \
        -iso -joliet -default-volume-name cidata
fi

printf 'Phase 0 VM artifacts are ready under %s\n' "$PCIE_PHASE0_DIR"
printf 'The SSH private key is ephemeral. Never commit it.\n'
