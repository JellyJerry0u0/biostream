# GitHub에 프로젝트 올리기 가이드

## 1. GitHub 저장소 생성

1. GitHub 웹사이트(https://github.com)에 로그인
2. 우측 상단의 "+" 버튼 클릭 → "New repository" 선택
3. 저장소 이름 입력 (예: `biostream`)
4. Public 또는 Private 선택
5. **"Initialize this repository with a README" 체크박스는 해제** (이미 로컬에 프로젝트가 있으므로)
6. "Create repository" 클릭

## 2. 로컬에서 Git 초기화 및 커밋

터미널에서 프로젝트 디렉토리로 이동한 후 다음 명령어를 실행:

```bash
# Git 초기화 (아직 안 했다면)
git init

# 현재 상태 확인
git status

# 모든 파일 추가
git add .

# 첫 커밋
git commit -m "Initial commit: Flutter biostream app"

# GitHub 저장소를 원격 저장소로 추가
# YOUR_USERNAME과 REPOSITORY_NAME을 실제 값으로 변경하세요
git remote add origin https://github.com/YOUR_USERNAME/REPOSITORY_NAME.git

# 또는 SSH를 사용하는 경우:
# git remote add origin git@github.com:YOUR_USERNAME/REPOSITORY_NAME.git

# 브랜치 이름을 main으로 변경 (필요한 경우)
git branch -M main

# GitHub에 푸시
git push -u origin main
```

## 3. 인증 문제 해결

만약 인증 오류가 발생하면:

### Personal Access Token 사용 (HTTPS)
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token" 클릭
3. 필요한 권한 선택 (repo 권한 필수)
4. 토큰 생성 후 복사
5. 비밀번호 대신 이 토큰을 사용

### SSH 키 사용
```bash
# SSH 키 생성 (이미 있다면 생략)
ssh-keygen -t ed25519 -C "your_email@example.com"

# SSH 키를 GitHub에 추가
# ~/.ssh/id_ed25519.pub 파일 내용을 복사하여
# GitHub → Settings → SSH and GPG keys → New SSH key에 추가

# 원격 저장소를 SSH로 변경
git remote set-url origin git@github.com:YOUR_USERNAME/REPOSITORY_NAME.git
```

## 4. 이후 업데이트 방법

코드를 수정한 후:

```bash
# 변경사항 확인
git status

# 변경된 파일 추가
git add .

# 또는 특정 파일만 추가
git add lib/screens/coach_screen.dart

# 커밋
git commit -m "설명: 변경 내용 요약"

# GitHub에 푸시
git push
```

## 5. .gitignore에 포함된 항목

다음 항목들은 자동으로 제외됩니다:
- 빌드 파일들 (`/build/`, `/android/app/debug`, 등)
- 의존성 파일들 (`.dart_tool/`, `.flutter-plugins`, `pubspec.lock`)
- IDE 설정 파일들 (`.idea/`, `*.iml`)
- OS 파일들 (`.DS_Store`)
- 플랫폼별 생성 파일들 (iOS, Android, macOS, Windows, Linux)

## 6. 주의사항

- **민감한 정보는 절대 커밋하지 마세요**: API 키, 비밀번호, 인증서 등
- `local.properties` 파일은 이미 .gitignore에 포함되어 있습니다
- `pubspec.lock`은 일반적으로 제외하지만, 팀 프로젝트라면 포함할 수도 있습니다

