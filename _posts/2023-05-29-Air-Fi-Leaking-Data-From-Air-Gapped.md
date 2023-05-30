---
layout: post
title: '[논문 스터디] Air-Fi: Leaking Data From Air-Gapped Computers Using Wi-Fi Frequencies'
summary: Air-gap break using DDR-SDRAM
author: TouBVa
date: '2023-05-29 16:59:23 +09'
category: ['paper_study', 'network_hacking']
thumbnail: /assets/img/posts/hello.jpg
keywords: Air-Gap break
usemathjax: true
permalink: /blog/paper_study/air-fi
---

* TOC
{:toc}

<br>

# 마인드맵 정리본
<div style="position: relative; width: 100%; height: 0; overflow: hidden; padding-bottom: 80%;">
<iframe src="https://xmind.app/embed/iUU64D" style="position: absolute; top:0; left:0; width:100%; height: 100%; max-width: 1080px; max-height: 720px;" frameborder="0" scrolling="no"></iframe></div>

<br>

# 들어가기에 앞서

<br>

이번에 읽은 논문은 <mark> AIR-FI: Leaking Data From Air-Gapped Computers Using Wi-Fi Frequencies </mark> (저자: Mordechai Guri)이다. 저작권을 존중해 최대한 쉬운 말로 개념을 설명하는 선에서 글을 끝낼 것이다. 원문을 보고 싶다면, [이쪽](https://ieeexplore.ieee.org/document/9808153)에서 구독이나 구매 혹은 대학생 신분을 입증하고 무료로 pdf를 받아 보길 바란다.

학교에서 교수님께 추천받아 읽은 논문인데, 정말 글을 잘 썼다는 생각이 들어 읽으면서 writing에 대해 다시 생각해 보게 된 논문이다. 근데 이 교수님은 추천해 주시는 논문마다 수작이더라… 어떻게 찾으셨어요 물어보고 싶다

원래는 취미로 논문을 읽는데, 아니 이렇게 말하니까 되게 이상한데 근데 힘들여 읽는 게 아니고 전체를 이해하는 선에서 간단히 끝내는 식으로… 흥미가 가는 주제만 골라서… 그런 거라 정말 취미 독서 수준이다. 아무튼 이렇게 가볍게 읽고 넘겨버리니까 묘하게 휘발성인 느낌이라 앞으로 한 편 읽을 때마다 독후감을 남기기로 했다.

(이번 논문은 기말고사 프로젝트 용으로 추천받은 거라 조원들과 공유하려고 더 세세하게 썼다)

개인적으로 피지컬 레이어가 포함된 보안 관련 연구를 좋아해서 더 재밌게 읽었다. 특히 사이드 채널 어택은 너무나도 인디아나 존스의 보물찾기 느낌이라 좋아한다구!

<br><br>

# Sec3) 공격 모델: 이원적

<br>

## 개요

<br>

- Transmitter가 CPU-DDR SDRAM 간 데이터 전송을 조절한다(RAM 모델명이 DDR4-x라고 치면 x는 최대 몇 MHz로 데이터를 보낼 수 있는지를 의미한다. 따라서 순정 상태일 때 어떤 램이 방출하는 전자기파는 x MHz다).
    
    → 이는 CPU의 오버클럭, 언더클럭으로 조정한다.
    
- 해당 데이터 버스에서 데이터가 전기 신호로 오갈 때마다 방출되는 전기 신호의 주파수를 2.4GHz 와이파이 채널 대역과 맞추어 와이파이 신호로서 해독될 수 있게 한다.
- 그렇게 방출된 와이파이 신호를, 다양한 아키텍처 레이어에서 조작한 와이파이 Receiver를 이용해 해독하여 Usable한 데이터 포맷으로 만든다.

<br>

## Transmitter

<br>

> Air-gapped workstation
> 

<br>

## Receiver

<br>

> Transmitter가 Wi-fi signal emission 하면 그걸 받아챙기는 Wi-fiable 디바이스
> 

<br><br>

# Sec4) DDR SDRAM, Wi-Fi 배경지식 (다들 알 것 같아서 생략)

<br>

(그치만 혹시나 하는 마음에 간략하게 써둠)

DDR4-2400이라고 하면 2400MHz로 데이터를 전송할 수 있는 거고, 이때 데이터 버스에서는 2400MHz 주파수의 전자기파가 발생한다. 여기에 착안하여 데이터 버스에 데이터가 오고가는 속도를 조절해서 2.4Ghz 와이파이 대역의 채널에 데이터 버스에서 발산되는 주파수를 맞출 수 있지 않을까 하게 된 게 아이디어의 핵심이다. 이후 논문에는 CPU 클럭과 DDR-SDRAM의 대역폭 간의 관계를 안다는 전에 하에 설명이 이어지기 때문에, 만일 이해가 힘들 것 같다면 관련 개념을 훑어보고 오는 것을 추천한다.

Wi-Fi는 현재 802.11b/g/n이 제일 많이 쓰이는데, 이들은 와이파이 대역폭을 14개의 채널로 나누고 각 채널은 20MHz의 대역폭을 가진다. 보통 1~13 채널까지는 각 채널 간에 5MHz의 공간을 두고 배치되고, 13채널과 14채널은 12MHz의 공간을 두고 배치된다. 이 14개 채널 중 전세계에서 공통으로 사용 가능한 채널은 1~11채널인 11개 채널뿐이다.

<br><br>

# Sec5) Sender(transmissin) 입장의 기작

<br>

## 5.1. Signal Generation

<br>

### 5.1.1. 전자기 신호 방출

<br>

- **Persistent Emission**
    
    : 그냥 언제나 방출되는 전자기 신호.
    
- **Triggered Emission**
: 데이터 버스에서 데이터가 오고갈 때만 발생하는 전자기 신호로, 이 논문의 익스플로잇에 사용됨

<br>

### 5.1.2. Wi-Fi 신호를 어떻게 생성할 것인가?

<br>

- **Memory Operations**
    
    : 요즘 DDR SDRAMS 전송속도가 802.11b/g/n 채널 주파수 대역에 걸쳐 있어서 가능한 방법. 데이터 버스에 데이터가 오고가는 걸 이용함
    
- **Memory Operations + Clocking**
: 만약 CPU 클럭이 못 받쳐주면 CPU 클럭을 BIOS/UEFI로 조정해서(이걸 손대는 악성코드 되게 많음) 버스에서 와이파이 대역과 일치하는 주파수의 전자기파가 방출되게 만듦

<br>

### 5.1.3. Wi-Fi 채널 간섭 현상은 어떻게 해결할 것인가?

- 2.44000 GHz 대역으로 데이터를 방출한다고 치면 채널 5~8에 모두 걸치는 대역이 되는데, 이는 타이밍 변수를 조절해서 한 채널만을 이용한 데이터 전송을 구현할 수 있으니 해결된다. 실제로 802.11b/g/n 의 채널별로 맞추어서 신호 송신을 해냈음.

<br>

## 5.2. **Signal Modulation**

<br>

- 언제:
Wifi standard상으로 한 비트를 읽는 데 들이는 시간인 Bit time 동안
- 전송하려는 데이터가 1이면:
데이터를 array에서 array로 옮기며 버스에서 전자기파가 방출되게 한다.
- 전송하려는 데이터가 0이면 :
아무것도 하지 않는다. 주파수를 맞추기 위하여 PWM(Pulse-Width Modulation) 기술을 사용해서 푸리에 변환을 통해 캐리어 파동(연속파동)상에 직사각파(펄스파, 불연속파동)를 구현한다.
- 캐싱은 어떻게 피하는가?:
1이 n 번 전송되면 array를 randomize 한다.
아니면 몇 개 array를 사용해서 그 중 사용할 array를 랜덤하게 선택하든가.
- 멀티코어 구조를 이용할 수도 있음. governor 쓰레드의 통제를 받는 멀티스레딩을 통해서 한번에 발산하는 전자기파가 중첩이 되어 신호가 더 강해지게 하는 것.

<br>

## 5.3. **Data Transmission**

<br>

- 패킷 구조는 어떻게 구성할 것인가?
    - Pre-amble: 패킷들을 구분하기 위한 헤더
    - Payload: 모두가 아는 그것
    - Error Detection: CRC-8 사용함

<br>

# Sec6) Receiver 입장의 기작

<br><br>

## 6.1. 개요

<br>

해커는 Receiver의 물리 레이어로 들어오는 raw data를 가져와야 한다. 이는 manufacturer가 기본 제공하는 UI를 사용해서도, WiFi 칩의 드라이버나 펌웨어를 변조해서도 가능하다. 이렇게 가져온 raw data를 소프트웨어 스택으로 던져주면 디코딩 등의 과정을 거쳐 usable data 가 된다.

<br>

## 6.2. Physical Layer에 접근 가능한 Wifi 스택의 레이어

<br>

### 6.2.1. Application Layer (user-level)

<br>

- **설명:**
Command-line tools, Userspace APIs(Linux OS), Device I/O control(Windows OS)
을 통해 커널에서 유저애플리케이션으로 데이터 전송
- **공격 시나리오:**
공격자가 디바이스의 루트 권한 탈취
WiFi 물리 레이어 모니터링용 프로세스나 스레드 시작
쉘코드 인젝션이나 쓰레드 인젝션을 통해 프로세스 인젝션을 수행해 보안 기능 회피

<br>

### 6.2.2. Device-Drivers Layer (kernel-layer)

<br>

- **설명:**
보통 칩셋들은 물리 레이어로 들어온 정보를 디바이스 드라이버(커널 레벨에서 돌아감)에게 토스함.
보통 물리 레이어로 들어온 정보를 ioctl 커맨드로 받아감.
- **공격 시나리오:**
공격자가 디바이스를 원격으로 익스함
권한 상승 기법으로 커널스페이스에 코드 인젝션
인젝션된 코드가 와이파이 모듈에서 직접 정보를 쿼리해 오거나, 아니면 와이파이 드라이버를 변조하거나 replace해서 원하는 대로 동작하게 함

<br>

### 6.2.3. Firmware-Level

<br>

- **설명:**
임베디드 기기들이 와이파이 칩 관리에 펌웨어를 사용함. 그리고 보통 이 펌웨어는 OS를 탑재함. 즉 와이파이 칩 내부에서 모든 레이어의 연산이 이루어짐.
- **공격 시나리오:**
공격자가 디바이스를 원격으로 익스함.
와이파이 펌웨어를 변조함(이때 커널스페이스를 돌리고, 펌웨어 파일 시스템을 변조할 수 있는 루트 권한이 필요해 매우 높은 수준의 기술이 필요함)

<br>

### 6.2.4. Attack Surface 설정

<br>

- 방법 1은 업자들이 다 엠바고를 걸어서 정보가 없음. 따라서 방법 2와 방법 3이 유효함. 방법 3은 정말 높은 수준의 기술이 필요하지만 공격자들은 할 수 있음.

<br><br>

# Sec7) 실제 실험 방식 (차후 수정본에서 업로드)

<br>

(지금 이걸 구조화해서 쉽게 쓰기엔 배고파서 못하겠다… 밥먹고 할래 근데 엄청난 지점: VM상에서도 가능하다는 것. 피지컬 레이어가 복합된 VM 익스라고도 부를 수 있을 듯)

<br><br>

# Sec8) Countermeasures (차후 수정본에서 디테일 업로드)

<br>

## 8.1. 물리적 분리

<br>

- TEMPEST 쓰라는 말이다.

<br>

## 8.2. Runtime Detection

<br>

<br>

## 8.3. Memory Access Monitor

<br>

<br>

## 8.4. Wi-Fi Monitoring

<br>

<br>

## 8.5. Signal Jamming(H/W)

<br>

<br>

## 8.6. Signal Jamming(S/W)

<br>

<br>

## 8.7. Faraday Shielding

<br>

<br>