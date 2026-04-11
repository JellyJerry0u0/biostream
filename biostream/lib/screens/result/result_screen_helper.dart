import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_config.dart';

class ResultScreenHelper {
  static Future<bool> openExternalUrl(String? rawUrl) async {
    final value = rawUrl?.toString().trim();
    if (value == null || value.isEmpty) {
      return false;
    }
    try {
      final uri = Uri.parse(value);
      if (!await canLaunchUrl(uri)) {
        return false;
      }
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 리포트 결과 슬라이더 왼쪽: 촬영·업로드 원본만 사용.
  static String? extractOriginalImageUrl(
    Map<String, dynamic>? lifestyleData,
    Map<String, dynamic>? reportData,
  ) {
    final lifestyleImages = lifestyleData?['images'];
    if (lifestyleImages is Map<String, dynamic>) {
      final original = lifestyleImages['original_image_url']?.toString().trim();
      if (original != null && original.isNotEmpty) return original;
    }

    final direct = lifestyleData?['original_image_url']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final reportDirect = reportData?['original_image_url']?.toString().trim();
    if (reportDirect != null && reportDirect.isNotEmpty) return reportDirect;

    final params = reportData?['image_gen_params'];
    if (params is Map<String, dynamic>) {
      final source = params['image_url']?.toString().trim();
      if (source != null && source.isNotEmpty) return source;
    }
    return null;
  }

  /// 리포트 결과 슬라이더 오른쪽: **설문 생활습관 점수 기반** skin-edit(`generated_image_url`)만.
  /// `ideal_habits_skin_image_url`(습관 만점 skin-edit)은 미래 얼굴 탭에서만 사용한다.
  static String? extractGeneratedImageUrl(
    Map<String, dynamic>? lifestyleData,
    Map<String, dynamic>? reportData,
  ) {
    final lifestyleImages = lifestyleData?['images'];
    if (lifestyleImages is Map<String, dynamic>) {
      final generated =
          lifestyleImages['generated_image_url']?.toString().trim();
      if (generated != null && generated.isNotEmpty) return generated;
    }

    final direct = lifestyleData?['generated_image_url']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final reportDirect = reportData?['generated_image_url']?.toString().trim();
    if (reportDirect != null && reportDirect.isNotEmpty) return reportDirect;

    return null;
  }

  static Future<String?> resolveImageUrl(String? rawUrl) async {
    final value = rawUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      // localhost URL을 앱의 실제 API origin으로 치환한다.
      try {
        final parsed = Uri.parse(value);
        final host = parsed.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
          final origin = await ApiConfig.getBaseOrigin();
          final originUri = Uri.parse(origin);
          final replaced = parsed.replace(
            scheme: originUri.scheme,
            host: originUri.host,
            port: originUri.hasPort ? originUri.port : null,
          );
          return replaced.toString();
        }
      } catch (_) {
        // 파싱 실패 시 원본 유지
      }
      return value;
    }

    // 서버 로컬 경로(/.../uploads/xxx.jpg)라면 API 이미지 엔드포인트로 변환
    const marker = '/uploads/';
    final index = value.replaceAll('\\', '/').indexOf(marker);
    if (index >= 0) {
      final relativePath =
          value.replaceAll('\\', '/').substring(index + marker.length);
      final origin = await ApiConfig.getBaseOrigin();
      return '$origin/data/image/$relativePath';
    }

    return value;
  }

  static Map<String, dynamic> convertOldSchemaToNew(
    Map<String, dynamic> reportData,
    dynamic cards,
  ) {
    final sections = <String, dynamic>{};
    final tabs = <String>[];

    if (cards != null && cards is List) {
      final sectionTitles = {
        'goals': {'title': '주요 목표 분석 및 개선 방안', 'key': 'goals'},
        'sleep': {'title': '수면 및 리듬', 'key': 'sleep'},
        'uv': {'title': '자외선 및 노화 관리', 'key': 'uv'},
        'lifestyle': {'title': '생활습관 관리', 'key': 'lifestyle'},
        'activity': {'title': '활동 및 대사', 'key': 'activity'},
      };

      int index = 0;
      for (final card in cards) {
        final cardMap = card as Map<String, dynamic>;
        final sectionKeys = sectionTitles.keys.toList();
        final sectionKey = index < sectionKeys.length
            ? sectionKeys[index % sectionKeys.length]
            : 'goals';
        final sectionInfo = sectionTitles[sectionKey]!;

        if (!sections.containsKey(sectionKey)) {
          sections[sectionKey] = {
            'title': sectionInfo['title'],
            'cards': [],
            'evidence_refs': {'narrative': [], 'quant': []},
          };
          tabs.add(sectionKey);
        }

        sections[sectionKey]['cards'].add({
          'type': 'problem',
          'title': '현재 상태',
          'text': cardMap['content'] ?? '',
        });
        index++;
      }
    }

    return {
      'tabs': tabs,
      'sections': sections,
    };
  }

  static bool isGallerySaveSuccess(dynamic result) {
    if (result == null) return false;
    if (result is bool) return result;
    if (result is Map) {
      final dynamic ok = result['isSuccess'];
      if (ok is bool) return ok;
      final dynamic flag = result['success'];
      if (flag is bool) return flag;
      final dynamic filePath = result['filePath'];
      if (filePath is String && filePath.isNotEmpty) return true;
    }
    return false;
  }

  static Future<Uint8List?> downloadImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
