# 토리

친구들과 여행하며 쓴 돈을, 여행이 끝나면 원화로 깔끔하게 나눠주는 정산 앱 (Flutter 웹 + Supabase)

- 기획안: [docs/planning.md](docs/planning.md)
- 개발 방향: [docs/development.md](docs/development.md)
- 개발 규칙·명령어: [CLAUDE.md](CLAUDE.md)

## 처음 설정

```sh
brew install gitleaks                    # 비밀정보 검사 도구
git config core.hooksPath .githooks      # 커밋·push 검사 훅 켜기
cp env/example.json env/dev.json         # 값 채우기 (공개용 키만)
flutter pub get
```

## 실행

```sh
flutter run -d chrome --dart-define-from-file=env/dev.json
```
