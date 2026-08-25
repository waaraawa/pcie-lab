#!/bin/sh
# Intel macOS host workflow.
set -eu

. "$(dirname -- "$0")/config.sh"

pcie_builder_dir=${PCIE_PROJECT_DIR}/tools/phase0-kernel-builder
pcie_actual_sha=$(shasum -a 256 "$PCIE_DEBUG_KERNEL_TARBALL" | awk '{print $1}')

if [ "$pcie_actual_sha" != "$PCIE_DEBUG_KERNEL_SHA256" ]; then
    printf 'Kernel source checksum mismatch.\nExpected: %s\nActual:   %s\n' \
        "$PCIE_DEBUG_KERNEL_SHA256" "$pcie_actual_sha" >&2
    exit 1
fi

mkdir -p "$PCIE_DEBUG_KERNEL_OUTPUT"

docker build --platform linux/amd64 \
    -t "$PCIE_KERNEL_BUILDER_IMAGE" \
    "$pcie_builder_dir"

docker volume create "$PCIE_DEBUG_KERNEL_VOLUME" >/dev/null

docker run --rm --platform linux/amd64 \
    --mount "type=volume,src=${PCIE_DEBUG_KERNEL_VOLUME},dst=/kernel" \
    --mount "type=bind,src=${PCIE_DEBUG_KERNEL_TARBALL},dst=/input/linux.tar.xz,readonly" \
    --mount "type=bind,src=${PCIE_DEBUG_KERNEL_OUTPUT},dst=/output" \
    "$PCIE_KERNEL_BUILDER_IMAGE" \
    bash -lc '
        set -eu
        kernel_dir=/kernel/linux-'"$PCIE_DEBUG_KERNEL_VERSION"'
        if [ ! -f "$kernel_dir/Makefile" ]; then
            tar -xf /input/linux.tar.xz -C /kernel
        fi
        cd "$kernel_dir"
        if [ ! -f .config ]; then
            make x86_64_defconfig
            scripts/config --set-str LOCALVERSION -pcie-lab
            scripts/config --enable DEBUG_KERNEL
            scripts/config --enable DEBUG_INFO
            scripts/config --disable DEBUG_INFO_NONE
            scripts/config --enable DEBUG_INFO_DWARF5
            scripts/config --disable DEBUG_INFO_REDUCED
            scripts/config --disable DEBUG_INFO_BTF
            scripts/config --enable GDB_SCRIPTS
            scripts/config --disable RANDOMIZE_BASE
            scripts/config --enable KALLSYMS_ALL
            scripts/config --enable MODULES
            scripts/config --enable MODULE_UNLOAD
            scripts/config --enable MODVERSIONS
            scripts/config --enable PCI
            scripts/config --enable PCI_MSI
            scripts/config --enable VIRTIO
            scripts/config --enable VIRTIO_PCI
            scripts/config --enable VIRTIO_BLK
            scripts/config --enable VIRTIO_NET
            scripts/config --enable EXT4_FS
            scripts/config --enable DEVTMPFS
            scripts/config --enable DEVTMPFS_MOUNT
            scripts/config --enable SERIAL_8250
            scripts/config --enable SERIAL_8250_CONSOLE
            scripts/config --enable EFI_PARTITION
        fi
        scripts/config --disable DRM
        scripts/config --disable SOUND
        scripts/config --disable HID
        scripts/config --disable USB_SUPPORT
        scripts/config --disable SCSI
        scripts/config --disable ATA
        scripts/config --disable NETWORK_FILESYSTEMS
        scripts/config --disable NFS_FS
        scripts/config --disable 9P_FS
        scripts/config --disable FAT_FS
        scripts/config --disable MSDOS_FS
        scripts/config --disable VFAT_FS
        scripts/config --disable ISO9660_FS
        scripts/config --disable PCMCIA
        scripts/config --disable BLK_DEV_DM
        scripts/config --disable MD
        scripts/config --disable WIRELESS
        scripts/config --disable WLAN
        scripts/config --disable CFG80211
        scripts/config --disable MAC80211
        scripts/config --disable ETHERNET
        scripts/config --disable I2C
        scripts/config --disable MEDIA_SUPPORT
        scripts/config --disable AGP
        scripts/config --disable FB
        scripts/config --disable VGA_CONSOLE
        scripts/config --disable FRAMEBUFFER_CONSOLE
        scripts/config --disable CPU_FREQ
        scripts/config --disable CPU_IDLE
        scripts/config --disable THERMAL
        scripts/config --disable POWER_SUPPLY
        scripts/config --disable UNWINDER_ORC
        scripts/config --enable UNWINDER_FRAME_POINTER
        scripts/config --enable FRAME_POINTER
        make olddefconfig
        for required_symbol in \
            PCI VIRTIO VIRTIO_PCI VIRTIO_BLK VIRTIO_NET EXT4_FS \
            DEVTMPFS SERIAL_8250 SERIAL_8250_CONSOLE DEBUG_INFO_DWARF5 \
            GDB_SCRIPTS FRAME_POINTER; do
            grep -q "^CONFIG_${required_symbol}=y" .config || {
                printf "Required CONFIG_%s is not built in.\n" "$required_symbol" >&2
                exit 1
            }
        done
        grep -q "^# CONFIG_RANDOMIZE_BASE is not set" .config
        make -j6 bzImage scripts_gdb
        test -s arch/x86/boot/bzImage
        test -s vmlinux
        cp -f arch/x86/boot/bzImage /output/bzImage-'"$PCIE_DEBUG_KERNEL_VERSION"'-pcie-lab
        cp -f vmlinux /output/vmlinux-'"$PCIE_DEBUG_KERNEL_VERSION"'-pcie-lab
        cp -f .config /output/config-'"$PCIE_DEBUG_KERNEL_VERSION"'-pcie-lab
        printf "kernel release: "; make -s kernelrelease
        ls -lh arch/x86/boot/bzImage vmlinux
    '

shasum -a 256 \
    "$PCIE_DEBUG_BZIMAGE" \
    "$PCIE_DEBUG_VMLINUX"
