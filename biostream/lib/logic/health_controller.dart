// lib/logic/health_controller.dart (예시)
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../models/health_data_model.dart';

class HealthController {
  final HealthService _healthService = HealthService();
  final ApiService _apiService = ApiService();

  Future<void> syncHealthData(String userToken, String userId) async {
    // 1. 데이터 수집 (HealthService 호출)
    final rawData = await _healthService.fetchHealthData();

    if (rawData.isEmpty) {
      print("수집된 데이터가 없습니다.");
      return;
    }

    // 2. 데이터 변환 (HealthDataPoint -> Map 리스트)
    final List<Map<String, dynamic>> metrics = rawData.map((point) => {
      'type': point.typeString,
      'value': point.value.toString(),
      'unit': point.unitString,
      'from': point.dateFrom.toIso8601String(),
      'to': point.dateTo.toIso8601String(),
    }).toList();

    // 3. 모델 객체 생성
    final payload = HealthDataPayload(
      userId: userId,
      metrics: metrics,
      timestamp: DateTime.now(),
    );

    // 4. 서버 전송 (ApiService 호출)
    await _apiService.sendHealthData(payload.toJson(), userToken);
    print("✅ 성공적으로 서버에 생체 데이터를 전송했습니다.");
  }
}