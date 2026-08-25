# Windows/WSL Host Scripts

현재 Windows/WSL Phase 1 workflow는 `phase1/`에 있다. 모든 명령은 repository
root에서 실행한다.

- `phase1/run-qemu-edu.sh`: Linux 6.12.101, BusyBox initramfs와 QEMU EDU 실행
- `phase1/update-initramfs.sh`: canonical EDU module 복사·재패키징·동일성 검사
- `phase1/refresh-compile-commands.sh`: VS Code/clangd source navigation database
  재생성

입력만 검사할 때:

```bash
scripts/wsl/phase1/run-qemu-edu.sh --check
scripts/wsl/phase1/update-initramfs.sh --check
```

기본 host-local 경로는 `local/wsl/`이며 Git에 포함하지 않는다. 다른 위치를
사용하려면 각 script의 `PCIE_*` environment override를 사용한다. 전체 재현
절차와 정상 결과는 [`../../docs/hosts/windows-wsl.md`](../../docs/hosts/windows-wsl.md)에
있다.
