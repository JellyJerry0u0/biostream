"""
LLM 초기화 및 유틸리티 (google-generativeai 직접 사용)
- Gemini LLM 초기화 (모델 폴백)
- LRU 캐시
- JSON 추출/파싱
- invoke_llm_json (재시도 + 429 처리 + 캐싱)
"""

import os
import re
import json
import time
import hashlib
from typing import Dict, Any, Optional
from collections import OrderedDict

import google.generativeai as genai


# ──────────────────────────── 환경 설정 ────────────────────────────

REPORT_DEBUG = os.getenv("REPORT_DEBUG", "0") == "1"

GOOGLE_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY") or ""
if not GOOGLE_API_KEY:
    print("⚠️ 경고: GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")


# ──────────────────────────── LLM 초기화 ────────────────────────────

genai_model_name: Optional[str] = None
fallback_models = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-pro-latest",
    "gemini-flash-latest",
]

if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    for _model_name in fallback_models:
        try:
            _ = genai.GenerativeModel(_model_name)
            genai_model_name = _model_name
            print(f"✅ LLM 초기화 성공 - 모델: {_model_name}")
            break
        except Exception as e:
            print(f"⚠️ 모델 {_model_name} 초기화 실패: {e}")
            continue


# ──────────────────────────── LLM 호출 캐시 (LRU) ────────────────────────────

_llm_cache: OrderedDict[str, Optional[Dict[str, Any]]] = OrderedDict()
_LLM_CACHE_MAX_SIZE = 1000

# 리포트 생성당 LLM 호출 카운터
_llm_call_count = 0


def get_llm_call_count() -> int:
    return _llm_call_count


def reset_llm_call_count() -> None:
    global _llm_call_count
    _llm_call_count = 0


def _llm_cache_get(key: str) -> Optional[Dict[str, Any]]:
    """LRU 캐시에서 값 가져오기 (접근 시 최신으로 이동)"""
    if key in _llm_cache:
        value = _llm_cache.pop(key)
        _llm_cache[key] = value
        return value
    return None


def _llm_cache_set(key: str, value: Optional[Dict[str, Any]]) -> None:
    """LRU 캐시에 값 저장 (크기 제한 적용)"""
    if key in _llm_cache:
        _llm_cache.pop(key)
    _llm_cache[key] = value
    while len(_llm_cache) > _LLM_CACHE_MAX_SIZE:
        _llm_cache.popitem(last=False)


# ──────────────────────────── JSON 추출 ────────────────────────────

def extract_json_from_text(text: str, debug: bool = False) -> tuple[Optional[Dict[str, Any]], str]:
    """LLM 응답에서 JSON만 추출

    Returns:
        (parsed_json, failure_reason)
    """
    original_text = text
    attempt_patterns = []

    # 패턴 1: ```json 블록
    json_match = re.search(r'```json\s*\n(.*?)\n```', text, re.DOTALL)
    if json_match:
        text = json_match.group(1)
        attempt_patterns.append("```json 블록")
        try:
            result = json.loads(text.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: ```json 블록)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ ```json 블록 추출했지만 파싱 실패: {str(e)[:100]}")

    # 패턴 2: ``` 블록
    json_match = re.search(r'```\s*\n(.*?)\n```', original_text, re.DOTALL)
    if json_match:
        text = json_match.group(1)
        attempt_patterns.append("``` 블록")
        try:
            result = json.loads(text.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: ``` 블록)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ ``` 블록 추출했지만 파싱 실패: {str(e)[:100]}")

    # 패턴 3: { } 블록
    json_match = re.search(r'\{.*\}', original_text, re.DOTALL)
    if json_match:
        text = json_match.group(0)
        attempt_patterns.append("{ } 블록")
        try:
            result = json.loads(text.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: {{ }} 블록)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ {{ }} 블록 추출했지만 파싱 실패: {str(e)[:100]}")

    # 패턴 4: 앞뒤 불필요한 텍스트 제거 후 재시도
    cleaned = re.sub(r'^[^{]*', '', original_text)
    cleaned = re.sub(r'[^}]*$', '', cleaned)
    if cleaned != original_text:
        attempt_patterns.append("앞뒤 텍스트 제거")
        try:
            result = json.loads(cleaned.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: 앞뒤 텍스트 제거)")
            return result, ""
        except json.JSONDecodeError:
            pass

    failure_reason = f"모든 패턴 실패 (시도: {', '.join(attempt_patterns) if attempt_patterns else '없음'})"
    if debug:
        print(f"    ❌ JSON 파싱 실패: {failure_reason}")
        print(f"    📝 원문 앞 500자: {original_text[:500]}")
    return None, failure_reason


# ──────────────────────────── invoke_llm_json ────────────────────────────

def invoke_llm_json(
    prompt: str,
    system_prompt: str = "",
    retry: bool = True,
    context: str = "",
) -> Optional[Dict[str, Any]]:
    """LLM 호출하여 JSON 응답 파싱 (모델 폴백 + 재시도 + 429 처리 + 캐싱)"""
    global _llm_call_count

    if not GOOGLE_API_KEY:
        print(f"  ❌ [{context}] LLM 호출 실패: GEMINI_API_KEY 없음")
        return None

    debug = REPORT_DEBUG

    # 캐싱 확인
    cache_key = hashlib.md5((system_prompt + prompt).encode()).hexdigest()
    cached_result = _llm_cache_get(cache_key)
    if cached_result is not None:
        if debug:
            print(f"  💾 [{context}] 캐시 히트 (호출 스킵)")
        return cached_result

    _llm_call_count += 1
    if debug:
        print(f"  📊 [LLMBudget] 호출 횟수: {_llm_call_count}회")

    # 모델 폴백 리스트 구성
    current_models = [genai_model_name] if genai_model_name else []
    current_models.extend([m for m in fallback_models if m != genai_model_name])

    last_error = None
    last_raw_text = ""
    failure_reason = ""

    # ── 1단계: 모델 폴백 루프 ──
    for attempt_idx, model_name in enumerate(current_models):
        try:
            if attempt_idx > 0:
                backoff_seconds = min(2 ** attempt_idx, 8)
                print(f"  ⏳ [{context}] 모델 폴백 대기: {backoff_seconds}초...")
                time.sleep(backoff_seconds)

            model = genai.GenerativeModel(model_name)
            full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
            response = model.generate_content(full_prompt)
            raw_text = response.text

            if debug:
                print(f"  📝 [{context}] LLM 호출 성공 (모델: {model_name}), raw_text 길이: {len(raw_text)}")

            result, parse_failure = extract_json_from_text(raw_text, debug=debug)
            failure_reason = parse_failure

            if result is not None:
                _llm_cache_set(cache_key, result)
                return result

            last_raw_text = raw_text
            if attempt_idx < len(current_models) - 1:
                continue

        except Exception as e:
            error_str = str(e)
            last_error = e
            is_429 = any(kw in error_str.upper() for kw in ["429", "RESOURCE_EXHAUSTED", "QUOTA", "RATE LIMIT"])

            print(f"  ⚠️ [{context}] LLM 호출 실패 (모델: {model_name}): {error_str[:200]}")
            if attempt_idx < len(current_models) - 1:
                continue
            if is_429:
                print(f"  ❌ [{context}] 모든 모델에서 429 에러")
                _llm_cache_set(cache_key, None)
                return None
            break

    # ── 2단계: 재시도 (raw_text가 있고 429가 아닐 때) ──
    if not retry or not last_raw_text:
        print(f"  ❌ [{context}] JSON 파싱 최종 실패: {failure_reason or '알 수 없음'}")
        _llm_cache_set(cache_key, None)
        return None

    if last_error and any(kw in str(last_error).upper() for kw in ["429", "RESOURCE_EXHAUSTED"]):
        _llm_cache_set(cache_key, None)
        return None

    # 2차 시도: temperature 낮춤
    if debug:
        print(f"  🔄 [{context}] 2차 시도 (temperature=0.2)...")
    try:
        model = genai.GenerativeModel(genai_model_name or current_models[0])
        gen_config = genai.types.GenerationConfig(temperature=0.2)
        full_prompt = f"{system_prompt}\n\n{prompt}\n\n⚠️ 중요: 설명 문장 없이 JSON만 출력하세요." if system_prompt else f"{prompt}\n\n⚠️ 중요: 설명 문장 없이 JSON만 출력하세요."
        response = model.generate_content(full_prompt, generation_config=gen_config)
        result, _ = extract_json_from_text(response.text, debug=debug)
        if result is not None:
            _llm_cache_set(cache_key, result)
            return result
    except Exception as e:
        if any(kw in str(e).upper() for kw in ["429", "RESOURCE_EXHAUSTED"]):
            _llm_cache_set(cache_key, None)
            return None
        print(f"  ⚠️ [{context}] 2차 시도 실패: {e}")

    # 3차 시도: REPAIR 모드
    if debug:
        print(f"  🔧 [{context}] 3차 시도 (REPAIR 모드)...")
    try:
        repair_prompt = f"""아래 텍스트에서 JSON 부분만 추출하여 유효한 JSON으로 수정하세요.
원문:
{last_raw_text[:2000]}

위 텍스트에서 JSON 부분만 추출하여 완전한 유효한 JSON으로 출력하세요.
설명 문장 없이 JSON만 출력하세요."""

        repair_system = system_prompt or "당신은 JSON 수정 전문가입니다. 유효한 JSON만 출력하세요."
        model = genai.GenerativeModel(genai_model_name or current_models[0])
        gen_config = genai.types.GenerationConfig(temperature=0.0)
        response = model.generate_content(f"{repair_system}\n\n{repair_prompt}", generation_config=gen_config)
        result, _ = extract_json_from_text(response.text, debug=debug)
        if result is not None:
            _llm_cache_set(cache_key, result)
            return result
    except Exception as e:
        if any(kw in str(e).upper() for kw in ["429", "RESOURCE_EXHAUSTED"]):
            _llm_cache_set(cache_key, None)
            return None
        print(f"  ⚠️ [{context}] REPAIR 실패: {e}")

    print(f"  ❌ [{context}] JSON 파싱 최종 실패: {failure_reason or '알 수 없음'}")
    _llm_cache_set(cache_key, None)
    return None


# ──────────────────────────── invoke_llm_text ────────────────────────────

def invoke_llm_text(
    prompt: str,
    system_prompt: str = "",
    context: str = "",
) -> Optional[str]:
    """LLM 호출하여 일반 텍스트 반환 (JSON 파싱 없음)."""
    global _llm_call_count

    if not GOOGLE_API_KEY:
        print(f"  ❌ [{context}] LLM 호출 실패: GEMINI_API_KEY 없음")
        return None

    cache_key = "text:" + hashlib.md5((system_prompt + prompt).encode()).hexdigest()
    cached = _llm_cache_get(cache_key)
    if cached is not None:
        return cached if isinstance(cached, str) else None

    _llm_call_count += 1
    current_models = [genai_model_name] if genai_model_name else []
    current_models.extend([m for m in fallback_models if m != genai_model_name])

    for attempt_idx, model_name in enumerate(current_models):
        try:
            if attempt_idx > 0:
                time.sleep(min(2 ** attempt_idx, 8))
            model = genai.GenerativeModel(model_name)
            full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
            response = model.generate_content(full_prompt)
            raw_text = (response.text or "").strip()
            if raw_text:
                _llm_cache_set(cache_key, raw_text)
                return raw_text
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e).upper():
                continue
            print(f"  ⚠️ [{context}] LLM 호출 실패: {e}")
    return None
