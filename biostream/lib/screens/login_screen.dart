import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'facescan_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    // Navigate to FaceScanScreen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const FaceScanScreen(),
      ),
    );
  }

  void _onForgotPassword() {
    // TODO: Navigate to forgot password screen
    debugPrint('Forgot password tapped');
  }

  void _onSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SignUpScreen(),
      ),
    );
  }

  void _onKakaoLogin() {
    // TODO: Implement Kakao login
    debugPrint('Kakao login tapped');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);
    final maxWidth = Responsive.maxContentWidth(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              bottom: -128,
              right: -128,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF37EC13).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 80,
              left: -128,
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  color: const Color(0xFF37EC13).withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Main content
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: [
                    // Header Section
                    Padding(
                      padding: EdgeInsets.only(
                        top: Responsive.padding(context, 48),
                        left: horizontalPadding,
                        right: horizontalPadding,
                        bottom: Responsive.padding(context, 24),
                      ),
                      child: Column(
                        children: [
                          // Logo Icon
                          Container(
                            width: Responsive.fontSize(context, 96),
                            height: Responsive.fontSize(context, 96),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  const Color(0xFF37EC13).withOpacity(0.2),
                                  const Color(0xFF37EC13).withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Background image placeholder
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Icon(
                                    Icons.face_3,
                                    size: Responsive.fontSize(context, 48),
                                    color: const Color(0xFF37EC13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: Responsive.padding(context, 24)),
                          // Title
                          Text(
                            'AI 피부 분석',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 30),
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF101B0D),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: Responsive.padding(context, 8)),
                          // Subtitle
                          Text(
                            '미래의 나를 만나는 시간,\n지금 바로 시작하세요.',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              color: isDark ? Colors.grey[400] : Colors.grey[500],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Form Section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          children: [
                            // Email Input
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '이메일',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1F331B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[200]!,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 16),
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'example@email.com',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: Responsive.fontSize(context, 16),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: Responsive.padding(context, 20),
                                        vertical: Responsive.padding(context, 16),
                                      ),
                                      suffixIcon: Padding(
                                        padding: EdgeInsets.only(
                                          right: Responsive.padding(context, 16),
                                        ),
                                        child: Icon(
                                          Icons.mail_outline,
                                          color: Colors.grey[400],
                                          size: Responsive.iconSize(context, 20),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            // Password Input
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '비밀번호',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1F331B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[200]!,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 16),
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '••••••••',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: Responsive.fontSize(context, 16),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: Responsive.padding(context, 20),
                                        vertical: Responsive.padding(context, 16),
                                      ),
                                      suffixIcon: Padding(
                                        padding: EdgeInsets.only(
                                          right: Responsive.padding(context, 16),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: Colors.grey[400],
                                            size: Responsive.iconSize(context, 20),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 8)),
                            // Forgot Password Link
                            TextButton(
                              onPressed: _onForgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[500],
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '비밀번호를 잊으셨나요?',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 12),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 32)),
                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: Responsive.fontSize(context, 56),
                              child: ElevatedButton(
                                onPressed: _onLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF37EC13),
                                  foregroundColor: const Color(0xFF0A1F05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  elevation: 8,
                                  shadowColor:
                                      const Color(0xFF37EC13).withOpacity(0.2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '로그인',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 18),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(
                                        width: Responsive.padding(context, 8)),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: Responsive.iconSize(context, 24),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 32)),
                            // Divider with Text
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.padding(context, 12),
                                  ),
                                  child: Text(
                                    'SNS 계정으로 간편 로그인',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 12),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 32)),
                            // Kakao Login Button
                            Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _onKakaoLogin,
                                  borderRadius: BorderRadius.circular(9999),
                                  child: Container(
                                    width: Responsive.fontSize(context, 48),
                                    height: Responsive.fontSize(context, 48),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE500),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: CustomPaint(
                                        size: Size(
                                          Responsive.iconSize(context, 24),
                                          Responsive.iconSize(context, 24),
                                        ),
                                        painter: _KakaoIconPainter(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer
                    Padding(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: TextButton(
                        onPressed: _onSignUp,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.grey[400]
                              : Colors.grey[500],
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[500],
                            ),
                            children: [
                              const TextSpan(text: '계정이 없으신가요? '),
                              TextSpan(
                                text: '회원가입',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF37EC13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Kakao Icon Custom Painter
class _KakaoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF191919)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.125)
      ..cubicTo(
        size.width * 0.2917, size.height * 0.125,
        size.width * 0.1667, size.height * 0.2413,
        size.width * 0.1667, size.height * 0.385,
      )
      ..cubicTo(
        size.width * 0.1667, size.height * 0.4683,
        size.width * 0.2179, size.height * 0.5413,
        size.width * 0.2979, size.height * 0.5896,
      )
      ..lineTo(size.width * 0.2596, size.height * 0.7325)
      ..cubicTo(
        size.width * 0.2563, size.height * 0.7433,
        size.width * 0.2704, size.height * 0.7558,
        size.width * 0.2808, size.height * 0.7463,
      )
      ..lineTo(size.width * 0.4567, size.height * 0.6296)
      ..cubicTo(
        size.width * 0.465, size.height * 0.6258,
        size.width * 0.475, size.height * 0.6258,
        size.width * 0.5, size.height * 0.6296,
      )
      ..cubicTo(
        size.width * 0.7083, size.height * 0.6296,
        size.width * 0.8333, size.height * 0.5133,
        size.width * 0.8333, size.height * 0.3696,
      )
      ..cubicTo(
        size.width * 0.8333, size.height * 0.2258,
        size.width * 0.7083, size.height * 0.125,
        size.width * 0.5, size.height * 0.125,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

