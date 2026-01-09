import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();

  final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
  ];

  Future<bool> requestPermission() async {
    return await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
  }

  Future<List<HealthDataPoint>> fetchData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return await _health.getHealthDataFromTypes(
      startTime: yesterday,
      endTime: now,
      types: _types,
    );
  }
}
