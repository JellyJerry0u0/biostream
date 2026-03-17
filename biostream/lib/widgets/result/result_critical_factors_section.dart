import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultCriticalFactorsSection extends StatelessWidget {
  final bool isDark;
  final String collagenLabel;
  final double collagenScore;
  final Color collagenColor;
  final String uvLabel;
  final double uvScore;
  final Color uvColor;

  const ResultCriticalFactorsSection({
    super.key,
    required this.isDark,
    required this.collagenLabel,
    required this.collagenScore,
    required this.collagenColor,
    required this.uvLabel,
    required this.uvScore,
    required this.uvColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C17) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Critical Factors',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 8),
                  vertical: Responsive.padding(context, 4),
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Impact Score',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _impactRow(
            context: context,
            title: 'Collagen Preservation',
            label: collagenLabel,
            score: collagenScore,
            color: collagenColor,
            showGlow: true,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _impactRow(
            context: context,
            title: 'UV Damage Control',
            label: uvLabel,
            score: uvScore,
            color: uvColor,
            showGlow: false,
          ),
        ],
      ),
    );
  }

  Widget _impactRow({
    required BuildContext context,
    required String title,
    required String label,
    required double score,
    required Color color,
    required bool showGlow,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.padding(context, 6)),
        Container(
          height: Responsive.fontSize(context, 8),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: score.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: showGlow
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
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
