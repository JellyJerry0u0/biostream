import asyncio
import random

class ImageGenerationService:
    def __init__(self):
        # 나중에 실제 AWS G4dn 인스턴스 IP가 생기면 여기에 기입합니다.
        self.gpu_server_url = "http://your-aws-gpu-ip:8000/generate"

    async def request_aging_simulation(self, lifestyle_id: int, gender: str, target_years: int, habits: dict):
        """
        이미지 생성 요청을 시뮬레이션하는 함수 (Mock)
        """
        # 1. 시뮬레이션 파라미터 계산 (나중에 모델에 전달할 수치들)
        # 예: 흡연 여부와 자외선 노출량에 따라 주름 지표를 0.0 ~ 1.0 사이로 계산
        wrinkle_score = 0.2
        if habits.get("smoking_status") == "current":
            wrinkle_score += 0.4
        if habits.get("uv_exposure_10to16") in [">2h", "1~2h"]:
            wrinkle_score += 0.3
            
        params = {
            "target_age_offset": target_years,
            "gender": gender,
            "wrinkles": min(wrinkle_score, 1.0),
            "pigmentation": random.uniform(0.1, 0.5) # 일단 랜덤값
        }

        print(f"[ImageService] Lifestyle {lifestyle_id}에 대한 이미지 생성 요청 접수")
        print(f"[ImageService] 계산된 파라미터: {params}")

        # 2. 실제로는 여기서 GPU 서버에 비동기 HTTP 요청을 보냅니다.
        # 지금은 GPU가 없으므로 5초간 기다리는 척 합니다.
        await asyncio.sleep(5)

        # 3. 결과물 (지금은 테스트용 샘플 S3 URL 반환)
        # 실제 환경에서는 GPU 서버가 생성 후 S3에 올린 URL을 반환하게 됩니다.
        mock_url = f"https://biostream-bucket.s3.amazonaws.com/generated/future_{lifestyle_id}.png"
        
        return {
            "status": "completed",
            "image_url": mock_url,
            "params": params
        }

# 싱글톤 패턴으로 인스턴스 생성
image_gen_service = ImageGenerationService()