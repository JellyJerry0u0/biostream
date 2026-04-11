import 'package:biostream/widgets/login/login_form_section.dart';
import 'package:biostream/widgets/login/login_header_section.dart';
import 'package:biostream/widgets/login/login_social_footer_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginFormSection', () {
    testWidgets('비밀번호 표시 토글 콜백을 호출한다', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        _testApp(
          child: LoginFormSection(
            isDark: false,
            emailController: TextEditingController(),
            passwordController: TextEditingController(),
            emailFocusNode: FocusNode(),
            passwordFocusNode: FocusNode(),
            obscurePassword: true,
            onTogglePasswordVisibility: () {
              toggled = true;
            },
            onForgotPassword: () {},
            onLogin: () {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('비밀번호 찾기와 로그인 콜백을 호출한다', (tester) async {
      var forgotCalled = false;
      var loginCalled = false;

      await tester.pumpWidget(
        _testApp(
          child: LoginFormSection(
            isDark: false,
            emailController: TextEditingController(),
            passwordController: TextEditingController(),
            emailFocusNode: FocusNode(),
            passwordFocusNode: FocusNode(),
            obscurePassword: true,
            onTogglePasswordVisibility: () {},
            onForgotPassword: () {
              forgotCalled = true;
            },
            onLogin: () {
              loginCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('비밀번호를 잊으셨나요?'));
      await tester.pump();
      await tester.tap(find.text('로그인'));
      await tester.pump();

      expect(forgotCalled, isTrue);
      expect(loginCalled, isTrue);
    });
  });

  group('LoginSocialSection', () {
    testWidgets('카카오 로그인 버튼 콜백을 호출한다', (tester) async {
      var kakaoCalled = false;

      await tester.pumpWidget(
        _testApp(
          child: LoginSocialSection(
            isDark: false,
            onKakaoLogin: () {
              kakaoCalled = true;
            },
          ),
        ),
      );

      expect(find.text('SNS 계정으로 간편 로그인'), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(kakaoCalled, isTrue);
    });
  });

  group('LoginFooterSection', () {
    testWidgets('회원가입 이동 콜백을 호출한다', (tester) async {
      var signUpCalled = false;

      await tester.pumpWidget(
        _testApp(
          child: LoginFooterSection(
            isDark: false,
            horizontalPadding: 16,
            onSignUp: () {
              signUpCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(signUpCalled, isTrue);
    });
  });

  group('LoginHeaderSection', () {
    testWidgets('헤더 주요 텍스트를 렌더링한다', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const LoginHeaderSection(
            isDark: false,
            horizontalPadding: 24,
          ),
        ),
      );

      expect(find.text('AI 피부 분석'), findsOneWidget);
      expect(find.textContaining('미래의 나를 만나는 시간'), findsOneWidget);
    });
  });
}

Widget _testApp({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}
