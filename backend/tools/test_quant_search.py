#!/usr/bin/env python3
"""
정량 근거 검색 함수 테스트
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# .env 파일 로드
backend_dir = Path(__file__).parent.parent
env_path = backend_dir / ".env"
if env_path.exists():
    load_dotenv(env_path, override=True)

# 경로 설정
sys.path.insert(0, str(backend_dir))
sys.path.insert(0, str(backend_dir / "app" / "services"))

from quant_evidence_retriever import search_by_outcomes, get_grouped_stats_multi

print("="*80)
print("정량 근거 검색 함수 테스트")
print("="*80)
print()

# 테스트 1: elasticity 검색
print("테스트 1: outcome_mapped=['elasticity'] 검색")
print("-"*80)
try:
    cards = search_by_outcomes(['elasticity'], top_k=10, min_score=0.0)
    print(f"✅ 검색 성공: {len(cards)}개 카드 발견")
    if cards:
        print("\n   발견된 카드:")
        for i, card in enumerate(cards[:3], 1):
            print(f"   {i}. outcome={card.outcome_mapped}, value={card.effect_signed_value}%, "
                  f"timeframe={card.timeframe_days}일, is_valid={card.is_valid}")
except Exception as e:
    print(f"❌ 검색 실패: {e}")
    import traceback
    traceback.print_exc()

print()
print()

# 테스트 2: get_grouped_stats_multi 테스트
print("테스트 2: get_grouped_stats_multi(['elasticity']) 통계 계산")
print("-"*80)
try:
    stats = get_grouped_stats_multi(['elasticity'], exclude_suspicious=True)
    print(f"✅ 통계 계산 성공")
    print(f"   outcome_mapped_list: {stats.get('outcome_mapped_list')}")
    print(f"   timeframe_groups 수: {len(stats.get('timeframe_groups', {}))}")
    
    if stats.get('timeframe_groups'):
        print("\n   timeframe_groups:")
        for timeframe_days, group in stats['timeframe_groups'].items():
            print(f"     - {timeframe_days}일: {group['count']}개 카드, "
                  f"mean={group['mean']}%, median={group['median']}%")
    else:
        print("   ⚠️ timeframe_groups가 비어있습니다!")
        
except Exception as e:
    print(f"❌ 통계 계산 실패: {e}")
    import traceback
    traceback.print_exc()

print()
print()

# 테스트 3: 여러 outcome 검색
print("테스트 3: get_grouped_stats_multi(['wrinkle', 'elasticity']) 통계 계산")
print("-"*80)
try:
    stats = get_grouped_stats_multi(['wrinkle', 'elasticity'], exclude_suspicious=True)
    print(f"✅ 통계 계산 성공")
    print(f"   outcome_mapped_list: {stats.get('outcome_mapped_list')}")
    print(f"   timeframe_groups 수: {len(stats.get('timeframe_groups', {}))}")
    
    if stats.get('timeframe_groups'):
        print("\n   timeframe_groups:")
        for timeframe_days, group in stats['timeframe_groups'].items():
            print(f"     - {timeframe_days}일: {group['count']}개 카드, "
                  f"mean={group['mean']}%, median={group['median']}%")
    else:
        print("   ⚠️ timeframe_groups가 비어있습니다!")
        print("   (wrinkle 데이터가 없을 수 있습니다)")
        
except Exception as e:
    print(f"❌ 통계 계산 실패: {e}")
    import traceback
    traceback.print_exc()

print()
print("="*80)
print("테스트 완료")
print("="*80)
