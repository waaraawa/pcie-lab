#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

pcie_builder_dir=${PCIE_PROJECT_DIR}/tools/phase0-module-builder
pcie_module_source=${PCIE_PROJECT_DIR}/labs/phase0/module-smoke

mkdir -p "$PCIE_MODULE_OUTPUT"

docker build --platform linux/amd64 \
    --build-arg "KERNEL_RELEASE=${PCIE_KERNEL_RELEASE}" \
    --build-arg "KERNEL_HEADERS_VERSION=${PCIE_KERNEL_HEADERS_VERSION}" \
    -t "$PCIE_BUILDER_IMAGE" \
    "$pcie_builder_dir"

docker run --rm --platform linux/amd64 \
    --mount "type=bind,src=${pcie_module_source},dst=/src,readonly" \
    --mount "type=bind,src=${PCIE_MODULE_OUTPUT},dst=/out" \
    "$PCIE_BUILDER_IMAGE" \
    bash -lc "cp -a /src/. /build/ && make -C /lib/modules/${PCIE_KERNEL_RELEASE}/build M=/build modules && cp /build/phase0_sanity.ko /out/"

file "$PCIE_MODULE_OUTPUT/phase0_sanity.ko"
shasum -a 256 "$PCIE_MODULE_OUTPUT/phase0_sanity.ko"
