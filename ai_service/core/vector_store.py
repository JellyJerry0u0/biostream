# ai_service/core/vector_store.py
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

def setup_qdrant_collection(client: QdrantClient, collection_name: str):
    # 3072차원, 코사인 유사도 설정 (text-embedding-004 기준)
    client.recreate_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(size=3072, distance=Distance.COSINE),
    )
    
    # 필터링을 자주 할 필드에 인덱스 생성 (성능 최적화)
    client.create_payload_index(collection_name, "paper_id", "keyword")
    client.create_payload_index(collection_name, "topics", "keyword")
    client.create_payload_index(collection_name, "doc_type", "keyword")