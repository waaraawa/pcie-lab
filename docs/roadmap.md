# PCIe 드라이버 학습 로드맵

## 최종 목표

1. Linux에서 PCI/PCIe 구조와 드라이버 API를 이해한다.
2. QEMU 가상 PCI 장치로 안전하게 MMIO, 인터럽트, DMA를 실습한다.
3. 실제 PCIe 하드웨어의 Linux 드라이버를 구현한다.
4. 같은 하드웨어의 Windows KMDF 드라이버를 구현한다.

목표는 API 이름을 암기하는 것이 아니라 사용자 요청부터 장치 완료까지의
host-to-device data path를 설명하고, 구현하고, 디버깅하고, 검증하는 것이다.

## 전체 단계

| 단계 | 환경 | 핵심 결과 |
| --- | --- | --- |
| [0. 환경과 smoke test](common/phase-0-host-contract.md) | Intel Mac, Windows/WSL, QEMU/Linux | 호스트별로 반복 가능한 부팅·모듈·로그·디버깅 경로 |
| [1. QEMU EDU](common/phase-1-qemu-edu.md) | 검증된 어느 호스트의 QEMU/Linux | MMIO, IRQ, DMA와 사용자 인터페이스를 갖춘 공통 PCI 드라이버 |
| [2. QEMU PCIe data path](common/phase-2-qemu-pcie-data-path.md) | QEMU NVMe와 선택적 custom device | queue, doorbell, MSI-X, timeout과 reset의 end-to-end 이해 |
| [3. 실제 하드웨어](common/phase-3-physical-hardware.md) | x86 Linux host와 physical endpoint | 실제 link, IRQ, DMA, recovery, 성능과 isolation 검증 |
| 4. Windows KMDF | Windows test host와 같은 physical endpoint | Linux에서 검증한 hardware protocol의 KMDF 구현 |

가상 장치부터 시작하면 커널 실패를 안전하고 반복 가능하게 만들 수 있다.
EDU에서 기본 수명주기를 익힌 뒤 NVMe에서 queue 기반 데이터 경로를 추적하고,
software 쪽 불확실성을 줄인 다음 실제 하드웨어와 Windows로 이동한다.

## 현재 위치

### 단계 0 — 커널 디버깅 실습 환경 구축

- Windows/WSL host: 완료
- Intel macOS host: boot와 module smoke test 완료, symbol/debugger 경로 미완료

- Linux 6.12.101 디버그 커널 빌드
- BusyBox initramfs 부팅
- QEMU GDB 서버 연결
- `start_kernel` 브레이크포인트 적중
- BusyBox 셸 진입

이 환경은 이후 PCI 드라이버의 `probe()`, MMIO, 인터럽트, DMA 코드를 소스 수준에서 추적하는 기반이다.

호스트별 gate는 독립적이다. 한 호스트에서 Phase 1을 진행하는 동안 다른
호스트는 Phase 0을 마칠 수 있다. 같은 source revision과 guest-side test가 두
호스트에서 통과한 경우에만 cross-host 완료로 기록한다.

### 다음 단계 진입 조건

Phase 2 진입 조건:

- 반복 load/unload와 BAR/MMIO, interrupt, 양방향 DMA test가 통과한다.
- 자원 획득·실패·해제 경로를 설명하고 반복 검증할 수 있다.
- Phase 1 환경과 사용자 공간 test를 문서에서 재현할 수 있다.

Phase 3 진입 조건:

- 사용자 요청이 Linux driver와 QEMU device를 왕복하는 한 경로를 추적한다.
- queue ownership, doorbell, completion, MSI-X, timeout과 reset을 설명한다.
- 실제 endpoint, host, debug/recovery 경로와 예산을 근거로 선정한다.

모든 단계는 재현 절차, source 또는 trace, 검증 결과, 실패 분석, 알려진 제한과
완료 조건을 evidence로 남긴다.

## 단계 1 — Linux PCI 기초와 QEMU EDU 장치

학습 장치로 QEMU의 `edu`를 사용한다.

- QEMU 옵션: `-device edu`
- Vendor ID: `0x1234`
- Device ID: `0x11e8`
- BAR0: 1 MiB MMIO
- 실습 기능: 식별 레지스터, 값 반전, 팩토리얼, INTx/MSI, DMA

현재 로컬 QEMU 8.2.2에서 `edu` 장치 지원을 확인했다.

EDU는 QEMU에서 conventional PCI endpoint로 제공된다. PCIe와 공통인 Linux 장치 매칭, configuration space, BAR/MMIO, interrupt, DMA 드라이버 구조를 먼저 배우는 용도다. PCIe capability와 link 관련 기능은 EDU 실습 뒤 별도 단계에서 다룬다.

### 1-1. PCI 장치 관찰: 완료

- PCI domain:bus:device.function 주소 이해
- configuration space와 Vendor/Device ID 확인
- BAR, IRQ, class, driver binding 확인
- `/sys/bus/pci/devices`, `resource`, `config` 구조 관찰
- 필요하면 initramfs에 `lspci`를 추가

완료 조건:

- 게스트에서 `1234:11e8` 장치를 찾는다.
- BAR0 주소와 크기를 설명할 수 있다.

확인 결과:

- BDF: `0000:00:03.0`
- BAR0: `0xfea00000-0xfeafffff`, 1 MiB MMIO
- resource flags: `0x40200` (`IORESOURCE_MEM | IORESOURCE_SIZEALIGN`)
- legacy INTx IRQ: 11

### 1-2. 최소 PCI 커널 모듈: 완료

- out-of-tree 모듈과 Makefile 작성
- `struct pci_device_id`에 `1234:11e8` 등록
- `struct pci_driver`와 `module_pci_driver()` 사용
- `probe()`/`remove()`에서 로그 출력
- 모듈을 initramfs에 넣고 `insmod`/`rmmod` 반복
- GDB에서 드라이버 `probe()`에 브레이크포인트 설정

현재 진행:

- 사용자가 현재 `driver/edu/`로 이동된 driver source와 문서의 초기 파일을
  생성했다.
- 사용자가 module/PCI 헤더와 EDU PCI ID 테이블을 작성했고 기능 검토를 통과했다.
- 공식 kernel clang-format 적용과 ID 테이블 스타일 정리를 완료했다.
- 사용자가 `probe()`/`remove()` callback을 작성했다.
- Device ID 로그 format specifier 수정을 완료했다.
- `struct pci_driver`와 module 등록 코드를 작성했다.
- `MODULE_DESCRIPTION` 철자를 수정해 최소 C 소스 리뷰를 완료했다.
- out-of-tree module `Makefile` 작성과 정적 검토를 완료했다.
- 사용자가 실제 `make`를 실행했고 `edu_pci.ko` 생성 및 metadata 검증을
  완료했다.
- 모듈을 `initramfs/lib/modules/6.12.101/extra/`에 복사하고 원본과 동일함을
  확인했다.
- 새 `initramfs.cpio.gz.new`를 생성하고 gzip 무결성 및 module 포함 여부를
  검증했다.
- 복사, 비교, 재패키징, 검증과 backup을 자동화하는
  `update-edu-initramfs.sh`를 추가하고 문법을 검사했다.
- 사용자가 전체 갱신과 `--check`를 실행했고 Codex 재검증도 통과했다.
- QEMU 게스트에서 `insmod` exit code 0과 `probe()` 로그를 확인했다.
- sysfs driver binding과 `/proc/modules`의 `Live (O)` 상태를 확인했다.
- `rmmod` 후 `remove()` callback 로그를 확인했다.
- binding과 `/proc/modules`의 module entry 제거를 확인했다.
- 단계 1-2 최소 module 생명주기 검증을 완료했다.
- driver `probe()`의 GDB source breakpoint 실습은 환경 구축 때 이미 검증한
  GDB 기반을 사용해 MMIO 또는 interrupt 단계에서 필요할 때 진행한다.

완료 조건:

- `insmod` 시 `probe()`가 한 번 호출된다.
- `rmmod` 시 `remove()`가 호출되고 자원이 남지 않는다.

### 1-3. BAR와 MMIO: 완료

- `pci_enable_device()`
- `pci_request_regions()` 또는 managed API
- `pci_iomap()`/`pci_iounmap()`
- `readl()`/`writel()`과 posted write 이해
- EDU identification, liveness, factorial 레지스터 실습
- probe 실패 경로에서 역순으로 자원 정리

현재 진행:

- `probe()` 입력 로그 뒤에 `pci_enable_device()`와 오류 반환을 추가했다.
- `remove()`에 대응하는 `pci_disable_device()`를 추가했다.
- 정적 코드 리뷰와 kernel style 검사를 통과했다.
- 변경 후 module build와 metadata/symbol 검증을 통과했다.
- initramfs 갱신과 final archive 재검증을 통과했다.
- QEMU에서 변경 module의 `probe()` 진입 로그를 확인했다.
- sysfs binding, `rmmod` exit 0, remove 로그와 module 제거를 확인했다.
- PCI device enable/disable 하위 단계의 QEMU 회귀 검증을 완료했다.
- BAR0 region request/release와 request 실패 cleanup을 작성하고 정적 코드
  리뷰를 통과했다.
- 변경 후 module build와 PCI region API symbol 검증을 통과했다.
- initramfs 갱신과 QEMU probe/remove 회귀 검증을 통과했다.
- `/proc/iomem`에서 load 중 BAR0 owner `edu_pci`와 unload 후 owner 제거를
  확인했다.
- BAR0 region request/release 하위 단계를 완료했다.
- `pci_iomap()`/`pci_iounmap()`과 driver data 저장 코드를 작성하고 실행했다.
- NULL 검사 조건을 반대로 작성해 mapping 성공을 `-ENOMEM` 실패로 처리한
  것을 확인했다.
- 조건을 `if (!bar0)`로 수정하고 정적 코드 리뷰를 통과했다.
- 수정 module rebuild와 initramfs 갱신을 완료했다.
- QEMU load에서 이전 mapping 실패 로그가 사라졌다.
- remove callback이 호출돼 mapping 성공과 binding을 확인했다.
- load 중 `/proc/iomem`의 `edu_pci` BAR0 owner와 mapping failure 부재를
  확인했다.
- 이어서 rmmod와 remove callback까지 수행했다.
- unload 후 `/proc/iomem`의 BAR0 owner 제거를 확인했다.
- BAR0 iomap/iounmap과 cleanup 하위 단계를 완료했다.
- identification offset `0x00`의 `readl()`과 8자리 hex log를 작성하고 정적
  코드 리뷰를 통과했다.
- module build와 disassembly의 32-bit MMIO read 검증을 통과했다.
- initramfs 갱신 후 QEMU에서 identification `0x010000ed`를 읽었다.
- major 1, minor 0과 EDU 고정 식별부 `0x00ed`를 확인했다.
- unload 후 BAR0 owner와 module entry 제거를 확인했다.
- identification read와 cleanup 하위 단계를 완료했다.
- offset `0x04` liveness code를 실행했으나 `readl()` 대입 누락으로
  uninitialized value 0을 비교해 `-EIO`로 실패했다.
- 누락된 read를 추가한 뒤 QEMU에서
  `0x12345678 -> 0xedcba987` inversion을 확인했다.
- unload cleanup과 module 제거를 확인했다.
- mismatch log의 `0x`/newline을 수정하고 코드 리뷰를 통과했다.
- 수정 후 build와 module string 검증을 통과했다.
- liveness write/read와 cleanup 하위 단계를 완료했다.
- factorial register에 `5`를 쓰고 status computing bit를
  `readl_poll_timeout()`으로 기다린 뒤 결과 `120`을 읽었다.
- factorial timeout과 result mismatch 오류 경로를 구현했다.
- QEMU에서 identification, liveness, factorial 성공과 unload cleanup을
  검증했다.
- canonical source를 `driver/edu/`, WSL Phase 1 script를
  `scripts/wsl/phase1/`, local kernel/initramfs를 `local/wsl/`로 재배치했다.
- 새 경로에서 clean build, clangd, initramfs 갱신과 archive 동일성 검사를
  통과했다.

완료 조건:

- EDU 식별 값을 읽는다.
- 값 반전과 팩토리얼 기능을 드라이버에서 검증한다.

### 1-4. 인터럽트

- polling과 interrupt 방식 비교
- `pci_alloc_irq_vectors()`
- `request_irq()`와 ISR
- interrupt status 읽기와 acknowledge
- INTx를 먼저 확인하고 MSI로 전환
- 동시성과 메모리 배리어 기초

Current WSL progress:

- A one-shot write to interrupt-raise offset `0x60` verified INTx routing,
  shared-handler registration, cause readback, acknowledgement, and clean
  teardown.
- The driver now registers the handler before starting factorial, enables
  status bit `0x80`, waits on a completion instead of polling, acknowledges
  factorial cause `0x1`, and reads `5! = 120` after the ISR wakes the probe.
- Linux 6.12.101 build, initramfs identity, one delivered IRQ without a storm,
  and unload cleanup passed on Windows/WSL.
- A read-only module parameter skipped factorial start and deterministically
  produced completion timeout `-110`. Probe cleanup removed binding, IRQ action,
  and BAR0 ownership and cleared status and pending IRQ registers to zero.
- A read-only `use_msi` parameter selects a single non-shared MSI vector. The
  first runtime attempt exposed a missing Bus Master Enable; after pairing
  `pci_set_master()` with cleanup, factorial completion arrived once on MSI IRQ
  28 and unload removed the vector, BAR owner, module, Bus Master Enable, and
  INTx Disable state.
- Combined MSI and forced-timeout testing also returned EDU status and pending
  cause to zero and released the MSI action, BAR owner, and PCI Command state
  before the unbound module was removed.
- Intel macOS IRQ parity remains.

완료 조건:

- EDU가 발생시킨 인터럽트를 ISR에서 확인하고 정상적으로 acknowledge한다.
- 인터럽트 폭주 없이 반복 동작한다.

### 1-5. DMA

- CPU virtual, physical, DMA/bus address 차이 이해
- EDU 기본 28-bit DMA mask 설정
- `dma_set_mask_and_coherent()`
- coherent DMA와 streaming DMA 비교
- `dma_alloc_coherent()` 또는 DMA mapping API 사용
- DMA 방향, 수명, cache coherency, IOMMU 이해

Current WSL progress:

- The driver has negotiated the EDU 28-bit DMA mask and allocated one 64-byte
  coherent buffer.
- Runtime output showed device address `0x047fd000`, which is within the
  28-bit limit, while the CPU pointer was safely restricted as `(ptrval)`.
- Normal remove and forced factorial-timeout paths released all observable PCI,
  IRQ, and BAR resources; the error path also cleared status and pending cause.
- DMA register programming and data transfer have not started.

완료 조건:

- RAM → EDU → RAM 전송 후 데이터가 일치한다.
- DMA 주소를 CPU 포인터처럼 사용하면 안 되는 이유를 설명할 수 있다.

### 1-6. 사용자 인터페이스와 견고성

- sysfs 또는 character device 중 작은 인터페이스 구현
- `ioctl`, read/write, mmap의 용도 비교
- locking, timeout, reset, error path
- hot-unplug/remove 중 I/O 중단
- 여러 장치 인스턴스 지원
- `dev_*()` 로그와 dynamic debug 활용

완료 조건:

- 사용자 프로그램에서 장치 기능을 호출한다.
- 반복 load/unload와 실패 주입에도 자원 누수가 없다.

### 1-7. PCIe 전용 기능

- PCI와 PCIe configuration/capability 차이
- Root Complex, Root Port, Endpoint 토폴로지
- PCIe capability 탐색과 link speed/width 확인
- MSI-X와 여러 interrupt vector
- AER와 error recovery callback
- ASPM, D-state, reset/FLR
- 실제 하드웨어가 지원하면 SR-IOV 기초

완료 조건:

- conventional PCI 공통 기능과 PCIe 전용 기능을 구분해 설명할 수 있다.
- 실제 장치의 PCIe capability와 현재 link 상태를 읽고 해석할 수 있다.

## 단계 2 — QEMU PCIe 데이터 경로

EDU의 단순 register/DMA 모델 다음에는 QEMU NVMe를 이용해 submission queue,
completion queue, doorbell, MSI-X, timeout과 controller reset을 추적한다. 전체
학습 범위와 완료 조건은
[`phase-2-qemu-pcie-data-path.md`](common/phase-2-qemu-pcie-data-path.md)에
있다.

NVMe driver 전체를 다시 구현하는 것이 목표는 아니다. 사용자 공간 I/O 한 건이
Linux queue에 들어가 QEMU device에서 처리되고 interrupt/completion으로 돌아오는
구조를 end-to-end로 이해하는 것이 목표다.

## 단계 3 — 실제 PCIe 하드웨어 Linux 드라이버

시작 전에 다음 정보가 필요하다.

- 정확한 보드/칩/FPGA 모델
- Vendor/Device/Subsystem ID
- BAR별 register map과 access width
- interrupt 방식: INTx, MSI, MSI-X
- DMA engine 규격, descriptor 형식, address width
- reset, power, firmware loading 절차
- 데이터시트와 errata

진행 순서:

1. 별도 테스트 장비에서 장치 열거와 configuration space를 기록한다.
2. BAR를 매핑하되 처음에는 읽기 전용 식별 레지스터만 확인한다.
3. reset과 작은 PIO/MMIO 기능부터 구현한다.
4. 인터럽트를 구현한다.
5. DMA를 작은 버퍼부터 구현하고 IOMMU를 켜서 검증한다.
6. 사용자 API, 오류 복구, 전원 관리, hot-plug를 추가한다.
7. 스트레스, 장시간, 반복 load/unload, suspend/resume를 시험한다.

실제 하드웨어에서는 잘못된 MMIO 쓰기나 DMA 주소가 시스템 또는 장치를 손상시킬 수 있으므로, 레지스터 문서 없이 추측해서 쓰지 않는다.

세부 hardware 선택 기준과 공통 완료 조건은
[`phase-3-physical-hardware.md`](common/phase-3-physical-hardware.md)에 있다.

## 단계 4 — Windows PCIe 드라이버

Linux 드라이버와 하드웨어 동작이 검증된 뒤 KMDF로 옮긴다.

학습 순서:

1. Visual Studio, WDK, KMDF 테스트 환경 구성
2. INF와 장치 ID 매칭
3. `EvtDevicePrepareHardware`에서 BAR와 interrupt resource 확인
4. MMIO 매핑과 레지스터 접근
5. interrupt object, ISR, DPC 구현
6. KMDF DMA enabler와 DMA transaction 구현
7. IOCTL 기반 사용자 프로그램 작성
8. PnP, power, surprise removal, cancel, timeout 처리
9. 테스트 서명, 격리된 테스트 PC/VM, Driver Verifier 검증

Linux와 Windows API 이름은 다르지만 다음 하드웨어 지식은 그대로 재사용된다.

- configuration space와 BAR
- register map
- interrupt acknowledge 순서
- DMA descriptor와 address width
- reset/error recovery 절차
- concurrency와 memory ordering 요구 사항

## 바로 다음 작업

단계 1-3 factorial polling까지 완료했다. repository 병합 작업을 마친 뒤
단계 1-4 IRQ를 진행한다.

1. EDU test interrupt register로 독립적인 IRQ를 발생시킨다.
2. IRQ handler에서 interrupt status를 읽고 acknowledge한다.
3. handler와 teardown을 검증한 뒤 factorial 완료를 polling에서 IRQ 방식으로
   전환한다.

## 참고 문서

- QEMU EDU 장치: <https://www.qemu.org/docs/master/specs/edu.html>
- Linux PCI 드라이버 작성: <https://docs.kernel.org/PCI/pci.html>
- Linux PCI 드라이버 API: <https://docs.kernel.org/driver-api/pci/index.html>
- Windows KMDF 하드웨어 리소스: <https://learn.microsoft.com/windows-hardware/drivers/wdf/finding-and-mapping-hardware-resources>
- Windows KMDF bus-master DMA: <https://learn.microsoft.com/windows-hardware/drivers/wdf/handling-i-o-requests-in-a-kmdf-driver-for-a-bus-master-dma-device>
