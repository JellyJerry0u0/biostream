"""
정량 근거 데이터 인덱서
quant_corpus CSV 파일을 읽어서 Qdrant quant_evidence 컬렉션에 적재합니다.
"""

import os
import csv
import math
from pathlib import Path
from typing import List, Dict, Any, Optional
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct, 
    PayloadSchemaType, FieldCondition, MatchValue
)
import google.generativeai as genai

# .env 파일 로드 (있는 경우) - override=True로 기존 환경 변수 덮어쓰기
try:
    from dotenv import load_dotenv
    backend_dir = Path(__file__).parent.parent.parent
    env_path = backend_dir / ".env"
    if env_path.exists():
        load_dotenv(env_path, override=True)  # override=True 추가
except ImportError:
    pass

# 환경 변수
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_QUANT_COLLECTION", "quant_evidence")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
GEMINI_EMBED_MODEL = os.getenv("GEMINI_EMBED_MODEL", "gemini-embedding-001")
EMBED_DIM = 3072  # quant_evidence는 3072 차원 고정


def get_embedding(text: str, max_retries: int = 3, retry_delay: int = 60) -> List[float]:
    """Gemini API를 사용하여 텍스트 임베딩 생성 (재시도 로직 포함)"""
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
    
    import time
    
    for attempt in range(max_retries):
        try:
            genai.configure(api_key=GEMINI_API_KEY)
            result = genai.embed_content(
                model=GEMINI_EMBED_MODEL,
                content=text,
                task_type="retrieval_document"
            )
            embedding = result['embedding']
            
            # 차원 검증
            if len(embedding) != EMBED_DIM:
                raise ValueError(f"임베딩 차원 불일치: 예상 {EMBED_DIM}, 실제 {len(embedding)}")
            
            return embedding
            
        except Exception as e:
            error_str = str(e)
            # 429 에러 (할당량 초과) 처리
            if "429" in error_str or "quota" in error_str.lower() or "Quota exceeded" in error_str:
                if attempt < max_retries - 1:
                    wait_time = retry_delay * (attempt + 1)
                    print(f"⚠️ 할당량 초과 (429). {wait_time}초 대기 후 재시도... ({attempt + 1}/{max_retries})")
                    time.sleep(wait_time)
                    continue
                else:
                    raise Exception(f"할당량 초과: Gemini API 일일 할당량을 초과했습니다.")
            else:
                raise Exception(f"임베딩 생성 실패: {str(e)}")
    
    raise Exception(f"임베딩 생성 실패: 최대 재시도 횟수 초과")


def build_quant_text(row: Dict[str, str]) -> str:
    """
    quant_text 생성 규칙
    TITLE: {title}
    OUTCOME: {outcome_mapped}
    TIME: {timeframe_value_num} {timeframe_unit_norm}
    EFFECT: {effect_signed_value} {effect_unit_filled}
    P_VALUE: {p_value_num}
    SNIPPET: {source_snippet}
    """
    title = row.get("title", "").strip()
    outcome_mapped = row.get("outcome_mapped", "").strip()
    timeframe_value_num = row.get("timeframe_value_num", "").strip()
    timeframe_unit_norm = row.get("timeframe_unit_norm", "").strip()
    effect_signed_value = row.get("effect_signed_value", "").strip()
    effect_unit_filled = row.get("effect_unit_filled", "").strip()
    p_value_num = row.get("p_value_num", "").strip()
    source_snippet = row.get("source_snippet", "").strip()
    
    # p_value_num이 NaN이면 "NA"로 처리
    if not p_value_num or p_value_num.lower() == "nan" or p_value_num == "":
        p_value_num = "NA"
    
    parts = []
    if title:
        parts.append(f"TITLE: {title}")
    if outcome_mapped:
        parts.append(f"OUTCOME: {outcome_mapped}")
    if timeframe_value_num and timeframe_unit_norm:
        parts.append(f"TIME: {timeframe_value_num} {timeframe_unit_norm}")
    if effect_signed_value and effect_unit_filled:
        parts.append(f"EFFECT: {effect_signed_value} {effect_unit_filled}")
    if p_value_num:
        parts.append(f"P_VALUE: {p_value_num}")
    if source_snippet:
        parts.append(f"SNIPPET: {source_snippet}")
    
    return "\n".join(parts)


def safe_point_id(chunk_id: str, outcome_mapped: str, timeframe_days: Optional[float], row_uid: str) -> int:
    """
    Point ID 생성 (safe id)
    {chunk_id}__{outcome_mapped}__{int(timeframe_days)}d__{row_uid}
    """
    # timeframe_days가 NaN이면 0으로 처리
    if timeframe_days is None or (isinstance(timeframe_days, float) and math.isnan(timeframe_days)):
        timeframe_days = 0.0
    
    # row_uid가 비어있으면 chunk_id 사용
    if not row_uid or row_uid.strip() == "":
        row_uid = chunk_id
    
    point_id_str = f"{chunk_id}__{outcome_mapped}__{int(timeframe_days)}d__{row_uid}"
    
    # hash를 사용하여 int64 범위 내로 변환
    point_id = hash(point_id_str) % (2**63)
    
    return point_id


def ensure_collection(client: QdrantClient, collection_name: str):
    """컬렉션 생성 및 인덱스 설정"""
    try:
        collections = client.get_collections().collections
        collection_names = [c.name for c in collections]
        
        if collection_name not in collection_names:
            print(f"컬렉션 '{collection_name}' 생성 중... (차원: {EMBED_DIM})")
            client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(
                    size=EMBED_DIM,
                    distance=Distance.COSINE
                )
            )
            print(f"✅ 컬렉션 '{collection_name}' 생성 완료")
        else:
            print(f"컬렉션 '{collection_name}' 이미 존재합니다.")
        
        # Payload 인덱스 생성
        try:
            # keyword 인덱스
            client.create_payload_index(
                collection_name=collection_name,
                field_name="outcome_mapped",
                field_schema=PayloadSchemaType.KEYWORD
            )
            print(f"✅ 인덱스 생성: outcome_mapped (keyword)")
        except Exception as e:
            if "already exists" not in str(e).lower():
                print(f"⚠️ outcome_mapped 인덱스 생성 실패 (이미 존재할 수 있음): {e}")
        
        try:
            client.create_payload_index(
                collection_name=collection_name,
                field_name="paper_id",
                field_schema=PayloadSchemaType.KEYWORD
            )
            print(f"✅ 인덱스 생성: paper_id (keyword)")
        except Exception as e:
            if "already exists" not in str(e).lower():
                print(f"⚠️ paper_id 인덱스 생성 실패: {e}")
        
        try:
            client.create_payload_index(
                collection_name=collection_name,
                field_name="chunk_id",
                field_schema=PayloadSchemaType.KEYWORD
            )
            print(f"✅ 인덱스 생성: chunk_id (keyword)")
        except Exception as e:
            if "already exists" not in str(e).lower():
                print(f"⚠️ chunk_id 인덱스 생성 실패: {e}")
        
        # float 인덱스
        for field in ["timeframe_days", "p_value_num", "effect_signed_value"]:
            try:
                client.create_payload_index(
                    collection_name=collection_name,
                    field_name=field,
                    field_schema=PayloadSchemaType.FLOAT
                )
                print(f"✅ 인덱스 생성: {field} (float)")
            except Exception as e:
                if "already exists" not in str(e).lower():
                    print(f"⚠️ {field} 인덱스 생성 실패: {e}")
        
        # bool 인덱스
        for field in ["is_valid", "suspicious_cross_outcome_copy"]:
            try:
                client.create_payload_index(
                    collection_name=collection_name,
                    field_name=field,
                    field_schema=PayloadSchemaType.BOOL
                )
                print(f"✅ 인덱스 생성: {field} (bool)")
            except Exception as e:
                if "already exists" not in str(e).lower():
                    print(f"⚠️ {field} 인덱스 생성 실패: {e}")
                    
    except Exception as e:
        print(f"⚠️ 컬렉션 생성/확인 중 오류: {e}")
        raise


def parse_float(value: str) -> Optional[float]:
    """문자열을 float로 변환 (NaN 처리)"""
    if not value or value.strip() == "" or value.lower() == "nan":
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


def parse_bool(value: str) -> bool:
    """문자열을 bool로 변환"""
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ["true", "1", "yes", "t"]
    return False


def load_csv(csv_path: str, batch_size: int = 64) -> int:
    """
    CSV 파일을 읽어서 Qdrant에 업로드
    
    Returns:
        업로드된 포인트 수
    """
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {csv_path}")
    
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
    
    # Qdrant 클라이언트 초기화
    client = QdrantClient(url=QDRANT_URL)
    
    # 컬렉션 생성/확인
    ensure_collection(client, QDRANT_COLLECTION)
    
    # CSV 읽기
    print(f"CSV 파일 읽기 시작: {csv_path}")
    points = []
    total_processed = 0
    total_skipped = 0
    
    # BOM 제거를 위해 utf-8-sig 사용
    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        
        for idx, row in enumerate(reader, 1):
            try:
                # 필수 필드 확인
                chunk_id = row.get("chunk_id", "").strip()
                outcome_mapped = row.get("outcome_mapped", "").strip()
                row_uid = row.get("row_uid", "").strip()
                
                if not chunk_id or not outcome_mapped:
                    total_skipped += 1
                    if idx <= 3:
                        print(f"⚠️ 행 {idx}: 필수 필드(chunk_id, outcome_mapped)가 없습니다. 건너뜁니다.")
                    continue
                
                # quant_text 생성
                quant_text = build_quant_text(row)
                if not quant_text.strip():
                    total_skipped += 1
                    if idx <= 3:
                        print(f"⚠️ 행 {idx}: quant_text가 비어있습니다. 건너뜁니다.")
                    continue
                
                # 임베딩 생성
                if idx % 10 == 0 or idx <= 5:
                    print(f"  [{idx}] 임베딩 생성 중... (chunk_id: {chunk_id}, outcome: {outcome_mapped})")
                
                import time
                if idx > 1:
                    time.sleep(0.1)  # API 호출 간 0.1초 대기
                
                embedding = get_embedding(quant_text)
                
                # Point ID 생성
                timeframe_days = parse_float(row.get("timeframe_days", ""))
                point_id = safe_point_id(chunk_id, outcome_mapped, timeframe_days, row_uid)
                
                # Payload 구성
                payload = {
                    "paper_id": row.get("paper_id", "").strip(),
                    "chunk_id": chunk_id,
                    "outcome_final": row.get("outcome_final", "").strip(),
                    "outcome_mapped": outcome_mapped,
                    "effect_value_filled": row.get("effect_value_filled", "").strip(),
                    "effect_unit_filled": row.get("effect_unit_filled", "").strip(),
                    "effect_signed_final": row.get("effect_signed_final", "").strip(),
                    "timeframe_value_num": parse_float(row.get("timeframe_value_num", "")),
                    "timeframe_unit_norm": row.get("timeframe_unit_norm", "").strip(),
                    "p_label": row.get("p_label", "").strip(),
                    "source_snippet": row.get("source_snippet", "").strip(),
                    "title": row.get("title", "").strip(),
                    "row_uid": row_uid,
                    "is_valid": parse_bool(row.get("is_valid", "True")),
                    "invalid_reason": row.get("invalid_reason", "").strip(),
                    "suspicious_cross_outcome_copy": parse_bool(row.get("suspicious_cross_outcome_copy", "False")),
                }
                
                # float 필드 추가 (None이 아닌 경우만)
                timeframe_days_val = parse_float(row.get("timeframe_days", ""))
                if timeframe_days_val is not None:
                    payload["timeframe_days"] = timeframe_days_val
                
                p_value_num_val = parse_float(row.get("p_value_num", ""))
                if p_value_num_val is not None:
                    payload["p_value_num"] = p_value_num_val
                
                effect_signed_value_val = parse_float(row.get("effect_signed_value", ""))
                if effect_signed_value_val is not None:
                    payload["effect_signed_value"] = effect_signed_value_val
                
                # CI 필드 추가
                ci_low = row.get("ci_low", "").strip()
                ci_high = row.get("ci_high", "").strip()
                if ci_low:
                    payload["ci_low"] = ci_low
                if ci_high:
                    payload["ci_high"] = ci_high
                
                ci_low_num = parse_float(row.get("ci_low_num", ""))
                ci_high_num = parse_float(row.get("ci_high_num", ""))
                if ci_low_num is not None:
                    payload["ci_low_num"] = ci_low_num
                if ci_high_num is not None:
                    payload["ci_high_num"] = ci_high_num
                
                # Point 생성
                point = PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload=payload
                )
                points.append(point)
                total_processed += 1
                
                # 배치 업로드
                if len(points) >= batch_size:
                    print(f"  배치 업로드 중... ({len(points)}개)")
                    client.upsert(
                        collection_name=QDRANT_COLLECTION,
                        points=points
                    )
                    points = []
                    print(f"  ✅ 배치 업로드 완료")
                
            except Exception as e:
                print(f"⚠️ 행 {idx} 처리 중 오류: {e}")
                total_skipped += 1
                continue
        
        # 남은 포인트 업로드
        if points:
            print(f"  마지막 배치 업로드 중... ({len(points)}개)")
            client.upsert(
                collection_name=QDRANT_COLLECTION,
                points=points
            )
            print(f"  ✅ 마지막 배치 업로드 완료")
    
    print(f"✅ CSV 수집 완료: {csv_path}")
    print(f"  - 처리된 행: {total_processed}개")
    print(f"  - 건너뛴 행: {total_skipped}개")
    
    # 컬렉션 정보 확인
    collection_info = client.get_collection(QDRANT_COLLECTION)
    print(f"컬렉션 정보:")
    print(f"  - 총 포인트 수: {collection_info.points_count}")
    print(f"  - 벡터 차원: {collection_info.config.params.vectors.size}")
    
    return total_processed


if __name__ == "__main__":
    import sys
    
    # 기본 CSV 경로
    default_csv = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "data",
        "quant_corpus_v0_3_clean_valid_v3.csv"
    )
    
    csv_path = sys.argv[1] if len(sys.argv) > 1 else default_csv
    
    try:
        count = load_csv(csv_path)
        print(f"\n✅ 인덱싱 완료: {count}개 포인트 업로드됨")
    except Exception as e:
        print(f"❌ 수집 실패: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
