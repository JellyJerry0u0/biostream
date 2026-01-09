//추출된 데이터를 Backend의 auth.py 또는 데이터 수집 API로 전송
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class ApiService {
  Future<void> sendHealthData(Map<String, dynamic> data, String token) async {
    final origin = await ApiConfig.getBaseOrigin();
    final response = await http.post(
      Uri.parse("$origin/data/collect"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // 카카오 로그인 시 받은 JWT
      },
      body: jsonEncode(data),
    );
    
    if (response.statusCode != 200) {
      print("데이터 전송 실패: ${response.body}");
    }
  }
}