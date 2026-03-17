import 'package:flutter/material.dart';

typedef SurveyChoiceBuilder = Widget Function({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
  required bool isDark,
});

typedef SurveyChipBuilder = Widget Function({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
  required bool isDark,
});

typedef SurveySliderBuilder = Widget Function({
  required String label,
  required double value,
  required double min,
  required double max,
  required int divisions,
  required String suffix,
  required ValueChanged<double> onChanged,
  required bool isDark,
  bool isInteger,
});

typedef SurveyTextFieldBuilder = Widget Function({
  required String label,
  required String? value,
  required String placeholder,
  required ValueChanged<String?> onChanged,
  required bool isDark,
  TextInputType keyboardType,
});

typedef SurveyNumberFieldBuilder = Widget Function({
  required String label,
  required TextEditingController controller,
  required String placeholder,
  required String suffix,
  required bool isDark,
});

typedef SurveyIntegerFieldBuilder = Widget Function({
  required String label,
  required int? value,
  required String placeholder,
  required ValueChanged<int?> onChanged,
  required bool isDark,
});
