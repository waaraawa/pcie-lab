#!/usr/bin/env bash
#
# Build Debian kernel packages (.deb) for the Phase 3 physical target PC.
#
# Prerequisites on the WSL/Ubuntu build host:
#   sudo apt-get update && sudo apt-get install -y debhelper dpkg-dev rsync
#   (Linux scripts/package/mkdebian requires debhelper-compat (= 12).)
#
# Usage:
#   ./scripts/wsl/phase3/build-deb-kernel.sh              # Build linux-image + linux-headers (fast default)
#   ./scripts/wsl/phase3/build-deb-kernel.sh --with-dbg   # Also build linux-image-*-dbg.deb (~374 MiB vmlinux)
#   ./scripts/wsl/phase3/build-deb-kernel.sh --check      # Verify generated .deb packages in local/wsl/
#
# Why -dbg.deb is skipped by default:
#   In a 2-PC serial kgdb setup, the host PC (WSL) runs GDB and reads DWARF symbols
#   directly from local/wsl/linux-6.12.101/vmlinux, so the target PC only needs
#   linux-image and linux-headers. Pass --with-dbg if you also want unstripped
#   vmlinux symbols installed on the target PC itself (e.g., for local perf/crash).

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_dir="$(cd -- "${script_dir}/../../.." && pwd)"
readonly local_dir="${PCIE_WSL_LOCAL_DIR:-${project_dir}/local/wsl}"
readonly kernel_dir="${PCIE_KERNEL_DIR:-${local_dir}/linux-6.12.101}"
readonly config_check="${script_dir}/configure-debug-kernel.sh"
readonly jobs="${PCIE_BUILD_JOBS:-$(nproc)}"

die() {
    echo "error: $*" >&2
    exit 1
}

check_packages() {
    local image_deb headers_deb dbg_deb
    image_deb="$(find "${local_dir}" -maxdepth 1 -name 'linux-image-6.12.101_*.deb' ! -name '*-dbg_*' | head -n 1)"
    headers_deb="$(find "${local_dir}" -maxdepth 1 -name 'linux-headers-6.12.101_*.deb' | head -n 1)"
    dbg_deb="$(find "${local_dir}" -maxdepth 1 -name 'linux-image-6.12.101-dbg_*.deb' | head -n 1)"

    [[ -n "${image_deb}" && -f "${image_deb}" ]] ||
        die "linux-image .deb not found in ${local_dir}"
    [[ -n "${headers_deb}" && -f "${headers_deb}" ]] ||
        die "linux-headers .deb not found in ${local_dir}"

    echo "[OK] kernel image package  : ${image_deb}"
    echo "[OK] kernel headers package: ${headers_deb}"
    if [[ -n "${dbg_deb}" && -f "${dbg_deb}" ]]; then
        echo "[OK] kernel debug package  : ${dbg_deb}"
    fi
}

if [[ "${1:-}" == "--check" ]]; then
    "${config_check}" --check
    check_packages
    exit 0
fi

command -v dpkg-buildpackage >/dev/null 2>&1 ||
    die "dpkg-buildpackage is not installed (run: sudo apt-get install -y dpkg-dev)"
command -v dh >/dev/null 2>&1 ||
    die "debhelper (dh) is not installed (run: sudo apt-get install -y debhelper)"
command -v rsync >/dev/null 2>&1 ||
    die "rsync is not installed (run: sudo apt-get install -y rsync)"

"${config_check}" --check

build_profiles="pkg.linux-upstream.nokerneldbg"
if [[ "${1:-}" == "--with-dbg" ]]; then
    build_profiles=""
fi

echo "Building Debian kernel packages in ${local_dir} (jobs=${jobs})..."
DEB_BUILD_PROFILES="${build_profiles}" \
    make -C "${kernel_dir}" -j"${jobs}" bindeb-pkg

check_packages

