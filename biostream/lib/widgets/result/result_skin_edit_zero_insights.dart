import 'package:flutter/material.dart';

import '../../screens/survey/survey_labels.dart';
import '../../utils/responsive.dart';

/// `/skin-edit`에 전달되는 6종 점수(0/100)를 lifestyle 응답과 동일 규칙으로 계산.
/// 백엔드 `ImageGenerationService._map_habits_to_gpu_skin_scores` 와 맞춤.
class SkinEditGpuScores {
  const SkinEditGpuScores({
    required this.uvScore,
    required this.sleepScore,
    required this.exerciseScore,
    required this.smokingScore,
    required this.alcoholScore,
    required this.stressScore,
  });

  final int uvScore;
  final int sleepScore;
  final int exerciseScore;
  final int smokingScore;
  final int alcoholScore;
  final int stressScore;

  static SkinEditGpuScores fromLifestyleData(Map<String, dynamic>? root) {
    final life = root?['lifestyle'] as Map<String, dynamic>?;
    if (life == null) {
      return const SkinEditGpuScores(
        uvScore: 100,
        sleepScore: 100,
        exerciseScore: 100,
        smokingScore: 100,
        alcoholScore: 100,
        stressScore: 100,
      );
    }

    final smoking = life['smoking'] as Map<String, dynamic>?;
    final sleep = life['sleep'] as Map<String, dynamic>?;
    final uv = life['uv'] as Map<String, dynamic>?;
    final drinking = life['drinking'] as Map<String, dynamic>?;
    final stress = life['stress'] as Map<String, dynamic>?;
    final activity = life['activity'] as Map<String, dynamic>?;

    final smokingStatus =
        (smoking?['smoking_status'] ?? '').toString().trim().toLowerCase();
    final smokingScore = smokingStatus == 'current' ? 0 : 100;

    final uvRaw = (uv?['uv_exposure_10to16'] ?? '').toString().trim();
    final sf = (uv?['sunscreen_frequency'] ?? '').toString().trim().toLowerCase();
    final dailySunscreen =
        sf == 'daily_with_reapply' || sf == '6-7';
    final minimalOutdoor = uvRaw == '<30m';
    final uvScore = (dailySunscreen || minimalOutdoor)
        ? 100
        : (uvRaw.isEmpty && sf.isEmpty)
            ? 100
            : 0;

    final sh = _parseLeadingDouble(sleep?['sleep_hours_weekday']);
    final sleepScore = sh == null ? 100 : (sh < 7.5 ? 0 : 100);

    final drink =
        (drinking?['drinking_days_per_week'] ?? '').toString().trim();
    final alcoholScore =
        (drink == '6-7' || drink == '6~7') ? 0 : 100;

    final st = _parseLeadingDouble(stress?['stress_score']);
    final stressScore = st == null ? 100 : (st >= 7.0 ? 0 : 100);

    final aerobic = (activity?['aerobic_weekly'] ?? '').toString().trim();
    final resistance =
        (activity?['resistance_weekly'] ?? '').toString().trim();
    final aerobicBad =
        aerobic == '0' || aerobic == '1-2' || aerobic == '3-4';
    final resistanceBad = resistance == '0' || resistance == '1';
    final exerciseScore = (aerobic.isEmpty && resistance.isEmpty)
        ? 100
        : ((aerobicBad || resistanceBad) ? 0 : 100);

    return SkinEditGpuScores(
      uvScore: uvScore,
      sleepScore: sleepScore,
      exerciseScore: exerciseScore,
      smokingScore: smokingScore,
      alcoholScore: alcoholScore,
      stressScore: stressScore,
    );
  }

  static double? _parseLeadingDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final m = RegExp(r'([\d.]+)').firstMatch(v.toString().trim());
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }
}

/// GPU skin-edit 6도메인별 설문·근거·시뮬 반영 설명 (리포트 대기 / 미래얼굴 탭 공용).
class SkinEditInsightSection {
  const SkinEditInsightSection({
    required this.title,
    required this.surveyLine,
    required this.paragraphs,
    required this.impacts,
  });

  final String title;
  final String surveyLine;
  final List<String> paragraphs;
  final List<String> impacts;
}

/// 자외선 → 수면 → 운동 → 흡연 → 음주 → 스트레스 고정 순서.
class SkinEditInsightsBuilder {
  SkinEditInsightsBuilder._();

  static String sleepSurveyLine(Map<String, dynamic>? sleep) {
    if (sleep == null) return '미입력';
    final w = sleep['sleep_hours_weekday']?.toString() ?? '';
    final we = sleep['sleep_hours_weekend']?.toString() ?? '';
    final q = sleep['sleep_quality_score']?.toString() ?? '';
    final parts = <String>[];
    if (w.isNotEmpty) parts.add('평일 $w');
    if (we.isNotEmpty) parts.add('주말 $we');
    if (q.isNotEmpty) parts.add('수면 질 $q');
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  /// AI 이미지 생성 직후 skin-edit에 쓰는 6축 전부 — 과학 근거·시뮬 반영을 영역별로 정리.
  static List<SkinEditInsightSection> allDomains(
    Map<String, dynamic>? lifestyleRoot,
  ) {
    final life = lifestyleRoot?['lifestyle'] as Map<String, dynamic>?;

    final uv = life?['uv'] as Map<String, dynamic>?;
    final sleep = life?['sleep'] as Map<String, dynamic>?;
    final activity = life?['activity'] as Map<String, dynamic>?;
    final smoking = life?['smoking'] as Map<String, dynamic>?;
    final drinking = life?['drinking'] as Map<String, dynamic>?;
    final stress = life?['stress'] as Map<String, dynamic>?;

    final uvSurvey = SurveyLabels.uvExposureSummary(
      uvExposure10to16: uv?['uv_exposure_10to16']?.toString(),
      sunscreenFrequency: uv?['sunscreen_frequency']?.toString(),
    );

    final sleepSurvey = sleepSurveyLine(sleep);
    final exerciseSurvey =
        '유산소 ${SurveyLabels.aerobicLabel(activity?['aerobic_weekly']?.toString())}, '
        '근력 ${SurveyLabels.resistanceLabel(activity?['resistance_weekly']?.toString())}';
    final smokingSurvey = SurveyLabels.drinkingSmokingSummary(
      drinkingDaysPerWeek: null,
      smokingStatus: smoking?['smoking_status']?.toString(),
      smokingDaysPerWeek: smoking?['smoking_days_per_week']?.toString(),
    );
    final drinkingDays = drinking?['drinking_days_per_week']?.toString();
    final alcoholSurvey = (drinkingDays != null && drinkingDays.isNotEmpty)
        ? '음주: ${SurveyLabels.drinkingDaysLabel(drinkingDays)}'
        : '미입력';
    final stressSurvey = stress?['stress_score'] != null
        ? '스트레스: ${stress!['stress_score']}'
        : '미입력';

    return [
      SkinEditInsightSection(
        title: '자외선',
        surveyLine: uvSurvey,
        paragraphs: const [
          '자외선 노출에 의한 노화인 광노화는 피부 노화 전체의 가장 지배적인 요인입니다.',
          '임상 연구에 따르면, 하루 2시간 이상 자외선에 노출되는 그룹은 30분 미만 노출 그룹에 비해 주름 발생률이 8배, 색소 침착 발생률은 약 5.7배 높은 것으로 나타납니다.',
        ],
        impacts: const [
          '얼굴에 기미나 색소침착이 나타날 수 있습니다.',
          '입가 주름이 심화될 수 있습니다.',
        ],
      ),
      SkinEditInsightSection(
        title: '수면',
        surveyLine: sleepSurvey,
        paragraphs: const [
          '성인(18세~64세)의 적정 수면 시간은 7-9시간 입니다.',
          '수면은 피부 세포가 손상을 복구하고 재생하는 유일한 시간으로, 수면 부족은 이러한 복구 과정을 차단하여 피부 노화를 급격히 가속화합니다.',
          '클리블랜드 클리닉과 에스티로더의 공동 연구에 따르면, 하루 5시간 이하로 자는 사람들은 7~9시간을 자는 사람들에 비해 미세 주름의 양이 약 2배 더 많은 것으로 측정됩니다.',
        ],
        impacts: const [
          '다크써클과 눈가 주름이 얼굴에 나타날 수 있습니다.',
        ],
      ),
      SkinEditInsightSection(
        title: '운동',
        surveyLine: exerciseSurvey,
        paragraphs: const [
          '규칙적인 운동은 피부 세포에 더 많은 영양분을 공급하고 노폐물을 신속히 제거합니다.',
          '중년 여성을 대상으로 한 연구에서 근력 운동은 피부의 진피 두께와 탄력을 직접적으로 증가시키는 것으로 확인되었습니다.',
        ],
        impacts: const [
          '피부 탄력이 떨어질 수 있습니다.',
        ],
      ),
      SkinEditInsightSection(
        title: '흡연',
        surveyLine: smokingSurvey,
        paragraphs: const [
          '연구에 따르면, 흡연자는 비흡연자인 형제/자매에 비해 10년의 흡연 기간당 약 2.5세 더 늙어 보이는 것으로 나타났습니다.',
          '임상적으로 유의미한 외관상의 차이가 발생하기 위한 최소 임계치는 약 5년의 흡연 기간인 것으로 확인되었습니다.',
        ],
        impacts: const [
          '피부가 노란빛으로 변하는 안색의 변화가 동반될 수 있습니다.',
        ],
      ),
      SkinEditInsightSection(
        title: '음주',
        surveyLine: alcoholSurvey,
        paragraphs: const [
          '노스웨스턴 대학교와 프레이밍햄 심장 연구의 데이터에 따르면, 알코올 섭취는 생물학적 노화 지표를 유의미하게 상승시킵니다.',
          '특히 증류주의 섭취가 맥주나 와인보다 노화에 미치는 영향이 월등히 큰 것으로 확인됩니다.',
          '중년층에서 하루 평균 표준 잔 1잔을 추가로 마실 때마다 생물학적 연령은 약 0.71년 더 많아진 것으로 나타났습니다.',
          '1회 5잔 이상의 폭음은 생물학적 연령을 1.5개월 앞당기는 효과가 있습니다.',
        ],
        impacts: const [
          '노화가 가속화 될 수 있습니다.',
        ],
      ),
      SkinEditInsightSection(
        title: '스트레스',
        surveyLine: stressSurvey,
        paragraphs: const [
          '스트레스는 보이지 않는 노화의 주범으로 불리며, 피부 세포의 DNA를 손상시키고 피부 장벽을 무너뜁니다.',
          '만성적인 심리적 스트레스를 보통 또는 높음 수준으로 겪고 있는 피험자들은 낮음 수준인 대조군에 비해 피부 미세 구조 변형 및 미세 주름의 심각도가 약 32.9% 더 높은 것으로 나타났습니다.',
        ],
        impacts: const [
          '턱 주변의 염증이 생길 수 있습니다.',
          '피부가 만성적으로 건조하고 예민해집니다.',
        ],
      ),
    ];
  }

  /// GPU 점수 0인 축만 (리포트 생성 대기 카드용).
  static List<SkinEditInsightSection> zeroScoreOnly(
    Map<String, dynamic>? lifestyleRoot,
  ) {
    final scores = SkinEditGpuScores.fromLifestyleData(lifestyleRoot);
    final all = allDomains(lifestyleRoot);
    final out = <SkinEditInsightSection>[];
    if (scores.uvScore == 0) out.add(all[0]);
    if (scores.sleepScore == 0) out.add(all[1]);
    if (scores.exerciseScore == 0) out.add(all[2]);
    if (scores.smokingScore == 0) out.add(all[3]);
    if (scores.alcoholScore == 0) out.add(all[4]);
    if (scores.stressScore == 0) out.add(all[5]);
    return out;
  }
}

/// 미래 얼굴(A/B) 탭: 슬라이더 아래 설문·GPU 시뮬 6축 전체 설명.
class SkinEditAllDomainsInsightsPanel extends StatelessWidget {
  const SkinEditAllDomainsInsightsPanel({
    super.key,
    required this.lifestyleData,
    required this.isDark,
    required this.accentColor,
    required this.titleColor,
    required this.mutedColor,
  });

  final Map<String, dynamic>? lifestyleData;
  final bool isDark;
  final Color accentColor;
  final Color titleColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final sections = SkinEditInsightsBuilder.allDomains(lifestyleData);
    final pad = Responsive.padding(context, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '설문·생활습관이 GPU 시뮬레이션에 어떻게 반영되는지',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 17),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: titleColor,
          ),
        ),
        SizedBox(height: pad * 0.5),
        Text(
          '이미지 생성 직후 skin-edit에 넣는 6가지 점수(자외선·수면·운동·흡연·음주·스트레스)와 같은 기준으로, '
          '영역별 설문 응답·과학 근거·시뮬에 나타날 수 있는 변화를 모두 정리했습니다.',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 13),
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: mutedColor,
          ),
        ),
        SizedBox(height: pad * 1.2),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: pad * 0.85),
          _SkinEditInsightCard(
            isDark: isDark,
            section: sections[i],
            accentColor: accentColor,
          ),
        ],
      ],
    );
  }
}

/// 리포트 생성 대기 중 — skin-edit 0점 항목만 과학 근거·영향 카드로 표시.
class ResultSkinEditZeroInsights extends StatefulWidget {
  const ResultSkinEditZeroInsights({
    super.key,
    required this.lifestyleData,
    required this.isDark,
    this.play = true,
  });

  final Map<String, dynamic>? lifestyleData;
  final bool isDark;
  final bool play;

  @override
  State<ResultSkinEditZeroInsights> createState() =>
      _ResultSkinEditZeroInsightsState();
}

class _ResultSkinEditZeroInsightsState extends State<ResultSkinEditZeroInsights>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.play) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections =
        SkinEditInsightsBuilder.zeroScoreOnly(widget.lifestyleData);
    final pad = Responsive.padding(context, 12);
    final muted =
        widget.isDark ? Colors.white60 : const Color(0xFF5C6560);
    final statusStyle = TextStyle(
      fontSize: Responsive.fontSize(context, 13.5),
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: muted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AI가 설문과 과학 근거를 바탕으로 건강 리포트를 작성하고 있어요. 완료되면 알려 드릴게요.',
          textAlign: TextAlign.center,
          style: statusStyle,
        ),
        if (sections.isNotEmpty) ...[
          SizedBox(height: pad * 1.25),
          ...List.generate(sections.length, (i) {
            final start = i * 0.18;
            final end = (start + 0.5).clamp(0.0, 1.0);
            final curved = CurvedAnimation(
              parent: _ctrl,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            );
            return Padding(
              padding: EdgeInsets.only(bottom: pad * 0.85),
              child: AnimatedBuilder(
                animation: curved,
                builder: (context, child) {
                  final t = curved.value;
                  return Transform.translate(
                    offset: Offset(0, (1 - t) * 48),
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: _SkinEditInsightCard(
                  isDark: widget.isDark,
                  section: sections[i],
                  accentColor: const Color(0xFF37EC13),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _SkinEditInsightCard extends StatelessWidget {
  const _SkinEditInsightCard({
    required this.isDark,
    required this.section,
    required this.accentColor,
  });

  final bool isDark;
  final SkinEditInsightSection section;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.padding(context, 14);
    final cardBg = isDark ? const Color(0xFF1A2C16) : Colors.white;
    final bodyColor = isDark ? Colors.grey[300]! : const Color(0xFF3D4540);
    final surveyBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF0F4F0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: accentColor,
            ),
          ),
          SizedBox(height: Responsive.padding(context, 10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 12),
              vertical: Responsive.padding(context, 10),
            ),
            decoration: BoxDecoration(
              color: surveyBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: Responsive.padding(context, 18),
                  color: accentColor.withValues(alpha: 0.85),
                ),
                SizedBox(width: Responsive.padding(context, 8)),
                Expanded(
                  child: Text(
                    '설문 응답: ${section.surveyLine}',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12.5),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.88)
                          : const Color(0xFF2A332E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 12)),
          for (final p in section.paragraphs) ...[
            Text(
              p,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 13),
                height: 1.42,
                color: bodyColor,
              ),
            ),
            SizedBox(height: Responsive.padding(context, 10)),
          ],
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              Responsive.padding(context, 12),
              Responsive.padding(context, 12),
              Responsive.padding(context, 12),
              Responsive.padding(context, 10),
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? accentColor.withValues(alpha: 0.08)
                  : Color.alphaBlend(
                      accentColor.withValues(alpha: 0.06),
                      const Color(0xFFEEF9EC),
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: accentColor.withValues(alpha: 0.75),
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이미지 시뮬레이션에 반영될 수 있는 변화',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: accentColor.withValues(alpha: 0.95),
                  ),
                ),
                SizedBox(height: Responsive.padding(context, 8)),
                ...section.impacts.map(
                  (line) => Padding(
                    padding: EdgeInsets.only(
                      bottom: Responsive.padding(context, 6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '· ',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 13),
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            height: 1.35,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 13),
                              fontWeight: FontWeight.w600,
                              height: 1.38,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : const Color(0xFF1A221C),
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
        ],
      ),
    );
  }
}
