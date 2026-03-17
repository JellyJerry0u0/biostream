import 'package:flutter/material.dart';

class MyInfoStatsPanel extends StatelessWidget {
  const MyInfoStatsPanel({super.key});

  static const Color _primary = Color(0xFF2BEE75);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.14)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _StatItem(label: '리포트', value: '12', showDivider: true),
          ),
          Expanded(
            child: _StatItem(label: '미래 얼굴', value: '8', showDivider: true),
          ),
          Expanded(
            child: _StatItem(label: '연속 출석', value: '5일'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.showDivider = false,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF2BEE75);

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7A8380),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            width: 1,
            height: 34,
            color: primary.withValues(alpha: 0.18),
          ),
      ],
    );
  }
}
