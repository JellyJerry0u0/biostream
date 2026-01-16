# ai_service/test_search.py
"""
Qdrant 벡터 검색 테스트 스크립트
사용자가 질문을 입력하면 임베딩하여 Qdrant에서 유사한 문서를 검색합니다.
"""

import os
import logging
from qdrant_client import QdrantClient
from core.embedder import BioEmbedder

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_search(query: str, collection_name: str = None, limit: int = 3):
    """
    쿼리를 임베딩하여 Qdrant에서 유사한 문서를 검색합니다.
    """
    if collection_name is None:
        collection_name = os.getenv("COLLECTION_NAME", "biostream_v1")

    # 임베더 및 클라이언트 설정
    embedder = BioEmbedder()
    q_client = QdrantClient(os.getenv("QDRANT_URL", "http://localhost:6333"))

    try:
        # 1. 쿼리 임베딩
        logger.info(f"쿼리 임베딩 중: {query}")
        query_vector = embedder.embed_text(query)

        # 2. Qdrant 검색
        logger.info(f"Qdrant 검색 중 (컬렉션: {collection_name}, 상위 {limit}개)")
        search_results = q_client.query_points(
            collection_name=collection_name,
            query=query_vector,
            limit=limit,
            with_payload=True,
            with_vectors=False  # 벡터 데이터는 제외
        ).points

        # 3. 결과 출력
        logger.info(f"검색 결과 ({len(search_results)}개):")
        for i, result in enumerate(search_results, 1):
            logger.info(f"\n--- 결과 {i} ---")
            logger.info(f"ID: {result.id}")
            logger.info(f"점수 (유사도): {result.score:.4f}")
            logger.info("Payload (메타데이터):")
            for key, value in result.payload.items():
                logger.info(f"  {key}: {value}")

        return search_results

    except Exception as e:
        logger.error(f"검색 중 오류: {str(e)}")
        raise

def interactive_search():
    """
    대화형 검색 모드: 사용자가 질문을 입력하면 검색을 수행합니다.
    """
    print("Qdrant 검색 테스트 모드")
    print("질문을 입력하세요 (종료하려면 'exit' 입력)")
    print("-" * 50)

    while True:
        query = input("질문: ").strip()
        if query.lower() in ['exit', 'quit', 'q']:
            print("검색 테스트를 종료합니다.")
            break

        if not query:
            print("질문을 입력해주세요.")
            continue

        try:
            test_search(query)
        except Exception as e:
            print(f"오류 발생: {e}")

        print("-" * 50)

if __name__ == "__main__":
    import sys

    if len(sys.argv) == 1:
        # 인자가 없으면 대화형 모드
        interactive_search()
    elif len(sys.argv) == 2:
        # 쿼리 하나만 입력
        query = sys.argv[1]
        test_search(query)
    else:
        print("사용법:")
        print("  python test_search.py                    # 대화형 모드")
        print("  python test_search.py '질문 내용'        # 단일 검색")
        sys.exit(1)