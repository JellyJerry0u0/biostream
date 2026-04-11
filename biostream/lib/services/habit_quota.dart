/// API `habit_quota`: { "max": int, "active_count": int }
class HabitQuotaInfo {
  const HabitQuotaInfo({required this.max, required this.activeCount});

  final int max;
  final int activeCount;

  static int? _parseIntLoose(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static HabitQuotaInfo? tryParse(Map<String, dynamic> body) {
    final raw = body['habit_quota'];
    if (raw is! Map<String, dynamic>) return null;
    final maxV = _parseIntLoose(raw['max']);
    final ac = _parseIntLoose(raw['active_count']);
    if (maxV == null || ac == null) return null;
    return HabitQuotaInfo(max: maxV, activeCount: ac);
  }
}
