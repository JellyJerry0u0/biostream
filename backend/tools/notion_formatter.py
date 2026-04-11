"""
Notion Formatter: LangGraph final_report → Notion Blocks 변환
더 예쁘고 구조화된 디자인으로 리포트를 Notion에 표시

주요 기능:
- 섹션별 테마 색상 및 이모지 적용
- 카드는 Heading + Quote 블록으로 세련되게 표시
- 신뢰도는 Progress Bar로 시각화 (🟩🟩🟩...)
- 과학적 근거는 토글로 접어서 깔끔하게 정리
- Hero Section과 안내 메시지로 전문적인 느낌
"""

import os
import sys
import json
from typing import Dict, Any, List, Optional
from datetime import datetime

# .env 파일 로드
try:
    from dotenv import load_dotenv
    env_paths = [
        os.path.join(os.path.dirname(__file__), '.env'),
        os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'),
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env'),
    ]
    for env_path in env_paths:
        if os.path.exists(env_path):
            load_dotenv(env_path)
            break
except ImportError:
    pass

# 경로 설정
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.append(backend_dir)


class NotionBlockBuilder:
    """Notion Block 생성 헬퍼 클래스"""

    @staticmethod
    def _normalize_emoji(emoji: Optional[str], default: str = "💡") -> str:
        """Notion callout icon용 emoji 정규화 (빈 값 방지)"""
        if emoji is None:
            return default

        normalized = str(emoji).strip()
        if not normalized:
            return default

        return normalized
    
    @staticmethod
    def heading_1(text: str) -> Dict[str, Any]:
        """Heading 1 블록"""
        return {
            "object": "block",
            "type": "heading_1",
            "heading_1": {
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }
    
    @staticmethod
    def heading_2(text: str) -> Dict[str, Any]:
        """Heading 2 블록"""
        return {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }
    
    @staticmethod
    def heading_3(text: str) -> Dict[str, Any]:
        """Heading 3 블록"""
        return {
            "object": "block",
            "type": "heading_3",
            "heading_3": {
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }
    
    @staticmethod
    def paragraph(text: str, bold: bool = False, italic: bool = False) -> Dict[str, Any]:
        """Paragraph 블록"""
        if not text:
            text = " "
        
        annotations = {}
        if bold:
            annotations["bold"] = True
        if italic:
            annotations["italic"] = True
        
        rich_text = {"type": "text", "text": {"content": text}}
        if annotations:
            rich_text["annotations"] = annotations
        
        return {
            "object": "block",
            "type": "paragraph",
            "paragraph": {"rich_text": [rich_text]}
        }
    
    @staticmethod
    def quote(text: str, color: str = "default") -> Dict[str, Any]:
        """Quote 블록 (강조용)"""
        return {
            "object": "block",
            "type": "quote",
            "quote": {
                "rich_text": [{"type": "text", "text": {"content": text}}],
                "color": color
            }
        }
    
    @staticmethod
    def callout(text: str, emoji: str = "💡", color: str = "gray_background") -> Dict[str, Any]:
        """Callout 블록"""
        icon_emoji = NotionBlockBuilder._normalize_emoji(emoji)
        return {
            "object": "block",
            "type": "callout",
            "callout": {
                "rich_text": [{"type": "text", "text": {"content": text}}],
                "icon": {"type": "emoji", "emoji": icon_emoji},
                "color": color
            }
        }
    
    @staticmethod
    def bulleted_list_item(text: str) -> Dict[str, Any]:
        """Bulleted list item 블록"""
        return {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }
    
    @staticmethod
    def toggle(title: str, children: List[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Toggle 블록 (접을 수 있는 블록)"""
        toggle_block = {
            "object": "block",
            "type": "toggle",
            "toggle": {
                "rich_text": [{"type": "text", "text": {"content": title}}]
            }
        }
        if children:
            toggle_block["toggle"]["children"] = children
        return toggle_block
    
    @staticmethod
    def divider() -> Dict[str, Any]:
        """Divider 블록"""
        return {
            "object": "block",
            "type": "divider",
            "divider": {}
        }
    
    @staticmethod
    def image(url: str, caption: str = "") -> Dict[str, Any]:
        """Image 블록"""
        image_block = {
            "object": "block",
            "type": "image",
            "image": {
                "type": "external",
                "external": {"url": url}
            }
        }
        if caption:
            image_block["image"]["caption"] = [
                {"type": "text", "text": {"content": caption}}
            ]
        return image_block


class NotionReportFormatter:
    """개선된 시각적 디자인을 적용한 Notion Report Formatter"""
    
    def __init__(self):
        self.builder = NotionBlockBuilder()
        
        # 🎨 섹션별 테마 설정
        self.section_themes = {
            "goals": {
                "title": "🎯 주요 목표 분석 및 개선 방안",
                "emoji": "🎯",
                "color": "purple_background",
                "description": "당신의 피부 건강 목표와 맞춤형 케어 전략을 제시합니다"
            },
            "sleep": {
                "title": "😴 수면 및 생체 리듬",
                "emoji": "😴",
                "color": "blue_background",
                "description": "수면 패턴이 피부 재생에 미치는 영향을 분석합니다"
            },
            "uv": {
                "title": "☀️ 자외선 및 노화 관리",
                "emoji": "☀️",
                "color": "yellow_background",
                "description": "자외선 노출과 피부 보호 전략을 제시합니다"
            },
            "lifestyle": {
                "title": "🏃 생활습관 관리",
                "emoji": "🏃",
                "color": "green_background",
                "description": "일상 습관이 피부 건강에 미치는 영향을 분석합니다"
            },
            "activity": {
                "title": "💪 활동 및 대사",
                "emoji": "💪",
                "color": "orange_background",
                "description": "운동과 대사가 피부 건강에 미치는 영향을 분석합니다"
            }
        }
        
        # 🎨 카드 타입별 스타일
        self.card_styles = {
            "problem": {
                "title": "현재 상태",
                "emoji": "🔍",
                "color": "red_background"
            },
            "cause": {
                "title": "왜 이런 상태인가",
                "emoji": "🧬",
                "color": "orange_background"
            },
            #왜 실제 노션에서는 실천 방안이 보이지 않을까?
            "action": {
                "title": "당신에게 필요한 행동 3가지",
                "emoji": "💡",
                "color": "green_background"
            },
            "simulation": {
                "title": "예상 효과",
                "emoji": "📊",
                "color": "blue_background"
            }
        }
    
    #핵심 컨트롤러
    def convert_report_to_blocks(self, final_report: Dict[str, Any]) -> List[Dict[str, Any]]:
        """리포트를 Notion Block으로 변환"""
        blocks = []
        
        # 📌 Hero Section
        blocks.extend(self._create_hero_section(final_report))
        
        # 📋 섹션들
        sections = final_report.get("sections", {})
        tabs = final_report.get("tabs", [])
        
        for i, tab in enumerate(tabs, 1):
            section_data = sections.get(tab, {})
            if not section_data:
                continue
            
            section_blocks = self._create_section(tab, section_data, section_number=i)
            blocks.extend(section_blocks)
            
            # 섹션 구분선 (마지막 제외)
            if i < len(tabs):
                blocks.append(self.builder.divider())
                blocks.append(self.builder.divider())
                blocks.append(self.builder.paragraph(""))
        
        # 🎊 Footer
        blocks.extend(self._create_footer())
        
        return blocks
    
    #리포트 상단 디자인 생성
    def _create_hero_section(self, final_report: Dict[str, Any]) -> List[Dict[str, Any]]:
        """멋진 Hero Section 생성"""
        blocks = []
        
        # 메인 타이틀
        blocks.append(self.builder.heading_1("🧬 개인 맞춤 건강 리포트 결과"))
        blocks.append(self.builder.paragraph("AI 기반 피부 분석 및 맞춤 케어 인사이트 제공"))
        blocks.append(self.builder.divider())

        # 요약 정보 Callout
        survey_summary = final_report.get("survey_summary", {})
        generated_at = final_report.get("generated_at", "")
        
        if survey_summary:
           
            outcomes = survey_summary.get("outcomes", [])
            target_years = survey_summary.get("target_years", 30)
            
            outcome_labels = {
                "wrinkles": "주름",
                "elasticity": "탄력",
                "pigmentation": "색소침착",
                "hydration": "수분",
                "skin_barrier": "피부 장벽",
                "acne": "여드름",
                "redness": "홍조",
                "overall_aging": "전체 노화"
            }

            outcome_text = ", ".join([outcome_labels.get(o, o) for o in outcomes])

            #KPI 스타일 카드 3개 
            blocks.append(self.builder.callout(
            f"주요 피부 고민\n{outcome_text}",
            emoji="🎯",
            color="purple_background"
        ))
 
            blocks.append(self.builder.callout(
            f"목표 연령\n{target_years}세",
            emoji="🎂",
            color="blue_background"
        ))

            blocks.append(self.builder.callout(
                f"리포트 생성\n{generated_at}",
                emoji="📅",
                color="gray_background"
            ))
        
        blocks.append(self.builder.divider())
        blocks.append(self.builder.paragraph(""))
        
        # 안내 메시지
        intro = (
            "이 리포트는 당신의 생활습관 데이터와 관련 연구 자료를 기반으로 "
            "개인 맞춤형 건강 개선 방안을 제시합니다. "
            "각 섹션은 현재 상태, 문제 진단, 당신에게 필요한 행동 3가지, 예상 효과로 구성되어 있습니다."
        )
        blocks.append(self.builder.callout(intro, emoji="💡", color="gray_background"))



        generated_image_url = final_report.get("generated_image_url")
        if generated_image_url:
            blocks.append(self.builder.paragraph(""))
            blocks.append(self.builder.heading_3("🖼️ AI 예측 시뮬레이션"))
            blocks.append(self.builder.callout(
                "아래 이미지는 현재 입력 데이터를 바탕으로 생성된 AI 예측 이미지입니다.",
                emoji="🔮",
                color="blue_background"
            ))
            blocks.append(self.builder.image(
                generated_image_url,
                caption="AI 생성 미래 예측 이미지"
            ))

        blocks.append(self.builder.divider())
        blocks.append(self.builder.paragraph(""))
        
        return blocks
    
    def _format_summary(self, survey_summary: Dict[str, Any]) -> str:
        """설문 요약 포맷팅"""
        outcomes = survey_summary.get("outcomes", [])
        target_years = survey_summary.get("target_years", 30)
        
        outcome_labels = {
           {
  "wrinkles": "주름",
  "elasticity": "탄력",
  "pigmentation": "색소침착",
  "hydration": "수분",
  "skin_barrier": "피부 장벽",
  "acne": "여드름",
  "redness": "홍조",
  "overall_aging": "전체 노화"
}

        }
        
        outcome_text = ", ".join([outcome_labels.get(o, o) for o in outcomes])
        return f"주요 피부 고민: {outcome_text} | 목표 연도: {target_years}세"
    
    def _create_section(self, section_key: str, section_data: Dict[str, Any], section_number: int) -> List[Dict[str, Any]]:
        """섹션 생성"""
        blocks = []
        
        # 섹션 헤더
        theme = self.section_themes.get(section_key, {
            "title": section_data.get("title", section_key),
            "emoji": "📋",
            "color": "gray_background",
            "description": ""
        })
        
        # 제목 (번호 포함)
        blocks.append(self.builder.heading_1(f"{section_number}. {theme['title']}"))
        
        # 설명
        if theme.get("description"):
            blocks.append(self.builder.callout(
                theme["description"],
                emoji=theme["emoji"],
                color=theme["color"]
            ))
        
        blocks.append(self.builder.paragraph(""))

        # 신뢰도 점수 (카드 상단 배치)
        reliability_score = section_data.get("reliability_score")
        if reliability_score is not None:
            blocks.extend(self._create_reliability(reliability_score))
            blocks.append(self.builder.paragraph(""))
        
        # 카드 또는 서브섹션
        if "subsections" in section_data:
            for subsection in section_data.get("subsections", []):
                blocks.extend(self._create_subsection(subsection))
        elif "cards" in section_data:
            blocks.extend(self._create_cards(section_data.get("cards", [])))
        
        # 과학적 근거
        evidence_refs = section_data.get("evidence_refs", {})
        if evidence_refs:
            blocks.extend(self._create_evidence(evidence_refs))
        
        # AI 예측 이미지
        image_url = section_data.get("future_image_url") or section_data.get("image_url")
        if image_url:
            blocks.extend(self._create_image_section(image_url, theme))
        
        return blocks
    
    def _create_subsection(self, subsection: Dict[str, Any]) -> List[Dict[str, Any]]:
        """하위 섹션 (lifestyle용)"""
        blocks = []
        
        title = subsection.get("title", "")
        blocks.append(self.builder.heading_2(f"📌 {title}"))
        blocks.append(self.builder.paragraph(""))
        
        cards = subsection.get("cards", [])
        blocks.extend(self._create_cards(cards))
        
        return blocks
    
    def _create_cards(self, cards: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
     blocks = []

     card_map: Dict[str, Dict[str, Any]] = {}
     for card in cards:
        card_type = card.get("type")
        if card_type:
            card_map[card_type] = card

     # 1) 진단 섹션 (problem + cause)
     problem_text = str(card_map.get("problem", {}).get("text", "")).strip()
     cause_text = str(card_map.get("cause", {}).get("text", "")).strip()

     if problem_text or cause_text:
        diagnosis_lines = []
        if problem_text:
            diagnosis_lines.append(f"🚩 현상: {problem_text}")
        if cause_text:
            diagnosis_lines.append(f"🧬 원인: {cause_text}")

        blocks.append(self.builder.heading_3("🔍 핵심 진단"))
        blocks.append(self.builder.callout(
            "\n".join(diagnosis_lines),
            emoji="🔍",
            color="red_background"
        ))
        blocks.append(self.builder.paragraph(""))

     # 2) 솔루션 섹션 (action)
     action_card = card_map.get("action", {})
     action_text = str(action_card.get("text", "")).strip()
     action_items = action_card.get("items", [])

     has_action_items = isinstance(action_items, list) and len(action_items) > 0
     if action_text or has_action_items:
        blocks.append(self.builder.heading_3("✅ 당신을 위한 맞춤 솔루션"))

        if action_text:
            blocks.append(self.builder.callout(
                action_text,
                emoji="💡",
                color="green_background"
            ))

        if has_action_items:
            for idx, item in enumerate(action_items, 1):
                if isinstance(item, dict):
                    item_title = str(item.get("title", "")).strip()
                    item_detail = str(item.get("detail", "")).strip()

                    if item_title and item_detail:
                        item_text = f"{idx}. {item_title}: {item_detail}"
                    elif item_title:
                        item_text = f"{idx}. {item_title}"
                    elif item_detail:
                        item_text = f"{idx}. {item_detail}"
                    else:
                        continue
                else:
                    item_text = str(item).strip()
                    if not item_text:
                        continue
                    item_text = f"{idx}. {item_text}"

                blocks.append(self.builder.bulleted_list_item(item_text))

        blocks.append(self.builder.paragraph(""))

     # 3) 시뮬레이션 섹션 (simulation)
     simulation_text = str(card_map.get("simulation", {}).get("text", "")).strip()
     if simulation_text:
        blocks.append(self.builder.heading_3("📈 예상 효과"))
        blocks.append(self.builder.quote(
            f"미래 예측: {simulation_text}",
            color="blue_background"
        ))
        blocks.append(self.builder.paragraph(""))

     return blocks

    
    def _create_reliability(self, score: float) -> List[Dict[str, Any]]:
        """신뢰도 점수를 직관적인 게이지로 표시"""
        percent = int(max(0.0, min(1.0, score)) * 100)
        filled_blocks = int(max(0.0, min(1.0, score)) * 10)
        bar = "🟩" * filled_blocks + "⬜" * (10 - filled_blocks)

        return [
            self.builder.paragraph(f"데이터 분석 신뢰도: {percent}%", bold=True),
            self.builder.paragraph(bar)
        ]
    
    def _create_evidence(self, evidence_refs: Dict[str, Any]) -> List[Dict[str, Any]]:
        """과학적 근거 (Toggle로 접기)"""
        blocks = []
        
        narrative_refs = evidence_refs.get("narrative", [])
        quant_refs = evidence_refs.get("quant", [])
        
        if not narrative_refs and not quant_refs:
            return blocks
        
        blocks.append(self.builder.heading_3("📚 과학적 근거"))
        
        # Toggle 내용
        children = []
        
        # 정량 데이터
        if quant_refs:
            children.append(self.builder.heading_3("📊 정량 데이터 분석"))
            children.append(self.builder.paragraph(
                "여러 논문의 데이터를 종합한 정량적 분석 결과입니다.",
                italic=True
            ))
            for ref in quant_refs[:5]:
                formatted = self._format_quant_ref(ref)
                if formatted:
                    children.append(self.builder.bulleted_list_item(formatted))
            children.append(self.builder.paragraph(""))
        
        # 참고 논문
        if narrative_refs:
            children.append(self.builder.heading_3("📄 참고 논문"))
            children.append(self.builder.paragraph(
                "이 분석의 근거가 된 주요 연구 논문들입니다.",
                italic=True
            ))
            for ref in narrative_refs[:5]:
                children.append(self.builder.bulleted_list_item(
                    self._format_narrative_ref(ref)
                ))
        
        blocks.append(self.builder.toggle(
            "🔬 과학적 근거 자세히 보기 (클릭)",
            children=children
        ))
        blocks.append(self.builder.paragraph(""))
        
        return blocks
    
    def _format_quant_ref(self, ref: Dict[str, Any]) -> str:
        """정량 근거 포맷팅"""
        # 레거시 스키마: outcome/factor/effect/n_papers
        outcome = str(ref.get("outcome", "")).strip()
        factor = str(ref.get("factor", "")).strip()
        effect = str(ref.get("effect", "")).strip()

        # 현재 스키마(report_graph quant_refs): outcome_mapped/effect_signed_value/effect_unit/timeframe_days/p_label/paper_id
        if not outcome:
            outcome = str(ref.get("outcome_mapped", "")).strip()

        if not effect:
            signed_value = ref.get("effect_signed_value")
            unit = str(ref.get("effect_unit", "")).strip()
            if signed_value not in (None, ""):
                effect = f"{signed_value}{unit}" if unit else str(signed_value)

        timeframe_days = ref.get("timeframe_days")
        timeframe_label = ""
        if isinstance(timeframe_days, (int, float)):
            timeframe_label = f"약 {int(timeframe_days)}일"

        p_label = str(ref.get("p_label", "")).strip()

        n_papers_raw = ref.get("n_papers")
        if isinstance(n_papers_raw, (int, float)):
            n_papers = int(n_papers_raw)
        else:
            n_papers = 1 if str(ref.get("paper_id", "")).strip() else 0

        # 완전히 비어있는 행은 출력하지 않음
        if not any([outcome, factor, effect, timeframe_label, p_label, n_papers]):
            return ""

        if factor:
            headline = f"{factor} → {outcome or '지표'}"
        else:
            headline = outcome or "정량 지표"

        detail_parts = []
        if effect:
            detail_parts.append(effect)
        if timeframe_label:
            detail_parts.append(timeframe_label)
        if p_label:
            detail_parts.append(p_label)

        detail_text = " | ".join(detail_parts) if detail_parts else "효과 값 정보 없음"
        return f"{headline}: {detail_text} (논문 {n_papers}편 분석)"
    
    def _format_narrative_ref(self, ref: Dict[str, Any]) -> str:
        """서술 근거 포맷팅"""
        title = ref.get("title", "")
        pmid = ref.get("pmid", "")
        return f"{title} (PMID: {pmid})" if pmid else title
    
    def _create_image_section(self, image_url: str, theme: Dict[str, Any]) -> List[Dict[str, Any]]:
        """AI 예측 이미지 섹션"""
        blocks = []
        
        blocks.append(self.builder.heading_3("🖼️ AI 예측 시뮬레이션"))
        blocks.append(self.builder.callout(
            "아래는 현재 습관을 유지했을 때와 개선했을 때의 미래 모습을 AI로 시뮬레이션한 결과입니다.",
            emoji="🔮",
            color="blue_background"
        ))
        
        caption = f"{theme.get('title', '')} - AI 생성 미래 예측 이미지"
        blocks.append(self.builder.image(image_url, caption=caption))
        blocks.append(self.builder.paragraph(""))
        
        return blocks
    
    def _create_footer(self) -> List[Dict[str, Any]]:
        """Footer"""
        blocks = []
        
        blocks.append(self.builder.divider())
        blocks.append(self.builder.callout(
            "✨ 건강한 변화는 작은 습관에서 시작됩니다. 오늘부터 한 가지씩 실천해보세요!",
            emoji="💪",
            color="green_background"
        ))
        
        return blocks


# ════════════════════════════════════════════════════════════════
#  DB 로드 및 메인 변환 함수
# ════════════════════════════════════════════════════════════════

def load_report_from_db(user_id: int, lifestyle_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
    """DB에서 리포트 로드"""
    try:
        from app.database import get_db
        from app.models import Lifestyle, Report
    except (ImportError, Exception) as e:
        print(f"❌ DB 모듈 import 실패: {e}")
        return None

    try:
        db_gen = get_db()
        db = next(db_gen)
    except Exception as e:
        print(f"❌ DB 연결 실패: {e}")
        return None

    try:
        if lifestyle_id:
            lifestyle = db.query(Lifestyle).filter(
                Lifestyle.id == lifestyle_id,
                Lifestyle.user_id == user_id,
            ).first()
        else:
            lifestyle = db.query(Lifestyle).filter(
                Lifestyle.user_id == user_id
            ).order_by(Lifestyle.created_at.desc()).first()

        report_row = (
            db.query(Report).filter(Report.lifestyle_id == lifestyle.id).first()
            if lifestyle
            else None
        )
        if not lifestyle or not report_row or not report_row.report:
            print(f"⚠️ 리포트를 찾을 수 없습니다. (user_id={user_id})")
            return None

        print(f"✅ 리포트 로드 완료 (lifestyle_id={lifestyle.id})")
        return report_row.report
        
    except Exception as e:
        print(f"❌ 리포트 로드 실패: {e}")
        return None
    finally:
        db.close()


# 리포트를 Notion Block으로 변환하는 메인 함수
def format_report_to_notion(final_report: Dict[str, Any], output_file: Optional[str] = None) -> List[Dict[str, Any]]:
    """리포트를 Notion Block으로 변환"""
    formatter = NotionReportFormatter()
    blocks = formatter.convert_report_to_blocks(final_report)
    
    if output_file:
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(blocks, f, indent=2, ensure_ascii=False)
            print(f"✅ Notion blocks 저장: {output_file}")
        except Exception as e:
            print(f"⚠️ 파일 저장 실패: {e}")
    
    return blocks #Notion에 바로 POST 가능한 블록 리스트 반환


# ════════════════════════════════════════════════════════════════
#  테스트 함수
# ════════════════════════════════════════════════════════════════

def test_with_sample():
    """샘플 데이터로 테스트"""
    print("=" * 60)
    print("Notion Formatter 테스트 (샘플)")
    print("=" * 60)
    
    sample = {
        "tabs": ["sleep", "uv"],
        "sections": {
            "sleep": {
                "title": "수면 및 리듬",
                "cards": [
                    {"type": "problem", "text": "수면 시간이 5.5시간으로 권장 시간보다 부족합니다."},
                    {"type": "cause", "text": "수면 부족은 피부 재생을 방해하고 염증을 증가시킵니다."},
                    {"type": "action", "text": "매일 밤 11시 이전에 취침하고 7시간 이상 수면하세요."},
                    {"type": "simulation", "text": "3개월간 충분한 수면 시 피부 탄력 15% 개선 예상."}
                ],
                "reliability_score": 0.92,
                "evidence_refs": {
                    "narrative": [
                        {"title": "Sleep and Skin Aging", "pmid": "123456"}
                    ],
                    "quant": [
                        {"outcome": "wrinkles", "factor": "sleep_hours", "effect": "-20%", "n_papers": 5}
                    ]
                }
            },
            "uv": {
                "title": "자외선 관리",
                "cards": [
                    {"type": "problem", "text": "자외선 차단제 사용이 주 2회로 부족합니다."},
                    {"type": "action", "text": "매일 아침 자외선 차단제를 바르세요."}
                ]
            }
        },
        "survey_summary": {
            "outcomes": ["acne", "wrinkles"],
            "target_years": 30
        },
        "generated_at": "2026-02-10 19:30:00"
    }
    
    blocks = format_report_to_notion(sample, output_file="notion_blocks_sample.json")
    
    print(f"\n✅ 변환 완료: {len(blocks)}개 블록")
    print(f"📄 'notion_blocks_sample.json' 파일을 확인하세요")
    
    return blocks


def test_with_real_report(user_id: int = 1):
    """실제 리포트로 테스트"""
    print("=" * 60)
    print(f"Notion Formatter 테스트 (User {user_id})")
    print("=" * 60)
    
    final_report = load_report_from_db(user_id)
    
    if not final_report:
        print("\n⚠️ 리포트를 찾을 수 없습니다. 샘플로 전환합니다.")
        return test_with_sample()
    
    blocks = format_report_to_notion(final_report, output_file="notion_blocks_output.json")
    
    print(f"\n✅ 변환 완료: {len(blocks)}개 블록")
    print(f"📄 'notion_blocks_output.json' 파일을 확인하세요")
    
    return blocks


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Notion Formatter")
    parser.add_argument("--user-id", type=int, default=1, help="사용자 ID")
    parser.add_argument("--sample", action="store_true", help="샘플 데이터 사용")
    
    args = parser.parse_args()
    
    if args.sample:
        test_with_sample()
    else:
        test_with_real_report(user_id=args.user_id)
