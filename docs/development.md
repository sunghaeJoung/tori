# 토리 — 개발 방향

기획 내용은 [planning.md](planning.md) 참고.

## 1. 기술 스택과 선택 이유

| 영역           | 선택                           | 이유                                                                                                         |
| -------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| 앱             | **Flutter (Dart)**             | 코드 하나로 웹·iOS·Android를 모두 만들 수 있다. 웹으로 먼저 친구들과 써보고 나중에 폰 앱으로 확장하기 좋다   |
| 라우팅         | **go_router**                  | URL 기반 라우팅. 웹에서 초대 링크(`/join/ABC123`)를 바로 열 수 있다                                          |
| 상태 관리      | **riverpod**                   | 서버 데이터의 로딩·에러·캐싱과 화면 간 공유 상태를 한 방식으로 다룬다                                        |
| 백엔드         | **Supabase**                   | DB, 로그인, 실시간 동기화, API를 한 번에 제공해서 서버 코드를 직접 짜지 않아도 된다. 무료 플랜으로 충분하다  |
| DB             | **PostgreSQL** (Supabase 내장) | 여행-멤버-지출-분배처럼 관계가 뚜렷한 데이터에 맞는 표 형태 DB                                               |
| 로그인         | **Supabase 익명 로그인**       | 회원가입 없이 기기별로 사용자를 구분한다                                                                     |
| 보안           | **RLS** (행 단위 보안)         | 그 여행의 멤버만 데이터를 읽고 쓸 수 있도록 DB에서 직접 막는다                                               |
| 실시간         | **Supabase Realtime**          | 친구가 입력한 지출을 내 화면에 바로 반영한다                                                                 |
| 환율           | **Frankfurter API**            | 무료, API 키가 필요 없다. 유럽중앙은행 기준 환율로 KRW·JPY·CNY·USD를 모두 지원한다. 정산할 때만 1번 호출한다 |
| 숫자·날짜 표기 | **intl**                       | `12,350원` 같은 한국식 숫자·날짜 포맷                                                                        |
| 공유           | **share_plus**                 | 카톡 등으로 초대 링크를 보내는 시스템 공유 시트                                                              |
| 글꼴           | **Pretendard** (앱에 포함)     | 한글 가독성이 좋은 무료 글꼴                                                                                 |
| 웹 배포        | **Vercel** 또는 **Netlify**    | `flutter build web` 결과물(정적 파일)을 무료로 올려 친구들에게 링크로 공유한다                               |

## 2. DB 설계

### 테이블

```
trips 1 ──── N members
trips 1 ──── N expenses 1 ──── N expense_splits N ──── 1 members
trips 1 ──── N settlements
```

**trips** — 여행방

| 컬럼                 | 타입              | 설명                                             |
| -------------------- | ----------------- | ------------------------------------------------ |
| id                   | uuid PK           |                                                  |
| name                 | text              | 여행 이름                                        |
| start_date, end_date | date              | 기간                                             |
| local_currency       | text              | `KRW` / `JPY` / `CNY` / `USD`                    |
| settle_currency      | text              | `KRW` (고정)                                     |
| settle_rate          | numeric           | 확정 환율 (현지 통화 1단위 → 원). 확정 전엔 null |
| settle_rate_date     | date              | 환율 기준일                                      |
| settled_at           | timestamptz       | 정산을 확정한 시각                               |
| expenses_changed_at  | timestamptz       | 지출이 마지막으로 바뀐 시각 (트리거가 갱신)      |
| settlements_changed_at | timestamptz     | 송금 완료 체크가 바뀐 시각 (실시간 알림용)       |
| invite_code          | text unique       | 8자리 초대 코드 (암호학적 난수)                  |
| created_by           | uuid → auth.users |                                                  |
| created_at           | timestamptz       |                                                  |

**members** — 여행 멤버

| 컬럼         | 타입                         | 설명                               |
| ------------ | ---------------------------- | ---------------------------------- |
| id           | uuid PK                      |                                    |
| trip_id      | uuid → trips                 |                                    |
| name         | text                         | 표시 이름                          |
| sort_order   | int                          | 멤버 순서 (지출 나누기 나머지 기준) |
| user_id      | uuid → auth.users, null 허용 | "나는 누구?"에서 선택하면 연결된다 |
| bank_account | text, null 허용              | v2                                 |

- `(trip_id, user_id)` unique: 한 사람이 한 여행에서 멤버 하나만 차지
- `(trip_id, name)`, `(trip_id, sort_order)` unique

**expenses** — 지출

| 컬럼                   | 타입              | 설명                                                                           |
| ---------------------- | ----------------- | ------------------------------------------------------------------------------ |
| id                     | uuid PK           |                                                                                |
| trip_id                | uuid → trips      |                                                                                |
| title                  | text              | 내용                                                                           |
| amount                 | bigint            | 통화의 최소 단위 정수                                                          |
| currency               | text              | 여행의 현지 통화 또는 `KRW`                                                    |
| paid_by                | uuid → members    | 낸 사람                                                                        |
| category               | text              | `lodging`, `food`, `transport`, `cafe`, `drink`, `activity`, `shopping`, `etc` |
| spent_at               | date              | 지출 날짜                                                                      |
| created_by             | uuid → auth.users |                                                                                |
| created_at, updated_at | timestamptz       |                                                                                |

**expense_splits** — 지출별 부담액

| 컬럼         | 타입                             | 설명                              |
| ------------ | -------------------------------- | --------------------------------- |
| expense_id   | uuid → expenses (cascade delete) |                                   |
| member_id    | uuid → members                   |                                   |
| share_amount | bigint                           | 지출과 같은 통화의 최소 단위 정수 |

- PK `(expense_id, member_id)`
- 규칙: 한 지출의 `share_amount` 합계 = `expenses.amount`
  - 지출과 분배를 한 트랜잭션에서 넣을 수 있도록, 커밋 직전에 검사하는 트리거(deferred constraint trigger)로 막는다
  - 분배받는 멤버·낸 사람은 같은 여행 멤버여야 한다. 지출 통화는 여행 현지 통화 또는 `KRW`

**settlements** — 송금 기록

| 컬럼                   | 타입                   | 설명                        |
| ---------------------- | ---------------------- | --------------------------- |
| id                     | uuid PK                |                             |
| trip_id                | uuid → trips           |                             |
| from_member, to_member | uuid → members         |                             |
| amount_krw             | bigint                 | 10원 단위로 반올림한 송금액 |
| done_at                | timestamptz, null 허용 | 송금 완료 체크 시각         |

- 정산을 확정할 때 계산 결과로 다시 만든다. "정산 다시 하기"를 하면 지우고 새로 만든다
- `confirm_settlement(여행, 계산에 쓴 지출 버전, 환율, 기준일, 보내는 멤버들, 받는 멤버들, 금액들)` RPC로만 만든다. 원화 여행은 환율 1
  - 송금 목록은 앱의 `settle()`이 계산한다 (정산 알고리즘은 `core/money` 한 곳에만 둔다). DB는 금액 > 0 · 10원 단위 · 같은 여행 멤버만 막고, 잔액과 맞는지는 검사하지 않는다 (초대 코드를 아는 친구끼리의 신뢰)
  - 지출 버전(`expenses_changed_at`)이 그사이 바뀌었으면 거절한다. 옛 지출로 계산한 송금 목록이 확정되지 않게
- 정산 뒤 지출이 바뀌면(`expenses_changed_at > settled_at`) 앱이 "지출이 바뀌었어요. 정산을 다시 해주세요"로 보여준다

### 저장 규칙

- 금액은 모두 정수(`bigint`), 환율만 `numeric`으로 저장한다
- 통화별 소수 자리수는 앱 코드에 상수로 둔다: `KRW=0, JPY=0, CNY=2, USD=2`

### 보안(RLS)과 입장 흐름

- 공통 함수 `is_trip_member(trip_id)`: 현재 로그인한 사용자가 그 여행의 멤버(`members.user_id`)인지 확인
- 모든 테이블의 읽기·쓰기는 `is_trip_member`가 참일 때만 허용
- 아직 멤버가 아닌 사람이 초대 코드로 들어오는 단계는 RLS로 막히므로 DB 함수(RPC) 2개로 처리한다
  - `preview_trip(invite_code)` → 여행 이름·기간·통화와 멤버 이름 목록(연결 여부 포함)만 돌려준다
  - `claim_member(invite_code, member_id)` → 선택한 멤버에 내 `user_id`를 연결한다
  - 브라우저를 바꿔 다시 들어온 친구가 자기 이름을 다시 고를 수 있도록, 이미 연결된 멤버도 다시 연결할 수 있게 허용한다 (초대 코드를 아는 친구끼리의 신뢰를 전제로 한 선택)
- 여행을 만든 사람은 만들 때 자기 멤버에 바로 연결된다
  - 여행·멤버는 직접 insert할 수 없고 `create_trip(이름, 기간, 통화, 내 이름, 친구 이름들)` RPC로만 만든다. 멤버 순서는 나 → 친구들 입력 순서
- 지출과 분배는 `save_expense(여행, 지출 id 또는 null, 내용, 금액, 통화, 낸 사람, 카테고리, 날짜, 멤버 id들, 부담액들)` RPC로만 추가·수정한다. 한 트랜잭션이라 반쯤 저장된 지출이 없다. 지우기는 `expenses` delete (분배는 cascade)
- 고칠 수 있는 열만 열어둔다: 초대 코드·만든 사람·소속 여행은 바꿀 수 없다
- 실시간 반영: 지출이 바뀌면 트리거가 `trips.expenses_changed_at`을 갱신하고, 앱은 여행 행 하나만 Supabase Realtime으로 구독해 바뀌면 지출을 다시 불러온다
  - Realtime의 delete 이벤트는 필터·RLS가 적용되지 않아 지출 테이블을 직접 구독하지 않는다
  - 정산 뒤 지출이 바뀌었는지(`settled_at`과 비교) 판단하는 데도 쓴다
  - 정산 확정(`settled_at` 등)이나 송금 완료 체크(`settlements_changed_at`)도 여행 행을 바꾸므로 같은 구독으로 받는다. 앱은 알림이 오면 여행 정보·송금 목록을 다시 불러오고, `expenses_changed_at`이 바뀌었을 때만 지출 목록도 다시 불러온다
- 환율은 Frankfurter(`api.frankfurter.dev`, 유럽중앙은행 고시, 키 없음·HTTPS·CORS)에서 받는다. 못 받으면 직접 입력해서 정산한다
- 마이그레이션은 `supabase/migrations/`에 두고 `supabase db push`로 적용한다. RLS 점검은 `dart run tool/rls_check.dart`

## 3. 정산 알고리즘

모두 앱 안에서 계산하는 순수 함수로 만든다. UI나 서버와 분리되어 있어서 테스트하기 쉽다.

### 3-1. 지출 나누기 (`splitEvenly`)

```
입력: amount(최소 단위 정수), 참여 멤버 목록(멤버 순서 고정)
몫 = amount ÷ 인원 (정수 나눗셈)
나머지 = amount mod 인원
앞에서부터 나머지 개수만큼 몫 + 1, 나머지는 몫
```

- 예: 5,850(58.50위안) ÷ 4 → 1,463 / 1,463 / 1,462 / 1,462
- 결과는 `expense_splits`에 저장한다. 나중에 멤버 순서가 바뀌어도 지난 지출 금액은 변하지 않는다

### 3-2. 잔액 (`computeBalances`)

```
통화별로, 멤버마다:
  잔액 = (그 멤버가 낸 지출 amount 합) − (그 멤버의 share_amount 합)
```

- 통화별 잔액 합계는 항상 0이다 (검증용)

### 3-3. 원화 환산

```
멤버 원화 잔액 = 현지 통화 잔액 ÷ 10^자리수 × settle_rate + 원화 잔액
```

- 소수를 정확히 계산하는 decimal 타입으로 계산하고, **이 단계에선 반올림하지 않는다**

### 3-4. 최소 송금 매칭 (`settle`)

```
받을 사람 = 잔액 > 0, 줄 사람 = 잔액 < 0
반복:
  가장 많이 받을 사람 C, 가장 많이 줄 사람 D를 고른다
  x = min(C 받을 돈, D 줄 돈)
  "D → C : x" 기록
  C, D에서 x만큼 빼고, 0이 된 사람은 목록에서 제외
둘 중 한 목록이 빌 때까지
```

- 송금 건수는 최대 (인원 − 1)
- 마지막으로 각 송금액 x만 **10원 단위로 반올림** (5원 이상 올림)

### 3-5. 검증용 예시: 4명 중국 여행 (환율 1위안 = 192.35원 가정)

멤버 순서: 민지, 수아, 지훈, 하린

| 지출          | 금액         | 낸 사람 | 나눌 사람      |
| ------------- | ------------ | ------- | -------------- |
| 항공권        | 1,200,000원  | 수아    | 전원           |
| 훠궈 저녁     | 680.00위안   | 민지    | 전원           |
| 디디 택시     | 58.50위안    | 지훈    | 전원           |
| 호텔 2박      | 4,800.00위안 | 하린    | 전원           |
| 맥주          | 96.00위안    | 지훈    | 민지·지훈·하린 |
| 밀크티        | 45.00위안    | 수아    | 전원           |
| 와이탄 크루즈 | 480.00위안   | 민지    | 전원           |

| 멤버 | 위안 잔액     | 원화 잔액  | 원화 환산 합계 |
| ---- | ------------- | ---------- | -------------- |
| 민지 | −387.88위안   | −300,000원 | −374,608.72원  |
| 수아 | −1,470.88위안 | +900,000원 | +617,076.23원  |
| 지훈 | −1,393.37위안 | −300,000원 | −568,014.72원  |
| 하린 | +3,252.13위안 | −300,000원 | +325,547.21원  |

정산 결과 (송금 3건):

| 송금        | 계산값       | 10원 반올림   |
| ----------- | ------------ | ------------- |
| 지훈 → 수아 | 568,014.72원 | **568,010원** |
| 민지 → 하린 | 325,547.21원 | **325,550원** |
| 민지 → 수아 | 49,061.51원  | **49,060원**  |

이 예시는 그대로 단위 테스트 케이스로 쓴다.

## 4. 폴더 구조 초안

기능(feature)별로 폴더를 나누고, 돈 계산 로직은 `core/money`에 따로 모은다.

```
tori/
├── docs/
│   ├── planning.md
│   └── development.md
├── lib/
│   ├── main.dart                  # 앱 시작점, Supabase 초기화
│   ├── app/
│   │   ├── router.dart            # go_router 경로 정의
│   │   └── theme.dart             # 컬러, 글꼴, 다크 모드
│   ├── core/
│   │   ├── money/
│   │   │   ├── currency.dart      # 통화 목록, 소수 자리수, 표기 방법
│   │   │   ├── money_format.dart  # 12,350원 / 128.50위안 포맷
│   │   │   ├── split.dart         # splitEvenly
│   │   │   └── settlement.dart    # computeBalances, settle
│   │   ├── supabase/
│   │   │   └── supabase_client.dart
│   │   └── exchange_rate/
│   │       └── frankfurter_api.dart
│   ├── features/
│   │   ├── onboarding/            # 첫 실행, 닉네임
│   │   ├── trips/                 # 홈, 여행 만들기, 여행 설정
│   │   ├── invite/                # 초대하기, 나는 누구?
│   │   ├── expenses/              # 지출 내역, 지출 추가/수정
│   │   ├── balances/              # 잔액
│   │   └── settlement/            # 환율 확인, 정산 결과
│   │   (각 기능 폴더 안: data/ 저장소, providers.dart, ui/ 화면·위젯)
│   └── shared/
│       └── widgets/               # 공통 버튼, 금액 표시, 빈 화면 등
├── assets/
│   ├── fonts/                     # Pretendard
│   └── images/                    # 토리 캐릭터
├── supabase/
│   └── migrations/                # 테이블, RLS, RPC SQL
└── test/
    └── core/money/                # 나누기·정산 단위 테스트
```

## 5. 개발 단계 로드맵

목표: 10/21(수) 시작 → 10/25(일) 완성 → 11/1(일) 중국 여행에서 실사용. 그 사이 주중은 버그 수정용 여유.

진행 원칙: 기반(셋업 → 돈 계산 로직 → 테마·라우팅 → DB)을 먼저 깔고, 그 다음은 기능 하나를 화면 + DB + 저장까지 끝까지 완성하는 순서로 간다.

| 일정  | 단계                      | 할 일                                                                          | 끝났다는 기준                                 |
| ----- | ------------------------- | ------------------------------------------------------------------------------ | --------------------------------------------- |
| 수    | 0. 프로젝트 셋업          | Flutter 웹 프로젝트, gitignore·env, 패키지, 폴더 구조, 글꼴, git 훅, CLAUDE.md | `flutter run -d chrome`으로 빈 앱 실행        |
| 수    | 1. 돈 계산 로직           | `core/money` 구현 + 단위 테스트 (3-5 예시 포함)                                | `flutter test` 전부 통과                      |
| 목    | 2. 테마·라우팅·공통 위젯  | 토리 테마, go_router 경로, 공통 버튼·금액 표시·빈 화면                         | 빈 화면들 사이 이동이 됨                      |
| 목    | 3. Supabase 연결          | 테이블·RLS·RPC 마이그레이션, 익명 로그인                                       | 자동 로그인, 남의 데이터가 안 보임            |
| 목    | 4. 첫 실행·홈·여행 만들기 | 닉네임 → 홈 → 단계형 여행 만들기 → DB 저장                                     | 새로고침해도 여행이 남아 있음                 |
| 금    | 5. 초대·나는 누구?        | 초대 화면, `/join/:code` → 멤버 선택 → 입장                                    | 일반 창 + 시크릿 창으로 같은 여행방 입장      |
| 금    | 6. 지출                   | 지출 내역·추가·수정·삭제, 분배 저장, 실시간 반영                               | 한 창에서 입력하면 다른 창에 바로 보임        |
| 토    | 7. 잔액·정산              | 잔액, 환율 조회 + 직접 입력 대체, 환율 확정 → 송금 목록, 완료 체크             | 3-5 예시 입력 시 568,010 / 325,550 / 49,060원 |
| 일    | 8. 다듬기·배포            | 빈 화면·오류·로딩 정리, CDN 없이 웹 빌드, Vercel 배포                          | 친구들 폰에서 접속·입력 성공                  |
| 월~토 | 여유                      | 피드백 반영, 버그 수정                                                         | 출발 전 안정화                                |

### 이번 주 범위

- 넣는 것: 여행 만들기(통화 4종), 초대 + 나는 누구?, 지출 추가·수정·삭제(전원/일부 균등 분배), 잔액, 환율 확정 → 원화 송금 목록, 송금 완료 체크, 실시간 동기화, 웹 배포
- 앞당기는 것: 환율 직접 입력 (해외에서 환율 API가 막힐 때 대비)
- 미루는 것: 계좌 복사·송금 앱 연결, 다크 모드, 여행 설정 화면, 정산 완료 축하 화면(시간 남으면), 카카오 공유(링크 복사 + 휴대폰 공유창으로 대체)

## 6. 개발 규칙

### 브랜치·커밋·PR

- 브랜치: `main`(배포용) · `develop`(개발 통합) · 작업 브랜치 `feature/<단계>-<이름>`
- 작업 브랜치 → develop 대상 PR → GitHub에서 리뷰·머지. **main 직접 push 금지**, main은 `develop → main` PR로만 반영
- 커밋은 작업 단위로 나누고 Conventional Commits + 한글 설명 (`feat:` `fix:` `chore:` `test:` `docs:` `refactor:`)
- git 훅(`.githooks/`): pre-commit에서 gitleaks 비밀정보 검사, pre-push에서 main push 차단

### 보안

- 앱 설정값은 `env/*.json`(gitignore)에 두고 `--dart-define-from-file`로 주입. 저장소에는 `env/example.json`만
- 웹 앱에 들어간 값은 누구나 볼 수 있다 → 앱에는 Supabase **공개용 키(publishable/anon)만**. service_role/secret 키는 앱·저장소에 절대 넣지 않는다
- 실제 보안은 DB가 책임진다: 모든 테이블 RLS, 기본 거부, 여행 멤버만 접근. RPC는 `security definer` + `set search_path = ''`, 최소 정보만 반환
- DB 제약조건으로 잘못된 값 차단: 금액 > 0, 통화 4종, 이름 길이, 분배 합계 = 지출 금액
- 서로 다른 사용자(일반 창 + 시크릿 창)로 남의 여행에 접근할 수 없는지 직접 확인한다

## 7. 중국에서 쓸 때 주의

- Flutter 웹은 기본 설정에서 Google CDN(gstatic)에서 엔진과 대체 글꼴을 받는다. 중국 현지 망에서는 막힐 수 있다
  - `flutter build web --no-web-resources-cdn`으로 엔진을 함께 배포하고, 글꼴(Pretendard)은 앱에 포함한다
- Supabase·Vercel 등 해외 서버도 현지 망에서 불안정할 수 있다
  - 한국 통신사 로밍이나 로밍형 eSIM은 보통 한국 쪽을 거쳐 나가므로 영향이 적다. 출발 전 친구들 폰으로 접속을 꼭 확인한다
