---
layout: post
title:  "System Hackig Step 3-1"
summary: gdb 사용 기초와 각종 명령어
author: TouBVa
date: '2022-07-10 21:10:23 +09'
category: System Hacking Basic
thumbnail: /assets/img/syshack3-1/Untitled.jpeg
keywords: System Hacking, Computer Architecture, Register, OS basic
usemathjax: true
permalink: /blog/system-hacking-step3-1/
---

# STAGE 3-1

- gdb 설치와 pwndbg 플러그인 설치하기.
- 만일 뭔가 잘못해서 aslr 커맨드의 화이트리스트로~ 라는 경고문이 나온다면, 그건 여러 gdb 플러그인을 설치했기 때문에 .gdbinit 파일이 중복돼서 생기는 문제이므로 ~/.gdbinit 파일을 깨끗하게 지우고 설치했던 플러그인 폴더들을 다 지운 후 gdb가 여전히 남아 있는지 확인 한 번 해보고 다시 플러그인을 설치하는 것을 추천한다. 설치할 때의 instruction을 잘 따르자.

# gdb 사용하기 기초

## TL;DR

- gdb는 리눅스의 대표적인 디버거
- 무료로 설치할 수 있고, 수많은 유용한 플러그인을 결합해 사용할 수 있음.
- 다양한 명령어가 존재하며, 적재적소에 명령어를 사용할 때 그 진가를 발휘할 수 있음.

---

## Prolog

리눅스의 실행파일은 .elf이다. 이런 elf 파일의 정보를 읽어오기 위해 리눅스에서 기본으로 제공하고 있는 명령어가 있는데, 그것은 바로 `readelf` 이다.

`readelf -h {file path}` 를 실행해 대상 실행 파일의 헤더 정보를 읽어온 결과는 아래와 같이 표시된다.

![readelf로 elf 파일의 헤더 정보를 읽어온 결과](/assets/img/syshack3-1/Untitled.jpeg)

readelf로 elf 파일의 헤더 정보를 읽어온 결과

이를 이용해 대상 파일의 EP, 즉 entry point를 알 수 있다. **리버싱할 때 제일 중요한 게 바로 이 EP를 찾는 것**인데, 리눅스 환경에서 ELF 파일은 손쉽게 EP를 알 수 있으므로 스타트는 쉽게 끊을 수 있다.

다만 ASLR 이라고 리눅스 자체 메모리 보호 기법이 있는데, 힙이나 스택 등 어떤 프로세스를 실행할 때마다 그 프로세스에게 할당되는 가상 메모리의 주소가 전부 달라지는 기능이 있다. ASLR이 설정되어 있다면 디버깅할 때마다 모든 주소가 달라지는 진기명기를 확인할 수 있으니, ASLR을 꺼두는 것을 추천한다. 

ASLR이 함수의 EP에도 영향을 주는지는 내가 방금 ASLR을 끄고 디버깅해서 확인했다. 진짜로 끄는 것을 강력 추천한다.

ASLR을 해제하기 위해서는 아래의 명령어를 터미널에 입력하면 된다.

`sudo sysctl -w kernel.randomize_va_space=0`

해당 elf 파일의 헤더 정보를 알아냈다면, 드디어 gdb를 이용해 실행 파일을 분석해 볼 시간이다.

1. `gdb {file_path}` 를 실행해 gdb를 해당 파일에 붙인다.
2. `start` 명령어를 입력한다.
    
    ![start 명령어를 실행한 결과.](/assets/img/syshack3-1/Untitled%201.jpeg)
    
    start 명령어를 실행한 결과.
    
    - gdb의 `start` 명령어는 EP부터 프로그램을 분석할 수 있게 해준다.
    - 현재 rip의 값은 DISASM 섹션의 화살표가 가리키고 있는 주소이다.
        - 이 경우 `0x555555555149` 임을 확인할 수 있다.
        - `0x1149` 에 BP가 걸린 걸 보니 이 프로세스의 EP는 오프셋 `0x1149` 일 것이다.
        - 아니 앞에서는 EP 주소가 `0x1060` 인데 왜 main의 엔트리는 `0x1149` 인 거야???
            
            ![이해가 안 돼서 main의 엔트리와 원래 엔트리로 예상되는 주소의 데이터를 체크해 보았다.](/assets/img/syshack3-1/Untitled%202.jpeg)
            
            이해가 안 돼서 main의 엔트리와 원래 엔트리로 예상되는 주소의 데이터를 체크해 보았다.
            
            `_start` 함수는 컴파일할 때 자동으로 따라와 붙는 함수인데, 해당 함수의 끝 부분에서 `__libc_start_main` 이라는 dll을 호출한다. 해당 dll에서 연쇄적인 호출 과정을 거쳐서 내가 만든 프로세스의 진짜 엔트리인 `main` 이 호출되기 때문이 이와 같은 불일치 현상이 일어나는 것이다. 
            
            한 마디로 elf 파일의 엔트리는 `_start` 함수부터라고 인식하지만, gdb를 붙여서 돌렸을 때 gdb는 쓸데없는 dll 실행은 넘겨 버리고 `main` 에 BP를 만들기 때문에 발생하는 현상이다. ~~gdb가 너무 똑똑해서 생긴 문제였다…!~~
            

---

## Context: pwndbg의 대시보드

사실 Context라는 말은 프로세스 관련해서 많이 쓰이는 말이다. pwndbg는 이런 context의 특성을 차용해 **프로세스 실행 시 주요 메모리들의 실시간 상태를 보여주는** 자신의 대시보드를 **Context**라고 칭하고 있다.

pwndbg의 context는 크게 4개의 영역으로 구분된다.

![Untitled](/assets/img/syshack3-1/Untitled%203.jpeg)

1. Registers: 레지스터의 상태를 보여준다. 레지스터의 종류가 뭐였지? 라는 의문이 든다면 [System Hacking Step2: Computer Architecture](https://toubva.github.io/blog/system-hacking-step2/#/) 참고.
2. Disasm: rip부터 시작해서 여러 줄에 걸쳐 디스어셈블된 결과를 보여주는 섹션이다. 즉, 앞으로 실행될 인스트럭션들을 어셈블리어로 보여주는 섹션이다.
3. Stack: rsp부터 여러 줄에 걸쳐 스택의 값들을 보여준다. 스택의 맨 위부터 뭐가 있는지(스택에 뭐가 들어있는지 가장 최신의 것부터)를 어느 정도 보여준다는 뜻이다.
4. Backtrace: 현재 rip에 도달할 때까지 어떤 함수들이 중첩되어 호출됐는지 보여준다. 화살표가 있는 부분이 현재 rip가 있는 함수이고, 그 밑에 있는 것들이 이제까지 호출됐던 함수 목록이다. 보통 이러면 콜스택 보여주지 않나? 왜 굳이 이미 지나가서 기능이 끝난 함수들을 보여주려 하지?

---

## break&continue

- gdb를 이용해 프로그램을 분석할 땐, 프로그램의 동작 중 아주 일부분에만 관심이 있을 때이다.
- 이러한 목적 달성을 위해 break와 continue라는 기능이 있다.
    - break: 특정 주소에 중단점(breakpoint)를 설정하는 기능
    - continue: 현재 지점에서 다음 중단점까지 멈춤 없이 실행하는 기능

---

## run

- 프로그램을 단순히 실행만 시키는 명령어.
- 중단점에서 멈추지만, **프로그램을 처음부터 시작한다-중단점이 있으면 멈춘다**의 시퀀스이므로 **중단점에서 시작한다-다음 중단점에서 멈춘다**의 시퀀스를 가진 **continue와는 확연한 차이점**이 있다.

<aside>
⚙ gdb는 명령어 줄여쓰기 기능을 제공하기 때문에, 명령어를 특정할 수 있는 최소한의 문자열만 입력하면 자동으로 명령어를 찾아서 수행해 준다. 예를 들어서, 앞서 설명한 break는 b만 쳐도 되고, continue의 경우에는 c만 쳐도 된다. run 또한 r만 쳐도 자동으로 실행된다.

</aside>

## disassembly

- gdb에서 기본으로 제공하는 디스어셈블 명령어.
- 함수 이름을 인자로 전달하면 해당 함수가 리턴될 때까지 전부 디스어셈블해 보여준다.
    
    ![Untitled](/assets/img/syshack3-1/Untitled%204.jpeg)
    
- pwndbg에서는 **u, nearpc, pdisassemble**을 제공한다. 디스어셈블된 코드를 가독성 좋게 출력해준다는 점에서 쓸 만하다!
    
    ![확실히 낫다.](/assets/img/syshack3-1/Untitled%205.jpeg)
    
    확실히 낫다.
    

---

## navigate: ni, si, finish

- 명령어를 한 줄씩 자세히 분석하는 기능.
    - **ni(next instruction)**: 어셈블리 명령어를 딱 한 줄 실행한다. **서브루틴의 내부로 들어가지 않는다.**
    - **si(step into)**: 어셈블리 명령어를 딱 한 줄 실행한다. **서브루틴의 내부로 들어간다.**
        - **finish**: 함수 규모가 너무 커서 ni로는 도무지 원래 함수로 돌아올 수 없는 경우, 현재 위치한 함수의 맨 끝까지 한번에 실행할 수 있는 명령어.
- 서브루틴이란?
    - 함수 내부에서 다른 함수를 콜할 때, 그 다른 함수의 실행 루틴을 서브루틴이라고 한다.
    - 즉 서브루틴의 내부=현재 함수에서 콜한 다른 함수의 내부

---

## examine: x

- 가상 메모리에 존재하는 임의 주소의 값을 관찰해야 할 때 사용한다.
- **x**: **원하는 주소**에서, **원하는 길이**만큼의 데이터를 **원하는 형식으로 인코딩**해 확인할 수 있다.
    - 형식: `x/{원하는 데이터 묶음 수}{한 데이터 묶음의 길이}{데이터 형식}  {메모리 주소}`
        - 한 데이터 묶음의 길이(size): b(byte), h(halfword), w(word), g(giant; 8 bytes)
        - 데이터의 형식(format): o(octal), x(hex), d(decimal), u(unsigned decimal), t(binary), f(float), a(address), i(instruction), c(char), s(string), z(hex, zero padded on the left)

---

## telescope

- pwndbg가 제공하는 메모리 덤프 기능. 메모리가 참조하고 있는 주소를 재귀적으로 탐색해 값을 보여주기까지 함!
- 현재 보이는 이 값이 어떤 주소에서 어떻게 사용되는지까지 알 수 있으므로 굉장히 유용하다.
    - rsp 기준으로 8개의 메모리 주소를 보여주기 때문에 콜스택의 역사를 알 수 있다.
        
        ![Untitled](/assets/img/syshack3-1/Untitled%206.jpeg)
        

---

## vmmap

- 가상 메모리의 레이아웃을 보여주며, 어떤 파일이 매핑된 영역일 때 해당 파일의 경로까지 보여줌.
- cat /proc/{pid}/maps와 동일한 일을 한다. 물론 가독성은 훨씬 좋다.
    
    ![Untitled](/assets/img/syshack3-1/Untitled%207.jpeg)
    

<aside>
⚙ 파일 매핑:

- 어떤 파일을 메모리에 적재하는 것.
- 리눅스에서 ELF를 실행할 때의 과정:
    1. ELF 자체의 코드, 데이터 등을 가상 메모리에 매핑 
    2. 해당 ELF에 링크된 공유 오브젝트(.so)를 추가로 메모리에 매핑
        - 리눅스의 so = 윈도우의 dll
    3. so에 구현된 함수를 호출할 땐 매핑된 메모리에 존재하는 함수를 대신 호출(메모리에 적재된 so 내부의 함수를 호출)
</aside>

---

## gdb/python

- gdb를 이용해 디버깅 시, 숫자/알파벳 이외의 값은 입력값으로 직접 입력해줄 수 없는 문제가 있다.
- 첫번째 방식: python argv
    - 목표 프로그램에 gdb를 붙이고 r 명령어의 인자로 `$({원하는 내용을 줄 수 있는 파이썬 코드})` 를 입력하면 프로그램의 **‘인자’**를 전달할 수 있다.
    - 사용예:
        
        ![Untitled](/assets/img/syshack3-1/Untitled%208.jpeg)
        
- 두번째 방식: python input
    - 목표 프로그램에 gdb를 붙이고, r 명령어의 인자로 `<<< $({파이썬 코드})` 를 입력하면 프로그램 실행 중에 받는 **‘입력값'**을 미리 전달할 수 있다.
    - 사용예: *(해당 프로그램은 인자와 입력값 모두를 요구하기 때문에 첫번째 방식과 두번째 방식이 함께 쓰였다.)
        
        ![Untitled](/assets/img/syshack3-1/Untitled%209.jpeg)
        

---

## 그 외 자주 사용되는 명령어들과, 그 단축키

- b: break
- c: continue
- r: run
- si: step into
    - 어떤 함수 안으로 들어가는 것이다.
- ni: next instruction
    - 명령어를 딱 한 줄 더 실행하는 것이다.
- i: info
    - 접두어로 주로 사용되고, 접미로 붙는 요소의 정보를 확인하는 데 사용된다.
    - 예시: info b (현재 브레이크 포인트 보기)
- k: kill
    - kill process
- pd: pdisas
    - 기존 gdb 명령어의 peda 버전으로, disas의 확장판이다.
    - 화면이 좀 더 예쁘게, 가독성 좋게 나온다. ~~기부니가 조크든요~~

---

