import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class FaceScanHeader extends StatelessWidget {
  const FaceScanHeader({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onSkip,
  });

  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 20),
        vertical: Responsive.padding(context, 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: isDark ? const Color(0xFF1C2E18) : Colors.white,
            borderRadius: BorderRadius.circular(9999),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                padding: EdgeInsets.all(Responsive.padding(context, 8)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                  size: Responsive.iconSize(context, 20),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: Responsive.fontSize(context, 32),
                height: Responsive.fontSize(context, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF37EC13),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              SizedBox(width: Responsive.padding(context, 6)),
              Container(
                width: Responsive.fontSize(context, 8),
                height: Responsive.fontSize(context, 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              SizedBox(width: Responsive.padding(context, 6)),
              Container(
                width: Responsive.fontSize(context, 8),
                height: Responsive.fontSize(context, 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
              padding: EdgeInsets.all(Responsive.padding(context, 8)),
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
    );
  }
}
