// ============================================================
// Employee Screen — List + Form + Hierarchy View
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────
class EmployeeRecord {
  final String id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String email;
  final String? phone;
  final String roleName;
  final int roleLevel;
  final String? branchName;
  final String? schoolName;
  final String? managerName;
  final String? reportsToEmpId;
  final bool canApprove;
  final bool canUploadBulk;
  final bool isActive;
  final bool isHidden;
  final List<String> extraRoles;

  const EmployeeRecord({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.email,
    this.phone,
    required this.roleName,
    required this.roleLevel,
    this.branchName,
    this.schoolName,
    this.managerName,
    this.reportsToEmpId,
    required this.canApprove,
    required this.canUploadBulk,
    required this.isActive,
    this.isHidden = false,
    this.extraRoles = const [],
  });

  String get fullName => '$firstName $lastName';

  factory EmployeeRecord.fromJson(Map<String, dynamic> j) => EmployeeRecord(
        id:            j['id']             as String,
        employeeId:    j['employee_id']    as String? ?? '',
        firstName:     j['first_name']     as String? ?? '',
        lastName:      j['last_name']      as String? ?? '',
        photoUrl:      j['photo_url']      as String?,
        email:         j['email']          as String? ?? '',
        phone:         j['phone']          as String?,
        roleName:      j['role_name']      as String? ?? '',
        roleLevel:     j['role_level']     as int? ?? 9,
        branchName:    j['branch_name']    as String?,
        schoolName:    j['school_name']    as String?,
        managerName:   j['manager_name']   as String?,
        reportsToEmpId:j['reports_to_emp_id'] as String?,
        canApprove:    (j['can_approve']   as int?) == 1,
        canUploadBulk: (j['can_upload_bulk'] as int?) == 1,
        isActive:      (j['is_active']     as int?) != 0,
        isHidden:      (j['is_hidden']     as int?) == 1,
        extraRoles:    (j['extra_roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );

  static List<EmployeeRecord> mockList() => [
        const EmployeeRecord(id: 'e1', employeeId: 'EMP001', firstName: 'Rajesh',  lastName: 'Sharma',  email: 'rajesh@school.in',  phone: '9876543210', roleName: 'Principal',      roleLevel: 1, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: true,  isActive: true),
        const EmployeeRecord(id: 'e2', employeeId: 'EMP002', firstName: 'Sunita',  lastName: 'Rao',     email: 'sunita@school.in',  phone: '9123456789', roleName: 'Vice Principal', roleLevel: 2, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: true,  isActive: true),
        const EmployeeRecord(id: 'e3', employeeId: 'EMP003', firstName: 'Arjun',   lastName: 'Nair',    email: 'arjun@school.in',   phone: '9234567890', roleName: 'Head Teacher',   roleLevel: 3, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e4', employeeId: 'EMP004', firstName: 'Divya',   lastName: 'Menon',   email: 'divya@school.in',   phone: '9345678901', roleName: 'Head Teacher',   roleLevel: 3, branchName: 'East Campus',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e5', employeeId: 'EMP005', firstName: 'Kiran',   lastName: 'Joshi',   email: 'kiran@school.in',   phone: '9456789012', roleName: 'Vice Principal', roleLevel: 2, branchName: 'West Campus',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: true,  isActive: true),
        const EmployeeRecord(id: 'e6', employeeId: 'EMP006', firstName: 'Priya',   lastName: 'Gupta',   email: 'priya@school.in',   phone: '9567890123', roleName: 'Senior Teacher', roleLevel: 4, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e7', employeeId: 'EMP007', firstName: 'Rohit',   lastName: 'Verma',   email: 'rohit@school.in',   phone: '9678901234', roleName: 'Class Teacher',  roleLevel: 5, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e8', employeeId: 'EMP008', firstName: 'Kavya',   lastName: 'Iyer',    email: 'kavya@school.in',   phone: '9789012345', roleName: 'Subject Teacher', roleLevel: 6, branchName: 'Main Branch', schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: false),
        const EmployeeRecord(id: 'e9', employeeId: 'EMP009', firstName: 'Suresh',  lastName: 'Patel',   email: 'suresh@school.in',  phone: '9890123456', roleName: 'Senior Teacher', roleLevel: 4, branchName: 'East Campus',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
        const EmployeeRecord(id:'e10', employeeId: 'EMP010', firstName: 'Anita',   lastName: 'Reddy',   email: 'anita@school.in',   phone: '9901234567', roleName: 'Class Teacher',  roleLevel: 5, branchName: 'East Campus',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
      ];
}

// ── Providers ─────────────────────────────────────────────────
final _selectedEmployeeProvider  = StateProvider<EmployeeRecord?>((ref) => null);
final _employeeFilterProvider    = StateProvider<int?>((_) => null); // level filter
final _showInactiveProvider      = StateProvider<bool>((_) => false);
final _showHiddenProvider        = StateProvider<bool>((_) => false);

// Employees provider with inactive/hidden support
final _employeesProvider = FutureProvider.family<List<EmployeeRecord>, ({bool inactive, bool hidden})>((ref, opts) async {
  try {
    final data = await ApiService().get('/employees', params: {
      if (opts.inactive) 'include_inactive': 'true',
      if (opts.hidden)   'include_hidden': 'true',
    });
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => EmployeeRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return EmployeeRecord.mockList();
  }
});

// Fetch org roles for the assignment form
final _orgRolesDropdownProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, schoolId) async {
  try {
    final user = ref.read(authNotifierProvider).value;
    final sid = schoolId ?? user?.employee?.schoolId;
    if (sid == null) return [];
    final res = await ApiService().get('/org/roles/$sid');
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  } catch (_) { return []; }
});

// ── Screen ────────────────────────────────────────────────────
class EmployeeScreen extends ConsumerWidget {
  const EmployeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showInactive = ref.watch(_showInactiveProvider);
    final showHidden   = ref.watch(_showHiddenProvider);
    final employeesAsy = ref.watch(_employeesProvider((inactive: showInactive, hidden: showHidden)));
    final selected     = ref.watch(_selectedEmployeeProvider);
    final levelFilter  = ref.watch(_employeeFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeForm(context, ref, null),
        icon:  const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ).animate().scale(delay: 300.ms),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            _EmployeeToolbar(levelFilter: levelFilter),
            const SizedBox(height: 12),
            // Table
            Expanded(
              child: employeesAsy.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (e, _) => Center(child: Text('Error: $e')),
                data:    (employees) {
                  final filtered = levelFilter != null
                      ? employees.where((e) => e.roleLevel == levelFilter).toList()
                      : employees;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: selected != null ? 1 : 1, // Let table share space
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: _EmployeeTable(
                            employees: filtered,
                            onSelect: (e) => ref
                                .read(_selectedEmployeeProvider.notifier)
                                .state = e,
                          ),
                        ),
                      ),
                      if (selected != null) ...[
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 300,
                          child: _EmployeeDetailPanel(
                            employee: selected,
                            onClose:  () => ref
                                .read(_selectedEmployeeProvider.notifier)
                                .state = null,
                            onEdit: () => _showEmployeeForm(
                                context, ref, selected),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeForm(
      BuildContext context, WidgetRef ref, EmployeeRecord? employee) {
    showModalBottomSheet(
      context:      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeFormSheet(employee: employee),
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────
class _EmployeeToolbar extends ConsumerWidget {
  final int? levelFilter;
  const _EmployeeToolbar({this.levelFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showInactive = ref.watch(_showInactiveProvider);
    final showHidden   = ref.watch(_showHiddenProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Level filter chips
            ...AppConstants.orgLevels.entries.map((e) {
              final isActive = levelFilter == e.key;
              return FilterChip(
                label: Text('L${e.key} ${e.value}',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isActive ? Colors.white : AppTheme.grey800,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400)),
                selected:      isActive,
                selectedColor: AppTheme.primary,
                showCheckmark: false,
                side:          BorderSide(
                    color: isActive
                        ? AppTheme.primary
                        : AppTheme.grey300),
                onSelected: (_) {
                  ref.read(_employeeFilterProvider.notifier).state =
                      isActive ? null : e.key;
                },
              );
            }),

            const VerticalDivider(width: 20, indent: 4, endIndent: 4),

            // Show inactive toggle
            FilterChip(
              label: Text('Show Inactive',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: showInactive ? Colors.white : AppTheme.grey800,
                      fontWeight: showInactive ? FontWeight.w600 : FontWeight.w400)),
              selected:      showInactive,
              selectedColor: AppTheme.error,
              showCheckmark: false,
              avatar: Icon(Icons.person_off_outlined,
                  size: 14,
                  color: showInactive ? Colors.white : AppTheme.grey600),
              side: BorderSide(color: showInactive ? AppTheme.error : AppTheme.grey300),
              onSelected: (_) =>
                  ref.read(_showInactiveProvider.notifier).state = !showInactive,
            ),

            // Show hidden toggle
            FilterChip(
              label: Text('Show Hidden',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: showHidden ? Colors.white : AppTheme.grey800,
                      fontWeight: showHidden ? FontWeight.w600 : FontWeight.w400)),
              selected:      showHidden,
              selectedColor: AppTheme.grey600,
              showCheckmark: false,
              avatar: Icon(Icons.visibility_off_outlined,
                  size: 14,
                  color: showHidden ? Colors.white : AppTheme.grey600),
              side: BorderSide(color: showHidden ? AppTheme.grey600 : AppTheme.grey300),
              onSelected: (_) =>
                  ref.read(_showHiddenProvider.notifier).state = !showHidden,
            ),

            const VerticalDivider(width: 20, indent: 4, endIndent: 4),

            // Bulk upload
            OutlinedButton.icon(
              onPressed: () => _showBulkUpload(context),
              icon:  const Icon(Icons.upload_file, size: 15),
              label: const Text('Bulk Upload'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                textStyle: GoogleFonts.poppins(fontSize: 12),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _BulkUploadDialog(),
    );
  }
}

// ── Employee Table ────────────────────────────────────────────
class _EmployeeTable extends StatelessWidget {
  final List<EmployeeRecord> employees;
  final ValueChanged<EmployeeRecord> onSelect;
  const _EmployeeTable({required this.employees, required this.onSelect});

  Color _levelColor(int level) {
    switch (level) {
      case 1:  return const Color(0xFFFFD700);
      case 2:  return const Color(0xFFC0C0C0);
      case 3:  return const Color(0xFFCD7F32);
      case 4:  return AppTheme.primary;
      case 5:  return AppTheme.secondary;
      case 6:  return AppTheme.accent;
      default: return AppTheme.grey600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing:   12,
      horizontalMargin: 16,
      minWidth:        700,
      headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
      columns: [
        const DataColumn2(label: Text('Employee'), size: ColumnSize.L),
        const DataColumn2(label: Text('ID'),       fixedWidth: 90),
        const DataColumn2(label: Text('Level'),    fixedWidth: 180),
        const DataColumn2(label: Text('Branch'),   fixedWidth: 130),
        const DataColumn2(label: Text('Permissions'), fixedWidth: 120),
        const DataColumn2(label: Text('Status'),   fixedWidth: 80),
        const DataColumn2(label: Text('Actions'),  fixedWidth: 80),
      ],
      rows: employees.map((e) {
        final color = _levelColor(e.roleLevel);
        return DataRow2(
          onTap: () => onSelect(e),
          color: WidgetStateProperty.all(
              e.isActive ? Colors.white : AppTheme.grey100),
          cells: [
            DataCell(Row(
              children: [
                _EmpAvatar(url: e.photoUrl, name: e.fullName, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Text(e.fullName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      Text(e.email,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppTheme.grey600),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            )),
            DataCell(Text(e.employeeId,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.grey600))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  6, height: 6,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(e.roleName,
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('L${e.roleLevel}',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          color:      color,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            )),
            DataCell(Text(e.branchName ?? '—',
                style: GoogleFonts.poppins(fontSize: 12),
                overflow: TextOverflow.ellipsis)),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PermIcon(icon: Icons.check_circle, active: e.canApprove,    tooltip: 'Can Approve'),
                const SizedBox(width: 4),
                _PermIcon(icon: Icons.upload_file,  active: e.canUploadBulk, tooltip: 'Bulk Upload'),
              ],
            )),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: e.isActive
                    ? AppTheme.statusGreen.withOpacity(0.1)
                    : AppTheme.grey200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(e.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: e.isActive
                          ? AppTheme.statusGreen
                          : AppTheme.grey600,
                      fontWeight: FontWeight.w600)),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onSelect(e),
                  icon:    const Icon(Icons.info_outline, size: 16),
                  color:   AppTheme.primary,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'View',
                ),
              ],
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _EmpAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final Color color;
  const _EmpAvatar({this.url, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
          radius: 18, backgroundImage: NetworkImage(url!));
    }
    return CircleAvatar(
      radius:          18,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'E',
        style: GoogleFonts.poppins(
            color:      color,
            fontSize:   13,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PermIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  const _PermIcon({
    required this.icon,
    required this.active,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size:  14,
        color: active ? AppTheme.statusGreen : AppTheme.grey300,
      ),
    );
  }
}

const Color _grey400 = Color(0xFFBDBDBD);

// ── Employee Detail Panel ─────────────────────────────────────
class _EmployeeDetailPanel extends StatefulWidget {
  final EmployeeRecord employee;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  const _EmployeeDetailPanel({
    required this.employee,
    required this.onClose,
    required this.onEdit,
  });

  @override
  State<_EmployeeDetailPanel> createState() => _EmployeeDetailPanelState();
}

class _EmployeeDetailPanelState extends State<_EmployeeDetailPanel> {
  bool _actioning = false;

  Color get _levelColor {
    switch (widget.employee.roleLevel) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      case 4: return AppTheme.primary;
      case 5: return AppTheme.secondary;
      default: return AppTheme.grey600;
    }
  }

  Future<void> _deactivate(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate Employee?'),
        content: Text(
            'This will deactivate ${widget.employee.fullName} and remove them from active lists.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _actioning = true);
    try {
      await ApiService().delete('/employees/${widget.employee.id}');
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee deactivated'), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _toggleHidden(BuildContext context) async {
    setState(() => _actioning = true);
    try {
      await ApiService().patch('/employees/${widget.employee.id}/toggle-hidden');
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visibility updated'), backgroundColor: AppTheme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _levelColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Details',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  _EmpAvatar(
                      url:   widget.employee.photoUrl,
                      name:  widget.employee.fullName,
                      color: c),
                  const SizedBox(height: 8),
                  Text(widget.employee.fullName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color:        c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width:  6, height: 6,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'L${widget.employee.roleLevel} · ${widget.employee.roleName}',
                          style: GoogleFonts.poppins(
                              color:      c,
                              fontSize:   11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _Row('ID',       widget.employee.employeeId,     Icons.badge_outlined),
            _Row('Email',    widget.employee.email,           Icons.email_outlined),
            if (widget.employee.phone != null)
              _Row('Phone',  widget.employee.phone!,          Icons.phone_outlined),
            if (widget.employee.branchName != null)
              _Row('Branch', widget.employee.branchName!,     Icons.account_tree_outlined),
            if (widget.employee.managerName != null)
              _Row('Reports to', widget.employee.managerName!, Icons.person_outline),
            const SizedBox(height: 12),
            // Permissions
            Text('Permissions',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.grey600,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _PermChip(
                    label: 'Can Approve',
                    active: widget.employee.canApprove),
                _PermChip(
                    label: 'Bulk Upload',
                    active: widget.employee.canUploadBulk),
              ],
            ),
            const Spacer(),
            // Edit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actioning ? null : widget.onEdit,
                icon:  const Icon(Icons.edit, size: 14),
                label: const Text('Edit Employee'),
              ),
            ),
            const SizedBox(height: 8),
            // Hide / Unhide
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _actioning ? null : () => _toggleHidden(context),
                icon: const Icon(Icons.visibility_off_outlined, size: 14),
                label: const Text('Hide / Unhide'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.grey700,
                  side: const BorderSide(color: AppTheme.grey300),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Deactivate
            if (widget.employee.isActive)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _actioning ? null : () => _deactivate(context),
                  icon: _actioning
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_off_outlined, size: 14),
                  label: const Text('Deactivate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.3, duration: 300.ms);
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Row(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.grey600),
          const SizedBox(width: 6),
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.grey600)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PermChip extends StatelessWidget {
  final String label;
  final bool active;
  const _PermChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.cancel,
        size:  12,
        color: active ? AppTheme.statusGreen : _grey400,
      ),
      label: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              color: active ? AppTheme.statusGreen : AppTheme.grey600)),
      backgroundColor: active
          ? AppTheme.statusGreen.withOpacity(0.08)
          : AppTheme.grey100,
      side: BorderSide(
          color: active
              ? AppTheme.statusGreen.withOpacity(0.3)
              : AppTheme.grey300),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Employee Form Sheet ───────────────────────────────────────
class _EmployeeFormSheet extends StatefulWidget {
  final EmployeeRecord? employee;
  const _EmployeeFormSheet({this.employee});

  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _empIdCtrl;
  int     _roleLevel    = 5;
  String? _managerId;
  bool    _canApprove   = false;
  bool   _canBulk      = false;
  bool   _isActive     = true;
  bool   _saving       = false;
  Uint8List? _photo;
  List<String> _extraRoles = [];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _firstCtrl  = TextEditingController(text: e?.firstName ?? '');
    _lastCtrl   = TextEditingController(text: e?.lastName  ?? '');
    _emailCtrl  = TextEditingController(text: e?.email     ?? '');
    _phoneCtrl  = TextEditingController(text: e?.phone     ?? '');
    _empIdCtrl  = TextEditingController(text: e?.employeeId ?? '');
    _roleLevel  = e?.roleLevel  ?? 5;
    _managerId  = e?.reportsToEmpId;
    _canApprove = e?.canApprove ?? false;
    _canBulk    = e?.canUploadBulk ?? false;
    _isActive   = e?.isActive   ?? true;
    _extraRoles = List.from(e?.extraRoles ?? []);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _empIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 300, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = {
        'first_name':  _firstCtrl.text.trim(),
        'last_name':   _lastCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'employee_id': _empIdCtrl.text.trim(),
        'role_level':  _roleLevel,
        'reports_to_emp_id': _managerId,
        'is_active':   _isActive ? 1 : 0,
        'extra_roles': _extraRoles,
      };
      if (widget.employee?.id != null) {
        await ApiService().put('/employees/${widget.employee!.id}', body: body);
      } else {
        await ApiService().post('/employees', body: body);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Employee saved successfully'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      expand:           false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.employee != null ? 'Edit Employee' : 'Add Employee',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Photo
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: CircleAvatar(
                          radius:          40,
                          backgroundColor: AppTheme.grey200,
                          backgroundImage: _photo != null
                              ? MemoryImage(_photo!)
                              : null,
                          child: _photo == null
                              ? const Icon(Icons.add_a_photo,
                                  size: 28, color: AppTheme.grey600)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _Fld(
                              label: 'First Name *',
                              ctrl:  _firstCtrl,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _Fld(
                              label: 'Last Name *',
                              ctrl:  _lastCtrl,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Fld(
                        label: 'Email *',
                        ctrl:  _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator:    (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _Fld(
                              label: 'Phone',
                              ctrl:  _phoneCtrl,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _Fld(label: 'Employee ID', ctrl: _empIdCtrl),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Role level
                      DropdownButtonFormField<int>(
                        value:      _roleLevel,
                        style:      GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.grey900),
                        decoration: const InputDecoration(labelText: 'Hierarchy Level *'),
                        items: AppConstants.orgLevels.entries.map((e) =>
                            DropdownMenuItem(
                              value: e.key,
                              child: Text('Level ${e.key}: ${e.value}'),
                            )).toList(),
                        onChanged: (v) {
                          setState(() {
                            _roleLevel = v ?? _roleLevel;
                            _managerId = null; // reset manager if level changes
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Manager Assignment
                      Consumer(builder: (context, ref, _) {
                        final expsAsync = ref.watch(_employeesProvider((inactive: false, hidden: false)));
                        return expsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error:   (e, _) => const SizedBox(),
                          data:    (employees) {
                            // Only allow users with lower roleLevel (higher up in chain) to be managers
                            final managers = employees.where((e) => e.roleLevel < _roleLevel && e.id != widget.employee?.id).toList();
                            return DropdownButtonFormField<String>(
                              value: _managerId,
                              decoration: const InputDecoration(labelText: 'Reports To (Manager)'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('— None (Top Level) —')),
                                ...managers.map((m) => DropdownMenuItem(
                                      value: m.id,
                                      child: Text('${m.fullName} (L${m.roleLevel})'),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _managerId = v),
                            );
                          },
                        );
                      }),
                      const SizedBox(height: 16),

                      // Extra Roles Multi-select
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Supplementary Roles (Optional)',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.grey700,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      Consumer(builder: (context, ref, _) {
                        final rolesAsync = ref.watch(_orgRolesDropdownProvider(null));
                        return rolesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error:   (e, _) => Text('Error loading roles: $e'),
                          data:    (roles) {
                            if (roles.isEmpty) return const Text('No roles configured.');
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: roles.map((role) {
                                final isPrimary = role['level'] == _roleLevel; // rough heuristic
                                final roleId    = role['id'] as String;
                                final isSelected = _extraRoles.contains(roleId);
                                return FilterChip(
                                  label: Text(role['name'],
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: isSelected ? Colors.white : AppTheme.grey800)),
                                  selected: isSelected,
                                  selectedColor: AppTheme.accent,
                                  showCheckmark: false,
                                  side: BorderSide(
                                      color: isSelected ? AppTheme.accent : AppTheme.grey300),
                                  onSelected: (primary) {
                                    if (isPrimary) return; // Can't add primary level role as extra
                                    setState(() {
                                      if (isSelected) {
                                        _extraRoles.remove(roleId);
                                      } else {
                                        _extraRoles.add(roleId);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            );
                          },
                        );
                      }),
                      const SizedBox(height: 16),

                      // Toggles
                      _ToggleRow(
                        label:    'Can Approve Requests',
                        value:    _canApprove,
                        onToggle: (v) => setState(() => _canApprove = v),
                      ),
                      _ToggleRow(
                        label:    'Bulk Upload Permission',
                        value:    _canBulk,
                        onToggle: (v) => setState(() => _canBulk = v),
                      ),
                      _ToggleRow(
                        label:    'Active',
                        value:    _isActive,
                        onToggle: (v) => setState(() => _isActive = v),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 16),
                          label: Text(_saving ? 'Saving...' : 'Save Employee'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fld extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  const _Fld({
    required this.label,
    required this.ctrl,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   ctrl,
      validator:    validator,
      keyboardType: keyboardType,
      style:        GoogleFonts.poppins(fontSize: 13),
      decoration:   InputDecoration(labelText: label),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onToggle;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13)),
        const Spacer(),
        Switch(
          value:       value,
          onChanged:   onToggle,
          activeColor: AppTheme.primary,
        ),
      ],
    );
  }
}

// ── Bulk Upload Dialog ────────────────────────────────────────
class _BulkUploadDialog extends StatefulWidget {
  const _BulkUploadDialog();

  @override
  State<_BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<_BulkUploadDialog> {
  PlatformFile? _file;
  bool _uploading = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type:             FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = result.files.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bulk Upload Employees',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap:   _pick,
              child: Container(
                height:      100,
                width:       double.infinity,
                decoration:  BoxDecoration(
                  border:       Border.all(color: AppTheme.grey300),
                  borderRadius: BorderRadius.circular(10),
                  color:        AppTheme.grey50,
                ),
                child: _file == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_upload_outlined,
                              color: AppTheme.grey600, size: 32),
                          Text('Click to select Excel / CSV',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.grey600)),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.description,
                                color: AppTheme.statusGreen, size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_file!.name,
                                  style: GoogleFonts.poppins(fontSize: 12)),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _file = null),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _uploading || _file == null
              ? null
              : () async {
                  setState(() => _uploading = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
          child: Text(_uploading ? 'Uploading...' : 'Upload'),
        ),
      ],
    );
  }
}

