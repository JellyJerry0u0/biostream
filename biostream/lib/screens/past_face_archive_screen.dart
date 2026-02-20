import 'package:flutter/material.dart';

import '../services/lifestyle_service.dart';
import 'coach_chat_screen.dart';
import 'facescan_screen.dart';
import 'future_face_compare_screen.dart';
import 'home_screen.dart';
import 'my_info_screen.dart';

class PastFaceArchiveScreen extends StatefulWidget {
  const PastFaceArchiveScreen({super.key});

  @override
  State<PastFaceArchiveScreen> createState() => _PastFaceArchiveScreenState();
}

class _PastFaceArchiveScreenState extends State<PastFaceArchiveScreen> {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);

  final PageController _pageController = PageController(viewportFraction: 0.75);
  final LifestyleService _lifestyleService = LifestyleService();

  List<_ArchiveItem> _archiveItems = [];
  double _currentPage = 0;
  bool _latestFirst = true;
  bool _isLoading = true;
  String? _loadError;

  List<_ArchiveItem> get _displayItems {
    if (_latestFirst) return _archiveItems;
    return _archiveItems.reversed.toList();
  }

  int get _activeIndex {
    if (_displayItems.isEmpty) return 0;
    final rounded = _currentPage.round();
    return rounded.clamp(0, _displayItems.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _loadArchiveItems();
    _pageController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSort() {
    setState(() {
      _latestFirst = !_latestFirst;
    });
    if (_pageController.hasClients && _displayItems.isNotEmpty) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _loadArchiveItems() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await _lifestyleService.getReportArchives();

    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> rawItems = (result['items'] as List<dynamic>? ?? []);
      final items = rawItems
          .map((item) {
            final map = item as Map<String, dynamic>;
            final generatedAt = (map['generated_at'] ?? '').toString();
            final targetYears = map['target_years'];
            final int parsedYears = targetYears is int
                ? targetYears
                : int.tryParse('$targetYears') ?? 0;

            return _ArchiveItem(
              date: _formatDate(generatedAt),
              horizonLabel: parsedYears > 0 ? '+${parsedYears}년 뒤' : '+미래',
              imageUrl: (map['image_url'] ?? '').toString(),
            );
          })
          .where((item) => item.imageUrl.isNotEmpty)
          .toList();

      setState(() {
        _archiveItems = items;
        _currentPage = 0;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _archiveItems = [];
      _loadError = (result['message'] ?? '아카이브를 불러오지 못했습니다.').toString();
      _isLoading = false;
    });
  }

  String _formatDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return '-';
    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _displayItems.length;

    return Scaffold(
      backgroundColor: _backgroundLight,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '총 $itemCount개의 아카이브',
                            style: const TextStyle(
                              color: Color(0xFF7A8380),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: _toggleSort,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.swap_vert,
                                      color: _primary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _latestFirst ? '최신순' : '오래된순',
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 98),
                        child: _buildBodyContent(itemCount),
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomNavigation(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(int itemCount) {
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
                  color: Color(0xFF7A8380), size: 42),
              const SizedBox(height: 12),
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
                onPressed: _loadArchiveItems,
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

    if (itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_not_supported_outlined,
                  color: Color(0xFF7A8380), size: 44),
              const SizedBox(height: 12),
              const Text(
                '아직 생성된 이미지가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF102217),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '미래 얼굴 리포트를 생성하면\n과거 얼굴 조회에서 확인할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7A8380),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const FaceScanScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: const Color(0xFF102217),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text(
                  '레포트 생성하러 가기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 520,
          child: PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final item = _displayItems[index];
              final delta = (_currentPage - index).abs();
              final scale = (1 - (delta * 0.08)).clamp(0.9, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Transform.scale(
                  scale: scale,
                  child: _ArchiveCard(item: item),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(itemCount, (index) {
            final bool isActive = index == _activeIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 8 : 6,
              height: isActive ? 8 : 6,
              decoration: BoxDecoration(
                color: isActive ? _primary : const Color(0xFFBFC7C3),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
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
          _roundIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              '과거 얼굴 조회',
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

  Widget _buildBottomNavigation(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: _primary.withValues(alpha: 0.14)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavItem(
                icon: Icons.assignment,
                label: '설문 조사',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FaceScanScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.home,
                label: '홈 화면',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.face_retouching_natural,
                label: '내 미래 얼굴',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FutureFaceCompareScreen(),
                    ),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.chat_bubble,
                label: '챗봇',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachChatScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.person,
                label: '내 정보',
                isActive: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyInfoScreen()),
                  );
                },
              ),
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
          color: _primary.withValues(alpha: 0.08),
        ),
        child: Icon(icon, color: const Color(0xFF102217), size: 20),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.item});

  final _ArchiveItem item;

  static const Color _primary = Color(0xFF2BEE75);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
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
                      Colors.black.withValues(alpha: 0.28),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.date,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.horizonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primary.withValues(alpha: 0.2),
                          border: Border.all(
                              color: _primary.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.zoom_in,
                            color: _primary, size: 22),
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

class _ArchiveItem {
  const _ArchiveItem({
    required this.date,
    required this.horizonLabel,
    required this.imageUrl,
  });

  final String date;
  final String horizonLabel;
  final String imageUrl;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2BEE75);
    final color = isActive ? primary : const Color(0xFF7A8380);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
