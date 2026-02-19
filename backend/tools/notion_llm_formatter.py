"""
Notion LLM Formatter: LLM이 직접 Notion Block 구조를 생성
기존 수동 파싱 방식(notion_formatter.py)과 비교하기 위한 실험적 구현

Agent 기반 문서 포맷팅:
1. Content Generation Agent: 리포트 내용 (의미 + 구조)
2. Notion Layout Agent: LLM이 Notion block schema로 변환
"""

import os
import json
from typing import Dict, Any, List, Optional
import google.generativeai as genai

# Gemini 설정
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


class NotionBlockSchemaGuide:
    """Notion Block Schema 가이드 (LLM에게 제공)"""
    
    SCHEMA_EXAMPLES = """
# Notion Block Schema Examples

## 1. Heading Blocks
```json
{
  "object": "block",
  "type": "heading_1",
  "heading_1": {
    "rich_text": [{"type": "text", "text": {"content": "제목"}}]
  }
}
```

## 2. Paragraph Block
```json
{
  "object": "block",
  "type": "paragraph",
  "paragraph": {
    "rich_text": [{"type": "text", "text": {"content": "내용"}}]
  }
}
```

## 3. Callout Block (강조)
```json
{
  "object": "block",
  "type": "callout",
  "callout": {
    "rich_text": [{"type": "text", "text": {"content": "중요 메시지"}}],
    "icon": {"type": "emoji", "emoji": "💡"},
    "color": "blue_background"
  }
}
```

## 4. Quote Block
```json
{
  "object": "block",
  "type": "quote",
  "quote": {
    "rich_text": [{"type": "text", "text": {"content": "인용문"}}],
    "color": "gray_background"
  }
}
```

## 5. Bulleted List Item
```json
{
  "object": "block",
  "type": "bulleted_list_item",
  "bulleted_list_item": {
    "rich_text": [{"type": "text", "text": {"content": "항목"}}]
  }
}
```

## 6. Toggle Block (접기/펼치기)
```json
{
  "object": "block",
  "type": "toggle",
  "toggle": {
    "rich_text": [{"type": "text", "text": {"content": "토글 제목"}}],
    "children": [
      {
        "object": "block",
        "type": "paragraph",
        "paragraph": {"rich_text": [{"type": "text", "text": {"content": "숨겨진 내용"}}]}
      }
    ]
  }
}
```

## 7. Divider
```json
{
  "object": "block",
  "type": "divider",
  "divider": {}
}
```

## 8. Image Block
```json
{
  "object": "block",
  "type": "image",
  "image": {
    "type": "external",
    "external": {"url": "https://example.com/image.png"},
    "caption": [{"type": "text", "text": {"content": "이미지 설명"}}]
  }
}
```

## Available Colors
- default, gray, brown, orange, yellow, green, blue, purple, pink, red
- Add "_background" suffix for background color (e.g., "blue_background")

## Popular Emojis for Health Reports
- 🧬 DNA/유전자
- 🎯 목표
- 😴 수면
- ☀️ 자외선
- 🏃 운동
- 💪 활동
- 🔍 분석
- 🧪 실험
- 💡 아이디어
- 📊 통계
- ✅ 완료
- ⚠️ 경고
- 🌟 우수
- 📚 연구
"""

    FORMATTING_INSTRUCTIONS = """
# Notion Block Formatting Instructions

당신은 건강 리포트를 Notion 페이지로 아름답게 구성하는 Document Layout Agent입니다.

## 목표
1. **가독성**: 정보 계층이 명확하게 보이도록
2. **시각적 매력**: 적절한 색상, 이모지, 공백 활용
3. **전문성**: 신뢰감을 주는 레이아웃

## 디자인 원칙
1. **Hero Section**: heading_1 + callout으로 시작
2. **섹션**: heading_1 또는 heading_2로 구분, divider 사용
3. **카드**: heading_3 + quote 또는 callout
4. **강조**: callout (중요), quote (내용), toggle (상세)
5. **공백**: paragraph("")로 여백 생성
6. **색상 일관성**: 
   - 목표/중요: purple_background
   - 수면: blue_background  
   - 자외선: yellow_background
   - 생활습관: green_background
   - 활동: orange_background
   - 문제: red_background
   - 정보: gray_background

## 구조 예시
```json
[
  {"type": "heading_1", ...},  // 메인 타이틀
  {"type": "callout", ...},    // 요약
  {"type": "divider", ...},
  {"type": "heading_2", ...},  // 섹션 1
  {"type": "callout", ...},    // 섹션 설명
  {"type": "heading_3", ...},  // 카드 제목
  {"type": "quote", ...},      // 카드 내용
  {"type": "toggle", ...},     // 상세 정보 (접기)
  {"type": "divider", ...},
  ...
]
```

## 주의사항
- 반드시 유효한 JSON 배열 반환
- 각 블록은 완전한 Notion block schema 준수
- rich_text는 항상 배열 형태
- children은 toggle 블록에만 사용
"""


class NotionLLMFormatter:
    """LLM 기반 Notion 포맷터"""
    
    # 사용 가능한 모델 리스트 (우선순위 순)
    FALLBACK_MODELS = [
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-pro-latest",
        "gemini-flash-latest",
        "gemini-1.5-pro",
        "gemini-1.5-flash",
    ]
    
    def __init__(self):
        """모델 초기화 (폴백은 실제 호출 시 수행)"""
        self.model_name = self.FALLBACK_MODELS[0]
        self.model = None  # 실제 사용 시 생성
        self.schema_guide = NotionBlockSchemaGuide()
        print(f"✅ [LLM Formatter] 초기화 완료 (폴백 모델: {len(self.FALLBACK_MODELS)}개)")
    
    def format_report_with_llm(self, final_report: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        LLM을 사용하여 리포트를 Notion block으로 변환
        
        Args:
            final_report: LangGraph에서 생성된 최종 리포트
        
        Returns:
            Notion block 배열
        """
        print("[LLM Formatter] 리포트 구조화 시작...")
        
        # 1. 리포트 단순화 (LLM 입력용)
        simplified_report = self._simplify_report(final_report)
        
        # 2. LLM에게 Notion block 생성 요청
        prompt = self._build_formatting_prompt(simplified_report)
        
        # 3. 모델 폴백으로 시도
        last_error = None
        for attempt_idx, model_name in enumerate(self.FALLBACK_MODELS):
            try:
                print(f"  [{attempt_idx + 1}/{len(self.FALLBACK_MODELS)}] 모델 시도: {model_name}")
                
                model = genai.GenerativeModel(model_name)
                response = model.generate_content(
                    prompt,
                    generation_config=genai.types.GenerationConfig(
                        temperature=0.3,  # 일관성 있는 구조 생성
                        max_output_tokens=8000,
                    )
                )
                
                # JSON 파싱
                blocks = self._parse_llm_response(response.text)
                
                print(f"✅ [LLM Formatter] {len(blocks)}개 블록 생성 완료 (모델: {model_name})")
                return blocks
                
            except Exception as e:
                last_error = e
                error_str = str(e)
                print(f"  ⚠️ 모델 {model_name} 실패: {error_str[:200]}")
                
                # 429 에러면 바로 폴백
                is_429 = any(kw in error_str.upper() for kw in ["429", "RESOURCE_EXHAUSTED", "QUOTA", "RATE LIMIT"])
                if is_429 and attempt_idx < len(self.FALLBACK_MODELS) - 1:
                    import time
                    time.sleep(1)
                    continue
                
                # 마지막 모델이 아니면 계속 시도
                if attempt_idx < len(self.FALLBACK_MODELS) - 1:
                    continue
        
        # 모든 모델 실패 시 에러 블록 반환
        print(f"❌ [LLM Formatter] 모든 모델 실패: {last_error}")
        import traceback
        traceback.print_exc()
        
        # Fallback: 기본 구조
        return self._create_fallback_blocks(final_report)
    
    def _simplify_report(self, final_report: Dict[str, Any]) -> Dict[str, Any]:
        """리포트를 LLM이 처리하기 쉬운 형태로 단순화"""
        simplified = {
            "title": "개인 맞춤 건강 리포트",
            "generated_at": final_report.get("generated_at", ""),
            "survey_summary": final_report.get("survey_summary", {}),
            "sections": []
        }
        
        tabs = final_report.get("tabs", [])
        sections = final_report.get("sections", {})
        
        for tab_key in tabs:
            section = sections.get(tab_key, {})
            if not section:
                continue
            
            section_data = {
                "key": tab_key,
                "title": section.get("title", tab_key),
                "cards": []
            }
            
            # 카드 추출
            if "subsections" in section:
                for subsection in section.get("subsections", []):
                    for card in subsection.get("cards", []):
                        section_data["cards"].append({
                            "type": card.get("type", ""),
                            "text": card.get("text", "")
                        })
            elif "cards" in section:
                section_data["cards"] = [
                    {"type": c.get("type", ""), "text": c.get("text", "")}
                    for c in section.get("cards", [])
                ]
            
            # 신뢰도
            if "reliability_score" in section:
                section_data["reliability_score"] = section["reliability_score"]
            
            # 이미지
            if "future_image_url" in section:
                section_data["image_url"] = section["future_image_url"]
            
            simplified["sections"].append(section_data)
        
        return simplified
    
    def _build_formatting_prompt(self, simplified_report: Dict[str, Any]) -> str:
        """LLM 프롬프트 생성"""
        report_json = json.dumps(simplified_report, ensure_ascii=False, indent=2)
        
        prompt = f"""
{self.schema_guide.FORMATTING_INSTRUCTIONS}

# Notion Block Schema Reference
{self.schema_guide.SCHEMA_EXAMPLES}

---

# 변환할 건강 리포트 데이터
```json
{report_json}
```

---

# 작업 지시
위 건강 리포트 데이터를 아름답고 전문적인 Notion 페이지로 변환하세요.

## 필수 요구사항
1. **Hero Section**: 제목 + 요약 callout
2. **각 섹션**: heading으로 구분, 설명 callout 추가
3. **카드**: heading_3 + quote/callout로 구성
4. **신뢰도**: 있으면 progress bar 스타일로 표시 (🟩/🟦/🟨)
5. **이미지**: 있으면 image 블록 추가
6. **Footer**: 마무리 메시지
7. **적절한 공백**: paragraph("")로 가독성 확보

## 색상 가이드
- goals: purple_background
- sleep: blue_background
- uv: yellow_background
- lifestyle: green_background
- activity: orange_background
- problem 카드: red_background
- action 카드: green_background

## 출력 형식
**반드시 유효한 JSON 배열만 출력하세요.** 다른 텍스트는 포함하지 마세요.

예시:
```json
[
  {{"object": "block", "type": "heading_1", "heading_1": {{"rich_text": [{{"type": "text", "text": {{"content": "제목"}}}}]}}}},
  ...
]
```

시작:
"""
        return prompt
    
    def _parse_llm_response(self, response_text: str) -> List[Dict[str, Any]]:
        """LLM 응답에서 JSON 추출 및 파싱"""
        print(f"[LLM Parser] 응답 길이: {len(response_text)} 문자")
        
        # JSON 코드 블록 제거
        text = response_text.strip()
        
        # ```json ... ``` 제거
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        
        if text.endswith("```"):
            text = text[:-3]
        
        text = text.strip()
        
        # JSON 파싱 시도 1: 원본
        try:
            parsed = json.loads(text)
            print(f"[LLM Parser] ✅ JSON 파싱 성공, 타입: {type(parsed)}")
            
            if not isinstance(parsed, list):
                print(f"⚠️ LLM이 배열이 아닌 객체를 반환했습니다: {type(parsed)}")
                print(f"응답 내용: {str(parsed)[:500]}")
                return []
            
            print(f"[LLM Parser] 파싱된 블록 개수: {len(parsed)}")
            return self._validate_and_filter_blocks(parsed)
            
        except json.JSONDecodeError as e:
            print(f"⚠️ JSON 파싱 실패: {e}")
            print(f"  위치: line {e.lineno}, column {e.colno}")
        
        # JSON 파싱 시도 2: 끝에 ] 추가
        if not text.endswith("]"):
            print(f"[LLM Parser] 🔧 JSON 복구 시도 1: 끝에 ] 추가")
            try:
                # 마지막 완성된 객체까지만 파싱
                last_complete = text.rfind("},")
                if last_complete > 0:
                    repaired_text = text[:last_complete + 1] + "\n]"
                    parsed = json.loads(repaired_text)
                    if isinstance(parsed, list):
                        print(f"[LLM Parser] ✅ 복구 성공! {len(parsed)}개 블록")
                        return self._validate_and_filter_blocks(parsed)
            except:
                pass
        
        # JSON 파싱 시도 3: 불완전한 마지막 객체 제거
        print(f"[LLM Parser] 🔧 JSON 복구 시도 2: 불완전한 객체 제거")
        try:
            # { 로 시작하는 가장 마지막 위치 찾기
            last_object_start = text.rfind("\n  {")
            if last_object_start > 0:
                repaired_text = text[:last_object_start].strip()
                if repaired_text.endswith(","):
                    repaired_text = repaired_text[:-1]
                repaired_text += "\n]"
                parsed = json.loads(repaired_text)
                if isinstance(parsed, list):
                    print(f"[LLM Parser] ✅ 복구 성공! {len(parsed)}개 블록")
                    return self._validate_and_filter_blocks(parsed)
        except Exception as repair_error:
            print(f"  복구 실패: {repair_error}")
        
        # 모든 시도 실패
        print(f"❌ [LLM Parser] 모든 JSON 파싱 시도 실패")
        print(f"응답 앞 500자:\n{text[:500]}")
        print(f"응답 뒤 500자:\n{text[-500:]}")
        return []
    
    def _validate_and_filter_blocks(self, blocks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """블록 유효성 검증 및 필터링"""
        valid_blocks = []
        for idx, block in enumerate(blocks):
            if self._validate_block(block):
                valid_blocks.append(block)
            else:
                print(f"⚠️ [{idx}] 유효하지 않은 블록: type={block.get('type', 'missing')}, keys={list(block.keys())}")
        
        print(f"[LLM Parser] 유효성 검증 통과: {len(valid_blocks)}/{len(blocks)} 블록")
        return valid_blocks
    
    def _validate_block(self, block: Dict[str, Any]) -> bool:
        """Notion block 유효성 검증"""
        if not isinstance(block, dict):
            return False
        
        if "object" not in block or block["object"] != "block":
            return False
        
        if "type" not in block:
            return False
        
        block_type = block["type"]
        
        # type 필드와 동일한 키가 있어야 함
        if block_type not in block:
            return False
        
        return True
    
    def _create_fallback_blocks(self, final_report: Dict[str, Any]) -> List[Dict[str, Any]]:
        """LLM 실패 시 기본 구조"""
        return [
            {
                "object": "block",
                "type": "heading_1",
                "heading_1": {
                    "rich_text": [{"type": "text", "text": {"content": "🧬 BioStream 건강 리포트"}}]
                }
            },
            {
                "object": "block",
                "type": "callout",
                "callout": {
                    "rich_text": [{"type": "text", "text": {"content": "리포트 생성 중 오류가 발생했습니다."}}],
                    "icon": {"type": "emoji", "emoji": "⚠️"},
                    "color": "yellow_background"
                }
            }
        ]


# ════════════════════════════════════════════════════════════════
#  메인 함수
# ════════════════════════════════════════════════════════════════

def format_report_with_llm(final_report: Dict[str, Any], output_file: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    LLM을 사용하여 리포트를 Notion block으로 변환
    
    Args:
        final_report: LangGraph 최종 리포트
        output_file: 결과 저장 파일 (optional)
    
    Returns:
        Notion block 배열
    """
    formatter = NotionLLMFormatter()
    blocks = formatter.format_report_with_llm(final_report)
    
    if output_file:
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(blocks, f, indent=2, ensure_ascii=False)
            print(f"✅ LLM 생성 블록 저장: {output_file}")
        except Exception as e:
            print(f"⚠️ 파일 저장 실패: {e}")
    
    return blocks


# ════════════════════════════════════════════════════════════════
#  테스트
# ════════════════════════════════════════════════════════════════

def test_llm_formatter():
    """LLM Formatter 테스트"""
    print("=" * 60)
    print("LLM Notion Formatter 테스트")
    print("=" * 60)
    
    sample = {
        "tabs": ["sleep", "uv"],
        "sections": {
            "sleep": {
                "title": "수면 및 리듬",
                "cards": [
                    {"type": "problem", "text": "수면 시간이 5.5시간으로 부족합니다."},
                    {"type": "action", "text": "매일 밤 11시 이전 취침을 권장합니다."}
                ],
                "reliability_score": 0.92
            },
            "uv": {
                "title": "자외선 관리",
                "cards": [
                    {"type": "problem", "text": "자외선 차단제 사용이 부족합니다."}
                ]
            }
        },
        "generated_at": "2026-02-18"
    }
    
    blocks = format_report_with_llm(sample, output_file="notion_blocks_llm_test.json")
    
    print(f"\n✅ 생성 완료: {len(blocks)}개 블록")
    return blocks


if __name__ == "__main__":
    test_llm_formatter()
