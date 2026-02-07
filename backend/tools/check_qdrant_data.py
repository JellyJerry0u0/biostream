#!/usr/bin/env python3
"""
Qdrant 데이터 확인 스크립트
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchValue, MatchAny

# .env 파일 로드
backend_dir = Path(__file__).parent.parent
env_path = backend_dir / ".env"
if env_path.exists():
    load_dotenv(env_path, override=True)

QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_QUANT_COLLECTION", "quant_evidence")

print("="*80)
print("Qdrant 데이터 확인")
print("="*80)
print(f"QDRANT_URL: {QDRANT_URL}")
print(f"QDRANT_COLLECTION: {QDRANT_COLLECTION}")
print()

try:
    # Qdrant 클라이언트 연결
    print("1. Qdrant 연결 중...")
    client = QdrantClient(url=QDRANT_URL)
    print("   ✅ 연결 성공")
    print()
    
    # 컬렉션 목록 확인
    print("2. 컬렉션 목록 확인...")
    collections = client.get_collections().collections
    collection_names = [c.name for c in collections]
    print(f"   발견된 컬렉션: {collection_names}")
    print()
    
    if QDRANT_COLLECTION not in collection_names:
        print(f"   ⚠️ '{QDRANT_COLLECTION}' 컬렉션이 존재하지 않습니다!")
        print()
        print("   사용 가능한 컬렉션:")
        for name in collection_names:
            info = client.get_collection(name)
            print(f"     - {name}: {info.points_count}개 포인트")
        sys.exit(1)
    
    # 컬렉션 정보 확인
    print(f"3. '{QDRANT_COLLECTION}' 컬렉션 정보...")
    collection_info = client.get_collection(QDRANT_COLLECTION)
    print(f"   포인트 수: {collection_info.points_count}")
    print(f"   벡터 차원: {collection_info.config.params.vectors.size}")
    print()
    
    if collection_info.points_count == 0:
        print("   ⚠️ 컬렉션에 데이터가 없습니다!")
        sys.exit(1)
    
    # 샘플 데이터 조회 (필터 없이)
    print("4. 샘플 데이터 조회 (필터 없이, 상위 5개)...")
    sample_results = client.scroll(
        collection_name=QDRANT_COLLECTION,
        limit=5,
        with_payload=True,
        with_vectors=False
    )
    
    print(f"   발견된 포인트: {len(sample_results[0])}개")
    print()
    
    for i, point in enumerate(sample_results[0][:3], 1):
        payload = point.payload
        print(f"   샘플 {i}:")
        print(f"     - outcome_mapped: {payload.get('outcome_mapped', 'N/A')}")
        print(f"     - outcome_final: {payload.get('outcome_final', 'N/A')}")
        print(f"     - effect_signed_value: {payload.get('effect_signed_value', 'N/A')}")
        print(f"     - effect_unit_filled: {payload.get('effect_unit_filled', 'N/A')}")
        print(f"     - timeframe_days: {payload.get('timeframe_days', 'N/A')}")
        print(f"     - is_valid: {payload.get('is_valid', 'N/A')}")
        print(f"     - suspicious_cross_outcome_copy: {payload.get('suspicious_cross_outcome_copy', 'N/A')}")
        print()
    
    # outcome_mapped별 통계
    print("5. outcome_mapped별 통계...")
    all_results = client.scroll(
        collection_name=QDRANT_COLLECTION,
        limit=10000,  # 충분히 큰 수
        with_payload=True,
        with_vectors=False
    )
    
    outcome_counts = {}
    valid_counts = {}
    for point in all_results[0]:
        outcome = point.payload.get('outcome_mapped', 'unknown')
        is_valid = point.payload.get('is_valid', False)
        
        outcome_counts[outcome] = outcome_counts.get(outcome, 0) + 1
        if is_valid:
            valid_counts[outcome] = valid_counts.get(outcome, 0) + 1
    
    print(f"   전체 포인트 수: {len(all_results[0])}")
    print()
    print("   outcome_mapped별 카운트:")
    for outcome in sorted(outcome_counts.keys()):
        total = outcome_counts[outcome]
        valid = valid_counts.get(outcome, 0)
        print(f"     - {outcome}: 전체 {total}개, is_valid=True {valid}개")
    print()
    
    # 특정 outcome으로 필터링 테스트
    print("6. 필터링 테스트 (outcome_mapped='elasticity', is_valid=True)...")
    test_filter = Filter(
        must=[
            FieldCondition(
                key="outcome_mapped",
                match=MatchAny(any=["elasticity"])
            ),
            FieldCondition(
                key="is_valid",
                match=MatchValue(value=True)
            )
        ]
    )
    
    test_results = client.scroll(
        collection_name=QDRANT_COLLECTION,
        scroll_filter=test_filter,
        limit=10,
        with_payload=True,
        with_vectors=False
    )
    
    print(f"   발견된 포인트: {len(test_results[0])}개")
    if test_results[0]:
        print("   첫 번째 결과:")
        payload = test_results[0][0].payload
        print(f"     - outcome_mapped: {payload.get('outcome_mapped')}")
        print(f"     - effect_signed_value: {payload.get('effect_signed_value')}")
        print(f"     - effect_unit_filled: {payload.get('effect_unit_filled')}")
        print(f"     - timeframe_days: {payload.get('timeframe_days')}")
        print(f"     - is_valid: {payload.get('is_valid')}")
    print()
    
    print("="*80)
    print("✅ 확인 완료")
    print("="*80)
    
except Exception as e:
    print(f"❌ 오류 발생: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
