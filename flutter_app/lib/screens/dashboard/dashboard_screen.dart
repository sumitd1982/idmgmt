// ============================================================
// Dashboard Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:responsive_framework/responsive_framework.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import 'dashboard_overview.dart';

// ── Data Models ───────────────────────────────────────────────
class _DashboardStats {
  final int totalStudents;
  final int greenCount;
  final int blueCount;
  final int redCount;
  final int totalEmployees;
  final int totalBranches;
  final int totalSchools;

  const _DashboardStats({
    required this.totalStudents,
    required this.greenCount,
    required this.blueCount,
    required this.redCount,
    required this.totalEmployees,
    required this.totalBranches,
    required this.totalSchools,
  });

  factory _DashboardStats.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? j;
    return _DashboardStats(
      totalStudents:  (data['students']          as num?)?.toInt() ?? 0,
      greenCount:     (data['students_approved'] as num?)?.toInt() ?? 0,
      blueCount:      (data['students_changed']  as num?)?.toInt() ?? 0,
      redCount:       (data['students_pending']  as num?)?.toInt() ?? 0,
      totalEmployees: (data['employees']         as num?)?.toInt() ?? 0,
      totalBranches:  (data['branches']          as num?)?.toInt() ?? 0,
      totalSchools:   (data['schools']           as num?)?.toInt() ?? 0,
    );
  }

  factory _DashboardStats.empty() => const _DashboardStats(
        totalStudents:  0,
        greenCount:     0,
        blueCount:      0,
        redCount:       0,
        totalEmployees: 0,
        totalBranches:  0,
        totalSchools:   0,
      );
}

class _ReviewRequest {
  final String id;
  final String studentName;
  final String className;
  final String section;
  final String status;
  final DateTime createdAt;

  _ReviewRequest({
    required this.id,
    required this.studentName,
    required this.className,
    required this.section,
    required this.status,
    required this.createdAt,
  });

  factory _ReviewRequest.fromJson(Map<String, dynamic> j) => _ReviewRequest(
        id:          j['id'] as String,
        studentName: '${j['first_name'] ?? ''} ${j['last_name'] ?? ''}'.trim(),
        className:   j['class_name']  as String? ?? '',
        section:     j['section']     as String? ?? '',
        status:      j['status']      as String? ?? 'pending',
        createdAt:   DateTime.tryParse(j['submitted_at'] as String? ??
                     j['created_at']  as String? ?? '') ?? DateTime.now(),
      );
}

class _ClassChartData {
  final String label;
  final int green;
  final int blue;
  final int red;
  const _ClassChartData(this.label, this.green, this.blue, this.red);
}

// ── Providers ─────────────────────────────────────────────────
final _dashboardStatsProvider = FutureProvider<_DashboardStats>((ref) async {
  try {
    final data = await ApiService().get('/dashboard/stats');
    return _DashboardStats.fromJson(data);
  } catch (_) {
    return _DashboardStats.empty();
  }
});

final _recentRequestsProvider = FutureProvider<List<_ReviewRequest>>((ref) async {
  try {
    final data = await ApiService().get('/parent/reviews', params: {'status': 'parent_submitted'});
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => _ReviewRequest.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

final _classChartProvider = FutureProvider<List<_ClassChartData>>((ref) async {
  return _mockChartData;
});

// ── Workflow Summary Models ────────────────────────────────────
class _WfSummaryRequest {
  final String id;
  final String title;
  final String requestType;
  final String status;
  final int totalItems;
  final int pendingItems;
  final int completedItems;
  const _WfSummaryRequest({
    required this.id, required this.title, required this.requestType,
    required this.status, required this.totalItems,
    required this.pendingItems, required this.completedItems,
  });
  factory _WfSummaryRequest.fromJson(Map<String, dynamic> j) => _WfSummaryRequest(
    id:            j['id'] as String,
    title:         j['title'] as String? ?? '',
    requestType:   j['request_type'] as String? ?? 'student_info',
    status:        j['status'] as String? ?? 'draft',
    totalItems:    (j['total_items'] as num?)?.toInt() ?? 0,
    pendingItems:  (j['pending_items'] as num?)?.toInt() ?? 0,
    completedItems:(j['completed_items'] as num?)?.toInt() ?? 0,
  );
  double get pct => totalItems == 0 ? 0 : completedItems / totalItems;
}

class _WfClassStat {
  final String className;
  final String section;
  final Map<String, dynamic>? classTeacher;
  final int total, pending, sentToParent, parentSubmitted, approved, rejected;
  const _WfClassStat({
    required this.className, required this.section, this.classTeacher,
    required this.total, required this.pending, required this.sentToParent,
    required this.parentSubmitted, required this.approved, required this.rejected,
  });
  factory _WfClassStat.fromJson(Map<String, dynamic> j) {
    final s = (j['stats'] as Map<String, dynamic>?) ?? {};
    return _WfClassStat(
      className:       j['class_name'] as String? ?? '',
      section:         j['section']    as String? ?? '',
      classTeacher:    j['class_teacher'] as Map<String, dynamic>?,
      total:           (s['total']           as num?)?.toInt() ?? 0,
      pending:         (s['pending']         as num?)?.toInt() ?? 0,
      sentToParent:    (s['sent_to_parent']  as num?)?.toInt() ?? 0,
      parentSubmitted: (s['parent_submitted'] as num?)?.toInt() ?? 0,
      approved:        (s['approved']        as num?)?.toInt() ?? 0,
      rejected:        (s['rejected']        as num?)?.toInt() ?? 0,
    );
  }
}

final _activeWorkflowRequestsProvider = FutureProvider<List<_WfSummaryRequest>>((ref) async {
  try {
    final data = await ApiService().get('/workflow/requests', params: {'status': 'active'});
    final list = data['data'] as List<dynamic>? ?? [];
    // Also include in_progress requests
    final data2 = await ApiService().get('/workflow/requests', params: {'status': 'in_progress'});
    final list2 = data2['data'] as List<dynamic>? ?? [];
    final combined = [...list, ...list2];
    return combined.map((e) => _WfSummaryRequest.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

const _mockChartData = [
  _ClassChartData('Cls 1', 48, 12, 8),
  _ClassChartData('Cls 2', 55, 18, 10),
  _ClassChartData('Cls 3', 62, 22, 14),
  _ClassChartData('Cls 4', 71, 19, 11),
  _ClassChartData('Cls 5', 80, 25, 16),
  _ClassChartData('Cls 6', 68, 28, 20),
  _ClassChartData('Cls 7', 74, 30, 22),
  _ClassChartData('Cls 8', 59, 24, 18),
];

// ── Screen ────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _profileDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowProfileDialog());
  }

  void _maybeShowProfileDialog() {
    if (_profileDialogShown) return;
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user != null && (user.email == null || user.email!.isEmpty) && mounted) {
      _profileDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ProfileCompletionDialog(
          onSaved: () => ref.read(authNotifierProvider.notifier).refreshUser(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user      = authState.valueOrNull;
    final isWide    = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    // Show profile dialog if user's name was just loaded and is still empty
    if (!_profileDialogShown && user != null && (user.email == null || user.email!.isEmpty)) {
      _profileDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _ProfileCompletionDialog(
              onSaved: () => ref.read(authNotifierProvider.notifier).refreshUser(),
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardStatsProvider);
          ref.invalidate(_recentRequestsProvider);
          ref.invalidate(_classChartProvider);
          ref.invalidate(_activeWorkflowRequestsProvider);
          invalidateDashboardOverview(ref);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              _WelcomeHeader(user: user),
              const SizedBox(height: 24),

              // Stats row
              _StatsRow(),
              const SizedBox(height: 24),

              // Onboarding Guide (if no schools found) — hidden for parents
              if (user?.role != 'parent') ...[
                _OnboardingGuide(),
                const SizedBox(height: 24),
              ],

              // Main content
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              if (user?.role != 'parent') ...[
                                _QuickActions(),
                                const SizedBox(height: 20),
                              ],
                              _RecentRequestsTable(),
                              const SizedBox(height: 20),
                              _ClassChartCard(),
                              const SizedBox(height: 20),
                              DashboardOverviewComponent(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 300,
                          child: _NotificationFeed(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        if (user?.role != 'parent') ...[
                          _QuickActions(),
                          const SizedBox(height: 20),
                        ],
                        _RecentRequestsTable(),
                        const SizedBox(height: 20),
                        _ClassChartCard(),
                        const SizedBox(height: 20),
                        DashboardOverviewComponent(),
                        const SizedBox(height: 20),
                        _NotificationFeed(),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Welcome Header ────────────────────────────────────────────
class _WelcomeHeader extends StatelessWidget {
  final dynamic user;
  const _WelcomeHeader({this.user});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _displayName() {
    if (user == null) return 'there';
    final name = user.fullName;
    if (name.isNotEmpty) return name;
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, ${_displayName()} 👋',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Role: ${_formatRole(user?.role ?? "Administrator")}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.school, color: Colors.white24, size: 80),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  String _formatRole(String role) =>
      role.replaceAll('_', ' ').split(' ')
          .map((w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
}

// ── Stats Row ─────────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_dashboardStatsProvider);

    return statsAsync.when(
      loading: () => _StatsShimmer(),
      error:   (_, __) => const SizedBox.shrink(),
      data:    (stats) {
        final cards = [
          _StatCardData(
            label:    'Total Students',
            value:    stats.totalStudents,
            icon:     Icons.people,
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            ),
          ),
          _StatCardData(
            label:    'Verified (Green)',
            value:    stats.greenCount,
            icon:     Icons.check_circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
          ),
          _StatCardData(
            label:    'Changes Pending (Blue)',
            value:    stats.blueCount,
            icon:     Icons.sync,
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            ),
          ),
          _StatCardData(
            label:    'Not Responded (Red)',
            value:    stats.redCount,
            icon:     Icons.cancel,
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFFE53935)],
            ),
          ),
          _StatCardData(
            label:    'Employees',
            value:    stats.totalEmployees,
            icon:     Icons.badge,
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
            ),
          ),
          _StatCardData(
            label:    'Branches',
            value:    stats.totalBranches,
            icon:     Icons.account_tree,
            gradient: const LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF00897B)],
            ),
          ),
          if (ref.read(authNotifierProvider).valueOrNull?.role == 'super_admin')
            _StatCardData(
              label:    'Total Schools',
              value:    stats.totalSchools,
              icon:     Icons.home_work,
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFB8C00)],
              ),
            ),
        ];

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final crossCount = constraints.maxWidth > 900
                ? 6
                : constraints.maxWidth > 600
                    ? 3
                    : 2;
            return GridView.builder(
              shrinkWrap:  true,
              physics:     const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:  crossCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: cards.length,
              itemBuilder: (ctx, i) => _StatCard(data: cards[i], index: i),
            );
          },
        );
      },
    );
  }
}

class _StatCardData {
  final String label;
  final int value;
  final IconData icon;
  final Gradient gradient;
  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  final int index;
  const _StatCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: data.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: Colors.white54, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedCounter(value: data.value),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (index * 80).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.3, curve: Curves.easeOut);
  }
}

class _AnimatedCounter extends StatefulWidget {
  final int value;
  const _AnimatedCounter({required this.value});

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        NumberFormat.compact().format(_anim.value.toInt()),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.grey200,
          borderRadius: BorderRadius.circular(16),
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1200.ms,
            color: Colors.white30,
          ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────
class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickActionBtn(
                  label:  'Send Review Links',
                  icon:   Icons.send,
                  color:  AppTheme.primary,
                  onTap:  () {},
                ),
                _QuickActionBtn(
                  label:  'Bulk Upload',
                  icon:   Icons.upload_file,
                  color:  AppTheme.secondary,
                  onTap:  () => context.go('/students'),
                ),
                _QuickActionBtn(
                  label:  'Generate IDs',
                  icon:   Icons.badge,
                  color:  AppTheme.accent,
                  onTap:  () => context.go('/id-cards'),
                ),
                _QuickActionBtn(
                  label:  'View Reports',
                  icon:   Icons.bar_chart,
                  color:  AppTheme.success,
                  onTap:  () => context.go('/reports'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon:  Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 13)),
    );
  }
}

// ── Recent Requests Table ─────────────────────────────────────
class _RecentRequestsTable extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_recentRequestsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Recent Review Requests',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/requests'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            requestsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (requests) {
                if (requests.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No review requests yet',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.grey600),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
                    columns: [
                      DataColumn(label: Text('Student', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Class',   style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Status',  style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Time',    style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    ],
                    rows: requests.take(5).map((r) => DataRow(cells: [
                      DataCell(Text(r.studentName, style: GoogleFonts.poppins(fontSize: 13))),
                      DataCell(Text('${r.className} ${r.section}', style: GoogleFonts.poppins(fontSize: 13))),
                      DataCell(_StatusBadge(status: r.status)),
                      DataCell(Text(timeago.format(r.createdAt), style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600))),
                    ])).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

// ── Workflow Dashboard Card ────────────────────────────────────
class _WorkflowDashboardCard extends ConsumerWidget {
  const _WorkflowDashboardCard();

  bool _shouldShow(AppUser? user) {
    if (user == null) return false;
    return user.isAdmin || user.isPrincipal ||
        ['vice_principal', 'head_teacher', 'school_owner'].contains(user.role) ||
        (user.employee?.roleLevel ?? 0) >= 3;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (!_shouldShow(user)) return const SizedBox.shrink();

    final requestsAsync = ref.watch(_activeWorkflowRequestsProvider);

    return requestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Active Workflow Requests',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/workflow'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...requests.map((req) => _WfRequestRow(request: req)),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 450.ms, duration: 400.ms);
      },
    );
  }
}

class _WfRequestRow extends StatefulWidget {
  final _WfSummaryRequest request;
  const _WfRequestRow({required this.request});

  @override
  State<_WfRequestRow> createState() => _WfRequestRowState();
}

class _WfRequestRowState extends State<_WfRequestRow> {
  bool _expanded = false;
  List<_WfClassStat> _classStats = [];
  bool _loading = false;

  Future<void> _loadClassStats() async {
    if (_classStats.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService().get('/workflow/requests/${widget.request.id}/overview');
      final list = data['data'] as List<dynamic>? ?? [];
      setState(() {
        _classStats = list.map((e) => _WfClassStat.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color get _statusColor {
    switch (widget.request.status) {
      case 'completed':   return AppTheme.statusGreen;
      case 'in_progress': return AppTheme.statusBlue;
      case 'active':      return AppTheme.accent;
      case 'on_hold':     return AppTheme.warning;
      default:            return AppTheme.grey400;
    }
  }

  String get _statusLabel {
    switch (widget.request.status) {
      case 'completed':   return 'Completed';
      case 'in_progress': return 'In Progress';
      case 'active':      return 'Active';
      case 'on_hold':     return 'On Hold';
      default:            return 'Draft';
    }
  }

  IconData get _typeIcon {
    switch (widget.request.requestType) {
      case 'teacher_info': return Icons.badge_outlined;
      case 'document':     return Icons.folder_open_outlined;
      default:             return Icons.school_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // ── Request header row ──
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadClassStats();
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_typeIcon, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(req.title,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _statusColor.withOpacity(0.3)),
                        ),
                        child: Text(_statusLabel,
                            style: GoogleFonts.poppins(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16, color: AppTheme.grey500),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _DashWfPill('${req.totalItems} total',     AppTheme.grey500),
                      const SizedBox(width: 4),
                      _DashWfPill('${req.completedItems} done',  AppTheme.statusGreen),
                      const SizedBox(width: 4),
                      if (req.pendingItems > 0)
                        _DashWfPill('${req.pendingItems} pending', AppTheme.warning),
                      const Spacer(),
                      if (req.totalItems > 0)
                        SizedBox(
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: req.pct,
                              backgroundColor: AppTheme.grey100,
                              color: req.pct == 1.0 ? AppTheme.statusGreen : AppTheme.primary,
                              minHeight: 5,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text('${(req.pct * 100).round()}%',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded class-section table ──
          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.grey200)),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _classStats.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text('No class assignments found.',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
                        )
                      : Column(
                          children: [
                            // Table header
                            Container(
                              color: AppTheme.grey50,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(width: 90,  child: Text('Class/Sec', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.grey600))),
                                  Expanded(           child: Text('Teacher',   style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.grey600))),
                                  SizedBox(width: 42,  child: Text('Total',    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.grey600), textAlign: TextAlign.center)),
                                  SizedBox(width: 52,  child: Text('Verified', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.statusGreen), textAlign: TextAlign.center)),
                                  SizedBox(width: 56,  child: Text('Responded',style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.statusBlue), textAlign: TextAlign.center)),
                                  SizedBox(width: 52,  child: Text('Pending',  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.warning), textAlign: TextAlign.center)),
                                ],
                              ),
                            ),
                            ..._classStats.map((cs) {
                              final teacherName = (cs.classTeacher?['name'] as String?) ?? '—';
                              final responded   = cs.parentSubmitted + cs.sentToParent;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: const BoxDecoration(
                                  border: Border(top: BorderSide(color: AppTheme.grey100)),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text('${cs.className}–${cs.section}',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 11, color: AppTheme.grey400),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(teacherName,
                                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey700),
                                                maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 42, child: Text('${cs.total}',    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                                    SizedBox(width: 52, child: Text('${cs.approved}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.statusGreen), textAlign: TextAlign.center)),
                                    SizedBox(width: 56, child: Text('$responded',     style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.statusBlue), textAlign: TextAlign.center)),
                                    SizedBox(width: 52, child: Text('${cs.pending}',  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: cs.pending > 0 ? AppTheme.warning : AppTheme.grey400), textAlign: TextAlign.center)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
            ),
        ],
      ),
    );
  }
}

class _DashWfPill extends StatelessWidget {
  final String label;
  final Color color;
  const _DashWfPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = AppTheme.statusGreen;
        label = 'Approved';
        break;
      case 'parent_reviewed':
        color = AppTheme.statusBlue;
        label = 'Reviewed';
        break;
      default:
        color = AppTheme.statusRed;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Class Chart ───────────────────────────────────────────────
class _ClassChartCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(_classChartProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class-wise Review Status',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            // Legend
            Row(
              children: [
                _Legend(color: AppTheme.statusGreen, label: 'Verified'),
                const SizedBox(width: 16),
                _Legend(color: AppTheme.statusBlue, label: 'Changed'),
                const SizedBox(width: 16),
                _Legend(color: AppTheme.statusRed, label: 'Pending'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: chartAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (_, __) => const Center(child: Text('Failed to load chart')),
                data: (data) => BarChart(
                  BarChartData(
                    alignment:       BarChartAlignment.spaceAround,
                    maxY:            100,
                    barTouchData:    BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles:   AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= data.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(data[i].label,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10, color: AppTheme.grey600)),
                            );
                          },
                        ),
                      ),
                      topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData:    FlGridData(
                      drawHorizontalLine: true,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.grey200,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(data.length, (i) {
                      final d = data[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY:   d.green.toDouble(),
                            color: AppTheme.statusGreen,
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY:   d.blue.toDouble(),
                            color: AppTheme.statusBlue,
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY:   d.red.toDouble(),
                            color: AppTheme.statusRed,
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
      ],
    );
  }
}

// ── Notification Feed ─────────────────────────────────────────
class _NotificationFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No notifications yet',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.grey600),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }
}

// ── Onboarding Guide ──────────────────────────────────────────
class _OnboardingGuide extends ConsumerWidget {
  const _OnboardingGuide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_dashboardStatsProvider);
    
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        // Only show if user has no schools
        final user = ref.read(authNotifierProvider).valueOrNull;
        // Show if user has no schools OR if they are a school_owner with no branches yet
        if (stats.totalSchools > 0 && !(user?.isSchoolOwner ?? false && stats.totalBranches == 0)) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: AppTheme.primary.withOpacity(0.05),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.primary.withOpacity(0.1))),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Institution Setup Guide',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Follow these steps to get your institution management system up and running.',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey700),
                ),
                const SizedBox(height: 24),
                _OnboardingStep(
                  number: 1,
                  title: 'Create Your School',
                  subtitle: 'Register your main institution details, logo, and banner.',
                  icon: Icons.school_outlined,
                  isDone: stats.totalSchools > 0,
                  onTap: () => context.go('/schools/new'),
                ),
                _OnboardingStep(
                  number: 2,
                  title: 'Add Branches',
                  subtitle: 'Define your campuses or distinct units (if any).',
                  icon: Icons.account_tree_outlined,
                  isDone: stats.totalBranches > 0,
                  onTap: () => context.go('/branches'),
                ),
                _OnboardingStep(
                  number: 3,
                  title: 'Define Organization Structure',
                  subtitle: 'Set up hierarchy and roles (Principal, Teachers).',
                  icon: Icons.hub_outlined,
                  isDone: false, 
                  onTap: () => context.go('/org-structure'),
                ),
                _OnboardingStep(
                  number: 4,
                  title: 'Onboard Staff & Students',
                  subtitle: 'Perform bulk uploads or add individual records.',
                  icon: Icons.people_outline,
                  isDone: stats.totalEmployees > 0,
                  onTap: () => context.go('/employees'),
                ),
              ],
            ),
          ),
        ).animate().fadeIn().slideY(begin: 0.1);
      },
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;
  final VoidCallback onTap;

  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDone ? AppTheme.statusGreen.withOpacity(0.3) : AppTheme.grey200),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.statusGreen.withOpacity(0.1) : AppTheme.grey100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check : icon,
                  color: isDone ? AppTheme.statusGreen : AppTheme.grey600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone ? '$title ✅' : title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDone ? AppTheme.grey600 : AppTheme.grey900),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.grey300),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Completion Dialog ──────────────────────────────────
class _ProfileCompletionDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _ProfileCompletionDialog({required this.onSaved});

  @override
  ConsumerState<_ProfileCompletionDialog> createState() =>
      _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState
    extends ConsumerState<_ProfileCompletionDialog> {
  final _emailCtrl = TextEditingController();
  bool _saving     = false;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(authNotifierProvider).valueOrNull;
    final name  = user?.fullName ?? '';
    final first = name.isNotEmpty ? name.split(' ').first : 'there';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, $first! 🎉',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            'Your profile is managed by school records.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Name — read-only
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: AppTheme.grey400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name.isNotEmpty ? name : 'Name from school records',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Name is managed by your school.',
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400)),
            const SizedBox(height: 16),
            // Email — editable
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Gmail / Email (optional)',
                labelStyle: GoogleFonts.poppins(fontSize: 13),
                hintText: 'you@gmail.com',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                helperText: 'Add Gmail for an alternative way to sign in',
                helperStyle: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey500),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () { Navigator.of(context).pop(); widget.onSaved(); },
          child: Text('Skip for now',
              style: GoogleFonts.poppins(color: AppTheme.grey500)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  const _Field({required this.controller, required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: GoogleFonts.poppins(fontSize: 13),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

