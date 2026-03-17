import 'package:flutter/material.dart';

class FutureFaceScenarioCards extends StatelessWidget {
  const FutureFaceScenarioCards({
    super.key,
    required this.isDark,
    required this.textColor,
    required this.primaryColor,
    required this.wellManaged,
    required this.simulationPromptText,
    required this.onScenarioChanged,
  });

  final bool isDark;
  final Color textColor;
  final Color primaryColor;
  final bool wellManaged;
  final String simulationPromptText;
  final ValueChanged<bool> onScenarioChanged;

  @override
  Widget build(BuildContext context) {
    final panelBg =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _scenarioButton(
                  icon: Icons.verified_user,
                  label: '관리 잘했을 때',
                  active: wellManaged,
                  onTap: () => onScenarioChanged(true),
                ),
              ),
              Expanded(
                child: _scenarioButton(
                  icon: Icons.warning_amber,
                  label: '관리가 부족할 때',
                  active: !wellManaged,
                  onTap: () => onScenarioChanged(false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _analysisCard(
                bgColor: panelBg,
                title: '피부 탄력 유지',
                value: wellManaged ? '82%' : '61%',
                valueColor: primaryColor,
                trailing: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analysisCard(
                bgColor: panelBg,
                title: '예상 주름 깊이',
                value: wellManaged ? '-12%' : '+18%',
                valueColor: wellManaged ? textColor : Colors.orangeAccent,
                trailing: wellManaged ? Icons.remove : Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (simulationPromptText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.14)),
            ),
            child: Text(
              simulationPromptText,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        if (simulationPromptText.isNotEmpty) const SizedBox(height: 20),
      ],
    );
  }

  Widget _scenarioButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final textColor = active ? const Color(0xFF102217) : Colors.white70;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: active ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisCard({
    required Color bgColor,
    required String title,
    required String value,
    required Color valueColor,
    required IconData trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(trailing, color: valueColor, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
