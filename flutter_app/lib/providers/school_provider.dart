import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final allSchoolsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final data = await ApiService().get('/schools');
    return data['data'] as List<dynamic>? ?? [];
  } catch (_) {
    return [];
  }
});

final branchesProvider = FutureProvider.family<List<dynamic>, String?>((ref, schoolId) async {
  if (schoolId == null) return [];
  try {
    final data = await ApiService().get('/branches', params: {'school_id': schoolId});
    return data['data'] as List<dynamic>? ?? [];
  } catch (_) {
    return [];
  }
});
