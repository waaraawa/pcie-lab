# QEMU EDU PCI driver lab

전체 학습 목표, 현재 위치와 각 단계의 성공 조건은
[`phase-1-qemu-edu.md`](../../docs/common/phase-1-qemu-edu.md)를 먼저 참고한다.

Build the out-of-tree module from the project root:

```bash
make -C driver/edu
```

From the project root, copy the module into the initramfs, verify it, rebuild the
archive, and install the verified image:

```bash
scripts/wsl/phase1/update-initramfs.sh
```

The script preserves the previous `initramfs.cpio.gz` as a timestamped backup.
It checks the kernel release, byte-for-byte module copy, gzip integrity, and the
module stored inside the final archive.

Run only the checks again with:

```bash
scripts/wsl/phase1/update-initramfs.sh --check
```

## VS Code navigation

The workspace uses clangd with the real Kbuild flags stored in the project-root
`compile_commands.json`. Rebuild the database after changing the module build
configuration:

```bash
scripts/wsl/phase1/refresh-compile-commands.sh
```

Install the recommended VS Code clangd extension and the Ubuntu `clangd`
package. In a C file, use F12 for declaration/definition, Shift+F12 for
references, and hover for the function signature.

The project-root `.clangd` removes GCC-only Kbuild flags from clangd analysis;
it does not change the real GCC module build.

For C files, the workspace selects clangd as the default formatter and enables
format-on-save. The project-root `.clang-format` is copied from the Linux
6.12.101 kernel style: tabs displayed at width 8 with an 80-column limit.
Clangd's fallback style is disabled, so formatting depends on finding this
file.

## EDU BAR0 register map

BAR0 is a 1 MiB MMIO region. Accesses below offset `0x80` must be 32-bit;
registers from `0x80` onward accept 32-bit or 64-bit accesses.

| Offset | Access | Register | Meaning |
| ---: | :---: | --- | --- |
| `0x00` | RO | Identification | EDU version identifier (`0xRRrr00edu`) |
| `0x04` | RW | Liveness | Reads back the bitwise inverse of the written value |
| `0x08` | RW | Factorial | Input value is replaced by its factorial result |
| `0x20` | RW | Status | Bit `0x01`: computing (RO); bit `0x80`: interrupt after factorial |
| `0x24` | RO | Interrupt status | Bitwise OR of pending interrupt causes |
| `0x60` | WO | Interrupt raise | Raises the bits written here |
| `0x64` | WO | Interrupt acknowledge | Clears the pending bits written here |
| `0x80` | RW | DMA source | DMA source address |
| `0x88` | RW | DMA destination | DMA destination address |
| `0x90` | RW | DMA count | Transfer size in bytes |
| `0x98` | RW | DMA command | `0x01`: start, `0x02`: EDU-to-RAM, `0x04`: completion IRQ |

The EDU-local DMA buffer is 4096 bytes at BAR0 offset `0x40000`; it is memory,
not another control register. DMA completion with command bit `0x04` raises
interrupt cause `0x100`.

## Factorial interrupt check

The probe registers an INTx handler, enables status bit `0x80`, writes `5` to
the factorial register at BAR0 offset `0x08`, and sleeps on a kernel completion.
EDU replaces the input with `120`, raises interrupt cause `0x1`, and the handler
acknowledges that cause before waking the probe. Successful guest output keeps
the IRQ line before the factorial result:

```text
edu_pci 0000:00:03.0: irq: BDF=0000:00:03.0, irq=23, pending=0x00000001 remaining=0x00000000
edu_pci 0000:00:03.0: factorial: 5! = 120
```

After the check, unload the module and verify that the driver released its IRQ
action, BAR0 region, and module entry:

```sh
rmmod edu_pci
grep -F 'edu_pci_irq' /proc/interrupts || echo "OK: IRQ handler removed"
grep -F 'edu_pci' /proc/iomem || echo "OK: BAR0 region released"
grep '^edu_pci ' /proc/modules || echo "OK: module removed"
```

## Factorial timeout fault injection

The read-only `force_factorial_timeout` module parameter skips the factorial
start while leaving its completion IRQ enabled. This deterministically exercises
the one-second completion timeout and probe cleanup:

```sh
insmod /lib/modules/6.12.101/extra/edu_pci.ko \
    force_factorial_timeout=1
```

Expected output includes `forcing factorial timeout`, status `0x00000080`, and
probe error `-110`. PCI driver registration still succeeds, so `insmod` can
return zero and the module can remain loaded even though the EDU device is not
bound. The IRQ action and BAR0 owner must already be absent; remove the
unbound module with `rmmod edu_pci` after checking them.
