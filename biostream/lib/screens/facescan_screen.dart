import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/responsive.dart';
import '../widgets/facescan/facescan_bottom_actions.dart';
import '../widgets/facescan/facescan_header.dart';
import '../widgets/facescan/facescan_main_content.dart';
import '../services/image_service.dart';
import 'facescan/facescan_controller.dart';
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
  late final FaceScanController _faceScanController = FaceScanController(
    imageService: _imageService,
  );
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _isPickingImage = false; // 이미지 피커 활성화 상태 추적

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
    await _pickImageAndUpload(
      source: ImageSource.camera,
      sourceLabel: '카메라',
      errorPrefix: '카메라를 사용하는 중 오류가 발생했습니다',
    );
  }

  Future<void> _onGallery() async {
    await _pickImageAndUpload(
      source: ImageSource.gallery,
      sourceLabel: '갤러리',
      errorPrefix: '갤러리에서 이미지를 선택하는 중 오류가 발생했습니다',
    );
  }

  Future<void> _pickImageAndUpload({
    required ImageSource source,
    required String sourceLabel,
    required String errorPrefix,
  }) async {
    if (_isUploading || _isPickingImage) {
      debugPrint('[FaceScanScreen] 이미지 피커가 활성화되어 있습니다. $sourceLabel 열기 취소');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      debugPrint('[FaceScanScreen] ===== $sourceLabel 버튼 클릭됨 =====');
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        debugPrint('[FaceScanScreen] ✅ $sourceLabel에서 이미지 선택 완료!');
        debugPrint('[FaceScanScreen] 선택된 이미지 경로: ${image.path}');
        debugPrint('[FaceScanScreen] 선택된 이미지 이름: ${image.name}');
        debugPrint('[FaceScanScreen] 이미지 업로드 및 설문조사 페이지로 이동 시작...');
        await _uploadAndNavigate(image);
      } else {
        debugPrint('[FaceScanScreen] ❌ $sourceLabel에서 이미지 선택 취소됨');
      }
    } catch (e, stackTrace) {
      debugPrint('[FaceScanScreen] ❌ $sourceLabel 오류 발생: $e');
      debugPrint('[FaceScanScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorPrefix: $e'),
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
      final result = await _faceScanController.uploadForSurvey(image);

      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (result.success && mounted) {
        debugPrint('[FaceScanScreen] ===== 이미지 업로드 성공! =====');
        debugPrint('[FaceScanScreen] ✅ 최종 전달할 URL: ${result.originalImageUrl}');
        debugPrint('[FaceScanScreen] ✅ lifestyle_id: ${result.lifestyleId}');
        debugPrint('[FaceScanScreen] 설문조사 페이지로 이동 중...');

        // SurveyScreen으로 이동하며 original_image_url 전달
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SurveyScreen(
                originalImageUrl: result.originalImageUrl,
                showHomeButtonOnFirstPage: true,
              ),
            ),
          );
          debugPrint('[FaceScanScreen] ✅ 설문조사 페이지로 이동 완료!');
          debugPrint(
              '[FaceScanScreen] 전달된 original_image_url: ${result.originalImageUrl}');
        }
      } else {
        debugPrint('[FaceScanScreen] 이미지 업로드 실패: ${result.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? '이미지 업로드에 실패했습니다.'),
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
            FaceScanHeader(
              isDark: isDark,
              onBack: _onBack,
              onSkip: _onSkip,
            ),
            FaceScanMainContent(
              isDark: isDark,
              horizontalPadding: horizontalPadding,
              scanController: _scanController,
            ),
            FaceScanBottomActions(
              isDark: isDark,
              horizontalPadding: horizontalPadding,
              onCamera: _onCamera,
              onGallery: _onGallery,
            ),
          ],
        ),
      ),
    );
  }
}
