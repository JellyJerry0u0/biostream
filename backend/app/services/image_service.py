import os
from typing import Optional, Dict, Any
from urllib.parse import urlparse

import httpx
from sqlalchemy.orm import Session

from app.models import Lifestyle
from app.database import SessionLocal

'''
.env루트 (추가해야함)
IMAGE_GENERATION_API_URL=http://your-gpu-ip:8000/generate
IMAGE_GENERATION_API_KEY=your-secret-key
'''
class ImageGenerationService:

    def __init__(self):
        self.gpu_server_url = os.getenv("IMAGE_GENERATION_API_URL")
        self.api_key = os.getenv("IMAGE_GENERATION_API_KEY")
        self.enabled = bool(self.gpu_server_url)

    async def request_aging_simulation(
        self,
        lifestyle_id: int,
        user_id: Optional[int] = None,
        db: Optional[Session] = None,
        gender: Optional[str] = None,
        target_years: Optional[int] = None,
        habits: Optional[Dict[str, Any]] = None,
    ):
        if not self.enabled:
            raise Exception("IMAGE_GENERATION_API_URL not set")

        owns_session = db is None
        if db is None:
            db = SessionLocal()

        try:
            query = db.query(Lifestyle).filter(Lifestyle.id == lifestyle_id)
            if user_id is not None:
                query = query.filter(Lifestyle.user_id == user_id)
            lifestyle = query.first()

            if not lifestyle:
                raise Exception("Lifestyle not found")

            source_image_url = lifestyle.original_image_url
            if not source_image_url:
                raise Exception("Original image not found")

            effective_habits = habits or {
                "smoking_status": lifestyle.smoking_status,
                "uv_exposure_10to16": lifestyle.uv_exposure_10to16,
                "drinking_days_per_week": lifestyle.drinking_days_per_week,
                "sleep_hours_weekday": lifestyle.sleep_hours_weekday,
                "stress_score": lifestyle.stress_score,
            }

            effective_gender = gender or (lifestyle.owner.gender if lifestyle.owner else None)
            effective_target_years = target_years or lifestyle.target_years or 30

            aging_score = self._calculate_score(effective_habits)

            payload = {
                "image_url": source_image_url,
                "aging_strength": aging_score,
                "gender": effective_gender,
                "target_years": effective_target_years,
                "habits": effective_habits,
            }
            output_url = await self._request_legacy_gpu_image(payload)

            lifestyle.generated_image_url = output_url
            db.commit()

            return {
                "output_url": output_url,
                "image_url": output_url,
                "status": "completed",
                "params": {
                    "aging_strength": aging_score,
                    "gender": effective_gender,
                    "target_years": effective_target_years,
                    "habits": effective_habits,
                },
            }
        except httpx.ConnectError as e:
            host = urlparse(self.gpu_server_url).hostname if self.gpu_server_url else None
            raise Exception(
                f"이미지 생성 서버 연결 실패 (host={host}, url={self.gpu_server_url}): {e}"
            ) from e
        except httpx.RequestError as e:
            host = urlparse(self.gpu_server_url).hostname if self.gpu_server_url else None
            raise Exception(
                f"이미지 생성 요청 실패 (host={host}, url={self.gpu_server_url}): {e}"
            ) from e
        finally:
            if owns_session and db is not None:
                db.close()

    async def _request_legacy_gpu_image(self, payload: Dict[str, Any]) -> str:
        if not self.gpu_server_url:
            raise Exception("Legacy 이미지 서버 URL이 비어 있습니다.")

        headers = {}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        async with httpx.AsyncClient(timeout=120) as client:
            response = await client.post(
                self.gpu_server_url,
                json=payload,
                headers=headers,
            )
        response.raise_for_status()
        result = response.json()
        output_url = result.get("output_url") or result.get("image_url")
        if not output_url:
            raise Exception("GPU 서버 응답에 output_url/image_url이 없습니다.")
        return output_url

    def _calculate_score(self, habits: Dict[str, Any]) -> float:
        score = 0.2

        if habits.get("smoking_status") == "current":
            score += 0.25

        uv_exposure = habits.get("uv_exposure_10to16")
        if uv_exposure in ["1~2h", ">2h"]:
            score += 0.2

        sleep_hours = habits.get("sleep_hours_weekday")
        try:
            if sleep_hours is not None and float(sleep_hours) < 6:
                score += 0.15
        except (TypeError, ValueError):
            pass

        stress_score = habits.get("stress_score")
        try:
            if stress_score is not None and float(stress_score) >= 7:
                score += 0.1
        except (TypeError, ValueError):
            pass

        drinking = habits.get("drinking_days_per_week")
        if drinking in ["4-5", "6-7", "4~5", "6~7"]:
            score += 0.1

        return min(max(score, 0.0), 1.0)


image_service = ImageGenerationService()
image_gen_service = image_service
