"""
RAGAS 디버깅 버전 - 각 단계별 진행 상황 확인
"""

import os
import sys
from dotenv import load_dotenv

load_dotenv()

print("\n" + "="*60)
print("RAGAS 디버깅 테스트")
print("="*60 + "\n")

# 1. API 키 확인
print("1. API 키 확인...")
api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
if api_key:
    print(f"✅ API 키 존재 (앞 10자: {api_key[:10]}...)")
else:
    print("❌ API 키 없음")
    sys.exit(1)

# 2. Gemini LLM 직접 테스트
print("\n2. Gemini LLM 직접 테스트...")
try:
    from langchain_google_genai import ChatGoogleGenerativeAI
    
    llm = ChatGoogleGenerativeAI(
        model="gemini-2.0-flash",
        temperature=0.0,
        google_api_key=api_key,
        timeout=10  # 10초 타임아웃
    )
    
    print("   LLM 객체 생성 완료")
    print("   간단한 질문 테스트 중...")
    
    response = llm.invoke("Say hello")
    print(f"✅ LLM 응답: {response.content[:50]}...")
    
except Exception as e:
    print(f"❌ LLM 테스트 실패: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# 3. 임베딩 테스트
print("\n3. Gemini 임베딩 테스트...")
try:
    from langchain_google_genai import GoogleGenerativeAIEmbeddings
    
    embeddings = GoogleGenerativeAIEmbeddings(
        model="models/gemini-embedding-001",
        google_api_key=api_key
    )
    
    print("   임베딩 객체 생성 완료")
    print("   간단한 텍스트 임베딩 중...")
    
    result = embeddings.embed_query("test")
    print(f"✅ 임베딩 벡터 길이: {len(result)}")
    
except Exception as e:
    print(f"❌ 임베딩 테스트 실패: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# 4. RAGAS 임포트 테스트
print("\n4. RAGAS 임포트 테스트...")
try:
    from ragas import evaluate
    from ragas.metrics.collections import faithfulness, answer_relevancy
    from datasets import Dataset
    print("✅ RAGAS 임포트 성공 (새로운 import 경로 사용)")
except ImportError:
    print("⚠️  새로운 import 실패, 구버전 시도...")
    try:
        from ragas import evaluate
        from ragas.metrics import faithfulness, answer_relevancy
        from datasets import Dataset
        print("✅ RAGAS 임포트 성공 (구버전 경로)")
    except Exception as e:
        print(f"❌ RAGAS 임포트 실패: {e}")
        sys.exit(1)

# 5. 간단한 RAGAS 평가 (단일 메트릭만)
print("\n5. RAGAS 평가 테스트 (faithfulness만)...")
print("   데이터 준비 중...")

test_data = {
    "question": ["What is 2+2?"],
    "contexts": [["2+2 equals 4"]],
    "answer": ["2+2 is 4"]
}

dataset = Dataset.from_dict(test_data)
print("✅ 데이터셋 준비 완료")

print("\n   RAGAS evaluate 실행 중...")
print("   (이 단계에서 오래 걸리면 Gemini API 응답 지연입니다)\n")

try:
    import time
    start_time = time.time()
    
    result = evaluate(
        dataset,
        metrics=[faithfulness],  # 하나의 메트릭만 테스트
        llm=llm,
        embeddings=embeddings,
        raise_exceptions=True
    )
    
    elapsed = time.time() - start_time
    print(f"\n✅ 평가 완료! (소요 시간: {elapsed:.1f}초)")
    print(f"\n결과:\n{result}")
    
    print("\n" + "="*60)
    print("✅ 모든 테스트 통과!")
    print("="*60)
    
except Exception as e:
    elapsed = time.time() - start_time
    print(f"\n❌ 평가 실패 (경과 시간: {elapsed:.1f}초)")
    print(f"에러: {e}")
    import traceback
    traceback.print_exc()
