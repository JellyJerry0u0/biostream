# ai_service/main.py

import json
import os
import logging
import pandas as pd
from qdrant_client import QdrantClient
from core.embedder import BioEmbedder
from core.vector_store import setup_qdrant_collection

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def load_data(file_path: str):
    """
    JSON, CSV, XLSX 파일을 로드하여 리스트 형태로 반환.
    """
    if file_path.endswith('.json'):
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if isinstance(data, dict):
            data = [data]  # 단일 객체일 경우 리스트로 변환
    elif file_path.endswith('.csv'):
        data = pd.read_csv(file_path).to_dict('records')
    elif file_path.endswith(('.xlsx', '.xls')):
        data = pd.read_excel(file_path).to_dict('records')
    else:
        raise ValueError("지원되지 않는 파일 형식입니다. JSON, CSV, XLSX만 지원합니다.")
    
    # NaN 값들을 None으로 변환 (Qdrant 호환성)
    for record in data:
        for key, value in record.items():
            if pd.isna(value):
                record[key] = None
    
    return data

def validate_data(data: list):
    """
    데이터 검증: 각 레코드에 'text' 필드가 있는지 확인.
    """
    for i, record in enumerate(data):
        if 'text' not in record or not record['text'] or pd.isna(record['text']):
            raise ValueError(f"레코드 {i}에 'text' 필드가 없거나 비어 있습니다.")
    logger.info(f"데이터 검증 완료: {len(data)}개의 레코드")

def run_ingestion(file_path: str):
    try:
        # 1. 데이터 로드
        logger.info(f"데이터 로드 중: {file_path}")
        raw_data = load_data(file_path)

        # 2. 유효한 데이터만 필터링 (text가 있는 레코드만)
        valid_data = [record for record in raw_data if record.get('text') and not pd.isna(record['text'])]
        logger.info(f"유효한 데이터: {len(valid_data)}개 (총 {len(raw_data)}개 중)")

        # 3. 데이터 검증
        validate_data(valid_data)

        # 3. 임베더 및 클라이언트 설정
        embedder = BioEmbedder()
        q_client = QdrantClient(os.getenv("QDRANT_URL", "http://localhost:6333"))
        COLLECTION_NAME = os.getenv("COLLECTION_NAME", "biostream_v1")

        # 4. 컬렉션 세팅 (존재하지 않으면 생성)
        try:
            q_client.get_collection(COLLECTION_NAME)
            logger.info(f"컬렉션 '{COLLECTION_NAME}'이 이미 존재합니다.")
        except:
            logger.info(f"컬렉션 '{COLLECTION_NAME}' 생성 중...")
            setup_qdrant_collection(q_client, COLLECTION_NAME)

        # 5. 포인트 생성 및 업로드 (배치 처리)
        logger.info("임베딩 생성 및 업로드 중...")
        points = embedder.create_qdrant_points(valid_data)
        batch_size = 100  # 배치 크기 조정 가능
        for i in range(0, len(points), batch_size):
            batch = points[i:i + batch_size]
            q_client.upsert(collection_name=COLLECTION_NAME, points=batch)
            logger.info(f"배치 {i//batch_size + 1} 업로드 완료: {len(batch)}개 포인트")

        logger.info(f"성공적으로 {len(points)}개의 데이터를 Qdrant에 적재했습니다.")

    except Exception as e:
        logger.error(f"오류 발생: {str(e)}")
        raise

def view_qdrant_data(collection_name: str = None, limit: int = 5):
    """
    Qdrant에 저장된 데이터를 조회합니다.
    """
    if collection_name is None:
        collection_name = os.getenv("COLLECTION_NAME", "biostream_v1")
    
    q_client = QdrantClient(os.getenv("QDRANT_URL", "http://localhost:6333"))
    
    try:
        # 컬렉션 정보 확인
        collection_info = q_client.get_collection(collection_name)
        logger.info(f"컬렉션 '{collection_name}' 정보: {collection_info}")
        
        # 포인트 조회 (스크롤)
        points, next_page = q_client.scroll(
            collection_name=collection_name,
            limit=limit,
            with_payload=True,
            with_vectors=False  # 벡터는 길어서 제외
        )
        
        logger.info(f"처음 {len(points)}개의 포인트 조회:")
        for point in points:
            logger.info(f"ID: {point.id}, Payload: {point.payload}")
        
        return points
    
    except Exception as e:
        logger.error(f"조회 중 오류: {str(e)}")
        raise

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("사용법: python main.py <명령> [인자]")
        print("명령:")
        print("  ingest <파일_경로>  : 데이터 적재")
        print("  view [컬렉션_이름]   : 데이터 조회 (기본 5개)")
        print("  reset               : 컬렉션 삭제 후 재생성")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "ingest":
        if len(sys.argv) != 3:
            print("사용법: python main.py ingest <파일_경로>")
            sys.exit(1)
        file_path = sys.argv[2]
        run_ingestion(file_path)
    
    elif command == "view":
        collection_name = sys.argv[2] if len(sys.argv) > 2 else None
        view_qdrant_data(collection_name)
    
    elif command == "reset":
        # Qdrant 클라이언트 연결
        client = QdrantClient(url="http://localhost:6333")
        collection_name = "biostream_v1"
        
        # 기존 컬렉션 삭제
        try:
            client.delete_collection(collection_name)
            print(f"✅ 컬렉션 '{collection_name}' 삭제 완료")
        except Exception as e:
            print(f"⚠️ 컬렉션 삭제 실패 (없을 수 있음): {e}")
        
        # 새 컬렉션 생성
        setup_qdrant_collection(client, collection_name)
        print(f"✅ 컬렉션 '{collection_name}' 재생성 완료 (768차원)")
    
    else:
        print(f"알 수 없는 명령: {command}")
        sys.exit(1)