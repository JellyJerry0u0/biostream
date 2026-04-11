"""
요약 탭 데이터 생성 모듈
- goals(주요 목표) 플로팅 표시용
- 피부 타입 및 특성
- 5각형 라이프스타일 점수 (수면, 음주·흡연, 스트레스, 활동, 자외선) 0~100
- 참고할 상황 기반 솔루션 (LLM)
"""

from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any, Optional
from .report_constants import OUTCOME_LABELS


# 피부 타입별 라벨 및 특성 (한국어)
SKIN_TYPE_LABELS: Dict[str, str] = {
    "dry": "건성",
    "oily": "지성",
    "combination": "복합성",
    "sensitive": "민감성",
}

SKIN_TYPE_CHARACTERISTICS: Dict[str, str] = {
    "dry": "보습이 부족하고 각질이 잘 생기는 편입니다. 촉촉한 보습 관리가 중요합니다.",
    "oily": "피지 분비가 많고 확대된 모공이 있을 수 있습니다. 과도한 세안은 피하고 수분 밸런스를 맞추세요.",
    "combination": "T존은 지성, U존은 건성인 혼합형입니다. 부위별 맞춤 관리가 도움이 됩니다.",
    "sensitive": "자극에 쉽게 반응하고 홍조가 생기기 쉽습니다. 저자극 제품 선택이 중요합니다.",
}


def _norm_outcome(o: str) -> str:
    """UI outcomes(wrinkle vs wrinkles 등) 정규화"""
    m = {
        "wrinkles": "wrinkle",
        "overall_aging": "general_aging",
        "skin_barrier": "hydration_barrier",
    }
    return m.get(o, o)


def compute_pentagon_scores(survey: dict) -> Dict[str, int]:
    """
    Lifestyle 설문 값 기반 5각형 그래프 점수 계산 (0~100, 높을수록 좋음).

    기준:
    - sleep: 수면시간(평일) + 수면질
      - 7~8h=90, 6~7h=75, 8~9h=85, 5~6h=55, <5 or >10=35
      - 수면질 1~10점 → *10
      - (시간점수 + 수면질*10) / 2
    - alcohol: 음주일수 (0일=100, 1일=85, 2-3일=65, 4-5일=40, 6-7일=20)
    - smoking: 흡연상태 (never=100, former=65, current=25)
      → 렌더링 시 (alcohol + smoking) / 2 로 합쳐서 '음주·흡연' 축 표시
    - stress: 스트레스 1~10 (낮을수록 좋음)
      - 1-2=95, 3-4=80, 5-6=55, 7-8=35, 9-10=15
    - activity: 유산소 + 근력
      - 유산소 5+=100, 3-4=85, 1-2=60, 0=25
      - 근력 3+=95, 2=75, 1=55, 0=30
      - 평균
    - uv: 자외선 노출 + 선크림
      - 선크림 daily_with_reapply=95, most_days=75, sometimes=45, never=20
      - 노출 <30m=80, 30~60=60, 1~2h=40, >2h=25
      - (선크림 + (100-노출보정)) / 2, 노출보정=노출이 나쁘면 점수 낮춤
    """
    def clamp(v: float) -> int:
        return max(0, min(100, int(round(v))))

    scores: Dict[str, int] = {
        "sleep": 50,
        "alcohol": 50,
        "smoking": 50,
        "stress": 50,
        "activity": 50,
        "uv": 50,
    }

    # Sleep (평일 없으면 주말 평균으로 보강 — 설문만 저장된 경우 누락 방지)
    hours = survey.get("sleep_hours_weekday")
    if hours is None and survey.get("sleep_hours_weekend") is not None:
        hours = survey.get("sleep_hours_weekend")
    quality = survey.get("sleep_quality_score")
    if hours is not None:
        try:
            h = float(hours)
            if 7 <= h <= 8:
                h_score = 90
            elif 6 <= h < 7 or 8 < h <= 9:
                h_score = 75 if h < 7 else 85
            elif 5 <= h < 6 or 9 < h <= 10:
                h_score = 55
            else:
                h_score = 35
        except (TypeError, ValueError):
            h_score = 50
    else:
        h_score = 50

    if quality is not None:
        try:
            q = float(quality)
            q_score = clamp(q * 10)
        except (TypeError, ValueError):
            q_score = 50
    else:
        q_score = 50

    scores["sleep"] = clamp((h_score + q_score) / 2)

    # Alcohol & Smoking (점수는 따로 계산, 렌더링 시 합침)
    drinking = survey.get("drinking_days_per_week")
    smoking = survey.get("smoking_status")
    drink_map = {"0": 100, "1": 85, "2-3": 65, "4-5": 40, "6-7": 20}
    smoke_map = {"never": 100, "former": 65, "current": 25}
    scores["alcohol"] = clamp(drink_map.get(str(drinking).strip() if drinking else "0", 50))
    scores["smoking"] = clamp(smoke_map.get(str(smoking).strip().lower() if smoking else "never", 50))

    # Stress (1-10, lower is better)
    stress_val = survey.get("stress_score")
    if stress_val is not None:
        try:
            sv = float(stress_val)
            if sv <= 2:
                scores["stress"] = 95
            elif sv <= 4:
                scores["stress"] = 80
            elif sv <= 6:
                scores["stress"] = 55
            elif sv <= 8:
                scores["stress"] = 35
            else:
                scores["stress"] = 15
        except (TypeError, ValueError):
            pass

    # Activity
    aerobic = survey.get("aerobic_weekly")
    resistance = survey.get("resistance_weekly")
    aero_map = {"0": 25, "1-2": 60, "3-4": 85, "5+": 100}
    res_map = {"0": 30, "1": 55, "2": 75, "3+": 95}
    a_score = aero_map.get(str(aerobic).strip() if aerobic else "0", 50)
    r_score = res_map.get(str(resistance).strip() if resistance else "0", 50)
    scores["activity"] = clamp((a_score + r_score) / 2)

    # UV (노출 적을수록 높은 값, 선크림 좋을수록 높은 값 → 둘 평균)
    sunscreen = survey.get("sunscreen_frequency")
    uv_exposure = survey.get("uv_exposure_10to16")
    sun_map = {
        "daily_with_reapply": 95,
        "most_days": 75,
        "sometimes": 45,
        "never": 20,
        "6-7": 95,
        "4-5": 78,
        "2-3": 55,
        "1": 40,
        "0": 20,
    }
    # 노출 적을수록 높음: <30m=80, 30~60=60, 1~2h=40, >2h=25
    exposure_map = {"<30m": 80, "30~60": 60, "1~2h": 40, ">2h": 25}
    sun_score = sun_map.get(str(sunscreen).strip().lower() if sunscreen else "never", 50)
    exposure_score = exposure_map.get(str(uv_exposure).strip() if uv_exposure else "<30m", 80)
    uv_score = (sun_score + exposure_score) / 2 if uv_exposure else sun_score
    scores["uv"] = clamp(uv_score)

    return scores


def _format_survey_brief(survey: dict) -> str:
    """설문 요약 (피부 목표 솔루션용)"""
    parts = []
    if survey.get("sleep_hours_weekday") is not None:
        parts.append(f"수면 평일 {survey['sleep_hours_weekday']}h")
    if survey.get("sleep_quality_score") is not None:
        parts.append(f"수면질 {survey['sleep_quality_score']}/10")
    if survey.get("uv_exposure_10to16"):
        parts.append(f"자외선노출 {survey['uv_exposure_10to16']}")
    if survey.get("sunscreen_frequency"):
        parts.append(f"선크림 {survey['sunscreen_frequency']}")
    if survey.get("drinking_days_per_week"):
        parts.append(f"음주 {survey['drinking_days_per_week']}일/주")
    if survey.get("smoking_status"):
        parts.append(f"흡연 {survey['smoking_status']}")
    if survey.get("stress_score") is not None:
        parts.append(f"스트레스 {survey['stress_score']}/10")
    if survey.get("aerobic_weekly"):
        parts.append(f"유산소 {survey['aerobic_weekly']}회/주")
    if survey.get("resistance_weekly"):
        parts.append(f"근력 {survey['resistance_weekly']}회/주")
    return ", ".join(parts) if parts else "설문 요약 없음"


def build_summary_data(
    survey: dict,
    situation_text: Optional[str],
    report_sections_text: str,
) -> Dict[str, Any]:
    """
    요약 탭용 데이터 생성.
    (다른 리포트 탭 카드 생성 완료 후 호출됨 - report_sections_text 사용)
    survey: DB Lifestyle 설문 dict(get_survey)와 동일.
    - goals: 주요 목표 라벨 리스트 (플로팅용)
    - skin_type, skin_type_label, skin_characteristics
    - pentagon_scores: { sleep, alcohol, smoking, stress, activity, uv } 0~100 (렌더 시 alcohol+smoking 합침)
    - goals_solution: 피부 목표에 대한 솔루션 (RAG·리포트·설문 기반, goals 있을 때 생성)
    - situation_solution: 참고 상황 기반 간략 솔루션 (LLM, situation_text 있을 때만)
    """
    from .report_llm import invoke_llm_text

    outcomes = survey.get("outcomes", []) or []
    goals = [OUTCOME_LABELS.get(_norm_outcome(o), o) for o in outcomes]

    skin_type_raw = survey.get("skin_type") or ""
    skin_type_label = SKIN_TYPE_LABELS.get(str(skin_type_raw).strip().lower(), "미입력")
    skin_characteristics = (
        SKIN_TYPE_CHARACTERISTICS.get(str(skin_type_raw).strip().lower(), "")
        if skin_type_raw
        else ""
    )

    pentagon_scores = compute_pentagon_scores(survey)

    goals_solution = ""
    situation_solution = ""
    need_goals = bool(goals and report_sections_text.strip())
    need_situation = bool(situation_text and situation_text.strip())

    if need_goals and need_situation:
        def _run_goals_solution() -> str:
            return (
                invoke_llm_text(
                    prompt=f"""사용자의 피부 목표: {', '.join(goals)}

설문 요약: {_format_survey_brief(survey)}

생성된 리포트 내용:
{report_sections_text[:2000]}

⚠️ 정말 관련되고 중요한 것 1~3가지만 골라서 1~3문장으로 짧게 작성하세요.
전부 언급하지 마세요. 피부 목표에 직접 연결되는 핵심 포인트만. 불필요하면 1문장으로 끝내세요.
마크다운·번호 없이 일반 문장으로만.""",
                    system_prompt="당신은 피부과 전문의입니다. 피부 목표에 정말 중요한 조언 1~3가지만 압축해서 짧게 작성합니다. 길게 쓰지 마세요.",
                    context="summary.goals_solution",
                )
                or ""
            )

        def _run_situation_solution() -> str:
            return (
                invoke_llm_text(
                    prompt=f"""사용자가 입력한 참고 상황:
"{situation_text.strip()[:300]}"

생성된 리포트 요약:
{report_sections_text[:1500]}

⚠️ 이 상황에 정말 관련되고 중요한 것 1~3가지만 골라서 1~3문장으로 짧게 작성하세요.
전부 언급하지 마세요. 해당 상황에 직접 도움이 되는 핵심 포인트만. 불필요하면 1문장으로 끝내세요.
마크다운·번호 없이 일반 문장으로만.""",
                    system_prompt="당신은 피부과 전문의입니다. 참고 상황에 정말 중요한 조언 1~3가지만 압축해서 짧게 작성합니다. 길게 쓰지 마세요.",
                    context="summary.situation_solution",
                )
                or ""
            )

        with ThreadPoolExecutor(max_workers=2) as pool:
            f_g = pool.submit(_run_goals_solution)
            f_s = pool.submit(_run_situation_solution)
            goals_solution = f_g.result()
            situation_solution = f_s.result()
    else:
        if need_goals:
            goals_solution = (
                invoke_llm_text(
                    prompt=f"""사용자의 피부 목표: {', '.join(goals)}

설문 요약: {_format_survey_brief(survey)}

생성된 리포트 내용:
{report_sections_text[:2000]}

⚠️ 정말 관련되고 중요한 것 1~3가지만 골라서 1~3문장으로 짧게 작성하세요.
전부 언급하지 마세요. 피부 목표에 직접 연결되는 핵심 포인트만. 불필요하면 1문장으로 끝내세요.
마크다운·번호 없이 일반 문장으로만.""",
                    system_prompt="당신은 피부과 전문의입니다. 피부 목표에 정말 중요한 조언 1~3가지만 압축해서 짧게 작성합니다. 길게 쓰지 마세요.",
                    context="summary.goals_solution",
                )
                or ""
            )

        if need_situation:
            situation_solution = (
                invoke_llm_text(
                    prompt=f"""사용자가 입력한 참고 상황:
"{situation_text.strip()[:300]}"

생성된 리포트 요약:
{report_sections_text[:1500]}

⚠️ 이 상황에 정말 관련되고 중요한 것 1~3가지만 골라서 1~3문장으로 짧게 작성하세요.
전부 언급하지 마세요. 해당 상황에 직접 도움이 되는 핵심 포인트만. 불필요하면 1문장으로 끝내세요.
마크다운·번호 없이 일반 문장으로만.""",
                    system_prompt="당신은 피부과 전문의입니다. 참고 상황에 정말 중요한 조언 1~3가지만 압축해서 짧게 작성합니다. 길게 쓰지 마세요.",
                    context="summary.situation_solution",
                )
                or ""
            )

    return {
        "goals": goals,
        "skin_type": skin_type_raw,
        "skin_type_label": skin_type_label,
        "skin_characteristics": skin_characteristics,
        "pentagon_scores": pentagon_scores,
        "goals_solution": goals_solution,
        "situation_solution": situation_solution,
    }
