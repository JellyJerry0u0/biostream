import 'package:flutter/material.dart';

import '../../screens/today_me/today_me_models.dart';

class TodayMeContent extends StatelessWidget {
  const TodayMeContent({
    super.key,
    required this.primaryColor,
    required this.pageController,
    required this.faceCards,
    required this.activeFaceIndex,
    required this.onPageChanged,
    required this.metrics,
    required this.metricsNotice,
    required this.onRecordTap,
    required this.onCalendarTap,
    required this.onNotificationTap,
    required this.headerSlide,
    required this.headerOpacity,
    required this.carouselSlide,
    required this.carouselOpacity,
    required this.metricsSlide,
    required this.metricsOpacity,
    required this.recordOpacity,
    required this.bottomPadding,
  });

  final Color primaryColor;
  final PageController pageController;
  final List<FaceCardItem> faceCards;
  final int activeFaceIndex;
  final ValueChanged<int> onPageChanged;
  final List<MetricItem> metrics;
  final String? metricsNotice;
  final VoidCallback onRecordTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onNotificationTap;
  final Animation<Offset> headerSlide;
  final Animation<double> headerOpacity;
  final Animation<Offset> carouselSlide;
  final Animation<double> carouselOpacity;
  final Animation<Offset> metricsSlide;
  final Animation<double> metricsOpacity;
  final Animation<double> recordOpacity;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlideTransition(
            position: headerSlide,
            child: FadeTransition(
              opacity: headerOpacity,
              child: _buildHeader(),
            ),
          ),
          const SizedBox(height: 4),
          SlideTransition(
            position: carouselSlide,
            child: FadeTransition(
              opacity: carouselOpacity,
              child: Column(
                children: [
                  _buildFaceCarousel(),
                  _buildIndicator(),
                ],
              ),
            ),
          ),
          SlideTransition(
            position: metricsSlide,
            child: FadeTransition(
              opacity: metricsOpacity,
              child: _buildMetricsPanel(),
            ),
          ),
          FadeTransition(
            opacity: recordOpacity,
            child: _buildRecordButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2024년 5월 24일',
                  style: TextStyle(
                    color: Color(0xFF7A8380),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '오늘의 나',
                  style: TextStyle(
                    color: Color(0xFF102217),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _roundIconButton(icon: Icons.calendar_today, onTap: onCalendarTap),
          const SizedBox(width: 8),
          _roundIconButton(
              icon: Icons.notifications_none, onTap: onNotificationTap),
        ],
      ),
    );
  }

  Widget _buildFaceCarousel() {
    return SizedBox(
      height: 470,
      child: PageView.builder(
        controller: pageController,
        itemCount: faceCards.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final item = faceCards[index];
          final isActive = activeFaceIndex == index;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isActive ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(item.imageUrl, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.highlight
                                  ? primaryColor
                                  : Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: item.highlight
                                    ? const Color(0xFF102217)
                                    : const Color(0xFF7A8380),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(faceCards.length, (index) {
          final isActive = activeFaceIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 4,
            width: isActive ? 22 : 6,
            decoration: BoxDecoration(
              color: isActive ? primaryColor : const Color(0xFFE3ECE7),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '어제의 나의 활동',
                        style: TextStyle(
                          color: Color(0xFF102217),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '종합 건강 지표 분석',
                        style: TextStyle(
                          color: Color(0xFF92A29B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'YESTERDAY',
                    style: TextStyle(
                      color: Color(0xFF16984B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (metricsNotice != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6FAF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3ECE7)),
                ),
                child: Text(
                  metricsNotice!,
                  style: const TextStyle(
                    color: Color(0xFF6B7E75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.48,
              ),
              itemBuilder: (context, index) {
                final metric = metrics[index];
                if (metric.wide) {
                  return GridTile(child: _MetricCard(metric: metric));
                }
                return _MetricCard(metric: metric);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: InkWell(
        onTap: onRecordTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF102217),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: Color(0x302BEE75),
                child: Icon(Icons.add_a_photo, color: Color(0xFF2BEE75)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 얼굴 기록하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '오후 세션 기록이 아직 없습니다',
                      style: TextStyle(
                        color: Color(0xFFA7B5AE),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Color(0xFFA7B5AE), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primaryColor.withValues(alpha: 0.09),
        ),
        child: Icon(icon, color: const Color(0xFF102217), size: 20),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final MetricItem metric;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(metric.icon, color: const Color(0xFF2BEE75), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    metric.label,
                    style: const TextStyle(
                      color: Color(0xFF7A8380),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  metric.value,
                  style: const TextStyle(
                    color: Color(0xFF102217),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    metric.unit,
                    style: const TextStyle(
                      color: Color(0xFF96A09B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
