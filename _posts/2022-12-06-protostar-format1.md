---
layout: post
title:  "Protostar-format1.c x86-64"
summary: FSB(Format String Bug) exploitation in 64 bit
author: TouBVa
date: '2022-12-06 00:20:58 +09'
category: ['system_hacking', 'protostar']
thumbnail: /assets/img/posts/format1/Untitled%201.jpeg
keywords: System Hacking, Memory Exploit, Format String Bug
usemathjax: true
permalink: /blog/system_hacking/protostar-format1/
---


* TOC
{:toc}

<br>

# Format1.c

결론부터 말하자면, 이 문제는 64비트로 푸는 게 불가능한 문제다. 입력값으로 페이로드를 받는다면 어떻게든 풀 수 있겠으나, 함수의 인자로 페이로드를 받기 때문에 리눅스 쉘의 파이프 특성상 null byte가 제외되어 불가능하다.

그래도 문제를 풀며 많은 것을 알게 되었으니 이렇게 정리해 둔다.<br>

# 0. 포맷 스트링 버그란

> 버퍼 오버플로우 취약점으로 이어질 수 있는 버그로,
> 
> - 사용자 입력을 검증하지 않고 사용한 결과
> - 사용자가 악의적인 용도로 입력한 Format String이
> - 프로그램 실행에 영향을 끼치는 것을 의미한다.

## 0.1. 포맷 스트링이란

- C언어에서 자주 사용되는 “출력 용도의 함수”가 출력할 “데이터의 형식을 지정”하기 위해 사용하는 특수 문자
- 포맷 스트링의 종류는 매우 다양하다.
    
    
    | 인자 &nbsp; |  &nbsp; 입력 타입 &nbsp; |  &nbsp;출력 &nbsp;  |  &nbsp;익스플로잇 용도 &nbsp;  |
    |   :---:  |   :---:   |   :---   |   :---  |
    | %d &nbsp;|&nbsp; 값 &nbsp;| &nbsp;10진수&nbsp; | &nbsp;&nbsp; |
    | %s&nbsp; | &nbsp;포인터&nbsp; |&nbsp; 해당 포인터가 가리키는 문자열 &nbsp;| &nbsp;&nbsp; |
    | %x &nbsp;|&nbsp; 값 &nbsp;| &nbsp;16진수 &nbsp;| &nbsp;메모리를 읽을 때 사용한다 &nbsp;|
    | %u &nbsp;|&nbsp; 값 &nbsp;| &nbsp;Unsigned 10진수 &nbsp;| &nbsp;&nbsp; |
    | %p &nbsp;| &nbsp;포인터 &nbsp;| &nbsp;포인터가 가리키는 메모리 주소 &nbsp;| &nbsp;&nbsp; |
    | %n &nbsp;| &nbsp;포인터 &nbsp;| &nbsp;%n이 나오기 전까지 출력했던 바이트 수를,&nbsp;<br> 포인터가 가리키는 메모리 주소에 넣어줌 &nbsp;|&nbsp; 메모리 값을 변조할 때 사용한다&nbsp; |
    | %c &nbsp;| &nbsp;포인터 &nbsp;| &nbsp;1byte 한 글자 &nbsp;| &nbsp;&nbsp; |
    | … &nbsp;|&nbsp; … &nbsp;| &nbsp;… &nbsp;|&nbsp;&nbsp;  |
- 위 포맷 스트링 중 가장 중요한 건 `%x`, `%n` 이다.
- 특히 `%n` 의 경우, 메모리 주소를 가리키는 포인터를 인자로 받기 때문에 32비트 환경에서는 4바이트, 64비트 환경에서는 8 바이트를 한 번에 읽어서 주소로 사용한다는 점 잊지 말기!
<br><br>


# 1. 예제 코드 분석

주어진 코드는 아래와 같다.

```c
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
 
int target;
 
void vuln(char *string)
{
  printf(string);
  
  if(target) {
      printf("you have modified the target :)\n");
  }
}
 
int main(int argc, char **argv)
{
  vuln(argv[1]);
}
```

사용자에게서 프로그램의 argument로 입력받은 값을 문자열의 형태로 `vuln` 함수에게 넘겨준다.

해당 문자열은 `printf`에서 즉석으로 호명되며, 이후 프로그램의 control flow는 `printf` 내부로 흘러들어가게 되고, 해당 함수 내에서 입력된 문자열과 format string이 처리된다.

format string bug는 바로 이 지점, 즉 프로그램이 컴파일되어 실행되는 시점과 사용자 입력을 처리하여 알맞은 행위를 취하는 시점의 시차에서 발생한다.
<br><br>


# 2. 익스플로잇

익스플로잇은 아래의 단계로 구성된다.

1. 프로그램 분석해 취약점 확정
2. 취약점을 익스플로잇할 방법 지정
3. 익스플로잇 생성 및 실행

먼저 주어진 프로그램을 익스플로잇했을 때 성취해야 할 목적은 `target` 변수를 0 이외의 것으로 변경하는 것이다. `target` 변수는 global int로 uninitialized 이기 때문에 `.bss` 영역에 저장될 것이고, 전역변수인 이상 컴파일 당시 컴파일러에 의해 0으로 자동 초기화될 것이기 때문이다.

앞에서 프로그램 분석과 취약점 확정을 마무리했으므로, 2) 취약점 익스플로잇 방법 확정부터 시작한다.

## 2.1. 취약점 익스플로잇 방법 지정

### 2.1.1. 배경 설명

64bit 프로그램에서 아래와 같은 printf 구문이 함수 내에 있을 때 printf가 변수를 참조하는 방식에 대해 자세히 알아보자.

```c
char *buf = '%p.%x.%c.%d.%f.%h.%n';
printf(buf);
```

위의 코드 라인이 진행되면 결론적으로는 `printf('%p.%x.%c.%d.%f.%h.%n')` 가 실행되는데, 이때 주의깊게 봐야 할 것은 64비트 프로그램에서 함수에 인자를 전달할 때 레지스터와 스택의 사용 방식이다.

> 리눅스용 gcc는 64비트 컴파일 시 `fastcall` 이라는 calling convention을 사용하는데, 이 규약 하에서는 `rdi, rsi, rdx, rcx, r8, r9` 순으로 인자가 들어가고 남아있는 인자는 스택에 마지막 인자부터 push하여 이후 스택에서 인자를 pop할 때 순서대로 pop되도록 한다.
> 

그렇다면 `printf` 함수에서 인자는 어떤 식으로 전달될까? 익스플잇할 대상 프로그램에 직접 디버거를 붙여 확인해 보았다.

![Untitled](/assets/img/posts/format1/Untitled.jpeg)

- `rdi` , 즉 첫 번째 인자로 프린트할 스트링의 시작 주소가 주어졌고
- `rsi` , 즉 두번째 인자로 현재 프로세스의 적재 위치가 주어졌다.

만일 대상 프로그램에서 `printf(string)` 이 아닌 `printf(string, 0xDEADBEEF, ... , 0xCAFECAFE)` 등의 형식으로 여러 인자를 전달했다면 `rdi` 는 `string` , `rsi` 는 `0xDEADBEEF` … 식이 되었을 것이다. 

이처럼, `printf` 함수는 프린트할 스트링의 시작주소를 무조건 첫 번째 인자로 받고, 해당 스트링에 포맷 스트링이 6개 포함되어 있을 경우 함수의 인자 규칙과 calling convention에 따라 `rsi`, `rdx`, `rcx`, `r8`, `r9`, `stack` 을 각 포맷 스트링에 대해 순서대로 참조한다. 이 사실을 기반으로 다시 한 번 예시를 보자. 

```c
char *buf = '%p.%x.%c.%d.%f.%h.%n';
printf(buf);
```

따라서 `printf(buf)` 가 인자를 사용하기 위해 레지스트리와 스택을 참조하는 순서는 아래와 같을 것이다.

1. `rdi`: &buf
2. `rsi`: some hex value → %p에 주어질 포인터로서 참조
3. `rdx`:  ‘’ → %x에 주어질 값으로서 참조
4. `rcx`:  ‘’ → %c에 주어질 포인터로서 참조
5. `r8`:  ‘’ → %d에 주어질 값으로서 참조
6. `r9`:  ‘’ → %f에 주어질 값으로서 참조
7. `stack`:  ‘’ → %h에 주어질 값으로서 참조
8. `stack(next address)`:  ‘’ → %n에 주어질 포인터로서 참조

이제 언급된 포맷 스트링 `%n`에 대해 자세히 알아보자. `%n` 은 인자로서 어떤 메모리의 주소(포인터)를 받는다. 이렇게 받은 포인터가 가리키는 메모리에 `%n` 은 자신이 나오기 전까지 입력된 문자의 개수를 입력한다.

포맷 스트링 중 유일하게 메모리 값을 변조하는 것이 바로 `%n` 포맷 스트링이기 때문에 이는 익스플로잇에 매우 자주 이용된다.

### 2.1.2. 익스플로잇 설계

앞서 설명한 내용의 요점은 아래와 같다.

1. 64비트 프로그램의 Calling Convention을 고려했을 때, 입력값을 검증하지 않고 사용하는 `printf()` 함수에게 format string을 많이 주어 스택에 순차적으로 접근할 수 있다.
2. 포맷 스트링 중 `%n` 만이 유일하게 사용자의 입력값을 반영하여 인자로 주어진 포인터가 가리키는 메모리 값을 변조한다.

따라서 아래와 같이 익스플로잇의 개념을 설계할 수 있다.

> 충분히 많은 format string을 사용하여 스택에 접근할 수 있도록 한 뒤, 마지막으로 사용된 `%n` format string이 참조할 스택 위치에 `target` 변수의 주소가 들어가도록 한다면 `%n` 은 결론적으로 `target` 변수의 값을 이제까지 받은 character의 수로 변조하게 될 것이다.
> 

말로만 하니 이해가 힘들 수 있다. 그림을 보면서 이해해 보자.

**주의:** `argv[1][0]` 은 사실 아래 그림과 같은 식으로 존재하지 않는다. 아무래도 이중 배열이니 `argv[0]` 이 진짜로 있는 곳 바로 아래에 `argv[1]` 이 있고, 그게 가리키는 곳에 `argv[1][0]` 이 있을 거라… `main` 의 스택 프레임 내부에서 `argv[1][0]` 이 보일 리가 없다. 그러나 설명의 용이를 위해 아래와 같이 그린 점 감안해 주십사…

![Untitled](/assets/img/posts/format1/Untitled%201.jpeg)

 `vuln` 함수가 콜되었을 때의 스택 프레임이다. 함수를 시작할 때 패스했던 인자의 시작 주소는 이중 배열인 `argv` 의 두 번째 인덱스에 저장되고, 이 시작 주소 `argv[1][0]` 은 `vuln()` 함수에게 인자로 전달된다. 

![Untitled](/assets/img/posts/format1/Untitled%202.jpeg)

그리고 `vuln()` 스택 프레임 안에서 `printf()` 함수를 콜했을 때의 스택 프레임이다. `printf()` 에게 첫 번째 인자로 주어진 `string`, 실제로는 `argv[1][0]` 가 포인터의 형태로 `rdi` 에 들어간 것을 확인할 수 있다.

![Untitled](/assets/img/posts/format1/Untitled%203.jpeg)

그렇다면 `format1` 프로그램에게 인자로 `%5$p.%4$x.$n` 을 준다면 어떻게 될까? 아래 사진은 읽어들인 내용이 모두 보이도록 `%{int}${format}` 의 형식을 취하지 않았고, 균일한 형식으로 보이게 하기 위해 동일한 `%p` 포맷 스트링을 사용했으나 개수를 기준으로 설명하겠다.

![Untitled](/assets/img/posts/format1/Untitled%204.jpeg)

![Untitled](/assets/img/posts/format1/Untitled%205.jpeg)

직전의 스택 프레임 사진을 고려하면 

- 출력할 스트링의 시작주소를 담고 있는 `rdi` 를 제외한 나머지 5개의 레지스터에 저장된 값을 `%p` 포맷 스트링이 읽어들이고
- 스택에 저장된 값을 `fastcall` calling convention에 따라 `printf`의 `rbp(sfp)` 를 뛰어넘어서 바로 아래에 있던 `vuln()`의 스택 4개 주소를 `%x`가 읽어온 것(스택 사진과 값이 다른 점이 있으나 이건 다른 시점에 찍어서 그렇다. `printf` 가 `vsprintf` 를 내부적으로 콜하고 그 안에서 stdout이 이루어지는 것 같은데 거기까지 가서 찾기는 좀… 그래…)
- 조금 논외로, `vuln()` 의 스택 프레임을 그린 사진과 바로 위에서 확인되는 실제 스택 프레임의 구조가 다른데, 내가 알기로는… 컴파일 당시 컴파일러는 최적화를 위해 로컬변수선언이 안된 함수의 경우 외부에서 받아온 인자를 굳이 스택에 저장하지 않는데 왜 저장했는지 모르겠다. 이걸 어디에서 찾아야 할지 감이 안 와

을 확인할 수 있다. 

따라서 마지막에 사용된 `%n` 은 `0x7fffffffdfa0` 주소 안에 있는 값을 메모리 주소로 생각하고 해당 주소에 자신이 나오기 전까지 출력됐던 글자수를 입력할 것이다.

즉, 이 익스플로잇의 요지는 아래와 같다.

> `%n` 이 읽어올 메모리 주소 안의 값이 `target` 변수의 주소가 되도록 하는 것.
> 

위의 목적은 사용자가 변조할 수 있는 유일한 위치, 즉 `argv[1][0]` 에 `target` 변수의 주소를 주고 `%n` 이 `argv[1][0]` 에 접근하게 함으로써 성취할 수 있다.

그렇다면, `argv[1][0]` 은 대체 어디에 있고 얼마나 많은 스택의 주소를 읽어야 `%n` 이 `argv[1][0]` 에 접근할 수 있을까?

이를 알기 위해 pwndbg를 붙여 main을 디스어셈블해서 전체적인 흐름을 파악하고 실제로 실행해서 스택 구성이 어떻게 되었는지 확인해 보았다.

![main 함수의 디스어셈블 결과.](/assets/img/posts/format1/Untitled%206.jpeg)

main 함수의 디스어셈블 결과.

하얗게 하이라이트가 된 부분이 바로 `argv[0][0]` 의 위치다. 바로 위의 `rbp-0x4` 는 확보한 공간으로 미루어볼 때 int type인 argv일 것이다. 그렇다면 `argv[1][0]` 은 아마 `argv[0][0]` 의 바로 다음 바이트에 있을 것이다. `argv` 는 `char **` 타입이기 때문이다. 그렇다면 당연히 확보 공간도 1바이트겠지!

![Untitled](/assets/img/posts/format1/Untitled%207.jpeg)

`rbp-0x10` 이 `rsp` 의 위치인 것을 확인했다. 이중배열답게 두 번 참조한 모습이다. 따라서 `argv[1]` 은 `0x7fffffffe088` 의 바로 다음 주소인 `0x7fffffffe090` 일 것이다. 그리고 해당 주소에 담긴 값이 바로 `argv[1][0]` 일 테다.

![Untitled](/assets/img/posts/format1/Untitled%208.jpeg)

`0x7fffffffe3f0` 이 `argv[1][0]` 의 주소임을 확인했다. 해당 주소에 정말로 내가 인자로 입력했던 문자열이 저장되어 있는지 확인해 보았다.

![Untitled](/assets/img/posts/format1/Untitled%209.jpeg)

확인 완료!

현재 ASLR이 꺼져 있기 때문에, 스택의 위치는 고정이다. 따라서 앞서 확인했던 ‘스택이 참조될 때 가장 먼저 참조되는 주소’는 `0x7fffffffdf80` 으로 고정일 것이다.

즉, `0x7fffffffdf80` 에서부터 시작해 `0x7fffffffe3e8` 까지를 참조해야 마지막에 올 `%n` 은 `0x7fffffffe3f0` 을 참조할 수 있을 것이다.

(`0x7fffffffe3e8`  -  `0x7fffffffdf80`)/8 = 141이다. 메모리 한 주소가 1byte짜리이기 때문에 1byte씩을 읽어 오는 포맷 스트링 몇 개가 필요한지 알아내기 위해 8로 나누었다.

즉, 만약 5개의 레지스터 + 142개의 주소를 읽어 온다면 맨 마지막에 내가 입력해준 문자열인 ‘AAAAAAAA’가 확인될 것이다. 예상이 맞는지 직접 프로그램에 인자를 주어 실행해 보았다.

![Untitled](/assets/img/posts/format1/Untitled%2010.jpeg)

어? 내 입력값을 읽어온 건 맞는데…. 처음 4바이트가 잘렸다. 왜지?

![Untitled](/assets/img/posts/format1/Untitled%2011.jpeg)

아하… 입력값 길이가 달라지면 문자열의 시작 주소도 달라지는 모양이다.(이걸 보고 스택의 높이가 변한다고 하고(참), root 계정으로 파이썬 익스플로잇을 만들어야 스택의 높이가 변하지 않는다고 하더라(확인되지 않음. 정말 카더라임) )

시작 주소 차이가 -3만큼 나고 문자열의 길이 차이가 +3만큼 나는 걸 생각하면 끝 주소를 고정해 놓은 것으로 추측된다. 그렇다면 어차피 근사한 위치이기 때문에 실제 익스플로잇 페이로드를 넣어보면서 오차를 좁히는 것이 가장 효율적인 방안일 것이다. 

충분히 수학적으로 계산해서 정확하게 읽어야 할 주소의 개수를 구할 수 있을 것 같은데 왜 굳이 삽질을 하냐는 의문이 들 수 있다. 그런데 계산이 더 삽질이다… 마지막에 서술해 두었다.

아무튼, 근사치를 구해 보면,

![Untitled](/assets/img/posts/format1/Untitled%2012.jpeg)

아무래도 뒤의 A 4개 대신 `target`의 주소를 넣는 게 맞을 것 같다. `target`의 주소는 objdump를 떠서도 구할 수 있는데, 나는 pwndbg를 이용해 구했다.

![Untitled](/assets/img/posts/format1/Untitled%2013.jpeg)

`0x0060103c`인 것으로 확인되었다.

![Untitled](/assets/img/posts/format1/Untitled%2014.jpeg)

64비트 환경에서 포인터 타입의 데이터는 1byte로 인식되기 때문에, `0x000000000060103c` 를 입력값으로 넣을 수 있도록…. 했는데

.

.

.

.

.

.

불가능하다는 것을 확인받았다. argument로 null byte를 전달하는 방법이… 없더라… input으로 전달이라면 얼마든지 어떻게든 해볼 수 있었겠지만 argument로 전달하는 건 진짜 안 되더라. 다른 분들께 물어보니 그건 0이 필수로 포함되는 64비트 환경에서는 안 되는 문제라는 답을 받을 수 있었다.

그치만 이 문제를 64비트에서 해결하실 수 있는 분… 꼭 연락 주세요. 분명히 방법이 있을 텐데….
<br><br>


# 3. 논외-수학적으로 읽어야 할 주소 개수 구하기를 시도했는데 고려한 변수가 한두개가 아니라 포기한 건에 대하여

웹소설 제목 st 소제목 기막히죠

length=x(null 제외) 문자열을 넣었을 때

![Untitled](/assets/img/posts/format1/Untitled%2015.jpeg)

문자열의 끝 주소: 0x7fffffffe401인데 null이 여기 오는 거 감안하면 0x7fffffffe400을 끝 주소로 봐도 무방함 

따라서 문자열의 시작 주소는 0x7fffffffe400-(x-1)

{0x7fffffffe400-(x-1) - 0x7fffffffdf80}/8 = 문자열의 시작 주소까지 읽어야 하는 주소의 수

{1152-(x-1)}/8 = 144-(x-1)/8

따라서 입력한 문자열이 null byte 제외 x글자일 때, 해당 문자열의 시작이 나오도록 하기 위해 읽어야 하는 주소의 수는 `144-(x-1)/8` 이다.

예를 들어 ‘AAAAAAAA..%5$x..%{3자리_수}$p…’ 면 25글자이기 때문에 들어가야 하는 3자리 수는 144-(25-1)/8 = 144-24/8 = 144-3 = 141 이다.

즉, ‘AAAAAAAA..%5$x..%141$p…’ 를 입력해야 한다. 

그러나 논리상 맞는데 이상하게 오차가 생겼다. 왜인지 확인해 보니…

![Untitled](/assets/img/posts/format1/Untitled%2016.jpeg)

입력값 길이가 달라지면… 달라진 입력값 길이/8 을 올림한 만큼…. 스택은 더 위로 이동하는 것 같았다. 이곳저곳에 조언을 구해 보니, 입력값이 늘어나면 늘어날수록 시스템이 더 큰 공간을 할당해 주고, 거기에 문제가 없도록 여유 공간 또한 주기 때문에 스택 프레임의 위치가 더 위로 이동하게 된다고 하더라. (아래 그림과 위 그림 비교)

![Untitled](/assets/img/posts/format1/Untitled%205.jpeg)

그래서 그것까지 계산하느니 그냥 근사값 가지고 때려 맞추는 게 더 나을 것 같아서 수학적 계산은 그만뒀다.