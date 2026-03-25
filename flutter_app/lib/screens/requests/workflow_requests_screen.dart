// ============================================================
// Workflow Requests Screen — Industry-grade data review system
// Templates: Student Info Review | Teacher Info Review | Documents
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import 'package:excel/excel.dart' as xl;

// ── Models ────────────────────────────────────────────────────

class RequestTemplate {
  final String id;
  final String name;
  final String templateType;
  final String description;
  final bool isStandard;
  final List<String> defaultFields;
  final List<String> notifyChannels;
  final String? parentId;
  final String? parentName;

  const RequestTemplate({
    required this.id,
    required this.name,
    required this.templateType,
    required this.description,
    required this.isStandard,
    required this.defaultFields,
    required this.notifyChannels,
    this.parentId,
    this.parentName,
  });

  factory RequestTemplate.fromJson(Map<String, dynamic> j) => RequestTemplate(
        id:            j['id'] as String,
        name:          j['name'] as String? ?? '',
        templateType:  j['template_type'] as String? ?? 'student_info',
        description:   j['description'] as String? ?? '',
        isStandard:    (j['is_standard'] == true || j['is_standard'] == 1),
        defaultFields: _parseJsonList(j['default_fields']),
        notifyChannels:_parseJsonList(j['notify_channels']),
        parentId:      j['parent_id'] as String?,
        parentName:    j['parent_name'] as String?,
      );

  static List<String> _parseJsonList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

class WorkflowRequest {
  final String id;
  final String title;
  final String description;
  final String requestType;
  final String status;
  final int totalItems;
  final int pendingItems;
  final int completedItems;
  final DateTime startDate;
  final DateTime? dueDate;
  final DateTime? extendedDueDate;
  final DateTime? launchedAt;
  final bool sendToParent;
  final String requesterName;
  final String templateName;
  final DateTime createdAt;
  final List<String> notifyChannels;
  final List<String> selectedFields;
  final List<Map<String, String>> selectedClasses;

  const WorkflowRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.requestType,
    required this.status,
    required this.totalItems,
    required this.pendingItems,
    required this.completedItems,
    required this.startDate,
    this.dueDate,
    this.extendedDueDate,
    this.launchedAt,
    required this.sendToParent,
    required this.requesterName,
    required this.templateName,
    required this.createdAt,
    required this.notifyChannels,
    required this.selectedFields,
    required this.selectedClasses,
  });

  static List<String> _parseStrList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      try {
        final d = jsonDecode(v); if (d is List) return d.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static List<Map<String, String>> _parseClassList(dynamic v) {
    if (v == null) return [];
    List raw = [];
    if (v is List) raw = v;
    else if (v is String) { try { final d = jsonDecode(v); if (d is List) raw = d; } catch (_) {} }
    return raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString()))).toList();
  }

  factory WorkflowRequest.fromJson(Map<String, dynamic> j) => WorkflowRequest(
        id:             j['id'] as String,
        title:          j['title'] as String? ?? '',
        description:    j['description'] as String? ?? '',
        requestType:    j['request_type'] as String? ?? 'student_info',
        status:         j['status'] as String? ?? 'draft',
        totalItems:     (j['total_items'] as num?)?.toInt() ?? 0,
        pendingItems:   (j['pending_items'] as num?)?.toInt() ?? 0,
        completedItems: (j['completed_items'] as num?)?.toInt() ?? 0,
        startDate:      DateTime.tryParse(j['start_date'] as String? ?? '') ?? DateTime.now(),
        dueDate:        j['due_date'] != null ? DateTime.tryParse(j['due_date'] as String) : null,
        extendedDueDate: j['extended_due_date'] != null
            ? DateTime.tryParse(j['extended_due_date'] as String) : null,
        launchedAt:     j['launched_at'] != null ? DateTime.tryParse(j['launched_at'] as String) : null,
        sendToParent:   (j['send_to_parent'] == true || j['send_to_parent'] == 1),
        requesterName:  j['requester_name'] as String? ?? '',
        templateName:   j['template_name'] as String? ?? '',
        createdAt:      DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        notifyChannels: RequestTemplate._parseJsonList(j['notify_channels']),
        selectedFields: _parseStrList(j['selected_fields']),
        selectedClasses: _parseClassList(j['selected_classes']),
      );

  double get progressPct => totalItems == 0 ? 0 : completedItems / totalItems;
}

class WorkflowItem {
  final String id;
  final String itemType;
  final String? studentId;
  final String? studentFirst;
  final String? studentLast;
  final String? studentPhoto;
  final String? employeeId;
  final String? empFirst;
  final String? empLast;
  final String? empPhoto;
  final String? className;
  final String? section;
  final String? rollNumber;
  final String? teacherName;
  final String? teacherPhoto;
  final String status;
  final DateTime? lastNotifiedAt;
  final int reminderCount;
  final String? teacherNotes;
  final String? parentReviewStatus;
  final Map<String, dynamic>? parentChangesSummary;
  final DateTime? parentSubmittedAt;
  final String? parentReviewId;

  const WorkflowItem({
    required this.id,
    required this.itemType,
    this.studentId,
    this.studentFirst,
    this.studentLast,
    this.studentPhoto,
    this.employeeId,
    this.empFirst,
    this.empLast,
    this.empPhoto,
    this.className,
    this.section,
    this.rollNumber,
    this.teacherName,
    this.teacherPhoto,
    required this.status,
    this.lastNotifiedAt,
    required this.reminderCount,
    this.teacherNotes,
    this.parentReviewStatus,
    this.parentChangesSummary,
    this.parentSubmittedAt,
    this.parentReviewId,
  });

  String get displayName => itemType == 'student'
      ? '${studentFirst ?? ''} ${studentLast ?? ''}'.trim()
      : '${empFirst ?? ''} ${empLast ?? ''}'.trim();

  String? get photoUrl => itemType == 'student' ? studentPhoto : empPhoto;

  factory WorkflowItem.fromJson(Map<String, dynamic> j) => WorkflowItem(
        id:               j['id'] as String,
        itemType:         j['item_type'] as String? ?? 'student',
        studentId:        j['student_id'] as String?,
        studentFirst:     j['student_first'] as String?,
        studentLast:      j['student_last'] as String?,
        studentPhoto:     j['student_photo'] as String?,
        employeeId:       j['employee_id'] as String?,
        empFirst:         j['emp_first'] as String?,
        empLast:          j['emp_last'] as String?,
        empPhoto:         j['emp_photo'] as String?,
        className:        j['class_name'] as String?,
        section:          j['section'] as String?,
        rollNumber:       j['roll_number'] as String?,
        teacherName:      j['teacher_name'] as String?,
        teacherPhoto:     j['teacher_photo'] as String?,
        status:           j['status'] as String? ?? 'pending',
        lastNotifiedAt:   j['last_notified_at'] != null
            ? DateTime.tryParse(j['last_notified_at'] as String) : null,
        reminderCount:    (j['reminder_count'] as num?)?.toInt() ?? 0,
        teacherNotes:     j['teacher_notes'] as String?,
        parentReviewStatus: j['parent_review_status'] as String?,
        parentChangesSummary: j['parent_changes_summary'] is Map
            ? Map<String, dynamic>.from(j['parent_changes_summary'] as Map)
            : null,
        parentSubmittedAt: j['parent_submitted_at'] != null
            ? DateTime.tryParse(j['parent_submitted_at'] as String) : null,
        parentReviewId: j['parent_review_id'] as String?,
      );
}

class ItemComment {
  final String id;
  final String commenterName;
  final String commenterType;
  final String commentText;
  final DateTime createdAt;

  const ItemComment({
    required this.id,
    required this.commenterName,
    required this.commenterType,
    required this.commentText,
    required this.createdAt,
  });

  factory ItemComment.fromJson(Map<String, dynamic> j) => ItemComment(
        id:            j['id'] as String,
        commenterName: j['commenter_name'] as String? ?? '',
        commenterType: j['commenter_type'] as String? ?? 'teacher',
        commentText:   j['comment_text'] as String? ?? '',
        createdAt:     DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

// ── Providers ─────────────────────────────────────────────────
final _templatesProvider = FutureProvider<List<RequestTemplate>>((ref) async {
  try {
    final data = await ApiService().get('/workflow/templates');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => RequestTemplate.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return _mockTemplates();
  }
});

final _workflowRequestsProvider = FutureProvider<List<WorkflowRequest>>((ref) async {
  try {
    final data = await ApiService().get('/workflow/requests');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => WorkflowRequest.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

final _selectedTabProvider = StateProvider<int>((ref) => 0);
final _selectedRequestProvider = StateProvider<WorkflowRequest?>((ref) => null);
final _itemSortProvider = StateProvider<String>((ref) => 'class');
final _itemStatusFilterProvider = StateProvider<String?>((ref) => null);

// Mock data for offline/fallback
List<RequestTemplate> _mockTemplates() => [
  RequestTemplate(
    id: 'std-tmpl-0001-student-info', name: 'Review Student Info',
    templateType: 'student_info', isStandard: true,
    description: 'Standard template for reviewing student information for ID card or data verification.',
    defaultFields: ['student_name','class_name','section','photo_url','mother_photo','father_photo','student_aadhaar','student_pan'],
    notifyChannels: ['sms','whatsapp','email'],
  ),
  RequestTemplate(
    id: 'std-tmpl-0002-teacher-info', name: 'Review Teacher Info',
    templateType: 'teacher_info', isStandard: true,
    description: 'Standard template for reviewing teacher information for ID card or data verification.',
    defaultFields: ['teacher_name','employee_id','photo_url','aadhaar_no','pan_no'],
    notifyChannels: ['sms','whatsapp','email'],
  ),
  RequestTemplate(
    id: 'std-tmpl-0003-document-review', name: 'Review Aadhaar / PAN / Documents',
    templateType: 'document', isStandard: true,
    description: 'Standard template for collecting and verifying Aadhaar, PAN, or any other important documents.',
    defaultFields: ['name','aadhaar_no','pan_no','document_attachment'],
    notifyChannels: ['sms','whatsapp','email'],
  ),
];

// ── Main Screen ────────────────────────────────────────────────
class WorkflowRequestsScreen extends ConsumerWidget {
  const WorkflowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_selectedTabProvider);
    final selected = ref.watch(_selectedRequestProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final hasEmployee = user?.employee != null || user?.isSuperAdmin == true || user?.isSchoolOwner == true;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(tab: tab, ref: ref, hasEmployee: hasEmployee),
          if (!hasEmployee && user != null)
            _NoEmployeeBanner(),
          Expanded(
            child: tab == 0
                ? _TemplatesTab(ref: ref)
                : LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isNarrow = constraints.maxWidth < 800;
                      // Mobile: selected request takes full panel
                      if (isNarrow && selected != null) {
                        return _RequestDetailPanel(request: selected);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isNarrow || selected == null)
                            Expanded(
                              flex: selected != null ? 2 : 1,
                              child: const _RequestsTab(),
                            ),
                          if (selected != null) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: _RequestDetailPanel(request: selected),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Header with tabs ─────────────────────────────────────────
class _Header extends StatelessWidget {
  final int tab;
  final WidgetRef ref;
  final bool hasEmployee;
  const _Header({required this.tab, required this.ref, required this.hasEmployee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.grey200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Text('Workflow Requests',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              if (tab == 1)
                Tooltip(
                  message: hasEmployee ? '' : 'You need an employee profile to create requests',
                  child: FilledButton.icon(
                    onPressed: hasEmployee
                        ? () => ref.read(_selectedTabProvider.notifier).state = 0
                        : null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Request'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TabButton(label: 'Templates', index: 0, current: tab, ref: ref),
              const SizedBox(width: 4),
              _TabButton(label: 'Active Requests', index: 1, current: tab, ref: ref),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final WidgetRef ref;
  const _TabButton({required this.label, required this.index, required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => ref.read(_selectedTabProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
              color: active ? AppTheme.primary : AppTheme.grey600,
            )),
      ),
    );
  }
}

// ── Templates Tab ─────────────────────────────────────────────
class _TemplatesTab extends ConsumerWidget {
  final WidgetRef ref;
  const _TemplatesTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final templatesAsync = ref.watch(_templatesProvider);
    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (templates) {
        final standards = templates.where((t) => t.isStandard).toList();
        final customs   = templates.where((t) => !t.isStandard).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Standard Templates',
                subtitle: 'Pre-configured templates ready to use or clone',
                icon: Icons.verified_outlined,
                iconColor: AppTheme.primary,
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  childAspectRatio: 1.55,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: standards.length,
                itemBuilder: (ctx, i) => _TemplateCard(
                  template: standards[i],
                  onUse: () => _showCreateWizard(context, ref, standards[i]),
                  onClone: () => _showCloneDialog(context, ref, standards[i]),
                ).animate(delay: (i * 80).ms).fadeIn(duration: 300.ms),
              ),

              if (customs.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Custom Templates',
                  subtitle: 'School-specific clones with your customizations',
                  icon: Icons.tune_outlined,
                  iconColor: AppTheme.accent,
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: customs.length,
                  itemBuilder: (ctx, i) => _TemplateCard(
                    template: customs[i],
                    onUse: () => _showCreateWizard(context, ref, customs[i]),
                    onClone: () => _showCloneDialog(context, ref, customs[i]),
                  ).animate(delay: (i * 80).ms).fadeIn(duration: 300.ms),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCreateWizard(BuildContext context, WidgetRef ref, RequestTemplate template) {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user?.employee == null && user?.isSuperAdmin != true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.person_off_outlined, color: AppTheme.error),
            const SizedBox(width: 8),
            Text('No Employee Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ]),
          content: Text(
            'Your account is not linked to an employee profile.\n\n'
            'All admin users (Principal, VP, Branch Admin, etc.) must be added as employees to create workflow requests.',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey700),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () { Navigator.pop(ctx); context.push('/employees/new'); },
              child: const Text('Add Employee Profile'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateRequestWizard(template: template, ref: ref),
    );
  }

  void _showCloneDialog(BuildContext context, WidgetRef ref, RequestTemplate template) {
    showDialog(
      context: context,
      builder: (_) => _CloneTemplateDialog(template: template, ref: ref),
    );
  }
}

// ── No-Employee Warning Banner ────────────────────────────────
class _NoEmployeeBanner extends StatelessWidget {
  const _NoEmployeeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              'Add yourself as an employee to create workflow requests.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5D4037)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/employees/new'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE65100),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text('Add My Profile',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  const _SectionHeader({required this.title, required this.subtitle, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
          ],
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final RequestTemplate template;
  final VoidCallback onUse;
  final VoidCallback onClone;
  const _TemplateCard({required this.template, required this.onUse, required this.onClone});

  Color get _typeColor {
    switch (template.templateType) {
      case 'teacher_info': return const Color(0xFF1565C0);
      case 'document':     return const Color(0xFF6A1B9A);
      default:             return AppTheme.primary;
    }
  }

  IconData get _typeIcon {
    switch (template.templateType) {
      case 'teacher_info': return Icons.badge_outlined;
      case 'document':     return Icons.folder_open_outlined;
      default:             return Icons.school_outlined;
    }
  }

  String get _typeLabel {
    switch (template.templateType) {
      case 'teacher_info': return 'Teacher Info';
      case 'document':     return 'Documents';
      default:             return 'Student Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon, color: _typeColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(template.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (template.isStandard)
                  Tooltip(
                    message: 'Standard Template',
                    child: Icon(Icons.verified, color: AppTheme.statusGreen, size: 16),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_typeLabel,
                        style: GoogleFonts.poppins(fontSize: 10, color: _typeColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  Text(template.description,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.check_box_outlined, size: 12, color: AppTheme.grey500),
                      const SizedBox(width: 4),
                      Text('${template.defaultFields.length} fields pre-selected',
                          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                      const Spacer(),
                      // Clone
                      Tooltip(
                        message: 'Clone & customize',
                        child: InkWell(
                          onTap: onClone,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.copy_outlined, size: 16, color: AppTheme.grey600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: onUse,
                        style: FilledButton.styleFrom(
                          backgroundColor: _typeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 30),
                          textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Use Template'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Request Wizard ──────────────────────────────────────
class _CreateRequestWizard extends StatefulWidget {
  final RequestTemplate template;
  final WidgetRef ref;
  const _CreateRequestWizard({required this.template, required this.ref});

  @override
  State<_CreateRequestWizard> createState() => _CreateRequestWizardState();
}

class _CreateRequestWizardState extends State<_CreateRequestWizard> {
  int _step = 0;

  // Step 1 — Basic Info
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  // Step 2 — Field Selection
  late Set<String> _selectedFields;

  // Step 3 — Class-Section & Teacher Assignment
  List<Map<String, dynamic>> _classSections = [];
  List<Map<String, dynamic>> _assignments   = [];
  bool _sendToParent = false;
  bool _loadingClasses = false;
  String _classFilter = '';
  final _classFilterCtrl = TextEditingController();

  // Step 4 — Schedule & Notifications
  DateTime _startDate  = DateTime.now().add(const Duration(days: 1));
  DateTime? _dueDate;
  Set<String> _channels = {'sms', 'whatsapp', 'email'};

  bool _submitting = false;

  static const _fieldLabels = {
    'student_name': 'Student Name', 'class_name': 'Class', 'section': 'Section',
    'roll_number': 'Roll Number', 'photo_url': 'Student Photo',
    'date_of_birth': 'Date of Birth', 'gender': 'Gender', 'blood_group': 'Blood Group',
    'nationality': 'Nationality', 'religion': 'Religion', 'category': 'Category',
    'student_aadhaar': 'Aadhaar No.', 'student_pan': 'PAN No.',
    'admission_no': 'Admission No.', 'academic_year': 'Academic Year',
    'address': 'Address', 'city': 'City', 'state': 'State', 'zip_code': 'PIN Code',
    'bus_route': 'Bus Route', 'bus_stop': 'Bus Stop', 'bus_number': 'Bus Number',
    'mother_name': 'Mother Name', 'mother_phone': 'Mother Phone',
    'mother_email': 'Mother Email', 'mother_photo': 'Mother Photo',
    'mother_aadhaar': 'Mother Aadhaar', 'mother_pan': 'Mother PAN',
    'father_name': 'Father Name', 'father_phone': 'Father Phone',
    'father_email': 'Father Email', 'father_photo': 'Father Photo',
    'father_aadhaar': 'Father Aadhaar', 'father_pan': 'Father PAN',
    'guardian_name': 'Guardian Name', 'guardian_phone': 'Guardian Phone',
    'guardian_email': 'Guardian Email', 'guardian_photo': 'Guardian Photo',
    'guardian_aadhaar': 'Guardian Aadhaar',
    // Teacher fields
    'teacher_name': 'Teacher Name', 'employee_id': 'Employee ID',
    'designation': 'Designation', 'assigned_classes': 'Assigned Classes',
    'aadhaar_no': 'Aadhaar No.', 'pan_no': 'PAN No.',
    'qualification': 'Qualification', 'specialization': 'Specialization',
    'experience_years': 'Experience (Years)', 'date_of_joining': 'Date of Joining',
    'phone': 'Phone', 'email': 'Email', 'whatsapp_no': 'WhatsApp No.',
    // Document
    'name': 'Full Name', 'document_attachment': 'Document Attachment',
  };

  static const _fieldGroups = {
    'student_info': {
      'Identity': ['student_name','date_of_birth','gender','blood_group','nationality','religion','category'],
      'Enrollment': ['class_name','section','roll_number','academic_year','admission_no'],
      'Photos': ['photo_url'],
      'Contact & Address': ['address','city','state','zip_code'],
      'Government IDs': ['student_aadhaar','student_pan'],
      'Transport': ['bus_route','bus_stop','bus_number'],
      'Mother': ['mother_name','mother_phone','mother_email','mother_photo','mother_aadhaar','mother_pan'],
      'Father': ['father_name','father_phone','father_email','father_photo','father_aadhaar','father_pan'],
      'Guardian': ['guardian_name','guardian_phone','guardian_email','guardian_photo','guardian_aadhaar'],
    },
    'teacher_info': {
      'Identity': ['teacher_name','employee_id','date_of_birth','gender'],
      'Role': ['designation','assigned_classes'],
      'Photos': ['photo_url'],
      'Contact': ['email','phone','whatsapp_no','address'],
      'Government IDs': ['aadhaar_no','pan_no'],
      'Professional': ['qualification','specialization','experience_years','date_of_joining'],
    },
    'document': {
      'Person': ['name','date_of_birth','gender'],
      'IDs': ['aadhaar_no','pan_no'],
      'Photos': ['photo_url'],
      'Attachments': ['document_attachment'],
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedFields = Set<String>.from(widget.template.defaultFields);
    _titleCtrl.text = 'Review ${widget.template.name} — ${DateFormat('MMM yyyy').format(DateTime.now())}';
    _loadClasses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _classFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    if (widget.template.templateType != 'student_info') return;
    setState(() => _loadingClasses = true);
    try {
      final data = await ApiService().get('/workflow/classes');
      final list = (data['data'] as List<dynamic>? ?? []);
      setState(() {
        _classSections = list.map((e) {
          final teacherId   = e['teacher_id']   as String?;
          final teacherName = e['teacher_name'] as String?;
          return {
            'class_name':    e['class_name'] as String,
            'section':       e['section']    as String,
            'selected':      true,
            'teacher_ids':   teacherId != null && teacherId.isNotEmpty
                               ? <String>[teacherId] : <String>[],
            'teacher_names': teacherName != null && teacherName.trim().isNotEmpty
                               ? <String>[teacherName.trim()] : <String>[],
          };
        }).toList();
        _assignments = List<Map<String, dynamic>>.from(_classSections);
      });
    } catch (_) {
      setState(() {
        _classSections = [];
        _assignments   = [];
      });
    }
    setState(() => _loadingClasses = false);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final selected = _classSections.where((c) => c['selected'] == true).toList();
      final assignmentPayload = selected.map((cs) => {
        'class_name': cs['class_name'],
        'section':    cs['section'],
        'teacher_ids': cs['teacher_ids'] ?? [],
      }).toList();

      final body = {
        'template_id':      widget.template.id,
        'title':            _titleCtrl.text.trim(),
        'description':      _descCtrl.text.trim(),
        'request_type':     widget.template.templateType,
        'selected_fields':  _selectedFields.toList(),
        'selected_classes': selected.map((c) => {'class_name': c['class_name'], 'section': c['section']}).toList(),
        'start_date':       DateFormat('yyyy-MM-dd').format(_startDate),
        'due_date':         _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
        'send_to_parent':   _sendToParent,
        'notify_channels':  _channels.toList(),
        'assignments':      assignmentPayload,
      };

      final result = await ApiService().post('/workflow/requests', body: body);
      final requestId = result['data']['id'] as String?;

      if (requestId != null) {
        // Auto-launch if start_date is today
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (DateFormat('yyyy-MM-dd').format(_startDate) == today) {
          await ApiService().post('/workflow/requests/$requestId/launch', body: {});
        }
      }

      widget.ref.invalidate(_workflowRequestsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        widget.ref.read(_selectedTabProvider.notifier).state = 1;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workflow request created successfully'),
            backgroundColor: AppTheme.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Basic Info', 'Select Fields', 'Assign Teachers', 'Schedule'];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_add, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Create Workflow Request',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
            // Stepper header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppTheme.grey50,
              child: Row(
                children: List.generate(steps.length, (i) {
                  final done   = i < _step;
                  final active = i == _step;
                  return Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: done
                              ? AppTheme.statusGreen
                              : active ? AppTheme.primary : AppTheme.grey300,
                          child: done
                              ? const Icon(Icons.check, color: Colors.white, size: 13)
                              : Text('${i+1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11, color: active ? Colors.white : AppTheme.grey600,
                                    fontWeight: FontWeight.w600,
                                  )),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(steps[i],
                                  style: GoogleFonts.poppins(
                                    fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                    color: active ? AppTheme.primary : AppTheme.grey600,
                                  )),
                              if (i < steps.length - 1)
                                Container(height: 1, margin: const EdgeInsets.only(top: 2),
                                    color: done ? AppTheme.statusGreen : AppTheme.grey200),
                            ],
                          ),
                        ),
                        if (i < steps.length - 1) const SizedBox(width: 6),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 1),
            // Step content
            Expanded(child: _stepContent()),
            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step < 3)
                    FilledButton(
                      onPressed: _canNext() ? () => setState(() => _step++) : null,
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.rocket_launch, size: 16),
                      label: Text(_submitting ? 'Creating...' : 'Create & Launch'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.statusGreen),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canNext() {
    switch (_step) {
      case 0: return _titleCtrl.text.trim().isNotEmpty;
      case 1: return _selectedFields.isNotEmpty;
      case 2: return _classSections.any((c) => c['selected'] == true) ||
                     widget.template.templateType != 'student_info';
      default: return true;
    }
  }

  Widget _stepContent() {
    switch (_step) {
      case 0: return _step0BasicInfo();
      case 1: return _step1FieldSelection();
      case 2: return _step2Assignment();
      case 3: return _step3Schedule();
      default: return const SizedBox();
    }
  }

  // Step 0 ── Basic Info
  Widget _step0BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBanner(
            icon: Icons.info_outline,
            text: 'Using template: ${widget.template.name}',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: GoogleFonts.poppins(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Request Title *',
              hintText: 'e.g. Annual ID Card Data Verification 2025-26',
              hintStyle: GoogleFonts.poppins(fontSize: 12),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Notification Channels',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final ch in ['sms','whatsapp','email'])
                FilterChip(
                  label: Text(_channelLabel(ch), style: GoogleFonts.poppins(fontSize: 12)),
                  selected: _channels.contains(ch),
                  avatar: Icon(_channelIcon(ch), size: 14),
                  onSelected: (v) => setState(() => v ? _channels.add(ch) : _channels.remove(ch)),
                  selectedColor: AppTheme.primary.withOpacity(0.15),
                  checkmarkColor: AppTheme.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 1 ── Field Selection
  Widget _step1FieldSelection() {
    final groups = _fieldGroups[widget.template.templateType] ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_selectedFields.length} fields selected',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _selectedFields = {}),
                child: Text('Clear all', style: GoogleFonts.poppins(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => setState(() =>
                    _selectedFields = groups.values.expand((f) => f).toSet()),
                child: Text('Select all', style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...groups.entries.map((entry) {
            final groupSelected = entry.value.where((f) => _selectedFields.contains(f)).length;
            return _FieldGroup(
              title: entry.key,
              fields: entry.value,
              selectedFields: _selectedFields,
              fieldLabels: _fieldLabels,
              groupSelected: groupSelected,
              onToggle: (field, val) => setState(() => val ? _selectedFields.add(field) : _selectedFields.remove(field)),
              onToggleAll: (val) => setState(() {
                if (val) {
                  _selectedFields.addAll(entry.value);
                } else {
                  _selectedFields.removeAll(entry.value);
                }
              }),
            );
          }),
        ],
      ),
    );
  }

  // Step 2 ── Class-Section Assignment
  Widget _step2Assignment() {
    if (widget.template.templateType == 'teacher_info') {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(
              icon: Icons.people_outline,
              text: 'All active teachers will be included in this workflow. You can assign a senior reviewer.',
              color: AppTheme.statusBlue,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('Allow any senior teacher in same hierarchy to review',
                  style: GoogleFonts.poppins(fontSize: 13)),
              subtitle: Text('Senior teachers can approve or return submissions.',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
              value: true,
              onChanged: (_) {},
            ),
          ],
        ),
      );
    }

    if (_loadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _classSections.asMap().entries.where((entry) {
      if (_classFilter.isEmpty) return true;
      final q = _classFilter.toLowerCase();
      final label = 'class ${entry.value['class_name']} section ${entry.value['section']}'.toLowerCase();
      return label.contains(q);
    }).toList();

    final selectedCount = _classSections.where((c) => c['selected'] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Select Class-Sections',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Text('$selectedCount/${_classSections.length} selected',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _classFilterCtrl,
                decoration: InputDecoration(
                  hintText: 'Filter by class or section…',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.grey500),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey200),
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 12),
                onChanged: (v) => setState(() => _classFilter = v),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: filtered.isEmpty ? null : () => setState(() {
                      for (final e in filtered) {
                        _classSections[e.key]['selected'] = true;
                      }
                    }),
                    icon: const Icon(Icons.check_box_outlined, size: 15),
                    label: Text('Select All', style: GoogleFonts.poppins(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: filtered.isEmpty ? null : () => setState(() {
                      for (final e in filtered) {
                        _classSections[e.key]['selected'] = false;
                      }
                    }),
                    icon: const Icon(Icons.check_box_outline_blank, size: 15),
                    label: Text('Unselect All', style: GoogleFonts.poppins(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      foregroundColor: AppTheme.grey600,
                    ),
                  ),
                  if (_classFilter.isNotEmpty) ...[
                    const Spacer(),
                    Text('${filtered.length} shown',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                  ],
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Send directly to Parent/Guardian',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Skips teacher — sends review link directly to parent inbox.',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
            value: _sendToParent,
            onChanged: (v) => setState(() => _sendToParent = v),
            activeColor: AppTheme.primary,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _classFilter.isEmpty ? 'No classes found' : 'No match for "$_classFilter"',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final entry = filtered[idx];
                    final i  = entry.key;   // actual index in _classSections
                    final cs = entry.value;
                    final isSelected = cs['selected'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : AppTheme.grey200,
                        ),
                      ),
                      elevation: 0,
                      child: ListTile(
                        dense: true,
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (v) => setState(() => _classSections[i]['selected'] = v),
                          activeColor: AppTheme.primary,
                        ),
                        title: Text(
                          'Class ${cs['class_name']} — Section ${cs['section']}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: (cs['teacher_names'] as List).isNotEmpty
                            ? Text(
                                'Assigned: ${(cs['teacher_names'] as List).join(', ')}',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
                              )
                            : Text('No teacher assigned — tap + to assign',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                        trailing: isSelected
                            ? IconButton(
                                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: AppTheme.primary),
                                tooltip: 'Assign teacher',
                                onPressed: () => _showTeacherPickerForClass(ctx, i),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showTeacherPickerForClass(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (_) => _TeacherPickerDialog(
        classSection: _classSections[index],
        onSave: (teacherIds, teacherNames) => setState(() {
          _classSections[index]['teacher_ids']   = teacherIds;
          _classSections[index]['teacher_names'] = teacherNames;
        }),
      ),
    );
  }

  // Step 3 ── Schedule & Notifications
  Widget _step3Schedule() {
    final fmt = DateFormat('dd MMM yyyy');
    final today = DateTime.now();
    final effectiveDue = _dueDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Start date
          _DatePickerTile(
            label: 'Start Date *',
            subtitle: 'Cannot be set in the past',
            icon: Icons.calendar_today_outlined,
            value: fmt.format(_startDate),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          const SizedBox(height: 12),
          // Due date
          _DatePickerTile(
            label: 'Due Date (optional)',
            subtitle: 'Deadline for completing this review',
            icon: Icons.event_outlined,
            value: effectiveDue != null ? fmt.format(effectiveDue) : 'Not set',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: effectiveDue ?? _startDate.add(const Duration(days: 7)),
                firstDate: _startDate,
                lastDate: today.add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            trailing: effectiveDue != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => _dueDate = null),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // Summary
          Text('Review Summary',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Template', value: widget.template.name),
          _SummaryRow(label: 'Request Title', value: _titleCtrl.text),
          _SummaryRow(label: 'Fields selected', value: '${_selectedFields.length} fields'),
          if (widget.template.templateType == 'student_info')
            _SummaryRow(
              label: 'Class-Sections',
              value: '${_classSections.where((c) => c['selected'] == true).length} sections',
            ),
          _SummaryRow(label: 'Start Date', value: fmt.format(_startDate)),
          _SummaryRow(label: 'Due Date', value: effectiveDue != null ? fmt.format(effectiveDue) : 'Not set'),
          _SummaryRow(label: 'Send to Parent', value: _sendToParent ? 'Yes (directly)' : 'Via Teacher'),
          _SummaryRow(label: 'Notifications', value: _channels.map(_channelLabel).join(', ')),
          const SizedBox(height: 16),
          if (_startDate.day == today.day && _startDate.month == today.month && _startDate.year == today.year)
            _InfoBanner(
              icon: Icons.rocket_launch,
              text: 'Start date is today — the workflow will be launched immediately after creation.',
              color: AppTheme.statusGreen,
            )
          else
            _InfoBanner(
              icon: Icons.schedule,
              text: 'The workflow will be created in draft. You can launch it on ${fmt.format(_startDate)}.',
              color: AppTheme.statusBlue,
            ),
        ],
      ),
    );
  }
}

// ── Field Group Widget ────────────────────────────────────────
class _FieldGroup extends StatefulWidget {
  final String title;
  final List<String> fields;
  final Set<String> selectedFields;
  final Map<String, String> fieldLabels;
  final int groupSelected;
  final void Function(String, bool) onToggle;
  final void Function(bool) onToggleAll;
  const _FieldGroup({
    required this.title, required this.fields, required this.selectedFields,
    required this.fieldLabels, required this.groupSelected,
    required this.onToggle, required this.onToggleAll,
  });
  @override
  State<_FieldGroup> createState() => _FieldGroupState();
}

class _FieldGroupState extends State<_FieldGroup> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: widget.groupSelected == 0 ? false
                        : widget.groupSelected == widget.fields.length ? true : null,
                    onChanged: (v) => widget.onToggleAll(v == true),
                    activeColor: AppTheme.primary,
                  ),
                  Text(widget.title,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text('(${widget.groupSelected}/${widget.fields.length})',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: AppTheme.grey500),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.fields.map((f) {
                final sel = widget.selectedFields.contains(f);
                return FilterChip(
                  label: Text(widget.fieldLabels[f] ?? f,
                      style: GoogleFonts.poppins(fontSize: 11,
                          color: sel ? Colors.white : AppTheme.grey700)),
                  selected: sel,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.grey100,
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: sel ? AppTheme.primary : AppTheme.grey300),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  onSelected: (v) => widget.onToggle(f, v),
                );
              }).toList(),
            ).animate().fadeIn(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Teacher Picker Dialog ─────────────────────────────────────
class _TeacherPickerDialog extends StatefulWidget {
  final Map<String, dynamic> classSection;
  final void Function(List<String> ids, List<String> names) onSave;
  const _TeacherPickerDialog({required this.classSection, required this.onSave});
  @override
  State<_TeacherPickerDialog> createState() => _TeacherPickerDialogState();
}

class _TeacherPickerDialogState extends State<_TeacherPickerDialog> {
  final Set<String> _selectedIds    = {};
  final Map<String, String> _nameMap = {};
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.classSection['teacher_ids'] as List<dynamic>;
    _selectedIds.addAll(existing.map((e) => e.toString()));
    _loadTeachers();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final data = await ApiService().get('/employees');
      final list = data['data'] as List<dynamic>? ?? [];
      final map = <String, String>{};
      for (final e in list) {
        final id   = e['id'] as String? ?? '';
        final name = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
        if (id.isNotEmpty && name.isNotEmpty) map[id] = name;
      }
      setState(() {
        _nameMap.addAll(map);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _nameMap.entries
        .where((e) => _search.isEmpty ||
            e.value.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign Teachers',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(
            'Class ${widget.classSection['class_name']} — Section ${widget.classSection['section']}',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${_selectedIds.length} teacher(s) selected',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  TextField(
                    controller: _searchCtrl,
                    style:      GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:       'Search teacher...',
                      hintStyle:      GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey400),
                      prefixIcon:     const Icon(Icons.search, size: 16),
                      border:         OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense:        true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No teachers found',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: AppTheme.grey500)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount:  filtered.length,
                            itemBuilder: (_, i) {
                              final entry = filtered[i];
                              final isPrimary = i == 0 && _search.isEmpty;
                              final isSel = _selectedIds.contains(entry.key);
                              return CheckboxListTile(
                                dense:       true,
                                value:       isSel,
                                title:       Text(entry.value,
                                    style: GoogleFonts.poppins(fontSize: 13)),
                                subtitle:    isPrimary
                                    ? Text('Suggested (Class Teacher)',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10, color: AppTheme.statusGreen))
                                    : null,
                                onChanged:   (v) => setState(() =>
                                    v! ? _selectedIds.add(entry.key)
                                       : _selectedIds.remove(entry.key)),
                                activeColor: AppTheme.primary,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          onPressed: () {
            final ids   = _selectedIds.toList();
            final names = ids.map((id) => _nameMap[id] ?? id).toList();
            widget.onSave(ids, names);
            Navigator.of(context).pop();
          },
          child: Text('Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Clone Template Dialog ─────────────────────────────────────
class _CloneTemplateDialog extends StatefulWidget {
  final RequestTemplate template;
  final WidgetRef ref;
  const _CloneTemplateDialog({required this.template, required this.ref});
  @override
  State<_CloneTemplateDialog> createState() => _CloneTemplateDialogState();
}

class _CloneTemplateDialogState extends State<_CloneTemplateDialog> {
  final _nameCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = '${widget.template.name} (Custom)';
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Clone Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create a school-specific copy of "${widget.template.name}" that you can customize.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: const InputDecoration(labelText: 'Template Name *', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: _submitting ? null : () async {
            setState(() => _submitting = true);
            try {
              await ApiService().post('/workflow/templates/${widget.template.id}/clone',
                  body: {'name': _nameCtrl.text.trim()});
              widget.ref.invalidate(_templatesProvider);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template cloned successfully'),
                        backgroundColor: AppTheme.statusGreen));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
            } finally {
              if (mounted) setState(() => _submitting = false);
            }
          },
          child: Text(_submitting ? 'Cloning...' : 'Clone', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Requests Tab ──────────────────────────────────────────────
class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_workflowRequestsProvider);
    final selected      = ref.watch(_selectedRequestProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 56, color: AppTheme.grey300),
                const SizedBox(height: 12),
                Text('No workflow requests yet',
                    style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.grey600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Go to Templates tab to create one',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _RequestCard(
            request:    requests[i],
            isSelected: selected?.id == requests[i].id,
            onTap: () {
              final notifier = ref.read(_selectedRequestProvider.notifier);
              notifier.state = selected?.id == requests[i].id ? null : requests[i];
            },
          ).animate(delay: (i * 60).ms).fadeIn(duration: 300.ms),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final WorkflowRequest request;
  final bool isSelected;
  final VoidCallback onTap;
  const _RequestCard({required this.request, required this.isSelected, required this.onTap});

  Color get _statusColor {
    switch (request.status) {
      case 'completed':    return AppTheme.statusGreen;
      case 'in_progress':  return AppTheme.statusBlue;
      case 'cancelled':    return AppTheme.error;
      case 'active':       return AppTheme.accent;
      default:             return AppTheme.grey400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = request.progressPct;
    final due      = request.extendedDueDate ?? request.dueDate;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.grey200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [BoxShadow(
          color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.black.withOpacity(0.03),
          blurRadius: isSelected ? 10 : 3, offset: const Offset(0, 2),
        )],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeIcon(type: request.requestType, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(request.title,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar
              if (request.totalItems > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.grey100,
                          color: _statusColor,
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${request.completedItems}/${request.totalItems}',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: AppTheme.grey500),
                  const SizedBox(width: 4),
                  Text(request.requesterName,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
                  const Spacer(),
                  if (due != null) ...[
                    Icon(Icons.event_outlined, size: 12,
                        color: due.isBefore(DateTime.now()) ? AppTheme.error : AppTheme.grey500),
                    const SizedBox(width: 3),
                    Text(
                      'Due ${DateFormat('dd MMM').format(due)}',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: due.isBefore(DateTime.now()) ? AppTheme.error : AppTheme.grey500,
                          fontWeight: due.isBefore(DateTime.now()) ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Request Detail Panel ──────────────────────────────────────
class _RequestDetailPanel extends ConsumerStatefulWidget {
  final WorkflowRequest request;
  const _RequestDetailPanel({required this.request});

  @override
  ConsumerState<_RequestDetailPanel> createState() => _RequestDetailPanelState();
}

class _RequestDetailPanelState extends ConsumerState<_RequestDetailPanel> {
  List<WorkflowItem> _items = [];
  bool _loading = true;
  String _sortBy = 'class';
  String? _statusFilter;
  String? _classFilter;
  Set<String> _selectedItems = {};
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(_RequestDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.request.id != widget.request.id) {
      _items = [];
      _selectedItems = {};
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{'sort_by': _sortBy};
      if (_statusFilter != null) params['status'] = _statusFilter!;
      if (_classFilter  != null) params['class_name'] = _classFilter!;
      final data = await ApiService().get('/workflow/requests/${widget.request.id}/items', params: params);
      setState(() {
        _items = (data['data'] as List<dynamic>? ?? [])
            .map((e) => WorkflowItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      setState(() => _items = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> get _allClasses =>
      _items.map((i) => i.className ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort();

  bool _canRemindOrNotify(AppUser? user) => user != null && (
    user.isAdmin || user.isPrincipal ||
    ['vice_principal', 'head_teacher', 'school_owner'].contains(user.role) ||
    (user.employee?.roleLevel ?? 0) >= 3
  );

  @override
  Widget build(BuildContext context) {
    final due = widget.request.extendedDueDate ?? widget.request.dueDate;
    final isOverdue = due != null && due.isBefore(DateTime.now()) && widget.request.status != 'completed';
    final canCancel = !['completed', 'cancelled'].contains(widget.request.status);
    final canHold   = ['active', 'in_progress', 'draft'].contains(widget.request.status);
    final canResume = widget.request.status == 'on_hold';
    final canRemind = _canRemindOrNotify(ref.read(authNotifierProvider).valueOrNull);

    final isNarrow = MediaQuery.of(context).size.width < 800;
    return DefaultTabController(
      length: 2,
      child: Card(
        margin: isNarrow ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 16, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: const Border(bottom: BorderSide(color: AppTheme.grey200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isNarrow) ...[
                        IconButton(
                          onPressed: () =>
                              ref.read(_selectedRequestProvider.notifier).state = null,
                          icon: const Icon(Icons.arrow_back_ios_new,
                              size: 18, color: AppTheme.primary),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: 4),
                      ],
                      _TypeIcon(type: widget.request.requestType, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.request.title,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      _StatusChip(status: widget.request.status),
                      const SizedBox(width: 4),
                      if (canHold)
                        Tooltip(
                          message: 'Put on hold',
                          child: IconButton(
                            onPressed: () => _changeStatus(context, 'hold'),
                            icon: const Icon(Icons.pause_circle_outline, size: 18, color: AppTheme.warning),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ),
                      if (canResume)
                        Tooltip(
                          message: 'Resume workflow',
                          child: IconButton(
                            onPressed: () => _changeStatus(context, 'resume'),
                            icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.statusGreen),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ),
                      if (canCancel)
                        Tooltip(
                          message: 'Cancel request',
                          child: IconButton(
                            onPressed: () => _changeStatus(context, 'cancel'),
                            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ),
                      IconButton(
                        onPressed: () => ref.read(_selectedRequestProvider.notifier).state = null,
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoPill(icon: Icons.people_outline, label: '${widget.request.totalItems} items'),
                      const SizedBox(width: 6),
                      _InfoPill(icon: Icons.check_circle_outline, label: '${widget.request.completedItems} done',
                          color: AppTheme.statusGreen),
                      const SizedBox(width: 6),
                      if (widget.request.pendingItems > 0)
                        _InfoPill(icon: Icons.pending_outlined, label: '${widget.request.pendingItems} pending',
                            color: AppTheme.warning),
                      const Spacer(),
                      if (due != null)
                        _InfoPill(
                          icon: Icons.event_outlined,
                          label: 'Due ${DateFormat('dd MMM').format(due)}',
                          color: isOverdue ? AppTheme.error : AppTheme.grey600,
                        ),
                    ],
                  ),
                  if (widget.request.totalItems > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.request.progressPct,
                        backgroundColor: AppTheme.grey100,
                        color: widget.request.status == 'completed' ? AppTheme.statusGreen : AppTheme.primary,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── TabBar ──
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.grey200)),
              ),
              child: TabBar(
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.grey600,
                indicatorColor: AppTheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [Tab(text: 'Overview'), Tab(text: 'Items')],
              ),
            ),

            // ── TabBarView ──
            Expanded(
              child: TabBarView(
                children: [
                  // ── Overview Tab ──
                  _OverviewTabContent(request: widget.request),

                  // ── Items Tab ──
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Row(
                          children: [
                            PopupMenuButton<String>(
                              initialValue: _sortBy,
                              onSelected: (v) { setState(() => _sortBy = v); _loadItems(); },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'class',  child: Text('Sort by Class')),
                                const PopupMenuItem(value: 'roll',   child: Text('Sort by Roll No.')),
                                const PopupMenuItem(value: 'name',   child: Text('Sort by Name')),
                                const PopupMenuItem(value: 'status', child: Text('Sort by Status')),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.grey200),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.sort, size: 14, color: AppTheme.grey600),
                                  const SizedBox(width: 4),
                                  Text('Sort', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (_allClasses.isNotEmpty)
                              DropdownButton<String?>(
                                value: _classFilter,
                                hint: Text('All Classes', style: GoogleFonts.poppins(fontSize: 11)),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey800),
                                isDense: true,
                                underline: Container(height: 1, color: AppTheme.grey200),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Classes')),
                                  ..._allClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))),
                                ],
                                onChanged: (v) { setState(() => _classFilter = v); _loadItems(); },
                              ),
                            const SizedBox(width: 6),
                            PopupMenuButton<String?>(
                              initialValue: _statusFilter,
                              onSelected: (v) { setState(() => _statusFilter = v); _loadItems(); },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: null,                   child: Text('All Status')),
                                const PopupMenuItem(value: 'pending',              child: Text('Pending')),
                                const PopupMenuItem(value: 'sent_to_parent',       child: Text('Sent to Parent')),
                                const PopupMenuItem(value: 'parent_submitted',     child: Text('Parent Submitted')),
                                const PopupMenuItem(value: 'teacher_under_review', child: Text('Under Review')),
                                const PopupMenuItem(value: 'approved',             child: Text('Approved')),
                                const PopupMenuItem(value: 'rejected',             child: Text('Rejected')),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _statusFilter != null ? AppTheme.primary : AppTheme.grey200),
                                  borderRadius: BorderRadius.circular(6),
                                  color: _statusFilter != null ? AppTheme.primary.withOpacity(0.06) : null,
                                ),
                                child: Row(children: [
                                  Icon(Icons.filter_list, size: 14,
                                      color: _statusFilter != null ? AppTheme.primary : AppTheme.grey600),
                                  const SizedBox(width: 4),
                                  Text('Status', style: GoogleFonts.poppins(fontSize: 11,
                                      color: _statusFilter != null ? AppTheme.primary : AppTheme.grey600)),
                                ]),
                              ),
                            ),
                            const Spacer(),
                            if (_items.isNotEmpty)
                              Tooltip(
                                message: 'Export to Excel',
                                child: IconButton(
                                  onPressed: _exportItemsExcel,
                                  icon: const Icon(Icons.download_outlined, size: 16, color: AppTheme.statusGreen),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                ),
                              ),
                            if (canRemind && widget.request.pendingItems > 0)
                              Tooltip(
                                message: 'Send reminder to all pending',
                                child: OutlinedButton.icon(
                                  onPressed: () => _showRemindDialog(context),
                                  icon: const Icon(Icons.notifications_active_outlined, size: 14),
                                  label: const Text('Remind All'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    textStyle: GoogleFonts.poppins(fontSize: 11),
                                    minimumSize: const Size(0, 32),
                                    foregroundColor: AppTheme.warning,
                                    side: const BorderSide(color: AppTheme.warning),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: _loadItems,
                              icon: const Icon(Icons.refresh, size: 18, color: AppTheme.grey600),
                              tooltip: 'Refresh',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            ),
                          ],
                        ),
                      ),
                      // ── Bulk selection bar ──
                      if (_items.isNotEmpty)
                        Container(
                          color: _selectedItems.isNotEmpty
                              ? AppTheme.primary.withOpacity(0.04)
                              : Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: Row(
                            children: [
                              // Master checkbox (select all / none / indeterminate)
                              Checkbox(
                                value: _selectedItems.length == _items.length && _items.isNotEmpty
                                    ? true
                                    : _selectedItems.isEmpty
                                        ? false
                                        : null,
                                tristate: true,
                                onChanged: (v) => setState(() {
                                  if (v == true || v == null) {
                                    _selectedItems = _items.map((i) => i.id).toSet();
                                  } else {
                                    _selectedItems = {};
                                  }
                                }),
                                activeColor: AppTheme.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                _selectedItems.isEmpty
                                    ? 'Select All'
                                    : '${_selectedItems.length} selected',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _selectedItems.isEmpty
                                      ? AppTheme.grey600
                                      : AppTheme.primary,
                                  fontWeight: _selectedItems.isEmpty
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                              if (_selectedItems.isNotEmpty) ...[
                                const Spacer(),
                                // Send to Parent
                                _BulkBtn(
                                  icon: Icons.send_outlined,
                                  label: 'Send',
                                  color: AppTheme.secondary,
                                  onTap: () => _bulkAction(context, 'send_to_parent'),
                                ),
                                const SizedBox(width: 4),
                                // Remind
                                _BulkBtn(
                                  icon: Icons.notifications_active_outlined,
                                  label: 'Remind',
                                  color: AppTheme.warning,
                                  onTap: () => _bulkRemindSelected(context),
                                ),
                                const SizedBox(width: 4),
                                // Approve
                                _BulkBtn(
                                  icon: Icons.check_circle_outline,
                                  label: 'Approve',
                                  color: AppTheme.statusGreen,
                                  onTap: () => _bulkAction(context, 'approve'),
                                ),
                                const SizedBox(width: 4),
                                // Reject
                                _BulkBtn(
                                  icon: Icons.cancel_outlined,
                                  label: 'Reject',
                                  color: AppTheme.error,
                                  onTap: () => _bulkAction(context, 'reject'),
                                ),
                                const SizedBox(width: 4),
                                // Clear
                                IconButton(
                                  onPressed: () => setState(() => _selectedItems = {}),
                                  icon: const Icon(Icons.close, size: 15),
                                  color: AppTheme.grey600,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  tooltip: 'Clear selection',
                                ),
                              ] else
                                const Spacer(),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _items.isEmpty
                                ? Center(child: Text('No items found',
                                    style: GoogleFonts.poppins(color: AppTheme.grey500)))
                                : _buildGroupedItems(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().slideX(begin: 0.15, duration: 280.ms),
    );
  }

  Widget _buildGroupedItems() {
    final groups = <String, List<WorkflowItem>>{};
    for (final item in _items) {
      final key = '${item.className ?? '?'}_${item.section ?? '?'}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    final user = ref.read(authNotifierProvider).valueOrNull;
    final canRemindTeacher = _canRemindOrNotify(user);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: groups.length,
      itemBuilder: (ctx, gi) {
        final entry = groups.entries.elementAt(gi);
        final groupKey   = entry.key;
        final groupItems = entry.value;

        // Status counts
        final pending    = groupItems.where((i) => i.status == 'pending').length;
        final inReview   = groupItems.where((i) => i.status == 'teacher_under_review').length;
        final sent       = groupItems.where((i) => i.status == 'sent_to_parent').length;
        final submitted  = groupItems.where((i) => i.status == 'parent_submitted').length;
        final approved   = groupItems.where((i) => i.status == 'approved').length;
        final rejected   = groupItems.where((i) => i.status == 'rejected').length;
        final resubmit   = groupItems.where((i) => i.status == 'resubmit_requested').length;

        final isCollapsed  = _collapsedGroups.contains(groupKey);
        final displayKey   = groupItems.isNotEmpty
            ? 'Class ${groupItems.first.className ?? '?'} — Sec ${groupItems.first.section ?? '?'}'
            : groupKey;
        final teacherName  = groupItems.isNotEmpty ? groupItems.first.teacherName : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Group Header (collapsible) ──
            InkWell(
              onTap: () => setState(() {
                if (isCollapsed) _collapsedGroups.remove(groupKey);
                else             _collapsedGroups.add(groupKey);
              }),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                color: AppTheme.grey50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.class_outlined, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(displayKey,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primary)),
                        const SizedBox(width: 8),
                        Text('${groupItems.length}',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600, fontWeight: FontWeight.w600)),
                        Text(' students',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400)),
                        if (teacherName != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.person_outline, size: 11, color: AppTheme.grey400),
                          const SizedBox(width: 3),
                          Text(teacherName,
                              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                        ],
                        const Spacer(),
                        // Remind Teacher button (for pending items, senior roles only)
                        if (canRemindTeacher && pending > 0)
                          Tooltip(
                            message: 'Remind class teacher — $pending pending',
                            child: TextButton.icon(
                              onPressed: () => _remindGroupItems(
                                context,
                                groupItems.where((i) => i.status == 'pending').map((i) => i.id).toList(),
                                'teacher',
                              ),
                              icon: const Icon(Icons.supervisor_account_outlined, size: 12),
                              label: Text('Teacher ($pending)',
                                  style: GoogleFonts.poppins(fontSize: 10)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.warning,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: const Size(0, 24),
                              ),
                            ),
                          ),
                        // Remind Parents button (senior roles only — same check as teacher)
                        if (canRemindTeacher && sent > 0)
                          Tooltip(
                            message: 'Remind parents — $sent waiting',
                            child: TextButton.icon(
                              onPressed: () => _remindGroupItems(
                                context,
                                groupItems.where((i) => i.status == 'sent_to_parent').map((i) => i.id).toList(),
                                'parent',
                              ),
                              icon: const Icon(Icons.notifications_active_outlined, size: 12),
                              label: Text('Parents ($sent)',
                                  style: GoogleFonts.poppins(fontSize: 10)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6A1B9A),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: const Size(0, 24),
                              ),
                            ),
                          ),
                        Icon(
                          isCollapsed ? Icons.expand_more : Icons.expand_less,
                          size: 16,
                          color: AppTheme.grey500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // ── Status summary pills ──
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (pending   > 0) _GrpStatusPill('$pending Pending',       AppTheme.grey500),
                        if (inReview  > 0) _GrpStatusPill('$inReview In Review',    AppTheme.warning),
                        if (sent      > 0) _GrpStatusPill('$sent Sent',             AppTheme.accent),
                        if (submitted > 0) _GrpStatusPill('$submitted Submitted',   AppTheme.statusBlue),
                        if (approved  > 0) _GrpStatusPill('$approved Approved',     AppTheme.statusGreen),
                        if (rejected  > 0) _GrpStatusPill('$rejected Rejected',     AppTheme.error),
                        if (resubmit  > 0) _GrpStatusPill('$resubmit Resubmit',     const Color(0xFFE65100)),
                        if (pending + inReview + sent + submitted + approved + rejected + resubmit == 0)
                          Text('No items', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Items rows (shown when not collapsed) ──
            if (!isCollapsed) ...[
              Container(
                color: AppTheme.grey100,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    // Group-level checkbox
                    SizedBox(
                      width: 36,
                      child: Checkbox(
                        value: groupItems.every((i) => _selectedItems.contains(i.id))
                            ? true
                            : groupItems.any((i) => _selectedItems.contains(i.id))
                                ? null
                                : false,
                        tristate: true,
                        onChanged: (v) => setState(() {
                          if (v == true || v == null) {
                            _selectedItems.addAll(groupItems.map((i) => i.id));
                          } else {
                            _selectedItems.removeAll(groupItems.map((i) => i.id));
                          }
                        }),
                        activeColor: AppTheme.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    SizedBox(width: 38, child: Text('Roll', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey600))),
                    Expanded(child: Text('Student Name', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey600))),
                    SizedBox(width: 100, child: Text('Status', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey600))),
                    if (canRemindTeacher) ...[
                      SizedBox(width: 80, child: Text('Parent', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey600))),
                      SizedBox(width: 80, child: Text('Teacher', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey600))),
                    ],
                  ],
                ),
              ),
              ...groupItems.map((item) => _ItemTableRow(
                item: item,
                requestId: widget.request.id,
                onAction: _loadItems,
                canRemindTeacher: canRemindTeacher,
                isSelected: _selectedItems.contains(item.id),
                onToggleSelect: (v) => setState(() =>
                    v ? _selectedItems.add(item.id) : _selectedItems.remove(item.id)),
              )),
            ],
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  Future<void> _remindGroupItems(BuildContext context, List<String> itemIds, String targetType) async {
    if (itemIds.isEmpty) return;
    try {
      await ApiService().post('/workflow/requests/${widget.request.id}/remind', body: {
        'item_ids': itemIds,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reminder sent to ${itemIds.length} ${targetType == 'teacher' ? 'teacher(s)' : 'parent(s)'}'),
          backgroundColor: AppTheme.statusGreen,
          duration: const Duration(seconds: 2),
        ));
        _loadItems();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  void _exportItemsExcel() {
    try {
      final workbook = xl.Excel.createExcel();
      final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
      final sheet = workbook.sheets[sheetName]!;

      sheet.appendRow([
        xl.TextCellValue('Class'),
        xl.TextCellValue('Section'),
        xl.TextCellValue('Roll No'),
        xl.TextCellValue('Student Name'),
        xl.TextCellValue('Status'),
        xl.TextCellValue('Teacher'),
        xl.TextCellValue('Last Notified'),
        xl.TextCellValue('Reminder Count'),
      ]);

      for (final item in _items) {
        sheet.appendRow([
          xl.TextCellValue(item.className ?? ''),
          xl.TextCellValue(item.section ?? ''),
          xl.TextCellValue(item.rollNumber ?? ''),
          xl.TextCellValue(item.displayName),
          xl.TextCellValue(_itemStatusLabel(item.status)),
          xl.TextCellValue(item.teacherName ?? ''),
          xl.TextCellValue(item.lastNotifiedAt != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(item.lastNotifiedAt!) : '—'),
          xl.IntCellValue(item.reminderCount),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) return;
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'workflow_items.xlsx');
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      // ignore export errors silently
    }
  }

  String _itemStatusLabel(String status) {
    switch (status) {
      case 'approved':              return 'Approved';
      case 'rejected':              return 'Rejected';
      case 'parent_submitted':      return 'Parent Submitted';
      case 'sent_to_parent':        return 'Sent to Parent';
      case 'teacher_under_review':  return 'Under Review';
      case 'resubmit_requested':    return 'Resubmit Requested';
      default:                      return 'Pending';
    }
  }

  Future<void> _changeStatus(BuildContext context, String action) async {
    final labels = {'cancel': 'Cancel Request', 'hold': 'Put on Hold', 'resume': 'Resume'};
    final colors = {
      'cancel': AppTheme.error,
      'hold':   AppTheme.warning,
      'resume': AppTheme.statusGreen,
    };
    final msgs = {
      'cancel': 'This will permanently cancel the workflow. No further actions can be taken.',
      'hold':   'This will pause the workflow. Teachers and parents will not receive reminders until resumed.',
      'resume': 'This will re-activate the workflow and resume notifications.',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(labels[action]!, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text(msgs[action]!, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No, go back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors[action]),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(labels[action]!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService().patch(
          '/workflow/requests/${widget.request.id}/status', body: {'action': action});
      ref.invalidate(_workflowRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${labels[action]} successful'),
          backgroundColor: colors[action],
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  void _showRemindDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _RemindDialog(requestId: widget.request.id, onSent: _loadItems),
    );
  }

  // ── Bulk actions ─────────────────────────────────────────────
  Future<void> _bulkAction(BuildContext context, String action) async {
    if (_selectedItems.isEmpty) return;
    final ids = List<String>.from(_selectedItems);
    setState(() => _selectedItems = {});
    int ok = 0;
    for (final id in ids) {
      try {
        await ApiService().patch(
          '/workflow/requests/${widget.request.id}/items/$id',
          body: {'action': action},
        );
        ok++;
      } catch (_) {}
    }
    await _loadItems();
    if (mounted) {
      final label = {
        'send_to_parent':    'Sent to parents',
        'approve':           'Approved',
        'reject':            'Rejected',
        'request_resubmit':  'Resubmit requested',
        'mark_under_review': 'Marked under review',
      }[action] ?? action;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label: $ok/${ids.length} done'),
        backgroundColor: ok == ids.length ? AppTheme.statusGreen : AppTheme.warning,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _bulkRemindSelected(BuildContext context) async {
    if (_selectedItems.isEmpty) return;
    final ids = List<String>.from(_selectedItems);
    setState(() => _selectedItems = {});
    try {
      await ApiService().post(
        '/workflow/requests/${widget.request.id}/remind',
        body: {'item_ids': ids},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reminder sent to ${ids.length} student(s)'),
          backgroundColor: AppTheme.statusGreen,
          duration: const Duration(seconds: 2),
        ));
      }
      await _loadItems();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }
}

// ── Overview Tab Content ──────────────────────────────────────
class _ClassOverviewEntry {
  final String className;
  final String section;
  final Map<String, dynamic>? classTeacher;
  final List<Map<String, dynamic>> backupTeachers;
  final Map<String, dynamic>? supervisor;
  final int total, pending, inReview, sentToParent, parentSubmitted, approved, rejected, resubmit;

  const _ClassOverviewEntry({
    required this.className, required this.section,
    this.classTeacher, required this.backupTeachers, this.supervisor,
    required this.total, required this.pending, required this.inReview,
    required this.sentToParent, required this.parentSubmitted,
    required this.approved, required this.rejected, required this.resubmit,
  });

  factory _ClassOverviewEntry.fromJson(Map<String, dynamic> j) {
    final s = (j['stats'] as Map<String, dynamic>?) ?? {};
    return _ClassOverviewEntry(
      className:       j['class_name']   as String? ?? '',
      section:         j['section']      as String? ?? '',
      classTeacher:    j['class_teacher'] as Map<String, dynamic>?,
      backupTeachers:  (j['backup_teachers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      supervisor:      j['supervisor']   as Map<String, dynamic>?,
      total:           (s['total']              as num?)?.toInt() ?? 0,
      pending:         (s['pending']            as num?)?.toInt() ?? 0,
      inReview:        (s['in_review']          as num?)?.toInt() ?? 0,
      sentToParent:    (s['sent_to_parent']      as num?)?.toInt() ?? 0,
      parentSubmitted: (s['parent_submitted']    as num?)?.toInt() ?? 0,
      approved:        (s['approved']            as num?)?.toInt() ?? 0,
      rejected:        (s['rejected']            as num?)?.toInt() ?? 0,
      resubmit:        (s['resubmit_requested']  as num?)?.toInt() ?? 0,
    );
  }
}

class _OverviewTabContent extends StatefulWidget {
  final WorkflowRequest request;
  const _OverviewTabContent({required this.request});

  @override
  State<_OverviewTabContent> createState() => _OverviewTabContentState();
}

class _OverviewTabContentState extends State<_OverviewTabContent> {
  List<_ClassOverviewEntry> _overview = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_OverviewTabContent old) {
    super.didUpdateWidget(old);
    if (old.request.id != widget.request.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().get('/workflow/requests/${widget.request.id}/overview');
      final list = data['data'] as List<dynamic>? ?? [];
      setState(() {
        _overview = list
            .map((e) => _ClassOverviewEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final req = widget.request;
    final fmt = DateFormat('dd MMM yyyy');
    final due = req.extendedDueDate ?? req.dueDate;

    // Aggregate totals from class overview data
    final aggSent      = _overview.fold(0, (s, e) => s + e.sentToParent);
    final aggInReview  = _overview.fold(0, (s, e) => s + e.inReview);
    final aggSubmitted = _overview.fold(0, (s, e) => s + e.parentSubmitted);
    final aggRejected  = _overview.fold(0, (s, e) => s + e.rejected);
    final aggResubmit  = _overview.fold(0, (s, e) => s + e.resubmit);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [

        // ── 1. Progress + Aggregate Stats ────────────────────
        Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primary.withOpacity(0.15)),
          ),
          elevation: 0,
          color: AppTheme.primary.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (req.totalItems > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: req.progressPct,
                            backgroundColor: AppTheme.grey200,
                            color: req.progressPct == 1.0 ? AppTheme.statusGreen : AppTheme.primary,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${(req.progressPct * 100).round()}%',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // All status counts
                Wrap(
                  spacing: 0,
                  children: [
                    _OverviewStatCell('Total',     req.totalItems,     AppTheme.grey600),
                    _OverviewStatCell('Pending',   req.pendingItems,   AppTheme.warning),
                    _OverviewStatCell('Done',      req.completedItems, AppTheme.statusGreen),
                    if (aggInReview  > 0) _OverviewStatCell('In Review',  aggInReview,  AppTheme.warning),
                    if (aggSent      > 0) _OverviewStatCell('Sent',       aggSent,      AppTheme.accent),
                    if (aggSubmitted > 0) _OverviewStatCell('Submitted',  aggSubmitted, AppTheme.statusBlue),
                    if (aggRejected  > 0) _OverviewStatCell('Rejected',   aggRejected,  AppTheme.error),
                    if (aggResubmit  > 0) _OverviewStatCell('Resubmit',   aggResubmit,  const Color(0xFFE65100)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── 2. Schedule & Configuration ──────────────────────
        Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.grey200),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OvSectionLabel('Schedule'),
                const SizedBox(height: 8),
                _OvInfoRow(Icons.play_circle_outline, 'Start Date', fmt.format(req.startDate)),
                if (due != null)
                  _OvInfoRow(Icons.event_outlined, 'Due Date', fmt.format(due)),
                if (req.launchedAt != null)
                  _OvInfoRow(Icons.rocket_launch_outlined, 'Launched', fmt.format(req.launchedAt!)),
                _OvInfoRow(Icons.calendar_today_outlined, 'Created', fmt.format(req.createdAt)),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _OvSectionLabel('Configuration'),
                const SizedBox(height: 8),
                _OvInfoRow(Icons.person_outline, 'Requested By', req.requesterName),
                if (req.templateName.isNotEmpty)
                  _OvInfoRow(Icons.description_outlined, 'Template', req.templateName),
                _OvInfoRow(
                  req.sendToParent ? Icons.share_outlined : Icons.person_off_outlined,
                  'Parent Review',
                  req.sendToParent ? 'Enabled — sent directly to parents' : 'Disabled',
                ),
                if (req.notifyChannels.isNotEmpty)
                  _OvInfoRow(Icons.notifications_outlined, 'Notify Via',
                      req.notifyChannels.map((c) => c.toUpperCase()).join(' · ')),

                // Selected classes chips
                if (req.selectedClasses.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _OvSectionLabel('Classes (${req.selectedClasses.length})'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: req.selectedClasses.map((cs) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Text(
                        '${cs['class_name'] ?? ''} ${cs['section'] ?? ''}'.trim(),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
                      ),
                    )).toList(),
                  ),
                ],

                // Description
                if (req.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _OvSectionLabel('Description'),
                  const SizedBox(height: 6),
                  Text(req.description,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey700, height: 1.6)),
                ],

                // Selected fields chips
                if (req.selectedFields.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _OvSectionLabel('Fields (${req.selectedFields.length})'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: req.selectedFields.map((f) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _fieldLabel(f),
                        style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey700),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── 3. Class-Section Teacher Overview ────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Row(
            children: [
              const Icon(Icons.class_outlined, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Class Overview',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.grey800)),
              const SizedBox(width: 6),
              if (_overview.isNotEmpty)
                Text('(${_overview.length} class${_overview.length == 1 ? '' : 'es'})',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
            ],
          ),
        ),

        if (_overview.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_ind_outlined, size: 36, color: AppTheme.grey300),
                const SizedBox(height: 8),
                Text('No class assignments yet',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Assign teachers to class-sections when creating the workflow.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500),
                    textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ..._overview.map((e) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.grey200),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Class ${e.className} — Sec ${e.section}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary)),
                      ),
                      const Spacer(),
                      if (e.total > 0) ...[
                        _MiniStatPill('${e.approved}/${e.total} done', AppTheme.statusGreen),
                        const SizedBox(width: 6),
                        if (e.pending > 0) _MiniStatPill('${e.pending} pending', AppTheme.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Teacher columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _TeacherCell(
                        label: 'Class Teacher',
                        icon: Icons.person_outline,
                        teacher: e.classTeacher,
                        isPrimary: true,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _TeacherCell(
                        label: 'Backup Teacher',
                        icon: Icons.people_alt_outlined,
                        teacher: e.backupTeachers.isNotEmpty ? e.backupTeachers.first : null,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _TeacherCell(
                        label: 'Supervisor (n+1)',
                        icon: Icons.supervisor_account_outlined,
                        teacher: e.supervisor,
                      )),
                    ],
                  ),
                  if (e.total > 0) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // Full status breakdown per class
                    Wrap(
                      spacing: 0,
                      children: [
                        if (e.pending      > 0) _OverviewStatCell('Pending',   e.pending,        AppTheme.grey500),
                        if (e.inReview     > 0) _OverviewStatCell('In Review', e.inReview,       AppTheme.warning),
                        if (e.sentToParent > 0) _OverviewStatCell('Sent',      e.sentToParent,   AppTheme.accent),
                        if (e.parentSubmitted > 0) _OverviewStatCell('Submitted', e.parentSubmitted, AppTheme.statusBlue),
                        if (e.approved     > 0) _OverviewStatCell('Approved',  e.approved,       AppTheme.statusGreen),
                        if (e.rejected     > 0) _OverviewStatCell('Rejected',  e.rejected,       AppTheme.error),
                        if (e.resubmit     > 0) _OverviewStatCell('Resubmit',  e.resubmit,       const Color(0xFFE65100)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          )),
      ],
    );
  }

  String _fieldLabel(String key) => key.replaceAll('_', ' ').split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}

class _TeacherCell extends StatelessWidget {
  final String label;
  final IconData icon;
  final Map<String, dynamic>? teacher;
  final bool isPrimary;
  const _TeacherCell({required this.label, required this.icon, this.teacher, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.primary.withOpacity(0.04) : AppTheme.grey50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary ? AppTheme.primary.withOpacity(0.2) : AppTheme.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: isPrimary ? AppTheme.primary : AppTheme.grey500),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: isPrimary ? AppTheme.primary : AppTheme.grey600)),
            ],
          ),
          const SizedBox(height: 6),
          if (teacher != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppTheme.grey200,
                  backgroundImage: teacher!['photo'] != null
                      ? NetworkImage(teacher!['photo'] as String) : null,
                  child: teacher!['photo'] == null
                      ? Text(
                          ((teacher!['name'] as String?) ?? '?').isNotEmpty
                              ? (teacher!['name'] as String)[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey700),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(teacher!['name'] as String? ?? '—',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ] else
            Text('Not assigned',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey400,
                    fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniStatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _OverviewStatCell extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _OverviewStatCell(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$count',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.grey500)),
        ],
      ),
    );
  }
}

// ── Item Table Row (Items tab) ─────────────────────────────────
class _ItemTableRow extends StatelessWidget {
  final WorkflowItem item;
  final String requestId;
  final VoidCallback onAction;
  final bool canRemindTeacher;
  final bool isSelected;
  final void Function(bool) onToggleSelect;
  const _ItemTableRow({
    required this.item,
    required this.requestId,
    required this.onAction,
    this.canRemindTeacher = false,
    this.isSelected = false,
    required this.onToggleSelect,
  });

  Color get _statusColor {
    switch (item.status) {
      case 'approved':             return AppTheme.statusGreen;
      case 'rejected':             return AppTheme.error;
      case 'parent_submitted':     return AppTheme.statusBlue;
      case 'sent_to_parent':       return AppTheme.accent;
      case 'teacher_under_review': return AppTheme.warning;
      case 'resubmit_requested':   return const Color(0xFFE65100);
      default:                     return AppTheme.grey400;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'approved':              return 'Approved';
      case 'rejected':              return 'Rejected';
      case 'parent_submitted':      return 'Submitted';
      case 'sent_to_parent':        return 'Sent';
      case 'teacher_under_review':  return 'In Review';
      case 'resubmit_requested':    return 'Resubmit';
      default:                      return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.05) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: AppTheme.grey100)),
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 36,
              child: Checkbox(
                value: isSelected,
                onChanged: (v) => onToggleSelect(v ?? false),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Roll No.
            SizedBox(
              width: 38,
              child: Text(item.rollNumber ?? '—',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey700)),
            ),
            // Student Name
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.grey100,
                    backgroundImage: item.photoUrl != null ? NetworkImage(item.photoUrl!) : null,
                    child: item.photoUrl == null
                        ? Text(item.displayName.isNotEmpty ? item.displayName[0] : '?',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey700))
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item.displayName,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            // Status chip
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _statusColor.withOpacity(0.3)),
                ),
                child: Text(_statusLabel,
                    style: GoogleFonts.poppins(fontSize: 9, color: _statusColor, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
            ),
            // Remind Parent + Teacher columns (senior roles only)
            if (canRemindTeacher) ...[
              SizedBox(width: 80, child: _buildRemindParentCell(context)),
              SizedBox(width: 80, child: _buildRemindTeacherCell(context)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemindParentCell(BuildContext context) {
    if (item.status == 'sent_to_parent') {
      return TextButton.icon(
        onPressed: () => _sendParentReminder(context),
        icon: const Icon(Icons.notifications_active_outlined, size: 12),
        label: Text('Remind', style: GoogleFonts.poppins(fontSize: 10)),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF6A1B9A),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: const Size(0, 26),
        ),
      );
    }
    if (item.status == 'parent_submitted') {
      return Text('Submitted ✓',
          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.statusBlue));
    }
    if (['approved', 'rejected'].contains(item.status)) {
      return Text('—',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey400));
    }
    return Text('Not sent',
        style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.grey400, fontStyle: FontStyle.italic));
  }

  Widget _buildRemindTeacherCell(BuildContext context) {
    if (item.status == 'pending') {
      return TextButton.icon(
        onPressed: () => _sendTeacherReminder(context),
        icon: const Icon(Icons.person_outline, size: 12),
        label: Text('Remind', style: GoogleFonts.poppins(fontSize: 10)),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.warning,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: const Size(0, 26),
        ),
      );
    }
    return Text('—', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey400));
  }

  Future<void> _sendParentReminder(BuildContext context) async {
    try {
      await ApiService().post('/workflow/requests/$requestId/remind', body: {'item_ids': [item.id]});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parent reminder sent'), backgroundColor: AppTheme.statusGreen));
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _sendTeacherReminder(BuildContext context) async {
    try {
      await ApiService().post('/workflow/requests/$requestId/remind', body: {'item_ids': [item.id]});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher reminder sent'), backgroundColor: AppTheme.statusGreen));
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(item: item, requestId: requestId, onAction: onAction),
    );
  }
}

// ── Item Row ──────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final WorkflowItem item;
  final String requestId;
  final VoidCallback onAction;
  const _ItemRow({required this.item, required this.requestId, required this.onAction});

  Color get _statusColor {
    switch (item.status) {
      case 'approved':             return AppTheme.statusGreen;
      case 'rejected':             return AppTheme.error;
      case 'parent_submitted':     return AppTheme.statusBlue;
      case 'sent_to_parent':       return AppTheme.accent;
      case 'teacher_under_review': return AppTheme.warning;
      case 'resubmit_requested':   return const Color(0xFFE65100);
      default:                     return AppTheme.grey400;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'approved':              return 'Approved';
      case 'rejected':              return 'Rejected';
      case 'parent_submitted':      return 'Parent Submitted';
      case 'sent_to_parent':        return 'Sent to Parent';
      case 'teacher_under_review':  return 'Under Review';
      case 'resubmit_requested':    return 'Resubmit Requested';
      default:                      return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showItemDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.grey100,
              backgroundImage: item.photoUrl != null ? NetworkImage(item.photoUrl!) : null,
              child: item.photoUrl == null
                  ? Text(item.displayName.isNotEmpty ? item.displayName[0] : '?',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.grey700))
                  : null,
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  Row(
                    children: [
                      if (item.className != null)
                        Text('${item.className}-${item.section} · Roll ${item.rollNumber ?? '-'}',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                      if (item.teacherName != null) ...[
                        Text(' · ', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400)),
                        Text(item.teacherName!,
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Text(_statusLabel,
                  style: GoogleFonts.poppins(fontSize: 9, color: _statusColor, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            // Quick actions based on status
            if (!['approved','rejected'].contains(item.status))
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: AppTheme.grey600),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onSelected: (action) => _doAction(context, action),
                itemBuilder: (_) => [
                  if (item.status == 'pending')
                    const PopupMenuItem(value: 'send_to_parent',
                        child: ListTile(dense:true, leading: Icon(Icons.send, size:16), title: Text('Send to Parent'))),
                  if (item.status == 'parent_submitted')
                    ...[
                      const PopupMenuItem(value: 'approve',
                          child: ListTile(dense:true, leading: Icon(Icons.check, size:16, color: Colors.green), title: Text('Approve'))),
                      const PopupMenuItem(value: 'request_resubmit',
                          child: ListTile(dense:true, leading: Icon(Icons.undo, size:16, color: Colors.orange), title: Text('Request Resubmit'))),
                      const PopupMenuItem(value: 'reject',
                          child: ListTile(dense:true, leading: Icon(Icons.close, size:16, color: Colors.red), title: Text('Reject'))),
                    ],
                  if (['pending','sent_to_parent'].contains(item.status))
                    const PopupMenuItem(value: 'remind',
                        child: ListTile(dense:true, leading: Icon(Icons.notifications_active_outlined, size:16), title: Text('Send Reminder'))),
                  const PopupMenuItem(value: 'view',
                      child: ListTile(dense:true, leading: Icon(Icons.comment_outlined, size:16), title: Text('View / Comment'))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doAction(BuildContext context, String action) async {
    if (action == 'view') { _showItemDetail(context); return; }
    if (action == 'remind') { _sendReminder(context); return; }

    // Show notes dialog for approve/reject/resubmit
    String? notes;
    if (['approve','reject','request_resubmit'].contains(action)) {
      notes = await _askForNotes(context, action);
      if (notes == null) return; // cancelled
    }

    try {
      await ApiService().patch('/workflow/requests/$requestId/items/${item.id}', body: {
        'action': action,
        'notes': notes,
      });
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<String?> _askForNotes(BuildContext context, String action) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(_actionTitle(action), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Add a comment or note (optional)...',
            hintStyle: GoogleFonts.poppins(fontSize: 12),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: action == 'approve'
                  ? AppTheme.statusGreen
                  : action == 'reject' ? AppTheme.error : AppTheme.warning,
            ),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(_actionLabel(action), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _actionTitle(String action) {
    switch (action) {
      case 'approve':          return 'Approve Submission';
      case 'reject':           return 'Reject Submission';
      case 'request_resubmit': return 'Request Resubmission';
      default:                 return action;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'approve':          return 'Approve';
      case 'reject':           return 'Reject';
      case 'request_resubmit': return 'Request Resubmit';
      default:                 return action;
    }
  }

  Future<void> _sendReminder(BuildContext context) async {
    try {
      await ApiService().post('/workflow/requests/$requestId/remind', body: {
        'item_ids': [item.id],
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder sent'), backgroundColor: AppTheme.statusGreen));
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showItemDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(item: item, requestId: requestId, onAction: onAction),
    );
  }
}

// ── Item Detail Sheet ─────────────────────────────────────────
class _ItemDetailSheet extends StatefulWidget {
  final WorkflowItem item;
  final String requestId;
  final VoidCallback onAction;
  const _ItemDetailSheet({required this.item, required this.requestId, required this.onAction});
  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  List<ItemComment> _comments = [];
  bool _loadingComments = true;
  final _commentCtrl = TextEditingController();
  bool _submittingComment = false;
  List<Map<String, dynamic>> _parentMessages = [];
  bool _loadingParentMessages = false;
  bool _submittingAction = false;

  Future<void> _doItemAction(String action, {String? notes}) async {
    setState(() => _submittingAction = true);
    try {
      await ApiService().patch(
        '/workflow/requests/${widget.requestId}/items/${widget.item.id}',
        body: {
          'action': action,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      widget.onAction();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _submittingAction = false);
    }
  }

  Future<void> _sendReminderFromSheet() async {
    try {
      await ApiService().post('/workflow/requests/${widget.requestId}/remind',
          body: {'item_ids': [widget.item.id]});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reminder sent'),
          backgroundColor: AppTheme.statusGreen,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadParentMessages();
  }

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _loadComments() async {
    try {
      final data = await ApiService().get(
          '/workflow/requests/${widget.requestId}/items/${widget.item.id}/comments');
      setState(() {
        _comments = (data['data'] as List<dynamic>? ?? [])
            .map((e) => ItemComment.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
    setState(() => _loadingComments = false);
  }

  Future<void> _loadParentMessages() async {
    final reviewId = widget.item.parentReviewId;
    if (reviewId == null || reviewId.isEmpty) return;
    setState(() => _loadingParentMessages = true);
    try {
      final data = await ApiService().get('/parent/reviews/$reviewId/messages');
      setState(() {
        _parentMessages = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingParentMessages = false);
  }

  Future<void> _addComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      await ApiService().post(
          '/workflow/requests/${widget.requestId}/items/${widget.item.id}/comments',
          body: {'comment_text': _commentCtrl.text.trim()});
      _commentCtrl.clear();
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize:     0.95,
      minChildSize:     0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.grey300, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.grey100,
                    backgroundImage: widget.item.photoUrl != null ? NetworkImage(widget.item.photoUrl!) : null,
                    child: widget.item.photoUrl == null
                        ? Text(widget.item.displayName.isNotEmpty ? widget.item.displayName[0] : '?',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.grey700))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.displayName,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (widget.item.className != null)
                          Text('Class ${widget.item.className}-${widget.item.section} · Roll ${widget.item.rollNumber ?? '-'}',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + info
                    _ItemStatusSection(item: widget.item),
                    const SizedBox(height: 20),

                    // Teacher notes
                    if (widget.item.teacherNotes?.isNotEmpty == true) ...[
                      Text('Teacher Notes',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.grey200),
                        ),
                        child: Text(widget.item.teacherNotes!,
                            style: GoogleFonts.poppins(fontSize: 13, height: 1.5)),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Parent submitted changes
                    if (widget.item.status == 'parent_submitted' ||
                        widget.item.parentChangesSummary != null) ...[
                      _ParentSubmissionSection(
                        changesSummary: widget.item.parentChangesSummary,
                        submittedAt: widget.item.parentSubmittedAt,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Comment thread
                    Text('Comments',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),
                    if (_loadingComments)
                      const Center(child: CircularProgressIndicator())
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('No comments yet. Start the conversation.',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
                      )
                    else
                      ..._comments.map((c) => _CommentBubble(comment: c)),

                    // Parent ↔ Teacher messages
                    if (widget.item.parentReviewId != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.chat_outlined, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text('Parent Messages',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                          const Spacer(),
                          if (_loadingParentMessages)
                            const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 16),
                              onPressed: _loadParentMessages,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_parentMessages.isEmpty && !_loadingParentMessages)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('No messages exchanged yet.',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
                        )
                      else
                        ..._parentMessages.map((msg) {
                          final isParent = (msg['sender_type'] as String? ?? '') == 'parent';
                          return Align(
                            alignment: isParent ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isParent ? AppTheme.grey100 : AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isParent ? AppTheme.grey200 : AppTheme.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isParent
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    msg['sender_name'] as String? ?? (isParent ? 'Parent' : 'Teacher'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isParent ? AppTheme.grey600 : AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg['message'] as String? ?? '',
                                    style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),

            // ── Action bar (approve / reject / send / remind) ──
            if (!['approved', 'rejected'].contains(widget.item.status)) ...[
              const Divider(height: 1),
              _ItemActionBar(
                item: widget.item,
                submitting: _submittingAction,
                onAction: _doItemAction,
                onRemind: _sendReminderFromSheet,
              ),
            ],

            // Comment input
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: GoogleFonts.poppins(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submittingComment ? null : _addComment,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submittingComment
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Parent Submission Section ─────────────────────────────────
class _ParentSubmissionSection extends StatelessWidget {
  final Map<String, dynamic>? changesSummary;
  final DateTime? submittedAt;
  const _ParentSubmissionSection({this.changesSummary, this.submittedAt});

  static const _fieldLabels = {
    'first_name': 'First Name',
    'last_name': 'Last Name',
    'date_of_birth': 'Date of Birth',
    'address_line1': 'Address Line 1',
    'address_line2': 'Address Line 2',
    'city': 'City',
    'state': 'State',
    'zip_code': 'ZIP Code',
    'bus_route': 'Bus Route',
    'bus_stop': 'Bus Stop',
    'photo_url': 'Photo',
  };

  @override
  Widget build(BuildContext context) {
    final changes = changesSummary ?? {};
    final submittedStr = submittedAt != null
        ? '${submittedAt!.day.toString().padLeft(2,'0')} '
          '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][submittedAt!.month-1]} '
          '${submittedAt!.year}, '
          '${submittedAt!.hour.toString().padLeft(2,'0')}:${submittedAt!.minute.toString().padLeft(2,'0')}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.assignment_turned_in_outlined, size: 16, color: Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Text('Parent Submission',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13,
                  color: const Color(0xFF1565C0))),
          if (submittedStr != null) ...[
            const SizedBox(width: 8),
            Text(submittedStr,
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
          ],
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: changes.isEmpty
              ? Text('Parent confirmed — no changes made.',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column labels
                    Row(children: [
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 26),
                      Expanded(
                        child: Text('Current',
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('New (Parent)',
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.statusGreen),
                            textAlign: TextAlign.center),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ...changes.entries.map((e) {
                    final label = _fieldLabels[e.key] ?? e.key;
                    final oldVal = e.value is Map ? (e.value['old'] ?? '—').toString() : '—';
                    final newVal = e.value is Map ? (e.value['new'] ?? '—').toString() : '—';
                    final isPhoto = e.key == 'photo_url';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: GoogleFonts.poppins(fontSize: 11,
                                  fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
                          const SizedBox(height: 3),
                          if (isPhoto)
                            _PhotoCompare(oldUrl: oldVal, newUrl: newVal)
                          else
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Text(oldVal,
                                    style: GoogleFonts.poppins(fontSize: 12,
                                        color: AppTheme.error,
                                        decoration: TextDecoration.lineThrough)),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward, size: 14, color: AppTheme.grey500),
                              ),
                              Expanded(
                                child: Text(newVal,
                                    style: GoogleFonts.poppins(fontSize: 12,
                                        color: AppTheme.statusGreen,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                        ],
                      ),
                    );
                  }).toList(),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ItemStatusSection extends StatelessWidget {
  final WorkflowItem item;
  const _ItemStatusSection({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'approved': AppTheme.statusGreen, 'rejected': AppTheme.error,
      'parent_submitted': AppTheme.statusBlue, 'sent_to_parent': AppTheme.accent,
      'teacher_under_review': AppTheme.warning, 'resubmit_requested': const Color(0xFFE65100),
      'pending': AppTheme.grey400,
    };
    final statusLabels = {
      'approved': 'Approved', 'rejected': 'Rejected',
      'parent_submitted': 'Parent Submitted', 'sent_to_parent': 'Sent to Parent',
      'teacher_under_review': 'Under Teacher Review', 'resubmit_requested': 'Resubmit Requested',
      'pending': 'Pending',
    };
    final color = statusColors[item.status] ?? AppTheme.grey400;
    final label = statusLabels[item.status] ?? item.status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            ],
          ),
          if (item.teacherName != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline, size: 13, color: AppTheme.grey600),
              const SizedBox(width: 4),
              Text('Assigned to: ${item.teacherName}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
            ]),
          ],
          if (item.lastNotifiedAt != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.notifications_outlined, size: 13, color: AppTheme.grey600),
              const SizedBox(width: 4),
              Text(
                'Last notified: ${DateFormat('dd MMM, hh:mm a').format(item.lastNotifiedAt!)} · ${item.reminderCount} reminder(s)',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final ItemComment comment;
  const _CommentBubble({required this.comment});

  Color get _color {
    switch (comment.commenterType) {
      case 'parent':    return const Color(0xFF1565C0);
      case 'teacher':   return AppTheme.primary;
      case 'admin':     return const Color(0xFF6A1B9A);
      default:          return AppTheme.grey700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _color.withOpacity(0.12),
            child: Text(
              comment.commenterName.isNotEmpty ? comment.commenterName[0] : '?',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: _color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.commenterName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(comment.commenterType,
                          style: GoogleFonts.poppins(fontSize: 9, color: _color, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Text(DateFormat('dd MMM, hh:mm a').format(comment.createdAt),
                        style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.grey50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: Text(comment.commentText,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Remind Dialog ─────────────────────────────────────────────
class _RemindDialog extends StatefulWidget {
  final String requestId;
  final VoidCallback onSent;
  const _RemindDialog({required this.requestId, required this.onSent});
  @override
  State<_RemindDialog> createState() => _RemindDialogState();
}

class _RemindDialogState extends State<_RemindDialog> {
  final _msgCtrl    = TextEditingController();
  DateTime? _extendTo;
  bool _submitting  = false;

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Send Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This will send reminders to all pending parents and teachers via SMS, WhatsApp, and Email.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
          const SizedBox(height: 14),
          TextField(
            controller: _msgCtrl,
            maxLines: 3,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Custom Message (optional)',
              hintText: 'Leave blank to use default reminder message',
              hintStyle: GoogleFonts.poppins(fontSize: 11),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          _DatePickerTile(
            label: 'Extend Due Date (optional)',
            subtitle: 'Give more time to pending recipients',
            icon: Icons.event_available_outlined,
            value: _extendTo != null
                ? DateFormat('dd MMM yyyy').format(_extendTo!)
                : 'Not extended',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 3)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _extendTo = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
          onPressed: _submitting ? null : () async {
            setState(() => _submitting = true);
            try {
              await ApiService().post('/workflow/requests/${widget.requestId}/remind', body: {
                if (_msgCtrl.text.trim().isNotEmpty) 'custom_message': _msgCtrl.text.trim(),
                if (_extendTo != null) 'extend_due_date': DateFormat('yyyy-MM-dd').format(_extendTo!),
              });
              widget.onSent();
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminders sent successfully'),
                        backgroundColor: AppTheme.statusGreen));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
            } finally {
              if (mounted) setState(() => _submitting = false);
            }
          },
          icon: const Icon(Icons.notifications_active_outlined, size: 16),
          label: Text(_submitting ? 'Sending...' : 'Send Reminders',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Shared Helpers ────────────────────────────────────────────
class _TypeIcon extends StatelessWidget {
  final String type;
  final double size;
  const _TypeIcon({required this.type, this.size = 18});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case 'teacher_info': icon = Icons.badge_outlined;        color = const Color(0xFF1565C0); break;
      case 'document':     icon = Icons.folder_open_outlined;  color = const Color(0xFF6A1B9A); break;
      default:             icon = Icons.school_outlined;        color = AppTheme.primary;
    }
    return Icon(icon, color: color, size: size);
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'completed':    color = AppTheme.statusGreen; label = 'Completed';  break;
      case 'in_progress':  color = AppTheme.statusBlue;  label = 'In Progress'; break;
      case 'active':       color = AppTheme.accent;      label = 'Active';     break;
      case 'cancelled':    color = AppTheme.error;       label = 'Cancelled';  break;
      case 'on_hold':      color = AppTheme.warning;    label = 'On Hold';     break;
      default:             color = AppTheme.grey400;     label = 'Draft';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: color, height: 1.4))),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill({required this.icon, required this.label, this.color = AppTheme.grey600});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
      ],
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  const _DatePickerTile({
    required this.label, required this.subtitle, required this.icon,
    required this.value, required this.onTap, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                ],
              ),
            ),
            Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            if (trailing != null) trailing!,
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

String _channelLabel(String ch) {
  switch (ch) {
    case 'sms':      return 'SMS';
    case 'whatsapp': return 'WhatsApp';
    case 'email':    return 'Email';
    default:         return ch;
  }
}

IconData _channelIcon(String ch) {
  switch (ch) {
    case 'sms':      return Icons.sms_outlined;
    case 'whatsapp': return Icons.chat_outlined;
    case 'email':    return Icons.email_outlined;
    default:         return Icons.notifications_outlined;
  }
}

// ── Bulk action button (small icon+label) ──────────────────────
class _BulkBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BulkBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Item action bar (sticky in detail sheet) ───────────────────
class _ItemActionBar extends StatelessWidget {
  final WorkflowItem item;
  final bool submitting;
  final Future<void> Function(String action, {String? notes}) onAction;
  final Future<void> Function() onRemind;
  const _ItemActionBar({
    required this.item,
    required this.submitting,
    required this.onAction,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.grey50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey600)),
          const SizedBox(height: 8),
          if (submitting)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Send to parent (pending / resubmit)
                if (['pending', 'resubmit_requested'].contains(item.status))
                  _ActionChip(
                    label: 'Send to Parent',
                    icon: Icons.send_outlined,
                    color: AppTheme.secondary,
                    onTap: () => onAction('send_to_parent'),
                  ),
                // Mark under review
                if (['pending', 'parent_submitted', 'resubmit_requested']
                    .contains(item.status))
                  _ActionChip(
                    label: 'Under Review',
                    icon: Icons.hourglass_top_outlined,
                    color: AppTheme.warning,
                    onTap: () => onAction('mark_under_review'),
                  ),
                // Approve
                if (!['approved', 'rejected'].contains(item.status))
                  _ActionChip(
                    label: 'Approve',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.statusGreen,
                    onTap: () => _confirmAction(context, 'approve'),
                  ),
                // Request resubmit
                if (!['approved', 'rejected', 'resubmit_requested'].contains(item.status))
                  _ActionChip(
                    label: 'Resubmit',
                    icon: Icons.replay_outlined,
                    color: const Color(0xFFE65100),
                    onTap: () => _confirmAction(context, 'request_resubmit'),
                  ),
                // Reject
                if (!['approved', 'rejected'].contains(item.status))
                  _ActionChip(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: AppTheme.error,
                    onTap: () => _confirmAction(context, 'reject'),
                  ),
                // Remind (sent to parent / pending)
                if (['sent_to_parent', 'pending'].contains(item.status))
                  _ActionChip(
                    label: 'Send Reminder',
                    icon: Icons.notifications_active_outlined,
                    color: AppTheme.primary,
                    onTap: onRemind,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAction(BuildContext context, String action) async {
    final labels = {
      'approve': 'Approve', 'reject': 'Reject', 'request_resubmit': 'Request Resubmit',
    };
    final colors = {
      'approve': AppTheme.statusGreen, 'reject': AppTheme.error,
      'request_resubmit': const Color(0xFFE65100),
    };
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(labels[action]!,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: false,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Add a note (optional)…',
            hintStyle: GoogleFonts.poppins(fontSize: 12),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors[action]),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(labels[action]!,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onAction(action, notes: ctrl.text.trim());
    }
    ctrl.dispose();
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Photo comparison (old | new) ───────────────────────────────
class _PhotoCompare extends StatelessWidget {
  final String oldUrl;
  final String newUrl;
  const _PhotoCompare({required this.oldUrl, required this.newUrl});

  bool _isUrl(String v) => v.startsWith('http');

  Widget _photoBox(String url, String caption, Color borderColor) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _isUrl(url)
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 32,
                          color: AppTheme.grey400),
                    )
                  : Container(
                      color: AppTheme.grey100,
                      child: const Icon(Icons.person_outline,
                          size: 36, color: AppTheme.grey400),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(caption,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: borderColor,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photoBox(oldUrl, 'Current', AppTheme.grey400),
        const SizedBox(width: 10),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 30),
            Icon(Icons.arrow_forward, size: 18, color: AppTheme.grey400),
          ],
        ),
        const SizedBox(width: 10),
        _photoBox(newUrl, 'New (by Parent)', AppTheme.statusGreen),
      ],
    );
  }
}

// ── Group status pill (Items tab group header) ─────────────────
class _GrpStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _GrpStatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Overview section label ──────────────────────────────────────
class _OvSectionLabel extends StatelessWidget {
  final String text;
  const _OvSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppTheme.grey600, letterSpacing: 0.4));
}

// ── Overview info row ───────────────────────────────────────────
class _OvInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _OvInfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.grey500),
          const SizedBox(width: 8),
          Text('$label:  ',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey800)),
          ),
        ],
      ),
    );
  }
}

// ── Overview info chip (Overview tab request summary) ──────────
class _OvInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _OvInfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.grey500),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey700)),
      ],
    );
  }
}
