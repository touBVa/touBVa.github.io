---
layout: post
title: 'Dreamhack-Reversing-Chaining 문제 풀이'
summary: Chaining 문제 풀이
author: TouBVa
date: '2023-08-31 13:05:23 +09'
category: ['reversing']
thumbnail: /assets/img/posts/chaining/Untitled.png
keywords: IPSec, IKE
usemathjax: true
permalink: /blog/paper_study/reversing/chaining
---

* TOC
{:toc}

# Dreamhack Chaining 문제 풀이

주어진 바이너리를 실행해 보면 아래와 같은 화면이 출력된다.

![Untitled](/assets/img/posts/chaining/Untitled.png){: width="100%" height="100%"}

Password로 알맞은 값을 줘야 pass가 뜰 것이고, 그건 플래그값이 될 것이다.

일단 바이너리의 data섹션에 저장된 string을 불러오는 부분이 있을 것이고, 해당 스트링을 띄우는 함수 내부에서 input값이 올바른 값인지 체크하는 부분이 있을 것임을 유추할 수 있다.

# 0. 바이너리 포맷 분석

## 0.1. 파일에 적용된 보호 기법 및 엔트리 확인

![Untitled](/assets/img/posts/chaining/Untitled%201.png){: width="100%" height="100%"}

1. 해당 파일에는 모든 보호 조치가 적용되어 있고, PIE(바이너리가 업로드되는 메모리 영역이 매번 달라져서 plt나 got 접근을 통해 라이브러리 함수의 절대 주소를 알아내는 기법을 차단함)및 Full RELRO(got overwrite를 차단함)가 적용되어 있다.
2. 또한 Stripped되어 있어 함수나 변수 등의 심볼이 전부 없어져 있다.
3. 이런 경우, 함수의 엔트리가 어디인지 알아내야 이후 리버싱이 편하다. readelf로 헤더 정보를 읽어낸 결과, 엔트리 오프셋은 `0x10a0`임을 확인했다.

## 0.2. 엔트리의 함수 확인

IDA를 사용해 엔트리에 어떤 함수가 정의되어 있는지 확인한다.

![Untitled](/assets/img/posts/chaining/Untitled%202.png){: width="100%" height="100%"}

start로 정의되어 있고, 내부에서 libc_start_main을 콜함을 확인했다. 이 함수의 첫 번째 인자인 rdi에 들어간 주소가 main함수의 주소이므로, main을 찾아낼 수 있었다.

![Untitled](/assets/img/posts/chaining/Untitled%203.png){: width="100%" height="100%"}

main의 내부에서는 sub_34D7을 콜함을 확인했다.

그런데 조금 이상하다. `sub_34D7(rbp+var_18, rbp+var_10), var_18과 var_10은 모두 특정 ptr과 관련 있음`은 대체 무슨 뜻인지 모르겠기 때문이다… 심지어 저 ptr이 뭔지도 알 수 없다. 따라서 gdb를 붙여서 직접 어떤 인자가 들어가는지 확인해 보려 한다.

![Untitled](/assets/img/posts/chaining/Untitled%204.png){: width="100%" height="100%"}

일단 엔트리 상에서 메인함수를 콜하는 부분을 찾았다.

![Untitled](/assets/img/posts/chaining/Untitled%205.png){: width="100%" height="100%"}

그리고 메인함수를 보니 IDA로 찾았던 메인함수의 인스트럭션과 일치함을 확인할 수 있었다.

아하! IDA에서 보였던 ptr 변수는 main 스택프레임의 rbp였다. 해당 바이너리가 stripped되었기 때문에 생긴 현상으로 보인다.

# 1. 행위기반 정적 디버깅

일단 여기까지 하고, 앞서 추측했던 점-내부에 저장된 문자열이 출력되는 함수와 사용자 입력값 verification 부분이 밀접할 것이라는 점-이 맞는지 확인해 보기로 했다.

![Untitled](/assets/img/posts/chaining/Untitled%206.png){: width="100%" height="100%"}

아마 good:) 부분이 올바른 코드 플로우겠지

![Untitled](/assets/img/posts/chaining/Untitled%207.png){: width="100%" height="100%"}

xref lookup을 이용해 해당 문자열을 참조하는 코드섹션으로 이동했다.

![Untitled](/assets/img/posts/chaining/Untitled%208.png){: width="100%" height="100%"}

해당 문자열을 출력하는 기능을 발견했고, 함수가 정의되어 있지 않아 함수로 정의해 주었다.

여기에서부터 문제를 푸는 방법을 고려해 보았으나, 다 stripped되어 있으므로 역으로 따라가는 것은 힘들어 보인다. 따라서 `password:` 를 출력하는 부분부터 순차적으로 따라가 보기로 했다.

`sub_19C4`에서 시작하는 함수에서 `password:` 문자열을 참조하고 있음을 확인했지만, 정작 프린트하는 함수는 없어 보인다.

애초에 해당 함수는 굉장히 이상해 보이는데, 이유는 아래와 같다.

첫째, 분명히 `password:` 문자열을 가져와 사용하는데 이걸 pseudo-function으로 바꿔 보면 그런 부분이 전혀 보이지 않는다. 즉 IDA가 인지할 수 없는 형태로 코드가 짜여져 있다.

![Untitled](/assets/img/posts/chaining/Untitled%209.png){: width="100%" height="100%"}

둘째, 이전의 문자열 출력 함수들에서 주로 보였던 puts 등의 출력 함수를 콜하는 부분이 보이지 않는다. 실제로 pwndbg의 rop를 이용해 찾은 call 가젯 중 오프셋 `0x193C`이상 `0x34CE` (0x00005555555559C4~0x00005555555574CE) 범위에 해당되는 것은 없었다.

![Untitled](/assets/img/posts/chaining/Untitled%2010.png){: width="100%" height="100%"}

셋째. 그렇다면 상기 조건을 모두 충족할 때, 여기에서 syscall write on console이 가능한 이유는 뭘까? 사실 당장은 모르겠다.

일단 접근법을 결정해 보자. 현재 목표는 `good:)`를 출력하기 전에, 사용자 입력값 verification 과정을 찾아내는 것이다. 이를 위해 역순으로 접근했으나 함수 간의 연결성이 확보되지 않아 스트링을 근거로 `password:` 를 출력하는 부분부터 찾아 이후 함수의 행위를 확인함으로써 함수 간의 연결성을 확보하려는 시도 중이다.

이를 위해 첫째, syscall이 수행되기 위해 필수적인 가젯을 찾아본다. 둘째, 동적으로 디버깅하며 syscall write가 수행되는 지점에 bp를 건다. 두 가지 접근이 가능하다. 

단, 현재 문제를 푸는 과정이므로 두 번째 방식으로 접근해 빠르게 `password:`를 출력하는 부분을 찾고 이후 어떤 함수가 실행되는지 체크해야 한다.

# 2. 동적 디버깅

## 2.1. main 이후 실행되는 함수: sub_34D7

![Untitled](/assets/img/posts/chaining/Untitled%2011.png){: width="100%" height="100%"}

일단 앞에서 찾았던 지점을 정리하고 `password:`를 출력하는 부분을 찾자.

IDA에서 sub_34D7을 콜하는 지점으로 확인됐던 지점에 bp를 걸고 실행해 보았다.

![Untitled](/assets/img/posts/chaining/Untitled%2012.png){: width="100%" height="100%"}

저거 너무 string같은 포맷인데… 실제로 확인해 보니 스트링이 맞다.

![Untitled](/assets/img/posts/chaining/Untitled%2013.png){: width="100%" height="100%"}

저런 문자열을 보통 받는 함수가 있나? 그건 이후 찾아봐야 할 문제 같다.

일단 `sub_34D7(”\177ELF\002\001\001\003”, “\177ELF\002\001\001”)` 인 점은 체크해두자.

![Untitled](/assets/img/posts/chaining/Untitled%2014.png){: width="100%" height="100%"}

이후 `sub_19C4(”\177ELF\002\001\001\003”, “\177ELF\002\001\001”)` 를 한다.

## 2.2. sub_19C4 내부에서 password: 를 출력하는 부분 체크

pwndbg 내부에는 특정 시스콜이 실행될 때 코드플로우를 멈춰 주는 기능이 있다.

따라서 `catch syscall write` 옵션을 주고 프로그램을 실행시켜 보았다.

![Untitled](/assets/img/posts/chaining/Untitled%2015.png){: width="100%" height="100%"}

전혀 상관 없는 함수 내부의 syscall 인스트럭션을 실행하는 부분에서 멈췄다. 현재 rsi에 `input` 이 들어가 있고, 아래 스택에 `password:` 가 들어가 있는 것을 보아 실제로 `input password:` 를 콘솔에 뿌려 주는 부분인 것이 맞는 것 같다.

여기에서 rip가 멈춰 있는 함수는 vmmap으로 확인한 결과 기본 라이브러리 함수였다. 

![Untitled](/assets/img/posts/chaining/Untitled%2016.png){: width="100%" height="100%"}

아하! 그럼 주어진 바이너리는 rop를 이용해 만든 바이너리임을 추측할 수 있다. 원래 바이너리의 코드부가 아닌 멀쩡한 라이브러리 함수의 코드부에서도 특정 목적을 위한 인스트럭션으로 점프한 것을 그 근거로 들 수 있다. 또한 콜스택에 유의미한 콜러-콜리 정보가 없는 대신 스택에 가젯들이 들어가 있는 것을 그 그 근거로 들 수 있겠다.

그럼 이제 해당 행위가 끝나고 리턴할 지점은 콜스택이 아니라 프로세스 스택에 저장되어 있을 것이다. 즉 pwndbg가 제공하는 backtrace로는 리턴할 callee를 찾아낼 수 없다.

![Untitled](/assets/img/posts/chaining/Untitled%2017.png){: width="100%" height="100%"}

따라서 스택을 분석해 보았다. 그 결과 알아낸 점은 아래와 같다.

1. 사이에 2개 값들이 용처가 정확하지 않게 비어 있다. 이것들이 어떻게 되는지는 쭉 따라가면서 찾아봐야 할 텐데, 중간의 0xbeefbeefbeefbeef는 누가 봐도 바이너리에서 넣어 준 값 같다. 매우 특징적인 값이므로 따라가볼 만하다고 생각한다.
    - 찾아보니, 정말로 바이너리에 있었다. 오프셋 `0x202e`에서 진행되는 행위였다.
        
        해당 지점은 스택에 rop chain을 저장하는 기능에 포함되어 있었다.
        
        ![Untitled](/assets/img/posts/chaining/Untitled%2018.png){: width="100%" height="100%"}
        
2. 사용자 입력값을 저장하는 버퍼로 0x55555555a800를 사용하고 있다. 디버거상에서 해당 메모리를 참조할 때마다 멈추도록 설정한 다음 프로그램을 돌리면 어떤 행위가 일어나는지, 그리고 그 행위는 어떤 함수에서 수행되는지 알 수 있을 것 같다.
    - 행위 분석 및 함수 복원
        
        ![Untitled](/assets/img/posts/chaining/Untitled%2019.png){: width="100%" height="100%"}
        
        ![Untitled](/assets/img/posts/chaining/Untitled%2020.png){: width="100%" height="100%"}
        
        bp가 트리거되었을 때 컨텍스트. 앞선 read/write를 끝내고 오프셋 0x1215로 돌아와 다른 행위를 하는데, 사용자 입력값이 저장된 버퍼에 어떤 행위를 했다.
        
        어떤 행위를 했는지 IDA로 확인해 보니, 아래와 같았다. 
        
        ![Untitled](/assets/img/posts/chaining/Untitled%2021.png){: width="100%" height="100%"}
        
        사용자 입력값이 저장된 버퍼에 rax의 하위 32비트(al)을 저장했다.
        
        해당 기능은 IDA기준 `sub_1215` 함수의 일부로 정의되어 있다. 해당 함수를 가상코드로 변환해 보면 영 이상하다. 어셈블리와 비교하며 올바른 루프문으로 바꿔주면 아래와 같다.
        
        ![Untitled](/assets/img/posts/chaining/Untitled%2022.png){: width="100%" height="100%"}
        
        반복할 횟수를 a1으로 받아(아마 문자열의 길이일 것이고, 앞에서 봤던 스택을 생각하면 0x40일 것이다), 사용자 입력이 저장된 버퍼에 대해 a3와 xor연산을 한다.  a3는 전달받을 당시 edx로 전달되며 이후 버퍼에 저장된 첫 글자부터 xor되는 int값이다.  앞에서 봤던 스택과, 동적으로 디버깅했을 때 0x41과 xor된 값이 0x5라는 점을 감안하면 0x44가 인자로 주어지는 것 같다. 따라서 `sub_1215`를 복원하면 아래와 같다.
        
        `sub_1215(0x40, char *buf, 0x44)`: does xor every chars in user input with 0x44
        
3. 또한 해당 바이너리의 코드 영역에 해당하는 주소가 중간에 2개 존재하는데, 이는 특정 행위를 마치고 코드 플로우가 돌아갈 부분을 의미하는 것 같다. 실제로 동적으로 디버깅해 보니 `0x1215` 이후 `0x1268`이 실행됨을 확인할 수 있었다. 두 주소를 IDA에서 확인해 보니 아래와 같았다.
    - 0x1215 함수는 이미 복원했으므로 0x1268만 다루겠다.
        
        ![0x1268의 루틴](/assets/img/posts/chaining/Untitled%2023.png){: width="100%" height="100%"}
        
        0x1268의 루틴
        
    
    ![0x1268의 pseudo-code](/assets/img/posts/chaining/Untitled%2024.png){: width="100%" height="100%"}
    
    0x1268의 pseudo-code
    
    해당 함수가 실행되는 순간의 레지스터는 아래와 같았다.
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2025.png){: width="100%" height="100%"}
    
    즉 `0x1268(0xe5119cf0, 0xddc615f0, 0x7851327a, 0x84a7815a, char *buf)`이다.
    
    그렇다면 이 함수는 어떤 기능을 할까? 일단 사용자 인풋이 저장되는 주소인 `0x55555555a800` 과는 아무런 상호작용이 없다는 점에서 입력과는 독립적인 무언가를 행하는 부분일 것이다.
    
    아마 느낌상 `0x55555555a900`이 모종의 단계를 거쳐 변화한 값이 저장되는 부분일 것이고…
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2026.png){: width="100%" height="100%"}
    
    그리고 실제로도 맞는 것 같다. 그럼 대체 뭘 변화시킨 걸까?
    
    사실 감이 안 온다. 그럼 일단 넘어가고, 다음에 실행되는 함수를 분석해 보자.
    
    해당 함수를 총 3회 정도 추가로 수행하고 다음 함수로 넘어감을 확인했다. 그 때의 `0x55555555a900` 은 다음과 같았다. (참고: 어떤 함수를 몇 번 수행할지는 스택을 보면 알 수 있다. ROP chaining을 통해 이미 스택에 코드 플로우가 다 들어가 있기 때문이다. 따라서 동적 디버깅을 할 때 왜 똑같은 함수로 들어가는 거지? 싶으면 스택을 보면 된다.)
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2027.png){: width="100%" height="100%"}
    

## 2.3. sub_1447 분석

현재까지의 흐름은 아래와 같다.. 

`main` → `sub_34d7` → `sub_19c4`(rop chaining) → `sub_1215` → `sub_1268` * 4

이후 실행되는 함수는 `sub_1447`이었다. 해당 함수의 기능을 알아보자.

IDA 상에서는 함수로 인식되지 않기 때문에, 내가 직접 함수로 설정해줘야 한다. create function 기능을 이용해 함수로 만들어 주었다.

![Untitled](/assets/img/posts/chaining/Untitled%2028.png){: width="100%" height="100%"}

해당 함수는 두 개의 인자를 받는데, 첫 번째가 user input이 저장된 부분이고 두 번째가 `sub_1268`에서 만들어준 값이 저장된 부분이다. 여기에서 user input이 변화할 것임을 추측할 수 있다.

또한 우리는 `sub_1268`에서 모종의 값을 변화해 저장하면서 16바이트의 공간에 16회 접근한 것을 알고 있다. 즉, 1바이트를 배열의 한 인덱스에 저장되는 값으로 취급했음을 알고 있다. 이를 기반으로 IDA에서 출력해 주는 가상함수를 수정하면 아래와 같다.

![Untitled](/assets/img/posts/chaining/Untitled%2029.png){: width="100%" height="100%"}

아하… sub_1268에서 만들어준 값 배열은 위치 지정자였음을 알 수 있다. 일종의 테이블 아닐까? SPN 네트워크 구조에서 보이는 Permutation 구조를 반영한 것 말이다. 즉 user input 내부의 순서를 마구 바꿔서 다시 user input에 저장하는… 그런 것 같다.

따라서 나는 `sub_1447`을 `after_password_3_Permutation_sub_1447`로 네이밍했고, `sub_1268`을 `after_password_2_making_permutation_table_sub_1268`로 네이밍했다.

sub_1447을 복원하면 아래와 같다.

`sub_1447(char *buf, int8 *table)`: Does Permutation on user input(buf)

이제 다른 함수로 넘어가 보자. 그 전에, 이 함수를 총 몇 회 수행하는지 체크했다.

![Untitled](/assets/img/posts/chaining/Untitled%2030.png){: width="100%" height="100%"}

총 4회 수행한다. (usr_input의 0~15, 16~31, 32~47, 48~63 인덱스에 대해 차례로 table의 첫 바이트부터 참고하여 permutation을 수행하는 것이라 어느 쪽으로 옮겨진 게 또 다른 쪽으로 옮겨질 수도 있다.)

## 2.4. sub_14ed 분석

현재까지의 흐름은 아래와 같다

`main` → `sub_34d7` → `sub_19c4`(rop chaining) → `sub_1215` → `sub_1268` * 4 → `sub_1447` *4

이쯤에서 사용자 input은 어떻게 됐는지 보자. 아 그런데 나는 입력값을 알파벳 하나로 통일해서… permutation이 안 잡힐 것 같긴 하다….

![Untitled](/assets/img/posts/chaining/Untitled%2031.png){: width="100%" height="100%"}

그리고 역시 안 잡혔다. 하지만 permutation이 진행된 것이다…!!!!!!

음 입력값의 permutation이 더 확실히 잡히는 게 나을 것 같아 다른 값을 주고 재실행했다.

입력값: 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@!

sub_1447(permutation) 수행 전

![Untitled](/assets/img/posts/chaining/Untitled%2032.png){: width="100%" height="100%"}

sub_1447(permutation) 수행 마무리 후

![Untitled](/assets/img/posts/chaining/Untitled%2033.png){: width="100%" height="100%"}

IDA에서는 sub_14ed 또한 함수로 인식하지 못하므로 create function 해줬다.

![Untitled](/assets/img/posts/chaining/Untitled%2034.png){: width="100%" height="100%"}

여기에서 전달되는 두 개의 인자는 무엇인지 확인해 보았다.

![Untitled](/assets/img/posts/chaining/Untitled%2035.png){: width="100%" height="100%"}

rsi로는 user input buffer의 시작주소가 들어가 있는 것을 확인했다.

rdi에는 이전까지 보지 못했던 주소가 들어가 있다. 해당 주소에 뭐가 있는지 확인해 보니 아래와 같았다. 

![Untitled](/assets/img/posts/chaining/Untitled%2036.png){: width="100%" height="100%"}

user input에 영향을 받는 부분일까? 알고 싶어 다시 한 개 알파벳으로만 통일한 값을 줘 보았으나, 변동은 없었다. 이것도 모종의 테이블 같다. (0xa060은 오프셋 0x6060으로 정답값이 들어있는 64바이트 배열이다)

![Untitled](/assets/img/posts/chaining/Untitled%2037.png){: width="100%" height="100%"}

어셈블리에서 1바이트 단위로 테이블에서 값을 가져와 xor 연산을 하고 있다는 점을 감안해 IDA의 가상함수를 수정하니 아래와 같았다.

![Untitled](/assets/img/posts/chaining/Untitled%2038.png){: width="100%" height="100%"}

또 xor이다! 

즉 sub_14ed를 복원하면 아래와 같았다.

`sub_14ed(char *table, char *buf)` : table의 1 byte를 buf의 1byte와 xor해 buf에 저장한다.

## 2.5. sub_15bb 분석

혹시나 해서 다시 언급한다. 이 문제는 stack-based rop chaining으로, 다음에 무슨 함수가 실행될지는 스택을 쭉 펼쳐보면 알 수 있다. 동적으로 디버깅하는 코드 플로우와 스택을 비교해 가면서 지금 내가 맞는 위치에 있는지 꼭 확인하자!

![Untitled](/assets/img/posts/chaining/Untitled%2039.png){: width="100%" height="100%"}

어셈블리까지 감안해 보았을 때, 해당 함수에 전달되는 파라미터는 하나로, user input이 저장된 buf의 시작주소인 것 같다.

그리고 가상코드로 변환한 IDA의 코드를 보면 다음과 같다.

![Untitled](/assets/img/posts/chaining/Untitled%2040.png){: width="100%" height="100%"}

buf에서 4k, 4k+1, 4k+2, 4k+3 (k=0, 1, … , 15) 번째의 원소별로 다른 알고리즘을 적용해 변환한다. 즉 substitution 연산을 한다.

이제 callee들을 분석해 보자.

### 2.5.1. sub_1545 (for 4k, 4k+2 elements)

전달되는 인자들의 type을 감안해 해당 함수에서 사용되는 파라미터들의 type을 수정해 주었다.

![Untitled](/assets/img/posts/chaining/Untitled%2041.png){: width="100%" height="100%"}

숫자 8을 기준으로 대칭이 되는 pair로 좌, 우에 대해 각각 시프트 연산을 한다는 의미는 다음과 같다.

1. 시프트 연산 대상의 자료형이 8bits 크기를 가진다.
    
    → 즉, 이 크기를 넘어가게 시프트를 시켜버리면 데이터가 완전히 소실된다.
    
2. 좌, 우에 대해 각각 x, y 비트만큼을 시프트시킬 때 x+y=8이고, 그 둘을 or 연산 한다.
    
    → or 연산의 의미는 데이터를 최대한 보존하겠다는 것이다.
    
    → 이는 좌로 x비트 순환 시프트 연산(==우로 y비트 순환 시프트 연산)을 시키겠다는 뜻이다.
    
3. 결론: 해당 함수는 우로 a2비트 순환 시프트 연산을 수행하는 함수다.

### 2.5.2 sub_1580 (for 4k+1, 4k+3 elements)

![Untitled](/assets/img/posts/chaining/Untitled%2042.png){: width="100%" height="100%"}

좌로 a2비트 순환 시프트 연산을 수행하는 함수다.

이제 분석이 끝났으니, 해당 함수의 끝에 bp를 걸고 다음 함수로 넘어가 보자. 

## 2.6. sub_16e0 분석

![Untitled](/assets/img/posts/chaining/Untitled%2043.png){: width="100%" height="100%"}

여기에서 IDA로 뺀 가상함수는 알아보기 힘들기 때문에 참고해서 재구성해야 한다.

해당 함수에 진입하기 전에 수행된 함수가 epilogue를 수행한 직후의 스택을 확인하자(stack-based rop chaining이므로 전달되는 파라미터가 const인지 확인하려면 스택을 봐야 한다)

![Untitled](/assets/img/posts/chaining/Untitled%2044.png){: width="100%" height="100%"}

pop rsi를 통해 함수의 두 번째 인자로 전달될 값이 무조건 고정임을 확인했다. (offset이 0x0011이고, 이후 이것의 하위 1바이트를 사용하므로)

또한 어셈블리를 보고 함수를 재구성한 결과 복원된 함수는 아래와 같음을 확인했다.

```c
sub_16e0(char *buf, const int x) // x==0x11
{
	for(i=0;i<=63;i++)
	{
		buf[i] += 0x11
	}
}
```

즉 카이사르 치환 암호화를 적용했다.

## 2.7. sub_172e 분석

그 다음에 실행되는 함수는 sub_172e였다. 해당 함수 프롤로그 실행될 당시의 context를 보자.

![Untitled](/assets/img/posts/chaining/Untitled%2045.png){: width="100%" height="100%"}

어셈블리로부터 인자가 단 하나만 들어갔고, 그 인자는 user_input의 시작 주소임을 알 수 있다.

이제 IDA로 디스어셈블한 코드를 보자.

![Untitled](/assets/img/posts/chaining/Untitled%2046.png){: width="100%" height="100%"}

굳이 더 부연하지 않고 넘어가야겠다. 중요한 건 이걸 복호화하는 코드를 만드는 일이고, 그를 위해서는 해당 연산에 xor만이 사용되었다, 즉 xor로 간단히 복호화 가능하다는 점만이 중요하기 때문이다.

## 2.8. sub_193c 분석

여기는 사용자의 입력이 정답이 아닐 경우 nop :( 를 출력해 주는 함수다. 해당 함수가 수행되기 직전의 스택 상태를 보면 다음과 같다.

![Untitled](/assets/img/posts/chaining/Untitled%2047.png){: width="100%" height="100%"}

그리고 sub_193c의 내용은 다음과 같다.

![Untitled](/assets/img/posts/chaining/Untitled%2048.png){: width="100%" height="100%"}

스택에 sub_193c가 먼저 나와 있고, sub_19a3이 다음으로 나와 있는 것, 그리고 후자에서 good:) 를 출력해 주는 것을 감안하면 저 if 문 안으로 들어가지 않고 return 되었을 때 good:) 가 출력될 것을 추측할 수 있다.

즉, byte_6060이 진짜 정답이 들어 있는 배열일 것이고, 64 바이트일 것이다.

해당 배열의 내용은 다음과 같다.

![Untitled](/assets/img/posts/chaining/Untitled%2049.png){: width="100%" height="100%"}

```c
27 63 72 73 43 3F 9F 43 2E F0 33 F3 1E 07 0A 33 E5 6C DB 5F C9 11 DE 62 42 18 FE 9B 8E 15 3A BB 96 DB 9E 23 FD 90 10 9B 8E 0A 89 47 BD 8E 88 D6 F9 B9 50 76 E1 0C 4F 89 54 9D B1 F1 A6 9B 8A 2C
```

그럼 이제 절반 왔다! 우리는 사용자의 입력값이 어떤 변환 과정을 거치는지 알고, 그 변환 결과가 어떤 값이 되어야 하는지도 알고 있다. 그럼 이제 복호화 프로그램을 만들어 보자.

# 3. 복호화 프로그램 만들기

앞선 과정을 다시 정리해 보자.

## 3.1. sub_1215: does xor every char in user input with 0x44

- `sub_1215(0x40, char *buf, 0x44)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2022.png){: width="100%" height="100%"}
    

## 3.2. sub_1268: make a permutation table

- `sub_1268(0xe5119cf0, 0xddc615f0, 0x7851327a, 0x84a7815a, char *buf)`
    
    table: (명령어: dump memory ./permutation_table.txt 0x55555555a900 0x55555555a940)
    
    ```c
    07 09 0E 01 0C 08 03 06 04 0A 02 0B 00 05 0F 0D 03 01 04 0A 02 06 0B 08 0F 09 0C 05 0E 00 0D 07 0A 0E 0D 04 05 06 08 03 0B 0F 09 01 0C 02 07 00 07 01 09 0A 05 06 0F 03 0D 02 0E 00 04 0C 08 0B
    ```
    

## 3.3. sub_1447: Does Permutation on user input(buf)

- `sub_1447(char *buf, int8 *table)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2029.png){: width="100%" height="100%"}
    

## 3.4. sub_14ed:  table의 1 byte를 buf의 1byte와 xor해 buf에 저장한다.

- `sub_14ed(char *table2, char *buf)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2038.png){: width="100%" height="100%"}
    
    사용된 테이블:
    
    ```c
    E9 10 8A 6D 2D 6C 45 61 0C F6 21 47 15 0E C8 25 9A E5 CA 53 18 07 F4 C3 FB 4C AC 34 31 38 D3 0A D5 22 0B C4 F5 F8 19 ED D0 42 F2 BE F8 4A 0B 37 B4 68 58 92 BB 47 E6 A5 4C 21 4D EC 8E 7A FA 2F
    ```
    

## 3.5. sub_15bb: buf에서 4k, 4k+1, 4k+2, 4k+3 (k=0, 1, … , 15) 번째의 원소별로 다른 알고리즘을 적용해 변환한다. 즉 substitution 연산을 한다.

- `sub_15bb(char *buf)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2040.png){: width="100%" height="100%"}
    

### 3.5.1. sub_1545: 우로 n비트 순환 시프트 연산을 수행하는 함수다. (for 4k, 4k+2)

- `sub_1545(char c, int n)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2041.png){: width="100%" height="100%"}
    

### 3.5.2. sub_1580: 좌로 n비트 순환 시프트 연산을 수행하는 함수다. (for 4k+1, 4k+3)

- `sub_1580(char c, int n)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2050.png){: width="100%" height="100%"}
    

## 3.6. sub_16e0: 카이사르 치환 암호화

- `sub_16e0(char *buf, const int x(0x11))`
    
    ```c
    sub_16e0(char *buf, const int x) // x==0x11
    {
    	for(i=0;i<=63;i++)
    	{
    		buf[i] += 0x11
    	}
    }
    ```
    

## 3.7. sub_172e

- `sub_172e(char *buf)`
    
    ![Untitled](/assets/img/posts/chaining/Untitled%2046.png){: width="100%" height="100%"}
    

## 3.8. sub_193c: 여긴 정답 배열과 input 배열을 대조하는 루틴이다.

- 정답 배열
    
    ```c
    27 63 72 73 43 3F 9F 43 2E F0 33 F3 1E 07 0A 33 E5 6C DB 5F C9 11 DE 62 42 18 FE 9B 8E 15 3A BB 96 DB 9E 23 FD 90 10 9B 8E 0A 89 47 BD 8E 88 D6 F9 B9 50 76 E1 0C 4F 89 54 9D B1 F1 A6 9B 8A 2C
    ```
    
- 디버거에서 뽑은 값은 그대로 복사하면 안된다. 리틀 엔디언이라 순서가 바뀌므로 IDA의 Hex view→범위저장→ HXD로 열어서 복사의 과정을 거치자.

# 4. 구현 및 결과

```c
#include<stdio.h>
#include<string.h>
#include<stdlib.h>
        
void rev1_sub_1215(int len, char *buf, int xor);

void rev2_sub_1447(char *buf, char *table);

void rev3_sub_14ed(char *table, char *buf);

void rev4_sub_15bb(char *buf);

unsigned char rev4_1_sub_1545(unsigned char c, int n);

unsigned char rev4_2_sub_1580(unsigned char c, int n);

void rev5_sub_16e0(char *buf, const int x);

void rev6_sub_172E(char* buf);

int main(){
    // will be parsed and appended to the table1
    unsigned char *tmp1 = "07 09 0E 01 0C 08 03 06 04 0A 02 0B 00 05 0F 0D 03 01 04 0A 02 06 0B 08 0F 09 0C 05 0E 00 0D 07 0A 0E 0D 04 05 06 08 03 0B 0F 09 01 0C 02 07 00 07 01 09 0A 05 06 0F 03 0D 02 0E 00 04 0C 08 0B";
    // will be parsed and appended to the table2
    unsigned char *tmp2 = "E9 10 8A 6D 2D 6C 45 61 0C F6 21 47 15 0E C8 25 9A E5 CA 53 18 07 F4 C3 FB 4C AC 34 31 38 D3 0A D5 22 0B C4 F5 F8 19 ED D0 42 F2 BE F8 4A 0B 37 B4 68 58 92 BB 47 E6 A5 4C 21 4D EC 8E 7A FA 2F";
    // will be parsed and appended to the answer
    unsigned char *tmp3 = "27 63 72 73 43 3F 9F 43 2E F0 33 F3 1E 07 0A 33 E5 6C DB 5F C9 11 DE 62 42 18 FE 9B 8E 15 3A BB 96 DB 9E 23 FD 90 10 9B 8E 0A 89 47 BD 8E 88 D6 F9 B9 50 76 E1 0C 4F 89 54 9D B1 F1 A6 9B 8A 2C";
    
    //parsing 
    int tmp_len1 = 64;
    unsigned char *table1 = (unsigned char *)malloc(tmp_len1 * sizeof(unsigned char));
    unsigned char *table2 = (unsigned char *)malloc(tmp_len1 * sizeof(unsigned char));
    unsigned char *flag = (unsigned char *)malloc(tmp_len1 * sizeof(unsigned char));

    for(int i=0, j=0; i<tmp_len1;i++, j+=3){
        unsigned char hexByte[3]={'0'};
        hexByte[0] = tmp1[j];
        hexByte[1] = tmp1[j + 1];
        hexByte[2] = '\0';
        table1[i] = (unsigned char)strtol(hexByte, NULL, 16);
        //printf("table1[%d]: %ldbyte, \\x0%x\n", i, sizeof(table1[i]), table1[i]);
    }

    for(int i=0, j=0; i<tmp_len1;i++, j+=3){
        unsigned char hexByte[3]={'0'};
        hexByte[0] = tmp2[j];
        hexByte[1] = tmp2[j + 1];
        hexByte[2] = '\0';
        table2[i] = (unsigned char)strtol(hexByte, NULL, 16);
        //printf("table1[%d]: %ldbyte, \\x0%x\n", i, sizeof(table1[i]), table1[i]);
    }

    for(int i=0, j=0; i<tmp_len1;i++, j+=3){
        unsigned char hexByte[3]={'0'};
        hexByte[0] = tmp3[j];
        hexByte[1] = tmp3[j + 1];
        hexByte[2] = '\0';
        flag[i] = (unsigned char)strtol(hexByte, NULL, 16);
        //printf("table1[%d]: %ldbyte, \\x0%x\n", i, sizeof(table1[i]), table1[i]);
    }

    rev6_sub_172E(flag);

    rev5_sub_16e0(flag, 0x11);

    rev4_sub_15bb(flag);

    rev3_sub_14ed(table2, flag);
    printf("14ed output: \n");
    for(int i =0;i < 64; i++) printf("0x%02x ", flag[i]);
    printf("\n");

    rev2_sub_1447(flag+48, table1+48);
    rev2_sub_1447(flag+32, table1+32);
    rev2_sub_1447(flag+16, table1+16);
    rev2_sub_1447(flag, table1);
    printf("1447 output: \n");
    for(int i =0;i < 64; i++) printf("0x%02x ", flag[i]);
    printf("\n");

    rev1_sub_1215(tmp_len1, flag, 0x44);

    printf("%s", flag);

}

void rev1_sub_1215(int len, char *buf, int xor){
    for(int i=0;i<len;i++){
        *(buf+i)^=xor;
    }
}

void rev2_sub_1447(char *buf, char *table){
    char tmp[16]={'0'};
    for(int i=0;i<16;i++){
        tmp[i]=*(buf+*(table+i));
    }

    for(int j=0;j<16;j++){
        *(buf+j) = tmp[j];
    }

}

void rev3_sub_14ed(char *table2, char *buf){
    for(int i = 0;i<64;i++){
        buf[i]^=table2[i];
    }
}

void rev4_sub_15bb(char *buf){
    for(int i = 0; i<64; i+=4){
        buf[i] = rev4_1_sub_1545(buf[i], 5);
    }
    
    for(int i = 1; i<64; i+=4){
        buf[i] = rev4_2_sub_1580(buf[i], 7);
    }

    for(int i = 2; i<64; i+=4){
        buf[i] = rev4_1_sub_1545(buf[i], 3);
    }

    for(int i = 3; i<64; i+=4){
        buf[i] = rev4_2_sub_1580(buf[i], 2);
    }
}

unsigned char rev4_1_sub_1545(unsigned char c, int n){ // 4k, 4k+2nd elements
    return ((c << n) | (c >> (8-n)));
}

unsigned char rev4_2_sub_1580(unsigned char c, int n){ // 4k+1, 4k+3rd elements
    return ((c >> n) | (c << (8-n)));
}

void rev5_sub_16e0(char *buf, const int x){
    for(int i =0;i<64;i++){
        if(buf[i]>=x) buf[i] -= x;
        else buf[i] = 0xff-(x-buf[i]-1); // 0x00~0xff hence, 0xff+1 == 0x00
    }
}

void rev6_sub_172E(char* buf)
{
    char i; // [rsp+16h] [rbp-2h]
    char k; // [rsp+16h] [rbp-2h]
    char ii; // [rsp+16h] [rbp-2h]
    char mm; // [rsp+16h] [rbp-2h]
    char j; // [rsp+17h] [rbp-1h]
    char m; // [rsp+17h] [rbp-1h]
    char n; // [rsp+17h] [rbp-1h]
    char jj; // [rsp+17h] [rbp-1h]
    char kk; // [rsp+17h] [rbp-1h]
    char nn; // [rsp+17h] [rbp-1h]

    for (i = 63; i >= 48; i--)
    {
        for (nn = 47; nn >= 0; nn--)
            buf[nn] ^= buf[i];
            buf[nn] = buf[nn] & 0xFF;
    }

    for (ii = 47; ii >= 32; ii--)
    {
        for (kk = 63; kk >= 48; kk--)
            buf[kk] ^= buf[ii];
            buf[kk] = buf[kk] & 0xFF;
        for (jj = 31; jj >= 0; jj--)
            buf[jj] ^= buf[ii];
            buf[jj] = buf[jj] & 0xFF;
    }

    for (k = 31; k >= 16; k--)
    {
        for (n = 63; n >= 32; n--)
            buf[n] ^= buf[k];
            buf[n] = buf[n] & 0xFF;
        for (m = 15; m >= 0; m--)
            buf[m] ^= buf[k];
            buf[m] = buf[m] & 0xFF;
    }

    for (i = 15; i >= 0; i--)
    {
        for (j = 63; j >= 16; j--)
            buf[j] ^= buf[i];
            buf[j] = buf[j] & 0xFF;
    }
}

```

이것저것 시행착오를 거친 끝에 정답을 구할 수 있었다.

정말 중요한 사실: char 타입은 음수가 될 경우 출력이나 연산에 사용 시 자동으로 int type로 전환되어 사용된다. 이걸 몰라서 한참 헤맸다.

따라서 음수가 되는 경우를 무시하고 0x00~0xff 범위 내부를 순환하도록 하고 싶다면 char가 아닌 unsigned char로 정의하고, 함수에 인자를 전달할 때에도 반드시 해당 형식으로 전달해야 한다.

파이썬으로 작성했다면 훨씬 편했을 텐데… 하…. 포인터를 쓰고 싶어서 C 언어로 작성하는 바람에 type 관련해서 정말 힘들었다.

문제 정말 어렵더라. 더 화이팅 해보자!