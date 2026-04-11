import 'dart:convert';

import 'api_config.dart';
import 'authorized_http.dart';

/// DB 영속 코치 적응형 목표 (committed_action 습관 카드와 별개)
class CoachActiveGoalItem {
  const CoachActiveGoalItem({
    required this.goalId,
    required this.domain,
    required this.description,
    required this.currentTarget,
    this.unit,
    required this.status,
    required this.pendingUserApproval,
    this.proposedTarget,
    this.successRate7d,
  });

  final String goalId;
  final String domain;
  final String description;
  final String currentTarget;
  final String? unit;
  final String status;
  final bool pendingUserApproval;
  final String? proposedTarget;
  final double? successRate7d;

  factory CoachActiveGoalItem.fromJson(Map<String, dynamic> j) {
    final sr = j['success_rate_7d'];
    return CoachActiveGoalItem(
      goalId: j['goal_id']?.toString() ?? '',
      domain: j['domain']?.toString() ?? 'general',
      description: j['description']?.toString() ?? '',
      currentTarget: j['current_target']?.toString() ?? '',
      unit: j['unit']?.toString(),
      status: j['status']?.toString() ?? 'active',
      pendingUserApproval: j['pending_user_approval'] == true,
      proposedTarget: j['proposed_target']?.toString(),
      successRate7d: sr is num ? sr.toDouble() : double.tryParse('$sr'),
    );
  }
}

class CoachGoalsService {
  CoachGoalsService._();
  static final CoachGoalsService instance = CoachGoalsService._();

  final AuthorizedHttp _http = AuthorizedHttp();

  Future<List<CoachActiveGoalItem>> fetchActiveGoals() async {
    if (!await _http.hasAnyCredential()) {
      return [];
    }
    final origin = await ApiConfig.getBaseOrigin();
    final res = await _http.get(
      Uri.parse('$origin/api/coach/active-goals'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) {
      return [];
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = data['goals'];
    if (raw is! List) {
      return [];
    }
    return raw
        .whereType<Map>()
        .map((e) => CoachActiveGoalItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
