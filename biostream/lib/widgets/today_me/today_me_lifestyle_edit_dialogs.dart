import 'package:flutter/material.dart';

import '../survey/common/survey_form_fields.dart';

/// 오늘의 나 생활 편집 — 흰 카드 · 메인 그린 액센트
class TodayMeLifestyleEditStyle {
  TodayMeLifestyleEditStyle._();

  static const Color accent = Color(0xFF2BEE75);
  static const Color titleColor = Color(0xFF1A1F1C);
  static const Color muted = Color(0xFF6B7570);
  static const Color border = Color(0xFFE8F0EB);
  static const Color chipFill = Color(0xFFF3F7F4);
}

Widget _sheetButton({
  required String label,
  required VoidCallback? onPressed,
  bool primary = false,
}) {
  if (primary) {
    return Expanded(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: TodayMeLifestyleEditStyle.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
  return Expanded(
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: TodayMeLifestyleEditStyle.muted,
        side: const BorderSide(color: TodayMeLifestyleEditStyle.border, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    ),
  );
}

/// 흡연/금연, 음주/금주, 선크림 등 2지선다
Future<String?> showTodayMeBinaryStringDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<({String label, String value})> options,
  String? selectedValue,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      String? sel = selectedValue;
      return StatefulBuilder(
        builder: (context, setSt) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: TodayMeLifestyleEditStyle.titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: TodayMeLifestyleEditStyle.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _BinaryChip(
                              label: options[i].label,
                              selected: sel == options[i].value,
                              onTap: () => setSt(() => sel = options[i].value),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _sheetButton(
                          label: '취소',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 10),
                        _sheetButton(
                          label: '완료',
                          primary: true,
                          onPressed: sel == null ? null : () => Navigator.pop(ctx, sel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _BinaryChip extends StatelessWidget {
  const _BinaryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? TodayMeLifestyleEditStyle.accent.withValues(alpha: 0.14) : TodayMeLifestyleEditStyle.chipFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? TodayMeLifestyleEditStyle.accent : TodayMeLifestyleEditStyle.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? const Color(0xFF0D3D22) : TodayMeLifestyleEditStyle.titleColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showTodayMeSunscreenBinaryDialog({
  required BuildContext context,
  bool? initialApplied,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      bool? sel = initialApplied;
      return StatefulBuilder(
        builder: (context, setSt) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '선크림',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: TodayMeLifestyleEditStyle.titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '오늘 선크림을 도포하셨나요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: TodayMeLifestyleEditStyle.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _BinaryChip(
                            label: 'O',
                            selected: sel == true,
                            onTap: () => setSt(() => sel = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BinaryChip(
                            label: 'X',
                            selected: sel == false,
                            onTap: () => setSt(() => sel = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _sheetButton(label: '취소', onPressed: () => Navigator.pop(ctx)),
                        const SizedBox(width: 10),
                        _sheetButton(
                          label: '완료',
                          primary: true,
                          onPressed: sel == null ? null : () => Navigator.pop(ctx, sel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showTodayMeUvDialog({
  required BuildContext context,
  String? selectedKey,
}) {
  const options = ['<30m', '30~60', '1~2h', '>2h'];
  const labels = ['30분 미만', '30분~1시간', '1~2시간', '2시간 이상'];
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      String? sel = selectedKey;
      return StatefulBuilder(
        builder: (context, setSt) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '코어시간(10~16시) 외출',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: TodayMeLifestyleEditStyle.titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(options.length, (i) {
                      final on = sel == options[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setSt(() => sel = options[i]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: on ? TodayMeLifestyleEditStyle.accent.withValues(alpha: 0.12) : TodayMeLifestyleEditStyle.chipFill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: on ? TodayMeLifestyleEditStyle.accent : TodayMeLifestyleEditStyle.border,
                                  width: on ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      labels[i],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                                        color: TodayMeLifestyleEditStyle.titleColor,
                                      ),
                                    ),
                                  ),
                                  if (on)
                                    const Icon(Icons.check_circle_rounded, color: TodayMeLifestyleEditStyle.accent, size: 22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _sheetButton(label: '취소', onPressed: () => Navigator.pop(ctx)),
                        const SizedBox(width: 10),
                        _sheetButton(
                          label: '완료',
                          primary: true,
                          onPressed: sel == null ? null : () => Navigator.pop(ctx, sel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// 스트레스·수면의 질 (0~10 슬라이더, 설문과 동일 패턴)
Future<double?> showTodayMeScoreSliderDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required double initial,
}) {
  return showDialog<double>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      var v = initial.clamp(0.0, 10.0);
      return StatefulBuilder(
        builder: (context, setSt) {
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final maxH = MediaQuery.sizeOf(context).height * 0.88 - viewInsets.vertical;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.fromLTRB(
              22,
              24,
              22,
              24 + viewInsets.bottom * 0.5,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH.clamp(200.0, 560.0)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 26, 12, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: TodayMeLifestyleEditStyle.titleColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: TodayMeLifestyleEditStyle.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SurveyFormFields.sliderField(
                        context: context,
                        label: '',
                        value: v,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        suffix: '점',
                        isInteger: true,
                        isDark: false,
                        onChanged: (nv) => setSt(() => v = nv),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            _sheetButton(label: '취소', onPressed: () => Navigator.pop(ctx)),
                            const SizedBox(width: 10),
                            _sheetButton(
                              label: '완료',
                              primary: true,
                              onPressed: () => Navigator.pop(ctx, v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// 유산소·근력 0~6 휠
Future<({int aerobic, int resistance})?> showTodayMeExerciseWheelsDialog({
  required BuildContext context,
  int initialAerobic = 0,
  int initialResistance = 0,
}) {
  return showDialog<({int aerobic, int resistance})>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      var aer = initialAerobic.clamp(0, 6);
      var res = initialResistance.clamp(0, 6);
      return StatefulBuilder(
        builder: (context, setSt) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '운동 (30분 이상 세션)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: TodayMeLifestyleEditStyle.titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '스크롤하여 횟수를 맞춰 주세요 (0~6회)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: TodayMeLifestyleEditStyle.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _CountWheel(
                              label: '유산소',
                              value: aer,
                              onChanged: (n) => setSt(() => aer = n),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _CountWheel(
                              label: '근력',
                              value: res,
                              onChanged: (n) => setSt(() => res = n),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _sheetButton(label: '취소', onPressed: () => Navigator.pop(ctx)),
                        const SizedBox(width: 10),
                        _sheetButton(
                          label: '완료',
                          primary: true,
                          onPressed: () => Navigator.pop(ctx, (aerobic: aer, resistance: res)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _CountWheel extends StatefulWidget {
  const _CountWheel({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_CountWheel> createState() => _CountWheelState();
}

class _CountWheelState extends State<_CountWheel> {
  late FixedExtentScrollController _ctrl;
  late int _selected;

  static const double _itemExtent = 44;

  @override
  void initState() {
    super.initState();
    _selected = widget.value.clamp(0, 6);
    _ctrl = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void didUpdateWidget(covariant _CountWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selected = widget.value.clamp(0, 6);
      if (_ctrl.hasClients) {
        _ctrl.jumpToItem(_selected);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: TodayMeLifestyleEditStyle.muted,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: _itemExtent,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: TodayMeLifestyleEditStyle.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TodayMeLifestyleEditStyle.accent.withValues(alpha: 0.35)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _ctrl,
                itemExtent: _itemExtent,
                perspective: 0.003,
                diameterRatio: 1.35,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  final n = i.clamp(0, 6);
                  setState(() => _selected = n);
                  widget.onChanged(n);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 7,
                  builder: (context, index) {
                    final sel = index == _selected;
                    return Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: sel ? 26 : 20,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          color: sel ? TodayMeLifestyleEditStyle.titleColor : TodayMeLifestyleEditStyle.muted,
                          height: 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 숫자·텍스트 입력 (체중·키·수면 시간 등)
Future<String?> showTodayMeTextFieldDialog({
  required BuildContext context,
  required String title,
  String? hint,
  String initialText = '',
  TextInputType keyboardType = TextInputType.text,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _TodayMeTextFieldDialog(
      title: title,
      hint: hint,
      initialText: initialText,
      keyboardType: keyboardType,
    ),
  );
}

class _TodayMeTextFieldDialog extends StatefulWidget {
  const _TodayMeTextFieldDialog({
    required this.title,
    this.hint,
    required this.initialText,
    required this.keyboardType,
  });

  final String title;
  final String? hint;
  final String initialText;
  final TextInputType keyboardType;

  @override
  State<_TodayMeTextFieldDialog> createState() => _TodayMeTextFieldDialogState();
}

class _TodayMeTextFieldDialogState extends State<_TodayMeTextFieldDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.88 - viewInsets.vertical;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(
        22,
        24,
        22,
        24 + viewInsets.bottom * 0.5,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH.clamp(200.0, 560.0)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: TodayMeLifestyleEditStyle.titleColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _controller,
                  keyboardType: widget.keyboardType,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: TodayMeLifestyleEditStyle.titleColor,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: TodayMeLifestyleEditStyle.chipFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _sheetButton(label: '취소', onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    _sheetButton(
                      label: '완료',
                      primary: true,
                      onPressed: () => Navigator.pop(context, _controller.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 파싱 헬퍼 (표시 문자열 → 편집 초기값) ─────────────────────────────

double parseTodayMeStressInitial(String value) {
  if (value == '-' || value.isEmpty) return 5;
  final m = RegExp(r'^(\d+)').firstMatch(value.trim());
  if (m != null) return double.tryParse(m.group(1)!) ?? 5;
  return 5;
}

double parseTodayMeSleepQualityInitial(String value) {
  return parseTodayMeStressInitial(value);
}

({int aerobic, int resistance}) parseTodayMeExerciseInitial(String value) {
  if (value == '-' || !value.contains('회')) return (aerobic: 0, resistance: 0);
  final aer = RegExp(r'유산소\s*(\d+)').firstMatch(value)?.group(1);
  final res = RegExp(r'근력\s*(\d+)').firstMatch(value)?.group(1);
  return (
    aerobic: int.tryParse(aer ?? '0')?.clamp(0, 6) ?? 0,
    resistance: int.tryParse(res ?? '0')?.clamp(0, 6) ?? 0,
  );
}

/// 표시값·레거시 문자열 → 음주 다이얼로그 초기 API 값 ('0' / '1')
String? drinkingInitialApiValue(String display) {
  if (display == '-' || display.isEmpty) return null;
  if (display == '금주' || display == '0일') return '0';
  if (display == '음주') return '1';
  final m = RegExp(r'^(\d+)').firstMatch(display);
  if (m != null && m.group(1) == '0') return '0';
  return '1';
}

/// 흡연 다이얼로그 초기 선택값
String? smokingInitialApiValue(String display) {
  if (display == '-' || display.isEmpty) return null;
  if (display == '흡연') return 'current';
  if (display == '금연') return 'never';
  final low = display.toLowerCase();
  if (low.contains('current') || display.contains('현재')) return 'current';
  if (low.contains('never') || display.contains('금연') || display.contains('비흡연')) return 'never';
  if (low.contains('former') || display.contains('과거')) return 'never';
  return 'never';
}

String? uvKeyFromItemDisplay(String value) {
  const rev = {
    '30분 미만': '<30m',
    '30분~1시간': '30~60',
    '1~2시간': '1~2h',
    '2시간 이상': '>2h',
  };
  if (rev.containsKey(value)) return rev[value];
  const keys = {'<30m', '30~60', '1~2h', '>2h'};
  if (keys.contains(value)) return value;
  return null;
}
