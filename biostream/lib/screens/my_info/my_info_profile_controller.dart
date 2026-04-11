import 'package:shared_preferences/shared_preferences.dart';

import '../../services/profile_service.dart';

class MyInfoProfileData {
  const MyInfoProfileData({
    required this.nickname,
    required this.userId,
    required this.accountEmail,
    this.heightCm,
    this.weightKg,
  });

  final String nickname;
  /// 표시용 (서버 user_id 문자열)
  final String userId;
  /// 로그인 계정 이메일 — 서버 PUT /me 에만 사용, UI에 노출하지 않음
  final String accountEmail;
  final double? heightCm;
  final double? weightKg;
}

class MyInfoProfileController {
  MyInfoProfileController({
    required ProfileService profileService,
    required Future<SharedPreferences> Function() prefsProvider,
  })  : _profileService = profileService,
        _prefsProvider = prefsProvider;

  static const String keyProfileEmail = 'profile_email';
  static const String keyProfileNickname = 'profile_nickname';
  static const String keyProfileUserId = 'profile_user_id';
  static const String keyProfileHeightCm = 'profile_height_cm';
  static const String keyProfileWeightKg = 'profile_weight_kg';

  final ProfileService _profileService;
  final Future<SharedPreferences> Function() _prefsProvider;

  static String? _readPrefsString(SharedPreferences prefs, String key) {
    final raw = prefs.get(key);
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _parsePrefsDouble(SharedPreferences prefs, String key) {
    final s = _readPrefsString(prefs, key);
    if (s == null) return null;
    return double.tryParse(s);
  }

  Future<MyInfoProfileData> loadLocalProfile({
    required String defaultNickname,
    required String defaultUserId,
    required String defaultAccountEmail,
  }) async {
    final prefs = await _prefsProvider();

    final nickname = _readPrefsString(prefs, keyProfileNickname) ?? defaultNickname;
    final accountEmail = _readPrefsString(prefs, keyProfileEmail) ?? defaultAccountEmail;
    final userId = _readPrefsString(prefs, keyProfileUserId) ?? defaultUserId;

    return MyInfoProfileData(
      nickname: nickname,
      userId: userId,
      accountEmail: accountEmail,
      heightCm: _parsePrefsDouble(prefs, keyProfileHeightCm),
      weightKg: _parsePrefsDouble(prefs, keyProfileWeightKg),
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
    final rawUid = data['user_id'];
    final serverUserId =
        rawUid == null ? '' : rawUid.toString().trim();
    final serverHeight = data['height_cm'];
    final serverWeight = data['weight_kg'];
    double? heightCm;
    double? weightKg;
    if (serverHeight is num) heightCm = serverHeight.toDouble();
    if (serverWeight is num) weightKg = serverWeight.toDouble();

    final resolvedNickname =
        serverNickname.isNotEmpty ? serverNickname : current.nickname;
    final resolvedEmail =
        serverEmail.isNotEmpty ? serverEmail : current.accountEmail;
    final resolvedUserId =
        serverUserId.isNotEmpty ? serverUserId : current.userId;
    final resolvedHeight = heightCm ?? current.heightCm;
    final resolvedWeight = weightKg ?? current.weightKg;

    final prefs = await _prefsProvider();
    if (serverNickname.isNotEmpty) {
      await prefs.setString(keyProfileNickname, serverNickname);
    }
    if (serverEmail.isNotEmpty) {
      await prefs.setString(keyProfileEmail, serverEmail);
    }
    if (serverUserId.isNotEmpty) {
      await prefs.setString(keyProfileUserId, serverUserId);
    }
    if (heightCm != null) {
      await prefs.setString(keyProfileHeightCm, heightCm.toString());
    }
    if (weightKg != null) {
      await prefs.setString(keyProfileWeightKg, weightKg.toString());
    }

    return MyInfoProfileData(
      nickname: resolvedNickname,
      userId: resolvedUserId,
      accountEmail: resolvedEmail,
      heightCm: resolvedHeight,
      weightKg: resolvedWeight,
    );
  }

  Future<MyInfoProfileData> saveProfile({
    required MyInfoProfileData previous,
    required String nickname,
    required String accountEmail,
    double? heightCm,
    double? weightKg,
  }) async {
    final apiResult = await _profileService.updateMyProfile(
      nickname: nickname,
      accountEmail: accountEmail,
      heightCm: heightCm,
      weightKg: weightKg,
    );

    var resolvedNickname = nickname;
    var resolvedEmail = accountEmail;
    double? resolvedHeight = heightCm;
    double? resolvedWeight = weightKg;
    var resolvedUserId = previous.userId;

    if (apiResult['success'] == true) {
      final data = apiResult['data'] as Map<String, dynamic>;
      final serverNickname = (data['nickname'] ?? '').toString().trim();
      final serverEmail = (data['email'] ?? '').toString().trim();
      final rawUid = data['user_id'];
      final uid = rawUid == null ? '' : rawUid.toString().trim();
      final sh = data['height_cm'];
      final sw = data['weight_kg'];
      if (serverNickname.isNotEmpty) resolvedNickname = serverNickname;
      if (serverEmail.isNotEmpty) resolvedEmail = serverEmail;
      if (uid.isNotEmpty) resolvedUserId = uid;
      if (sh is num) resolvedHeight = sh.toDouble();
      if (sw is num) resolvedWeight = sw.toDouble();
    }

    final prefs = await _prefsProvider();
    await prefs.setString(keyProfileNickname, resolvedNickname);
    await prefs.setString(keyProfileEmail, resolvedEmail);
    if (resolvedUserId.isNotEmpty) {
      await prefs.setString(keyProfileUserId, resolvedUserId);
    }
    if (resolvedHeight != null) {
      await prefs.setString(keyProfileHeightCm, resolvedHeight.toString());
    }
    if (resolvedWeight != null) {
      await prefs.setString(keyProfileWeightKg, resolvedWeight.toString());
    }

    return MyInfoProfileData(
      nickname: resolvedNickname,
      userId: resolvedUserId,
      accountEmail: resolvedEmail,
      heightCm: resolvedHeight,
      weightKg: resolvedWeight,
    );
  }
}
