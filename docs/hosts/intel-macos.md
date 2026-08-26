# Intel macOS PCIe Lab

This guide uses the shortest verified workflow for practicing the QEMU EDU PCI
driver on an Intel Mac:

```text
Docker builds edu_pci.ko
        -> QEMU runs Ubuntu and the EDU device
        -> SCP copies the module into Ubuntu
        -> SSH provides a shell for the PCIe exercise
```

The SSH key is only a login credential for the local QEMU guest. It is not a
GitHub key, a module-signing key, or part of PCIe.

Run host commands from the repository root. Commands marked **guest** run in
the Ubuntu shell opened through SSH.

## 1. Learning target

The emulated device is QEMU EDU, identified by PCI vendor/device ID
`1234:11e8`. Its BAR0 contains registers used by this exercise.

The driver controls the device in this order:

1. Match the PCI ID and enter `probe()`.
2. Enable the PCI device.
3. Reserve and map BAR0.
4. Read the identification register.
5. Write and read the liveness register.
6. Request factorial, poll for completion, and read the result.
7. Unmap and release resources in `remove()`.

The exercise succeeds when the log shows:

```text
identification: 0x010000ed
liveness: wrote=0x12345678 read=0xedcba987
factorial: 5! = 120
```

After `rmmod`, the driver binding, module entry, and BAR0 ownership must also be
gone.

## 2. Check the host once

This workflow requires an Intel x86-64 Mac, Docker Desktop, and QEMU with HVF.

```sh
uname -m
docker info --format 'os={{.OSType}} arch={{.Architecture}}'
qemu-system-x86_64 --version
qemu-system-x86_64 -accel help
```

Expected results:

- `uname -m` is `x86_64`.
- Docker reports Linux and `x86_64`.
- QEMU lists `hvf` as an accelerator.

If Docker cannot connect to its daemon, start Docker Desktop first.

## 3. Prepare and start the guest

Load the Mac lab configuration:

```sh
. scripts/macos/phase0/config.sh
```

The first run needs an Ubuntu image, writable disk, cloud-init data, and a
guest login key. The preparation script creates these host-local artifacts
under `/private/tmp/pcie-phase0` and verifies the downloaded image:

```sh
scripts/macos/phase0/prepare-vm.sh
```

This is environment preparation, not part of the PCIe driver exercise. The
artifacts are reused on later runs and must not be committed.

Start QEMU and wait for Ubuntu:

```sh
scripts/macos/phase0/start-vm.sh
scripts/macos/phase0/wait-for-guest.sh
```

The wait command checks three things:

- cloud-init finished;
- the guest kernel is `6.8.0-137-generic`;
- EDU `1234:11e8` is visible to Linux.

If EDU is missing, confirm QEMU is running before investigating the driver:

```sh
cat "$PCIE_QEMU_PID"
tail -n 30 "$PCIE_SERIAL_LOG"
```

## 4. Build the module on the Mac

The module must be built against the same kernel release as the Ubuntu guest.
Docker supplies the matching Linux build environment; it does not run the
driver.

Build the reusable builder image:

```sh
docker build \
    --platform linux/amd64 \
    --build-arg "KERNEL_RELEASE=$PCIE_KERNEL_RELEASE" \
    --build-arg "KERNEL_HEADERS_VERSION=$PCIE_KERNEL_HEADERS_VERSION" \
    -t "$PCIE_BUILDER_IMAGE" \
    tools/phase0-module-builder
```

Compile the canonical driver source:

```sh
mkdir -p "$PCIE_MODULE_OUTPUT"

docker run --rm \
    --platform linux/amd64 \
    --mount "type=bind,src=$PCIE_PROJECT_DIR/driver/edu,dst=/src,readonly" \
    --mount "type=bind,src=$PCIE_MODULE_OUTPUT,dst=/out" \
    "$PCIE_BUILDER_IMAGE" \
    bash -lc "
        set -eu
        cp -a /src/. /build/
        make -C /lib/modules/$PCIE_KERNEL_RELEASE/build M=/build modules
        cp /build/edu_pci.ko /out/
        modinfo -F vermagic /build/edu_pci.ko
        modinfo -F alias /build/edu_pci.ko
    "
```

Check the output:

```sh
file "$PCIE_MODULE_OUTPUT/edu_pci.ko"
```

Expected results:

- `file` reports an x86-64 relocatable ELF file.
- Vermagic starts with `6.8.0-137-generic`.
- The PCI alias contains vendor `1234` and device `11E8`.

A vermagic mismatch means the module was built for a different kernel and must
not be loaded. A skipped-BTF message is expected in this build environment.

## 5. Copy the module and enter Ubuntu

Copy only the built module into the guest:

```sh
scp \
    -i "$PCIE_SSH_KEY" \
    -P "$PCIE_SSH_PORT" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$PCIE_MODULE_OUTPUT/edu_pci.ko" \
    "$PCIE_GUEST_USER@127.0.0.1:/tmp/edu_pci.ko"
```

Open the guest shell:

```sh
ssh \
    -i "$PCIE_SSH_KEY" \
    -p "$PCIE_SSH_PORT" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$PCIE_GUEST_USER@127.0.0.1"
```

SCP transfers the `.ko` file; SSH is where the remaining commands are entered
directly. QEMU runs in the background, so its serial port is written to a log
instead of being used as an interactive terminal.

## 6. Observe the PCI device before loading the driver

Run the rest of this section in the **guest**:

```sh
lspci -Dnn -d 1234:11e8

export EDU_BDF=$(lspci -Dnn -d 1234:11e8 | awk 'NR == 1 { print $1 }')
echo "$EDU_BDF"
sudo lspci -vv -s "$EDU_BDF"

cat "/sys/bus/pci/devices/$EDU_BDF/vendor"
cat "/sys/bus/pci/devices/$EDU_BDF/device"
cat "/sys/bus/pci/devices/$EDU_BDF/resource"
test ! -e "/sys/bus/pci/devices/$EDU_BDF/driver" &&
    echo "OK: EDU is unbound"
```

Expected results:

- The ID is `1234:11e8`.
- BAR0 is a 1 MiB memory resource.
- EDU has no bound driver before `insmod`.

The BDF, such as `0000:00:03.0`, can change. Find it from the PCI ID rather
than hard-coding it.

## 7. Load and inspect the driver

Still in the **guest**, verify the kernel match:

```sh
uname -r
modinfo -F vermagic /tmp/edu_pci.ko
```

The start of vermagic must equal `uname -r`.

Load the module and read its results:

```sh
sudo insmod /tmp/edu_pci.ko

sudo dmesg |
    grep -E 'edu_pci.*(probe:|identification:|liveness:|factorial:)' |
    tail -n 4
```

The four log lines prove PCI matching, BAR0 MMIO access, and factorial command
completion. Check the live state separately:

```sh
readlink "/sys/bus/pci/devices/$EDU_BDF/driver"
grep '^edu_pci ' /proc/modules
sudo grep -F 'edu_pci' /proc/iomem
```

Expected results:

- The driver link ends in `/bus/pci/drivers/edu_pci`.
- `/proc/modules` contains a live `edu_pci` entry.
- `/proc/iomem` shows BAR0 owned by `edu_pci`.

If `insmod` fails, inspect the latest messages:

```sh
sudo dmesg | grep -E 'edu_pci|probe with driver' | tail -n 20
```

Common meanings:

- `invalid module format`: guest kernel and module vermagic differ.
- BAR request failure: another owner holds the resource.
- liveness mismatch: the MMIO write/read path did not behave as expected.
- factorial timeout: the device did not finish before the driver's deadline.

## 8. Unload and verify cleanup

Run in the **guest**:

```sh
sudo rmmod edu_pci

sudo dmesg | grep -E 'edu_pci.*remove:' | tail -n 1

test ! -e "/sys/bus/pci/devices/$EDU_BDF/driver" &&
    echo "OK: driver unbound"

grep '^edu_pci ' /proc/modules ||
    echo "OK: module removed"

sudo grep -F 'edu_pci' /proc/iomem ||
    echo "OK: BAR0 region released"
```

All three `OK` messages are required. They show that the driver reversed its
setup and left no binding or BAR0 ownership behind.

## 9. Repeat after changing the driver

For each driver change:

1. Run `rmmod` and confirm cleanup in the guest.
2. Edit `driver/edu/edu_pci.c` on the Mac.
3. Repeat the Docker compile command.
4. Repeat SCP, `insmod`, log inspection, and cleanup.

Before adding a new EDU feature, identify its register or function, the order
of driver operations, and the result that will prove success. The next learning
step is interrupt handling after the current polling flow is familiar.

## 10. Stop QEMU

Exit the guest shell and stop the VM from the Mac:

```sh
exit
scripts/macos/phase0/stop-vm.sh
```

The stop script requests a normal guest shutdown and checks the writable disk.
The expected final message from `qemu-img check` is:

```text
No errors were found on the image.
```
