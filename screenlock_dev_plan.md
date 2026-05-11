# Screen Lock Media Player Development Plan

이 문서는 안드로이드 및 iOS의 잠금 화면(Screen Lock)에서 완벽하게 작동하는 미디어 플레이어 위젯을 구현하기 위한 상세 기술 플랜입니다. 기존의 오작동 사례를 분석하여 시스템 레벨에서 신뢰할 수 있는 제어 환경을 구축하는 것을 목표로 합니다.

## 1. 핵심 목표
*   **완벽한 제어**: 재생, 일시중지, 이전/다음 곡, 탐색(Slider) 기능의 100% 동기화.
*   **시각 정보**: 곡 제목, 아티스트, 고화질 썸네일(Thumbnail) 표시.
*   **안정성**: 백그라운드 전환 시 세션 끊김 방지 및 애플 뮤직 등 타 앱으로의 주도권 탈취 방어.

---

## 2. 플랫폼별 기술 요구사항

### Android (API 21+)
*   **MediaSessionCompat**: 시스템과 앱 간의 브릿지 역할.
*   **MediaStyle Notification**: 잠금 화면 및 알림창에 표시될 표준 UI.
*   **Foreground Service**: OS에 의해 앱이 종료되지 않도록 보장.
*   **Permissions**: `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (Android 14+ 대응).

### iOS (iOS 12.0+)
*   **MPNowPlayingInfoCenter**: 잠금 화면에 곡 정보 및 썸네일 전달.
*   **MPRemoteCommandCenter**: 잠금 화면 버튼 이벤트를 수신하여 앱 로직과 연결.
*   **Audio Session**: `AVAudioSessionCategoryPlayback` 설정으로 백그라운드 권한 획득.

---

## 3. 상세 구현 단계 (Step-by-Step)

### 단계 1: 프로젝트 환경 재설정
1.  **Android**: `minSdkVersion`을 21로 상향 조정하고 `AndroidManifest.xml`에 필요한 서비스 및 권한 선언.
2.  **iOS**: `Info.plist`에 `UIBackgroundModes` (audio)를 추가하고 Xcode에서 해당 기능 활성화.

### 단계 2: 싱글톤 AudioHandler 구축 (핵심)
*   `audio_service` 패키지를 사용하여 전역적으로 접근 가능한 `BaseAudioHandler` 클래스 구현.
*   **역할**: UI와 분리된 독립적인 오디오 엔진 제어.

### 단계 3: 미디어 정보 동기화 로직 (Metadata)
*   곡이 변경될 때마다 `mediaItem.add(...)`를 통해 시스템에 최신 정보를 즉시 전송.
*   **탐색(Slider) 지원**: `playbackState.add(...)`를 통해 현재 재생 위치(position)와 버퍼링 상태를 실시간으로 시스템과 동기화하여 잠금 화면 슬라이더가 부드럽게 움직이도록 처리.

### 단계 4: 시스템 명령 인터셉트 (Remote Commands)
*   잠금 화면의 '다음 곡' 버튼 클릭 시, 네이티브 단의 신호를 가로채서 Flutter의 `playNext()` 로직을 안전하게 실행.
*   **방어 로직**: 네트워크 지연 중에도 오디오 세션을 `Active` 상태로 유지하여 애플 뮤직이 실행되는 것을 방지.

### 단계 5: 썸네일 최적화
*   네트워크 이미지를 시스템이 읽을 수 있는 로컬 캐시 경로 또는 메모리 바이트 데이터로 변환하여 전달.
*   고해상도 이미지가 잠금 화면 로딩을 지연시키지 않도록 적절한 사이즈(예: 300x300)로 다운스케일링.

---

## 4. 오작동 방지를 위한 체크리스트 (Safeguards)

| 현상 | 원인 | 해결 방안 |
| :--- | :--- | :--- |
| **재생 중 멈춤 (90%)** | OS의 백그라운드 프로세스 제한 | Foreground Service 활성화 및 WakeLock 적용 |
| **애플 뮤직 강제 실행** | 오디오 세션 비활성화(Idle) | 트랜지션 중에도 `session.setActive(true)` 유지 |
| **슬라이더 제어 안됨** | PlaybackState 미동기화 | `updatePosition`을 1초 주기로 시스템에 업데이트 |
| **썸네일 미출력** | 이미지 로딩 실패 또는 포맷 불일치 | `artUri` 설정 전 사전 다운로드 및 유효성 검사 |

---

## 5. 향후 확장성 (Native Bridge)
Flutter 단에서 특수한 OS 제약으로 인해 오작동이 지속될 경우를 대비하여, **Platform Channel (MethodChannel)**을 통해 Kotlin/Swift로 직접 네이티브 미디어 센터를 제어할 수 있는 구조를 마련해 둡니다.

---

## 6. 개발 우선순위
1.  [ ] **[상]** 네이티브 오디오 세션 초기화 및 백그라운드 권한 확보.
2.  [ ] **[상]** 재생/중지/다음곡/이전곡 기본 버튼 명령 연결.
3.  [ ] **[중]** 잠금 화면 슬라이더(Position) 실시간 연동.
4.  [ ] **[중]** 고화질 썸네일 표시 및 캐싱 로직.
5.  [ ] **[하]** 알림창 내 닫기/고정 등 커스텀 액션 추가.
