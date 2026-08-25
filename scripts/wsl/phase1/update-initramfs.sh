#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_dir="$(cd -- "${script_dir}/../../.." && pwd)"
readonly local_dir="${PCIE_WSL_LOCAL_DIR:-${project_dir}/local/wsl}"
readonly kernel_dir="${PCIE_KERNEL_DIR:-${local_dir}/linux-6.12.101}"
readonly source_module="${project_dir}/driver/edu/edu_pci.ko"
readonly initramfs_root="${PCIE_INITRAMFS_ROOT:-${local_dir}/initramfs}"
readonly initramfs_image="${PCIE_INITRAMFS_IMAGE:-${local_dir}/initramfs.cpio.gz}"
readonly staging_image="${initramfs_image}.new"

temporary_image=""

die() {
    echo "error: $*" >&2
    exit 1
}

cleanup() {
    if [[ -n "${temporary_image}" && -e "${temporary_image}" ]]; then
        rm -f -- "${temporary_image}"
    fi
}

usage() {
    cat <<'EOF'
Usage:
  scripts/wsl/phase1/update-initramfs.sh
      Copy, verify, package, and install
  scripts/wsl/phase1/update-initramfs.sh --check
      Verify the currently installed image
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

verify_module() {
    local module_path="$1"
    local label="$2"
    local module_vermagic
    local module_release

    [[ -f "${module_path}" ]] || die "${label} not found: ${module_path}"

    module_vermagic="$(modinfo -F vermagic "${module_path}")"
    module_release="${module_vermagic%% *}"
    [[ "${module_release}" == "${kernel_release}" ]] ||
        die "${label} targets ${module_release}, expected ${kernel_release}"

    echo "[OK] ${label}: Linux ${module_release}"
}

verify_copy() {
    verify_module "${installed_module}" "initramfs module copy"
    cmp -s -- "${source_module}" "${installed_module}" ||
        die "the copied module differs from driver/edu/edu_pci.ko"
    echo "[OK] copied module is byte-for-byte identical"
}

verify_image() {
    local image_path="$1"

    [[ -f "${image_path}" ]] || die "initramfs image not found: ${image_path}"

    gzip -t "${image_path}"
    echo "[OK] gzip integrity: $(basename -- "${image_path}")"

    if ! gzip -dc "${image_path}" |
        cpio --extract --quiet --to-stdout \
            "${archive_entry}" "./${archive_entry}" 2>/dev/null |
        cmp -s -- "${source_module}" -; then
        die "archive module is missing or differs from driver/edu/edu_pci.ko"
    fi

    echo "[OK] archive contains the identical module: ${archive_entry}"
}

mode="update"
case "${1:-}" in
    "")
        ;;
    --check)
        mode="check"
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

for command_name in cmp cpio file find gzip make modinfo; do
    require_command "${command_name}"
done

[[ -d "${kernel_dir}" ]] || die "kernel tree not found: ${kernel_dir}"
[[ -d "${initramfs_root}" ]] ||
    die "initramfs directory not found: ${initramfs_root}"

readonly kernel_release="$(
    make --no-print-directory -s -C "${kernel_dir}" kernelrelease
)"
readonly module_dir="${initramfs_root}/lib/modules/${kernel_release}/extra"
readonly installed_module="${module_dir}/edu_pci.ko"
readonly archive_entry="lib/modules/${kernel_release}/extra/edu_pci.ko"

verify_module "${source_module}" "built EDU module"
file "${source_module}"

if [[ "${mode}" == "check" ]]; then
    verify_copy
    verify_image "${initramfs_image}"
    echo "All checks passed."
    exit 0
fi

mkdir -p -- "${module_dir}"
cp -- "${source_module}" "${installed_module}"
verify_copy

temporary_image="$(mktemp "${initramfs_image}.tmp.XXXXXX")"
trap cleanup EXIT

(
    cd -- "${initramfs_root}"
    find . -print0 | cpio --null -o --format=newc --owner=root:root
) | gzip -9 >"${temporary_image}"

verify_image "${temporary_image}"
chmod 0644 "${temporary_image}"

mv -- "${temporary_image}" "${staging_image}"
temporary_image=""

if [[ -f "${initramfs_image}" ]]; then
    readonly backup_image="${initramfs_image}.backup-$(date +%Y%m%d-%H%M%S)-$$"
    cp -p -- "${initramfs_image}" "${backup_image}"
    echo "[OK] previous image backed up: $(basename -- "${backup_image}")"
fi

mv -- "${staging_image}" "${initramfs_image}"
verify_image "${initramfs_image}"

echo "Updated initramfs: ${initramfs_image}"
echo "Run 'scripts/wsl/phase1/update-initramfs.sh --check' to verify it again."
