# Phase 0 - Common Host Validation Contract

## Objective

Define the minimum evidence required before a host environment is considered
ready for the shared Linux PCI/PCIe curriculum.

The host operating system may differ. The Linux driver source, guest-side
tests, QEMU device model, and functional acceptance criteria remain common.

## Supported host tracks

- [Intel macOS](../hosts/intel-macos.md)
- [Windows with WSL](../hosts/windows-wsl.md)
- [Cross-host validation matrix](../validation-matrix.md)

Each host advances through the gates independently. Work on one validated host
does not wait for another host, but a milestone is cross-host verified only
after the same canonical source and guest-side test pass on both.

## Canonical artifacts

- Linux driver source: `driver/edu/`
- Guest-side functional tests: `tests/guest/`
- Expected results and comparison rules: `tests/expected/`
- Host-independent helper logic: `scripts/common/`
- Host launch and provisioning logic: `scripts/macos/` and `scripts/wsl/`

Kernel modules are build artifacts, not canonical artifacts. Build a `.ko` for
the exact guest kernel and verify its release, headers, configuration, and
`vermagic` rather than copying a module blindly between hosts.

## Per-host entry gate for Phase 1

- Record the host, QEMU, guest distribution, guest kernel, build toolchain,
  debugger, acceleration mode, paths, and resource constraints without private
  identifiers.
- Boot the Linux guest repeatedly and discover QEMU `edu` as `1234:11e8`.
- Build, transfer, load, and unload a minimal external module against the exact
  guest kernel.
- Preserve serial and kernel logs outside the guest.
- Provide a matching symbol-bearing `vmlinux` and validate a QEMU remote-GDB
  breakpoint, or document a technically justified limitation.
- Document shutdown, recovery, artifact cleanup, and secret-handling
  procedures.
- Have the learner personally repeat and explain kernel/header/`vermagic`
  matching, module lifecycle, a controlled mismatch, matching symbols, KASLR,
  and the debugger path.

## Cross-host completion rule

A functional milestone such as `probe()`/`remove()`, BAR/MMIO, interrupts, or
DMA is cross-host complete only when:

1. Both hosts use the same source revision under `driver/edu/`.
2. Environment-specific build outputs are produced for the corresponding guest
   kernels.
3. The same guest-side test and acceptance criteria are used.
4. Host-specific commands and limitations are recorded separately.
5. Results are entered in `docs/validation-matrix.md` with evidence locations.

## Non-goals

- Producing byte-identical `.ko` files across different guest kernels
- Maintaining separate Mac and WSL implementations of the Linux driver
- Blocking progress on one host because the other host is temporarily
  unavailable
- Treating Windows/WSL host support as Windows kernel-driver porting
