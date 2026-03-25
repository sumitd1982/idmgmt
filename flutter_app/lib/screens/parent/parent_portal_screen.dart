// ============================================================
// Parent Portal — Redesigned Dashboard (v3)
// Tab per child · Request-wise status · Student menu
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Helpers ───────────────────────────────────────────────────

Map<String, Map<String, dynamic>> _parseChangesMap(dynamic raw) {
  if (raw == null) return {};
  Map<String, dynamic> source = {};
  if (raw is Map) source = Map<String, dynamic>.from(raw);
  final result = <String, Map<String, dynamic>>{};
  source.forEach((k, v) {
    if (v is Map) result[k.toString()] = {'old': v['old'], 'new': v['new']};
  });
  return result;
}

String? _parseChangesSummary(dynamic raw) {
  final map = _parseChangesMap(raw);
  final lines = map.entries
      .where((e) => e.key != 'photo_url')
      .map((e) {
        final label  = e.key.replaceAll('_', ' ');
        final oldVal = e.value['old']?.toString() ?? '—';
        final newVal = e.value['new']?.toString() ?? '—';
        return '$label:  $oldVal  →  $newVal';
      }).toList();
  return lines.isEmpty ? null : lines.join('\n');
}

String _guardianLabel(String type) {
  switch (type) {
    case 'father':    return 'Father';
    case 'mother':    return 'Mother';
    case 'guardian1': return 'Guardian 1';
    case 'guardian2': return 'Guardian 2';
    default:          return 'Guardian';
  }
}

// ── Models ────────────────────────────────────────────────────

class _Guardian {
  final String type;
  final String name;
  final String phone;
  const _Guardian({required this.type, required this.name, required this.phone});
  factory _Guardian.fromJson(Map<String, dynamic> j) => _Guardian(
    type:  j['type']  as String? ?? 'guardian1',
    name:  j['name']  as String? ?? '',
    phone: j['phone'] as String? ?? '',
  );
  bool get hasData => name.isNotEmpty || phone.isNotEmpty;
}

class _ChildInfo {
  final String id;
  final String firstName;
  final String lastName;
  final String className;
  final String section;
  final String schoolName;
  final String branchName;
  final String? photoUrl;
  final String? studentId;
  final String statusColor;
  final String? guardianType;
  final String? classTeacherName;
  final int totalInClass;
  final List<_Guardian> guardians;

  const _ChildInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.className,
    required this.section,
    required this.schoolName,
    required this.branchName,
    this.photoUrl,
    this.studentId,
    required this.statusColor,
    this.guardianType,
    this.classTeacherName,
    this.totalInClass = 0,
    this.guardians = const [],
  });

  factory _ChildInfo.fromJson(Map<String, dynamic> j) {
    final rawGuardians = j['guardians'] as List<dynamic>? ?? [];
    return _ChildInfo(
      id:              j['id']              as String,
      firstName:       j['first_name']      as String? ?? '',
      lastName:        j['last_name']       as String? ?? '',
      className:       j['class_name']      as String? ?? '',
      section:         j['section']         as String? ?? '',
      schoolName:      j['school_name']     as String? ?? '',
      branchName:      j['branch_name']     as String? ?? '',
      photoUrl:        j['photo_url']       as String?,
      studentId:       j['student_id']      as String?,
      statusColor:     j['status_color']    as String? ?? 'green',
      guardianType:    j['guardian_type']   as String?,
      classTeacherName: (j['class_teacher_name'] as String?)?.trim().isEmpty == true
          ? null : j['class_teacher_name'] as String?,
      totalInClass:    (j['total_in_class'] as num?)?.toInt() ?? 0,
      guardians:       rawGuardians
          .map((g) => _Guardian.fromJson(g as Map<String, dynamic>))
          .where((g) => g.hasData)
          .toList(),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class _Review {
  final String id;
  final String status;
  final String? studentId;
  final String studentFirstName;
  final String studentLastName;
  final String className;
  final String section;
  final String? photoUrl;
  final String schoolName;
  final String teacherName;
  final DateTime? linkSentAt;
  final DateTime? linkExpiresAt;
  final DateTime? submittedAt;
  final String? returnReason;
  final bool documentRequired;
  final String? documentInstructions;
  final int docCount;
  final int unreadCount;
  final String? reviewToken;
  final String? changesSummary;
  final String? reviewNotes;
  final Map<String, Map<String, dynamic>> changesMap;

  const _Review({
    required this.id,
    required this.status,
    this.studentId,
    required this.studentFirstName,
    required this.studentLastName,
    required this.className,
    required this.section,
    this.photoUrl,
    required this.schoolName,
    required this.teacherName,
    this.linkSentAt,
    this.linkExpiresAt,
    this.submittedAt,
    this.returnReason,
    required this.documentRequired,
    this.documentInstructions,
    required this.docCount,
    required this.unreadCount,
    this.reviewToken,
    this.changesSummary,
    this.reviewNotes,
    this.changesMap = const {},
  });

  factory _Review.fromJson(Map<String, dynamic> j) {
    final changesMap = _parseChangesMap(j['changes_summary']);
    return _Review(
      id:                   j['id']                   as String,
      status:               j['status']               as String? ?? '',
      studentId:            j['student_id']           as String?,
      studentFirstName:     j['first_name']           as String? ?? '',
      studentLastName:      j['last_name']            as String? ?? '',
      className:            j['class_name']           as String? ?? '',
      section:              j['section']              as String? ?? '',
      photoUrl:             j['photo_url']            as String?,
      schoolName:           j['school_name']          as String? ?? '',
      teacherName:          (j['teacher_name']        as String? ?? '').trim(),
      linkSentAt:           j['link_sent_at']   != null ? DateTime.tryParse(j['link_sent_at'] as String) : null,
      linkExpiresAt:        j['link_expires_at'] != null ? DateTime.tryParse(j['link_expires_at'] as String) : null,
      submittedAt:          j['submitted_at']   != null ? DateTime.tryParse(j['submitted_at'] as String) : null,
      returnReason:         j['return_reason']        as String?,
      documentRequired:     (j['document_required'] as dynamic) == 1 || j['document_required'] == true,
      documentInstructions: j['document_instructions'] as String?,
      docCount:             (j['doc_count']   as num?)?.toInt() ?? 0,
      unreadCount:          (j['unread_count'] as num?)?.toInt() ?? 0,
      reviewToken:          j['review_token'] as String?,
      changesSummary:       _parseChangesSummary(j['changes_summary']),
      reviewNotes:          j['review_notes']         as String?,
      changesMap:           changesMap,
    );
  }

  String get studentFullName => '$studentFirstName $studentLastName'.trim();
  bool get needsAction => ['link_sent', 'returned'].contains(status);
  bool get isSubmitted => status == 'parent_submitted';
  DateTime? get requestDate => linkSentAt;

  Color get statusColor {
    switch (status) {
      case 'link_sent':        return AppTheme.statusRed;
      case 'returned':         return Colors.orange;
      case 'parent_submitted': return AppTheme.statusBlue;
      case 'approved':         return AppTheme.statusGreen;
      default:                 return AppTheme.statusRed;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'link_sent':        return 'Action Required';
      case 'returned':         return 'Revision Needed';
      case 'parent_submitted': return 'Under Review';
      case 'approved':         return 'Approved';
      case 'rejected':         return 'Rejected';
      default:                 return status;
    }
  }
}

class _WorkflowItem {
  final String id;
  final String status;
  final String studentId;
  final String? parentReviewId;
  final String requestId;
  final String title;
  final String? description;
  final DateTime? requestDate;
  final DateTime? dueDate;
  final String? assignedTeacher;
  final String? teacherNotes;

  const _WorkflowItem({
    required this.id,
    required this.status,
    required this.studentId,
    this.parentReviewId,
    required this.requestId,
    required this.title,
    this.description,
    this.requestDate,
    this.dueDate,
    this.assignedTeacher,
    this.teacherNotes,
  });

  factory _WorkflowItem.fromJson(Map<String, dynamic> j) => _WorkflowItem(
    id:              j['id']              as String,
    status:          j['status']          as String? ?? 'pending',
    studentId:       j['student_id']      as String,
    parentReviewId:  j['parent_review_id'] as String?,
    requestId:       j['request_id']      as String,
    title:           j['title']           as String? ?? 'Request',
    description:     j['description']     as String?,
    requestDate:     j['request_date'] != null ? DateTime.tryParse(j['request_date'] as String) : null,
    dueDate:         j['due_date']    != null ? DateTime.tryParse(j['due_date']    as String) : null,
    assignedTeacher: (j['assigned_teacher'] as String?)?.trim(),
    teacherNotes:    j['teacher_notes'] as String?,
  );

  Color get statusColor {
    switch (status) {
      case 'pending':
      case 'sent_to_parent': return AppTheme.statusRed;
      case 'parent_submitted':
      case 'teacher_under_review': return AppTheme.statusBlue;
      case 'approved': return AppTheme.statusGreen;
      case 'rejected': return Colors.redAccent;
      case 'resubmit_requested': return Colors.orange;
      default: return AppTheme.statusRed;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':              return 'Pending';
      case 'sent_to_parent':       return 'Action Required';
      case 'parent_submitted':     return 'Submitted';
      case 'teacher_under_review': return 'Under Review';
      case 'resubmit_requested':   return 'Revision Needed';
      case 'approved':             return 'Approved';
      case 'rejected':             return 'Rejected';
      default:                     return status;
    }
  }
}

class _AttendanceSummary {
  final int? overallPercentage;
  final List<_ModuleAttendance> byModule;
  const _AttendanceSummary({this.overallPercentage, required this.byModule});
  factory _AttendanceSummary.fromJson(Map<String, dynamic> j) {
    final modules = (j['by_module'] as List<dynamic>? ?? [])
        .map((m) => _ModuleAttendance.fromJson(m as Map<String, dynamic>))
        .toList();
    return _AttendanceSummary(
      overallPercentage: (j['overall_percentage'] as num?)?.toInt(),
      byModule: modules,
    );
  }
}

class _ModuleAttendance {
  final String name;
  final String type;
  final int totalDays;
  final int presentDays;
  final int? percentage;
  const _ModuleAttendance({required this.name, required this.type,
      required this.totalDays, required this.presentDays, this.percentage});
  factory _ModuleAttendance.fromJson(Map<String, dynamic> j) => _ModuleAttendance(
    name:        j['name']         as String? ?? '',
    type:        j['type']         as String? ?? '',
    totalDays:   (j['total_days']   as num?)?.toInt() ?? 0,
    presentDays: (j['present_days'] as num?)?.toInt() ?? 0,
    percentage:  (j['percentage']   as num?)?.toInt(),
  );
  IconData get icon {
    switch (type) {
      case 'transport': return Icons.directions_bus;
      case 'event':     return Icons.event;
      default:          return Icons.class_;
    }
  }
  Color get color {
    final pct = percentage ?? 0;
    if (pct >= 75) return AppTheme.statusGreen;
    if (pct >= 50) return Colors.orange;
    return AppTheme.statusRed;
  }
}

class _Message {
  final String id;
  final String senderType;
  final String senderName;
  final String message;
  final DateTime createdAt;
  const _Message({required this.id, required this.senderType,
      required this.senderName, required this.message, required this.createdAt});
  factory _Message.fromJson(Map<String, dynamic> j) => _Message(
    id:         j['id']          as String,
    senderType: j['sender_type'] as String? ?? 'parent',
    senderName: j['sender_name'] as String? ?? '',
    message:    j['message']     as String? ?? '',
    createdAt:  j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
  bool get isParent => senderType == 'parent';
}

// ── Providers ─────────────────────────────────────────────────

final _childrenProvider = FutureProvider.autoDispose<List<_ChildInfo>>((ref) async {
  final data = await ApiService().get('/parent/students');
  final list = data['data'] as List<dynamic>? ?? [];
  return list.map((e) => _ChildInfo.fromJson(e as Map<String, dynamic>)).toList();
});

final _reviewsProvider = FutureProvider.autoDispose<List<_Review>>((ref) async {
  final data = await ApiService().get('/parent/my-reviews');
  final list = data['data'] as List<dynamic>? ?? [];
  return list.map((e) => _Review.fromJson(e as Map<String, dynamic>)).toList();
});

final _reviewsHistoryProvider = FutureProvider.autoDispose<List<_Review>>((ref) async {
  final data = await ApiService().get('/parent/my-reviews', params: {'history': 'true'});
  final list = data['data'] as List<dynamic>? ?? [];
  return list.map((e) => _Review.fromJson(e as Map<String, dynamic>)).toList();
});

final _workflowProvider = FutureProvider.autoDispose<List<_WorkflowItem>>((ref) async {
  final data = await ApiService().get('/parent/workflow-requests');
  final list = data['data'] as List<dynamic>? ?? [];
  return list.map((e) => _WorkflowItem.fromJson(e as Map<String, dynamic>)).toList();
});

final _attendanceProvider = FutureProvider.autoDispose<Map<String, _AttendanceSummary>>((ref) async {
  final data = await ApiService().get('/parent/attendance-summary');
  final map  = data['data'] as Map<String, dynamic>? ?? {};
  return map.map((k, v) => MapEntry(k, _AttendanceSummary.fromJson(v as Map<String, dynamic>)));
});

// ── Main Screen ───────────────────────────────────────────────

class ParentPortalScreen extends ConsumerStatefulWidget {
  const ParentPortalScreen({super.key});
  @override
  ConsumerState<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends ConsumerState<ParentPortalScreen>
    with TickerProviderStateMixin {
  TabController? _tabCtrl;
  bool _welcomeShown = false;

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  void _initTabs(List<_ChildInfo> children) {
    final count = children.length.clamp(1, 10);
    if (_tabCtrl != null && _tabCtrl!.length == count) return;
    _tabCtrl?.dispose();
    _tabCtrl = TabController(length: count, vsync: this);
    if (mounted) setState(() {});
  }

  void _maybeShowWelcome(dynamic user, List<_ChildInfo>? children) {
    if (_welcomeShown) return;
    if (user == null) return;
    final hasNoEmail = user.email == null || (user.email as String).isEmpty;
    if (!hasNoEmail) return;
    if (children == null) return; // wait until children load
    _welcomeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _WelcomeDialog(
          user: user,
          children: children,
          onSaved: () => ref.read(authNotifierProvider.notifier).refreshUser(),
        ),
      );
    });
  }

  void _doRefresh() {
    ref.invalidate(_childrenProvider);
    ref.invalidate(_reviewsProvider);
    ref.invalidate(_reviewsHistoryProvider);
    ref.invalidate(_workflowProvider);
    ref.invalidate(_attendanceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user          = ref.watch(authNotifierProvider).valueOrNull;
    final childrenAsync = ref.watch(_childrenProvider);
    final reviewsAsync  = ref.watch(_reviewsProvider);
    final workflowAsync = ref.watch(_workflowProvider);
    final attendanceAsync = ref.watch(_attendanceProvider);

    // React to children loading
    ref.listen(_childrenProvider, (_, next) {
      final kids = next.valueOrNull;
      if (kids != null) {
        _initTabs(kids);
        _maybeShowWelcome(user, kids);
      }
    });

    final children   = childrenAsync.valueOrNull ?? [];
    final reviews    = reviewsAsync.valueOrNull ?? [];
    final workflows  = workflowAsync.valueOrNull ?? [];
    final attendance = attendanceAsync.valueOrNull ?? {};

    // Total pending across all children
    final totalPending = reviews.where((r) => r.needsAction).length
        + workflows.where((w) => w.status == 'sent_to_parent' || w.status == 'resubmit_requested').length;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: _buildAppBar(context, user, children, totalPending),
      body: RefreshIndicator(
        onRefresh: () async => _doRefresh(),
        child: childrenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => _ErrorView(message: e.toString()),
          data: (kids) {
            if (kids.isEmpty) return _EmptyState();
            if (_tabCtrl == null) return const Center(child: CircularProgressIndicator());
            return TabBarView(
              controller: _tabCtrl,
              children: kids.take(10).map((child) {
                final childReviews   = reviews.where((r) => r.studentId == child.id).toList();
                final childWorkflows = workflows.where((w) => w.studentId == child.id).toList();
                final att            = attendance[child.id];
                return _ChildTab(
                  child: child,
                  activeReviews: childReviews,
                  workflowItems: childWorkflows,
                  attendance: att,
                  onOpenMenu: () => _openStudentMenu(context, ref, child),
                  onRefresh: _doRefresh,
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, dynamic user, List<_ChildInfo> children, int totalPending) {
    final greeting = _greet(user?.fullName as String? ?? 'Parent');
    return AppBar(
      backgroundColor: AppTheme.primary,
      elevation: 0,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
        ],
      ),
      actions: [
        if (totalPending > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$totalPending',
                          style: const TextStyle(color: Colors.white, fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _doRefresh,
        ),
        const SizedBox(width: 4),
      ],
      bottom: children.isNotEmpty && _tabCtrl != null
          ? TabBar(
              controller: _tabCtrl,
              isScrollable: children.length > 4,
              tabAlignment: children.length > 4 ? TabAlignment.start : TabAlignment.fill,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorWeight: 3,
              tabs: children.take(10).map((c) => Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.firstName,
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      Text(c.className,
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              )).toList(),
            )
          : null,
    );
  }

  void _openStudentMenu(BuildContext context, WidgetRef ref, _ChildInfo child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentMenuSheet(child: child, ref: ref),
    );
  }

  String _greet(String name) {
    final h = DateTime.now().hour;
    final s = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    final first = name.isNotEmpty ? name.split(' ').first : 'Parent';
    return '$s, $first!';
  }
}

// ── Child Tab ─────────────────────────────────────────────────

class _ChildTab extends StatelessWidget {
  final _ChildInfo child;
  final List<_Review> activeReviews;
  final List<_WorkflowItem> workflowItems;
  final _AttendanceSummary? attendance;
  final VoidCallback onOpenMenu;
  final VoidCallback onRefresh;

  const _ChildTab({
    required this.child,
    required this.activeReviews,
    required this.workflowItems,
    this.attendance,
    required this.onOpenMenu,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Merge and sort active requests newest first
    final requests = _buildMergedRequests();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Child Info Card ──
          _ChildInfoCard(child: child),
          const SizedBox(height: 16),

          // ── Active Requests ──
          _SectionBar(
            title: 'Requests',
            icon: Icons.assignment_outlined,
            count: requests.length,
          ),
          const SizedBox(height: 8),
          if (requests.isEmpty)
            _EmptyTile(icon: Icons.check_circle_outline,
                message: 'No active requests — all clear!')
          else
            ...requests.asMap().entries.map((e) => _RequestCard(
              request: e.value,
              index: e.key,
              context: context,
            )),

          const SizedBox(height: 20),

          // ── Attendance Mini ──
          _SectionBar(
            title: 'Attendance (30 days)',
            icon: Icons.bar_chart_outlined,
            trailing: TextButton(
              onPressed: onOpenMenu,
              child: Text('View all',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          if (attendance == null || attendance!.byModule.isEmpty)
            _EmptyTile(icon: Icons.event_busy_outlined, message: 'No attendance data available')
          else
            _AttendanceMiniCard(summary: attendance!),

          const SizedBox(height: 20),

          // ── Open Full Profile ──
          OutlinedButton.icon(
            onPressed: onOpenMenu,
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text('Open full profile',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  List<_MergedRequest> _buildMergedRequests() {
    final list = <_MergedRequest>[];

    for (final r in activeReviews) {
      list.add(_MergedRequest.fromReview(r));
    }

    // Only add workflow items that don't have an associated parent_review_id
    // (to avoid duplication with review requests)
    for (final w in workflowItems) {
      if (w.parentReviewId == null) {
        list.add(_MergedRequest.fromWorkflow(w));
      }
    }

    // Sort: newest first
    list.sort((a, b) {
      final da = a.requestDate ?? DateTime(2000);
      final db = b.requestDate ?? DateTime(2000);
      return db.compareTo(da);
    });
    return list;
  }
}

// ── Merged Request model ──────────────────────────────────────

class _MergedRequest {
  final String id;
  final String type; // 'review' or 'workflow'
  final String studentId;
  final String title;
  final DateTime? requestDate;
  final Color statusColor;
  final String statusLabel;
  final bool needsAction;
  final String? reviewToken; // for review type
  final String? workflowId; // for workflow type

  const _MergedRequest({
    required this.id,
    required this.type,
    required this.studentId,
    required this.title,
    this.requestDate,
    required this.statusColor,
    required this.statusLabel,
    required this.needsAction,
    this.reviewToken,
    this.workflowId,
  });

  factory _MergedRequest.fromReview(_Review r) => _MergedRequest(
    id:          r.id,
    type:        'review',
    studentId:   r.studentId ?? '',
    title:       'Data Review Request',
    requestDate: r.linkSentAt,
    statusColor: r.statusColor,
    statusLabel: r.statusLabel,
    needsAction: r.needsAction,
    reviewToken: r.reviewToken,
  );

  factory _MergedRequest.fromWorkflow(_WorkflowItem w) => _MergedRequest(
    id:          w.id,
    type:        'workflow',
    studentId:   w.studentId,
    title:       w.title,
    requestDate: w.requestDate,
    statusColor: w.statusColor,
    statusLabel: w.statusLabel,
    needsAction: w.status == 'sent_to_parent' || w.status == 'resubmit_requested' || w.status == 'pending',
    workflowId:  w.requestId,
  );
}

// ── Request Card ──────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final _MergedRequest request;
  final int index;
  final BuildContext context;

  const _RequestCard({required this.request, required this.index, required this.context});

  @override
  Widget build(BuildContext outerContext) {
    final isUrgent = request.needsAction;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isUrgent
            ? BorderSide(color: request.statusColor.withOpacity(0.4), width: 1)
            : BorderSide.none,
      ),
      elevation: isUrgent ? 3 : 1,
      child: InkWell(
        onTap: isUrgent && request.type == 'review' && request.reviewToken != null
            ? () {
                final router = GoRouter.of(outerContext);
                router.go('/parent-review?token=${request.reviewToken}');
              }
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: request.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  request.type == 'review'
                      ? (isUrgent ? Icons.assignment_late_outlined : Icons.assignment_turned_in_outlined)
                      : Icons.task_outlined,
                  color: request.statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.title,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppTheme.grey900)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: request.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: request.statusColor.withOpacity(0.3)),
                          ),
                          child: Text(request.statusLabel,
                              style: GoogleFonts.poppins(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: request.statusColor)),
                        ),
                        if (request.requestDate != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.calendar_today_outlined,
                              size: 10, color: AppTheme.grey400),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('d MMM yyyy').format(request.requestDate!),
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppTheme.grey500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isUrgent && request.type == 'review' && request.reviewToken != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: request.statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Open',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                )
              else
                Icon(Icons.chevron_right, color: AppTheme.grey400, size: 20),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }
}

// ── Child Info Card ───────────────────────────────────────────

class _ChildInfoCard extends StatelessWidget {
  final _ChildInfo child;
  const _ChildInfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage:
                    child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
                child: child.photoUrl == null
                    ? Text(
                        child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.fullName,
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${child.className} · Section ${child.section}',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12)),
                    Text(child.branchName,
                        style: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              // Status dot
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.circle,
                    size: 10,
                    color: child.statusColor == 'green'
                        ? AppTheme.statusGreen
                        : child.statusColor == 'blue'
                            ? AppTheme.statusBlue
                            : AppTheme.statusRed),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Info chips row
          Row(
            children: [
              if (child.classTeacherName != null && child.classTeacherName!.isNotEmpty)
                Expanded(
                  child: _InfoChip(
                    icon: Icons.person_outline,
                    label: child.classTeacherName!,
                    subtitle: 'Class Teacher',
                  ),
                ),
              if (child.classTeacherName != null && child.classTeacherName!.isNotEmpty)
                const SizedBox(width: 8),
              if (child.totalInClass > 0)
                _InfoChip(
                  icon: Icons.groups_outlined,
                  label: '${child.totalInClass}',
                  subtitle: 'In Class',
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  const _InfoChip({required this.icon, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attendance Mini Card ──────────────────────────────────────

class _AttendanceMiniCard extends StatelessWidget {
  final _AttendanceSummary summary;
  const _AttendanceMiniCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final overall = summary.overallPercentage;
    final overallColor = overall == null
        ? AppTheme.grey400
        : overall >= 75
            ? AppTheme.statusGreen
            : overall >= 50 ? Colors.orange : AppTheme.statusRed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          if (overall != null) ...[
            Row(
              children: [
                SizedBox(
                  width: 44, height: 44,
                  child: Stack(children: [
                    SizedBox(
                      width: 44, height: 44,
                      child: CircularProgressIndicator(
                        value: overall / 100,
                        strokeWidth: 5,
                        backgroundColor: AppTheme.grey200,
                        valueColor: AlwaysStoppedAnimation<Color>(overallColor),
                      ),
                    ),
                    Center(
                      child: Text('$overall%',
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: overallColor)),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Attendance',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppTheme.grey900)),
                      Text(
                        overall >= 75 ? 'Great attendance!' :
                        overall >= 50 ? 'Needs improvement' : 'Attendance is low',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: overallColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.byModule.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
            ],
          ],
          // Module bars (max 3)
          Row(
            children: summary.byModule.take(3).map((m) {
              final pct = m.percentage ?? 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(m.icon, size: 11, color: m.color),
                          Text('$pct%',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: m.color)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 5,
                          backgroundColor: AppTheme.grey200,
                          valueColor: AlwaysStoppedAnimation<Color>(m.color),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.type == 'transport' ? 'Bus' : m.name,
                        style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.grey500),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Student Menu Sheet ────────────────────────────────────────

class _StudentMenuSheet extends StatefulWidget {
  final _ChildInfo child;
  final WidgetRef ref;
  const _StudentMenuSheet({required this.child, required this.ref});
  @override
  State<_StudentMenuSheet> createState() => _StudentMenuSheetState();
}

class _StudentMenuSheetState extends State<_StudentMenuSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<_Review>? _historyReviews;
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadHistory() async {
    try {
      final data = await ApiService().get('/parent/my-reviews', params: {'history': 'true'});
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => _Review.fromJson(e as Map<String, dynamic>))
          .where((r) => r.studentId == widget.child.id)
          .toList();
      if (mounted) setState(() { _historyReviews = list; _historyLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final reviews    = widget.ref.read(_reviewsProvider).valueOrNull ?? [];
    final workflows  = widget.ref.read(_workflowProvider).valueOrNull ?? [];
    final attendance = widget.ref.read(_attendanceProvider).valueOrNull ?? {};

    final childReviews   = reviews.where((r) => r.studentId == child.id).toList();
    final childWorkflows = workflows.where((w) => w.studentId == child.id).toList();
    final att            = attendance[child.id];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.grey300, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    backgroundImage: child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
                    child: child.photoUrl == null
                        ? Text(child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(
                                fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primary))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.fullName,
                            style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w700,
                                color: AppTheme.grey900)),
                        Text('${child.className} · Section ${child.section} · ${child.branchName}',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.grey500),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Tabs
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.grey500,
              indicatorColor: AppTheme.primary,
              labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Requests'),
                Tab(text: 'Attendance'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // ── Tab 1: Overview ──
                  _buildOverviewTab(controller, child, att),
                  // ── Tab 2: Requests (active + history) ──
                  _buildRequestsTab(controller, childReviews, childWorkflows),
                  // ── Tab 3: Attendance ──
                  _buildAttendanceTab(controller, att),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ScrollController ctrl, _ChildInfo child, _AttendanceSummary? att) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Student info block
        _SectionBar(title: 'Student Details', icon: Icons.person_outline),
        const SizedBox(height: 10),
        _InfoCard(children: [
          _InfoRow(label: 'Name', value: child.fullName),
          _InfoRow(label: 'Class', value: child.className),
          _InfoRow(label: 'Section', value: child.section),
          if (child.classTeacherName != null && child.classTeacherName!.isNotEmpty)
            _InfoRow(label: 'Class Teacher', value: child.classTeacherName!),
          _InfoRow(label: 'Branch', value: child.branchName),
          _InfoRow(label: 'School', value: child.schoolName),
          if (child.totalInClass > 0)
            _InfoRow(label: 'Students in Class', value: '${child.totalInClass}'),
        ]),
        const SizedBox(height: 20),
        // Attendance quick view
        _SectionBar(title: 'Attendance', icon: Icons.bar_chart_outlined),
        const SizedBox(height: 10),
        if (att == null || att.byModule.isEmpty)
          _EmptyTile(icon: Icons.event_busy_outlined, message: 'No attendance data')
        else
          _AttendanceMiniCard(summary: att),
      ],
    );
  }

  Widget _buildRequestsTab(
    ScrollController ctrl,
    List<_Review> activeReviews,
    List<_WorkflowItem> activeWorkflows,
  ) {
    // Build merged active requests
    final activeList = <_MergedRequest>[];
    for (final r in activeReviews) activeList.add(_MergedRequest.fromReview(r));
    for (final w in activeWorkflows) {
      if (w.parentReviewId == null) activeList.add(_MergedRequest.fromWorkflow(w));
    }
    activeList.sort((a, b) {
      final da = a.requestDate ?? DateTime(2000);
      final db = b.requestDate ?? DateTime(2000);
      return db.compareTo(da);
    });

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Active requests
        _SectionBar(
            title: 'Active Requests',
            icon: Icons.pending_actions_outlined,
            count: activeList.length),
        const SizedBox(height: 8),
        if (activeList.isEmpty)
          _EmptyTile(icon: Icons.check_circle_outline, message: 'No active requests')
        else
          ...activeList.asMap().entries.map((e) => _RequestCard(
                request: e.value,
                index: e.key,
                context: context,
              )),

        const SizedBox(height: 24),

        // History
        _SectionBar(
            title: 'Request History',
            icon: Icons.history_outlined,
            count: _historyReviews?.length ?? 0),
        const SizedBox(height: 8),
        if (_historyLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_historyReviews == null || _historyReviews!.isEmpty)
          _EmptyTile(icon: Icons.inbox_outlined, message: 'No completed requests yet')
        else
          ..._historyReviews!.asMap().entries.map((e) => _HistoryTile(
                review: e.value, index: e.key)),
      ],
    );
  }

  Widget _buildAttendanceTab(ScrollController ctrl, _AttendanceSummary? att) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionBar(title: 'Attendance (Last 30 Days)', icon: Icons.calendar_today_outlined),
        const SizedBox(height: 12),
        if (att == null || att.byModule.isEmpty)
          _EmptyTile(icon: Icons.event_busy_outlined, message: 'No attendance data available')
        else ...[
          if (att.overallPercentage != null) ...[
            _OverallAttendanceCard(percentage: att.overallPercentage!),
            const SizedBox(height: 12),
          ],
          ...att.byModule.map((m) => _AttendanceModuleCard(module: m)),
        ],
      ],
    );
  }
}

// ── Info Card / Row ───────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.grey900)),
          ),
        ],
      ),
    );
  }
}

// ── History Tile ──────────────────────────────────────────────

class _HistoryTile extends StatefulWidget {
  final _Review review;
  final int index;
  const _HistoryTile({required this.review, required this.index});
  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final review     = widget.review;
    final isApproved = review.status == 'approved';
    final color      = isApproved ? AppTheme.statusGreen : Colors.redAccent;
    final icon       = isApproved ? Icons.check_circle_outline : Icons.cancel_outlined;
    final changes    = review.changesMap;
    final hasChanges = changes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        onTap: hasChanges ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Data Review Request',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppTheme.grey900)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Text(review.statusLabel,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10, fontWeight: FontWeight.w600,
                                      color: color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (review.linkSentAt != null)
                          Text(
                            'Requested ${DateFormat('d MMM yyyy').format(review.linkSentAt!)}',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400),
                          ),
                        if (review.submittedAt != null)
                          Text(
                            'Submitted ${DateFormat('d MMM yyyy').format(review.submittedAt!)}',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400),
                          ),
                      ],
                    ),
                  ),
                  if (hasChanges)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.grey400, size: 18,
                    ),
                ],
              ),
              if (review.reviewNotes != null && review.reviewNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 13, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(review.reviewNotes!,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppTheme.grey700,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_expanded && hasChanges) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _ChangesView(changesMap: changes),
              ],
              if (!_expanded && hasChanges) ...[
                const SizedBox(height: 4),
                Text(
                  '${changes.length} change${changes.length > 1 ? 's' : ''} — tap to view',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: (widget.index * 50).ms).fadeIn(duration: 300.ms);
  }
}

class _ChangesView extends StatelessWidget {
  final Map<String, Map<String, dynamic>> changesMap;
  const _ChangesView({required this.changesMap});
  @override
  Widget build(BuildContext context) {
    final photoChange  = changesMap['photo_url'];
    final fieldChanges = changesMap.entries.where((e) => e.key != 'photo_url').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photoChange != null) ...[
          Text('Photo', style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.grey700)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _PhotoCompare(label: 'Before',
                url: photoChange['old'] as String?, accent: AppTheme.grey400)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: AppTheme.grey400),
            ),
            Expanded(child: _PhotoCompare(label: 'After',
                url: photoChange['new'] as String?, accent: AppTheme.statusGreen)),
          ]),
          const SizedBox(height: 10),
        ],
        if (fieldChanges.isNotEmpty) ...[
          Text('Changes', style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.grey700)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Column(
              children: fieldChanges.asMap().entries.map((entry) {
                final isLast = entry.key == fieldChanges.length - 1;
                final field  = entry.value.key.replaceAll('_', ' ');
                final oldVal = entry.value.value['old']?.toString() ?? '—';
                final newVal = entry.value.value['new']?.toString() ?? '—';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(bottom: BorderSide(color: AppTheme.grey200)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field, style: GoogleFonts.poppins(
                          fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey500)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Expanded(child: Text(oldVal,
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: Colors.redAccent.shade200,
                                decoration: TextDecoration.lineThrough))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward, size: 12, color: AppTheme.grey400),
                        ),
                        Expanded(child: Text(newVal,
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: AppTheme.statusGreen, fontWeight: FontWeight.w500))),
                      ]),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Photo Compare ─────────────────────────────────────────────

class _PhotoCompare extends StatelessWidget {
  final String label;
  final String? url;
  final Color accent;
  const _PhotoCompare({required this.label, this.url, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
      const SizedBox(height: 4),
      Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null
            ? Image.network(url!, fit: BoxFit.cover, width: double.infinity,
                errorBuilder: (_, __, ___) => _noPhoto())
            : _noPhoto(),
      ),
    ]);
  }

  Widget _noPhoto() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.person_outline, color: AppTheme.grey400, size: 28),
      Text('No photo', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.grey400)),
    ]),
  );
}

// ── Attendance Widgets ────────────────────────────────────────

class _OverallAttendanceCard extends StatelessWidget {
  final int percentage;
  const _OverallAttendanceCard({required this.percentage});
  @override
  Widget build(BuildContext context) {
    final color = percentage >= 75 ? AppTheme.statusGreen
        : percentage >= 50 ? Colors.orange : AppTheme.statusRed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        SizedBox(
          width: 60, height: 60,
          child: Stack(children: [
            SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(
                value: percentage / 100,
                strokeWidth: 6,
                backgroundColor: AppTheme.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Center(child: Text('$percentage%',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color))),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overall Attendance',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
            Text('Last 30 days · All modules',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
            const SizedBox(height: 4),
            Text(
              percentage >= 75 ? 'Good attendance!' :
              percentage >= 50 ? 'Needs improvement' : 'Attendance is low',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AttendanceModuleCard extends StatelessWidget {
  final _ModuleAttendance module;
  const _AttendanceModuleCard({required this.module});
  @override
  Widget build(BuildContext context) {
    final pct = module.percentage ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: module.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(module.icon, color: module.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(module.name,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey900)),
            Text('${module.presentDays}/${module.totalDays} days present',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 5,
                backgroundColor: AppTheme.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(module.color),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Text('$pct%',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: module.color)),
      ]),
    );
  }
}

// ── Message Widgets ───────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _Message msg;
  const _MessageBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isMe = msg.isParent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.15),
              child: Icon(Icons.person, size: 16, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(msg.senderName,
                        style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary : AppTheme.grey100,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(msg.message,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isMe ? Colors.white : AppTheme.grey900)),
                ),
                const SizedBox(height: 2),
                Text(DateFormat('hh:mm a').format(msg.createdAt),
                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400)),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.15),
              child: Icon(Icons.family_restroom, size: 14, color: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Review Detail Sheet ───────────────────────────────────────
// (Used from requests tab when parent opens an active review)

class _ReviewDetailSheet extends StatefulWidget {
  final _Review review;
  final WidgetRef ref;
  const _ReviewDetailSheet({required this.review, required this.ref});
  @override
  State<_ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<_ReviewDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<_Message> _messages = [];
  bool _msgLoading = true;
  final _msgController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() { _tabs.dispose(); _msgController.dispose(); super.dispose(); }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService().get('/parent/reviews/${widget.review.id}/messages');
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((m) => _Message.fromJson(m as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _messages = list; _msgLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _msgLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final txt = _msgController.text.trim();
    if (txt.isEmpty) return;
    setState(() => _sending = true);
    try {
      final data = await ApiService().post(
        '/parent/reviews/${widget.review.id}/messages',
        body: {'message': txt},
      );
      final msg = _Message.fromJson(data['data'] as Map<String, dynamic>);
      _msgController.clear();
      setState(() { _messages.add(msg); _sending = false; });
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.grey300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(review.studentFullName,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: review.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: review.statusColor.withOpacity(0.3)),
                      ),
                      child: Text(review.statusLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: review.statusColor)),
                    ),
                    const SizedBox(width: 8),
                    Text('${review.className} · ${review.section}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                  ]),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppTheme.grey500),
              ),
            ]),
          ),
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.grey500,
            indicatorColor: AppTheme.primary,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Details'), Tab(text: 'Messages')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Details tab
                ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (review.returnReason != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Returned for revision',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, fontWeight: FontWeight.w700,
                                          color: Colors.orange)),
                                  const SizedBox(height: 2),
                                  Text(review.returnReason!,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: AppTheme.grey700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _DetailRow(label: 'Teacher',
                        value: review.teacherName.isEmpty ? 'Not assigned' : review.teacherName),
                    _DetailRow(label: 'School', value: review.schoolName),
                    _DetailRow(label: 'Status', value: review.statusLabel),
                    if (review.linkSentAt != null)
                      _DetailRow(label: 'Requested',
                          value: DateFormat('d MMM yyyy').format(review.linkSentAt!)),
                    if (review.linkExpiresAt != null)
                      _DetailRow(label: 'Expires',
                          value: DateFormat('d MMM yyyy').format(review.linkExpiresAt!)),
                    if (review.submittedAt != null)
                      _DetailRow(label: 'Submitted',
                          value: DateFormat('d MMM yyyy').format(review.submittedAt!)),
                    if (review.documentRequired)
                      _DetailRow(label: 'Documents',
                          value: '${review.docCount} uploaded'
                              '${review.documentInstructions != null ? " · ${review.documentInstructions}" : ""}'),
                    if (review.needsAction) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          final token  = review.reviewToken;
                          final router = GoRouter.of(context);
                          Navigator.pop(context);
                          if (token != null && token.isNotEmpty) {
                            router.go('/parent-review?token=$token');
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: Text('Open Review Form',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
                // Messages tab
                Column(children: [
                  Expanded(
                    child: _msgLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                            ? Center(
                                child: Text(
                                  'No messages yet.\nStart a conversation with the teacher.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: AppTheme.grey500),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (_, i) => _MessageBubble(msg: _messages[i]),
                              ),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      left: 16, right: 8, top: 8,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.grey200)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Message the teacher...',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 13, color: AppTheme.grey400),
                            filled: true,
                            fillColor: AppTheme.grey50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sending ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppTheme.primary, shape: BoxShape.circle),
                          child: _sending
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Welcome Dialog ────────────────────────────────────────────

class _WelcomeDialog extends ConsumerStatefulWidget {
  final dynamic user;
  final List<_ChildInfo> children;
  final VoidCallback onSaved;
  const _WelcomeDialog({
    required this.user,
    required this.children,
    required this.onSaved,
  });
  @override
  ConsumerState<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends ConsumerState<_WelcomeDialog> {
  final _emailCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { Navigator.of(context).pop(); widget.onSaved(); return; }
    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateEmail(email);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name       = widget.user?.fullName as String? ?? '';
    final firstName  = name.isNotEmpty ? name.split(' ').first : 'there';

    // Collect all unique guardian entries from children
    // Group by type and deduplicate by phone
    final seen = <String>{};
    final guardians = <_Guardian>[];
    for (final child in widget.children) {
      for (final g in child.guardians) {
        final key = '${g.type}_${g.phone}';
        if (!seen.contains(key)) {
          seen.add(key);
          guardians.add(g);
        }
      }
    }
    // Sort: father, mother, guardian1, guardian2
    const order = ['father', 'mother', 'guardian1', 'guardian2'];
    guardians.sort((a, b) {
      final ai = order.indexOf(a.type);
      final bi = order.indexOf(b.type);
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header gradient
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.waving_hand, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Welcome, $firstName!',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Your details registered with the school',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Registered guardian info (read-only)
              if (guardians.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registered Contacts',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.grey600)),
                      const SizedBox(height: 10),
                      ...guardians.map((g) => _GuardianInfoTile(guardian: g)),
                    ],
                  ),
                ),
              ],

              // Email input
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Optional: Add Gmail for alternate login',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppTheme.grey600)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'you@gmail.com',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.grey400),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your name and phone cannot be changed here.\nContact school to update records.',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.grey400),
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () {
                        Navigator.of(context).pop();
                        widget.onSaved();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.grey600,
                        side: BorderSide(color: AppTheme.grey300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text('Skip',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 44),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Continue',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianInfoTile extends StatelessWidget {
  final _Guardian guardian;
  const _GuardianInfoTile({required this.guardian});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              guardian.type == 'mother' ? Icons.woman_outlined
                  : guardian.type == 'father' ? Icons.man_outlined
                  : Icons.person_outline,
              color: AppTheme.primary, size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_guardianLabel(guardian.type),
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.grey500)),
                if (guardian.name.isNotEmpty)
                  Text(guardian.name,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppTheme.grey900)),
                if (guardian.phone.isNotEmpty)
                  Text(guardian.phone,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.grey600)),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 14, color: AppTheme.grey400),
        ],
      ),
    );
  }
}

// ── Shared Helper Widgets ─────────────────────────────────────

class _SectionBar extends StatelessWidget {
  final String title;
  final IconData icon;
  final int? count;
  final Widget? trailing;
  const _SectionBar({required this.title, required this.icon,
      this.count, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 17, color: AppTheme.primary),
      const SizedBox(width: 7),
      Expanded(
        child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
      ),
      if (count != null && count! > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      if (trailing != null) trailing!,
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.grey900)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(children: [
          const Icon(Icons.child_care, size: 72, color: AppTheme.grey400),
          const SizedBox(height: 16),
          Text('No children linked yet',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.grey700)),
          const SizedBox(height: 8),
          Text(
            'Your phone number must match the student records.\nPlease contact the school if you believe this is an error.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500),
          ),
        ]),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTile({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.grey400),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
        ),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 12),
          Text('Could not load data', style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.error)),
          const SizedBox(height: 4),
          Text(message, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
