import 'package:biostream/screens/my_info/my_info_profile_controller.dart';
import 'package:biostream/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileService extends ProfileService {
  Map<String, dynamic> getProfileResponse = {'success': false};
  Map<String, dynamic> updateProfileResponse = {'success': false};

  @override
  Future<Map<String, dynamic>> getMyProfile() async => getProfileResponse;

  @override
  Future<Map<String, dynamic>> updateMyProfile({
    required String nickname,
    required String email,
    String? profileImagePath,
  }) async {
    return updateProfileResponse;
  }
}

void main() {
  group('MyInfoProfileController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadLocalProfile은 prefs값을 우선 사용한다', () async {
      SharedPreferences.setMockInitialValues({
        MyInfoProfileController.keyProfileNickname: '로컬닉',
        MyInfoProfileController.keyProfileEmail: 'local@test.com',
        MyInfoProfileController.keyProfileImagePath: '/tmp/local.jpg',
      });
      final controller = MyInfoProfileController(
        profileService: _FakeProfileService(),
        prefsProvider: SharedPreferences.getInstance,
      );

      final result = await controller.loadLocalProfile(
        defaultNickname: '기본닉',
        defaultEmail: 'default@test.com',
      );

      expect(result.nickname, '로컬닉');
      expect(result.email, 'local@test.com');
      expect(result.profileImagePath, '/tmp/local.jpg');
    });

    test('syncProfileFromServer 성공 시 서버 데이터와 prefs를 갱신한다', () async {
      final fakeService = _FakeProfileService()
        ..getProfileResponse = {
          'success': true,
          'data': {
            'nickname': '서버닉',
            'email': 'server@test.com',
            'profile_image_url': 'https://example.com/p.jpg',
          },
        };
      final controller = MyInfoProfileController(
        profileService: fakeService,
        prefsProvider: SharedPreferences.getInstance,
      );

      final result = await controller.syncProfileFromServer(
        current: const MyInfoProfileData(
          nickname: '현재닉',
          email: 'current@test.com',
        ),
      );

      expect(result, isNotNull);
      expect(result!.nickname, '서버닉');
      expect(result.email, 'server@test.com');
      expect(result.profileImagePath, 'https://example.com/p.jpg');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(MyInfoProfileController.keyProfileNickname),
        '서버닉',
      );
      expect(
        prefs.getString(MyInfoProfileController.keyProfileEmail),
        'server@test.com',
      );
    });

    test('saveProfile은 서버 응답값을 우선 적용해 저장한다', () async {
      final fakeService = _FakeProfileService()
        ..updateProfileResponse = {
          'success': true,
          'data': {
            'nickname': '서버저장닉',
            'email': 'saved@test.com',
            'profile_image_url': 'https://example.com/saved.jpg',
          },
        };
      final controller = MyInfoProfileController(
        profileService: fakeService,
        prefsProvider: SharedPreferences.getInstance,
      );

      final result = await controller.saveProfile(
        nickname: '입력닉',
        email: 'input@test.com',
        currentImagePath: '/tmp/old.jpg',
      );

      expect(result.nickname, '서버저장닉');
      expect(result.email, 'saved@test.com');
      expect(result.profileImagePath, 'https://example.com/saved.jpg');
    });
  });
}
