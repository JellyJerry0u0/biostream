import 'package:shared_preferences/shared_preferences.dart';

import '../../services/profile_service.dart';

class MyInfoProfileData {
  const MyInfoProfileData({
    required this.nickname,
    required this.email,
    this.profileImagePath,
  });

  final String nickname;
  final String email;
  final String? profileImagePath;
}

class MyInfoProfileController {
  MyInfoProfileController({
    required ProfileService profileService,
    required Future<SharedPreferences> Function() prefsProvider,
  })  : _profileService = profileService,
        _prefsProvider = prefsProvider;

  static const String keyProfileEmail = 'profile_email';
  static const String keyProfileNickname = 'profile_nickname';
  static const String keyProfileImagePath = 'profile_image_path';

  final ProfileService _profileService;
  final Future<SharedPreferences> Function() _prefsProvider;

  Future<MyInfoProfileData> loadLocalProfile({
    required String defaultNickname,
    required String defaultEmail,
  }) async {
    final prefs = await _prefsProvider();

    final nickname =
        prefs.getString(keyProfileNickname)?.trim().isNotEmpty == true
            ? prefs.getString(keyProfileNickname)!.trim()
            : defaultNickname;
    final email = prefs.getString(keyProfileEmail)?.trim().isNotEmpty == true
        ? prefs.getString(keyProfileEmail)!.trim()
        : defaultEmail;
    final profileImagePath = prefs.getString(keyProfileImagePath);

    return MyInfoProfileData(
      nickname: nickname,
      email: email,
      profileImagePath: profileImagePath,
    );
  }

  Future<MyInfoProfileData?> syncProfileFromServer({
    required MyInfoProfileData current,
  }) async {
    final result = await _profileService.getMyProfile();
    if (result['success'] != true) return null;

    final data = result['data'] as Map<String, dynamic>;
    final serverNickname = (data['nickname'] ?? '').toString().trim();
    final serverEmail = (data['email'] ?? '').toString().trim();
    final serverImage = (data['profile_image_url'] ?? '').toString().trim();

    final resolvedNickname =
        serverNickname.isNotEmpty ? serverNickname : current.nickname;
    final resolvedEmail = serverEmail.isNotEmpty ? serverEmail : current.email;
    final resolvedImage =
        serverImage.isNotEmpty ? serverImage : current.profileImagePath;

    final prefs = await _prefsProvider();
    if (serverNickname.isNotEmpty) {
      await prefs.setString(keyProfileNickname, serverNickname);
    }
    if (serverEmail.isNotEmpty) {
      await prefs.setString(keyProfileEmail, serverEmail);
    }
    if (serverImage.isNotEmpty) {
      await prefs.setString(keyProfileImagePath, serverImage);
    }

    return MyInfoProfileData(
      nickname: resolvedNickname,
      email: resolvedEmail,
      profileImagePath: resolvedImage,
    );
  }

  Future<MyInfoProfileData> saveProfile({
    required String nickname,
    required String email,
    String? currentImagePath,
    String? profileImagePath,
  }) async {
    final apiResult = await _profileService.updateMyProfile(
      nickname: nickname,
      email: email,
      profileImagePath: profileImagePath,
    );

    var resolvedNickname = nickname;
    var resolvedEmail = email;
    String? resolvedImage = profileImagePath ?? currentImagePath;

    if (apiResult['success'] == true) {
      final data = apiResult['data'] as Map<String, dynamic>;
      final serverNickname = (data['nickname'] ?? '').toString().trim();
      final serverEmail = (data['email'] ?? '').toString().trim();
      final serverImage = (data['profile_image_url'] ?? '').toString().trim();

      if (serverNickname.isNotEmpty) resolvedNickname = serverNickname;
      if (serverEmail.isNotEmpty) resolvedEmail = serverEmail;
      if (serverImage.isNotEmpty) resolvedImage = serverImage;
    }

    final prefs = await _prefsProvider();
    await prefs.setString(keyProfileNickname, resolvedNickname);
    await prefs.setString(keyProfileEmail, resolvedEmail);
    if (resolvedImage != null && resolvedImage.isNotEmpty) {
      await prefs.setString(keyProfileImagePath, resolvedImage);
    }

    return MyInfoProfileData(
      nickname: resolvedNickname,
      email: resolvedEmail,
      profileImagePath: resolvedImage,
    );
  }
}
