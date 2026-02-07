# Evidence-Based Personalization 개선 요약

## 개요
리포트 생성 코드를 "일반론적"에서 "근거 기반 + 개인화"로 전환하기 위한 개선 작업 완료.

## 핵심 변경 사항

### 1. 사용자 기본 정보 파생 지표 계산
**파일**: `backend/langgraph_modules/report_graph.py`
**함수**: `calculate_user_profile_derived()`, `format_user_profile_for_prompt()`

- User 모델에서 성별, 생년월일 조회
- Lifestyle에서 키, 몸무게 조회
- BMI 계산 및 카테고리 분류 (저체중/정상/과체중/비만)
- 연령대 bucket 계산 (10대/20대/30대/40대/50대/60대 이상)
- 프롬프트용 텍스트 포맷팅

**사용 위치**: `load_survey()` 노드에서 자동 계산 후 `state.user_profile`에 저장

---

### 2. Evidence Extraction 노드 추가
**파일**: `backend/langgraph_modules/report_graph.py`
**노드**: `extract_claims()`

**기능**:
- 카드 타입별(problem/cause/action)로 narrative evidence를 구조화된 claims로 변환
- 각 claim은:
  - `claim`: 사용자에게 실제로 해당되는 1문장 주장
  - `support`: 근거 리스트 (chunk_id, support_text, why_relevant)
  - `survey_hooks`: 사용된 설문 값
  - `profile_hooks`: 사용된 사용자 정보

**프롬프트 전략**:
- 설문 데이터 + 사용자 프로필 + 검색된 근거를 LLM에 제공
- LLM이 "주장-근거-설문-사용자정보 연결" 구조로 JSON 생성

**워크플로우 위치**: `retrieve_narrative_evidence` → `extract_claims` → `write_section_cards`

---

### 3. RetrieveNarrativeEvidence 카드별 분리
**파일**: `backend/langgraph_modules/report_graph.py`
**노드**: `retrieve_narrative_evidence()` (수정)

**변경 사항**:
- 기존: 섹션당 1개 쿼리로 통합 검색
- 개선: 카드 타입별(problem/cause/action)로 쿼리 분리

**쿼리 전략 예시** (sleep 섹션):
- `problem`: "수면 부족 단기간 피부 장벽 수분 {outcome_keywords}"
- `cause`: "수면 파편화 코르티솔 염증 피부 {outcome_keywords}"
- `action`: "수면 연장 개입 시험 피부 {outcome_keywords} {timeframe_label}"

**사용자 정보 반영**:
- 성별/연령대/BMI 키워드를 쿼리에 soft하게 포함
- candidate_k 증가 (30 → 50)로 다양성 확보

**결과 구조**:
```python
narrative_evidence = {
    "sleep": {
        "problem": [EvidenceItem, ...],
        "cause": [EvidenceItem, ...],
        "action": [EvidenceItem, ...]
    }
}
```

---

### 4. BuildQueries 카드별 쿼리 생성
**파일**: `backend/langgraph_modules/report_graph.py`
**노드**: `build_queries()` (수정)

**변경 사항**:
- 섹션별 outcome 키워드 추출
- timeframe 키워드 추출
- 사용자 정보 키워드 (성별/연령대/BMI) 추출
- 카드 타입별로 특화된 쿼리 생성

**결과 구조**:
```python
section_queries = {
    "sleep": {
        "problem": "수면 부족 단기간 피부 장벽 수분 ...",
        "cause": "수면 파편화 코르티솔 염증 피부 ...",
        "action": "수면 연장 개입 시험 피부 ..."
    }
}
```

---

### 5. WriteSectionCards 프롬프트 강화
**파일**: `backend/langgraph_modules/report_graph.py`
**함수**: `_build_card_prompt_enhanced()` (신규)

**프롬프트 구성**:
1. 사용자 설문 데이터 (자연스러운 요약 강조)
2. 사용자 기본 정보 (성별/나이대/BMI - 의학적으로 자연스럽게 반영)
3. 정량 근거 (기존 유지)
4. 구조화된 주장(claims) - 각 카드 타입별로 claims와 support_text 제공

**카드 작성 규칙 강화**:
- problem/cause: claims의 "claim"과 "support_text"를 바탕으로 작성, 설문 수치 자연스럽게 요약
- action: 사용자 설문 + 신체정보에서 가장 큰 레버 1~2개에 집중
- Evidence 기반 키워드 최소 1개 포함
- 불확실하면 약하게 표현 ('가능성이 큽니다/경향이 있습니다')
- 근거에서 말하는 메커니즘/방향성(장벽/염증/멜라닌/콜라겐) 1번 이상 언급

---

### 6. ValidateCards 노드 추가
**파일**: `backend/langgraph_modules/report_graph.py`
**노드**: `validate_cards()` (신규)

**검증 항목**:
1. 설문 수치/선택지가 최소 1개 이상 자연스럽게 반영됨
2. 사용자 기본 정보(성별/나이대/BMI) 중 최소 1개 이상 반영됨
3. Evidence 기반 키워드(claims의 support_text에서 추출) 최소 1개 포함
4. 금지 패턴 검출 (PMC/PMID/p=/CI, 과도한 일반론 문구)
5. 지나친 확신 표현 검출 ("반드시/확실히")

**재시도 로직**:
- 검증 실패 시 최대 2회 재시도
- `retry_count`로 섹션별 재시도 횟수 추적
- LangGraph conditional edge로 재시도 분기

**워크플로우 위치**: `write_section_cards` → `validate_cards` → (재시도 또는) `assemble_report`

---

## 워크플로우 변경

### 기존 워크플로우
```
LoadSurvey → PlanSections → PreloadQuantEvidence → BuildQueries → 
RetrieveNarrativeEvidence → WriteSectionCards → AssembleReport → SaveReport
```

### 개선된 워크플로우
```
LoadSurvey (user_profile 계산) → PlanSections → PreloadQuantEvidence → 
BuildQueries (카드별 쿼리) → RetrieveNarrativeEvidence (카드별 검색) → 
ExtractClaims (구조화) → WriteSectionCards (근거 기반 강화) → 
ValidateCards (품질 검증 + 재시도) → AssembleReport → SaveReport
```

---

## State 구조 변경

### 추가된 필드
- `user_profile`: 사용자 기본 정보 파생 지표 (BMI, age_bucket 등)
- `section_queries`: 섹션별 카드 타입별 쿼리 딕셔너리
- `narrative_evidence`: 섹션별 카드 타입별 근거 딕셔너리
- `extracted_claims`: 섹션별 카드 타입별 구조화된 claims
- `retry_count`: 재시도 횟수 추적
- `quality_flags`: 품질 검증 플래그

---

## 주요 함수 목록

### 신규 함수
1. `calculate_user_profile_derived()`: 사용자 프로필 파생 지표 계산
2. `format_user_profile_for_prompt()`: 프롬프트용 프로필 텍스트 포맷팅
3. `extract_claims()`: Evidence Extraction 노드
4. `_format_survey_data_for_claims()`: Claims 추출용 설문 데이터 포맷팅
5. `_build_card_prompt_enhanced()`: 근거 기반 강화 프롬프트
6. `validate_cards()`: ValidateCards 노드
7. `_validate_section_cards()`: 섹션 카드 품질 검증
8. `_check_survey_values_in_text()`: 설문 값 반영 확인
9. `_extract_evidence_keywords()`: Evidence 키워드 추출
10. `_check_forbidden_patterns()`: 금지 패턴 확인
11. `_check_overconfident_language()`: 지나친 확신 표현 확인

### 수정된 함수
1. `load_survey()`: user_profile 계산 추가
2. `build_queries()`: 카드별 쿼리 생성으로 변경
3. `retrieve_narrative_evidence()`: 카드별 검색으로 변경
4. `write_section_cards()`: extracted_claims + user_profile 사용

---

## 예상 효과

1. **개인화 강화**: 설문 수치와 사용자 기본 정보가 자연스럽게 반영된 리포트
2. **근거 기반 전문화**: Evidence Extraction을 통해 주장-근거 연결이 명확해짐
3. **카드별 특화**: 카드 타입별로 다른 쿼리와 근거를 사용하여 다양성 확보
4. **품질 안정화**: ValidateCards로 자동 검증 및 재시도로 품질 일관성 확보

---

## 테스트 권장 사항

1. 다양한 사용자 프로필(성별/나이/BMI)로 리포트 생성 테스트
2. 설문 값이 자연스럽게 반영되는지 확인
3. Evidence 기반 키워드가 카드에 포함되는지 확인
4. 금지 패턴(PMC/PMID)이 제거되는지 확인
5. 재시도 로직이 정상 작동하는지 확인

---

## 주의사항

1. `user_profile` 계산 시 DB 연결 필요 (User 모델 조회)
2. Evidence Extraction은 LLM 호출이므로 비용/시간 증가 가능
3. ValidateCards 재시도는 최대 2회로 제한 (무한 루프 방지)
4. 기존 `_build_card_prompt()` 함수는 호환성을 위해 유지 (사용되지 않음)
