"""
Qdrant 검색 도구
Recall 최우선형 RAG 검색 전략을 사용하여 관련 논문 근거를 검색합니다.

전략(최종):
1차: topics 필터로 검색 (topics가 있을 때만)
2차(fallback): 필터 없이 전체 코퍼스 검색 (topics 필터를 썼는데 결과가 부족/품질 낮을 때만)
결과: 섹션별 다양성 확보(각 섹션 상위 N개) 후, 부족분은 전체 점수 순으로 채워 top_k를 보장
"""

import os
from pathlib import Path
from typing import Dict, List
from collections import defaultdict

from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchAny
import google.generativeai as genai

try:
    from tools.schemas import QdrantSearchInput, QdrantSearchOutput, EvidenceItem
except ImportError:
    from schemas import QdrantSearchInput, QdrantSearchOutput, EvidenceItem

# .env 파일 로드 (있는 경우)
try:
    from dotenv import load_dotenv

    backend_dir = Path(__file__).parent.parent
    env_path = backend_dir / ".env"
    if env_path.exists():
        load_dotenv(env_path)
except ImportError:
    pass

# 환경 변수에서 설정 읽기
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "biostream_corpus_v1")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
GEMINI_EMBED_MODEL = os.getenv("GEMINI_EMBED_MODEL","models/gemini-embedding-001")

# genai configure는 프로세스당 1회만
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


# ── 임베딩 LRU 캐시 ──
# 같은 query text → 같은 벡터이므로 API 재호출 방지
# 리포트 1건 내 동일 쿼리 + fallback cascade에서 큰 절감 효과
_embedding_cache: Dict[str, List[float]] = {}
_EMBEDDING_CACHE_MAX = 256


def get_embedding(text: str) -> List[float]:
    """Gemini API를 사용하여 텍스트 임베딩 생성 (LRU 캐시 적용)"""
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")

    # 캐시 히트
    if text in _embedding_cache:
        return _embedding_cache[text]

    # 모델명에 models/ 접두사 추가 (없는 경우)
    model_name = GEMINI_EMBED_MODEL
    if not model_name.startswith("models/") and not model_name.startswith("tunedModels/"):
        model_name = f"models/{model_name}"

    try:
        result = genai.embed_content(
            model=model_name,
            content=text,
            task_type="retrieval_query",
        )
        embedding = result["embedding"]

        # 캐시 저장 (크기 제한)
        if len(_embedding_cache) >= _EMBEDDING_CACHE_MAX:
            # 가장 오래된 항목 제거 (dict는 3.7+ 삽입 순서 보장)
            oldest_key = next(iter(_embedding_cache))
            del _embedding_cache[oldest_key]
        _embedding_cache[text] = embedding

        return embedding
    except Exception as e:
        raise Exception(f"임베딩 생성 실패: {str(e)}")


def _to_items(points, min_score: float, seen_ids: set) -> List[EvidenceItem]:
    """Qdrant points -> EvidenceItem list (dedup 포함)"""
    items: List[EvidenceItem] = []
    for p in points:
        if p.score < min_score:
            continue

        payload = p.payload or {}
        paper_id = payload.get("paper_id", "")
        chunk_id = payload.get("chunk_id", "")
        # chunk_id가 전역 유니크라도 안전하게 paper_id까지 포함해 dedup
        item_id = f"{paper_id}_{chunk_id}"
        if item_id in seen_ids:
            continue

        seen_ids.add(item_id)
        items.append(
            EvidenceItem(
                paper_id=paper_id,
                chunk_id=chunk_id,
                text=payload.get("text", ""),
                score=p.score,
                section_norm=payload.get("section_norm", "") or "",
                topics=payload.get("topics", []) or [],
                pmid=payload.get("pmid"),
                title=payload.get("title"),
            )
        )
    return items


def _diversify_by_section(
    items: List[EvidenceItem],
    top_k: int,
    per_section: int = 2,
) -> List[EvidenceItem]:
    """
    섹션별 다양성 확보:
    1) 섹션별 상위 per_section개를 먼저 뽑고
    2) top_k가 안 채워지면 전체 점수 순으로 남은 아이템으로 채움
    """
    if not items:
        return []

    # 이미 score desc로 정렬되어 들어오는 걸 가정하지 않고, 안전하게 정렬
    items_sorted = sorted(items, key=lambda x: x.score, reverse=True)

    by_section = defaultdict(list)
    for it in items_sorted:
        sec = it.section_norm or "unknown"
        by_section[sec].append(it)

    final_items: List[EvidenceItem] = []
    final_ids = set()

    # 섹션별 상위 per_section개
    for sec, group in by_section.items():
        group_sorted = sorted(group, key=lambda x: x.score, reverse=True)
        for it in group_sorted[:per_section]:
            item_id = f"{it.paper_id}_{it.chunk_id}"
            if item_id in final_ids:
                continue
            final_items.append(it)
            final_ids.add(item_id)

    # 부족하면 전체 상위에서 남은 걸로 채우기
    if len(final_items) < top_k:
        for it in items_sorted:
            if len(final_items) >= top_k:
                break
            item_id = f"{it.paper_id}_{it.chunk_id}"
            if item_id in final_ids:
                continue
            final_items.append(it)
            final_ids.add(item_id)

    # 최종 score desc + top_k
    final_items = sorted(final_items, key=lambda x: x.score, reverse=True)[:top_k]
    return final_items


def qdrant_search(params: QdrantSearchInput) -> QdrantSearchOutput:
    """
    Qdrant에서 관련 근거 검색 (Recall 최우선형 + 섹션 다양성 확보)

    - topics가 있을 때만 1차에서 topics 필터 사용
    - fallback은 "topics 필터를 사용했는데" 결과가 부족/점수 낮을 때만 수행
    - 결과는 섹션별 다양성(per_section=2) 확보 후 top_k 채우기
    """
    client = QdrantClient(url=QDRANT_URL)
    query_embedding = get_embedding(params.query)

    items: List[EvidenceItem] = []
    seen_ids = set()

    # 1차: topics-only (topics가 있을 때만)
    did_use_topic_filter = bool(params.topics)
    query_filter = None

    if did_use_topic_filter:
        query_filter = Filter(
            must=[
                FieldCondition(
                    key="topics",
                    match=MatchAny(any=params.topics),
                )
            ]
        )

    search_results = client.query_points(
        collection_name=QDRANT_COLLECTION,
        query=query_embedding,
        query_filter=query_filter,
        limit=params.candidate_k,
        with_payload=True,
        with_vectors=False,
    )

    items.extend(_to_items(search_results.points, params.min_score, seen_ids))

    best_score = search_results.points[0].score if search_results.points else 0.0

    # fallback은 "topics 필터를 실제로 사용한 경우"에만 고려
    need_fallback = (
        did_use_topic_filter
        and (len(items) < params.top_k or best_score < params.min_score)
    )

    # 2차: no-filter fallback
    if need_fallback:
        fallback_results = client.query_points(
            collection_name=QDRANT_COLLECTION,
            query=query_embedding,
            query_filter=None,
            limit=params.candidate_k,
            with_payload=True,
            with_vectors=False,
        )
        items.extend(_to_items(fallback_results.points, params.min_score, seen_ids))
        search_method = "topics + fallback(no-filter)"
    else:
        search_method = "topics-only" if did_use_topic_filter else "no-filter"

    # 섹션별 분배 + top_k 보장
    items = _diversify_by_section(items, top_k=params.top_k, per_section=2)

    return QdrantSearchOutput(
        items=items,
        total_found=len(items),
        search_method=search_method,
    )


def self_test():
    print("Qdrant 검색 도구 자체 테스트 시작...\n")

    # A) topics 없는 경우: no-filter로만 검색되고 fallback이 돌면 안 됨
    base = QdrantSearchInput(
        query="sun exposure photoaging sunscreen",
        top_k=10,
        section_norm=None,  # 현재 전략에서 사용하지 않음
        topics=None,
        candidate_k=30,
        min_score=0.0,
    )
    base_res = qdrant_search(base)
    print(f"[A] no-topic (no-filter) results: {base_res.total_found}, method={base_res.search_method}")
    for i, it in enumerate(base_res.items[:5], 1):
        print(f"  {i}. score={it.score:.3f}, section={it.section_norm}, topics={it.topics}, id={it.paper_id}:{it.chunk_id}")

    if base_res.total_found == 0:
        print("❌ 필터 없이도 0개면, (1) 컬렉션/데이터 없음 (2) 임베딩/차원 불일치 (3) Qdrant URL 문제")
        return

    # B) 실제 payload에서 topics 1~2개를 뽑아서 topics-only 검색이 잘 되는지 확인
    picked_topics = None
    for it in base_res.items:
        if it.topics:
            picked_topics = it.topics[:2]
            break

    if not picked_topics:
        print("⚠️ 샘플 결과에서 topics를 못 찾았음(데이터 특성). topics-only 테스트를 건너뜁니다.")
        return

    test = QdrantSearchInput(
        query="Does sunscreen prevent photoaging wrinkles pigmentation?",
        top_k=8,
        section_norm=None,
        topics=picked_topics,
        candidate_k=40,
        min_score=0.0,
    )
    res = qdrant_search(test)
    print(f"\n[B] topics-only search: found={res.total_found}, method={res.search_method}, topics={picked_topics}")
    for i, it in enumerate(res.items[:8], 1):
        print(f"  {i}. score={it.score:.3f}, section={it.section_norm}, topics={it.topics}, id={it.paper_id}:{it.chunk_id}")

    # C) fallback 강제: 존재하지 않는 topic을 넣어서 1차를 0에 가깝게 만들고 2차로 건지기
    force_fb = QdrantSearchInput(
        query="photoaging UV sunscreen",
        top_k=8,
        section_norm=None,
        topics=["__nonexistent_topic__"],
        candidate_k=40,
        min_score=0.0,
    )
    fb_res = qdrant_search(force_fb)
    print(f"\n[C] fallback-test: found={fb_res.total_found}, method={fb_res.search_method}")
    for i, it in enumerate(fb_res.items[:8], 1):
        print(f"  {i}. score={it.score:.3f}, section={it.section_norm}, topics={it.topics}, id={it.paper_id}:{it.chunk_id}")


if __name__ == "__main__":
    self_test()
