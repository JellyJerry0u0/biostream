import 'package:flutter/material.dart';

import '../services/lifestyle_service.dart';
import 'result/result_screen.dart';

class PastReportHistoryScreen extends StatefulWidget {
  const PastReportHistoryScreen({super.key});

  @override
  State<PastReportHistoryScreen> createState() =>
      _PastReportHistoryScreenState();
}

class _PastReportHistoryScreenState extends State<PastReportHistoryScreen> {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _bgLight = Color(0xFFF6F8F6);
  static const Color _bgDark = Color(0xFF132210);

  final LifestyleService _lifestyleService = LifestyleService();
  bool _isLoading = true;
  String? _loadError;
  List<_PastReportRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final result = await _lifestyleService.getReportHistory();
    if (!mounted) return;
    if (result['success'] == true) {
      final raw = (result['items'] as List<dynamic>? ?? []);
      final rows = raw.map((e) {
        final map = e as Map<String, dynamic>;
        final id = map['lifestyle_id'];
        return _PastReportRow(
          lifestyleId: id is int ? id : int.tryParse('$id') ?? 0,
          dateLabel: _formatDate((map['generated_at'] ?? '').toString()),
        );
      }).where((r) => r.lifestyleId > 0).toList();
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _loadError =
          (result['message'] ?? '리포트 이력을 불러오지 못했습니다.').toString();
      _isLoading = false;
    });
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '-';
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  void _openReport(int lifestyleId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(viewOnlyLifestyleId: lifestyleId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _bgDark : _bgLight;
    final fgTitle =
        isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF101B0D);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: fgTitle),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '과거 리포트',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: fgTitle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            Expanded(child: _body(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: isDark ? Colors.white54 : const Color(0xFF7A8380),
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF7A8380),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: const Color(0xFF102217),
                ),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          '생성된 리포트가 아직 없습니다.',
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF7A8380),
            fontSize: 14,
          ),
        ),
      );
    }
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: dividerColor),
      itemBuilder: (context, i) {
        final r = _rows[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          title: Text(
            r.dateLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF102217),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white38 : const Color(0xFF96A09B),
          ),
          onTap: () => _openReport(r.lifestyleId),
        );
      },
    );
  }
}

class _PastReportRow {
  const _PastReportRow({
    required this.lifestyleId,
    required this.dateLabel,
  });

  final int lifestyleId;
  final String dateLabel;
}
