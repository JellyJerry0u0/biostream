import os
import httpx
from sqlalchemy.orm import Session
from app.models import Lifestyle

'''
.env루트 (추가해야함)
IMAGE_GENERATION_API_URL=http://your-gpu-ip:8000/generate
IMAGE_GENERATION_API_KEY=your-secret-key
'''
class ImageGenerationService:

    def __init__(self):
        self.gpu_server_url = os.getenv("IMAGE_GENERATION_API_URL")
        self.api_key = os.getenv("IMAGE_GENERATION_API_KEY")

        if not self.gpu_server_url:
            raise ValueError("IMAGE_GENERATION_API_URL not set")

    async def request_aging_simulation(
        self,
        db: Session,
        lifestyle_id: int
    ):
        """
        1. Lifestyle 조회
        2. 노화 점수 계산
        3. GPU 서버 호출
        4. 결과 DB 저장
        """

        # 1️⃣ lifestyle 조회
        lifestyle = db.query(Lifestyle).filter(
            Lifestyle.id == lifestyle_id
        ).first()

        if not lifestyle:
            raise Exception("Lifestyle not found")

        if not lifestyle.image_url:
            raise Exception("Original image not found")

        # 2️⃣ 노화 점수 계산
        aging_score = self._calculate_score(lifestyle)

        # 3️⃣ GPU 서버 호출
        payload = {
            "image_url": lifestyle.image_url,
            "aging_strength": aging_score
        }

        headers = {}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        async with httpx.AsyncClient(timeout=120) as client:
            response = await client.post(
                self.gpu_server_url,
                json=payload,
                headers=headers
            )

        response.raise_for_status()
        result = response.json()

        output_url = result.get("output_url")
        if not output_url:
            raise Exception("GPU server did not return output_url")

        # 4️⃣ 결과 DB 저장
        lifestyle.aged_image_url = output_url
        db.commit()

        return {"output_url": output_url}

    def _calculate_score(self, lifestyle):
        """
        설문 데이터를 기반으로 노화 강도 계산 (0.0 ~ 1.0)
        """

        score = 0.2  # 기본 노화값

        # 흡연
        if lifestyle.smoking == "current":
            score += 0.4

        # 자외선 노출
        if lifestyle.UV in ["1~2h", ">2h"]:
            score += 0.3

        # 수면 부족
        if lifestyle.sleep in ["<5h", "5~6h"]:
            score += 0.2

        # 최대 1.0 제한
        return min(score, 1.0)


image_service = ImageGenerationService()
