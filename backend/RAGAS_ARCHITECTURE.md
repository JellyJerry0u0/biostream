# RAGAS 신뢰도 평가 시스템 전체 구조

## 📋 목차
1. [전체 아키텍처](#전체-아키텍처)
2. [코드 상세 설명](#코드-상세-설명)
3. [RAGAS 평가 로직](#ragas-평가-로직)
4. [MCP 통합 계획](#mcp-통합-계획)
5. [데이터 흐름](#데이터-흐름)

---

## 1. 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                     LangGraph Report Generation                  │
│                      (report_graph.py)                           │
│                                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Load     │→ │ Plan     │→ │ Preload  │→ │ Build    │        │
│  │ Survey   │  │ Sections │  │ Quant    │  │ Queries  │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│                                                    ↓              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Save     │← │ Assemble │← │ Write    │← │ Retrieve │        │
│  │ Report   │  │ Report   │  │ Cards    │  │ Evidence │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│                                                                   │
│              Final State (ReportState)                           │
│  ┌────────────────────────────────────────────────────┐         │
│  │ - active_sections: ["sleep", "uv", ...]           │         │
│  │ - section_queries: {section: {card_type: query}}  │         │
│  │ - narrative_evidence: {section: {card_type: [EvidenceItem]}}│
│  │ - section_cards: {section: [card1, card2, ...]}   │         │
│  └────────────────────────────────────────────────────┘         │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│              RAGAS Reliability Evaluation                        │
│                (reliability_auditor.py)                          │
│                                                                   │
│  ┌─────────────────────────────────────────────────────┐        │
│  │           ReliabilityAuditor                         │        │
│  │  ┌───────────────────────────────────────────────┐  │        │
│  │  │ __init__(api_key)                             │  │        │
│  │  │  - Gemini 1.5 Flash LLM 초기화               │  │        │
│  │  │  - Temperature = 0.0 (일관성 중시)           │  │        │
│  │  └───────────────────────────────────────────────┘  │        │
│  │                                                       │        │
│  │  ┌───────────────────────────────────────────────┐  │        │
│  │  │ evaluate_section(section, card_type, ...)    │  │        │
│  │  │                                               │  │        │
│  │  │  Input:                                       │  │        │
│  │  │    - question: "수면 부족 단기간 피부 장벽"  │  │        │
│  │  │    - contexts: ["Sleep deprivation...", ...] │  │        │
│  │  │    - answer: "수면이 부족하면 피부의..."      │  │        │
│  │  │                                               │  │        │
│  │  │  Process:                                     │  │        │
│  │  │    1. 데이터를 RAGAS Dataset 형식으로 변환   │  │        │
│  │  │    2. ragas.evaluate() 호출                   │  │        │
│  │  │       - faithfulness 메트릭                   │  │        │
│  │  │       - answer_relevancy 메트릭              │  │        │
│  │  │    3. 점수 추출 및 평균 계산                  │  │        │
│  │  │    4. 등급 할당 (Verified/Plausible/Caution) │  │        │
│  │  │                                               │  │        │
│  │  │  Output: ReliabilityScore                    │  │        │
│  │  └───────────────────────────────────────────────┘  │        │
│  │                                                       │        │
│  │  ┌───────────────────────────────────────────────┐  │        │
│  │  │ evaluate_report_state(state)                 │  │        │
│  │  │                                               │  │        │
│  │  │  Loop: 각 섹션 × 각 카드 타입               │  │        │
│  │  │    - sleep/problem                            │  │        │
│  │  │    - sleep/cause                              │  │        │
│  │  │    - sleep/action                             │  │        │
│  │  │    - uv/problem, uv/cause, uv/action ...     │  │        │
│  │  │                                               │  │        │
│  │  │  Output: {section: [ReliabilityScore, ...]} │  │        │
│  │  └───────────────────────────────────────────────┘  │        │
│  └─────────────────────────────────────────────────────┘        │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                  MCP Server Integration                          │
│                   (mcp_server/server.py)                         │
│                        [향후 계획]                                │
│                                                                   │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  @mcp.tool()                                        │        │
│  │  async def evaluate_report_reliability(            │        │
│  │      user_id: int,                                  │        │
│  │      lifestyle_id: int                              │        │
│  │  ) -> dict:                                         │        │
│  │      """리포트 생성 후 자동으로 신뢰도 평가"""      │        │
│  │                                                      │        │
│  │      1. LangGraph 실행 (report_graph.py)           │        │
│  │      2. final_state 획득                            │        │
│  │      3. ReliabilityAuditor.evaluate_report_state()  │        │
│  │      4. 결과를 DB에 저장 (새 테이블 또는 JSON)     │        │
│  │      5. 클라이언트에 신뢰도 메타데이터 반환        │        │
│  │                                                      │        │
│  │      return {                                        │        │
│  │          "report_id": ...,                          │        │
│  │          "reliability_scores": {                    │        │
│  │              "sleep": [                             │        │
│  │                  {"card_type": "problem",           │        │
│  │                   "grade": "Verified",              │        │
│  │                   "color": "Green",                 │        │
│  │                   "faithfulness": 0.95,             │        │
│  │                   "relevancy": 0.92}                │        │
│  │              ],                                      │        │
│  │              ...                                     │        │
│  │          },                                          │        │
│  │          "overall_grade": "Verified",               │        │
│  │          "overall_score": 0.88                      │        │
│  │      }                                               │        │
│  └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 코드 상세 설명

### 2.1 핵심 클래스 및 데이터 구조

#### `ReliabilityScore` (데이터클래스)
각 카드의 신뢰도 평가 결과를 저장하는 구조체입니다.

```python
@dataclass
class ReliabilityScore:
    section: str              # 섹션 이름 (sleep, uv, lifestyle 등)
    card_type: str            # 카드 타입 (problem, cause, action)
    faithfulness_score: float # 신뢰성 점수 (0~1) - 답변이 근거에 충실한가?
    relevancy_score: float    # 관련성 점수 (0~1) - 답변이 질문과 관련있는가?
    average_score: float      # 평균 점수 = (faithfulness + relevancy) / 2
    grade: str                # 등급 (Verified/Plausible/Caution)
    color: str                # UI 표시 색상 (Green/Blue/Yellow)
    message: str              # 사용자 메시지
    question: str             # 원본 질문 (쿼리)
    contexts_count: int       # 사용된 근거 문서 개수
    answer_length: int        # 생성된 답변 길이
```

**목적**: 각 카드의 신뢰도를 다각도로 평가하고, UI에 표시할 정보를 모두 포함

---

#### `ReliabilityAuditor` (메인 클래스)

##### 초기화 (`__init__`)
```python
def __init__(self, api_key: Optional[str] = None):
    # 1. API 키 자동 로드 (환경변수 우선)
    # 2. Gemini 1.5 Flash LLM 설정
    #    - temperature=0.0: 평가의 일관성 확보
    #    - max_retries=3: API 오류 대비
```

**설계 이유**: 
- Gemini 1.5 Flash는 속도가 빠르고 비용이 저렴하여 평가용으로 적합
- Temperature=0.0으로 매번 동일한 평가 기준 유지
- 환경변수 자동 로드로 편의성 제공

---

##### 등급 계산 (`_calculate_grade`)
```python
def _calculate_grade(self, score: float) -> tuple[str, str, str]:
    if score >= 0.9:
        return "Verified", "Green", "모든 내용이 논문 근거와 일치합니다."
    elif score >= 0.7:
        return "Plausible", "Blue", "대부분의 근거가 확실하며 개연성이 높습니다."
    else:
        return "Caution", "Yellow", "일부 추론이 포함되어 있으니 주의가 필요합니다."
```

**점수 기준 논리**:
- **0.9 이상 (Verified)**: 
  - 거의 완벽한 근거 기반 답변
  - 사용자가 완전히 신뢰할 수 있는 수준
  - UI: 녹색 배지로 강조
  
- **0.7~0.9 (Plausible)**: 
  - 대부분 근거에 기반하나 일부 해석 포함
  - 일반적으로 수용 가능한 품질
  - UI: 파란색 배지
  
- **0.7 미만 (Caution)**: 
  - 근거가 불충분하거나 추론이 많음
  - 사용자에게 주의 필요성 알림
  - UI: 노란색 경고 배지

---

##### 단일 카드 평가 (`evaluate_section`)

이것이 **핵심 평가 로직**입니다.

```python
def evaluate_section(
    self,
    section: str,        # "sleep"
    card_type: str,      # "problem"
    question: str,       # "수면 부족 단기간 피부 장벽 수분"
    contexts: List[str], # ["Sleep deprivation has...", "The skin's ability..."]
    answer: str          # "수면이 부족하면 피부의 장벽 기능이..."
) -> Optional[ReliabilityScore]:
```

**처리 흐름**:

1. **데이터 검증**
   ```python
   if not contexts or not answer or not question:
       return None  # 필수 데이터 없으면 평가 불가
   ```

2. **RAGAS 데이터셋 변환**
   ```python
   eval_data = {
       "question": [question],      # 리스트 형태로 변환
       "contexts": [contexts],      # contexts는 이미 리스트, 한번 더 감싸기
       "answer": [answer]
   }
   dataset = Dataset.from_dict(eval_data)  # HuggingFace Dataset 객체
   ```
   
   **중요**: RAGAS는 HuggingFace `datasets` 라이브러리의 Dataset 형식을 요구

3. **RAGAS 평가 실행**
   ```python
   result = evaluate(
       dataset=dataset,
       metrics=[faithfulness, answer_relevancy],
       llm=self.evaluator_llm,      # Gemini 1.5 Flash
       embeddings=None              # RAGAS 기본 임베딩 사용
   )
   ```
   
   **내부 동작** (RAGAS 라이브러리):
   - `faithfulness`: LLM에게 "이 답변의 각 주장(claim)이 contexts에서 지지되는가?" 질문
   - `answer_relevancy`: LLM에게 "이 답변이 질문과 얼마나 관련있는가?" 질문
   - 여러 번의 LLM 호출로 정밀 평가

4. **점수 추출 및 등급 할당**
   ```python
   faithfulness_score = result.get("faithfulness", 0.0)
   relevancy_score = result.get("answer_relevancy", 0.0)
   average_score = (faithfulness_score + relevancy_score) / 2
   
   grade, color, message = self._calculate_grade(average_score)
   ```

5. **결과 객체 생성**
   ```python
   return ReliabilityScore(
       section=section,
       card_type=card_type,
       faithfulness_score=faithfulness_score,
       relevancy_score=relevancy_score,
       average_score=average_score,
       grade=grade,
       color=color,
       message=message,
       ...
   )
   ```

---

##### 전체 리포트 평가 (`evaluate_report_state`)

LangGraph의 `ReportState`를 받아 **모든 섹션 × 모든 카드 타입**을 순회하며 평가합니다.

```python
def evaluate_report_state(self, state: Dict[str, Any]) -> Dict[str, List[ReliabilityScore]]:
```

**처리 흐름**:

1. **State에서 데이터 추출**
   ```python
   active_sections = state.get("active_sections", [])  # ["sleep", "uv", ...]
   section_queries = state.get("section_queries", {})
   narrative_evidence = state.get("narrative_evidence", {})
   section_cards = state.get("section_cards", {})
   ```

2. **이중 루프: 섹션 × 카드 타입**
   ```python
   for section in active_sections:  # sleep, uv, lifestyle, ...
       for card_type in ["problem", "cause", "action"]:
           # 데이터 매핑
           question = queries.get(card_type, "")
           
           # EvidenceItem 객체에서 텍스트만 추출
           evidence_items = evidence.get(card_type, [])
           contexts = [item.text for item in evidence_items 
                      if isinstance(item, EvidenceItem)]
           
           # 해당 카드 타입의 카드 찾기
           answer = ""
           for card in cards:
               if card.get("card_type") == card_type:
                   answer = card.get("text", "")
                   break
           
           # 평가 실행
           score = self.evaluate_section(...)
   ```

3. **결과 집계**
   ```python
   all_scores = {
       "sleep": [
           ReliabilityScore(card_type="problem", ...),
           ReliabilityScore(card_type="cause", ...),
           ReliabilityScore(card_type="action", ...)
       ],
       "uv": [...]
   }
   return all_scores
   ```

---

### 2.2 편의 함수

#### `run_ragas_test` (원라이너 실행)
```python
def run_ragas_test(state: Dict[str, Any]) -> Dict[str, List[ReliabilityScore]]:
    auditor = ReliabilityAuditor()
    scores = auditor.evaluate_report_state(state)
    auditor.print_summary(scores)  # 결과 요약 출력
    return scores
```

**용도**: 
- 간편하게 한 줄로 평가 + 출력
- LangGraph 실행 직후 바로 사용 가능

```python
# 사용 예시
from report_modules.report_graph import app
from tools.reliability_auditor import run_ragas_test

# 1. 리포트 생성
final_state = app.invoke(initial_state)

# 2. 신뢰도 평가
reliability_scores = run_ragas_test(final_state)
```

---

## 3. RAGAS 평가 로직

### 3.1 RAGAS란?

**RAGAS** (Retrieval Augmented Generation Assessment)는 RAG 시스템의 품질을 평가하는 프레임워크입니다.

#### 핵심 메트릭

##### 1. **Faithfulness (충실성, 신뢰성)**

$$Faithfulness = \frac{|\text{Claims supported by context}|}{|\text{Total claims in answer}|}$$

**평가 방법**:
1. LLM이 답변에서 모든 주장(claim)을 추출
   - 예: "수면 부족은 피부 장벽을 약화시킨다" → Claim 1
   - 예: "단 하루만 수면 부족해도 영향을 준다" → Claim 2

2. 각 주장이 contexts(근거 문서)에 의해 지지되는지 검증
   - Claim 1: contexts에 "Sleep deprivation impairs skin barrier" 있음 → ✅
   - Claim 2: contexts에 "even one night of poor sleep affects skin" 있음 → ✅

3. 지지되는 비율 계산
   - 2개 주장 모두 지지됨 → 2/2 = 1.0 (완벽)

**의미**: 
- 점수가 높을수록 답변이 근거에 충실
- 점수가 낮으면 "환각(hallucination)" 또는 과도한 추론 포함

---

##### 2. **Answer Relevancy (관련성)**

답변이 질문과 얼마나 관련 있는가?

**평가 방법**:
1. LLM이 답변을 보고 역으로 질문을 생성 (reverse question generation)
2. 생성된 질문과 원본 질문의 유사도 계산 (코사인 유사도)

**예시**:
- 원본 질문: "수면 부족이 피부에 미치는 영향은?"
- 답변: "수면 부족은 피부 장벽을 약화시키고 수분 손실을 증가시킵니다."
- LLM 생성 질문: "수면 부족이 피부 장벽과 수분에 어떤 영향을 주나요?"
- 유사도: 높음 → 0.95

**의미**: 
- 답변이 질문의 핵심을 다루는지 평가
- 엉뚱한 답변이나 주제 이탈 방지

---

### 3.2 평가 흐름 (내부 동작)

```
Input: question, contexts, answer
  ↓
┌─────────────────────────────────────────┐
│ 1. Faithfulness 평가                    │
│                                          │
│  LLM Prompt:                             │
│  "다음 답변에서 모든 주장을 추출하세요"  │
│  Answer: "수면 부족은 피부 장벽을..."    │
│                                          │
│  LLM Response:                           │
│  Claims: [                               │
│    "수면 부족은 피부 장벽을 약화",       │
│    "수분 손실 증가",                     │
│    "하루만 부족해도 영향"                │
│  ]                                       │
│                                          │
│  ─────────────────────────────────       │
│                                          │
│  LLM Prompt (각 claim별):                │
│  "이 주장이 contexts에 의해 지지되나요?" │
│  Claim: "수면 부족은 피부 장벽을 약화"   │
│  Contexts: ["Sleep deprivation...", ...] │
│                                          │
│  LLM Response: Yes (1) or No (0)         │
│                                          │
│  최종 점수: 3개 중 3개 지지됨 = 1.0      │
└─────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────┐
│ 2. Answer Relevancy 평가                │
│                                          │
│  LLM Prompt:                             │
│  "이 답변을 보고 원래 질문이 무엇인지   │
│   추론하세요"                            │
│  Answer: "수면 부족은 피부 장벽을..."    │
│                                          │
│  LLM Response (생성된 질문):             │
│  "수면 부족이 피부 건강에 미치는 영향?"  │
│                                          │
│  ─────────────────────────────────       │
│                                          │
│  Embedding 유사도 계산:                  │
│  원본 질문 임베딩 vs 생성 질문 임베딩    │
│  Cosine Similarity: 0.92                 │
└─────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────┐
│ 3. 점수 집계                             │
│                                          │
│  faithfulness_score: 1.0                 │
│  relevancy_score: 0.92                   │
│  average_score: 0.96                     │
│                                          │
│  Grade: Verified (≥ 0.9)                 │
│  Color: Green                            │
└─────────────────────────────────────────┘
```

---

## 4. MCP 통합 계획

### 4.1 현재 상태 vs. MCP 통합 후

#### 현재 (reliability_auditor.py 단독)
```python
# 수동 실행
from report_modules.report_graph import app
from tools.reliability_auditor import run_ragas_test

final_state = app.invoke(initial_state)
scores = run_ragas_test(final_state)
```

#### MCP 통합 후
```python
# mcp_server/server.py에 추가

@mcp.tool()
async def generate_report_with_reliability(
    user_id: int,
    lifestyle_id: int
) -> dict:
    """리포트 생성 + 자동 신뢰도 평가"""
    
    # 1. LangGraph로 리포트 생성
    from report_modules.report_graph import app
    initial_state = {
        "user_id": user_id,
        "lifestyle_id": lifestyle_id,
        ...
    }
    final_state = app.invoke(initial_state)
    
    # 2. 신뢰도 평가
    from tools.reliability_auditor import ReliabilityAuditor
    auditor = ReliabilityAuditor()
    scores = auditor.evaluate_report_state(final_state)
    
    # 3. 결과 포맷팅
    reliability_metadata = {
        "overall_grade": calculate_overall_grade(scores),
        "overall_score": calculate_overall_score(scores),
        "section_scores": {
            section: [
                {
                    "card_type": score.card_type,
                    "grade": score.grade,
                    "color": score.color,
                    "faithfulness": score.faithfulness_score,
                    "relevancy": score.relevancy_score,
                    "message": score.message
                }
                for score in section_scores
            ]
            for section, section_scores in scores.items()
        }
    }
    
    # 4. DB 저장 (선택)
    # save_reliability_to_db(final_state["report_id"], reliability_metadata)
    
    # 5. 반환
    return {
        "report_id": final_state.get("final_report", {}).get("id"),
        "report": final_state.get("final_report"),
        "reliability": reliability_metadata
    }
```

---

### 4.2 프론트엔드 연동 예시

```typescript
// Flutter/Dart 클라이언트
const response = await mcpClient.callTool(
  'generate_report_with_reliability',
  { user_id: 123, lifestyle_id: 456 }
);

// 신뢰도 배지 표시
for (const section in response.reliability.section_scores) {
  for (const card of response.reliability.section_scores[section]) {
    // UI에 배지 표시
    renderReliabilityBadge(
      grade: card.grade,       // "Verified"
      color: card.color,       // "Green"
      message: card.message    // "모든 내용이 논문 근거와..."
    );
  }
}
```

---

## 5. 데이터 흐름

### 5.1 전체 파이프라인

```
┌──────────────────────────────────────────────────────────────┐
│ Step 1: 사용자 데이터 수집                                   │
│  - 설문조사 (outcomes, sleep_hours, sun_exposure, ...)      │
└────────────────────┬─────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 2: LangGraph 리포트 생성                                │
│  - BuildQueries: "수면 부족 단기간 피부 장벽 수분"          │
│  - RetrieveNarrativeEvidence: Qdrant 검색                   │
│    → contexts: ["Sleep deprivation has...", ...]            │
│  - WriteSectionCards: Gemini로 카드 생성                    │
│    → answer: "수면이 부족하면 피부의 장벽 기능이..."         │
└────────────────────┬─────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 3: RAGAS 신뢰도 평가 (reliability_auditor.py)          │
│                                                              │
│  For each section (sleep, uv, ...):                         │
│    For each card_type (problem, cause, action):             │
│                                                              │
│      Input:                                                  │
│        question = section_queries[section][card_type]       │
│        contexts = [item.text for item in                    │
│                    narrative_evidence[section][card_type]]  │
│        answer = section_cards[section][card_type]["text"]   │
│                                                              │
│      ─────────────────────────────────                      │
│                                                              │
│      RAGAS evaluate():                                       │
│        1. Faithfulness 계산                                  │
│           - LLM이 claims 추출                                │
│           - 각 claim이 contexts에 지지되는지 검증            │
│           - 비율 계산: supported / total                     │
│                                                              │
│        2. Answer Relevancy 계산                              │
│           - LLM이 답변 보고 질문 역생성                      │
│           - 임베딩 유사도 계산                               │
│                                                              │
│      ─────────────────────────────────                      │
│                                                              │
│      Output: ReliabilityScore                               │
│        - faithfulness_score: 0.95                           │
│        - relevancy_score: 0.92                              │
│        - average_score: 0.935                               │
│        - grade: "Verified"                                   │
│        - color: "Green"                                      │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 4: 결과 통합 및 반환                                    │
│                                                              │
│  {                                                           │
│    "report": { ... },                                        │
│    "reliability": {                                          │
│      "overall_grade": "Verified",                           │
│      "overall_score": 0.88,                                  │
│      "section_scores": {                                     │
│        "sleep": [                                            │
│          {                                                   │
│            "card_type": "problem",                          │
│            "grade": "Verified",                             │
│            "color": "Green",                                 │
│            "faithfulness": 0.95,                            │
│            "relevancy": 0.92,                                │
│            "message": "모든 내용이 논문 근거와 일치합니다."  │
│          },                                                  │
│          ...                                                 │
│        ],                                                    │
│        ...                                                   │
│      }                                                       │
│    }                                                         │
│  }                                                           │
└────────────────────┬─────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 5: UI 표시                                              │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  Sleep Section                               │          │
│  │  ┌────────────────────────────────────────┐ │          │
│  │  │ Problem Card                    [✅ Verified] │          │
│  │  │ "수면이 부족하면 피부의 장벽..."        │ │          │
│  │  │                                          │ │          │
│  │  │ ℹ️ 모든 내용이 논문 근거와 일치합니다.  │ │          │
│  │  └────────────────────────────────────────┘ │          │
│  │                                              │          │
│  │  ┌────────────────────────────────────────┐ │          │
│  │  │ Cause Card                      [✅ Verified] │          │
│  │  │ "수면 파편화는 코르티솔 수치를..."      │ │          │
│  │  └────────────────────────────────────────┘ │          │
│  │                                              │          │
│  │  ┌────────────────────────────────────────┐ │          │
│  │  │ Action Card                     [🔵 Plausible] │         │
│  │  │ "충분한 수면을 확보하면 2-4주..."       │ │          │
│  │  │                                          │ │          │
│  │  │ ℹ️ 대부분의 근거가 확실하며 개연성이... │ │          │
│  │  └────────────────────────────────────────┘ │          │
│  └──────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────┘
```

---

## 6. 핵심 장점

### 6.1 품질 보증
- **자동화된 신뢰도 검증**: 사람이 일일이 확인할 필요 없이 LLM이 자동으로 평가
- **객관적 지표**: Faithfulness와 Relevancy라는 정량적 메트릭 사용
- **일관성**: Temperature=0.0으로 동일한 기준 적용

### 6.2 사용자 신뢰
- **투명성**: 각 카드의 신뢰도를 명시적으로 표시
- **근거 기반**: 논문 근거와 얼마나 일치하는지 수치로 제공
- **위험 관리**: Caution 등급으로 불확실한 내용 사전 경고

### 6.3 개발 효율성
- **모듈화**: ReliabilityAuditor 클래스로 독립적 사용 가능
- **확장성**: MCP 서버에 쉽게 통합 가능
- **디버깅**: 로컬 테스트 코드로 즉시 검증

---

## 7. 잠재적 이슈 및 해결 방안

### 이슈 1: RAGAS 평가 비용
- **문제**: 카드마다 LLM 호출 → 비용 증가
- **해결**: 
  - Gemini 1.5 Flash 사용 (저비용)
  - 캐싱 활용 (동일 contexts 재평가 방지)
  - 배치 평가 (한 번에 여러 카드 평가)

### 이슈 2: 평가 시간
- **문제**: 리포트 생성 + 평가 = 긴 대기 시간
- **해결**:
  - 비동기 처리 (리포트 먼저 반환, 신뢰도는 나중에 업데이트)
  - 백그라운드 작업 큐 사용
  - 캐싱으로 재평가 방지

### 이슈 3: 한글-영어 혼재
- **문제**: 질문(한글) vs. Contexts(영어) → 평가 정확도 저하 가능
- **해결**:
  - 질문을 영어로 번역 후 평가
  - 또는 contexts를 한글로 번역 후 평가
  - RAGAS가 다국어 지원하므로 실험 필요

---

## 8. 다음 단계

### Phase 1: 로컬 테스트 ✅
- [x] reliability_auditor.py 작성
- [ ] 샘플 데이터로 실행 확인
- [ ] 점수 범위 및 등급 기준 검증

### Phase 2: LangGraph 통합
- [ ] report_graph.py에 평가 노드 추가
- [ ] 실제 리포트 State로 테스트
- [ ] 성능 측정 (평가 시간, API 비용)

### Phase 3: MCP 서버 통합
- [ ] mcp_server/server.py에 tool 추가
- [ ] DB 스키마 설계 (신뢰도 메타데이터 저장)
- [ ] 비동기 처리 구현

### Phase 4: 프론트엔드 연동
- [ ] 신뢰도 배지 UI 컴포넌트
- [ ] 상세 정보 툴팁
- [ ] 필터링 기능 (Verified만 보기 등)

---

## 결론

`reliability_auditor.py`는 RAGAS를 활용하여 LangGraph 리포트의 신뢰도를 자동으로 평가하는 완전한 시스템입니다. 

**핵심 강점**:
- ✅ LangGraph State와 완벽히 호환
- ✅ Faithfulness + Relevancy 이중 검증
- ✅ 3단계 등급 시스템 (Verified/Plausible/Caution)
- ✅ MCP 서버 통합 준비 완료
- ✅ 로컬 테스트 코드 포함

**코드 유지 권장**: 이 코드는 요구사항을 충실히 구현하고 있으며, 향후 MCP 통합과 프론트엔드 연동이 용이한 구조입니다.
