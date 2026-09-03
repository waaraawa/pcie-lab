# Intel macOS Phase 1 entry points

Run commands from the repository root. The complete Phase 1 host-side VM and
module-build workflow is available from this directory:

```sh
. scripts/macos/phase1/config.sh
scripts/macos/phase1/prepare-vm.sh
scripts/macos/phase1/start-vm.sh
scripts/macos/phase1/wait-for-guest.sh
scripts/macos/phase1/build-module.sh
scripts/macos/phase1/copy-module.sh
scripts/macos/phase1/connect-guest.sh
```

`prepare-vm.sh` is required only when the shared host-local VM assets do not
exist. The prepare, start, wait, and stop entry points delegate to the existing
tested QEMU/HVF implementation. The build entry point compiles the canonical
`driver/edu/edu_pci.c` against the guest's matching Linux headers.

`copy-module.sh` transfers the built module to `/tmp/edu_pci.ko` in the guest.
`connect-guest.sh` then opens the interactive guest shell. `insmod`,
observations, and `rmmod` remain manual learning steps. After finishing the
guest work, exit SSH, then stop and check the guest with:

```sh
scripts/macos/phase1/stop-vm.sh
```

The shared implementation remains under `scripts/macos/phase0/`; Phase 1 users
do not need to invoke or remember those paths.
