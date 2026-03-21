import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

import 'home_screen.dart';
import 'my_info_screen.dart';
import 'facescan_screen.dart';
import 'future_face_compare_screen.dart';
import 'coach_chat_screen.dart';

class TodayMeScreen extends StatefulWidget {
  const TodayMeScreen({super.key});

  @override
  State<TodayMeScreen> createState() => _TodayMeScreenState();
}

class _TodayMeScreenState extends State<TodayMeScreen> {
  static const Color primary = Color(0xFF2BEE75);
  static const Color bg = Color(0xFFF6F8F6);

  List<Map<String, dynamic>> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await http.get(
        Uri.parse("http://localhost:8000/api/fcm/skin-age-history/1"),
      );

      final data = jsonDecode(res.body);

      setState(() {
        history = List<Map<String, dynamic>>.from(data['skin_age_history']);
        isLoading = false;
      });
    } catch (e) {
      print("API 에러: $e");
      setState(() => isLoading = false);
    }
  }

  List<FlSpot> _spots() {
    return List.generate(history.length, (i) {
      return FlSpot(i.toDouble(), history[i]['age'].toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _faceCard(),
                            const SizedBox(height: 20),
                            _graphCard(),
                            const SizedBox(height: 20),
                            _activityCard(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _bottomNav(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔙 상단바 (MyInfo 동일 스타일)
  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: primary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
          ),
          const Expanded(
            child: Text(
              '오늘의 나',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 얼굴 카드
  Widget _faceCard() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage(
              "https://images.unsplash.com/photo-1527980965255-d3b416303d12"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 그래프 (API 유지)
  Widget _graphCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("피부 나이 변화 추이",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= history.length) {
                          return const Text('');
                        }
                        final date = history[value.toInt()]['date'];
                        return Text(
                          "${date.split('-')[1]}/${date.split('-')[2]}",
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots(),
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 활동 카드 (UI 복구)
  Widget _activityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: const [
          _MetricBox("이동 거리", "5.2", "km", Icons.map),
          _MetricBox("걸음 수", "8432", "보", Icons.directions_walk),
          _MetricBox("산소 포화도", "98", "%", Icons.favorite),
          _MetricBox("수면 시간", "7.5", "시간", Icons.bedtime),
        ],
      ),
    );
  }

  /// 네비게이션 (핵심 수정)
  Widget _bottomNav(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: primary.withOpacity(0.1)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _nav(Icons.timer, true, () {}),
            _nav(Icons.assignment, false, () {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const FaceScanScreen()));
            }),
            _nav(Icons.home, false, () {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            }),
            _nav(Icons.face, false, () {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const FutureFaceCompareScreen()));
            }),
            _nav(Icons.chat, false, () {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const CoachChatScreen()));
            }),
            _nav(Icons.person, false, () {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const MyInfoScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? primary : Colors.grey),
          const SizedBox(height: 4),
          Text("",
              style: TextStyle(
                  fontSize: 10,
                  color: active ? primary : Colors.grey)),
        ],
      ),
    );
  }
}

/// 카드 UI 유지
class _MetricBox extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;

  const _MetricBox(this.title, this.value, this.unit, this.icon);

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2BEE75);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 20),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("$title · $unit",
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}