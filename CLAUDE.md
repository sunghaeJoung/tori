# CLAUDE.md

토리: 친구들끼리 쓰는 여행 경비 정산 앱 (한국판 Tricount). Flutter 웹으로 먼저 만들고, 백엔드는 Supabase.
기획은 [docs/planning.md](docs/planning.md), 기술·DB·정산 알고리즘·로드맵은 [docs/development.md](docs/development.md)가 기준이다. 범위나 규칙이 바뀌면 문서도 같이 고친다.

## 진행 방식

- **모든 답변·설명·질문은 한국어로 쓴다.** 영어로 답하지 않는다. (코드·명령어·고유명사는 원문 그대로)
- 사용자는 Next.js 프론트 개발자이고 Flutter는 처음이다. Claude가 구현하고 사용자가 리뷰한다.
- 로드맵(development.md 5장)의 단계 하나씩 진행한다. 단계가 끝나면 PR을 만들고 멈춘 뒤, 새로 나온 Flutter/Dart 개념을 짧게 설명한다. 사용자가 머지하기 전에는 다음 단계로 넘어가지 않는다.
- 화면은 프로토타입 캔버스를 기준으로 만든다: https://claude.ai/artifact/5uegyZ6hZZrwM8SkgSBtfR

## 명령어

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=env/dev.json   # 개발 실행
flutter test                                                 # 단위·위젯 테스트
flutter analyze                                              # 정적 분석 (경고 0 유지)
flutter build web --no-web-resources-cdn --dart-define-from-file=env/prod.json   # 배포 빌드
supabase db push                                             # 마이그레이션을 Supabase에 적용
dart run tool/rls_check.dart                                 # 두 익명 사용자로 RLS 점검
```

- 배포 빌드는 반드시 `--no-web-resources-cdn`을 붙인다. 엔진(CanvasKit)을 Google CDN이 아닌 우리 배포 파일에서 읽게 해서 중국에서도 앱이 뜨게 한다.

## 폴더 구조

```
lib/
  main.dart              앱 시작점, Supabase 초기화
  app/                   router.dart(go_router 경로), theme.dart(컬러·글꼴)
  core/money/            통화 정의, 금액 포맷, 나누기, 잔액·정산 계산 (순수 Dart, UI·서버 의존 금지)
  core/supabase/         Supabase 클라이언트
  core/exchange_rate/    Frankfurter 환율 API
  features/<기능>/       onboarding, trips, invite, expenses, balances, settlement
                         각 기능 안: data/(저장소), providers.dart(riverpod), ui/(화면·위젯)
  shared/widgets/        공통 버튼, 금액 표시, 빈 화면, 라벨 입력칸, 배지 등
  shared/dates.dart      날짜 표기(2026.11.06)와 DB 날짜 문자열
  shared/limits.dart     이름 길이·멤버 수 제한 (DB 제약조건과 같게)
assets/fonts/            Pretendard 400/600/700/800 (OFL)
assets/images/           토리 캐릭터 등
supabase/migrations/     테이블·RLS·RPC SQL
test/                    lib/ 구조를 그대로 따른다 (예: test/core/money/)
env/                     example.json만 커밋. dev.json·prod.json은 gitignore
```

## 브랜치·커밋·PR

- 브랜치: `main`(배포) · `develop`(통합) · 작업 브랜치 `feature/<단계>-<이름>` (예: `feature/1-money-logic`)
- 작업 브랜치는 최신 `develop`에서 만들고, push 후 **`develop` 대상 PR**을 `gh pr create --base develop`으로 만든다. 머지는 사용자가 GitHub에서 한다.
- **main에 직접 커밋·push 금지.** main은 배포 때 `develop → main` PR로만 바꾼다. `--no-verify`로 훅을 우회하지 않는다.
- 커밋은 작업 단위로 잘게 나눈다 (예: 테스트 추가, 기능 구현, 화면 연결을 각각). 메시지는 Conventional Commits + 한글 설명:
  `feat:` `fix:` `chore:` `test:` `docs:` `refactor:` → `feat: 지출 추가 화면 키패드 구현`
- 커밋 메시지에 `Co-Authored-By` 줄을 붙이지 않는다.

## 돈 계산 규칙

- 금액은 항상 **해당 통화의 최소 단위 정수**(`int`, DB는 `bigint`)로 다룬다. `double`로 금액을 계산하지 않는다.
  - 소수 자리수: KRW 0, JPY 0, CNY 2, USD 2
- 지출 나누기는 입력한 통화의 최소 단위로 하고, 나머지는 멤버 순서대로 앞사람부터 1단위씩 더 낸다. 분배 합계는 항상 원래 금액과 같아야 한다.
- 환율은 정산하는 날의 환율 하나를 모든 지출에 적용한다. 환율·원화 환산은 `decimal` 패키지로 계산하고 중간에 반올림하지 않는다.
- **송금 금액만 마지막에 10원 단위로 반올림**한다.
- 표기: `12,350원` · `1,500엔` · `128.50위안` · `$12.99` (엔화·위안화에 `¥` 기호를 쓰지 않는다)
- development.md 3-5의 4명 예시(568,010 / 325,550 / 49,060원)는 회귀 테스트로 유지한다.

## 보안 규칙

- 설정값은 `env/*.json`에 두고 `--dart-define-from-file`로 주입해 `String.fromEnvironment`로 읽는다. 코드·문서·커밋에 실제 키 값을 쓰지 않는다.
- **웹 번들에 들어간 값은 공개된다.** 앱에는 Supabase 공개용 키(publishable/anon)만 넣는다. service_role/secret 키는 앱·저장소·env 파일에 절대 넣지 않는다. 필요하면 터미널 환경변수로만 쓴다.
- 데이터 보호는 DB가 책임진다.
  - 모든 테이블에 RLS를 켜고 기본 거부. 여행 멤버(`is_trip_member`)만 읽기·쓰기 허용
  - RPC는 `security definer` + `set search_path = ''`로 만들고, 필요한 최소 정보만 반환
  - 금액 > 0, 통화 4종, 이름 길이, 분배 합계 = 지출 금액을 DB 제약조건으로도 막는다
  - 초대 코드는 암호학적 난수 8자리
- RLS·RPC를 바꾸면 서로 다른 익명 사용자(일반 창 + 시크릿 창)로 남의 여행에 접근할 수 없는지 확인한다. `tool/rls_check.dart`에 점검 항목을 추가하고 돌린다.
- 패키지는 신뢰할 수 있는 것만 추가하고 `pubspec.lock`을 커밋한다. 외부 통신은 HTTPS만 쓴다.
- git 훅(`.githooks/`, `git config core.hooksPath .githooks`): pre-commit에서 gitleaks 비밀정보 검사, pre-push에서 main push 차단.

## UI 규칙

- 글꼴은 테마에서 `Pretendard`로 지정한다. Google Fonts 패키지·CDN은 쓰지 않는다 (중국에서 막힐 수 있음).
- 화면에 이모지를 쓰지 않는다. Pretendard에 없는 글자는 Google CDN에서 대체 글꼴을 받아오기 때문이다. 아이콘은 Material Icons 또는 직접 그린 아이콘을 쓴다.
- 받을 돈 = 파랑, 줄 돈 = 빨강. 터치 영역은 최소 44px.
