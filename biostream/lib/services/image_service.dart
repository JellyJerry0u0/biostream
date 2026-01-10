import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';

class ImageService {
  final storage = const FlutterSecureStorage();

  // 이미지 업로드
  Future<Map<String, dynamic>> uploadImage(
    XFile imageFile,
    int targetYears,
  ) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        debugPrint('[ImageService] JWT 토큰이 없습니다.');
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      // JWT 토큰에서 user_id 추출 (임시로 1로 설정, 나중에 토큰에서 추출)
      // TODO: JWT 토큰 디코딩하여 실제 user_id 가져오기
      final userId = await _getUserIdFromToken(token);

      debugPrint('[ImageService] 이미지 업로드 시작');
      debugPrint('[ImageService] 파일 경로: ${imageFile.path}');
      debugPrint('[ImageService] 파일 이름: ${imageFile.name}');
      debugPrint('[ImageService] User ID: $userId');
      debugPrint('[ImageService] Target Years: $targetYears');

      final origin = await ApiConfig.getBaseOrigin();
      final uri = Uri.parse('$origin/data/upload');
      
      debugPrint('[ImageService] API 엔드포인트: $uri');

      // multipart/form-data 요청 생성
      final request = http.MultipartRequest('POST', uri);
      
      // 헤더에 토큰 추가
      request.headers['Authorization'] = 'Bearer $token';
      
      // 파일 추가
      final file = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: imageFile.name,
      );
      request.files.add(file);
      
      // 폼 데이터 추가
      request.fields['user_id'] = userId.toString();
      request.fields['target_years'] = targetYears.toString();

      debugPrint('[ImageService] 업로드 요청 전송 중...');
      
      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[ImageService] 응답 상태 코드: ${response.statusCode}');
      debugPrint('[ImageService] 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final savedPath = data['saved_path'] as String?;
        
        debugPrint('[ImageService] 이미지 업로드 성공!');
        debugPrint('[ImageService] 저장된 경로: $savedPath');
        debugPrint('[ImageService] Lifestyle ID: ${data['lifestyle_id']}');
        
        return {
          "success": true,
          "saved_path": savedPath,
          "original_image_url": savedPath,
          "lifestyle_id": data['lifestyle_id'],
          "message": "이미지 업로드 성공",
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? "이미지 업로드 실패";
        debugPrint('[ImageService] 이미지 업로드 실패: $errorMessage');
        return {"success": false, "message": errorMessage};
      }
    } catch (e, stackTrace) {
      debugPrint('[ImageService] 이미지 업로드 오류: $e');
      debugPrint('[ImageService] 스택 트레이스: $stackTrace');
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  // JWT 토큰에서 user_id 추출 (임시 구현)
  Future<int> _getUserIdFromToken(String token) async {
    try {
      // JWT 토큰은 base64로 인코딩된 payload를 포함
      // 실제로는 jwt 패키지를 사용하여 디코딩해야 함
      // 임시로 1 반환 (나중에 실제 구현 필요)
      
      // TODO: JWT 토큰 디코딩하여 user_id 추출
      // 예: final payload = jwt.decode(token);
      //     return payload['user_id'] as int;
      
      debugPrint('[ImageService] JWT 토큰에서 user_id 추출 (임시: 1)');
      return 1; // 임시 값
    } catch (e) {
      debugPrint('[ImageService] user_id 추출 오류: $e');
      return 1; // 기본값
    }
  }
}

