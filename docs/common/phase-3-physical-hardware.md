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

## Out of scope until hardware selection

- Board-specific commands and wiring
- Vendor-specific FPGA or SoC tool flows
- A fixed budget or purchase list
- Destructive DMA or fault-injection experiments without isolation and recovery
  controls
