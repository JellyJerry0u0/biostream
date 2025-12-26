import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../widgets/face_scanner_widget.dart';
import 'survey_screen.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController?.dispose();
    super.dispose();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  void _onSkip() {
    // TODO: Navigate to main app
    debugPrint('Skip tapped');
  }

  void _onCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SurveyScreen(),
      ),
    );
  }

  void _onGallery() {
    // TODO: Open gallery
    debugPrint('Gallery tapped');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Navigation Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 20),
                vertical: Responsive.padding(context, 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  Material(
                    color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                    borderRadius: BorderRadius.circular(9999),
                    child: InkWell(
                      onTap: _onBack,
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: EdgeInsets.all(Responsive.padding(context, 8)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : Colors.black87,
                          size: Responsive.iconSize(context, 20),
                        ),
                      ),
                    ),
                  ),

                  // Progress Indicator
                  Row(
                    children: [
                      Container(
                        width: Responsive.fontSize(context, 32),
                        height: Responsive.fontSize(context, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF37EC13),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                      SizedBox(width: Responsive.padding(context, 6)),
                      Container(
                        width: Responsive.fontSize(context, 8),
                        height: Responsive.fontSize(context, 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                      SizedBox(width: Responsive.padding(context, 6)),
                      Container(
                        width: Responsive.fontSize(context, 8),
                        height: Responsive.fontSize(context, 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ],
                  ),

                  // Skip Button
                  TextButton(
                    onPressed: _onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.grey[400] : Colors.grey[600],
                      padding: EdgeInsets.all(Responsive.padding(context, 8)),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Scroll Area
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: Responsive.padding(context, 8)),

                    // Hero Title
                    Column(
                      children: [
                        Text(
                          '얼굴 스캔 시작',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 28),
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: Responsive.padding(context, 12)),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.padding(context, 16),
                          ),
                          child: Text(
                            'AI가 현재 피부 상태를 분석하고\n미래의 얼굴 변화를 예측합니다.',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 40)),

                    // Scanner Visual
                    _scanController != null
                        ? FaceScannerWidget(
                            scanController: _scanController!,
                            isDark: isDark,
                          )
                        : const SizedBox.shrink(),

                    SizedBox(height: Responsive.padding(context, 40)),

                    // Guidelines Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '촬영 가이드',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 18),
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.padding(context, 12),
                                vertical: Responsive.padding(context, 4),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF37EC13).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                '정확도 98% 향상',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF37EC13),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: Responsive.padding(context, 16)),

                        // Guideline Cards
                        Row(
                          children: [
                            Expanded(
                              child: _GuidelineCard(
                                icon: Icons.wb_sunny,
                                title: '밝은 조명',
                                description: '얼굴 전체가 잘 보이도록',
                                isGood: true,
                                isDark: isDark,
                              ),
                            ),
                            SizedBox(width: Responsive.padding(context, 12)),
                            Expanded(
                              child: _GuidelineCard(
                                icon: Icons.face_retouching_off,
                                title: '안경/마스크',
                                description: '착용하지 않은 상태',
                                isGood: false,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: Responsive.padding(context, 16)),

                        // Info Alert
                        Container(
                          padding:
                              EdgeInsets.all(Responsive.padding(context, 16)),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1C2E18) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: Responsive.iconSize(context, 20),
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              SizedBox(width: Responsive.padding(context, 12)),
                              Expanded(
                                child: Text(
                                  '정면을 바라보고 무표정으로 촬영해주세요. 화장이 진하거나 머리카락이 얼굴을 가리면 분석이 어려울 수 있습니다.',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 120)),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Action Area
            Container(
              padding: EdgeInsets.all(horizontalPadding),
              decoration: BoxDecoration(
                color:
                    (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                        .withOpacity(0.95),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Camera Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.fontSize(context, 56),
                    child: ElevatedButton(
                      onPressed: _onCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37EC13),
                        foregroundColor: const Color(0xFF101B0D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFF37EC13).withOpacity(0.25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: Responsive.iconSize(context, 20),
                          ),
                          SizedBox(width: Responsive.padding(context, 8)),
                          Text(
                            '카메라 실행하기',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 16),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.padding(context, 12)),

                  // Gallery Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.fontSize(context, 56),
                    child: OutlinedButton(
                      onPressed: _onGallery,
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.grey[200] : Colors.grey[700],
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: Responsive.iconSize(context, 20),
                          ),
                          SizedBox(width: Responsive.padding(context, 8)),
                          Text(
                            '갤러리에서 선택',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 16),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.padding(context, 16)),

                  // Privacy Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock,
                        size: Responsive.iconSize(context, 12),
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                      SizedBox(width: Responsive.padding(context, 6)),
                      Text(
                        '사진은 암호화되어 안전하게 처리됩니다',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Guideline Card Widget
class _GuidelineCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGood;
  final bool isDark;

  const _GuidelineCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGood,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2E18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: Responsive.padding(context, 12),
            right: Responsive.padding(context, 12),
            child: Icon(
              isGood ? Icons.check_circle : Icons.cancel,
              color: isGood
                  ? const Color(0xFF37EC13)
                  : (isDark ? Colors.grey[400] : Colors.grey[400]),
              size: Responsive.iconSize(context, 18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: Responsive.fontSize(context, 40),
                height: Responsive.fontSize(context, 40),
                decoration: BoxDecoration(
                  color: isGood
                      ? const Color(0xFF37EC13).withOpacity(0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGood
                      ? const Color(0xFF37EC13)
                      : (isDark ? Colors.grey[400] : Colors.grey[500]),
                  size: Responsive.iconSize(context, 20),
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 4)),
              Text(
                description,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
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
