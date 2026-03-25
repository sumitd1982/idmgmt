// ============================================================
// Workflow Requests Screen — Data Review Workflow System
// Templates → Create → Launch → Track items → Approve/Reject
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────
class WfTemplate {
  final String id;
  final String? schoolId;
  final String name;
  final String templateType;
  final String? description;
  final bool isStandard;
  final String? parentName;
  final List<String> defaultFields;

  const WfTemplate({
    required this.id,
    this.schoolId,
    required this.name,
    required this.templateType,
    this.description,
    required this.isStandard,
    this.parentName,
    required this.defaultFields,
  });

  factory WfTemplate.fromJson(Map<String, dynamic> j) => WfTemplate(
        id:           j['id'] as String,
        schoolId:     j['school_id'] as String?,
        name:         j['name'] as String,
        templateType: j['template_type'] as String,
        description:  j['description'] as String?,
        isStandard:   (j['is_standard'] is bool)
            ? j['is_standard'] as bool
            : (j['is_standard'] as int? ?? 0) == 1,
        parentName:   j['parent_name'] as String?,
        defaultFields: _parseStrList(j['default_fields']),
      );

  static List<String> _parseStrList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.cast<String>();
    if (v is String) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d.cast<String>();
      } catch (_) {}
    }
    return [];
  }
}

class WfRequest {
  final String id;
  final String title;
  final String? description;
  final String requestType;
  final String status;
  final List<String> selectedFields;
  final List<Map<String, String>> selectedClasses;
  final DateTime startDate;
  final DateTime? dueDate;
  final bool sendToParent;
  final int totalItems;
  final int pendingItems;
  final int completedItems;
  final String requestedBy;
  final String requesterName;
  final String? templateName;
  final DateTime createdAt;
  final DateTime? launchedAt;

  const WfRequest({
    required this.id,
    required this.title,
    this.description,
    required this.requestType,
    required this.status,
    required this.selectedFields,
    required this.selectedClasses,
    required this.startDate,
    this.dueDate,
    required this.sendToParent,
    required this.totalItems,
    required this.pendingItems,
    required this.completedItems,
    required this.requestedBy,
    required this.requesterName,
    this.templateName,
    required this.createdAt,
    this.launchedAt,
  });

  double get progress =>
      totalItems > 0 ? completedItems / totalItems : 0.0;

  factory WfRequest.fromJson(Map<String, dynamic> j) {
    List<String> parseStrList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.cast<String>();
      if (v is String) {
        try {
          final d = jsonDecode(v);
          if (d is List) return d.cast<String>();
        } catch (_) {}
      }
      return [];
    }

    List<Map<String, String>> parseClasses(dynamic v) {
      if (v == null) return [];
      List raw = [];
      if (v is List) {
        raw = v;
      } else if (v is String) {
        try {
          final d = jsonDecode(v);
          if (d is List) raw = d;
        } catch (_) {}
      }
      return raw
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    }

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v == 1;
      return false;
    }

    return WfRequest(
      id:             j['id'] as String,
      title:          j['title'] as String? ?? '',
      description:    j['description'] as String?,
      requestType:    j['request_type'] as String? ?? 'student_info',
      status:         j['status'] as String? ?? 'draft',
      selectedFields: parseStrList(j['selected_fields']),
      selectedClasses: parseClasses(j['selected_classes']),
      startDate:      DateTime.tryParse(j['start_date'] as String? ?? '') ??
                      DateTime.now(),
      dueDate:        j['due_date'] != null
                      ? DateTime.tryParse(j['due_date'] as String) : null,
      sendToParent:   parseBool(j['send_to_parent']),
      totalItems:     j['total_items'] as int? ?? 0,
      pendingItems:   j['pending_items'] as int? ?? 0,
      completedItems: j['completed_items'] as int? ?? 0,
      requestedBy:    j['requested_by'] as String? ?? '',
      requesterName:  j['requester_name'] as String? ?? '',
      templateName:   j['template_name'] as String?,
      createdAt:      DateTime.tryParse(j['created_at'] as String? ?? '') ??
                      DateTime.now(),
      launchedAt:     j['launched_at'] != null
                      ? DateTime.tryParse(j['launched_at'] as String) : null,
    );
  }
}

class WfItem {
  final String id;
  final String requestId;
  final String itemType;
  final String? studentId;
  final String? employeeId;
  final String? className;
  final String? section;
  final String? rollNumber;
  final String? assignedTeacherId;
  final String? parentReviewId;
  final String status;
  final String? teacherNotes;
  final String? studentFirst;
  final String? studentLast;
  final String? studentPhoto;
  final String? empFirst;
  final String? empLast;
  final String? teacherName;
  final String? parentReviewStatus;
  final int reminderCount;

  const WfItem({
    required this.id,
    required this.requestId,
    required this.itemType,
    this.studentId,
    this.employeeId,
    this.className,
    this.section,
    this.rollNumber,
    this.assignedTeacherId,
    this.parentReviewId,
    required this.status,
    this.teacherNotes,
    this.studentFirst,
    this.studentLast,
    this.studentPhoto,
    this.empFirst,
    this.empLast,
    this.teacherName,
    this.parentReviewStatus,
    this.reminderCount = 0,
  });

  String get displayName =>
      itemType == 'student'
          ? '${studentFirst ?? ''} ${studentLast ?? ''}'.trim()
          : '${empFirst ?? ''} ${empLast ?? ''}'.trim();

  String get classSection =>
      [className, section].where((s) => s != null && s.isNotEmpty).join(' - ');

  factory WfItem.fromJson(Map<String, dynamic> j) => WfItem(
        id:                j['id'] as String,
        requestId:         j['request_id'] as String? ?? '',
        itemType:          j['item_type'] as String? ?? 'student',
        studentId:         j['student_id'] as String?,
        employeeId:        j['employee_id'] as String?,
        className:         j['class_name'] as String?,
        section:           j['section'] as String?,
        rollNumber:        j['roll_number'] as String?,
        assignedTeacherId: j['assigned_teacher_id'] as String?,
        parentReviewId:    j['parent_review_id'] as String?,
        status:            j['status'] as String? ?? 'pending',
        teacherNotes:      j['teacher_notes'] as String?,
        studentFirst:      j['student_first'] as String?,
        studentLast:       j['student_last'] as String?,
        studentPhoto:      j['student_photo'] as String?,
        empFirst:          j['emp_first'] as String?,
        empLast:           j['emp_last'] as String?,
        teacherName:       j['teacher_name'] as String?,
        parentReviewStatus: j['parent_review_status'] as String?,
        reminderCount:     j['reminder_count'] as int? ?? 0,
      );
}

class WfComment {
  final String id;
  final String commenterName;
  final String commenterType;
  final String text;
  final DateTime createdAt;

  const WfComment({
    required this.id,
    required this.commenterName,
    required this.commenterType,
    required this.text,
    required this.createdAt,
  });

  factory WfComment.fromJson(Map<String, dynamic> j) => WfComment(
        id:            j['id'] as String,
        commenterName: j['commenter_name'] as String? ?? '',
        commenterType: j['commenter_type'] as String? ?? 'teacher',
        text:          j['comment_text'] as String? ?? '',
        createdAt:     DateTime.tryParse(j['created_at'] as String? ?? '') ??
                       DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────
class _WfFilter {
  final String? status;
  final String? requestType;
  const _WfFilter({this.status, this.requestType});
}

final _filterProv = StateProvider<_WfFilter>((ref) => const _WfFilter());
final _selReqProv  = StateProvider<WfRequest?>((ref) => null);
final _selItemProv = StateProvider<WfItem?>((ref) => null);
final _itemStatusProv = StateProvider<String?>((ref) => null);
final _detailTabProv  = StateProvider<int>((ref) => 0);

final _templatesProv = FutureProvider.autoDispose<List<WfTemplate>>((ref) async {
  try {
    final d = await ApiService().get('/workflow/templates');
    final list = d['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => WfTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final _fieldDefsProv =
    FutureProvider.autoDispose<Map<String, Map<String, List<String>>>>(
        (ref) async {
  try {
    final d = await ApiService().get('/workflow/field-defs');
    final raw = d['data'] as Map<String, dynamic>? ?? {};
    return raw.map((type, groups) => MapEntry(
          type,
          (groups as Map<String, dynamic>).map(
            (grp, fields) =>
                MapEntry(grp, (fields as List).cast<String>()),
          ),
        ));
  } catch (_) {
    return {};
  }
});

final _requestsProv =
    FutureProvider.autoDispose<List<WfRequest>>((ref) async {
  final filter = ref.watch(_filterProv);
  try {
    final params = <String, dynamic>{};
    if (filter.status != null) params['status'] = filter.status;
    if (filter.requestType != null) params['request_type'] = filter.requestType;
    final d = await ApiService().get('/workflow/requests', params: params);
    final list = d['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => WfRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final _itemsProv =
    FutureProvider.autoDispose.family<List<WfItem>, String>(
        (ref, requestId) async {
  final statusFilter = ref.watch(_itemStatusProv);
  try {
    final params = <String, dynamic>{'sort_by': 'class'};
    if (statusFilter != null) params['status'] = statusFilter;
    final d = await ApiService()
        .get('/workflow/requests/$requestId/items', params: params);
    final list = d['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => WfItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final _commentsProv =
    FutureProvider.autoDispose.family<List<WfComment>, ({String reqId, String itemId})>(
        (ref, ids) async {
  try {
    final d = await ApiService().get(
        '/workflow/requests/${ids.reqId}/items/${ids.itemId}/comments');
    final list = d['data'] as List<dynamic>? ?? [];
    return list.map((e) => WfComment.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

final _classesProv = FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  try {
    final d = await ApiService().get('/workflow/classes');
    final list = d['data'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
});

final _employeesProv = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ApiService().get('/employees');
    final list = d['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_requestsProv);
    final selected      = ref.watch(_selReqProv);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateWizard(context, ref),
        icon:  const Icon(Icons.add),
        label: const Text('New Request'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ).animate().scale(delay: 300.ms),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => _ErrorView(message: e.toString()),
          data:    (requests) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: selected != null ? 5 : 10,
                child: _RequestList(requests: requests),
              ),
              if (selected != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: _RequestDetailPanel(request: selected),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateWizard(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context:   context,
      barrierDismissible: false,
      builder:   (_) => const _CreateWorkflowWizard(),
    );
    if (result == true) {
      ref.invalidate(_requestsProv);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Request List (Left Panel)
// ─────────────────────────────────────────────────────────────
class _RequestList extends ConsumerWidget {
  final List<WfRequest> requests;
  const _RequestList({required this.requests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter   = ref.watch(_filterProv);
    final selected = ref.watch(_selReqProv);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text('${requests.length} Workflows',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),

        // Status filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                  label: 'All',
                  selected: filter.status == null && filter.requestType == null,
                  onTap: () => ref.read(_filterProv.notifier).state =
                      const _WfFilter()),
              const SizedBox(width: 6),
              for (final s in ['draft', 'active', 'in_progress', 'completed', 'cancelled']) ...[
                _FilterChip(
                    label: _statusLabel(s),
                    selected: filter.status == s,
                    color: _statusColor(s),
                    onTap: () => ref.read(_filterProv.notifier).state =
                        _WfFilter(status: s, requestType: filter.requestType)),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 10),
              // Type filters
              for (final t in ['student_info', 'teacher_info', 'document']) ...[
                _FilterChip(
                    label: _typeLabel(t),
                    selected: filter.requestType == t,
                    color: _typeColor(t),
                    onTap: () => ref.read(_filterProv.notifier).state =
                        _WfFilter(status: filter.status, requestType: t)),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 48, color: AppTheme.grey400),
                      const SizedBox(height: 12),
                      Text('No workflows found',
                          style: GoogleFonts.poppins(
                              color: AppTheme.grey600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('Create one using the + button',
                          style: GoogleFonts.poppins(
                              color: AppTheme.grey400, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _RequestCard(
                    request:    requests[i],
                    isSelected: selected?.id == requests[i].id,
                    onTap: () {
                      ref.read(_selReqProv.notifier).state =
                          selected?.id == requests[i].id ? null : requests[i];
                      ref.read(_selItemProv.notifier).state    = null;
                      ref.read(_detailTabProv.notifier).state  = 0;
                      ref.read(_itemStatusProv.notifier).state = null;
                    },
                  ).animate(delay: (i * 50).ms).fadeIn(duration: 250.ms),
                ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final WfRequest request;
  final bool isSelected;
  final VoidCallback onTap;
  const _RequestCard({
    required this.request,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.grey200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: isSelected ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  _TypeBadge(type: request.requestType),
                  const Spacer(),
                  _StatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                request.title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (request.templateName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Template: ${request.templateName}',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppTheme.grey500),
                ),
              ],
              const SizedBox(height: 10),

              // Progress bar (only if launched)
              if (request.launchedAt != null && request.totalItems > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: request.progress,
                          backgroundColor: AppTheme.grey200,
                          color: request.progress == 1.0
                              ? AppTheme.statusGreen
                              : AppTheme.primary,
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${request.completedItems}/${request.totalItems}',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.grey600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Footer
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 11, color: AppTheme.grey500),
                  const SizedBox(width: 4),
                  Text(request.requesterName,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.grey600)),
                  const Spacer(),
                  if (request.dueDate != null) ...[
                    Icon(Icons.schedule_outlined,
                        size: 11, color: AppTheme.warning),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd MMM').format(request.dueDate!),
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.warning),
                    ),
                  ] else ...[
                    Text(
                      DateFormat('dd MMM').format(request.createdAt),
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.grey500),
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

// ─────────────────────────────────────────────────────────────
// Request Detail Panel (Right Panel)
// ─────────────────────────────────────────────────────────────
class _RequestDetailPanel extends ConsumerStatefulWidget {
  final WfRequest request;
  const _RequestDetailPanel({required this.request});

  @override
  ConsumerState<_RequestDetailPanel> createState() => _RequestDetailPanelState();
}

class _RequestDetailPanelState extends ConsumerState<_RequestDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) {
        ref.read(_detailTabProv.notifier).state = _tabs.index;
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                _TypeBadge(type: req.requestType),
                const SizedBox(width: 10),
                _StatusBadge(status: req.status),
                const Spacer(),
                // Launch button
                if (req.status == 'draft') ...[
                  _LaunchButton(request: req),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  onPressed: () =>
                      ref.read(_selReqProv.notifier).state = null,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(req.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            labelStyle:   GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            labelColor:   AppTheme.primary,
            unselectedLabelColor: AppTheme.grey600,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Items'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(request: req),
                _ItemsTab(request: req),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideX(begin: 0.15, duration: 250.ms);
  }
}

// ─────────────────────────────────────────────────────────────
// Overview Tab
// ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final WfRequest request;
  const _OverviewTab({required this.request});

  @override
  Widget build(BuildContext context) {
    final req = request;
    final fmt = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress (if launched)
          if (req.launchedAt != null && req.totalItems > 0) ...[
            _SectionLabel('Progress'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: req.progress,
                      backgroundColor: AppTheme.grey200,
                      color: req.progress == 1.0
                          ? AppTheme.statusGreen
                          : AppTheme.primary,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(req.progress * 100).round()}%',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(
                    label: 'Total',
                    value: '${req.totalItems}',
                    color: AppTheme.grey600),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'Pending',
                    value: '${req.pendingItems}',
                    color: AppTheme.warning),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'Done',
                    value: '${req.completedItems}',
                    color: AppTheme.statusGreen),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
          ],

          // Schedule
          _SectionLabel('Schedule'),
          const SizedBox(height: 8),
          _InfoRow(
              Icons.play_circle_outline,
              'Start Date',
              fmt.format(req.startDate)),
          if (req.dueDate != null)
            _InfoRow(
                Icons.event_outlined, 'Due Date', fmt.format(req.dueDate!)),
          if (req.launchedAt != null)
            _InfoRow(Icons.rocket_launch_outlined, 'Launched',
                fmt.format(req.launchedAt!)),
          _InfoRow(Icons.calendar_today_outlined, 'Created',
              fmt.format(req.createdAt)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Details
          _SectionLabel('Configuration'),
          const SizedBox(height: 8),
          _InfoRow(Icons.person_outline, 'Requested By', req.requesterName),
          if (req.templateName != null)
            _InfoRow(Icons.description_outlined, 'Template', req.templateName!),
          _InfoRow(
              Icons.share_outlined,
              'Parent Review',
              req.sendToParent ? 'Yes — sent directly to parents' : 'No'),

          // Class-sections
          if (req.selectedClasses.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _SectionLabel('Classes (${req.selectedClasses.length})'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: req.selectedClasses.map((cs) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Text(
                      '${cs['class_name'] ?? ''} ${cs['section'] ?? ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  )).toList(),
            ),
          ],

          // Description
          if (req.description != null && req.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _SectionLabel('Description'),
            const SizedBox(height: 8),
            Text(req.description!,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.grey700,
                    height: 1.6)),
          ],

          // Fields
          if (req.selectedFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _SectionLabel('Fields (${req.selectedFields.length})'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: req.selectedFields.map((f) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _fieldLabel(f),
                      style: GoogleFonts.poppins(fontSize: 10),
                    ),
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _fieldLabel(String key) =>
      key.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
}

// ─────────────────────────────────────────────────────────────
// Items Tab
// ─────────────────────────────────────────────────────────────
class _ItemsTab extends ConsumerWidget {
  final WfRequest request;
  const _ItemsTab({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync   = ref.watch(_itemsProv(request.id));
    final statusFilter = ref.watch(_itemStatusProv);

    return Column(
      children: [
        // Status filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    selected: statusFilter == null,
                    onTap: () =>
                        ref.read(_itemStatusProv.notifier).state = null),
                const SizedBox(width: 6),
                for (final s in [
                  'pending',
                  'sent_to_parent',
                  'parent_submitted',
                  'teacher_under_review',
                  'approved',
                  'rejected',
                  'resubmit_requested',
                ]) ...[
                  _FilterChip(
                      label: _itemStatusLabel(s),
                      selected: statusFilter == s,
                      color: _itemStatusColor(s),
                      onTap: () =>
                          ref.read(_itemStatusProv.notifier).state = s),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => _ErrorView(message: e.toString()),
            data:    (items) => items.isEmpty
                ? Center(
                    child: Text(
                      request.status == 'draft'
                          ? 'Launch the workflow to generate items'
                          : 'No items match the current filter',
                      style: GoogleFonts.poppins(
                          color: AppTheme.grey500, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _ItemRow(
                      item:    items[i],
                      request: request,
                      onTap: () =>
                          _showItemActionSheet(ctx, ref, items[i], request),
                    ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms),
                  ),
          ),
        ),
      ],
    );
  }

  void _showItemActionSheet(
      BuildContext context, WidgetRef ref, WfItem item, WfRequest request) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _ItemActionSheet(item: item, request: request),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final WfItem item;
  final WfRequest request;
  final VoidCallback onTap;
  const _ItemRow({required this.item, required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin:  const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppTheme.grey200),
        ),
        child: Row(
          children: [
            // Avatar / photo
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                item.displayName.isNotEmpty ? item.displayName[0] : '?',
                style: GoogleFonts.poppins(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  Row(
                    children: [
                      if (item.classSection.isNotEmpty) ...[
                        Text(item.classSection,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppTheme.grey600)),
                      ],
                      if (item.rollNumber != null &&
                          item.rollNumber!.isNotEmpty) ...[
                        Text('  #${item.rollNumber}',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppTheme.grey500)),
                      ],
                    ],
                  ),
                  if (item.teacherName != null) ...[
                    Text('Teacher: ${item.teacherName}',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppTheme.grey500)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ItemStatusBadge(status: item.status),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_outlined,
                size: 16, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Item Action Sheet
// ─────────────────────────────────────────────────────────────
class _ItemActionSheet extends ConsumerStatefulWidget {
  final WfItem item;
  final WfRequest request;
  const _ItemActionSheet({
    required this.item,
    required this.request,
  });

  @override
  ConsumerState<_ItemActionSheet> createState() => _ItemActionSheetState();
}

class _ItemActionSheetState extends ConsumerState<_ItemActionSheet> {
  final _notesCtrl    = TextEditingController();
  final _commentCtrl  = TextEditingController();
  bool _submitting    = false;
  bool _commenting    = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _doAction(String action) async {
    setState(() => _submitting = true);
    try {
      await ApiService().patch(
        '/workflow/requests/${widget.request.id}/items/${widget.item.id}',
        body: {
          'action': action,
          if (_notesCtrl.text.trim().isNotEmpty)
            'notes': _notesCtrl.text.trim(),
        },
      );
      ref.invalidate(_itemsProv(widget.request.id));
      ref.invalidate(_requestsProv);
      if (mounted) Navigator.of(context).pop();
      _showSnack(context, _actionLabel(action), _actionColor(action));
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        _showSnack(context, 'Error: $e', AppTheme.error);
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _commenting = true);
    try {
      await ApiService().post(
        '/workflow/requests/${widget.request.id}/items/${widget.item.id}/comments',
        body: {'comment_text': _commentCtrl.text.trim()},
      );
      _commentCtrl.clear();
      ref.invalidate(
          _commentsProv((reqId: widget.request.id, itemId: widget.item.id)));
    } catch (e) {
      _showSnack(context, 'Error: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _commenting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final req  = widget.request;
    final commentsAsync = ref.watch(
        _commentsProv((reqId: req.id, itemId: item.id)));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize:     0.95,
      minChildSize:     0.4,
      expand:           false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.displayName,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        if (item.classSection.isNotEmpty)
                          Text(
                            '${item.classSection}'
                            '${item.rollNumber != null ? ' · #${item.rollNumber}' : ''}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppTheme.grey600),
                          ),
                      ],
                    ),
                  ),
                  _ItemStatusBadge(status: item.status),
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18)),
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
                    // Notes field
                    _SectionLabel('Teacher Notes'),
                    const SizedBox(height: 8),
                    TextField(
                      controller:  _notesCtrl,
                      maxLines:    3,
                      style:       GoogleFonts.poppins(fontSize: 13),
                      decoration:  InputDecoration(
                        hintText:       item.teacherNotes ??
                            'Add notes visible to parent...',
                        hintStyle:      GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.grey400),
                        border:         OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    _SectionLabel('Actions'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing:    8,
                      runSpacing: 8,
                      children: [
                        if (item.status == 'pending' ||
                            item.status == 'parent_submitted' ||
                            item.status == 'resubmit_requested') ...[
                          _ActionBtn(
                            label:    'Send to Parent',
                            icon:     Icons.send_outlined,
                            color:    AppTheme.secondary,
                            onTap:    _submitting ? null : () => _doAction('send_to_parent'),
                          ),
                          _ActionBtn(
                            label:    'Mark Under Review',
                            icon:     Icons.hourglass_top_outlined,
                            color:    AppTheme.info,
                            onTap:    _submitting ? null : () => _doAction('mark_under_review'),
                          ),
                        ],
                        if (item.status != 'approved' &&
                            item.status != 'rejected') ...[
                          _ActionBtn(
                            label:    'Approve',
                            icon:     Icons.check_circle_outline,
                            color:    AppTheme.statusGreen,
                            onTap:    _submitting ? null : () => _doAction('approve'),
                          ),
                          _ActionBtn(
                            label:    'Request Resubmit',
                            icon:     Icons.replay_outlined,
                            color:    AppTheme.warning,
                            onTap:    _submitting ? null : () => _doAction('request_resubmit'),
                          ),
                          _ActionBtn(
                            label:    'Reject',
                            icon:     Icons.cancel_outlined,
                            color:    AppTheme.error,
                            onTap:    _submitting ? null : () => _doAction('reject'),
                          ),
                        ],
                      ],
                    ),
                    if (_submitting) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Comments
                    _SectionLabel('Comments'),
                    const SizedBox(height: 10),

                    // Comment input
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            maxLines:   3,
                            minLines:   1,
                            style:      GoogleFonts.poppins(fontSize: 12),
                            decoration: InputDecoration(
                              hintText:       'Add a comment...',
                              hintStyle:      GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.grey400),
                              border:         OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _commenting ? null : _addComment,
                          child: _commenting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Comment list
                    commentsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error:   (e, _) => const SizedBox.shrink(),
                      data:    (comments) => comments.isEmpty
                          ? Text(
                              'No comments yet.',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.grey400),
                            )
                          : Column(
                              children: comments
                                  .map((c) => _CommentBubble(comment: c))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'approve':          return 'Approved';
      case 'reject':           return 'Rejected';
      case 'request_resubmit': return 'Resubmit requested';
      case 'mark_under_review':return 'Marked under review';
      case 'send_to_parent':   return 'Sent to parent';
      default:                 return 'Done';
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'approve':          return AppTheme.statusGreen;
      case 'reject':           return AppTheme.error;
      case 'request_resubmit': return AppTheme.warning;
      default:                 return AppTheme.primary;
    }
  }
}

class _CommentBubble extends StatelessWidget {
  final WfComment comment;
  const _CommentBubble({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isParent = comment.commenterType == 'parent';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius:          16,
            backgroundColor: isParent
                ? AppTheme.secondary.withOpacity(0.15)
                : AppTheme.primary.withOpacity(0.1),
            child: Icon(
              isParent ? Icons.family_restroom : Icons.school_outlined,
              size:  16,
              color: isParent ? AppTheme.secondary : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.commenterName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 11)),
                    const SizedBox(width: 6),
                    Text(
                      '(${comment.commenterType})',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.grey500),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM, hh:mm a')
                          .format(comment.createdAt),
                      style: GoogleFonts.poppins(
                          fontSize: 9, color: AppTheme.grey400),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color:        AppTheme.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(comment.text,
                      style: GoogleFonts.poppins(
                          fontSize: 12, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Launch Button
// ─────────────────────────────────────────────────────────────
class _LaunchButton extends ConsumerStatefulWidget {
  final WfRequest request;
  const _LaunchButton({required this.request});

  @override
  ConsumerState<_LaunchButton> createState() => _LaunchButtonState();
}

class _LaunchButtonState extends ConsumerState<_LaunchButton> {
  bool _launching = false;

  Future<void> _launch() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Launch Workflow',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will create items for all selected students/teachers and '
          'notify assigned teachers. This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Launch',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _launching = true);
    try {
      await ApiService()
          .post('/workflow/requests/${widget.request.id}/launch', body: {});
      ref.invalidate(_requestsProv);
      ref.invalidate(_itemsProv(widget.request.id));
      ref.read(_selReqProv.notifier).state = null;
      if (mounted) {
        _showSnack(context, 'Workflow launched! Click it to view items.',
            AppTheme.statusGreen);
      }
    } catch (e) {
      if (mounted) _showSnack(context, 'Error: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _launching ? null : _launch,
      style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.statusGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8))),
      icon: _launching
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.rocket_launch_outlined, size: 14),
      label: Text('Launch',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Create Workflow Wizard (5-step dialog)
// ─────────────────────────────────────────────────────────────
class _CreateWorkflowWizard extends ConsumerStatefulWidget {
  const _CreateWorkflowWizard();

  @override
  ConsumerState<_CreateWorkflowWizard> createState() =>
      _CreateWorkflowWizardState();
}

class _CreateWorkflowWizardState
    extends ConsumerState<_CreateWorkflowWizard> {
  int _step = 0;
  bool _saving = false;

  // Step 1: template
  WfTemplate? _selectedTemplate;

  // Step 2: title, fields
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  Set<String> _selectedFields = {};

  // Step 3: classes
  Set<String> _selectedClassKeys = {}; // "class_name||section"

  // Step 4: teacher assignments {classKey → [teacherId]}
  final Map<String, List<String>> _assignments = {};
  String _teacherSearch = '';

  // Step 5: schedule
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _sendToParent = false;
  Set<String> _notifyChannels = {'sms', 'whatsapp', 'email'};

  bool get _isStudentType =>
      (_selectedTemplate?.templateType ?? '') == 'student_info';
  bool get _isTeacherType =>
      (_selectedTemplate?.templateType ?? '') == 'teacher_info';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _selectedTemplate != null;
      case 1: return _titleCtrl.text.trim().isNotEmpty && _selectedFields.isNotEmpty;
      case 2: return _isTeacherType || _selectedClassKeys.isNotEmpty;
      case 3: return true; // teacher assignment optional
      case 4: return _startDate != null;
      default: return false;
    }
  }

  List<Map<String, String>> get _selectedClassList {
    return _selectedClassKeys.map((k) {
      final parts = k.split('||');
      return {'class_name': parts[0], 'section': parts[1]};
    }).toList();
  }

  List<Map<String, dynamic>> get _assignmentList {
    final result = <Map<String, dynamic>>[];
    for (final entry in _assignments.entries) {
      if (entry.value.isEmpty) continue;
      final parts = entry.key.split('||');
      result.add({
        'class_name': parts[0],
        'section':    parts[1],
        'teacher_ids': entry.value,
      });
    }
    return result;
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final body = {
        'template_id':     _selectedTemplate!.id,
        'title':           _titleCtrl.text.trim(),
        'description':     _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'request_type':    _selectedTemplate!.templateType,
        'selected_fields': _selectedFields.toList(),
        'selected_classes': _selectedClassList,
        'start_date':      DateFormat('yyyy-MM-dd').format(_startDate!),
        if (_dueDate != null)
          'due_date': DateFormat('yyyy-MM-dd').format(_dueDate!),
        'send_to_parent':  _sendToParent,
        'notify_channels': _notifyChannels.toList(),
        'assignments':     _assignmentList,
      };
      await ApiService().post('/workflow/requests', body: body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showSnack(context, 'Error: $e', AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['Template', 'Fields', 'Classes', 'Teachers', 'Schedule'];

    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 740,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text('New Workflow Request',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),

            // Step indicators
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: List.generate(steps.length * 2 - 1, (i) {
                  if (i.isOdd) {
                    return Expanded(
                        child: Container(
                            height: 2,
                            color: i ~/ 2 < _step
                                ? AppTheme.primary
                                : AppTheme.grey200));
                  }
                  final idx = i ~/ 2;
                  final done    = idx < _step;
                  final current = idx == _step;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width:  32, height: 32,
                        decoration: BoxDecoration(
                          color: done || current
                              ? AppTheme.primary
                              : AppTheme.grey200,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: done
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : Text('${idx + 1}',
                                  style: GoogleFonts.poppins(
                                      color: current
                                          ? Colors.white
                                          : AppTheme.grey500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(steps[idx],
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: current
                                  ? AppTheme.primary
                                  : AppTheme.grey500,
                              fontWeight: current
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ],
                  );
                }),
              ),
            ),
            const Divider(height: 1),

            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(context),
                ),
              ),
            ),

            // Footer buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12)),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step < 4)
                    ElevatedButton(
                      onPressed: _canProceed
                          ? () => setState(() => _step++)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Next'),
                    ),
                  if (_step == 4)
                    ElevatedButton.icon(
                      onPressed: (_canProceed && !_saving) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_saving ? 'Creating...' : 'Create Draft',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0: return _buildTemplateStep();
      case 1: return _buildFieldsStep();
      case 2: return _buildClassesStep();
      case 3: return _buildTeachersStep();
      case 4: return _buildScheduleStep();
      default: return const SizedBox.shrink();
    }
  }

  // ── Step 1: Template ────────────────────────────────────────
  Widget _buildTemplateStep() {
    final templatesAsync = ref.watch(_templatesProv);
    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorView(message: e.toString()),
      data:    (templates) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a template to start from',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.grey700)),
            const SizedBox(height: 16),
            // Standard templates first
            _SectionLabel('Standard Templates'),
            const SizedBox(height: 10),
            GridView.extent(
              maxCrossAxisExtent: 220,
              shrinkWrap:         true,
              crossAxisSpacing:   12,
              mainAxisSpacing:    12,
              childAspectRatio:   1.4,
              physics: const NeverScrollableScrollPhysics(),
              children: templates
                  .where((t) => t.isStandard)
                  .map((t) => _TemplateCard(
                        template:   t,
                        isSelected: _selectedTemplate?.id == t.id,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = t;
                            _selectedFields = Set.from(t.defaultFields);
                          });
                        },
                      ))
                  .toList(),
            ),
            // School-specific templates
            if (templates.any((t) => !t.isStandard)) ...[
              const SizedBox(height: 20),
              _SectionLabel('Custom Templates'),
              const SizedBox(height: 10),
              GridView.extent(
                maxCrossAxisExtent: 220,
                shrinkWrap:         true,
                crossAxisSpacing:   12,
                mainAxisSpacing:    12,
                childAspectRatio:   1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: templates
                    .where((t) => !t.isStandard)
                    .map((t) => _TemplateCard(
                          template:   t,
                          isSelected: _selectedTemplate?.id == t.id,
                          onTap: () {
                            setState(() {
                              _selectedTemplate = t;
                              _selectedFields = Set.from(t.defaultFields);
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Step 2: Fields + Title ──────────────────────────────────
  Widget _buildFieldsStep() {
    final fieldDefsAsync = ref.watch(_fieldDefsProv);
    final typeKey = _selectedTemplate?.templateType ?? 'student_info';

    return fieldDefsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorView(message: e.toString()),
      data:    (defs) {
        final groups = defs[typeKey] ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleCtrl,
                style:      GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  labelText:    'Workflow Title *',
                  hintText:     'e.g. Student Data Review — Jan 2026',
                  hintStyle:    GoogleFonts.poppins(
                      color: AppTheme.grey400, fontSize: 12),
                  border:       OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon:   const Icon(Icons.title_outlined, size: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines:   2,
                style:      GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border:    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _SectionLabel('Select Fields'),
                  const Spacer(),
                  Text(
                    '${_selectedFields.length} selected',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.grey600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...groups.entries.map((entry) => _FieldGroup(
                    groupName:  entry.key,
                    fields:     entry.value,
                    selected:   _selectedFields,
                    onToggle:   (field) {
                      setState(() {
                        if (_selectedFields.contains(field)) {
                          _selectedFields.remove(field);
                        } else {
                          _selectedFields.add(field);
                        }
                      });
                    },
                    onToggleAll: (fields, allSelected) {
                      setState(() {
                        if (allSelected) {
                          _selectedFields.removeAll(fields);
                        } else {
                          _selectedFields.addAll(fields);
                        }
                      });
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  // ── Step 3: Class Selection ─────────────────────────────────
  Widget _buildClassesStep() {
    if (_isTeacherType) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outlined,
                  size: 48, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                'All active teachers will be included',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'For Teacher Info review, the workflow covers all '
                'active employees in your school/branch.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppTheme.grey600, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final classesAsync = ref.watch(_classesProv);
    return classesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorView(message: e.toString()),
      data:    (classes) => classes.isEmpty
          ? Center(
              child: Text('No classes found. Please add students first.',
                  style: GoogleFonts.poppins(
                      color: AppTheme.grey500, fontSize: 13)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Select Classes & Sections',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppTheme.grey700)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selectedClassKeys.length == classes.length) {
                            _selectedClassKeys.clear();
                          } else {
                            _selectedClassKeys = classes
                                .map((c) =>
                                    '${c['class_name']}||${c['section']}')
                                .toSet();
                          }
                        }),
                        child: Text(
                          _selectedClassKeys.length == classes.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing:    10,
                    runSpacing: 10,
                    children: classes.map((c) {
                      final key =
                          '${c['class_name']}||${c['section']}';
                      final sel = _selectedClassKeys.contains(key);
                      return FilterChip(
                        label: Text(
                          'Class ${c['class_name']} - ${c['section']}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color:
                                  sel ? Colors.white : AppTheme.grey700,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                        ),
                        selected:        sel,
                        selectedColor:   AppTheme.primary,
                        backgroundColor: AppTheme.grey100,
                        checkmarkColor:  Colors.white,
                        side: BorderSide(
                            color: sel
                                ? AppTheme.primary
                                : AppTheme.grey300),
                        onSelected: (_) => setState(() {
                          if (sel) {
                            _selectedClassKeys.remove(key);
                            _assignments.remove(key);
                          } else {
                            _selectedClassKeys.add(key);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  if (_selectedClassKeys.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${_selectedClassKeys.length} class(es) selected',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Step 4: Teacher Assignment ──────────────────────────────
  Widget _buildTeachersStep() {
    final employeesAsync = ref.watch(_employeesProv);

    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorView(message: e.toString()),
      data:    (employees) {
        final selected = _selectedClassKeys.toList()..sort();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isTeacherType
                    ? 'Assign a senior teacher or reviewer for oversight'
                    : 'Assign teachers for each class-section',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.grey700),
              ),
              const SizedBox(height: 6),
              Text(
                'Teachers will receive notifications and can forward to parents.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.grey500),
              ),
              const SizedBox(height: 16),

              if (_isTeacherType) ...[
                // For teacher review, assign one reviewer
                _TeacherAssignRow(
                  classKey:  '_all_teachers_',
                  label:     'Reviewer / Senior Teacher',
                  employees: employees,
                  assigned:  _assignments['_all_teachers_'] ?? [],
                  onChanged: (ids) => setState(
                      () => _assignments['_all_teachers_'] = ids),
                ),
              ] else ...[
                ...selected.map((key) {
                  final parts = key.split('||');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _TeacherAssignRow(
                      classKey:  key,
                      label:     'Class ${parts[0]} - ${parts[1]}',
                      employees: employees,
                      assigned:  _assignments[key] ?? [],
                      onChanged: (ids) =>
                          setState(() => _assignments[key] = ids),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Step 5: Schedule ────────────────────────────────────────
  Widget _buildScheduleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set schedule and notification options',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.grey700)),
          const SizedBox(height: 20),

          // Start date
          _SectionLabel('Start Date *'),
          const SizedBox(height: 8),
          _DatePickerTile(
            label:    _startDate != null
                ? DateFormat('dd MMMM yyyy').format(_startDate!)
                : 'Select start date',
            icon:     Icons.play_circle_outline,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate:   DateTime.now(),
                lastDate:    DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          const SizedBox(height: 14),

          // Due date
          _SectionLabel('Due Date (optional)'),
          const SizedBox(height: 8),
          _DatePickerTile(
            label:    _dueDate != null
                ? DateFormat('dd MMMM yyyy').format(_dueDate!)
                : 'Select due date',
            icon:     Icons.event_outlined,
            onTap: () async {
              final firstDate = _startDate ?? DateTime.now();
              final picked = await showDatePicker(
                context:     context,
                initialDate: firstDate.add(const Duration(days: 7)),
                firstDate:   firstDate,
                lastDate:    DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          const SizedBox(height: 20),

          // Send to parent directly
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        _sendToParent
                  ? AppTheme.secondary.withOpacity(0.08)
                  : AppTheme.grey50,
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(
                  color: _sendToParent
                      ? AppTheme.secondary.withOpacity(0.3)
                      : AppTheme.grey200),
            ),
            child: Row(
              children: [
                Icon(Icons.family_restroom,
                    color: _sendToParent
                        ? AppTheme.secondary
                        : AppTheme.grey400,
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Send Directly to Parents',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text(
                        'Skip teacher step — review links go directly to '
                        'parents/guardians on launch.',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.grey600,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value:    _sendToParent,
                  onChanged: (_isStudentType || _isTeacherType == false)
                      ? (v) => setState(() => _sendToParent = v)
                      : null,
                  activeColor: AppTheme.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notify channels
          _SectionLabel('Notification Channels'),
          const SizedBox(height: 8),
          Wrap(
            spacing:    8,
            runSpacing: 8,
            children: [
              for (final ch in ['sms', 'whatsapp', 'email']) ...[
                FilterChip(
                  label: Text(ch.toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _notifyChannels.contains(ch)
                              ? Colors.white
                              : AppTheme.grey700)),
                  selected:        _notifyChannels.contains(ch),
                  selectedColor:   AppTheme.primary,
                  backgroundColor: AppTheme.grey100,
                  checkmarkColor:  Colors.white,
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _notifyChannels.add(ch);
                    } else {
                      _notifyChannels.remove(ch);
                    }
                  }),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),
          // Summary box
          if (_startDate != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                    color: AppTheme.primary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: AppTheme.primary)),
                  const SizedBox(height: 8),
                  _SummaryRow('Template',
                      _selectedTemplate?.name ?? ''),
                  _SummaryRow('Type',
                      _typeLabel(_selectedTemplate?.templateType ?? '')),
                  _SummaryRow('Fields', '${_selectedFields.length} selected'),
                  if (_isStudentType)
                    _SummaryRow('Classes',
                        '${_selectedClassKeys.length} selected'),
                  _SummaryRow('Start Date',
                      DateFormat('dd MMM yyyy').format(_startDate!)),
                  if (_dueDate != null)
                    _SummaryRow('Due Date',
                        DateFormat('dd MMM yyyy').format(_dueDate!)),
                  _SummaryRow('Parent Direct',
                      _sendToParent ? 'Yes' : 'No'),
                  _SummaryRow('Notify',
                      _notifyChannels.join(', ').toUpperCase()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WfTemplate template;
  final bool isSelected;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = template.templateType == 'student_info'
        ? Icons.people_outlined
        : template.templateType == 'teacher_info'
            ? Icons.school_outlined
            : Icons.badge_outlined;
    final color = template.templateType == 'student_info'
        ? AppTheme.primary
        : template.templateType == 'teacher_info'
            ? AppTheme.secondary
            : AppTheme.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:        isSelected ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: isSelected ? color : AppTheme.grey200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)]
            : [],
      ),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:    const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  if (template.isStandard)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        AppTheme.grey100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Standard',
                          style: GoogleFonts.poppins(
                              fontSize: 8, color: AppTheme.grey600)),
                    ),
                ],
              ),
              const Spacer(),
              Text(template.name,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (template.description != null) ...[
                const SizedBox(height: 2),
                Text(template.description!,
                    style: GoogleFonts.poppins(
                        fontSize: 9, color: AppTheme.grey500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  final String groupName;
  final List<String> fields;
  final Set<String> selected;
  final void Function(String) onToggle;
  final void Function(List<String>, bool allSelected) onToggleAll;
  const _FieldGroup({
    required this.groupName,
    required this.fields,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = fields.every((f) => selected.contains(f));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(groupName,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.grey700)),
              const Spacer(),
              TextButton(
                onPressed: () => onToggleAll(fields, allSelected),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 28)),
                child: Text(allSelected ? 'Deselect all' : 'Select all',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing:    8,
            runSpacing: 6,
            children: fields.map((f) {
              final sel = selected.contains(f);
              return FilterChip(
                label: Text(
                  _fieldLabel(f),
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color:
                          sel ? Colors.white : AppTheme.grey700),
                ),
                selected:        sel,
                selectedColor:   AppTheme.primary,
                backgroundColor: AppTheme.grey100,
                checkmarkColor:  Colors.white,
                side:            BorderSide(
                    color: sel ? AppTheme.primary : AppTheme.grey300),
                onSelected: (_) => onToggle(f),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _fieldLabel(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class _TeacherAssignRow extends StatefulWidget {
  final String classKey;
  final String label;
  final List<Map<String, dynamic>> employees;
  final List<String> assigned;
  final void Function(List<String>) onChanged;
  const _TeacherAssignRow({
    required this.classKey,
    required this.label,
    required this.employees,
    required this.assigned,
    required this.onChanged,
  });

  @override
  State<_TeacherAssignRow> createState() => _TeacherAssignRowState();
}

class _TeacherAssignRowState extends State<_TeacherAssignRow> {
  String _search = '';

  String _empName(Map<String, dynamic> e) =>
      '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final filtered = widget.employees
        .where((e) =>
            _search.isEmpty ||
            _empName(e)
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .take(60)
        .toList();

    final assignedEmps = widget.employees
        .where((e) => widget.assigned.contains(e['id'] as String? ?? ''))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),

          // Assigned teachers chips
          if (assignedEmps.isNotEmpty) ...[
            Wrap(
              spacing:    6,
              runSpacing: 4,
              children: assignedEmps.map((e) => Chip(
                    avatar: CircleAvatar(
                      radius:          10,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        _empName(e).isNotEmpty ? _empName(e)[0] : '?',
                        style: GoogleFonts.poppins(
                            fontSize: 9, color: AppTheme.primary),
                      ),
                    ),
                    label: Text(_empName(e),
                        style: GoogleFonts.poppins(fontSize: 11)),
                    deleteIcon:   const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      final ids = List<String>.from(widget.assigned)
                        ..remove(e['id'] as String? ?? '');
                      widget.onChanged(ids);
                    },
                    visualDensity: VisualDensity.compact,
                  )).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // Search + add
          TextField(
            style:    GoogleFonts.poppins(fontSize: 12),
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText:       'Search teacher to add...',
              hintStyle:      GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey400),
              prefixIcon:     const Icon(Icons.search, size: 16),
              border:         OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              isDense:        true,
            ),
          ),
          if (_search.isNotEmpty && filtered.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border:       Border.all(color: AppTheme.grey200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount:  filtered.length,
                itemBuilder: (_, i) {
                  final e   = filtered[i];
                  final id  = e['id'] as String? ?? '';
                  final sel = widget.assigned.contains(id);
                  return ListTile(
                    dense:       true,
                    leading:     CircleAvatar(
                      radius:          14,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        _empName(e).isNotEmpty ? _empName(e)[0] : '?',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppTheme.primary),
                      ),
                    ),
                    title: Text(_empName(e),
                        style: GoogleFonts.poppins(fontSize: 12)),
                    subtitle: e['designation'] != null
                        ? Text(e['designation'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppTheme.grey500))
                        : null,
                    trailing: sel
                        ? const Icon(Icons.check,
                            size: 16, color: AppTheme.statusGreen)
                        : null,
                    onTap: () {
                      final ids = List<String>.from(widget.assigned);
                      if (sel) {
                        ids.remove(id);
                      } else {
                        ids.add(id);
                      }
                      widget.onChanged(ids);
                      setState(() => _search = '');
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = _typeLabel(type);
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    final color = _statusColor(status);
    final icon  = _statusIcon(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  color:      color,
                  fontSize:   10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ItemStatusBadge extends StatelessWidget {
  final String status;
  const _ItemStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _itemStatusLabel(status);
    final color = _itemStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize:   9,
              color:      color,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
              color: selected ? c : AppTheme.grey200,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize:   11,
                color:      selected ? c : AppTheme.grey600,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon:  Icon(icon, size: 14),
      label: Text(label,
          style: GoogleFonts.poppins(fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize:   12,
            color:      AppTheme.grey700));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.grey500),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppTheme.grey600)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey800)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize:   16,
                  color:      color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DatePickerTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppTheme.grey300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.grey700)),
            const Spacer(),
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey600)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
          const SizedBox(height: 8),
          Text('Something went wrong',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(message,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────
String _statusLabel(String s) {
  switch (s) {
    case 'draft':       return 'Draft';
    case 'active':      return 'Active';
    case 'in_progress': return 'In Progress';
    case 'completed':   return 'Completed';
    case 'cancelled':   return 'Cancelled';
    default:            return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'draft':       return AppTheme.grey600;
    case 'active':      return AppTheme.statusBlue;
    case 'in_progress': return AppTheme.warning;
    case 'completed':   return AppTheme.statusGreen;
    case 'cancelled':   return AppTheme.error;
    default:            return AppTheme.grey600;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'draft':       return Icons.edit_outlined;
    case 'active':      return Icons.play_arrow_outlined;
    case 'in_progress': return Icons.sync;
    case 'completed':   return Icons.check_circle_outline;
    case 'cancelled':   return Icons.cancel_outlined;
    default:            return Icons.circle_outlined;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'student_info': return 'Student Info';
    case 'teacher_info': return 'Teacher Info';
    case 'document':     return 'Documents';
    default:             return t;
  }
}

Color _typeColor(String t) {
  switch (t) {
    case 'student_info': return AppTheme.primary;
    case 'teacher_info': return AppTheme.secondary;
    case 'document':     return AppTheme.accent;
    default:             return AppTheme.grey600;
  }
}

String _itemStatusLabel(String s) {
  switch (s) {
    case 'pending':              return 'Pending';
    case 'sent_to_parent':       return 'Sent to Parent';
    case 'parent_submitted':     return 'Parent Submitted';
    case 'teacher_under_review': return 'Under Review';
    case 'approved':             return 'Approved';
    case 'rejected':             return 'Rejected';
    case 'resubmit_requested':   return 'Resubmit';
    default:                     return s;
  }
}

Color _itemStatusColor(String s) {
  switch (s) {
    case 'pending':              return AppTheme.grey600;
    case 'sent_to_parent':       return AppTheme.secondary;
    case 'parent_submitted':     return AppTheme.info;
    case 'teacher_under_review': return AppTheme.warning;
    case 'approved':             return AppTheme.statusGreen;
    case 'rejected':             return AppTheme.error;
    case 'resubmit_requested':   return AppTheme.accent;
    default:                     return AppTheme.grey600;
  }
}

void _showSnack(BuildContext context, String message, Color color) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:         Text(message, style: GoogleFonts.poppins(fontSize: 12)),
    backgroundColor: color,
    behavior:        SnackBarBehavior.floating,
    shape:           RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8)),
  ));
}
