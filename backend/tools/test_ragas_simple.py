"""
간단한 RAGAS 동작 확인 테스트
임베딩 완료 전 RAGAS 엔진이 정상 작동하는지만 확인하는 최소 스크립트
"""

import os
from dotenv import load_dotenv

load_dotenv()

# RAGAS 임포트
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from datasets import Dataset

print("\n" + "="*60)
print("RAGAS 간단 테스트")
print("="*60 + "\n")

# 1. LLM 및 임베딩 설정
print("1. Gemini 설정 중...")
api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

llm = ChatGoogleGenerativeAI(
    model="gemini-2.0-flash",
    temperature=0.0,
    google_api_key=api_key
)

embeddings = GoogleGenerativeAIEmbeddings(
    model="models/gemini-embedding-001",
    google_api_key=api_key
)
print("✅ 설정 완료\n")

# 2. 테스트 데이터 준비
print("2. 테스트 데이터 준비...")
test_data = {
    "question": ["피부 건강에 수면이 중요한가?"],
    "contexts": [[
        "Sleep is essential for skin health. During sleep, the body repairs damaged skin cells.",
        "Lack of sleep can lead to increased stress hormones that damage collagen."
    ]],
    "answer": ["수면은 피부 건강에 매우 중요합니다. 수면 중에 피부 세포가 재생되고 회복됩니다."]
}

dataset = Dataset.from_dict(test_data)
print("✅ 데이터 준비 완료\n")

# 3. RAGAS 평가 실행
print("3. RAGAS 평가 실행 중...")
print("   (Gemini API 호출 중 - 약 10-20초 소요)\n")

try:
    result = evaluate(
        dataset,
        metrics=[faithfulness, answer_relevancy],
        llm=llm,
        embeddings=embeddings
    )
    
    print("✅ 평가 완료!\n")
    
    # 4. 결과 출력
    print("="*60)
    print("결과")
    print("="*60)
    print(f"\n결과 타입: {type(result)}")
    print(f"결과 내용:\n{result}")
    
    # DataFrame 형태라면 컬럼별 출력
    if hasattr(result, 'columns'):
        print(f"\n컬럼 목록: {result.columns.tolist()}")
        for col in result.columns:
            if col in ['faithfulness', 'answer_relevancy']:
                print(f"\n{col}: {result[col].iloc[0]:.4f}")
    
    print("\n" + "="*60)
    print("✅ RAGAS 테스트 성공!")
    print("="*60)
    
except Exception as e:
    print(f"\n❌ 평가 실패: {e}")
    import traceback
    traceback.print_exc()
