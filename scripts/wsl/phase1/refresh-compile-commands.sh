#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_dir="$(cd -- "${script_dir}/../../.." && pwd)"
readonly local_dir="${PCIE_WSL_LOCAL_DIR:-${project_dir}/local/wsl}"
readonly kernel_dir="${PCIE_KERNEL_DIR:-${local_dir}/linux-6.12.101}"
readonly generator="${kernel_dir}/scripts/clang-tools/gen_compile_commands.py"
readonly module_order="${project_dir}/driver/edu/modules.order"
readonly output="${project_dir}/compile_commands.json"

die() {
    echo "error: $*" >&2
    exit 1
}

command -v python3 >/dev/null 2>&1 || die "python3 is not installed"
[[ -f "${generator}" ]] || die "generator not found: ${generator}"
[[ -f "${module_order}" ]] ||
    die "build the EDU module first; missing: ${module_order}"

python3 "${generator}" \
    --directory "${kernel_dir}" \
    --output "${output}" \
    "${module_order}"

[[ -s "${output}" ]] || die "empty compile database: ${output}"
grep -Fq 'driver/edu/edu_pci.c' "${output}" ||
    die "EDU source entry not found in compile database"

echo "[OK] compile database: ${output}"
echo "[OK] source entry: driver/edu/edu_pci.c"
