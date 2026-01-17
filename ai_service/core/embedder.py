# 임베딩 모델 설정 및 함수

import os
from dotenv import load_dotenv
from openai import OpenAI

# .env 파일 로드
load_dotenv()

class BioEmbedder:
    def __init__(self):
        # OpenAI 임베딩 모델 사용 (3072차원)
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        self.model = "text-embedding-3-large"

#검색 쿼리나 단일 문서에 사용 
    def embed_text(self, text: str):
        """단일 문장을 벡터로 변환합니다."""
        response = self.client.embeddings.create(
            input=text,
            model=self.model
        )
        return response.data[0].embedding
    
#여러 텍스트를 배치로 임베딩
    def embed_documents(self, texts: list):
        """여러 문서(청크)를 한꺼번에 벡터로 변환합니다."""
        response = self.client.embeddings.create(
            input=texts,
            model=self.model
        )
        return [data.embedding for data in response.data]
    

    #JSON/CSV 데이터를 읽어, text 필드는 백터로 만들고 나머지 25개 필드는 payload로 묶어 Qdrant 포인트 리스트 생성
    def create_qdrant_points(self, data_list: list):
        """
        JSON/CSV 데이터를 받아 Qdrant 포인트 객체 리스트를 생성합니다.
        data_list: [ {'paper_id': '...', 'text': '...', ...}, ... ]
        """
        points = []
        for i, record in enumerate(data_list):
            try:
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
                print(f"레코드 {i} 처리 중 오류: {str(e)}")
                continue
        return points