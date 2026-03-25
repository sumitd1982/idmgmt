// ============================================================
// Employee Screen — Advanced List with Sort, Filter, Export
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/employee_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_provider.dart';
import '../../widgets/common/advanced_filter.dart';
import '../../widgets/common/data_exporter.dart';
import 'package:intl/intl.dart';

// ── Providers ─────────────────────────────────────────────────
final _showInactiveProvider = StateProvider<bool>((_) => true);
final _showHiddenProvider   = StateProvider<bool>((_) => false);
final _employeesProvider    = FutureProvider.family<List<EmployeeRecord>, ({bool inactive, bool hidden})>(
  (ref, opts) async {
    try {
      final data = await ApiService().get('/employees', params: {
        if (opts.inactive) 'include_inactive': 'true',
        if (opts.hidden)   'include_hidden':   'true',
      });
      return (data['data'] as List<dynamic>? ?? [])
          .map((e) => EmployeeRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return EmployeeRecord.mockList(); }
  },
);

// ── Sort Config ───────────────────────────────────────────────
class _SortConfig {
  final String column;
  final bool ascending;
  _SortConfig(this.column, this.ascending);

  _SortConfig toggle() => _SortConfig(column, !ascending);
  _SortConfig copyWith({String? column, bool? ascending}) =>
      _SortConfig(column ?? this.column, ascending ?? this.ascending);
}

// Available columns (key, label)
const _allColumns = [
  ('name',        'Employee Name'),
  ('employeeId',  'Employee ID'),
  ('role',        'Role / Level'),
  ('branch',      'Branch'),
  ('phone',       'Phone'),
  ('email',       'Email'),
  ('manager',     'Manager'),
  ('permissions', 'Permissions'),
  ('status',      'Status'),
];

const _defaultVisible = ['name', 'employeeId', 'role', 'branch', 'permissions', 'status'];

// ── Filter fields for employees ────────────────────────────────
List<FilterField> _buildFilterFields() => [
  const FilterField(key: 'firstName',   label: 'First Name',  type: FilterFieldType.text,   icon: Icons.person_outline),
  const FilterField(key: 'lastName',    label: 'Last Name',   type: FilterFieldType.text,   icon: Icons.person_outline),
  const FilterField(key: 'email',       label: 'Email',       type: FilterFieldType.text,   icon: Icons.email_outlined),
  const FilterField(key: 'phone',       label: 'Phone',       type: FilterFieldType.text,   icon: Icons.phone_outlined),
  const FilterField(key: 'employeeId',  label: 'Employee ID', type: FilterFieldType.text,   icon: Icons.badge_outlined),
  const FilterField(key: 'roleName',    label: 'Role',        type: FilterFieldType.text,   icon: Icons.work_outline),
  FilterField(key: 'roleLevel', label: 'Level', type: FilterFieldType.select, icon: Icons.layers_outlined,
    options: AppConstants.orgLevels.entries.map((e) => FilterOption(e.key.toString(), 'L${e.key}: ${e.value}')).toList()),
  const FilterField(key: 'branchName',  label: 'Branch',      type: FilterFieldType.text,   icon: Icons.account_tree_outlined),
  const FilterField(key: 'managerName', label: 'Manager',     type: FilterFieldType.text,   icon: Icons.supervisor_account_outlined),
  FilterField(key: 'isActive', label: 'Status', type: FilterFieldType.select, icon: Icons.toggle_on_outlined,
    options: const [FilterOption('true', 'Active'), FilterOption('false', 'Inactive')]),
  FilterField(key: 'canApprove', label: 'Can Approve', type: FilterFieldType.boolean, icon: Icons.approval_outlined),
];

String _empValue(EmployeeRecord e, String key) {
  switch (key) {
    case 'firstName':   return e.firstName;
    case 'lastName':    return e.lastName;
    case 'email':       return e.email;
    case 'phone':       return e.phone ?? '';
    case 'employeeId':  return e.employeeId;
    case 'roleName':    return e.roleName;
    case 'roleLevel':   return e.roleLevel.toString();
    case 'branchName':  return e.branchName ?? '';
    case 'managerName': return e.managerName ?? '';
    case 'isActive':    return e.isActive.toString();
    case 'canApprove':  return e.canApprove.toString();
    default:            return '';
  }
}

// ── Screen ────────────────────────────────────────────────────
class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> {
  // Selection
  final Set<String> _selectedIds = {};

  // Branch filter
  String? _selectedBranchId;

  // Search
  final _searchCtrl = TextEditingController();
  String _searchText = '';

  // Filter
  List<FilterRule> _filterRules = [];
  FilterLogic _filterLogic = FilterLogic.and;

  // Sort
  List<_SortConfig> _sorts = [_SortConfig('roleLevel', true)];

  // Columns
  List<String> _visibleColumns = List.from(_defaultVisible);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<EmployeeRecord> _applyLocalFilters(List<EmployeeRecord> all) {
    var list = all;

    // Branch filter
    if (_selectedBranchId != null) {
      list = list.where((e) => e.branchId == _selectedBranchId).toList();
    }

    // Search
    if (_searchText.isNotEmpty) {
      final q = _searchText.toLowerCase();
      list = list.where((e) =>
        e.fullName.toLowerCase().contains(q) ||
        e.email.toLowerCase().contains(q) ||
        e.employeeId.toLowerCase().contains(q) ||
        (e.phone?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    // Filter rules
    list = list.where((e) => applyFilters(e, _filterRules, _filterLogic, _empValue)).toList();

    // Sort
    list.sort((a, b) {
      for (final s in _sorts) {
        int cmp = 0;
        switch (s.column) {
          case 'name':       cmp = a.fullName.compareTo(b.fullName); break;
          case 'employeeId': cmp = a.employeeId.compareTo(b.employeeId); break;
          case 'roleLevel':  cmp = a.roleLevel.compareTo(b.roleLevel); break;
          case 'branch':     cmp = (a.branchName ?? '').compareTo(b.branchName ?? ''); break;
          case 'status':     cmp = a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1); break;
          default:           cmp = 0;
        }
        if (cmp != 0) return s.ascending ? cmp : -cmp;
      }
      return 0;
    });

    return list;
  }

  void _toggleSort(String column) {
    setState(() {
      final idx = _sorts.indexWhere((s) => s.column == column);
      if (idx >= 0) {
        final existing = _sorts[idx];
        if (!existing.ascending) {
          _sorts.removeAt(idx);
        } else {
          _sorts[idx] = existing.toggle();
        }
      } else {
        _sorts = [_SortConfig(column, true), ..._sorts.take(2)];
      }
    });
  }

  void _openSortDialog() {
    showDialog(
      context: context,
      builder: (_) => _SortDialog(
        sorts: _sorts,
        onChanged: (s) => setState(() => _sorts = s),
      ),
    );
  }

  void _openColumnDialog() {
    showDialog(
      context: context,
      builder: (_) => _ColumnChooserDialog(
        visible: _visibleColumns,
        onChanged: (cols) => setState(() => _visibleColumns = cols),
      ),
    );
  }

  Future<void> _openExportDialog(List<EmployeeRecord> allData, List<EmployeeRecord> filtered) async {
    final cols = _allColumns.map((c) =>
      ExportColumnDef(key: c.$1, label: c.$2, defaultSelected: _visibleColumns.contains(c.$1))
    ).toList();

    final req = await showExportDialog(
      context: context,
      columns: cols,
      totalCount: allData.length,
      filteredCount: filtered.length,
      selectedCount: _selectedIds.length,
      title: 'Export Employees',
    );
    if (req == null || !mounted) return;

    final params = <String>[];
    if (req.scope == ExportScope.selected) params.add('ids=${_selectedIds.join(',')}');
    final ext = req.format == ExportFormat.xlsx ? 'xlsx' : 'csv';
    final filename = 'employees_export.$ext';
    try {
      await ApiService().downloadFile(
        '/employees/export?${params.join('&')}',
        filename,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showInactive = ref.watch(_showInactiveProvider);
    final showHidden   = ref.watch(_showHiddenProvider);
    final employeesAsy = ref.watch(_employeesProvider((inactive: showInactive, hidden: showHidden)));
    final currentUser  = ref.watch(authNotifierProvider).valueOrNull;
    final role         = currentUser?.role ?? '';
    final hasEmployee  = currentUser?.employee != null || currentUser?.isSuperAdmin == true || currentUser?.isSchoolOwner == true;
    final canEdit      = role == 'super_admin' || role == 'school_owner' || role == 'principal' || role == 'vp' || role == 'head_teacher';

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await context.push('/employees/new');
                if (result == true) ref.invalidate(_employeesProvider);
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Employee'),
            ).animate().scale(delay: 300.ms)
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Warning Banner ──────────────────────────────────
          if (!hasEmployee && currentUser != null)
            _NoProfileBanner(onAdd: () async {
              final result = await context.push('/employees/new');
              if (result == true) ref.invalidate(_employeesProvider);
            }),

          // ── Toolbar ─────────────────────────────────────────
          _Toolbar(
            searchCtrl: _searchCtrl,
            onSearch: (v) => setState(() => _searchText = v),
            filterRules: _filterRules,
            filterLogic: _filterLogic,
            sorts: _sorts,
            visibleColumns: _visibleColumns,
            showInactive: showInactive,
            showHidden: showHidden,
            selectedBranchId: _selectedBranchId,
            onBranchChanged: (v) => setState(() => _selectedBranchId = v),
            onFilterChanged: (rules) => setState(() => _filterRules = rules),
            onFilterLogicChanged: (l) => setState(() => _filterLogic = l),
            onSortTap: _openSortDialog,
            onColumnsTap: _openColumnDialog,
            onExportTap: () => employeesAsy.whenData((all) {
              final filtered = _applyLocalFilters(all);
              _openExportDialog(all, filtered);
            }),
            onToggleInactive: (v) => ref.read(_showInactiveProvider.notifier).state = v,
            onToggleHidden: (v) => ref.read(_showHiddenProvider.notifier).state = v,
          ),

          // ── Table ────────────────────────────────────────────
          Expanded(
            child: employeesAsy.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (allEmployees) {
                final filtered = _applyLocalFilters(allEmployees);
                return Column(
                  children: [
                    // Stats bar
                    _StatsBar(
                      total: allEmployees.length,
                      filtered: filtered.length,
                      selected: _selectedIds.length,
                      activeFilters: _filterRules.where((r) => r.enabled).length,
                    ),
                    Expanded(
                      child: _EmployeeTable(
                        employees: filtered,
                        allEmployees: allEmployees,
                        selectedIds: _selectedIds,
                        visibleColumns: _visibleColumns,
                        sorts: _sorts,
                        canEdit: canEdit,
                        onSelectionChanged: (ids) => setState(() {
                          _selectedIds.clear();
                          _selectedIds.addAll(ids);
                        }),
                        onSortColumn: _toggleSort,
                        onEdit: (e) async {
                          final result = await context.push('/employees/${e.id}');
                          if (result == true) ref.invalidate(_employeesProvider);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Bar ─────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final int total, filtered, selected, activeFilters;
  const _StatsBar({required this.total, required this.filtered, required this.selected, required this.activeFilters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: AppTheme.grey50,
      child: Row(children: [
        _Stat('Total', total, AppTheme.primary),
        const SizedBox(width: 16),
        _Stat('Showing', filtered, AppTheme.secondary),
        if (selected > 0) ...[
          const SizedBox(width: 16),
          _Stat('Selected', selected, AppTheme.accent),
        ],
        if (activeFilters > 0) ...[
          const SizedBox(width: 16),
          _Stat('Filters', activeFilters, AppTheme.warning),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Stat(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text('$label: ', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
    Text('$count', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey800)),
  ]);
}

// ── No Profile Banner ─────────────────────────────────────────
class _NoProfileBanner extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoProfileBanner({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3E0),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Your account is not linked to an employee profile. Add yourself to create workflow requests.',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5D4037)),
        )),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onAdd,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE65100), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          child: Text('Add My Profile', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────
class _Toolbar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final List<FilterRule> filterRules;
  final FilterLogic filterLogic;
  final List<_SortConfig> sorts;
  final List<String> visibleColumns;
  final bool showInactive, showHidden;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<List<FilterRule>> onFilterChanged;
  final ValueChanged<FilterLogic> onFilterLogicChanged;
  final VoidCallback onSortTap, onColumnsTap, onExportTap;
  final ValueChanged<bool> onToggleInactive, onToggleHidden;

  const _Toolbar({
    required this.searchCtrl, required this.onSearch,
    required this.filterRules, required this.filterLogic,
    required this.sorts, required this.visibleColumns,
    required this.showInactive, required this.showHidden,
    required this.selectedBranchId, required this.onBranchChanged,
    required this.onFilterChanged, required this.onFilterLogicChanged,
    required this.onSortTap, required this.onColumnsTap, required this.onExportTap,
    required this.onToggleInactive, required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilters = filterRules.where((r) => r.enabled).length;
    final activeSorts   = sorts.length;

    final currentUser = ref.watch(authNotifierProvider).valueOrNull;
    final schoolId    = currentUser?.schoolId ?? currentUser?.employee?.schoolId;
    final branches    = ref.watch(branchesProvider(schoolId)).valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.grey200)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Branch dropdown
          SizedBox(
            width: 160,
            height: 36,
            child: DropdownButtonFormField<String>(
              value: selectedBranchId,
              isDense: true,
              hint: Text('All Branches', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                filled: true, fillColor: AppTheme.grey50,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Branches', style: GoogleFonts.poppins(fontSize: 12)),
                ),
                ...branches.map((b) => DropdownMenuItem<String>(
                  value: b['id'] as String?,
                  child: Text(
                    b['name'] as String? ?? '',
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
              onChanged: onBranchChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Search
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearch,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search name, email, ID...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () { searchCtrl.clear(); onSearch(''); },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                  filled: true, fillColor: AppTheme.grey50,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button
          AdvancedFilter(
            compact: true,
            fields: _buildFilterFields(),
            rules: filterRules,
            logic: filterLogic,
            onRulesChanged: onFilterChanged,
            onLogicChanged: onFilterLogicChanged,
          ),
          const SizedBox(width: 6),
          // Sort button
          _ToolBtn(
            icon: Icons.sort_rounded,
            label: 'Sort',
            badge: activeSorts > 0 ? activeSorts : null,
            onTap: onSortTap,
            active: activeSorts > 0,
          ),
          const SizedBox(width: 6),
          // Columns button
          _ToolBtn(icon: Icons.view_column_rounded, label: 'Columns', onTap: onColumnsTap),
          const SizedBox(width: 6),
          // Export button
          _ToolBtn(icon: Icons.download_rounded, label: 'Export', onTap: onExportTap, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          // Bulk upload
          _ToolBtn(
            icon: Icons.upload_file_rounded,
            label: 'Bulk Upload',
            onTap: () => context.push('/employees/bulk-upload'),
          ),
        ]),
        // Toggles row
        const SizedBox(height: 6),
        Row(children: [
          _Toggle('Show Inactive', showInactive, onToggleInactive),
          const SizedBox(width: 12),
          _Toggle('Show Hidden', showHidden, onToggleHidden),
          if (activeFilters > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Text('$activeFilters active filter${activeFilters > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final bool active;
  final Color? color;
  const _ToolBtn({required this.icon, required this.label, required this.onTap, this.badge, this.active = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? AppTheme.primary : AppTheme.grey700);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? c : AppTheme.grey300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: c)),
          if (badge != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
              child: Text('$badge', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Transform.scale(scale: 0.75, child: Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primary)),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
    ]);
  }
}

// ── Employee Table ─────────────────────────────────────────────
class _EmployeeTable extends StatelessWidget {
  final List<EmployeeRecord> employees;
  final List<EmployeeRecord> allEmployees;
  final Set<String> selectedIds;
  final List<String> visibleColumns;
  final List<_SortConfig> sorts;
  final bool canEdit;
  final ValueChanged<Set<String>> onSelectionChanged;
  final ValueChanged<String> onSortColumn;
  final ValueChanged<EmployeeRecord> onEdit;

  const _EmployeeTable({
    required this.employees,
    required this.allEmployees,
    required this.selectedIds,
    required this.visibleColumns,
    required this.sorts,
    required this.canEdit,
    required this.onSelectionChanged,
    required this.onSortColumn,
    required this.onEdit,
  });

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

  DataColumn2 _sortableCol(String key, String label, {double? fixedWidth, ColumnSize size = ColumnSize.S}) {
    final sortIdx = sorts.indexWhere((s) => s.column == key);
    final isSorted = sortIdx >= 0;
    final asc = isSorted && sorts[sortIdx].ascending;
    return DataColumn2(
      fixedWidth: fixedWidth,
      size: size,
      onSort: (_, __) => onSortColumn(key),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600))),
        if (isSorted) ...[
          const SizedBox(width: 2),
          Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: AppTheme.primary),
          if (sorts.length > 1)
            Text('${sortIdx + 1}', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build columns based on visibleColumns order
    final cols = <DataColumn2>[
      // Always: Name
      _sortableCol('name', 'Employee', size: ColumnSize.L),
    ];
    for (final colKey in visibleColumns) {
      if (colKey == 'name') continue;
      switch (colKey) {
        case 'employeeId':  cols.add(_sortableCol('employeeId',  'Emp ID',       fixedWidth: 90)); break;
        case 'role':        cols.add(_sortableCol('roleLevel',   'Role / Level', fixedWidth: 160)); break;
        case 'branch':      cols.add(_sortableCol('branch',      'Branch',       fixedWidth: 120)); break;
        case 'phone':       cols.add(const DataColumn2(label: Text('Phone'), fixedWidth: 120)); break;
        case 'email':       cols.add(const DataColumn2(label: Text('Email'), size: ColumnSize.M)); break;
        case 'manager':     cols.add(const DataColumn2(label: Text('Manager'), fixedWidth: 120)); break;
        case 'permissions': cols.add(const DataColumn2(label: Text('Perms'), fixedWidth: 80)); break;
        case 'status':      cols.add(_sortableCol('status', 'Status', fixedWidth: 80)); break;
      }
    }
    // Always last: Actions
    cols.add(const DataColumn2(label: Text(''), fixedWidth: 80));

    return DataTable2(
      columnSpacing: 10,
      horizontalMargin: 16,
      minWidth: 600,
      showCheckboxColumn: true,
      headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
      headingCheckboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppTheme.primary : null),
      ),
      datarowCheckboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppTheme.primary : null),
      ),
      onSelectAll: (val) {
        final newSet = val == true ? employees.map((e) => e.id).toSet() : <String>{};
        onSelectionChanged(newSet);
      },
      columns: cols,
      rows: employees.map((e) {
        final color = _levelColor(e.roleLevel);
        final isSel = selectedIds.contains(e.id);
        final cells = <DataCell>[
          // Name
          DataCell(Row(children: [
            _EmpAvatar(url: e.photoUrl, name: e.fullName, color: color),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.fullName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                Text(e.email,    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500), overflow: TextOverflow.ellipsis),
              ],
            )),
          ])),
        ];

        for (final colKey in visibleColumns) {
          if (colKey == 'name') continue;
          switch (colKey) {
            case 'employeeId':
              cells.add(DataCell(Text(e.employeeId, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600))));
              break;
            case 'role':
              cells.add(DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Flexible(child: Text(e.roleName, style: GoogleFonts.poppins(fontSize: 11), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('L${e.roleLevel}', style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
                ),
              ])));
              break;
            case 'branch':
              cells.add(DataCell(Text(e.branchName ?? '—', style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis)));
              break;
            case 'phone':
              cells.add(DataCell(Text(e.phone ?? '—', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600))));
              break;
            case 'email':
              cells.add(DataCell(Text(e.email, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600), overflow: TextOverflow.ellipsis)));
              break;
            case 'manager':
              cells.add(DataCell(Text(e.managerName ?? '—', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600), overflow: TextOverflow.ellipsis)));
              break;
            case 'permissions':
              cells.add(DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                _PermIcon(icon: Icons.check_circle, active: e.canApprove, tooltip: 'Can Approve'),
                const SizedBox(width: 4),
                _PermIcon(icon: Icons.upload_file,  active: e.canUploadBulk, tooltip: 'Bulk Upload'),
              ])));
              break;
            case 'status':
              cells.add(DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: e.isActive ? AppTheme.statusGreen.withOpacity(0.1) : AppTheme.grey200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(e.isActive ? 'Active' : 'Inactive', style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: e.isActive ? AppTheme.statusGreen : AppTheme.grey600)),
              )));
              break;
          }
        }

        // Actions cell — always last
        cells.add(DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          if (canEdit)
            Tooltip(
              message: 'Edit',
              child: InkWell(
                onTap: () => onEdit(e),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primary),
                ),
              ),
            ),
        ])));

        return DataRow2(
          selected: isSel,
          onSelectChanged: (v) {
            final newSet = Set<String>.from(selectedIds);
            if (v == true) newSet.add(e.id); else newSet.remove(e.id);
            onSelectionChanged(newSet);
          },
          color: WidgetStateProperty.all(isSel ? AppTheme.primary.withOpacity(0.04) : (e.isActive ? Colors.white : AppTheme.grey50)),
          cells: cells,
        );
      }).toList(),
    );
  }
}

// ── Sort Dialog ────────────────────────────────────────────────
class _SortDialog extends StatefulWidget {
  final List<_SortConfig> sorts;
  final ValueChanged<List<_SortConfig>> onChanged;
  const _SortDialog({required this.sorts, required this.onChanged});

  @override
  State<_SortDialog> createState() => _SortDialogState();
}

class _SortDialogState extends State<_SortDialog> {
  late List<_SortConfig> _draft;

  static const _cols = [
    ('name',       'Employee Name'),
    ('employeeId', 'Employee ID'),
    ('roleLevel',  'Role Level'),
    ('branch',     'Branch'),
    ('status',     'Status'),
  ];

  @override
  void initState() {
    super.initState();
    _draft = List.from(widget.sorts);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sort_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Multi-Sort', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            if (_draft.isNotEmpty)
              TextButton(onPressed: () => setState(() => _draft = []), child: Text('Clear', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500))),
          ]),
          const SizedBox(height: 4),
          Text('Click a column header to quick-sort. Use this dialog for multi-level sorting.',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
          const SizedBox(height: 16),
          ..._draft.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                Text('${i + 1}.', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: s.column,
                      isDense: true,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey900),
                      items: _cols.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2))).toList(),
                      onChanged: (v) => setState(() => _draft[i] = _draft[i].copyWith(column: v)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _draft[i] = _draft[i].toggle()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(s.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(s.ascending ? 'Asc' : 'Desc', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => setState(() => _draft.removeAt(i)),
                  icon: const Icon(Icons.close, size: 14),
                  color: AppTheme.grey400,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                ),
              ]),
            );
          }),
          if (_draft.length < 3)
            OutlinedButton.icon(
              onPressed: () => setState(() => _draft.add(_SortConfig('name', true))),
              icon: const Icon(Icons.add, size: 14),
              label: Text('Add sort level', style: GoogleFonts.poppins(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)),
            ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () { widget.onChanged(_draft); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: Text('Apply', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── Column Chooser Dialog ──────────────────────────────────────
class _ColumnChooserDialog extends StatefulWidget {
  final List<String> visible;
  final ValueChanged<List<String>> onChanged;
  const _ColumnChooserDialog({required this.visible, required this.onChanged});

  @override
  State<_ColumnChooserDialog> createState() => _ColumnChooserDialogState();
}

class _ColumnChooserDialogState extends State<_ColumnChooserDialog> {
  // All optional columns in their current display order: (key, label, visible)
  late List<(String, String, bool)> _cols;

  @override
  void initState() {
    super.initState();
    final visSet = widget.visible.toSet();
    final orderedVisible = widget.visible
        .where((k) => k != 'name')
        .map((k) {
          final match = _allColumns.where((c) => c.$1 == k);
          return match.isNotEmpty ? match.first : (k, k);
        })
        .toList();
    final hidden = _allColumns
        .where((c) => c.$1 != 'name' && !visSet.contains(c.$1))
        .toList();
    _cols = [
      ...orderedVisible.map((c) => (c.$1, c.$2, true)),
      ...hidden.map((c) => (c.$1, c.$2, false)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.view_column_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Choose Columns', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _cols = _cols.map((c) => (c.$1, c.$2, true)).toList()),
                child: Text('All', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ),
              TextButton(
                onPressed: () => setState(() => _cols = _cols.map((c) => (c.$1, c.$2, false)).toList()),
                child: Text('Reset', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 16)),
            ]),
          ),
          // Fixed: Name column (always visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primary.withOpacity(0.04),
            child: Row(children: [
              const Icon(Icons.lock_rounded, size: 14, color: AppTheme.grey400),
              const SizedBox(width: 10),
              Text('Employee Name', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey500)),
              const Spacer(),
              Text('Always visible', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey400, fontStyle: FontStyle.italic)),
            ]),
          ),
          const Divider(height: 1),
          // Reorderable list
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              onReorder: (old, newIdx) {
                setState(() {
                  if (newIdx > old) newIdx--;
                  final item = _cols.removeAt(old);
                  _cols.insert(newIdx, item);
                });
              },
              itemCount: _cols.length,
              itemBuilder: (_, i) {
                final col = _cols[i];
                return ListTile(
                  key: ValueKey(col.$1),
                  dense: true,
                  leading: Checkbox(
                    value: col.$3,
                    onChanged: (v) => setState(() => _cols[i] = (col.$1, col.$2, v ?? false)),
                    activeColor: AppTheme.primary,
                  ),
                  title: Text(col.$2, style: GoogleFonts.poppins(fontSize: 13, color: col.$3 ? AppTheme.grey900 : AppTheme.grey400)),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator_rounded, color: AppTheme.grey400, size: 18),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  final visible = ['name', ..._cols.where((c) => c.$3).map((c) => c.$1)];
                  widget.onChanged(visible);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                child: Text('Apply', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────
class _EmpAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final Color color;
  const _EmpAvatar({this.url, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(radius: 18, backgroundImage: NetworkImage(url!));
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'E',
        style: GoogleFonts.poppins(color: color, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PermIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  const _PermIcon({required this.icon, required this.active, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Icon(icon, size: 14, color: active ? AppTheme.statusGreen : AppTheme.grey300),
  );
}
