import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/lifestyle_service.dart';
import '../services/notification_service.dart';

class DebugUvTestScreen extends StatefulWidget {
  const DebugUvTestScreen({super.key});

  @override
  State<DebugUvTestScreen> createState() => _DebugUvTestScreenState();
}

class _DebugUvTestScreenState extends State<DebugUvTestScreen> {
  final LifestyleService _lifestyleService = LifestyleService();

  bool _loading = false;
  String _status = '대기 중';
  Map<String, dynamic>? _todayData;

  String get _todayIsoDate => DateTime.now().toIso8601String().split('T').first;

  Future<void> _showOutdoorPromptNow() async {
    await NotificationService.instance.showOutdoorPrompt(
      date: _todayIsoDate,
      stepsSnapshot: 3500,
    );
    setState(() {
      _status = '로컬 알림을 강제 발송했습니다.';
    });
  }

  Future<void> _submitAnswer(String answer) async {
    setState(() {
      _loading = true;
      _status = '$answer 응답 저장 중...';
    });

    final result = await _lifestyleService.submitOutdoorCheckResponse(
      date: _todayIsoDate,
      answer: answer,
      stepsSnapshot: 3500,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          _todayData = data;
          _status =
              '저장 완료: score=${data['uvExposureScore'] ?? '-'} yes=${data['uvOutdoorYesCount'] ?? '-'} no=${data['uvOutdoorNoCount'] ?? '-'}';
        } else {
          _status = '저장 완료';
        }
      } else {
        _status = '저장 실패: ${result['message'] ?? '알 수 없는 오류'}';
      }
    });
  }

  Future<void> _refreshTodayData() async {
    setState(() {
      _loading = true;
      _status = '오늘 데이터 조회 중...';
    });
    final result = await _lifestyleService.getTodayHealthData();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        _todayData = result['data'] as Map<String, dynamic>;
        _status = '오늘 데이터 조회 완료';
      } else {
        _status = '조회 실패: ${result['message'] ?? '데이터 없음'}';
      }
    });
  }

  Widget _buildDataCard() {
    if (_todayData == null) {
      return const Text(
        '아직 조회된 데이터가 없습니다.',
        style: TextStyle(color: Color(0xFF7A8380)),
      );
    }

    const fields = <String>[
      'date',
      'steps',
      'uvPromptCount',
      'uvOutdoorYesCount',
      'uvOutdoorNoCount',
      'uvOutdoorUnknownCount',
      'uvExposureScore',
      'uvSource',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '$key: ${_todayData![key]}',
                style: const TextStyle(
                  color: Color(0xFF102217),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            jsonEncode(_todayData),
            style: const TextStyle(
              color: Color(0xFF6B7E75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug UV 테스트'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '백그라운드 알림/응답 테스트 보조 화면',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '상태: $_status',
            style: const TextStyle(color: Color(0xFF4A5A54)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _showOutdoorPromptNow,
            icon: const Icon(Icons.notifications_active),
            label: const Text('알림 강제 발송'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _submitAnswer('yes'),
                  child: const Text('YES 저장'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _submitAnswer('no'),
                  child: const Text('NO 저장'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _refreshTodayData,
            icon: const Icon(Icons.refresh),
            label: const Text('오늘 UV 데이터 조회'),
          ),
          const SizedBox(height: 16),
          _buildDataCard(),
        ],
      ),
    );
  }
}
