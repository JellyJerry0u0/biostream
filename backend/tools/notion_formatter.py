"""
Notion Formatter: LangGraph final_report → Notion Blocks 변환
- final_report JSON 구조를 Notion Block 형태로 매핑
- 카드별 포맷팅 (problem, cause, action, simulation)
- 근거 참조 링크 추가
- 신뢰도 점수 표시 (RAGAS)
- 이미지 블록 추가 (S3 URL)

매핑 구조:
1. 섹션 제목 (Title) → Heading 1 (#)
2. 4개 카드 (Problem/Cause 등) → Callout (카드별 배경색 적용)
3. 신뢰도 점수 (RAGAS) → Callout ("신뢰도: 92% (Verified)" 표시)
4. 인용 근거 (Evidence) → Toggle List (클릭 시 상세 논문 정보 노출)
5. 생성된 미래 사진 → Image Block (S3 URL 이용)
"""

import os
import sys
import json
from typing import Dict, Any, List, Optional
from datetime import datetime

# .env 파일 로드 (python-dotenv가 설치되어 있으면)
try:
    from dotenv import load_dotenv
    # 우선순위: 1) backend/tools/.env  2) backend/.env  3) root/.env
    env_paths = [
        os.path.join(os.path.dirname(__file__), '.env'),
        os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'),
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env'),
    ]
    for env_path in env_paths:
        if os.path.exists(env_path):
            load_dotenv(env_path)
            print(f"✅ 환경변수 로드: {env_path}")
            break
except ImportError:
    print("⚠️ python-dotenv가 설치되지 않았습니다. 환경변수를 수동으로 설정하세요.")

# 경로 설정
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.append(backend_dir)


class NotionBlockBuilder:
    """Notion Block 생성 헬퍼 클래스"""
    
    @staticmethod
    def heading_1(text: str) -> Dict[str, Any]:
        """Heading 1 블록 생성"""
        return {
            "object": "block",
            "type": "heading_1",
            "heading_1": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {"content": text}
                    }
                ]
            }
        }
    
    @staticmethod
    def heading_2(text: str) -> Dict[str, Any]:
        """Heading 2 블록 생성"""
        return {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {"content": text}
                    }
                ]
            }
        }
    
    @staticmethod
    def heading_3(text: str) -> Dict[str, Any]:
        """Heading 3 블록 생성"""
        return {
            "object": "block",
            "type": "heading_3",
            "heading_3": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {"content": text}
                    }
                ]
            }
        }
    
    @staticmethod
    def paragraph(text: str, bold: bool = False, italic: bool = False) -> Dict[str, Any]:
        """Paragraph 블록 생성"""
        if not text:
            text = " "
        
        annotations = {}
        if bold:
            annotations["bold"] = True
        if italic:
            annotations["italic"] = True
        
        rich_text = {
            "type": "text",
            "text": {"content": text}
        }
        if annotations:
            rich_text["annotations"] = annotations
        
        return {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [rich_text]
            }
        }
    
    @staticmethod
    def bulleted_list_item(text: str) -> Dict[str, Any]:
        """Bulleted list item 블록 생성"""
        return {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {"content": text}
                    }
                ]
            }
        }
    
    @staticmethod
    def callout(text: str, emoji: str = "💡", color: str = "gray_background") -> Dict[str, Any]:
        """Callout 블록 생성"""
        return {
            "object": "block",
            "type": "callout",
            "callout": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {"content": text}
                    }
                ],
                "icon": {
                    "type": "emoji",
                    "emoji": emoji
                },
                "color": color
            }
        }
    
    @staticmethod
    def toggle(title: str, children: List[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Toggle 블록 생성 (접을 수 있는 블록)"""
        toggle_block = {
            "object": "block",
            "type": "toggle",
            "toggle": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {"content": title}
                    }
                ]
            }
        }
        if children:
            toggle_block["toggle"]["children"] = children
        return toggle_block
    
    @staticmethod
    def divider() -> Dict[str, Any]:
        """Divider 블록 생성"""
        return {
            "object": "block",
            "type": "divider",
            "divider": {}
        }
    
    @staticmethod
    def image(url: str, caption: str = "") -> Dict[str, Any]:
        """Image 블록 생성 (외부 URL)"""
        image_block = {
            "object": "block",
            "type": "image",
            "image": {
                "type": "external",
                "external": {
                    "url": url
                }
            }
        }
        if caption:
            image_block["image"]["caption"] = [
                {
                    "type": "text",
                    "text": {"content": caption}
                }
            ]
        return image_block


class NotionReportFormatter:
    """final_report → Notion Blocks 변환기"""
    
    def __init__(self):
        self.builder = NotionBlockBuilder()
        # 카드 타입별 Callout 스타일 (이미지 매핑 구조 반영)
        self.card_type_config = {
            "problem": {
                "title": "🔍 문제 진단",
                "emoji": "🔍",
                "color": "red_background"
            },
            "cause": {
                "title": "🧬 원인 분석",
                "emoji": "🧬",
                "color": "orange_background"
            },
            "action": {
                "title": "💡 실천 방안",
                "emoji": "💡",
                "color": "green_background"
            },
            "simulation": {
                "title": "📊 예상 효과",
                "emoji": "📊",
                "color": "blue_background"
            }
        }
        # 섹션별 제목 (한글)
        self.section_titles = {
            "goals": "주요 목표 분석 및 개선 방안",
            "sleep": "수면 및 리듬",
            "uv": "자외선 및 노화 관리",
            "lifestyle": "생활습관 관리",
            "activity": "활동 및 대사",
        }
    
    def convert_report_to_blocks(self, final_report: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        final_report JSON을 Notion Block 리스트로 변환
        
        Args:
            final_report: LangGraph에서 생성된 리포트 JSON
            
        Returns:
            Notion Block 리스트
        """
        blocks = []
        
        # 1. 리포트 제목
        blocks.append(self.builder.heading_1("🧬 BioStream 개인 맞춤 리포트"))
        blocks.append(self.builder.paragraph(""))
        
        # 2. 요약 정보
        survey_summary = final_report.get("survey_summary", {})
        if survey_summary:
            summary_text = self._format_survey_summary(survey_summary)
            blocks.append(self.builder.callout(summary_text, emoji="📋", color="gray_background"))
            blocks.append(self.builder.paragraph(""))
        
        # 3. 섹션별 변환
        sections = final_report.get("sections", {})
        tabs = final_report.get("tabs", [])
        
        for tab in tabs:
            section_data = sections.get(tab, {})
            if not section_data:
                continue
            
            section_blocks = self._convert_section_to_blocks(tab, section_data)
            blocks.extend(section_blocks)
            
            # 섹션 구분선
            blocks.append(self.builder.divider())
            blocks.append(self.builder.paragraph(""))
        
        # 4. 리포트 생성 시간
        generated_at = final_report.get("generated_at")
        if generated_at:
            blocks.append(self.builder.paragraph(f"📅 생성 시간: {generated_at}", italic=True))
        
        return blocks
    
    def _format_survey_summary(self, survey_summary: Dict[str, Any]) -> str:
        """설문 요약 포맷팅"""
        outcomes = survey_summary.get("outcomes", [])
        target_years = survey_summary.get("target_years", 30)
        
        outcome_labels = {
            "acne": "여드름",
            "wrinkles": "주름",
            "pigmentation": "색소침착",
            "skin_tone": "피부톤",
            "elasticity": "탄력",
            "texture": "결",
            "redness": "홍조"
        }
        
        outcome_text = ", ".join([outcome_labels.get(o, o) for o in outcomes])
        
        return f"📋 분석 목표: {outcome_text} | 🎯 목표 기간: {target_years}세까지"
    
    def _convert_section_to_blocks(self, section_key: str, section_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """섹션 데이터를 Notion Block으로 변환 (매핑 구조 반영)"""
        blocks = []
        
        # 1. 섹션 제목 (Heading 1)
        title = section_data.get("title", self.section_titles.get(section_key, section_key))
        blocks.append(self.builder.heading_1(f"# {title}"))
        blocks.append(self.builder.paragraph(""))
        
        # 2. subsections가 있는 경우 (lifestyle)
        if "subsections" in section_data:
            for subsection in section_data.get("subsections", []):
                subsection_blocks = self._convert_subsection_to_blocks(subsection)
                blocks.extend(subsection_blocks)
        # 일반 카드가 있는 경우
        elif "cards" in section_data:
            # 3. 4개 카드를 Callout으로 표시 (카드별 배경색)
            cards = section_data.get("cards", [])
            card_blocks = self._convert_cards_to_blocks(cards)
            blocks.extend(card_blocks)
        
        # 4. 신뢰도 점수 표시 (RAGAS)
        reliability_score = section_data.get("reliability_score")
        if reliability_score is not None:
            reliability_blocks = self._create_reliability_block(reliability_score)
            blocks.extend(reliability_blocks)
        
        # 5. 인용 근거 (Toggle List)
        evidence_refs = section_data.get("evidence_refs", {})
        if evidence_refs:
            evidence_blocks = self._convert_evidence_to_blocks(evidence_refs)
            if evidence_blocks:
                blocks.extend(evidence_blocks)
        
        # 6. 생성된 미래 사진 (Image Block)
        image_url = section_data.get("future_image_url")
        if image_url:
            blocks.append(self.builder.image(image_url, caption=f"{title} - AI 생성 예측 이미지"))
            blocks.append(self.builder.paragraph(""))
        
        return blocks
    
    def _convert_subsection_to_blocks(self, subsection: Dict[str, Any]) -> List[Dict[str, Any]]:
        """하위 섹션 변환 (lifestyle 전용)"""
        blocks = []
        
        # 하위 섹션 제목
        subsection_title = subsection.get("title", "")
        blocks.append(self.builder.heading_2(f"📌 {subsection_title}"))
        blocks.append(self.builder.paragraph(""))
        
        # 카드 변환
        cards = subsection.get("cards", [])
        card_blocks = self._convert_cards_to_blocks(cards)
        blocks.extend(card_blocks)
        
        return blocks
    
    def _convert_cards_to_blocks(self, cards: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """카드 리스트를 Notion Block으로 변환 (Callout으로 카드별 배경색 적용)"""
        blocks = []
        
        for card in cards:
            card_type = card.get("type", "")
            text = card.get("text", "")
            
            if not text:
                continue
            
            config = self.card_type_config.get(card_type, {})
            title = config.get("title", card_type)
            emoji = config.get("emoji", "📝")
            color = config.get("color", "gray_background")
            
            # 카드를 Callout에 제목 포함하여 표시
            card_content = f"{title}\n\n{text}"
            blocks.append(self.builder.callout(card_content, emoji=emoji, color=color))
            blocks.append(self.builder.paragraph(""))
        
        return blocks
    
    def _convert_evidence_to_blocks(self, evidence_refs: Dict[str, Any]) -> List[Dict[str, Any]]:
        """근거 참조를 Notion Block으로 변환 (Toggle로 접기)"""
        blocks = []
        
        narrative_refs = evidence_refs.get("narrative", [])
        quant_refs = evidence_refs.get("quant", [])
        
        if not narrative_refs and not quant_refs:
            return blocks
        
        # Toggle 블록으로 근거 숨기기
        children = []
        
        # 정량 근거
        if quant_refs:
            children.append(self.builder.heading_3("📊 정량 근거"))
            for ref in quant_refs[:5]:  # 최대 5개
                ref_text = self._format_quant_ref(ref)
                children.append(self.builder.bulleted_list_item(ref_text))
        
        # 서술 근거
        if narrative_refs:
            children.append(self.builder.heading_3("📄 서술 근거"))
            for ref in narrative_refs[:5]:  # 최대 5개
                ref_text = self._format_narrative_ref(ref)
                children.append(self.builder.bulleted_list_item(ref_text))
        
        # Toggle로 감싸기
        toggle_block = self.builder.toggle("📚 참고 문헌 및 근거", children=children)
        blocks.append(toggle_block)
        blocks.append(self.builder.paragraph(""))
        
        return blocks
    
    def _format_quant_ref(self, ref: Dict[str, Any]) -> str:
        """정량 근거 포맷팅"""
        outcome = ref.get("outcome", "")
        factor = ref.get("factor", "")
        effect = ref.get("effect", "")
        n_papers = ref.get("n_papers", 0)
        
        return f"{factor} → {outcome}: {effect} (논문 {n_papers}편 분석)"
    
    def _format_narrative_ref(self, ref: Dict[str, Any]) -> str:
        """서술 근거 포맷팅"""
        title = ref.get("title", "")
        pmid = ref.get("pmid", "")
        
        if pmid:
            return f"{title} (PMID: {pmid})"
        return title
    
    def _create_reliability_block(self, score: float) -> List[Dict[str, Any]]:
        """신뢰도 점수 블록 생성 (Callout)"""
        blocks = []
        
        # 신뢰도 레벨 판정
        if score >= 0.9:
            level = "Verified"
            emoji = "✅"
            color = "green_background"
        elif score >= 0.7:
            level = "Good"
            emoji = "👍"
            color = "blue_background"
        else:
            level = "Needs Review"
            emoji = "⚠️"
            color = "yellow_background"
        
        score_percent = int(score * 100)
        score_text = f"신뢰도: {score_percent}% ({level})"
        
        blocks.append(self.builder.callout(score_text, emoji=emoji, color=color))
        blocks.append(self.builder.paragraph(""))
        
        return blocks


# ════════════════════════════════════════════════════════════════
#  실제 리포트 데이터 로드 함수
# ════════════════════════════════════════════════════════════════

def load_report_from_db(user_id: int, lifestyle_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
    """
    데이터베이스에서 실제 리포트 데이터 로드
    
    Args:
        user_id: 사용자 ID
        lifestyle_id: Lifestyle 레코드 ID (None이면 최신 레코드)
    
    Returns:
        final_report JSON 또는 None
    """
    try:
        # DB 모듈 import (환경변수가 없으면 여기서 실패)
        from app.database import get_db
        from app.models import Lifestyle
    except (ImportError, Exception) as e:
        print(f"❌ DB 모듈 import 실패: {e}")
        print(f"⚠️ DATABASE_URL 환경변수가 설정되지 않았을 수 있습니다.")
        print(f"💡 도커 환경에서 실행하거나, .env 파일을 확인하세요.")
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
                Lifestyle.user_id == user_id
            ).first()
        else:
            # 최신 레코드 조회
            lifestyle = db.query(Lifestyle).filter(
                Lifestyle.user_id == user_id
            ).order_by(Lifestyle.created_at.desc()).first()
        
        if not lifestyle or not lifestyle.health_report:
            print(f"⚠️ 리포트를 찾을 수 없습니다. (user_id={user_id})")
            return None
        
        print(f"✅ 리포트 로드 완료 (lifestyle_id={lifestyle.id})")
        return lifestyle.health_report
        
    except Exception as e:
        print(f"❌ 리포트 로드 실패: {e}")
        import traceback
        traceback.print_exc()
        return None
    finally:
        db.close()


def load_report_from_file(file_path: str) -> Optional[Dict[str, Any]]:
    """
    파일에서 리포트 데이터 로드 (테스트용)
    
    Args:
        file_path: JSON 파일 경로
    
    Returns:
        final_report JSON 또는 None
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            report = json.load(f)
        print(f"✅ 파일에서 리포트 로드 완료: {file_path}")
        return report
    except Exception as e:
        print(f"❌ 파일 로드 실패: {e}")
        return None


# ════════════════════════════════════════════════════════════════
#  메인 변환 함수
# ════════════════════════════════════════════════════════════════

def format_report_to_notion(final_report: Dict[str, Any], output_file: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    리포트를 Notion Block으로 변환하고 선택적으로 파일로 저장
    
    Args:
        final_report: LangGraph에서 생성된 리포트 JSON
        output_file: 출력 파일 경로 (None이면 저장 안 함)
    
    Returns:
        Notion Block 리스트
    """
    formatter = NotionReportFormatter()
    blocks = formatter.convert_report_to_blocks(final_report)
    
    if output_file:
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(blocks, f, indent=2, ensure_ascii=False)
            print(f"✅ Notion blocks 저장 완료: {output_file}")
        except Exception as e:
            print(f"⚠️ 파일 저장 실패: {e}")
    
    return blocks


# ════════════════════════════════════════════════════════════════
#  테스트 함수
# ════════════════════════════════════════════════════════════════

def test_formatter_with_sample():
    """Formatter 테스트 (샘플 데이터)"""
    print("=" * 60)
    print("Notion Formatter 테스트 (샘플 데이터)")
    print("=" * 60)
    
    # 샘플 final_report
    sample_report = {
        "tabs": ["sleep", "uv"],
        "sections": {
            "sleep": {
                "title": "수면 및 리듬",
                "cards": [
                    {
                        "type": "problem",
                        "text": "당신의 수면 시간은 평균 5.5시간으로 권장 수면 시간(7-9시간)보다 크게 부족합니다."
                    },
                    {
                        "type": "cause",
                        "text": "수면 부족은 피부 재생 호르몬 분비를 방해하고, 염증 반응을 증가시켜 피부 노화를 가속화합니다."
                    },
                    {
                        "type": "action",
                        "text": "매일 밤 11시 이전에 취침하고, 최소 7시간 이상 수면을 유지하세요."
                    },
                    {
                        "type": "simulation",
                        "text": "3개월간 충분한 수면을 유지하면 피부 탄력이 15% 개선될 수 있습니다."
                    }
                ],
                "reliability_score": 0.92,
                "evidence_refs": {
                    "narrative": [
                        {
                            "paper_id": "PMC123456",
                            "chunk_id": "1",
                            "title": "Sleep and Skin Aging",
                            "pmid": "123456"
                        }
                    ],
                    "quant": [
                        {
                            "outcome": "wrinkles",
                            "factor": "sleep_hours",
                            "effect": "-20% 개선",
                            "n_papers": 5
                        }
                    ]
                }
            },
            "uv": {
                "title": "자외선 및 노화 관리",
                "cards": [
                    {
                        "type": "problem",
                        "text": "당신의 자외선 차단제 사용 빈도는 주 2회로 매우 낮습니다."
                    },
                    {
                        "type": "action",
                        "text": "매일 아침 자외선 차단제를 바르고, 외출 시 2-3시간마다 재도포하세요."
                    }
                ]
            }
        },
        "survey_summary": {
            "outcomes": ["acne", "wrinkles"],
            "target_years": 30
        },
        "generated_at": "2026-02-10 15:30:00"
    }
    
    # Formatter 실행
    blocks = format_report_to_notion(sample_report, output_file="notion_blocks_sample.json")
    
    print(f"\n✅ 변환 완료: {len(blocks)}개 블록 생성")
    print("\n[샘플 블록 미리보기 (처음 8개)]")
    
    for i, block in enumerate(blocks[:8]):
        print(f"\n--- Block {i+1}: {block.get('type', 'unknown')} ---")
        print(json.dumps(block, indent=2, ensure_ascii=False))
    
    print(f"\n... (총 {len(blocks)}개 블록)")
    print(f"\n📄 전체 블록은 'notion_blocks_sample.json' 파일을 확인하세요.")
    
    return blocks


def test_formatter_with_real_report(user_id: int = 1):
    """실제 리포트 데이터로 Formatter 테스트"""
    print("=" * 60)
    print("Notion Formatter 테스트 (실제 리포트)")
    print("=" * 60)
    
    # 1. 실제 리포트 로드
    print(f"\n[1] 실제 리포트 로드 (user_id={user_id})")
    final_report = load_report_from_db(user_id)
    
    if not final_report:
        print("\n⚠️ 실제 리포트를 찾을 수 없습니다. 샘플 테스트로 전환합니다.")
        return test_formatter_with_sample()
    
    # 2. Notion Block으로 변환
    print(f"\n[2] Notion Block 변환 시작")
    blocks = format_report_to_notion(
        final_report,
        output_file="notion_blocks_output.json"
    )
    
    print(f"\n✅ 변환 완료: {len(blocks)}개 블록 생성")
    
    # 3. 샘플 블록 미리보기
    print("\n[3] 샘플 블록 미리보기 (처음 5개)")
    for i, block in enumerate(blocks[:5]):
        print(f"\n--- Block {i+1}: {block.get('type', 'unknown')} ---")
        print(json.dumps(block, indent=2, ensure_ascii=False))
    
    print(f"\n... (총 {len(blocks)}개 블록)")
    print(f"\n📄 전체 블록은 'notion_blocks_output.json' 파일을 확인하세요.")
    
    return blocks


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Notion Formatter 테스트")
    parser.add_argument("--user-id", type=int, default=1, help="사용자 ID (기본값: 1)")
    parser.add_argument("--sample", action="store_true", help="샘플 데이터 사용")
    parser.add_argument("--file", type=str, help="JSON 파일에서 리포트 로드")
    
    args = parser.parse_args()
    
    if args.sample:
        test_formatter_with_sample()
    elif args.file:
        print(f"파일에서 리포트 로드: {args.file}")
        report = load_report_from_file(args.file)
        if report:
            format_report_to_notion(report, output_file="notion_blocks_output.json")
    else:
        test_formatter_with_real_report(user_id=args.user_id)
