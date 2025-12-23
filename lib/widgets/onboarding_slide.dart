import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/responsive.dart';

class OnboardingSlide extends StatelessWidget {
  final int slideIndex;

  const OnboardingSlide({super.key, required this.slideIndex});

  @override
  Widget build(BuildContext context) {
    switch (slideIndex) {
      case 0:
        return _Slide1();
      case 1:
        return _Slide2();
      case 2:
        return _Slide3();
      default:
        return _Slide1();
    }
  }
}

// Slide 1: AI로 미리 보는 10년 후 내 얼굴
class _Slide1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image Container
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background Image
                    Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBeITGKq5j-sHdMyN_GgekxyBnlmU569R5bfEprvrxNNw07O619OqY94CgAgjxKtNr-MYRLCOE1dPyZtgLgBm8iTZuX2UP_W5YuOsdUSQO1ZAjJdFFcGiSdIyr589uVyFovgwu9gZ1u8jiXhSq_EemJYz3JpPr-ds47SnS_TCd4MqZvxe0EKz7BR4b9JP74cLf5X-hicyWmitfN0aIlllPPBNY43e8xXCVhVUTdvP3P3EGoz6-EzE0EA4YjuZZCNZ3xKWy20RwE5lk',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image, size: 64, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                    
                    // Floating Label
                    Positioned(
                      top: Responsive.padding(context, 16),
                      left: Responsive.padding(context, 16),
                      right: Responsive.padding(context, 16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(context, 12),
                          vertical: Responsive.padding(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timelapse,
                              size: Responsive.iconSize(context, 16),
                              color: const Color(0xFF37EC13),
                            ),
                            SizedBox(width: Responsive.padding(context, 6)),
                            Text(
                              '+10 Years',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Scan Effect Overlay
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        painter: _ScanLinePainter(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: Responsive.padding(context, 24)),
          
          // Text Content
          Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 28),
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  children: const [
                    TextSpan(text: 'AI로 미리 보는\n'),
                    TextSpan(
                      text: '10년 후',
                      style: TextStyle(color: Color(0xFF37EC13)),
                    ),
                    TextSpan(text: ' 내 얼굴'),
                  ],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Text(
                '현재 얼굴과 10년 후의 얼굴을 비교해보세요.\n최첨단 AI가 당신의 미래를 예측합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  height: 1.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Scan Line Painter
class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF37EC13).withOpacity(0.5)
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.5);
    
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Slide 2: 오늘의 습관이 내일의 얼굴을 만듭니다
class _Slide2 extends StatefulWidget {
  @override
  State<_Slide2> createState() => _Slide2State();
}

class _Slide2State extends State<_Slide2> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image Container
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background Image
                    Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuADjPO4VDKcj3axpv_w4D4cCbqzF_46uE3fl8Wy0w-sYbAJ_rWfIgKVIyPrZYGMYjXDXvqHeh7mRGkxJvKA_Z8s-pmMm97OrIzNRnIQHxglFRk4D1E8zrkewZuojh-xUxCwAgF-TvNwIINM0WofW4A3WxPAc0FdOl5wWmXtI61vLysaQBx65xRPYlbCXPaNJXweRr63tMzgk_Gy_5Gm2L3_lkBsTEOUJvMdZtD8CvzfNiEne3-oCirNMxtdugBjWYLjBv30nhBM-jA',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.9),
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image, size: 64, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                    
                    // Gradient Overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark 
                                  ? const Color(0xFF132210) 
                                  : const Color(0xFFF6F8F6))
                                  .withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Floating Habit Icons
                    Positioned(
                      bottom: Responsive.padding(context, 48),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _BouncingIcon(
                            controller: _controller,
                            delay: 0,
                            icon: Icons.water_drop,
                            label: '수분',
                            color: Colors.blue,
                            isDark: isDark,
                          ),
                          _BouncingIcon(
                            controller: _controller,
                            delay: 150,
                            icon: Icons.wb_sunny,
                            label: '자외선',
                            color: const Color(0xFF37EC13),
                            isDark: isDark,
                          ),
                          _BouncingIcon(
                            controller: _controller,
                            delay: 300,
                            icon: Icons.bedtime,
                            label: '수면',
                            color: Colors.indigo,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: Responsive.padding(context, 24)),
          
          // Text Content
          Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 28),
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  children: [
                    const TextSpan(text: '오늘의 습관이\n내일의 '),
                    const TextSpan(
                      text: '얼굴',
                      style: TextStyle(color: Color(0xFF37EC13)),
                    ),
                    const TextSpan(text: '을 만듭니다'),
                  ],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Text(
                '작은 생활 습관이 피부에 미치는 영향,\n이제 눈으로 직접 확인하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  height: 1.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BouncingIcon extends StatelessWidget {
  final AnimationController controller;
  final int delay;
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _BouncingIcon({
    required this.controller,
    required this.delay,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final offset = math.sin(
          (controller.value * 2 * math.pi) + (delay / 1000),
        ) * 8;
        
        return Transform.translate(
          offset: Offset(0, offset),
          child: Column(
            children: [
              Container(
                width: Responsive.iconSize(context, 48),
                height: Responsive.iconSize(context, 48),
                decoration: BoxDecoration(
                  color: color == const Color(0xFF37EC13)
                      ? const Color(0xFF37EC13)
                      : (isDark ? Colors.grey[700] : Colors.white),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color == const Color(0xFF37EC13)
                      ? Colors.black
                      : color,
                  size: Responsive.iconSize(context, 24),
                ),
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 8),
                  vertical: Responsive.padding(context, 4),
                ),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white)
                      .withOpacity(0.8),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Slide 3: 데이터로 관리하는 스마트 안티에이징
class _Slide3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dashboard Container
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[900],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Abstract Background
                    Positioned.fill(
                      child: Image.network(
                        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?q=80&w=2070&auto=format&fit=crop',
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.3),
                        errorBuilder: (context, error, stackTrace) {
                          return Container(color: Colors.grey[800]);
                        },
                      ),
                    ),
                    
                    // Dashboard Card
                    Center(
                      child: Container(
                        margin: EdgeInsets.all(Responsive.padding(context, 24)),
                        padding: EdgeInsets.all(Responsive.padding(context, 24)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SKIN AGE',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 10),
                                        color: Colors.grey[300],
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: Responsive.padding(context, 4)),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '24.5',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, 24),
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: Responsive.padding(context, 4)),
                                        Text(
                                          '세',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, 14),
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.padding(context, 8),
                                    vertical: Responsive.padding(context, 4),
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF37EC13)
                                        .withOpacity(0.2),
                                    border: Border.all(
                                      color: const Color(0xFF37EC13)
                                          .withOpacity(0.5),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.trending_down,
                                        size: Responsive.iconSize(context, 14),
                                        color: const Color(0xFF37EC13),
                                      ),
                                      SizedBox(width: Responsive.padding(context, 4)),
                                      Text(
                                        '-2.4',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 10),
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF37EC13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: Responsive.padding(context, 24)),
                            
                            // Bar Chart
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final chartHeight = Responsive.fontSize(context, 110);
                                return SizedBox(
                                  height: chartHeight,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _BarItem(
                                        height: 0.4,
                                        label: 'Apr',
                                        isActive: false,
                                        chartHeight: chartHeight,
                                      ),
                                      _BarItem(
                                        height: 0.55,
                                        label: 'May',
                                        isActive: false,
                                        chartHeight: chartHeight,
                                      ),
                                      _BarItem(
                                        height: 0.45,
                                        label: 'Jun',
                                        isActive: false,
                                        chartHeight: chartHeight,
                                      ),
                                      _BarItem(
                                        height: 0.8,
                                        label: 'Today',
                                        isActive: true,
                                        chartHeight: chartHeight,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: Responsive.padding(context, 24)),
          
          // Text Content
          Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 28),
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  children: [
                    const TextSpan(text: '데이터로 관리하는\n스마트 '),
                    const TextSpan(
                      text: '안티에이징',
                      style: TextStyle(color: Color(0xFF37EC13)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Text(
                '감에 의존하지 마세요.\n객관적인 수치로 피부 건강을 지키세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  height: 1.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final double height;
  final String label;
  final bool isActive;
  final double chartHeight;

  const _BarItem({
    required this.height,
    required this.label,
    required this.isActive,
    required this.chartHeight,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = chartHeight * height;
    
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 4),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Bar
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF37EC13)
                    : Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF37EC13).withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            ),
            // Label above bar
            Positioned(
              bottom: barHeight + Responsive.padding(context, 4),
              child: isActive
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 6),
                        vertical: Responsive.padding(context, 2),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 10),
                        color: Colors.grey[300],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

