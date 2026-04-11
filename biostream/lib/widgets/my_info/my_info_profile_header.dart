import 'package:flutter/material.dart';

class MyInfoProfileHeader extends StatelessWidget {
  const MyInfoProfileHeader({
    super.key,
    required this.nickname,
    required this.email,
  });

  final String nickname;
  final String email;

  static const Color _primary = Color(0xFF2BEE75);

  @override
  Widget build(BuildContext context) {
    final emailLine = email.trim().isEmpty ? '—' : email.trim();

    return Center(
      child: Column(
        children: [
          Text(
            '$nickname 님',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF102217),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emailLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primary.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
