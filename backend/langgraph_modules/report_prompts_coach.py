"""
코치형 헬스 리포트 프롬프트 템플릿
4단 구조: 문제 진단 → 원인 설명 → 행동 제시 → 정량 효과
의사가 환자에게 조용히 설명하는 톤
"""

def build_coach_prompt(
    section: str,
    survey: dict,
    evidence_summary: str,
    quant_summary_text: str,
    outcomes_text: str
) -> str:
    """
    코치형 헬스 리포트 프롬프트 생성
    
    Args:
        section: 섹션 이름 (goals, sleep, uv, lifestyle, activity)
        survey: 설문 데이터
        evidence_summary: 논문 근거 요약
        quant_summary_text: 정량 근거 한국어 요약
        outcomes_text: 사용자 피부 고민 텍스트
    
    Returns:
        프롬프트 문자열
    """
    
    # 설문 데이터 추출 (None 처리)
    def get_survey_value(key, default="N/A"):
        value = survey.get(key)
        if value is None:
            return default
        return value
    
    # 섹션별 설문 데이터 수집
    survey_context = {
        "sleep": {
            "hours_weekday": get_survey_value("sleep_hours_weekday"),
            "quality_score": get_survey_value("sleep_quality_score"),
            "weekend_catchup": get_survey_value("sleep_weekend_catchup", False)
        },
        "uv": {
            "exposure_10to16": get_survey_value("uv_exposure_10to16"),
            "sunscreen_freq": get_survey_value("sunscreen_frequency")
        },
        "lifestyle": {
            "smoking": get_survey_value("smoking_status"),
            "drinking_days": get_survey_value("drinking_days_per_week"),
            "stress_score": get_survey_value("stress_score")
        },
        "activity": {
            "aerobic": get_survey_value("aerobic_weekly"),
            "resistance": get_survey_value("resistance_weekly")
        }
    }
    
    # 공통 프롬프트 템플릿
    prompt = f"""당신은 피부과 전문의입니다.
환자(사용자)의 설문 데이터를 보고, "의사가 환자에게 자연스럽게 설명하는" 톤으로 작성하세요.
설문 데이터를 곧이곧대로 나열하지 말고, 의사가 요약한 것처럼 자연스럽게 표현하세요.

아래 형식을 절대 벗어나지 마세요.

==================================================
[출력 형식 — 반드시 이 4단 구조만 사용]

⚠️ 전체 길이 제한:
- 한 섹션당 전체 문장은 12~18문장 이내로 제한합니다.
- 같은 말을 반복하거나 문단을 늘려 길게 쓰는 행위는 금지입니다.
- 각 항목은 3~5문장 이내로 작성하세요.

--------------------------------------------------

(1) 당신의 문제는 이것입니다
- ⚠️ 사용자 설문 수치를 반드시 반영하되, "의사가 환자에게 자연스럽게 설명하는" 톤으로 작성
- ⚠️ "당신은", "당신의" 같은 2인칭을 반드시 사용할 것
- ⚠️ 설문 데이터를 곧이곧대로 나열하지 말고, 의사가 요약한 것처럼 자연스럽게 표현
- ⚠️ 일반론적 표현("수면이 부족하면", "자외선에 노출되면") 금지

예시 (올바른 예 - 자연스러운 요약):
  "당신의 수면 패턴을 보면, 평일 평균 5.5시간 정도로 부족한 편입니다.
   수면의 질도 4점대 수준이라 피부 회복에 필요한 시간이 확보되지 않고 있습니다."

예시 (잘못된 예 - 직설적):
  "당신의 평일 평균 수면은 5.5시간이며, 수면의 질 점수는 4/10점입니다." (X - 너무 직설적)

예시 (잘못된 예 - 일반론):
  "수면이 부족하면 피부 회복에 문제가 생깁니다." (X)
  "평균적으로 7시간 이상 수면이 필요합니다." (X)

- 일반론 금지
- 은유 남발 금지 (1회 이내만 허용)
- 단정적 진단 톤 사용
- 길게 설명하지 말고 상태만 정확히 규정할 것
- 설문 데이터는 정확히 반영하되, 표현은 "의사가 요약한 것처럼" 자연스럽게

--------------------------------------------------

(2) 왜 이런 상태가 되었는지
- ⚠️ 설문 값 3개 이상을 반영하되, "의사가 인과관계를 자연스럽게 설명하는" 톤으로 작성
- ⚠️ "당신은", "당신의" 같은 2인칭을 반드시 사용할 것
- ⚠️ 설문 데이터를 나열식으로 나열하지 말고, 의사가 요약한 것처럼 자연스럽게 연결
- ⚠️ 아래 인과 사슬 형태를 반드시 따를 것 (사용자 데이터 포함, 하지만 자연스럽게):

  "당신의 {설문 패턴 요약} 때문에
   → 그래서 {피부 변화}가 되었고
   → 그 결과 지금 상태가 되었습니다."

예시 (올바른 예 - 자연스러운 요약):
  "당신의 수면 패턴을 보면, 평일 5.5시간 정도로 부족하고 수면의 질도 낮은 편입니다.
   이 때문에 피부가 충분히 회복되지 못하고,
   그 결과 수분을 붙잡아 두는 능력이 약해진 상태입니다."

예시 (잘못된 예 - 직설적 나열):
  "당신은 평일 5.5시간만 자고, 수면의 질이 4/10점이기 때문에..." (X - 너무 직설적)

예시 (잘못된 예 - 일반론):
  "수면 부족은 피부 회복을 방해합니다." (X)
  "연구에 따르면 수면이 중요합니다." (X)

- 논문 일반론 금지
- 피부 상식 나열 금지
- 사용자 데이터 없이 설명하는 것 절대 금지
- 설문 데이터는 정확히 반영하되, 표현은 "의사가 요약한 것처럼" 자연스럽게

- 전문용어 사용 규칙:
  * 전문용어는 사용 가능
  * 단, 처음 등장 시 반드시 괄호로 쉬운 말 풀이를 붙일 것

  예:
  "콜라겐(피부를 지탱하는 섬유)이 빠르게 줄어들면서…"
  "코르티솔(스트레스 호르몬)이 높아진 상태가 지속되면…"

--------------------------------------------------

(3) 그래서 당신에게 필요한 행동 3가지
- ⚠️ 각 Action은 사용자 설문 값을 반영하되, "의사가 조언하는" 톤으로 자연스럽게 작성
- ⚠️ "당신은", "당신의" 같은 2인칭을 반드시 사용할 것
- ⚠️ 설문 데이터를 괄호로 나열하지 말고, 자연스럽게 문장에 녹여서 표현
- Action 1: 오늘부터 당장 가능한 것 (사용자 현재 상태 기반)
- Action 2: 1주일 유지하면 되는 것 (사용자 현재 상태 기반)
- Action 3: 4주 유지하면 되는 것 (사용자 현재 상태 기반)

- 각 Action은 반드시:
  "왜 이게 당신에게 필요한지" 1문장으로 설명
  설문 데이터는 자연스럽게 문장에 포함 (괄호 나열 금지)

예시 (올바른 예 - 자연스러운 요약):
  Action 1: "수면 시간을 조금만 늘려 6.5시간 정도로 맞추세요.
            현재 부족한 수면 시간을 보완하면 피부 회복 시간이 확보됩니다."

예시 (잘못된 예 - 직설적):
  Action 1: "당신의 현재 수면 시간(5.5시간)을 6.5시간으로 늘리세요." (X - 괄호 나열)

예시 (잘못된 예 - 일반론):
  Action 1: "수면 시간을 늘리세요." (X)

- 강요 톤 금지
- 실현 불가능한 행동 금지
- 사용자 설문 값과 직접 연결된 행동만 제시
- 일반론적 조언 절대 금지
- 설문 데이터는 정확히 반영하되, 표현은 "의사가 조언하는 것처럼" 자연스럽게

--------------------------------------------------

(4) 지금 바꾸면 이렇게 달라질 수 있습니다

⚠️ 정량 수치 생성 규칙 (최중요)

A) quant_evidence(정량 근거)가 존재하는 경우
- 반드시 그 수치만 그대로 사용하세요.
- 새로운 숫자 생성 금지
- 반올림 금지
- 부호 변경 금지

- 반드시 아래 형식으로 작성하세요 (2~4문장 이내):

  "비슷한 조건의 사람들을 추적한 연구들에서는,
   이 습관을 {{timeframe}} 유지했을 때
   {{outcome_label}}이 평균 {{mean}}% 정도 변화하는 경향이 관찰되었습니다
   (범위: {{min}}% ~ {{max}}%)."

--------------------------------------------------

B) quant_evidence(정량 근거)가 존재하지 않는 경우
- 아래 문구 구조를 반드시 따르세요.
- 숫자는 '폭(range)' 표현만 허용합니다.
- 소수점 사용 금지
- 지나치게 정밀한 수치 금지

반드시 아래 형식을 그대로 사용하세요 (3~4문장 이내):

"이 항목에 대해서는 아직 신뢰할 만한 연구 기반 정량 수치는 충분하지 않습니다.
다만 유사한 조건에서 생활습관을 개선했을 때,
12주 후 약 5~12% 정도의 개선이 흔히 관찰되는 것으로 알려져 있습니다.
이 수치는 연구 데이터가 아니라
다양한 사례 및 전문가 경험을 바탕으로 한 일반적 추정치입니다.
개인에 따라 차이가 매우 클 수 있습니다."

--------------------------------------------------

[추가 금지 규칙 — 반드시 지킬 것]

- 논문 요약체 금지
- 피부 상식 칼럼체 금지
- 같은 의미의 문장 반복 금지
- "중간 정도", "꽤", "상당히" 같은 모호한 표현 금지

- 전문용어 관련:
  * 사용 자체는 허용
  * 단, 반드시 즉시 쉬운 말로 풀어서 설명할 것
  * 의미 설명 없이 던지는 전문용어 사용 금지

- 숫자 관련:
  * 숫자는 (4)에서만 사용
  * 추정 수치를 확정형으로 쓰는 것 금지
  * 추정 수치를 연구 기반인 것처럼 쓰는 것 금지

==================================================

[최종 목표 톤]

- "의사가 내 데이터를 보고 조용히 설명해 주는 느낌"
- 과장 금지
- 공포 마케팅 금지
- 사용자 비난 금지
- 하지만 회피하지 말고 단정적으로 말할 것

==================================================

[사용자 설문 데이터]

{_build_survey_context(section, survey, survey_context)}

[논문 근거 - 메커니즘/인과관계 설명용]
{evidence_summary}

[정량 근거 - 수치 생성용 (반드시 이 데이터만 사용, 새로 만들지 말 것)]
{quant_summary_text}

[사용자 피부 고민]
{outcomes_text}

{_build_section_specific_guidance(section, survey_context)}

위 형식을 절대 벗어나지 말고, 한국어로만 작성하세요. 마크다운 문법은 사용하지 마세요."""

    return prompt


def _build_survey_context(section: str, survey: dict, survey_context: dict) -> str:
    """섹션별 설문 데이터 컨텍스트 생성"""
    if section == "sleep":
        ctx = survey_context["sleep"]
        return f"""수면 시간 (평일): {ctx['hours_weekday']}시간
수면의 질 점수: {ctx['quality_score']}/10점
주말 몰아잠: {ctx['weekend_catchup']}"""
    
    elif section == "uv":
        ctx = survey_context["uv"]
        return f"""자외선 노출 (10-16시): {ctx['exposure_10to16']}
선크림 사용 빈도: {ctx['sunscreen_freq']}"""
    
    elif section == "lifestyle":
        ctx = survey_context["lifestyle"]
        return f"""흡연 상태: {ctx['smoking']}
주당 음주 일수: {ctx['drinking_days']}일
스트레스 점수: {ctx['stress_score']}/10점"""
    
    elif section == "activity":
        ctx = survey_context["activity"]
        return f"""유산소 운동: {ctx['aerobic']}회/주
근력 운동: {ctx['resistance']}회/주"""
    
    else:  # goals
        outcomes = survey.get("outcomes", [])
        return f"""사용자 피부 고민: {', '.join(outcomes)}"""


def _build_section_specific_guidance(section: str, survey_context: dict) -> str:
    """섹션별 특화 가이드"""
    if section == "goals":
        return """[섹션별 특화 가이드]
- 사용자 outcomes 각각을 독립적인 "문제 단락"으로 처리하세요.
- quant_evidence가 가장 많은 outcome 2개만 상세히 작성하세요.
- 나머지는 문제 요약 + 행동만 작성하세요."""
    
    elif section == "sleep":
        ctx = survey_context["sleep"]
        return f"""[섹션별 특화 가이드]
- 반드시 수면 시간({ctx['hours_weekday']}시간)과 수면의 질({ctx['quality_score']}/10점)을 직접 인용하세요.
- "회복 모드로 못 내려가는 상태"라는 은유는 1회만 허용합니다."""
    
    elif section == "uv":
        ctx = survey_context["uv"]
        return f"""[섹션별 특화 가이드]
- 반드시 자외선 노출({ctx['exposure_10to16']})과 선크림 빈도({ctx['sunscreen_freq']})를 직접 인용하세요.
- "보이지 않는 주름 생성기"라는 은유는 1회만 허용합니다."""
    
    elif section == "lifestyle":
        ctx = survey_context["lifestyle"]
        return f"""[섹션별 특화 가이드]
- 흡연({ctx['smoking']}) / 음주({ctx['drinking_days']}일/주) / 스트레스({ctx['stress_score']}/10점) 중 가장 영향 큰 요인 1개만 집어서 집중 공격하세요.
- "이건 나쁜 소식이 아니라 좋은 소식입니다. 지금 당장 교정 가능한 변수입니다." 문장을 1회 포함하세요."""
    
    elif section == "activity":
        ctx = survey_context["activity"]
        return f"""[섹션별 특화 가이드]
- 반드시 운동 패턴(유산소 {ctx['aerobic']}회/주, 근력 {ctx['resistance']}회/주)을 직접 인용하세요.
- 운동을 보호 요인으로 강조하세요.
- "지금 피부의 몇 안 되는 방어막입니다" 표현은 1회만 허용합니다."""
    
    else:
        return ""
