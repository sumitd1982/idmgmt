// ============================================================
// Employee Screen — List + Form + Hierarchy View
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../models/employee_model.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────

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
    if (employee == null) {
      context.push('/employees/new');
    } else {
      context.push('/employees/${employee.id}');
    }
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

