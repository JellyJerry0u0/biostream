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
    JSON 또는 CSV 파일을 로드하여 리스트 of dict 형태로 반환.
    """
    if file_path.endswith('.json'):
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if isinstance(data, dict):
            data = [data]  # 단일 객체일 경우 리스트로 변환
    elif file_path.endswith('.csv'):
        data = pd.read_csv(file_path).to_dict('records')
    else:
        raise ValueError("지원되지 않는 파일 형식입니다. JSON 또는 CSV만 지원합니다.")
    return data

def validate_data(data: list):
    """
    데이터 검증: 각 레코드에 'text' 필드가 있는지 확인.
    """
    for i, record in enumerate(data):
        if 'text' not in record or not record['text']:
            raise ValueError(f"레코드 {i}에 'text' 필드가 없거나 비어 있습니다.")
    logger.info(f"데이터 검증 완료: {len(data)}개의 레코드")

def run_ingestion(file_path: str):
    try:
        # 1. 데이터 로드
        logger.info(f"데이터 로드 중: {file_path}")
        raw_data = load_data(file_path)

        # 2. 데이터 검증
        validate_data(raw_data)

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
        points = embedder.create_qdrant_points(raw_data)
        batch_size = 100  # 배치 크기 조정 가능
        for i in range(0, len(points), batch_size):
            batch = points[i:i + batch_size]
            q_client.upsert(collection_name=COLLECTION_NAME, points=batch)
            logger.info(f"배치 {i//batch_size + 1} 업로드 완료: {len(batch)}개 포인트")

        logger.info(f"성공적으로 {len(points)}개의 데이터를 Qdrant에 적재했습니다.")

    except Exception as e:
        logger.error(f"오류 발생: {str(e)}")
        raise

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("사용법: python main.py <파일_경로>")
        print("예: python main.py sample_dataset.json")
        sys.exit(1)
    
    file_path = sys.argv[1]
    run_ingestion(file_path)