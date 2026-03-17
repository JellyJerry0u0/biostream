import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SignUpGenderPregnancySection extends StatelessWidget {
  const SignUpGenderPregnancySection({
    super.key,
    required this.isDark,
    required this.selectedGender,
    required this.isPregnant,
    required this.onSelectGender,
    required this.onSelectPregnancy,
  });

  final bool isDark;
  final String? selectedGender;
  final bool? isPregnant;
  final ValueChanged<String> onSelectGender;
  final ValueChanged<bool> onSelectPregnancy;

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
            'Gender',
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
                child: _GenderOption(
                  label: '남성',
                  isSelected: selectedGender == '남성',
                  onTap: () => onSelectGender('남성'),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: _GenderOption(
                  label: '여성',
                  isSelected: selectedGender == '여성',
                  onTap: () => onSelectGender('여성'),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: _GenderOption(
                  label: '기타',
                  isSelected: selectedGender == '기타',
                  onTap: () => onSelectGender('기타'),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        if (selectedGender == '여성') ...[
          SizedBox(height: Responsive.padding(context, 20)),
          Padding(
            padding: EdgeInsets.only(
              left: Responsive.padding(context, 4),
              bottom: Responsive.padding(context, 8),
            ),
            child: Text(
              '임신 여부',
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
                color:
                    isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF),
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
                  child: _PregnancyOption(
                    label: '임신 아님',
                    isSelected: isPregnant == false,
                    onTap: () => onSelectPregnancy(false),
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: Responsive.padding(context, 8)),
                Expanded(
                  child: _PregnancyOption(
                    label: '임신 중',
                    isSelected: isPregnant == true,
                    onTap: () => onSelectPregnancy(true),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PregnancyOption extends StatelessWidget {
  const _PregnancyOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
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
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
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

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
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
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
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
