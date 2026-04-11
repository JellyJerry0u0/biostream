import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/responsive.dart';

class SurveyFormFields {
  static Widget chip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 24),
          vertical: Responsive.padding(context, 14),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF37EC13)
              : (isDark ? const Color(0xFF1A2C16) : Colors.white),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey[300]!),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black87),
          ),
        ),
      ),
    );
  }

  static Widget sliderField({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
    required bool isDark,
    bool isInteger = false,
  }) {
    final displayValue = isInteger ? value.toInt() : value;
    final displayText = isInteger
        ? '$displayValue$suffix'
        : '${displayValue.toStringAsFixed(1)}$suffix';

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: Responsive.padding(context, 40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            displayText,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF37EC13),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF37EC13),
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFD3E7CF),
              thumbColor: const Color(0xFF37EC13),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: Responsive.fontSize(context, 10),
              ),
            ),
            child: Slider(
              value: isInteger ? value.roundToDouble() : value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (newValue) {
                if (isInteger) {
                  onChanged(newValue.roundToDouble());
                } else {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget choiceButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 24),
          vertical: Responsive.padding(context, 14),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey[300]!),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black87),
          ),
        ),
      ),
    );
  }

  static Widget textField({
    required String label,
    required String? value,
    required String placeholder,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SurveyTextFieldBuilder(
      label: label,
      value: value,
      placeholder: placeholder,
      onChanged: onChanged,
      isDark: isDark,
      keyboardType: keyboardType,
    );
  }

  static Widget integerTextField({
    required String label,
    required int? value,
    required String placeholder,
    required ValueChanged<int?> onChanged,
    required bool isDark,
  }) {
    return SurveyIntegerTextFieldBuilder(
      label: label,
      value: value,
      placeholder: placeholder,
      onChanged: onChanged,
      isDark: isDark,
    );
  }

  static Widget numberTextField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required String suffix,
    required bool isDark,
  }) {
    if (label.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
              ),
            ),
          ),
          SizedBox(width: Responsive.padding(context, 8)),
          Text(
            suffix,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF132210)
                      : const Color(0xFFF6F8F6),
                  contentPadding:
                      EdgeInsets.all(Responsive.padding(context, 16)),
                ),
              ),
            ),
            SizedBox(width: Responsive.padding(context, 8)),
            Text(
              suffix,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SurveyIntegerTextFieldBuilder extends StatefulWidget {
  const SurveyIntegerTextFieldBuilder({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    required this.isDark,
  });

  final String label;
  final int? value;
  final String placeholder;
  final ValueChanged<int?> onChanged;
  final bool isDark;

  @override
  State<SurveyIntegerTextFieldBuilder> createState() =>
      _SurveyIntegerTextFieldBuilderState();
}

class _SurveyIntegerTextFieldBuilderState
    extends State<SurveyIntegerTextFieldBuilder> {
  late TextEditingController _controller;

  void _handleControllerChanged() {
    final text = _controller.text;
    if (text.isEmpty) {
      widget.onChanged(null);
    } else {
      final value = int.tryParse(text);
      widget.onChanged(value);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SurveyIntegerTextFieldBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        widget.value?.toString() != _controller.text) {
      // `text =`는 리스너를 호출해 상위 setState가 빌드 중에 돌 수 있음 → 잠시 분리
      _controller.removeListener(_handleControllerChanged);
      _controller.text = widget.value?.toString() ?? '';
      _controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label.isEmpty) {
      return TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor:
              widget.isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
          contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: widget.isDark
                ? const Color(0xFF132210)
                : const Color(0xFFF6F8F6),
            contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
          ),
        ),
      ],
    );
  }
}

class SurveyTextFieldBuilder extends StatefulWidget {
  const SurveyTextFieldBuilder({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    required this.isDark,
    this.keyboardType = TextInputType.text,
  });

  final String label;
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;
  final bool isDark;
  final TextInputType keyboardType;

  @override
  State<SurveyTextFieldBuilder> createState() => _SurveyTextFieldBuilderState();
}

class _SurveyTextFieldBuilderState extends State<SurveyTextFieldBuilder> {
  late TextEditingController _controller;

  void _handleControllerChanged() {
    widget.onChanged(_controller.text.isEmpty ? null : _controller.text);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SurveyTextFieldBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.removeListener(_handleControllerChanged);
      _controller.text = widget.value ?? '';
      _controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label.isEmpty) {
      return TextField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor:
              widget.isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
          contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        TextField(
          controller: _controller,
          keyboardType: widget.keyboardType,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: widget.isDark
                ? const Color(0xFF132210)
                : const Color(0xFFF6F8F6),
            contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
          ),
        ),
      ],
    );
  }
}
