// ============================================================
// Parent Portal — Children Overview Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Model ─────────────────────────────────────────────────────
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
  final String guardianType;

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
    required this.guardianType,
  });

  factory _ChildInfo.fromJson(Map<String, dynamic> j) => _ChildInfo(
        id:           j['id']           as String,
        firstName:    j['first_name']   as String? ?? '',
        lastName:     j['last_name']    as String? ?? '',
        className:    j['class_name']   as String? ?? '',
        section:      j['section']      as String? ?? '',
        schoolName:   j['school_name']  as String? ?? '',
        branchName:   j['branch_name']  as String? ?? '',
        photoUrl:     j['photo_url']    as String?,
        studentId:    j['student_id']   as String?,
        statusColor:  j['status_color'] as String? ?? 'green',
        guardianType: j['guardian_type'] as String? ?? 'guardian1',
      );

  String get fullName => '$firstName $lastName'.trim();

  Color get statusIndicator {
    switch (statusColor) {
      case 'green':  return AppTheme.statusGreen;
      case 'blue':   return AppTheme.statusBlue;
      default:       return AppTheme.statusRed;
    }
  }

  String get statusLabel {
    switch (statusColor) {
      case 'green':  return 'Verified';
      case 'blue':   return 'Changes Pending';
      default:       return 'Action Required';
    }
  }

  String get relationLabel {
    switch (guardianType) {
      case 'mother':    return 'Mother';
      case 'father':    return 'Father';
      case 'guardian1': return 'Guardian 1';
      case 'guardian2': return 'Guardian 2';
      default:          return 'Guardian';
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final _childrenProvider = FutureProvider.autoDispose<List<_ChildInfo>>((ref) async {
  final data = await ApiService().get('/parent/students');
  final list = data['data'] as List<dynamic>? ?? [];
  return list.map((e) => _ChildInfo.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────
class ParentPortalScreen extends ConsumerWidget {
  const ParentPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authNotifierProvider).valueOrNull;
    final childrenAsync = ref.watch(_childrenProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_childrenProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _ParentHeader(name: user?.fullName ?? user?.displayName ?? 'Parent'),
              const SizedBox(height: 24),

              // Section title
              Text(
                'Your Children',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.grey900,
                ),
              ),
              const SizedBox(height: 12),

              // Children list
              childrenAsync.when(
                loading: () => _ShimmerList(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (children) {
                  if (children.isEmpty) {
                    return _EmptyState();
                  }
                  return Column(
                    children: children
                        .asMap()
                        .entries
                        .map((entry) => _ChildCard(
                              child: entry.value,
                              index: entry.key,
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _ParentHeader extends StatelessWidget {
  final String name;
  const _ParentHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  _greeting(name),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Parent Portal',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.family_restroom, color: Colors.white24, size: 70),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final salutation = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    final displayName = name.isNotEmpty ? name.split(' ').first : 'Parent';
    return '$salutation, $displayName 👋';
  }
}

// ── Child Card ────────────────────────────────────────────────
class _ChildCard extends StatelessWidget {
  final _ChildInfo child;
  final int index;
  const _ChildCard({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              backgroundImage:
                  child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
              child: child.photoUrl == null
                  ? Text(
                      child.firstName.isNotEmpty
                          ? child.firstName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.fullName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${child.className} – Section ${child.section}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.grey600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${child.schoolName} · ${child.branchName}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.grey500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: child.statusIndicator.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: child.statusIndicator.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: child.statusIndicator,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              child.statusLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: child.statusIndicator,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Relation badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.grey100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          child.relationLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppTheme.grey700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            const Icon(Icons.chevron_right, color: AppTheme.primary),
          ],
        ),
      ),
    )
        .animate(delay: (index * 70).ms)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, curve: Curves.easeOut);
  }
}

// ── Empty State ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.child_care, size: 64, color: AppTheme.grey400),
            const SizedBox(height: 16),
            Text(
              'No children linked yet',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your phone number must match the student records.\nPlease contact the school if you believe this is an error.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.grey500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.error.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Could not load children: $message',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer List ──────────────────────────────────────────────
class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(
            color: AppTheme.grey200,
            borderRadius: BorderRadius.circular(16),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms,
              color: Colors.white30,
            ),
      ),
    );
  }
}
