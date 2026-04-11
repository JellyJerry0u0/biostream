import 'package:biostream/screens/home/home_models.dart';
import 'package:biostream/widgets/home/home_quest_section.dart';
import 'package:biostream/widgets/home/home_recent_prediction_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeQuestSection', () {
    testWidgets('로딩 상태에서 인디케이터를 표시한다', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: HomeQuestSection(
            primaryColor: const Color(0xFF2BEE75),
            gameCardColor: const Color(0xFF0D1F14),
            isLoadingQuests: true,
            questError: null,
            questItems: const [],
            onOpenQuestEditor: (_) {},
            onToggleDoneOnList: (_, __) async {},
            onGoToReport: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('생활습관 항목 탭 시 편집 콜백을 호출한다', (tester) async {
      final editorOpened = <HomeQuestItem>[];
      final item = HomeQuestItem(
        id: 'q1',
        title: '수분 섭취 늘리기',
        detail: '하루 8잔 물 마시기',
      );

      await tester.pumpWidget(
        _testApp(
          child: HomeQuestSection(
            primaryColor: const Color(0xFF2BEE75),
            gameCardColor: const Color(0xFF0D1F14),
            isLoadingQuests: false,
            questError: null,
            questItems: [item],
            onOpenQuestEditor: editorOpened.add,
            onToggleDoneOnList: (_, __) async {},
            onGoToReport: () {},
          ),
        ),
      );

      await tester.tap(find.text('수분 섭취 늘리기'));
      await tester.pump();
      expect(editorOpened, hasLength(1));
      expect(editorOpened.first.id, 'q1');
    });

    testWidgets('에러 상태에서 리포트 이동 콜백을 호출한다', (tester) async {
      var goToReportCalled = false;

      await tester.pumpWidget(
        _testApp(
          child: HomeQuestSection(
            primaryColor: const Color(0xFF2BEE75),
            gameCardColor: const Color(0xFF0D1F14),
            isLoadingQuests: false,
            questError: '맞춤 솔루션을 불러오지 못했습니다.',
            questItems: const [],
            onOpenQuestEditor: (_) {},
            onToggleDoneOnList: (_, __) async {},
            onGoToReport: () {
              goToReportCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('리포트 만들러 가기'));
      await tester.pump();

      expect(goToReportCalled, isTrue);
    });
  });

  group('HomeRecentPredictionSection', () {
    testWidgets('표시할 데이터가 없으면 섹션을 숨긴다', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: HomeRecentPredictionSection(
            originalImageUrl: null,
            generatedImageUrl: null,
            predictionPoint: null,
            primaryColor: const Color(0xFF2BEE75),
            gameCardColor: const Color(0xFF0D1F14),
            onOpenResult: () {},
          ),
        ),
      );

      expect(find.text('최근 Weekly Report 조회'), findsNothing);
    });

    testWidgets('다시 보기가 결과 열기 콜백을 호출한다', (tester) async {
      var openResultCalled = 0;

      await tester.pumpWidget(
        _testApp(
          child: HomeRecentPredictionSection(
            originalImageUrl: null,
            generatedImageUrl: null,
            predictionPoint: '눈가 주름 관리가 필요합니다.',
            primaryColor: const Color(0xFF2BEE75),
            gameCardColor: const Color(0xFF0D1F14),
            onOpenResult: () {
              openResultCalled += 1;
            },
          ),
        ),
      );

      expect(find.text('최근 Weekly Report 조회'), findsOneWidget);

      await tester.tap(find.text('다시 보기'));
      await tester.pump();

      expect(openResultCalled, 1);
    });
  });
}

Widget _testApp({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}
