# 정량 근거 컬렉션 설정 가이드

## 개요

정량 근거 기반 수치 생성을 위해 Qdrant에 `quant_evidence` 컬렉션을 추가하고, 기존 원문 컬렉션 `biostream_corpus_v1`과 2-컬렉션 구조로 리포트를 생성하도록 구현했습니다.

## 구조

- **원문 컬렉션** (`biostream_corpus_v1`): 서술/메커니즘/개선안용
- **정량 근거 컬렉션** (`quant_evidence`): 정량 수치 근거만 (3072 차원)

## 1. CSV 인덱싱

### 실행 방법

```bash
cd backend
python -m app.services.quant_evidence_indexer
```

또는 CSV 경로 지정:

```bash
python -m app.services.quant_evidence_indexer backend/data/quant_corpus_v0_3_clean_valid_v3.csv
```

### 환경 변수

- `QDRANT_URL`: Qdrant 서버 주소 (기본값: `http://localhost:6333`)
- `QDRANT_QUANT_COLLECTION`: 컬렉션 이름 (기본값: `quant_evidence`)
- `GEMINI_API_KEY`: Gemini API 키 (필수)
- `GEMINI_EMBED_MODEL`: 임베딩 모델 (기본값: `gemini-embedding-001`)

### 인덱싱 결과 확인

인덱싱 완료 후 다음 정보가 출력됩니다:
- 처리된 행 수
- 건너뛴 행 수
- 컬렉션 총 포인트 수
- 벡터 차원

## 2. 검색 및 통계 테스트

```bash
cd backend
python -m app.services.quant_evidence_retriever
```

이 스크립트는 다음을 테스트합니다:
- `elasticity` 검색
- `hydration_barrier` 검색
- 통계 계산
- 요약 텍스트 생성

## 3. 리포트 생성 통합

리포트 생성 시 자동으로 2-컬렉션 구조가 사용됩니다:

1. **원문 컬렉션 검색**: 모든 섹션에서 서술/메커니즘/개선안용 근거 검색
2. **정량 근거 검색**: 모든 섹션에서 수행
   - `goals` 섹션: 사용자 목표 키워드(`outcomes`)를 outcome 필터로 사용
   - 일반 섹션: 섹션별 `outcome_mapped` 매핑 사용
3. **LLM 프롬프트 주입**: 모든 섹션 프롬프트에 정량 근거 블록 주입, 정량 수치는 반드시 이 데이터만 사용하도록 강제

### outcome 매핑

**사용자 목표 → outcome_mapped (goals 섹션용)**
- `wrinkle` → `wrinkle`
- `pigmentation` → `pigmentation`
- `hydration` → `hydration_barrier`
- `acne` → `acne`
- `redness` → `redness`
- `general_aging` → 매핑 없음 (정량 근거 검색 안 함)

**섹션 → outcome_mapped (일반 섹션용)**
- `SECTION_TO_OUTCOME_MAPPED` 딕셔너리에 정의
- 현재는 대부분 `None` (정량 근거 없음)
- 필요시 추가 가능 (예: `"elasticity": "elasticity"`)

## 4. 정량 근거 검색 로직

### 모든 섹션 공통

- 기본 필터:
  - `outcome_mapped == 섹션의 outcome`
  - `is_valid == True`

- 요약 통계(mean / median / range)에 쓰는 카드:
  - `is_valid == True`
  - `suspicious_cross_outcome_copy == False`

- 근거 카드 리스트:
  - `is_valid == True` 인 카드 전부 포함
  - `suspicious_cross_outcome_copy == True` 인 카드는 "review" 또는 "check needed" 라벨 표시

### goals 섹션 특수 규칙

- 사용자 목표 키워드(`outcomes`)를 outcome 필터로 사용
- 예: 사용자 목표가 `["wrinkle", "elasticity", "hydration"]`이면
  - `outcome_mapped IN ["wrinkle", "elasticity", "hydration_barrier"]` 필터로 검색

### 일반 섹션 규칙

- `SECTION_TO_OUTCOME_MAPPED` 딕셔너리의 매핑 사용
- `outcome_mapped == None`인 섹션은 정량 근거 검색 안 함

## 5. 정량 블록 생성 규칙

1. `quant_evidence` 검색 결과를 `timeframe_days` 기준으로 그룹핑
2. 각 timeframe 그룹마다 다음 블록 생성:
   - 섹션 제목: `"{Outcome} — {N weeks}"`
   - 요약 문장: `"At {N weeks}, across {K} evidence cards, {outcome} changed by an average of {mean}% (median {median}%, range {min}% to {max}%)."`
   - 근거 카드 리스트: `{paper_id} / {chunk_id} (p={p_value_num}, {p_label}): {source_snippet}`

## 6. 정량 근거가 없는 경우

해당 섹션/timeframe에서 quant 카드가 하나도 없으면:
- "정량 근거 없음 (quantitative evidence not found)" 문구 출력
- 숫자 생성 절대 금지

## 7. 주의사항

- 기존 `biostream_corpus_v1` 컬렉션은 절대 수정하지 않음
- 정량 문장에 새 숫자를 생성하지 않음
- quant 카드가 없으면 숫자 출력 금지
- 평균/중앙값/범위 계산 시 단위별로 분리 계산 (% 단위 우선)

## 8. 검증 체크리스트

- [ ] upsert 후 `quant_evidence` count == CSV row 수 (≈ 20) 로그 확인
- [ ] `outcome_mapped`별 검색 테스트:
  - [ ] `elasticity`
  - [ ] `hydration_barrier`
  - [ ] `pigmentation`
- [ ] 리포트 생성 시:
  - [ ] 숫자 문장이 payload의 `effect_signed_value` / `timeframe` 값과 일치하는지 확인
  - [ ] LLM이 새로운 숫자를 생성하지 않는지 확인

## 9. 파일 구조

```
backend/
├── app/
│   └── services/
│       ├── quant_evidence_indexer.py    # CSV 인덱싱
│       └── quant_evidence_retriever.py  # 검색 및 통계
├── langgraph_modules/
│   └── report_graph.py                  # 리포트 생성 (2-컬렉션 통합)
└── data/
    └── quant_corpus_v0_3_clean_valid_v3.csv
```

## 11. 통합 지점

리포트 생성 파이프라인에서 정량 블록이 주입되는 지점:

1. **`retrieve_evidence` 노드** (line 290-407):
   - 모든 섹션에서 원문 컬렉션 검색
   - 모든 섹션에서 정량 근거 검색 및 통계 계산
   - `goals` 섹션: 사용자 목표 키워드 사용
   - 일반 섹션: `SECTION_TO_OUTCOME_MAPPED` 매핑 사용

2. **`write_section_draft` 노드** (line 410-710):
   - 모든 섹션 프롬프트에 정량 근거 블록 주입
   - `format_quant_block()` 함수로 정량 블록 생성
   - LLM 프롬프트에 "숫자는 반드시 quant 근거만 사용" 제약 명시

## 12. 문제 해결

### Import 오류

`quant_evidence_retriever`를 찾을 수 없는 경우:
- `backend/app/services/` 디렉토리가 Python 경로에 포함되어 있는지 확인
- `sys.path.append`가 올바르게 설정되어 있는지 확인

### 임베딩 차원 오류

3072 차원이 아닌 경우:
- `GEMINI_EMBED_MODEL`이 `gemini-embedding-001`인지 확인
- Gemini API 응답의 실제 차원 확인

### 정량 근거가 검색되지 않는 경우

- `outcome_mapped` 값이 CSV와 일치하는지 확인
- `is_valid == True`인 항목만 검색됨
- Qdrant 컬렉션에 데이터가 올바르게 적재되었는지 확인
