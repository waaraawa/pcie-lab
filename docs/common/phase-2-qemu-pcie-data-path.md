# Phase 2 - QEMU PCIe Data Path

This curriculum is host-independent. Host-specific launch and acceleration
details belong under `docs/hosts/`.

## Objective

Understand and trace a modern queue-based PCIe I/O path using QEMU NVMe and the
Linux NVMe driver, then decide whether a small accelerator-like QEMU device is
needed for implementation practice.

The goal is not to rewrite the NVMe driver. It is to understand the reusable
architecture behind high-throughput PCIe devices.

## Prerequisites

- Phase 1 completion criteria met
- Comfort with Linux PCI resource lifetime, interrupts, DMA mappings, and
  teardown
- A kernel and QEMU build with symbols suitable for tracing both sides of the
  interface

## Topics

1. Admin, submission, and completion queues
2. Descriptor ownership and producer/consumer indices
3. Doorbell registers and MMIO ordering
4. MSI-X vectors, queue affinity, and completion handling
5. Scatter-gather I/O and large transfer construction
6. Memory barriers, cache visibility, and concurrency
7. Timeout detection, abort, controller reset, and recovery
8. User-space request to kernel queue to QEMU device and back
9. Tracing, performance counters, and latency decomposition
10. Similarities and differences between NVMe and an AI/NPU host stack

## Planned labs

- Launch a documented QEMU NVMe controller and inspect its PCIe capabilities.
- Trace controller initialization and queue creation in the Linux driver.
- Trace one I/O from user space through submission, doorbell, QEMU processing,
  interrupt, and completion.
- Map queue memory and interrupt vectors to relevant source paths and trace
  events.
- Observe and document timeout/reset behavior in a controlled experiment.
- Measure baseline latency and throughput only after functional tracing is
  stable.
- Produce an accelerator-oriented design note for command/completion queues,
  DMA buffers, reset, and errors.
- Decide at the phase midpoint whether to implement an optional custom QEMU
  queue device.

## Optional custom device

If NVMe analysis alone does not provide enough implementation evidence, define
a small QEMU device with:

- A command queue and completion queue
- Doorbell registers
- DMA-backed payload buffers
- MSI-X completion notification
- Status, error, timeout, and reset behavior

Keep the protocol deliberately smaller than NVMe and document it as an
educational accelerator-like endpoint, not a production NPU design.

## Deliverables

- Reproducible QEMU NVMe configuration
- End-to-end initialization and I/O trace notes
- Queue, interrupt, DMA, and reset diagrams
- Source navigation and debugging guide
- Accelerator-host-stack comparison document
- Optional custom-device specification, implementation, driver, and tests

## Completion criteria

- One request can be traced end to end on both the Linux and QEMU sides.
- Queue ownership, doorbells, MSI-X, DMA, memory ordering, and completion can be
  explained.
- Timeout and reset behavior is observed and documented.
- The differences between Phase 1's simple register/DMA model and a queue-based
  device are explicit.
- Hardware requirements for Phase 3 can be selected from written criteria
  rather than guesswork.

## Out of scope

- Reimplementing the full NVMe specification
- Production-grade NPU runtime APIs
- Windows porting
- Unbounded QEMU feature development
