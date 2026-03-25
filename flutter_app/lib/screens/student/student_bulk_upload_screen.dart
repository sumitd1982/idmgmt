// ============================================================
// Student Bulk Upload Screen — full-screen, same layout as Employee
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common/bulk_upload_widget.dart';

// ── History provider ───────────────────────────────────────────
final _studentUploadHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService().get('/students/bulk-upload/history');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

// ── Screen ────────────────────────────────────────────────────
class StudentBulkUploadScreen extends ConsumerWidget {
  const StudentBulkUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final schoolId = user?.schoolId ?? user?.employee?.schoolId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Bulk Upload',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.grey200),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/students/bulk-upload/history'),
            icon: const Icon(Icons.history, size: 16),
            label: Text('History', style: GoogleFonts.poppins(fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Warning banner if no profile
          if (user?.employee == null &&
              user?.isSuperAdmin != true &&
              user?.isSchoolOwner != true)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3E0),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE65100), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your account is not linked to a school. Bulk upload may be restricted.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF5D4037)),
                  ),
                ),
              ]),
            ),

          // Bulk upload widget
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: BulkUploadWidget(
                config: BulkUploadConfigs.student(schoolId: schoolId),
                onComplete: () => context.go('/students'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History Screen ─────────────────────────────────────────────
class StudentBulkUploadHistoryScreen extends ConsumerWidget {
  const StudentBulkUploadHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_studentUploadHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Upload History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.grey200),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_studentUploadHistoryProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: GoogleFonts.poppins())),
        data: (batches) => batches.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 48, color: AppTheme.grey300),
                    const SizedBox(height: 16),
                    Text('No uploads yet',
                        style: GoogleFonts.poppins(
                            fontSize: 15, color: AppTheme.grey500)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: batches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _StudentBatchCard(batch: batches[i]),
              ),
      ),
    );
  }
}

class _StudentBatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _StudentBatchCard({required this.batch});

  Color get _statusColor {
    switch (batch['status'] as String? ?? '') {
      case 'completed':  return AppTheme.statusGreen;
      case 'failed':     return AppTheme.error;
      case 'processing': return AppTheme.warning;
      default:           return AppTheme.grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final createdAt = batch['created_at'] != null
        ? fmt.format(DateTime.parse(batch['created_at'].toString()).toLocal())
        : '—';
    final confirmedAt = batch['confirmed_at'] != null
        ? fmt.format(DateTime.parse(batch['confirmed_at'].toString()).toLocal())
        : null;
    final status = batch['status'] as String? ?? 'unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              batch['filename'] as String? ?? 'Unknown file',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: [
          _InfoChip(Icons.check_circle_outline, AppTheme.statusGreen,
              '${batch['success_rows'] ?? 0} Success'),
          if ((batch['warning_rows'] as int? ?? 0) > 0)
            _InfoChip(Icons.warning_amber_rounded, AppTheme.warning,
                '${batch['warning_rows']} Warning'),
          _InfoChip(Icons.cancel_outlined, AppTheme.error,
              '${batch['failed_rows'] ?? 0} Failed'),
          _InfoChip(Icons.table_rows_outlined, AppTheme.grey600,
              '${batch['total_rows'] ?? 0} Total'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.access_time, size: 13, color: AppTheme.grey500),
          const SizedBox(width: 4),
          Text(createdAt,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey500)),
          if (batch['uploaded_by_name'] != null) ...[
            const SizedBox(width: 8),
            Text('by ${batch['uploaded_by_name']}',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.grey500)),
          ],
        ]),
        if (confirmedAt != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.done_all, size: 13, color: AppTheme.statusGreen),
            const SizedBox(width: 4),
            Text('Confirmed $confirmedAt',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.grey500)),
            if (batch['confirmed_by_name'] != null) ...[
              const SizedBox(width: 4),
              Text('by ${batch['confirmed_by_name']}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.grey500)),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _InfoChip(this.icon, this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      );
}
