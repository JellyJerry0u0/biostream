import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultAsyncStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isDark;
  final VoidCallback onRetry;
  final Widget child;

  const ResultAsyncStateView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isDark,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF37EC13),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: Responsive.iconSize(context, 48),
              color: Colors.red,
            ),
            SizedBox(height: Responsive.padding(context, 16)),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                color: isDark ? Colors.white : const Color(0xFF101B0D),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.padding(context, 16)),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return child;
  }
}
