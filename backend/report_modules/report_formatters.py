"""
리포트 생성 포맷팅/유틸리티 함수
- outcome → topic 매핑
- timeframe 라벨 변환
- 사용자 프로필 파생 지표 (BMI, age_bucket 등)
- 설문 데이터 포맷팅
- 정량 근거 포맷팅
"""

import os
import sys
from typing import Dict, Any, List, Optional
from datetime import date

# 경로 설정
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.append(backend_dir)

from app.database import get_db
from app.models import User
from app.services.quant_evidence_retriever import get_grouped_stats_multi

from .report_constants import (
    OUTCOME_LABELS,
    OUTCOME_TO_NARRATIVE_TOPICS,
    STANDARD_TIMEFRAMES,
)


# ──────────────────────────── outcome → topic 매핑 ────────────────────────────

def map_outcomes_to_topics(outcomes: List[str], include_fallback: bool = True) -> List[str]:
    """UI outcomes를 narrative 코퍼스 topics로 변환"""
    topics = []
    seen = set()

    for outcome in outcomes:
        mapped_topics = OUTCOME_TO_NARRATIVE_TOPICS.get(outcome, [])
        for topic in mapped_topics:
            if topic not in seen:
                topics.append(topic)
                seen.add(topic)
        if include_fallback and not mapped_topics and outcome not in seen:
            topics.append(outcome)
            seen.add(outcome)

    return topics


# ──────────────────────────── timeframe ────────────────────────────

def timeframe_days_to_label(days: float) -> str:
    """timeframe_days를 사람이 읽기 쉬운 레이블로 변환"""
    if days <= 35:
        return "4주"
    elif days <= 100:
        return "12주"
    elif days <= 200:
        return "6개월"
    else:
        weeks = round(days / 7)
        return f"{weeks}주"


def select_top_timeframes(timeframe_groups: Dict[float, Dict], max_count: int = 2) -> List[float]:
    """대표 timeframe 1-2개 선택 (표준 라벨 우선)"""
    if not timeframe_groups:
        return []

    selected = []
    for _tf_label, tf_days_std in STANDARD_TIMEFRAMES.items():
        for tf_days in timeframe_groups.keys():
            if abs(tf_days - tf_days_std) < 7:
                if tf_days not in selected:
                    selected.append(tf_days)
                    if len(selected) >= max_count:
                        return selected

    remaining = sorted(
        [d for d in timeframe_groups.keys() if d not in selected],
        key=lambda d: timeframe_groups[d].get("count", 0),
        reverse=True,
    )
    for tf_days in remaining:
        if len(selected) >= max_count:
            break
        selected.append(tf_days)

    return selected[:max_count]


# ──────────────────────────── 사용자 프로필 ────────────────────────────

def calculate_user_profile_derived(user_id: int, survey: dict) -> Dict[str, Any]:
    """사용자 기본 정보로부터 파생 지표 계산 (BMI, age_bucket 등)"""
    profile: Dict[str, Any] = {
        "user_id": user_id,
        "gender": None,
        "age": None,
        "age_bucket": None,
        "height": survey.get("height"),
        "weight": survey.get("weight"),
        "bmi": None,
        "bmi_category": None,
    }

    try:
        db_gen = get_db()
        db = next(db_gen)
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            profile["gender"] = user.gender
            if user.birthdate:
                today = date.today()
                age = today.year - user.birthdate.year - (
                    (today.month, today.day) < (user.birthdate.month, user.birthdate.day)
                )
                profile["age"] = age
                buckets = [(20, "10대"), (30, "20대"), (40, "30대"), (50, "40대"), (60, "50대")]
                profile["age_bucket"] = "60대 이상"
                for threshold, label in buckets:
                    if age < threshold:
                        profile["age_bucket"] = label
                        break
        db.close()
    except Exception as e:
        print(f"⚠️ 사용자 정보 조회 실패: {e}")

    height = profile.get("height")
    weight = profile.get("weight")
    if height and weight and height > 0:
        height_m = height / 100
        bmi = weight / (height_m ** 2)
        profile["bmi"] = round(bmi, 1)
        if bmi < 18.5:
            profile["bmi_category"] = "저체중"
        elif bmi < 23:
            profile["bmi_category"] = "정상"
        elif bmi < 25:
            profile["bmi_category"] = "과체중"
        else:
            profile["bmi_category"] = "비만"

    return profile


def format_user_profile_for_prompt(profile: Dict[str, Any]) -> str:
    """프롬프트에 사용할 사용자 프로필 텍스트"""
    parts = []
    if profile.get("gender"):
        gender_label = "남성" if profile["gender"].lower() in ["male", "m", "남성", "남"] else "여성"
        parts.append(f"성별: {gender_label}")
    if profile.get("age_bucket"):
        parts.append(f"연령대: {profile['age_bucket']}")
    if profile.get("bmi") and profile.get("bmi_category"):
        parts.append(f"BMI: {profile['bmi']} ({profile['bmi_category']})")
    return ", ".join(parts) if parts else "사용자 기본 정보 없음"


# ──────────────────────────── outcome 점수 / estimated stats ────────────────────────────

def score_outcome_for_selection(stats: Dict[str, Any]) -> float:
    """outcome 선택을 위한 점수 계산"""
    if not stats or not stats.get("timeframe_groups"):
        return 0.0

    timeframe_groups = stats["timeframe_groups"]
    max_score = 0.0
    p_label_weights = {"strong": 3, "moderate": 2, "weak": 1}

    for _tf_days, group in timeframe_groups.items():
        n_cards = group.get("count", 0)
        if n_cards == 0:
            continue

        cards = group.get("cards", [])
        p_weight = p_label_weights.get(cards[0].get("p_label", "weak"), 1) if cards else 1

        median_abs = abs(group.get("median", 0))
        if median_abs > 50:
            continue

        score = n_cards * p_weight
        max_score = max(max_score, score)

    return max_score


def calculate_estimated_stats(outcome_list: List[str]) -> Optional[Dict[str, Any]]:
    """전체 코퍼스에서 추정치 계산 (fallback)"""
    try:
        stats = get_grouped_stats_multi(outcome_list, exclude_suspicious=True)
        if not stats or not stats.get("timeframe_groups"):
            return None

        timeframe_groups = stats["timeframe_groups"]
        selected_timeframes = select_top_timeframes(timeframe_groups, max_count=1)
        if not selected_timeframes:
            return None

        selected_timeframe = selected_timeframes[0]
        group = timeframe_groups[selected_timeframe]
        cards = group.get("cards", [])
        if not cards:
            return None

        values = [abs(c.get("effect_signed_value", 0)) for c in cards if c.get("effect_unit_filled") == "%"]
        values = [v for v in values if v <= 50]
        if not values:
            return None

        sorted_values = sorted(values)
        n = len(sorted_values)
        median = sorted_values[n // 2] if n % 2 == 1 else (sorted_values[n // 2 - 1] + sorted_values[n // 2]) / 2
        q75_idx = (3 * n) // 4
        q75 = sorted_values[q75_idx] if q75_idx < n else sorted_values[-1]

        return {
            "timeframe_days": selected_timeframe,
            "timeframe_label": timeframe_days_to_label(selected_timeframe),
            "median": median,
            "min": max(-30, -q75),
            "max": min(30, q75),
            "count": len(values),
        }
    except Exception as e:
        print(f"  ⚠️ 추정치 계산 실패: {e}")
        return None


# ──────────────────────────── 설문 데이터 포맷팅 ────────────────────────────

def normalize_survey_value(value: Any, field: str) -> str:
    """설문 값을 한국어로 자연스럽게 변환"""
    if value is None or value == "N/A":
        return "정보 없음"

    value_str = str(value).lower().strip()

    field_mappings: Dict[str, List[tuple]] = {
        "sunscreen_frequency": [
            (["never", "안", "거의", "드문", "안함", "안 씀", "거의 안"], "거의 사용하지 않음"),
            (["가끔", "sometimes", "외출 시"], "가끔 사용"),
            (["매일", "daily", "항상", "always"], "매일 사용"),
            (["자주", "often", "주 3회"], "자주 사용"),
        ],
        "smoking_status": [
            (["never", "안", "비흡연", "never smoked"], "비흡연"),
            (["current", "현재", "흡연", "smoking"], "현재 흡연"),
            (["former", "과거", "ex-smoker"], "과거 흡연"),
        ],
        "uv_exposure_10to16": [
            (["never", "안", "거의", "드문"], "거의 없음"),
            (["가끔", "sometimes"], "가끔"),
            (["자주", "often", "매일", "daily"], "자주"),
        ],
    }

    mappings = field_mappings.get(field, [])
    for keywords, result in mappings:
        if any(kw in value_str for kw in keywords):
            return result

    return str(value)


def format_survey_data(section: str, survey: dict) -> str:
    """섹션별 설문 데이터 포맷팅"""
    if section == "goals":
        outcomes = survey.get("outcomes", [])
        labels = ", ".join([OUTCOME_LABELS.get(o, o) for o in outcomes])
        return f"""피부 고민: {labels}
⚠️ 이 고민들을 "당신의 {labels} 문제"로 직접 언급하세요."""
    elif section == "sleep":
        hours = survey.get("sleep_hours_weekday", "N/A")
        quality = survey.get("sleep_quality_score", "N/A")
        return f"""평일 수면 시간: {hours}시간
수면의 질 점수: {quality}/10점
⚠️ 반드시 "당신의 평일 수면은 {hours}시간이며, 수면의 질은 {quality}/10점입니다"로 직접 인용하세요."""
    elif section == "uv":
        exposure_kr = normalize_survey_value(survey.get("uv_exposure_10to16", "N/A"), "uv_exposure_10to16")
        sunscreen_kr = normalize_survey_value(survey.get("sunscreen_frequency", "N/A"), "sunscreen_frequency")
        return f"""자외선 노출 (10-16시): {exposure_kr}
선크림 사용 빈도: {sunscreen_kr}
⚠️ 반드시 "자외선 노출이 {exposure_kr}이고, 선크림 사용이 {sunscreen_kr}인 편입니다"처럼 자연스럽게 요약하세요."""
    elif section == "lifestyle":
        smoking_kr = normalize_survey_value(survey.get("smoking_status", "N/A"), "smoking_status")
        drinking = survey.get("drinking_days_per_week", "N/A")
        stress = survey.get("stress_score", "N/A")
        return f"""흡연 상태: {smoking_kr}
주당 음주 일수: {drinking}일
스트레스 점수: {stress}/10점
⚠️ 반드시 "생활습관을 보면 {smoking_kr}이고, 주당 {drinking}일 음주하며, 스트레스는 {stress}/10점입니다"처럼 자연스럽게 요약하세요."""
    elif section == "activity":
        aerobic = survey.get("aerobic_weekly", "N/A")
        resistance = survey.get("resistance_weekly", "N/A")
        return f"""유산소 운동: {aerobic}회/주
근력 운동: {resistance}회/주
⚠️ 반드시 "당신은 유산소 운동을 주 {aerobic}회, 근력 운동을 주 {resistance}회 합니다"로 직접 인용하세요."""
    return ""


def get_personalization_note(section: str, survey: dict) -> str:
    """섹션별 개인화 강조 노트"""
    if section == "sleep":
        hours = survey.get("sleep_hours_weekday", "N/A")
        return f"""⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 설문 데이터({hours}시간)를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "수면 패턴을 보면 평일 평균 {hours}시간 정도로 부족한 편입니다" (자연스러운 요약)
- X: "당신의 평일 수면은 {hours}시간입니다" (직설적 나열)
- 일반론("수면이 부족하면") 금지"""
    elif section == "uv":
        exposure_kr = normalize_survey_value(survey.get("uv_exposure_10to16", "N/A"), "uv_exposure_10to16")
        sunscreen_kr = normalize_survey_value(survey.get("sunscreen_frequency", "N/A"), "sunscreen_frequency")
        return f"""⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 설문 데이터를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "자외선 노출이 {exposure_kr}이고, 선크림 사용이 {sunscreen_kr}인 편입니다" (자연스러운 요약)
- "never", "안 씀" 같은 영어/직설적 표현 금지, 반드시 한국어로 자연스럽게 요약
- 일반론("자외선에 노출되면") 금지"""
    elif section == "lifestyle":
        smoking_kr = normalize_survey_value(survey.get("smoking_status", "N/A"), "smoking_status")
        return f"""⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 흡연/음주/스트레스 상태를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "생활습관을 보면 {smoking_kr}이고, 주당 음주 빈도가 높은 편입니다" (자연스러운 요약)
- "never", "안 함" 같은 영어/직설적 표현 금지, 반드시 한국어로 자연스럽게 요약
- 일반론("흡연하면", "음주하면") 금지"""
    elif section == "activity":
        return """⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 운동 빈도를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "운동 패턴을 보면 유산소는 주 1회, 근력은 거의 하지 않는 편입니다" (자연스러운 요약)
- 일반론("운동이 중요합니다") 금지"""
    return ""


# ──────────────────────────── 정량 근거 포맷팅 ────────────────────────────

def format_quant_data(section_quant: dict) -> str:
    """정량 근거 데이터 포맷팅"""
    mode = section_quant.get("mode", "estimated")
    stats_by_outcome = section_quant.get("stats_by_outcome", {})

    if mode == "grounded" and stats_by_outcome:
        lines = []
        for outcome, stats in stats_by_outcome.items():
            if isinstance(stats, dict) and "timeframe_groups" in stats:
                for tf_days, group in stats["timeframe_groups"].items():
                    tf_label = timeframe_days_to_label(tf_days)
                    outcome_label = OUTCOME_LABELS.get(outcome, outcome)
                    median = group.get("median", group.get("mean", 0))
                    min_val = group.get("min", 0)
                    max_val = group.get("max", 0)
                    lines.append(
                        f"{outcome_label}: {tf_label} 유지 시, 연구에서 {outcome_label}이(가) "
                        f"중앙값 {median:.1f}% 변화(범위 {min_val:.1f}~{max_val:.1f}%)"
                    )
        return "\n".join(lines) if lines else "정량 근거 없음"
    elif mode == "estimated" and "estimated" in stats_by_outcome:
        est = stats_by_outcome["estimated"]
        return (
            f"추정치: 정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 추정하면, "
            f"{est['timeframe_label']}에 {est['min']:.0f}~{est['max']:.0f}% 정도 변화 가능"
        )
    return "정량 근거 없음"
