// ============================================================
// Employee Bulk Photo Upload Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/bulk_photo_upload_widget.dart';

class EmployeeBulkPhotosScreen extends ConsumerWidget {
  const EmployeeBulkPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authNotifierProvider).valueOrNull;
    final schoolId    = currentUser?.schoolId ?? currentUser?.employee?.schoolId;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/employees'),
        ),
        title: Text(
          'Bulk Photo Upload — Employees',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.grey900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.grey200),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: BulkPhotoUploadWidget(
          config: BulkPhotoUploadConfigs.employee(schoolId: schoolId),
          onDone: () => context.go('/employees'),
        ),
      ),
    );
  }
}
