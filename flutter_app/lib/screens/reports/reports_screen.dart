// ============================================================
// Reports Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────
class _ReportSummary {
  final int total;
  final int green;
  final int blue;
  final int red;

  const _ReportSummary({
    required this.total,
    required this.green,
    required this.blue,
    required this.red,
  });

  double get greenPct => total > 0 ? green / total : 0;
  double get bluePct  => total > 0 ? blue  / total : 0;
  double get redPct   => total > 0 ? red   / total : 0;

  factory _ReportSummary.mock() => const _ReportSummary(
        total: 1248,
        green: 842,
        blue:  231,
        red:   175,
      );
}

class _ClassReport {
  final String className;
  final String section;
  final int green;
  final int blue;
  final int red;
  int get total => green + blue + red;

  const _ClassReport({
    required this.className,
    required this.section,
    required this.green,
    required this.blue,
    required this.red,
  });
}

class _TeacherReport {
  final String teacherName;
  final List<String> classes;
  final int green;
  final int blue;
  final int red;
  int get total => green + blue + red;

  const _TeacherReport({
    required this.teacherName,
    required this.classes,
    required this.green,
    required this.blue,
    required this.red,
  });
}

class _PendingReview {
  final String studentName;
  final String className;
  final String field;
  final String oldValue;
  final String newValue;
  final String submittedAt;

  const _PendingReview({
    required this.studentName,
    required this.className,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.submittedAt,
  });
}

class _LoginStatusReport {
  final int empTotal;
  final int empLinked;
  final int guardTotal;
  final int guardLinked;
  final List<Map<String, dynamic>> recentLogins;

  const _LoginStatusReport({
    required this.empTotal,
    required this.empLinked,
    required this.guardTotal,
    required this.guardLinked,
    required this.recentLogins,
  });
}

// ── Providers ─────────────────────────────────────────────────
final _reportSummaryProvider = FutureProvider<_ReportSummary>((ref) async {
  try {
    final d = await ApiService().get('/reports/dashboard');
    // Backend: { data: { totals: { total, approved, changes_pending, not_responded } } }
    final t = (d['data'] as Map<String, dynamic>?)?['totals'] as Map<String, dynamic>? ?? {};
    return _ReportSummary(
      total: (t['total']           as num?)?.toInt() ?? 0,
      green: (t['approved']        as num?)?.toInt() ?? 0,
      blue:  (t['changes_pending'] as num?)?.toInt() ?? 0,
      red:   (t['not_responded']   as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return _ReportSummary.mock();
  }
});

final _classReportProvider = FutureProvider<List<_ClassReport>>((ref) async {
  return _mockClassReports;
});

final _teacherReportProvider = FutureProvider<List<_TeacherReport>>((ref) async {
  return _mockTeacherReports;
});

final _pendingReviewsProvider = FutureProvider<List<_PendingReview>>((ref) async {
  return _mockPendingReviews;
});

final _loginStatusProvider = FutureProvider<_LoginStatusReport>((ref) async {
  try {
    final res = await ApiService().get('/reports/login-status');
    final data = res['data'] as Map<String, dynamic>;
    return _LoginStatusReport(
      empTotal:    (data['employees']['total'] as num).toInt(),
      empLinked:   (data['employees']['linked'] as num?)?.toInt() ?? 0,
      guardTotal:  (data['guardians']['total'] as num).toInt(),
      guardLinked: (data['guardians']['linked'] as num?)?.toInt() ?? 0,
      recentLogins: List<Map<String, dynamic>>.from(data['recent_logins'] ?? []),
    );
  } catch (_) {
    return const _LoginStatusReport(empTotal: 0, empLinked: 0, guardTotal: 0, guardLinked: 0, recentLogins: []);
  }
});

const _mockClassReports = [
  _ClassReport(className: 'Class 1', section: 'A', green: 28, blue: 4, red: 3),
  _ClassReport(className: 'Class 1', section: 'B', green: 26, blue: 5, red: 4),
  _ClassReport(className: 'Class 2', section: 'A', green: 30, blue: 8, red: 5),
  _ClassReport(className: 'Class 2', section: 'B', green: 27, blue: 6, red: 3),
  _ClassReport(className: 'Class 3', section: 'A', green: 32, blue: 9, red: 6),
  _ClassReport(className: 'Class 3', section: 'B', green: 29, blue: 7, red: 5),
  _ClassReport(className: 'Class 4', section: 'A', green: 35, blue: 10, red: 8),
  _ClassReport(className: 'Class 5', section: 'A', green: 38, blue: 12, red: 9),
];

const _mockTeacherReports = [
  _TeacherReport(teacherName: 'Mrs. Sunita Sharma',  classes: ['Class 1-A', 'Class 1-B'], green: 54, blue: 9,  red: 7),
  _TeacherReport(teacherName: 'Mr. Rajesh Kumar',    classes: ['Class 2-A', 'Class 2-B'], green: 57, blue: 14, red: 8),
  _TeacherReport(teacherName: 'Ms. Priya Nair',      classes: ['Class 3-A', 'Class 3-B'], green: 61, blue: 16, red: 11),
  _TeacherReport(teacherName: 'Mr. Arun Patel',      classes: ['Class 4-A'],              green: 35, blue: 10, red: 8),
  _TeacherReport(teacherName: 'Mrs. Kavita Reddy',   classes: ['Class 5-A'],              green: 38, blue: 12, red: 9),
];

const _mockPendingReviews = [
  _PendingReview(studentName: 'Arjun Kumar',  className: 'Class 5-A', field: 'Mother Name',   oldValue: 'Sunita Kumar',     newValue: 'Sunita Devi Kumar',  submittedAt: '2 hrs ago'),
  _PendingReview(studentName: 'Priya Sharma', className: 'Class 3-B', field: 'Address',        oldValue: '12, Main St',       newValue: '24, Park Avenue',    submittedAt: '5 hrs ago'),
  _PendingReview(studentName: 'Ravi Patel',   className: 'Class 7-A', field: 'Father Phone',   oldValue: '9876543210',        newValue: '9812345678',         submittedAt: '1 day ago'),
  _PendingReview(studentName: 'Sneha Reddy',  className: 'Class 2-C', field: 'Bus Stop',       oldValue: 'Main Gate',         newValue: 'North Gate',         submittedAt: '2 days ago'),
  _PendingReview(studentName: 'Mohan Singh',  className: 'Class 9-A', field: 'Student Photo',  oldValue: 'Previous photo',    newValue: 'New photo uploaded', submittedAt: '3 days ago'),
];

// ── Screen ────────────────────────────────────────────────────
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(_reportSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Column(
        children: [
          // Summary stats bar
          summaryAsync.when(
            loading: () => const SizedBox(height: 80,
                child: Center(child: CircularProgressIndicator())),
            error:   (_, __) => const SizedBox.shrink(),
            data:    (s) => _SummaryBar(summary: s),
          ),

          // Tab bar
          Container(
            color: AppTheme.primary,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'By Class'),
                Tab(text: 'By Teacher'),
                Tab(text: 'Pending Reviews'),
                Tab(text: 'Login Status'),
                Tab(text: 'Export'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _OverviewTab(),
                _ByClassTab(),
                _ByTeacherTab(),
                _PendingReviewsTab(),
                _LoginStatusTab(),
                _ExportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Bar ───────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final _ReportSummary summary;
  const _SummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: AppTheme.cardGradient,
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _SummaryItem(
            label:   'Total',
            value:   summary.total,
            color:   Colors.white,
            percent: 1.0,
          ),
          _Divider(),
          _SummaryItem(
            label:   'Verified',
            value:   summary.green,
            color:   AppTheme.statusGreen,
            percent: summary.greenPct,
            icon:    Icons.check_circle,
          ),
          _Divider(),
          _SummaryItem(
            label:   'Changed',
            value:   summary.blue,
            color:   AppTheme.statusBlue,
            percent: summary.bluePct,
            icon:    Icons.sync,
          ),
          _Divider(),
          _SummaryItem(
            label:   'Pending',
            value:   summary.red,
            color:   AppTheme.statusRed,
            percent: summary.redPct,
            icon:    Icons.cancel,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final double percent;
  final IconData? icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          LinearPercentIndicator(
            width:             60,
            lineHeight:        6,
            percent:           percent.clamp(0.0, 1.0),
            progressColor:     color,
            backgroundColor:   Colors.white24,
            barRadius:         const Radius.circular(3),
            padding:           EdgeInsets.zero,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
              Text(
                value.toString(),
                style: GoogleFonts.poppins(
                    color: color, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                    color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width:  1,
      color:  Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_reportSummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (_, __) => const Center(child: Text('Failed to load data')),
      data:    (s) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _PieChartCard(summary: s)),
            const SizedBox(width: 16),
            Expanded(child: _BarChartCard()),
          ],
        ),
      ),
    );
  }
}

class _PieChartCard extends StatefulWidget {
  final _ReportSummary summary;
  const _PieChartCard({required this.summary});

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final sections = [
      (widget.summary.green, AppTheme.statusGreen, 'Verified'),
      (widget.summary.blue,  AppTheme.statusBlue,  'Changed'),
      (widget.summary.red,   AppTheme.statusRed,   'Pending'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Distribution',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex = response?.touchedSection
                            ?.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: List.generate(sections.length, (i) {
                    final (value, color, label) = sections[i];
                    final isTouched = i == _touchedIndex;
                    final pct = widget.summary.total > 0
                        ? value / widget.summary.total * 100
                        : 0.0;
                    return PieChartSectionData(
                      color:        color,
                      value:        value.toDouble(),
                      title:        isTouched
                          ? '$label\n${pct.toStringAsFixed(1)}%'
                          : '${pct.toStringAsFixed(1)}%',
                      radius:       isTouched ? 80 : 70,
                      titleStyle: GoogleFonts.poppins(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      Colors.white,
                      ),
                    );
                  }),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sections.map((s) {
                final (_, color, label) = s;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.grey600)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

class _BarChartCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(_classReportProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class-wise Breakdown',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: classAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (_, __) => const Text('Error'),
                data:    (data) {
                  final unique = <String>[];
                  for (final r in data) {
                    if (!unique.contains(r.className)) unique.add(r.className);
                  }
                  return BarChart(
                    BarChartData(
                      alignment:    BarChartAlignment.spaceAround,
                      maxY: data.fold(0.0, (m, r) =>
                          r.total > m ? r.total.toDouble() : m) + 10,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true, reservedSize: 28),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= unique.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  unique[i].replaceAll('Class ', 'C'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: AppTheme.grey600),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles:   const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppTheme.grey200, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(unique.length, (i) {
                        final cls = unique[i];
                        final rows = data.where((r) => r.className == cls);
                        final g = rows.fold(0, (s, r) => s + r.green);
                        final b = rows.fold(0, (s, r) => s + r.blue);
                        final r = rows.fold(0, (s, rr) => s + rr.red);
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY:   g.toDouble(),
                              color: AppTheme.statusGreen,
                              width: 8,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            BarChartRodData(
                              toY:   b.toDouble(),
                              color: AppTheme.statusBlue,
                              width: 8,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            BarChartRodData(
                              toY:   r.toDouble(),
                              color: AppTheme.statusRed,
                              width: 8,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

// ── By Class Tab ──────────────────────────────────────────────
class _ByClassTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(_classReportProvider);

    return classAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (_, __) => const Center(child: Text('Error loading data')),
      data:    (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
              columns: [
                DataColumn(
                    label: Text('Class', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Section', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Verified ✓', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.statusGreen))),
                DataColumn(
                    label: Text('Changed ⟳', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.statusBlue))),
                DataColumn(
                    label: Text('Pending ✗', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.statusRed))),
                DataColumn(
                    label: Text('Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
              ],
              rows: data.map((r) {
                final dominantStatus = r.green >= r.blue && r.green >= r.red
                    ? AppConstants.statusGreen
                    : r.blue >= r.red
                        ? AppConstants.statusBlue
                        : AppConstants.statusRed;
                final rowColor = dominantStatus == AppConstants.statusGreen
                    ? AppTheme.statusGreen.withOpacity(0.04)
                    : dominantStatus == AppConstants.statusBlue
                        ? AppTheme.statusBlue.withOpacity(0.04)
                        : AppTheme.statusRed.withOpacity(0.04);

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    DataCell(Text(r.className, style: GoogleFonts.poppins(fontSize: 13))),
                    DataCell(Text(r.section,   style: GoogleFonts.poppins(fontSize: 13))),
                    DataCell(Text('${r.total}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(_CountCell(value: r.green, color: AppTheme.statusGreen)),
                    DataCell(_CountCell(value: r.blue,  color: AppTheme.statusBlue)),
                    DataCell(_CountCell(value: r.red,   color: AppTheme.statusRed)),
                    DataCell(SizedBox(
                      width: 80,
                      child: LinearPercentIndicator(
                        lineHeight:     8,
                        percent:        r.total > 0 ? r.green / r.total : 0,
                        progressColor:  AppTheme.statusGreen,
                        backgroundColor: AppTheme.grey200,
                        barRadius: const Radius.circular(4),
                        padding: EdgeInsets.zero,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountCell extends StatelessWidget {
  final int value;
  final Color color;
  const _CountCell({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$value',
        style: GoogleFonts.poppins(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── By Teacher Tab ────────────────────────────────────────────
class _ByTeacherTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(_teacherReportProvider);

    return teacherAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (_, __) => const Center(child: Text('Error')),
      data:    (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: data.asMap().entries.map((e) {
            final teacher = e.value;
            final greenPct = teacher.total > 0
                ? teacher.green / teacher.total
                : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.12),
                      child: Text(
                        teacher.teacherName[0],
                        style: GoogleFonts.poppins(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(teacher.teacherName,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(teacher.classes.join(' • '),
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppTheme.grey600)),
                          const SizedBox(height: 8),
                          LinearPercentIndicator(
                            lineHeight:    8,
                            percent:       greenPct.clamp(0.0, 1.0),
                            progressColor: AppTheme.statusGreen,
                            backgroundColor: AppTheme.grey200,
                            barRadius: const Radius.circular(4),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _CountCell(value: teacher.green, color: AppTheme.statusGreen),
                    const SizedBox(width: 6),
                    _CountCell(value: teacher.blue,  color: AppTheme.statusBlue),
                    const SizedBox(width: 6),
                    _CountCell(value: teacher.red,   color: AppTheme.statusRed),
                  ],
                ),
              ),
            ).animate(delay: (e.key * 60).ms).fadeIn(duration: 300.ms);
          }).toList(),
        ),
      ),
    );
  }
}

// ── Pending Reviews Tab ───────────────────────────────────────
class _PendingReviewsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingReviewsProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (_, __) => const Center(child: Text('Error')),
      data:    (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${data.length} pending approvals',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.statusRed)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon:  const Icon(Icons.check_circle, size: 14),
                  label: const Text('Approve All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.statusGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...data.asMap().entries.map((e) {
              final r = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius:          16,
                            backgroundColor: AppTheme.statusBlue.withOpacity(0.12),
                            child: Text(r.studentName[0],
                                style: GoogleFonts.poppins(
                                    color: AppTheme.statusBlue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.studentName,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text('${r.className} · ${r.submittedAt}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.grey600)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.statusBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(r.field,
                                style: GoogleFonts.poppins(
                                    color: AppTheme.statusBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Old vs New
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:  AppTheme.grey100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CURRENT',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: AppTheme.grey600,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8)),
                                  const SizedBox(height: 4),
                                  Text(r.oldValue,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppTheme.grey800)),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward,
                                size: 16, color: AppTheme.grey600),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:  AppTheme.statusBlue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.statusBlue
                                        .withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PROPOSED',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: AppTheme.statusBlue,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8)),
                                  const SizedBox(height: 4),
                                  Text(r.newValue,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppTheme.statusBlue,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: BorderSide(
                                  color: AppTheme.error.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: GoogleFonts.poppins(fontSize: 12),
                            ),
                            icon:  const Icon(Icons.close, size: 14),
                            label: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.statusGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: GoogleFonts.poppins(fontSize: 12),
                            ),
                            icon:  const Icon(Icons.check, size: 14),
                            label: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate(delay: (e.key * 60).ms).fadeIn(duration: 300.ms);
            }),
          ],
        ),
      ),
    );
  }
}

// ── Export Tab ────────────────────────────────────────────────
// ── Login Status Tab ──────────────────────────────────────────
class _LoginStatusTab extends ConsumerWidget {
  const _LoginStatusTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_loginStatusProvider);

    return statusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data:    (s) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _EngagementCard(
                  title: 'Employee Engagement',
                  total: s.empTotal,
                  linked: s.empLinked,
                  icon: Icons.badge,
                  color: AppTheme.primary,
                )),
                const SizedBox(width: 16),
                Expanded(child: _EngagementCard(
                  title: 'Parent Engagement',
                  total: s.guardTotal,
                  linked: s.guardLinked,
                  icon: Icons.family_restroom,
                  color: AppTheme.accent,
                )),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Active Sessions',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 16),
                    if (s.recentLogins.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No recent logins found')),
                      )
                    else
                      ...s.recentLogins.map((u) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.grey100,
                          child: Text(u['display_name'] != null && u['display_name'].isNotEmpty 
                            ? u['display_name'][0].toUpperCase() 
                            : 'U'),
                        ),
                        title: Text(u['display_name'] ?? 'User', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('${u['role']} • ${u['phone']}', style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          u['last_login'] != null ? 'Active' : 'Never',
                          style: const TextStyle(fontSize: 10, color: AppTheme.statusGreen),
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  final String title;
  final int total;
  final int linked;
  final IconData icon;
  final Color color;

  const _EngagementCard({
    required this.title,
    required this.total,
    required this.linked,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (linked / total) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 16),
            CircularPercentIndicator(
              radius: 40,
              lineWidth: 8,
              percent: pct.clamp(0.0, 1.0),
              center: Text('${(pct * 100).toStringAsFixed(0)}%', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              progressColor: color,
              backgroundColor: color.withOpacity(0.1),
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 12),
            Text('$linked / $total Linked', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
          ],
        ),
      ),
    );
  }
}

class _ExportTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const base = AppConstants.apiBaseUrl;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download Reports',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text('All reports download as Excel (.xlsx) files',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ExportCard(
                icon:        Icons.table_chart,
                title:       'Dashboard / Overview',
                subtitle:    'Class-wise student status breakdown',
                color:       AppTheme.statusGreen,
                downloadUrl: '$base/reports/download/dashboard',
              ),
              _ExportCard(
                icon:        Icons.class_,
                title:       'Class-wise Summary',
                subtitle:    'Detailed student list by class with parent contacts',
                color:       AppTheme.statusBlue,
                downloadUrl: '$base/reports/download/class-summary',
              ),
              _ExportCard(
                icon:        Icons.person,
                title:       'Teacher-wise Report',
                subtitle:    'Each teacher\'s student counts and status',
                color:       AppTheme.primary,
                downloadUrl: '$base/reports/download/teacher-wise',
              ),
              _ExportCard(
                icon:        Icons.account_tree,
                title:       'N+1 Hierarchy Report',
                subtitle:    'Your team\'s student counts in reporting chain',
                color:       AppTheme.secondary,
                downloadUrl: '$base/reports/download/n-plus-one',
              ),
              _ExportCard(
                icon:        Icons.pending_actions,
                title:       'Pending Reviews',
                subtitle:    'Parent changes awaiting approval',
                color:       AppTheme.statusRed,
                downloadUrl: '$base/reports/download/review-changes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String downloadUrl;

  const _ExportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.downloadUrl,
  });

  Future<void> _download(BuildContext context) async {
    final uri = Uri.base.resolve(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.grey600)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _download(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.statusGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                  ),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Download Excel'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
