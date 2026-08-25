# Cross-Host Validation Matrix

## 상태 표시

- **Verified**: 해당 host에서 실행 결과와 evidence가 문서화됨
- **User-verified**: 사용자가 실제 실행 결과를 확인했고 대화/작업 기록에 남음
- **Static recheck**: 현재 host에서 source, 입력 파일 또는 archive만 재검사함
- **Pending**: 아직 실행하거나 입증하지 않음

Intel Mac evidence는
[`hosts/intel-macos.md`](hosts/intel-macos.md), Windows/WSL evidence는
[`hosts/windows-wsl.md`](hosts/windows-wsl.md)를 기준으로 한다.

## 환경과 driver 상태

| 기능 | Intel macOS host | Windows/WSL host | Cross-host 상태 |
| --- | --- | --- | --- |
| Host inventory | Verified (2026-08-05) | Partial: WSL/QEMU 확인, Windows 정보 미기록 | Pending |
| QEMU Linux boot | Verified twice, Ubuntu guest/HVF | User-verified, custom Linux 6.12.101 | Verified per host |
| QEMU EDU discovery `1234:11e8` | Verified | User-verified at `0000:00:03.0` | Verified per host |
| External module build/load/unload | Verified with `phase0_sanity` | User-verified with canonical `edu_pci` | Environment gate only; module이 다름 |
| Matching symbol-bearing `vmlinux` | Pending | Verified for Linux 6.12.101 | Pending |
| QEMU remote-GDB breakpoint | Pending | User-verified at `start_kernel` | Pending |
| Canonical `edu_pci` `probe()`/`remove()` | Pending | User-verified | Pending |
| BAR0 ownership/MMIO mapping | Pending | User-verified | Pending |
| Identification/liveness | Pending | User-verified | Pending |
| Factorial polling | Pending | User-verified: `5! = 120` | Pending |
| INTx/MSI | Pending | Pending | Pending |
| Bidirectional DMA | Pending | Pending | Pending |
| User-space validation | Pending | Pending | Pending |
| 2026-08-25 module/initramfs input integrity | Not run | Static recheck passed | Host-local only |

## Cross-host 완료 규칙

기능을 cross-host 완료로 바꾸려면 다음 조건을 모두 만족해야 한다.

1. 두 host가 `driver/edu/`의 같은 source revision을 사용한다.
2. 각 guest kernel에 맞춰 module을 별도로 build한다.
3. `tests/guest/`의 같은 test와 `tests/expected/`의 같은 정상 조건을 사용한다.
4. host별 문서에 실행 명령, 결과, log 위치와 알려진 제한을 기록한다.
5. 단순 smoke-test module 결과를 EDU 기능 검증으로 확대하지 않는다.

현재 cross-host 환경 준비 evidence는 있지만 canonical EDU 기능은 WSL에서만
진행됐다. Intel Mac에서 같은 source와 test를 실행하기 전에는 EDU 기능 행을
cross-host 완료로 표시하지 않는다.
