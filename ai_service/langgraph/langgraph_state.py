from typing import TypedDict, List, Annotated, Optional
import operator

class BioStreamState(TypedDict):
    # 1. 사용자의 설문 입력 데이터 (원본)
    # 예: {"smoking": "heavy", "sleep": 5, "stress": "high"}
    user_inputs: dict

    # 2. LLM이 생성한 검색용 쿼리 (분산 검색을 위해 리스트로 관리)
    # 예: ["ALDH2 deficiency aging", "sleep deprivation skin elasticity"]
    search_queries: List[str]

    # 3. Qdrant에서 검색된 논문 컨텍스트
    # Annotated와 operator.add를 사용하면 여러 노드에서 찾은 결과가 하나로 합쳐집니다.
    retrieved_contexts: Annotated[List[str], operator.add]

    # 4. 의학적 근거 기반 노화 평가 리포트
    # 논문 수치(p-value, OR 등)를 포함한 텍스트 분석 결과
    evaluation_report: str

    # 5. 시각적 변화에 대한 정밀 묘사 (이미지 생성용 중간 데이터)
    # 예: "눈가 주름 15% 깊어짐, 피부 톤의 황색화 관찰"
    visual_description: str

    # 6. 최종 이미지 생성 모델용 프롬프트 (영문)
    image_prompt: str

    # 7. 생성된 이미지 결과
    image_url: Optional[str]

    # 8. 흐름 제어를 위한 상태 플래그 (선택 사항)
    next_step: str