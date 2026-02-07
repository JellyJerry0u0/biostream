# 리포트 생성 파이프라인 리팩토링 요약

## 변경 사항 요약

### A. 그래프 개인화 복구 ✅
**파일**: `backend/langgraph_modules/report_graph.py`
- **라인 2627-2628**: 그래프 엣지 수정
  - 기존: `plan_sections -> preload_quant_evidence`
  - 변경: `plan_sections -> derive_user_profile -> preload_quant_evidence`
- **라인 273-286**: `ReportState`에 `user_profile` 필드 확인 (이미 존재)
- **라인 650-668**: `derive_user_profile` 노드가 정상 실행되도록 엣지 추가

**검증 방법**:
```bash
# 리포트 생성 시 로그에서 다음 메시지 확인:
# "[DeriveUserProfile] 사용자 프로필 계산 완료: 성별: 여성, 연령대: 30대, BMI: 23.5 (정상)"
```

### B. Outcome -> Narrative Topics 매핑 ✅
**파일**: `backend/langgraph_modules/report_graph.py`
- **라인 327-340**: `OUTCOME_TO_NARRATIVE_TOPICS` 딕셔너리 추가
  - UI outcomes (예: `wrinkle`, `hydration_barrier`)를 narrative 코퍼스 topics (예: `wrinkle_elasticity`, `barrier_hydration`)로 매핑
- **라인 355-377**: `map_outcomes_to_topics()` 함수 구현
  - 중복 제거, 순서 유지, fallback 옵션 제공
- **라인 1022-1027**: `retrieve_narrative_evidence`에서 goals 섹션의 topics 매핑 적용

**검증 방법**:
```bash
# 리포트 생성 시 로그에서 다음 메시지 확인:
# "[goals] UI outcomes ['wrinkle', 'hydration_barrier'] → narrative topics ['wrinkle_elasticity', 'wrinkle', 'skin_aging', 'collagen', 'barrier_hydration', 'skin_barrier', 'hydration', 'moisture']"
```

### C. 듀얼 쿼리(영문 중심)로 RAG recall 개선 ✅
**파일**: `backend/langgraph_modules/report_graph.py`
- **라인 1004-1095**: `build_dual_queries()` 함수 추가
  - 섹션별/카드 타입별 영어 키워드 정의
  - 영어 쿼리(필수) + 한국어 보조 쿼리(선택) 반환
- **라인 1031-1105**: `retrieve_narrative_evidence` 수정
  - 1차: 영어 쿼리로 검색 (min_score=0.2)
  - 2차: 한국어 쿼리로 보충 (부족 시)
  - 3차: min_score=0.12로 완화하여 재검색 (0건일 때)

**검증 방법**:
```bash
# 리포트 생성 시 로그에서 다음 메시지 확인:
# "[sleep.problem] 1차 영어 검색: 3개 (top_score=0.456)"
# "[sleep.problem] 2차 한국어 보충: 총 5개"
# 또는
# "[uv.cause] 3차 fallback (min_score=0.12): 2개 (top_score=0.134)"
```

### D. Quant fallback 안정화 ✅
**파일**: `backend/langgraph_modules/report_graph.py`
- **라인 273-286**: `ReportState`에 `available_quant_outcomes: Optional[set]` 필드 추가
- **라인 684-700**: `preload_quant_evidence`에서 available outcomes 수집
  - 모든 후보 outcome을 샘플링하여 실제 존재하는 것만 필터링
- **라인 900-909, 920-930**: `calculate_estimated_stats` 호출 전 available outcomes로 필터링
  - goals 섹션과 일반 섹션 모두 적용

**검증 방법**:
```bash
# 리포트 생성 시 로그에서 다음 메시지 확인:
# "📊 Available quant outcomes: 15개 (['acne', 'elasticity', 'hydration_barrier', ...])"
# "⚠️ grounded 없음 → estimated (12주, 8.5%)"  # available outcomes만 사용
```

### E. Claim extraction 입력 손실 개선 ✅
**파일**: `backend/langgraph_modules/report_graph.py`
- **라인 1115-1135**: `extract_claims`에서 문장 단위 추출로 변경
  - 기존: `item.text[:300]` (문자 수로 자르기)
  - 변경: 마침표/세미콜론 기준 문장 분리 후, 충분한 길이(30자 이상)의 문장 1-2개 선택
  - 최대 400자로 제한

**검증 방법**:
- 리포트 생성 후 카드 텍스트가 문맥이 유지된 문장으로 구성되었는지 확인
- 로그에서 claims 추출 성공 메시지 확인

### F. 과확신 표현 완화 ✅
**파일**: `backend/langgraph_modules/report_graph.py`
- **라인 2092-2107**: `_soften_overconfident_language()` 함수 추가
  - "반드시" → "권장됩니다"
  - "확실히" → "가능성이 큽니다"
  - "절대적으로" → "대체로"
  - "필수적으로" → "권장됩니다"
  - "100%" → "높은 확률로"
- **라인 2320, 2330, 2367-2368**: `_postprocess_cards`에서 모든 카드 타입에 적용
  - problem/cause/simulation/action 모두 적용

**검증 방법**:
- 리포트 생성 후 카드 텍스트에서 "반드시", "확실히" 같은 강한 표현이 완화되었는지 확인

## 변경된 파일 목록

1. **backend/langgraph_modules/report_graph.py** (주요 변경)
   - 약 100줄 추가/수정
   - 주요 변경 라인:
     - 273-286: State 정의 (available_quant_outcomes 추가)
     - 327-377: Outcome 매핑 관련 함수 추가
     - 684-930: preload_quant_evidence 수정 (available outcomes 수집)
     - 1004-1095: build_dual_queries 함수 추가
     - 1031-1105: retrieve_narrative_evidence 듀얼 쿼리 적용
     - 1115-1135: extract_claims 문장 단위 추출
     - 2092-2107: _soften_overconfident_language 함수 추가
     - 2320, 2330, 2367-2368: 과확신 표현 완화 적용
     - 2627-2628: 그래프 엣지 수정

2. **backend/tools/test_report_refactoring.py** (신규)
   - 리팩토링 검증 테스트 스크립트

## 테스트 방법

### 1. 단위 테스트 (매핑 함수)
```bash
cd /Users/wecd_ds/biostream/backend
python tools/test_report_refactoring.py
```

### 2. 리포트 생성 스모크 테스트
```bash
cd /Users/wecd_ds/biostream/backend
python -c "
from langgraph_modules.report_graph import generate_report
result = generate_report(user_id=1, lifestyle_id=None)
print('Success:', result.get('success'))
if result.get('report'):
    sections = result['report'].get('sections', {})
    print('Sections:', list(sections.keys()))
"
```

### 3. 로그 확인 체크리스트
리포트 생성 시 다음 로그 메시지들을 확인하세요:

- [ ] `[DeriveUserProfile] 사용자 프로필 계산 완료: ...` (A. 개인화 복구)
- [ ] `[goals] UI outcomes [...] → narrative topics [...]` (B. Topics 매핑)
- [ ] `1차 영어 검색: N개` (C. 듀얼 쿼리)
- [ ] `Available quant outcomes: N개` (D. Quant fallback)
- [ ] 리포트 카드에서 "반드시" 같은 강한 표현이 없음 (F. 과확신 완화)

## 주의사항

1. **하위 호환성**: 기존 API 스키마는 유지됩니다. `final_report` 구조는 변경되지 않았습니다.
2. **Fallback 안정성**: quant 근거가 없어도 리포트 생성이 중단되지 않습니다 (narrative만 사용).
3. **성능**: available outcomes 수집은 샘플링 방식으로 빠르게 처리됩니다.
4. **에러 처리**: 모든 단계에서 예외가 발생해도 리포트 생성이 계속 진행됩니다.

## 다음 단계 (선택사항)

1. **성능 최적화**: available outcomes 수집을 캐싱하거나 비동기 처리
2. **매핑 확장**: 더 많은 outcome-topic 매핑 추가
3. **쿼리 개선**: LLM을 사용한 동적 쿼리 생성 고려
4. **모니터링**: 각 단계별 성공률/실패율 메트릭 수집
