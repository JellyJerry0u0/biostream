"""
정량 근거 검색 및 통계 모듈
quant_evidence 컬렉션에서 outcome_mapped 기반 검색 및 통계 계산
"""

import os
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
from collections import defaultdict
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchValue, MatchAny, Range
import google.generativeai as genai
import math

# .env 파일 로드 (있는 경우) - override=False로 Docker 환경 변수 우선
try:
    from dotenv import load_dotenv
    backend_dir = Path(__file__).parent.parent.parent
    env_path = backend_dir / ".env"
    if env_path.exists():
        # Docker 환경에서는 환경 변수가 우선되어야 하므로 override=False
        # 로컬 개발 환경에서는 .env 파일이 사용됨
        load_dotenv(env_path, override=False)
except ImportError:
    pass

# 환경 변수 (Docker 환경 변수가 우선, 없으면 기본값)
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_QUANT_COLLECTION", "quant_evidence")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
GEMINI_EMBED_MODEL = os.getenv("GEMINI_EMBED_MODEL", "gemini-embedding-001")


# ── 임베딩 LRU 캐시 ──
# search_by_outcomes가 scroll로 전환되어 이 함수 호출이 대폭 감소했지만,
# 혹시 다른 경로에서 호출될 경우를 대비해 캐시 유지
_embedding_cache: Dict[str, List[float]] = {}
_EMBEDDING_CACHE_MAX = 256


def get_embedding(text: str) -> List[float]:
    """Gemini API를 사용하여 텍스트 임베딩 생성 (LRU 캐시 적용)"""
    # 함수 내에서 환경 변수 다시 읽기 (모듈 레벨 변수 대신)
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")

    # 캐시 히트
    if text in _embedding_cache:
        return _embedding_cache[text]

    try:
        genai.configure(api_key=api_key)  # 함수 내에서 읽은 api_key 사용
        result = genai.embed_content(
            model=GEMINI_EMBED_MODEL,
            content=text,
            task_type="retrieval_query",
        )
        embedding = result["embedding"]

        # 캐시 저장 (크기 제한)
        if len(_embedding_cache) >= _EMBEDDING_CACHE_MAX:
            oldest_key = next(iter(_embedding_cache))
            del _embedding_cache[oldest_key]
        _embedding_cache[text] = embedding

        return embedding
    except Exception as e:
        raise Exception(f"임베딩 생성 실패: {str(e)}")


def get_p_value_label(p_value: Optional[float]) -> str:
    """
    p-value 신뢰도 라벨 규칙
    - p ≤ 0.01  → strong
    - 0.01 < p ≤ 0.05 → moderate
    - p > 0.05 or NA → weak
    """
    if p_value is None or math.isnan(p_value):
        return "weak"
    if p_value <= 0.01:
        return "strong"
    if p_value <= 0.05:
        return "moderate"
    return "weak"


class QuantEvidenceCard:
    """정량 근거 카드"""
    def __init__(self, payload: Dict[str, Any], score: float = 1.0):
        self.paper_id = payload.get("paper_id", "")
        self.chunk_id = payload.get("chunk_id", "")
        self.outcome_mapped = payload.get("outcome_mapped", "")
        self.outcome_final = payload.get("outcome_final", "")
        self.effect_signed_value = payload.get("effect_signed_value")
        self.effect_unit_filled = payload.get("effect_unit_filled", "")
        self.timeframe_value_num = payload.get("timeframe_value_num")
        self.timeframe_unit_norm = payload.get("timeframe_unit_norm", "")
        self.timeframe_days = payload.get("timeframe_days")
        self.p_value_num = payload.get("p_value_num")
        self.p_label = payload.get("p_label", "")
        self.source_snippet = payload.get("source_snippet", "")
        self.title = payload.get("title", "")
        self.is_valid = payload.get("is_valid", True)
        self.suspicious_cross_outcome_copy = payload.get("suspicious_cross_outcome_copy", False)
        self.ci_low = payload.get("ci_low")
        self.ci_high = payload.get("ci_high")
        self.ci_low_num = payload.get("ci_low_num")
        self.ci_high_num = payload.get("ci_high_num")
        self.row_uid = payload.get("row_uid", "")
        self.score = score
        
        # p_label이 없으면 계산
        if not self.p_label and self.p_value_num is not None:
            self.p_label = get_p_value_label(self.p_value_num)
    
    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리로 변환"""
        return {
            "paper_id": self.paper_id,
            "chunk_id": self.chunk_id,
            "outcome_mapped": self.outcome_mapped,
            "outcome_final": self.outcome_final,
            "effect_signed_value": self.effect_signed_value,
            "effect_unit_filled": self.effect_unit_filled,
            "timeframe_value_num": self.timeframe_value_num,
            "timeframe_unit_norm": self.timeframe_unit_norm,
            "timeframe_days": self.timeframe_days,
            "p_value_num": self.p_value_num,
            "p_label": self.p_label,
            "source_snippet": self.source_snippet,
            "title": self.title,
            "is_valid": self.is_valid,
            "suspicious_cross_outcome_copy": self.suspicious_cross_outcome_copy,
            "ci_low": self.ci_low,
            "ci_high": self.ci_high,
            "ci_low_num": self.ci_low_num,
            "ci_high_num": self.ci_high_num,
            "row_uid": self.row_uid,
            "score": self.score,
        }


def search_by_outcome(
    outcome_mapped: str,
    top_k: int = 20,
    timeframe_days_range: Optional[Tuple[float, float]] = None,
    min_score: float = 0.0
) -> List[QuantEvidenceCard]:
    """
    outcome_mapped로 검색 (단일 outcome)
    
    Args:
        outcome_mapped: 검색할 outcome (예: "elasticity", "hydration_barrier")
        top_k: 반환할 최대 결과 수
        timeframe_days_range: (min_days, max_days) 튜플, None이면 필터 없음
        min_score: 최소 유사도 점수 (임베딩 검색 시)
    
    Returns:
        QuantEvidenceCard 리스트
    """
    return search_by_outcomes(
        outcome_mapped_list=[outcome_mapped],
        top_k=top_k,
        timeframe_days_range=timeframe_days_range,
        min_score=min_score
    )


def search_by_outcomes(
    outcome_mapped_list: List[str],
    top_k: int = 20,
    timeframe_days_range: Optional[Tuple[float, float]] = None,
    min_score: float = 0.0
) -> List[QuantEvidenceCard]:
    """
    여러 outcome_mapped로 검색 (확장 매핑용)
    
    ⚡ 최적화: 이 함수는 필터 기반 검색만 필요하므로
    임베딩을 생성하지 않고 scroll()을 사용합니다.
    (이전에는 의미 없는 더미 임베딩을 매번 생성하여 API 할당량을 소비했음)
    
    Args:
        outcome_mapped_list: 검색할 outcome 리스트 (예: ["wrinkle", "elasticity"])
        top_k: 반환할 최대 결과 수
        timeframe_days_range: (min_days, max_days) 튜플, None이면 필터 없음
        min_score: 최소 유사도 점수 (scroll 모드에서는 무시됨)
    
    Returns:
        QuantEvidenceCard 리스트
    """
    print(f"\n  🔍 [search_by_outcomes] 검색 시작 (scroll 모드, 임베딩 불필요):")
    print(f"     outcome_mapped_list: {outcome_mapped_list}")
    print(f"     QDRANT_URL: {QDRANT_URL}")
    print(f"     QDRANT_COLLECTION: {QDRANT_COLLECTION}")
    
    try:
        client = QdrantClient(url=QDRANT_URL)
        
        # 컬렉션 존재 여부 확인
        collections = client.get_collections().collections
        collection_names = [c.name for c in collections]
        print(f"     사용 가능한 컬렉션: {collection_names}")
        
        if QDRANT_COLLECTION not in collection_names:
            print(f"     ⚠️ 컬렉션 '{QDRANT_COLLECTION}'이 존재하지 않습니다!")
            return []
        
        # 컬렉션 정보 확인
        collection_info = client.get_collection(QDRANT_COLLECTION)
        print(f"     컬렉션 포인트 수: {collection_info.points_count}")
        
        # 필터 구성
        must_conditions = [
            FieldCondition(
                key="outcome_mapped",
                match=MatchAny(any=outcome_mapped_list)
            ),
            FieldCondition(
                key="is_valid",
                match=MatchValue(value=True)
            )
        ]
        
        # timeframe_days 범위 필터
        if timeframe_days_range:
            min_days, max_days = timeframe_days_range
            must_conditions.append(
                FieldCondition(
                    key="timeframe_days",
                    range=Range(gte=min_days, lte=max_days)
                )
            )
        
        query_filter = Filter(must=must_conditions)
        
        # ⚡ scroll 기반 검색 (임베딩 불필요 — 필터만으로 결과 가져옴)
        print(f"     Qdrant scroll 수행 중... (limit={top_k})")
        all_points = []
        offset = None
        remaining = top_k
        
        while remaining > 0:
            batch_limit = min(remaining, 100)  # scroll은 한 번에 최대 100개
            points, next_offset = client.scroll(
                collection_name=QDRANT_COLLECTION,
                scroll_filter=query_filter,
                limit=batch_limit,
                offset=offset,
                with_payload=True,
                with_vectors=False,
            )
            if not points:
                break
            all_points.extend(points)
            remaining -= len(points)
            offset = next_offset
            if next_offset is None:
                break
        
        print(f"     검색 결과: {len(all_points)}개 포인트 발견")
        
        # QuantEvidenceCard로 변환 (scroll에는 score가 없으므로 1.0 사용)
        cards = []
        for i, point in enumerate(all_points):
            card = QuantEvidenceCard(point.payload, score=1.0)
            cards.append(card)
            if i < 3:  # 처음 3개만 상세 로깅
                print(f"       포인트 {i+1}: outcome={card.outcome_mapped}, "
                      f"value={card.effect_signed_value}, unit={card.effect_unit_filled}, "
                      f"timeframe={card.timeframe_days}, is_valid={card.is_valid}")
        
        print(f"     ✅ 최종 반환 카드 수: {len(cards)}")
        return cards
        
    except Exception as e:
        print(f"     ❌ [search_by_outcomes] 검색 실패: {e}")
        import traceback
        traceback.print_exc()
        return []


def get_grouped_stats(
    outcome_mapped: str,
    exclude_suspicious: bool = True
) -> Dict[str, Any]:
    """
    단일 outcome_mapped에 대한 통계 (기존 호환성)
    """
    return get_grouped_stats_multi(
        outcome_mapped_list=[outcome_mapped],
        exclude_suspicious=exclude_suspicious
    )


def get_grouped_stats_multi(
    outcome_mapped_list: List[str],
    exclude_suspicious: bool = True
) -> Dict[str, Any]:
    """
    여러 outcome_mapped에 대한 통계 계산 (확장 매핑용)
    
    Args:
        outcome_mapped_list: 검색할 outcome 리스트
        exclude_suspicious: suspicious_cross_outcome_copy가 True인 항목 제외 여부
    
    Returns:
        {
            "outcome_mapped_list": List[str],
            "timeframe_groups": {
                timeframe_days: {
                    "timeframe_days": float,
                    "timeframe_unit_norm": str,
                    "count": int,
                    "mean": float,
                    "median": float,
                    "min": float,
                    "max": float,
                    "cards": List[Dict],  # suspicious 제외된 카드만
                    "all_cards": List[Dict]  # 모든 카드 (suspicious 포함)
                }
            },
            "overall_stats": {
                "count": int,
                "mean": float,
                "median": float,
                "min": float,
                "max": float
            }
        }
    """
    print(f"\n  📊 [get_grouped_stats_multi] 통계 계산 시작:")
    print(f"     outcome_mapped_list: {outcome_mapped_list}")
    print(f"     exclude_suspicious: {exclude_suspicious}")
    
    # 모든 카드 검색 (top_k를 크게 설정)
    all_cards = search_by_outcomes(outcome_mapped_list, top_k=1000, min_score=0.0)
    print(f"     검색된 전체 카드 수: {len(all_cards)}")
    
    # suspicious 제외 여부에 따라 필터링
    if exclude_suspicious:
        valid_cards = [c for c in all_cards if not c.suspicious_cross_outcome_copy]
        print(f"     suspicious 제외 후 카드 수: {len(valid_cards)} (제외: {len(all_cards) - len(valid_cards)})")
    else:
        valid_cards = all_cards
        print(f"     suspicious 필터링 없음: {len(valid_cards)}개 카드")
    
    # timeframe_days별 그룹핑
    timeframe_groups = defaultdict(list)
    cards_without_timeframe = 0
    for card in valid_cards:
        if card.timeframe_days is not None:
            timeframe_groups[card.timeframe_days].append(card)
        else:
            cards_without_timeframe += 1
    
    if cards_without_timeframe > 0:
        print(f"     ⚠️ timeframe_days가 None인 카드: {cards_without_timeframe}개")
    
    print(f"     timeframe 그룹 수: {len(timeframe_groups)}")
    
    # 그룹별 통계 계산
    grouped_stats = {}
    for timeframe_days, cards in timeframe_groups.items():
        # 통계 계산에 사용할 카드 필터링 (강제 조건)
        stats_cards = []
        for card in cards:
            # 필수 조건 체크
            if not card.is_valid:
                continue
            if card.suspicious_cross_outcome_copy:
                continue
            if card.effect_signed_value is None or math.isnan(card.effect_signed_value):
                continue
            if card.effect_unit_filled != "%":
                continue
            stats_cards.append(card)
        
        if not stats_cards:
            # 로깅: 통계 계산에 사용할 카드가 없음
            print(f"  ⚠️ [{timeframe_days}일] 통계 계산 불가: 필터 조건을 만족하는 카드 없음")
            print(f"     전체 카드 수: {len(cards)}")
            for i, card in enumerate(cards[:3], 1):  # 처음 3개만 로깅
                print(f"       카드 {i}: is_valid={card.is_valid}, suspicious={card.suspicious_cross_outcome_copy}, "
                      f"value={card.effect_signed_value}, unit={card.effect_unit_filled}")
            continue
        
        # 통계 계산에 사용된 값 추출
        stats_values = [c.effect_signed_value for c in stats_cards]
        
        # 로깅: 통계 계산에 포함된 카드 정보
        print(f"\n  📊 [{timeframe_days}일] 통계 계산:")
        print(f"     포함된 카드 수: {len(stats_cards)}")
        print(f"     카드 식별자 리스트: {[f'{c.chunk_id}__{c.row_uid}' for c in stats_cards]}")
        for card in stats_cards:
            print(f"       - {card.chunk_id}__{card.row_uid}: outcome={card.outcome_mapped}, "
                  f"value={card.effect_signed_value}%, timeframe={card.timeframe_days}일, "
                  f"is_valid={card.is_valid}, suspicious={card.suspicious_cross_outcome_copy}")
        print(f"     통계에 사용된 값: {stats_values}")
        
        # 통계 계산
        sorted_values = sorted(stats_values)
        n = len(sorted_values)
        mean = sum(sorted_values) / n
        median = sorted_values[n // 2] if n % 2 == 1 else (sorted_values[n // 2 - 1] + sorted_values[n // 2]) / 2
        min_val = sorted_values[0]
        max_val = sorted_values[-1]
        
        print(f"     계산 결과: mean={round(mean, 2)}, median={round(median, 2)}, "
              f"min={round(min_val, 2)}, max={round(max_val, 2)}")
        
        # timeframe_unit_norm 찾기 (첫 번째 카드에서)
        timeframe_unit_norm = stats_cards[0].timeframe_unit_norm if stats_cards else ""
        
        # suspicious 제외된 카드만 (통계용)
        clean_cards = [c.to_dict() for c in stats_cards]
        # 모든 카드 (is_valid == True인 모든 카드, suspicious 포함)
        all_cards_dict = [c.to_dict() for c in cards if c.is_valid]
        
        grouped_stats[timeframe_days] = {
            "timeframe_days": timeframe_days,
            "timeframe_unit_norm": timeframe_unit_norm,
            "count": n,
            "mean": round(mean, 2),
            "median": round(median, 2),
            "min": round(min_val, 2),
            "max": round(max_val, 2),
            "unit": "%",
            "cards": clean_cards,
            "all_cards": all_cards_dict,
            "stats_values": stats_values  # 디버깅용
        }
    
    # 전체 통계 계산 (모든 timeframe 통합) - 동일한 필터 적용
    all_stats_cards = []
    for card in valid_cards:
        if not card.is_valid:
            continue
        if card.suspicious_cross_outcome_copy:
            continue
        if card.effect_signed_value is None or math.isnan(card.effect_signed_value):
            continue
        if card.effect_unit_filled != "%":
            continue
        all_stats_cards.append(card)
    
    all_effect_values = [c.effect_signed_value for c in all_stats_cards]
    
    overall_stats = {}
    if all_effect_values:
        sorted_all = sorted(all_effect_values)
        n_all = len(sorted_all)
        overall_stats = {
            "count": n_all,
            "mean": round(sum(sorted_all) / n_all, 2),
            "median": round(sorted_all[n_all // 2] if n_all % 2 == 1 
                          else (sorted_all[n_all // 2 - 1] + sorted_all[n_all // 2]) / 2, 2),
            "min": round(sorted_all[0], 2),
            "max": round(sorted_all[-1], 2)
        }
    else:
        overall_stats = {
            "count": 0,
            "mean": None,
            "median": None,
            "min": None,
            "max": None
        }
    
    return {
        "outcome_mapped_list": outcome_mapped_list,
        "timeframe_groups": grouped_stats,
        "overall_stats": overall_stats
    }


def format_quant_summary(
    stats: Dict[str, Any],
    outcome_mapped: Optional[str] = None,
    outcome_polarity_map: Optional[Dict[str, str]] = None
) -> str:
    """
    통계를 한국어 요약 텍스트로 변환 (polarity 반영)
    
    Args:
        stats: get_grouped_stats() 결과
        outcome_mapped: outcome_mapped 값 (polarity 판단용)
        outcome_polarity_map: outcome polarity 매핑
    
    Returns:
        "12주 후 평균 약 15% 정도의 개선이 관찰되었습니다 (개인차 범위: 약 12% ~ 18%)" 형식의 텍스트
    """
    if not stats.get("timeframe_groups"):
        return "정량 근거 없음"
    
    summaries = []
    for timeframe_days, group in sorted(stats["timeframe_groups"].items()):
        # timeframe 라벨 변환 (한국어)
        timeframe_label = timeframe_days_to_label_korean(timeframe_days)
        
        unit = group.get("unit", "%")
        mean = group.get("mean", 0)
        min_val = group.get("min", 0)
        max_val = group.get("max", 0)
        
        # polarity 반영하여 "개선/악화/변화" 결정
        if outcome_mapped:
            mean_interpretation = interpret_effect_with_polarity(mean, outcome_mapped, outcome_polarity_map)
            if mean_interpretation == "improved":
                summary = f"{timeframe_label} 후 평균 약 {abs(mean)}{unit} 정도의 개선이 관찰되었습니다 (개인차 범위: 약 {min_val}% ~ {max_val}%)"
            elif mean_interpretation == "worsened":
                summary = f"{timeframe_label} 후 평균 약 {abs(mean)}{unit} 정도의 악화가 관찰되었습니다 (개인차 범위: 약 {min_val}% ~ {max_val}%)"
            else:  # changed
                summary = f"{timeframe_label} 후 평균 약 {abs(mean)}{unit} 정도의 변화가 관찰되었습니다 (개인차 범위: 약 {min_val}% ~ {max_val}%)"
        else:
            # polarity 정보 없으면 "변화" 사용
            summary = f"{timeframe_label} 후 평균 약 {abs(mean)}{unit} 정도의 변화가 관찰되었습니다 (개인차 범위: 약 {min_val}% ~ {max_val}%)"
        
        summaries.append(summary)
    
    return " | ".join(summaries)


def timeframe_days_to_label_korean(days: float) -> str:
    """
    timeframe_days 값을 한국어 라벨로 변환
    
    Args:
        days: timeframe_days 값
    
    Returns:
        "12주", "6개월", "X일" 등
    """
    days_int = int(round(days))
    
    # 특정 범위 매칭 (약간의 오차 허용)
    if 26 <= days_int <= 30:  # 28 ± 2
        return "4주"
    elif 81 <= days_int <= 87:  # 84 ± 3
        return "12주"
    elif 170 <= days_int <= 190:  # 180 ± 10
        return "6개월"
    elif 350 <= days_int <= 380:  # 365 ± 15
        return "12개월"
    elif 88 <= days_int <= 98:  # 91 ± 5 (약 13주)
        return "13주"
    elif 55 <= days_int <= 65:  # 56 ± 5 (약 8주)
        return "8주"
    else:
        # 7로 나누어 떨어지면 주 단위
        if days_int % 7 == 0:
            weeks = days_int // 7
            return f"{weeks}주"
        else:
            return f"{days_int}일"


# Outcome polarity 테이블 (개선 방향성)
OUTCOME_POLARITY = {
    "wrinkle": "decrease_is_improvement",
    "pigmentation": "decrease_is_improvement",
    "acne": "decrease_is_improvement",
    "redness": "decrease_is_improvement",
    "elasticity": "increase_is_improvement",
    "hydration": "increase_is_improvement",
    "hydration_barrier": "increase_is_improvement",
    "general_aging": "mixed",
    "general_skin": "mixed",
}


def get_outcome_polarity(outcome_mapped: str, outcome_polarity_map: Optional[Dict[str, str]] = None) -> str:
    """
    outcome의 polarity 반환
    
    Args:
        outcome_mapped: outcome_mapped 값
        outcome_polarity_map: polarity 매핑 (None이면 기본값 사용)
    
    Returns:
        "increase_is_improvement", "decrease_is_improvement", "mixed"
    """
    if outcome_polarity_map is None:
        outcome_polarity_map = OUTCOME_POLARITY
    return outcome_polarity_map.get(outcome_mapped, "mixed")


def interpret_effect_with_polarity(
    effect_value: float,
    outcome_mapped: str,
    outcome_polarity_map: Optional[Dict[str, str]] = None
) -> str:
    """
    effect_signed_value를 polarity에 따라 해석
    
    Args:
        effect_value: effect_signed_value
        outcome_mapped: outcome_mapped 값
        outcome_polarity_map: polarity 매핑 (None이면 기본값 사용)
    
    Returns:
        "improved", "worsened", "changed"
    """
    polarity = get_outcome_polarity(outcome_mapped, outcome_polarity_map)
    
    if polarity == "mixed":
        return "changed"
    
    # effect_value의 부호 확인
    if effect_value > 0:
        if polarity == "increase_is_improvement":
            return "improved"
        else:  # decrease_is_improvement
            return "worsened"
    elif effect_value < 0:
        if polarity == "increase_is_improvement":
            return "worsened"
        else:  # decrease_is_improvement
            return "improved"
    else:
        return "changed"


def timeframe_days_to_label(days: float) -> str:
    """
    timeframe_days 값을 사람이 읽기 쉬운 라벨로 변환
    
    Args:
        days: timeframe_days 값
    
    Returns:
        "4 weeks", "12 weeks", "6 months", "X days" 등
    """
    days_int = int(round(days))
    
    # 특정 범위 매칭 (약간의 오차 허용)
    if 26 <= days_int <= 30:  # 28 ± 2
        return "4 weeks"
    elif 81 <= days_int <= 87:  # 84 ± 3
        return "12 weeks"
    elif 170 <= days_int <= 190:  # 180 ± 10
        return "6 months"
    elif 350 <= days_int <= 380:  # 365 ± 15
        return "12 months"
    elif 88 <= days_int <= 98:  # 91 ± 5 (약 13주)
        return "13 weeks"
    elif 55 <= days_int <= 65:  # 56 ± 5 (약 8주)
        return "8 weeks"
    else:
        # 7로 나누어 떨어지면 주 단위
        if days_int % 7 == 0:
            weeks = days_int // 7
            return f"{weeks} weeks"
        else:
            return f"{days_int} days"


def format_quant_block(
    outcome_mapped: str,
    outcome_label: str,
    stats: Dict[str, Any],
    outcome_polarity_map: Optional[Dict[str, str]] = None
) -> Dict[str, Any]:
    """
    정량 블록 생성 (요약 문장 + 카드 리스트)
    polarity를 반영하여 "improved/worsened/changed" 결정
    
    Args:
        outcome_mapped: outcome_mapped 값 (또는 UI outcome)
        outcome_label: 한글 라벨
        stats: get_grouped_stats() 또는 get_grouped_stats_multi() 결과
        outcome_polarity_map: outcome polarity 매핑 (None이면 기본값 사용)
    
    Returns:
        {
            "blocks": [
                {
                    "title": "{Outcome} — {N weeks}",
                    "summary": "At {N weeks}, across {K} evidence cards, ...",
                    "cards": [...]
                }
            ],
            "has_evidence": bool
        }
    """
    # 기본 polarity 매핑
    if outcome_polarity_map is None:
        outcome_polarity_map = OUTCOME_POLARITY
    
    if not stats or not stats.get("timeframe_groups"):
        return {
            "blocks": [],
            "has_evidence": False,
            "message": "정량 근거 없음 (quantitative evidence not found)"
        }
    
    blocks = []
    
    for timeframe_days, group in sorted(stats["timeframe_groups"].items()):
        # timeframe 라벨 변환
        timeframe_label = timeframe_days_to_label(timeframe_days)
        
        # 블록 제목
        title = f"{outcome_label} — {timeframe_label}"
        
        # 요약 문장 생성 (polarity 반영)
        count = group.get("count", 0)
        mean = group.get("mean", 0)
        median = group.get("median", 0)
        min_val = group.get("min", 0)
        max_val = group.get("max", 0)
        unit = group.get("unit", "%")
        
        # mean 값으로 개선/악화 판단
        mean_interpretation = interpret_effect_with_polarity(mean, outcome_mapped, outcome_polarity_map)
        
        # 단복수 처리
        card_text = "evidence card" if count == 1 else "evidence cards"
        
        # 요약 문장 생성
        if mean_interpretation == "improved":
            summary = (
                f"At {timeframe_label}, across {count} {card_text}, "
                f"{outcome_label} improved by an average of {abs(mean)}{unit} "
                f"(median {abs(median)}{unit}, range {min_val}{unit} to {max_val}{unit})."
            )
        elif mean_interpretation == "worsened":
            summary = (
                f"At {timeframe_label}, across {count} {card_text}, "
                f"{outcome_label} worsened by an average of {abs(mean)}{unit} "
                f"(median {abs(median)}{unit}, range {min_val}{unit} to {max_val}{unit})."
            )
        else:  # changed
            summary = (
                f"At {timeframe_label}, across {count} {card_text}, "
                f"{outcome_label} changed by an average of {abs(mean)}{unit} "
                f"(median {abs(median)}{unit}, range {min_val}{unit} to {max_val}{unit})."
            )
        
        # 카드 리스트 (suspicious 포함, 라벨 표시)
        cards = []
        for card in group.get("all_cards", []):
            paper_id = card.get("paper_id", "")
            chunk_id = card.get("chunk_id", "")
            p_value = card.get("p_value_num")
            p_label = card.get("p_label", "weak")
            source_snippet = card.get("source_snippet", "")
            is_suspicious = card.get("suspicious_cross_outcome_copy", False)
            
            # 카드 텍스트
            card_text = f"{paper_id} / {chunk_id}"
            if p_value is not None:
                card_text += f" (p={p_value}, {p_label})"
            else:
                card_text += f" (p=NA, {p_label})"
            
            if is_suspicious:
                card_text += " [review / check needed]"
            
            card_text += f": {source_snippet}"
            
            cards.append({
                "text": card_text,
                "paper_id": paper_id,
                "chunk_id": chunk_id,
                "p_value": p_value,
                "p_label": p_label,
                "is_suspicious": is_suspicious,
                "source_snippet": source_snippet
            })
        
        blocks.append({
            "title": title,
            "summary": summary,
            "cards": cards,
            "timeframe_label": timeframe_label,
            "timeframe_days": timeframe_days
        })
    
    return {
        "blocks": blocks,
        "has_evidence": True,
        "message": None
    }


if __name__ == "__main__":
    # 테스트
    print("정량 근거 검색 테스트 시작...\n")
    
    # 1. elasticity 검색
    print("[1] elasticity 검색 테스트")
    cards = search_by_outcome("elasticity", top_k=10)
    print(f"  검색 결과: {len(cards)}개")
    for i, card in enumerate(cards[:5], 1):
        print(f"  {i}. {card.effect_signed_value}{card.effect_unit_filled} @ {card.timeframe_days}일 "
              f"(p={card.p_value_num}, {card.p_label})")
    
    # 2. hydration_barrier 검색
    print("\n[2] hydration_barrier 검색 테스트")
    cards = search_by_outcome("hydration_barrier", top_k=10)
    print(f"  검색 결과: {len(cards)}개")
    for i, card in enumerate(cards[:5], 1):
        print(f"  {i}. {card.effect_signed_value}{card.effect_unit_filled} @ {card.timeframe_days}일 "
              f"(p={card.p_value_num}, {card.p_label})")
    
    # 3. 통계 계산
    print("\n[3] elasticity 통계 계산")
    stats = get_grouped_stats("elasticity")
    print(f"  전체 통계: {stats['overall_stats']}")
    print(f"  timeframe 그룹 수: {len(stats['timeframe_groups'])}")
    for timeframe, group in stats["timeframe_groups"].items():
        print(f"    {timeframe}일: 평균 {group['mean']}{group.get('unit', '%')} "
              f"(범위: {group['min']}~{group['max']}, n={group['count']})")
    
    # 4. 요약 텍스트 생성
    print("\n[4] 요약 텍스트 생성")
    summary = format_quant_summary(stats, outcome_mapped="elasticity")
    print(f"  {summary}")
