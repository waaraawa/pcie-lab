# Intel macOS Host - Phase 0 Environment and Smoke Test

This document records the Intel Mac implementation and evidence for the common host-validation contract. Host-independent curriculum requirements live in [`../common/phase-0-host-contract.md`](../common/phase-0-host-contract.md).

## Objective

Inventory the Intel Mac host, choose a reproducible Linux/QEMU/kernel-debugging architecture, and prove the minimum boot path before writing a PCI driver.

This phase exists to separate environment failures from driver failures. It ends when a Linux guest can be started repeatedly, the QEMU `edu` device is visible, logs can be retained, and the planned kernel/module development workflow is documented.

## Constraints and assumptions

- The primary workstation is an Intel Mac.
- QEMU with macOS hardware acceleration is the initial virtualization candidate, but it must be verified locally.
- Linux is the guest and driver-development target.
- Git repository setup is intentionally deferred until the user connects the repository.
- No package, VM, kernel, or large disk image should be installed before the inventory and architecture decision are recorded.

## Host inventory

Collect only information needed to design the lab. Do not record serial numbers, hardware UUIDs, account names, tokens, or unrelated private data.

### Hardware and operating system

- [x] macOS version and build
- [x] CPU model and architecture
- [x] Logical and physical CPU count
- [x] Installed memory
- [x] Free disk space available to this project
- [x] Whether the machine can use HVF successfully with x86_64 QEMU

### Existing tools

- [x] Homebrew version and prefix, if installed
- [x] QEMU version and available x86_64 system binary
- [x] Docker client availability and version
- [x] Runnable Docker daemon or another Linux build environment
- [x] C compiler, linker, make, and related host build tools
- [x] GDB availability and version
- [x] LLDB availability and version
- [x] Existing project-local Linux images or VMs that may be reusable

### Verified environment

Verified on 2026-08-05.

| Item | Verified value | Notes |
| --- | --- | --- |
| macOS | 26.5.2, build 25F84 | Host operating system |
| Host architecture | x86_64 | Confirmed by the installed Clang target |
| CPU | Intel Core i7-9750H at 2.60 GHz | 6 physical cores, 12 logical CPUs |
| Memory | 16 GiB | `17179869184` bytes |
| Project volume | 466 GiB total, 76 GiB available | 83% used; disk consumption must be controlled |
| Homebrew | 6.0.15 | Intel prefix: `/usr/local` |
| QEMU | 11.0.3 | `qemu-system-x86_64` executes successfully |
| QEMU accelerators | `tcg`, `hvf` | Two actual Ubuntu x86_64 guest boots completed with `q35,accel=hvf` |
| QEMU devices | `edu`, `nvme`, `nvme-ns`, `nvme-subsys` | `q35` machine is also available |
| Docker | Client 29.6.2, build dfc4efb; Docker Desktop running | A local `linux/amd64` Alpine 3.23 container ran successfully and read the project through a read-only bind mount |
| C compiler | Apple Clang 21.0.0 | Target is `x86_64-apple-darwin25.5.0` |
| Linker | Apple `ld` project 1267 | x86_64 support is listed |
| Make | GNU Make 3.81 | Host tool only; the Linux build environment will provide its own toolchain |
| Additional build tools | CMake 4.4.2, Ninja 1.13.2, pkg-config 3.0.5 | Available on the host |
| Parser/build utilities | Bison 2.3, Flex 2.6.4, bc 7.0.3, Perl 5.34.1 | Available on the host |
| Python | 3.14.6 | Available at `/usr/local/bin/python3` |
| GDB | 17.2 | QEMU remote connection is not yet tested |
| LLDB | 2100.0.17.108 | Available as a secondary debugger option |
| Project-local Linux artifacts | None found | No qcow2, img, ISO, kernel, or `vmlinux` file exists under the project |

### Remaining execution checks

- [x] Prove HVF with an actual x86_64 Linux guest boot. The same guest overlay booted and shut down cleanly twice.
- [x] Start or select a Linux build environment and prove it can execute. Docker Desktop ran a local `linux/amd64` container successfully without downloading a new image.

### Safe read-only command examples

Use equivalent commands when a listed tool is unavailable. Review output before committing it to the repository.

```sh
sw_vers
uname -srm
uname -m
sysctl -n machdep.cpu.brand_string
sysctl -n hw.physicalcpu
sysctl -n hw.logicalcpu
sysctl -n hw.memsize
df -h .
command -v brew
command -v qemu-system-x86_64
command -v docker
command -v gcc
command -v clang
command -v make
command -v gdb
command -v lldb
```

Do not use broad hardware-report commands without filtering out device serial numbers and identifiers.

## Architecture decisions

Record the selected value and rationale for each item before installing or generating large artifacts.

- [x] macOS host responsibilities: run QEMU/HVF, retain source and artifacts, capture logs, and host the debugger
- [x] Linux build environment: Docker Desktop with explicit `linux/amd64` containers and project-mounted outputs
- [x] Linux guest distribution and version: Ubuntu 24.04.4 LTS amd64 cloud image, downloaded from the official Noble image service on 2026-08-05
- [ ] Linux kernel version and configuration source: the stock `6.8.0-136-generic` kernel is validated for smoke tests; the source-based learning kernel is not yet selected
- [x] Root filesystem format: checksum-verified qcow2 base image plus a disposable writable qcow2 overlay
- [x] Kernel and module build method for the stock smoke-test kernel: digest-pinned Ubuntu 24.04 amd64 Docker image with exact `6.8.0-136.136` kernel headers; source is mounted read-only and outputs stay under the temporary lab directory
- [x] Method for moving modules and test artifacts into the guest: SSH/SCP through QEMU user networking and a localhost port forward
- [x] QEMU machine type and acceleration mode: `q35,accel=hvf`, host CPU, 2 vCPUs, and 2 GiB RAM for the smoke test
- [x] Serial console and kernel-log capture method: guest kernel uses `console=ttyS0`; QEMU writes serial output to a host file
- [ ] Kernel debugging method and symbol location
- [x] VM reset, snapshot, and recovery procedure: request `systemctl poweroff`; preserve the verified base image and recreate the disposable overlay after corruption or unwanted state
- [x] Location and size policy for generated images and build outputs: scripts and source live in the project; downloaded images, SSH keys, serial logs, module binaries, and other generated artifacts live under `/private/tmp/pcie-phase0` and must not enter version control

Prefer the smallest setup that satisfies Phase 1. Avoid selecting tools merely because they may be useful in later phases.

## Smoke test

The first smoke test uses a stock or prebuilt Linux guest when practical. Building a custom kernel is a separate validation step after basic QEMU boot succeeds.

### Minimum boot path

- [x] Start `qemu-system-x86_64` with the selected acceleration mode.
- [x] Reach a usable Linux serial console.
- [x] Run basic guest commands and retain the console log on the host.
- [x] Attach QEMU `edu` and find PCI ID `1234:11e8` with `lspci -nn`.
- [x] Inspect the device's BAR and interrupt information without a custom driver.
- [x] Shut down or terminate the guest using a documented recovery procedure.
- [x] Repeat the start, discovery, and shutdown sequence successfully.

### Validated smoke-test evidence

Validated on 2026-08-05. These are smoke-test artifacts, not the final reproducible lab scripts.

- Official image: `noble-server-cloudimg-amd64.img` from `https://cloud-images.ubuntu.com/noble/current/`
- Verified SHA-256: `0533b0655c32e68b31d792ecd6ccfca95abdbc536c4446874fe0513bd4140ffe`
- Image format: qcow2, 3.5 GiB virtual size, about 608 MiB allocated on the host
- Guest result: Ubuntu 24.04.4 LTS, x86_64, stock kernel `6.8.0-136-generic`
- QEMU result: `q35`, HVF, 2 vCPUs, 2 GiB RAM, virtio disk/network, and QEMU `edu`
- PCI discovery: `00:03.0`, vendor/device `1234:11e8`, revision `10`
- Resource discovery: BAR 0 at `0xfea00000`, 32-bit non-prefetchable, size 1 MiB
- Interrupt discovery: INTx pin A routed to IRQ 11; one 64-bit-capable MSI vector advertised and initially disabled
- Driver state: intentionally unbound
- Provisioning result: cloud-init `status: done`; SSH key login through localhost forwarding succeeded
- Repeatability result: two clean boot/discovery/poweroff sequences completed; the second boot reached its target in 12.639 seconds
- Disk validation: `qemu-img check` reported no errors after the second clean shutdown

The temporary base, overlay, seed ISO, private key, and serial logs are under `/private/tmp/pcie-phase0`. The private key is ephemeral and must never be copied into the project or committed. Because `/private/tmp` is not durable project storage, the final artifact and log location remains an open decision.

### Development-path validation

- [x] Build a minimal external kernel module against the selected kernel headers or build tree.
- [x] Transfer the module into the guest.
- [x] Load and unload the module while capturing kernel logs.
- [ ] Obtain or build a symbol-bearing `vmlinux` for later debugging.
- [ ] Connect the selected debugger to QEMU and stop at a known kernel symbol, if remote kernel debugging is included in the chosen architecture.

### Validated external-module path

Validated on 2026-08-05 using only the project scripts:

1. `scripts/macos/phase0/prepare-vm.sh`
2. `scripts/macos/phase0/build-module.sh`
3. `scripts/macos/phase0/start-vm.sh`
4. `scripts/macos/phase0/wait-for-guest.sh`
5. `scripts/macos/phase0/test-module.sh`
6. `scripts/macos/phase0/stop-vm.sh`

The builder uses `ubuntu:24.04` for amd64 at digest `sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea` and installs `linux-headers-6.8.0-136-generic` version `6.8.0-136.136`. The source-only module is `labs/phase0/module-smoke/phase0_sanity.c`; it does not access the PCI device and exists only to prove the environment.

Verified evidence:

- Output format: 64-bit x86-64 relocatable ELF kernel module with debug information
- Output SHA-256 for this build: `49e377cbe986d0f82b9ab3ff413d08663502cd6c1e1c3285742c98b58c520212`
- Guest kernel: `6.8.0-136-generic`
- Module vermagic: `6.8.0-136-generic SMP preempt mod_unload modversions`
- Load evidence: `phase0_sanity: loaded`
- Unload evidence: `phase0_sanity: unloaded`
- Post-test image check: no errors

The build emitted two understood warnings. GCC's executable name differs from the compiler name recorded by Ubuntu, but both report GCC 13.3.0 with the same Ubuntu build version. BTF generation was skipped because a symbol-bearing `vmlinux` is not yet present; resolving that is the remaining debugger-path work.

Remote GDB is desirable but should not block the earliest `edu` discovery smoke test. Document any debugger limitation explicitly.

## Deliverables

- Sanitized host and tool inventory
- Environment architecture decision record
- Pinned guest, kernel, QEMU, and tool versions
- Reproducible QEMU launch command or script design
- Captured successful boot and `lspci -nn` evidence
- Documented module build/transfer/load path
- Debugger validation result or an explicit blocker
- Disk usage, recovery, and cleanup notes

## Completion criteria

- Another contributor can understand the chosen lab architecture without prior conversation.
- Linux boots repeatedly under QEMU with the selected acceleration mode.
- QEMU `edu` appears as `1234:11e8` in the guest.
- Console and kernel logs are retained outside the guest.
- A minimal module can be built, transferred, loaded, and unloaded.
- Kernel symbols are available for Phase 1 debugging.
- Failures, workarounds, and remaining debugger limitations are documented.
- The learner has personally repeated the essential module and debugger checks and can explain why the running kernel, build headers, module vermagic, and `vmlinux` must match.
- Phase 1 can begin without an unresolved environment-design decision.

## Learner checkpoint

Initial provisioning, downloads, long builds, and troubleshooting may be delegated to an agent, but the concepts below are part of the curriculum and must not be skipped. Phase 0 is not complete until the learner personally performs and explains them.

- Compare `uname -r` in the guest with the selected header tree and the module's `modinfo -F vermagic` result.
- Build the sanity module, transfer it, load it, verify `/sys/module` and `dmesg`, unload it, and verify teardown.
- Cause or inspect one intentional version-mismatch failure and explain why the kernel rejects that module.
- Identify `start_kernel` or another known symbol in the exact matching `vmlinux`.
- Connect GDB to QEMU, stop at the known symbol, and explain why KASLR is disabled for this lab.
- Explain which work happens in Docker and which work happens in QEMU, and why separating build and execution helps debugging.

The learner does not need to repeat package-manager output or the initial large downloads merely for ceremony. The required work is the technical verification path and the reasoning behind it.

## Out of scope

- Implementing the `edu` PCI driver
- BAR/MMIO programming from a custom driver
- Interrupt or DMA implementation
- QEMU NVMe analysis
- Physical PCIe hardware
- Windows, ROS 2, or security extensions

## Current status

- Document scaffold: complete
- Core host inventory: complete
- Host and installed-tool inventory: complete
- Linux build environment execution: validated
- Architecture selection: in progress; the stock-kernel module path is selected, while the symbol-bearing learning kernel and debugger path remain open
- QEMU/Linux smoke test: minimum boot path validated twice
- Module validation: complete
- Symbol and debugger validation: not started
