#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_dir="$(cd -- "${script_dir}/../../.." && pwd)"
readonly local_dir="${PCIE_WSL_LOCAL_DIR:-${project_dir}/local/wsl}"
readonly kernel_dir="${PCIE_KERNEL_DIR:-${local_dir}/linux-6.12.101}"
readonly config_file="${kernel_dir}/.config"
readonly config_tool="${kernel_dir}/scripts/config"

readonly required_options=(
    KGDB
    KGDB_SERIAL_CONSOLE
    KGDB_KDB
    DMA_API_DEBUG
    PCIEAER
    PCI_DEBUG
)

die() {
    echo "error: $*" >&2
    exit 1
}

verify_config() {
    local opt
    [[ -f "${config_file}" ]] || die "kernel .config not found: ${config_file}"

    for opt in "${required_options[@]}"; do
        grep -qx "CONFIG_${opt}=y" "${config_file}" ||
            die "missing required option: CONFIG_${opt}=y in ${config_file}"
        echo "[OK] CONFIG_${opt}=y"
    done
}

[[ -d "${kernel_dir}" ]] || die "kernel directory not found: ${kernel_dir}"
[[ -x "${config_tool}" ]] || die "scripts/config not found: ${config_tool}"
[[ -f "${config_file}" ]] || die "kernel .config not found: ${config_file}"

if [[ "${1:-}" == "--check" ]]; then
    verify_config
    exit 0
fi

"${config_tool}" --file "${config_file}" \
    --enable KGDB \
    --enable KGDB_SERIAL_CONSOLE \
    --enable KGDB_KDB \
    --enable DMA_API_DEBUG \
    --enable PCIEAER \
    --enable PCI_DEBUG

make -C "${kernel_dir}" olddefconfig
verify_config

