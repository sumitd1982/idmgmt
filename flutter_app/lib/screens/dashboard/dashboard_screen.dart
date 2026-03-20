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

// ── Data Models ───────────────────────────────────────────────
class _DashboardStats {
  final int totalStudents;
  final int greenCount;
  final int blueCount;
  final int redCount;
  final int totalEmployees;
  final int totalBranches;

  const _DashboardStats({
    required this.totalStudents,
    required this.greenCount,
    required this.blueCount,
    required this.redCount,
    required this.totalEmployees,
    required this.totalBranches,
  });

  factory _DashboardStats.fromJson(Map<String, dynamic> j) {
    // Backend returns { data: { totals: {...}, by_class: [...] } }
    final t = (j['data'] as Map<String, dynamic>?)?['totals'] as Map<String, dynamic>? ?? j;
    return _DashboardStats(
      totalStudents:  (t['total']           as num?)?.toInt() ?? 0,
      greenCount:     (t['approved']        as num?)?.toInt() ?? 0,
      blueCount:      (t['changes_pending'] as num?)?.toInt() ?? 0,
      redCount:       (t['not_responded']   as num?)?.toInt() ?? 0,
      totalEmployees: (j['total_employees'] as num?)?.toInt() ?? 0,
      totalBranches:  (j['total_branches']  as num?)?.toInt() ?? 0,
    );
  }

  factory _DashboardStats.mock() => const _DashboardStats(
        totalStudents:  1248,
        greenCount:     842,
        blueCount:      231,
        redCount:       175,
        totalEmployees: 64,
        totalBranches:  5,
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

class _Notification {
  final String message;
  final IconData icon;
  final Color color;
  final DateTime time;
  const _Notification(this.message, this.icon, this.color, this.time);
}

// ── Providers ─────────────────────────────────────────────────
final _dashboardStatsProvider = FutureProvider<_DashboardStats>((ref) async {
  try {
    final data = await ApiService().get('/reports/dashboard');
    return _DashboardStats.fromJson(data);
  } catch (_) {
    return _DashboardStats.mock();
  }
});

final _recentRequestsProvider = FutureProvider<List<_ReviewRequest>>((ref) async {
  try {
    final data = await ApiService().get('/parent/reviews', params: {'status': 'parent_submitted'});
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => _ReviewRequest.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return _mockRequests;
  }
});

final _classChartProvider = FutureProvider<List<_ClassChartData>>((ref) async {
  return _mockChartData;
});

// Mock requests — using non-const constructor so we can use real DateTime values
final _mockRequests = [
  _ReviewRequest(id: '1', studentName: 'Arjun Kumar',   className: 'Class 5', section: 'A', status: 'parent_reviewed', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
  _ReviewRequest(id: '2', studentName: 'Priya Sharma',  className: 'Class 3', section: 'B', status: 'pending',         createdAt: DateTime.now().subtract(const Duration(hours: 5))),
  _ReviewRequest(id: '3', studentName: 'Ravi Patel',    className: 'Class 7', section: 'A', status: 'approved',        createdAt: DateTime.now().subtract(const Duration(days: 1))),
  _ReviewRequest(id: '4', studentName: 'Sneha Reddy',   className: 'Class 2', section: 'C', status: 'pending',         createdAt: DateTime.now().subtract(const Duration(days: 2))),
  _ReviewRequest(id: '5', studentName: 'Mohan Singh',   className: 'Class 9', section: 'A', status: 'parent_reviewed', createdAt: DateTime.now().subtract(const Duration(days: 3))),
];

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
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user      = authState.valueOrNull;
    final isWide    = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardStatsProvider);
          ref.invalidate(_recentRequestsProvider);
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

              // Main content
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _QuickActions(),
                              const SizedBox(height: 20),
                              _RecentRequestsTable(),
                              const SizedBox(height: 20),
                              _ClassChartCard(),
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
                        _QuickActions(),
                        const SizedBox(height: 20),
                        _RecentRequestsTable(),
                        const SizedBox(height: 20),
                        _ClassChartCard(),
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
                  '${_greeting()}, ${user?.displayName ?? 'Admin'} 👋',
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
                    'Role: ${user?.role ?? 'Administrator'}',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
                columns: [
                  DataColumn(
                      label: Text('Student',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Class',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Status',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Time',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600))),
                ],
                rows: _mockRequestsData
                    .map((r) => DataRow(cells: [
                          DataCell(Text(r['name']!,
                              style: GoogleFonts.poppins(fontSize: 13))),
                          DataCell(Text(r['class']!,
                              style: GoogleFonts.poppins(fontSize: 13))),
                          DataCell(_StatusBadge(status: r['status']!)),
                          DataCell(Text(r['time']!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.grey600))),
                        ]))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

const _mockRequestsData = [
  {'name': 'Arjun Kumar',   'class': 'Class 5-A', 'status': 'parent_reviewed', 'time': '2 hrs ago'},
  {'name': 'Priya Sharma',  'class': 'Class 3-B', 'status': 'pending',         'time': '5 hrs ago'},
  {'name': 'Ravi Patel',    'class': 'Class 7-A', 'status': 'approved',        'time': '1 day ago'},
  {'name': 'Sneha Reddy',   'class': 'Class 2-C', 'status': 'pending',         'time': '2 days ago'},
  {'name': 'Mohan Singh',   'class': 'Class 9-A', 'status': 'parent_reviewed', 'time': '3 days ago'},
];

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
  static final _notifications = [
    _Notification('Arjun Kumar updated guardian info', Icons.person_outline,
        AppTheme.statusBlue, DateTime.now().subtract(const Duration(hours: 2))),
    _Notification('Bulk upload completed: 45 students added', Icons.upload,
        AppTheme.statusGreen, DateTime.now().subtract(const Duration(hours: 5))),
    _Notification('12 review links pending response', Icons.pending_actions,
        AppTheme.statusRed, DateTime.now().subtract(const Duration(hours: 8))),
    _Notification('ID Cards generated for Class 5-A', Icons.badge,
        AppTheme.statusGreen, DateTime.now().subtract(const Duration(days: 1))),
    _Notification('New branch "East Campus" added', Icons.account_tree,
        AppTheme.primary, DateTime.now().subtract(const Duration(days: 1, hours: 3))),
    _Notification('Priya Sharma photo updated', Icons.photo,
        AppTheme.statusBlue, DateTime.now().subtract(const Duration(days: 2))),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Notifications',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_notifications.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._notifications.asMap().entries.map((e) {
              final n = e.value;
              return _NotificationItem(notification: n, index: e.key);
            }),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }
}

class _NotificationItem extends StatelessWidget {
  final _Notification notification;
  final int index;
  const _NotificationItem({
    required this.notification,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: notification.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(notification.icon,
                color: notification.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.grey800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(notification.time),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 300.ms);
  }
}
