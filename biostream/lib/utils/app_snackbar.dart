import 'package:flutter/material.dart';

/// 성공·완료 안내는 스낵바로 띄우지 않습니다. 오류·검증 실패만 표시할 때 사용하세요.
void showErrorSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
