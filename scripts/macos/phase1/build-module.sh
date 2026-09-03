#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

. "${script_dir}/config.sh"

pcie_builder_dir=${PCIE_PROJECT_DIR}/tools/phase0-module-builder
pcie_module_source=${PCIE_PROJECT_DIR}/driver/edu
pcie_module=${PCIE_MODULE_OUTPUT}/edu_pci.ko

for pcie_command in docker file shasum; do
	if ! command -v "$pcie_command" >/dev/null 2>&1; then
		printf 'error: required command not found: %s\n' "$pcie_command" >&2
		exit 1
	fi
done

if [ ! -f "${pcie_module_source}/edu_pci.c" ]; then
	printf 'error: EDU driver source not found: %s\n' \
		"${pcie_module_source}/edu_pci.c" >&2
	exit 1
fi

mkdir -p "$PCIE_MODULE_OUTPUT"

docker build --platform linux/amd64 \
	--build-arg "KERNEL_RELEASE=${PCIE_KERNEL_RELEASE}" \
	--build-arg "KERNEL_HEADERS_VERSION=${PCIE_KERNEL_HEADERS_VERSION}" \
	-t "$PCIE_BUILDER_IMAGE" \
	"$pcie_builder_dir"

docker run --rm -i --platform linux/amd64 \
	--mount "type=bind,src=${pcie_module_source},dst=/src,readonly" \
	--mount "type=bind,src=${PCIE_MODULE_OUTPUT},dst=/out" \
	"$PCIE_BUILDER_IMAGE" \
	bash -s -- "$PCIE_KERNEL_RELEASE" <<'EOF'
set -eu

expected_release=$1

cp -a /src/. /build/
make -C "/lib/modules/${expected_release}/build" M=/build clean
make -C "/lib/modules/${expected_release}/build" M=/build modules

module_vermagic=$(modinfo -F vermagic /build/edu_pci.ko)
module_release=${module_vermagic%% *}
if [ "$module_release" != "$expected_release" ]; then
	printf 'error: module targets %s, expected %s\n' \
		"$module_release" "$expected_release" >&2
	exit 1
fi

module_alias=$(modinfo -F alias /build/edu_pci.ko)
if ! printf '%s\n' "$module_alias" |
	grep -Eq '^pci:v00001234d000011E8'; then
	printf 'error: EDU PCI alias not found: %s\n' "$module_alias" >&2
	exit 1
fi

cp /build/edu_pci.ko /out/

printf '[OK] vermagic: %s\n' "$module_vermagic"
printf '[OK] PCI alias: %s\n' "$module_alias"
EOF

file "$pcie_module"
shasum -a 256 "$pcie_module"
printf '[OK] built EDU module: %s\n' "$pcie_module"
