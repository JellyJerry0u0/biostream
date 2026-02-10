# Notion API 설정 가이드

## 1. Notion Integration 생성

### 1.1 Notion Integration 만들기
1. [Notion Integrations 페이지](https://www.notion.so/my-integrations) 접속
2. **"+ New integration"** 클릭
3. Integration 정보 입력:
   - **Name**: `BioStream Report Exporter` (원하는 이름)
   - **Logo**: (선택사항)
   - **Associated workspace**: 사용할 Workspace 선택
4. **Capabilities** 설정:
   - ✅ Read content
   - ✅ Update content
   - ✅ Insert content
5. **Submit** 클릭

### 1.2 Integration Token 복사
- Integration 생성 후 표시되는 **"Internal Integration Token"** 복사
- 형식: `secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- ⚠️ 이 토큰은 절대 공유하지 마세요!

---

## 2. Notion Database 또는 Page 설정

### 방법 A: Database에 페이지 생성 (권장)

#### 2.1 Database 생성 또는 선택
1. Notion에서 Database 페이지 열기 (또는 새로 생성)
2. Reports를 저장할 Database 준비

#### 2.2 Database에 Integration 연결
1. Database 페이지 우측 상단 **"..."** 클릭
2. **"Connections"** 또는 **"Add connections"** 클릭  
3. 앞서 생성한 Integration 선택 (예: `BioStream Report Exporter`)

#### 2.3 Database ID 복사
- Database 페이지 URL에서 ID 추출
- URL 형식: `https://www.notion.so/workspace/{database_id}?v=...`
- `{database_id}` 부분 복사 (32자리 영숫자, 하이픈 포함 또는 제외)

**예시:**
```
URL: https://www.notion.so/myworkspace/a1b2c3d4e5f6789012345678901234567?v=...
Database ID: a1b2c3d4e5f6789012345678901234567
```

### 방법 B: Page 하위에 페이지 생성

#### 2.1 Parent Page 선택
1. Reports를 저장할 Parent Page 열기

#### 2.2 Page에 Integration 연결
1. Page 우측 상단 **"..."** 클릭
2. **"Connections"** 또는 **"Add connections"** 클릭
3. Integration 선택

#### 2.3 Page ID 복사
- Page URL에서 ID 추출
- URL 형식: `https://www.notion.so/Title-{page_id}`
- `{page_id}` 부분 복사

---

## 3. 환경 변수 설정

### 3.1 `.env` 파일 수정
`backend/tools/.env` 파일을 열고 다음 값을 설정:

```bash
# Notion Export 활성화
ENABLE_NOTION_EXPORT=true

# Notion Integration Token (필수)
NOTION_TOKEN=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 방법 A: Database에 생성하는 경우
NOTION_DATABASE_ID=a1b2c3d4e5f6789012345678901234567

# 방법 B: Page 하위에 생성하는 경우 (Database ID 대신 사용)
# NOTION_PAGE_ID=your_parent_page_id_here
```

### 3.2 설정 확인
- `ENABLE_NOTION_EXPORT=true`: Notion Export 기능 활성화
- `NOTION_TOKEN`: Integration Token (필수)
- `NOTION_DATABASE_ID` 또는 `NOTION_PAGE_ID` 중 하나만 설정 (필수)

---

## 4. 테스트

### 4.1 간단한 테스트
```bash
cd backend/tools
python notion_integration.py
```

### 4.2 실제 리포트 Export 테스트
```bash
cd backend/tools
python test_report_with_notion.py
```

### 4.3 성공 시 출력 예시
```
✅ Notion 클라이언트 초기화 완료
[Notion API] 페이지 생성 시작: 건강 리포트 - User 1
[Notion API] 블록 개수: 74개
✅ [Notion API] 페이지 생성 완료 (페이지 ID: abc123...)
```

### 4.4 Notion에서 확인
1. Notion Workspace 열기
2. Database 또는 Parent Page 확인
3. 생성된 "건강 리포트" 페이지 확인
4. 내용 확인:
   - 제목
   - 섹션 (운동, 영양, 수면 등)
   - Callout (전체 평가, 신뢰도 점수)
   - Evidence 토글 블록

---

## 5. 트러블슈팅

### 5.1 "API 토큰이 유효하지 않습니다" 오류
- Integration Token을 다시 확인하세요
- `secret_`으로 시작하는지 확인
- 복사 시 공백이 없는지 확인

### 5.2 "Database/Page에 접근할 수 없습니다" 오류
- Database/Page에 Integration이 연결되었는지 확인
- Database/Page ID가 올바른지 확인

### 5.3 "Notion 클라이언트 초기화 실패" 오류
- notion-client가 설치되었는지 확인:
  ```bash
  pip list | grep notion
  ```
- 설치되지 않았다면:
  ```bash
  pip install notion-client
  ```

### 5.4 블록이 일부만 생성됨
- Notion API는 한 번에 100개 블록까지만 추가 가능
- 코드가 자동으로 배치 처리하므로 로그 확인
- 오류 로그가 있는지 확인

---

## 6. Database Properties 추가 (선택사항)

### 6.1 추천 Properties
Database에 다음 Properties를 추가하면 유용합니다:

- **Name** (Title): 리포트 제목
- **Created** (Created time): 생성 시간
- **User ID** (Number): 사용자 ID
- **Lifestyle ID** (Number): Lifestyle ID
- **Reliability Score** (Number): 신뢰도 점수
- **Status** (Select): Draft, Published 등

### 6.2 Properties 자동 설정
향후 `notion_integration.py`를 수정하여 Properties를 자동으로 설정할 수 있습니다.

---

## 문의사항
설정 중 문제가 있으면 로그를 확인하고, 필요 시 문의하세요.
