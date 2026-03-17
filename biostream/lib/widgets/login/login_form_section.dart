import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class LoginFormSection extends StatelessWidget {
  const LoginFormSection({
    super.key,
    required this.isDark,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
    required this.onLogin,
  });

  final bool isDark;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _labeledTextField(
          context: context,
          label: '이메일',
          child: TextField(
            controller: emailController,
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
        SizedBox(height: Responsive.padding(context, 20)),
        _labeledTextField(
          context: context,
          label: '비밀번호',
          child: TextField(
            controller: passwordController,
            obscureText: obscurePassword,
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
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[400],
                    size: Responsive.iconSize(context, 20),
                  ),
                  onPressed: onTogglePasswordVisibility,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: Responsive.padding(context, 8)),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.grey[400] : Colors.grey[500],
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
        SizedBox(
          width: double.infinity,
          height: Responsive.fontSize(context, 56),
          child: ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37EC13),
              foregroundColor: const Color(0xFF0A1F05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF37EC13).withValues(alpha: 0.2),
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
                SizedBox(width: Responsive.padding(context, 8)),
                Icon(
                  Icons.arrow_forward,
                  size: Responsive.iconSize(context, 24),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _labeledTextField({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: Responsive.padding(context, 8)),
          child: Center(
            child: Text(
              label,
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
            color: isDark ? const Color(0xFF1F331B) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}
