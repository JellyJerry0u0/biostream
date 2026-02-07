# Quant-First 리팩토링 품질/안정성 개선 완료 요약

## 📋 개요

Quant-first 리팩토링에 추가된 **7가지 품질/안정성 개선 사항**이 모두 반영되었습니다.

---

## ✅ 완료된 개선 사항

### A) Quant 앵커 선택 정책 고도화 ✅
- **섹션당 최대 2개 outcome만 선택** (점수 기반)
- **timeframe 1-2개만 선택** (표준 라벨 우선)
- **점수 계산**: n_cards × p_weight (strong=3, moderate=2, weak=1)
- **극단치 제외**: |value| > 50% 페널티

**파일**: `report_graph.py`
- `score_outcome_for_selection()` 함수 추가
- `select_top_timeframes()` 함수 추가
- `preload_quant_evidence()` 수정 (goals/일반 섹션 모두 적용)

---

### B) Estimated Fallback 안전장치 강화 ✅
- **SECTION_OUTCOME_CANDIDATES만 사용** (전체 outcome 무제한 사용 금지)
- **effect_unit "%"만 필터링** (다른 단위 제외)
- **winsorize 50%** (절대값 > 50% 제외)
- **q25/q75 기반 범위** 계산
- **보수적 추정치** 표현

**파일**: `report_graph.py`
- `calculate_estimated_stats()` 함수 개선

---

### C) 카드 텍스트 길이 강제 ✅
- **problem/cause**: 3문장 이하
- **simulation**: 4문장 이하
- **action title/detail**: 각 1문장

**파일**: `report_graph.py`
- `_limit_sentences()` 함수 추가
- `_postprocess_cards()` 함수에서 모든 카드 후처리

---

### D) JSON 출력 안정화 ✅
- **프롬프트 강화**: "설명 문장 없이 JSON만 출력" 반복
- **extract_json_from_text() 개선**: ```json 블록, { } 블록 추출
- **재시도 로직**: 파싱 실패 시 temperature=0.2로 재시도
- **Fallback**: 그래도 실패하면 기본 카드 생성

**파일**: `report_graph.py`
- `extract_json_from_text()` 개선
- `invoke_llm_json()` 재시도 로직 추가

---

### E) PMC/논문ID 본문 노출 금지 ✅
- **패턴 검사**: PMC, PMID, p=, CI
- **자동 제거**: 발견 시 제거 및 quality_flags 설정
- **모든 카드 텍스트 적용**: problem/cause/simulation/action

**파일**: `report_graph.py`
- `_remove_citation_leaks()` 함수 추가
- `_postprocess_cards()`에서 모든 텍스트 처리

---

### F) Simulation 텍스트 템플릿 강제 ✅
- **코드에서 템플릿 생성**: LLM이 숫자를 꾸미지 않도록
- **Grounded 템플릿**: "{timeframe_label} 유지 시, 연구에서 {outcome_label}이(가) 중앙값 {median}% 변화(범위 {min}~{max}%)"
- **Estimated 템플릿**: "정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 추정하면..."

**파일**: `report_graph.py`
- `_format_simulation_text()` 함수 추가
- `_postprocess_cards()`에서 simulation 카드 템플릿 강제 적용

---

### G) 테스트 확장 ✅
- **action.items == 3** 검증
- **문장 수 제한** 검증 (problem/cause/simulation)
- **PMC/PMID/p=/CI 패턴** 검증
- **simulation.mode** 검증
- **grounded일 때 quant_refs > 0** 검증

**파일**: `report_smoke_test.py`
- 모든 검증 항목 추가

---

## 📝 변경된 파일 및 핵심 함수

### 1. `backend/langgraph_modules/report_graph.py`

#### 신규 함수
- `score_outcome_for_selection(stats)` - outcome 선택 점수 계산
- `select_top_timeframes(timeframe_groups, max_count=2)` - timeframe 1-2개 선택
- `_limit_sentences(text, max_sentences)` - 문장 수 제한
- `_remove_citation_leaks(text)` - PMC/논문ID 제거
- `_format_simulation_text(section_quant)` - simulation 템플릿 강제 생성
- `_postprocess_cards(cards, section_quant)` - 카드 후처리 (길이/PMC/템플릿)

#### 수정된 함수
- `calculate_estimated_stats()` - 안전장치 강화
- `preload_quant_evidence()` - outcome/timeframe 선택 정책 개선
- `invoke_llm_json()` - 재시도 로직 추가
- `write_section_cards()` - 후처리 적용

### 2. `backend/tools/report_smoke_test.py`
- 문장 수 검증 추가
- action.items 검증 추가
- citation 패턴 검증 강화

---

## 🔍 핵심 변경 Diff

### A) Quant 선택 정책

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

# timeframe 1-2개만 선택 (표준 라벨 우선)
selected_timeframes = select_top_timeframes(timeframe_groups, max_count=2)
```

### B) Estimated 안전장치

**Before**:
```python
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

### C) 카드 후처리

**New**:
```python
def _postprocess_cards(cards, section_quant):
    for card in cards:
        # 1. 문장 수 제한
        if card["type"] in ["problem", "cause"]:
            card["text"] = _limit_sentences(card["text"], max_sentences=3)
        
        # 2. PMC 제거
        card["text"], leaked = _remove_citation_leaks(card["text"])
        
        # 3. simulation 템플릿 강제
        if card["type"] == "simulation":
            card["text"] = _format_simulation_text(section_quant)
```

### D) JSON 파싱 재시도

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

## ✅ 검증 항목 (스모크 테스트)

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

---

## 📊 테스트 방법

```bash
cd backend
python tools/report_smoke_test.py --user_id 1
```

모든 검증 항목을 통과하면 성공입니다.
