# QEMU/Linux 커널 GDB 상세 가이드

이 문서는 현재 작업 환경에 맞춘 실전용 메모다.

- 커널: Linux 6.12.101
- 심볼 파일: `<repo>/local/wsl/linux-6.12.101/vmlinux`
- QEMU GDB 서버: `127.0.0.1:1234`
- KASLR: QEMU 커널 인수의 `nokaslr`로 비활성화

## 지금 `start_kernel`에서 멈춘 상태라면

다음 명령부터 실행해보면 된다.

```gdb
list
bt
info registers
x/10i $pc
lx-version
```

부팅을 계속하려면:

```gdb
continue
```

실행 중인 커널을 다시 멈추려면 GDB 터미널에서 `Ctrl-C`를 누른다.

## GDB 시작과 QEMU 연결

```bash
cd /home/waaraawa/projects/pcie/local/wsl/linux-6.12.101
gdb ./vmlinux
```

```gdb
target remote 127.0.0.1:1234
```

현재 상태 확인:

```gdb
info target
info program
info threads
```

QEMU 원격 대상에는 일반 프로그램처럼 `run`을 사용하지 않는다. 실행 재개는 `continue`를 사용한다.

## 가장 많이 쓰는 단축 명령

| 목적 | 명령 |
|---|---|
| 실행 계속 | `continue` 또는 `c` |
| 실행 중단 | `Ctrl-C` |
| 소스 한 줄 진행, 함수 진입 | `step` 또는 `s` |
| 소스 한 줄 진행, 함수 건너뜀 | `next` 또는 `n` |
| 어셈블리 한 명령 진행, 호출 진입 | `stepi` 또는 `si` |
| 어셈블리 한 명령 진행, 호출 건너뜀 | `nexti` 또는 `ni` |
| 현재 함수가 반환할 때까지 실행 | `finish` |
| 현재 줄 이후 지정 위치까지 실행 | `until` 또는 `u` |
| 소스 보기 | `list` 또는 `l` |
| 호출 스택 | `backtrace` 또는 `bt` |
| 레지스터 전체 | `info registers` |
| 현재 명령어 | `x/i $pc` |

빈 줄에서 Enter를 누르면 직전 명령을 반복한다. `stepi`나 `nexti`를 반복할 때 편리하다.

## 브레이크포인트

### 일반 브레이크포인트

```gdb
break start_kernel
b start_kernel
b init/main.c:1000
b *0xffffffff83270a00
```

- `b 함수명`: 함수 시작에서 중단
- `b 파일:줄`: 특정 소스 줄에서 중단
- `b *주소`: 지정한 명령어 주소에서 중단

현재 위치까지만 한 번 멈춘 뒤 자동 삭제:

```gdb
tbreak 함수명
```

### 하드웨어 실행 브레이크포인트

GDB에서는 다음처럼 하드웨어 실행 브레이크포인트를 설정한다.

```gdb
hbreak *주소
```

예:

```gdb
hbreak *0xffffffff83270a00
```

함수 이름을 알고 있다면:

```gdb
hbreak start_kernel
```

QEMU GDB stub이 지원하면 하드웨어 브레이크포인트로 설정된다. 일반적인 커널 함수 중단에는 먼저 `break 함수명`을 사용하면 된다.

### 조건부 브레이크포인트

설정할 때 조건 지정:

```gdb
b 함수명 if 변수 == 값
```

기존 브레이크포인트 번호에 조건 추가:

```gdb
condition 1 변수 == 값
```

특정 횟수만큼 무시:

```gdb
ignore 1 10
```

### 브레이크포인트 관리

```gdb
info breakpoints
disable 1
enable 1
delete 1
delete
```

`delete`만 입력하면 모든 브레이크포인트 삭제 여부를 묻는다.

브레이크포인트 적중 시 자동 명령 실행:

```gdb
commands 1
silent
bt
continue
end
```

## 데이터 감시점: 값이 바뀌거나 접근될 때 중단

```gdb
watch 변수
watch *주소
rwatch 변수
awatch 변수
```

- `watch`: 값이 쓰여 변경될 때 중단
- `rwatch`: 읽을 때 중단
- `awatch`: 읽거나 쓸 때 중단

주소에 자료형을 지정하는 예:

```gdb
watch *(unsigned int *)0xffffffff81234567
watch *(unsigned long *)주소
```

하드웨어 브레이크포인트와 감시점 개수는 CPU/QEMU가 제공하는 디버그 레지스터 수로 제한된다.

## 변수와 구조체 확인

```gdb
print 변수
p 변수
p/x 변수
p/d 변수
p &변수
```

- `/x`: 16진수
- `/d`: 부호 있는 10진수
- `/u`: 부호 없는 10진수
- `/t`: 2진수
- `/c`: 문자

자료형 확인:

```gdb
whatis 변수
ptype struct task_struct
ptype /o struct pci_dev
```

구조체 포인터 확인:

```gdb
p *포인터
p 포인터->필드
p/x 포인터->필드
```

문자열 확인:

```gdb
x/s 주소
p (char *)주소
```

## 메모리 확인

기본 형식은 `x/개수형식크기 주소`다.

```gdb
x/16bx 주소
x/16hx 주소
x/16wx 주소
x/16gx 주소
x/10i $pc
x/s 주소
```

크기:

- `b`: 1바이트
- `h`: 2바이트
- `w`: 4바이트
- `g`: 8바이트

표시 형식:

- `x`: 16진수
- `d`: 10진수
- `u`: 부호 없는 10진수
- `i`: 명령어
- `s`: 문자열

예:

```gdb
x/8gx $rsp
x/20i $rip
x/64bx 0xffffffff81234567
```

## 레지스터와 어셈블리

```gdb
info registers
info registers rip rsp rbp rax rbx rcx rdx
p/x $rip
p/x $cr3
x/10i $rip
disassemble /m 함수명
disassemble /r 함수명
```

- `/m`: 소스와 어셈블리 혼합
- `/r`: 실제 명령어 바이트 포함

다음 명령어를 매번 자동 표시:

```gdb
display/i $pc
info display
undisplay 1
```

Intel 어셈블리 문법을 선호하면:

```gdb
set disassembly-flavor intel
```

## 호출 스택과 함수 프레임

```gdb
bt
bt full
frame 0
frame 1
up
down
info args
info locals
```

특정 프레임으로 이동한 뒤 `list`, `info args`, `info locals`를 사용하면 그 함수의 문맥을 볼 수 있다.

## SMP CPU와 GDB 스레드

QEMU GDB에서는 각 가상 CPU가 GDB 스레드처럼 보인다.

```gdb
info threads
thread 1
thread apply all bt
thread apply all info registers
```

`info threads` 출력에서 `*`가 현재 선택된 CPU다.

## 소스와 심볼 찾기

```gdb
list 함수명
info address 함수명
info line 함수명
info functions 이름일부
info variables 이름일부
```

정규식으로 함수 찾기:

```gdb
rbreak pci_.*probe
```

`rbreak`는 일치하는 함수가 많으면 브레이크포인트를 매우 많이 만들 수 있으므로 먼저 `info functions 정규식`으로 범위를 확인한다.

주소가 어느 소스 줄인지 확인:

```gdb
info line *주소
list *주소
```

## Linux 커널 전용 `lx-*` 명령

현재 커널의 `vmlinux-gdb.py`에서 사용할 수 있다.

```gdb
lx-version
lx-cmdline
lx-dmesg
lx-cpus
lx-ps
lx-lsmod
lx-symbols
lx-iomem
lx-ioports
lx-interruptlist
lx-mounts
lx-vmallocinfo
lx-slabinfo
```

자주 쓰는 용도:

- `lx-version`: 실행 중인 커널 버전 확인
- `lx-cmdline`: 커널 명령줄 확인
- `lx-dmesg`: 커널 로그 버퍼 출력
- `lx-cpus`: CPU 상태 확인
- `lx-ps`: 태스크 목록 확인
- `lx-lsmod`: 로드된 모듈 확인
- `lx-symbols`: 로드된 커널 모듈 심볼 다시 읽기
- `lx-iomem`: 커널 I/O 메모리 리소스 확인
- `lx-interruptlist`: 인터럽트 상태 확인

전체 명령 검색:

```gdb
apropos lx-
help lx-dmesg
```

일부 `lx-*` 명령은 커널 초기 부팅 단계에서는 필요한 자료구조가 아직 초기화되지 않아 실패할 수 있다. 부팅 후 다시 실행한다.

## PCI/PCIe 디버깅에 유용한 예

함수 존재 여부부터 확인:

```gdb
info functions pci_device_probe
info functions pci_bus_read_config
info functions pci_bus_write_config
```

대표적인 중단점 예:

```gdb
b pci_device_probe
b pci_bus_read_config_dword
b pci_bus_write_config_dword
```

브레이크포인트에 멈춘 뒤:

```gdb
bt
info args
info locals
p/x *dev
p/x dev->vendor
p/x dev->device
```

실제 인자 이름과 자료형은 커널 함수마다 다르므로 먼저 다음으로 확인한다.

```gdb
list 함수명
ptype 함수명
```

PCI 장치 열거가 끝난 뒤에는 다음 명령도 유용하다.

```gdb
lx-iomem
lx-interruptlist
lx-dmesg
```

## TUI 화면

```gdb
layout src
layout asm
layout split
layout regs
```

- `Ctrl-x a`: TUI 켜기/끄기
- `Ctrl-l`: 화면 다시 그리기
- `focus cmd`: 명령 창에 포커스
- `focus src`: 소스 창에 포커스

터미널 화면이 깨지면 `Ctrl-l` 또는 `tui disable`을 사용한다.

## 명령 도움말

```gdb
help break
help x
help watch
help info registers
apropos breakpoint
```

명령을 일부만 기억할 때 `apropos 검색어`가 유용하다.

## 주의가 필요한 명령

다음 명령은 실행 상태나 메모리를 바꾸므로 의도를 확인하고 사용한다.

```gdb
set variable 변수 = 값
set $rax = 값
set *(unsigned int *)주소 = 값
jump 위치
return
```

- `set`: 실행 중인 커널의 변수, 레지스터 또는 메모리를 변경할 수 있다.
- `jump`: 정상적인 제어 흐름을 건너뛴다.
- `return`: 현재 함수를 강제로 반환시킨다.

원격 커널 디버깅 중에는 `run`, `start`, `kill`을 사용하지 않는 편이 안전하다.

## 종료

실행 중이면 먼저 `Ctrl-C`로 멈춘다.

GDB 연결만 끊으려면:

```gdb
detach
quit
```

`detach`하면 일반적으로 QEMU 게스트 실행이 재개된다. 커널을 멈춘 상태로 계속 조사하려면 연결을 유지한다.

QEMU 자체를 종료하려면 QEMU 터미널에서 `Ctrl-a`를 눌렀다 놓고 `x`를 누른다.
