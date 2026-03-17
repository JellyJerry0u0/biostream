import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SignUpHeader extends StatelessWidget {
  const SignUpHeader({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.onBack,
    required this.onLogin,
  });

  final bool isDark;
  final double horizontalPadding;
  final VoidCallback onBack;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              onTap: onBack,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                width: Responsive.fontSize(context, 48),
                height: Responsive.fontSize(context, 48),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
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
            onPressed: onLogin,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? const Color(0xFF8FC985) : const Color(0xFF599A4C),
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
    );
  }
}
