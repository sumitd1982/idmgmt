// ============================================================
// Org Structure Screen — Interactive tree visualization
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_provider.dart';

// ── Models ────────────────────────────────────────────────────
class OrgNode {
  final String id;
  final String name;
  final String roleName;
  final int roleLevel;
  final String? photoUrl;
  final String? branchName;
  final String? branchId;
  final String? managerId;
  final List<OrgNode> children;

  OrgNode({
    required this.id,
    required this.name,
    required this.roleName,
    required this.roleLevel,
    this.photoUrl,
    this.branchName,
    this.branchId,
    this.managerId,
    this.children = const [],
  });

  factory OrgNode.fromJson(Map<String, dynamic> j) => OrgNode(
        id:         j['id']         as String,
        name:       '${j['first_name'] ?? ''} ${j['last_name'] ?? ''}'.trim(),
        roleName:   j['role_name']  as String? ?? '',
        roleLevel:  j['role_level'] as int? ?? 9,
        photoUrl:   j['photo_url']  as String?,
        branchName: j['branch_name'] as String?,
        branchId:   j['branch_id']  as String?,
        managerId:  j['reports_to_emp_id'] as String?,
        children: (j['children'] as List<dynamic>?)
            ?.map((c) => OrgNode.fromJson(c as Map<String, dynamic>))
            .toList() ?? [],
      );

  static List<OrgNode> mockTree() => [
        OrgNode(
          id: 'e1', name: 'Dr. Rajesh Sharma', roleName: 'Principal',
          roleLevel: 1, branchName: 'Main Branch',
          children: [
            OrgNode(
              id: 'e2', name: 'Mrs. Sunita Rao', roleName: 'Vice Principal',
              roleLevel: 2, branchName: 'Main Branch', managerId: 'e1',
              children: [
                OrgNode(
                  id: 'e3', name: 'Mr. Arjun Nair', roleName: 'Head Teacher',
                  roleLevel: 3, branchName: 'Main Branch', managerId: 'e2',
                  children: [
                    OrgNode(id: 'e6', name: 'Ms. Priya Gupta',  roleName: 'Senior Teacher',  roleLevel: 4, branchName: 'Main Branch', managerId: 'e3'),
                    OrgNode(id: 'e7', name: 'Mr. Rohit Verma',  roleName: 'Class Teacher',   roleLevel: 5, branchName: 'Main Branch', managerId: 'e3'),
                    OrgNode(id: 'e8', name: 'Mrs. Kavya Iyer',  roleName: 'Subject Teacher', roleLevel: 6, branchName: 'Main Branch', managerId: 'e3'),
                  ],
                ),
                OrgNode(
                  id: 'e4', name: 'Mrs. Divya Menon', roleName: 'Head Teacher',
                  roleLevel: 3, branchName: 'East Campus', managerId: 'e2',
                  children: [
                    OrgNode(id: 'e9',  name: 'Mr. Suresh Patel',  roleName: 'Senior Teacher',  roleLevel: 4, branchName: 'East Campus', managerId: 'e4'),
                    OrgNode(id: 'e10', name: 'Ms. Anita Reddy',   roleName: 'Class Teacher',   roleLevel: 5, branchName: 'East Campus', managerId: 'e4'),
                  ],
                ),
              ],
            ),
            OrgNode(
              id: 'e5', name: 'Mr. Kiran Joshi', roleName: 'Vice Principal',
              roleLevel: 2, branchName: 'West Campus', managerId: 'e1',
              children: [
                OrgNode(id: 'e11', name: 'Ms. Pooja Singh',  roleName: 'Head Teacher',    roleLevel: 3, branchName: 'West Campus', managerId: 'e5'),
                OrgNode(id: 'e12', name: 'Mr. Amit Sharma',  roleName: 'Senior Teacher',  roleLevel: 4, branchName: 'West Campus', managerId: 'e5'),
              ],
            ),
          ],
        ),
      ];
}

// ── Level Colors ──────────────────────────────────────────────
Color _levelColor(int level) {
  switch (level) {
    case 1: return const Color(0xFFFFD700); // Gold
    case 2: return const Color(0xFFC0C0C0); // Silver
    case 3: return const Color(0xFFCD7F32); // Bronze
    case 4: return AppTheme.primary;
    case 5: return AppTheme.secondary;
    case 6: return AppTheme.accent;
    case 7: return AppTheme.statusGreen;
    case 8: return AppTheme.grey600;
    default: return AppTheme.grey600;
  }
}

// ── Providers ─────────────────────────────────────────────────
final _orgTreeProvider = FutureProvider.family<List<OrgNode>, String?>(
    (ref, schoolId) async {
  try {
    // Resolve school_id from param or logged-in user's employee context
    final user = ref.read(authNotifierProvider).value;
    final effectiveSchoolId = schoolId ?? user?.employee?.schoolId;
    if (effectiveSchoolId == null) return OrgNode.mockTree();
    final data = await ApiService().get('/employees/org-tree/$effectiveSchoolId');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((n) => OrgNode.fromJson(n as Map<String, dynamic>)).toList();
  } catch (_) {
    return OrgNode.mockTree();
  }
});

final _selectedNodeProvider   = StateProvider<OrgNode?>((ref) => null);
final _orgBranchFilterProvider = StateProvider<String?>((ref) => null);
final _orgSchoolSelectorProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────
class OrgStructureScreen extends ConsumerWidget {
  const OrgStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(authNotifierProvider).valueOrNull;
    final selectedSchool = ref.watch(_orgSchoolSelectorProvider) ?? user?.employee?.schoolId;
    final branchFilter   = ref.watch(_orgBranchFilterProvider);
    final treeAsync      = ref.watch(_orgTreeProvider(selectedSchool));
    final selected       = ref.watch(_selectedNodeProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Column(
        children: [
          // Toolbar
          _OrgToolbar(
            selectedSchoolId: selectedSchool,
            selectedBranchId: branchFilter,
          ),
          // Level legend
          _LevelLegend(),
          // Main content
          Expanded(
            child: treeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (nodes) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tree
                  Expanded(
                    flex: selected != null ? 3 : 1,
                    child: _OrgTreeView(nodes: nodes),
                  ),
                  // Details panel
                  if (selected != null) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 280,
                      child: _NodeDetailPanel(node: selected),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/employees/new?schoolId=${selectedSchoolId ?? ''}&branchId=${branchFilter ?? ''}',
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ).animate().scale(delay: 300.ms),
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────
class _OrgToolbar extends ConsumerWidget {
  final String? selectedSchoolId;
  final String? selectedBranchId;
  const _OrgToolbar({this.selectedSchoolId, this.selectedBranchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isSuper = user?.role == 'super_admin';
    final schoolsAsync = ref.watch(allSchoolsProvider);
    final branchesAsync = ref.watch(branchesProvider(selectedSchoolId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.hub, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text('Organizational Hierarchy',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 24),
          
          // School Selector (SuperAdmin only)
          if (isSuper) ...[
            SizedBox(
              width: 180,
              child: schoolsAsync.when(
                data: (schools) => DropdownButtonFormField<String>(
                  value: selectedSchoolId,
                  hint: const Text('Select School'),
                  isDense: true,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                  items: schools.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(s['name'] as String, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) {
                    ref.read(_orgSchoolSelectorProvider.notifier).state = v;
                    ref.read(_orgBranchFilterProvider.notifier).state = null;
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error:   (_, __) => const Text('Error'),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Branch Filter
          SizedBox(
            width: 180,
            child: branchesAsync.when(
              data: (branches) => DropdownButtonFormField<String>(
                value: selectedBranchId,
                hint: const Text('All Branches'),
                isDense: true,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Branches')),
                  ...branches.map((b) => DropdownMenuItem(
                    value: b['id'] as String,
                    child: Text(b['name'] as String, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => ref.read(_orgBranchFilterProvider.notifier).state = v,
              ),
              loading: () => const CircularProgressIndicator(strokeWidth: 2),
              error:   (_, __) => const Text('No Branches'),
            ),
          ),
          const Spacer(),
          Text('Click a node to view details',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey600)),
        ],
      ),
    );
  }
}

// ── Level Legend ──────────────────────────────────────────────
class _LevelLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppTheme.grey100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: AppConstants.orgLevels.entries.take(8).map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _levelColor(e.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('L${e.key} ${e.value}',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tree View ─────────────────────────────────────────────────
class _OrgTreeView extends StatelessWidget {
  final List<OrgNode> nodes;
  const _OrgTreeView({required this.nodes});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: nodes.map((node) => _OrgSubTree(node: node, isRoot: true)).toList(),
        ),
      ),
    );
  }
}

class _OrgSubTree extends ConsumerStatefulWidget {
  final OrgNode node;
  final bool isRoot;
  const _OrgSubTree({required this.node, this.isRoot = false});

  @override
  ConsumerState<_OrgSubTree> createState() => _OrgSubTreeState();
}

class _OrgSubTreeState extends ConsumerState<_OrgSubTree> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node     = widget.node;
    final selected = ref.watch(_selectedNodeProvider);
    final isSelected = selected?.id == node.id;
    final color    = _levelColor(node.roleLevel);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Node card
        GestureDetector(
          onTap: () => ref.read(_selectedNodeProvider.notifier).state =
              isSelected ? null : node,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:   160,
            margin:  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:  isSelected ? color.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : AppTheme.grey200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:  isSelected
                      ? color.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 12 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius:          24,
                      backgroundColor: color.withOpacity(0.15),
                      backgroundImage: node.photoUrl != null
                          ? NetworkImage(node.photoUrl!)
                          : null,
                      child: node.photoUrl == null
                          ? Text(node.name[0],
                              style: GoogleFonts.poppins(
                                color:      color,
                                fontWeight: FontWeight.w700,
                                fontSize:   16,
                              ))
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right:  -2,
                      child: Container(
                        width:  16,
                        height: 16,
                        decoration: BoxDecoration(
                          color:  color,
                          shape:  BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${node.roleLevel}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  node.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize:   11,
                    color:      AppTheme.grey900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.roleName,
                    style: GoogleFonts.poppins(
                        color:      color,
                        fontSize:   9,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (node.branchName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    node.branchName!,
                    style: GoogleFonts.poppins(
                        fontSize: 8, color: AppTheme.grey600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),

        // Expand/collapse + children
        if (node.children.isNotEmpty) ...[
          // Connector line + toggle
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width:  24,
              height: 20,
              decoration: BoxDecoration(
                color:        _expanded
                    ? AppTheme.grey600
                    : AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Icon(
                _expanded ? Icons.remove : Icons.add,
                size:  12,
                color: _expanded ? Colors.white : AppTheme.primary,
              ),
            ),
          ),

          if (_expanded)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve:    Curves.easeInOut,
              child: CustomPaint(
                painter: _TreeLinePainter(
                    childCount: node.children.length),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: node.children
                      .map((child) => _OrgSubTree(node: child))
                      .toList(),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// Custom painter to draw connecting lines
class _TreeLinePainter extends CustomPainter {
  final int childCount;
  _TreeLinePainter({required this.childCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.grey300
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Horizontal line
    canvas.drawLine(
        Offset(size.width / childCount / 2, 0),
        Offset(size.width - size.width / childCount / 2, 0),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Node Detail Panel ─────────────────────────────────────────
class _NodeDetailPanel extends ConsumerWidget {
  final OrgNode node;
  const _NodeDetailPanel({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _levelColor(node.roleLevel);

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Employee Details',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      ref.read(_selectedNodeProvider.notifier).state = null,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Avatar
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius:          40,
                    backgroundColor: color.withOpacity(0.15),
                    backgroundImage: node.photoUrl != null
                        ? NetworkImage(node.photoUrl!)
                        : null,
                    child: node.photoUrl == null
                        ? Text(
                            node.name[0],
                            style: GoogleFonts.poppins(
                                color:      color,
                                fontSize:   28,
                                fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(node.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(node.roleName,
                        style: GoogleFonts.poppins(
                            color:      color,
                            fontSize:   12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            _DetailRow('Level',  'Level ${node.roleLevel}',      Icons.layers),
            _DetailRow('Branch', node.branchName ?? '—',         Icons.account_tree_outlined),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/employees/${node.id}'),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/employees/new?schoolId=${selectedSchoolId ?? ''}&reportsTo=${node.id}',
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 14),
                    label: const Text('Add Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.3, duration: 300.ms);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DetailRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.grey600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.grey600)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
