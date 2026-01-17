# ai_service/evaluate_retrieval.py
"""
RAG 검색(리트리벌) 성능 평가 스크립트 (객관 지표 기반 + topic 제한 + Gemini query 분리)

데이터셋 스키마(엑셀):
- section_chunk: 검색 대상 문서(corpus)
- evidence_card / plain_summary: 검색 쿼리(query)
- source_chunk_id: 쿼리가 "원래 근거로 삼는" section_chunk의 chunk_id (정답)

평가 방식:
1) section_chunk의 text를 임베딩하여 코퍼스 벡터 생성
2) evidence_card/plain_summary의 text를 임베딩하여 쿼리 벡터 생성
3) 코사인 유사도로 문서 랭킹
4) 정답(source_chunk_id)이 Top-K에 포함되는지 평가
   - Recall@K (Hit@K와 동일: 정답이 1개인 세팅)
   - MRR@K
   - nDCG@K (정답 1개인 세팅에서 표준적으로 사용 가능)

추가 기능(이 버전의 핵심):
- Gemini 임베딩: 문서(embed_documents) / 쿼리(embed_query) 분리
- 평가 난이도 상승: 후보 코퍼스를 "같은 topic"으로 제한
  * query topics ∩ doc topics != ∅ 인 문서만 후보
  * query topics가 비었거나 후보가 0개면 전체 코퍼스로 fallback(옵션으로 끌 수 있음)
  * ⚠️ 중요한 보정: topic 제한으로 정답이 후보에서 빠질 수 있으므로,
    정답이 후보에 없으면 "평가 가능"하도록 정답 문서를 후보에 강제로 포함
    (랭킹은 여전히 유사도로 결정됨 → 공정성 유지 + mean_answer_rank=inf 방지)

출력:
- retrieval_eval_per_query.csv : 쿼리별 지표/메타
- retrieval_eval_overall.json  : 전체 평균 지표
- 콘솔: 전체 요약 + 언어별/토픽별 + 후보 문서 분포

사용 예시:
- 기본(추천): Gemini + topic 제한
  python ai_service/evaluate_retrieval.py --xlsx /path/to/RAG_qc2.xlsx

- OpenAI로 비교:
  python ai_service/evaluate_retrieval.py --xlsx ... --embed-backend openai --openai-embed-model text-embedding-004

- topic 제한 끄기:
  python ai_service/evaluate_retrieval.py --xlsx ... --no-topic-filter

- fallback 끄기(토픽 없는/불일치 쿼리 제외):
  python ai_service/evaluate_retrieval.py --xlsx ... --no-fallback
"""

from __future__ import annotations

import os
import json
import math
import hashlib
import argparse
from dataclasses import dataclass
from typing import Dict, List, Tuple, Set

import numpy as np
import pandas as pd
from dotenv import load_dotenv

# -----------------------------
# 0) 환경변수 로드
# -----------------------------
load_dotenv()


# -----------------------------
# 1) 임베딩 백엔드
# -----------------------------
class Embedder:
    """
    임베딩 백엔드 인터페이스.
    - embed_texts: 문서(corpus) 임베딩
    - embed_queries: 쿼리(query) 임베딩 (기본은 문서와 동일, 필요 시 override)
    """
    name: str = "embedder"

    def embed_texts(self, texts: List[str]) -> np.ndarray:
        raise NotImplementedError

    def embed_queries(self, texts: List[str]) -> np.ndarray:
        return self.embed_texts(texts)


def _l2_normalize(x: np.ndarray, eps: float = 1e-12) -> np.ndarray:
    """
    코사인 유사도 계산을 위해 임베딩을 L2 정규화.
    정규화가 되어 있으면 dot(query, doc) == cosine similarity
    """
    norms = np.linalg.norm(x, axis=1, keepdims=True)
    norms = np.maximum(norms, eps)
    return x / norms


class SentenceTransformerEmbedder(Embedder):
    """
    로컬 임베딩 백엔드 (sentence-transformers)
    """
    def __init__(self, model_name: str = "sentence-transformers/all-MiniLM-L6-v2", batch_size: int = 64):
        from sentence_transformers import SentenceTransformer  # lazy import
        self.model = SentenceTransformer(model_name)
        self.batch_size = batch_size
        self.name = f"st__{model_name}"

    def embed_texts(self, texts: List[str]) -> np.ndarray:
        vecs = self.model.encode(
            texts,
            batch_size=self.batch_size,
            normalize_embeddings=True,  # 이미 정규화
            show_progress_bar=True
        )
        return np.asarray(vecs, dtype=np.float32)


class OpenAIEmbedder(Embedder):
    """
    OpenAI 임베딩 백엔드
    - OPENAI_API_KEY 필요
    """
    def __init__(self, model: str = "text-embedding-004", batch_size: int = 128):
        from openai import OpenAI  # official SDK
        self.client = OpenAI()
        self.model = model
        self.batch_size = batch_size
        self.name = f"openai__{model}"

    def embed_texts(self, texts: List[str]) -> np.ndarray:
        all_vecs: List[List[float]] = []
        safe_texts = [t if (t and t.strip()) else " " for t in texts]

        for i in range(0, len(safe_texts), self.batch_size):
            batch = safe_texts[i:i + self.batch_size]
            resp = self.client.embeddings.create(model=self.model, input=batch)
            all_vecs.extend([item.embedding for item in resp.data])

        vecs = np.asarray(all_vecs, dtype=np.float32)
        return _l2_normalize(vecs)


class GeminiEmbedder(Embedder):
    """
    Gemini 임베딩 백엔드 (LangChain wrapper)
    - GOOGLE_API_KEY 필요
    - 문서: embed_documents
    - 쿼리: embed_query  (중요: query/document 인코딩이 다를 수 있으므로 분리)
    """
    def __init__(self, model: str = "models/gemini-embedding-001", batch_size: int = 64):
        from langchain_google_genai import GoogleGenerativeAIEmbeddings  # lazy import

        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            raise ValueError("GOOGLE_API_KEY가 없습니다. .env 또는 환경변수에 설정하세요.")

        self.model = model
        self.batch_size = batch_size
        self.embeddings = GoogleGenerativeAIEmbeddings(model=self.model, google_api_key=api_key)
        self.name = f"gemini__{model}"

    def embed_texts(self, texts: List[str]) -> np.ndarray:
        """
        문서(corpus) 임베딩: embed_documents (배치 가능)
        """
        safe_texts = [t if (t and t.strip()) else " " for t in texts]
        all_vecs: List[List[float]] = []

        for i in range(0, len(safe_texts), self.batch_size):
            batch = safe_texts[i:i + self.batch_size]
            vecs = self.embeddings.embed_documents(batch)
            all_vecs.extend(vecs)

        arr = np.asarray(all_vecs, dtype=np.float32)
        return _l2_normalize(arr)

    def embed_queries(self, texts: List[str]) -> np.ndarray:
        """
        쿼리(query) 임베딩: embed_query (보통 단건 API)
        """
        safe_texts = [t if (t and t.strip()) else " " for t in texts]
        all_vecs: List[List[float]] = []

        for t in safe_texts:
            v = self.embeddings.embed_query(t)
            all_vecs.append(v)

        arr = np.asarray(all_vecs, dtype=np.float32)
        return _l2_normalize(arr)


# -----------------------------
# 2) 데이터 로드 & 평가 세팅
# -----------------------------
@dataclass
class EvalConfig:
    xlsx_path: str
    cache_dir: str = ".cache_embeddings"
    use_doc_types_as_query: Tuple[str, ...] = ("evidence_card", "plain_summary")
    use_doc_types_as_corpus: Tuple[str, ...] = ("section_chunk",)
    ks: Tuple[int, ...] = (1, 3, 5, 10)

    # ✅ 난이도 상승 옵션: topic으로 후보 코퍼스 제한
    restrict_corpus_by_topic: bool = True
    # topics가 비어있거나 매칭이 0개일 때 fallback을 허용할지
    allow_fallback_to_all_corpus: bool = True
    # ✅ topic 제한으로 정답이 후보에서 누락되는 경우를 보정할지
    force_include_answer_in_candidates: bool = True


def _safe_text(x) -> str:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return ""
    return str(x).strip()


def _parse_topics(raw: str) -> Set[str]:
    """
    topics 컬럼을 토큰 집합으로 파싱.
    - 쉼표/세미콜론/파이프/슬래시 등으로 대충 분리
    - 소문자화, 공백 제거
    """
    s = _safe_text(raw).lower()
    if not s:
        return set()

    for sep in [";", "|", "/", "\\", "\n", "\t"]:
        s = s.replace(sep, ",")

    tokens = [t.strip() for t in s.split(",") if t.strip()]
    return set(tokens)


def load_dataset(cfg: EvalConfig) -> pd.DataFrame:
    df = pd.read_excel(cfg.xlsx_path)

    required = {"doc_type", "chunk_id", "source_chunk_id", "text"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"엑셀에 필요한 컬럼이 없습니다: {sorted(missing)}")

    df["text"] = df["text"].apply(_safe_text)
    df["chunk_id"] = df["chunk_id"].apply(_safe_text)
    df["source_chunk_id"] = df["source_chunk_id"].apply(_safe_text)

    if "topics" not in df.columns:
        df["topics"] = ""

    return df


def build_corpus_and_queries(df: pd.DataFrame, cfg: EvalConfig) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    - corpus_df: section_chunk만 (문서 + 메타)
    - query_df : evidence_card/plain_summary만 (쿼리 + 메타 + 정답)
    """
    corpus_df = df[df["doc_type"].isin(cfg.use_doc_types_as_corpus)].copy()
    query_df = df[df["doc_type"].isin(cfg.use_doc_types_as_query)].copy()

    corpus_df = corpus_df[corpus_df["chunk_id"].astype(bool) & corpus_df["text"].astype(bool)].copy()
    query_df = query_df[
        query_df["chunk_id"].astype(bool) &
        query_df["text"].astype(bool) &
        query_df["source_chunk_id"].astype(bool)
    ].copy()

    if corpus_df.empty:
        raise ValueError("corpus가 비어있습니다. section_chunk가 있는지 확인하세요.")
    if query_df.empty:
        raise ValueError("queries가 비어있습니다. evidence_card/plain_summary 및 source_chunk_id 링크를 확인하세요.")

    corpus_ids = set(corpus_df["chunk_id"].tolist())
    query_df = query_df[query_df["source_chunk_id"].isin(corpus_ids)].copy()

    if query_df.empty:
        raise ValueError("정답(source_chunk_id)이 corpus에 존재하는 query가 없습니다. 링크 규칙을 확인하세요.")

    return corpus_df, query_df


# -----------------------------
# 3) 임베딩 캐시
# -----------------------------
def _fingerprint_texts(texts: List[str], extra: str = "") -> str:
    h = hashlib.sha256()
    h.update(extra.encode("utf-8"))
    for t in texts:
        h.update(t.encode("utf-8"))
        h.update(b"\n")
    return h.hexdigest()[:16]


def _save_npz(path: str, emb: np.ndarray) -> None:
    np.savez_compressed(path, emb=emb)


def _load_npz(path: str) -> np.ndarray:
    data = np.load(path)
    return data["emb"]


def embed_docs_with_cache(embedder: Embedder, doc_texts: List[str], cache_dir: str, cache_key: str) -> np.ndarray:
    os.makedirs(cache_dir, exist_ok=True)
    cache_path = os.path.join(cache_dir, f"{cache_key}.npz")
    if os.path.exists(cache_path):
        return _load_npz(cache_path)

    emb = embedder.embed_texts(doc_texts)
    _save_npz(cache_path, emb)
    return emb


def embed_queries_with_cache(embedder: Embedder, query_texts: List[str], cache_dir: str, cache_key: str) -> np.ndarray:
    os.makedirs(cache_dir, exist_ok=True)
    cache_path = os.path.join(cache_dir, f"{cache_key}.npz")
    if os.path.exists(cache_path):
        return _load_npz(cache_path)

    emb = embedder.embed_queries(query_texts)
    _save_npz(cache_path, emb)
    return emb


# -----------------------------
# 4) 검색 & 평가 메트릭
# -----------------------------
def rank_docs(sim_row: np.ndarray, doc_ids: List[str]) -> List[str]:
    idx = np.argsort(-sim_row)
    return [doc_ids[i] for i in idx]


def metrics_for_one_query(ranked: List[str], answer: str, ks: Tuple[int, ...]) -> Dict[str, float]:
    """
    정답 1개인 세팅에서 표준 지표.
    """
    out: Dict[str, float] = {}
    try:
        rank = ranked.index(answer) + 1  # 1-based
    except ValueError:
        rank = None

    for k in ks:
        hit = 1.0 if (rank is not None and rank <= k) else 0.0
        out[f"recall@{k}"] = hit

        if hit == 1.0:
            out[f"mrr@{k}"] = 1.0 / rank
            out[f"ndcg@{k}"] = 1.0 / math.log2(rank + 1)
        else:
            out[f"mrr@{k}"] = 0.0
            out[f"ndcg@{k}"] = 0.0

    out["answer_rank"] = float(rank) if rank is not None else float("inf")
    return out


def aggregate_metrics(rows: List[Dict[str, float]]) -> Dict[str, float]:
    keys = [k for k in rows[0].keys() if k != "answer_rank"]
    out = {k: float(np.mean([r[k] for r in rows])) for k in keys}
    out["mean_answer_rank"] = float(np.mean([r["answer_rank"] for r in rows]))
    out["median_answer_rank"] = float(np.median([r["answer_rank"] for r in rows]))
    return out


# -----------------------------
# 5) Topic 제한 로직
# -----------------------------
def _build_topic_to_doc_indices(corpus_topics: List[Set[str]]) -> Dict[str, List[int]]:
    mapping: Dict[str, List[int]] = {}
    for i, tset in enumerate(corpus_topics):
        for tok in tset:
            mapping.setdefault(tok, []).append(i)
    return mapping


def _select_candidate_indices_by_topic(
    query_topic_tokens: Set[str],
    topic_to_doc_indices: Dict[str, List[int]],
    total_docs: int,
    allow_fallback: bool
) -> List[int]:
    """
    query topics와 겹치는 문서 인덱스 후보 선택 (union).
    - query topics 비면 fallback/빈 리스트
    - 후보 0개면 fallback/빈 리스트
    """
    if not query_topic_tokens:
        return list(range(total_docs)) if allow_fallback else []

    cand: Set[int] = set()
    for tok in query_topic_tokens:
        cand.update(topic_to_doc_indices.get(tok, []))

    if not cand:
        return list(range(total_docs)) if allow_fallback else []

    return sorted(cand)


# -----------------------------
# 6) 평가
# -----------------------------
def evaluate(
    embedder: Embedder,
    corpus_df: pd.DataFrame,
    query_df: pd.DataFrame,
    cfg: EvalConfig
) -> Tuple[pd.DataFrame, Dict[str, float]]:
    """
    반환:
    - per-query 결과 DataFrame
    - overall metrics dict
    """
    # corpus 준비
    doc_ids = corpus_df["chunk_id"].tolist()
    doc_texts = corpus_df["text"].tolist()
    doc_topics = [_parse_topics(x) for x in corpus_df.get("topics", "").tolist()]

    topic_to_doc_indices = _build_topic_to_doc_indices(doc_topics)

    # queries 준비
    query_ids = query_df["chunk_id"].tolist()
    query_texts = query_df["text"].tolist()
    query_answers = query_df["source_chunk_id"].tolist()
    query_topics = [_parse_topics(x) for x in query_df.get("topics", "").tolist()]

    # 임베딩(전체 코퍼스/전체 쿼리) 1회 생성 + 캐시
    doc_fp = _fingerprint_texts(doc_texts, extra=f"docs::{embedder.name}")
    q_fp = _fingerprint_texts(query_texts, extra=f"queries::{embedder.name}")

    doc_emb = embed_docs_with_cache(embedder, doc_texts, cfg.cache_dir, f"doc_{doc_fp}")
    q_emb = embed_queries_with_cache(embedder, query_texts, cfg.cache_dir, f"qry_{q_fp}")

    per_rows: List[Dict] = []
    metric_rows: List[Dict[str, float]] = []

    # doc id -> index (정답 후보 강제 포함을 빠르게)
    doc_id_to_index = {cid: i for i, cid in enumerate(doc_ids)}

    for qi in range(len(query_texts)):
        answer_id = query_answers[qi]

        # 1) topic 제한 후보 선택
        if cfg.restrict_corpus_by_topic:
            cand_indices = _select_candidate_indices_by_topic(
                query_topics[qi],
                topic_to_doc_indices,
                total_docs=len(doc_ids),
                allow_fallback=cfg.allow_fallback_to_all_corpus
            )
        else:
            cand_indices = list(range(len(doc_ids)))

        # 후보가 비면 평가 불가(옵션에 의해 fallback도 꺼진 케이스)
        if not cand_indices:
            continue

        # 2) (중요) 정답이 후보에서 누락되면 강제로 후보에 포함
        if cfg.force_include_answer_in_candidates:
            ans_idx = doc_id_to_index.get(answer_id, None)
            if ans_idx is not None and ans_idx not in cand_indices:
                cand_indices = sorted(set(cand_indices + [ans_idx]))

        cand_doc_ids = [doc_ids[i] for i in cand_indices]
        cand_doc_emb = doc_emb[cand_indices]  # (Ncand, D)

        # 3) 후보 문서에 대해서만 유사도 계산
        sim_row = np.matmul(q_emb[qi:qi + 1], cand_doc_emb.T).reshape(-1)  # (Ncand,)
        ranked_doc_ids = rank_docs(sim_row, cand_doc_ids)

        # 4) 메트릭
        m = metrics_for_one_query(ranked_doc_ids, answer_id, cfg.ks)

        row = {
            "qid": query_ids[qi],
            "answer_chunk_id": answer_id,
            "answer_rank": m["answer_rank"],
            "candidate_docs": len(cand_doc_ids),
            "topics": _safe_text(query_df.iloc[qi].get("topics", "")),
            "language": _safe_text(query_df.iloc[qi].get("language", "")),
            "paper_id": _safe_text(query_df.iloc[qi].get("paper_id", "")),
            "title": _safe_text(query_df.iloc[qi].get("title", "")),
            "year": query_df.iloc[qi].get("year", None),
            "evidence_level": query_df.iloc[qi].get("evidence_level", None),
            "effect_direction": _safe_text(query_df.iloc[qi].get("effect_direction", "")),
        }
        for k in cfg.ks:
            row[f"recall@{k}"] = m[f"recall@{k}"]
            row[f"mrr@{k}"] = m[f"mrr@{k}"]
            row[f"ndcg@{k}"] = m[f"ndcg@{k}"]

        per_rows.append(row)
        metric_rows.append(m)

    if not per_rows:
        raise ValueError("평가 결과가 비었습니다. (후보 코퍼스가 비거나 데이터가 필터링됨)")

    per_df = pd.DataFrame(per_rows)
    overall = aggregate_metrics(metric_rows)
    overall["avg_candidate_docs"] = float(per_df["candidate_docs"].mean())

    return per_df, overall


# -----------------------------
# 7) 실행 진입점
# -----------------------------
def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--xlsx",
        type=str,
        default=os.path.join(os.path.dirname(__file__), "sample_dataset.xlsx"),
        help="엑셀 데이터셋 경로"
    )

    parser.add_argument(
        "--embed-backend",
        type=str,
        default="gemini",
        choices=["openai", "gemini", "st"],
        help="임베딩 백엔드 선택 (기본: gemini)"
    )

    # OpenAI
    parser.add_argument("--openai-embed-model", type=str, default="text-embedding-004")
    parser.add_argument("--openai-batch-size", type=int, default=128)

    # Gemini
    parser.add_argument("--gemini-embed-model", type=str, default="models/gemini-embedding-001")
    parser.add_argument("--gemini-batch-size", type=int, default=64)

    # SentenceTransformer
    parser.add_argument("--st-model", type=str, default="sentence-transformers/all-MiniLM-L6-v2")
    parser.add_argument("--st-batch-size", type=int, default=64)

    # Eval settings
    parser.add_argument("--cache-dir", type=str, default=".cache_embeddings")
    parser.add_argument("--out-csv", type=str, default="retrieval_eval_per_query.csv")
    parser.add_argument("--out-json", type=str, default="retrieval_eval_overall.json")
    parser.add_argument("--ks", type=str, default="1,3,5,10")

    # ✅ topic 제한 옵션 (베이스라인에서는 기본 OFF)
    parser.add_argument("--topic-filter", action="store_true", help="topic 제한 ON (기본: OFF)")
    parser.add_argument("--fallback", action="store_true", help="topic 후보 0개일 때 전체 코퍼스 fallback ON (기본: OFF)")
    parser.add_argument("--force-include-answer", action="store_true", help="정답 강제 포함 ON (기본: OFF)")

    args = parser.parse_args()

    ks = tuple(int(x.strip()) for x in args.ks.split(",") if x.strip())

    cfg = EvalConfig(
        xlsx_path=args.xlsx,
        cache_dir=args.cache_dir,
        ks=ks,
        restrict_corpus_by_topic=args.topic_filter,
        allow_fallback_to_all_corpus=args.fallback,
        force_include_answer_in_candidates=args.force_include_answer,
    )

    df = load_dataset(cfg)
    # 데이터 연결성(정답 링크) 확인용 베이스라인 카운트
    total_docs = int(df["doc_type"].isin(cfg.use_doc_types_as_corpus).sum())
    total_queries = int(df["doc_type"].isin(cfg.use_doc_types_as_query).sum())

    corpus_df, query_df = build_corpus_and_queries(df, cfg)
    print(f"[Dataset] corpus: {len(corpus_df)}/{total_docs}, queries: {len(query_df)}/{total_queries}")

    # 임베더 선택
    if args.embed_backend == "openai":
        embedder = OpenAIEmbedder(model=args.openai_embed_model, batch_size=args.openai_batch_size)
    elif args.embed_backend == "gemini":
        embedder = GeminiEmbedder(model=args.gemini_embed_model, batch_size=args.gemini_batch_size)
    else:
        embedder = SentenceTransformerEmbedder(model_name=args.st_model, batch_size=args.st_batch_size)

    # 평가 실행
    per_df, overall = evaluate(embedder, corpus_df, query_df, cfg)

    # 저장
    per_df.to_csv(args.out_csv, index=False, encoding="utf-8-sig")
    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump(overall, f, ensure_ascii=False, indent=2)

    # 콘솔 출력 (요약)
    print("\n====================")
    print("RAG Retrieval Eval (Overall)")
    print("====================")
    for k, v in overall.items():
        if isinstance(v, float):
            print(f"{k:>18}: {v:.4f}")
        else:
            print(f"{k:>18}: {v}")

    # 언어별 평균 recall@5
    k_show = 5 if 5 in ks else ks[min(2, len(ks) - 1)]
    col = f"recall@{k_show}"

    if "language" in per_df.columns and col in per_df.columns:
        print(f"\n--- By language (avg {col}) ---")
        per_df["language"] = per_df["language"].replace("", "unknown")
        print(per_df.groupby("language")[col].mean().to_string())

    # 토픽별 평균 recall@5 (보너스)
    if "topics" in per_df.columns and col in per_df.columns:
        print(f"\n--- By topics (avg {col}) ---")
        per_df["topics"] = per_df["topics"].replace("", "unknown")
        print(per_df.groupby("topics")[col].mean().sort_values(ascending=False).head(20).to_string())

    # 후보 코퍼스 크기 분포 (topic 제한 난이도 확인)
    if "candidate_docs" in per_df.columns:
        print("\n--- Candidate docs stats ---")
        print(per_df["candidate_docs"].describe().to_string())


if __name__ == "__main__":
    main()
