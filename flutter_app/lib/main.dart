// ============================================================
// ID Management System — Flutter Entry Point
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'config/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path strategy — removes # from URLs
  usePathUrlStrategy();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey:            String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
      appId:             String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_ID', defaultValue: ''),
      projectId:         String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
      authDomain:        String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: ''),
      storageBucket:     String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
    ),
  );

  runApp(
    const ProviderScope(
      child: IdMgmtApp(),
    ),
  );
}
