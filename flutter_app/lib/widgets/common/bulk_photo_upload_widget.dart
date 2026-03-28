// ============================================================
// Bulk Photo Upload Widget — Employee & Student
// Flow: Guide → Upload ZIP → Validating → Review → Applying → Done
// ============================================================
library bulk_photo_upload_widget;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

// ── Config ─────────────────────────────────────────────────────────────────

class BulkPhotoUploadConfig {
  final String entityType;          // 'employee' | 'student'
  final String? schoolId;
  final String? branchId;
  final String namingGuidePath;     // e.g. /employees/bulk-photos/naming-guide
  final String validatePath;        // e.g. /employees/bulk-photos/validate
  final String applyPath;           // e.g. /employees/bulk-photos/apply
  final String historyPath;         // e.g. /employees/bulk-photos/history

  const BulkPhotoUploadConfig({
    required this.entityType,
    this.schoolId,
    this.branchId,
    required this.namingGuidePath,
    required this.validatePath,
    required this.applyPath,
    required this.historyPath,
  });
}

class BulkPhotoUploadConfigs {
  static BulkPhotoUploadConfig employee({String? schoolId, String? branchId}) =>
      BulkPhotoUploadConfig(
        entityType:      'employee',
        schoolId:        schoolId,
        branchId:        branchId,
        namingGuidePath: '/employees/bulk-photos/naming-guide',
        validatePath:    '/employees/bulk-photos/validate',
        applyPath:       '/employees/bulk-photos/apply',
        historyPath:     '/employees/bulk-photos/history',
      );

  static BulkPhotoUploadConfig student({String? schoolId, String? branchId}) =>
      BulkPhotoUploadConfig(
        entityType:      'student',
        schoolId:        schoolId,
        branchId:        branchId,
        namingGuidePath: '/students/bulk-photos/naming-guide',
        validatePath:    '/students/bulk-photos/validate',
        applyPath:       '/students/bulk-photos/apply',
        historyPath:     '/students/bulk-photos/history',
      );
}

// ── Result models ───────────────────────────────────────────────────────────

enum _PhotoRowStatus { matched, unmatched, skipped, error }

class _PhotoRow {
  final String file;
  final String entityId;
  final String? fullName;
  final _PhotoRowStatus status;
  final String? reason;
  final String? matchMethod;
  final bool hasExistingPhoto;
  final List<String> warnings;
  final String? photoUrl;         // set after apply

  const _PhotoRow({
    required this.file,
    required this.entityId,
    this.fullName,
    required this.status,
    this.reason,
    this.matchMethod,
    this.hasExistingPhoto = false,
    this.warnings = const [],
    this.photoUrl,
  });

  factory _PhotoRow.fromJson(Map<String, dynamic> j) {
    final s = j['status'] as String? ?? 'unmatched';
    _PhotoRowStatus st;
    switch (s) {
      case 'matched':  st = _PhotoRowStatus.matched;   break;
      case 'skipped':  st = _PhotoRowStatus.skipped;   break;
      case 'error':    st = _PhotoRowStatus.error;     break;
      default:         st = _PhotoRowStatus.unmatched;
    }
    return _PhotoRow(
      file:             j['file']   as String? ?? '',
      entityId:         j['entityId'] as String? ?? '',
      fullName:         j['fullName'] as String?,
      status:           st,
      reason:           j['reason'] as String?,
      matchMethod:      j['matchMethod'] as String?,
      hasExistingPhoto: j['hasExistingPhoto'] == true,
      warnings:         List<String>.from(j['warnings'] ?? []),
      photoUrl:         j['photoUrl'] as String?,
    );
  }
}

// ── Steps ───────────────────────────────────────────────────────────────────

enum _Step { guide, upload, validating, review, applying, done }

// ── Widget ──────────────────────────────────────────────────────────────────

class BulkPhotoUploadWidget extends ConsumerStatefulWidget {
  final BulkPhotoUploadConfig config;
  final VoidCallback? onDone;

  const BulkPhotoUploadWidget({
    super.key,
    required this.config,
    this.onDone,
  });

  @override
  ConsumerState<BulkPhotoUploadWidget> createState() => _BulkPhotoUploadWidgetState();
}

class _BulkPhotoUploadWidgetState extends ConsumerState<BulkPhotoUploadWidget> {
  _Step _step    = _Step.guide;
  bool  _loading = false;
  String? _error;

  // Upload state
  Uint8List? _zipBytes;
  String     _zipName = '';

  // Validate results
  String?        _batchId;
  List<_PhotoRow> _rows           = [];
  int _matched    = 0;
  int _unmatched  = 0;
  int _warnings   = 0;
  List<String> _xlsxWarnings = [];
  List<Map<String, dynamic>> _skipped = [];

  // Review filters
  _PhotoRowStatus? _filterStatus;
  String           _searchTerm = '';
  String           _uploadMode = 'partial'; // 'full' | 'partial'
  bool             _missingOnly = false;

  // Apply results
  int _processed = 0;
  int _failed    = 0;

  BulkPhotoUploadConfig get cfg => widget.config;
  String get _entityLabel => cfg.entityType == 'employee' ? 'Employee' : 'Student';

  // ── API calls ────────────────────────────────────────────────────────────

  Map<String, String> get _queryParams => {
    if (cfg.schoolId != null) 'school_id': cfg.schoolId!,
    if (cfg.branchId != null) 'branch_id': cfg.branchId!,
  };

  String _buildPath(String base) {
    if (_queryParams.isEmpty) return base;
    final q = _queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$base?$q';
  }

  Future<void> _downloadNamingGuide() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final path = _buildPath(cfg.namingGuidePath) +
          (_queryParams.isEmpty ? '?' : '&') +
          'missing_only=${_missingOnly}';
      await api.downloadFile(path, '${cfg.entityType}_photo_naming_guide.xlsx');
    } catch (e) {
      setState(() => _error = 'Download failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type:              FileType.custom,
      allowedExtensions: ['zip'],
      withData:          true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) {
      setState(() => _error = 'Could not read file — try again');
      return;
    }
    final mb = (f.bytes!.length / (1024 * 1024));
    if (mb > 200) {
      setState(() => _error = 'ZIP file exceeds 200 MB limit (${mb.toStringAsFixed(1)} MB)');
      return;
    }
    setState(() {
      _zipBytes = f.bytes;
      _zipName  = f.name;
      _error    = null;
    });
  }

  Future<void> _validate() async {
    if (_zipBytes == null) return;
    setState(() { _step = _Step.validating; _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final fields = <String, String>{
        if (cfg.schoolId != null) 'school_id': cfg.schoolId!,
        if (cfg.branchId != null) 'branch_id': cfg.branchId!,
      };
      final res = await api.uploadFile(
        cfg.validatePath,
        bytes:     _zipBytes,
        fileName:  _zipName,
        fieldName: 'file',
        fields:    fields,
      );

      final d = (res['data'] ?? res) as Map<String, dynamic>;
      _batchId   = d['batchId']  as String?;
      _matched   = (d['matched']   as num? ?? 0).toInt();
      _unmatched = (d['unmatched'] as num? ?? 0).toInt();
      _warnings  = (d['warnings']  as num? ?? 0).toInt();
      _rows      = ((d['results']  as List?) ?? []).map((e) => _PhotoRow.fromJson(e as Map<String, dynamic>)).toList();
      _xlsxWarnings = List<String>.from(d['xlsxFiles'] ?? []);
      _skipped   = List<Map<String, dynamic>>.from(d['skippedFiles'] ?? []);

      // Default mode
      _uploadMode = _unmatched > 0 ? 'partial' : 'full';

      setState(() { _step = _Step.review; _loading = false; });
    } catch (e) {
      setState(() { _step = _Step.upload; _loading = false; _error = 'Validation failed: $e'; });
    }
  }

  Future<void> _apply() async {
    if (_batchId == null) return;

    if (_uploadMode == 'full' && _unmatched > 0) {
      setState(() => _error = 'Full upload requires all files to be matched. Switch to Partial or fix unmatched files.');
      return;
    }

    setState(() { _step = _Step.applying; _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post(cfg.applyPath, body: {
        'batch_id': _batchId,
        'mode':     _uploadMode,
      });

      final d = (res['data'] ?? res) as Map<String, dynamic>;
      _processed = (d['processed'] as num? ?? 0).toInt();
      _failed    = (d['failed']    as num? ?? 0).toInt();

      setState(() { _step = _Step.done; _loading = false; });
      widget.onDone?.call();
    } catch (e) {
      setState(() { _step = _Step.review; _loading = false; _error = 'Apply failed: $e'; });
    }
  }

  void _reset() {
    setState(() {
      _step         = _Step.guide;
      _zipBytes     = null;
      _zipName      = '';
      _batchId      = null;
      _rows         = [];
      _matched      = 0;
      _unmatched    = 0;
      _warnings     = 0;
      _xlsxWarnings = [];
      _skipped      = [];
      _processed    = 0;
      _failed       = 0;
      _filterStatus = null;
      _searchTerm   = '';
      _error        = null;
      _loading      = false;
    });
  }

  // ── Filtered rows ────────────────────────────────────────────────────────

  List<_PhotoRow> get _filteredRows {
    return _rows.where((r) {
      if (_filterStatus != null && r.status != _filterStatus) return false;
      if (_searchTerm.isNotEmpty) {
        final q = _searchTerm.toLowerCase();
        return r.entityId.toLowerCase().contains(q) ||
            (r.fullName?.toLowerCase().contains(q) ?? false) ||
            r.file.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepper(),
        const SizedBox(height: 20),
        if (_error != null) _buildError(),
        _buildBody(),
      ],
    );
  }

  Widget _buildStepper() {
    const steps = [
      (_Step.guide,       'Guide',    Icons.menu_book_rounded),
      (_Step.upload,      'Upload',   Icons.upload_file_rounded),
      (_Step.validating,  'Validate', Icons.fact_check_rounded),
      (_Step.review,      'Review',   Icons.preview_rounded),
      (_Step.applying,    'Apply',    Icons.check_circle_outline_rounded),
      (_Step.done,        'Done',     Icons.celebration_rounded),
    ];

    final idx = steps.indexWhere((s) => s.$1 == _step);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done    = stepIdx < idx;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? AppTheme.primary : AppTheme.primary.withOpacity(0.15),
              ),
            );
          }
          final si   = i ~/ 2;
          final step = steps[si];
          final done = si < idx;
          final curr = si == idx;
          return _StepDot(
            icon:  step.$3,
            label: step.$2,
            done:  done,
            active: curr,
          );
        }),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error))),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => setState(() => _error = null),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.guide:      return _buildGuideStep();
      case _Step.upload:     return _buildUploadStep();
      case _Step.validating: return _buildLoadingStep('Validating ZIP file…');
      case _Step.review:     return _buildReviewStep();
      case _Step.applying:   return _buildLoadingStep('Processing photos…');
      case _Step.done:       return _buildDoneStep();
    }
  }

  // ── STEP 0: Guide ────────────────────────────────────────────────────────

  Widget _buildGuideStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        icon: Icons.lightbulb_outline_rounded,
        iconColor: AppTheme.warning,
        title: 'How Bulk Photo Upload Works',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _GuideStep(n: '1', text: 'Download the Naming Guide to see all ${_entityLabel.toLowerCase()}s and their current photo status.'),
          _GuideStep(n: '2', text: 'Rename each photo to the ${_entityLabel} ID (e.g.  EMP-001.jpg  or  STU-042.png).'),
          _GuideStep(n: '3', text: 'Put all renamed photos into a folder and compress it to a ZIP file.'),
          _GuideStep(n: '4', text: 'Upload the ZIP here — we\'ll match photos to ${_entityLabel.toLowerCase()}s and show you a preview.'),
          _GuideStep(n: '5', text: 'Review the matches and confirm to apply.'),
        ]),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        icon: Icons.rule_rounded,
        iconColor: AppTheme.info,
        title: 'Matching Rules',
        child: Table(
          columnWidths: const { 0: FlexColumnWidth(2), 1: FlexColumnWidth(3) },
          children: const [
            TableRow(children: [
              _TableCell('Exact match',   bold: true),
              _TableCell('EMP-001.jpg  →  EMP-001'),
            ]),
            TableRow(children: [
              _TableCell('Loose match',  bold: true),
              _TableCell('EMP001.jpg  →  EMP-001  (hyphens stripped)'),
            ]),
            TableRow(children: [
              _TableCell('Phone match',  bold: true),
              _TableCell('9876543210.jpg  →  employee with that phone (employees only)'),
            ]),
            TableRow(children: [
              _TableCell('Case-insensitive', bold: true),
              _TableCell('emp-001.JPG  ===  EMP-001'),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        icon: Icons.folder_zip_outlined,
        iconColor: AppTheme.primary,
        title: 'File Requirements',
        child: Wrap(spacing: 24, runSpacing: 8, children: const [
          _InfoChip(icon: Icons.image_outlined,          label: 'Formats: jpg, jpeg, png, webp, gif'),
          _InfoChip(icon: Icons.folder_zip_rounded,     label: 'Max ZIP: 200 MB'),
          _InfoChip(icon: Icons.photo_size_select_large, label: 'Per photo warning: >8 MB'),
          _InfoChip(icon: Icons.crop_rounded,           label: 'Output: 400×400 WebP'),
        ]),
      ),
      const SizedBox(height: 24),

      // Naming guide download section
      Text('Naming Guide', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(
        'Download this XLSX to see all ${_entityLabel.toLowerCase()}s, their current photo status, and the exact filename to use.',
        style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black54),
      ),
      const SizedBox(height: 10),
      Row(children: [
        // Missing only toggle
        _ToggleChip(
          label: 'Show only missing photos',
          active: _missingOnly,
          onTap: () => setState(() => _missingOnly = !_missingOnly),
        ),
        const Spacer(),
        if (_loading)
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
        else
          FilledButton.icon(
            onPressed: _downloadNamingGuide,
            icon: const Icon(Icons.download_rounded, size: 17),
            label: Text('Download Naming Guide', style: GoogleFonts.poppins(fontSize: 13)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
      ]),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FilledButton.icon(
          onPressed: () => setState(() { _step = _Step.upload; _error = null; }),
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: Text('Next: Upload ZIP', style: GoogleFonts.poppins(fontSize: 13)),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
        ),
      ]),
    ]);
  }

  // ── STEP 1: Upload ───────────────────────────────────────────────────────

  Widget _buildUploadStep() {
    final hasFile = _zipBytes != null;
    final sizeMb  = hasFile ? (_zipBytes!.length / (1024 * 1024)) : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: _pickZip,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: hasFile
                ? AppTheme.success.withOpacity(0.05)
                : AppTheme.primary.withOpacity(0.04),
            border: Border.all(
              color: hasFile ? AppTheme.success : AppTheme.primary.withOpacity(0.2),
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.folder_zip_rounded,
              size: 48,
              color: hasFile ? AppTheme.success : AppTheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            if (hasFile) ...[
              Text(_zipName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${sizeMb.toStringAsFixed(1)} MB', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
            ] else ...[
              Text('Click to select ZIP file', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              const SizedBox(height: 4),
              Text('Max 200 MB · Only .zip files accepted', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      Row(children: [
        OutlinedButton.icon(
          onPressed: () => setState(() { _step = _Step.guide; _error = null; }),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text('Back', style: GoogleFonts.poppins(fontSize: 13)),
        ),
        const Spacer(),
        if (hasFile)
          FilledButton.icon(
            onPressed: _loading ? null : _validate,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.fact_check_rounded, size: 17),
            label: Text('Validate ZIP', style: GoogleFonts.poppins(fontSize: 13)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
      ]),
    ]);
  }

  // ── STEP loading ─────────────────────────────────────────────────────────

  Widget _buildLoadingStep(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(msg, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54)),
        ]),
      ),
    );
  }

  // ── STEP 2: Review ───────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final filtered = _filteredRows;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Summary bar
      Wrap(spacing: 10, runSpacing: 8, children: [
        _SummaryChip(
          label: '$_matched matched',
          icon: Icons.check_circle_rounded,
          color: AppTheme.success,
          active: _filterStatus == _PhotoRowStatus.matched,
          onTap: () => setState(() => _filterStatus = _filterStatus == _PhotoRowStatus.matched ? null : _PhotoRowStatus.matched),
        ),
        _SummaryChip(
          label: '$_unmatched unmatched',
          icon: Icons.help_outline_rounded,
          color: AppTheme.warning,
          active: _filterStatus == _PhotoRowStatus.unmatched,
          onTap: () => setState(() => _filterStatus = _filterStatus == _PhotoRowStatus.unmatched ? null : _PhotoRowStatus.unmatched),
        ),
        if (_warnings > 0)
          _SummaryChip(
            label: '$_warnings with warnings',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.accent,
            active: false,
            onTap: () {},
          ),
      ]),

      // XLSX warning
      if (_xlsxWarnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.table_chart_rounded, color: AppTheme.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'ZIP contains spreadsheet file(s): ${_xlsxWarnings.join(', ')} — these were skipped.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.warning),
            )),
          ]),
        ),
      ],

      const SizedBox(height: 14),

      // Upload mode selector
      Row(children: [
        Text('Apply mode:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        _ModeChip(
          label: 'Partial',
          subtitle: 'Apply matched, skip unmatched',
          selected: _uploadMode == 'partial',
          onTap: () => setState(() => _uploadMode = 'partial'),
        ),
        const SizedBox(width: 8),
        _ModeChip(
          label: 'Full',
          subtitle: 'Abort if any unmatched',
          selected: _uploadMode == 'full',
          enabled: _unmatched == 0,
          onTap: () {
            if (_unmatched > 0) {
              setState(() => _error = 'Cannot use Full mode: $_unmatched file(s) are unmatched.');
            } else {
              setState(() => _uploadMode = 'full');
            }
          },
        ),
      ]),

      const SizedBox(height: 14),

      // Search
      TextField(
        decoration: InputDecoration(
          hintText: 'Search by filename, ${_entityLabel.toLowerCase()} ID or name…',
          hintStyle: GoogleFonts.poppins(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        style: GoogleFonts.poppins(fontSize: 13),
        onChanged: (v) => setState(() => _searchTerm = v.trim()),
      ),

      const SizedBox(height: 12),

      // Results table
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No results match your filter.', style: GoogleFonts.poppins(color: Colors.black45))),
        )
      else
        _buildResultsTable(filtered),

      const SizedBox(height: 20),

      // Action row
      Row(children: [
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text('Upload Different ZIP', style: GoogleFonts.poppins(fontSize: 13)),
        ),
        const Spacer(),
        if (_matched > 0)
          FilledButton.icon(
            onPressed: _loading ? null : _apply,
            icon: const Icon(Icons.cloud_upload_rounded, size: 17),
            label: Text(
              _uploadMode == 'partial'
                  ? 'Apply $_matched Photo${_matched != 1 ? 's' : ''}'
                  : 'Apply All Photos',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
      ]),
    ]);
  }

  Widget _buildResultsTable(List<_PhotoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Header
            Container(
              color: AppTheme.primary.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                _TblHdr('File',              flex: 3),
                _TblHdr('${_entityLabel} ID', flex: 2),
                _TblHdr('Name',              flex: 3),
                _TblHdr('Status',            flex: 2),
                _TblHdr('Note',              flex: 3),
              ]),
            ),
            // Rows
            ...rows.asMap().entries.map((e) {
              final idx  = e.key;
              final row  = e.value;
              return Container(
                color: idx.isEven ? Colors.white : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // File
                  Expanded(flex: 3, child: Text(
                    row.file,
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  )),
                  // Entity ID
                  Expanded(flex: 2, child: Text(
                    row.entityId,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  )),
                  // Full name
                  Expanded(flex: 3, child: Text(
                    row.fullName ?? '—',
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  )),
                  // Status badge
                  Expanded(flex: 2, child: _StatusBadge(row.status)),
                  // Warnings / reason
                  Expanded(flex: 3, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.reason != null)
                        Text(row.reason!, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.warning)),
                      ...row.warnings.map((w) => Text(
                        '⚠ $w',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45),
                      )),
                    ],
                  )),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── STEP 3: Done ─────────────────────────────────────────────────────────

  Widget _buildDoneStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 64),
          const SizedBox(height: 16),
          Text('Photos Applied!', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '$_processed photo${_processed != 1 ? 's' : ''} updated successfully'
            '${_failed > 0 ? ',  $_failed failed' : ''}',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.upload_file_rounded, size: 17),
            label: Text('Upload Another Batch', style: GoogleFonts.poppins(fontSize: 13)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ]),
      ),
    );
  }
}

// ── Private helper widgets ──────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     done;
  final bool     active;
  const _StepDot({required this.icon, required this.label, this.done = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    final Color bg = done ? AppTheme.success : active ? AppTheme.primary : Colors.grey.shade300;
    final Color fg = (done || active) ? Colors.white : Colors.grey.shade500;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 16),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: active ? AppTheme.primary : Colors.black45,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final Widget   child;
  const _SectionCard({required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String n;
  final String text;
  const _GuideStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          child: Center(child: Text(n, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 13))),
      ]),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool   bold;
  const _TableCell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: AppTheme.primary.withOpacity(0.7)),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.poppins(fontSize: 12.5)),
    ]);
  }
}

class _ToggleChip extends StatelessWidget {
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: active ? AppTheme.primary : Colors.black26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 15, color: active ? AppTheme.primary : Colors.black45),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: active ? AppTheme.primary : Colors.black54)),
        ]),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     active;
  final VoidCallback onTap;
  const _SummaryChip({required this.label, required this.icon, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : color.withOpacity(0.06),
          border: Border.all(color: active ? color : color.withOpacity(0.3), width: active ? 1.5 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.poppins(fontSize: 12.5, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final bool     selected;
  final bool     enabled;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.subtitle, required this.selected, this.enabled = true, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color active = AppTheme.primary;
    final Color muted  = Colors.black26;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? active.withOpacity(0.08) : Colors.transparent,
            border: Border.all(color: selected ? active : muted, width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 14, color: selected ? active : muted),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? active : Colors.black87)),
            ]),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45)),
          ]),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _PhotoRowStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label; IconData icon;
    switch (status) {
      case _PhotoRowStatus.matched:
        bg = AppTheme.success; fg = Colors.white; label = 'Matched'; icon = Icons.check_rounded; break;
      case _PhotoRowStatus.unmatched:
        bg = AppTheme.warning; fg = Colors.white; label = 'No match'; icon = Icons.help_rounded; break;
      case _PhotoRowStatus.skipped:
        bg = Colors.grey.shade400; fg = Colors.white; label = 'Skipped'; icon = Icons.skip_next_rounded; break;
      case _PhotoRowStatus.error:
        bg = AppTheme.error; fg = Colors.white; label = 'Error'; icon = Icons.error_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 11),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TblHdr extends StatelessWidget {
  final String text;
  final int    flex;
  const _TblHdr(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
    );
  }
}
