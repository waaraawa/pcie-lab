#!/bin/sh
# Phase 1 entry point for preparing the shared Intel macOS VM assets.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

. "${script_dir}/config.sh"

exec "${script_dir}/../phase0/prepare-vm.sh"
