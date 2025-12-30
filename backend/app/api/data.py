from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from typing import List
import json

router = APIRouter()

# [1] 데이터 규격 정의 (Flutter의 HealthDataPayload와 일치해야 함)
class HealthMetric(BaseModel):
    type: str
    value: str
    unit: str
    from_date: str
    to_date: str

class HealthPayload(BaseModel):
    user_id: str
    metrics: List[HealthMetric]
    timestamp: str

# [2] 데이터 수집 엔드포인트
@router.post("/collect")
async def collect_data(payload: HealthPayload):
    # 여기서 데이터를 확인합니다.
    print(f"📥 수신된 데이터 - 사용자: {payload.user_id}, 지표 수: {len(payload.metrics)}")
    
    # TODO: 여기서 kafka_producer를 통해 Kafka 토픽으로 전송하는 로직이 들어갑니다.
    # producer.send('biometrics', value=payload.dict())

    # 상위 3개 데이터만 상세 출력 (너무 많을 수 있으므로)
    for i, metric in enumerate(payload.metrics[:3]):
        print(f"  [{i+1}] 타입: {metric.type} | 값: {metric.value} {metric.unit}")
        print(f"      기간: {metric.from_date} ~ {metric.to_date}")
    
    if len(payload.metrics) > 3:
        print(f"  ... 외 {len(payload.metrics) - 3}개의 데이터 생략")
    print("="*50 + "\n")
    
    return {"status": "success", "message": f"{len(payload.metrics)}개의 데이터가 Kafka로 전송되었습니다."}