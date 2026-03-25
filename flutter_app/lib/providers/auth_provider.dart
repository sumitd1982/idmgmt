// ============================================================
// Auth Providers — Firebase + User State
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

// Raw Firebase auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// App-level user profile (from backend)
// Supports BOTH Google (Firebase) and phone OTP (stored JWT) login paths
final appUserProvider = FutureProvider.autoDispose<AppUser?>((ref) async {
  final authService = ref.read(authServiceProvider);

  // 1. Check stored JWT first (phone OTP login — no Firebase session)
  final storedToken = await authService.getStoredToken();
  if (storedToken != null) {
    try {
      final user = await authService.getCurrentUser();
      if (user != null) return user;
    } catch (_) {
      // Token expired/invalid — fall through to Firebase check
    }
  }

  // 2. Fall back to Firebase auth state (Google login)
  final firebaseUser = await ref.watch(authStateProvider.future);
  if (firebaseUser == null) return null;
  return authService.getCurrentUser();
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Auth notifier for login/logout actions
class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() async {
    // Check stored JWT first (MSG91 phone login persisted across sessions)
    final storedToken = await _service.getStoredToken();
    if (storedToken != null) {
      try {
        final appUser = await _service.getCurrentUser();
        if (appUser != null) {
          state = AsyncValue.data(appUser);
          return;
        }
      } catch (_) {
        await _service.clearToken(); // token expired/invalid
      }
    }

    // Fall back to Firebase auth stream (Google login)
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        try {
          final appUser = await _service.getCurrentUser();
          state = AsyncValue.data(appUser);
        } catch (e, st) {
          state = AsyncValue.error(e, st);
        }
      } else {
        // Firebase has no user — only sign out if there's no stored phone JWT
        final storedToken = await _service.getStoredToken();
        if (storedToken == null) {
          state = const AsyncValue.data(null);
        }
        // If stored JWT exists, phone OTP user is still logged in — keep current state
      }
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.signInWithGoogle();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithPhone(String phone, String otp) async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.signInWithPhone(phone, otp);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> refreshUser() async {
    try {
      final appUser = await _service.getCurrentUser();
      state = AsyncValue.data(appUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    String? email,
  }) async {
    final user = await _service.updateProfile(
      firstName:  firstName,
      middleName: middleName,
      lastName:   lastName,
      email:      email,
    );
    state = AsyncValue.data(user);
  }

  Future<void> updateEmail(String email) async {
    final user = await _service.updateProfile(
      firstName: '',
      lastName:  '',
      email:     email,
    );
    state = AsyncValue.data(user);
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});
