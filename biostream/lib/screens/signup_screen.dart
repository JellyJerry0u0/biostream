import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import 'facescan_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
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

  final _authService = AuthService(); // 서비스 인스턴스 추가

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
    // 1. 모든 필드 유효성 검사
    final List<String> missingFields = [];

    if (_emailController.text.trim().isEmpty) {
      missingFields.add('이메일');
    }
    if (_passwordController.text.isEmpty) {
      missingFields.add('비밀번호');
    }
    if (_confirmPasswordController.text.isEmpty) {
      missingFields.add('비밀번호 확인');
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('비밀번호가 일치하지 않습니다.');
      return;
    }
    if (_nicknameController.text.trim().isEmpty) {
      missingFields.add('닉네임');
    }
    if (_birthdateController.text.trim().isEmpty) {
      missingFields.add('생년월일');
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      missingFields.add('성별');
    }
    if (!_agreeToTerms) {
      missingFields.add('약관 동의');
    }

    // 누락된 필드가 있으면 메시지 출력
    if (missingFields.isNotEmpty) {
      final message = '다음 항목을 입력해주세요:\n${missingFields.join(', ')}';
      _showSnackBar(message);
      return;
    }

    debugPrint('[SignUpScreen] 회원가입 시작');
    debugPrint('[SignUpScreen] Email: ${_emailController.text.trim()}');
    debugPrint('[SignUpScreen] Nickname: ${_nicknameController.text.trim()}');
    debugPrint('[SignUpScreen] Birthdate: ${_birthdateController.text.trim()}');
    debugPrint('[SignUpScreen] Gender: $_selectedGender');

    // 2. 백엔드 통신 시작
    final result = await _authService.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _nicknameController.text.trim(),
      _birthdateController.text.trim(),
      _selectedGender!,
      _selectedGender == '여성' ? _isPregnant : null, // 여성일 경우에만 임신 여부 전달
    );

    debugPrint('[SignUpScreen] 회원가입 결과: $result');

    if (result['success']) {
      _showSnackBar('회원가입 성공! 로그인해주세요.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      _showSnackBar(result['message']);
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FaceScanScreen()),
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
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: Responsive.padding(context, 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onBack,
                          borderRadius: BorderRadius.circular(9999),
                          child: Container(
                            width: Responsive.fontSize(context, 48),
                            height: Responsive.fontSize(context, 48),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              size: Responsive.iconSize(context, 24),
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _onLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFF8FC985)
                              : const Color(0xFF599A4C),
                        ),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: Responsive.padding(context, 16)),
                        // Hero Text
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 30),
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF101B0D),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 8)),
                        Text(
                          'Analyze habits, see your future.',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 16),
                            color: isDark
                                ? const Color(0xFF8FC985)
                                : const Color(0xFF599A4C),
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 32)),
                        // Form
                        Column(
                          children: [
                            // Email Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Text(
                                    'Email Address',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Focus(
                                  child: Builder(
                                    builder: (context) {
                                      final hasFocus =
                                          FocusScope.of(context).focusedChild !=
                                              null;
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1C3019)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: hasFocus
                                                ? const Color(0xFF37EC13)
                                                    .withOpacity(0.5)
                                                : (isDark
                                                    ? const Color(0xFF2A4225)
                                                    : const Color(0xFFD3E7CF)),
                                            width: hasFocus ? 2 : 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 16),
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter your email',
                                            hintStyle: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFF8FC985)
                                                      .withOpacity(0.5)
                                                  : const Color(0xFF599A4C)
                                                      .withOpacity(0.6),
                                              fontSize: Responsive.fontSize(
                                                  context, 16),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: Responsive.padding(
                                                  context, 20),
                                              vertical: Responsive.padding(
                                                  context, 20),
                                            ),
                                            suffixIcon: hasFocus
                                                ? Padding(
                                                    padding: EdgeInsets.only(
                                                      right: Responsive.padding(
                                                          context, 16),
                                                    ),
                                                    child: Icon(
                                                      Icons.mail_outline,
                                                      color: const Color(
                                                          0xFF37EC13),
                                                      size: Responsive.iconSize(
                                                          context, 20),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            // Password Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Text(
                                    'Password',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1C3019)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2A4225)
                                          : const Color(0xFFD3E7CF),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 16),
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '8+ characters',
                                            hintStyle: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFF8FC985)
                                                      .withOpacity(0.5)
                                                  : const Color(0xFF599A4C)
                                                      .withOpacity(0.6),
                                              fontSize: Responsive.fontSize(
                                                  context, 16),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(
                                              left: Responsive.padding(
                                                  context, 20),
                                              right: Responsive.padding(
                                                  context, 8),
                                              top: Responsive.padding(
                                                  context, 20),
                                              bottom: Responsive.padding(
                                                  context, 20),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: Responsive.padding(
                                                  context, 16),
                                              vertical: Responsive.padding(
                                                  context, 20),
                                            ),
                                            child: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: isDark
                                                  ? const Color(0xFF8FC985)
                                                  : const Color(0xFF599A4C),
                                              size: Responsive.iconSize(
                                                  context, 24),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            // Confirm Password Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Text(
                                    'Confirm Password',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1C3019)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2A4225)
                                          : const Color(0xFFD3E7CF),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              _confirmPasswordController,
                                          obscureText: _obscureConfirmPassword,
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 16),
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Re-enter password',
                                            hintStyle: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFF8FC985)
                                                      .withOpacity(0.5)
                                                  : const Color(0xFF599A4C)
                                                      .withOpacity(0.6),
                                              fontSize: Responsive.fontSize(
                                                  context, 16),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(
                                              left: Responsive.padding(
                                                  context, 20),
                                              right: Responsive.padding(
                                                  context, 8),
                                              top: Responsive.padding(
                                                  context, 20),
                                              bottom: Responsive.padding(
                                                  context, 20),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: Responsive.padding(
                                                  context, 16),
                                              vertical: Responsive.padding(
                                                  context, 20),
                                            ),
                                            child: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: isDark
                                                  ? const Color(0xFF8FC985)
                                                  : const Color(0xFF599A4C),
                                              size: Responsive.iconSize(
                                                  context, 24),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            // Nickname Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Text(
                                    'Nickname',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Focus(
                                  child: Builder(
                                    builder: (context) {
                                      final hasFocus =
                                          FocusScope.of(context).focusedChild !=
                                              null;
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1C3019)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: hasFocus
                                                ? const Color(0xFF37EC13)
                                                    .withOpacity(0.5)
                                                : (isDark
                                                    ? const Color(0xFF2A4225)
                                                    : const Color(0xFFD3E7CF)),
                                            width: hasFocus ? 2 : 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _nicknameController,
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 16),
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter your nickname',
                                            hintStyle: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFF8FC985)
                                                      .withOpacity(0.5)
                                                  : const Color(0xFF599A4C)
                                                      .withOpacity(0.6),
                                              fontSize: Responsive.fontSize(
                                                  context, 16),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: Responsive.padding(
                                                  context, 20),
                                              vertical: Responsive.padding(
                                                  context, 20),
                                            ),
                                            suffixIcon: hasFocus
                                                ? Padding(
                                                    padding: EdgeInsets.only(
                                                      right: Responsive.padding(
                                                          context, 16),
                                                    ),
                                                    child: Icon(
                                                      Icons.person_outline,
                                                      color: const Color(
                                                          0xFF37EC13),
                                                      size: Responsive.iconSize(
                                                          context, 20),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            // Birthdate Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Text(
                                    'Birthdate',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _selectBirthdate,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C3019)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF2A4225)
                                            : const Color(0xFFD3E7CF),
                                        width: 1,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          Responsive.padding(context, 20),
                                      vertical: Responsive.padding(context, 20),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _birthdateController.text.isEmpty
                                                ? 'YYYY-MM-DD (예: 1990-01-01)'
                                                : _birthdateController.text,
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 16),
                                              color: _birthdateController
                                                      .text.isEmpty
                                                  ? (isDark
                                                      ? const Color(0xFF8FC985)
                                                          .withOpacity(0.5)
                                                      : const Color(0xFF599A4C)
                                                          .withOpacity(0.6))
                                                  : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          color: isDark
                                              ? const Color(0xFF8FC985)
                                              : const Color(0xFF599A4C),
                                          size:
                                              Responsive.iconSize(context, 20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 20)),
                            // Gender Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.padding(context, 4),
                                    bottom: Responsive.padding(context, 8),
                                  ),
                                  child: Text(
                                    'Gender',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1C3019)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2A4225)
                                          : const Color(0xFFD3E7CF),
                                      width: 1,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.padding(context, 4),
                                    vertical: Responsive.padding(context, 4),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _GenderOption(
                                          label: '남성',
                                          isSelected: _selectedGender == '남성',
                                          onTap: () {
                                            setState(() {
                                              _selectedGender = '남성';
                                              _isPregnant = null; // 남성 선택 시 임신 여부 초기화
                                            });
                                          },
                                          isDark: isDark,
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              Responsive.padding(context, 8)),
                                      Expanded(
                                        child: _GenderOption(
                                          label: '여성',
                                          isSelected: _selectedGender == '여성',
                                          onTap: () {
                                            setState(() {
                                              _selectedGender = '여성';
                                              // 여성이 아닌 다른 성별 선택 시 임신 여부 초기화
                                            });
                                          },
                                          isDark: isDark,
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              Responsive.padding(context, 8)),
                                      Expanded(
                                        child: _GenderOption(
                                          label: '기타',
                                          isSelected: _selectedGender == '기타',
                                          onTap: () {
                                            setState(() {
                                              _selectedGender = '기타';
                                              _isPregnant = null; // 기타 선택 시 임신 여부 초기화
                                            });
                                          },
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // 임신 여부 필드 (여성 선택 시에만 표시)
                            if (_selectedGender == '여성') ...[
                              SizedBox(height: Responsive.padding(context, 20)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: Responsive.padding(context, 4),
                                      bottom: Responsive.padding(context, 8),
                                    ),
                                    child: Text(
                                      '임신 여부',
                                      style: TextStyle(
                                        fontSize:
                                            Responsive.fontSize(context, 14),
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C3019)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF2A4225)
                                            : const Color(0xFFD3E7CF),
                                        width: 1,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.padding(context, 4),
                                      vertical: Responsive.padding(context, 4),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _PregnancyOption(
                                            label: '임신 아님',
                                            isSelected: _isPregnant == false,
                                            onTap: () {
                                              setState(() {
                                                _isPregnant = false;
                                              });
                                            },
                                            isDark: isDark,
                                          ),
                                        ),
                                        SizedBox(
                                            width: Responsive.padding(context, 8)),
                                        Expanded(
                                          child: _PregnancyOption(
                                            label: '임신 중',
                                            isSelected: _isPregnant == true,
                                            onTap: () {
                                              setState(() {
                                                _isPregnant = true;
                                              });
                                            },
                                            isDark: isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: Responsive.padding(context, 8)),
                            // Terms Checkbox
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: Responsive.fontSize(context, 20),
                                  height: Responsive.fontSize(context, 20),
                                  child: Checkbox(
                                    value: _agreeToTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreeToTerms = value ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFF37EC13),
                                    checkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    width: Responsive.padding(context, 12)),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize:
                                            Responsive.fontSize(context, 14),
                                        color: isDark
                                            ? const Color(0xFF8FC985)
                                            : const Color(0xFF599A4C),
                                        height: 1.4,
                                      ),
                                      children: [
                                        const TextSpan(text: 'I agree to the '),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.w500,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor:
                                                const Color(0xFF37EC13),
                                            decorationThickness: 2,
                                          ),
                                        ),
                                        const TextSpan(text: ' and '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.w500,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor:
                                                const Color(0xFF37EC13),
                                            decorationThickness: 2,
                                          ),
                                        ),
                                        const TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            // CTA Button
                            SizedBox(
                              width: double.infinity,
                              height: Responsive.fontSize(context, 56),
                              child: ElevatedButton(
                                onPressed: _onStartJourney,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF37EC13),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  elevation: 0,
                                  shadowColor:
                                      const Color(0xFF37EC13).withOpacity(0.3),
                                ),
                                child: Text(
                                  'Start Your Journey',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 18),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? const Color(0xFF2A4225)
                                        : const Color(0xFFD3E7CF),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.padding(context, 16),
                                  ),
                                  child: Text(
                                    'Or continue with',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 12),
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFF8FC985)
                                          : const Color(0xFF599A4C),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? const Color(0xFF2A4225)
                                        : const Color(0xFFD3E7CF),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 24)),
                            // Social Sign Up - Only Kakao
                            Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _onKakaoSignUp,
                                  borderRadius: BorderRadius.circular(9999),
                                  child: Container(
                                    width: Responsive.fontSize(context, 56),
                                    height: Responsive.fontSize(context, 56),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE500),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF2A4225)
                                            : const Color(0xFFD3E7CF),
                                        width: 1,
                                      ),
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
                        SizedBox(height: Responsive.padding(context, 48)),
                        // Decorative Footer
                        Center(
                          child: Opacity(
                            opacity: isDark ? 0.2 : 0.3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.face,
                                  color: const Color(0xFF37EC13),
                                  size: Responsive.iconSize(context, 24),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Text(
                                  'Powered by Skin AI',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    color: isDark
                                        ? const Color(0xFF8FC985)
                                        : const Color(0xFF599A4C),
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

// Kakao Icon Custom Painter
class _KakaoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3C1E1E)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.125)
      ..cubicTo(
        size.width * 0.2917,
        size.height * 0.125,
        size.width * 0.1667,
        size.height * 0.2413,
        size.width * 0.1667,
        size.height * 0.385,
      )
      ..cubicTo(
        size.width * 0.1667,
        size.height * 0.4683,
        size.width * 0.2179,
        size.height * 0.5413,
        size.width * 0.2979,
        size.height * 0.5896,
      )
      ..lineTo(size.width * 0.2596, size.height * 0.7325)
      ..cubicTo(
        size.width * 0.2563,
        size.height * 0.7433,
        size.width * 0.2704,
        size.height * 0.7558,
        size.width * 0.2808,
        size.height * 0.7463,
      )
      ..lineTo(size.width * 0.4567, size.height * 0.6296)
      ..cubicTo(
        size.width * 0.465,
        size.height * 0.6258,
        size.width * 0.475,
        size.height * 0.6258,
        size.width * 0.5,
        size.height * 0.6296,
      )
      ..cubicTo(
        size.width * 0.7083,
        size.height * 0.6296,
        size.width * 0.8333,
        size.height * 0.5133,
        size.width * 0.8333,
        size.height * 0.3696,
      )
      ..cubicTo(
        size.width * 0.8333,
        size.height * 0.2258,
        size.width * 0.7083,
        size.height * 0.125,
        size.width * 0.5,
        size.height * 0.125,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pregnancy Option Widget
class _PregnancyOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _PregnancyOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: Responsive.fontSize(context, 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

// Gender Option Widget
class _GenderOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _GenderOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: Responsive.fontSize(context, 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}
