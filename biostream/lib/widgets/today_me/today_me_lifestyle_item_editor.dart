import 'package:flutter/material.dart';

import '../../screens/today_me/today_me_models.dart';
import 'today_me_lifestyle_edit_dialogs.dart';

TodayLifestyleItem _itemWithValue(TodayLifestyleItem item, String value) {
  return TodayLifestyleItem(
    key: item.key,
    icon: item.icon,
    label: item.label,
    value: value,
    unit: item.unit,
    editable: item.editable,
  );
}

/// 생활 항목 편집 다이얼로그 묶음. [valueForEditResult]는 `TodayMeController.displayValueForEditResult` 등.
Future<TodayLifestyleItem?> runTodayMeLifestyleItemEditor({
  required BuildContext context,
  required TodayLifestyleItem item,
  required String Function(String key, dynamic raw) valueForEditResult,
}) async {
  if (item.key == 'uv_outdoor') {
    final selected = await showTodayMeUvDialog(
      context: context,
      selectedKey: uvKeyFromItemDisplay(item.value),
    );
    if (selected == null) return null;
    return _itemWithValue(item, valueForEditResult(item.key, selected));
  }

  if (item.key == 'sunscreen') {
    bool? initial;
    switch (item.value) {
      case '도포':
      case '도포함':
        initial = true;
        break;
      case '도포X':
      case '안 함':
        initial = false;
        break;
      default:
        initial = null;
    }
    final selected = await showTodayMeSunscreenBinaryDialog(
      context: context,
      initialApplied: initial,
    );
    if (selected == null) return null;
    return _itemWithValue(item, valueForEditResult(item.key, selected));
  }

  if (item.key == 'drinking') {
    final selected = await showTodayMeBinaryStringDialog(
      context: context,
      title: '음주',
      subtitle: '오늘 기준으로 선택해 주세요',
      options: [
        (label: '음주', value: '1'),
        (label: '금주', value: '0'),
      ],
      selectedValue: drinkingInitialApiValue(item.value),
    );
    if (selected == null) return null;
    return _itemWithValue(item, valueForEditResult(item.key, selected));
  }

  if (item.key == 'smoking') {
    final selected = await showTodayMeBinaryStringDialog(
      context: context,
      title: '흡연',
      subtitle: '오늘 기준으로 선택해 주세요',
      options: [
        (label: '흡연', value: 'current'),
        (label: '금연', value: 'never'),
      ],
      selectedValue: smokingInitialApiValue(item.value),
    );
    if (selected == null) return null;
    return _itemWithValue(item, valueForEditResult(item.key, selected));
  }

  if (item.key == 'exercise') {
    final init = parseTodayMeExerciseInitial(item.value);
    final result = await showTodayMeExerciseWheelsDialog(
      context: context,
      initialAerobic: init.aerobic,
      initialResistance: init.resistance,
    );
    if (result == null) return null;
    return _itemWithValue(
      item,
      valueForEditResult(item.key, {
        'aerobic': result.aerobic,
        'resistance': result.resistance,
      }),
    );
  }

  if (item.key == 'stress') {
    final initial = parseTodayMeStressInitial(item.value);
    final v = await showTodayMeScoreSliderDialog(
      context: context,
      title: '스트레스',
      subtitle: '지난 1주 기준으로 느끼는 정도를 맞춰 주세요',
      initial: initial,
    );
    if (v == null) return null;
    return _itemWithValue(item, valueForEditResult(item.key, v));
  }

  if (item.key == 'sleep_quality') {
    final initial = parseTodayMeSleepQualityInitial(item.value);
    final v = await showTodayMeScoreSliderDialog(
      context: context,
      title: '수면의 질',
      subtitle: '오늘 아침 기준 주관적 만족도예요',
      initial: initial,
    );
    if (v == null) return null;
    return _itemWithValue(item, valueForEditResult(item.key, v));
  }

  String initialVal = item.value
      .replaceAll(RegExp(r'\s*/\d+$'), '')
      .replaceAll('/10', '')
      .replaceAll('시간', '')
      .replaceAll('일/주', '')
      .replaceAll('일', '')
      .replaceAll('점', '')
      .trim();
  if (item.key == 'sleep_quality' && initialVal == '-') initialVal = '';
  if (item.key == 'sleep' && initialVal == '-') initialVal = '';

  final text = await showTodayMeTextFieldDialog(
    context: context,
    title: '${item.label} 입력',
    hint: item.key == 'sleep' ? '시간 (예: 7.5)' : (item.unit.isNotEmpty ? item.unit : null),
    initialText: initialVal == '-' ? '' : initialVal,
    keyboardType: item.key == 'sleep'
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
  );
  if (text == null) return null;
  if (item.key == 'sleep') {
    final normalized = text.trim().replaceAll(',', '.');
    final hours = double.tryParse(normalized);
    if (hours == null || hours <= 0) return null;
    return _itemWithValue(
      item,
      valueForEditResult(item.key, (hours * 60).round()),
    );
  }
  return _itemWithValue(item, valueForEditResult(item.key, text.trim()));
}
