import 'dart:io';

import 'package:flutter/material.dart';

class MyInfoProfileHeader extends StatelessWidget {
  const MyInfoProfileHeader({
    super.key,
    required this.nickname,
    required this.email,
    required this.profileImagePath,
    required this.onEditTap,
  });

  final String nickname;
  final String email;
  final String? profileImagePath;
  final VoidCallback onEditTap;

  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);
  static const Color _backgroundDark = Color(0xFF050C08);

  @override
  Widget build(BuildContext context) {
    final imageValue = profileImagePath ?? '';
    final hasImage = imageValue.isNotEmpty;
    final isNetworkImage = hasImage && imageValue.startsWith('http');
    final isLocalImage =
        hasImage && !isNetworkImage && File(imageValue).existsSync();

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 1.8),
                ),
                child: ClipOval(
                  child: isNetworkImage
                      ? Image.network(imageValue, fit: BoxFit.cover)
                      : isLocalImage
                          ? Image.file(File(imageValue), fit: BoxFit.cover)
                          : Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuDUmqMNsrWVq2zRG6oqresa9PHOXbvbCb3aoOQacp6WImb8sMY-ZGxaJBN0cB2XIfGkzhOBaj_GkXwQu9aWdpwUBygdkMl-7QQrbXKKEd1CceNN0n4JtAf7BM0lDJ6EBAlzpkJEUTfG-qfogrOiwo-9eqZAaV7VuaX3t-FTTryEOYZ_rSosFrP6VuF_Ih9UQI43XNPwgwhSX9lEEausS25jKHrnEYFw6eI-eSz0nw6CjKJTqjyBhBB4s_-5Ky7TOqjGV3hScQr1Ujw',
                              fit: BoxFit.cover,
                            ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: onEditTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: _backgroundLight, width: 2),
                    ),
                    child: const Icon(Icons.edit,
                        color: _backgroundDark, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$nickname 님',
            style: const TextStyle(
              color: Color(0xFF102217),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              color: _primary.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
