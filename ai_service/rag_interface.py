# ai_service/rag_interface.py
"""
RAG 검색 결과를 LLM에 전달하기 위한 인터페이스
검색 결과를 구조화하여 프롬프트 엔지니어링에 적합한 형태로 변환합니다.
"""

import os
import logging
from test_search import test_search
from evaluate_search import analyze_lifestyle_impact

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class RAGInterface:
    """
    RAG 검색 결과를 LLM 프롬프트에 맞게 포맷팅하는 인터페이스
    """

    def __init__(self, max_tokens_per_chunk: int = 1000, max_chunks: int = 5):
        self.max_tokens_per_chunk = max_tokens_per_chunk
        self.max_chunks = max_chunks

    def search_and_format_for_llm(self, query: str, context_window: int = 4000) -> dict:
        """
        쿼리로 검색하고 LLM 입력용으로 포맷팅합니다.
        """
        logger.info(f"RAG 검색 및 LLM 포맷팅: {query}")

        # 1. 검색 수행
        search_results = test_search(query, limit=self.max_chunks)

        # 2. 결과 필터링 및 정제
        filtered_results = self._filter_and_rank_results(search_results, query)

        # 3. 컨텍스트 윈도우에 맞게 청킹
        context_chunks = self._create_context_chunks(filtered_results, context_window)

        # 4. LLM 프롬프트용 포맷팅
        llm_input = self._format_for_llm(query, context_chunks)

        return llm_input

    def _filter_and_rank_results(self, results: list, query: str) -> list:
        """
        검색 결과를 필터링하고 재랭킹합니다.
        """
        # 유사도 점수로 정렬 (이미 되어 있음)
        # 추가 필터링: 증거 수준이 높은 것 우선
        evidence_priority = {'1': 5, '2': 4, '3': 3, '4': 2, '5': 1}

        filtered = []
        for result in results:
            payload = result.payload

            # 증거 수준 점수 추가
            evidence_level = str(payload.get('evidence_level', '5'))
            evidence_score = evidence_priority.get(evidence_level, 1)

            # 최종 점수 = 유사도 + 증거 가중치
            final_score = result.score + (evidence_score * 0.1)

            filtered.append({
                'result': result,
                'final_score': final_score,
                'evidence_level': evidence_level
            })

        # 최종 점수로 재정렬
        filtered.sort(key=lambda x: x['final_score'], reverse=True)

        return filtered[:self.max_chunks]

    def _create_context_chunks(self, filtered_results: list, context_window: int) -> list:
        """
        컨텍스트 윈도우에 맞게 텍스트 청킹합니다.
        """
        chunks = []
        current_chunk = ""
        current_tokens = 0

        for item in filtered_results:
            result = item['result']
            payload = result.payload

            # 텍스트 추출 및 토큰 수 추정 (대략 4자=1토큰)
            text = payload.get('text', '')
            estimated_tokens = len(text) // 4

            # 청킹 결정
            if current_tokens + estimated_tokens > self.max_tokens_per_chunk:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                    current_chunk = ""
                    current_tokens = 0

            # 메타데이터 + 텍스트 추가
            chunk_text = self._format_chunk_text(payload, item['evidence_level'])
            current_chunk += chunk_text + "\n\n"
            current_tokens += estimated_tokens

        if current_chunk:
            chunks.append(current_chunk.strip())

        # 전체 컨텍스트 윈도우 제한
        total_tokens = sum(len(chunk) // 4 for chunk in chunks)
        if total_tokens > context_window:
            # 토큰 수에 맞게 청크 줄이기
            chunks = self._truncate_chunks(chunks, context_window)

        return chunks

    def _format_chunk_text(self, payload: dict, evidence_level: str) -> str:
        """
        개별 청크 텍스트 포맷팅
        """
        title = payload.get('title', '제목 없음')
        year = payload.get('year', '년도 없음')
        text = payload.get('text', '')
        topics = payload.get('topics', '')
        outcomes = payload.get('outcomes_ko', payload.get('outcomes_std', ''))

        formatted = f"""
[증거 수준: {evidence_level}] {title} ({year})
주제: {topics}
결과: {outcomes}
내용: {text}
출처: {payload.get('paper_id', '')}, 페이지 {payload.get('page_start', '')}-{payload.get('page_end', '')}
""".strip()

        return formatted

    def _truncate_chunks(self, chunks: list, max_tokens: int) -> list:
        """
        토큰 수에 맞게 청크를 줄입니다.
        """
        truncated = []
        current_tokens = 0

        for chunk in chunks:
            chunk_tokens = len(chunk) // 4
            if current_tokens + chunk_tokens > max_tokens:
                break
            truncated.append(chunk)
            current_tokens += chunk_tokens

        return truncated

    def _format_for_llm(self, query: str, context_chunks: list) -> dict:
        """
        LLM 입력용 최종 포맷팅
        """
        context = "\n\n".join(context_chunks)

        system_prompt = """당신은 건강과 노화 분야의 전문가입니다.
제공된 연구 데이터를 기반으로 사용자의 질문에 정확하고 과학적인 답변을 제공하세요.
증거 수준을 고려하여 답변의 신뢰도를 표시하세요."""

        user_prompt = f"""질문: {query}

관련 연구 데이터:
{context}

위 데이터를 기반으로 질문에 답변해주세요. 각 답변에 사용된 증거의 수준을 명시하세요."""

        return {
            'system_prompt': system_prompt,
            'user_prompt': user_prompt,
            'context_chunks': len(context_chunks),
            'estimated_tokens': sum(len(chunk) // 4 for chunk in context_chunks),
            'sources': [chunk.split('\n')[0] for chunk in context_chunks if chunk]  # 출처 목록
        }

    def analyze_lifestyle_for_llm(self, lifestyle: str) -> dict:
        """
        생활습관 분석 결과를 LLM 입력용으로 포맷팅
        """
        logger.info(f"생활습관 '{lifestyle}' LLM 분석 준비")

        # 생활습관 분석 수행
        try:
            analysis_result = analyze_lifestyle_impact(lifestyle)
            # analyze_lifestyle_impact은 결과를 출력만 하고 반환하지 않으므로 수정 필요
            # 임시로 검색 기반 분석
            search_results = test_search(lifestyle, limit=10)

            # 분석 결과를 LLM 프롬프트로 변환
            context = self._create_lifestyle_context(search_results)

            system_prompt = """당신은 건강과 노화 분야의 전문가입니다.
생활습관이 노화에 미치는 영향을 분석하여 과학적 근거 기반으로 조언하세요."""

            user_prompt = f"""생활습관 '{lifestyle}'의 노화 영향에 대해 분석해주세요.

관련 연구 데이터:
{context}

다음 항목들을 포함하여 답변하세요:
1. {lifestyle}의 노화 영향 메커니즘
2. 과학적 증거 수준과 주요 연구 결과
3. 건강 조언과 권장사항
4. 추가 연구 필요성"""

            return {
                'system_prompt': system_prompt,
                'user_prompt': user_prompt,
                'lifestyle': lifestyle,
                'evidence_count': len(search_results)
            }

        except Exception as e:
            logger.error(f"생활습관 분석 실패: {e}")
            return None

    def _create_lifestyle_context(self, results: list) -> str:
        """
        생활습관 분석용 컨텍스트 생성
        """
        context_parts = []

        for result in results[:5]:  # 상위 5개만
            payload = result.payload
            part = f"""
연구: {payload.get('title', '')} ({payload.get('year', '')})
증거 수준: {payload.get('evidence_level', '')}
결과: {payload.get('outcomes_ko', '')}
내용: {payload.get('text', '')[:300]}...
"""
            context_parts.append(part.strip())

        return "\n\n".join(context_parts)

# 전역 인터페이스 인스턴스
rag_interface = RAGInterface()

def get_llm_prompt(query: str) -> dict:
    """
    쿼리에 대한 LLM 프롬프트를 생성합니다.
    """
    return rag_interface.search_and_format_for_llm(query)

def get_lifestyle_analysis_prompt(lifestyle: str) -> dict:
    """
    생활습관 분석용 LLM 프롬프트를 생성합니다.
    """
    return rag_interface.analyze_lifestyle_for_llm(lifestyle)

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("사용법: python rag_interface.py <쿼리>")
        sys.exit(1)

    query = sys.argv[1]
    result = get_llm_prompt(query)

    print("=== LLM 입력 포맷팅 결과 ===")
    print(f"시스템 프롬프트: {result['system_prompt']}")
    print(f"사용자 프롬프트: {result['user_prompt']}")
    print(f"컨텍스트 청크 수: {result['context_chunks']}")
    print(f"예상 토큰 수: {result['estimated_tokens']}")
    print(f"출처: {result['sources']}")