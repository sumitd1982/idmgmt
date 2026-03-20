// ============================================================
// Student Master Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────
class StudentRecord {
  final String id;
  final String studentId;
  final String firstName;
  final String lastName;
  final String photoUrl;
  final String className;
  final String section;
  final String rollNo;
  final String gender;
  final String status;        // green | blue | red
  final String schoolName;
  final String branchName;

  const StudentRecord({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.photoUrl = '',
    required this.className,
    required this.section,
    required this.rollNo,
    required this.gender,
    required this.status,
    required this.schoolName,
    required this.branchName,
  });

  String get fullName => '$firstName $lastName';

  factory StudentRecord.fromJson(Map<String, dynamic> j) => StudentRecord(
        id:          j['id'] as String,
        studentId:   j['student_id'] as String? ?? '',
        firstName:   j['first_name']  as String? ?? '',
        lastName:    j['last_name']   as String? ?? '',
        photoUrl:    j['photo_url']   as String? ?? '',
        className:   j['class_name']  as String? ?? '',
        section:     j['section']     as String? ?? '',
        rollNo:      j['roll_number'] as String? ?? '',
        gender:      j['gender']     as String? ?? '',
        status:      j['status_color'] as String? ?? AppConstants.statusRed,
        schoolName:  j['school_name'] as String? ?? '',
        branchName:  j['branch_name'] as String? ?? '',
      );

  // Mock factory
  static List<StudentRecord> mockList() => List.generate(25, (i) {
        final statuses = [
          AppConstants.statusGreen,
          AppConstants.statusBlue,
          AppConstants.statusRed
        ];
        final classes  = ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
                          'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'];
        final sections = ['A', 'B', 'C'];
        final names    = [
          ['Arjun', 'Kumar'],   ['Priya', 'Sharma'],  ['Ravi', 'Patel'],
          ['Sneha', 'Reddy'],   ['Mohan', 'Singh'],   ['Anita', 'Gupta'],
          ['Rahul', 'Verma'],   ['Kavya', 'Nair'],    ['Suresh', 'Iyer'],
          ['Divya', 'Menon'],   ['Kiran', 'Joshi'],   ['Pooja', 'Rao'],
          ['Amit', 'Deshpande'],['Sanya', 'Malhotra'],['Vikram', 'Bansal'],
        ];
        final n = names[i % names.length];
        return StudentRecord(
          id:         'std_$i',
          studentId:  'STU${(1000 + i).toString()}',
          firstName:  n[0],
          lastName:   n[1],
          className:  classes[i % classes.length],
          section:    sections[i % sections.length],
          rollNo:     '${(i + 1).toString().padLeft(2, '0')}',
          gender:     i.isEven ? 'Male' : 'Female',
          status:     statuses[i % statuses.length],
          schoolName: 'Green Valley School',
          branchName: 'Main Branch',
        );
      });
}

// ── Providers ─────────────────────────────────────────────────
final _studentFilterProvider = StateProvider<_StudentFilter>(
    (_) => const _StudentFilter());

class _StudentFilter {
  final String? schoolId;
  final String? branchId;
  final String? className;
  final String? section;
  final String? status; // null = all
  final String  search;
  final int     page;
  const _StudentFilter({
    this.schoolId,
    this.branchId,
    this.className,
    this.section,
    this.status,
    this.search = '',
    this.page   = 1,
  });

  _StudentFilter copyWith({
    String?  schoolId,
    String?  branchId,
    String?  className,
    String?  section,
    String?  status,
    String?  search,
    int?     page,
    bool clearStatus = false,
  }) =>
      _StudentFilter(
        schoolId:  schoolId  ?? this.schoolId,
        branchId:  branchId  ?? this.branchId,
        className: className ?? this.className,
        section:   section   ?? this.section,
        status:    clearStatus ? null : (status ?? this.status),
        search:    search    ?? this.search,
        page:      page      ?? this.page,
      );
}

final _studentsProvider =
    FutureProvider.family<List<StudentRecord>, _StudentFilter>(
        (ref, filter) async {
  try {
    final data = await ApiService().get('/students', params: {
      if (filter.schoolId  != null) 'school_id':    filter.schoolId,
      if (filter.branchId  != null) 'branch_id':    filter.branchId,
      if (filter.className != null) 'class_name':   filter.className,
      if (filter.section   != null) 'section':      filter.section,
      if (filter.status    != null) 'status_color': filter.status,
      if (filter.search.isNotEmpty) 'search':       filter.search,
      'page': filter.page.toString(),
    });
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => StudentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return StudentRecord.mockList();
  }
});

final _selectedStudentsProvider = StateProvider<Set<String>>((_) => {});

// ── Screen ────────────────────────────────────────────────────
class StudentScreen extends ConsumerStatefulWidget {
  const StudentScreen({super.key});

  @override
  ConsumerState<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends ConsumerState<StudentScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter  = ref.watch(_studentFilterProvider);
    final students = ref.watch(_studentsProvider(filter));
    final selected = ref.watch(_selectedStudentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/students/new'),
        icon:  const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ).animate().scale(delay: 300.ms),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter toolbar
            _FilterToolbar(filter: filter, searchCtrl: _searchCtrl),
            const SizedBox(height: 12),

            // Status chips
            _StatusChips(filter: filter),
            const SizedBox(height: 12),

            // Bulk action bar
            if (selected.isNotEmpty)
              _BulkActionBar(selected: selected, students: students.valueOrNull ?? []),

            const SizedBox(height: 4),

            // Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: students.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error:   (e, _) => Center(child: Text('Error: $e')),
                  data:    (list) => _StudentDataTable(
                    students: list,
                    selected: selected,
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

// ── Filter Toolbar ────────────────────────────────────────────
class _FilterToolbar extends ConsumerWidget {
  final _StudentFilter filter;
  final TextEditingController searchCtrl;
  const _FilterToolbar({required this.filter, required this.searchCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // School
            _DropdownFilter(
              hint:  'All Schools',
              value: null,
              items: const ['Green Valley School', 'Blue Ridge School'],
              onChanged: (_) {},
            ),
            // Branch
            _DropdownFilter(
              hint:  'All Branches',
              value: null,
              items: const ['Main Branch', 'East Campus', 'West Campus'],
              onChanged: (_) {},
            ),
            // Class
            _DropdownFilter(
              hint:  'All Classes',
              value: null,
              items: List.generate(10, (i) => 'Class ${i + 1}'),
              onChanged: (_) {},
            ),
            // Section
            _DropdownFilter(
              hint:  'All Sections',
              value: null,
              items: const ['A', 'B', 'C', 'D'],
              onChanged: (_) {},
            ),
            // Search
            SizedBox(
              width: 240,
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText:    'Search name, ID...',
                  prefixIcon:  const Icon(Icons.search, size: 18),
                  suffixIcon:  searchCtrl.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchCtrl.clear();
                            ref
                                .read(_studentFilterProvider.notifier)
                                .state = ref
                                .read(_studentFilterProvider)
                                .copyWith(search: '');
                          },
                          icon: const Icon(Icons.close, size: 16))
                      : null,
                  isDense:     true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onChanged: (v) {
                  ref.read(_studentFilterProvider.notifier).state =
                      ref.read(_studentFilterProvider).copyWith(search: v);
                },
              ),
            ),
            // Bulk upload
            OutlinedButton.icon(
              onPressed: () => _showBulkUploadDialog(context),
              icon:  const Icon(Icons.upload_file, size: 16),
              label: const Text('Bulk Upload'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _BulkUploadDialog(),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value:       value,
        hint:        Text(hint, style: GoogleFonts.poppins(fontSize: 12)),
        isDense:     true,
        decoration:  const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(fontSize: 12))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Status Chips ──────────────────────────────────────────────
class _StatusChips extends ConsumerWidget {
  final _StudentFilter filter;
  const _StatusChips({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = [
      ('All',      null,                        AppTheme.primary,       Icons.list),
      ('Verified', AppConstants.statusGreen,    AppTheme.statusGreen,   Icons.check_circle),
      ('Changed',  AppConstants.statusBlue,     AppTheme.statusBlue,    Icons.sync),
      ('Pending',  AppConstants.statusRed,      AppTheme.statusRed,     Icons.cancel),
    ];

    return Row(
      children: chips.map((c) {
        final (label, status, color, icon) = c;
        final isActive = filter.status == status;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isActive ? Colors.white : color),
                const SizedBox(width: 4),
                Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isActive ? Colors.white : color,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
            selected:          isActive,
            selectedColor:     color,
            backgroundColor:   color.withOpacity(0.08),
            checkmarkColor:    Colors.white,
            showCheckmark:     false,
            side:              BorderSide(color: color.withOpacity(0.3)),
            onSelected: (_) {
              ref.read(_studentFilterProvider.notifier).state = status == null
                  ? filter.copyWith(clearStatus: true)
                  : filter.copyWith(status: status);
            },
          ),
        );
      }).toList(),
    );
  }
}

// ── Bulk Action Bar ───────────────────────────────────────────
class _BulkActionBar extends StatelessWidget {
  final Set<String> selected;
  final List<StudentRecord> students;
  const _BulkActionBar({required this.selected, required this.students});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text('${selected.length} selected',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontSize: 13)),
          const Spacer(),
          _BulkBtn(
            icon:  Icons.send,
            label: 'Send Links',
            color: AppTheme.primary,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _BulkBtn(
            icon:  Icons.download,
            label: 'Download',
            color: AppTheme.secondary,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _BulkBtn(
            icon:  Icons.delete_outline,
            label: 'Delete',
            color: AppTheme.error,
            onTap: () {},
          ),
        ],
      ),
    ).animate().slideY(begin: -0.5, duration: 200.ms);
  }
}

class _BulkBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BulkBtn({
    required this.icon,
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: GoogleFonts.poppins(fontSize: 12),
        minimumSize: Size.zero,
      ),
      icon:  Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

// ── Student DataTable ─────────────────────────────────────────
class _StudentDataTable extends ConsumerStatefulWidget {
  final List<StudentRecord> students;
  final Set<String> selected;
  const _StudentDataTable({required this.students, required this.selected});

  @override
  ConsumerState<_StudentDataTable> createState() => _StudentDataTableState();
}

class _StudentDataTableState extends ConsumerState<_StudentDataTable> {
  bool _sortAscending = true;
  int  _sortColumn    = 0;

  Color _rowColor(String status) {
    switch (status) {
      case AppConstants.statusGreen:
        return AppTheme.statusGreen.withOpacity(0.04);
      case AppConstants.statusBlue:
        return AppTheme.statusBlue.withOpacity(0.04);
      default:
        return AppTheme.statusRed.withOpacity(0.04);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = widget.selected.length == widget.students.length &&
        widget.students.isNotEmpty;

    return DataTable2(
      columnSpacing:  12,
      horizontalMargin: 16,
      minWidth:       700,
      headingRowColor: WidgetStateProperty.all(AppTheme.grey100),
      sortColumnIndex: _sortColumn,
      sortAscending:  _sortAscending,
      columns: [
        DataColumn2(
          label: Checkbox(
            value:         allSelected,
            tristate:      true,
            onChanged: (_) {
              final notifier = ref.read(_selectedStudentsProvider.notifier);
              if (allSelected) {
                notifier.state = {};
              } else {
                notifier.state = widget.students.map((s) => s.id).toSet();
              }
            },
          ),
          fixedWidth: 48,
        ),
        const DataColumn2(label: Text('Photo'), fixedWidth: 60),
        DataColumn2(
          label:    const Text('Name'),
          onSort: (col, asc) => setState(() {
            _sortColumn    = col;
            _sortAscending = asc;
          }),
        ),
        const DataColumn2(label: Text('Student ID'), fixedWidth: 110),
        const DataColumn2(label: Text('Class / Sec'), fixedWidth: 100),
        const DataColumn2(label: Text('Roll No'),     fixedWidth: 80),
        const DataColumn2(label: Text('Gender'),      fixedWidth: 80),
        const DataColumn2(label: Text('Status'),      fixedWidth: 110),
        const DataColumn2(label: Text('Actions'),     fixedWidth: 100),
      ],
      rows: widget.students.map((s) {
        final isSelected = widget.selected.contains(s.id);
        return DataRow2(
          color: WidgetStateProperty.all(_rowColor(s.status)),
          selected: isSelected,
          onSelectChanged: (_) {
            final notifier = ref.read(_selectedStudentsProvider.notifier);
            final current  = Set<String>.from(notifier.state);
            if (current.contains(s.id)) {
              current.remove(s.id);
            } else {
              current.add(s.id);
            }
            notifier.state = current;
          },
          cells: [
            DataCell(Checkbox(
              value:     isSelected,
              onChanged: (_) {
                final notifier = ref.read(_selectedStudentsProvider.notifier);
                final current  = Set<String>.from(notifier.state);
                if (current.contains(s.id)) {
                  current.remove(s.id);
                } else {
                  current.add(s.id);
                }
                notifier.state = current;
              },
            )),
            DataCell(_StudentAvatar(url: s.photoUrl, name: s.fullName)),
            DataCell(Text(s.fullName,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500))),
            DataCell(Text(s.studentId,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppTheme.grey600))),
            DataCell(Text('${s.className} - ${s.section}',
                style: GoogleFonts.poppins(fontSize: 12))),
            DataCell(Text(s.rollNo,
                style: GoogleFonts.poppins(fontSize: 12))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  s.gender == 'Male' ? Icons.male : Icons.female,
                  size: 14,
                  color: s.gender == 'Male'
                      ? AppTheme.statusBlue
                      : const Color(0xFFE91E8C),
                ),
                const SizedBox(width: 4),
                Text(s.gender,
                    style: GoogleFonts.poppins(fontSize: 12)),
              ],
            )),
            DataCell(_StudentStatusBadge(status: s.status)),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => context.go('/students/${s.id}'),
                  icon:    const Icon(Icons.edit_outlined, size: 16),
                  color:   AppTheme.primary,
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                ),
                IconButton(
                  onPressed: () {},
                  icon:    const Icon(Icons.send_outlined, size: 16),
                  color:   AppTheme.secondary,
                  padding: EdgeInsets.zero,
                  tooltip: 'Send link',
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                ),
              ],
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final String url;
  final String name;
  const _StudentAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius:          16,
      backgroundColor: AppTheme.primary.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: GoogleFonts.poppins(
            color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StudentStatusBadge extends StatelessWidget {
  final String status;
  const _StudentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case AppConstants.statusGreen:
        color = AppTheme.statusGreen;
        label = 'Verified';
        icon  = Icons.check_circle_outline;
        break;
      case AppConstants.statusBlue:
        color = AppTheme.statusBlue;
        label = 'Changed';
        icon  = Icons.sync;
        break;
      default:
        color = AppTheme.statusRed;
        label = 'Pending';
        icon  = Icons.radio_button_unchecked;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
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
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type:           FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _file  = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_file == null) {
      setState(() => _error = 'Please select a file first.');
      return;
    }
    setState(() => _uploading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _uploading = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bulk upload completed successfully!'),
        backgroundColor: AppTheme.statusGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.upload_file, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text('Bulk Upload Students',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload an Excel (.xlsx) or CSV file with student data.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickFile,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _file != null
                        ? AppTheme.statusGreen
                        : AppTheme.grey300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _file != null
                      ? AppTheme.statusGreen.withOpacity(0.05)
                      : AppTheme.grey50,
                ),
                child: _file == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 36, color: AppTheme.grey600),
                          const SizedBox(height: 8),
                          Text('Click to browse or drag & drop',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.grey600)),
                          Text('Supports: .xlsx, .xls, .csv',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppTheme.grey600)),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.description,
                                color: AppTheme.statusGreen, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(_file!.name,
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(
                                    '${(_file!.size / 1024).toStringAsFixed(1)} KB',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppTheme.grey600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _file = null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: GoogleFonts.poppins(
                      color: AppTheme.error, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {},
              icon:  const Icon(Icons.download, size: 16),
              label: const Text('Download sample template'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _upload,
          icon: _uploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload, size: 16),
          label: Text(_uploading ? 'Uploading...' : 'Upload'),
        ),
      ],
    );
  }
}
