import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'authorized_http.dart';

/// 카메라/갤러리 JPEG·PNG의 EXIF orientation 을 픽셀에 반영해 GPU·/docs 와 동일한 "바른" 방향으로 맞춤.
({Uint8List bytes, String filename}) _normalizeImageForGpuUpload(
  Uint8List raw,
  String originalName,
) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      return (bytes: raw, filename: originalName);
    }
    final baked = img.bakeOrientation(decoded);
    final dot = originalName.lastIndexOf('.');
    final base = dot > 0 ? originalName.substring(0, dot) : 'upload';
    final lower = originalName.toLowerCase();
    if (lower.endsWith('.png')) {
      return (
        bytes: Uint8List.fromList(img.encodePng(baked)),
        filename: '$base.png',
      );
    }
    return (
      bytes: Uint8List.fromList(img.encodeJpg(baked, quality: 92)),
      filename: '$base.jpg',
    );
  } catch (e, st) {
    debugPrint('[ImageService] EXIF 정규화 실패, 원본 업로드: $e\n$st');
    return (bytes: raw, filename: originalName);
  }
}

class ImageService {
  final storage = const FlutterSecureStorage();
  final AuthorizedHttp _authHttp = AuthorizedHttp();
  final AuthService _auth = AuthService();

  // 이미지 업로드 (target_years=30 고정, DB 저장용)
  Future<Map<String, dynamic>> uploadImage(
    XFile imageFile, {
    int targetYears = 30,
  }) async {
    try {
      if (!await _authHttp.hasAnyCredential()) {
        debugPrint('[ImageService] JWT 토큰이 없습니다.');
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      debugPrint('[ImageService] 이미지 업로드 시작');
      debugPrint('[ImageService] 파일 경로: ${imageFile.path}');
      debugPrint('[ImageService] 파일 이름: ${imageFile.name}');
      debugPrint('[ImageService] Target Years: $targetYears');

      final origin = await ApiConfig.getBaseOrigin();
      final uri = Uri.parse('$origin/data/upload');

      debugPrint('[ImageService] API 엔드포인트: $uri');

      final rawBytes = await imageFile.readAsBytes();
      final normalized =
          _normalizeImageForGpuUpload(rawBytes, imageFile.name);
      debugPrint(
        '[ImageService] 업로드 파일: ${normalized.filename} '
        '(${normalized.bytes.length} bytes, EXIF 반영)',
      );

      Future<http.StreamedResponse> sendMultipart() async {
        final token = await storage.read(key: 'jwt_token');
        final request = http.MultipartRequest('POST', uri);
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            normalized.bytes,
            filename: normalized.filename,
          ),
        );
        request.fields['target_years'] = targetYears.toString();
        return request.send();
      }

      debugPrint('[ImageService] 업로드 요청 전송 중...');

      var streamedResponse = await sendMultipart();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        if (await _auth.refreshTokens()) {
          streamedResponse = await sendMultipart();
          response = await http.Response.fromStream(streamedResponse);
        }
      }
      if (response.statusCode == 401) {
        await _auth.invalidateLocalSession();
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      }

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

  // 업로드 직후 기본 파라미터로 생성 요청
  Future<Map<String, dynamic>> requestGenerateDefault(int lifestyleId) async {
    try {
      if (!await _authHttp.hasAnyCredential()) {
        debugPrint('[ImageService] JWT 토큰이 없습니다. /generate 요청 건너뜀');
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final uri = Uri.parse('$origin/data/generate/$lifestyleId');
      debugPrint('[ImageService] 기본 생성 요청 시작: $uri');

      final response = await _authHttp.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: '{}',
      );

      debugPrint('[ImageService] /generate 응답 코드: ${response.statusCode}');
      debugPrint('[ImageService] /generate 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "data": data,
        };
      }

      final errorData = jsonDecode(response.body);
      return {
        "success": false,
        "message": errorData['detail'] ?? "기본 생성 요청에 실패했습니다.",
      };
    } catch (e, stackTrace) {
      debugPrint('[ImageService] /generate 요청 오류: $e');
      debugPrint('[ImageService] 스택 트레이스: $stackTrace');
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

}

