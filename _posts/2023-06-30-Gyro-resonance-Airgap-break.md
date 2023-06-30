---
layout: post
title: '[논문 재현] Gyroscope 센서의 공진을 이용한 Airgap Break 논문 재현 프로젝트(1)'
summary: Breaking airgap using resonance frequency of a smartphone gyroscope sensor.
author: TouBVa
date: '2023-06-30 15:53:23 +09'
category: ['paper_study', 'network_hacking']
thumbnail: /assets/img/posts/gyro/Untitled.png
keywords: Airgap Brek
usemathjax: true
permalink: /blog/paper_study/airgap-break-using-gyro-resonance
---

* TOC
{:toc}

<br>

# 0. 배경지식

Reproduce 타겟 논문은 “GAIROSCOPE: Injecting Data from Air-Gapped Computers to Nearby Gyroscopes”로, [여기](https://arxiv.org/abs/2208.09764)에서 다운받을 수 있다.
이 프로젝트는 논문을 오류가 많은 방식으로 재현했다. 조만간 팀원과 함께 논문의 원래 방식대로 재현해서 정리글을 올리려 하니 그것도 많은 기대 부탁!!

<br>

## 0.1. Gyroscope?

<br>

### 0.1.1 자이로스코프의 원리

<br>

![Untitled](/assets/img/posts/gyro/Untitled.png){: width="80%" height="80%"}

<br>

1. 핸드폰에는 주로 MEMS 센서가 사용된다.
2. 총 6개의 축이 있으나 그 중 3개가 중요하다; x, y, z
3. 이 중 x축과 y축은 실존하며, z축은 가상의 개념이다
    1. x축은 Sensing Direction
    2. y축은 Driving Direction 으로 칭한다.
4. 센서에는 Proof mass라는 물질이 발려 있다(사진의 파란색)
    1. 이 물질은 미세전류의 영향 하에 y축 방향으로 진행한다.
    2. 이 때, z축에 대해 $$\Omega$$의 각속도로 센서가 회전할 경우 코리올리 효과로 인해 x축으로의 가속력이 발생한다.
    3. 기본은 이러한 x축, y축의 각속도 값을 이용해 센서의 위상을 알아내는 것이다.
    4. 그러나 x축 방향으로의 움직임에서 관성력과 원심력 요소를 감안해 제거해야 한다.
    5. 이를 위해 proof mass를 하나 더 발라두고 y축 정반대 방향으로 진행케 해 잡음 신호를 상쇄시킨다. (위 사진에서 파란색 사각형이 두 개인 이유)

<br>

### 0.1.2. 디지털 자이로스코프가 주는 신호의 의미

<br>

자이로스코프 센서 (둘 다 time domain 신호 발생)

- 아날로그 센서
    - 시간 축에 대해 특정 진동수로 특정 전압을 발생시킴으로써 위상의 변화를 알린다.
- 디지털 센서
    - 시간 축에 대해 rad/sec, 즉 자이로스코프의 x, y, z 축에 대한 회전의 각속도 값을 전달함으로써 위상의 변화를 알린다.

<br>

### 0.1.3. 해당 신호를 실험에 사용할 수 있는 이유

<br>

- 자이로스코프의 공진을 다룬 논문 “Vulnerability of MEMS Gyroscopes to Targeted Acoustic Attacks”
    - 여기에서 사용하는 신호는 아날로그 센서의 ‘전압’
    - 그러나 우리가 사용해야 하는 신호는 디지털 센서의 ‘rad/s’
        
        → 디지털 센서가 주는 값을 공진 탐지에 사용할 수 있는가?
        
        → ‘전압’과 ‘rad/s’는 비례하는가?
        
        → 아날로그 센서는 $$\Omega$$에 비례해 전압을 발생, 디지털 센서는 $$\Omega_{axis}$$에 비례해 dps(degree per second)/LSB(최소비트변화) 발생
        
        → 즉, 디지털 센서가 주는 값을 공진 탐지에 사용할 수 있다(각속도를 매개변수로 사용하여 아날로그의 신호와 디지털의 신호 간 비례관계를 밝힐 수 있기 때문). 그러나, x, y, z축 중 어느 축이 영향을 받았는지 구분해 내야 한다.
        

<br>

## 0.2. 공격 시나리오

<br>

이원적 구조(에어갭으로 분리된 망의 PC, 데이터를 읽어들일 스마트폰)

1. 공격자는 에어갭으로 분리된 PC에, 파일을 바이너리로 읽어 와 음파로 변환해 출력하는 프로그램을 설치
    1. 이는 웹 페이지의 JS로도 구현이 가능함
    2. 해당 프로그램이 출력하는 음파는 특정 스마트폰 기종에 설치된 자이로스코프의 공진을 일으킴
    3. 또한 그 음파는 비가청대역 주파수로 이루어져 있음
2. 자이로스코프의 공진 여부를 감지해 바이너리 데이터로 변환하는 프로그램이 설치된 핸드폰을 음파가 닿을 수 있는 책상에 놓고 앱 실행
3. 에어갭으로 분리된 네트워크상에 존재하는 데이터가 핸드폰으로 전송

<br>

<br>

# 1. 연구 방법

<br>

먼저 최대한 소스 코드를 찾아 봤지만, 아무것도 나오지 않았다.

따라서 Transmitter의 소스 코드의 일부는 논문에 쓰인 코드를 참고해 새로 만들었고,

Receiver의 소스 코드는 순서도부터 계획해 만들었다.

<br>

## 1.1. 공진주파수?

<br>

이 익스플로잇의 핵심은 특정 기종 핸드폰에 탑재된 자이로스코프 센서가 공진하는 주파수 대역을 찾아내는 것이다.

<br>

### 1.1.1. 공진 대역을 찾기 위해…

<br>

1. 핸드폰 제조 회사에 문의
    
    → 시스템 칩 팀의 기밀사항으로 알려줄 수 없다는 거절
    
2. 주파수 대역을 Brute-Forcing
    - 우리가 가진 기기는 삼성 SM-A605K (Galaxy Jean, 2018)
    - 논문에 소개된 자이로스코프 센서들은 아래와 같다:
        
        ![Untitled](/assets/img/posts/gyro/Untitled%201.png){: width="80%" height="80%"}
        
    - 이 중 디지털 센서에서 공진이 발생한 대역은
        - 7,900~20,000 Hz
        - 25,000~29,000 Hz
    - 일반적인 스피커는 20,000Hz 대역 주변부까지를 커버할 수 있다
    - 따라서 첫 번째 구간을 Brute-Forcing하기로 결정

<br>

### 1.1.2. 결과

<br>

normal-status (아무 주파수도 없을 때 일반적인 양상)

![Untitled](/assets/img/posts/gyro/Untitled%202.png){: width="80%" height="80%"}

- 들어오는 값의 오차를 없애기 위해 초당 다회 값을 읽어 오는 자이로스코프의 특징을 이용했다
    - 2초동안 특정 주파수를 생성하고, 동일 타임스탬프 하에 기록된 값들의 평균치를 구함
    - 2초마다 주파수가 50Hz씩 높아지는 특징을 이용, 타임스탬프를 Hz로 변환해 그래프의 X축을 구성하게끔 함
- 이 과정에서 20120Hz ~20200Hz 부근에서 공진주파수를 찾아냄
- 정확한 공진주파수 대역을 좁히기 위해 Hz 변이폭을 10Hz로 두고, 동일 실험을 5회 진행

<br>

1회차 실험
    
![Untitled](/assets/img/posts/gyro/Untitled%203.png){: width="80%" height="80%"}
    

<br>

2회차 실험
    
![Untitled](/assets/img/posts/gyro/Untitled%204.png){: width="80%" height="80%"}
    

<br>

3회차 실험
    
![Untitled](/assets/img/posts/gyro/Untitled%205.png){: width="80%" height="80%"}
    

<br>

4회차 실험
    
![Untitled](/assets/img/posts/gyro/Untitled%206.png){: width="80%" height="80%"}
    

<br>

5회차 실험
    
![Untitled](/assets/img/posts/gyro/Untitled%207.png){: width="80%" height="80%"}
    

<br>

- 실험 결과
    - 20150Hz와 20170Hz가 공진주파수 대역으로 좁혀졌다.
    - 가운데 20160Hz가 공진주파수 대역이 아닌 이유는,
        - 자이로스코프가 자체적으로 오류를 방지하기 위해 자이로스코프가 의도치 않은 노이즈에 의해 일정 정도 이상으로 떨릴 경우 신호 필터링을 거는데(논문에서는 이걸 가리켜 10Hz 로우컷이라 칭한다)
        - 그로 인해 노이즈가 발생하는 부근의 한중간에서 신호 발생 그래프가 푹 꺼지는 Dip이 발생하기 때문이다.
        - 즉 20160Hz는 Dip 구간이므로 사용할 수 없는 공진대역.

<br>

## 1.2. Transmitter: Air-gapped computer

<br>

1. 지정된 파일의 데이터를 읽어와 형식에 맞는 패킷을 만든다.
    1. Preamble(4 bit) + Payload(8 bit) + Parity(1 bit)
    2. Preamble은 1010으로, 이를 이용해 Receiver는 한 비트에 할당된 출력 시간을 인지하고, 뒤이어 패킷 바디가 들어올 것을 예상한다.
2. 패킷의 바이너리를 미리 알아 둔 공진주파수에 대응시킨다.
3. 해당 기능을 구현한 코드 부분(일부 잘라옴) :
    
    ```python
    paudio = pyaudio.PyAudio()
    vol = 0.5
    sr = 48000
    duration = 0.625
    mark_frequency = 20150  # 1
    space_frequency = 20400 # 0
    
    # Read file and convert to binary data
    with open('testfile', 'rb') as file:
        content = file.read()
    binary_data = np.unpackbits(np.frombuffer(content, dtype=np.uint8))
    binary_data = list(make_packet(binary_data, 8))
    
    print(binary_data)
    modulated_signals = modulate_data(binary_data, mark_frequency, space_frequency, sr, duration, vol)
    
    for modulated_signal in modulated_signals:
        time.sleep(1.5)
        ostream = paudio.open(format=pyaudio.paFloat32, channels=1, rate=sr, output=True)
        ostream.write(modulated_signal.tobytes())
        ostream.close()
        
    paudio.terminate()
    ```
    
4. 일반적인 BFSK는 고주파를 1, 상대적 저주파를 0에 대응시키지만, 우리는 반대로 했다.
    - 이하 ‘Carrier Frequency’
5. 수신자 측의 CPU가 오차 없이 인식할 수 있는 시간 동안 Carrier Frequency를 쏴주기 위해, 부동소수점 표기로 정확히 표현이 가능한 0.625($$101_{(2)}$$) 초를 Carrier Frequency 의 BitTime으로 결정했다.
6. 발생하는 최고 주파수가 20400이므로, 이를 표현하기 위해서는 2배인 40800 이상의 샘플레이트가 필요하다. 따라서 샘플레이트는 48000Hz로 결정했다.

<br>

## 1.3. Receiver: Smartphone

<br>

이쪽은 코드를 긁어와 설명하기엔 너무 길어서, 순서도로 기능을 설명한다.

<br>

![Untitled](/assets/img/posts/gyro/Untitled%208.png){: width="80%" height="80%"}

<br>

이후 바이너리 데이터는 아스키 코드로 변환하여 앱의 화면에 보여준다.

핸드폰을 책상 위에 놓고 스피커로 음파를 재생할 때, 자이로스코프 센서의 z축은 거의 영향을 받지 않고, x축과 y축이 크게 영향을 받는다는 점에 유념해 Magnitude를 구했다. 다만 논문과는 달리 데모를 재현한 우리 팀 특성상 x축과 y축의 magnitude 값을 합쳐 영향을 극대화해야 했다.

<br>

<br>

# 2. 결과 및 성능 평가

<br>

## 2.1. 데모 영상

<br>

<div style="position: relative; width: 100%; height: 0; overflow: hidden; padding-bottom: 80%;">
<iframe src="https://www.youtube.com/embed/MZGVMOy3WaA" style="position: absolute; top:0; left:0; width: 80%; height: 80%; max-width: 1080px; max-height: 720px;" frameborder="0" scrolling="no"></iframe></div>

<br>

## 2.2. 성능 평가

<br>

- 10cm 거리에서 N37WORk53CUR17Y! 를 전송한 결과 (1회차) - 에러율 0% 정확도 100%
    
    ```
    2023-06-21 15:53:51.129  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 15:53:51.729  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 15:53:51.729  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 15:53:52.380  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 15:53:52.980  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:53:52.980  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:53:53.631  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:53:54.281  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:53:54.939  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:53:55.590  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:53:56.241  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:53:56.892  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:53:57.540  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:53:58.200  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:53:58.851  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:53:58.900  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01001110 = 78(N)
    2023-06-21 15:53:58.943  3194-3194  SH                      com.example.gyroscope                E  N
    2023-06-21 15:54:00.900  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:54:01.550  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:54:01.550  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:54:02.149  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:54:02.750  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:54:02.750  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:54:03.419  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:04.070  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:04.720  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:05.370  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:06.019  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:06.680  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:07.330  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:07.980  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:08.629  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:08.679  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110011 = 51(3)
    2023-06-21 15:54:08.722  3194-3194  SH                      com.example.gyroscope                E  3
    2023-06-21 15:54:10.731  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 15:54:11.330  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 15:54:11.330  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 15:54:11.981  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 15:54:12.579  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:54:12.579  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:54:13.230  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:13.880  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:14.529  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:15.190  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:15.840  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:16.489  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:17.140  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:17.789  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:18.449  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:18.500  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110111 = 55(7)
    2023-06-21 15:54:18.530  3194-3194  SH                      com.example.gyroscope                E  7
    2023-06-21 15:54:20.500  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:54:21.149  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:54:21.150  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:54:21.750  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:54:22.370  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:54:22.370  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:54:23.019  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:23.670  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:24.320  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:24.969  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:25.620  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:26.280  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:26.930  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:27.580  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:28.231  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:28.280  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010111 = 87(W)
    2023-06-21 15:54:28.322  3194-3194  SH                      com.example.gyroscope                E  W
    2023-06-21 15:54:30.290  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:54:30.939  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:54:30.939  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:54:31.549  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:54:32.161  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:54:32.161  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:54:32.810  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:33.461  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:34.110  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:34.760  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:35.410  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:36.060  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:36.710  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:37.359  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:38.019  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:38.070  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110000 = 48(0)
    2023-06-21 15:54:38.117  3194-3194  SH                      com.example.gyroscope                E  0
    2023-06-21 15:54:40.140  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:54:40.740  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 12
    2023-06-21 15:54:40.740  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 15:54:41.350  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:54:41.900  3194-3194  SH                      com.example.gyroscope                D  bitlen : 12
    2023-06-21 15:54:41.900  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:54:42.500  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:43.100  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:43.700  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:44.309  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:44.910  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:45.510  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:46.110  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:46.710  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:47.310  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:47.360  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010010 = 82(R)
    2023-06-21 15:54:47.411  3194-3194  SH                      com.example.gyroscope                E  R
    2023-06-21 15:54:47.610  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 5
    2023-06-21 15:54:48.010  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 8 5
    2023-06-21 15:54:49.913  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:54:50.560  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:54:50.560  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:54:51.159  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:54:51.760  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:54:51.761  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:54:52.410  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:53.069  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:53.720  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:54.370  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:55.020  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:55.670  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:54:56.320  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:56.969  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:57.629  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:54:57.679  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01101011 = 107(k)
    2023-06-21 15:54:57.710  3194-3194  SH                      com.example.gyroscope                E  k
    2023-06-21 15:54:59.730  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 15:55:00.380  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 13
    2023-06-21 15:55:00.380  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:55:00.980  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:55:01.589  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:55:01.589  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:55:02.249  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:02.899  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:03.559  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:04.210  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:04.870  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:05.520  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:06.170  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:06.820  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:07.470  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:07.520  3194-3194  SH                      com.example.gyroscope                E  Parity Check Failed
    2023-06-21 15:55:07.522  3194-3194  SH                      com.example.gyroscope                E  parseMessage: 
    2023-06-21 15:55:07.525  3194-3194  SH                      com.example.gyroscope                E  parseMessage: 
    2023-06-21 15:55:07.526  3194-3194  SH                      com.example.gyroscope                D  parseMessage:  = 0(??)
    2023-06-21 15:55:07.571  3194-3194  SH                      com.example.gyroscope                E  ??
    2023-06-21 15:55:09.530  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 15:55:10.139  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 15:55:10.139  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 15:55:10.740  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:55:11.340  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:55:11.340  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:55:11.989  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:12.639  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:13.309  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:13.959  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:14.639  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:15.289  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:15.939  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:16.589  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:17.239  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:17.289  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110101 = 53(5)
    2023-06-21 15:55:17.313  3194-3194  SH                      com.example.gyroscope                E  5
    2023-06-21 15:55:19.339  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 15:55:19.939  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 15:55:19.939  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 15:55:20.590  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 15:55:21.200  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:55:21.200  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:55:21.849  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:22.509  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:23.159  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:23.809  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:24.459  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:25.119  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:25.770  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:26.420  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:27.070  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:27.120  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110011 = 51(3)
    2023-06-21 15:55:27.169  3194-3194  SH                      com.example.gyroscope                E  3
    2023-06-21 15:55:29.120  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:55:29.769  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:55:29.769  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:55:30.370  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:55:30.970  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:55:30.970  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:55:31.619  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:32.269  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:32.919  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:33.580  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:34.229  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:34.890  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:35.540  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:36.199  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:36.850  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:36.901  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01000011 = 67(C)
    2023-06-21 15:55:36.941  3194-3194  SH                      com.example.gyroscope                E  C
    2023-06-21 15:55:38.900  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:55:39.549  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:55:39.549  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:55:40.149  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:55:40.750  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:55:40.750  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:55:41.409  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:42.060  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:42.730  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:43.390  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:44.039  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:44.690  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:45.349  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:45.999  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:46.649  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:46.699  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010101 = 85(U)
    2023-06-21 15:55:46.719  3194-3194  SH                      com.example.gyroscope                E  U
    2023-06-21 15:55:48.700  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:55:49.349  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:55:49.350  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:55:49.950  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:55:50.550  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:55:50.550  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:55:51.200  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:51.850  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:52.500  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:53.149  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:53.809  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:54.460  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:55.120  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:55.770  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:55:56.421  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:55:56.470  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010010 = 82(R)
    2023-06-21 15:55:56.517  3194-3194  SH                      com.example.gyroscope                E  R
    2023-06-21 15:55:58.522  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 15:55:59.170  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 13
    2023-06-21 15:55:59.170  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:55:59.770  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:56:00.379  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:56:00.379  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:56:01.030  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:01.679  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:02.329  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:02.990  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:03.640  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:04.300  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:04.951  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:05.599  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:06.250  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:06.300  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110001 = 49(1)
    2023-06-21 15:56:06.336  3194-3194  SH                      com.example.gyroscope                E  1
    2023-06-21 15:56:08.300  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:56:08.951  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:56:08.951  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:56:09.561  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:56:10.161  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:56:10.161  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:56:10.810  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:11.460  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:12.110  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:12.759  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:13.419  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:14.070  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:14.720  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:15.370  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:16.029  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:16.080  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110111 = 55(7)
    2023-06-21 15:56:16.119  3194-3194  SH                      com.example.gyroscope                E  7
    2023-06-21 15:56:18.080  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:56:18.729  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:56:18.729  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:56:19.330  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:56:19.929  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:56:19.929  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:56:20.580  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:21.230  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:21.880  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:22.530  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:23.180  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:23.830  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:24.480  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:25.130  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:25.780  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:25.830  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01011001 = 89(Y)
    2023-06-21 15:56:25.866  3194-3194  SH                      com.example.gyroscope                E  Y
    2023-06-21 15:56:27.880  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 15:56:28.529  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 15:56:28.529  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 15:56:29.130  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 15:56:29.729  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 15:56:29.729  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 15:56:30.380  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:31.029  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:31.690  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:32.339  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:33.000  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:33.649  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:34.300  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:34.949  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 15:56:35.601  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 15:56:35.650  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00100001 = 33(!)
    2023-06-21 15:56:35.694  3194-3194  SH                      com.example.gyroscope                E  !
    ```
    
- 10cm 거리에서 N37WORk53CUR17Y! 를 전송한 결과 (2회차) - 에러율 6.25% 정확도 93.75%
    
    ```
    2023-06-21 16:06:18.370  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:06:18.970  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 12
    2023-06-21 16:06:18.970  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:06:19.619  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:06:20.220  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:06:20.220  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:06:20.871  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:21.521  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:22.180  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:22.830  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:23.480  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:24.139  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:24.790  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:25.439  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:26.090  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:26.139  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01001110 = 78(N)
    2023-06-21 16:06:26.173  3194-3194  SH                      com.example.gyroscope                E  N
    2023-06-21 16:06:28.189  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:06:28.790  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:06:28.790  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:06:29.390  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:06:29.990  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:06:29.990  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:06:30.639  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:31.289  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:31.939  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:32.599  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:33.259  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:33.909  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:34.560  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:35.209  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:35.870  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:35.920  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110011 = 51(3)
    2023-06-21 16:06:35.967  3194-3194  SH                      com.example.gyroscope                E  3
    2023-06-21 16:06:37.980  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:06:38.580  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:06:38.580  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:06:39.230  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:06:39.830  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:06:39.830  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:06:40.480  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:41.130  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:41.779  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:42.430  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:43.080  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:43.729  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:44.381  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:45.030  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:45.680  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:45.730  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110111 = 55(7)
    2023-06-21 16:06:45.772  3194-3194  SH                      com.example.gyroscope                E  7
    2023-06-21 16:06:47.740  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:06:48.389  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 16:06:48.389  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:06:49.040  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:06:49.640  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:06:49.640  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:06:50.290  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:50.940  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:51.589  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:52.239  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:52.891  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:06:53.539  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:54.193  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:54.839  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:55.500  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:06:55.550  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010111 = 87(W)
    2023-06-21 16:06:55.582  3194-3194  SH                      com.example.gyroscope                E  W
    2023-06-21 16:06:57.561  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:06:58.210  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 16:06:58.210  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:06:58.810  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:06:59.410  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:06:59.410  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:00.059  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:00.720  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:01.380  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:02.029  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:02.679  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:03.339  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:03.990  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:04.639  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:05.290  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:05.341  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110000 = 48(0)
    2023-06-21 16:07:05.378  3194-3194  SH                      com.example.gyroscope                E  0
    2023-06-21 16:07:07.360  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:07:08.010  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 16:07:08.010  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:07:08.610  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:07:09.209  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:07:09.210  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:09.859  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:10.510  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:11.159  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:11.813  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:12.470  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:13.119  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:13.769  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:14.429  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:15.089  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:15.139  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010010 = 82(R)
    2023-06-21 16:07:15.164  3194-3194  SH                      com.example.gyroscope                E  R
    2023-06-21 16:07:17.160  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:07:17.810  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 16:07:17.810  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:07:18.419  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:07:19.019  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:07:19.019  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:19.670  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:20.319  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:20.970  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:21.620  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:22.270  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:22.930  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:23.579  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:24.229  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:24.879  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:24.929  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01101011 = 107(k)
    2023-06-21 16:07:24.957  3194-3194  SH                      com.example.gyroscope                E  k
    2023-06-21 16:07:26.949  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:07:27.600  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 16:07:27.600  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:07:28.250  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:07:28.851  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:07:28.851  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:29.500  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:30.149  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:30.800  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:31.450  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:32.099  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:32.750  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:33.399  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:34.049  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:34.700  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:34.750  3194-3194  SH                      com.example.gyroscope                E  Parity Check Failed
    2023-06-21 16:07:34.752  3194-3194  SH                      com.example.gyroscope                E  parseMessage: 
    2023-06-21 16:07:34.755  3194-3194  SH                      com.example.gyroscope                E  parseMessage: 
    2023-06-21 16:07:34.756  3194-3194  SH                      com.example.gyroscope                D  parseMessage:  = 0(??)
    2023-06-21 16:07:34.796  3194-3194  SH                      com.example.gyroscope                E  ??
    2023-06-21 16:07:36.760  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:07:37.359  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 12
    2023-06-21 16:07:37.360  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:07:38.009  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:07:38.610  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:07:38.610  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:39.260  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:39.919  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:40.570  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:41.220  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:41.870  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:42.520  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:43.169  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:43.819  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:44.470  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:44.521  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110101 = 53(5)
    2023-06-21 16:07:44.546  3194-3194  SH                      com.example.gyroscope                E  5
    2023-06-21 16:07:46.570  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:07:47.221  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 12
    2023-06-21 16:07:47.221  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:07:47.821  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:07:48.419  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:07:48.419  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:49.070  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:49.720  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:50.370  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:51.020  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:51.670  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:52.320  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:52.970  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:53.620  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:07:54.269  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:54.319  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110011 = 51(3)
    2023-06-21 16:07:54.336  3194-3194  SH                      com.example.gyroscope                E  3
    2023-06-21 16:07:56.380  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:07:57.029  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 13 13
    2023-06-21 16:07:57.029  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 13
    2023-06-21 16:07:57.630  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:07:58.230  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:07:58.230  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:07:58.880  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:07:59.530  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:00.180  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:00.830  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:01.490  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:02.139  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:02.789  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:03.439  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:04.089  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:04.139  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01000011 = 67(C)
    2023-06-21 16:08:04.157  3194-3194  SH                      com.example.gyroscope                E  C
    2023-06-21 16:08:06.199  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:08:06.800  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:08:06.800  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:08:07.410  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:08:08.010  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:08:08.010  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:08:08.660  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:09.310  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:09.959  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:10.610  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:11.260  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:11.909  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:12.570  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:13.219  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:13.870  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:13.920  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010101 = 85(U)
    2023-06-21 16:08:13.937  3194-3194  SH                      com.example.gyroscope                E  U
    2023-06-21 16:08:15.920  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:08:16.620  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 14 12
    2023-06-21 16:08:17.230  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 12
    2023-06-21 16:08:17.979  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 15 12
    2023-06-21 16:08:19.079  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:08:19.680  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:08:19.680  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:08:20.339  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:08:20.939  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:08:20.939  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:08:21.590  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:22.239  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:22.900  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:23.549  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:24.210  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:24.859  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:25.509  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:26.170  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:26.820  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:26.870  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01010010 = 82(R)
    2023-06-21 16:08:26.898  3194-3194  SH                      com.example.gyroscope                E  R
    2023-06-21 16:08:27.029  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 3
    2023-06-21 16:08:27.330  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 6 3
    2023-06-21 16:08:30.150  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 25
    2023-06-21 16:08:31.550  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 28 25
    2023-06-21 16:08:33.210  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 24
    2023-06-21 16:08:34.560  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 27 24
    2023-06-21 16:08:35.559  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:08:36.160  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:08:36.160  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:08:36.809  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:08:37.410  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:08:37.410  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:08:38.060  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:38.709  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:39.360  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:40.009  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:40.660  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:41.310  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:41.959  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:42.610  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:43.260  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:43.310  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00110111 = 55(7)
    2023-06-21 16:08:43.343  3194-3194  SH                      com.example.gyroscope                E  7
    2023-06-21 16:08:45.369  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:08:45.981  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:08:45.981  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:08:46.590  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 12
    2023-06-21 16:08:47.190  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:08:47.190  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:08:47.840  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:48.490  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:49.161  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:49.810  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:50.459  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:51.110  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:51.760  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:52.419  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:53.070  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:53.120  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 01011001 = 89(Y)
    2023-06-21 16:08:53.154  3194-3194  SH                      com.example.gyroscope                E  Y
    2023-06-21 16:08:55.169  3194-3194  SH                      com.example.gyroscope                D  preamble: 0, len 13
    2023-06-21 16:08:55.770  3194-3194  SH                      com.example.gyroscope                D  tempbitlen: 12 13
    2023-06-21 16:08:55.770  3194-3194  SH                      com.example.gyroscope                D  preamble: 1, len 12
    2023-06-21 16:08:56.420  3194-3194  SH                      com.example.gyroscope                D  preamble: 2, len 13
    2023-06-21 16:08:57.021  3194-3194  SH                      com.example.gyroscope                D  bitlen : 13
    2023-06-21 16:08:57.021  3194-3194  SH                      com.example.gyroscope                D  DEMODULATE
    2023-06-21 16:08:57.673  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:58.320  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:08:58.981  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:08:59.632  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:09:00.280  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:09:00.929  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:09:01.580  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:09:02.229  3194-3194  SH                      com.example.gyroscope                D  new bit1
    2023-06-21 16:09:02.879  3194-3194  SH                      com.example.gyroscope                D  new bit0
    2023-06-21 16:09:02.929  3194-3194  SH                      com.example.gyroscope                D  parseMessage: 00100001 = 33(!)
    2023-06-21 16:09:02.962  3194-3194  SH                      com.example.gyroscope                E  !
    ```
    

<br>

→ 평균 에러율 3.125%, 평균 정확도 96.875%

<br>

<br>

# 3. 아쉬웠던 점

<br>

논문을 다른 방식으로 재현해야 했다.

<br>

1.  원본: 1과 0에 각각 다른 공진주파수(Dip으로 인해 공진주파수 대역은 2개가 된다)를 할당하여, 높은 주파수를 할당받은 비트에서 축이 더 자주 변동하며 값을 주는 것에 기초
    
    원본대로 할 때 진동수의 측정값: 고주파는 1, 저주파는 0으로, 진동 빈도의 변화를 이용해 0과 1을 구분한다. 이는 일반적인 DFSK에서 많이 사용하는 해석법이다.
    
    ![핸드폰에 자이로스코프의 값을 시각화해 주는 어플을 다운받아 실제로 높은 공진주파수와 상대적으로 낮은 공진주파수를 재생했을 때의 변화 양상이다. 이런 식으로 공진주파수의 Frequency를 다르게 줌으로써 비트를 구분할 경우 자이로스코프 신호의 주기가 바뀌므로 약 3m 떨어진 거리에서도 오차 없이 비트를 구분함을 알 수 있었다.](/assets/img/posts/gyro/Untitled.jpeg){: width="80%" height="80%"}
    
    핸드폰에 자이로스코프의 값을 시각화해 주는 어플을 다운받아 실제로 높은 공진주파수와 상대적으로 낮은 공진주파수를 재생했을 때의 변화 양상이다. 이런 식으로 공진주파수의 Frequency를 다르게 줌으로써 비트를 구분할 경우 자이로스코프 신호의 주기가 바뀌므로 약 3m 떨어진 거리에서도 오차 없이 비트를 구분함을 알 수 있었다.
    
2. 그러나 우리는 Time domain에서 센서의 축이 각속도의 변화를 알리는 이벤트가 얼마나 자주 발생하는지 알아오는 방법을 만들지 못했음.
    
    → 이 경우 java의 math3 라이브러리에서 FFT 메소드를 가져와 쓰면 되는데, 이것의 output이 무엇을 의미하는지 알지 못해 사용하지 못했다.
    
    → 인덱스가 파동의 주기라고는 하는데-푸리에 변환의 정의상으로 보면 그럴싸하기 때문에 신빙성이 있다고 판단한 정보다-, 해당 인덱스의 배열에 저장된 값이 대체 뭔지 모르겠다.
    
    → 아시는 분은 개인적으로 연락 부탁드립니다. 밑에 댓글란에….
    
3. 따라서 대안적으로 1에만 공진주파수를 할당하고, Preamble로부터 한 비트당 할당된 비트타임을 계산한 다음 미리 정의된 포맷으로 송신된 바이너리를 수신하는 전략을 사용
4. 이로 인해 가변거리에 따른 Threshold 설정이 새로운 문제 사항으로 대두
5. 그러나 이는 해결할 방법을 찾지 못했음
6. 이 경우 에러율을 줄이거나, 에러에도 robust하게 프로토콜을 변경하는 방법이 있음
7. 그 중 전자는 불가능에 가까움; 따라서 후자를 고려
8. 이 경우 대역폭이 좁고 오류가 빈번한 환경에서의 데이터 전송 방식을 참고하면 해결책을 찾을 수 있을 듯함(예. 전화선 통신 시의 에러 감수, 초기 와이파이 프로토콜에서의 데이터 전송)
    
    → 그러나 교수님의 조언에 따르면 우리가 사용하는 방식은 대역폭이 지나치게 좁은 관계로, 오류를 더블 체크 하거나… connection-oriented 방식을 쓰거나… 그런 게 불가능할 것 같다고 한다. 사실 동의함.
    

<br>

<br>

# 4. **참고문헌**

<br>

소스 코드는 팀원들의 동의를 얻지 못했기 때문에(그리고 이건 서울에서 부산을 가려고 개성이랑 베이징까지 갔다가 부산 옆 울산에 내린 수준이라) 비공개.

하지만 깃헙 레포 자체는 공개니까… (찡긋)

<br>

## 4.1. 논문 원본

<br>

“GAIROSCOPE: Injecting Data from Air-Gapped Computers to Nearby Gyroscopes”, Mordechai Guri

## 4.2. 참고 문헌

<br>

“Vulnerability of MEMS Gyroscopes to Targeted Acoustic Attacks”, Shadi Khazaaleh et al.

---

<br>

<br>

여기서부터는 내 사감이다.

먼저 고생했어 우리 팀원들!!! 주제 선정부터 발표까지 20일밖에 없었고, 나는 막학기 16학점(...^^....), 너희는 가장 바쁜 3학년이었잖아!
그 와중에 다같이 모여서 밤늦게까지 노력했고, 어찌 됐든 결과도 재현했고!
우리 완전 대단해 대단해~~~

플젝을 하는 내내 다같이 입버릇처럼 너무 재밌다 근데 시간이 없어서 속상하다 말했을 정도로 참 재밌었다.
특히 팀원 하나는 구현을 정말 잘하는데다 플젝에도 적극적이라 나도 에너지를 얻었다.
나는 구상을 잘 하는데, 이 친구가 구현을 특출나게 잘 하니까 엄청난 시너지가 나더라.
아니 정말로 내가 실험을 설계해서 이거 이렇게이렇게 하고 싶은데 어때, 라고 하면 말 그대로 뚝! 딱! 하는 사이에 코드를 짜서 짜잔 하고 보여준다.
당신은 신이에요. You are GOD.

진짜 존경스러웠고... 나에게 큰 자극이 되었다.


다른 팀원은 주제가 어려워 힘들어하면서도 마지막까지 어떻게든 팀에 기여하려 노력하는 면모가 배울 점이었다.
이거 정말 어렵잖아.... 답이 안 보여도 팀활동이기 때문에 끝까지 참여하는 거.
그냥 참여하는 것도 아니다. 다른 팀원에게 피해가 되지 않도록 배려하며 팀플에 참여하고자 했다.
아이고 내 친구 고생했다.

팀플레이를 정말 좋아한다. 개개인이 서로에게 좋은 에너지를 주고받으며 단순합이 아닌 곱의 결과를 내는 게 멋있다고 생각하기 때문이다.
이번 미니플젝은 이런 내 로망을 좀 이뤄준 것 같다 ㅋㅋㅋㅋㅋㅋㅋㅋㅋ

재밌었어! 담에 이런 거 또 하자 얘들아!!



