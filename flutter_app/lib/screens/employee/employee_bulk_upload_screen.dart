// ============================================================
// Employee Bulk Upload Screen — Clean, readable, step-by-step
// ============================================================
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Data classes ──────────────────────────────────────────────
enum _RowStatus { success, warning, failed }

class _ValidationRow {
  final int row;
  final _RowStatus status;
  final String empId;
  final String name;
  final List<String> errors;
  final List<String> warnings;
  final List<String> notes;

  const _ValidationRow({
    required this.row,
    required this.status,
    required this.empId,
    required this.name,
    required this.errors,
    required this.warnings,
    required this.notes,
  });

  factory _ValidationRow.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map? ?? {};
    final st = j['status'] as String? ?? 'failed';
    return _ValidationRow(
      row:      j['row'] as int? ?? 0,
      status:   st == 'success' ? _RowStatus.success : st == 'warning' ? _RowStatus.warning : _RowStatus.failed,
      empId:    data['empId'] as String? ?? '—',
      name:     '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
      errors:   List<String>.from(j['errors'] ?? []),
      warnings: List<String>.from(j['warnings'] ?? []),
      notes:    List<String>.from(j['notes'] ?? []),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────
class EmployeeBulkUploadScreen extends ConsumerStatefulWidget {
  const EmployeeBulkUploadScreen({super.key});

  @override
  ConsumerState<EmployeeBulkUploadScreen> createState() => _EmployeeBulkUploadScreenState();
}

class _EmployeeBulkUploadScreenState extends ConsumerState<EmployeeBulkUploadScreen> {
  int _step = 0;           // 0=download 1=upload 2=validate 3=submit
  bool _loading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  List<_ValidationRow> _rows = [];
  int _totalOk = 0;
  int _totalFail = 0;
  bool _canSubmit = false;
  String? _batchId;
  // filter
  _RowStatus? _filterStatus;
  String _search = '';
  // result
  int? _insertedCount;
  int? _replacedCount;

  void _pickFile() {
    if (!kIsWeb) return;
    final input = html.FileUploadInputElement()..accept = '.xlsx,.xls';
    input.click();
    input.onChange.listen((event) {
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        setState(() {
          _fileName = file.name;
          _fileBytes = reader.result as Uint8List?;
          _step = 1;
        });
      });
    });
  }

  Future<void> _validate() async {
    if (_fileBytes == null) return;
    setState(() { _loading = true; _step = 2; });
    try {
      final api = ApiService();
      final result = await api.uploadFile(
        '/employees/validate-bulk',
        bytes: _fileBytes!,
        fileName: _fileName ?? 'upload.xlsx',
        fieldName: 'file',
      );
      final data = result['data'] as Map? ?? {};
      final rawRows = data['results'] as List? ?? [];
      setState(() {
        _rows = rawRows.map((r) => _ValidationRow.fromJson(r as Map<String, dynamic>)).toList();
        _totalOk   = data['totalOk'] as int? ?? 0;
        _totalFail = data['totalFail'] as int? ?? 0;
        _canSubmit = data['canSubmit'] as bool? ?? false;
        _batchId   = data['batchId'] as String?;
      });
    } catch (e) {
      _showError('Validation failed: $e');
      setState(() => _step = 1);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit || _batchId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.upload_file, color: AppTheme.primary),
          const SizedBox(width: 10),
          Text('Confirm Upload', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'This will import $_totalOk employee records.\nExisting employees with the same Employee ID will be marked inactive and replaced.',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey700),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Upload', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _step = 3; });
    try {
      final api = ApiService();
      final result = await api.post('/employees/bulk', body: { 'batch_id': _batchId });
      final data = result['data'] as Map? ?? {};
      setState(() {
        _insertedCount  = data['inserted'] as int?;
        _replacedCount  = data['replaced'] as int?;
      });
    } catch (e) {
      _showError('Upload failed: $e');
      setState(() => _step = 2);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  void _reset() => setState(() {
    _step = 0; _fileName = null; _fileBytes = null;
    _rows = []; _totalOk = 0; _totalFail = 0;
    _canSubmit = false; _batchId = null; _insertedCount = null; _replacedCount = null;
  });

  List<_ValidationRow> get _filtered {
    var list = _rows;
    if (_filterStatus != null) list = list.where((r) => r.status == _filterStatus).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
        r.empId.toLowerCase().contains(q) ||
        r.name.toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Bulk Upload',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.grey200),
        ),
        actions: [
          if (_step > 0)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text('Start Over', style: GoogleFonts.poppins(fontSize: 13)),
            ),
          TextButton.icon(
            onPressed: () => context.push('/employees/bulk-upload/history'),
            icon: const Icon(Icons.history, size: 16),
            label: Text('History', style: GoogleFonts.poppins(fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (user?.employee == null && user?.isSuperAdmin != true && user?.isSchoolOwner != true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your account is not linked to an employee profile. '
                      'After uploading, remember to add yourself as an employee too.',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 260, child: _StepsSidebar(currentStep: _step)),
                    Expanded(child: _buildContent()),
                  ])
                : Column(children: [
                    _StepsTopBar(currentStep: _step),
                    Expanded(child: _buildContent()),
                  ]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_step == 3 && _insertedCount != null) return _buildSuccess();
    switch (_step) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildLoading('Uploading employees to database…');
      default: return const SizedBox.shrink();
    }
  }

  // Step 0 — Download Template
  Widget _buildStep0() {
    return _StepWrapper(
      title: 'Download the Template',
      subtitle: 'Fill in the Excel template and come back to upload it.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _InfoCard(
          icon: Icons.info_outline,
          color: AppTheme.primary,
          text: 'The template has two sheets:\n'
              '• "Instructions" — column explanations\n'
              '• "Employees" — paste your data here (100 sample rows are pre-filled)',
        ),
        const SizedBox(height: 20),
        _FieldTable(),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.download, color: Colors.white),
            label: Text('Download Excel Template', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            onPressed: () => ApiService().downloadFile('/employees/bulk-template/download', 'employee_bulk_template.xlsx'),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.upload_file, color: AppTheme.primary),
            label: Text('Already have the file? Upload Now', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primary)),
            onPressed: _pickFile,
          ),
        ),
      ]),
    );
  }

  // Step 1 — Upload file
  Widget _buildStep1() {
    return _StepWrapper(
      title: 'Upload Your File',
      subtitle: 'Select the completed Excel file from your device.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Drop zone
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: _fileBytes != null
                  ? AppTheme.primary.withOpacity(0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _fileBytes != null ? AppTheme.primary : AppTheme.grey300,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(children: [
              Icon(
                _fileBytes != null ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                size: 48,
                color: _fileBytes != null ? AppTheme.statusGreen : AppTheme.grey400,
              ),
              const SizedBox(height: 12),
              Text(
                _fileBytes != null ? _fileName ?? 'File selected' : 'Click to choose an Excel file (.xlsx)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _fileBytes != null ? AppTheme.statusGreen : AppTheme.grey600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _fileBytes != null ? 'Tap to change file' : 'Supports .xlsx format · Max 20 MB',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey400),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        if (_fileBytes != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.verified_outlined, color: Colors.white),
              label: Text('Validate File', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              onPressed: _loading ? null : _validate,
            ),
          ),
      ]),
    );
  }

  void _downloadValidationReport() {
    if (_batchId == null) return;
    ApiService().downloadFile('/employees/bulk-history/$_batchId/report', 'validation_report.xlsx');
  }

  // Step 2 — Validation results
  Widget _buildStep2() {
    if (_loading) return _buildLoading('Validating file — checking each row…');
    final filtered = _filtered;
    return Column(children: [
      // Summary bar
      _ValidationSummary(
        total: _rows.length,
        ok: _totalOk,
        fail: _totalFail,
        canSubmit: _canSubmit,
        onDownloadReport: _batchId != null ? _downloadValidationReport : null,
      ),
      // Filter + search
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by Employee ID or Name…',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey400),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.grey400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.grey300)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 10),
          _FilterChips(
            current: _filterStatus,
            onChanged: (s) => setState(() => _filterStatus = s),
            counts: {
              _RowStatus.success: _rows.where((r) => r.status == _RowStatus.success).length,
              _RowStatus.warning: _rows.where((r) => r.status == _RowStatus.warning).length,
              _RowStatus.failed:  _rows.where((r) => r.status == _RowStatus.failed).length,
            },
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Table header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: _TableHeader(),
      ),
      // Rows
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _ValidationRowCard(row: filtered[i]),
        ),
      ),
      // Submit bar
      if (_canSubmit)
        _SubmitBar(
          okCount: _totalOk,
          onSubmit: _submit,
          loading: _loading,
        ),
    ]);
  }

  Widget _buildLoading(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: AppTheme.primary),
      const SizedBox(height: 20),
      Text(msg, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey600)),
    ]));
  }

  Widget _buildSuccess() {
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppTheme.statusGreen.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: AppTheme.statusGreen, size: 44),
        ),
        const SizedBox(height: 24),
        Text('Upload Complete!', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.grey900)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StatPill(label: 'Inserted',  value: _insertedCount ?? 0, color: AppTheme.statusGreen),
          const SizedBox(width: 12),
          _StatPill(label: 'Replaced', value: _replacedCount ?? 0, color: AppTheme.statusBlue),
        ]),
        const SizedBox(height: 12),
        Text(
          'Prior records for replaced employees have been marked inactive. All reports now reflect the latest data.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
        ),
        const SizedBox(height: 36),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Upload Another'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {},
            icon: const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white),
            label: Text('View Employees', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ]),
      ]),
    ));
  }
}

// ── Steps Sidebar (wide screens) ─────────────────────────────
class _StepsSidebar extends StatelessWidget {
  final int currentStep;
  const _StepsSidebar({required this.currentStep});

  static const _steps = [
    ('Download Template', Icons.download_outlined),
    ('Upload File', Icons.upload_file_outlined),
    ('Review & Validate', Icons.fact_check_outlined),
    ('Submit', Icons.cloud_done_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('STEPS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.grey500)),
        const SizedBox(height: 20),
        ...List.generate(_steps.length, (i) {
          final done    = i < currentStep;
          final current = i == currentStep;
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: done
                        ? AppTheme.statusGreen
                        : current
                            ? AppTheme.primary
                            : AppTheme.grey100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Icon(_steps[i].$2, size: 18,
                            color: current ? Colors.white : AppTheme.grey400),
                  ),
                ),
                if (i < _steps.length - 1)
                  Container(width: 2, height: 20, color: done ? AppTheme.statusGreen.withOpacity(0.3) : AppTheme.grey200),
              ]),
              const SizedBox(width: 14),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _steps[i].$1,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    color: current ? AppTheme.primary : done ? AppTheme.grey600 : AppTheme.grey400,
                  ),
                ),
              )),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Steps Top Bar (narrow screens) ───────────────────────────
class _StepsTopBar extends StatelessWidget {
  final int currentStep;
  const _StepsTopBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(children: List.generate(4, (i) {
        final done    = i < currentStep;
        final current = i == currentStep;
        return Expanded(child: Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: done ? AppTheme.statusGreen : current ? AppTheme.primary : AppTheme.grey200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: current ? Colors.white : AppTheme.grey500)),
            ),
          ),
          if (i < 3) Expanded(child: Container(height: 2, color: done ? AppTheme.statusGreen.withOpacity(0.4) : AppTheme.grey200)),
        ]));
      })),
    );
  }
}

// ── Step Wrapper ──────────────────────────────────────────────
class _StepWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepWrapper({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.grey900)),
        const SizedBox(height: 6),
        Text(subtitle, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey600)),
        const SizedBox(height: 28),
        child,
      ]),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey800, height: 1.6))),
      ]),
    );
  }
}

// ── Field Table (shows required/optional columns) ─────────────
class _FieldTable extends StatelessWidget {
  const _FieldTable();

  static const _fields = [
    ('employee_id *',       'Unique ID — alphanumeric, hyphens ok',         true),
    ('first_name *',        'Employee first name (max 100)',                 true),
    ('last_name *',         'Employee last name (max 100)',                  true),
    ('display_name',        'Display name (defaults to first+last)',         false),
    ('gender *',            'male / female / other',                         true),
    ('email *',             'Work email address',                            true),
    ('phone *',             '10-digit mobile, starts 6–9, or +91…',         true),
    ('alt_phone',           'Alternate phone (same format)',                 false),
    ('whatsapp_no',         'WhatsApp (defaults to phone if blank)',         false),
    ('date_of_birth',       'YYYY-MM-DD, age must be ≥ 18',                 false),
    ('date_of_joining *',   'YYYY-MM-DD format',                             true),
    ('org_role_level *',    'Role level 1–10 (1=Principal)',                 true),
    ('org_role_code',       'Role code e.g. SR_TEACHER',                    false),
    ('reports_to_emp_id',   'Manager\'s Employee ID (blank = top-level)',   false),
    ('branch_code',         'Branch code if multi-branch school',           false),
    ('address_line1',       'House/flat/street (max 255)',                   false),
    ('address_line2',       'Locality/landmark (max 255)',                   false),
    ('city',                'City of residence',                             false),
    ('state',               'Indian state full name (e.g. Uttar Pradesh)',  false),
    ('country',             'Country (defaults to India)',                   false),
    ('zip_code',            '6-digit PIN code',                              false),
    ('qualification',       'Highest qualification e.g. B.Ed (max 100)',    false),
    ('specialization',      'Subject specialisation (max 100)',              false),
    ('experience_years',    'Teaching/work experience in years (0–50)',      false),
    ('assigned_classes',    'Classes taught e.g. 4A,5B (comma-separated)',  false),
    ('subject_specialty',   'Primary subject specialty',                     false),
    ('is_temp',             'TRUE for temporary staff (default FALSE)',      false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(children: [
        // Header
        Container(
          decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(flex: 2, child: Text('Column', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey700))),
            Expanded(flex: 3, child: Text('Description', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey700))),
            Text('Required', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey700)),
          ]),
        ),
        ...List.generate(_fields.length, (i) {
          final (col, desc, req) = _fields[i];
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? Colors.white : AppTheme.grey50,
              border: Border(bottom: BorderSide(color: AppTheme.grey100)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(flex: 2, child: Text(col, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.grey900))),
              Expanded(flex: 3, child: Text(desc, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600))),
              req
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('Required', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.error)),
                    )
                  : Text('Optional', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey400)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Validation Summary ────────────────────────────────────────
class _ValidationSummary extends StatelessWidget {
  final int total;
  final int ok;
  final int fail;
  final bool canSubmit;
  final VoidCallback? onDownloadReport;

  const _ValidationSummary({
    required this.total,
    required this.ok,
    required this.fail,
    required this.canSubmit,
    this.onDownloadReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _SummaryTile(label: 'Total Rows', value: total, color: AppTheme.primary, icon: Icons.table_rows_outlined),
          const _Divider(),
          _SummaryTile(label: 'Ready', value: ok, color: AppTheme.statusGreen, icon: Icons.check_circle_outline),
          const _Divider(),
          _SummaryTile(label: 'Errors', value: fail, color: AppTheme.error, icon: Icons.cancel_outlined),
          const _Divider(),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(
              canSubmit ? Icons.verified : Icons.error_outline,
              color: canSubmit ? AppTheme.statusGreen : AppTheme.error,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              canSubmit ? 'Ready to submit' : 'Fix errors first',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: canSubmit ? AppTheme.statusGreen : AppTheme.error,
              ),
            ),
          ])),
        ]),
        if (onDownloadReport != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDownloadReport,
            icon: const Icon(Icons.download_outlined, size: 16, color: AppTheme.primary),
            label: Text('Download Validation Report', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _SummaryTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text('$value', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
    ]));
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppTheme.grey200, margin: const EdgeInsets.symmetric(horizontal: 6));
}

// ── Filter chips ──────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final _RowStatus? current;
  final ValueChanged<_RowStatus?> onChanged;
  final Map<_RowStatus, int> counts;

  const _FilterChips({required this.current, required this.onChanged, required this.counts});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, children: [
      _Chip(label: 'All',     selected: current == null,                   onTap: () => onChanged(null)),
      _Chip(label: '✓ ${counts[_RowStatus.success] ?? 0}', selected: current == _RowStatus.success, color: AppTheme.statusGreen, onTap: () => onChanged(_RowStatus.success)),
      _Chip(label: '⚠ ${counts[_RowStatus.warning] ?? 0}', selected: current == _RowStatus.warning, color: AppTheme.warning,     onTap: () => onChanged(_RowStatus.warning)),
      _Chip(label: '✗ ${counts[_RowStatus.failed] ?? 0}',  selected: current == _RowStatus.failed,  color: AppTheme.error,       onTap: () => onChanged(_RowStatus.failed)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, this.color = AppTheme.grey600, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppTheme.grey300),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.grey600)),
      ),
    );
  }
}

// ── Table Header ──────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.grey900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        _TH(label: 'Row',         flex: 1),
        _TH(label: 'Emp ID',      flex: 2),
        _TH(label: 'Name',        flex: 3),
        _TH(label: 'Status',      flex: 2),
        _TH(label: 'Issues',      flex: 4),
      ]),
    );
  }
}

class _TH extends StatelessWidget {
  final String label;
  final int flex;
  const _TH({required this.label, required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

// ── Validation Row Card ───────────────────────────────────────
class _ValidationRowCard extends StatefulWidget {
  final _ValidationRow row;
  const _ValidationRowCard({required this.row});

  @override
  State<_ValidationRowCard> createState() => _ValidationRowCardState();
}

class _ValidationRowCardState extends State<_ValidationRowCard> {
  bool _expanded = false;

  Color get _bgColor {
    switch (widget.row.status) {
      case _RowStatus.success: return const Color(0xFFF0FDF4);
      case _RowStatus.warning: return const Color(0xFFFFFBEB);
      case _RowStatus.failed:  return const Color(0xFFFFF1F0);
    }
  }

  Color get _borderColor {
    switch (widget.row.status) {
      case _RowStatus.success: return AppTheme.statusGreen;
      case _RowStatus.warning: return AppTheme.warning;
      case _RowStatus.failed:  return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasIssues = widget.row.errors.isNotEmpty || widget.row.warnings.isNotEmpty || widget.row.notes.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor.withOpacity(0.4)),
      ),
      child: Column(children: [
        InkWell(
          onTap: hasIssues ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              // Row #
              Expanded(flex: 1, child: Text(
                '${widget.row.row}',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.grey600),
              )),
              // Emp ID
              Expanded(flex: 2, child: Text(
                widget.row.empId,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey900),
              )),
              // Name
              Expanded(flex: 3, child: Text(
                widget.row.name.isEmpty ? '—' : widget.row.name,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey700),
                overflow: TextOverflow.ellipsis,
              )),
              // Status badge
              Expanded(flex: 2, child: _StatusBadge(status: widget.row.status)),
              // Issues summary + expand chevron
              Expanded(flex: 4, child: Row(children: [
                Expanded(child: Text(
                  _issuesSummary,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
                if (hasIssues)
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: AppTheme.grey500),
              ])),
            ]),
          ),
        ),
        if (_expanded && hasIssues)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in widget.row.errors)
                _IssueLine(icon: Icons.cancel, color: AppTheme.error, text: e),
              for (final w in widget.row.warnings)
                _IssueLine(icon: Icons.warning_amber_outlined, color: AppTheme.warning, text: w),
              for (final n in widget.row.notes)
                _IssueLine(icon: Icons.info_outline, color: AppTheme.primary, text: n),
            ]),
          ),
      ]),
    );
  }

  String get _issuesSummary {
    if (widget.row.errors.isNotEmpty) return widget.row.errors.first;
    if (widget.row.warnings.isNotEmpty) return widget.row.warnings.first;
    if (widget.row.notes.isNotEmpty) return widget.row.notes.first;
    return 'All checks passed';
  }
}

class _IssueLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _IssueLine({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800))),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _RowStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      _RowStatus.success => ('Ready',   AppTheme.statusGreen, Icons.check_circle),
      _RowStatus.warning => ('Warning', AppTheme.warning,     Icons.warning_amber),
      _RowStatus.failed  => ('Error',   AppTheme.error,       Icons.cancel),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Submit Bar ────────────────────────────────────────────────
class _SubmitBar extends StatelessWidget {
  final int okCount;
  final VoidCallback onSubmit;
  final bool loading;

  const _SubmitBar({required this.okCount, required this.onSubmit, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.grey200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -3))],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$okCount rows ready to import', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
          Text('Duplicates will have prior record deactivated', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
        ]),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: loading ? null : onSubmit,
          icon: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
          label: Text('Submit Import', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ]),
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('$value', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: color.withOpacity(0.8))),
      ]),
    );
  }
}
