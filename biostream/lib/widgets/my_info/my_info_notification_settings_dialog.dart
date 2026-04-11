import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../utils/app_snackbar.dart';

/// 내 정보 > 알림 설정 — OS 푸시 권한 상태 안내 및 요청·설정 이동
Future<void> showMyInfoNotificationSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => const _MyInfoNotificationSettingsDialogBody(),
  );
}

class _MyInfoNotificationSettingsDialogBody extends StatefulWidget {
  const _MyInfoNotificationSettingsDialogBody();

  @override
  State<_MyInfoNotificationSettingsDialogBody> createState() =>
      _MyInfoNotificationSettingsDialogBodyState();
}

class _MyInfoNotificationSettingsDialogBodyState
    extends State<_MyInfoNotificationSettingsDialogBody> {
  static const Color _primary = Color(0xFF2BEE75);

  PushPermissionSettingsSnapshot? _snapshot;
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final s = await NotificationService.instance.loadPushPermissionSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = s;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final s =
          await NotificationService.instance.requestPushPermissionAgain();
      if (!mounted) return;
      setState(() {
        _snapshot = s;
        _requesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      showErrorSnackBar(context, '알림 요청 중 오류가 났어요: $e');
    }
  }

  Future<void> _openSettings() async {
    await NotificationService.instance.openSystemAppSettings();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.88,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: _primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '알림 설정',
                      style: TextStyle(
                        color: Color(0xFF102217),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                )
              else if (_snapshot != null) ...[
                Text(
                  _snapshot!.statusLine,
                  style: const TextStyle(
                    color: Color(0xFF102217),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (_snapshot!.detailLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _snapshot!.detailLine,
                    style: const TextStyle(
                      color: Color(0xFF5C6560),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_snapshot!.platformSupported) ...[
                  if (_snapshot!.showRequestButton)
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: _requesting ? null : _requestPermission,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: const Color(0xFF102217),
                          disabledBackgroundColor:
                              _primary.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: _requesting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF102217),
                                ),
                              )
                            : const Text('알림 허용 요청'),
                      ),
                    ),
                  if (_snapshot!.showRequestButton &&
                      _snapshot!.showSystemSettingsHint)
                    const SizedBox(height: 10),
                  if (_snapshot!.showSystemSettingsHint)
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _requesting ? null : _openSettings,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF102217),
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('시스템 설정 열기'),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      color: Color(0xFF7A8380),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
