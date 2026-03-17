import '../../services/auth_service.dart';

enum SignUpNextRoute {
  home,
  login,
  none,
}

class SignUpSubmissionInput {
  const SignUpSubmissionInput({
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.nickname,
    required this.birthdate,
    required this.gender,
    required this.agreeToTerms,
    this.isPregnant,
  });

  final String email;
  final String password;
  final String confirmPassword;
  final String nickname;
  final String birthdate;
  final String? gender;
  final bool agreeToTerms;
  final bool? isPregnant;
}

class SignUpSubmissionResult {
  const SignUpSubmissionResult({
    required this.success,
    required this.message,
    required this.nextRoute,
  });

  final bool success;
  final String message;
  final SignUpNextRoute nextRoute;
}

class SignUpController {
  SignUpController({required AuthService authService})
      : _authService = authService;

  final AuthService _authService;

  Future<SignUpSubmissionResult> submit(SignUpSubmissionInput input) async {
    final validationError = _validate(input);
    if (validationError != null) {
      return SignUpSubmissionResult(
        success: false,
        message: validationError,
        nextRoute: SignUpNextRoute.none,
      );
    }

    final email = input.email.trim();
    final password = input.password;
    final nickname = input.nickname.trim();
    final birthdate = input.birthdate.trim();
    final gender = input.gender!;
    final isPregnant = gender == '여성' ? input.isPregnant : null;

    final signUpResult = await _authService.signUp(
      email,
      password,
      nickname,
      birthdate,
      gender,
      isPregnant,
    );

    if (signUpResult['success'] != true) {
      return SignUpSubmissionResult(
        success: false,
        message: (signUpResult['message'] ?? '회원가입 실패').toString(),
        nextRoute: SignUpNextRoute.none,
      );
    }

    final loginResult = await _authService.login(email, password);
    if (loginResult['success'] == true) {
      return const SignUpSubmissionResult(
        success: true,
        message: '회원가입 및 로그인 성공!',
        nextRoute: SignUpNextRoute.home,
      );
    }

    return const SignUpSubmissionResult(
      success: true,
      message: '회원가입 성공! 로그인해주세요.',
      nextRoute: SignUpNextRoute.login,
    );
  }

  String? _validate(SignUpSubmissionInput input) {
    final missingFields = <String>[];

    if (input.email.trim().isEmpty) {
      missingFields.add('이메일');
    }
    if (input.password.isEmpty) {
      missingFields.add('비밀번호');
    }
    if (input.confirmPassword.isEmpty) {
      missingFields.add('비밀번호 확인');
    }
    if (input.password != input.confirmPassword) {
      return '비밀번호가 일치하지 않습니다.';
    }
    if (input.nickname.trim().isEmpty) {
      missingFields.add('닉네임');
    }
    if (input.birthdate.trim().isEmpty) {
      missingFields.add('생년월일');
    }
    if (input.gender == null || input.gender!.isEmpty) {
      missingFields.add('성별');
    }
    if (!input.agreeToTerms) {
      missingFields.add('약관 동의');
    }

    if (missingFields.isEmpty) {
      return null;
    }
    return '다음 항목을 입력해주세요:\n${missingFields.join(', ')}';
  }
}
