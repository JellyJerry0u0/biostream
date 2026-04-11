import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Bearer API 호출: 401이면 리프레시 1회 후 재시도, 그래도 401이면 [AuthService.invalidateLocalSession].
class AuthorizedHttp {
  AuthorizedHttp({
    FlutterSecureStorage? storage,
    AuthService? authService,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _auth = authService ?? AuthService();

  final FlutterSecureStorage _storage;
  final AuthService _auth;

  /// 액세스·리프레시 모두 없으면 네트워크 생략
  Future<bool> hasAnyCredential() async {
    final jwt = await _storage.read(key: 'jwt_token');
    if (jwt != null && jwt.isNotEmpty) return true;
    final r = await _storage.read(key: 'refresh_token');
    return r != null && r.isNotEmpty;
  }

  Map<String, String> _bearerHeaders(String? token, Map<String, String>? headers) {
    final h = Map<String, String>.from(headers ?? {});
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<http.Response> _withRetry(
    Future<http.Response> Function(String? token) send,
  ) async {
    var token = await _storage.read(key: 'jwt_token');
    var response = await send(token);
    if (response.statusCode == 401) {
      final refreshed = await _auth.refreshTokens();
      if (refreshed) {
        token = await _storage.read(key: 'jwt_token');
        response = await send(token);
      }
    }
    if (response.statusCode == 401) {
      await _auth.invalidateLocalSession();
    }
    return response;
  }

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) {
    return _withRetry(
      (t) => http.get(uri, headers: _bearerHeaders(t, headers)),
    );
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _withRetry(
      (t) => http.post(
        uri,
        headers: _bearerHeaders(t, headers),
        body: body,
        encoding: encoding,
      ),
    );
  }

  Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _withRetry(
      (t) => http.patch(
        uri,
        headers: _bearerHeaders(t, headers),
        body: body,
        encoding: encoding,
      ),
    );
  }

  Future<http.Response> delete(Uri uri, {Map<String, String>? headers}) {
    return _withRetry(
      (t) => http.delete(uri, headers: _bearerHeaders(t, headers)),
    );
  }
}
