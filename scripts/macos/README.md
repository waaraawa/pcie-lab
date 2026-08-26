# Intel macOS Host Scripts

Start with the manual
[Intel macOS PCIe lab guide](../../docs/hosts/intel-macos.md). It explains the
Docker build, QEMU launch, PCI observation, module load, MMIO results, and
cleanup checks without hiding the learning sequence.

The existing `phase0/` helpers wrap initial QEMU/HVF and Docker environment
work. Use them after understanding the manual commands or when repeating setup
that has already been learned. They use macOS-specific facilities such as HVF,
`hdiutil`, and the host-local `/private/tmp` artifact directory.

There is intentionally no Phase 1 automation yet. Add it only after the manual
EDU driver workflow is familiar or when automation is explicitly requested.
