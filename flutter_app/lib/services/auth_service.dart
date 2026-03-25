import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final FirebaseAuth _auth   = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(
    clientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: ''),
    scopes: ['email', 'profile'],
  );
  final ApiService _api = ApiService();

  static const _tokenKey = 'auth_token';

  // ── Token storage (for MSG91 JWT) ───────────────────────────
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Get current user (works for both Google and Phone login) ─
  Future<AppUser?> getCurrentUser() async {
    try {
      Map<String, dynamic> userData = {};

      // Try Firebase token first (Google login)
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final token = await firebaseUser.getIdToken();
        final resp  = await _api.get('/auth/me', headers: {'Authorization': 'Bearer $token'});
        final data  = resp['data'] as Map<String, dynamic>;
        userData = {
          ...data['user'] as Map<String, dynamic>,
          'employee': data['employee'],
        };
      } else {
        // Try stored JWT (phone login via MSG91)
        final storedToken = await getStoredToken();
        if (storedToken == null) return null;
        final resp = await _api.get('/auth/me', headers: {'Authorization': 'Bearer $storedToken'});
        final data = resp['data'] as Map<String, dynamic>;
        userData = {
          ...data['user'] as Map<String, dynamic>,
          'employee': data['employee'],
        };
      }

      // Check onboarding status for super_admin
      if (userData['role'] == 'super_admin') {
        try {
          final setupResp = await _api.get('/auth/setup-status');
          final needsOnboarding = (setupResp['data'] as Map?)?['needsOnboarding'] as bool? ?? false;
          userData['needs_onboarding'] = needsOnboarding;
        } catch (_) {}
      }

      return AppUser.fromJson(userData);
    } catch (_) {}
    return null;
  }

  // ── Google Sign-In (Firebase) ────────────────────────────────
  Future<AppUser?> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final token    = await userCred.user!.getIdToken();

      await _api.post('/auth/register', body: {
        'firebase_uid':  userCred.user!.uid,
        'email':         userCred.user!.email,
        'full_name':     userCred.user!.displayName ?? '',
        'display_name':  userCred.user!.displayName ?? '',
        'photo_url':     userCred.user!.photoURL,
      }, headers: {'Authorization': 'Bearer $token'});

      return getCurrentUser();
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response!.data['message'] : e.message;
      throw Exception(msg ?? 'Google Sign In Failed');
    }
  }

  // ── Phone OTP via MSG91 (no Firebase phone auth) ─────────────
  Future<void> sendOtp(String phone) async {
    try {
      final resp = await _api.post('/auth/otp/send', body: {'phone': phone});
      if (resp['success'] != true) {
        throw Exception(resp['message'] ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response!.data['message'] : e.message;
      throw Exception(msg ?? 'Network error while sending OTP');
    }
  }

  Future<AppUser?> signInWithPhone(String phone, String otp) async {
    try {
      final resp = await _api.post('/auth/otp/verify', body: {'phone': phone, 'otp': otp});
      if (resp['success'] != true) {
        throw Exception(resp['message'] ?? 'Invalid OTP');
      }
      final token = resp['data']['token'] as String;
      await saveToken(token);
      return getCurrentUser();
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response!.data['message'] : e.message;
      throw Exception(msg ?? 'Invalid OTP or network error');
    }
  }

  // ── Update user profile (name, email) ───────────────────────
  Future<AppUser?> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    String? email,
  }) async {
    try {
      await _api.put('/auth/profile', body: {
        'first_name':  firstName,
        if (middleName != null && middleName.isNotEmpty) 'middle_name': middleName,
        'last_name':   lastName,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return getCurrentUser();
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response!.data['message'] : e.message;
      throw Exception(msg ?? 'Failed to update profile');
    }
  }

  Future<void> signOut() async {
    await clearToken();
    if (_auth.currentUser != null) {
      await Future.wait([_auth.signOut(), _google.signOut()]);
    }
  }
}
