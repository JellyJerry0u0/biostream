# 임베딩 모델 설정 및 함수

import os
from dotenv import load_dotenv
import google.generativeai as genai
from qdrant_client.models import PointStruct

# .env 파일 로드
load_dotenv()

class BioEmbedder:
    def __init__(self):
        # Google Generative AI SDK 직접 사용 (768차원)
        genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
        self.model_name = "models/text-embedding-004"  # 768차원 모델

#검색 쿼리나 단일 문서에 사용 
    def embed_text(self, text: str):
        """단일 문장을 벡터로 변환합니다 (768차원)."""
        result = genai.embed_content(
            model=self.model_name,
            content=text,
            task_type="retrieval_document"
        )
        return result['embedding']
    
#여러 텍스트를 배치로 임베딩
    def embed_documents(self, texts: list):
        """여러 문서(청크)를 한꺼번에 벡터로 변환합니다 (768차원)."""
        embeddings = []
        for text in texts:
            result = genai.embed_content(
                model=self.model_name,
                content=text,
                task_type="retrieval_document"
            )
            embeddings.append(result['embedding'])
        return embeddings
    

    #JSON/CSV 데이터를 읽어, text 필드는 백터로 만들고 나머지 25개 필드는 payload로 묶어 Qdrant 포인트 리스트 생성
    def create_qdrant_points(self, data_list: list):
        """
        JSON/CSV 데이터를 받아 Qdrant 포인트 객체 리스트를 생성합니다.
        data_list: [ {'paper_id': '...', 'text': '...', ...}, ... ]
        """
        import logging
        logger = logging.getLogger(__name__)
        
        points = []
        total = len(data_list)
        for i, record in enumerate(data_list):
            try:
                # 진행률 로그 (100개마다)
                if (i + 1) % 100 == 0 or i == 0:
                    logger.info(f"임베딩 진행 중: {i+1}/{total} ({(i+1)/total*100:.1f}%)")
                
                # 1. 'text' 필드만 추출하여 임베딩 (핵심 지식)
                vector = self.embed_text(record['text'])
                
                # 2. 나머지 모든 필드는 payload(메타데이터)로 처리
                payload = {k: v for k, v in record.items() if k != 'text'}
                
                # 3. Qdrant 포인트 생성 (ID는 record의 'id' 필드 또는 인덱스 사용)
                point_id = record.get('id', i)
                points.append(PointStruct(
                    id=point_id,
                    vector=vector,
                    payload=payload
                ))
            except Exception as e:
                logger.error(f"레코드 {i} 처리 중 오류: {str(e)}")
                continue
        
        logger.info(f"✅ 임베딩 완료: 총 {len(points)}개 포인트 생성")
        return points