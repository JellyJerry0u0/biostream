"""
리포트 생성 상수 및 매핑 정의
- ReportState (TypedDict)
- 목표/섹션/outcome 관련 상수
- 카드 생성용 키워드 사전
"""

from typing import Dict, Any, List, Optional, TypedDict
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
    reliability_scores: Optional[Dict[str, Any]]  # RAGAS 신뢰도 평가 결과


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
    "hydration_barrier": "increase_is_improvement",
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
SECTION_OUTCOME_CANDIDATES: Dict[str, List[str]] = {
    "sleep": ["hydration_barrier", "wrinkle", "elasticity", "redness"],
    "uv": ["pigmentation", "wrinkle", "elasticity", "redness"],
    "lifestyle": ["acne", "redness", "hydration_barrier", "pigmentation"],
    "activity": ["elasticity", "wrinkle", "general_skin"],
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

# 카드 생성 시스템 프롬프트 (공통)
CARD_SYSTEM_PROMPT = """당신은 피부과 전문의입니다. 사용자의 설문 데이터, 정량 근거, 구조화된 주장(claims)을 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.

⚠️ 중요: 설명 문장 없이 JSON만 출력하세요. 다른 텍스트는 절대 포함하지 마세요.

반드시 아래 JSON 구조를 따르세요:
{
  "cards": [
    {"type": "problem", "title": "현재 상태", "text": "정확히 2-3문장만"},
    {"type": "cause", "title": "왜 이런 상태인가", "text": "정확히 2-3문장만"},
    {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
      {"title": "Action 1 (1문장)", "detail": "1문장 설명"},
      {"title": "Action 2 (1문장)", "detail": "1문장 설명"},
      {"title": "Action 3 (1문장)", "detail": "1문장 설명"}
    ]},
    {"type": "simulation", "title": "12주 후 예상 경로", "text": "정확히 2-4문장만", "meta": {
      "mode": "grounded" 또는 "estimated",
      "disclaimer_small": "estimated일 때만 필수"
    }}
  ]
}

규칙:
- problem/cause: 각 2-3문장까지만 (더 길면 잘라서 3문장)
- simulation: 4문장 초과 금지
- action items: 정확히 3개, title/detail 각 1문장
- 전문용어는 1회만 (괄호로 쉬운 설명)
- 한국어만 사용
- PMC, PMID, p=, CI 같은 논문 정보는 본문에 절대 포함하지 마세요.
- meta 필드는 서버에서 자동으로 생성합니다. LLM이 meta를 만들 필요 없습니다(simulation의 meta만 위 JSON 구조 그대로 생성하세요)."""

# 생활습관 서브섹션 통합 시스템 프롬프트 (1회 LLM 호출로 smoking/drinking/stress 전부 생성)
LIFESTYLE_COMBINED_SYSTEM_PROMPT = """당신은 피부과 전문의입니다. 사용자의 생활습관(흡연/음주/스트레스) 설문 데이터와 근거를 바탕으로,
요청된 **서브섹션별** 카드를 JSON 형식으로 한 번에 생성하세요.

⚠️ 중요: 설명 문장 없이 JSON만 출력하세요. 다른 텍스트는 절대 포함하지 마세요.

반드시 아래 JSON 구조를 따르세요:
{
  "subsections": {
    "<subsection_key>": {
      "cards": [
        {"type": "problem", "title": "현재 상태", "text": "정확히 2-3문장만"},
        {"type": "cause", "title": "왜 이런 상태인가", "text": "정확히 2-3문장만"},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
          {"title": "행동 제목 (1문장)", "detail": "1문장 설명"},
          {"title": "행동 제목 (1문장)", "detail": "1문장 설명"},
          {"title": "행동 제목 (1문장)", "detail": "1문장 설명"}
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
- **서브섹션 키는 요청에 명시된 것만** 생성하세요 (예: smoking, drinking, stress 중 해당하는 것만).
- 각 서브섹션은 독립적인 4개 카드(problem/cause/action/simulation)를 가져야 합니다.
- problem/cause: 각 2-3문장까지만
- simulation: 4문장 초과 금지
- action items: 정확히 3개, title/detail 각 1문장
- 각 서브섹션의 카드는 해당 생활습관 요인(흡연/음주/스트레스)에 **구체적으로 집중**하세요. 다른 요인을 혼합하지 마세요.
- "당신의", "당신은" 같은 2인칭을 반드시 사용하세요.
- 전문용어는 1회만 (괄호로 쉬운 설명)
- 한국어만 사용
- PMC, PMID, p=, CI 같은 논문 정보는 본문에 절대 포함하지 마세요.
- meta 필드는 서버에서 자동 생성합니다. simulation의 meta만 위 구조대로 생성하세요."""
