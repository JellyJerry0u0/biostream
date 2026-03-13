import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_config.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 카카오 SDK 초기화 (카카오 로그인용)
  KakaoSdk.init(
    nativeAppKey: ApiConfig.kakaoNativeAppKey,
  );
  await NotificationService.instance.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const MethodChannel _devChannel = MethodChannel('com.example.biostream/dev');
  static const String _yesterdaySyncDateKey = 'yesterday_health_sync_date';
  static const String _todaySyncDateKey = 'today_health_sync_date';
  bool _isSyncingYesterday = false;
  bool _isSyncingToday = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncYesterdayHealthAfterOneAmOnForeground();
    _syncTodayHealthOnForeground();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncYesterdayHealthAfterOneAmOnForeground();
      _syncTodayHealthOnForeground();
    }
  }

  Future<void> _syncYesterdayHealthAfterOneAmOnForeground() async {
    if (_isSyncingYesterday) return;
    _isSyncingYesterday = true;
    try {
      final now = DateTime.now();
      if (now.hour < 1) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final yesterday = now.subtract(const Duration(days: 1)).toIso8601String().split('T').first;
      final lastSyncedDate = prefs.getString(_yesterdaySyncDateKey);

      if (lastSyncedDate == yesterday) {
        return;
      }

      await _devChannel.invokeMethod<dynamic>('runImmediateHealthSync');
      await prefs.setString(_yesterdaySyncDateKey, yesterday);
    } on PlatformException {
      // 권한 미허용/로그인 전 상태 등에서는 다음 포그라운드 진입 시 재시도합니다.
    } catch (_) {
      // 네트워크/채널 이슈는 무시하고 다음 진입 시 재시도합니다.
    } finally {
      _isSyncingYesterday = false;
    }
  }

  Future<void> _syncTodayHealthOnForeground() async {
    if (_isSyncingToday) return;
    _isSyncingToday = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T').first;
      final lastSyncedDate = prefs.getString(_todaySyncDateKey);

      if (lastSyncedDate == today) {
        return;
      }

      await _devChannel.invokeMethod<dynamic>('runImmediateHealthSyncToday');
      await prefs.setString(_todaySyncDateKey, today);
    } on PlatformException {
      // 권한 미허용/로그인 전 상태 등에서는 다음 포그라운드 진입 시 재시도합니다.
    } catch (_) {
      // 네트워크/채널 이슈는 무시하고 다음 진입 시 재시도합니다.
    } finally {
      _isSyncingToday = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkinAI Onboarding',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF37EC13),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      ),
      themeMode: ThemeMode.light,
      home: const OnboardingScreen(),
    );
  }
}

