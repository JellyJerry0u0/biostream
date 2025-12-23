import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class SlideIndicator extends StatelessWidget {
  final int currentIndex;
  final int itemCount;

  const SlideIndicator({
    super.key,
    required this.currentIndex,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.padding(context, 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          itemCount,
          (index) => Container(
            margin: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 6),
            ),
            width: index == currentIndex 
                ? Responsive.fontSize(context, 24) 
                : Responsive.fontSize(context, 8),
            height: Responsive.fontSize(context, 8),
            decoration: BoxDecoration(
              color: index == currentIndex
                  ? const Color(0xFF37EC13)
                  : (isDark ? Colors.grey[700] : Colors.grey[300]),
              borderRadius: BorderRadius.circular(9999),
              boxShadow: index == currentIndex
                  ? [
                      BoxShadow(
                        color: const Color(0xFF37EC13).withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

