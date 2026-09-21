# PROJECT_CONTEXT.md

> 이 문서는 Codex/VS Code에서 이 Godot 프로젝트를 수정할 때 참고하는 프로젝트 컨텍스트다.
> 새 작업을 시작하기 전에 이 파일과 실제 프로젝트 파일을 먼저 읽고, 서로 충돌하면 **실제 프로젝트 파일의 현재 상태를 우선**한다.
> 기존에 정상 동작하는 기능은 최대한 유지하고, 필요한 부분만 최소 수정한다.

---

## 1. 프로젝트 개요

- 장르: 스토리 중심 협동 생존 선택 게임
- 엔진: **Godot 4.7.1 stable**
- 언어: **GDScript**
- 1차 배포 목표: **Web**
- 이후 목표: Steam/Windows
- 기본 게임 컨셉:
  - 플레이어가 자신이 원하는 캐릭터로 몰입해 스토리를 진행
  - 선택에 따라 분기와 다양한 엔딩 발생
  - 최대 **4인 멀티플레이**
  - 방장 1명 + 참가자 최대 3명
  - 같은 방 플레이어는 같은 스토리 진행 상태를 공유
  - 실제 화면 스트리밍이 아니라 **동일한 게임 상태를 동기화**하는 방식
  - 방장만 최종 선택 가능
  - 2인 이상일 때는 방장이 선택지를 고른 뒤 **나머지 참가자 전원이 동의해야 다음 장면으로 진행**
  - 참가자들은 토론/댓글로 의사결정에 참여
  - 중간 입장 가능
  - 방 생성 시 항상 초대 코드 자동 발급
  - 초대 코드는 게임 화면 어딘가에 상시 표시
  - 코드를 입력해 같은 방에 참가

---

## 2. 가장 중요한 작업 원칙

1. **Godot 4.7.1 stable 유지**
   - 임의로 버전 업그레이드하지 말 것.
   - 특히 4.7.2로 올리지 말 것.
   - Windows 한국어 IME 런타임/Export 문제 때문에 4.7.1을 의도적으로 사용 중.

2. **기존 정상 기능을 함부로 리팩터링하지 말 것**
   - 새 기능 추가 전에 관련 파일을 먼저 읽는다.
   - 이미 정상 동작하는 구조는 최소 수정한다.
   - “더 깔끔한 구조”라는 이유로 전체 아키텍처를 바꾸지 않는다.

3. **Dialogue Nodes 플러그인 내부 코드 수정 금지**
   - `res://addons/dialogue_nodes/`
   - 스토리는 `.tres` Dialogue graph로 관리.
   - 스토리 내용은 코드로 옮기지 않는다.

4. **기존 PC/모바일 레이아웃을 함부로 수정하지 말 것**
   - 특히 `main.gd`의 모바일 UI는 여러 시행착오 끝에 안정화됨.
   - 새 기능 때문에 전체 레이아웃 구조를 다시 짜지 않는다.

5. **사용자가 직접 시각화 그래프를 편집하는 영역은 Godot에서 유지**
   - Dialogue graph
   - 리소스 배치
   - 화면 배치 확인
   - 실제 플레이 테스트
   - Codex는 주로 `.gd`, `.tscn`, Manager, 서버 연동 코드 작업

6. **경로를 추측하지 말 것**
   - 실제 프로젝트 FileSystem을 보고 사용한다.
   - 파일 이동/이름 변경 전에는 참조 관계를 확인한다.

7. **큰 수정 전후 Git 체크포인트 권장**
   - 현재 Git 저장소 설정 완료.
   - `.gitignore`에 최소 다음이 포함됨:
     - `.godot/`
     - `build/`
     - `builds/`
     - `dist/`
     - `.DS_Store`
     - `Thumbs.db`
     - `.vscode/`

---

## 3. 해상도 / 레이아웃

### PC 기준

- 전체 기준 해상도: **1536×648**
- 게임 영역: **1152×648**
- 오른쪽 상시 토론 패널: **384×648**
- Stretch:
  - mode: `canvas_items`
  - aspect: `keep`
  - scale mode: `fractional`

### 모바일

- `ScreenLayout` Autoload가 PC/모바일 판별 및 레이아웃을 관리.
- 모바일 virtual width 약 720.
- 최소 height 약 1320.
- 모바일 전용 UI는 `main.gd`가 직접 소유.
- PC용 `DiscussionPanel`은 모바일에서 숨김.
- 모바일에서는 별도의 black page background / 배경 / insight / dialogue / options / discussion UI 사용.
- 모바일 배경은 16:9 전체 표시, 불필요한 crop 금지.
- 초상화는 dialogue 옆.
- 선택지는 full width.
- 모바일 토론 영역은 항상 아래에 표시.
- 이 구조는 이미 사용자가 만족한 상태이므로 함부로 변경 금지.

---

## 4. 폰트

- Pretendard 1.3.9 사용.
- MSDF / mipmaps 활성화.
- 실제 프로젝트 안의 폰트 경로를 확인해서 사용.
- 경로를 임의로 만들거나 추측하지 말 것.

---

## 5. Dialogue Nodes

- 플러그인 위치: `res://addons/dialogue_nodes/`
- 시각화 그래프가 **스토리 원본**.
- 플러그인 내부 코드를 건드리지 않는다.

### DialogueBox 핵심 구조

현재 구현에는 대략 다음 기능이 있음:

- `@export var data: DialogueData`
- setter에서 parser data 설정
- variables / characters 갱신
- `start(id)`
- `stop()`
- `select_option()`
- signals: `dialogue_processed`, `dialogue_signal`, `option_selected` 등

### 에피소드별 Dialogue 파일

현재 확인된 실제 경로:

- 학교: `res://school_test.tres`
- 병원: `res://hospital_dialogue.tres`

두 파일 모두 별도 그래프.
동일한 Start ID를 각각 사용해도 문제없음.

병원 Start node:
- `START1`

학교도 현재 Start ID를 `START1`로 사용하는 흐름.

### Signal 형식

기존 `INSIGHT1|...` 계열은 폐기.

현재 형식:

```text
INSIGHT|CALM|관찰|...
INSIGHT|CAUTIOUS|관찰|...
INSIGHT|CURIOUS|관찰|...
INSIGHT|DIRECT|판단|...
INSIGHT|TIMID|감지|...
```

성격 키:

- `CALM` = 차분함
- `CAUTIOUS` = 신중함
- `CURIOUS` = 호기심
- `DIRECT` = 직선적
- `TIMID` = 겁이 많음

현재 `main.gd`의 `_on_dialogue_signal()`은:
- 성격 키 normalize
- 캐릭터 ID가 아니라 personality만 비교
- 웹 새로고침을 위해 RoomManager fallback 지원
- signal event ordering 문제 대응을 위해 deferred flush 사용

### Signal node 편집

스토리가 길어져도 상단 Add Node를 쓸 필요 없음.

- 그래프 빈 공간 우클릭 → Signal
- 또는 이전 노드 연결점을 빈 공간까지 drag → Signal 생성

---

## 6. 캐릭터 / 성격 시스템

캐릭터와 성격은 분리:

- character identity
- name
- portrait
- personality

### 기본 캐릭터 12명

PC 6×2, 모바일 2×6.

1. 김솔음
2. 백사헌
3. 고영은
4. 은하제
5. 박민성
6. 이자헌
7. 이성해
8. 진나솔
9. J3
10. 곽제강
11. 최 요원
12. 류재관

### 커스텀 캐릭터

- 커스텀 캐릭터 화면 존재.
- 이름/초상화/성격 분리 구조.
- portrait loader는 `res://`와 `user://` 둘 다 지원.

### 현재 플로우

```text
캐릭터 선택
→ 성격 선택
→ 에피소드 선택
→ main
```

---

## 7. Episode Select

현재 새 씬:
- `res://episode_select.tscn`

현재 의도된 데이터:

```gdscript
const EPISODES := [
    {
        "id": "school",
        "title": "학교",
        "description": "존재하지 않아야 할 교실과 변해버린 학교.",
        "scene_id": "school_hallway",
        "scene_title": "학교 복도",
        "dialogue_file": "res://school_test.tres",
        "start_id": "START1",
        "scene_file": "res://main.tscn",
        "enabled": true
    },
    {
        "id": "hospital",
        "title": "병원",
        "description": "폐쇄된 병동에서 시작되는 오염 구역.",
        "scene_id": "hospital",
        "scene_title": "병원",
        "dialogue_file": "res://hospital_dialogue.tres",
        "start_id": "START1",
        "scene_file": "res://main.tscn",
        "enabled": true
    }
]
```

중요:
- 병원 파일은 현재 `res://hospital_dialogue.tres`
- `res://episodes/hospital/...`로 이동했다고 가정하지 말 것.

시작 시:

```gdscript
RoomManager.start_new_episode(
    scene_id,
    scene_title,
    scene_file,
    start_id,
    dialogue_file
)
```

호출 후 해당 scene_file로 이동.

---

## 8. RoomManager

Autoload:
- `RoomManager`
- 파일: `res://RoomManager.gd`

최근 스키마 버전:
- `SCHEMA_VERSION = 4`

### 주요 signals

- `feed_changed`
- `comment_added(comment_id)`
- `comment_edited(comment_id)`

### 현재 로컬 저장

- `user://rooms/`
- desktop TXT export: `user://exports/`

Web에서는 `user://`가 브라우저 IndexedDB로 저장됨.

### current_room 주요 구조

```text
current_room
├ members
├ game_state
├ feed
└ transcript
```

`game_state` 주요 필드:

- `scene_file`
- `scene_id`
- `scene_title`
- `checkpoint`
- `dialogue_start_id`
- `dialogue_file`
- `dialogue_history`
- `selected_character_id`
- `story_flags`
- `inventory`

### 주요 함수

```gdscript
func start_new_episode(
    scene_id: String,
    scene_title: String,
    scene_file: String,
    start_id: String,
    dialogue_file: String = ""
) -> void:
```

새 에피소드 시작 시:
- scene 상태 저장
- dialogue_file 저장
- dialogue_history 초기화
- story_flags 초기화
- inventory 초기화
- 기존 story transcript 제거
- comment transcript는 보존
- 저장

추가 함수:

```gdscript
func set_dialogue_file(dialogue_file: String) -> void
func get_dialogue_file() -> String
```

캐릭터 선택 저장:

```gdscript
set_selected_character(
    character_id,
    name,
    portrait_path,
    personality
)
```

### Undo / restore

지원 중:
- `create_dialogue_undo_snapshot()`
- `record_dialogue_selection(...)`
- `can_undo_dialogue_selection()`
- `undo_last_dialogue_selection()`

실제 choice rollback 시:
- 잘못 진행한 story transcript 제거
- comment는 보존

빈 `"계속"` 선택지는:
- dialogue_history replay 용으로 남김
- TXT transcript에는 실제 선택으로 기록하지 않음

`dialogue_history`는 restore / undo replay에 사용.

---

## 9. main.gd

현재 `main.gd`는 매우 중요.
새 기능 추가 시 전체 구조를 재작성하지 말 것.

### 에피소드 Dialogue 로딩

`_ready()` 이후 `_load_episode_dialogue_data()`가:

1. `RoomManager.get_dialogue_file()` 읽음
2. `ResourceLoader.load()`
3. `DialogueData`인지 확인
4. `dialogue_box.data`에 할당

### Dialogue 시작 순서 관련 수정

에디터 기본 샘플:

```text
Speaker
Some dialogue text...
Option 1
```

이 잠깐 보이는 문제가 있었음.

최근 수정 방향:
- 실제 Dialogue start/restore 먼저 처리
- 이후 layout 적용

### Desktop auto height

대표 상수:

```gdscript
const DESKTOP_OPTION_HEIGHT := 46
const DESKTOP_DIALOGUE_BOTTOM := 600.0
const DESKTOP_DIALOGUE_MIN_HEIGHT := 150.0
const DESKTOP_DIALOGUE_MAX_HEIGHT := 380.0
const DESKTOP_TEXT_MIN_HEIGHT := 44.0
const DESKTOP_TEXT_MAX_HEIGHT := 190.0
const DESKTOP_DIALOGUE_VERTICAL_PADDING := 18.0
const DESKTOP_INSIGHT_GAP := 8.0
```

관련 helper:

- `_get_desktop_dialogue_text_height()`
- `_get_desktop_options_height()`
- `_get_desktop_dialogue_required_height()`
- `_schedule_desktop_reflow()`
- `_reflow_desktop_after_frame()`

선택지 버튼:
- `AUTOWRAP_WORD_SMART`

### 모바일 auto height

```gdscript
const MOBILE_DIALOGUE_ROW_HEIGHT := 112.0
const MOBILE_DIALOGUE_TEXT_MIN_HEIGHT := 72.0
const MOBILE_DIALOGUE_TEXT_MAX_HEIGHT := 220.0
```

- mobile dialogue label scroll active
- 실제 텍스트 높이를 clamp
- options는 실제 text height 아래부터 시작

---

## 10. PC 초상화 / 이전 / 에피소드 재선택 버튼

현재 사용자 의도:

- `에피소드 재선택`과 `← 이전`은 **초상화 아래**
- 둘은 같은 위치를 번갈아 사용
- **버튼 바닥선이 선택지 영역의 바닥선과 정확히 수평**
- 초상화와 버튼 사이에는 약간의 여백
- 최근 6px보다 조금 더 벌리길 원해 **약 10px**로 조정하는 방향

최근 PC 기준 주요 값:

```gdscript
const PORTRAIT_POSITION := Vector2(48, 430)
const PORTRAIT_SIZE := Vector2(140, 170)

const CHOICE_DIALOGUE_POSITION := Vector2(205, 430)
const CHOICE_DIALOGUE_SIZE := Vector2(900, 170)

const CHOICE_INSIGHT_POSITION := Vector2(205, 384)
const CHOICE_INSIGHT_SIZE := Vector2(900, 38)

const NORMAL_DIALOGUE_POSITION := Vector2(48, 380)
const NORMAL_DIALOGUE_SIZE := Vector2(1056, 220)

const NORMAL_INSIGHT_POSITION := Vector2(48, 334)
const NORMAL_INSIGHT_SIZE := Vector2(1056, 38)
```

버튼 높이:
- 38px

버튼 바닥:
- `DESKTOP_DIALOGUE_BOTTOM = 600`

따라서 버튼 y:
- `600 - 38 = 562`

초상화는 버튼 위에 간격을 두고 올라감.

---

## 11. 에피소드 재선택 / 이전 규칙

### 에피소드 재선택

- 첫 실제 선택 화면에서만 보임.
- 아직 실제 choice history가 없을 때.
- episode select로 돌아감.

### ← 이전

- 실제 choice가 하나 이상 존재하면 표시.
- 마지막 실제 choice rollback.

둘은 동시에 보이지 않음.

---

## 12. 배경 시스템

에피소드별/장면별 배경 전환은 아직 완전히 구현하지 않음.

향후 계획:

```text
BG|school_hallway.png
BG|classroom.png
BG|rooftop.png
```

또는 key 방식.

현재 separate episode `.tres` 구조와 맞춰서 설계할 것.
현재 학교/병원 Dialogue는 분리됐지만 background는 아직 학교 배경이 공통으로 보일 수 있음.

---

## 13. 저장 정책

### 현재 비회원/로컬 저장

```text
Godot user://
→ Web에서는 브라우저 IndexedDB
```

한계:
- 사이트 데이터 삭제 시 유실 가능
- 다른 브라우저/기기에서 자동 공유되지 않음
- 배포 URL 변경 시 기존 세이브 접근 문제 가능

### 앞으로

**로컬 저장 + 클라우드 저장 병행**

```text
플레이
→ 로컬 즉시 저장
→ 서버에도 저장

인터넷 끊김
→ 로컬에는 계속 저장

연결 복구
→ 서버 동기화
```

회원가입 후에도 로컬 사본을 바로 삭제하지 않는다.

---

## 14. 로그인 / 비회원 / 계정 연동 설계

처음 플레이하는 유저는 회원가입 강제하지 않음.

첫 화면:

```text
로그인
회원가입
비회원으로 플레이
```

### 비회원 플레이

- 현재 브라우저에만 저장
- 기존 `user://` / IndexedDB 저장 사용

### 회원가입 이점

- 클라우드 보관
- PC / 모바일 이어하기
- 비회원 세이브를 나중에 계정으로 연동

### 로그인 화면 안내문 취지

> 비회원 플레이 데이터는 현재 브라우저에만 저장됩니다.  
> 브라우저 데이터가 삭제되거나 다른 기기를 사용할 경우 기존 데이터를 불러올 수 없습니다.  
> 회원가입 후에는 플레이 데이터를 계정에 연동하여 안전하게 보관할 수 있으며,  
> PC와 모바일 등 다른 기기에서도 이어서 플레이할 수 있습니다.  
> 비회원으로 먼저 플레이한 데이터도 회원가입 후 계정에 연동할 수 있습니다.

### 향후 AuthManager

예정:
- `res://AuthManager.gd`
- Autoload

최소 상태:
- `is_logged_in`
- `is_guest`
- `user_id`
- `email`
- `nickname`

Supabase 전 단계:
- 로그인 버튼 → “서버 연결 후 이용 가능합니다.”
- 회원가입 버튼 → 같은 안내
- 비회원으로 플레이 → 실제 정상 작동

### 비회원 → 회원 연동

```text
비회원 플레이
→ 로컬 세이브 생성
→ 나중에 회원가입
→ 로컬 세이브 발견
→ 기존 플레이 데이터를 계정에 연동할지 확인
→ 서버 업로드
→ 업로드 성공 확인
→ 클라우드에서도 접근 가능
```

---

## 15. Supabase 계획

향후 Supabase 역할:

- Auth
- 클라우드 세이브
- room / member persistence
- multiplayer realtime
- episode entitlement(구매 권한)

### 로그인

- 이메일 + 비밀번호 방식 고려
- 닉네임은 별도 profile에 저장
- 이메일 인증 사용 가능

### 클라우드 세이브

현재 `RoomManager.current_room`을 기반으로 서버에 저장.
초기에는 JSON/JSONB 중심으로 단순하게 가져가도 됨.

---

## 16. 멀티플레이 설계

### 최대 인원

- **최대 4인**
- 방장 1
- 참가자 최대 3

기존 RoomManager에 max_players가 1~3 clamp로 남아 있다면 나중에 4까지 허용.

### 방 생성

- 인원 수를 미리 고르지 않음
- 생성 시 무조건 초대 코드 발급
- 코드 예: `K7M4XP`
- 최대 4명
- 코드는 화면에 상시 표시

### 참가

- 코드 입력 → room join
- 중간 참가 가능
- 입장 시 현재 방장의 진행 상태를 받아 현재 장면으로 동기화

### 화면 공유 의미

**화면 스트리밍 아님.**

```text
방장 game state
→ 서버에 반영
→ 참가자들이 동일 episode/dialogue_history/current choice를 받아
→ 각자 로컬에서 같은 화면을 렌더링
```

### 방장 권한

- 최종 choice는 방장만 클릭 가능
- 참가자는 직접 확정 불가
- 참가자는 토론/댓글 가능

### 전원 동의

1인:
- 방장이 누르면 즉시 진행

2인 이상:
- 방장이 choice 선택
- 즉시 진행하지 않음
- pending choice 생성
- 나머지 참가자에게 “동의” 표시
- 방장을 제외한 현재 동의 대상 전원이 동의해야 진행

### 중간 입장과 투표

권장 규칙:
- 방장이 선택한 순간 현재 접속 중인 참가자를 승인 대상자로 snapshot
- vote 중 새로 들어온 사람은 현재 vote에는 미참여
- 다음 choice부터 참여

### 실시간 기술 방향

Supabase Realtime 고려:

- Presence: 접속/퇴장 상태
- Broadcast: choice proposal / approval / story progress / room state event

---

## 17. 결제 / 에피소드 해금 정책

현재 제작 예정 에피소드 4개는 **무료 배포**.
가입자/서비스 규모가 커지면 이후 에피소드부터 유료 가능성.

정책 확정:

**방장만 해당 에피소드를 구매했으면 초대받은 참가자들은 구매하지 않아도 함께 플레이 가능.**

```text
방장 hospital 구매
→ hospital 방 생성 가능

참가자
→ hospital 미구매여도 해당 방 참가 가능
```

구매 권한은 향후 계정에 귀속.

---

## 18. 서버 / 크로스플레이 목표

목표:
- Web PC
- 모바일 브라우저
- 이후 Steam/Windows

같은 계정/방을 사용할 수 있도록 설계.

---

## 19. 현재 이후 추천 순서

```text
1. 로그인 화면 UI
2. 비회원 플레이 정상 동작
3. AuthManager 구조
4. Supabase 프로젝트 생성
5. 실제 로그인/회원가입 연결
6. 비회원 로컬 세이브 → 계정 클라우드 연동
7. 방 생성
8. 6자리 초대 코드
9. 코드로 참가
10. 최대 4인 room membership
11. 실시간 접속자 동기화
12. 방장 story state 동기화
13. 방장 choice proposal
14. 참가자 전원 동의
15. 전원 승인 후 story 진행
16. 재접속 / 중간 입장 안정화
```

---

## 20. 로그인 화면 작업 요구사항

향후 새 파일 예정:

```text
res://login.tscn
res://login.gd
res://AuthManager.gd
```

AuthManager:
- Autoload 등록

Main Scene:
- 기존 시작 씬 경로를 먼저 확인하고 기억
- 프로젝트 실행 시 `login.tscn`이 먼저 나오게 설정
- 비회원 플레이 클릭 시 기존 시작 씬으로 이동

로그인 화면 구성:

```text
게임 제목

이메일
[________________]

비밀번호
[________________]

[ 로그인 ]
[ 회원가입 ]

------ 또는 ------

[ 비회원으로 플레이 ]

비회원 플레이 안내...
```

주의:
- Supabase 연결 전에는 로그인/회원가입 실제 인증 호출 금지
- 오류 없이 안내만 표시
- 비회원 버튼만 실제 동작
- Control/Container 기반 반응형 UI
- PC 1536×648와 세로 모바일 대응
- Pretendard 실제 경로가 있으면 사용
- `.tres` story graph / plugin 내부 코드 건드리지 않음

---

## 21. Discussion / Transcript

DiscussionPanel:
- PC 오른쪽 384px 상시 토론 UI
- 모바일에서는 별도 discussion UI 사용

RoomManager에는:
- feed
- comments
- transcript
기능이 있음.

Comment editing은 정상 동작 확인.

TXT export:
- Browser: `JavaScriptBridge.download_buffer`
- Desktop fallback: `user://exports/`

---

## 22. 현재 로컬 member ID 주의

과거 코드에:

```gdscript
const LOCAL_MEMBER_ID := "LOCAL_1"
```

같은 고정값이 있을 수 있음.

현재 단일 로컬 테스트용.
멀티/계정 단계에서는:
- Supabase user_id
- 또는 guest anonymous id
기준으로 변경.

로그인 UI 단계에서는 굳이 먼저 뜯지 않는다.

---

## 23. GameData

현재 GameData는:
- character identity
- personality
- portrait
위주로 정리.

portrait loader:
- `res://`
- `user://`
지원.

GameData 역할과 RoomManager 역할을 섞지 말 것.

---

## 24. 세계관 핵심

- 대한민국의 공식 명칭 **“오염 구역”**
- 장소별 진입 방식은 다르지만 공통 구조 존재
- 일반인도 극소수 진입 가능
- 진입/생존 후 자동 요원 등록 가능
- 노출자는 생존을 위해 억제제 필요
- 억제제는 고가
- 정부 예산 한계
- 오염 구역 출입 가능한 사람들을 조직화
- 빠른 종결 임무 수행
- 오염 구역 내부 원료로 억제제 생산
- 공급 안정 때문에 일부 구역을 의도적으로 완전 종결하지 않을 수 있음

학교 예:
- 요원에게만 보이는 “없는 교실”
- 진입하면 학교 전체가 변형된 오염 구역으로 전환

---

## 25. 스토리 진행 원칙

- 올바른 선택 연속 → 종결 / true ending 가능
- 잘못된 선택:
  - 즉시 퇴출/실패
  - 또는 잘못된 엔딩 분기
- 동일 사건 반복 플레이 허용
- 다양한 엔딩
- personality에 따라 표현되는 insight/선택지가 달라질 수 있음
- 최종 story state는 방 단위 공유

---

## 26. 멀티플레이에서 캐릭터 차이 처리

각 플레이어는:
- 서로 다른 character
- 서로 다른 personality
가능.

스토리 진행은 동일하지만:
- 각자 personality insight
- 각자 캐릭터 정보
는 다르게 렌더링 가능.

최종 choice:
- 방장만 선택
- 참가자 동의 절차 후 확정

---

## 27. Codex 작업 스타일

Codex는 새 작업마다:

1. 관련 파일을 먼저 읽는다.
2. 현재 구조를 짧게 요약한다.
3. 수정/생성할 파일을 먼저 나열한다.
4. 실제 파일을 직접 수정한다.
5. 불필요한 리팩터링을 하지 않는다.
6. 기존 기능에 미치는 영향 최소화.
7. 완료 후:
   - 수정 파일 목록
   - 핵심 변경점
   - Godot 테스트 방법
   - 문제 발생 시 확인할 로그/위치
   를 알려준다.

### 특히 금지

- 사용자 승인 없이 Godot 버전 변경
- plugin 내부 수정
- `.tres` graph 대규모 텍스트 재작성
- 모바일 레이아웃 전면 재작성
- 저장 구조 전면 교체
- 파일 경로 추측
- 기존 정상 기능 삭제

---

## 28. 사용자의 작업 선호

- 복붙 반복을 매우 불편해함.
- VS Code + Codex가 실제 파일을 직접 수정하는 방식 선호.
- 사용자가 수동으로 긴 코드를 붙이지 않게 한다.
- 에러가 나면 전체를 새로 갈아엎기보다 **현재 파일 기준 최소 수정**.
- 사용자는 Godot 시각 작업/테스트, Codex는 코드 반복 작업 담당.

---

## 29. Git 사용 방식

큰 작업 전:

```bash
git add .
git commit -m "Before <feature>"
```

작업 성공 후:

```bash
git add .
git commit -m "Add <feature>"
```

예:

```text
Initial working version
Add guest login screen
Add Supabase auth
Add room code system
Add multiplayer sync
Add unanimous choice approval
```

---

## 30. VS Code 배치

사용자 선호:

```text
왼쪽  : Explorer
가운데: 코드
오른쪽: Codex chat
```

- Explorer = Primary Side Bar
- Codex = Secondary Side Bar

---

## 31. 현재 바로 다음 작업

### A. 로그인 화면 구축

Supabase 연결 전 UI/guest flow부터:
- `login.tscn`
- `login.gd`
- `AuthManager.gd`
- Main Scene 전환
- Guest mode

### B. 이후 Supabase 연결

- Email/password auth
- profile/nickname
- cloud save
- guest save migration

### C. 이후 멀티

- room create
- invite code
- up to 4 players
- room member presence
- host-authoritative story state
- unanimous approval

---

## 32. 새 Codex 세션에서 첫 지시 예시

```text
PROJECT_CONTEXT.md를 먼저 읽고 실제 프로젝트 파일을 확인해.
문서와 실제 코드가 다르면 현재 코드 상태를 우선해.

이번 작업에서 기존 Dialogue Nodes, main.gd의 안정화된 PC/모바일 레이아웃,
RoomManager의 정상 저장/undo/transcript 기능은 불필요하게 변경하지 마.

관련 파일을 먼저 읽고, 수정할 파일 목록과 계획을 짧게 정리한 뒤 실제 파일을 수정해.
완료 후 테스트 방법을 알려줘.
```

---

## 33. 문서 유지 규칙

새 기능이 완성되면 이 문서를 함께 갱신한다.

특히 다음은 바뀔 때 반드시 업데이트:

- 실제 file path
- Main Scene
- Autoload 목록
- RoomManager schema version
- Supabase table 구조
- multiplayer event 규칙
- max player
- save migration 규칙
- episode file
- background system
- login flow
- paid episode entitlement 정책

이 문서는 설계 가이드다.
**실제 코드가 이미 변경되어 있다면 항상 현재 코드가 최종 진실(source of truth)** 이다.

---

## 34. 로그인 시작 화면 구현 (2026-09-21)

이 항목은 앞선 로그인 화면 구현 예정 설명을 대체하는 현재 구현 상태다.

- Main Scene: res://login.tscn (UI 로직: res://login.gd).
- 기존 Main Scene: res://start.tscn, UID uid://bvmk0k7hov8rd.
- 비회원으로 플레이: AuthManager.enter_guest_mode() 후 기존 start.tscn으로 이동.
- Autoload: AuthManager, GameData, RoomManager, ScreenLayout.
- AuthManager: res://AuthManager.gd. is_logged_in, is_guest, user_id, email, nickname 관리.
- 초기에는 로그인/비회원 상태 모두 false. 비회원 선택 시 is_guest=true, is_logged_in=false, nickname="비회원". user_id와 email은 빈 문자열이다.
- 비회원 user_id를 서버 계정 ID처럼 만들지 않는다. 기존 RoomManager의 LOCAL_1 및 user://rooms/ 저장을 그대로 사용한다.
- sign_in/sign_up은 서버 연결 후 이용 가능 안내만 반환한다. 비밀번호를 저장하지 않으며 서버 요청도 하지 않는다.
- sign_out은 인증 상태만 초기화하며 기존 로컬 저장을 삭제하지 않는다.
- Supabase 연결 시 sign_in/sign_up에 실제 인증 처리를 연결하고, 검증된 세션으로 계정 상태를 갱신한다. 클라우드 저장과 비회원 저장 이전은 아직 구현하지 않았다.
- UI는 Control/Container 및 세로 스크롤 기반이며 기존 ScreenLayout의 PC 1536x648 / 세로 모바일 가상 크기를 따른다.
- 폰트: res://fonts/Pretendard-Regular.otf.
- Web 안내는 브라우저 저장, 데스크톱 안내는 현재 기기 저장으로 표시한다. 계정 연동은 준비 중임을 명시한다.
- main.gd, RoomManager.gd, ScreenLayout.gd, 기존 씬과 스토리 그래프, 플러그인은 변경하지 않는다.


## 35. 시작 메뉴 및 구역 메뉴 변경 (2026-09-21)

- start.gd: 새 게임 / 불러오기 버튼을 가로 배치. 종료 버튼 유지.
- room_menu.gd: 새 게임은 생성 폼만, 불러오기는 저장된 구역 목록만 표시. 뒤로 버튼으로 start.tscn에 복귀.
- 메뉴 진입 모드는 SceneTree의 room_menu_show_saved 메타데이터로 전달하고 진입 시 제거한다. 직접 실행 시 생성 화면이 기본이다.
- 명칭: 새 구역 만들기 / 구역 이름 / 구역 만들기 / 저장된 구역.
- 인원 선택 UI 제거. 새 구역의 max_players는 4이며 RoomManager.create_room의 상한만 3에서 4로 변경했다. 기존 저장 데이터와 스키마는 유지한다.
- 안내: 초대 코드 입력 시 최대 4명까지 멀티 플레이 가능. 실제 코드 접속 및 멀티플레이는 아직 서버 연결 전 단계이며 미구현이다.
- 저장 목록의 인원 표시 제거. 로컬 저장 시간은 화면에서 2026년 9월 21일 오전 8시 46분 형식으로 표시한다. 저장 파일의 시간 문자열은 변경하지 않는다.
- 기존 불러오기/캐릭터 복원/삭제 처리 유지. main.gd, 스토리 그래프와 플러그인은 변경하지 않는다.
- 로그인 안내는 Web/데스크톱 공통으로 현재 기기 및 브라우저 저장 문구를 사용한다.


## 36. 서버 메뉴 및 이름 변경 (2026-09-21)

- 시작 화면의 종료 버튼 제거.
- 생성 화면: 신규 서버 생성 / 서버 이름 / 새로운 서버 만들기.
- 안내: ※ 서버 생성 후 지급되는 초대 코드 입력 시 최대 4명까지 멀티 플레이가 가능합니다.
- 실제 초대 코드 지급·접속 및 멀티플레이는 서버 연결 후 구현 예정이며 이번 변경은 메뉴 UI와 로컬 저장 관리다.
- 불러오기 제목과 빈 목록·삭제 안내를 서버 명칭으로 통일. 저장된 서버 목록에 배경과 테두리가 있는 PanelContainer 추가.
- 두 화면의 이전 버튼: ← 이전. 왼쪽 정렬, PC 110 / 모바일 150 기준 최소 너비.
- 저장 목록의 삭제 앞에 이름 변경 버튼 추가. 입력 팝업에서 변경 또는 Enter로 저장, 빈 이름은 거부.
- RoomManager.rename_room은 해당 JSON의 room_name만 변경한다. 저장 시간, 진행 상태, 다른 필드 및 현재 방 선택은 보존한다. 현재 방과 같은 ID이면 메모리의 이름도 갱신한다.
- 임시 파일 쓰기 성공 후 교체하며 실패하면 원본 파일을 유지한다.
- Godot 4.7.1 임시 복사본에서 이름 변경 저장/재로딩, 빈 이름 및 없는 저장 거부, 진행·시간 보존, 생성·불러오기·삭제, PC·모바일 가상 크기 검증 통과.


## 37. 커스텀 초상화 선택 (2026-09-21)

- custom_character.gd: 초상화 이미지 선택 버튼은 파일 업로드 / 초상화 없이 시작 선택 팝업을 연다.
- 파일 업로드는 기존 Web 및 데스크톱 파일 선택기를 사용한다.
- 초상화 없이 시작은 검정 RGB 이미지를 기존 _accept_portrait_image 경로로 저장하고 미리보기에 적용한다. 기존 user://custom_portraits/ 저장과 다음 화면의 portrait_path 전달을 유지한다.
- 이름 입력 후 다음 버튼으로 진행한다. 팝업의 취소는 기존 선택을 유지한다.
- Godot 4.7.1 임시 복사본에서 팝업, 검정 PNG 저장, 이름 조건, 파일 선택기 및 다음 화면 경로 전달 검증 통과. 실제 브라우저 업로드는 별도 확인 필요.


## 38. 공통 캐릭터 설정 (2026-09-21)

- SettingsOverlay.gd를 Autoload로 등록. settings_gear.svg 아이콘으로 모든 화면 오른쪽 위에 설정 버튼 표시.
- 기존 화면 전환 없이 설정을 열고 이름(1~20자), 초상화(파일 업로드 또는 검정 이미지), 특성을 변경한다.
- 캐릭터와 최초 특성 선택이 끝나기 전에는 설정 안내만 표시하고 변경 저장을 비활성화한다.
- 설정을 여는 동안 게임 진행을 일시 정지하며 닫으면 이전 정지 상태로 복귀한다. 취소는 저장 데이터와 특성 횟수를 변경하지 않는다.
- 한 플레이는 저장된 서버 하나 기준. 로컬 멤버의 personality_changes_used 필드에 사용 횟수를 저장한다. 최대 3회, 최초 선택/동일 특성/취소는 미차감.
- 기존 저장 파일에서 필드가 없으면 0회 사용으로 취급한다. 선택적 멤버 필드 추가이므로 기존 SCHEMA_VERSION=4와 스토리 저장 구조 유지.
- 불러오기, 에피소드 재선택, 선택 되돌리기는 사용 횟수를 초기화하지 않는다. 새 서버 생성 시 새 멤버이므로 3회부터 시작한다.
- RoomManager.apply_character_settings에서 제한을 재검사하며 임시 JSON 파일 작성 후 교체한다. 새 초상화는 별도 파일로 저장해 취소/저장 실패가 기존 초상화를 덮어쓰지 않게 한다.
- 기존 set_selected_character 경로도 한도를 검사하고 bool 성공 여부를 반환한다. personality_select.gd는 실패 시 화면 이동하지 않는다.
- GameData.character_settings_changed 신호로 main.gd의 이름/PC·모바일 초상화를 즉시 갱신한다. 특성 변경 시 기존 관찰 문구를 지우고 다음 대사부터 새 특성을 적용한다. 스토리를 재시작하거나 재생하지 않는다.
- custom_character.gd의 portrait_picker_only 모드로 기존 Web/데스크톱 파일 선택과 검정 이미지 생성을 재사용한다. 설정에서는 저장 전까지 이미지가 메모리에만 존재한다.
- Godot 4.7.1 임시 프로젝트 검증: 설정 열기/닫기/취소, 검정 이미지 저장, 실시간 이름·초상화 반영, 3회 제한 및 기존 선택 화면 우회 차단, 불러오기/에피소드/이전 선택 후 횟수 보존, 저장 실패 시 상태 보존, PC 1536x648 및 모바일 가상 크기 배치 통과.
- 실제 모바일 웹 파일 업로드/키보드와 브라우저 새로고침 시 IndexedDB 동작은 배포 환경에서 별도 확인한다.


### 설정 UI 후속 조정

- 게임 화면의 톱니바퀴는 PC 게임 배경 영역(너비 1152) 오른쪽 위에 배치하고 토론 패널을 피한다. 모바일에서는 배경 상단 오른쪽. 버튼 크기는 PC 32 / 모바일 48, 아이콘은 20 / 26.
- 설정 폼은 현재 초상화 → 중앙 정렬 초상화 변경 버튼 → 이름 입력 → 특성 순서. 하단 버튼은 변경 저장 / 취소.
- 안내: ※ 특성 변경은 한 플레이(서버)당 최대 3회까지 가능합니다. 다음 줄에 변경한 정보는 다음 장면부터 적용됩니다. [남은 횟수: N회]
- 앞선 즉시 표시 설명을 대체: 변경 내용은 저장 시 기록하되 현재 게임 화면의 이름·초상화는 다음 dialogue_processed 때 갱신한다. 특성은 이후 대사 신호에 적용한다.
- Godot 4.7.1 임시 복사본에서 PC·모바일 배치 및 다음 장면 표시 갱신 검증 통과.


### 설정 횟수 표시 및 댓글 수정 UI 보완

- 남은 횟수 표시: [현재 남은 횟수 : N회].
- A→B→A는 2회 변경으로 계산한다. 이름·초상화만 변경하면 차감하지 않는다. 기존 로직으로 검증 통과.
- 톱니바퀴 버튼의 icon_alignment를 가운데로 설정.
- PC/모바일 댓글 수정 입력칸은 안쪽 1px 테두리와 좌우 8px 여백을 사용한다. 바깥으로 확장되는 기본 포커스 테두리를 대체하고 수정 시작 커서를 0으로 두어 앞부분을 표시한다.
- Godot 4.7.1 임시 복사본에서 횟수 계산과 PC/모바일 댓글 수정 입력칸 검증 통과.


### 기본 초상화 및 안내 간격 변경

- 첫 시작과 설정 화면의 공통 초상화 선택 문구를 초상화 미설정으로 변경.
- default_portrait.svg: 회색 바탕에 단순한 사람 실루엣을 표시하는 기본 초상화. 기존 이미지 저장 경로를 사용하며 설정의 초상화 변경 횟수는 차감하지 않는다.
- 기존에 저장된 검정 초상화는 자동 덮어쓰지 않는다. 초상화 미설정을 다시 선택하고 저장하면 새 이미지로 바뀐다.
- 특성 설명과 변경 제한 안내 사이에 상단 여백 10px 추가.
- Godot 4.7.1 임시 복사본에서 첫 시작 이미지 저장 및 설정 화면 선택 적용 검증 통과.


### 설정 표시 범위 및 서버 삭제 확인창

- 톱니바퀴는 에피소드 선택 후 main.tscn 게임 화면에서만 표시한다. 로그인·메뉴·캐릭터·특성·에피소드 선택 화면에서는 숨기며 설정 열기도 차단한다.
- 삭제 확인창은 기본 창 제목 대신 내부 중앙 제목(26px, FontVariation 굵기 적용)을 사용한다. 사방 24px 여백, 안내 두 문장은 빈 줄 없이 가운데 정렬.
- 삭제/취소 버튼은 132x48, 간격 12px로 중앙 배치. 안내 최소 너비를 지정해 자동 줄바꿈으로 창이 세로로 늘어나는 문제 방지.
- Godot 4.7.1 임시 복사본에서 화면별 설정 표시, 삭제창 크기·정렬, 취소 시 저장 보존 확인.


## 39. Supabase 비회원 인증 연결 (2026-09-21)

이 항목은 기존 서버 미연결 AuthManager 설명을 대체한다.

- SupabaseConfig.gd: 프로젝트 URL과 클라이언트 공개용 Publishable key 보관. Secret/service_role 키 및 DB 비밀번호는 사용하지 않는다.
- 프로젝트 URL: https://emcnxoqmdhksahtaxfqc.supabase.co
- AuthManager.enter_guest_mode()는 비동기 String 결과 함수다. 빈 문자열은 성공, 나머지는 사용자 안내 오류다. 호출자는 await한다.
- 최초 접속: POST /auth/v1/signup (data: {})로 익명 사용자 생성. 공개 키는 apikey 헤더에 전달한다.
- 재실행: POST /auth/v1/token?grant_type=refresh_token으로 세션을 갱신하여 동일한 사용자 ID 복구.
- 세션은 user://supabase_session.json에 저장한다. 프로젝트 URL, 사용자 ID, access/refresh token, expires_at을 보관하며 토큰을 로그에 출력하지 않는다.
- 익명 인증 성공: is_guest=true, is_authenticated=true, is_logged_in=false. is_logged_in은 정식 회원 계정 로그인 여부를 뜻한다.
- 로그인 UI는 인증 중 입력·버튼 비활성화, 중복 요청 방지. 성공 후 기존 res://start.tscn으로 이동한다.
- 실패 시 재시도 가능하며 로컬로만 플레이 버튼을 표시한다. 로컬 모드는 온라인 인증 상태를 사용하지 않지만 기존 온라인 세션 파일과 게임 저장은 보존한다.
- 네트워크 실패, 잘못된 캐시, 만료/폐기된 refresh token 때문에 새 익명 계정을 자동 생성하지 않는다. 기존 계정 복구 실패를 안내한다.
- 30초마다 만료 임박 여부 확인 후 갱신. 이후 온라인 요청은 await AuthManager.get_access_token()을 사용한다. 빈 토큰이면 요청을 중단한다.
- sign_out은 로컬 인증만 제거하며 서버 세션 취소 API는 아직 연결하지 않았다. 익명 계정은 로그아웃 후 복구가 어려우므로 실제 로그아웃 UI 연결 전에 정책을 정한다.
- 이메일 로그인/회원가입은 준비 중 안내 유지. 클라우드 저장, 방 생성/코드 참가/Realtime은 아직 미구현.
- RoomManager와 LOCAL_1, 기존 user://rooms/ 저장은 유지했다. Supabase 사용자 ID와 온라인 방 멤버의 연결은 다음 단계에서 구현한다.
- 검증: Godot 4.7.1 임시 복사본에서 실제 Supabase 익명 사용자 생성, 프로세스 재실행 시 같은 ID 복구, 비회원 버튼→start.tscn 이동 및 중복 클릭 방지 통과.
- 테스트 사용자 ID: de46cc20-d16a-4b6c-a2fb-fe50b1b270e5. 테스트 세션은 게임 본래 저장과 분리된 CodexSupabaseValidation에 보관한다.
- 모의 응답 검증: 네트워크 실패·저장 실패·손상된 캐시·ID 불일치·만료 토큰 갱신·오프라인 상태 및 캐시 보존 통과.
- 실제 웹 배포에서 브라우저 IndexedDB 세션 유지 및 모바일 인증은 추가 확인 필요. 테스트 프로젝트의 Anonymous Sign-Ins 활성화 후 실제 연결 성공.
