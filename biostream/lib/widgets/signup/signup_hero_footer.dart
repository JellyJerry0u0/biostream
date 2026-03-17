import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SignUpHeroSection extends StatelessWidget {
  const SignUpHeroSection({
    super.key,
    required this.isDark,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: Responsive.padding(context, 16)),
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 30),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF101B0D),
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 8)),
        Text(
          'Analyze habits, see your future.',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: isDark ? const Color(0xFF8FC985) : const Color(0xFF599A4C),
          ),
        ),
        SizedBox(height: Responsive.padding(context, 32)),
      ],
    );
  }
}

class SignUpPrimaryCtaButton extends StatelessWidget {
  const SignUpPrimaryCtaButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: Responsive.fontSize(context, 56),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF37EC13),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          elevation: 0,
          shadowColor: const Color(0xFF37EC13).withValues(alpha: 0.3),
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
    );
  }
}

class SignUpDecorativeFooter extends StatelessWidget {
  const SignUpDecorativeFooter({
    super.key,
    required this.isDark,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
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
                color:
                    isDark ? const Color(0xFF8FC985) : const Color(0xFF599A4C),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
