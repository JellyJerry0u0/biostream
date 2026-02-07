# Outcomes 확장 가이드

## 개요

UI outcomes 옵션을 최소 확장하고, 내부적으로 1:N 매핑 구조로 정량 근거 검색 품질을 향상시켰습니다.

## 변경 사항

### 1. UI Outcomes 옵션 확장

**기존 (6개):**
- wrinkle (주름)
- pigmentation (색소)
- hydration (수분)
- acne (여드름)
- redness (홍조)
- general_aging (전체 노화)

**신규 (8개):**
- wrinkle (주름)
- **elasticity (탄력)** ← 신규
- pigmentation (색소)
- hydration (수분)
- **hydration_barrier (장벽)** ← 신규
- acne (여드름)
- redness (홍조)
- general_aging (전체 노화)

### 2. Outcome Polarity 테이블

각 outcome의 개선 방향성을 정의:

```python
OUTCOME_POLARITY = {
    "wrinkle": "decrease",  # decrease = improvement
    "elasticity": "increase",  # increase = improvement
    "pigmentation": "decrease",
    "hydration": "increase",
    "hydration_barrier": "increase",
    "acne": "decrease",
    "redness": "decrease",
    "general_aging": "mixed",  # mixed / neutral
    "general_skin": "mixed",
}
```

이 테이블은 정량 요약 문장에서 "improved / worsened / changed"를 결정할 때 사용됩니다.

### 3. UI Outcomes → Quant Evidence 매핑 (1:N 확장)

UI에서 선택한 outcome을 quant_evidence 검색 필터로 확장 매핑:

```python
UI_OUTCOME_TO_QUANT_MAPPED = {
    "wrinkle": ["wrinkle", "elasticity"],
    "elasticity": ["elasticity", "wrinkle"],
    "hydration": ["hydration_barrier"],
    "hydration_barrier": ["hydration_barrier"],
    "pigmentation": ["pigmentation"],
    "acne": ["acne"],
    "redness": ["redness"],
    "general_aging": ["general_skin", "wrinkle", "elasticity", "pigmentation"],
}
```

**예시:**
- 사용자가 "wrinkle" 선택 → quant_evidence에서 `outcome_mapped IN ["wrinkle", "elasticity"]` 검색
- 사용자가 "elasticity" 선택 → quant_evidence에서 `outcome_mapped IN ["elasticity", "wrinkle"]` 검색
- 사용자가 "general_aging" 선택 → quant_evidence에서 `outcome_mapped IN ["general_skin", "wrinkle", "elasticity", "pigmentation"]` 검색

### 4. 정량 요약 문장 생성 (Polarity 반영)

**기존:**
```
"At 4 weeks, across 5 evidence cards, elasticity changed by an average of 5.6% (median 5.6%, range 5.0% to 6.0%)."
```

**신규 (polarity 반영):**
```
"At 4 weeks, across 5 evidence cards, elasticity improved by an average of 5.6% (median 5.6%, range 5.0% to 6.0%)."
```

- `elasticity`는 `increase = improvement`이므로, `effect_signed_value > 0`이면 "improved"
- `wrinkle`은 `decrease = improvement`이므로, `effect_signed_value < 0`이면 "improved"

## 구현 파일

### 백엔드

1. **`backend/langgraph_modules/report_graph.py`**
   - `OUTCOME_LABELS`: UI outcomes 한글 라벨 (elasticity, hydration_barrier 추가)
   - `OUTCOME_POLARITY`: outcome별 개선 방향성 테이블
   - `UI_OUTCOME_TO_QUANT_MAPPED`: UI → quant 확장 매핑
   - `retrieve_evidence` 노드: 확장 매핑 사용
   - `write_section_draft` 노드: polarity 반영

2. **`backend/app/services/quant_evidence_retriever.py`**
   - `search_by_outcomes()`: 여러 outcome_mapped로 검색 (확장 매핑용)
   - `get_grouped_stats_multi()`: 여러 outcome_mapped에 대한 통계 계산
   - `get_outcome_polarity()`: outcome polarity 반환
   - `interpret_effect_with_polarity()`: effect_signed_value를 polarity에 따라 해석
   - `format_quant_block()`: polarity 반영한 정량 블록 생성
   - `format_quant_summary()`: polarity 반영한 요약 텍스트 생성

3. **`backend/app/models.py`**
   - `outcomes` 필드 주석 업데이트

4. **`backend/app/api/lifestyle_survey.py`**
   - `LifestyleSurveyCreate.outcomes` 주석 업데이트

5. **`backend/app/api/data.py`**
   - `outcomes_labels` 딕셔너리 업데이트

### 프론트엔드

1. **`biostream/lib/screens/survey_screen.dart`**
   - `_buildOutcomesPage()`: outcomes 옵션 리스트 업데이트 (elasticity, hydration_barrier 추가)
   - 요약 페이지의 outcomes 라벨 매핑 업데이트

## 리포트 생성 파이프라인 변경 지점

### 1. `retrieve_evidence` 노드 (line 290-437)

**변경 전:**
- goals 섹션: `OUTCOME_TO_MAPPED`로 단일 매핑 사용
- `get_grouped_stats(outcome_mapped)` 호출

**변경 후:**
- goals 섹션: `UI_OUTCOME_TO_QUANT_MAPPED`로 확장 매핑 사용
- `get_grouped_stats_multi(quant_outcome_list)` 호출
- 예: `wrinkle` → `["wrinkle", "elasticity"]` → 통합 통계 계산

### 2. `write_section_draft` 노드 (line 440-710)

**변경 전:**
- `format_quant_block(outcome_mapped, outcome_label, stats)` 호출
- polarity 미반영

**변경 후:**
- `format_quant_block(ui_outcome, outcome_label, stats, OUTCOME_POLARITY)` 호출
- polarity 반영하여 "improved/worsened/changed" 결정
- 요약 문장: "improved by X%" 또는 "worsened by X%" 또는 "changed by X%"

## 검증 체크리스트

- [ ] UI에서 elasticity, hydration_barrier 옵션 표시 확인
- [ ] wrinkle 선택 시 elasticity 근거도 함께 검색되는지 확인
- [ ] elasticity 선택 시 wrinkle 근거도 함께 검색되는지 확인
- [ ] general_aging 선택 시 여러 outcome 근거가 통합 검색되는지 확인
- [ ] 정량 요약 문장에서 "improved/worsened/changed" 올바르게 표시되는지 확인
- [ ] polarity가 올바르게 적용되는지 확인:
  - [ ] elasticity: increase = improvement → effect > 0이면 "improved"
  - [ ] wrinkle: decrease = improvement → effect < 0이면 "improved"
  - [ ] general_aging: mixed → 항상 "changed"

## 주의사항

1. **기존 biostream_corpus_v1 컬렉션은 절대 수정하지 않음**
2. **quant_evidence 컬렉션 구조는 그대로 유지**
3. **확장 매핑은 검색 범위를 넓히는 것이지, 데이터를 변경하는 것이 아님**
4. **polarity는 effect_signed_value의 부호를 해석하는 데만 사용**

## 향후 확장 가능성

- `pores`, `sebum`, `texture` 같은 항목은 정량 근거 커버리지가 충분해지면 추가 가능
- `SECTION_TO_OUTCOME_MAPPED`에 일반 섹션용 outcome 매핑 추가 가능
- polarity 테이블은 새로운 outcome 추가 시 함께 업데이트 필요
