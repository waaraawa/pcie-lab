#!/bin/sh
# Phase 1 entry point for the shared Intel macOS lab configuration.

# Resolve this directory in a clean non-interactive shell. An interactive zsh
# chpwd hook may write to stdout and corrupt command-substitution results.
pcie_phase1_config_dir=$(
	/bin/sh -c 'CDPATH= cd -- "$(dirname -- "$1")" && pwd -P' \
		pcie-phase1-config "$0"
)

. "${pcie_phase1_config_dir}/../phase0/config.sh"

unset pcie_phase1_config_dir
