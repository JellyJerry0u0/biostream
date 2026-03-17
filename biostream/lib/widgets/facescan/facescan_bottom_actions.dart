import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class FaceScanBottomActions extends StatelessWidget {
  const FaceScanBottomActions({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.onCamera,
    required this.onGallery,
  });

  final bool isDark;
  final double horizontalPadding;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: Responsive.fontSize(context, 56),
            child: ElevatedButton(
              onPressed: onCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37EC13),
                foregroundColor: const Color(0xFF101B0D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF37EC13).withValues(alpha: 0.25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera,
                    size: Responsive.iconSize(context, 20),
                  ),
                  SizedBox(width: Responsive.padding(context, 8)),
                  Text(
                    '카메라 실행하기',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 12)),
          SizedBox(
            width: double.infinity,
            height: Responsive.fontSize(context, 56),
            child: OutlinedButton(
              onPressed: onGallery,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[200] : Colors.grey[700],
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: Responsive.iconSize(context, 20),
                  ),
                  SizedBox(width: Responsive.padding(context, 8)),
                  Text(
                    '갤러리에서 선택',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: Responsive.iconSize(context, 12),
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
              SizedBox(width: Responsive.padding(context, 6)),
              Text(
                '사진은 암호화되어 안전하게 처리됩니다',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 10),
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
