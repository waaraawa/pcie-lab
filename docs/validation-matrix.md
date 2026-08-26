# Cross-Host Validation Matrix

## Status labels

- **Verified**: execution results and evidence are documented for that host.
- **User-verified**: the user observed the result and it is recorded in the work
  history.
- **Static recheck**: only source, input files, or an archive were rechecked.
- **Pending**: the behavior has not yet been demonstrated.

Intel Mac procedures are documented in
[`hosts/intel-macos.md`](hosts/intel-macos.md); execution evidence is recorded
in the root `WORKLOG.md` and summarized here. Windows/WSL evidence is recorded
in [`hosts/windows-wsl.md`](hosts/windows-wsl.md).

## Environment and driver state

| Capability | Intel macOS host | Windows/WSL host | Cross-host state |
| --- | --- | --- | --- |
| Host inventory | Verified (2026-08-05 and 2026-08-26) | Partial: WSL/QEMU verified; Windows inventory not recorded | Pending |
| QEMU Linux boot | Verified with Ubuntu/HVF | User-verified with custom Linux 6.12.101 | Verified per host |
| QEMU EDU discovery `1234:11e8` | Verified at `0000:00:03.0` | User-verified at `0000:00:03.0` | Verified per host |
| External module build/load/unload | Verified with canonical `edu_pci` on Linux 6.8.0-137; full guide learner-repeated | User-verified with canonical `edu_pci` on Linux 6.12.101 | Verified per host |
| Matching symbol-bearing `vmlinux` | Pending | Verified for Linux 6.12.101 | Pending |
| QEMU remote-GDB breakpoint | Pending | User-verified at `start_kernel` | Pending |
| Canonical `edu_pci` `probe()`/`remove()` | Verified | User-verified | Runtime parity verified; common test pending |
| BAR0 ownership/MMIO mapping | Verified | User-verified | Runtime parity verified; common test pending |
| Identification/liveness | Verified: `0x010000ed` and inversion | User-verified | Runtime parity verified; common test pending |
| Factorial polling | Verified: `5! = 120` | User-verified: `5! = 120` | Runtime parity verified; common test pending |
| INTx/MSI | Pending | Pending | Pending |
| Bidirectional DMA | Pending | Pending | Pending |
| User-space validation | Pending | Pending | Pending |
| Host-local artifact integrity | QEMU overlay clean after the 2026-08-26 learner run | Static module/initramfs recheck passed on 2026-08-25 | Host-local only |

## Cross-host completion rules

All of the following conditions are required before marking a capability as
cross-host complete:

1. Both hosts use the same `driver/edu/` source revision.
2. Each host builds the module for its own guest kernel.
3. Both hosts run the same test from `tests/guest/` against the same expected
   conditions in `tests/expected/`.
4. Host documentation records commands, results, log locations, and known
   limitations.
5. A smoke-test module result is not treated as EDU feature validation.

The canonical EDU driver now produces matching manual runtime behavior through
factorial polling on both hosts. Those rows remain short of the formal
cross-host completion gate until a shared guest test records the same checks on
both hosts.
