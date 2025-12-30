//Health Connect에서 받은 데이터를 서버(FastAPI)가 이해할 수 있는 형식으로 변환하는 역할

class HealthDataPayload {
  final String userId;
  final List<Map<String, dynamic>> metrics;
  final DateTime timestamp;

  HealthDataPayload({required this.userId, required this.metrics, required this.timestamp});

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "metrics": metrics,
    "timestamp": timestamp.toIso8601String(),
  };
}