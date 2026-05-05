# 어플리케이션 시스템 아키텍처 및 워크플로우

본 문서는 Flutter 어플리케이션(Client), 로컬 데이터베이스(Hive), 외부 서비스(YouTube) 간의 시스템 아키텍처 및 핵심 워크플로우를 나타내는 플로우 차트(Sequence Diagram 및 Architecture Graph)를 포함합니다. 서버 없이 전면 오프라인/로컬 스토리지 기반으로 작동하는 서버리스(Serverless) 구조입니다.

## 1. 시스템 아키텍처 구성도 (System Architecture)

어플리케이션(Client), 로컬 데이터베이스(Local DB), 외부 서비스 간의 관계를 보여주는 전체 아키텍처 맵입니다.

```mermaid
graph TD
    subgraph Client Layer
        App[모바일 앱<br>Flutter / GetX]
    end
    
    subgraph Local Storage Layer
        DB[(Local DB<br>Hive NoSQL)]
    end
    
    subgraph External Services
        YT_API[YouTube Data API v3<br>검색/추천/메타데이터]
        YT_Stream[YouTube Audio Stream<br>youtube_explode_dart]
        Chart[음원 차트 정보 API / Web Scraping]
    end
    
    %% Client to External
    App -.->|1. 곡 검색 및 데이터 파싱| YT_API
    App -.->|2. 오디오 스트림 전용 추출 - 광고 스킵| YT_Stream
    App -.->|3. 실시간 차트 정보 갱신| Chart
    
    %% Client to Local Storage
    App <==>|4. 재생목록 / 좋아요 CRUD| DB
    App <==>|5. 사용자 설정 및 캐싱 데이터 I/O| DB
    
    classDef client fill:#02569B,stroke:#fff,stroke-width:2px,color:#fff;
    classDef localdb fill:#FF9800,stroke:#fff,stroke-width:2px,color:#fff;
    classDef external fill:#FF0000,stroke:#fff,stroke-width:2px,color:#fff;
    
    class App client;
    class DB localdb;
    class YT_API,YT_Stream,Chart external;
```

---

## 2. 어플리케이션 핵심 워크플로우 (Workflow Sequence Diagram)

사용자의 행동(음악 검색, 재생, 플레이리스트 저장)에 따른 앱 내부, 로컬 스토리지, 외부 시스템 간의 데이터 흐름을 상세하게 나타냅니다.

```mermaid
sequenceDiagram
    autonumber
    actor User as 사용자
    participant App as 모바일 앱 (Flutter)
    participant YT as YouTube 서비스
    participant DB as 로컬 DB (Hive)

    %% 0. 앱 진입 워크플로우
    rect rgba(128, 128, 128, 0.1)
    Note over User, DB: 워크플로우 0: 앱 진입 (Splash) 및 시스템 설정 로드
    User->>App: 앱 실행
    App->>App: 스플래시 애니메이션 노출
    App->>DB: 사용자 설정(다국어 등) 로드
    App->>App: 로그인 과정 생략 및 즉시 홈 화면 진입
    end

    %% 1. 음악 탐색 및 재생 워크플로우
    rect rgba(128, 128, 128, 0.1)
    Note over User, DB: 워크플로우 1: 음악 검색, 재생 및 갭리스(Gapless) 처리
    User->>App: 듣고 싶은 곡 검색
    App->>YT: YouTube API로 검색어 전송
    YT-->>App: 영상 메타데이터(제목, 썸네일 등) 반환
    App->>App: Regex로 제목 파싱 (예: -MV- 삭제) 후 목록 표시
    User->>App: 곡 재생 선택
    App->>YT: 오디오 스트림 추출 요청 (youtube_explode_dart)
    YT-->>App: 광고가 제외된 순수 오디오 스트림 URL 반환
    App->>App: 백그라운드 오디오 플레이어 시작 (just_audio)
    App->>DB: 최근 재생한 곡 내역 로컬 저장
    App->>YT: ❗️현재 곡 종료 10초 전, 다음 곡 스트림 URL 미리 요청 (프리로딩)
    end

    %% 2. 재생목록(Playlist) 관리 워크플로우
    rect rgba(128, 128, 128, 0.1)
    Note over User, DB: 워크플로우 2: 오프라인 재생목록 (Playlist) 관리
    User->>App: 내 재생목록에 추가 터치
    App->>DB: 플레이리스트 객체 업데이트 및 로컬 DB 저장 (put)
    DB-->>App: 디스크 저장 완료 응답
    App->>App: GetX 상태 업데이트하여 플레이리스트 UI 즉각 갱신
    end
```
