// ============================================================
// Employee Bulk Upload History Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

final _uploadHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService().get('/employees/bulk-upload/history');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

class EmployeeBulkUploadHistoryScreen extends ConsumerWidget {
  const EmployeeBulkUploadHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_uploadHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Upload History', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
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
            onPressed: () => ref.invalidate(_uploadHistoryProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.poppins())),
        data: (batches) => batches.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.history, size: 48, color: AppTheme.grey300),
              const SizedBox(height: 16),
              Text('No uploads yet', style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.grey500)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: batches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _BatchCard(batch: batches[i]),
            ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _BatchCard({required this.batch});

  Color get _statusColor {
    switch (batch['status'] as String? ?? '') {
      case 'completed': return AppTheme.statusGreen;
      case 'failed':    return AppTheme.error;
      case 'processing': return AppTheme.warning;
      default:          return AppTheme.grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final createdAt = batch['created_at'] != null
        ? fmt.format(DateTime.parse(batch['created_at'].toString()).toLocal())
        : '—';
    final total    = batch['total_rows'] as int? ?? 0;
    final success  = batch['success_rows'] as int? ?? 0;
    final failed   = batch['failed_rows'] as int? ?? 0;
    final status   = (batch['status'] as String? ?? '').toUpperCase();
    final filename = batch['filename'] as String? ?? '—';
    final uploader = batch['uploaded_by_name'] as String? ?? '—';
    final batchId  = batch['id'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(filename, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey900),
              overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 20, runSpacing: 6, children: [
          _InfoChip(icon: Icons.person_outline, label: uploader),
          _InfoChip(icon: Icons.access_time, label: createdAt),
          _InfoChip(icon: Icons.table_rows_outlined, label: '$total rows'),
          if (success > 0) _InfoChip(icon: Icons.check_circle_outline, label: '$success imported', color: AppTheme.statusGreen),
          if (failed > 0)  _InfoChip(icon: Icons.cancel_outlined, label: '$failed failed', color: AppTheme.error),
        ]),
        if (batchId != null && (batch['status'] == 'validated' || batch['status'] == 'completed')) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ApiService().downloadFile(
              '/employees/bulk-history/$batchId/report',
              'validation_report_$filename',
            ),
            icon: const Icon(Icons.download_outlined, size: 15, color: AppTheme.primary),
            label: Text('Download Report', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, this.color = AppTheme.grey600});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: color)),
    ]);
  }
}
