import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';
import 'facescan_screen.dart';
import 'login/login_controller.dart';
import 'profile_completion_screen.dart';
import 'signup_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/app_snackbar.dart';
import '../widgets/login/login_form_section.dart';
import '../widgets/login/login_header_section.dart';
import '../widgets/login/login_social_footer_section.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService(); // 서비스 인스턴스 추가
  late final LoginController _loginController = LoginController(
    authService: _authService,
    prefsProvider: SharedPreferences.getInstance,
    syncTokenToServer: NotificationService.instance.syncTokenToServer,
  );
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onLogin() async {
    final result = await _loginController.submitLogin(
      LoginSubmissionInput(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
    if (!mounted) return;

    if (!result.success) {
      showErrorSnackBar(context, result.message);
      return;
    }

    _navigateForResult(result.nextRoute);
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

  void _navigateForResult(LoginNextRoute route) {
    switch (route) {
      case LoginNextRoute.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      case LoginNextRoute.profileCompletion:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const ProfileCompletionScreen()),
        );
      case LoginNextRoute.faceScan:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const FaceScanScreen()),
        );
      case LoginNextRoute.none:
        break;
    }
  }

  void _onKakaoLogin() async {
    final result = await _loginController.submitKakaoLogin();
    if (!mounted) return;
    if (!result.success) {
      showErrorSnackBar(context, result.message);
      return;
    }
    _navigateForResult(result.nextRoute);
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
                  color: const Color(0xFF37EC13).withValues(alpha: 0.1),
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
                  color: const Color(0xFF37EC13).withValues(alpha: 0.05),
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
                    LoginHeaderSection(
                      isDark: isDark,
                      horizontalPadding: horizontalPadding,
                    ),
                    // Form Section
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          children: [
                            LoginFormSection(
                              isDark: isDark,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              emailFocusNode: _emailFocusNode,
                              passwordFocusNode: _passwordFocusNode,
                              obscurePassword: _obscurePassword,
                              onTogglePasswordVisibility: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onForgotPassword: _onForgotPassword,
                              onLogin: _onLogin,
                            ),
                            LoginSocialSection(
                              isDark: isDark,
                              onKakaoLogin: _onKakaoLogin,
                            ),
                          ],
                        ),
                      ),
                    ),
                    LoginFooterSection(
                      isDark: isDark,
                      horizontalPadding: horizontalPadding,
                      onSignUp: _onSignUp,
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
