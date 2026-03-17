import 'package:biostream/screens/login/login_controller.dart';
import 'package:biostream/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  Map<String, dynamic> loginResponse = {'success': true};
  Map<String, dynamic> kakaoResponse = {'success': true};

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    return loginResponse;
  }

  @override
  Future<Map<String, dynamic>> loginWithKakao() async {
    return kakaoResponse;
  }
}

void main() {
  group('LoginController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('이메일/비밀번호 누락 시 실패를 반환한다', () async {
      final auth = _FakeAuthService();
      final controller = LoginController(
        authService: auth,
        prefsProvider: SharedPreferences.getInstance,
        syncTokenToServer: () async {},
      );

      final result = await controller.submitLogin(
        const LoginSubmissionInput(email: '', password: ''),
      );

      expect(result.success, isFalse);
      expect(result.message, '이메일과 비밀번호를 모두 입력해주세요.');
      expect(result.nextRoute, LoginNextRoute.none);
    });

    test('로그인 실패 시 서버 메시지를 반환한다', () async {
      final auth = _FakeAuthService()
        ..loginResponse = {'success': false, 'message': '로그인 실패'};
      final controller = LoginController(
        authService: auth,
        prefsProvider: SharedPreferences.getInstance,
        syncTokenToServer: () async {},
      );

      final result = await controller.submitLogin(
        const LoginSubmissionInput(email: 'a@b.com', password: '1234'),
      );

      expect(result.success, isFalse);
      expect(result.message, '로그인 실패');
      expect(result.nextRoute, LoginNextRoute.none);
    });

    test('로그인 성공 시 프로필 저장과 홈 라우트를 반환한다', () async {
      var tokenSynced = false;
      final auth = _FakeAuthService()
        ..loginResponse = {
          'success': true,
          'nickname': 'tester',
          'user_id': 42,
        };
      final controller = LoginController(
        authService: auth,
        prefsProvider: SharedPreferences.getInstance,
        syncTokenToServer: () async {
          tokenSynced = true;
        },
      );

      final result = await controller.submitLogin(
        const LoginSubmissionInput(email: 'a@b.com', password: '1234'),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LoginController.keyProfileEmail), 'a@b.com');
      expect(prefs.getString(LoginController.keyProfileNickname), 'tester');
      expect(prefs.getInt(LoginController.keyProfileUserId), 42);
      expect(tokenSynced, isTrue);
      expect(result.success, isTrue);
      expect(result.nextRoute, LoginNextRoute.home);
    });

    test('카카오 로그인 성공+프로필 필요 시 profileCompletion 라우트', () async {
      final auth = _FakeAuthService()
        ..kakaoResponse = {'success': true, 'needs_profile': true};
      final controller = LoginController(
        authService: auth,
        prefsProvider: SharedPreferences.getInstance,
        syncTokenToServer: () async {},
      );

      final result = await controller.submitKakaoLogin();

      expect(result.success, isTrue);
      expect(result.nextRoute, LoginNextRoute.profileCompletion);
    });

    test('카카오 로그인 성공+프로필 불필요 시 faceScan 라우트', () async {
      final auth = _FakeAuthService()
        ..kakaoResponse = {'success': true, 'needs_profile': false};
      final controller = LoginController(
        authService: auth,
        prefsProvider: SharedPreferences.getInstance,
        syncTokenToServer: () async {},
      );

      final result = await controller.submitKakaoLogin();

      expect(result.success, isTrue);
      expect(result.nextRoute, LoginNextRoute.faceScan);
    });

    test('카카오 로그인 실패 메시지를 반환한다', () async {
      final auth = _FakeAuthService()
        ..kakaoResponse = {'success': false, 'message': '카카오 실패'};
      final controller = LoginController(
        authService: auth,
        prefsProvider: SharedPreferences.getInstance,
        syncTokenToServer: () async {},
      );

      final result = await controller.submitKakaoLogin();

      expect(result.success, isFalse);
      expect(result.message, '카카오 실패');
      expect(result.nextRoute, LoginNextRoute.none);
    });
  });
}
