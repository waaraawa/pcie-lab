# QEMU EDU PCI 드라이버 학습 로드맵

## 최종 목표

QEMU가 제공하는 가상 PCI 장치 EDU를 Linux kernel driver로 제어한다.
완성된 실습에서는 다음 흐름이 동작해야 한다.

```text
사용자 프로그램
    │ ioctl/read/write
    ▼
edu_pci kernel driver
    │ MMIO / IRQ / DMA
    ▼
QEMU EDU PCI device
```

최종 사용 예시는 다음과 같은 형태다.

```text
./edu_test factorial 5  -> 120
./edu_test dma-test     -> data verified
```

## EDU는 어떤 장치인가

EDU는 PCI driver 학습을 위해 만든 작은 가상 연산 장치다. 다음 하드웨어
기능을 제공한다.

- identification: 장치 버전 확인
- liveness: MMIO 통신 확인
- factorial engine: 입력값의 factorial 계산
- interrupt controller: 작업 완료를 CPU에 알림
- DMA controller: CPU가 직접 복사하지 않고 RAM과 장치 사이에서 데이터 전송

QEMU 내부에서는 software로 구현됐지만 guest driver 관점에서는 BAR, IRQ와
DMA를 사용하는 PCI hardware다.

EDU는 PCI driver 기초를 위한 장치다. MMIO, INTx/MSI와 DMA는 지원하지만 이
실습만으로 PCIe capability, MSI-X, multi-queue와 link 동작까지 검증한 것은
아니다.

## 선행 조건과 참고 자료

선행 조건:

- Linux guest와 정확한 kernel version이 문서화되어 있다.
- kernel/module build와 QEMU 부팅·복구 절차를 반복할 수 있다.
- guest kernel log를 확인하고 matching `vmlinux`로 디버깅할 수 있다.
- 모든 host가 `driver/edu/`의 같은 source와 `tests/guest/`의 같은 test를
  사용한다.

주요 참고 자료:

- [LDD3 Chapter 12: PCI Drivers](https://lwn.net/images/pdf/LDD3/ch12.pdf)
- [현재 Linux kernel PCI 문서](https://docs.kernel.org/PCI/pci.html)
- [QEMU EDU 명세](https://www.qemu.org/docs/master/specs/edu.html)

LDD3는 PCI 개념과 수명주기를 이해하는 참고 자료로 사용한다. Linux 2.6.10
시대 자료이므로 실제 API, interrupt vector와 DMA 구현은 현재 선택한 kernel의
문서와 source를 기준으로 확인한다.

## 전체 학습 단계

### 1. PCI 장치 발견과 driver binding — 완료

목표:

- vendor/device ID로 EDU를 찾는다.
- module load 시 `probe()`, unload 시 `remove()`가 호출되는 것을 이해한다.

정상 조건:

- `1234:11e8` 장치에 `edu_pci`가 bind된다.
- unload 후 driver link와 module entry가 사라진다.

### 2. BAR0 확보와 MMIO — 완료

목표:

- BAR가 장치 register와 memory를 제공하는 창이라는 것을 이해한다.
- enable, region request, `pci_iomap()`과 반대 순서 cleanup을 구현한다.

정상 조건:

- `/proc/iomem`에 BAR0 owner가 표시된다.
- identification `0x010000ed`를 읽는다.
- unload 후 BAR0 owner가 사라진다.

### 3. 장치 명령과 polling — 완료

목표:

- liveness로 MMIO read/write를 검증한다.
- factorial engine에 명령하고 status register를 polling한다.

정상 조건:

- `0x12345678`을 쓰고 `0xedcba987`을 읽는다.
- factorial `5! = 120`을 읽는다.
- timeout과 결과 불일치 시 probe가 안전하게 실패하고 자원을 반환한다.

### 4. Interrupt/IRQ — in progress

Goal:

- Let the device report completion without repeated CPU register reads.
- Identify and acknowledge the device-local cause in the shared handler.

Verified on Windows/WSL:

1. A one-shot write to interrupt-raise offset `0x60` exercised the INTx path.
2. The handler read cause `0x1`, acknowledged it, and observed zero remaining
   causes without an interrupt storm.
3. Factorial now enables status bit `0x80` and waits on a kernel completion.
4. The device-generated IRQ wakes probe, which reads `5! = 120` from offset
   `0x08`.
5. Failure and remove paths disable the producer, acknowledge pending cause,
   and release the handler and vector before BAR0 teardown.

Remaining work:

- Exercise a controlled factorial timeout/error path.
- Compare INTx with MSI.
- Repeat the IRQ milestone on Intel macOS and satisfy the cross-host gate.

### 5. DMA — 예정

목표:

- DMA mask와 PCI bus mastering을 설정한다.
- DMA-safe RAM buffer를 준비한다.
- CPU 복사 대신 EDU DMA engine으로 RAM과 장치 buffer 사이를 전송한다.

정상 조건:

- RAM -> EDU -> RAM 왕복 후 데이터가 일치한다.
- timeout, DMA address와 cleanup을 검증한다.
- 이후 DMA 완료를 IRQ로 받는다.

### 6. 사용자 공간 interface — 예정

목표:

- `/dev/edu0` character device를 만든다.
- 사용자 프로그램이 `ioctl()`로 factorial과 DMA를 요청하게 한다.
- `copy_from_user()`와 `copy_to_user()`의 경계를 이해한다.

정상 조건:

- 사용자 프로그램에서 factorial 결과를 받는다.
- 잘못된 입력과 동시 요청을 driver가 안전하게 처리한다.

### 7. 실제 driver 형태로 정리 — 예정

목표:

- 장치별 state structure와 locking을 적용한다.
- 모든 probe 실패 지점과 remove cleanup을 검증한다.
- debug log, timeout과 오류 반환을 정리한다.

이 단계를 마치면 QEMU EDU 실습은 완료다. 이후 실제 PCIe hardware에서는
EDU register map 대신 해당 장치 datasheet의 register map을 사용하지만,
PCI binding, BAR, MMIO, IRQ, DMA와 사용자 interface라는 큰 구조는 동일하다.

## 현재 위치

```text
[complete] binding
   -> [complete] BAR/MMIO
   -> [complete] liveness/factorial polling
   -> [in progress] IRQ: WSL INTx verified; MSI and Mac parity remain
   -> [planned] DMA
   -> [planned] /dev/edu0 + ioctl
   -> [planned] production-style driver cleanup
```

코드를 추가하기 전에 매 단계에서 먼저 다음 세 가지를 확인한다.

1. 하드웨어 기능이 무엇인가
2. driver가 그 기능을 어떻게 제어하는가
3. 어떤 결과가 나오면 성공인가

## Phase 1 전체 완료 조건

- 다른 환경에서 repository 문서만으로 guest와 driver test를 재현한다.
- binding, BAR/MMIO, interrupt와 양방향 DMA test가 반복 통과한다.
- 사용자 공간 program으로 정상 요청과 잘못된 입력을 검증한다.
- 반복 load/unload, transfer와 timeout에서 kernel warning과 resource leak이
  없다.
- happy path뿐 아니라 probe 실패와 teardown 경로도 실행해 확인한다.
- CPU virtual address, physical address와 DMA/bus address의 역할 차이를
  설명할 수 있다.
- 명령, 정상 결과, 실패 분석과 알려진 제한을 문서에 기록한다.

MSI-X/multi-queue, 전체 PCIe capability, Windows port와 실제 link/endpoint
debugging은 Phase 1 범위 밖이며 이후 단계에서 다룬다.
