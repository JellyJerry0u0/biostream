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
            onToggleQuestItem: (_) {},
            onOpenQuestDetail: (_) {},
            onGoToReport: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('퀘스트 항목 탭과 상세보기 콜백을 호출한다', (tester) async {
      final tappedItems = <HomeQuestItem>[];
      final detailOpenedItems = <HomeQuestItem>[];
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
            onToggleQuestItem: tappedItems.add,
            onOpenQuestDetail: detailOpenedItems.add,
            onGoToReport: () {},
          ),
        ),
      );

      await tester.tap(find.text('수분 섭취 늘리기'));
      await tester.pump();
      expect(tappedItems, hasLength(1));
      expect(tappedItems.first.id, 'q1');

      await tester.tap(find.text('상세보기'));
      await tester.pump();
      expect(detailOpenedItems, hasLength(1));
      expect(detailOpenedItems.first.id, 'q1');
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
            onToggleQuestItem: (_) {},
            onOpenQuestDetail: (_) {},
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
            primaryColor: const Color(0xFF2BEE75),
            backgroundDarkColor: const Color(0xFF050C08),
            gameCardColor: const Color(0xFF0D1F14),
            originalImageUrl: null,
            generatedImageUrl: null,
            predictionPoint: null,
            onOpenResult: () {},
          ),
        ),
      );

      expect(find.text('최근 노화 예측 결과'), findsNothing);
      expect(find.text('AI 분석 리포트'), findsNothing);
    });

    testWidgets('전체 보기와 리포트 버튼이 동일 콜백을 호출한다', (tester) async {
      var openResultCalled = 0;

      await tester.pumpWidget(
        _testApp(
          child: HomeRecentPredictionSection(
            primaryColor: const Color(0xFF2BEE75),
            backgroundDarkColor: const Color(0xFF050C08),
            gameCardColor: const Color(0xFF0D1F14),
            originalImageUrl: null,
            generatedImageUrl: null,
            predictionPoint: '눈가 주름 관리가 필요합니다.',
            onOpenResult: () {
              openResultCalled += 1;
            },
          ),
        ),
      );

      expect(find.text('최근 노화 예측 결과'), findsOneWidget);
      expect(find.text('눈가 주름 관리가 필요합니다.'), findsOneWidget);

      await tester.tap(find.text('전체 보기'));
      await tester.pump();
      await tester.tap(find.text('AI 분석 리포트'));
      await tester.pump();

      expect(openResultCalled, 2);
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
