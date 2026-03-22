import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiService {
  static ApiService? _instance;
  late final Dio _dio;

  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          // Prefer stored JWT (phone OTP login) — avoids stale Firebase sessions
          final prefs = await SharedPreferences.getInstance();
          String? token = prefs.getString('auth_token');
          // Fall back to Firebase ID token (Google login)
          if (token == null) {
            try {
              token = await FirebaseAuth.instance.currentUser?.getIdToken();
            } catch (_) {/* Firebase error — no token */}
          }
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        } catch (_) {}
        handler.next(options);
      },
      onError: (err, handler) {
        handler.next(err);
      },
    ));
  }

  Future<Map<String, dynamic>> get(String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) async {
    final resp = await _dio.get(path,
      queryParameters: params,
      options: Options(headers: headers),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final resp = await _dio.post(path,
      data: body,
      options: Options(headers: headers),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {
    Map<String, dynamic>? body,
  }) async {
    final resp = await _dio.put(path, data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, {
    Map<String, dynamic>? body,
  }) async {
    final resp = await _dio.patch(path, data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final resp = await _dio.delete(path);
    return resp.data as Map<String, dynamic>;
  }

  /// Upload a file from raw bytes (used by bulk upload screens)
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    FormData? formData,
    Uint8List? bytes,
    String? fileName,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    final fd = formData ?? FormData.fromMap({
      ...?fields,
      fieldName: MultipartFile.fromBytes(bytes!, filename: fileName ?? 'upload.xlsx'),
    });
    final resp = await _dio.post(path,
      data: fd,
      options: Options(contentType: 'multipart/form-data'),
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Trigger a browser file download for the given API endpoint
  Future<void> downloadFile(String path, String saveAs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final url = '${AppConstants.apiBaseUrl}$path';
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', saveAs)
        ..setAttribute('target', '_blank');
      // Attach auth token via query param as fallback for direct GET downloads
      final fullUrl = token != null ? '$url?token=$token' : url;
      anchor.href = fullUrl;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    Map<String, dynamic> data, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      ...data,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final resp = await _dio.post(path, data: formData);
    return resp.data as Map<String, dynamic>;
  }
}
