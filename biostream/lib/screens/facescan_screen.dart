import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/responsive.dart';
import '../widgets/face_scanner_widget.dart';
import '../services/image_service.dart';
import 'survey_screen.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _scanController;
  final ImageService _imageService = ImageService();
  bool _isUploading = false;
  bool _isPickingImage = false;  // 이미지 피커 활성화 상태 추적

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

  Future<void> _onCamera() async {
    if (_isUploading || _isPickingImage) {
      debugPrint('[FaceScanScreen] 이미지 피커가 활성화되어 있습니다. 카메라 열기 취소');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      debugPrint('[FaceScanScreen] 카메라 버튼 클릭됨');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        debugPrint('[FaceScanScreen] 카메라에서 이미지 선택됨: ${image.path}');
        await _uploadAndNavigate(image);
      } else {
        debugPrint('[FaceScanScreen] 카메라에서 이미지 선택 취소됨');
      }
    } catch (e, stackTrace) {
      debugPrint('[FaceScanScreen] 카메라 오류: $e');
      debugPrint('[FaceScanScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카메라를 사용하는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _onGallery() async {
    if (_isUploading || _isPickingImage) {
      debugPrint('[FaceScanScreen] 이미지 피커가 활성화되어 있습니다. 갤러리 열기 취소');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      debugPrint('[FaceScanScreen] ===== 갤러리 버튼 클릭됨 =====');
      final ImagePicker picker = ImagePicker();
      
      debugPrint('[FaceScanScreen] 갤러리 열기 중...');
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        debugPrint('[FaceScanScreen] ✅ 갤러리에서 이미지 선택 완료!');
        debugPrint('[FaceScanScreen] 선택된 이미지 경로: ${image.path}');
        debugPrint('[FaceScanScreen] 선택된 이미지 이름: ${image.name}');
        debugPrint('[FaceScanScreen] 이미지 업로드 및 설문조사 페이지로 이동 시작...');
        await _uploadAndNavigate(image);
      } else {
        debugPrint('[FaceScanScreen] ❌ 갤러리에서 이미지 선택 취소됨');
      }
    } catch (e, stackTrace) {
      debugPrint('[FaceScanScreen] ❌ 갤러리 오류 발생: $e');
      debugPrint('[FaceScanScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('갤러리에서 이미지를 선택하는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _uploadAndNavigate(XFile image) async {
    if (!mounted) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 로딩 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      debugPrint('[FaceScanScreen] 이미지 업로드 시작: ${image.path}');
      // target_years는 기본값 30으로 설정 (나중에 SurveyScreen에서 수정 가능)
      final result = await _imageService.uploadImage(image, 30);

      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (result['success'] == true && mounted) {
        final originalImageUrl = result['original_image_url'] as String?;
        final savedPath = result['saved_path'] as String?;
        final finalImageUrl = originalImageUrl ?? savedPath;
        
        debugPrint('[FaceScanScreen] ===== 이미지 업로드 성공! =====');
        debugPrint('[FaceScanScreen] ✅ original_image_url: $originalImageUrl');
        debugPrint('[FaceScanScreen] ✅ saved_path: $savedPath');
        debugPrint('[FaceScanScreen] ✅ 최종 전달할 URL: $finalImageUrl');
        debugPrint('[FaceScanScreen] ✅ lifestyle_id: ${result['lifestyle_id']}');
        debugPrint('[FaceScanScreen] 설문조사 페이지로 이동 중...');
        
        // SurveyScreen으로 이동하며 original_image_url 전달
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SurveyScreen(
                originalImageUrl: finalImageUrl,
                showHomeButtonOnFirstPage: true,
              ),
            ),
          );
          debugPrint('[FaceScanScreen] ✅ 설문조사 페이지로 이동 완료!');
          debugPrint('[FaceScanScreen] 전달된 original_image_url: $finalImageUrl');
        }
      } else {
        debugPrint('[FaceScanScreen] 이미지 업로드 실패: ${result['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '이미지 업로드에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[FaceScanScreen] 이미지 업로드 오류: $e');
      debugPrint('[FaceScanScreen] 스택 트레이스: $stackTrace');
      
      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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
