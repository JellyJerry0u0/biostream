import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SignUpSmokingSection extends StatelessWidget {
  const SignUpSmokingSection({
    super.key,
    required this.isDark,
    required this.selectedSmoking,
    required this.onSelectSmoking,
  });

  final bool isDark;
  final String? selectedSmoking;
  final ValueChanged<String> onSelectSmoking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 4),
            bottom: Responsive.padding(context, 8),
          ),
          child: Text(
            '흡연 여부',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C3019) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 4),
            vertical: Responsive.padding(context, 4),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SmokingOption(
                  label: '비흡연',
                  value: 'never',
                  isSelected: selectedSmoking == 'never',
                  onTap: () => onSelectSmoking('never'),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: _SmokingOption(
                  label: '과거 흡연',
                  value: 'former',
                  isSelected: selectedSmoking == 'former',
                  onTap: () => onSelectSmoking('former'),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: _SmokingOption(
                  label: '현재 흡연',
                  value: 'current',
                  isSelected: selectedSmoking == 'current',
                  onTap: () => onSelectSmoking('current'),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmokingOption extends StatelessWidget {
  const _SmokingOption({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: Responsive.fontSize(context, 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 13),
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}
