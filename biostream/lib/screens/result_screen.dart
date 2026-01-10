import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/lifestyle_service.dart';
import 'coach_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final LifestyleService _lifestyleService = LifestyleService();
  Map<String, dynamic>? _lifestyleData;
  String? _healthReport;
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDataAndGenerateReport();
  }

  Future<void> _loadDataAndGenerateReport() async {
    setState(() {
      _isLoading = true;
      _isGeneratingReport = false;
      _errorMessage = null;
    });

    try {
      // 1. Lifestyle 데이터 로드
      final lifestyleResult = await _lifestyleService.getLifestyleData();
      debugPrint('🔍 Lifestyle 데이터 로드 결과: $lifestyleResult');
      
      if (lifestyleResult['success'] == true && lifestyleResult['data'] != null) {
        debugPrint('✅ 데이터 로드 성공: ${lifestyleResult['data']}');
        setState(() {
          _lifestyleData = lifestyleResult['data'];
          _isLoading = false;
          _isGeneratingReport = true; // 리포트 생성 시작
        });
        
        // 2. LLM을 사용하여 건강 리포트 생성
        await _generateHealthReport();
      } else {
        debugPrint('❌ 데이터 로드 실패: ${lifestyleResult['message']}');
        setState(() {
          _errorMessage = lifestyleResult['message'] ?? '데이터를 불러올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      setState(() {
        _errorMessage = '데이터 로드 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateHealthReport() async {
    try {
      debugPrint('🤖 건강 리포트 생성 시작...');
      final result = await _lifestyleService.generateHealthReport();
      
      if (result['success'] == true && result['report'] != null) {
        debugPrint('✅ 건강 리포트 생성 성공');
        setState(() {
          _healthReport = result['report'];
          _isGeneratingReport = false;
        });
      } else {
        debugPrint('❌ 건강 리포트 생성 실패: ${result['message']}');
        setState(() {
          _healthReport = result['message'] ?? '건강 리포트를 생성할 수 없습니다.';
          _isGeneratingReport = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 리포트 생성 에러: $e');
      debugPrint('스택 트레이스: $stackTrace');
      setState(() {
        _healthReport = '건강 리포트 생성 중 오류가 발생했습니다: $e';
        _isGeneratingReport = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 16);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(horizontalPadding),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                    .withOpacity(0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back,
                          size: Responsive.iconSize(context, 24),
                          color: isDark ? Colors.white : const Color(0xFF101B0D),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Results',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF101B0D),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // TODO: Share functionality
                        debugPrint('Share tapped');
                      },
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.share,
                          size: Responsive.iconSize(context, 24),
                          color: isDark ? Colors.white : const Color(0xFF101B0D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF37EC13),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: Responsive.iconSize(context, 48),
                                color: Colors.red,
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 16),
                                  color: isDark ? Colors.white : const Color(0xFF101B0D),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              ElevatedButton(
                                onPressed: _loadDataAndGenerateReport,
                                child: Text('다시 시도'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Column(
                            children: [
                              SizedBox(height: Responsive.padding(context, 8)),

                              // Title
                              Text(
                                'Aging Simulation',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 24),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF101B0D),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: Responsive.padding(context, 24)),

                    // Age Comparison
                    Row(
                      children: [
                        // Current Age
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: Responsive.fontSize(context, 80),
                                height: Responsive.fontSize(context, 80),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(19.2),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Icon(
                                        Icons.face_3,
                                        size: Responsive.iconSize(context, 32),
                                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topRight,
                                            end: Alignment.bottomLeft,
                                            colors: [
                                              Colors.black.withOpacity(0.1),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 8)),
                              Text(
                                _lifestyleData?['profile']?['age'] != null
                                    ? 'Now (${_lifestyleData!['profile']['age'].toString().split(' ')[0]})'
                                    : 'Now',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Arrow
                        Expanded(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 2,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: Responsive.padding(context, 16),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.grey[300],
                                      border: Border(
                                        top: BorderSide(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.2)
                                              : Colors.grey[300]!,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.padding(context, 12),
                                      vertical: Responsive.padding(context, 4),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                                    ),
                                    child: Icon(
                                      Icons.double_arrow,
                                      size: Responsive.iconSize(context, 18),
                                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Target Age
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: Responsive.fontSize(context, 80),
                                height: Responsive.fontSize(context, 80),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [Colors.white, Colors.grey[200]!]
                                        : [const Color(0xFF101B0D), const Color(0xFF1F3519)],
                                  ),
                                  borderRadius: BorderRadius.circular(19.2),
                                  border: Border.all(
                                    color: const Color(0xFF37EC13),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF37EC13).withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        _getTargetAge(),
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 28),
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFF101B0D) : Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF37EC13).withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 8)),
                              Text(
                                'Target Age',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF37EC13),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 8)),

                    // Comparison Images
                    SizedBox(
                      height: Responsive.fontSize(context, 416),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              // Left Image - Managed
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(32),
                                      bottomLeft: Radius.circular(32),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF37EC13).withOpacity(0.5),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF37EC13).withOpacity(0.15),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      // Background Image - Original Image
                                      Positioned.fill(
                                        child: _buildImageWidget(
                                          _lifestyleData?['images']?['original_image_url'],
                                        ),
                                      ),
                                      // Gradient Overlay
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.1),
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.9),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Badge
                                      Positioned(
                                        top: Responsive.padding(context, 12),
                                        left: Responsive.padding(context, 12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.padding(context, 8),
                                            vertical: Responsive.padding(context, 4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF37EC13),
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: Responsive.iconSize(context, 12),
                                                color: const Color(0xFF101B0D),
                                              ),
                                              SizedBox(width: Responsive.padding(context, 4)),
                                              Text(
                                                'Managed O',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(context, 10),
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF101B0D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Bottom Text
                                      Positioned(
                                        bottom: Responsive.padding(context, 20),
                                        left: Responsive.padding(context, 16),
                                        right: Responsive.padding(context, 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Youthful',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 20),
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.0,
                                              ),
                                            ),
                                            SizedBox(height: Responsive.padding(context, 4)),
                                            Text(
                                              'Skin Age: ${_calculateManagedSkinAge(_getCurrentAge(), _getTargetYears())}',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 10),
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF37EC13),
                                                letterSpacing: 2.0,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Right Image - Not Managed
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(32),
                                      bottomRight: Radius.circular(32),
                                    ),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      // Background Image - Generated Image
                                      Positioned.fill(
                                        child: ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            const Color(0xFF8B6914).withOpacity(0.2),
                                            BlendMode.overlay,
                                          ),
                                          child: _buildImageWidget(
                                            _lifestyleData?['images']?['generated_image_url'],
                                          ),
                                        ),
                                      ),
                                      // Gradient Overlay
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.9),
                                                Colors.black.withOpacity(0.1),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Badge
                                      Positioned(
                                        top: Responsive.padding(context, 12),
                                        right: Responsive.padding(context, 12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.padding(context, 8),
                                            vertical: Responsive.padding(context, 4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[600],
                                            borderRadius: BorderRadius.circular(9999),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.close,
                                                size: Responsive.iconSize(context, 12),
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: Responsive.padding(context, 4)),
                                              Text(
                                                'Managed X',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(context, 10),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Bottom Text
                                      Positioned(
                                        bottom: Responsive.padding(context, 20),
                                        left: Responsive.padding(context, 16),
                                        right: Responsive.padding(context, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Aged',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 20),
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.0,
                                              ),
                                            ),
                                            SizedBox(height: Responsive.padding(context, 4)),
                                            Text(
                                              'Skin Age: ${_calculateUnmanagedSkinAge(_getCurrentAge(), _getTargetYears())}',
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 10),
                                                fontWeight: FontWeight.w500,
                                                color: Colors.red[400],
                                                letterSpacing: 2.0,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // VS Badge
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 8)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A4025) : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.2)
                                        : Colors.grey[100]!,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 8)),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(Responsive.padding(context, 16)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.red[900]!.withOpacity(0.1)
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.red[900]!.withOpacity(0.3)
                                    : Colors.red[100]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.face_retouching_off,
                                      size: Responsive.iconSize(context, 20),
                                      color: isDark ? Colors.red[400] : Colors.red[700],
                                    ),
                                    SizedBox(width: Responsive.padding(context, 8)),
                                    Text(
                                      'Visual Gap',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 10),
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.red[300]!.withOpacity(0.7)
                                            : Colors.red[600]!.withOpacity(0.7),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  '${_getVisualGap()} Yrs',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 28),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.red[100] : Colors.red[900],
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  'Difference in apparent age',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.red[400] : Colors.red[600],
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 12)),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(Responsive.padding(context, 16)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green[900]!.withOpacity(0.1)
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.green[900]!.withOpacity(0.3)
                                    : Colors.green[100]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      size: Responsive.iconSize(context, 20),
                                      color: isDark ? Colors.green[400] : Colors.green[700],
                                    ),
                                    SizedBox(width: Responsive.padding(context, 8)),
                                    Text(
                                      'Potential',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 10),
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.green[300]!.withOpacity(0.7)
                                            : Colors.green[600]!.withOpacity(0.7),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  '-${_getPotentialPercentage().toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 28),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.green[100] : Colors.green[900],
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: Responsive.padding(context, 8)),
                                Text(
                                  'Less wrinkles with care',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.green[400] : Colors.green[700],
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 16)),

                    // Health Report Section (LLM 생성 리포트) - Critical Factors 앞에 표시
                    if (_healthReport != null || _isGeneratingReport)
                      Container(
                        margin: EdgeInsets.only(bottom: Responsive.padding(context, 16)),
                        padding: EdgeInsets.all(Responsive.padding(context, 20)),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A2C17) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey[100]!,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.medical_services,
                                  size: Responsive.iconSize(context, 24),
                                  color: const Color(0xFF37EC13),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Text(
                                  'AI 건강 리포트',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 18),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            if (_isGeneratingReport)
                              Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: const Color(0xFF37EC13),
                                    ),
                                    SizedBox(height: Responsive.padding(context, 16)),
                                    Text(
                                      'AI가 건강 리포트를 생성하고 있습니다...',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_healthReport != null)
                              Container(
                                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.2)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SelectableText(
                                  _healthReport!,
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 14),
                                    height: 1.6,
                                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Critical Factors Section
                    Container(
                      padding: EdgeInsets.all(Responsive.padding(context, 20)),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A2C17) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey[100]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Critical Factors',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 18),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.padding(context, 8),
                                  vertical: Responsive.padding(context, 4),
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Impact Score',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.padding(context, 16)),
                          // Collagen Preservation
                          Builder(
                            builder: (context) {
                              final collagenImpact = _getCollagenPreservationImpact();
                              final impactColor = _getImpactColor(collagenImpact['level']);
                              final impactScore = collagenImpact['score'] as double;
                              
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Collagen Preservation',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 14),
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        collagenImpact['label'],
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 14),
                                          fontWeight: FontWeight.bold,
                                          color: impactColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: Responsive.padding(context, 6)),
                                  Container(
                                    height: Responsive.fontSize(context, 8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor: impactScore.clamp(0.0, 1.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: impactColor,
                                              borderRadius: BorderRadius.circular(9999),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: impactColor.withOpacity(0.5),
                                                  blurRadius: 10,
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: Responsive.padding(context, 16)),
                          // UV Damage Control
                          Builder(
                            builder: (context) {
                              final uvImpact = _getUVDamageControlImpact();
                              final impactColor = _getImpactColor(uvImpact['level']);
                              final impactScore = uvImpact['score'] as double;
                              
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'UV Damage Control',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 14),
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        uvImpact['label'],
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 14),
                                          fontWeight: FontWeight.bold,
                                          color: impactColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: Responsive.padding(context, 6)),
                                  Container(
                                    height: Responsive.fontSize(context, 8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor: impactScore.clamp(0.0, 1.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: impactColor,
                                              borderRadius: BorderRadius.circular(9999),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),

                    // Action Buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: Responsive.fontSize(context, 56),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const CoachScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF37EC13),
                              foregroundColor: const Color(0xFF101B0D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              elevation: 0,
                              shadowColor: const Color(0xFF37EC13).withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View Action Plan',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 18),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Icon(
                                  Icons.arrow_forward,
                                  size: Responsive.iconSize(context, 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 12)),
                        SizedBox(
                          width: double.infinity,
                          height: Responsive.fontSize(context, 56),
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Save comparison
                              debugPrint('Save Comparison tapped');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF101B0D),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.grey[200]!,
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
                                  Icons.download,
                                  size: Responsive.iconSize(context, 20),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Text(
                                  'Save Comparison',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 16),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.padding(context, 24)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTargetAge() {
    if (_lifestyleData?['target_age'] != null) {
      final targetAgeStr = _lifestyleData!['target_age'].toString();
      // "X years after" 형식에서 숫자 추출
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        final years = int.tryParse(match.group(1) ?? '');
        if (years != null && _lifestyleData?['profile']?['age'] != null) {
          final currentAgeStr = _lifestyleData!['profile']['age'].toString().split(' ')[0];
          final currentAge = int.tryParse(currentAgeStr) ?? 0;
          return '${currentAge + years}';
        }
      }
    }
    return '65'; // 기본값
  }

  // 현재 나이 가져오기
  int _getCurrentAge() {
    if (_lifestyleData?['profile']?['age'] != null) {
      final ageStr = _lifestyleData!['profile']['age'].toString().split(' ')[0];
      return int.tryParse(ageStr) ?? 29;
    }
    return 29; // 기본값
  }

  // 타겟 연도 가져오기
  int _getTargetYears() {
    if (_lifestyleData?['target_age'] != null) {
      final targetAgeStr = _lifestyleData!['target_age'].toString();
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 36;
      }
    }
    return 36; // 기본값 (29 + 36 = 65)
  }

  // 생활습관 기반 피부 나이 가산점 계산 (관리했을 때)
  int _calculateManagedSkinAge(int currentAge, int targetYears) {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) return currentAge + (targetYears ~/ 2);

    int agingFactor = 0;

    // 흡연 요인
    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        agingFactor += targetYears ~/ 3; // 현재 흡연은 피부 나이 증가
      } else if (status.contains('과거') || status.contains('past')) {
        agingFactor += targetYears ~/ 5; // 과거 흡연은 약간 증가
      }
    }

    // 운동 요인
    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType = exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        agingFactor += targetYears ~/ 4;
      }
      
      final dailyMins = exercise['daily_exercise_minutes'];
      if (dailyMins != null) {
        final minsStr = dailyMins.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final mins = int.tryParse(minsStr) ?? 0;
        if (mins < 30) {
          agingFactor += targetYears ~/ 6;
        }
      }
    }

    // 수면 요인
    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr = sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          agingFactor += targetYears ~/ 6;
        }
      }
    }

    // 자외선 노출 요인
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none') || sunscreen.contains('가끔')) {
        agingFactor += targetYears ~/ 2; // 자외선 차단제 미사용은 큰 영향
      }
    }

    // 음주 요인
    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency = drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        agingFactor += targetYears ~/ 4;
      } else if (frequency.contains('주3') || frequency.contains('주4')) {
        agingFactor += targetYears ~/ 5;
      }
    }

    // 관리했을 때는 가산점의 일부만 적용 (관리 효과 반영)
    final managedAge = currentAge + (agingFactor ~/ 3) + (targetYears ~/ 2);
    return managedAge;
  }

  // 생활습관 기반 피부 나이 가산점 계산 (관리하지 않았을 때)
  int _calculateUnmanagedSkinAge(int currentAge, int targetYears) {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) return currentAge + targetYears;

    int agingFactor = 0;

    // 흡연 요인
    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        agingFactor += targetYears ~/ 2; // 현재 흡연은 큰 영향
      } else if (status.contains('과거') || status.contains('past')) {
        agingFactor += targetYears ~/ 3;
      }
    }

    // 운동 요인
    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType = exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        agingFactor += targetYears ~/ 2;
      }
      
      final dailyMins = exercise['daily_exercise_minutes'];
      if (dailyMins != null) {
        final minsStr = dailyMins.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final mins = int.tryParse(minsStr) ?? 0;
        if (mins < 30) {
          agingFactor += targetYears ~/ 3;
        }
      }
    }

    // 수면 요인
    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr = sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          agingFactor += targetYears ~/ 3;
        }
      }
    }

    // 자외선 노출 요인 (가장 큰 영향)
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none')) {
        agingFactor += targetYears; // 자외선 차단제 미사용은 매우 큰 영향
      } else if (sunscreen.contains('가끔')) {
        agingFactor += targetYears ~/ 2;
      }
    }

    // 음주 요인
    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency = drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        agingFactor += targetYears ~/ 2;
      } else if (frequency.contains('주3') || frequency.contains('주4')) {
        agingFactor += targetYears ~/ 3;
      }
    }

    // 관리하지 않았을 때는 가산점을 모두 적용
    final unmanagedAge = currentAge + agingFactor + targetYears;
    return unmanagedAge;
  }

  // Visual Gap 계산 (피부 나이 차이)
  int _getVisualGap() {
    final currentAge = _getCurrentAge();
    final targetYears = _getTargetYears();
    final managedAge = _calculateManagedSkinAge(currentAge, targetYears);
    final unmanagedAge = _calculateUnmanagedSkinAge(currentAge, targetYears);
    return (unmanagedAge - managedAge).abs();
  }

  // Potential 계산 (개선 가능 퍼센트)
  double _getPotentialPercentage() {
    final currentAge = _getCurrentAge();
    final targetYears = _getTargetYears();
    final managedAge = _calculateManagedSkinAge(currentAge, targetYears);
    final unmanagedAge = _calculateUnmanagedSkinAge(currentAge, targetYears);
    
    if (unmanagedAge == 0) return 0.0;
    final difference = unmanagedAge - managedAge;
    final percentage = (difference / unmanagedAge) * 100;
    return percentage.abs();
  }

  // Critical Factors 계산 - 콜라겐 보존 영향도
  Map<String, dynamic> _getCollagenPreservationImpact() {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) {
      return {'level': 'medium', 'score': 0.5, 'label': 'Medium Impact'};
    }

    double impactScore = 0.0;
    int factorCount = 0;

    // 흡연 요인
    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        impactScore += 0.9;
        factorCount++;
      } else if (status.contains('과거') || status.contains('past')) {
        impactScore += 0.5;
        factorCount++;
      }
    }

    // 운동 요인
    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType = exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        impactScore += 0.7;
        factorCount++;
      }
    }

    // 수면 요인
    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr = sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          impactScore += 0.6;
          factorCount++;
        }
      }
    }

    // 음주 요인
    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency = drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        impactScore += 0.8;
        factorCount++;
      }
    }

    final normalizedScore = factorCount > 0 ? impactScore / factorCount : 0.0;

    if (normalizedScore >= 0.7) {
      return {'level': 'high', 'score': normalizedScore, 'label': 'High Impact'};
    } else if (normalizedScore >= 0.4) {
      return {'level': 'medium', 'score': normalizedScore, 'label': 'Medium Impact'};
    } else {
      return {'level': 'low', 'score': normalizedScore, 'label': 'Low Impact'};
    }
  }

  // Critical Factors 계산 - 자외선 손상 관리 영향도
  Map<String, dynamic> _getUVDamageControlImpact() {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) {
      return {'level': 'medium', 'score': 0.5, 'label': 'Medium Impact'};
    }

    double impactScore = 0.0;

    // 자외선 차단제 사용
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none')) {
        impactScore = 0.9; // 매우 높은 영향
      } else if (sunscreen.contains('가끔')) {
        impactScore = 0.6; // 중간 영향
      } else if (sunscreen.contains('매일') || sunscreen.contains('daily')) {
        impactScore = 0.2; // 낮은 영향 (잘 관리)
      }
    }

    if (impactScore >= 0.7) {
      return {'level': 'high', 'score': impactScore, 'label': 'High Impact'};
    } else if (impactScore >= 0.4) {
      return {'level': 'medium', 'score': impactScore, 'label': 'Medium Impact'};
    } else {
      return {'level': 'low', 'score': impactScore, 'label': 'Low Impact'};
    }
  }

  // 영향도 색상 가져오기
  Color _getImpactColor(String level) {
    switch (level) {
      case 'high':
        return Colors.red[500]!;
      case 'medium':
        return Colors.yellow[500]!;
      case 'low':
        return Colors.green[500]!;
      default:
        return Colors.grey[500]!;
    }
  }

  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.image, size: Responsive.iconSize(context, 64), color: Colors.grey),
        ),
      );
    }

    // 서버 URL을 통해 이미지 로드
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: const Color(0xFF37EC13),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.image, size: Responsive.iconSize(context, 64), color: Colors.grey),
          ),
        );
      },
    );
  }
}

