#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

pcie_vmlinux=$PCIE_DEBUG_VMLINUX
pcie_gdb_log=${PCIE_PHASE0_DIR}/gdb-validation.log

gdb --batch -q "$pcie_vmlinux" \
    -ex 'set pagination off' \
    -ex "target remote 127.0.0.1:${PCIE_GDB_PORT}" \
    -ex 'hbreak start_kernel' \
    -ex 'continue' \
    -ex 'printf "stopped at: "' \
    -ex 'info symbol $pc' \
    -ex 'bt 3' \
    -ex 'delete breakpoints' \
    -ex 'detach' \
    > "$pcie_gdb_log"

cat "$pcie_gdb_log"
