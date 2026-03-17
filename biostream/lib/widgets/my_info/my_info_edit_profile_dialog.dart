import 'package:flutter/material.dart';

class MyInfoEditProfileDialog extends StatelessWidget {
  const MyInfoEditProfileDialog({
    super.key,
    required this.nicknameController,
    required this.emailController,
    required this.onPickImage,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController nicknameController;
  final TextEditingController emailController;
  final VoidCallback onPickImage;
  final VoidCallback onCancel;
  final Future<void> Function(String nickname, String email) onSave;

  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundDark = Color(0xFF050C08);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        '내 정보 수정',
        style: TextStyle(color: Color(0xFF102217)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nicknameController,
            style: const TextStyle(color: Color(0xFF102217)),
            decoration: const InputDecoration(
              labelText: '닉네임',
              labelStyle: TextStyle(color: Color(0xFF7A8380)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Color(0xFF102217)),
            decoration: const InputDecoration(
              labelText: '이메일',
              labelStyle: TextStyle(color: Color(0xFF7A8380)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.image, color: _primary),
              label: const Text('프로필 사진 변경', style: TextStyle(color: _primary)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('취소', style: TextStyle(color: Color(0xFF7A8380))),
        ),
        ElevatedButton(
          onPressed: () async {
            final nickname = nicknameController.text.trim();
            final email = emailController.text.trim();
            await onSave(nickname, email);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: _backgroundDark,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
