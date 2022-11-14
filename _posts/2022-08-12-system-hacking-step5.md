---
layout: post
title:  "System Hackig Step 5"
summary: Calling Convention
author: TouBVa
date: '2022-08-12 21:25:23 +09'
category: system_hacking_basic
thumbnail: /assets/img/posts/syshack5/Untitled.jpeg
keywords: System Hacking, Calling Convention, SYSV, cdecl
usemathjax: true
permalink: /blog/system-hacking-step5/
---

# STAGE 5

---

1. 함수 호출 규약의 정의와 종류 알기
2. `cdecl` , `SYSV` 호출 규약이 무엇인지 알기
3. 다음 코스의 스택 버퍼 오버플로우의 위험성 알기

---

# 1. Calling Convention

- 함수 호출 규약: 함수의 호출 및 반환에 대한 약속
- 한 함수 A에서 다른 함수 B를 호출하는 경우,
    - Caller(호출자): A
        - Caller의 Stack Frame, Return Address를 저장한다.
        - Caller는 Callee가 요구하는 인자를 전달해 줘야 한다.
        - Caller는 Callee의 실행이 종료될 때의 리턴값을 전달받아야 한다.
    - Callee(피호출자): B
- 함수 호출 규약 적용의 주체: **컴파일러**
    - 그러나 컴파일러를 사용하지 않고 어셈블리 코드를 만들거나, 어셈블리 코드를 이해하려면 Calling Convention을 알아야만 한다.
        
        → 시스템 해킹의 기본
        

---

# 2. 함수 호출 규약의 종류

- 컴파일러는 지원하는 호출 규약 중 CPU 아키텍처에 가장 적합한 것을 선핵한다.
    - x86(32bit): **스택으로 인자 전달**; 레지스터로 Callee의 인자를 전달하기에는 레지스터 수가 너무 적음.
    - x86-64(64bit): **레지스터로 인자 전달**(**적은 수**라면), 인자가 **너무 많다면 스택** 사용. 레지스터 수가 충분한 편.
- 그러나 사용하는 컴파일러의 종류가 달라질 경우, 동일 아키텍처 상에서라도 다른 호출 규약이 적용될 수 있다.
    - C언어 컴파일 시:
        - Windows-MSVC
            - x86-64에서 MSx64 calling convention 사용
        - Linux-gcc
            - x86-64에서 SYSTEM V calling convention 사용
- 대표적인 Calling Convention의 종류:
    - x86 architecture:
        - cdecl
        - stdcall
        - fastcall
        - thiscall
    - x86-64 architecture:
        - SYSTEM V AMD64 ABI의 Calling Convention
        - MS ABI의 Calling Convention

---

# 3. x86호출 규약: cdecl

## 들어가기 전에:

- x86아키텍처 → 적은 레지스터 → 레지스터에 여유 없음 → 스택을 통해 Caller가 Callee에게 인자 전달
    - 인자 전달에 사용된 스택은 Caller가 정리한다.
    - 스택을 통해 인자를 전달할 때, 마지막 인자부터 첫 번째 인자까지 거꾸로 스택에 push
        - 당연하다; 스택은 LIFO구조로 가장 위에서부터 pop 하니까, 원하는 순서대로 인자를 전달하고 싶다면 인자를 스택에 그 역순으로 push 해줘야 컴퓨터가 정순으로 읽을 수 있다.

## 실습

cdecl calling convention을 직접 확인해 보기 위해 리눅스 환경에서 gcc를 이용해 c언어를 어셈블리 소스 파일로 컴파일해 보았다.

컴파일한 코드는 단순히 Caller에서 Callee에게 1, 2를 인자로 넘겨주는 동작을 하는 코드였다.

컴파일 결과로 도출된 어셈블리어는 아래와 같았다.

![Untitled](/assets/img/posts/syshack5/Untitled.jpeg)

Callee 함수의 어셈블리 코드와 Caller 함수의 어셈블리 코드를 확인할 수 있었다. Caller 내부에서 Callee를 호출했으므로 해당 동작에 집중해 보자.

Caller에서 Callee에게 인자를 전달할 때, 코드 상에서는 Callee(1, 2)로 전달했다. 그러나 어셈블리 코드 상에서는 arg2인 2가 먼저 push되고, arg1인 1이 나중에 push되는 것을 볼 수 있다. 즉, x86 architecture calling convention의 주요 특징인 **‘Callee의 인자는 Caller가 스택에 역순으로 전달한다’**가 두드러졌다.

또한 Callee를 호출하고, Callee가 리턴된 이후 돌아온 코드 플로우에서 Caller의 행동도 눈여겨볼 만하다. esp에 8을 더함으로써(스택의 크기를 메모리 주소 8만큼 줄인다) **스택을 정리하는 행위**를 확인할 수 있기 때문이다. 인자를 두 개 전달했으므로 각각 int 형 4byte씩 8byte가 늘어나 있던 스택을 Callee를 호출하기 직전의 크기로 돌려놓은 것이다.

스택 정리와 관련해, Callee의 행동도 확인해 두자. Callee는 스택에 아무런 조작도 가하지 않고 리턴한다. 즉, x86 architecture의 calling convention 중 **cdecl calling convention은 Callee가 아닌 Caller가 스택을 정리한다는 점을 확인할 수 있다.**

---

# 4. x86-64 호출 규약: SYSV

- 리눅스는 SYSTEM V(SYSV) Application Binary Interface(ABI)를 기반으로 만들어졌다.
    - SYSV ABI란? [[자세한 설명]](https://wiki.osdev.org/System_V_ABI)
        - A set of specifications that detail [calling conventions](https://wiki.osdev.org/Calling_Conventions), [object file formats](https://wiki.osdev.org/Object_Files), [executable file formats](https://wiki.osdev.org/Executable_Formats), dynamic linking semantics, and much more for systems that complies with the *X/Open Common Application Environment Specification* and the *System V Interface Definition.*
        - ELF 포맷, 링킹 방법, 함수 호출 규약 등의 내용을 가지고 있음
        - 그 외 위에 명시된 Specification/Definition을 이용해 컴파일되는 시스템 전용 정보를 가지고 있음
        - 즉, 컴파일과 매우 밀접한 연관 → 리눅스의 바이너리 파일들은 무조건 SYSV ABI와 연관되어 있음
            
            ![실제로 file 명령어를 이용해 리눅스의 바이너리 파일들의 종류(타입)을 확인해 본 결과. SYSV에 명시된 규약을 따라 컴파일된 바이너리임을 알 수 있다.](/assets/img/posts/syshack5/Untitled%201.jpeg)
            
            실제로 file 명령어를 이용해 리눅스의 바이너리 파일들의 종류(타입)을 확인해 본 결과. SYSV에 명시된 규약을 따라 컴파일된 바이너리임을 알 수 있다.
            
- SYSV에서 정의된 함수 호출 규약:
    1. 6개의 인자를 RDI, RSI, RDX, RCX, R8, R9에 순서대로 저장해 전달한다.
        
        *64bit이므로 레지스터 수가 충분해서 웬만큼 감당 가능한 수의 인자면 레지스터에 담아 전달한댔다!*
        
        *즉, 더 많은 인자를 전달해야 할 때는 스택을 추가로 쓴다.*
        
    2. **Caller에서** 인자 전달에 사용된 **스택을 정리**한다.
    3. 함수의 반환 값은 RAX로 전달한다. 만일 syscall callee라면 해당 callee의 종류를 RAX로 지정해 call한다.

SYSV Calling Convention을 gdb로 자세히 알아보자.

## GDB로 SYSV Calling Convention 알아보기

### 코드 컴파일

아래와 같은 코드를 컴파일하여 실행해 보자.

![Untitled](/assets/img/posts/syshack5/Untitled%202.jpeg)

컴파일 옵션은 아래와 같았다.

```bash
gcc -fno-asynchronous-unwind-tables -masm=intel \
-fno-omit-frame-pointer -o sysv sysv.c -fno-pic -O0
```

### 인자 전달

이후 sysv에 gdb를 붙여 실행하고 중단점을 caller에 설정해(`b caller`) 중단점까지 실행한다.(`r`)

실행 결과 아래와 같은 Context를 확인할 수 있었다.

![Untitled](/assets/img/posts/syshack5/Untitled%203.jpeg)

Caller는 Callee에게 전달할 인자를 거꾸로 저장한다. 혹시라도 인자를 6개 초과하여 줄 때를 대비해, 즉 스택을 사용할 때를 대비해 전달할 인자를 거꾸로 저장하는 것 같았다.(추측)

`<caller+10>`~ `<caller+37>` 에서는 인자를 레지스터에 저장하지만, 7번째 인자를 저장하는 `<caller+8>` 에서는 스택에 push하는 것을 확인할 수 있었다.

이제 Callee 함수를 호출하기 전까지 실행해 보자. `b *caller+47` 로 중단점을 걸고 `c` 명령어로 해당 중단점까지 실행하면 된다.

![Untitled](/assets/img/posts/syshack5/Untitled%204.jpeg)

위의 REGISTER Context를 확인하면 rdi, rsi, rdx, rcx, r8, r9의 레지스터에 전달하고자 하는 인자가 들어가 있고, RSP즉 스택의 맨 꼭대기에 레지스터에 들어가지 못한 인자가 담겨 있음을 볼 수 있다. 

(그러고 보니, gdb pwndbg의 register context에 나열된 레지스터 중 앞에 *가 붙은 건 함수의 인자, 스택과 관련된 레지스터였구나!)

### 반환 주소 & 스택 프레임 저장

이제 si 명령어로 Callee의 내부로 들어가 보자.

![Untitled](/assets/img/posts/syshack5/Untitled%205.jpeg)

무엇보다 눈에 띄는 건 STACK context에서 확인할 수 있는 스택 구조이다. 

- `caller+52`, 즉 Callee가 리턴한 후 이어서 수행되어야 할 인스트럭션의 주소가 스택 꼭대기에 저장되어 있는 형태.
    - [이전](https://toubva.github.io/blog/system-hacking-step2-2/#/)에 공부했던 것처럼 Callee 함수의 스택 프레임이 생성되기 직전에 Callee가 리턴되고 코드 플로우가 이어져야 할 인스트럭션의 주소가 스택에 push된다는 것을 상기할 수 있다.
- Callee 함수의 prologue.
    - `push rbp` 를 통해 Caller의 rbp를 저장하고, 스택 꼭대기(rsp)의 주소를 스택 밑바닥(rbp)로 설정해 현재 함수의 스택 프레임을 만드는 모습을 볼 수 있다.
    - 이후 Callee가 리턴되면 저장되었던 Caller의 rbp를 꺼내고, 이어서 수행될 인스트럭션의 주소를 꺼내면서 Caller의 스택 프레임으로 돌아갈 수 있다.
        
        +) rbp는 스택 프레임의 밑바닥을 가리키는 포인터이기 때문에 SFP(Stack Frame Pointer)라고도 부른다.
        
        ![push rbp가 수행되기 직전의 스택 상태. 아직 Caller의 rbp가 저장되지 않았다.](/assets/img/posts/syshack5/Untitled%206.jpeg)
        
        push rbp가 수행되기 직전의 스택 상태. 아직 Caller의 rbp가 저장되지 않았다.
        
        ![push rbp가 수행된 직후의 스택 상태. rsp에 현재 rbp의 값이 저장되어 있는 것을 볼 수 있다.](/assets/img/posts/syshack5/Untitled%207.jpeg)
        
        push rbp가 수행된 직후의 스택 상태. rsp에 현재 rbp의 값이 저장되어 있는 것을 볼 수 있다.
        

### 새로운 스택 프레임 할당

`push rbp` 다음 인스트럭션인 `push rbp, rsp` 를 실행해 보자. 즉, rsp 값을 rbp에 넣음으로써 **Callee를 위한 새로운 스택 프레임을 할당**하는 것이다.

![rsp와 rbp가 일치하는 상황인 것을 확인할 수 있다. 이렇게 새로운 스택 프레임의 기반이 완성된다!](/assets/img/posts/syshack5/Untitled%208.jpeg)

rsp와 rbp가 일치하는 상황인 것을 확인할 수 있다. 이렇게 새로운 스택 프레임의 기반이 완성된다!

만일 Callee에서 지역 변수를 선언했다면 스택에 지역 변수를 저장해야 하기 때문에 rsp의 값을 뺄 텐데, 지역 변수를 선언하지 않기 때문에 아래 인스트럭션에서 볼 수 있듯 rsp의 값을 빼지 않고 그대로 진행된다.

![Untitled](/assets/img/posts/syshack5/Untitled%209.jpeg)

**어? 그런데 이상한 점이 있다. Callee 함수를 다시 보자.**

![Untitled](/assets/img/posts/syshack5/Untitled%202.jpeg)

**Callee 함수는 ret이라는 지역 변수를 선언한다! 그런데 Callee 함수의 인스트럭션을 보면 rsp에는 변동이 없다.**

**그 이유는 gcc의 컴파일 방식 때문이었다.** 어떤 **지역 변수가 오로지 반환 값을 저장하는 용도로만** 사용될 경우, gcc는 **스택을 할당하지 않으며 rax를 직접 사용**한다는 것.

효율적인 자원 사용을 위한 프로그래머들의 노력을 정말 존경하지만, 그로 인해 발생하는 이런 예외들을 보면 머리를 쥐어뜯게 된다(…)

### 반환값 전달

![Untitled](/assets/img/posts/syshack5/Untitled%2010.jpeg)

Callee 함수의 전체 인스트럭션을 살펴 보자. 계속해서 주어진 인자들을 더하다가, 마지막 `<callee+79>` ~ `<callee+91>` 에서 **리턴할 값을 rax에 저장하고, 함수를 마무리**짓고 있다. 즉, **함수의 Epilogue를 확인**할 수 있다. 이제 `<callee+91>`, 즉 함수를 리턴하는 인스트럭션에 중단점을 걸고 rax를 확인해 보자.

![Untitled](/assets/img/posts/syshack5/Untitled%2011.jpeg)

Callee에 전달했던 7개 인자의 합을 확인할 수 있다.

### 반환

반환은 저장해뒀던 Caller의 스택 프레임과 반환 인스트럭션 주소를 꺼내는 과정이다. 

![Untitled](/assets/img/posts/syshack5/Untitled%2012.jpeg)

Callee 함수가 지역 변수를 선언하지 않았기 때문에(리턴값을 담는 변수 제외) 스택 프레임을 만들지 않았고, 따라서 단순히 pop rbp로만 스택 프레임을 꺼내고 끝나는 것을 확인할 수 있다. 그러나, 일반적인 경우-즉, 지역 변수를 선언하는 경우에는 스택 프레임이 생성되었기 때문에 leave로 스택 프레임을 꺼낸다는 점을 꼭 염두에 두자.

- leave는 mov rsp, rbp | pop rbp 를 합쳐 둔 명령어이다.
- 즉, 확보된 스택 공간을 버리고 이전 스택 프레임의 rbp 꺼내 오는 명령어이다.
- 이를 다시 말하면 현재 스택 프레임을 버리고 이전 스택 프레임을 꺼내는 것이다.

스택 프레임을 꺼낸 이후에는 ret으로 Caller에게 복귀한다. 복귀할 때 변화하는 것은 앞서 설명했듯 rbp와 rip이므로 ret 인스트럭션을 수행한 직후 그 둘을 살펴보았다.

![rbp가 Caller의 rbp로 바뀐 모습.](/assets/img/posts/syshack5/Untitled%2013.jpeg)

rbp가 Caller의 rbp로 바뀐 모습.

![rip가 리턴 주소로 설정되어 있는 모습.](/assets/img/posts/syshack5/Untitled%2014.jpeg)

rip가 리턴 주소로 설정되어 있는 모습.

# 5. 부록-함수 호출 규약

**x86 함수 호출 규약**

| 함수호출규약 | 사용 컴파일러 | 인자 전달 방식 | 스택 정리 | 적용 |
| --- | --- | --- | --- | --- |
| stdcall | MSVC | Stack | Callee | WINAPI |
| cdecl | GCC, MSVC | Stack | Caller | 일반 함수 |
| fastcall | MSVC | ECX, EDX | Callee | 최적화된 함수 |
| thiscall | MSVC | ECX(인스턴스),Stack(인자) | Callee | 클래스의 함수 |

**x86-64 함수 호출 규약**

| 함수호출규약 | 사용 컴파일러 | 인자 전달 방식 | 스택 정리 | 적용 |
| --- | --- | --- | --- | --- |
| MS ABI | MSVC | RCX, RDX, R8, R9 | Caller | 일반 함수,Windows Syscall |
| System ABI | GCC | RDI, RSI, RDX, RCX, R8, R9, XMM0–7 | Caller | 일반 함수 |