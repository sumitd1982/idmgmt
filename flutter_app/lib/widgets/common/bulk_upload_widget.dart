// ============================================================
// Reusable Bulk Upload Widget (Student & Employee)
// Industry best-practice: Stage → Validate → Review → Confirm
// ============================================================
library bulk_upload_widget;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Config passed into the widget ─────────────────────────────
class BulkUploadConfig {
  final String entityType; // 'student' | 'employee'
  final String? schoolId;
  final String? branchId;
  final String templateDownloadPath;  // e.g. '/students/bulk-template/download'
  final String stagePath;             // e.g. '/students/bulk-upload/stage'
  final String reportPathPrefix;      // e.g. '/students/bulk-upload'  → /{batchId}/report
  final String confirmPathPrefix;     // e.g. '/students/bulk-upload'  → /{batchId}/confirm
  final List<_ColumnInfo> templateColumns;

  const BulkUploadConfig({
    required this.entityType,
    this.schoolId,
    this.branchId,
    required this.templateDownloadPath,
    required this.stagePath,
    required this.reportPathPrefix,
    required this.confirmPathPrefix,
    required this.templateColumns,
  });
}

class _ColumnInfo {
  final String name;
  final bool required;
  final String description;
  const _ColumnInfo(this.name, this.required, this.description);
}

// ── Pre-built configs ──────────────────────────────────────────
class BulkUploadConfigs {
  static BulkUploadConfig student({String? schoolId, String? branchId}) =>
      BulkUploadConfig(
        entityType: 'student',
        schoolId: schoolId,
        branchId: branchId,
        templateDownloadPath: '/students/bulk-template/download',
        stagePath: '/students/bulk-upload/stage',
        reportPathPrefix: '/students/bulk-upload',
        confirmPathPrefix: '/students/bulk-upload',
        templateColumns: const [
          _ColumnInfo('student_id', true, 'School-assigned unique student ID'),
          _ColumnInfo('first_name', true, 'First name'),
          _ColumnInfo('last_name', true, 'Last name'),
          _ColumnInfo('gender', true, 'male / female / other'),
          _ColumnInfo('date_of_birth', true, 'YYYY-MM-DD'),
          _ColumnInfo('class_name', true, 'e.g. Class 10'),
          _ColumnInfo('section', true, 'e.g. A'),
          _ColumnInfo('roll_number', false, 'Class roll number'),
          _ColumnInfo('blood_group', false, 'A+, B+, O+, AB+, etc.'),
          _ColumnInfo('guardian_type', true, 'father / mother / guardian1 / guardian2'),
          _ColumnInfo('guardian_name', true, 'Full name of guardian'),
          _ColumnInfo('guardian_phone', true, '10-digit mobile number'),
          _ColumnInfo('guardian_email', false, 'Guardian email'),
          _ColumnInfo('effective_start_date', false, 'YYYY-MM-DD — when this record is effective'),
          _ColumnInfo('change_reason', false, 'Reason for update (SCD history)'),
        ],
      );

  static BulkUploadConfig employee({String? schoolId, String? branchId}) =>
      BulkUploadConfig(
        entityType: 'employee',
        schoolId: schoolId,
        branchId: branchId,
        templateDownloadPath: '/employees/bulk-template/download',
        stagePath: '/employees/bulk-upload/stage',
        reportPathPrefix: '/employees/bulk-upload',
        confirmPathPrefix: '/employees/bulk-upload',
        templateColumns: const [
          _ColumnInfo('employee_id', true, 'School-assigned unique employee ID'),
          _ColumnInfo('first_name', true, 'First name'),
          _ColumnInfo('last_name', true, 'Last name'),
          _ColumnInfo('email', true, 'Work email'),
          _ColumnInfo('phone', true, '10-digit mobile number'),
          _ColumnInfo('gender', true, 'male / female / other'),
          _ColumnInfo('org_role_code', true, 'Role code from your org roles list'),
          _ColumnInfo('branch_code', false, 'Branch code — leave blank for school-level'),
          _ColumnInfo('date_of_joining', false, 'YYYY-MM-DD'),
          _ColumnInfo('reports_to_emp_id', false, 'Manager\'s employee ID'),
          _ColumnInfo('assigned_classes', false, 'Comma-separated classes e.g. Class 10,Class 11'),
          _ColumnInfo('qualification', false, 'Highest qualification'),
          _ColumnInfo('effective_start_date', false, 'YYYY-MM-DD'),
          _ColumnInfo('change_reason', false, 'Reason for update (SCD history)'),
        ],
      );
}

// ── State ──────────────────────────────────────────────────────
enum _UploadStep { template, upload, validating, review, confirm, done }

enum _RowStatus { success, warning, failed }

class _ValidationRow {
  final int row;
  final _RowStatus status;
  final String displayId;
  final String displayName;
  final List<String> errors;
  final List<String> warnings;
  final List<String> notes;

  const _ValidationRow({
    required this.row,
    required this.status,
    required this.displayId,
    required this.displayName,
    required this.errors,
    required this.warnings,
    required this.notes,
  });

  factory _ValidationRow.fromJson(Map<String, dynamic> j, String entityType) {
    final errs = List<String>.from(j['errors'] ?? []);
    final warns = List<String>.from(j['warnings'] ?? []);
    final ns = List<String>.from(j['notes'] ?? []);
    final st = j['status'] == 'failed'
        ? _RowStatus.failed
        : j['status'] == 'warning'
            ? _RowStatus.warning
            : _RowStatus.success;

    final data = j['data'] as Map<String, dynamic>? ?? {};
    final displayId = entityType == 'student'
        ? (data['stuId'] ?? data['student_id'] ?? '').toString()
        : (data['empId'] ?? data['employee_id'] ?? '').toString();
    final displayName = entityType == 'student'
        ? '${data['firstName'] ?? data['first_name'] ?? ''} ${data['lastName'] ?? data['last_name'] ?? ''}'.trim()
        : '${data['firstName'] ?? data['first_name'] ?? ''} ${data['lastName'] ?? data['last_name'] ?? ''}'.trim();

    return _ValidationRow(
      row: j['row'] ?? 0,
      status: st,
      displayId: displayId,
      displayName: displayName.isEmpty ? '—' : displayName,
      errors: errs,
      warnings: warns,
      notes: ns,
    );
  }
}

// ── Main Widget ────────────────────────────────────────────────
class BulkUploadWidget extends ConsumerStatefulWidget {
  final BulkUploadConfig config;
  final VoidCallback? onComplete;

  const BulkUploadWidget({
    super.key,
    required this.config,
    this.onComplete,
  });

  @override
  ConsumerState<BulkUploadWidget> createState() => _BulkUploadWidgetState();
}

class _BulkUploadWidgetState extends ConsumerState<BulkUploadWidget> {
  _UploadStep _step = _UploadStep.template;

  // File
  Uint8List? _fileBytes;
  String _fileName = '';

  // Validation results
  List<_ValidationRow> _rows = [];
  int _totalOk = 0;
  int _totalWarn = 0;
  int _totalFail = 0;
  String? _batchId;

  // Review filter & search
  _RowStatus? _filterStatus;
  String _searchTerm = '';
  final _searchCtrl = TextEditingController();

  // Confirm
  DateTime? _effectiveDate;
  String _changeReason = '';

  // Result
  int _inserted = 0;
  int _replaced = 0;
  int _skipped = 0;

  // Loading / error
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: pick file ─────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if ((file.size ?? 0) > 20 * 1024 * 1024) {
        _showError('File is too large (max 20 MB).');
        return;
      }
      setState(() {
        _fileBytes = file.bytes;
        _fileName = file.name;
        _error = null;
      });
    } catch (e) {
      _showError('Could not open file: $e');
    }
  }

  // ── Step 2: stage + validate ──────────────────────────────────
  Future<void> _stageAndValidate() async {
    if (_fileBytes == null) return;
    setState(() { _step = _UploadStep.validating; _loading = true; _error = null; });

    try {
      final api = ApiService();
      final extra = <String, String>{};
      if (widget.config.schoolId != null) extra['school_id'] = widget.config.schoolId!;
      if (widget.config.branchId != null) extra['branch_id'] = widget.config.branchId!;

      final resp = await api.uploadFile(
        widget.config.stagePath,
        bytes: _fileBytes!,
        fileName: _fileName,
        fields: extra,
      );

      final data = resp['data'] as Map<String, dynamic>? ?? {};
      final rawResults = data['results'] as List<dynamic>? ?? [];
      _batchId = data['batchId']?.toString() ?? data['batch_id']?.toString();

      final rows = rawResults
          .map((r) => _ValidationRow.fromJson(r as Map<String, dynamic>, widget.config.entityType))
          .toList();

      setState(() {
        _rows = rows;
        _totalOk = rows.where((r) => r.status == _RowStatus.success).length;
        _totalWarn = rows.where((r) => r.status == _RowStatus.warning).length;
        _totalFail = rows.where((r) => r.status == _RowStatus.failed).length;
        _step = _UploadStep.review;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Validation failed: $e'; _step = _UploadStep.upload; _loading = false; });
    }
  }

  // ── Step 3: download report ───────────────────────────────────
  Future<void> _downloadReport() async {
    if (_batchId == null) return;
    try {
      final api = ApiService();
      await api.downloadFile(
        '${widget.config.reportPathPrefix}/$_batchId/report',
        'validation_report_$_fileName',
      );
    } catch (e) {
      _showError('Could not download report: $e');
    }
  }

  // ── Step 4: confirm ───────────────────────────────────────────
  Future<void> _confirmUpload() async {
    if (_batchId == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      final api = ApiService();
      final body = <String, dynamic>{
        if (_effectiveDate != null)
          'effective_start_date': _effectiveDate!.toIso8601String().split('T').first,
        if (_changeReason.isNotEmpty) 'change_reason': _changeReason,
      };

      final resp = await api.post(
        '${widget.config.confirmPathPrefix}/$_batchId/confirm',
        body: body,
      );

      final data = resp['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _inserted = data['inserted'] ?? 0;
        _replaced = data['replaced'] ?? 0;
        _skipped = data['skipped'] ?? 0;
        _step = _UploadStep.done;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Submit failed: $e'; _loading = false; });
    }
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _reset() {
    setState(() {
      _step = _UploadStep.template;
      _fileBytes = null;
      _fileName = '';
      _rows = [];
      _batchId = null;
      _filterStatus = null;
      _searchTerm = '';
      _searchCtrl.clear();
      _effectiveDate = null;
      _changeReason = '';
      _error = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return isWide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Sidebar(step: _step, totalFail: _totalFail),
            const SizedBox(width: 24),
            Expanded(child: _buildStepContent()),
          ])
        : Column(children: [
            _TopStepBar(step: _step),
            const SizedBox(height: 16),
            _buildStepContent(),
          ]);
  }

  Widget _buildStepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          _UploadStep.template   => _buildTemplateStep(),
          _UploadStep.upload     => _buildUploadStep(),
          _UploadStep.validating => _buildValidatingStep(),
          _UploadStep.review     => _buildReviewStep(),
          _UploadStep.confirm    => _buildConfirmStep(),
          _UploadStep.done       => _buildDoneStep(),
        },
      ),
    );
  }

  // STEP 1 — Download Template
  Widget _buildTemplateStep() {
    final cols = widget.config.templateColumns;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon: Icons.download_rounded,
          title: 'Download Template',
          subtitle: 'Use the official template — other formats may be rejected',
        ),
        const SizedBox(height: 20),
        _InfoBanner(
          icon: Icons.info_outline,
          color: Colors.blue,
          text: 'Fill in the template. Columns marked * are mandatory. '
              'Date format: YYYY-MM-DD. Do not rename column headers.',
        ),
        const SizedBox(height: 20),
        Text('Template Columns', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade200, width: 1),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(3)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: ['Column', 'Required', 'Description']
                    .map((h) => Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(h, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                        ))
                    .toList(),
              ),
              ...cols.map((c) => TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(c.name, style: GoogleFonts.firaCode(fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: c.required
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                          : const Icon(Icons.remove, color: Colors.grey, size: 16),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(c.description, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                    ),
                  ])),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                await ApiService().downloadFile(
                  widget.config.templateDownloadPath,
                  '${widget.config.entityType}_bulk_template.xlsx',
                );
              } catch (e) {
                _showError('Download failed: $e');
              }
            },
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('I already have a file →'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _step = _UploadStep.upload),
          ),
        ]),
      ]),
    );
  }

  // STEP 2 — Upload File
  Widget _buildUploadStep() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon: Icons.upload_file_rounded,
          title: 'Upload File',
          subtitle: 'Select your filled XLSX file (max 20 MB)',
        ),
        const SizedBox(height: 20),
        // Drop zone
        GestureDetector(
          onTap: _pickFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: _fileBytes != null ? Colors.green.shade50 : Colors.grey.shade50,
              border: Border.all(
                color: _fileBytes != null ? Colors.green.shade400 : Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Icon(
                _fileBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                size: 48,
                color: _fileBytes != null ? Colors.green.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                _fileBytes != null ? _fileName : 'Click to select XLSX file',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _fileBytes != null ? Colors.green.shade700 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              if (_fileBytes == null) ...[
                const SizedBox(height: 4),
                Text('.xlsx or .xls — max 20 MB',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
              ],
            ]),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _InfoBanner(icon: Icons.error_outline, color: Colors.red, text: _error!),
        ],
        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(
            onPressed: () => setState(() => _step = _UploadStep.template),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('← Back'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Validate File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _fileBytes != null ? _stageAndValidate : null,
          ),
        ]),
      ]),
    );
  }

  // STEP 3 — Validating (progress indicator)
  Widget _buildValidatingStep() {
    return _Card(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: Color(0xFF1A237E)),
        const SizedBox(height: 24),
        Text('Validating your file…',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Checking against existing records, reference tables, and required fields.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
      ]),
    );
  }

  // STEP 4 — Review Results
  Widget _buildReviewStep() {
    final filtered = _rows.where((r) {
      final statusMatch = _filterStatus == null || r.status == _filterStatus;
      final searchMatch = _searchTerm.isEmpty ||
          r.displayId.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          r.displayName.toLowerCase().contains(_searchTerm.toLowerCase());
      return statusMatch && searchMatch;
    }).toList();

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon: Icons.rule_rounded,
          title: 'Validation Results',
          subtitle: '${_rows.length} rows processed — review before submitting',
        ),
        const SizedBox(height: 16),

        // Summary cards
        Row(children: [
          _SummaryChip(
            label: 'Total', count: _rows.length,
            color: Colors.grey.shade700, icon: Icons.table_rows_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Success', count: _totalOk,
            color: Colors.green.shade700, icon: Icons.check_circle_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Warning', count: _totalWarn,
            color: Colors.orange.shade700, icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Failed', count: _totalFail,
            color: Colors.red.shade700, icon: Icons.cancel_rounded,
          ),
        ]),

        if (_totalFail > 0) ...[
          const SizedBox(height: 12),
          _InfoBanner(
            icon: Icons.block,
            color: Colors.red,
            text: '$_totalFail row(s) have errors and will be skipped on submit. '
                'Download the report to fix them and re-upload.',
          ),
        ],

        const SizedBox(height: 16),

        // Filter + search + download
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchTerm = v),
              decoration: InputDecoration(
                hintText: 'Search by ID or name…',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                isDense: true,
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip2(
            label: 'All', selected: _filterStatus == null,
            onTap: () => setState(() => _filterStatus = null),
          ),
          const SizedBox(width: 4),
          _FilterChip2(
            label: '✓ OK', selected: _filterStatus == _RowStatus.success,
            color: Colors.green, onTap: () => setState(() => _filterStatus = _RowStatus.success),
          ),
          const SizedBox(width: 4),
          _FilterChip2(
            label: '⚠ Warn', selected: _filterStatus == _RowStatus.warning,
            color: Colors.orange, onTap: () => setState(() => _filterStatus = _RowStatus.warning),
          ),
          const SizedBox(width: 4),
          _FilterChip2(
            label: '✕ Fail', selected: _filterStatus == _RowStatus.failed,
            color: Colors.red, onTap: () => setState(() => _filterStatus = _RowStatus.failed),
          ),
          const SizedBox(width: 8),
          if (_batchId != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export Report'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _downloadReport,
            ),
        ]),

        const SizedBox(height: 12),

        // Table
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade200, width: 1),
                columnWidths: const {
                  0: FixedColumnWidth(56),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(90),
                  4: FlexColumnWidth(3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: ['Row', 'ID', 'Name', 'Status', 'Issues']
                        .map((h) => Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(h, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                            ))
                        .toList(),
                  ),
                  ...filtered.map((r) {
                    final statusColor = r.status == _RowStatus.failed
                        ? Colors.red.shade50
                        : r.status == _RowStatus.warning
                            ? Colors.orange.shade50
                            : Colors.white;
                    final issues = [...r.errors, ...r.warnings].take(3).join('; ');
                    return TableRow(
                      decoration: BoxDecoration(color: statusColor),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text('${r.row}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(r.displayId, style: GoogleFonts.firaCode(fontSize: 12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(r.displayName, style: GoogleFonts.inter(fontSize: 12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: _StatusBadge(r.status),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            issues.isEmpty ? (r.notes.firstOrNull ?? '—') : issues,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Row(children: [
          OutlinedButton(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('← Start Over'),
          ),
          const Spacer(),
          Text(
            '${_totalOk + _totalWarn} of ${_rows.length} rows will be submitted',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.navigate_next_rounded, size: 18),
            label: const Text('Proceed to Submit →'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: (_totalOk + _totalWarn) > 0
                ? () => setState(() => _step = _UploadStep.confirm)
                : null,
          ),
        ]),
      ]),
    );
  }

  // STEP 5 — Confirm
  Widget _buildConfirmStep() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon: Icons.send_rounded,
          title: 'Confirm & Submit',
          subtitle: 'Review the summary, set effective date, and submit',
        ),
        const SizedBox(height: 20),
        _InfoBanner(
          icon: Icons.info_outline,
          color: Colors.blue,
          text: 'Existing records with matching IDs will be closed (SCD Type 2) and replaced with new versions. '
              'Failed rows are skipped.',
        ),
        const SizedBox(height: 20),
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Submission Summary',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            _SummaryRow('Will be inserted/updated', '${_totalOk + _totalWarn}', Colors.green),
            _SummaryRow('Will be skipped (failed)', '$_totalFail', Colors.red),
            _SummaryRow('Total rows in file', '${_rows.length}', Colors.grey.shade700),
          ]),
        ),
        const SizedBox(height: 20),
        // Effective date
        Text('Effective Start Date (optional)',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(_effectiveDate == null
                ? 'Select date (defaults to today)'
                : '${_effectiveDate!.year}-${_effectiveDate!.month.toString().padLeft(2,'0')}-${_effectiveDate!.day.toString().padLeft(2,'0')}'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _effectiveDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2099),
              );
              if (d != null) setState(() => _effectiveDate = d);
            },
          ),
          if (_effectiveDate != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _effectiveDate = null),
              child: const Text('Clear'),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        Text('Change Reason (optional)',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => _changeReason = v,
          decoration: InputDecoration(
            hintText: 'e.g. Annual roll update 2026-27',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: GoogleFonts.inter(fontSize: 13),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _InfoBanner(icon: Icons.error_outline, color: Colors.red, text: _error!),
        ],
        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(
            onPressed: _loading ? null : () => setState(() => _step = _UploadStep.review),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('← Back'),
          ),
          const Spacer(),
          ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(_loading ? 'Submitting…' : 'Submit ${_totalOk + _totalWarn} Records'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _loading ? null : _confirmUpload,
          ),
        ]),
      ]),
    );
  }

  // STEP 6 — Done
  Widget _buildDoneStep() {
    return _Card(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 44, color: Colors.green.shade600),
        ),
        const SizedBox(height: 20),
        Text('Upload Complete!',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          '$_inserted record(s) inserted'
          '${_replaced > 0 ? ', $_replaced replaced (SCD)' : ''}'
          '${_skipped > 0 ? ', $_skipped skipped' : ''}.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Upload Another'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _reset,
          ),
          if (widget.onComplete != null) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('View Records'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: widget.onComplete,
            ),
          ],
        ]),
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ── Supporting Widgets ─────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: child,
      );
}

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1A237E), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
      ]);
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: color.withOpacity(0.9)))),
        ]),
      );
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SummaryChip({required this.label, required this.count, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(children: [
              Text('$count', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: color)),
            ]),
          ]),
        ),
      );
}

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip2({required this.label, required this.selected, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1A237E);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? c : Colors.grey.shade300),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? c : Colors.grey.shade700,
            )),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _RowStatus status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _RowStatus.success => ('✓ OK', Colors.green),
      _RowStatus.warning => ('⚠ Warn', Colors.orange),
      _RowStatus.failed  => ('✕ Fail', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700))),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}

// ── Sidebar / Step Indicators ──────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _UploadStep step;
  final int totalFail;
  const _Sidebar({required this.step, required this.totalFail});

  static const _steps = [
    (Icons.download_rounded, 'Download Template'),
    (Icons.upload_file_rounded, 'Upload File'),
    (Icons.rule_rounded, 'Validate'),
    (Icons.manage_search_rounded, 'Review Results'),
    (Icons.send_rounded, 'Confirm & Submit'),
    (Icons.check_circle_rounded, 'Done'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = step.index;
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length, (i) {
          final (icon, label) = _steps[i];
          final isDone = i < current;
          final isActive = i == current;
          final color = isDone
              ? Colors.green.shade600
              : isActive
                  ? const Color(0xFF1A237E)
                  : Colors.grey.shade400;
          return Column(children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(isActive ? 0.12 : 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: isActive ? 2 : 1),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : icon,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                      color: isActive ? const Color(0xFF1A237E) : color,
                    )),
              ),
            ]),
            if (i < _steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Container(width: 2, height: 20, color: Colors.grey.shade200),
              ),
          ]);
        }),
      ),
    );
  }
}

class _TopStepBar extends StatelessWidget {
  final _UploadStep step;
  const _TopStepBar({required this.step});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          final isActive = i == step.index;
          final isDone = i < step.index;
          return Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.green.shade600
                    : isActive
                        ? const Color(0xFF1A237E)
                        : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('${i + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.grey.shade500,
                        )),
              ),
            ),
            if (i < 5)
              Container(
                width: 24,
                height: 2,
                color: i < step.index ? Colors.green.shade600 : Colors.grey.shade200,
              ),
          ]);
        }),
      );
}
