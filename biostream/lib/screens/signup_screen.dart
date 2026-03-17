import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';
import 'facescan_screen.dart';
import 'login_screen.dart';
import 'profile_completion_screen.dart';
import 'signup/signup_controller.dart';
import '../services/auth_service.dart';
import '../widgets/signup/signup_form_fields.dart';
import '../widgets/signup/signup_gender_pregnancy_section.dart';
import '../widgets/signup/signup_header.dart';
import '../widgets/signup/signup_hero_footer.dart';
import '../widgets/signup/signup_social_section.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();
  late final SignUpController _signUpController =
      SignUpController(authService: _authService);
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _birthdateController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String? _selectedGender;
  bool? _isPregnant; // 임신 여부 (여성일 경우에만 사용)
  DateTime? _selectedDate;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  void _onLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF37EC13),
              onPrimary: Colors.black,
              surface: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C3019)
                  : Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _onStartJourney() async {
    final input = SignUpSubmissionInput(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      nickname: _nicknameController.text.trim(),
      birthdate: _birthdateController.text.trim(),
      gender: _selectedGender,
      agreeToTerms: _agreeToTerms,
      isPregnant: _isPregnant,
    );

    final result = await _signUpController.submit(input);
    if (!mounted) return;

    _showSnackBar(result.message);
    if (!result.success) {
      return;
    }

    switch (result.nextRoute) {
      case SignUpNextRoute.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case SignUpNextRoute.login:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        break;
      case SignUpNextRoute.none:
        // 성공/실패 흐름에서 이미 처리되므로 no-op
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onKakaoSignUp() async {
    _showSnackBar('카카오로 가입 중...');
    final result = await _authService.loginWithKakao();
    if (!mounted) return;
    if (result['success']) {
      final needsProfile = result['needs_profile'] == true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              needsProfile ? const ProfileCompletionScreen() : const FaceScanScreen(),
        ),
      );
    } else {
      _showSnackBar(result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);
    final maxWidth = Responsive.maxContentWidth(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                SignUpHeader(
                  isDark: isDark,
                  horizontalPadding: horizontalPadding,
                  onBack: _onBack,
                  onLogin: _onLogin,
                ),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SignUpHeroSection(isDark: isDark),
                        // Form
                        Column(
                          children: [
                            SignUpLabeledFocusTextField(
                              label: 'Email Address',
                              hintText: 'Enter your email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              isDark: isDark,
                              suffixIcon: Icons.mail_outline,
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            SignUpLabeledPasswordField(
                              label: 'Password',
                              hintText: '8+ characters',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              isDark: isDark,
                              onToggleVisibility: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            SignUpLabeledPasswordField(
                              label: 'Confirm Password',
                              hintText: 'Re-enter password',
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              isDark: isDark,
                              onToggleVisibility: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            SignUpLabeledFocusTextField(
                              label: 'Nickname',
                              hintText: 'Enter your nickname',
                              controller: _nicknameController,
                              isDark: isDark,
                              suffixIcon: Icons.person_outline,
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            SignUpBirthdateField(
                              birthdateText: _birthdateController.text,
                              isDark: isDark,
                              onTap: _selectBirthdate,
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            SignUpGenderPregnancySection(
                              isDark: isDark,
                              selectedGender: _selectedGender,
                              isPregnant: _isPregnant,
                              onSelectGender: (gender) {
                                setState(() {
                                  _selectedGender = gender;
                                  if (gender != '여성') {
                                    _isPregnant = null;
                                  }
                                });
                              },
                              onSelectPregnancy: (value) {
                                setState(() {
                                  _isPregnant = value;
                                });
                              },
                            ),
                            SizedBox(height: Responsive.padding(context, 8)),
                            SignUpTermsAgreementRow(
                              isDark: isDark,
                              agreeToTerms: _agreeToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value;
                                });
                              },
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            SignUpPrimaryCtaButton(onPressed: _onStartJourney),
                            SizedBox(height: Responsive.padding(context, 16)),
                            SignUpSocialSection(
                              isDark: isDark,
                              onKakaoTap: _onKakaoSignUp,
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.padding(context, 48)),
                        SignUpDecorativeFooter(isDark: isDark),
                        SizedBox(height: Responsive.padding(context, 32)),
                      ],
                    ),
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
