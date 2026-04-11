import 'package:flutter/material.dart';

class HomeRecentPredictionSection extends StatelessWidget {
  const HomeRecentPredictionSection({
    super.key,
    required this.originalImageUrl,
    required this.generatedImageUrl,
    required this.predictionPoint,
    this.summaryData,
    required this.primaryColor,
    required this.gameCardColor,
    required this.onOpenResult,
  });

  final String? originalImageUrl;
  final String? generatedImageUrl;
  final String? predictionPoint;
  final Map<String, dynamic>? summaryData;
  final Color primaryColor;
  final Color gameCardColor;
  final VoidCallback onOpenResult;

  static bool _hasSummaryPreview(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    final goals = data['goals'];
    if (goals is List && goals.isNotEmpty) return true;
    final label = data['skin_type_label']?.toString().trim() ?? '';
    if (label.isNotEmpty && label != '미입력') return true;
    for (final key in ['goals_solution', 'situation_solution']) {
      final s = data[key]?.toString().trim() ?? '';
      if (s.isNotEmpty) return true;
    }
    return false;
  }

  static String _truncate(String text, int maxChars) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    final hasOriginal =
        originalImageUrl != null && originalImageUrl!.isNotEmpty;
    final hasGenerated =
        generatedImageUrl != null && generatedImageUrl!.isNotEmpty;
    final hasPoint = predictionPoint != null && predictionPoint!.isNotEmpty;
    final hasSummary = _hasSummaryPreview(summaryData);

    if (!hasOriginal && !hasGenerated && !hasPoint && !hasSummary) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Text(
              '최근 Weekly Report 조회',
              style: TextStyle(
                color: Color(0xFF102217),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenResult,
                borderRadius: BorderRadius.circular(10),
                splashColor: const Color(0xFF102217).withValues(alpha: 0.06),
                highlightColor: const Color(0xFF102217).withValues(alpha: 0.04),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '다시 보기',
                        style: TextStyle(
                          color:
                              const Color(0xFF102217).withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 1),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: const Color(0xFF102217).withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasSummary && summaryData != null) ...[
          const SizedBox(height: 12),
          _HomeReportSummaryCard(
            data: summaryData!,
            primaryColor: primaryColor,
            gameCardColor: gameCardColor,
          ),
        ],
      ],
    );
  }
}

class _HomeReportSummaryCard extends StatelessWidget {
  const _HomeReportSummaryCard({
    required this.data,
    required this.primaryColor,
    required this.gameCardColor,
  });

  final Map<String, dynamic> data;
  final Color primaryColor;
  final Color gameCardColor;

  @override
  Widget build(BuildContext context) {
    final goals = (data['goals'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .take(5)
            .toList() ??
        const <String>[];

    final skinLabel = data['skin_type_label']?.toString().trim() ?? '';
    final skinChars = data['skin_characteristics']?.toString().trim() ?? '';
    final showSkin = skinLabel.isNotEmpty && skinLabel != '미입력';

    final goalsSol = data['goals_solution']?.toString().trim() ?? '';
    final sitSol = data['situation_solution']?.toString().trim() ?? '';
    final insight = goalsSol.isNotEmpty
        ? goalsSol
        : (sitSol.isNotEmpty ? sitSol : '');

    final tiles = <Widget>[];

    if (goals.isNotEmpty) {
      tiles.add(
        _SummaryTile(
          primaryColor: primaryColor,
          icon: Icons.flag_rounded,
          label: '주요 목표',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goals
                .map(
                  (g) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      g,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    if (showSkin) {
      tiles.add(
        _SummaryTile(
          primaryColor: primaryColor,
          icon: Icons.spa_rounded,
          label: '피부 타입',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                skinLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              if (skinChars.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  HomeRecentPredictionSection._truncate(skinChars, 220),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (insight.isNotEmpty) {
      tiles.add(
        _SummaryTile(
          primaryColor: primaryColor,
          icon: Icons.auto_awesome_rounded,
          label: '핵심 인사이트',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(
                  color: primaryColor.withValues(alpha: 0.65),
                  width: 3,
                ),
              ),
            ),
            child: Text(
              HomeRecentPredictionSection._truncate(insight, 280),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gameCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.summarize_rounded,
                  size: 18,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '리포트 요약',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            tiles[i],
          ],
        ],
      ),
    );
  }
}

/// 개별 요약 블록 — 내부 서브카드 느낌
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.primaryColor,
    required this.icon,
    required this.label,
    required this.child,
  });

  final Color primaryColor;
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: primaryColor.withValues(alpha: 0.95)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}
