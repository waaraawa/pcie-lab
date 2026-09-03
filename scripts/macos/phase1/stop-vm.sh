#!/bin/sh
# Phase 1 entry point for stopping and checking the shared QEMU guest.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

. "${script_dir}/config.sh"

exec "${script_dir}/../phase0/stop-vm.sh"
