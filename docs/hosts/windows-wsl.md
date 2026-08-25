# Windows/WSL 실습 환경 사용 설명서

이 문서는 Windows의 WSL2에서 repository를 clone한 뒤 Linux 6.12.101,
BusyBox initramfs, QEMU EDU와 `edu_pci` driver 실습 환경을 처음부터 만드는
절차다. 대화나 별도 작업 기록 없이 위에서 아래로 따라 할 수 있도록 작성했다.

실행 결과와 날짜별 evidence는
[Cross-host validation matrix](../validation-matrix.md)와 root `WORKLOG.md`에서
관리한다. 이 문서는 실행 방법과 정상 조건만 설명한다.

읽는 순서:

- 처음 환경을 만들 때: 2절부터 10절까지 순서대로 수행
- driver code만 수정한 뒤 다시 시험할 때: 11절 수행
- GDB가 필요할 때: 12절 수행
- 부팅이나 module load가 실패할 때: 14절 확인

## 1. 완성할 환경

이 문서를 끝까지 수행하면 다음 구조가 동작한다.

```text
Windows
└── WSL2 Ubuntu
    ├── pcie-lab repository
    ├── Linux 6.12.101 build tree
    ├── BusyBox initramfs
    ├── QEMU q35 + EDU device
    └── GDB + matching vmlinux

QEMU guest
└── edu_pci.ko
    ├── PCI binding
    ├── BAR0 mapping
    ├── identification
    ├── liveness
    └── factorial polling
```

현재 EDU 기능의 성공 조건은 다음과 같다.

- QEMU guest에서 `1234:11e8` 장치를 찾는다.
- `edu_pci.ko`가 Linux 6.12.101용으로 build된다.
- `insmod` 후 driver가 EDU에 bind된다.
- identification은 `0x010000ed`다.
- liveness는 `0x12345678`을 쓰면 `0xedcba987`을 반환한다.
- factorial polling은 `5! = 120`을 반환한다.
- `rmmod` 후 binding, module과 BAR0 owner가 모두 사라진다.

## 2. 준비 조건

### 2.1 Windows에서 WSL 확인

PowerShell에서 실행한다.

```powershell
wsl --version
wsl --status
wsl --list --verbose
```

정상 조건:

- WSL2가 설치되어 있다.
- Ubuntu distribution의 `VERSION`이 `2`다.
- WSL Ubuntu terminal을 열 수 있다.

이 문서의 검증 기준은 Windows 11, WSL2와 Ubuntu 24.04 x86-64다. 다른 Ubuntu
release에서도 가능하지만 package version과 QEMU version은 달라질 수 있다.

### 2.2 WSL package 설치

이 절부터는 WSL Ubuntu terminal에서 실행한다.

```bash
sudo apt update

sudo apt install -y \
    bc \
    binutils \
    bison \
    build-essential \
    busybox-static \
    cpio \
    curl \
    dwarves \
    flex \
    gdb \
    git \
    gzip \
    kmod \
    libelf-dev \
    libncurses-dev \
    libssl-dev \
    python3 \
    qemu-system-x86 \
    xz-utils
```

설치 확인:

```bash
command -v gcc
command -v make
command -v busybox
command -v cpio
command -v modinfo
command -v qemu-system-x86_64
command -v gdb

file "$(command -v busybox)"
qemu-system-x86_64 --version
```

정상 조건:

- 모든 `command -v`가 경로를 출력한다.
- BusyBox가 `statically linked`로 표시된다.
- `qemu-system-x86_64`가 version을 출력한다.

Kernel build tree는 약 5 GiB를 사용할 수 있다. repository와 backup까지 고려해
최소 10 GiB의 여유 공간을 권장한다.

```bash
df -h .
nproc
```

## 3. Repository 준비

새로 clone할 때:

```bash
mkdir -p $HOME/projects
cd $HOME/projects

git clone https://github.com/waaraawa/pcie-lab.git
cd pcie-lab

export PCIE_REPO_ROOT=$PWD
```

이미 clone한 repository라면:

```bash
cd /path/to/pcie-lab
git pull --ff-only
export PCIE_REPO_ROOT=$PWD
```

확인:

```bash
pwd
test -f driver/edu/edu_pci.c &&
    echo "OK: repository root"

git status --short --branch
```

이후 별도 설명이 없으면 모든 host 명령은 repository root에서 실행한다. 새
terminal을 열면 다음 두 명령으로 위치와 변수를 다시 설정한다.

```bash
cd /path/to/pcie-lab
export PCIE_REPO_ROOT=$PWD
```

## 4. Git 파일과 local 산출물의 경계

Git으로 공유하는 파일:

- `driver/edu/`: canonical Linux driver source
- `scripts/wsl/`: WSL helper script
- `docs/`와 `tests/`: 설명과 공통 test
- `.clang-format`, `.clangd`와 `.vscode/`: source navigation과 formatting 설정

이 컴퓨터에서만 생성하는 파일:

- `local/wsl/linux-6.12.101/`: kernel source와 build output
- `local/wsl/initramfs/`: unpacked initramfs
- `local/wsl/initramfs.cpio.gz`: QEMU에 전달할 archive
- `driver/edu/edu_pci.ko`와 module build output
- root `compile_commands.json`

이 local 산출물은 `.gitignore` 대상이다. 다른 guest kernel용 `.ko`를 복사해
재사용하지 말고, 해당 kernel build tree로 다시 build한다.

## 5. Linux 6.12.101 준비

### 목표

QEMU가 실행할 `bzImage`, GDB가 읽을 symbol-bearing `vmlinux`와 외부 module
build에 사용할 정확히 같은 kernel tree를 만든다.

### 5.1 Source 다운로드와 checksum 확인

실행 위치: repository root

```bash
mkdir -p local/wsl
cd local/wsl

curl -fLO \
    https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.101.tar.xz

printf '%s  %s\n' \
    '0d21cd11933f49f7151b7c9dbb8cc3fddc8c8abe506434b850feecf41fc28a76' \
    'linux-6.12.101.tar.xz' |
    sha256sum -c -

tar -xf linux-6.12.101.tar.xz
cd $PCIE_REPO_ROOT
```

정상 결과:

```text
linux-6.12.101.tar.xz: OK
```

확인:

```bash
test -f local/wsl/linux-6.12.101/Makefile &&
    echo "OK: kernel source"
```

### 5.2 Kernel configuration 생성

실행 위치: kernel tree

```bash
cd $PCIE_REPO_ROOT/local/wsl/linux-6.12.101

make x86_64_defconfig

scripts/config --enable BLK_DEV_INITRD
scripts/config --enable RD_GZIP
scripts/config --enable DEVTMPFS
scripts/config --enable DEVTMPFS_MOUNT
scripts/config --enable MODULES
scripts/config --enable MODULE_UNLOAD
scripts/config --enable PCI
scripts/config --enable PCI_MSI
scripts/config --enable SERIAL_8250
scripts/config --enable SERIAL_8250_CONSOLE
scripts/config --enable KALLSYMS
scripts/config --enable KALLSYMS_ALL
scripts/config --enable DEBUG_KERNEL
scripts/config --enable DEBUG_INFO
scripts/config --disable DEBUG_INFO_NONE
scripts/config --enable DEBUG_INFO_DWARF5
scripts/config --enable GDB_SCRIPTS

make olddefconfig
```

필수 설정 확인:

```bash
grep -E \
'^(CONFIG_BLK_DEV_INITRD|CONFIG_RD_GZIP|CONFIG_DEVTMPFS|CONFIG_MODULES|CONFIG_MODULE_UNLOAD|CONFIG_PCI|CONFIG_PCI_MSI|CONFIG_SERIAL_8250_CONSOLE|CONFIG_KALLSYMS_ALL|CONFIG_DEBUG_INFO|CONFIG_DEBUG_INFO_DWARF5|CONFIG_GDB_SCRIPTS)=y' \
.config

grep CONFIG_DEBUG_INFO_NONE .config
```

두 번째 명령의 정상 결과:

```text
# CONFIG_DEBUG_INFO_NONE is not set
```

필수 항목이 `=y`가 아니면 build 전에 설정 문제를 해결한다.

### 5.3 Kernel build

실행 위치: kernel tree

```bash
make -j"$(nproc)"
make scripts_gdb
```

WSL에 할당한 CPU나 memory가 적으면 `make -j4`처럼 job 수를 줄인다.

Build 확인:

```bash
file vmlinux

readelf -S vmlinux |
    grep -E '\.debug_info|\.debug_line' |
    head

file arch/x86/boot/bzImage
make --no-print-directory -s kernelrelease
```

정상 조건:

- `vmlinux`가 `with debug_info, not stripped`로 표시된다.
- `.debug_info`와 `.debug_line` section이 존재한다.
- `arch/x86/boot/bzImage`가 Linux kernel x86 boot executable로 표시된다.
- `kernelrelease` 출력이 `6.12.101`이다.

`vmlinux`, `bzImage`와 이후 생성할 `edu_pci.ko`는 반드시 이 kernel tree와
`.config`에서 나온 결과여야 한다.

## 6. BusyBox initramfs 생성

### 목표

별도 disk image 없이 kernel module을 load하고 sysfs/procfs를 확인할 수 있는
최소 guest root filesystem을 만든다.

### 6.1 Directory와 BusyBox 준비

실행 위치: repository root

```bash
cd $PCIE_REPO_ROOT

mkdir -p \
    local/wsl/initramfs/bin \
    local/wsl/initramfs/dev \
    local/wsl/initramfs/etc \
    local/wsl/initramfs/lib \
    local/wsl/initramfs/proc \
    local/wsl/initramfs/sbin \
    local/wsl/initramfs/sys \
    local/wsl/initramfs/tmp

chmod 1777 local/wsl/initramfs/tmp

install -m 0755 \
    "$(command -v busybox)" \
    local/wsl/initramfs/bin/busybox
```

BusyBox applet link를 만든다.

```bash
(
    cd local/wsl/initramfs/bin

    for applet in $(./busybox --list); do
        if [ "$applet" != "busybox" ]; then
            ln -sf busybox "$applet"
        fi
    done
)
```

`busybox` 자체는 link로 만들지 않는다. 그렇지 않으면 `busybox -> busybox`
자기참조 link가 되어 initramfs가 부팅되지 않는다.

확인:

```bash
file local/wsl/initramfs/bin/busybox
readlink local/wsl/initramfs/bin/sh
test -x local/wsl/initramfs/bin/insmod &&
    echo "OK: insmod"
test -x local/wsl/initramfs/bin/rmmod &&
    echo "OK: rmmod"
```

정상 조건:

- BusyBox는 `statically linked`다.
- `bin/sh`는 `busybox`를 가리킨다.
- `insmod`와 `rmmod` 확인이 출력된다.

### 6.2 `/init` 작성

실행 위치: repository root

```bash
tee local/wsl/initramfs/init >/dev/null <<'EOF'
#!/bin/sh

export PATH=/bin:/sbin

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "================================="
echo " Linux kernel GDB lab is running "
echo "================================="
echo

exec /bin/sh
EOF

chmod 0755 local/wsl/initramfs/init
```

확인:

```bash
test -x local/wsl/initramfs/init &&
    echo "OK: executable /init"
```

초기 archive는 별도로 만들 필요가 없다. 다음 단계의
`update-initramfs.sh`가 module을 복사하고 archive까지 생성한다.

## 7. EDU driver build

### 목표

`driver/edu/edu_pci.c`를 방금 만든 Linux 6.12.101의 외부 kernel module로
build한다.

실행 위치: repository root

```bash
cd $PCIE_REPO_ROOT

make -C driver/edu clean
make -C driver/edu
```

확인:

```bash
file driver/edu/edu_pci.ko
modinfo -F name driver/edu/edu_pci.ko
modinfo -F description driver/edu/edu_pci.ko
modinfo -F vermagic driver/edu/edu_pci.ko
```

정상 조건:

- `edu_pci.ko`는 `ELF 64-bit LSB relocatable, x86-64`다.
- module name은 `edu_pci`다.
- `vermagic`의 첫 field는 `6.12.101`이다.

VS Code/clangd navigation database도 만들려면:

```bash
scripts/wsl/phase1/refresh-compile-commands.sh

clangd \
    --check=driver/edu/edu_pci.c \
    --compile-commands-dir=. \
    --log=error
```

정상 조건:

- root `compile_commands.json`이 생성된다.
- clangd가 error 없이 종료한다.

## 8. Module을 initramfs에 반영

### 목표

Build한 `edu_pci.ko`를 unpacked initramfs와 compressed archive에 넣고 세
복사본이 같은지 확인한다.

실행 위치: repository root

```bash
scripts/wsl/phase1/update-initramfs.sh
scripts/wsl/phase1/update-initramfs.sh --check
```

정상 결과에 다음 항목이 모두 있어야 한다.

```text
[OK] built EDU module: Linux 6.12.101
[OK] copied module is byte-for-byte identical
[OK] gzip integrity
[OK] archive contains the identical module
All checks passed.
```

Archive 내부 경로:

```text
lib/modules/6.12.101/extra/edu_pci.ko
```

기존 `initramfs.cpio.gz`가 있으면 update script가 timestamp를 붙인 backup을
만든다.

## 9. QEMU 실행

### 9.1 입력 파일 확인

실행 위치: repository root

```bash
scripts/wsl/phase1/run-qemu-edu.sh --check
```

정상 결과:

```text
[OK] kernel image: .../local/wsl/linux-6.12.101/arch/x86/boot/bzImage
[OK] initramfs image: .../local/wsl/initramfs.cpio.gz
[OK] QEMU binary: .../qemu-system-x86_64
```

### 9.2 Guest 부팅

```bash
scripts/wsl/phase1/run-qemu-edu.sh
```

Script는 다음 주요 설정을 사용한다.

- `q35` machine
- 2 vCPU, 1 GiB RAM
- `-device edu`
- serial console
- `nokaslr`
- localhost GDB endpoint `127.0.0.1:1234`

정상 조건은 다음 banner와 BusyBox prompt다.

```text
Linux kernel GDB lab is running
~ #
```

다음 메시지는 최소 initramfs에서 예상된다.

```text
/bin/sh: can't access tty; job control turned off
```

이후 `~ #`가 붙은 명령은 QEMU guest에서 실행한다.

## 10. QEMU guest에서 EDU 검증

### 10.1 EDU 장치 찾기

Guest에서 실행:

```sh
EDU=""

for device_path in /sys/bus/pci/devices/*; do
    if [ "$(cat "$device_path/vendor")" = "0x1234" ] &&
       [ "$(cat "$device_path/device")" = "0x11e8" ]; then
        EDU="$device_path"
        break
    fi
done

test -n "$EDU" &&
    echo "EDU=$EDU"
```

정상 결과 예:

```text
EDU=/sys/bus/pci/devices/0000:00:03.0
```

Resource 확인:

```sh
cat "$EDU/vendor"
cat "$EDU/device"
cat "$EDU/resource"
cat "$EDU/irq"
```

정상 조건:

- vendor: `0x1234`
- device: `0x11e8`
- BAR0: 일반적으로 `0xfea00000-0xfeafffff`, 1 MiB
- load 전 driver link가 없으면 unbound 상태다.

```sh
readlink "$EDU/driver" ||
    echo "OK: unbound"
```

### 10.2 Module load와 기능 확인

```sh
insmod /lib/modules/6.12.101/extra/edu_pci.ko
echo "insmod exit=$?"
```

정상 조건:

```text
insmod exit=0
identification: 0x010000ed
liveness: wrote=0x12345678 read=0xedcba987
factorial: 5! = 120
```

`out-of-tree module taints kernel`은 외부 실습 module에서 예상되는 정보다.
초기 IRQ 11 log 뒤 ACPI가 IRQ 23을 enable할 수 있으며 현재 단계의 오류가 아니다.

Load 상태 확인:

```sh
readlink "$EDU/driver"
grep '^edu_pci ' /proc/modules
grep -F 'edu_pci' /proc/iomem

dmesg |
    grep -E 'edu_pci.*(probe|identification|liveness|factorial|failed)'
```

정상 조건:

- driver link가 `../../../bus/pci/drivers/edu_pci`를 가리킨다.
- `/proc/modules`에 `Live (O)` 상태가 보인다.
- `/proc/iomem`에 BAR0 owner `edu_pci`가 보인다.
- `failed` log가 없다.

### 10.3 Module unload와 cleanup 확인

```sh
rmmod edu_pci
echo "rmmod exit=$?"

test ! -L "$EDU/driver" &&
    echo "OK: binding released"

grep '^edu_pci ' /proc/modules ||
    echo "OK: module removed"

grep -F 'edu_pci' /proc/iomem ||
    echo "OK: BAR0 region released"
```

정상 조건:

```text
rmmod exit=0
OK: binding released
OK: module removed
OK: BAR0 region released
```

Kernel log에는 `remove: BDF=...`가 한 번 나타나야 한다.

## 11. Driver 수정 후 반복 절차

Kernel과 initramfs 기반이 이미 준비된 경우 매번 전체 환경을 다시 만들 필요는
없다. Driver source를 수정한 뒤 repository root에서 다음 순서만 반복한다.

```bash
make -C driver/edu
scripts/wsl/phase1/update-initramfs.sh
scripts/wsl/phase1/update-initramfs.sh --check
scripts/wsl/phase1/run-qemu-edu.sh
```

Guest에서는 다음 순서를 반복한다.

```sh
insmod /lib/modules/6.12.101/extra/edu_pci.ko
dmesg | tail -n 30
rmmod edu_pci
```

Source navigation 정보가 바뀌었으면 다음도 다시 실행한다.

```bash
scripts/wsl/phase1/refresh-compile-commands.sh
```

## 12. GDB로 kernel 디버깅

GDB가 필요하지 않으면 이 절을 건너뛰어도 module 기능 검증은 가능하다.

### 12.1 Kernel script 자동 로드 허용

Repository root에서:

```bash
mkdir -p $HOME/.config/gdb

GDB_SCRIPT="$PCIE_REPO_ROOT/local/wsl/linux-6.12.101/scripts/gdb/vmlinux-gdb.py"
GDB_SAFE_LINE="add-auto-load-safe-path $GDB_SCRIPT"

grep -Fqx "$GDB_SAFE_LINE" $HOME/.config/gdb/gdbinit 2>/dev/null ||
    printf '%s\n' "$GDB_SAFE_LINE" >>$HOME/.config/gdb/gdbinit
```

모든 경로를 허용하는 `set auto-load safe-path /`는 사용하지 않는다.

### 12.2 QEMU를 정지 상태로 시작

첫 번째 WSL terminal, repository root:

```bash
scripts/wsl/phase1/run-qemu-edu.sh -S
```

`-S` 때문에 guest 출력 없이 CPU가 정지해 있는 것이 정상이다.

### 12.3 GDB 연결

두 번째 WSL terminal:

```bash
cd /path/to/pcie-lab
export PCIE_REPO_ROOT=$PWD

gdb local/wsl/linux-6.12.101/vmlinux
```

GDB prompt에서:

```gdb
target remote 127.0.0.1:1234
break start_kernel
continue
```

`start_kernel`에서 멈추면:

```gdb
list
bt
info registers
lx-version
```

정상 조건:

- `start_kernel` breakpoint에 도달한다.
- `lx-version`이 Linux 6.12.101 build 정보를 출력한다.

부팅을 계속하려면:

```gdb
continue
```

더 많은 명령은 [GDB kernel guide](../debugging/gdb-kernel-guide.md)와
[GDB cheatsheet](../debugging/gdb-cheatsheet.md)를 참고한다.

## 13. QEMU 종료와 복구

정상 종료:

1. QEMU terminal에서 `Ctrl-a`를 누르고 뗀다.
2. `x`를 누른다.

종료되지 않으면 다른 WSL terminal에서 먼저 대상을 확인한다.

```bash
pgrep -af qemu-system-x86_64
```

확인한 PID만 종료한다.

```bash
kill <PID>
```

GDB port가 이미 사용 중인지 확인:

```bash
ss -ltnp |
    grep ':1234'
```

## 14. 자주 발생하는 문제

### `kernel tree not found`

`driver/edu/Makefile`의 기본 kernel 경로는
`local/wsl/linux-6.12.101`이다.

```bash
test -f local/wsl/linux-6.12.101/Makefile
```

다른 경로를 사용할 때:

```bash
make -C driver/edu \
    KDIR=/absolute/path/to/linux-6.12.101
```

### `invalid module format` 또는 vermagic 불일치

```bash
make --no-print-directory -s \
    -C local/wsl/linux-6.12.101 \
    kernelrelease

modinfo -F vermagic driver/edu/edu_pci.ko
```

두 출력의 kernel release가 같아야 한다. 다르면 module을 올바른 tree에서 clean
build하고 initramfs를 다시 갱신한다.

### `No working init found`

```bash
gzip -t local/wsl/initramfs.cpio.gz

gzip -dc local/wsl/initramfs.cpio.gz |
    cpio -it |
    grep -E '^(\./)?(init|bin/busybox|bin/sh)$'

file local/wsl/initramfs/bin/busybox
test -x local/wsl/initramfs/init
```

정상 조건:

- gzip 검사가 통과한다.
- archive에 `init`, `bin/busybox`와 `bin/sh`가 있다.
- BusyBox는 static executable이다.
- `init`은 executable이다.

### `busybox -> busybox`

BusyBox binary를 자기참조 symbolic link로 덮어쓴 상태다. `bin/busybox`를 다시
복사하고 `busybox`를 제외한 applet link만 생성한다.

### initramfs에 module이 없거나 다름

```bash
scripts/wsl/phase1/update-initramfs.sh --check
```

실패하면 `make -C driver/edu`와 update command를 다시 실행한다.

### GDB auto-load 거부

`~/.config/gdb/gdbinit`의 `add-auto-load-safe-path`가 현재 repository의
`vmlinux-gdb.py` 절대 경로와 일치하는지 확인한다.

### TSC clocksource 경고

GDB로 VM을 오래 멈춘 뒤 TSC skew 경고가 나타날 수 있다. Kernel이 TSC를
unstable로 표시하고 `Switched to clocksource hpet`까지 출력하면 이 실습을
막는 오류가 아니다.

### `can't access tty; job control turned off`

현재 최소 `/init`이 control TTY 없이 shell을 직접 실행해서 나타난다. 일반
guest 명령 실행에는 지장이 없다.

## 15. 완료 checklist

- [ ] WSL package와 QEMU가 준비됨
- [ ] Linux 6.12.101 `vmlinux`와 `bzImage` build
- [ ] `vmlinux` debug information 확인
- [ ] static BusyBox initramfs 생성
- [ ] `edu_pci.ko` build와 `6.12.101` vermagic 확인
- [ ] initramfs module 동일성과 gzip 검사 통과
- [ ] QEMU EDU `1234:11e8` 발견
- [ ] binding과 BAR0 owner 확인
- [ ] identification, liveness와 factorial 확인
- [ ] unload 후 binding/module/BAR0 cleanup 확인
- [ ] 필요 시 GDB `start_kernel` breakpoint 확인

모든 항목을 통과하면 기존 factorial polling 단계까지의 WSL 환경과 driver
복습이 완료된 것이다. 다음 학습 단계는 EDU interrupt/IRQ다.
