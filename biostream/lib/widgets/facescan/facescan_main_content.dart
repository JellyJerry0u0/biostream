import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../face_scanner_widget.dart';

class FaceScanMainContent extends StatelessWidget {
  const FaceScanMainContent({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.scanController,
  });

  final bool isDark;
  final double horizontalPadding;
  final AnimationController? scanController;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          children: [
            SizedBox(height: Responsive.padding(context, 8)),
            Column(
              children: [
                Text(
                  '얼굴 스캔 시작',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 28),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Responsive.padding(context, 12)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 16),
                  ),
                  child: Text(
                    'AI가 현재 피부 상태를 분석하고\n미래의 얼굴 변화를 예측합니다.',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.padding(context, 40)),
            scanController != null
                ? FaceScannerWidget(
                    scanController: scanController!,
                    isDark: isDark,
                  )
                : const SizedBox.shrink(),
            SizedBox(height: Responsive.padding(context, 40)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '촬영 가이드',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 12),
                        vertical: Responsive.padding(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF37EC13).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        '정확도 98% 향상',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF37EC13),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.padding(context, 16)),
                Row(
                  children: [
                    Expanded(
                      child: _GuidelineCard(
                        icon: Icons.wb_sunny,
                        title: '밝은 조명',
                        description: '얼굴 전체가 잘 보이도록',
                        isGood: true,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: Responsive.padding(context, 12)),
                    Expanded(
                      child: _GuidelineCard(
                        icon: Icons.face_retouching_off,
                        title: '안경/마스크',
                        description: '착용하지 않은 상태',
                        isGood: false,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.padding(context, 16)),
                Container(
                  padding: EdgeInsets.all(Responsive.padding(context, 16)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: Responsive.iconSize(context, 20),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      SizedBox(width: Responsive.padding(context, 12)),
                      Expanded(
                        child: Text(
                          '정면을 바라보고 무표정으로 촬영해주세요. 화장이 진하거나 머리카락이 얼굴을 가리면 분석이 어려울 수 있습니다.',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 12),
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.padding(context, 120)),
          ],
        ),
      ),
    );
  }
}

class _GuidelineCard extends StatelessWidget {
  const _GuidelineCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGood,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGood;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2E18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: Responsive.padding(context, 12),
            right: Responsive.padding(context, 12),
            child: Icon(
              isGood ? Icons.check_circle : Icons.cancel,
              color: isGood
                  ? const Color(0xFF37EC13)
                  : (isDark ? Colors.grey[400] : Colors.grey[400]),
              size: Responsive.iconSize(context, 18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: Responsive.fontSize(context, 40),
                height: Responsive.fontSize(context, 40),
                decoration: BoxDecoration(
                  color: isGood
                      ? const Color(0xFF37EC13).withValues(alpha: 0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGood
                      ? const Color(0xFF37EC13)
                      : (isDark ? Colors.grey[400] : Colors.grey[500]),
                  size: Responsive.iconSize(context, 20),
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 4)),
              Text(
                description,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
