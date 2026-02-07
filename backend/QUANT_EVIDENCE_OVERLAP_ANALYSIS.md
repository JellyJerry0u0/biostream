# 정량 근거 겹침 및 디테일 부족 원인 분석

## 🔍 문제 현상

1. **섹션마다 예상 경로가 겹침**: 각 섹션(sleep, uv, lifestyle, activity)의 simulation 카드가 비슷한 내용으로 보임
2. **디테일 부족**: "무엇을 유지하면"인지 명확하지 않음
3. **구체성 부족**: 섹션별 특성이 반영되지 않음

---

## 📊 원인 분석

### 1. 템플릿 구조의 문제

**현재 코드 위치**: `report_graph.py` - `_format_simulation_text()`

```python
return f"{tf_label} 유지 시, 연구에서 {outcome_label}이(가) 중앙값 {median:.1f}% 변화(범위 {min_val:.1f}~{max_val:.1f}%)하는 경향이 관찰되었습니다."
```

**문제점**:
- ❌ "유지 시"만 있고, **"무엇을 유지하면"**인지 명시되지 않음
- ❌ 섹션별 특성(수면, 자외선, 생활습관, 운동)이 반영되지 않음
- ❌ 모든 섹션이 동일한 템플릿 사용

**예시 (현재 출력)**:
- sleep: "12주 유지 시, 연구에서 수분 장벽이(가) 중앙값 15.0% 변화..."
- uv: "12주 유지 시, 연구에서 색소침착이(가) 중앙값 12.0% 변화..."
- lifestyle: "12주 유지 시, 연구에서 여드름이(가) 중앙값 10.0% 변화..."

→ 모두 "유지 시"만 있고, **무엇을 유지하는지** 명확하지 않음

---

### 2. 정량 근거 선택 로직의 문제

**현재 코드 위치**: `report_graph.py` - `preload_quant_evidence()`

**문제점**:
- 섹션별로 다른 outcome을 선택하지만, **timeframe이 동일**할 가능성 높음
- 예: sleep → hydration_barrier (12주), uv → pigmentation (12주)
- → timeframe이 같으면 템플릿이 거의 동일해 보임

**선택 로직**:
```python
# 첫 번째 timeframe만 선택
tf_days = list(timeframe_groups.keys())[0]
```

→ 섹션별로 다른 timeframe을 선택하지 않고, 항상 첫 번째만 사용

---

### 3. 섹션-정량 매핑의 문제

**현재 코드 위치**: `report_graph.py` - `SECTION_OUTCOME_CANDIDATES`

```python
SECTION_OUTCOME_CANDIDATES = {
    "sleep": ["hydration_barrier", "wrinkle", "elasticity", "redness"],
    "uv": ["pigmentation", "wrinkle", "elasticity", "redness"],
    "lifestyle": ["acne", "redness", "hydration_barrier", "pigmentation"],
    "activity": ["elasticity", "wrinkle", "general_skin"],
}
```

**문제점**:
- ❌ 섹션별로 outcome이 겹침 (wrinkle, redness 등)
- ❌ 같은 outcome이면 같은 정량 데이터를 사용할 가능성
- ❌ 섹션별 특성이 outcome 선택에 반영되지 않음

**예시**:
- sleep → wrinkle (12주, 10% 개선)
- uv → wrinkle (12주, 10% 개선)
- → 동일한 outcome + timeframe = 거의 동일한 텍스트

---

### 4. 템플릿 강제 생성의 문제

**현재 코드 위치**: `report_graph.py` - `_postprocess_cards()`

```python
# simulation: 템플릿 강제 + 문장 수 제한
elif card_type == "simulation":
    # 템플릿으로 강제 생성
    template_text = _format_simulation_text(section_quant)
```

**문제점**:
- ❌ LLM이 생성한 simulation 텍스트를 **무시하고 코드에서 강제 생성**
- ❌ 섹션별 맥락(survey 데이터)이 템플릿에 반영되지 않음
- ❌ "무엇을 유지하면"에 대한 정보가 없음

---

## 🎯 근본 원인 요약

### 1. 템플릿에 섹션 정보 부재
- "유지 시"만 있고, **"수면 패턴을 유지하면"**, **"선크림 사용을 유지하면"** 같은 섹션별 맥락이 없음

### 2. 사용자 설문 데이터 미반영
- 템플릿 생성 시 `survey` 데이터가 전달되지 않음
- "당신의 5.5시간 수면을 7시간으로 늘리면" 같은 개인화가 불가능

### 3. 섹션-정량 매핑의 중복
- 같은 outcome을 여러 섹션에서 사용
- 같은 timeframe을 여러 섹션에서 사용
- → 결과적으로 비슷한 텍스트 생성

### 4. LLM 생성 텍스트 무시
- LLM이 섹션 맥락을 반영해 생성한 텍스트를 버리고, 코드 템플릿으로 강제 교체
- → 섹션별 특성이 사라짐

---

## 💡 해결 방향 (참고용, 수정하지 말 것)

### 방향 1: 템플릿에 섹션 맥락 추가
```python
# 예시
if section == "sleep":
    return f"당신의 {hours}시간 수면 패턴을 {tf_label} 유지하면..."
elif section == "uv":
    return f"당신의 {sunscreen_freq} 선크림 사용을 {tf_label} 유지하면..."
```

### 방향 2: LLM 생성 텍스트 활용
- 코드 템플릿 강제 생성 제거
- LLM이 섹션 맥락을 반영한 텍스트 생성하도록 허용
- 후처리에서 숫자만 검증

### 방향 3: 섹션별 outcome/timeframe 차별화
- 같은 outcome을 여러 섹션에서 사용하지 않도록 필터링
- 섹션별로 다른 timeframe 우선 선택

### 방향 4: survey 데이터를 템플릿에 주입
- `_format_simulation_text()`에 `section`, `survey` 파라미터 추가
- 섹션별 맥락과 사용자 데이터를 템플릿에 반영

---

## 📝 결론

**주요 원인**:
1. 템플릿에 "무엇을 유지하면"이 명시되지 않음
2. 섹션별 맥락이 템플릿에 반영되지 않음
3. 사용자 설문 데이터가 템플릿 생성에 사용되지 않음
4. LLM 생성 텍스트를 무시하고 코드 템플릿으로 강제 교체

**결과**:
- 모든 섹션이 비슷한 "유지 시, 연구에서 X% 변화" 형태
- 섹션별 특성이 사라짐
- 개인화가 불가능
