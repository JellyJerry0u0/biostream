# Quant-First 리팩토링 품질/안정성 개선 사항

## 📋 개요

Quant-first 리팩토링에 추가된 품질/안정성 개선 사항 요약

---

## A) Quant 앵커 선택 정책 고도화

### 변경 전
- 모든 outcome 후보를 전부 stats 계산
- 가장 많은 카드를 가진 outcome 1개만 선택
- 모든 timeframe 그룹 포함

### 변경 후
- **섹션당 최대 2개 outcome만 선택** (점수 기반)
- **timeframe 1-2개만 선택** (표준 라벨 우선)

### 구현
```python
def score_outcome_for_selection(stats):
    """점수 계산:
    - n_cards * p_weight (strong=3, moderate=2, weak=1)
    - 극단치(|value| > 50%) 제외
    """
    
def select_top_timeframes(timeframe_groups, max_count=2):
    """표준 timeframe(4w/12w/6m) 우선 매핑"""
```

**효과**: simulation 카드에 숫자가 1-2개만 나오도록 제한

---

## B) Estimated Fallback 안전장치 강화

### 변경 전
- 전체 코퍼스에서 단순 통계 계산
- 극단치 클리핑만 수행

### 변경 후
- **SECTION_OUTCOME_CANDIDATES만 사용** (전체 outcome 무제한 사용 금지)
- **effect_unit "%"만 사용** (다른 단위 제외)
- **winsorize 50%** (절대값 > 50% 제외)
- **q25/q75 기반 범위** 계산
- **보수적 추정치** 표현

### 구현
```python
def calculate_estimated_stats(outcome_list):
    # SECTION_OUTCOME_CANDIDATES만 사용
    # effect_unit "%"만 필터링
    # 절대값 > 50% 제외
    # q25, q75 계산
    # -30% ~ 30% 범위로 클리핑
```

**효과**: 신뢰 가능한 추정치 제공

---

## C) 카드 텍스트 길이 강제

### 구현
```python
def _limit_sentences(text, max_sentences):
    """문장 단위로 자르기"""
    # problem/cause: 3문장
    # simulation: 4문장
    # action title/detail: 1문장
```

### 적용 위치
- `_postprocess_cards()` 함수에서 모든 카드 후처리
- LLM 출력 후 자동으로 길이 제한

**효과**: 장황한 출력 방지

---

## D) JSON 출력 안정화

### 변경 전
- JSON 파싱 실패 시 기본 카드만 생성

### 변경 후
- **프롬프트에 "설명 문장 없이 JSON만" 강조**
- **extract_json_from_text() 개선**:
  1. ```json 블록 우선 추출
  2. { } 블록 추출
  3. 앞뒤 텍스트 제거
- **파싱 실패 시 재시도** (temperature=0.2)
- **그래도 실패하면 fallback 카드**

### 구현
```python
def invoke_llm_json(prompt, system_prompt, retry=True):
    result = extract_json_from_text(raw_text)
    if result is None and retry:
        # temperature=0.2로 재시도
        # 프롬프트에 "JSON만 출력" 강조 추가
```

**효과**: JSON 파싱 실패율 감소

---

## E) PMC/논문ID 본문 노출 금지

### 구현
```python
def _remove_citation_leaks(text):
    """패턴 검사 및 제거:
    - PMC\d+
    - PMID\s*:?\s*\d+
    - p\s*[=<>]\s*[\d.]+
    - CI\s*:?\s*\[[^\]]+\]
    """
    # 발견 시 quality_flags["leaked_citation"] = True
```

### 적용 위치
- `_postprocess_cards()`에서 모든 카드 텍스트 처리
- problem/cause/simulation/action 모두 적용

**효과**: 본문에 논문 정보 노출 차단

---

## F) Simulation 텍스트 템플릿 강제

### 변경 전
- LLM이 자유롭게 숫자 표현

### 변경 후
- **코드에서 템플릿 강제 생성**
- LLM은 해석만 담당

### 템플릿

#### Grounded
```
"{timeframe_label} 유지 시, 연구에서 {outcome_label}이(가) 중앙값 {median:.1f}% 변화(범위 {min:.1f}~{max:.1f}%)하는 경향이 관찰되었습니다."
```

#### Estimated
```
"정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 추정하면, {timeframe_label}에 {min:.0f}~{max:.0f}% 정도 변화 가능합니다. 개인차가 매우 클 수 있습니다."
```

### 구현
```python
def _format_simulation_text(section_quant):
    """템플릿으로 강제 생성"""
    # 첫 번째 outcome/timeframe만 사용
    # 코드에서 숫자 포맷팅
```

**효과**: 숫자 표현 일관성, 과장 방지

---

## G) 테스트 확장

### 추가된 검증
1. ✅ `action.items == 3` 확인
2. ✅ `problem/cause/simulation` 문장 수 제한 확인
3. ✅ PMC/PMID/p=/CI 패턴 노출 확인
4. ✅ `simulation.mode` in {"grounded", "estimated"}
5. ✅ `grounded`일 때 `quant_refs > 0`

### 구현
```python
# report_smoke_test.py
- action.items 수 검증
- 문장 수 제한 검증 (re.split으로 문장 개수 계산)
- citation_patterns 검증 (정규식)
```

**효과**: 품질 보장

---

## 📊 변경된 파일

### 수정된 파일
1. `backend/langgraph_modules/report_graph.py`
   - `score_outcome_for_selection()` 추가
   - `select_top_timeframes()` 추가
   - `calculate_estimated_stats()` 개선
   - `_limit_sentences()` 추가
   - `_remove_citation_leaks()` 추가
   - `_format_simulation_text()` 추가
   - `_postprocess_cards()` 추가
   - `invoke_llm_json()` 개선 (재시도 로직)
   - `preload_quant_evidence()` 수정 (outcome/timeframe 선택 정책)
   - `write_section_cards()` 수정 (후처리 적용)

2. `backend/tools/report_smoke_test.py`
   - 문장 수 검증 추가
   - action.items 검증 추가
   - citation 패턴 검증 강화

---

## 🔍 핵심 함수 Diff 요약

### 1. `preload_quant_evidence()` - Quant 선택 정책

**Before**:
```python
# 가장 많은 카드를 가진 outcome 1개만
best_count = sum(len(g.get("cards", [])) for g in stats["timeframe_groups"].values())
```

**After**:
```python
# 점수 기반으로 최대 2개 outcome 선택
outcome_scores = [(outcome, stats, score_outcome_for_selection(stats)) for ...]
outcome_scores.sort(key=lambda x: x[2], reverse=True)
selected_outcomes_data = outcome_scores[:2]

# timeframe 1-2개만 선택
selected_timeframes = select_top_timeframes(timeframe_groups, max_count=2)
```

### 2. `calculate_estimated_stats()` - 안전장치 강화

**Before**:
```python
# 단순 통계
median = abs(group["median"])
min_val = max(group["min"], -30)
max_val = min(group["max"], 30)
```

**After**:
```python
# effect_unit "%"만 필터링
values = [abs(c.get("effect_signed_value", 0)) for c in cards if c.get("effect_unit_filled") == "%"]
# 절대값 > 50% 제외
values = [v for v in values if v <= 50]
# q25, q75 계산
q25 = sorted_values[n // 4]
q75 = sorted_values[(3 * n) // 4]
```

### 3. `_postprocess_cards()` - 후처리 추가

**New Function**:
```python
def _postprocess_cards(cards, section_quant):
    # 1. problem/cause: 문장 수 제한 (3문장)
    # 2. simulation: 템플릿 강제 + 문장 수 제한 (4문장)
    # 3. action: items 3개 강제 + PMC 제거
    # 4. 모든 텍스트: PMC/PMID/p=/CI 제거
    return processed_cards, quality_flags
```

### 4. `invoke_llm_json()` - 재시도 로직

**Before**:
```python
result = extract_json_from_text(raw_text)
return result
```

**After**:
```python
result = extract_json_from_text(raw_text)
if result is None and retry:
    # temperature=0.2로 재시도
    generation_config = genai.types.GenerationConfig(temperature=0.2)
    full_prompt += "\n\n⚠️ 중요: 설명 문장 없이 JSON만 출력하세요."
    result = extract_json_from_text(raw_text)
return result
```

---

## ✅ 검증 항목

스모크 테스트에서 확인하는 항목:

1. ✅ 각 섹션 `cards == 4`
2. ✅ `action.items == 3`
3. ✅ `simulation.mode` in {"grounded", "estimated"}
4. ✅ `grounded`일 때 `quant_refs > 0`
5. ✅ 본문에 PMC/PMID/p=/CI 패턴 없음
6. ✅ `problem/cause` 문장 수 ≤ 3
7. ✅ `simulation` 문장 수 ≤ 4

---

## 🎯 개선 효과

### Before
- ❌ 정량 숫자가 너무 많음 (혼란)
- ❌ 추정치가 과장됨
- ❌ 카드 텍스트가 장황함
- ❌ JSON 파싱 실패 빈번
- ❌ PMC 노출 가능성

### After
- ✅ 섹션당 1-2개 숫자만 (명확)
- ✅ 보수적 추정치 (신뢰)
- ✅ 짧고 읽기 쉬운 카드 (UX)
- ✅ JSON 파싱 안정화 (안정성)
- ✅ PMC 노출 차단 (품질)
