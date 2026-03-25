// ============================================================
// Dashboard Overview Component
// Role-aware: school / branch / teacher / parent
// Tabs: Students & Staff | Workflow Requests
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────

class DashTotals {
  final int students;
  final int employees;
  final int branches;
  const DashTotals({
    required this.students,
    required this.employees,
    required this.branches,
  });
  factory DashTotals.fromJson(Map<String, dynamic> j) => DashTotals(
        students:  (j['students']  as num?)?.toInt() ?? 0,
        employees: (j['employees'] as num?)?.toInt() ?? 0,
        branches:  (j['branches']  as num?)?.toInt() ?? 0,
      );
  static const empty = DashTotals(students: 0, employees: 0, branches: 0);
}

class DashSection {
  final String className;
  final String section;
  final int studentCount;
  final String? teacherName;
  final String? teacherPhoto;
  final String? classTeacherId;
  final String? branchName;
  const DashSection({
    required this.className,
    required this.section,
    required this.studentCount,
    this.teacherName,
    this.teacherPhoto,
    this.classTeacherId,
    this.branchName,
  });
  factory DashSection.fromJson(Map<String, dynamic> j) => DashSection(
        className:      j['class_name']       as String? ?? '',
        section:        j['section']          as String? ?? '',
        studentCount:   (j['student_count']   as num?)?.toInt() ?? 0,
        teacherName:    j['teacher_name']     as String?,
        teacherPhoto:   j['teacher_photo']    as String?,
        classTeacherId: j['class_teacher_id'] as String?,
        branchName:     j['branch_name']      as String?,
      );
}

class DashBranch {
  final String id;
  final String name;
  final DashTotals totals;
  final List<DashSection> sections;
  const DashBranch({
    required this.id,
    required this.name,
    required this.totals,
    required this.sections,
  });
  factory DashBranch.fromJson(Map<String, dynamic> j) => DashBranch(
        id:       j['id']   as String? ?? '',
        name:     j['name'] as String? ?? '',
        totals:   DashTotals.fromJson(j['totals'] as Map<String, dynamic>? ?? {}),
        sections: (j['sections'] as List<dynamic>? ?? [])
            .map((s) => DashSection.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class DashChild {
  final String id;
  final String firstName;
  final String lastName;
  final String className;
  final String section;
  final String branchName;
  const DashChild({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.className,
    required this.section,
    required this.branchName,
  });
  factory DashChild.fromJson(Map<String, dynamic> j) => DashChild(
        id:         j['id']          as String? ?? '',
        firstName:  j['first_name']  as String? ?? '',
        lastName:   j['last_name']   as String? ?? '',
        className:  j['class_name']  as String? ?? '',
        section:    j['section']     as String? ?? '',
        branchName: j['branch_name'] as String? ?? '',
      );
  String get fullName => '$firstName $lastName'.trim();
}

class DashOverviewResult {
  final String scope;
  final bool showTeacherNames;
  final DashTotals totals;
  final List<DashBranch> branches;
  final List<DashSection> sections;
  final List<DashChild> children;
  const DashOverviewResult({
    required this.scope,
    required this.showTeacherNames,
    required this.totals,
    this.branches = const [],
    this.sections = const [],
    this.children = const [],
  });
  factory DashOverviewResult.fromJson(Map<String, dynamic> j) {
    final d = j['data'] as Map<String, dynamic>? ?? j;
    return DashOverviewResult(
      scope:            d['scope']              as String? ?? 'school',
      showTeacherNames: d['show_teacher_names'] as bool? ?? true,
      totals:           DashTotals.fromJson(d['totals'] as Map<String, dynamic>? ?? {}),
      branches:         (d['branches'] as List<dynamic>? ?? [])
          .map((b) => DashBranch.fromJson(b as Map<String, dynamic>))
          .toList(),
      sections:         (d['sections'] as List<dynamic>? ?? [])
          .map((s) => DashSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      children:         (d['children'] as List<dynamic>? ?? [])
          .map((c) => DashChild.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Workflow models

class WfStatCounts {
  final int total;
  final int notStarted;
  final int notResponded;
  final int inProgress;
  final int completed;
  const WfStatCounts({
    required this.total,
    required this.notStarted,
    required this.notResponded,
    required this.inProgress,
    required this.completed,
  });
  factory WfStatCounts.fromJson(Map<String, dynamic> j) => WfStatCounts(
        total:        (j['total']         as num?)?.toInt() ?? 0,
        notStarted:   (j['not_started']   as num?)?.toInt() ?? 0,
        notResponded: (j['not_responded'] as num?)?.toInt() ?? 0,
        inProgress:   (j['in_progress']   as num?)?.toInt() ?? 0,
        completed:    (j['completed']     as num?)?.toInt() ?? 0,
      );
  static const empty = WfStatCounts(
    total: 0, notStarted: 0, notResponded: 0, inProgress: 0, completed: 0,
  );
  double get pct => total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
}

class WfSectionStat {
  final String className;
  final String section;
  final String? teacherName;
  final WfStatCounts counts;
  const WfSectionStat({
    required this.className,
    required this.section,
    this.teacherName,
    required this.counts,
  });
  factory WfSectionStat.fromJson(Map<String, dynamic> j) => WfSectionStat(
        className:   j['class_name']   as String? ?? '',
        section:     j['section']      as String? ?? '',
        teacherName: j['teacher_name'] as String?,
        counts:      WfStatCounts.fromJson(j),
      );
}

class WfBranchStat {
  final String id;
  final String name;
  final WfStatCounts totals;
  final List<WfSectionStat> sections;
  const WfBranchStat({
    required this.id,
    required this.name,
    required this.totals,
    required this.sections,
  });
  factory WfBranchStat.fromJson(Map<String, dynamic> j) => WfBranchStat(
        id:       j['id']   as String? ?? '',
        name:     j['name'] as String? ?? '',
        totals:   WfStatCounts.fromJson(j['totals'] as Map<String, dynamic>? ?? {}),
        sections: (j['sections'] as List<dynamic>? ?? [])
            .map((s) => WfSectionStat.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class WfChildStat {
  final String studentId;
  final String studentName;
  final String status;
  const WfChildStat({
    required this.studentId,
    required this.studentName,
    required this.status,
  });
  factory WfChildStat.fromJson(Map<String, dynamic> j) => WfChildStat(
        studentId:   j['student_id']   as String? ?? '',
        studentName: j['student_name'] as String? ?? '',
        status:      j['status']       as String? ?? 'pending',
      );
}

class WfRequestStat {
  final String id;
  final String title;
  final String requestType;
  final String status;
  final WfStatCounts totals;
  final List<WfBranchStat> branches;
  final List<WfSectionStat> sections;
  final List<WfChildStat> children;
  const WfRequestStat({
    required this.id,
    required this.title,
    required this.requestType,
    required this.status,
    required this.totals,
    this.branches = const [],
    this.sections = const [],
    this.children = const [],
  });
  factory WfRequestStat.fromJson(Map<String, dynamic> j) => WfRequestStat(
        id:          j['id']           as String? ?? '',
        title:       j['title']        as String? ?? '',
        requestType: j['request_type'] as String? ?? 'student_info',
        status:      j['status']       as String? ?? 'active',
        totals:      WfStatCounts.fromJson(j['totals'] as Map<String, dynamic>? ?? {}),
        branches:    (j['branches'] as List<dynamic>? ?? [])
            .map((b) => WfBranchStat.fromJson(b as Map<String, dynamic>))
            .toList(),
        sections:    (j['sections'] as List<dynamic>? ?? [])
            .map((s) => WfSectionStat.fromJson(s as Map<String, dynamic>))
            .toList(),
        children:    (j['children'] as List<dynamic>? ?? [])
            .map((c) => WfChildStat.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class WfOverviewResult {
  final String scope;
  final List<WfRequestStat> requests;
  const WfOverviewResult({required this.scope, required this.requests});
  factory WfOverviewResult.fromJson(Map<String, dynamic> j) {
    final d = j['data'] as Map<String, dynamic>? ?? j;
    return WfOverviewResult(
      scope:    d['scope']    as String? ?? 'school',
      requests: (d['requests'] as List<dynamic>? ?? [])
          .map((r) => WfRequestStat.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

final _dashOverviewProvider = FutureProvider<DashOverviewResult>((ref) async {
  final data = await ApiService().get('/dashboard/overview');
  return DashOverviewResult.fromJson(data);
});

final _wfOverviewProvider = FutureProvider<WfOverviewResult>((ref) async {
  final data = await ApiService().get('/dashboard/workflow-overview');
  return WfOverviewResult.fromJson(data);
});

/// Refresh both dashboard overview providers
void invalidateDashboardOverview(WidgetRef ref) {
  ref.invalidate(_dashOverviewProvider);
  ref.invalidate(_wfOverviewProvider);
}

// Local UI overrides — backend value is the source of truth on load
final _showTeacherNamesProvider = StateProvider<bool>((ref) => true);
final _sortByProvider           = StateProvider<String>((ref) => 'class');
// 'class' | 'students' | 'teacher'

// ─────────────────────────────────────────────────────────────
// Entry Widget
// ─────────────────────────────────────────────────────────────

class DashboardOverviewComponent extends ConsumerStatefulWidget {
  const DashboardOverviewComponent({super.key});

  @override
  ConsumerState<DashboardOverviewComponent> createState() =>
      _DashboardOverviewComponentState();
}

class _DashboardOverviewComponentState
    extends ConsumerState<DashboardOverviewComponent>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _savingTeacherSetting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(_dashOverviewProvider);
    ref.invalidate(_wfOverviewProvider);
  }

  // Sync backend show_teacher_names when data first loads
  void _syncTeacherSetting(bool value) {
    if (ref.read(_showTeacherNamesProvider) != value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_showTeacherNamesProvider.notifier).state = value;
      });
    }
  }

  Future<void> _toggleTeacherNames(bool show) async {
    ref.read(_showTeacherNamesProvider.notifier).state = show;
    // Persist to backend (best-effort)
    setState(() => _savingTeacherSetting = true);
    try {
      await ApiService().patch(
        '/dashboard/settings',
        body: {'show_teacher_names': show},
      );
    } catch (_) {
      // Not critical — local state already updated
    } finally {
      if (mounted) setState(() => _savingTeacherSetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync backend setting on initial load
    ref.listen(_dashOverviewProvider, (_, next) {
      next.whenData((r) => _syncTeacherSetting(r.showTeacherNames));
    });

    final showTeachers = ref.watch(_showTeacherNamesProvider);
    final sortBy       = ref.watch(_sortByProvider);

    // Role check — only admins/principals can toggle
    final user  = ref.watch(authNotifierProvider).valueOrNull;
    final level = user?.employee?.roleLevel ?? 99;
    final canToggleTeacher = user?.role == 'super_admin' || level <= 3;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.grey200)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dashboard_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'School Overview',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const Spacer(),
                    // Sort
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sortBy,
                        isDense: true,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey700),
                        items: const [
                          DropdownMenuItem(value: 'class',    child: Text('By Class')),
                          DropdownMenuItem(value: 'students', child: Text('By Students')),
                          DropdownMenuItem(value: 'teacher',  child: Text('By Teacher')),
                        ],
                        onChanged: (v) {
                          if (v != null) ref.read(_sortByProvider.notifier).state = v;
                        },
                      ),
                    ),
                    // Teacher name toggle (admin only)
                    if (canToggleTeacher)
                      Tooltip(
                        message: showTeachers ? 'Hide teacher names' : 'Show teacher names',
                        child: _savingTeacherSetting
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  showTeachers ? Icons.visibility : Icons.visibility_off,
                                  size: 18,
                                  color: showTeachers ? AppTheme.primaryLight : AppTheme.grey400,
                                ),
                                onPressed: () => _toggleTeacherNames(!showTeachers),
                              ),
                      ),
                    // Refresh
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppTheme.grey500),
                      onPressed: _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppTheme.primaryLight,
                  labelColor: AppTheme.primaryLight,
                  unselectedLabelColor: AppTheme.grey500,
                  labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Students & Staff'),
                    Tab(text: 'Workflow Requests'),
                  ],
                ),
              ],
            ),
          ),
          // Tabs
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (context, _) => IndexedStack(
              index: _tabCtrl.index,
              children: const [
                _OverviewSection(),
                _WorkflowSection(),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 450.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────
// Section A: Students & Staff
// ─────────────────────────────────────────────────────────────

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_dashOverviewProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: asyncData.when(
        loading: () => const _LoadingShimmer(),
        error:   (e, _) => _ErrorRetry(
          message: 'Failed to load overview',
          onRetry: () => ref.invalidate(_dashOverviewProvider),
        ),
        data: (result) {
          Widget content;
          switch (result.scope) {
            case 'school':
              content = _SchoolOverview(result: result);
              break;
            case 'branch':
              content = _BranchOverview(result: result);
              break;
            case 'teacher':
              content = _TeacherOverview(result: result);
              break;
            case 'parent':
              content = _ParentChildCards(result: result);
              break;
            default:
              content = const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.scope != 'parent') ...[
                _TotalsBar(totals: result.totals, scope: result.scope),
                const SizedBox(height: 16),
              ],
              content,
            ],
          );
        },
      ),
    );
  }
}

// Totals bar

class _TotalsBar extends StatelessWidget {
  final DashTotals totals;
  final String scope;
  const _TotalsBar({required this.totals, required this.scope});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatPill(label: 'Students',  count: totals.students,  color: AppTheme.primaryLight),
        if (totals.employees > 0)
          _StatPill(label: 'Staff',   count: totals.employees, color: AppTheme.success),
        if (scope == 'school' && totals.branches > 0)
          _StatPill(label: 'Branches', count: totals.branches, color: AppTheme.secondary),
      ],
    );
  }
}

// School scope — branch accordion

class _SchoolOverview extends ConsumerStatefulWidget {
  final DashOverviewResult result;
  const _SchoolOverview({required this.result});

  @override
  ConsumerState<_SchoolOverview> createState() => _SchoolOverviewState();
}

class _SchoolOverviewState extends ConsumerState<_SchoolOverview> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final showTeachers = ref.watch(_showTeacherNamesProvider);
    final sortBy       = ref.watch(_sortByProvider);

    if (widget.result.branches.isEmpty) {
      return _EmptyState(message: 'No branches found');
    }

    return Column(
      children: widget.result.branches.map((branch) {
        final isExpanded = _expanded.contains(branch.id);
        final sortedSections = _sortSections(branch.sections, sortBy);
        return _BranchAccordion(
          branchName:  branch.name,
          branchId:    branch.id,
          students:    branch.totals.students,
          employees:   branch.totals.employees,
          isExpanded:  isExpanded,
          onToggle:    () => setState(() => isExpanded
              ? _expanded.remove(branch.id)
              : _expanded.add(branch.id)),
          child: _SectionTable(sections: sortedSections, showTeachers: showTeachers),
        );
      }).toList(),
    );
  }
}

// Branch scope

class _BranchOverview extends ConsumerWidget {
  final DashOverviewResult result;
  const _BranchOverview({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTeachers = ref.watch(_showTeacherNamesProvider);
    final sortBy       = ref.watch(_sortByProvider);
    final sorted       = _sortSections(result.sections, sortBy);

    if (result.sections.isEmpty) return _EmptyState(message: 'No sections found');
    return _SectionTable(sections: sorted, showTeachers: showTeachers);
  }
}

// Teacher scope

class _TeacherOverview extends ConsumerWidget {
  final DashOverviewResult result;
  const _TeacherOverview({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTeachers = ref.watch(_showTeacherNamesProvider);
    final sortBy       = ref.watch(_sortByProvider);
    final sorted       = _sortSections(result.sections, sortBy);

    if (result.sections.isEmpty) return _EmptyState(message: 'No classes assigned');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columnSpacing: 20,
        columns: [
          DataColumn(label: _ColHeader('Class')),
          DataColumn(label: _ColHeader('Sec.')),
          DataColumn(label: _ColHeader('Branch')),
          DataColumn(label: _ColHeader('Students'), numeric: true),
          if (showTeachers) DataColumn(label: _ColHeader('My Role')),
        ],
        rows: sorted.map((s) {
          final user    = ref.read(authNotifierProvider).valueOrNull;
          final empId   = user?.employee?.id;
          final isMyClass = s.classTeacherId == empId;
          return DataRow(cells: [
            DataCell(Text(s.className,         style: _cellStyle())),
            DataCell(Text(s.section,           style: _cellStyle())),
            DataCell(Text(s.branchName ?? '—', style: _cellStyle())),
            DataCell(Text('${s.studentCount}', style: _cellStyle())),
            if (showTeachers)
              DataCell(_RoleBadge(isClassTeacher: isMyClass)),
          ]);
        }).toList(),
      ),
    );
  }
}

// Parent scope

class _ParentChildCards extends StatelessWidget {
  final DashOverviewResult result;
  const _ParentChildCards({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.children.isEmpty) {
      return _EmptyState(message: 'No children linked to your account');
    }
    return Column(
      children: result.children.asMap().entries.map((entry) {
        final child = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.grey200),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.grey50,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Class ${child.className} – ${child.section}  •  ${child.branchName}',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: (entry.key * 60).ms).fadeIn(duration: 300.ms);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section B: Workflow Requests
// ─────────────────────────────────────────────────────────────

class _WorkflowSection extends ConsumerWidget {
  const _WorkflowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_wfOverviewProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: asyncData.when(
        loading: () => const _LoadingShimmer(),
        error:   (e, _) => _ErrorRetry(
          message: 'Failed to load workflow data',
          onRetry: () => ref.invalidate(_wfOverviewProvider),
        ),
        data: (result) {
          if (result.requests.isEmpty) {
            return _EmptyState(message: 'No workflow requests found');
          }
          return Column(
            children: result.requests.asMap().entries.map((e) => _WfRequestCard(
              request: e.value,
              scope:   result.scope,
              index:   e.key,
            )).toList(),
          );
        },
      ),
    );
  }
}

class _WfRequestCard extends StatefulWidget {
  final WfRequestStat request;
  final String scope;
  final int index;
  const _WfRequestCard({
    required this.request,
    required this.scope,
    required this.index,
  });

  @override
  State<_WfRequestCard> createState() => _WfRequestCardState();
}

class _WfRequestCardState extends State<_WfRequestCard> {
  bool _expanded = false;

  Color get _typeColor {
    switch (widget.request.requestType) {
      case 'teacher_info': return AppTheme.accent;
      case 'document':     return AppTheme.warning;
      default:             return AppTheme.primary;
    }
  }

  String get _typeLabel {
    switch (widget.request.requestType) {
      case 'teacher_info': return 'Teacher';
      case 'document':     return 'Document';
      default:             return 'Student';
    }
  }

  Color get _statusColor {
    switch (widget.request.status) {
      case 'completed':   return AppTheme.statusGreen;
      case 'in_progress': return AppTheme.warning;
      case 'active':      return AppTheme.primaryLight;
      default:            return AppTheme.grey500;
    }
  }

  String get _statusLabel {
    switch (widget.request.status) {
      case 'completed':   return 'Completed';
      case 'in_progress': return 'In Progress';
      case 'active':      return 'Active';
      case 'draft':       return 'Draft';
      default:            return widget.request.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.request.totals;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeBadge(label: _typeLabel, color: _typeColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.request.title,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeBadge(label: _statusLabel, color: _statusColor),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppTheme.grey500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stat pills row
                  _WfStatPillsRow(counts: t),
                  const SizedBox(height: 10),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: t.pct,
                          minHeight: 6,
                          backgroundColor: AppTheme.grey200,
                          color: t.pct >= 1.0 ? AppTheme.statusGreen : AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${t.completed} of ${t.total} completed',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500),
                          ),
                          Text(
                            '${(t.pct * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppTheme.grey700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded breakdown
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.grey200)),
              ),
              child: _WfRequestDetail(request: widget.request, scope: widget.scope),
            ),
          ),
        ],
      ),
    ).animate(delay: (widget.index * 60).ms).fadeIn(duration: 300.ms);
  }
}

class _WfRequestDetail extends StatefulWidget {
  final WfRequestStat request;
  final String scope;
  const _WfRequestDetail({required this.request, required this.scope});

  @override
  State<_WfRequestDetail> createState() => _WfRequestDetailState();
}

class _WfRequestDetailState extends State<_WfRequestDetail> {
  final Set<String> _expandedBranches = {};

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    // Parent: per-child status cards
    if (widget.scope == 'parent') {
      return _ParentWfDetail(children: req.children);
    }

    // School: branch accordion → sections table
    if (widget.scope == 'school' && req.branches.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // School-wide totals bar
            _WfStatPillsRow(counts: req.totals, compact: true),
            const SizedBox(height: 10),
            ...req.branches.map((b) {
              final isExp = _expandedBranches.contains(b.id);
              return _BranchAccordion(
                branchName: b.name,
                branchId:   b.id,
                students:   b.totals.total,
                employees:  0,
                isExpanded: isExp,
                isWorkflow: true,
                wfCounts:   b.totals,
                onToggle:   () => setState(() => isExp
                    ? _expandedBranches.remove(b.id)
                    : _expandedBranches.add(b.id)),
                child: _WfSectionTable(sections: b.sections),
              );
            }),
          ],
        ),
      );
    }

    // Branch / Teacher: flat sections table
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WfStatPillsRow(counts: req.totals, compact: true),
          const SizedBox(height: 10),
          _WfSectionTable(sections: req.sections),
        ],
      ),
    );
  }
}

class _WfStatPillsRow extends StatelessWidget {
  final WfStatCounts counts;
  final bool compact;
  const _WfStatPillsRow({required this.counts, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatPill(label: 'Total',       count: counts.total,        color: AppTheme.grey600,         compact: true),
        _StatPill(label: 'Not Started', count: counts.notStarted,   color: AppTheme.grey500,         compact: true),
        _StatPill(label: 'No Response', count: counts.notResponded, color: const Color(0xFF6A1B9A),  compact: true),
        _StatPill(label: 'In Progress', count: counts.inProgress,   color: AppTheme.warning,         compact: true),
        _StatPill(label: 'Done',        count: counts.completed,    color: AppTheme.statusGreen,     compact: true),
      ],
    );
  }
}

class _WfSectionTable extends StatelessWidget {
  final List<WfSectionStat> sections;
  const _WfSectionTable({required this.sections});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _EmptyState(message: 'No sections'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
        dataRowMinHeight: 34,
        dataRowMaxHeight: 44,
        columnSpacing: 14,
        columns: [
          DataColumn(label: _ColHeader('Class')),
          DataColumn(label: _ColHeader('Sec.')),
          DataColumn(label: _ColHeader('Teacher')),
          DataColumn(label: _ColHeader('NS'),   numeric: true),
          DataColumn(label: _ColHeader('NR'),   numeric: true),
          DataColumn(label: _ColHeader('IP'),   numeric: true),
          DataColumn(label: _ColHeader('Done'), numeric: true),
        ],
        rows: sections.map((s) => DataRow(cells: [
          DataCell(Text(s.className,              style: _cellStyle())),
          DataCell(Text(s.section,                style: _cellStyle())),
          DataCell(Text(s.teacherName ?? '—',     style: _cellStyle())),
          DataCell(_CountCell(count: s.counts.notStarted,   color: AppTheme.grey500)),
          DataCell(_CountCell(count: s.counts.notResponded, color: const Color(0xFF6A1B9A))),
          DataCell(_CountCell(count: s.counts.inProgress,   color: AppTheme.warning)),
          DataCell(_CountCell(count: s.counts.completed,    color: AppTheme.statusGreen)),
        ])).toList(),
      ),
    );
  }
}

// Parent workflow: per-child status

class _ParentWfDetail extends StatelessWidget {
  final List<WfChildStat> children;
  const _ParentWfDetail({required this.children});

  String _friendlyStatus(String status) {
    switch (status) {
      case 'pending':              return 'Waiting — not started yet';
      case 'sent_to_parent':       return 'Action Required — please respond';
      case 'parent_submitted':     return 'Submitted — under review';
      case 'teacher_under_review': return 'Teacher is reviewing';
      case 'resubmit_requested':   return 'Revision needed — please resubmit';
      case 'approved':             return 'Approved';
      case 'rejected':             return 'Rejected';
      default:                     return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':             return AppTheme.statusGreen;
      case 'rejected':             return AppTheme.statusRed;
      case 'sent_to_parent':       return const Color(0xFF6A1B9A);
      case 'parent_submitted':
      case 'teacher_under_review':
      case 'resubmit_requested':   return AppTheme.warning;
      default:                     return AppTheme.grey500;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':             return Icons.check_circle;
      case 'rejected':             return Icons.cancel;
      case 'sent_to_parent':       return Icons.notification_important;
      case 'parent_submitted':     return Icons.hourglass_bottom;
      case 'resubmit_requested':   return Icons.replay;
      default:                     return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _EmptyState(message: 'No items for your children'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final c     = entry.value;
          final color = _statusColor(c.status);
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              border: Border.all(color: color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(c.status), color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.studentName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      Text(
                        _friendlyStatus(c.status),
                        style: GoogleFonts.poppins(fontSize: 11, color: color),
                      ),
                    ],
                  ),
                ),
                if (c.status == 'sent_to_parent')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Action Required',
                      style: GoogleFonts.poppins(
                          fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ).animate(delay: (entry.key * 40).ms).fadeIn(duration: 200.ms);
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared UI Components
// ─────────────────────────────────────────────────────────────

// Branch accordion used by both overview and workflow tabs

class _BranchAccordion extends StatelessWidget {
  final String branchId;
  final String branchName;
  final int students;
  final int employees;
  final bool isExpanded;
  final bool isWorkflow;
  final WfStatCounts? wfCounts;
  final VoidCallback onToggle;
  final Widget child;

  const _BranchAccordion({
    required this.branchId,
    required this.branchName,
    required this.students,
    required this.employees,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.isWorkflow = false,
    this.wfCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(9))
                    : BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      branchName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  if (isWorkflow && wfCounts != null) ...[
                    _StatPill(label: 'Done',   count: wfCounts!.completed,    color: AppTheme.statusGreen,    compact: true),
                    const SizedBox(width: 4),
                    _StatPill(label: 'IP',     count: wfCounts!.inProgress,   color: AppTheme.warning,        compact: true),
                    const SizedBox(width: 4),
                    _StatPill(label: 'Pending',count: wfCounts!.notStarted + wfCounts!.notResponded,
                        color: AppTheme.grey500, compact: true),
                  ] else ...[
                    _StatPill(label: 'Students', count: students,  color: AppTheme.primaryLight, compact: true),
                    if (employees > 0) ...[
                      const SizedBox(width: 6),
                      _StatPill(label: 'Staff', count: employees,  color: AppTheme.success,      compact: true),
                    ],
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.grey500,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: child,
          ),
        ],
      ),
    );
  }
}

// Section table for students & staff overview

class _SectionTable extends StatelessWidget {
  final List<DashSection> sections;
  final bool showTeachers;
  const _SectionTable({required this.sections, required this.showTeachers});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _EmptyState(message: 'No sections'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columnSpacing: 20,
        columns: [
          DataColumn(label: _ColHeader('Class')),
          DataColumn(label: _ColHeader('Sec.')),
          DataColumn(label: _ColHeader('Students'), numeric: true),
          if (showTeachers) DataColumn(label: _ColHeader('Class Teacher')),
        ],
        rows: sections.map((s) => DataRow(cells: [
          DataCell(Text(s.className,         style: _cellStyle())),
          DataCell(Text(s.section,           style: _cellStyle())),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${s.studentCount}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppTheme.primaryLight, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (showTeachers)
            DataCell(
              s.teacherName != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.teacherPhoto != null)
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(s.teacherPhoto!),
                        )
                      else
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary.withOpacity(0.15),
                          child: Text(
                            s.teacherName![0].toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(s.teacherName!, style: _cellStyle()),
                    ],
                  )
                : Text('—', style: _cellStyle().copyWith(color: AppTheme.grey400)),
            ),
        ])).toList(),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isClassTeacher;
  const _RoleBadge({required this.isClassTeacher});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isClassTeacher
            ? AppTheme.primary.withOpacity(0.1)
            : AppTheme.grey100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isClassTeacher ? 'Class Teacher' : 'Subject Teacher',
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: isClassTeacher ? AppTheme.primary : AppTheme.grey600,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool compact;
  const _StatPill({
    required this.label,
    required this.count,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        compact ? '$count' : '$label: $count',
        style: GoogleFonts.poppins(
          fontSize: compact ? 10 : 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CountCell extends StatelessWidget {
  final int count;
  final Color color;
  const _CountCell({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Text('—', style: _cellStyle().copyWith(color: AppTheme.grey400));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: AppTheme.grey300),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey500)),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey500)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text('Retry', style: GoogleFonts.poppins(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.grey200,
            borderRadius: BorderRadius.circular(10),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white30),
      ),
    );
  }
}

Widget _ColHeader(String label) => Text(
      label,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
    );

TextStyle _cellStyle() => GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800);

// ─────────────────────────────────────────────────────────────
// Sort helper
// ─────────────────────────────────────────────────────────────

List<DashSection> _sortSections(List<DashSection> sections, String sortBy) {
  final list = List<DashSection>.from(sections);
  switch (sortBy) {
    case 'students':
      list.sort((a, b) => b.studentCount.compareTo(a.studentCount));
      break;
    case 'teacher':
      list.sort((a, b) => (a.teacherName ?? '').compareTo(b.teacherName ?? ''));
      break;
    default: // 'class'
      list.sort((a, b) {
        final ca = int.tryParse(a.className.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final cb = int.tryParse(b.className.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final cmp = ca.compareTo(cb);
        if (cmp != 0) return cmp;
        final scmp = a.className.compareTo(b.className);
        if (scmp != 0) return scmp;
        return a.section.compareTo(b.section);
      });
  }
  return list;
}
