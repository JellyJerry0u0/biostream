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
    required String accountEmail,
    double? heightCm,
    double? weightKg,
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
        MyInfoProfileController.keyProfileUserId: '42',
        MyInfoProfileController.keyProfileHeightCm: '170',
        MyInfoProfileController.keyProfileWeightKg: '65.5',
      });
      final controller = MyInfoProfileController(
        profileService: _FakeProfileService(),
        prefsProvider: SharedPreferences.getInstance,
      );

      final result = await controller.loadLocalProfile(
        defaultNickname: '기본닉',
        defaultUserId: '0',
        defaultAccountEmail: 'default@test.com',
      );

      expect(result.nickname, '로컬닉');
      expect(result.accountEmail, 'local@test.com');
      expect(result.userId, '42');
      expect(result.heightCm, 170);
      expect(result.weightKg, 65.5);
    });

    test('syncProfileFromServer 성공 시 서버 데이터와 prefs를 갱신한다', () async {
      final fakeService = _FakeProfileService()
        ..getProfileResponse = {
          'success': true,
          'data': {
            'user_id': 7,
            'nickname': '서버닉',
            'email': 'server@test.com',
            'height_cm': 175.0,
            'weight_kg': 70.0,
          },
        };
      final controller = MyInfoProfileController(
        profileService: fakeService,
        prefsProvider: SharedPreferences.getInstance,
      );

      final result = await controller.syncProfileFromServer(
        current: const MyInfoProfileData(
          nickname: '현재닉',
          userId: '1',
          accountEmail: 'current@test.com',
        ),
      );

      expect(result, isNotNull);
      expect(result!.nickname, '서버닉');
      expect(result.accountEmail, 'server@test.com');
      expect(result.userId, '7');
      expect(result.heightCm, 175);
      expect(result.weightKg, 70);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(MyInfoProfileController.keyProfileNickname),
        '서버닉',
      );
      expect(
        prefs.getString(MyInfoProfileController.keyProfileEmail),
        'server@test.com',
      );
      expect(
        prefs.getString(MyInfoProfileController.keyProfileUserId),
        '7',
      );
    });

    test('saveProfile은 서버 응답값을 우선 적용해 저장한다', () async {
      final fakeService = _FakeProfileService()
        ..updateProfileResponse = {
          'success': true,
          'data': {
            'user_id': 99,
            'nickname': '서버저장닉',
            'email': 'saved@test.com',
            'height_cm': 180.0,
            'weight_kg': 75.0,
          },
        };
      final controller = MyInfoProfileController(
        profileService: fakeService,
        prefsProvider: SharedPreferences.getInstance,
      );

      final result = await controller.saveProfile(
        previous: const MyInfoProfileData(
          nickname: '이전닉',
          userId: '99',
          accountEmail: 'saved@test.com',
        ),
        nickname: '입력닉',
        accountEmail: 'input@test.com',
        heightCm: 170,
        weightKg: 68,
      );

      expect(result.nickname, '서버저장닉');
      expect(result.accountEmail, 'saved@test.com');
      expect(result.userId, '99');
      expect(result.heightCm, 180);
      expect(result.weightKg, 75);
    });
  });
}
