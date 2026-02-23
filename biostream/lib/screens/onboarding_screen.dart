import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/onboarding_slide.dart';
import '../widgets/slide_indicator.dart';
import '../utils/responsive.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import '../services/api_config.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const MethodChannel _devChannel = MethodChannel('com.example.biostream/dev');
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _currentApiOrigin;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _onGetStarted() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignUpScreen(),
      ),
    );
  }

  void _onLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  Future<void> _openDevSettingsDialog() async {
    final initial = await ApiConfig.getBaseOrigin();
    final controller = TextEditingController(text: initial);
    setState(() {
      _currentApiOrigin = initial;
    });

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('개발자 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'API Base URL',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.x.x:8080',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '현재: ${_currentApiOrigin ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ApiConfig.resetToDefault();
                final refreshed = await ApiConfig.getBaseOrigin();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentApiOrigin = refreshed;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('기본값으로 리셋되었습니다.')),
                  );
                }
              },
              child: const Text('기본값'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () async {
                await ApiConfig.setBaseOrigin(controller.text.trim());
                final refreshed = await ApiConfig.getBaseOrigin();
                if (!context.mounted) return;
                setState(() {
                  _currentApiOrigin = refreshed;
                });

                try {
                  await _devChannel.invokeMethod('enqueueOneTimeHealthSync');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('동기화 테스트 작업을 큐에 등록했습니다.')),
                    );
                  }
                } on PlatformException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('동기화 테스트 실패: ${e.message ?? e.code}')),
                    );
                  }
                } on MissingPluginException {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('현재 플랫폼에서는 동기화 테스트를 지원하지 않습니다.')),
                    );
                  }
                }
              },
              child: const Text('동기화 테스트'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiConfig.setBaseOrigin(controller.text.trim());
                final refreshed = await ApiConfig.getBaseOrigin();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentApiOrigin = refreshed;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API URL이 저장되었습니다.')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);
    final verticalPadding = Responsive.padding(context, 24);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: Column(
              children: [
                // Top Bar / Logo
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.face_retouching_natural,
                            color: const Color(0xFF37EC13),
                            size: Responsive.iconSize(context, 24),
                          ),
                          SizedBox(width: Responsive.padding(context, 6)),
                          Text(
                            'BioStream',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 18),
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _openDevSettingsDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                            child: Text(
                              '개발자설정',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _onGetStarted,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 14),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            
            // Carousel Section
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return OnboardingSlide(slideIndex: index);
                },
              ),
            ),
            
            // Dots Indicator
            SlideIndicator(
              currentIndex: _currentPage,
              itemCount: 3,
            ),
            
                // Footer / Actions
                Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    children: [
                      // Main CTA
                      SizedBox(
                        width: double.infinity,
                        height: Responsive.fontSize(context, 56),
                        child: ElevatedButton(
                          onPressed: _onGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF37EC13),
                            foregroundColor: const Color(0xFF101B0D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFF37EC13).withOpacity(0.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '3초만에 시작하기',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 16),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: Responsive.padding(context, 8)),
                              Icon(
                                Icons.arrow_forward,
                                size: Responsive.iconSize(context, 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: Responsive.padding(context, 12)),
                      
                      // Secondary Action
                      TextButton(
                        onPressed: _onLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey[300] : Colors.grey[600],
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.padding(context, 10),
                          ),
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[300] : Colors.grey[600],
                            ),
                            children: [
                              const TextSpan(text: '이미 계정이 있으신가요? '),
                              TextSpan(
                                text: '로그인',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: const Color(0xFF37EC13),
                                  decorationThickness: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: Responsive.padding(context, 8)),
                      
                      // Privacy Text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_open,
                            size: Responsive.iconSize(context, 12),
                            color: isDark 
                                ? Colors.green[500] 
                                : Colors.green[700],
                          ),
                          SizedBox(width: Responsive.padding(context, 6)),
                          Flexible(
                            child: Text(
                              '당신의 얼굴 데이터는 안전하게 암호화됩니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 11),
                                color: isDark 
                                    ? Colors.grey[500] 
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

