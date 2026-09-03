#!/bin/sh
# Phase 1 entry point for waiting until the shared Ubuntu guest is ready.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

. "${script_dir}/config.sh"

exec "${script_dir}/../phase0/wait-for-guest.sh"
