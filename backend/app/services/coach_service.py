"""
코치 서비스: intent 분류 → 2단 응답 → 근거 경로 → LLM 스트리밍

핵심 흐름:
  1. 의도(Intent) 분류  (규칙 기반, 즉시)
  2. 리포트 컨텍스트 로드  (report_id → DB)
  3. 코치 메모리 로드 & 업데이트  (규칙 기반)
  4. 프롬프트 구성  (2단 구조 지시)
  5. LLM 스트리밍  (langchain Gemini async)
  6. 액션 · 인용 · 메모리 이벤트 전송
"""

import os
import re
import uuid
import asyncio
import traceback
from typing import List, Dict, Any, Optional, Tuple
from enum import Enum

from app.services.session_store import SessionData
from app.services.coach_memory import (
    CoachMemory,
    extract_memory_updates,
    apply_memory_updates,
    get_or_create_memory,
    save_memory_to_session,
)


# ══════════════════════════════════════════════
#  Intent 분류
# ══════════════════════════════════════════════

class Intent(str, Enum):
    REPORT_EXPLAIN = "report_explain"
    LIFESTYLE_COACH = "lifestyle_coach"
    SITUATION_HELP = "situation_help"
    SMALLTALK = "smalltalk"


# 키워드 기반 의도 분류 규칙
_INTENT_RULES: List[Tuple[Intent, List[str]]] = [
    (Intent.REPORT_EXPLAIN, [
        "리포트", "보고서", "분석", "지표", "카드", "근거", "수치",
        "점수", "결과", "report", "왜 이런", "어떤 의미", "해석",
        "설명해", "알려줘", "evidence", "논문",
    ]),
    (Intent.SITUATION_HELP, [
        "야근", "여행", "트러블", "자극", "생겼", "급해", "오늘",
        "지금", "당장", "갑자기", "아파", "따가", "빨개", "부었",
        "건조해", "각질", "뾰루지", "stress",
    ]),
    (Intent.LIFESTYLE_COACH, [
        "습관", "루틴", "목표", "플랜", "계획", "관리",
        "코칭", "추천", "어떻게", "뭘 해야", "할 일",
        "액션", "실천", "개선", "도움", "팁",
    ]),
]

_SMALLTALK_PATTERNS = [
    r"^(안녕|하이|hello|hi|ㅎㅇ|반가|굿모닝|잘\s*자|ㅋ{2,}|ㅎㅎ)",
    r"^(고마워|감사|수고|잘\s*했|대단|멋져|좋아|ㅇㅋ)",
    r"^(뭐야|누구|뭐해|심심|재밌)",
]


def classify_intent(message: str, mode: str = "auto") -> Intent:
    """규칙 기반 의도 분류 — 즉시 결정"""
    if mode == "report_explain":
        return Intent.REPORT_EXPLAIN
    if mode == "coach":
        return Intent.LIFESTYLE_COACH

    msg = message.lower().strip()

    # smalltalk 먼저 체크 (짧은 메시지)
    if len(msg) < 15:
        for pat in _SMALLTALK_PATTERNS:
            if re.search(pat, msg):
                return Intent.SMALLTALK

    # 키워드 매칭 (가장 많이 매칭된 의도 선택)
    scores: Dict[Intent, int] = {}
    for intent, keywords in _INTENT_RULES:
        count = sum(1 for kw in keywords if kw in msg)
        if count > 0:
            scores[intent] = count

    if scores:
        return max(scores, key=scores.get)

    # 기본값: 코칭
    return Intent.LIFESTYLE_COACH


# ══════════════════════════════════════════════
#  리포트 컨텍스트 로드
# ══════════════════════════════════════════════

def load_report_context(session: SessionData, db=None) -> Dict[str, Any]:
    """
    report_id가 있으면 DB에서 리포트를 로드하여 컨텍스트 구성
    캐시가 있으면 캐시 사용
    """
    ctx: Dict[str, Any] = {
        "has_report": False,
        "summary_text": "",
        "evidence_refs": [],
        "section_summaries": {},
    }

    report_id = session.report_id
    if not report_id:
        return ctx

    # 캐시 체크
    if session.report_summary_cache:
        cached = session.report_summary_cache
        if cached.get("report_id") == report_id:
            return cached

    if not db:
        return ctx

    try:
        from app.models import Lifestyle

        lifestyle = db.query(Lifestyle).filter(Lifestyle.id == report_id).first()
        if not lifestyle or not lifestyle.health_report:
            return ctx

        report = lifestyle.health_report
        if not isinstance(report, dict):
            return ctx

        ctx["has_report"] = True
        ctx["report_id"] = report_id

        # 섹션별 요약 구성
        tabs = report.get("tabs", [])
        sections = report.get("sections", {})
        summary_parts = []
        evidence_refs = []

        for tab in tabs:
            section = sections.get(tab, {})
            if not isinstance(section, dict):
                continue

            title = section.get("title", tab)
            cards = section.get("cards", [])
            card_texts = []

            for card in cards:
                ctype = card.get("type", "")
                if ctype == "problem":
                    card_texts.append(f"[현재 상태] {card.get('text', '')[:100]}")
                elif ctype == "cause":
                    card_texts.append(f"[원인] {card.get('text', '')[:100]}")
                elif ctype == "action":
                    items = card.get("items", [])
                    actions = "; ".join(
                        f"{i.get('title', '')}" for i in items[:3]
                    )
                    card_texts.append(f"[권고 행동] {actions}")
                elif ctype == "simulation":
                    card_texts.append(f"[예측] {card.get('text', '')[:80]}")

            section_text = f"## {title}\n" + "\n".join(card_texts)
            summary_parts.append(section_text)

            ctx["section_summaries"][tab] = {
                "title": title,
                "cards": card_texts,
            }

            # 근거 참조 수집
            refs = section.get("evidence_refs", {})
            if isinstance(refs, dict):
                for ref_type in ["narrative", "quant"]:
                    for ref in refs.get(ref_type, []):
                        if isinstance(ref, dict):
                            evidence_refs.append(ref)

        ctx["summary_text"] = "\n\n".join(summary_parts)
        ctx["evidence_refs"] = evidence_refs[:20]

        # 캐시 저장
        session.report_summary_cache = ctx

    except Exception as e:
        print(f"[CoachService] 리포트 로드 실패: {e}")
        traceback.print_exc()

    return ctx


# ══════════════════════════════════════════════
#  프롬프트 구성
# ══════════════════════════════════════════════

_SYSTEM_PROMPT = """당신은 '손 안의 피부노화 관리사' — 사용자의 피부 건강 리포트를 기반으로 맞춤형 생활습관 코칭을 제공하는 AI 코치입니다.

답변 구조 (항상 이 순서로 출력하세요):
1. 결론 1줄 — 지금/오늘 할 일을 명확하게 (첫 줄에 반드시)
2. 이유 — 리포트 카드/근거 기반, 2~3문장 이내
3. 오늘의 액션 2~3개 — 각각 시간대와 난이도(쉬움/보통/도전) 포함
4. 주의사항 — 자극/금기/측정 관련, 1~2줄

원칙:
- 첫 줄(결론)을 최대한 빨리 출력하세요.
- 짧고 실용적인 답변 우선. 3~5줄이면 충분합니다.
- 의학적 진단은 하지 마세요. 생활습관 개선에 집중하세요.
- 리포트 데이터가 있으면 반드시 언급하되, 지나치게 길게 인용하지 마세요.
- 사용자의 목표·제약·민감성을 항상 고려하세요.
- '더 자세히'는 사용자가 요청할 때만 길게 답하세요.
- 한국어로 답변하세요.
- 절대 마크다운 문법(**, ##, -, ``` 등)을 사용하지 마세요. 모바일 채팅 앱에 표시되므로 일반 텍스트로만 답변하세요.
"""

_REPORT_EXPLAIN_ADDENDUM = """
지금은 리포트 해설 모드입니다.
- 리포트 원문을 그대로 복사하지 마세요. 핵심 내용만 대화하듯 자연스럽게 풀어서 설명하세요.
- 가장 중요한 2~3가지 포인트에 집중하세요.
- 수치가 있으면 그 수치가 의미하는 바를 쉽게 해석해 주세요.
- 절대 마크다운 문법을 사용하지 마세요. 일반 텍스트로만 답변하세요.
"""

_SITUATION_HELP_ADDENDUM = """
지금은 상황 대응 모드입니다. 사용자가 급한 피부 상황을 겪고 있습니다.
즉각적인 대응법을 먼저 알려주고, 이후 예방 팁을 짧게 추가하세요.
"""


def build_messages(
    intent: Intent,
    user_message: str,
    session: SessionData,
    report_ctx: Dict[str, Any],
    memory: CoachMemory,
) -> List[Dict[str, str]]:
    """LLM에 보낼 메시지 리스트 구성"""

    # 시스템 프롬프트
    system = _SYSTEM_PROMPT

    if intent == Intent.REPORT_EXPLAIN:
        system += _REPORT_EXPLAIN_ADDENDUM
    elif intent == Intent.SITUATION_HELP:
        system += _SITUATION_HELP_ADDENDUM

    # 코치 메모리 요약
    memory_summary = memory.to_prompt_summary()
    if memory_summary and memory_summary != "(메모리 없음)":
        system += f"\n\n## 사용자 메모리\n{memory_summary}"

    # 리포트 컨텍스트
    if report_ctx.get("has_report"):
        system += f"\n\n## 사용자 리포트 요약\n{report_ctx['summary_text'][:2000]}"

    messages = [{"role": "system", "content": system}]

    # 히스토리
    for turn in session.get_history_for_prompt():
        messages.append(turn)

    # 현재 사용자 메시지
    messages.append({"role": "user", "content": user_message})

    return messages


# ══════════════════════════════════════════════
#  액션 아이템 생성
# ══════════════════════════════════════════════

def generate_action_items(
    intent: Intent, session: SessionData, report_ctx: Dict[str, Any],
    rag_used: bool = False,
) -> List[Dict[str, Any]]:
    """의도에 따른 액션 버튼 목록 생성"""
    items = []

    if intent in (Intent.LIFESTYLE_COACH, Intent.SITUATION_HELP):
        items.append({
            "id": "start_today_plan",
            "label": "오늘의 플랜 시작하기",
            "payload": {"action": "generate_today_plan"},
        })

    # 근거 보기: RAG 검색을 실제로 수행했을 때만 표시
    if rag_used:
        items.append({
            "id": "show_citations",
            "label": "근거 보기",
            "payload": {"action": "show_citations"},
        })

    if report_ctx.get("has_report"):
        items.append({
            "id": "explain_report",
            "label": "리포트 요약 보기",
            "payload": {"action": "explain_report"},
        })

    if intent == Intent.SMALLTALK:
        items.append({
            "id": "start_coaching",
            "label": "코칭 시작하기",
            "payload": {"action": "start_coaching"},
        })

    return items


# ══════════════════════════════════════════════
#  인용(Citation) 추출
# ══════════════════════════════════════════════

def extract_citations(report_ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    """리포트 evidence_refs 에서 인용 항목 추출"""
    citations = []
    for ref in report_ctx.get("evidence_refs", [])[:10]:
        citations.append({
            "paper_id": ref.get("paper_id", ""),
            "chunk_id": ref.get("chunk_id", ""),
            "source_section": ref.get("section_norm", ""),
            "score": ref.get("score"),
        })
    return citations


# ══════════════════════════════════════════════
#  RAG 검색 (필요할 때만)
# ══════════════════════════════════════════════

def maybe_run_rag(
    intent: Intent, user_message: str, report_ctx: Dict[str, Any], session: SessionData
) -> Optional[str]:
    """
    RAG 검색이 필요한 경우에만 실행
    - 리포트 컨텍스트가 부족하고
    - 논문/근거/수치를 요구하는 질문일 때만
    """
    if report_ctx.get("has_report"):
        # 리포트가 있으면 기본적으로 RAG 불필요
        need_rag_keywords = ["논문", "연구", "수치", "데이터", "출처", "evidence", "study"]
        if not any(kw in user_message.lower() for kw in need_rag_keywords):
            return None

    # RAG 캐시 체크
    for cached in session.rag_cache:
        if cached.get("query", "") == user_message[:50]:
            return cached.get("result_text", "")

    try:
        import sys
        import os

        app_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        if app_root not in sys.path:
            sys.path.append(app_root)

        from tools.qdrant_search import qdrant_search
        from tools.schemas import QdrantSearchInput

        search_input = QdrantSearchInput(
            query=user_message[:200],
            top_k=3,
            min_score=0.3,
            candidate_k=15,
        )
        result = qdrant_search(search_input)

        if result.items:
            texts = []
            for item in result.items[:3]:
                texts.append(f"[{item.paper_id}] {item.text[:200]}")
            rag_text = "\n---\n".join(texts)

            session.cache_rag_result({
                "query": user_message[:50],
                "result_text": rag_text,
            })
            return rag_text

    except Exception as e:
        print(f"[CoachService] RAG 검색 실패 (무시하고 진행): {e}")

    return None


# ══════════════════════════════════════════════
#  LLM 스트리밍
# ══════════════════════════════════════════════

async def stream_llm_response(
    messages: List[Dict[str, str]],
    send_delta,
):
    """
    LLM 응답을 스트리밍하여 send_delta 콜백으로 전송
    Returns: 전체 응답 텍스트
    """
    full_response = ""

    try:
        # langchain-google-genai 사용
        from langchain_google_genai import ChatGoogleGenerativeAI
        from langchain_core.messages import SystemMessage, HumanMessage, AIMessage

        model_name = os.getenv("COACH_LLM_MODEL", "gemini-2.5-flash")
        api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

        if not api_key:
            # API 키 없으면 폴백 응답
            fallback = (
                "지금 바로 선크림을 바르세요!\n\n"
                "리포트 분석에 따르면 자외선 노출이 피부 노화의 주요 원인입니다.\n\n"
                "오늘의 액션:\n"
                "1. 선크림 도포 (아침, 쉬움)\n"
                "2. 물 500ml 추가 섭취 (종일, 쉬움)\n"
                "3. 취침 전 보습 크림 (밤, 쉬움)\n\n"
                "주의: 레티놀 제품은 낮에 사용하지 마세요."
            )
            for chunk in [fallback[i:i+20] for i in range(0, len(fallback), 20)]:
                await send_delta(chunk)
                full_response += chunk
                await asyncio.sleep(0.02)
            return full_response

        llm = ChatGoogleGenerativeAI(
            model=model_name,
            google_api_key=api_key,
            streaming=True,
            temperature=0.7,
            max_output_tokens=1024,
        )

        # langchain 메시지 형식으로 변환
        lc_messages = []
        for m in messages:
            role = m["role"]
            content = m["content"]
            if role == "system":
                lc_messages.append(SystemMessage(content=content))
            elif role == "user":
                lc_messages.append(HumanMessage(content=content))
            elif role == "assistant":
                lc_messages.append(AIMessage(content=content))

        # 비동기 스트리밍
        async for chunk in llm.astream(lc_messages):
            text = chunk.content if hasattr(chunk, "content") else str(chunk)
            if text:
                await send_delta(text)
                full_response += text

    except Exception as e:
        print(f"[CoachService] LLM 스트리밍 오류: {e}")
        traceback.print_exc()
        error_msg = "죄송합니다, 일시적인 오류가 발생했습니다. 다시 시도해 주세요."
        await send_delta(error_msg)
        full_response = error_msg

    return full_response


# ══════════════════════════════════════════════
#  메인 핸들러
# ══════════════════════════════════════════════

class CoachService:
    """코치 챗봇 서비스 — WebSocket 핸들러에서 호출"""

    async def handle_user_message(
        self,
        session: SessionData,
        user_message: str,
        mode: str,
        assistant_msg_id: str,
        send_json,
        db=None,
        engine_override: str = None,
    ):
        """
        사용자 메시지 처리 전체 파이프라인

        Args:
            session: 현재 세션
            user_message: 사용자 메시지 텍스트
            mode: "coach" | "report_explain" | "auto"
            assistant_msg_id: 어시스턴트 메시지 ID
            send_json: async callable — dict를 WS로 전송
            db: SQLAlchemy DB 세션
            engine_override: 메시지 단위 엔진 오버라이드 ("quick" | "deep")
        """
        # 엔진 결정: 메시지 오버라이드 > 세션 설정
        engine = engine_override or session.engine or "quick"

        # ── Deep 모드 분기 ──
        if engine == "deep":
            try:
                from app.services.coach_graph import run_deep_coach

                report_ctx = load_report_context(session, db)
                await run_deep_coach(
                    session=session,
                    user_message=user_message,
                    mode=mode,
                    report_ctx=report_ctx,
                    assistant_msg_id=assistant_msg_id,
                    send_json=send_json,
                    db=db,
                )
                return
            except ImportError as e:
                print(f"[CoachService] Deep Coach 모듈 로드 실패, Quick 모드로 폴백: {e}")
            except Exception as e:
                print(f"[CoachService] Deep Coach 실행 실패, Quick 모드로 폴백: {e}")
                traceback.print_exc()

        # ── Quick 모드 (기존 로직) ──
        try:
            # 1. Intent 분류 (규칙 기반, 즉시)
            intent = classify_intent(user_message, mode)
            print(f"[CoachService] intent={intent.value}, msg={user_message[:50]}...")

            # 2. 코치 메모리 로드 & 업데이트
            memory = get_or_create_memory(session)
            mem_updates = extract_memory_updates(user_message)
            if mem_updates:
                apply_memory_updates(memory, mem_updates)
                save_memory_to_session(session, memory)

                # 메모리 업데이트 이벤트 전송
                ui_items = memory.get_memory_items_for_ui()
                if ui_items:
                    await send_json({
                        "type": "memory_update",
                        "items": ui_items,
                    })

            # 3. 리포트 컨텍스트 로드
            report_ctx = load_report_context(session, db)

            # 4. RAG 검색 (필요할 때만)
            rag_text = maybe_run_rag(intent, user_message, report_ctx, session)
            rag_used = bool(rag_text)

            # RAG 결과를 세션에 캐싱 (근거 보기에서 재활용)
            if rag_used:
                session.last_rag_text = rag_text

            # 5. 프롬프트 구성
            messages = build_messages(intent, user_message, session, report_ctx, memory)

            # RAG 결과가 있으면 시스템 프롬프트에 추가
            if rag_text:
                rag_addendum = f"\n\n[참고 근거 (RAG 검색 결과)]\n{rag_text[:1000]}"
                messages[0]["content"] += rag_addendum

            # 6. LLM 스트리밍 — delta 이벤트로 전송
            async def send_delta(text: str):
                await send_json({
                    "type": "delta",
                    "assistant_message_id": assistant_msg_id,
                    "delta": text,
                })

            full_response = await stream_llm_response(messages, send_delta)

            # 7. 히스토리 저장
            session.add_turn("user", user_message)
            session.add_turn("assistant", full_response)
            save_memory_to_session(session, memory)

            # 8. 액션 아이템 전송 (근거 보기는 RAG 사용 시에만)
            action_items = generate_action_items(intent, session, report_ctx, rag_used=rag_used)
            if action_items:
                await send_json({
                    "type": "actions",
                    "assistant_message_id": assistant_msg_id,
                    "items": action_items,
                })

            # 10. Done
            await send_json({
                "type": "done",
                "assistant_message_id": assistant_msg_id,
            })

        except Exception as e:
            print(f"[CoachService] 처리 오류: {e}")
            traceback.print_exc()
            await send_json({
                "type": "error",
                "message": f"처리 중 오류가 발생했습니다: {str(e)[:100]}",
                "assistant_message_id": assistant_msg_id,
            })

    async def handle_action_event(
        self,
        session: SessionData,
        action_id: str,
        payload: Dict[str, Any],
        assistant_msg_id: str,
        send_json,
        db=None,
    ):
        """액션 버튼 이벤트 처리"""
        try:
            if action_id == "start_today_plan":
                # 오늘의 플랜: 구체적인 실행 계획을 요청
                await self.handle_user_message(
                    session=session,
                    user_message=(
                        "내 리포트 결과를 바탕으로 오늘 바로 실천할 수 있는 "
                        "피부 관리 플랜을 구체적으로 알려줘. "
                        "아침/점심/저녁 시간대별로 나눠서 알려줘."
                    ),
                    mode="coach",
                    assistant_msg_id=assistant_msg_id,
                    send_json=send_json,
                    db=db,
                )

            elif action_id == "explain_report":
                # 리포트 요약: 리포트를 그대로 보여주지 않고 핵심만 대화체로 설명
                await self.handle_user_message(
                    session=session,
                    user_message=(
                        "내 리포트의 핵심 결과만 간단하게 요약해줘. "
                        "리포트 원문을 그대로 옮기지 말고, "
                        "가장 중요한 2~3가지 포인트를 "
                        "대화하듯 자연스럽게 알려줘."
                    ),
                    mode="report_explain",
                    assistant_msg_id=assistant_msg_id,
                    send_json=send_json,
                    db=db,
                )

            elif action_id == "start_coaching":
                await self.handle_user_message(
                    session=session,
                    user_message="피부 관리 코칭을 시작하고 싶어",
                    mode="coach",
                    assistant_msg_id=assistant_msg_id,
                    send_json=send_json,
                    db=db,
                )

            elif action_id == "show_citations":
                # 근거 보기: 캐싱된 RAG 결과를 LLM으로 요약하여 보여줌
                rag_text = getattr(session, "last_rag_text", None)
                if rag_text:
                    await self.handle_user_message(
                        session=session,
                        user_message=(
                            "방금 답변의 근거가 된 논문/연구 자료를 "
                            "쉽게 풀어서 설명해줘. 어떤 연구에서 "
                            "어떤 결과가 나왔는지 간단히 알려줘."
                        ),
                        mode="coach",
                        assistant_msg_id=assistant_msg_id,
                        send_json=send_json,
                        db=db,
                    )
                else:
                    # 캐시가 없으면 안내 메시지
                    await send_json({
                        "type": "delta",
                        "assistant_message_id": assistant_msg_id,
                        "delta": "참고한 논문 근거가 없습니다. 근거가 필요한 질문을 해주시면 관련 연구 자료를 찾아드릴게요.",
                    })
                    await send_json({
                        "type": "done",
                        "assistant_message_id": assistant_msg_id,
                    })

            else:
                # 알 수 없는 액션 → 일반 메시지로 처리
                await self.handle_user_message(
                    session=session,
                    user_message=f"{action_id} 관련 코칭을 해줘",
                    mode="auto",
                    assistant_msg_id=assistant_msg_id,
                    send_json=send_json,
                    db=db,
                )

        except Exception as e:
            print(f"[CoachService] 액션 처리 오류: {e}")
            await send_json({
                "type": "error",
                "message": str(e)[:100],
                "assistant_message_id": assistant_msg_id,
            })


# 싱글톤
coach_service = CoachService()
