import 'package:flutter/material.dart';

import '../services/lifestyle_service.dart';

class PastReportHistoryScreen extends StatefulWidget {
  const PastReportHistoryScreen({super.key});

  @override
  State<PastReportHistoryScreen> createState() =>
      _PastReportHistoryScreenState();
}

class _PastReportHistoryScreenState extends State<PastReportHistoryScreen> {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);

  final LifestyleService _lifestyleService = LifestyleService();

  bool _isLoading = true;
  String? _loadError;
  List<_ReportHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadReportHistory();
  }

  Future<void> _loadReportHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await _lifestyleService.getReportHistory();
    if (!mounted) return;

    if (result['success'] == true) {
      final raw = (result['items'] as List<dynamic>? ?? []);
      final mapped = raw.map((e) {
        final map = e as Map<String, dynamic>;
        final years = map['target_years'];
        final parsedYears = years is int ? years : int.tryParse('$years') ?? 0;

        return _ReportHistoryItem(
          lifestyleId: (map['lifestyle_id'] is int)
              ? map['lifestyle_id'] as int
              : int.tryParse('${map['lifestyle_id']}') ?? 0,
          generatedAt: _formatDate((map['generated_at'] ?? '').toString()),
          targetYearsText: parsedYears > 0 ? '+${parsedYears}년 뒤' : '+미래',
          summary: (map['summary'] ?? '').toString().trim(),
        );
      }).toList();

      setState(() {
        _items = mapped;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _loadError = (result['message'] ?? '리포트 이력을 불러오지 못했습니다.').toString();
      _isLoading = false;
    });
  }

  String _formatDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return '-';
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: _primary.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF102217),
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '과거 리포트 조회',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102217),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
              const Icon(Icons.error_outline,
                  color: Color(0xFF7A8380), size: 40),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7A8380),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadReportHistory,
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

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          '생성된 리포트가 아직 없습니다.',
          style: TextStyle(
            color: Color(0xFF7A8380),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.generatedAt,
                    style: const TextStyle(
                      color: Color(0xFF102217),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.targetYearsText,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.summary.isNotEmpty ? item.summary : '요약 정보가 없습니다.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7A8380),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportHistoryItem {
  const _ReportHistoryItem({
    required this.lifestyleId,
    required this.generatedAt,
    required this.targetYearsText,
    required this.summary,
  });

  final int lifestyleId;
  final String generatedAt;
  final String targetYearsText;
  final String summary;
}
