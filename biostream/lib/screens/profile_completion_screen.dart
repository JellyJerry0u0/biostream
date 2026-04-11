import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_snackbar.dart';
import '../utils/responsive.dart';
import '../services/auth_service.dart';
import 'facescan_screen.dart';

/// 카카오로 회원가입한 사용자 중 성별/생년월일이 비어있을 때 입력받는 화면
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  String? _gender;
  DateTime? _birthdate;
  String? _smoking; // never / former / current
  bool _loading = false;

  final _authService = AuthService();

  Future<void> _submit() async {
    if (_gender == null || _gender!.isEmpty) {
      showErrorSnackBar(context, '성별을 선택해주세요.');
      return;
    }
    if (_birthdate == null) {
      showErrorSnackBar(context, '생년월일을 선택해주세요.');
      return;
    }

    setState(() => _loading = true);
    final result = await _authService.updateProfile(
      DateFormat('yyyy-MM-dd').format(_birthdate!),
      _gender!,
      smokingStatus: _smoking,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success']) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FaceScanScreen()),
      );
    } else {
      showErrorSnackBar(
        context,
        result['message']?.toString() ?? '저장에 실패했습니다.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: Responsive.padding(context, 48)),
              Text(
                '프로필 보완',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 24),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              Text(
                '리포트를 맞춤으로 만들어 드리기 위해 성별과 생년월일을 입력해주세요.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 40)),
              // 성별
              Text(
                '성별',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Wrap(
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: ['남성', '여성', '기타'].map((g) {
                  return InkWell(
                    onTap: () => setState(() => _gender = g),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 20),
                        vertical: Responsive.padding(context, 14),
                      ),
                      decoration: BoxDecoration(
                        color: _gender == g
                            ? const Color(0xFF37EC13).withValues(alpha: 0.2)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _gender == g
                              ? const Color(0xFF37EC13)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.1)),
                        ),
                      ),
                      child: Text(
                        g,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 15),
                          fontWeight:
                              _gender == g ? FontWeight.w600 : FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 28)),
              // 흡연 여부
              Text(
                '흡연 여부',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Wrap(
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '비흡연'},
                  {'value': 'former', 'label': '과거 흡연'},
                  {'value': 'current', 'label': '현재 흡연'},
                ].map((opt) {
                  final v = opt['value']! as String;
                  final label = opt['label']! as String;
                  return InkWell(
                    onTap: () => setState(() => _smoking = v),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 20),
                        vertical: Responsive.padding(context, 14),
                      ),
                      decoration: BoxDecoration(
                        color: _smoking == v
                            ? const Color(0xFF37EC13).withValues(alpha: 0.2)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _smoking == v
                              ? const Color(0xFF37EC13)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.1)),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 15),
                          fontWeight:
                              _smoking == v ? FontWeight.w600 : FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 28)),
              // 생년월일
              Text(
                '생년월일',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthdate ?? DateTime(1990, 1, 1),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _birthdate = picked);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 16),
                    vertical: Responsive.padding(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 22,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      SizedBox(width: Responsive.padding(context, 12)),
                      Text(
                        _birthdate != null
                            ? DateFormat('yyyy-MM-dd').format(_birthdate!)
                            : '생년월일 선택',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 15),
                          color: _birthdate != null
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: Responsive.padding(context, 48)),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF37EC13),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.padding(context, 16),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
