# pcie-lab

Linux에서 시작해 QEMU PCI 장치, 실제 PCIe 하드웨어, Windows KMDF까지 이어지는
실습 중심 PCI/PCIe driver 학습 repository다.

The canonical implementation is the QEMU EDU Linux driver under `driver/edu/`.
Windows/WSL has verified binding, BAR0/MMIO, identification, liveness, one-shot
INTx, interrupt-driven factorial completion, controlled timeout cleanup, and a
one-vector MSI mode with verified bus-master lifecycle. DMA and cross-host IRQ
parity remain.

## 학습 순서

1. [공통 host 준비 조건](docs/common/phase-0-host-contract.md)
2. [QEMU EDU Linux PCI driver](docs/common/phase-1-qemu-edu.md)
3. [QEMU NVMe PCIe data path](docs/common/phase-2-qemu-pcie-data-path.md)
4. [실제 PCIe hardware Linux driver](docs/common/phase-3-physical-hardware.md)
5. 실제 hardware의 Windows KMDF driver

전체 목표, 단계별 완료 조건과 현재 진도는
[학습 로드맵](docs/roadmap.md)에 있다.

## Host별 시작점

- [Intel macOS](docs/hosts/intel-macos.md): QEMU/HVF Phase 0 환경과 Mac evidence
- [Windows/WSL](docs/hosts/windows-wsl.md): 현재 Linux 6.12.101 EDU 실습 환경
- [Cross-host validation matrix](docs/validation-matrix.md): host별 검증 범위

두 host는 `driver/edu/`의 같은 source를 사용하되 각 guest kernel에 맞는
module을 별도로 build한다. 같은 guest test가 양쪽에서 통과해야 EDU 기능을
cross-host 완료로 표시한다.

## Repository 구조

- `driver/edu/`: canonical Linux EDU driver와 build/readme
- `docs/common/`: host-independent curriculum과 completion gate
- `docs/hosts/`: host별 setup, command, evidence와 limitation
- `docs/debugging/`: Linux kernel GDB guide와 cheatsheet
- `scripts/wsl/`: Windows/WSL host workflow
- `scripts/macos/`: Intel macOS host workflow
- `scripts/common/`: 두 host에서 검증된 공통 helper 위치
- `labs/phase0/`: 환경 확인용 최소 module lab
- `tools/`: host build-container 정의
- `tests/guest/`: Linux guest에서 실행할 공통 functional test
- `tests/expected/`: host-independent 정상 결과와 비교 규칙

`local/`에는 kernel build, initramfs와 VM 같은 host-local 산출물을 둔다.
`local/`, kernel module build output, `compile_commands.json`, `another/`와
agent-local `AGENTS.md`는 Git 추적 대상이 아니다.

## WSL 빠른 시작

host-local Linux 6.12.101 kernel과 initramfs가 준비된 repository root에서:

```bash
make -C driver/edu
scripts/wsl/phase1/update-initramfs.sh
scripts/wsl/phase1/run-qemu-edu.sh
```

입력 파일만 확인할 때:

```bash
scripts/wsl/phase1/update-initramfs.sh --check
scripts/wsl/phase1/run-qemu-edu.sh --check
```

상세 build, guest 확인 명령과 정상 결과는
[`driver/edu/README.md`](driver/edu/README.md)와
[`docs/hosts/windows-wsl.md`](docs/hosts/windows-wsl.md)에 있다.

## 참고 자료 사용 원칙

- [Linux Device Drivers, Third Edition](https://lwn.net/Kernel/LDD3/)
- [현재 Linux kernel PCI 문서](https://docs.kernel.org/PCI/pci.html)
- [QEMU EDU 명세](https://www.qemu.org/docs/master/specs/edu.html)

LDD3는 개념 참고 자료이며 현재 API의 권위 있는 기준은 선택한 Linux kernel의
문서와 source다.
