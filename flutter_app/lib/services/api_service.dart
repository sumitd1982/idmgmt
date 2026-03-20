import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<Map<String, dynamic>> uploadFile(String path, FormData formData) async {
    final resp = await _dio.post(path, data: formData);
    return resp.data as Map<String, dynamic>;
  }
}
