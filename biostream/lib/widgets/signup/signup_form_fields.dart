import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SignUpLabeledFocusTextField extends StatelessWidget {
  const SignUpLabeledFocusTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.isDark,
    this.keyboardType,
    this.suffixIcon,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool isDark;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 4),
            bottom: Responsive.padding(context, 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Focus(
          child: Builder(
            builder: (context) {
              final hasFocus = FocusScope.of(context).focusedChild != null;
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C3019) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasFocus
                        ? const Color(0xFF37EC13).withValues(alpha: 0.5)
                        : (isDark
                            ? const Color(0xFF2A4225)
                            : const Color(0xFFD3E7CF)),
                    width: hasFocus ? 2 : 1,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF8FC985).withValues(alpha: 0.5)
                          : const Color(0xFF599A4C).withValues(alpha: 0.6),
                      fontSize: Responsive.fontSize(context, 16),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 20),
                      vertical: Responsive.padding(context, 20),
                    ),
                    suffixIcon: hasFocus && suffixIcon != null
                        ? Padding(
                            padding: EdgeInsets.only(
                              right: Responsive.padding(context, 16),
                            ),
                            child: Icon(
                              suffixIcon,
                              color: const Color(0xFF37EC13),
                              size: Responsive.iconSize(context, 20),
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
    );
  }
}

class SignUpLabeledPasswordField extends StatelessWidget {
  const SignUpLabeledPasswordField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.isDark,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool isDark;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 4),
            bottom: Responsive.padding(context, 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C3019) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF8FC985).withValues(alpha: 0.5)
                          : const Color(0xFF599A4C).withValues(alpha: 0.6),
                      fontSize: Responsive.fontSize(context, 16),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(
                      left: Responsive.padding(context, 20),
                      right: Responsive.padding(context, 8),
                      top: Responsive.padding(context, 20),
                      bottom: Responsive.padding(context, 20),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleVisibility,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 16),
                      vertical: Responsive.padding(context, 20),
                    ),
                    child: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: isDark
                          ? const Color(0xFF8FC985)
                          : const Color(0xFF599A4C),
                      size: Responsive.iconSize(context, 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SignUpBirthdateField extends StatelessWidget {
  const SignUpBirthdateField({
    super.key,
    required this.birthdateText,
    required this.isDark,
    required this.onTap,
  });

  final String birthdateText;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C3019) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF),
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 20),
              vertical: Responsive.padding(context, 20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    birthdateText.isEmpty
                        ? 'YYYY-MM-DD (예: 1990-01-01)'
                        : birthdateText,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      color: birthdateText.isEmpty
                          ? (isDark
                              ? const Color(0xFF8FC985).withValues(alpha: 0.5)
                              : const Color(0xFF599A4C).withValues(alpha: 0.6))
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  color: isDark
                      ? const Color(0xFF8FC985)
                      : const Color(0xFF599A4C),
                  size: Responsive.iconSize(context, 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SignUpTermsAgreementRow extends StatelessWidget {
  const SignUpTermsAgreementRow({
    super.key,
    required this.isDark,
    required this.agreeToTerms,
    required this.onChanged,
  });

  final bool isDark;
  final bool agreeToTerms;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: Responsive.fontSize(context, 20),
          height: Responsive.fontSize(context, 20),
          child: Checkbox(
            value: agreeToTerms,
            onChanged: (value) => onChanged(value ?? false),
            activeColor: const Color(0xFF37EC13),
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(width: Responsive.padding(context, 12)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color:
                    isDark ? const Color(0xFF8FC985) : const Color(0xFF599A4C),
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF37EC13),
                    decorationThickness: 2,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF37EC13),
                    decorationThickness: 2,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
