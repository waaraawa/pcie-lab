# Intel macOS Host Scripts

Start with the manual
[Intel macOS PCIe lab guide](../../docs/hosts/intel-macos.md). It explains the
Docker build, QEMU launch, PCI observation, module load, MMIO results, and
cleanup checks without hiding the learning sequence.

The existing `phase0/` helpers wrap initial QEMU/HVF and Docker environment
work. Use them after understanding the manual commands or when repeating setup
that has already been learned. They use macOS-specific facilities such as HVF,
`hdiutil`, and the host-local `/private/tmp` artifact directory.

Use the Phase 1 entry points for the normal EDU VM and module-build workflow:

```sh
. scripts/macos/phase1/config.sh
scripts/macos/phase1/prepare-vm.sh
scripts/macos/phase1/start-vm.sh
scripts/macos/phase1/wait-for-guest.sh
scripts/macos/phase1/build-module.sh
scripts/macos/phase1/copy-module.sh
scripts/macos/phase1/connect-guest.sh
```

The Phase 1 configuration entry point reuses the canonical values from
`phase0/config.sh`; it does not duplicate kernel, VM, or SSH settings. The build
script also loads it automatically. Source it explicitly in the current shell
when later SCP commands need the exported paths and SSH settings.

The Phase 1 prepare, start, wait, and stop commands delegate to the existing
QEMU/HVF implementation without duplicating the VM definition. Phase 1 users
do not need to invoke scripts under `phase0/`. The build script builds
`driver/edu/edu_pci.c`, writes the host-local artifact to
`/private/tmp/pcie-phase0/module-out/edu_pci.ko`, and verifies its guest-kernel
vermagic and EDU PCI alias. `copy-module.sh` transfers that artifact to the
guest, and `connect-guest.sh` opens an interactive SSH shell. Module loading
and detailed observation remain manual lab steps.

See [`phase1/README.md`](phase1/README.md) for the concise command sequence.
