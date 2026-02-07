# 프론트엔드 UI 리팩토링 완료 요약

## 📋 개요

BioStream 프론트엔드를 새로운 백엔드 스키마(tabs + sections.cards)에 맞춰 리팩토링 완료.

---

## ✅ 구현 완료 사항

### 1. 새로운 컴포넌트 생성

#### 위젯 컴포넌트
- **`lib/widgets/report_tabs_bar.dart`**
  - 책갈피 탭 바 컴포넌트
  - 가로 스크롤 가능
  - 선택된 탭 강조 (녹색 배경)

#### 리포트 카드 컴포넌트
- **`lib/widgets/report_cards/problem_card.dart`**
  - 현재 상태 카드
  - PMC/PMID/p= 패턴 제거

- **`lib/widgets/report_cards/cause_card.dart`**
  - 원인 카드
  - PMC/PMID/p= 패턴 제거

- **`lib/widgets/report_cards/action_card.dart`**
  - 행동 3가지 카드
  - 항상 3개 아이템 보장
  - 번호 표시 (1, 2, 3)

- **`lib/widgets/report_cards/simulation_card.dart`**
  - 예상 경로 카드
  - 배지 표시: "연구 근거 있음" (grounded) / "AI 추정" (estimated)
  - estimated일 때만 disclaimer_small 회색 표시

#### 근거 모달
- **`lib/widgets/evidence_modal.dart`**
  - 정량 근거 (quant refs) 표시
  - 서술 근거 (narrative refs) 표시
  - BottomSheet 형태

---

### 2. result_screen.dart 수정

#### 상태 관리 변경
- `_reportCards` → `_reportData` (새 스키마)
- `_currentCardIndex` → `_selectedTab` (탭 선택)
- `_healthReport` 제거 (새 스키마 사용)

#### 데이터 처리
- 새로운 스키마 (`tabs` + `sections`) 처리
- 기존 스키마 호환성 변환 (`_convertOldSchemaToNew`)
- 첫 번째 탭 자동 선택

#### UI 렌더링
- `_buildReportSection()`: 탭 바 + 섹션 뷰
- `_buildSectionView()`: 섹션 헤더 + 4카드
- `_ensureFourCards()`: 항상 4개 카드 보장
- `_buildErrorSection()`: 오류 처리

---

## 📁 변경된 파일 목록

### 신규 파일
1. `biostream/lib/widgets/report_tabs_bar.dart`
2. `biostream/lib/widgets/report_cards/problem_card.dart`
3. `biostream/lib/widgets/report_cards/cause_card.dart`
4. `biostream/lib/widgets/report_cards/action_card.dart`
5. `biostream/lib/widgets/report_cards/simulation_card.dart`
6. `biostream/lib/widgets/evidence_modal.dart`

### 수정된 파일
1. `biostream/lib/screens/result_screen.dart`
   - 새로운 스키마 처리
   - 탭 기반 UI로 변경
   - 4카드 고정 렌더링

---

## 🎯 핵심 기능

### 1. 책갈피 탭
- 상단 Sticky 탭 바
- 가로 스크롤 가능
- 선택된 탭 강조 (녹색 배경)
- 탭 클릭 시 해당 섹션만 표시

### 2. 섹션별 4카드 고정
- 항상 4개 카드 렌더링
- 순서: problem → cause → action → simulation
- 부족한 카드는 fallback으로 채움

### 3. 카드 타입별 컴포넌트
- **ProblemCard**: 현재 상태 (2-3문장)
- **CauseCard**: 원인 (2-3문장)
- **ActionCard**: 행동 3가지 (번호 표시)
- **SimulationCard**: 예상 경로 (배지 + disclaimer)

### 4. 근거 보기 모달
- 섹션 헤더에 "근거 보기" 버튼
- BottomSheet로 표시
- 정량 근거 + 서술 근거 분리 표시

### 5. PMC/논문ID 노출 차단
- 모든 카드 텍스트에서 패턴 제거
- 정규식으로 2중 방어

---

## 🔍 테스트 체크리스트

- [x] tabs 렌더 + 클릭 시 섹션 변경 정상
- [x] 섹션마다 4카드 고정 렌더
- [x] action 카드 항상 3개 아이템 UI로 표시
- [x] simulation 배지 grounded/estimated 표시
- [x] estimated일 때만 disclaimer_small 회색 표시
- [x] 본문에 PMC/PMID/p= 문자열이 노출되지 않음 (2중 방어)
- [x] "근거 보기" 모달에서만 refs 노출

---

## 📊 UI 구조

```
ResultScreen
├── Header (뒤로가기, 제목, 공유)
├── Aging Simulation (기존)
├── Health Report Section (새로운 구조)
│   ├── ReportTabsBar
│   │   ├── Tab: goals
│   │   ├── Tab: sleep
│   │   ├── Tab: uv
│   │   ├── Tab: lifestyle
│   │   └── Tab: activity
│   └── SectionView (선택된 탭)
│       ├── SectionHeader + EvidenceButton
│       └── CardsList (4개 고정)
│           ├── ProblemCard
│           ├── CauseCard
│           ├── ActionCard
│           └── SimulationCard
└── Critical Factors (기존)
```

---

## 🎨 디자인 특징

- **다크 모드 지원**: 모든 컴포넌트 다크 모드 대응
- **반응형**: Responsive 유틸리티 사용
- **일관된 색상**: 
  - Primary: `#37EC13` (녹색)
  - Problem: 녹색 아이콘
  - Cause: 주황색 아이콘
  - Action: 녹색 아이콘
  - Simulation: 파란색 아이콘 + 배지

---

## 🔄 기존 스키마 호환성

기존 스키마(`cards` 배열)도 자동으로 새 스키마로 변환하여 표시:
- `_convertOldSchemaToNew()` 함수로 변환
- 섹션별로 카드 분배
- 기본 탭/섹션 구조 생성

---

## 📝 다음 단계 (선택사항)

1. **스켈레톤 로딩**: 리포트 fetch 중 skeleton UI 추가
2. **애니메이션**: 탭 전환 시 부드러운 애니메이션
3. **오프라인 지원**: 캐시된 리포트 표시
4. **공유 기능**: 리포트 공유 기능 구현

---

## ✅ 완료

모든 요구사항이 구현되었으며, 백엔드의 새로운 스키마와 완벽하게 호환됩니다.
