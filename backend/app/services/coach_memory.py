"""
코치 메모리: 사용자 목표 · 제약 · 루틴 저장 및 관리
- 규칙 기반(명시적 발화)일 때만 메모리를 업데이트한다.
- 프롬프트에는 요약본만 넣는다.
"""

import re
from typing import Dict, Any, List, Tuple, Optional
from dataclasses import dataclass, field


# ══════════════════════════════════════════════
#  메모리 스키마
# ══════════════════════════════════════════════

@dataclass
class CoachMemory:
    goal: str = ""                                      # 예: "색소 개선"
    constraints: List[str] = field(default_factory=list) # 예: ["야근 많음"]
    sensitivities: List[str] = field(default_factory=list)  # 예: ["레티놀 자극"]
    routine_level: str = "normal"                       # easy | normal | strict
    adherence_notes: str = ""                           # 최근 실천/실패 요약
    last_plan: Optional[Dict[str, Any]] = None          # {date, actions:[...]}

    def to_dict(self) -> Dict[str, Any]:
        return {
            "goal": self.goal,
            "constraints": self.constraints,
            "sensitivities": self.sensitivities,
            "routine_level": self.routine_level,
            "adherence_notes": self.adherence_notes,
            "last_plan": self.last_plan,
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "CoachMemory":
        return cls(
            goal=d.get("goal", ""),
            constraints=d.get("constraints", []),
            sensitivities=d.get("sensitivities", []),
            routine_level=d.get("routine_level", "normal"),
            adherence_notes=d.get("adherence_notes", ""),
            last_plan=d.get("last_plan"),
        )

    def to_prompt_summary(self) -> str:
        """프롬프트용 요약 (짧게)"""
        parts = []
        if self.goal:
            parts.append(f"목표: {self.goal}")
        if self.constraints:
            parts.append(f"제약: {', '.join(self.constraints[:3])}")
        if self.sensitivities:
            parts.append(f"민감: {', '.join(self.sensitivities[:3])}")
        if self.routine_level != "normal":
            parts.append(f"루틴 난이도: {self.routine_level}")
        if self.adherence_notes:
            parts.append(f"실천: {self.adherence_notes[:50]}")
        return " | ".join(parts) if parts else "(메모리 없음)"

    def get_memory_items_for_ui(self) -> List[Dict[str, str]]:
        """UI 노출용 메모리 항목 (민감정보 제외)"""
        items = []
        if self.goal:
            items.append({"key": "goal", "value": self.goal})
        if self.routine_level:
            items.append({"key": "routine_level", "value": self.routine_level})
        if self.constraints:
            items.append({"key": "constraints", "value": ", ".join(self.constraints[:3])})
        return items


# ══════════════════════════════════════════════
#  규칙 기반 메모리 추출
# ══════════════════════════════════════════════

# 목표 키워드
_SKIN_GOALS = {
    "주름": "주름 개선", "탄력": "탄력 회복", "색소": "색소 개선",
    "보습": "보습 강화", "장벽": "장벽 회복", "여드름": "여드름 관리",
    "홍조": "홍조 완화", "노화": "노화 관리", "미백": "미백 관리",
    "모공": "모공 관리", "각질": "각질 관리",
}

_GOAL_PATTERNS = [
    r"(?:내|나의)\s*목표는?\s*(.+?)(?:야|이야|입니다|이에요|요|$)",
    r"(.+?)(?:를|을)\s*(?:개선|관리|케어|치료)(?:하고\s*싶|할래|하려)",
]

_CONSTRAINT_PATTERNS = [
    r"(?:나는?|저는?)\s*(.+?)(?:못\s*해|못해요|할\s*수\s*없)",
    r"(야근|바쁘|시간\s*없|아침\s*루틴.*분)",
]

_SENSITIVITY_PATTERNS = [
    r"(레티놀|비타민\s*C|AHA|BHA|향|알코올|니코틴아마이드).*(?:자극|알레르기|트러블|따가)",
    r"(.+?)(?:에|가)\s*(?:자극|알레르기|트러블|따가워)",
]

_ROUTINE_KW = {
    "easy": ["간단", "쉽", "최소", "3분", "짧"],
    "strict": ["철저", "꼼꼼", "빡세", "열심히"],
}


def extract_memory_updates(user_msg: str) -> List[Tuple[str, Any]]:
    """
    사용자 메시지에서 규칙 기반으로 메모리 업데이트 항목 추출
    Returns: [(field_name, value), ...]
    """
    updates: List[Tuple[str, Any]] = []
    msg = user_msg.strip()

    # ── 목표 추출 ──
    # 먼저 키워드 직접 매칭
    for kw, goal_text in _SKIN_GOALS.items():
        if kw in msg:
            for pat in _GOAL_PATTERNS:
                if re.search(pat, msg):
                    updates.append(("goal", goal_text))
                    break
            else:
                # 패턴 없어도 키워드가 "개선/관리/회복" 등과 함께 있으면
                if any(v in msg for v in ["개선", "관리", "회복", "케어", "치료", "목표"]):
                    updates.append(("goal", goal_text))
            if updates:
                break

    # ── 제약사항 ──
    for pat in _CONSTRAINT_PATTERNS:
        m = re.search(pat, msg)
        if m:
            constraint = m.group(0).strip()[:40]
            updates.append(("add_constraint", constraint))
            break

    # ── 민감성 ──
    for pat in _SENSITIVITY_PATTERNS:
        m = re.search(pat, msg)
        if m:
            sensitivity = m.group(0).strip()[:40]
            updates.append(("add_sensitivity", sensitivity))
            break

    # ── 루틴 레벨 ──
    for level, keywords in _ROUTINE_KW.items():
        if any(kw in msg for kw in keywords):
            updates.append(("routine_level", level))
            break

    return updates


def apply_memory_updates(
    memory: CoachMemory,
    updates: List[Tuple[str, Any]],
) -> CoachMemory:
    """메모리에 업데이트 적용"""
    for field_name, value in updates:
        if field_name == "goal":
            memory.goal = value
        elif field_name == "add_constraint":
            if value not in memory.constraints:
                memory.constraints.append(value)
                memory.constraints = memory.constraints[-5:]
        elif field_name == "add_sensitivity":
            if value not in memory.sensitivities:
                memory.sensitivities.append(value)
                memory.sensitivities = memory.sensitivities[-5:]
        elif field_name == "routine_level":
            memory.routine_level = value
        elif field_name == "adherence_notes":
            memory.adherence_notes = value
    return memory


# ── 헬퍼: 세션에서 메모리 가져오기 ──

def get_or_create_memory(session) -> CoachMemory:
    """세션 데이터에서 CoachMemory 인스턴스 가져오거나 생성"""
    if session.coach_memory_dict:
        return CoachMemory.from_dict(session.coach_memory_dict)
    return CoachMemory()


def save_memory_to_session(session, memory: CoachMemory):
    """CoachMemory를 세션에 저장"""
    session.coach_memory_dict = memory.to_dict()
