---
layout: post
title:  "System Hackig Step 5-3"
summary: BOF-Return Address Overwrite
author: TouBVa
date: '2022-08-22 23:55:23 +09'
category: dreamhack_system_hacking
thumbnail: /assets/img/posts/syshack53/Untitled%203.jpeg
keywords: System Hacking, BOF, Return Address Overwrite
usemathjax: true
permalink: /blog/dreamhack_system_hacking/step5-3
---


* TOC
{:toc}

<br>

# STAGE 5-3: BOF-Return Address Overwrite

- Stack Buffer Overflow로 인해 가능한 Return Address 조작 공격을 실습
- 해당 취약점이 존재하는 예제 프로그램 공격 및 셸 획득이 목표

# 먼저 풀어보기:

## 1. 예제 코드 취약점 분석하기

```c
#include <stdio.h>
#include <unistd.h>

void init(){
	setvbuf(stdin, 0, 2, 0);
	setvbuf(stdout, 0, 2, 0);
}

void get_shell(){
	char *cmd = "/bin/sh";
	char *args[]={cmd, NULL};

	execve(cmd, args, NULL);
}

int main(){
	char buf[0x28];

	init();
	
	printf("Input: ");
	scanf("%s", buf);

	return 0;
}
```

- setvbuf 함수는 file I/O 작업 시 해당 작업의 속도가 메모리를 읽고 쓰는 것에 비해 너무 느리다 보니 버퍼를 선언하고 파일에 쓸 데이터/ 읽어올 데이터를 대용량으로 한 번에 저장한 후 지정된 조건을 만족하면 파일와의 상호작용을 하게끔 해서 비효율적인 자원 사용을 지양하기 위해 사용된다.

위 코드의 exploitable 한 부분은 사용자와의 상호작용을 하는 부분, 즉 main 함수에서 Input을 받는 부분이다. 해당 부분에 payload를 입력하면 익스가 가능할 것이다.

그렇다면 어떤 형태의 익스가 가능할까? main함수에서 buf라는 지역변수를 단 하나 설정해 두었고, 취약한 함수인 scanf 함수를 썼다. 또한 main 함수의 스택 프레임은 buf 아래에 libc_start_main 함수의 SFP, 그리고 그 아래에 rip의 ret add로 구성되어 있을 것이다. 

즉, ret add 조작으로 이어지는 스택 버퍼 오버플로우를 일으킬 수 있다.

## 2. 페이로드 구상하기

그렇다면 payload의 형태는 어떻게 구성될까? 

당연히 `0x28(+a)+0x08` byte의 dump data + `*get_shell()` 일 것이다. 여기에서 buf 변수의 크기에 a byte를 더한 이유는, C언어 컴파일러가 자체적으로 버퍼를 보호하기 위해서 명시적으로 선언된 버퍼에 몇 byte를 붙여 실질적인 스택 버퍼를 선언하는 경우가 있기 때문이다. 

이 경우에는 익스할 프로그램이 컴파일된 환경과 동일한 환경에서 컴파일 후 버퍼의 크기가 어떻게 선언되는지 확인해야 한다.

해당 프로그램을 컴파일한 후, gdb에 물려 스택의 상황과 인스트럭션을 확인해 보았더니 아래와 같았다.

![main 함수에서 선언된 지역 변수의 크기는 0x28인데, 스택은 0x30만큼을 확보하는 모습.](/assets/img/posts/syshack53/Untitled.jpeg)

main 함수에서 선언된 지역 변수의 크기는 0x28인데, 스택은 0x30만큼을 확보하는 모습.

![흰색 블록 처리된 부분의 왼쪽은 SFP, 오른쪽은 rip ret add 이다.](/assets/img/posts/syshack53/Untitled%201.jpeg)

흰색 블록 처리된 부분의 왼쪽은 SFP, 오른쪽은 rip ret add 이다.

즉, [예전에 풀었던 문제](https://toubva.github.io/blog/system-hacking-step3-2/#/)처럼 C 컴파일러가 Char 배열을 할당할 때 8byte를 더 할당해 준 것을 확인할 수 있었다.

따라서 정확한 payload의 구조는 아래와 같다.

`0x30byte + 8byte` dump data + `*get_shell`

이제 get_shell의 주소를 구해 보자.

![Untitled](/assets/img/posts/syshack53/Untitled%202.jpeg)

`0x4011dd` 로 확인되었다. 

즉, payload는 아래와 같다.

`“A”*0x38 + 0x4011dd`

## 3. 익스플로잇 코드 작성하기

![작성한 익스플로잇 코드.](/assets/img/posts/syshack53/Untitled%203.jpeg)

작성한 익스플로잇 코드.

위의 코드를 실행한 결과는 아래와 같았다.

![쉘을 획득하는 데 성공했다.](/assets/img/posts/syshack53/Untitled%204.jpeg)

쉘을 획득하는 데 성공했다.

---

# 코스 내용 학습:

## 1. 취약점 분석

- 프로그램의 취약점은 한 마디로 `scanf("%s", buf)` 함수 사용 취약점이다.
    - `scanf` 함수의 포맷 스트링의 한 종류인 `%s` 는 “문자열”
    - 그런데, C 언어의 특성상 이는 띄어쓰기, 탭, 개행 문자가 들어올 때까지 계속 입력을 받아버림.
    - 즉, 입력 길이에 제한을 두지 않는 것이나 마찬가지. → 오버플로우 발생 공격 가능
    - **따라서 scanf에서 %s 사용은 엄금, %[n]s 로 정확히 n개 문자만 입력받도록 설정할 것!**
- **C/C++의 표준 함수 중 버퍼를 다루면서 길이를 입력하지 않는 함수들은 대부분 위험하다.**
    - 예: `strcpy` , `strcat` , `sprintf`
    - 반례(버퍼 크기 입력을 받음): `strncpy` , `strncat`, `snprintf` , `fgets` , `memcpy`
    - 위험한 함수는 **OOB 취약점** 등의 심각한 취약점이 될 수 있음.
- **1) 입력의 길이를 제한하는 문자열 함수 사용 2) 문자열 사용 시 해당 문자열이 NULL byte로 종결되는지 확인**
- 프로그램의 취약점을 찾을 땐 위 항목을 역으로 이용하면 좋다.

<aside>
💡 OOB(Out Of Bound): C계열 언어에서 문자열을 읽어올 때, 문자열의 종결을 알리는 NULL byte를 찾지 못해 프로그래머가 의도한 크기를 넘어서 문자열의 인덱스를 참조하는 현상(Index Out-Of-Bound)을 발생시키는 취약점.

</aside>

## 2. 취약점 트리거

- 이미 앞에서 취약점 트리거를 완료했기 때문에, 여기에서는 교안으로 보고 새로 알게 된 내용만 정리해 작성한다.

프로그램을 실행한 후, 프로그램의 입장에서는 말도 안 될 만큼 긴 입력(64byte)를 줘 보았다. 

![Untitled](/assets/img/posts/syshack53/Untitled%205.jpeg)

그 결과, ‘Segmentation fault’ 라는 에러가 출력되면서 프로그램이 강제 종료된다. Segmentation은 앞에서 배웠듯 운영체제가 관리하는 프로세스의 메모리 구조인데, 이러한 구조에 문제가 생겼다는 뜻으로 해석된다. 

즉, 프로그램이 잘못된 메모리 섹션에 접근했으므로 버그가 발생했다는 의미이다.

그리고 마지막의 ‘core dumped’는 코어파일을 생성했다는 의미로, 프로그램이 위와 같이 비정상적으로 종료됐을 때, 디버깅을 수월하게 하기 위해 운영체제가 만들어 주는 것이다. 만일 위와 같은 알림이 떴음에도 코어 파일이 생성되지 않았다면 생성해야 할 코어 파일의 크기가 시스템에서 정한 한도를 초과했기 때문이다.

해당 한도는 `ulimit -c unlimited` 로 해제할 수 있다.

보통은 현재 디렉터리 아래에 core라는 폴더가 생기고, 그 안에 코어 덤프가 저장되어야 하는데… 내가 사용하는 Ubuntu 20.04+ 는 apport에 의해서 core dumping이 intercept돼 운영체제가 아니라 apport가 코어 덤프를 만들도록 되어 있었다… 그래서 한참을 뒤져 `/var/lib/apport/coredump` 에서 코어 덤프들을 찾아낼 수 있었다. 

그런데 또 문제상황.. 해당 코어 덤프와 원본 프로그램을 gdb에 같이 물려서 코드와 스택을 확인해 보려 했는데, Maximum recursion depth exceeded in comparison 오류가 떠서 제대로 안 되었다. 

결국 시간이 부족한 관계로 코어 덤프 분석은 교안을 읽고 마무리하기로 했다… 코어 덤프 분석의 결론은 SBOF로 인해 ret add가 입력값으로 덮어씌워졌고, 당연히 그것은 실행가능한 메모리 주소가 아니기 때문에 Segmentation fault가 발생했다는 것이었다.

## 3. 익스플로잇

이미 문제를 풀었고, 해당 원리를 알고 있기 때문에 각 페이즈에서 모르는 부분만 간단히 정리한다.

1. 스택 프레임 구조 파악
2. get_shell() 주소 파악
    - gdb에서 `print get_shell` 하면 된다.
3. 페이로드 구성
    - 구성한 페이로드의 중요 데이터는 반드시 엔디언(Endian)을 적용시켜서 프로그램에 전달해야 한다.
        - 예: get_shell()의 주소는 대상 시스템의 아키텍처에 따라 엔디언을 다르게 적용시켜서 페이로드에 합쳐야 한다. ( \xa7\x05\x40…즉 바이너리 포맷으로)
4. 익스플로잇
    - 나는 파이썬의 pwntools를 이용했는데, 해당 교안에서는 바로 파이썬 커맨드를 이용해 익스플로잇을 수행했기 때문에 해당 커맨드를 아래에 적는다.
        
        ```python
        $ (python -c "import sys;sys.stdout.buffer.write(b'A'*0x30 + b'B'*0x08 + b'{리틀_엔디언으로_작성된_대상_함수_주소}')";cat) | ./rao
        ```
        
    - 그리고 익스플로잇에 성공하여 **쉘을 땄다면, `id` 커맨드**를 쳐서 현재 계정의 권한을 출력해서 보여주는 것으로 증명한다.

---

# 취약점 패치

> C언어에서 자주 사용되는 문자열 입력 함수들의 패턴을 알고, 적절히 사용해야 한다.
> 

![Untitled](/assets/img/posts/syshack53/Untitled%206.jpeg)
- 널 종결: 문자열의 끝에 널이 있어서 문자열의 끝이 명시되는 것.