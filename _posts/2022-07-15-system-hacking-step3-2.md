---
layout: post
title:  "System Hackig Step 3-2"
summary: pwntools 사용법과 BOF 실습
author: TouBVa
date: '2022-07-15 18:25:23 +09'
category: dreamhack_system_hacking
thumbnail: /assets/img/posts/syshack3-2/Untitled%206.jpeg
keywords: System Hacking, pwntools, BOF
usemathjax: true
permalink: /blog/dreamhack_system_hacking/step3-2
---


* TOC
{:toc}

<br>

# STAGE 3-2

# Tool: PwnTools

- 파이썬을 이용해 익스플로잇을 수행할 때, 자주 사용하는 함수들이 있음. 예시) 리틀 엔디언 ↔ 빅 엔디언을 수행하는 함수
- 이런 함수들을 미리 구현해 둔 모듈을 만듦 → ‘pwntools’의 탄생
- 익스플로잇 대부분이 pwntools를 이용해 제작되고 공유되므로 반드시 알아 둬야 함.

설치 방법은 생략한다. 인터넷에 검색하면 나오기 때문에…

---

# PwnTools API 사용법

공식 매뉴얼: [여기!](http://docs.pwntools.com/en/latest/)

요즘은 매뉴얼화가 잘 되어 있기 때문에 어떤 모듈을 다운받으면 그 모듈의 매뉴얼부터 얼추 숙지해 두는 걸 추천한다. 보통은 영어로 되어 있으므로 파파고를 쓰거나, 영어 실력을 늘려서 언어 장벽을 낮추는 게 좋다. 

여기에서는 자주 사용되는 몇몇 함수만 간략히 소개한다.

## 1. process & remote

`process` 를 이용해 전달할 수 있는 함수는 `remote` 를 통해서도 전달 및 실행할 수 있다!

- process [[자세한 설명](http://docs.pwntools.com/en/latest/tubes/processes.html)]
    - 로컬 바이너리를 대상으로 익스플로잇을 테스트하고 디버깅할 때 사용한다.
    - 새로운 프로세스를 새 스레드에서 실행하면서, 커뮤니케이션이 가능한 튜브로 래핑해 둔다.
    - 즉, process 함수가 실행된 원래 함수와는 별개의 스레드에서 원하는 프로세스를 실행하면서 원래 함수에서 전달하려는 인수나 실행된 프로세스의 결과 등을 주고받을 수 있게 해준다.
    - 사용예:
        
        ```python
        from pwn import *
        p=process('./test')
        p.sendline(b"print('this is a shellcode')")
        b''=p.recv(timeout=0.01)
        .
        .
        .
        ```
        
- remote [[자세한 설명](http://docs.pwntools.com/en/latest/tubes/sockets.html?highlight=remote#pwnlib.tubes.remote.remote)]
    - 원격 서버를 대상으로 익스플로잇을 실제로 실행할 때 사용한다.
    - TCP나 UDP 연결을 만들어서 통신하게 해 주고, IPv4와 IPc6를 모두 지원한다.
    - 사용예:
        
        ```python
        from pwn import 
        r = remote('example.com', 30909) # 'example.com'의 30909 포트에서 서비스 중인 프로세스를 대상으로 익스 수행
        r.send(b'GET /\r\n\r\n')
        r.recvn(4)
        ```
        

---

## 2. send

- 데이터를 프로세스에 전송하기 위해 사용한다.
- 여러 variation이 있고, 각자 상황에 맞게 사용할 수 있다. [[자세한 설명](http://docs.pwntools.com/en/latest/tubes.html?highlight=send#pwnlib.tubes.tube.tube.send)]
- 사용예:
    
    ```python
    from pwn import *
    p = process('./test')
    
    p.send('A') # ./test에 'A'를 입력
    p.sendline('A') # 'A'+'\n'
    p.sendafter('hello', 'A') # ./test가 'hello'를 출력하면 'A'를 입력. Data로는 무조건 패킹된(스트링) 데이터가 들어가야 한다.
    p.sendlineafter('hello', 'A') # ./test가 'hello'를 출력하면 'A'+'\n'을 입력
    ```
    

---

## 3. recv

- 프로세스에서 데이터를 받기 위해 사용한다.
- 여러 variation이 있고, 각자 상황에 맞게 사용할 수 있다. (`pwnlib.tubes.process` 의 하위에 정의된 메소드이다)
    - `recv()` 와 `recvn()` 의 차이점을 주의해야 한다!
        - `recv(m)` : 최대 m 바이트를 받는 것이기 때문에, 그만큼을 받지 못해도 에러를 발생시키지 않는다.
        - `recvn(m)` : 정확히 m 바이트의 데이터를 받는 것이기 때문에 조건을 만족시키는 데이터를 받지 못하면 계속해서 기다린다.
- 사용예:
    
    ```python
    from pwn import *
    p =  process('./test')
    
    data = p.recv(1024) # p가 출력하는 데이터를 최대 1024 바이트까지 받을 수 있다.
    data = p.recvline() # store data printed out from p until '\n' comes in
    data = p.recvn(5) # get exactly 5 bytes of data
    data = p.recvuntil('hello') # store data printed out from p until 'hello' comes in
    data = p.recvall() # store data printed out from p until p is terminated 
    ```
    

---

## 4. packing & unpacking

- 원래 기능은 hex ↔ string
- 부가적 기능으로 엔디언을 바꾸는 데 사용한다.
- 패킹(hex → string)을 위한 함수: `p32()` , `p64()`
    - 사용예: `p32(int, endian='big/little')`
        
        ```python
        from pwn import *
        
        s32=0x41424344
        # p64 사용법은 동일하므로 생략
        
        print(p32(s32)) # 결과: b'DCBA'
        print(p32(s32, endian='big')) # 파라미터 추가 명시로 엔디언 변경 가능. 결과: b'ABCD'
        ```
        
- 언패킹(string → hex)을 위한 함수: `u32()` , `u64()`
    - 사용예: `u32((uint32_t*)addr, endian=’big/little’)` , 리턴값은 int 형식.
        
        ```python
        from pwn import *
        
        s32="ABCD"
        # s64 사용법은 동일하므로 생략
        
        print(hex(u32(s32))) # 결과: 0x44434241
        print(hex(u32(s32, endian='big'))) # 결과: 0x41424344
        ```
        

---

## 5. interactive

- 셸을 획득했거나, 익스플로잇의 특정 상황에 직접 입력을 주면서 출력을 확인하고 싶을 때 사용하는 함수.
    - 쌍방 세션을 생성해 준다.
    - 실제로 호출하면 터미널이 뜨게 되고, 거기에서 입력 및 출력이 가능하다.
- pwnlib.tubes.ssh.ssh.interactive이고, process나 remote를 사용하면서 그 하위 메소드로 이용할 수 있다.
- 사용예:
    
    ```python
    from pwn import *
    p = process('./test')
    p.interactive()
    ```
    

---

## 6. ELF

- [앞서 보았듯](https://toubva.github.io/blog/system-hacking-step3-1/), ELF 파일의 헤더에는 각종 정보가 기록되어 있고, 이들은 높은 확률로 익스플로잇에 사용할 수 있다.
- pwntools가 이런 정보들을 쉽게 참조할 수 있도록 보조해 준다.
- [[자세한 메소드와 사용예](http://docs.pwntools.com/en/latest/elf/elf.html?highlight=ELF)]
- 사용예:
    
    ```python
    from pwn import *
    e = ELF('./test')
    
    # 이하 ELF 메소드에 정의된 하위 메소드들 사용 가능
    ```
    

---

## 7. context.log

- 작성한 익스플로잇도 디버깅이 필요한데, 이때 사용하는 로깅 기능
- 로그 레벨은 `context.log_level` 에 특정 값을 할당함으로써 조절 가능하다
- 사용예
    
    ```python
    from pwn imort *
    context.log_level = 'error' # 에러만 출력
    context.log_level = 'debug' # 대상 프로세스와 익스플로잇 간에 오가는 모든 데이터를 화면에 출력
    context.log_level = 'info' # 비교적 중요한 정보들만 추려서 출력
    ```
    

---

## 8. context.arch

- architecture의 준말
- 즉, 공격 대상의 아키텍처 정보를 프로그래머가 원하는 대로 지정할 수 있게 함으로써 호환성을 높임
- 사용예
    
    ```python
    from pwn import *
    context.arch = "amd64" # x86-64
    context.arch = "i386"
    context.arch = "arm"
    ```
    

---

## 9. shellcraft

- 셸코드를 작성해 익스플로잇을 수행하는 과정에서 상황에 따라 여러 제약 조건이 존재할 수 있다. 따라서, 이를 맞추기 위해 직접 셸코드를 작성해야 할 때가 있다.
- pwntools에는 자주 사용되는 셸코드들이 저장되어 있어서 별다른 제약 조건이 없다면 꺼내 쓰면 된다.
- amd64(x86-64) 타겟으로 생성할 수 있는 셸코드 목록: [여기](https://docs.pwntools.com/en/stable/shellcraft/amd64.html)
- 사용예:
    
    ```python
    from pwm import *
    context.arch='amd64' # 아키텍처 지정을 하지 않으면 이후 shellcraft.amd64.{} 식으로 명시해 줘야 한다.
    
    code=shellcraft.sh()
    print(code)
    ```
    

---

## 10. asm

- pwntools에서 제공하는 어셈블 기능
- 기계어로 어셈블하는 것이므로, 대상 아키텍처가 중요하다. 따라서, 아키텍처를 꼭 지정해 주고 시작한다.
- 사용예:
    
    ```python
    from pwn import *
    context.arch = 'amd64'
    
    code=shellcraft.sh()
    code=asm(code) # 셸을 실행하는 셸 코드를 기계어로 어셈블
    print(code)
    ```
    
    결과:
    
    ![Untitled](/assets/img/posts/syshack3-2/Untitled.jpeg)
    

---

# pwntools 실습

아래의 코드에서 get_shell() 함수를 실행시키는 것이 목적이다. (시스템 해킹의 목적은 셸을 딴 후 루트 권한을 탈취하는 것이기 때문이다)

![Untitled](/assets/img/posts/syshack3-2/Untitled%201.jpeg)

먼저 이전에 배웠던 내용을 다시 돌아볼 필요가 있다. 

어떤 함수의 스택 프레임이 생성될 때 직전까지 rip가 위치해 있던 함수의 스택 프레임과의 관계는 아래와 같다.

![Untitled](/assets/img/posts/syshack3-2/Untitled%202.jpeg)

또한 리눅스의 프로세스에게 할당되는 메모리 구조는 아래와 같다.

![Untitled](/assets/img/posts/syshack3-2/Untitled%203.jpeg)

이제 배운 내용을 기반으로 하여 주어진 문제를 어떻게 해결할지 계획을 세워 보자.

> **단계**
> 
> 1. get_shell 함수의 시작 주소를 알아낸다.
> 2. 유저가 익스플로잇을 수행할 수 있는 부분을 좁힌다.
>     1.  “Input: “이 출력됐을 때 값을 입력하는 부분이 유일하게 유저가 프로세스와 소통할 수 있는 부분이다.
>     2. 따라서 유저 입력값을 받을 때 malicious 한 입력값을 넣어야 한다.
> 3. 현재 코드에서는 유저 입력값을 어디에 넣는지 확인한다.
>     1. buf[0x28]에 넣는 것으로 설정되어 있고, 입력값이 범위를 넘어가는 것을 차단하지 않는다.
>     2. 따라서 BOF(Buffer OverFlow) 공격을 수행하는 것으로 결정한다.
> 4. 유저가 입력값을 입력할 때 스택의 구조를 알아내어 현재 스택 프레임이 종료된 후 실행될 인스트럭션의 주소를 오염시킨다.

각 페이즈의 목적을 차근차근 달성해 보자.

### get_shell() 함수의 시작 주소 알아내기

특정 프로그램을 구성하는 함수들은 프로세스가 메모리에 올라갈 때 한꺼번에 코드 세그먼트에 로딩된다. c 언어의 경우 위에서부터 아래로 컴파일되기 때문에, 함수가 코드 세그먼트에 로딩되는 순서는 코드가 쓰인 순서와 일치하게 된다. 즉, get_shell() 함수 다음에 main() 함수가 코드 세그먼트에 로딩된다.

이제 gdb를 이용해 get_shell() 함수의 위치를 알아내 보자. 

![Untitled](/assets/img/posts/syshack3-2/Untitled%204.jpeg)

딱히 난독화하지 않았기 때문에 심볼이 그대로 살아 있다. 브레이크 포인트를 get_shell에 걺으로써 get_shell의 주소를 알아낼 수 있었다.

추가적으로, main() 함수의 주소는 아래와 같다.

![Untitled](/assets/img/posts/syshack3-2/Untitled%205.jpeg)

코드상에서 get_shell보다 아래에 main이 쓰여 있었기 때문에 메모리의 코드 영역에도 main이 get_shell보다 뒤에 로딩된 것을 확인할 수 있다.

### 유저 입력값을 받을 당시 스택의 구조 확인하기

위에서 짚어본 것처럼, 새롭게 콜된 함수의 스택 프레임과 이전 함수의 스택 프레임 간의 관계는 아래와 같다.

![Untitled](/assets/img/posts/syshack3-2/Untitled%202.jpeg)

스택에는 로컬 변수가 저장되기 때문에 우리가 BOF의 매개로 사용하는 buf[0x28] 변수 또한 스택에 있을 것을 예상하고 있다. 또한 변수는 선언된 순서대로 스택에 들어가므로 buf 변수는 main 함수의 rbp에 위치해 있을  것이다. 따라서 우리가 익스플로잇할 당시의 스택의 구조는 아래와 같다.

+++++++++++++++++++++++++++++++++++++++++++++++++++

.

.

.

**[rbp-0x1]~[rbp-0x28]**: buf[0x28]

================main() 스택 프레임 끝====================

**[rbp+0x7]~[rbp]**: start_main()의 rbp 주소(0x0000000000000000)

**[rbp+0x0e]~[rbp+0x07]**: main()이 끝난 후 이어서 실행될 인스트럭션 주소

.

.

.

+++++++++++++++++++++++++++++++++++++++++++++++++++

과연 추측이 맞는지 gdb를 붙여서 확인해 보자.

### 실제 스택의 구조를 디버거로 확인하기

주어진 함수를 gcc로 컴파일할 때 스택 카나리를 끄고(-fno-stack-protector) PIE를 끔으로써 ASLR도 적용되지 않도록(-no-pie) 해두었기 때문에 아마 스택의 구조는 비교적 간단할 것이다. 목표 프로세스인 `rao` 에 gdb를 붙여서 사용자 입력값을 받고 저장하는 시점의 스택의 구조를 해당 시점에서의 rbp까지 포함되도록 확인해 보았다.

![Untitled](/assets/img/posts/syshack3-2/Untitled%206.jpeg)

흰색으로 하이라이트한 부분, 즉 `0x7fffffffdf80` 이 rbp이며, 스택의 구조 자체는 예상했던 바와 일치함을 확인할 수 있었다. 그러나, 딱 한 가지 다른 부분이 있었다.

buf[0x28] 변수는 애초에 0x28 byte 만큼의 크기를 가지기 때문에 예상대로라면 buf[0x28]이 차지하는 주소는 `0x7fffffffdf7e` ~ `0x7fffffffdf58` 이었어야 하지만, 실제로 확인한 결과는 `0x7fffffffdf7e` ~ `0x7fffffffdf50` 이었다. 즉 8byte 만큼이 더 할당되어 있었다. buf[0x28] 이 실제로는 buf[0x30] 이었던 것이다.

이 이유가 궁금해 알아보니, 스택 보호의 일환으로 c 컴파일러가 char 배열을 할당할 때 8byte 정도를 더 할당해 준다는 사실을 알 수 있었다. 단순히 이론상으로만 문제에 접근할 게 아니라 실제로 구동하는 상황에서의 메모리 구조를 확인한 이후 익스플로잇을 작성하는 게 좋겠다는 교훈을 얻을 수 있었다.

### 익스플로잇 작성하기

익스플로잇에서 프로세스에게 보낼 페이로드를 먼저 구상해 보자. 프로세스가 구동중일 때 실제 스택의 구조는 아래와 같았다.

+++++++++++++++++++++++++++++++++++++++++++++++++++

.

.

.

**[rbp-0x1]~[rbp-0x30]**: buf[0x28]                                                              //0x30 byte

================main() 스택 프레임 끝====================

**[rbp+0x7]~[rbp]**: start_main()의 rbp 주소(0x0000000000000000)      //0x08 byte

**[rbp+0x0e]~[rbp+0x07]**: main()이 끝난 후 이어서 실행될 인스트럭션 주소  //0x08 byte

.

.

.

+++++++++++++++++++++++++++++++++++++++++++++++++++

따라서 우리는 총 0x38 byte를 더미값으로 채운 후, 마지막 0x08 byte에 실행되길 원하는 get_shell() 함수의 시작 주소를 붙인 페이로드를 만들면 된다.

이렇게 생성한 페이로드를 정상적으로 프로세스에 입력해줄 수 있는 python 스크립트를 만들어 실행하면 셸이 실행될 것이다. 여기에 해당 스크립트를 적고 자세한 분석 내용을 쓸까 고민했지만, 그렇게 하면 스포일러가 될지도 모르겠다는 생각이 들어 생략한다.

다만, 우리가 이제까지 배운 pwn 라이브러리 상에서 문제를 해결할 수 있으며, 어떤 메소드가 어떤 형식의 값을 받아 어떤 형식의 값을 리턴하는지, 그리고 셸을 땄음을 어떻게 확인할 수 있을지를 생각하고 스크립트를 작성하는 것을 추천한다.