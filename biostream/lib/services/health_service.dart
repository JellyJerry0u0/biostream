//health 패키지를 사용하여 실제 기기에서 데이터를 긁어오는 핵심 로직
//Health Connect API와 직접 통신하며 데이터를 가져오는 역할

import 'package:health/health.dart';

class HealthService {
  // [1] Health 패키지 인스턴스 생성
  final Health _health = Health();

  // [2] 우리가 가져올 데이터 타입 정의
  final List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.STEPS,
  ];

  // [3] 권한 요청 및 데이터 수집 메인 함수
  Future<List<HealthDataPoint>> fetchHealthData() async {
    try {
      // 1. 권한 확인 및 요청
      // 안드로이드의 경우 Health Connect 설치 여부도 여기서 확인됩니다.
      bool hasPermissions = await _health.hasPermissions(_types) ?? false;

      if (!hasPermissions) {
        // 권한이 없다면 사용자에게 팝업을 띄워 요청합니다.
        hasPermissions = await _health.requestAuthorization(_types);
      }

      if (hasPermissions) {
        // 2. 데이터 수집 기간 설정 (최근 24시간)
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(hours: 24));

        // 3. 데이터 가져오기
        List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
          startTime: yesterday,
          endTime: now,
          types: _types,
        );

        // 4. 중복 데이터 제거 (Clean up)
        return _health.removeDuplicates(healthData);
      } else {
        print("❌ Health Connect 권한이 거부되었습니다.");
        return [];
      }
    } catch (e) {
      print("⚠️ 데이터 수집 중 에러 발생: $e");
      return [];
    }
  }
}