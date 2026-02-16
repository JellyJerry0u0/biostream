# 리포트 생성 LLM 호출 최적화 방향

## 1. 현재 구조 요약

| 구분 | 내용 |
|------|------|
| **LLM 호출 수** | 4~5회 (섹션당 1회, lifestyle은 3서브섹션 통합 1회) |
| **호출 위치** | `generate_section_cards` (goals, sleep, uv, activity), `generate_lifestyle_cards` (lifestyle) |
| **캐시** | `invoke_llm_json` 내 LRU 캐시 (prompt+system 해시 기반) |
| **Fallback** | LLM 실패 시 `create_default_cards` / `create_template_based_subsection_cards` (설문 기반 개인화) |

---

## 2. 리팩터링 방향 (우선순위)

### 방향 A: 섹션 배치 통합 (5회 → 2~3회) ⭐ 권장

**아이디어**: 서로 연관된 섹션을 묶어 한 번에 생성

| 배치 | 섹션 | 근거 |
|------|------|------|
| 그룹 1 | goals + sleep | 둘 다 outcomes/수면 기반, 사용자 관심사와 수면 패턴 연결 |
| 그룹 2 | uv + activity | 외부 환경(UV) + 신체 활동, 둘 다 “행동 개입” 중심 |
| 그룹 3 | lifestyle | 이미 3서브섹션 통합 1회 호출 유지 |

**구현 포인트**
- `build_batch_section_prompt(group: List[str], ...)` 추가 (lifestyle 통합 패턴 재활용)
- LLM 출력 형식: `{"goals": {"cards": [...]}, "sleep": {"cards": [...]}}`
- 기존 `postprocess_cards` 그대로 적용

**예상 효과**: 5회 → 3회 (약 40% 감소)

**리스크**: 프롬프트·출력 토큰 증가, 한 배치 실패 시 해당 그룹 전체 fallback 필요

---

### 방향 B: 병렬 호출 (지연시간 단축) ✅ 구현됨

**아이디어**: 호출 수는 유지, 동시 실행으로 총 소요 시간 단축

```
현재: goals(2초) → sleep(2초) → uv(2초) → lifestyle(2초) → activity(2초) ≈ 10초
병렬: [goals, sleep, uv, lifestyle, activity] 동시 → ≈ 2~3초
```

**구현 포인트**
- `write_section_cards` 안에서 `concurrent.futures.ThreadPoolExecutor` 또는 `asyncio`로 섹션별 `generate_section_cards` 병렬 실행
- Gemini API rate limit(분당 요청 수) 고려
- 배치 통합(방향 A)과 병행 가능: 3그룹 × 병렬 → 3회 동시 실행

**예상 효과**: 총 지연 ~70% 감소, 호출 수는 동일

---

### 방향 C: evidence 약한 섹션 템플릿 우선 (조건부 호출)

**아이디어**: 정량·서사 근거가 적으면 LLM 대신 템플릿 사용

**조건 예시**
```python
def should_skip_llm(section, section_quant, extracted_claims) -> bool:
    if section == "goals":
        return False  # goals는 항상 LLM (핵심)
    if section_quant.get("mode") != "grounded":
        return True   # estimated/없음 → 템플릿
    if not any(extracted_claims.get(section, {}).get(ct) for ct in ["problem", "cause", "action"]):
        return True   # claims 없음 → 템플릿
    return False
```

**구현 포인트**
- `generate_section_cards` 진입 시 `should_skip_llm`로 분기
- `create_default_cards`는 이미 sleep/uv/lifestyle/activity 설문 기반 개인화 구현

**예상 효과**: 설문·RAG 결과에 따라 0~2회 추가 절감

**리스크**: “estimated” 구간에서도 LLM이 더 나은 경우 존재 → 보수적 적용 필요

---

### 방향 D: 프롬프트 압축 (토큰·비용 절감)

**아이디어**: 토큰을 줄여 비용·지연을 낮추되, 품질은 유지

**예시**
- `format_quant_data`: 효과량·p-value 중심 요약, 원문 snippet 축소
- `_format_claims_text`: support_text 200자 → 100자
- `format_survey_data`: N/A·빈 값 필드 생략

**구현 포인트**
- `report_formatters.py`, `report_cards.py`에서 출력 길이 제한 상수 도입
- A/B 테스트로 품질 확인

**예상 효과**: 입력 토큰 20~30% 감소 → 비용·지연 약간 감소

---

## 3. 구현 순서 제안

| 단계 | 작업 | 예상 호출 감소 | 품질 리스크 |
|------|------|----------------|-------------|
| 1 | **방향 A**: goals+sleep, uv+activity 배치 | 5→3회 | 중 |
| 2 | **방향 B**: 섹션(또는 그룹)별 병렬 호출 | 지연 ~70%↓ | 낮음 |
| 3 | **방향 C**: evidence 약한 섹션 템플릿 우선 (선택) | 0~2회 추가 | 중~높음 |
| 4 | **방향 D**: 프롬프트 압축 | 토큰↓ | 낮음 |

---

## 4. 주의사항

1. **Gemini context limit**: 배치 통합 시 입력+출력이 커지므로, 모델별 context limit 확인 필요
2. **429 rate limit**: 병렬·배치 시 분당 요청 수 증가 가능 → 재시도 로직(`invoke_llm_json`) 유지
3. **품질 검증**: `validate_cards` 기준을 유지하며, 배치 출력의 각 섹션별 카드 수·형식 검증
4. **캐시**: 배치 프롬프트 구조 변경 시, 캐시 키는 새 구조에 맞게 유지
