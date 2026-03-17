import 'package:biostream/screens/signup/signup_controller.dart';
import 'package:biostream/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  Map<String, dynamic> signUpResponse = {'success': true};
  Map<String, dynamic> loginResponse = {'success': true};

  String? lastSignUpEmail;
  String? lastSignUpGender;
  bool? lastSignUpIsPregnant;

  @override
  Future<Map<String, dynamic>> signUp(
    String email,
    String password,
    String nickname,
    String birthdate,
    String gender,
    bool? isPregnant,
  ) async {
    lastSignUpEmail = email;
    lastSignUpGender = gender;
    lastSignUpIsPregnant = isPregnant;
    return signUpResponse;
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    return loginResponse;
  }
}

void main() {
  group('SignUpController', () {
    test('비밀번호 불일치 시 즉시 실패한다', () async {
      final auth = _FakeAuthService();
      final controller = SignUpController(authService: auth);

      final result = await controller.submit(
        const SignUpSubmissionInput(
          email: 'test@example.com',
          password: '1234',
          confirmPassword: '12345',
          nickname: 'tester',
          birthdate: '1990-01-01',
          gender: '남성',
          agreeToTerms: true,
        ),
      );

      expect(result.success, isFalse);
      expect(result.message, '비밀번호가 일치하지 않습니다.');
      expect(result.nextRoute, SignUpNextRoute.none);
    });

    test('필수값 누락 시 안내 메시지를 반환한다', () async {
      final auth = _FakeAuthService();
      final controller = SignUpController(authService: auth);

      final result = await controller.submit(
        const SignUpSubmissionInput(
          email: '',
          password: '',
          confirmPassword: '',
          nickname: '',
          birthdate: '',
          gender: null,
          agreeToTerms: false,
        ),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('다음 항목을 입력해주세요:'));
      expect(result.message, contains('이메일'));
      expect(result.message, contains('약관 동의'));
    });

    test('회원가입 실패 메시지를 그대로 전달한다', () async {
      final auth = _FakeAuthService()
        ..signUpResponse = {'success': false, 'message': '이미 존재하는 이메일'};
      final controller = SignUpController(authService: auth);

      final result = await controller.submit(
        const SignUpSubmissionInput(
          email: 'dup@example.com',
          password: '1234',
          confirmPassword: '1234',
          nickname: 'tester',
          birthdate: '1990-01-01',
          gender: '남성',
          agreeToTerms: true,
        ),
      );

      expect(result.success, isFalse);
      expect(result.message, '이미 존재하는 이메일');
      expect(result.nextRoute, SignUpNextRoute.none);
    });

    test('회원가입+로그인 성공 시 home으로 이동한다', () async {
      final auth = _FakeAuthService()
        ..signUpResponse = {'success': true}
        ..loginResponse = {'success': true};
      final controller = SignUpController(authService: auth);

      final result = await controller.submit(
        const SignUpSubmissionInput(
          email: 'ok@example.com',
          password: '1234',
          confirmPassword: '1234',
          nickname: 'tester',
          birthdate: '1990-01-01',
          gender: '남성',
          agreeToTerms: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, '회원가입 및 로그인 성공!');
      expect(result.nextRoute, SignUpNextRoute.home);
      expect(auth.lastSignUpEmail, 'ok@example.com');
      expect(auth.lastSignUpGender, '남성');
      expect(auth.lastSignUpIsPregnant, isNull);
    });

    test('회원가입 성공 후 로그인 실패 시 login으로 이동한다', () async {
      final auth = _FakeAuthService()
        ..signUpResponse = {'success': true}
        ..loginResponse = {'success': false};
      final controller = SignUpController(authService: auth);

      final result = await controller.submit(
        const SignUpSubmissionInput(
          email: 'ok2@example.com',
          password: '1234',
          confirmPassword: '1234',
          nickname: 'tester',
          birthdate: '1990-01-01',
          gender: '여성',
          isPregnant: true,
          agreeToTerms: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, '회원가입 성공! 로그인해주세요.');
      expect(result.nextRoute, SignUpNextRoute.login);
      expect(auth.lastSignUpIsPregnant, isTrue);
    });
  });
}
