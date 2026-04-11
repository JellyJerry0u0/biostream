"""
리포트 생성 상수 및 매핑 정의
- ReportState (TypedDict)
- 목표/섹션/outcome 관련 상수
- 카드 생성용 키워드 사전
"""

from typing import Dict, Any, List, Optional, Tuple, TypedDict
from tools.schemas import EvidenceItem


# ──────────────────────────── State ────────────────────────────

class ReportState(TypedDict, total=False):
    """리포트 생성 상태 (Quant-First + Evidence Extraction + RAGAS Reliability)"""
    user_id: int
    lifestyle_id: Optional[int]
    survey: Optional[Dict[str, Any]]
    user_profile: Optional[Dict[str, Any]]
    active_sections: List[str]
    available_quant_outcomes: Optional[set]
    quant_evidence_results: Dict[str, Dict[str, Any]]
    section_queries: Dict[str, Dict[str, str]]
    narrative_evidence: Dict[str, Dict[str, List[EvidenceItem]]]
    extracted_claims: Dict[str, Dict[str, List[Dict[str, Any]]]]
    section_cards: Dict[str, List[Dict[str, Any]]]
    quality_flags: Dict[str, Any]
    final_report: Optional[Dict[str, Any]]
    retry_needed: bool
    retry_sections: List[str]
    retry_count: Dict[str, Any]
    # 이미지 생성 관련 필드
    generated_image_url: Optional[str]  # AI가 생성한 미래 얼굴 이미지 URL
    generation_status: Optional[str]    # 이미지 생성 상태 (not_started/pending/processing/completed/failed)
    image_gen_params: Optional[Dict[str, Any]]  # 이미지 생성에 사용된 파라미터 (wrinkles, pigmentation 등)
    situation_text: Optional[str]  # 사용자 참고 상황 (DB 저장 안 함, 프롬프트에만 반영)


# ──────────────────────────── 목표(outcome) 매핑 ────────────────────────────

OUTCOME_LABELS: Dict[str, str] = {
    "wrinkle": "주름",
    "elasticity": "탄력",
    "pigmentation": "색소",
    "hydration": "수분",
    "hydration_barrier": "장벽",
    "acne": "여드름",
    "redness": "홍조",
    "general_aging": "전체 노화",
    "general_skin": "전체 피부",
}

OUTCOME_POLARITY: Dict[str, str] = {
    "wrinkle": "decrease_is_improvement",
    "elasticity": "increase_is_improvement",
    "pigmentation": "decrease_is_improvement",
    "hydration": "increase_is_improvement",
    # TEWL(수분손실) 감소=개선 → 음수=좋음
    "hydration_barrier": "decrease_is_improvement",
    "acne": "decrease_is_improvement",
    "redness": "decrease_is_improvement",
    "general_aging": "mixed",
    "general_skin": "mixed",
}

# UI outcomes → quant_evidence.outcome_mapped 매핑
UI_OUTCOME_TO_QUANT_MAPPED: Dict[str, List[str]] = {
    "wrinkle": ["wrinkle", "elasticity"],
    "elasticity": ["elasticity", "wrinkle"],
    "hydration": ["hydration_barrier"],
    "hydration_barrier": ["hydration_barrier"],
    "pigmentation": ["pigmentation"],
    "acne": ["acne"],
    "redness": ["redness"],
    "general_aging": ["general_skin", "wrinkle", "elasticity", "pigmentation"],
}

# UI outcomes → narrative 코퍼스 topics 매핑
OUTCOME_TO_NARRATIVE_TOPICS: Dict[str, List[str]] = {
    "wrinkle": ["wrinkle_elasticity", "wrinkle", "skin_aging", "collagen"],
    "elasticity": ["wrinkle_elasticity", "elasticity", "skin_aging", "collagen"],
    "hydration": ["barrier_hydration", "hydration", "skin_barrier", "moisture"],
    "hydration_barrier": ["barrier_hydration", "skin_barrier", "hydration", "moisture"],
    "pigmentation": ["pigmentation", "melanin", "hyperpigmentation", "skin_color"],
    "acne": ["acne", "inflammation", "sebum", "skin_inflammation"],
    "redness": ["redness", "erythema", "inflammation", "skin_inflammation"],
    "general_aging": ["skin_aging", "wrinkle_elasticity", "pigmentation", "general_skin"],
}

# 섹션별 outcome 후보 리스트 (우선순위 순)
# ※ 각 섹션마다 고유한 1순위 outcome 배치 → 예상경로 겹침(탄력 4/5) 방지
SECTION_OUTCOME_CANDIDATES: Dict[str, List[str]] = {
    "sleep": ["hydration_barrier", "redness", "wrinkle", "elasticity"],      # 수면→수분/장벽
    "uv": ["pigmentation", "redness", "wrinkle", "elasticity"],               # UV→색소
    "lifestyle": ["acne", "redness", "hydration_barrier", "pigmentation"],   # 생활습관→여드름/염증
    "activity": ["elasticity", "wrinkle", "general_skin"],                   # 운동→탄력
}

# 생활습관 평탄화: smoking/drinking/stress를 최상위 섹션으로
LIFESTYLE_SECTIONS = ("smoking", "drinking", "stress")

# 섹션별 1순위 outcome (예상경로 다양화용)
SECTION_PRIMARY_OUTCOME: Dict[str, str] = {
    "sleep": "hydration_barrier",
    "uv": "pigmentation",
    "lifestyle": "acne",
    "activity": "elasticity",
}

# 섹션별 필수 설문 값 추출 설정: (survey_key, format) 리스트. format=None이면 str(value)
# goals는 outcomes 기반으로 별도 처리
SECTION_SURVEY_EXTRACT: Dict[str, List[Tuple[str, Optional[str]]]] = {
    "sleep": [("sleep_hours_weekday", "{0}시간"), ("sleep_quality_score", "{0}/10점")],
    "uv": [("uv_exposure_10to16", None), ("sunscreen_frequency", None)],
    "lifestyle": [("stress_score", "{0}/10점"), ("drinking_days_per_week", "{0}일"), ("smoking_status", None)],
    "smoking": [("smoking_status", None)],
    "drinking": [("drinking_days_per_week", "{0}일")],
    "stress": [("stress_score", "{0}/10점")],
    "activity": [("aerobic_weekly", "{0}회"), ("resistance_weekly", "{0}회")],
}

# 섹션별 강제 삽입 시 괄호 안 문구 (설문 값 없을 때)
SECTION_INJECT_SUFFIX: Dict[str, str] = {
    "sleep": " (현재 평일 수면 {0})",
    "uv": " (선크림 사용: {0})",
    "lifestyle": " (스트레스/음주/흡연: {0})",
    "smoking": " (흡연: {0})",
    "drinking": " (음주: {0})",
    "stress": " (스트레스: {0})",
    "activity": " (운동 빈도: {0})",
    "goals": " (피부 고민: {0})",
}

# 표준 timeframe (일 단위)
STANDARD_TIMEFRAMES: Dict[str, float] = {
    "4w": 28.0,
    "12w": 84.0,
    "6m": 182.5,
}


# ──────────────────────────── 카드 생성 키워드 ────────────────────────────

SECTION_CARD_TYPE_KEYWORDS: Dict[str, Dict[str, List[str]]] = {
    "sleep": {
        "problem": ["수면", "불면", "부족", "짧은", "나쁜", "질 낮은", "피로", "졸음", "수면 시간"],
        "cause": ["스트레스", "불규칙", "야근", "수면 환경", "카페인", "알코올", "수면 습관"],
        "action": ["규칙", "수면 시간", "침실 환경", "카페인 제한", "운동", "명상", "수면 위생"],
    },
    "uv": {
        "problem": ["자외선", "UV", "햇빛", "일광", "화상", "색소", "기미", "주근깨", "멜라닌"],
        "cause": ["선크림", "보호", "노출", "야외 활동", "자외선 차단", "UV-A", "UV-B"],
        "action": ["선크림", "자외선 차단", "모자", "긴팔", "그늘", "자외선 지수", "보호"],
    },
    "lifestyle": {
        "problem": ["흡연", "음주", "스트레스", "불규칙", "나쁜 습관", "건강", "피부"],
        "cause": ["담배", "니코틴", "알코올", "압박", "불안", "우울", "생활 패턴"],
        "action": ["금연", "절주", "스트레스 관리", "명상", "운동", "휴식", "건강한 생활"],
    },
    "activity": {
        "problem": ["운동 부족", "활동량", "신체 활동", "근력", "유연성", "체력"],
        "cause": ["좌식", "운동 시간", "일상 활동", "신체 활동 부족"],
        "action": ["유산소", "근력 운동", "스트레칭", "걷기", "달리기", "요가", "운동 계획"],
    },
    "goals": {
        "problem": ["주름", "탄력", "색소", "수분", "장벽", "여드름", "홍조", "노화"],
        "cause": ["나이", "자외선", "건조", "염증", "콜라겐", "엘라스틴", "수분 손실"],
        "action": ["보습", "자외선 차단", "안티에이징", "영양", "관리", "스킨케어", "성분"],
    },
}

# 섹션별 제목
SECTION_TITLES: Dict[str, str] = {
    "goals": "주요 목표 분석 및 개선 방안",
    "sleep": "수면 및 리듬",
    "uv": "자외선 및 노화 관리",
    "lifestyle": "생활습관 관리",
    "activity": "활동 및 대사",
}

# 섹션별 주제 범위 (해당 탭 밖의 내용 금지)
SECTION_TOPIC_SCOPE: Dict[str, Dict[str, str]] = {
    "sleep": {
        "scope": "수면·취침·수면질·수면시간에만 집중",
        "forbidden": "자외선, 선크림, 운동 종류, 흡연, 음주, 스트레스 관리 등 다른 탭 주제 언급 금지",
        "action_scope": "수면 습관만: 취침 시간, 침실 환경, 카페인 제한, 수면 전 휴식 등",
    },
    "uv": {
        "scope": "자외선·선크림·햇빛 노출에만 집중",
        "forbidden": "수면, 운동, 흡연, 음주, 스트레스 등 다른 탭 주제 언급 금지",
        "action_scope": "자외선 차단만: 선크림, 모자, 긴팔, 그늘, 야외 시간 등",
    },
    "smoking": {
        "scope": "흡연에만 집중",
        "forbidden": "수면, 운동, 선크림, 음주, 스트레스 등 다른 탭 주제 언급 금지",
        "action_scope": "흡연 관련만: 금연, 흡연 줄이기, 금단 대처 등",
    },
    "drinking": {
        "scope": "음주에만 집중",
        "forbidden": "수면, 운동, 선크림, 흡연, 스트레스 등 다른 탭 주제 언급 금지",
        "action_scope": "음주 관련만: 절주, 음주 빈도·량 조절, 물 섭취 등",
    },
    "stress": {
        "scope": "스트레스 관리에만 집중",
        "forbidden": "수면, 운동, 선크림, 흡연, 음주 등 다른 탭 주제 언급 금지",
        "action_scope": "스트레스 관리만: 호흡법, 명상, 휴식, 취미 등",
    },
    "activity": {
        "scope": "운동·신체 활동·유산소·근력에만 집중",
        "forbidden": "선크림, 자외선, 수면 습관, 흡연, 음주, 스트레스 등 다른 탭 주제 언급 금지",
        "action_scope": "운동만: 유산소, 근력, 걷기, 스트레칭, 주당 횟수, 일 30분 등. 선크림 바르라는 조언 절대 금지.",
    },
}

# 카드 생성 시스템 프롬프트 (공통)
CARD_SYSTEM_PROMPT = """당신은 피부과 전문의입니다. 사용자의 설문 데이터, 정량 근거, 구조화된 주장(claims)을 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.

⚠️ 중요: 설명 문장 없이 JSON만 출력하세요. 다른 텍스트는 절대 포함하지 마세요.

반드시 아래 JSON 구조를 따르세요:
{
  "cards": [
    {"type": "problem", "title": "현재 상태", "text": "정확히 2-3문장만"},
    {"type": "cause", "title": "왜 이런 상태인가", "text": "정확히 2-3문장만"},
    {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
      {"title": "할 일 제목(~하기·짧은 명사구)", "detail": "언제·왜·어떻게 1문장(평서·설명)"},
      {"title": "할 일 제목(~하기·짧은 명사구)", "detail": "언제·왜·어떻게 1문장(평서·설명)"},
      {"title": "할 일 제목(~하기·짧은 명사구)", "detail": "언제·왜·어떻게 1문장(평서·설명)"}
    ]},
    {"type": "simulation", "title": "12주 후 예상 경로", "text": "정확히 2-4문장만", "meta": {
      "mode": "grounded" 또는 "estimated",
      "disclaimer_small": "estimated일 때만 필수"
    }}
  ]
}

규칙:
- 논리적·유기적 연결: [현재 상태]→[왜 이런 상태인가]→[행동 3가지]가 하나의 흐름으로 이어져야 함. 사용자 설문 수치·추가 입력(참고 상황)·논문 근거를 세 카드 모두에 골고루 반영하고, 각 섹션이 서로를 인용·반영하세요.
- problem/cause/simulation: 현재 섹션 주제(키워드) 밖의 내용을 절대 넣지 마세요. 해당 탭만 다룹니다.
- problem/cause: 각 2-3문장까지만 (더 길면 잘라서 3문장)
- simulation: 4문장 초과 금지. 정량적 효과(%, 기간)는 simulation에만 넣고, action에는 넣지 마세요. 효과가 여러 가지면 모두 나열 가능.
- action items: 정확히 3개. **실생활에서 매일 체크할 수 있는 일일 단위 할 일**만. **title**은 오늘의 할 일 목록 제목처럼 짧게: **「~하기」** 또는 짧은 명사구(예: `선크림 바르기`, `외출 20분 전 SPF 도포`, `취침 1시간 전 스크린 끄기`). **~하세요/하십시오/해 보세요** 같은 명령·권유 문장을 title에 쓰지 마세요. **detail**은 1문장(한 줄): 언제·왜·어떻게를 평서·설명으로(「~하면 도움」 허용). 현재 섹션 주제와 직접 관련된 행동만. (예: 활동 탭이면 운동·걷기·스트레칭만. 선크림·수면·음주 등 다른 탭 주제 절대 금지) 설문에 피부 타입·피부 고민이 있으면 맥락을 구체적으로 녹이세요.
- 전문용어는 1회만 (괄호로 쉬운 설명)
- 한국어만 사용
- 카드 본문에 **, *, # 같은 마크다운 문법을 절대 사용하지 마세요. 일반 텍스트만 사용하세요.
- PMC, PMID, p=, CI 같은 논문 정보는 본문에 절대 포함하지 마세요.
- meta 필드는 서버에서 자동으로 생성합니다. LLM이 meta를 만들 필요 없습니다(simulation의 meta만 위 JSON 구조 그대로 생성하세요)."""

# 생활습관 섹션 통합 시스템 프롬프트 (1회 LLM 호출로 smoking/drinking/stress 전부 생성)
LIFESTYLE_COMBINED_SYSTEM_PROMPT = """당신은 피부과 전문의입니다. 사용자의 생활습관(흡연/음주/스트레스) 설문 데이터와 근거를 바탕으로,
요청된 **섹션별** 카드를 JSON 형식으로 한 번에 생성하세요.

⚠️ 중요: 설명 문장 없이 JSON만 출력하세요. 다른 텍스트는 절대 포함하지 마세요.

반드시 아래 JSON 구조를 따르세요:
{
  "subsections": {
    "<subsection_key>": {
      "cards": [
        {"type": "problem", "title": "현재 상태", "text": "정확히 2-3문장만"},
        {"type": "cause", "title": "왜 이런 상태인가", "text": "정확히 2-3문장만"},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
          {"title": "할 일 제목(~하기)", "detail": "설명 1문장(평서)"},
          {"title": "할 일 제목(~하기)", "detail": "설명 1문장(평서)"},
          {"title": "할 일 제목(~하기)", "detail": "설명 1문장(평서)"}
        ]},
        {"type": "simulation", "title": "12주 후 예상 경로", "text": "정확히 2-4문장만", "meta": {
          "mode": "estimated",
          "disclaimer_small": "이 수치는 논문 전반을 바탕으로 한 AI 추정치입니다."
        }}
      ]
    }
  }
}

규칙:
- 논리적·유기적 연결: [현재 상태]→[왜 이런 상태인가]→[행동 3가지]가 하나의 흐름으로 이어져야 함. 사용자 설문 수치·추가 입력(참고 상황)·논문 근거를 세 카드 모두에 골고루 반영하고, 각 섹션이 서로를 인용·반영하세요.
- **섹션 키는 요청에 명시된 것만** 생성하세요 (예: smoking, drinking, stress 중 해당하는 것만).
- 각 섹션은 독립적인 4개 카드(problem/cause/action/simulation)를 가져야 합니다.
- problem/cause: 각 2-3문장까지만
- simulation: 4문장 초과 금지
- action items: 정확히 3개. **매일 체크하는 할 일** 수준. **title**은 「~하기」·짧은 명사구(할 일 제목). title에 **하세요/해 보세요** 금지. **detail**은 1문장 평서·설명. 해당 섹션(흡연/음주/스트레스)과 직접 관련된 행동만. 다른 섹션 주제 금지. [피부 맥락]이 있으면 최소 1개에 피부 타입·고민을 반영하세요.
- 각 섹션의 카드는 해당 주제(흡연/음주/스트레스)에 **구체적으로 집중**하세요. 다른 주제를 혼합하지 마세요.
- action 카드에는 정량적 효과(%, 기간)를 넣지 마세요. 정량적 효과는 simulation 카드에만 넣고, 여러 가지가 있으면 모두 나열하세요.
- "당신의", "당신은" 같은 2인칭을 반드시 사용하세요.
- 전문용어는 1회만 (괄호로 쉬운 설명)
- 한국어만 사용
- 카드 본문에 **, *, # 같은 마크다운 문법을 절대 사용하지 마세요. 일반 텍스트만 사용하세요.
- PMC, PMID, p=, CI 같은 논문 정보는 본문에 절대 포함하지 마세요.
- meta 필드는 서버에서 자동 생성합니다. simulation의 meta만 위 구조대로 생성하세요."""
