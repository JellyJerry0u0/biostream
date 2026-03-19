import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TodayMeScreen extends StatefulWidget {
  const TodayMeScreen({super.key});

  @override
  State<TodayMeScreen> createState() => _TodayMeScreenState();
}

class _TodayMeScreenState extends State<TodayMeScreen> {
  static const Color primary = Color(0xFF2BEE75);
  static const Color bg = Color(0xFFF6F8F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              _faceCard(),
              _graphCard(),
              _activityCard(),
              _reportList(),
              _recordButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 상단
  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("2024년 5월 24일",
              style: TextStyle(fontSize: 12, color: Color(0xFF7A8380))),
          SizedBox(height: 4),
          Text("오늘의 나",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// ✅ 얼굴 카드
  Widget _faceCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: const DecorationImage(
            image: NetworkImage(
                "https://lh3.googleusercontent.com/aida-public/AB6AXuDcE5q_Esr_MHKVrXd8SBkI7pdqDBfYtByECWmGx4SxcKr9XVzrUp0Q3onHL2Dm5HsS1to8RiOufjQkZwqT5ll6qhNJzZokn5AmOvVCafALQ6jbLKtWJ1izG1LFTlh4EsA1vlAOqH8y0X8MlQ16vWO2--WejX_JUDuX7nFapkopER4m7U4X76atduqJLTgUrsRqrD_19_UT6JuO7wM886RJKztU_K5B-mE6Gz-6O7KmUUDUS7hEicxgVMeNxyPWpqrUy8E5Cxq-Xqk"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.5), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          child: const Text(
            "생성 시간: 오전 08:30",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /// ✅ 그래프 카드 (🔥 업그레이드 완료)
  Widget _graphCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFE7F3EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("피부 나이 변화 추이",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false),

                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: primary,
                        barWidth: 3,

                        dotData: FlDotData(show: true),

                        belowBarData: BarAreaData(
                          show: true,
                          color: primary.withOpacity(0.2),
                        ),

                        spots: [
                          FlSpot(0, 30),
                          FlSpot(1, 29),
                          FlSpot(2, 28),
                          FlSpot(3, 28),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("5/10"),
                Text("5/14"),
                Text("5/18"),
                Text("오늘"),
              ],
            ),

            const SizedBox(height: 10),

            const Text("현재 피부 나이: 28세",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// ✅ 활동 카드
  Widget _activityCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFE7F3EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("어제의 나의 활동",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: const [
                _MetricBox("거리", "5.2 km"),
                _MetricBox("운동", "45 min"),
                _MetricBox("수면", "7.5 hr"),
                _MetricBox("혈당", "92 mg/dL"),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// ✅ 리포트 리스트
  Widget _reportList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: const [
          _ReportItem("5월 24일", "피부 나이 28세"),
          _ReportItem("5월 23일", "피부 나이 29세"),
          _ReportItem("5월 22일", "피부 나이 30세"),
        ],
      ),
    );
  }

  /// ✅ 기록 버튼
  Widget _recordButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF102217),
          padding: const EdgeInsets.all(18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: () {},
        child: const Row(
          children: [
            Icon(Icons.camera_alt, color: primary),
            SizedBox(width: 12),
            Text("오늘의 얼굴 기록하기",
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// 컴포넌트들
/// ===============================

class _MetricBox extends StatelessWidget {
  final String title;
  final String value;

  const _MetricBox(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ReportItem extends StatelessWidget {
  final String date;
  final String value;

  const _ReportItem(this.date, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        tileColor: const Color(0xFFF6F8F7),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text(date),
        subtitle: Text(value),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}