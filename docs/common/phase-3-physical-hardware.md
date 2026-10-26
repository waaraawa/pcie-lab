# Phase 3 - Physical Hardware

This curriculum defines common endpoint-selection and validation requirements.
Physical-host details will be documented separately when hardware is selected.

## Objective

Move the software concepts proven in QEMU to a physical PCIe endpoint and
validate behavior that emulation cannot represent faithfully: link and
enumeration issues, real interrupt delivery, DMA coherency, reset, recovery,
throughput, and isolation.

Hardware is intentionally not selected until the Phase 2 gate is met.

## Candidate lab shape

- An x86 Linux host with an accessible PCIe slot and a safe recovery path
- An FPGA or SoC platform capable of PCIe endpoint mode, or another sufficiently
  documented endpoint
- Serial/JTAG or equivalent endpoint-side debugging where available
- Versioned endpoint firmware/bitstream and host driver sources

Prefer a platform supported by the Linux PCI Endpoint Framework or a vendor
reference design that exposes BAR, legacy/MSI/MSI-X, and DMA tests.

## Hardware selection criteria

- Public and usable endpoint documentation
- Linux host and endpoint reference support
- BAR and DMA examples with source access
- MSI and preferably MSI-X support
- Endpoint reset and recovery path
- Debug access that remains available after PCIe failure
- Replaceable or recoverable firmware/bitstream
- Acceptable cost, availability, and host compatibility

## Topics

1. Physical enumeration, configuration space, capabilities, and BAR assignment
2. Link state, width, speed, and training failures
3. Legacy/MSI/MSI-X delivery on real hardware
4. DMA addressing, coherency, scatter-gather, and IOMMU translation
5. Endpoint firmware and host-driver protocol agreement
6. Function-level or device reset and recovery
7. AER and observable hardware errors where supported
8. Throughput, latency, jitter, CPU cost, and interrupt behavior
9. Invalid descriptor, timeout, stalled endpoint, and teardown scenarios
10. Security boundaries for device firmware, DMA, and user-space access

## Planned labs

- Bring up an unmodified reference endpoint and reproduce vendor or kernel
  tests.
- Use Linux `pci_epf_test`/`pci_endpoint_test` when the hardware supports the
  endpoint framework.
- Validate BAR, legacy/MSI/MSI-X, and read/write/copy operations.
- Port or adapt the Phase 1 host-driver patterns to the physical endpoint.
- Compare emulated and physical behavior, recording every material difference.
- Establish performance baselines and identify the dominant bottlenecks.
- Exercise reset and recovery without requiring an uncontrolled host reinstall.
- Enable and validate IOMMU isolation before attempting unsafe DMA scenarios.

## Deliverables

- Hardware bill of materials and connection diagram
- Host, endpoint firmware, and debug setup instructions
- Versioned reference and modified endpoint images
- Linux driver and user-space validation tools
- Functional, recovery, and performance test results
- Emulation-versus-hardware comparison
- Threat model and controlled DMA-isolation analysis

## Completion criteria

- A different contributor can reproduce the physical lab from the
  documentation.
- BAR, interrupt, and DMA behavior is validated on real hardware.
- Reset and at least one failure-recovery path are demonstrated.
- Performance results include methodology and limitations, not only headline
  numbers.
- IOMMU and DMA-security claims are supported by observable evidence.
- The remaining gap to an AI/NPU production host stack is explicitly
  documented.

## Selected physical lab hardware and pre-arrival preparation (2026-10-26)

- **Target x86 Linux host motherboard**: **ASUS PRIME B760M-A D4**
  - Storage: SATA SSD (supported built-in by `CONFIG_SATA_AHCI=y`)
  - Network: Onboard Realtek 2.5GbE (supported built-in by `CONFIG_R8169=y`)
  - Serial console / `kgdb`: Onboard COM1 header (`0x3f8` / IRQ 4, `ttyS0`, supported built-in by `CONFIG_SERIAL_8250=y`, `CONFIG_SERIAL_8250_PNP=y`, `CONFIG_SERIAL_8250_CONSOLE=y`; configure GRUB with `console=tty0 console=ttyS0,115200n8 kgdboc=ttyS0,115200`)
- **Primary PCIe x1 Endpoint (Steps 1–4)**: **WCH CH382L dual serial port card**
  - PCI IDs (`include/linux/pci_ids.h:2592`): Vendor `0x1c00` (`PCI_VENDOR_ID_WCHIC`), Device `0x3253` (`PCI_DEVICE_ID_WCHIC_CH382_2S`) or `0x3250` (`CH382_2S1P`)
  - In-tree Linux reference (`drivers/tty/serial/8250/8250_pci.c` `pbn_wch382_2`): `BAR0`, `num_ports = 2`, `first_offset = 0xC0` (Port 0 at `BAR0 + 0xC0`, Port 1 at `BAR0 + 0xC8`, `uart_offset = 8`, `base_baud = 115200`)
  - Scope: physical PCIe x1 link/enumeration, 4 KiB ECAM configuration space & capabilities, BAR0 mapping, register I/O, and hardware TX/RX loopback IRQ between Port 0 and Port 1 (a separate bus-master PCIe NIC or secondary NVMe endpoint can be used for Step 5 DMA/IOMMU)
- **Target debug kernel & `.deb` packages prepared on WSL**:
  - `scripts/wsl/phase3/configure-debug-kernel.sh`: enables `CONFIG_KGDB=y`, `CONFIG_KGDB_SERIAL_CONSOLE=y`, `CONFIG_KGDB_KDB=y`, `CONFIG_DMA_API_DEBUG=y`, `CONFIG_PCIEAER=y`, and `CONFIG_PCI_DEBUG=y`
  - `scripts/wsl/phase3/build-deb-kernel.sh`: builds `local/wsl/linux-image-6.12.101_6.12.101-6_amd64.deb` and `local/wsl/linux-headers-6.12.101_6.12.101-6_amd64.deb` via `make bindeb-pkg` while keeping the matching 374 MiB `local/wsl/linux-6.12.101/vmlinux` on the WSL host for remote `kgdb`

## Out of scope until hardware assembly

- Board-specific commands and wiring
- Vendor-specific FPGA or SoC tool flows
- A fixed budget or purchase list
- Destructive DMA or fault-injection experiments without isolation and recovery
  controls
