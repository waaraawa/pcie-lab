# GDB 빠른 치트시트 — QEMU/Linux 커널

접속: `gdb ./vmlinux` → `target remote 127.0.0.1:1234` · 실행 중단: `Ctrl-C` · 원격 대상에서는 `run` 대신 `continue`

## 실행·스테핑

| 명령 | 설명 | 명령 | 설명 |
|---|---|---|---|
| `c` | 계속 실행 | `Ctrl-C` | 실행 중단 |
| `s` | 소스 한 줄, 함수 진입 | `n` | 소스 한 줄, 함수 건너뜀 |
| `si` | 명령어 한 개, 호출 진입 | `ni` | 명령어 한 개, 호출 건너뜀 |
| `finish` | 현재 함수 반환까지 | `until` | 현재 루프/줄을 벗어날 때까지 |
| `jump 위치` | 실행 위치 강제 변경 ⚠ | `return` | 현재 함수 강제 반환 ⚠ |

## 브레이크포인트·감시점

| 명령 | 설명 | 명령 | 설명 |
|---|---|---|---|
| `b 함수` | 함수에 중단점 | `b 파일.c:줄` | 소스 줄에 중단점 |
| `b *주소` | 주소에 중단점 | `hbreak *주소` | 하드웨어 실행 중단점 |
| `tb 함수` | 한 번만 중단 | `b 함수 if 조건` | 조건부 중단점 |
| `watch 변수` | 값 변경 시 중단 | `rwatch 변수` | 읽을 때 중단 |
| `awatch 변수` | 읽기/쓰기 시 중단 | `info b` | 중단점 목록 |
| `disable N` | N번 비활성화 | `enable N` | N번 활성화 |
| `delete N` | N번 삭제 | `condition N 조건` | N번에 조건 지정 |
| `ignore N 횟수` | N번 적중 무시 | `commands N` | 적중 시 자동 명령 |

## 소스·스택·변수

| 명령 | 설명 | 명령 | 설명 |
|---|---|---|---|
| `l` | 현재 소스 | `l 함수` | 함수 소스 |
| `bt` | 호출 스택 | `bt full` | 스택+지역 변수 |
| `f N` | N번 프레임 선택 | `up` / `down` | 호출 프레임 이동 |
| `info args` | 함수 인자 | `info locals` | 지역 변수 |
| `p 변수` | 값 출력 | `p/x 변수` | 16진수 출력 |
| `p *포인터` | 구조체 역참조 | `p 포인터->필드` | 구조체 필드 |
| `whatis 식` | 간단한 자료형 | `ptype 구조체` | 상세 자료형 |
| `info address 심볼` | 심볼 주소 | `info line *주소` | 주소의 소스 줄 |
| `info functions 패턴` | 함수 검색 | `rbreak 정규식` | 정규식 함수 중단점 |

## 메모리·레지스터·어셈블리

| 명령 | 설명 | 명령 | 설명 |
|---|---|---|---|
| `i r` | 레지스터 전체 | `p/x $rip` | RIP 출력 |
| `x/i $pc` | 현재 명령어 | `x/10i $pc` | 명령어 10개 |
| `x/16bx 주소` | 1바이트×16 | `x/8gx 주소` | 8바이트×8 |
| `x/s 주소` | 문자열 | `x/8gx $rsp` | 스택 메모리 |
| `disas 함수` | 함수 역어셈블 | `disas /r 함수` | 명령 바이트 포함 |
| `display/i $pc` | 매번 다음 명령 표시 | `undisplay N` | 자동 표시 제거 |
| `set disassembly-flavor intel` | Intel 문법 | `set $reg=값` | 레지스터 변경 ⚠ |

`x/NFU 주소`: N=개수 · F=`x`16진수/`d`10진수/`i`명령어/`s`문자열 · U=`b`1/`h`2/`w`4/`g`8바이트

## CPU·커널 전용

| 명령 | 설명 | 명령 | 설명 |
|---|---|---|---|
| `info threads` | QEMU 가상 CPU 목록 | `thread N` | CPU 선택 |
| `thread apply all bt` | 모든 CPU 스택 | `lx-cpus` | 커널 CPU 상태 |
| `lx-version` | 커널 버전 | `lx-cmdline` | 커널 명령줄 |
| `lx-dmesg` | 커널 로그 | `lx-ps` | 태스크 목록 |
| `lx-lsmod` | 모듈 목록 | `lx-symbols` | 모듈 심볼 로드 |
| `lx-iomem` | I/O 메모리 | `lx-ioports` | I/O 포트 |
| `lx-interruptlist` | 인터럽트 | `apropos lx-` | 모든 `lx-*` 검색 |

## 화면·도움말·종료

| 명령 | 설명 | 명령 | 설명 |
|---|---|---|---|
| `layout src` | 소스 TUI | `layout asm` | 어셈블리 TUI |
| `layout split` | 소스+어셈블리 | `Ctrl-x a` | TUI 켜기/끄기 |
| `Ctrl-l` | 화면 다시 그리기 | `help 명령` | 명령 도움말 |
| `apropos 단어` | 명령 검색 | `detach` | 연결 해제·실행 재개 |
| `quit` | GDB 종료 | QEMU `Ctrl-a`, `x` | QEMU 종료 |

## 현재 실습 최소 흐름

```gdb
b start_kernel
c
bt
i r
x/10i $pc
lx-version
c
```

상세 설명과 PCI/PCIe 예제:
[`gdb-kernel-guide.md`](gdb-kernel-guide.md)
