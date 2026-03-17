import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';

enum LoginNextRoute {
  none,
  home,
  profileCompletion,
  faceScan,
}

class LoginSubmissionInput {
  const LoginSubmissionInput({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class LoginFlowResult {
  const LoginFlowResult({
    required this.success,
    required this.message,
    required this.nextRoute,
  });

  final bool success;
  final String message;
  final LoginNextRoute nextRoute;
}

class LoginController {
  LoginController({
    required AuthService authService,
    required Future<SharedPreferences> Function() prefsProvider,
    required Future<void> Function() syncTokenToServer,
  })  : _authService = authService,
        _prefsProvider = prefsProvider,
        _syncTokenToServer = syncTokenToServer;

  static const String keyProfileEmail = 'profile_email';
  static const String keyProfileNickname = 'profile_nickname';
  static const String keyProfileUserId = 'profile_user_id';

  final AuthService _authService;
  final Future<SharedPreferences> Function() _prefsProvider;
  final Future<void> Function() _syncTokenToServer;

  Future<LoginFlowResult> submitLogin(LoginSubmissionInput input) async {
    if (input.email.trim().isEmpty || input.password.isEmpty) {
      return const LoginFlowResult(
        success: false,
        message: '이메일과 비밀번호를 모두 입력해주세요.',
        nextRoute: LoginNextRoute.none,
      );
    }

    final email = input.email.trim();
    final result = await _authService.login(email, input.password);
    if (result['success'] != true) {
      return LoginFlowResult(
        success: false,
        message: (result['message'] ?? '로그인에 실패했습니다.').toString(),
        nextRoute: LoginNextRoute.none,
      );
    }

    final prefs = await _prefsProvider();
    await prefs.setString(keyProfileEmail, email);

    final nickname = (result['nickname'] ?? '').toString().trim();
    if (nickname.isNotEmpty) {
      await prefs.setString(keyProfileNickname, nickname);
    }

    final userId = result['user_id'];
    if (userId is int) {
      await prefs.setInt(keyProfileUserId, userId);
    } else if (userId is num) {
      await prefs.setInt(keyProfileUserId, userId.toInt());
    }

    await _syncTokenToServer();
    return const LoginFlowResult(
      success: true,
      message: '',
      nextRoute: LoginNextRoute.home,
    );
  }

  Future<LoginFlowResult> submitKakaoLogin() async {
    final result = await _authService.loginWithKakao();
    if (result['success'] != true) {
      return LoginFlowResult(
        success: false,
        message: (result['message'] ?? '카카오 로그인 실패').toString(),
        nextRoute: LoginNextRoute.none,
      );
    }

    if (result['needs_profile'] == true) {
      return const LoginFlowResult(
        success: true,
        message: '',
        nextRoute: LoginNextRoute.profileCompletion,
      );
    }

    return const LoginFlowResult(
      success: true,
      message: '',
      nextRoute: LoginNextRoute.faceScan,
    );
  }
}
