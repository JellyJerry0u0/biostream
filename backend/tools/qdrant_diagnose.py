"""
Qdrant 검색 진단 스크립트
Qdrant 컬렉션 설정, 임베딩, payload 구조를 진단합니다.
"""

import os
import sys
from pathlib import Path
from typing import List
from qdrant_client import QdrantClient
import google.generativeai as genai

# .env 파일 로드 (있는 경우)
try:
    from dotenv import load_dotenv
    # backend 디렉토리에서 .env 파일 찾기
    backend_dir = Path(__file__).parent.parent
    env_path = backend_dir / ".env"
    if env_path.exists():
        load_dotenv(env_path)
except ImportError:
    pass  # python-dotenv가 없어도 계속 진행

# 환경 변수에서 설정 읽기
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "biostream_corpus_v1")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
GEMINI_EMBED_MODEL = os.getenv("GEMINI_EMBED_MODEL", "gemini-embedding-001")


def get_embedding(text: str) -> List[float]:
    """Gemini API를 사용하여 텍스트 임베딩 생성 (qdrant_search.py와 동일)"""
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
    
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        result = genai.embed_content(
            model=GEMINI_EMBED_MODEL,
            content=text,
            task_type="retrieval_query"
        )
        embedding = result['embedding']
        return embedding
    except Exception as e:
        raise Exception(f"임베딩 생성 실패: {str(e)}")


def main():
    print("=" * 60)
    print("QDRANT 검색 진단 스크립트")
    print("=" * 60)
    print()
    
    # Qdrant 클라이언트 초기화
    print(f"[설정] QDRANT_URL: {QDRANT_URL}")
    print(f"[설정] QDRANT_COLLECTION: {QDRANT_COLLECTION}")
    print()
    
    try:
        client = QdrantClient(url=QDRANT_URL)
    except Exception as e:
        print(f"❌ Qdrant 클라이언트 연결 실패: {e}")
        return
    
    # [1] Qdrant 컬렉션의 vector size 출력
    print("=" * 60)
    print("[1] QDRANT VECTOR CONFIG")
    print("=" * 60)
    try:
        info = client.get_collection(QDRANT_COLLECTION)
        print("=== QDRANT VECTOR CONFIG ===")
        print(info.config.params.vectors)
        print()
    except Exception as e:
        print(f"❌ 컬렉션 정보 조회 실패: {e}")
        print()
    
    # [2] Gemini 임베딩 길이 출력
    print("=" * 60)
    print("[2] EMBEDDING LENGTH")
    print("=" * 60)
    try:
        emb = get_embedding("test embedding length check")
        print("=== EMBEDDING LENGTH ===")
        print(len(emb))
        print()
    except Exception as e:
        print(f"❌ 임베딩 생성 실패: {e}")
        print()
        return
    
    # [3] 필터 없이 1개 검색해서 payload 키/값 출력
    print("=" * 60)
    print("[3] SAMPLE PAYLOAD (1개 검색)")
    print("=" * 60)
    try:
        res = client.query_points(
            collection_name=QDRANT_COLLECTION,
            query=get_embedding("sun exposure photoaging sunscreen"),
            limit=1,
            with_payload=True,
            with_vectors=False
        )
        
        if not res.points:
            print("❌ 검색 결과가 없습니다.")
            print()
        else:
            p = res.points[0]
            print("=== SAMPLE PAYLOAD KEYS ===")
            print(list(p.payload.keys()))
            print()
            
            print("=== SAMPLE PAYLOAD FULL ===")
            print(p.payload)
            print()
    except Exception as e:
        print(f"❌ 검색 실패: {e}")
        print()
    
    # [4] 필터 없이 20개 검색해서 section_norm / topics 타입 샘플링
    print("=" * 60)
    print("[4] SECTION_NORM / TOPICS SAMPLING (20개 검색)")
    print("=" * 60)
    try:
        base = client.query_points(
            collection_name=QDRANT_COLLECTION,
            query=get_embedding("sun exposure photoaging sunscreen"),
            limit=20,
            with_payload=True,
            with_vectors=False
        )
        
        if not base.points:
            print("❌ 검색 결과가 없습니다.")
            print()
        else:
            secs = set()
            topic_types = set()
            topic_samples = []
            
            for p in base.points:
                pl = p.payload
                secs.add(pl.get("section_norm"))
                t = pl.get("topics")
                topic_types.add(type(t).__name__)
                if t and len(topic_samples) < 5:
                    topic_samples.append(t)
            
            print("=== SECTION_NORM SAMPLES ===")
            print(list(secs))
            print()
            
            print("=== TOPICS TYPE ===")
            print(list(topic_types))
            print()
            
            print("=== TOPICS SAMPLES ===")
            print(topic_samples)
            print()
    except Exception as e:
        print(f"❌ 검색 실패: {e}")
        print()
    
    print("=" * 60)
    print("진단 완료")
    print("=" * 60)


if __name__ == "__main__":
    main()
