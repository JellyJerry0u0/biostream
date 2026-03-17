import 'package:biostream/models/coach_models.dart';
import 'package:biostream/widgets/coach/coach_chat_input_bar.dart';
import 'package:biostream/widgets/coach/coach_stream_chat_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachChat widgets', () {
    testWidgets('CoachChatInputBar 퀵칩 탭 시 onQuickAction 호출', (tester) async {
      String? quickActionText;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachChatInputBar(
              isDark: false,
              horizontalPadding: 16,
              inputController: controller,
              isAssistantStreaming: false,
              onSend: () {},
              onQuickAction: (text) {
                quickActionText = text;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('오늘의 플랜'));
      await tester.pumpAndSettle();

      expect(quickActionText, isNotNull);
      expect(quickActionText, contains('피부 관리법'));
      controller.dispose();
    });

    testWidgets('CoachChatInputBar 스트리밍 중 전송 버튼 비활성', (tester) async {
      var sendCount = 0;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachChatInputBar(
              isDark: false,
              horizontalPadding: 16,
              inputController: controller,
              isAssistantStreaming: true,
              onSend: () {
                sendCount += 1;
              },
              onQuickAction: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.hourglass_top));
      await tester.pumpAndSettle();

      expect(sendCount, 0);
      controller.dispose();
    });

    testWidgets('CoachStreamChatArea 액션칩 탭 시 onActionTap 호출', (tester) async {
      ActionItem? tappedAction;
      final message = CoachChatMessage(
        id: 'a1',
        role: 'assistant',
        content: '추천 액션입니다.',
        isStreaming: false,
        actions: [
          ActionItem(id: 'save_goal', label: '목표 저장'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachStreamChatArea(
              isDark: false,
              horizontalPadding: 16,
              scrollController: ScrollController(),
              messages: [message],
              centerScale: const AlwaysStoppedAnimation<double>(1),
              engine: CoachEngine.quick,
              currentToolStatus: null,
              onActionTap: (action) {
                tappedAction = action;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('목표 저장'));
      await tester.pumpAndSettle();

      expect(tappedAction, isNotNull);
      expect(tappedAction!.id, 'save_goal');
    });
  });
}
