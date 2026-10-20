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
| One-shot INTx raise/status/ack | Pending | User-verified: one IRQ on Linux IRQ 23, cause `0x1` acknowledged to zero, clean unload | Pending cross-host parity |
| Factorial completion via INTx | Pending | User-verified: handler precedes `5! = 120`, one IRQ, clean unload | Pending cross-host parity |
| Factorial completion timeout cleanup | Pending | User-verified: forced timeout `-110`, no binding/IRQ/BAR owner, status and pending cause zero | Pending cross-host parity |
| MSI | Pending | User-verified: one factorial MSI on Linux IRQ 28, cause `0x1` acknowledged to zero, bus-master and INTx-disable lifecycle observed, normal and forced-timeout cleanup passed | Pending cross-host parity |
| 28-bit DMA mask | User-verified | User-verified | Verified per host |
| Coherent DMA buffer lifecycle | User-verified: 64-byte allocation within 28-bit range, normal and forced-timeout cleanup passed | User-verified: 64-byte allocation within 28-bit range, normal and forced-timeout cleanup passed | Verified per host |
| Polling RAM-to-EDU command completion | User-verified: 64-byte command completed in about 108 ms; data not yet read back | Pending | Pending cross-host parity |
| Bidirectional DMA | User-verified: IRQ-driven 64-byte RAM-to-EDU-to-RAM round trip recovered the full pattern | User-verified (2026-10-14): INTx and MSI 64-byte round trips passed byte comparison; normal cleanup observed in both modes | Manual result recorded on both hosts; same-revision/shared-test gate pending |
| DMA completion via INTx | User-verified: cause `0x100` acknowledged to zero for both directions; normal remove with latest idle-wait loops reported command `0x06` and final binding/BAR/IRQ/module absence | User-verified (2026-10-14): two cause `0x100` IRQs on IRQ 23 acknowledged to zero; remove idle command `0x06`, binding/BAR/IRQ absent; subsequent fresh module load observed | Manual normal completion/cleanup recorded on both hosts; formal shared-test gate pending |
| DMA completion via MSI | Pending | User-verified (2026-10-14): IRQ 28, two DMA causes `0x100` and factorial cause `0x1`, all acknowledged to zero; 64-byte round trip passed, CPU counts 3+0; normal remove idle `0x06`, Command `0x0507`→`0x0103`, and final binding/BAR/IRQ/module absence observed | Mac MSI DMA and formal shared-test gate pending |
| DMA in-flight timeout idle wait | User-verified: command `0x05` at timeout, late INTx cause `0x100` acknowledged, command `0x04` before probe error `-110`; final binding, BAR owner, IRQ action, and module absent | User-verified (2026-10-14): timeout and idle wait at command `0x05`, late cause `0x100` acknowledged to zero, idle `0x04`, probe `-110`, reported insmod exit 0; binding absent before rmmod; rmmod exit 0 and final BAR/IRQ/module absence observed | Manual idle-wait/final cleanup result recorded on both hosts; formal shared-test gate pending |
| DMA lost-IRQ timeout cleanup | User-verified: command and pending cause zero; probe returned `-110`; binding, BAR0 owner, IRQ action, and final module entry absent | User-verified (2026-10-14): command/pending zero, idle log, probe `-110`, reported insmod exit 0; binding/BAR/IRQ absent; unbound module removed with rmmod exit 0 and final module absence | Manual cleanup result recorded on both hosts; formal shared-test gate pending |
| MSI DMA lost-IRQ timeout cleanup | Pending | User-verified (2026-10-14): MSI timeout command/pending zero, idle log, probe `-110`, reported insmod exit 0, post-probe Command `0x0103` clears BME/INTx-disable; binding/BAR/IRQ absent before rmmod, unbound module present, rmmod exit 0 and final module absence observed | Pending Mac parity and formal gate |
| MSI DMA in-flight timeout idle wait | Pending | User-verified (2026-10-14): timeout/idle wait `0x05`, idle `0x04`, probe `-110`, reported insmod exit 0, post-probe Command `0x0103`; no late ISR log; binding/BAR/IRQ absent before rmmod, unbound module present, rmmod exit 0 and final module absence observed | Pending Mac parity and formal gate |
| User-space validation | Pending | User-verified (2026-10-18, 2026-10-20): read-only `sysfs` `identification` returned `0x010000ed`; `/dev/edu0` `miscdevice` (`10, 258`) and `tests/guest/edu_ioctl_test.c` (`factorial(6) = 720`, DMA round trip, `EINVAL`/`EFAULT`, exit `0`) passed, with both nodes removed after `rmmod` | Pending Mac parity and shared-test runner |
| Host-local artifact integrity | QEMU overlay clean after the 2026-08-26 learner run | Static module/initramfs checks passed on 2026-10-18 | Host-local only |

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

The canonical EDU driver has manual normal DMA and timeout/cleanup evidence on
both hosts in INTx mode. On 2026-10-14 WSL user-provided output additionally
confirmed all three paths in MSI mode: normal 64-byte round trip, lost-IRQ
timeout, and in-flight timeout with idle-before-release/final cleanup.

The MSI in-flight run had no late ISR log. Do not require late MSI delivery as
its acceptance criterion: the driver clears bus mastering before polling idle,
and upstream QEMU 8.2.2 gates MSI writes through that address space. This is a
source-based explanation, not a transaction-trace result. Mac MSI DMA and the
same-revision/shared-guest-test formal gate remain pending.
