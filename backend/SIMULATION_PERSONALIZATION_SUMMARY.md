# Simulation 카드 개인화 강화 완료 요약

## 📋 개요

Simulation 카드가 "너무 일반론적"으로 보이는 문제를 해결하기 위해, 사용자 설문 데이터를 직접 반영한 개인화된 condition 문장을 생성하도록 개선했습니다.

---

## ✅ 구현 완료 사항

### 1. `_build_section_condition()` 함수 생성

**위치**: `backend/langgraph_modules/report_graph.py`

**기능**: 섹션별로 사용자 설문 데이터를 분석하여 개인화된 condition 문장 생성

**섹션별 로직**:

#### sleep 섹션
- `sleep_hours_weekday < 6`: "당신의 평일 수면이 현재 {hours}시간이므로, 이를 7시간 안팎으로만 늘려서 유지하면"
- `6 ≤ hours < 7`: "당신의 평일 수면 {hours}시간을 최소 7시간으로만 끌어올려 유지하면"
- `hours ≥ 7 and sleep_quality_score < 6`: "수면 시간은 충분하지만 수면의 질이 {quality}/10점으로 낮으므로, 깊은 수면 비율을 조금만 높여 유지하면"

#### uv 섹션
- 선크림 거의 안 씀: "당신은 선크림을 거의 바르지 않으므로, 외출할 때마다 한 번만이라도 바르는 습관을 유지하면"
- 낮 시간대 노출 많음: "당신은 낮 시간대(10~16시) 야외 노출이 거의 매일이므로, 이 시간대 노출을 절반만 줄여서 유지하면"

#### lifestyle 섹션
- 우선순위: 흡연 > 스트레스 > 음주
- 흡연: "당신은 현재 흡연 중이므로, 하루 흡연량을 절반으로만 줄여 이 상태를 유지하면"
- 스트레스: "당신의 스트레스 점수가 {stress}/10점으로 높으므로, 이 수치를 5점 이하로만 낮춰 유지하면"
- 음주: "당신은 주 {days}일 음주하고 있으므로, 이를 주 1일로만 줄여 유지하면"

#### activity 섹션
- 근력 운동 0회: "당신은 근력 운동을 전혀 하지 않으므로, 주 1회 20분만 추가해 유지하면"
- 유산소 운동 부족: "당신은 유산소 운동을 주 {aerobic}회만 하고 있으므로, 이를 주 3회로만 늘려 유지하면"

#### goals 섹션
- outcomes 1-2개: "당신이 선택한 '{주름/탄력/수분}' 목표에 맞춰 관리 습관을 조금만 강화해 유지하면"
- outcomes 3개 이상: "당신의 피부 목표 전반을 기준으로 생활습관을 조금만 교정해 유지하면"

---

### 2. `_format_simulation_text()` 시그니처 확장

**변경 전**:
```python
def _format_simulation_text(section_quant: dict) -> str:
```

**변경 후**:
```python
def _format_simulation_text(
    section_key: str,
    survey: dict,
    section_quant: dict
) -> tuple[str, dict]:
```

**반환값**: `(text: str, meta: dict)` - 텍스트와 메타 정보를 함께 반환

**템플릿 포맷**:

#### Grounded
```
"{condition} {tf_label} 뒤에는, 연구에서 {outcome_label}이(가) 중앙값 {median:.1f}% 변화(범위 {min:.1f}~{max:.1f}%)하는 경향이 관찰되었습니다."
```

#### Estimated
```
"{condition} {tf_label} 뒤에는, 정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 보면 {outcome_label}이(가) 대략 {median:.1f}% 안팎(범위 {min:.1f}~{max_val:.1f}%) 변화할 수 있습니다."
```

---

### 3. Outcome/Timeframe 겹침 완화

**구현 위치**: `preload_quant_evidence()`

**로직**:
- `used_outcomes` set으로 이미 사용된 outcome 추적
- `used_timeframe_labels` dict로 timeframe_label별 사용 횟수 추적
- 이미 사용된 outcome은 점수 10% 감소 (페널티)
- timeframe이 2번 이상 사용되면 우선순위 낮춤
- 카드 수가 많고 사용 횟수가 적을수록 높은 점수

**효과**: 섹션마다 다른 outcome/timeframe을 선택하여 겹침 완화

---

### 4. 로그 출력 추가

**형식**:
```
📊 [sleep] condition="당신의 평일 수면이 5.5시간이므로...", tf=12주, outcome=수분장벽
📊 [uv] condition="당신은 선크림을 거의 바르지 않으므로...", tf=6개월, outcome=색소침착
```

**위치**: `_format_simulation_text()` 내부

---

### 5. 테스트 검증 추가

**파일**: `backend/tools/report_smoke_test.py`

**검증 항목**:
- simulation.text에 다음 패턴 중 하나 이상 포함:
  - "당신의"
  - "당신은"
  - "현재"
  - 설문 값(시간, 횟수, 점수 등 숫자)

**Assertion**:
```python
assert has_personalization, f"{section_name} 섹션의 simulation은 개인화된 문장을 포함해야 합니다"
```

---

## 📝 변경된 파일

1. **`backend/langgraph_modules/report_graph.py`**
   - `_build_section_condition()` 함수 추가
   - `_format_simulation_text()` 시그니처 변경 및 개인화 로직 추가
   - `_postprocess_cards()` 시그니처 변경 (section_key, survey 추가)
   - `preload_quant_evidence()`에 outcome/timeframe 겹침 완화 로직 추가
   - 로그 출력 추가

2. **`backend/tools/report_smoke_test.py`**
   - simulation 개인화 검증 추가

---

## 🎯 핵심 개선 사항

### Before (일반론적)
```
"12주 유지 시, 연구에서 수분 장벽이(가) 중앙값 15.0% 변화..."
```

### After (개인화)
```
"당신의 평일 수면이 현재 5.5시간이므로, 이를 7시간 안팎으로만 늘려서 유지하면 12주 뒤에는, 연구에서 수분 장벽이(가) 중앙값 15.0% 변화..."
```

**차이점**:
- ✅ 사용자 설문 수치 직접 인용 (5.5시간)
- ✅ "무엇을 유지하면" 명확 (수면 시간 개선)
- ✅ 사용자 현재 상태를 정확히 지적
- ✅ 섹션별로 다른 condition 문장

---

## 🔍 Outcome/Timeframe 겹침 완화 효과

### Before
- sleep → wrinkle (12주, 10%)
- uv → wrinkle (12주, 10%)
- → 동일한 outcome + timeframe = 거의 동일한 텍스트

### After
- sleep → hydration_barrier (12주, 15%) [wrinkle은 이미 사용됨]
- uv → pigmentation (6개월, 12%) [12주는 이미 2번 사용됨]
- → 다른 outcome + 다른 timeframe = 다른 텍스트

---

## ✅ 검증 항목

스모크 테스트에서 확인:
- [x] simulation.text에 "당신의"/"당신은"/"현재" 포함
- [x] simulation.text에 설문 값(숫자) 포함
- [x] 섹션별로 다른 condition 문장 생성
- [x] outcome/timeframe 겹침 완화
- [x] 로그 출력 확인

---

## 📊 예시 출력

### sleep 섹션
```
📊 [sleep] condition="당신의 평일 수면이 5.5시간이므로, 이를 7시간 안팎으로만 늘려서 유지하면", tf=12주, outcome=수분장벽
```

### uv 섹션
```
📊 [uv] condition="당신은 선크림을 거의 바르지 않으므로, 외출할 때마다 한 번만이라도 바르는 습관을 유지하면", tf=6개월, outcome=색소침착
```

### activity 섹션
```
📊 [activity] condition="당신은 근력 운동을 전혀 하지 않으므로, 주 1회 20분만 추가해 유지하면", tf=12주, outcome=탄력
```

---

## 🎯 완료

모든 요구사항이 구현되었으며, simulation 카드가 사용자 데이터를 직접 반영한 개인화된 문장으로 생성됩니다.
