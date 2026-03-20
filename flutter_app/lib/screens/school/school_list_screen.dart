// ============================================================
// School List Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────
class SchoolItem {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  final String city;
  final String state;
  final String phone;
  final String email;
  final int branchCount;
  final int employeeCount;

  const SchoolItem({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    required this.city,
    required this.state,
    required this.phone,
    required this.email,
    required this.branchCount,
    required this.employeeCount,
  });

  factory SchoolItem.fromJson(Map<String, dynamic> j) => SchoolItem(
        id:           j['id']            as String,
        name:         j['name']          as String? ?? '',
        code:         j['code']          as String? ?? '',
        logoUrl:      j['logo_url']      as String?,
        city:         j['city']          as String? ?? '',
        state:        j['state']         as String? ?? '',
        phone:        j['phone1']        as String? ?? '',
        email:        j['email']         as String? ?? '',
        branchCount:  (j['branch_count'] as num?)?.toInt() ?? 0,
        employeeCount:(j['employee_count'] as num?)?.toInt() ?? 0,
      );

  static List<SchoolItem> mockList() => [
        const SchoolItem(
          id:           's1',
          name:         'Green Valley School',
          code:         'GVS001',
          city:         'New Delhi',
          state:        'Delhi',
          phone:        '+91 11 1234 5678',
          email:        'info@greenvalley.edu.in',
          branchCount:  3,
          employeeCount: 1248,
        ),
        const SchoolItem(
          id:           's2',
          name:         'Blue Ridge Academy',
          code:         'BRA002',
          city:         'Mumbai',
          state:        'Maharashtra',
          phone:        '+91 22 9876 5432',
          email:        'contact@blueridge.edu.in',
          branchCount:  2,
          employeeCount: 867,
        ),
        const SchoolItem(
          id:           's3',
          name:         'Sunrise International School',
          code:         'SIS003',
          city:         'Bangalore',
          state:        'Karnataka',
          phone:        '+91 80 2345 6789',
          email:        'admin@sunrise.edu.in',
          branchCount:  5,
          employeeCount: 2134,
        ),
        const SchoolItem(
          id:           's4',
          name:         'Heritage Public School',
          code:         'HPS004',
          city:         'Chennai',
          state:        'Tamil Nadu',
          phone:        '+91 44 3456 7890',
          email:        'heritage@school.in',
          branchCount:  1,
          employeeCount: 432,
        ),
      ];
}

// ── Providers ─────────────────────────────────────────────────
final _schoolsProvider = FutureProvider.family<List<SchoolItem>, String>(
    (ref, search) async {
  final data = await ApiService().get('/schools',
      params: search.isNotEmpty ? {'search': search} : null);
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => SchoolItem.fromJson(e as Map<String, dynamic>))
      .toList();
});


final _schoolSearchProvider = StateProvider<String>((_) => '');

// ── Screen ────────────────────────────────────────────────────
class SchoolListScreen extends ConsumerStatefulWidget {
  const SchoolListScreen({super.key});

  @override
  ConsumerState<SchoolListScreen> createState() => _SchoolListScreenState();
}

class _SchoolListScreenState extends ConsumerState<SchoolListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search    = ref.watch(_schoolSearchProvider);
    final schoolsAsy = ref.watch(_schoolsProvider(search));

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/schools/new'),
        icon:  const Icon(Icons.add_business),
        label: const Text('Add School'),
      ).animate().scale(delay: 300.ms),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Search
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText:   'Search schools...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(_schoolSearchProvider.notifier).state = '';
                              },
                              icon: const Icon(Icons.close, size: 16))
                          : null,
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        ref.read(_schoolSearchProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Count
            schoolsAsy.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (s) => Text(
                '${s.length} school(s) found',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.grey600),
              ),
            ),
            const SizedBox(height: 12),

            // Grid
            Expanded(
              child: schoolsAsy.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (e, _) => Center(child: Text('Error: $e')),
                data:    (schools) => schools.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.school_outlined,
                                size: 64, color: AppTheme.grey300),
                            const SizedBox(height: 12),
                            Text('No schools found',
                                style: GoogleFonts.poppins(
                                    color: AppTheme.grey600)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (ctx, constraints) {
                          final cols = constraints.maxWidth > 900
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 3
                                  : 2;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:  cols,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: schools.length,
                            itemBuilder: (ctx, i) => _SchoolCard(
                              school: schools[i],
                              index:  i,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── School Card ───────────────────────────────────────────────
class _SchoolCard extends StatelessWidget {
  final SchoolItem school;
  final int index;
  const _SchoolCard({required this.school, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/schools/${school.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SchoolLogo(url: school.logoUrl, name: school.name),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(school.code,
                        style: GoogleFonts.poppins(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                school.name,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppTheme.grey600),
                  const SizedBox(width: 3),
                  Text('${school.city}, ${school.state}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.grey600)),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _MiniStat(
                    icon:  Icons.account_tree_outlined,
                    value: '${school.branchCount}',
                    label: 'Branches',
                  ),
                  const SizedBox(width: 12),
                  _MiniStat(
                    icon:  Icons.people_outlined,
                    value: '${school.employeeCount}',
                    label: 'Employees',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/schools/${school.id}'),
                  icon:  const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (index * 80).ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.2);
  }
}

class _SchoolLogo extends StatelessWidget {
  final String? url;
  final String name;
  const _SchoolLogo({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url!,
            width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return Container(
      width:  44,
      height: 44,
      decoration: BoxDecoration(
        gradient:     AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.grey600),
        const SizedBox(width: 3),
        Text('$value ',
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: AppTheme.grey600)),
      ],
    );
  }
}
