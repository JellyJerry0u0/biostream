"""
Qdrant 데이터 수집 스크립트
biostream_corpus_final.csv를 읽어서 Qdrant에 업로드합니다.
"""

import os
import csv
from typing import List, Dict, Any
from dotenv import load_dotenv
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, CollectionStatus
import google.generativeai as genai

# .env 파일 로드
load_dotenv(override=True)

# 환경 변수
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "biostream_corpus_v1")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
GEMINI_EMBED_MODEL = os.getenv("GEMINI_EMBED_MODEL", "models/gemini-embedding-001")
EMBED_DIM = int(os.getenv("EMBED_DIM", "768"))
CSV_FILE = os.getenv("CORPUS_CSV", "data/biostream_corpus_final.csv")


def get_embedding(text: str, max_retries: int = 3, retry_delay: int = 60) -> List[float]:
    """Gemini API를 사용하여 텍스트 임베딩 생성 (재시도 로직 포함)"""
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
    
    import time
    
    # 모델명에 models/ 접두사 추가 (없는 경우)
    model_name = GEMINI_EMBED_MODEL
    if not model_name.startswith("models/") and not model_name.startswith("tunedModels/"):
        model_name = f"models/{model_name}"
    
    for attempt in range(max_retries):
        try:
            # google-generativeai 또는 google-genai 중 하나 사용
            try:
                genai.configure(api_key=GEMINI_API_KEY)
                result = genai.embed_content(
                    model=model_name,
                    content=text,
                    task_type="retrieval_document"
                )
                embedding = result['embedding']
            except AttributeError:
                # google-genai 패키지 사용 시도
                import google.genai as genai_alt
                genai_alt.configure(api_key=GEMINI_API_KEY)
                result = genai_alt.embed_content(
                    model=model_name,
                    content=text,
                    task_type="retrieval_document"
                )
                embedding = result['embedding']
            
            return embedding
            
        except Exception as e:
            error_str = str(e)
            # 429 에러 (할당량 초과) 처리
            if "429" in error_str or "quota" in error_str.lower() or "Quota exceeded" in error_str:
                if attempt < max_retries - 1:
                    wait_time = retry_delay * (attempt + 1)  # 점진적 대기 시간 증가
                    print(f"⚠️ 할당량 초과 (429). {wait_time}초 대기 후 재시도... ({attempt + 1}/{max_retries})")
                    time.sleep(wait_time)
                    continue
                else:
                    raise Exception(f"할당량 초과: Gemini API 일일 할당량을 초과했습니다. 내일 다시 시도하거나 유료 플랜으로 업그레이드하세요.")
            else:
                # 다른 에러는 즉시 재시도하지 않고 실패
                raise Exception(f"임베딩 생성 실패: {str(e)}")
    
    raise Exception(f"임베딩 생성 실패: 최대 재시도 횟수 초과")


def parse_topics(topics_str: str) -> List[str]:
    """topics 문자열을 리스트로 변환"""
    if not topics_str:
        return []
    
    # 쉼표나 세미콜론으로 구분된 경우 처리
    if "," in topics_str:
        return [t.strip() for t in topics_str.split(",") if t.strip()]
    elif ";" in topics_str:
        return [t.strip() for t in topics_str.split(";") if t.strip()]
    else:
        return [topics_str.strip()] if topics_str.strip() else []


def create_collection_if_not_exists(client: QdrantClient, collection_name: str, actual_dim: int):
    """컬렉션이 없으면 생성 (실제 임베딩 차원 사용)"""
    try:
        collections = client.get_collections().collections
        collection_names = [c.name for c in collections]
        
        if collection_name not in collection_names:
            print(f"컬렉션 '{collection_name}' 생성 중... (차원: {actual_dim})")
            client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(
                    size=actual_dim,
                    distance=Distance.COSINE
                )
            )
            print(f"✅ 컬렉션 '{collection_name}' 생성 완료 (차원: {actual_dim})")
        else:
            print(f"컬렉션 '{collection_name}' 이미 존재합니다.")
    except Exception as e:
        print(f"⚠️ 컬렉션 생성/확인 중 오류: {e}")


def ingest_csv(csv_path: str):
    """CSV 파일을 읽어서 Qdrant에 업로드"""
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {csv_path}")
    
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
    
    # Qdrant 클라이언트 초기화
    client = QdrantClient(url=QDRANT_URL)
    
    # CSV 읽기
    print(f"CSV 파일 읽기 시작: {csv_path}")
    points = []
    batch_size = 100
    actual_dim = None  # 실제 임베딩 차원 (첫 번째 임베딩에서 확인)
    
    # 이미 업로드된 포인트 수 확인
    try:
        collection_info = client.get_collection(QDRANT_COLLECTION)
        existing_count = collection_info.points_count
        print(f"이미 업로드된 포인트: {existing_count}개")
        if existing_count > 0:
            print(f"⚠️ 이미 데이터가 있습니다. 처음부터 다시 시작하려면 컬렉션을 삭제하세요.")
            print(f"   컬렉션 삭제: curl -X DELETE http://localhost:6333/collections/{QDRANT_COLLECTION}")
    except:
        existing_count = 0
    
    # BOM 제거를 위해 utf-8-sig 사용
    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        
        skipped = 0
        for idx, row in enumerate(reader, 1):
            # 이미 처리된 부분 건너뛰기 (할당량 초과로 중단된 경우 재개)
            if existing_count > 0 and idx <= existing_count:
                skipped += 1
                if skipped % 100 == 0:
                    print(f"  [{idx}] 이미 처리된 행 건너뛰는 중... ({skipped}개 건너뜀)")
                continue
            try:
                # 필수 필드 확인
                paper_id = row.get("paper_id", "")
                chunk_id = row.get("chunk_id", "")
                text = row.get("text", "")
                
                if not paper_id or not chunk_id or not text:
                    if idx <= 3:  # 처음 몇 개만 경고
                        print(f"⚠️ 행 {idx}: 필수 필드가 없습니다. 건너뜁니다.")
                    continue
                
                # topics 파싱
                topics = parse_topics(row.get("topics", ""))
                
                # section_norm
                section_norm = row.get("section_norm", "")
                
                # 임베딩 생성 (속도 제한: API 호출 간 0.1초 대기)
                if idx % 10 == 0 or idx <= 5:
                    print(f"  [{idx}] 임베딩 생성 중... (paper_id: {paper_id}, chunk_id: {chunk_id})")
                
                import time
                if idx > 1:  # 첫 번째는 대기 없이
                    time.sleep(0.1)  # API 호출 간 0.1초 대기 (초당 10개 제한)
                
                embedding = get_embedding(text)
                
                # 첫 번째 임베딩에서 실제 차원 확인 및 컬렉션 생성
                if actual_dim is None:
                    actual_dim = len(embedding)
                    if actual_dim != EMBED_DIM:
                        print(f"⚠️ 임베딩 차원이 예상과 다릅니다. 예상: {EMBED_DIM}, 실제: {actual_dim}")
                        print(f"   실제 차원({actual_dim})을 사용합니다.")
                    # 컬렉션 생성/확인 (실제 차원 사용)
                    create_collection_if_not_exists(client, QDRANT_COLLECTION, actual_dim)
                
                # Payload 구성
                payload = {
                    "paper_id": paper_id,
                    "chunk_id": chunk_id,
                    "text": text,
                    "topics": topics,
                    "section_norm": section_norm,
                }
                
                # 선택적 필드 추가
                if "pmid" in row and row["pmid"]:
                    payload["pmid"] = row["pmid"]
                if "title" in row and row["title"]:
                    payload["title"] = row["title"]
                if "license" in row and row["license"]:
                    payload["license"] = row["license"]
                if "source_section" in row and row["source_section"]:
                    payload["source_section"] = row["source_section"]
                
                # Point 생성 (ID는 paper_id_chunk_id 조합 사용)
                point_id = hash(f"{paper_id}_{chunk_id}") % (2**63)  # Qdrant는 int64 ID 사용
                point = PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload=payload
                )
                points.append(point)
                
                # 배치 업로드
                if len(points) >= batch_size:
                    print(f"  배치 업로드 중... ({len(points)}개)")
                    client.upsert(
                        collection_name=QDRANT_COLLECTION,
                        points=points
                    )
                    points = []
                    print(f"  ✅ 배치 업로드 완료")
                
            except Exception as e:
                print(f"⚠️ 행 {idx} 처리 중 오류: {e}")
                continue
        
        # 남은 포인트 업로드
        if points:
            print(f"  마지막 배치 업로드 중... ({len(points)}개)")
            client.upsert(
                collection_name=QDRANT_COLLECTION,
                points=points
            )
            print(f"  ✅ 마지막 배치 업로드 완료")
    
    print(f"✅ CSV 수집 완료: {csv_path}")
    
    # 컬렉션 정보 확인
    collection_info = client.get_collection(QDRANT_COLLECTION)
    print(f"컬렉션 정보:")
    print(f"  - 총 포인트 수: {collection_info.points_count}")
    print(f"  - 벡터 차원: {collection_info.config.params.vectors.size}")


if __name__ == "__main__":
    import sys
    
    csv_path = sys.argv[1] if len(sys.argv) > 1 else CSV_FILE
    
    try:
        ingest_csv(csv_path)
    except Exception as e:
        print(f"❌ 수집 실패: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
