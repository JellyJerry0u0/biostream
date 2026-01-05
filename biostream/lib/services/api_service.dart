//추출된 데이터를 Backend의 auth.py 또는 데이터 수집 API로 전송
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = "http://your-backend-ip:8000";
  //final String baseUrl = "http://172.30.1.11:8080";

  Future<void> sendHealthData(Map<String, dynamic> data, String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/data/collect"),
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