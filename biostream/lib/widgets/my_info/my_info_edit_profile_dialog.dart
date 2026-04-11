import 'package:flutter/material.dart';

/// 내 정보 수정 — 카드형 다이얼로그
class MyInfoEditProfileDialog extends StatelessWidget {
  const MyInfoEditProfileDialog({
    super.key,
    required this.emailController,
    required this.nicknameController,
    required this.heightCmController,
    required this.weightKgController,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController emailController;
  final TextEditingController nicknameController;
  final TextEditingController heightCmController;
  final TextEditingController weightKgController;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  static const Color _primary = Color(0xFF2BEE75);
  static const Color _ink = Color(0xFF102217);
  static const Color _muted = Color(0xFF7A8380);
  static const Color _fieldFill = Color(0xFFF0F4F1);

  static OutlineInputBorder _fieldBorder({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: color ?? Colors.black.withValues(alpha: 0.06),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: _primary,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: _fieldBorder(),
      focusedBorder: _fieldBorder(color: _primary.withValues(alpha: 0.55)),
      border: _fieldBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline, color: _primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 정보 수정',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '이메일·닉네임·체형을 업데이트하세요',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(color: _ink, fontSize: 15),
                decoration: _decoration('이메일'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nicknameController,
                style: const TextStyle(color: _ink, fontSize: 15),
                decoration: _decoration('닉네임'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: heightCmController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _ink, fontSize: 15),
                decoration: _decoration('키 (cm)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: weightKgController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _ink, fontSize: 15),
                decoration: _decoration('몸무게 (kg)'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await onSave();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: _ink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
