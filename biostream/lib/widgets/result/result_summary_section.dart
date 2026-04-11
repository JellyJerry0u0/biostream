import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

/// 요약 탭 전용 위젯 (워드클라우드 목표, 피부 타입, 5각형 그래프, 상황 솔루션)
class ResultSummarySection extends StatelessWidget {
  final Map<String, dynamic> summaryData;
  final bool isDark;

  const ResultSummarySection({
    super.key,
    required this.summaryData,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final goals = (summaryData['goals'] as List<dynamic>?)?.cast<String>() ?? [];
    final skinTypeLabel =
        summaryData['skin_type_label'] as String? ?? '미입력';
    final skinCharacteristics =
        summaryData['skin_characteristics'] as String? ?? '';
    final pentagonScores =
        summaryData['pentagon_scores'] as Map<String, dynamic>? ?? {};
    final goalsSolution =
        summaryData['goals_solution'] as String? ?? '';
    final situationSolution =
        summaryData['situation_solution'] as String? ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 피부 목표
          if (goals.isNotEmpty) _buildGoalsFloating(context, goals),
          if (goals.isNotEmpty) SizedBox(height: Responsive.padding(context, 24)),

          // 2. 당신의 피부 타입
          _buildSkinSection(context, skinTypeLabel, skinCharacteristics),
          SizedBox(height: Responsive.padding(context, 24)),

          // 3. 설문 기반 생활 지표 (5각형)
          _buildPentagonGraph(context, pentagonScores),
          SizedBox(height: Responsive.padding(context, 24)),

          // 4. 피부 목표에 대한 솔루션
          if (goalsSolution.isNotEmpty)
            _buildGoalsSolution(context, goalsSolution),
          if (goalsSolution.isNotEmpty)
            SizedBox(height: Responsive.padding(context, 24)),

          // 5. 참고 상황에 대한 솔루션
          if (situationSolution.isNotEmpty)
            _buildSituationSolution(context, situationSolution),
        ],
      ),
    );
  }

  Widget _buildGoalsFloating(BuildContext context, List<String> goals) {
    return SizedBox(
      height: 160,
      child: GoalsWordCloud(
        goals: goals,
        isDark: isDark,
      ),
    );
  }

  Widget _buildSkinSection(
    BuildContext context,
    String skinTypeLabel,
    String skinCharacteristics,
  ) {
    if (skinTypeLabel.isEmpty && skinCharacteristics.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2C16)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '당신의 피부 타입',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            skinTypeLabel,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (skinCharacteristics.isNotEmpty) ...[
            SizedBox(height: Responsive.padding(context, 6)),
            Text(
              skinCharacteristics,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const List<String> _pentagonLabels = [
    '수면',
    '음주·흡연',
    '스트레스',
    '활동',
    '자외선',
  ];

  static const List<String> _pentagonKeys = [
    'sleep',
    'alcohol_smoking', // 렌더 시 alcohol + smoking 평균으로 합침
    'stress',
    'activity',
    'uv',
  ];

  int _getPentagonScore(String key, Map<String, dynamic> pentagonScores) {
    if (key == 'alcohol_smoking') {
      final a = pentagonScores['alcohol'];
      final s = pentagonScores['smoking'];
      if (a != null || s != null) {
        final av = (a is int) ? a : (a is num ? a.toInt() : 50);
        final sv = (s is int) ? s : (s is num ? s.toInt() : 50);
        return ((av + sv) / 2).round().clamp(0, 100);
      }
      // 하위 호환: 기존 alcohol_smoking 단일 값
      final v = pentagonScores['alcohol_smoking'];
      return (v is int) ? v : (v is num ? v.toInt() : 50);
    }
    final v = pentagonScores[key];
    return (v is int) ? v : (v is num ? v.toInt() : 50);
  }

  Widget _buildPentagonGraph(
    BuildContext context,
    Map<String, dynamic> pentagonScores,
  ) {
    final scores = _pentagonKeys
        .map((k) => _getPentagonScore(k, pentagonScores))
        .toList();

    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2C16)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '설문 기반 생활습관 지표',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: Responsive.padding(context, 20)),
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: PentagonRadarPainter(
                  scores: scores,
                  labels: _pentagonLabels,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSolution(BuildContext context, String text) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2C16)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF37EC13).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: Responsive.iconSize(context, 18),
                color: const Color(0xFF37EC13),
              ),
              SizedBox(width: Responsive.padding(context, 6)),
              Text(
                '피부 목표에 대한 솔루션',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF37EC13),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 10)),
          Text(
            text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSituationSolution(BuildContext context, String text) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2C16)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF37EC13).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: Responsive.iconSize(context, 18),
                color: const Color(0xFF37EC13),
              ),
              SizedBox(width: Responsive.padding(context, 6)),
              Text(
                '참고 상황에 대한 솔루션',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF37EC13),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 10)),
          Text(
            text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// 선택 개수에 따라 글자 크기·간격·떠다니는 진폭·배치를 조정한다 (적을수록 크고 여유 있게).
class _GoalsCloudSpec {
  const _GoalsCloudSpec({
    required this.fontLogical,
    required this.gapLogical,
    required this.runLogical,
    required this.dxAmp,
    required this.dyAmp,
  });

  final double fontLogical;
  final double gapLogical;
  final double runLogical;
  final double dxAmp;
  final double dyAmp;

  static _GoalsCloudSpec forCount(int n) {
    final c = n < 1 ? 1 : n;
    if (c <= 1) {
      return const _GoalsCloudSpec(
        fontLogical: 27,
        gapLogical: 0,
        runLogical: 0,
        dxAmp: 6,
        dyAmp: 9,
      );
    }
    if (c == 2) {
      return const _GoalsCloudSpec(
        fontLogical: 23,
        gapLogical: 12,
        runLogical: 0,
        dxAmp: 5,
        dyAmp: 7,
      );
    }
    if (c == 3) {
      return const _GoalsCloudSpec(
        fontLogical: 20,
        gapLogical: 10,
        runLogical: 12,
        dxAmp: 4,
        dyAmp: 6,
      );
    }
    if (c == 4) {
      return const _GoalsCloudSpec(
        fontLogical: 18,
        gapLogical: 8,
        runLogical: 10,
        dxAmp: 4,
        dyAmp: 5.5,
      );
    }
    if (c == 5) {
      return const _GoalsCloudSpec(
        fontLogical: 17,
        gapLogical: 7,
        runLogical: 9,
        dxAmp: 3.5,
        dyAmp: 5,
      );
    }
    if (c == 6) {
      return const _GoalsCloudSpec(
        fontLogical: 16,
        gapLogical: 6,
        runLogical: 8,
        dxAmp: 3.5,
        dyAmp: 5,
      );
    }
    if (c <= 9) {
      return const _GoalsCloudSpec(
        fontLogical: 15,
        gapLogical: 5,
        runLogical: 7,
        dxAmp: 3,
        dyAmp: 4.5,
      );
    }
    return const _GoalsCloudSpec(
      fontLogical: 13,
      gapLogical: 4,
      runLogical: 6,
      dxAmp: 2.5,
      dyAmp: 4,
    );
  }
}

/// 워드클라우드 스타일 피부 목표 (둥둥 떠다니는 애니메이션)
class GoalsWordCloud extends StatefulWidget {
  final List<String> goals;
  final bool isDark;

  const GoalsWordCloud({
    super.key,
    required this.goals,
    required this.isDark,
  });

  @override
  State<GoalsWordCloud> createState() => _GoalsWordCloudState();
}

class _GoalsWordCloudState extends State<GoalsWordCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) return const SizedBox.shrink();

    final goals = widget.goals;
    final n = goals.length;
    final spec = _GoalsCloudSpec.forCount(n);
    final fs = Responsive.fontSize(context, spec.fontLogical);
    final gap = Responsive.padding(context, spec.gapLogical);
    final run = Responsive.padding(context, spec.runLogical);

    Widget word(int i) => _FloatingWord(
          word: goals[i],
          fontSize: fs,
          isDark: widget.isDark,
          phaseOffset: i * 0.62,
          animation: _controller,
          dxAmp: spec.dxAmp,
          dyAmp: spec.dyAmp,
        );

    final Widget body;
    if (n == 1) {
      body = SizedBox(
        height: fs * 2.5 + spec.dyAmp * 2,
        child: Center(child: word(0)),
      );
    } else if (n == 2) {
      body = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Center(child: word(0))),
          SizedBox(width: math.max(16.0, gap * 1.4)),
          Expanded(child: Center(child: word(1))),
        ],
      );
    } else if (n == 3) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: word(0)),
          SizedBox(height: run),
          Row(
            children: [
              Expanded(child: Center(child: word(1))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(2))),
            ],
          ),
        ],
      );
    } else if (n == 4) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Center(child: word(0))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(1))),
            ],
          ),
          SizedBox(height: run),
          Row(
            children: [
              Expanded(child: Center(child: word(2))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(3))),
            ],
          ),
        ],
      );
    } else if (n == 5) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Center(child: word(0))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(1))),
            ],
          ),
          SizedBox(height: run),
          Row(
            children: [
              Expanded(child: Center(child: word(2))),
              SizedBox(width: gap * 0.65),
              Expanded(child: Center(child: word(3))),
              SizedBox(width: gap * 0.65),
              Expanded(child: Center(child: word(4))),
            ],
          ),
        ],
      );
    } else if (n == 6) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Center(child: word(0))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(1))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(2))),
            ],
          ),
          SizedBox(height: run),
          Row(
            children: [
              Expanded(child: Center(child: word(3))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(4))),
              SizedBox(width: gap),
              Expanded(child: Center(child: word(5))),
            ],
          ),
        ],
      );
    } else {
      body = Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: math.max(6.0, gap),
        runSpacing: math.max(6.0, run),
        children: List.generate(n, word),
      );
    }

    Widget centeredBody = body;
    if (n >= 2 && n <= 6) {
      // 소수 goals 구간은 폭을 살짝 줄여 좌우 치우침 없이 중앙에 모이게 한다.
      final widthFactor = switch (n) {
        2 => 0.74,
        3 || 4 => 0.84,
        _ => 0.92,
      };
      centeredBody = FractionallySizedBox(
        widthFactor: widthFactor,
        child: body,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 16)),
      child: Center(child: centeredBody),
    );
  }
}

class _FloatingWord extends StatelessWidget {
  final String word;
  final double fontSize;
  final bool isDark;
  final double phaseOffset;
  final Animation<double> animation;
  final double dxAmp;
  final double dyAmp;

  const _FloatingWord({
    required this.word,
    required this.fontSize,
    required this.isDark,
    required this.phaseOffset,
    required this.animation,
    this.dxAmp = 4,
    this.dyAmp = 6,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final phase = animation.value * 2 * math.pi + phaseOffset;
        final dy = math.sin(phase) * dyAmp;
        final dx = math.cos(phase) * dxAmp;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Text(
            word,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : const Color(0xFF101B0D),
              shadows: [
                Shadow(
                  color: const Color(0xFF37EC13).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: (isDark ? Colors.black : Colors.grey.shade400)
                      .withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 5각형 레이더 차트 (수면, 음주·흡연, 스트레스, 활동, 자외선)
class PentagonRadarPainter extends CustomPainter {
  final List<int> scores; // 0~100, 순서: sleep, (alcohol+smoking)/2, stress, activity, uv
  final List<String> labels;
  final bool isDark;

  PentagonRadarPainter({
    required this.scores,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;

    // 5개 꼭짓점 각도 (위에서 시계방향)
    const angles = [270.0, 342.0, 54.0, 126.0, 198.0]; // 72도 간격
    final vertices = angles.map((a) {
      final rad = a * math.pi / 180;
      return Offset(
        center.dx + radius * math.cos(rad),
        center.dy + radius * math.sin(rad),
      );
    }).toList();

    // 배경 그리드 (20, 40, 60, 80, 100%)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var scale = 0.2; scale <= 1.0; scale += 0.2) {
      final pts = angles.map((a) {
        final rad = a * math.pi / 180;
        final r = radius * scale;
        return Offset(
          center.dx + r * math.cos(rad),
          center.dy + r * math.sin(rad),
        );
      }).toList();
      for (var i = 0; i < pts.length; i++) {
        canvas.drawLine(
          pts[i],
          pts[(i + 1) % pts.length],
          gridPaint,
        );
      }
    }

    // 점수에 따른 데이터 폴리곤
    final dataPts = <Offset>[];
    for (var i = 0; i < 5; i++) {
      final s = (i < scores.length) ? scores[i] : 50;
      final scale = s / 100.0;
      final rad = angles[i] * math.pi / 180;
      dataPts.add(Offset(
        center.dx + radius * scale * math.cos(rad),
        center.dy + radius * scale * math.sin(rad),
      ));
    }

    final fillPaint = Paint()
      ..color = const Color(0xFF37EC13).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF37EC13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(
      Path()..addPolygon(dataPts, true),
      fillPaint,
    );
    canvas.drawPath(
      Path()..addPolygon(dataPts, true),
      strokePaint,
    );

    // 축 라벨 (꼭짓점 바깥)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade800;
    for (var i = 0; i < 5; i++) {
      final label = i < labels.length ? labels[i] : '';
      final rad = angles[i] * math.pi / 180;
      final outer = radius * 1.12;
      final pos = Offset(
        center.dx + outer * math.cos(rad),
        center.dy + outer * math.sin(rad),
      );
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12,
          color: labelColor,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          pos.dx - textPainter.width / 2,
          pos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PentagonRadarPainter old) =>
      old.scores != scores || old.isDark != isDark;
}
