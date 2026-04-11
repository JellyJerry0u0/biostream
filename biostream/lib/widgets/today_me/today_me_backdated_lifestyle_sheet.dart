import 'package:flutter/material.dart';

import '../../utils/app_snackbar.dart';

import '../../screens/today_me/today_me_controller.dart';
import '../../screens/today_me/today_me_models.dart';
import 'today_me_lifestyle_intro_layer.dart';
import 'today_me_lifestyle_item_editor.dart';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _sheetDateTitle(DateTime d) {
  const w = ['월', '화', '수', '목', '금', '토', '일'];
  return '${d.month}월 ${d.day}일 (${w[d.weekday - 1]}) 기록';
}

Future<void> showTodayMeBackdatedLifestyleSheet({
  required BuildContext context,
  required DateTime recordDate,
  required TodayMeController controller,
  required Color primaryColor,
  required VoidCallback onSaved,
}) {
  final norm = DateTime(recordDate.year, recordDate.month, recordDate.day);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _TodayMeBackdatedLifestyleSheetBody(
        recordDate: norm,
        controller: controller,
        primaryColor: primaryColor,
        onSaved: onSaved,
      );
    },
  );
}

class _TodayMeBackdatedLifestyleSheetBody extends StatefulWidget {
  const _TodayMeBackdatedLifestyleSheetBody({
    required this.recordDate,
    required this.controller,
    required this.primaryColor,
    required this.onSaved,
  });

  final DateTime recordDate;
  final TodayMeController controller;
  final Color primaryColor;
  final VoidCallback onSaved;

  @override
  State<_TodayMeBackdatedLifestyleSheetBody> createState() =>
      _TodayMeBackdatedLifestyleSheetBodyState();
}

class _TodayMeBackdatedLifestyleSheetBodyState
    extends State<_TodayMeBackdatedLifestyleSheetBody> {
  late List<TodayLifestyleItem> _items;
  bool _showGate = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.controller.itemsFromHistoryDay(null);
  }

  Future<void> _editItem(TodayLifestyleItem item) async {
    final updated = await runTodayMeLifestyleItemEditor(
      context: context,
      item: item,
      valueForEditResult: widget.controller.displayValueForEditResult,
    );
    if (updated == null || !mounted) return;
    final idx = _items.indexWhere((e) => e.key == updated.key);
    if (idx < 0) return;
    setState(() {
      _items = [
        for (var i = 0; i < _items.length; i++)
          i == idx ? updated : _items[i],
      ];
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final batchResult = await widget.controller.saveSnapshotBatchFromItems(
      date: _dateKey(widget.recordDate),
      items: _items,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (batchResult['success'] != true) {
      showErrorSnackBar(context, '저장에 실패했습니다. 다시 시도해 주세요.');
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved();
  }

  Widget _placeholderBehindGate() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.48,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8F0EB)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: maxH,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3ECE7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF7A8380),
                    ),
                  ),
                  Expanded(
                    child: _showGate
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            child: TodayMeLifestyleIntroLayer(
                              showIntroGate: true,
                              onIntroDismissed: () {
                                if (mounted) {
                                  setState(() => _showGate = false);
                                }
                              },
                              primaryColor: widget.primaryColor,
                              introCardText:
                                  '해당 날짜 나의 생활을 기록하지 않았습니다.\n'
                                  '기록하려면 터치해주세요.',
                              child: _placeholderBehindGate(),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sheetDateTitle(widget.recordDate),
                                  style: const TextStyle(
                                    color: Color(0xFF102217),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '항목을 탭해 입력한 뒤 저장해 주세요.',
                                  style: TextStyle(
                                    color: Color(0xFF92A29B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _items.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1.48,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return _SheetLifestyleCard(
                                      item: item,
                                      primaryColor: widget.primaryColor,
                                      onTap: item.editable
                                          ? () => _editItem(item)
                                          : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _saving ? null : _save,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: widget.primaryColor,
                                      foregroundColor: const Color(0xFF102217),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Color(0xFF102217),
                                            ),
                                          )
                                        : const Text(
                                            '생활 기록 저장',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLifestyleCard extends StatelessWidget {
  const _SheetLifestyleCard({
    required this.item,
    required this.primaryColor,
    this.onTap,
  });

  final TodayLifestyleItem item;
  final Color primaryColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, color: primaryColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      color: Color(0xFF7A8380),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.edit, size: 14, color: Colors.grey[400]),
              ],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.value,
                        style: const TextStyle(
                          color: Color(0xFF102217),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.unit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            item.unit,
                            style: const TextStyle(
                              color: Color(0xFF96A09B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
