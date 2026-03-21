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
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
  bool _isLoading = false;
  
  // Validation state
  bool _isValidated = false;
  List<dynamic> _previewResults = [];
  int _totalRows = 0;
  int _totalOk = 0;
  int _totalFail = 0;
  bool _canSubmit = false;

  // Effective dates
  DateTime? _startDate;
  DateTime? _endDate;

  final NumberFormat _fmt = NumberFormat('#,###');

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _file = result.files.first;
        _isValidated = false;
        _previewResults = [];
      });
      _validateFile();
    }
  }

  Future<void> _validateFile() async {
    if (_file == null || _file!.bytes == null) return;
    setState(() => _isLoading = true);
    
    try {
      final res = await ApiService().postMultipart(
        '/students/validate-bulk',
        {},
        fileBytes: _file!.bytes!,
        fileName: _file!.name,
      );

      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _isValidated = true;
          _previewResults = res['data']['results'] ?? [];
          _totalOk = res['data']['totalOk'] ?? 0;
          _totalFail = res['data']['totalFail'] ?? 0;
          _totalRows = _previewResults.length;
          _canSubmit = res['data']['canSubmit'] ?? false;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Validation failed'), backgroundColor: AppTheme.error));
        setState(() => _file = null);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      setState(() => _file = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_file == null || _file!.bytes == null || !_canSubmit) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Effective Start Date is required'), backgroundColor: AppTheme.error));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fields = {
        'effective_start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        if (_endDate != null) 'effective_end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
      };
      
      final res = await ApiService().postMultipart(
        '/students/bulk',
        fields,
        fileBytes: _file!.bytes!,
        fileName: _file!.name,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully imported ${res['data']?['inserted'] ?? 0} students'), backgroundColor: AppTheme.statusGreen));
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Upload failed'), backgroundColor: AppTheme.error));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Uses dates from validation result if not empty
  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? (_startDate ?? DateTime.now()));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  void _downloadTemplate() async {
    try {
      final url = '${AppConstants.apiBaseUrl}/students/bulk-template/download';
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch download URL'), backgroundColor: AppTheme.error));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading template: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Bulk Upload Students', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.grey900)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download, size: 16, color: AppTheme.primary),
                  label: Text('Download Template', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            
            // Upload Dropzone
            if (!_isValidated)
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: _isLoading ? null : _pick,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 400,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.grey50,
                        border: Border.all(color: AppTheme.grey300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primary),
                              const SizedBox(height: 16),
                              Text('Click to select XLSX / CSV', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey800, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('Max file size: 20MB', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
                            ],
                          ),
                    ),
                  ),
                ),
              ),

            // Validation Preview
            if (_isValidated) ...[
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(8)),
                     child: Row(
                       children: [
                         const Icon(Icons.file_present, size: 16, color: AppTheme.grey700),
                         const SizedBox(width: 8),
                         Text(_file?.name ?? '', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                         const SizedBox(width: 12),
                         InkWell(
                           onTap: () => setState(() { _isValidated = false; _file = null; }),
                           child: Text('Change File', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, decoration: TextDecoration.underline)),
                         )
                       ],
                     ),
                   ),
                   const Spacer(),
                   _buildStat('Total', _totalRows, AppTheme.grey700),
                   const SizedBox(width: 16),
                   _buildStat('Valid', _totalOk, AppTheme.statusGreen),
                   const SizedBox(width: 16),
                   _buildStat('Errors', _totalFail, AppTheme.error),
                ],
              ),
              const SizedBox(height: 16),
              if (!_canSubmit)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.error.withOpacity(0.3))),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Please fix the errors in your file and re-upload. Submitting is disabled while errors exist.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error))),
                    ],
                  ),
                ),
                
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.grey200), borderRadius: BorderRadius.circular(8)),
                  child: ListView.separated(
                    itemCount: _previewResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = _previewResults[index];
                      final isFail = row['status'] == 'failed';
                      final isWarn = row['status'] == 'warning';
                      final data = row['data'] ?? {};
                      
                      return Container(
                        color: isFail ? AppTheme.error.withOpacity(0.05) : (isWarn ? Colors.orange.withOpacity(0.05) : Colors.transparent),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 40, child: Text('#${row['row']}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600))),
                            Icon(isFail ? Icons.cancel : (isWarn ? Icons.warning : Icons.check_circle), size: 16, color: isFail ? AppTheme.error : (isWarn ? Colors.orange : AppTheme.statusGreen)),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey900)),
                                  Text('${data['stuId'] ?? 'No ID'} • Class ${data['cls'] ?? '?'} ${data['sec'] ?? ''}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (row['errors'] != null && (row['errors'] as List).isNotEmpty)
                                    ...((row['errors'] as List).map((e) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Padding(padding: EdgeInsets.only(top: 2, right: 6), child: Icon(Icons.circle, size: 6, color: AppTheme.error)),
                                      Expanded(child: Text(e.toString(), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error))),
                                    ]))),
                                  if (row['warnings'] != null && (row['warnings'] as List).isNotEmpty)
                                    ...((row['warnings'] as List).map((w) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Padding(padding: EdgeInsets.only(top: 2, right: 6), child: Icon(Icons.circle, size: 6, color: Colors.orange)),
                                      Expanded(child: Text(w.toString(), style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade800))),
                                    ]))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              if (_canSubmit) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.grey50, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.grey200)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Effective Start Date *', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _pickDate(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(border: Border.all(color: AppTheme.grey300), borderRadius: BorderRadius.circular(6), color: Colors.white),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AppTheme.grey600),
                                    const SizedBox(width: 8),
                                    Text(_startDate != null ? DateFormat('MMM dd, yyyy').format(_startDate!) : 'Select Date', style: GoogleFonts.poppins(fontSize: 13, color: _startDate != null ? AppTheme.grey900 : AppTheme.grey500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Effective End Date (Optional)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _pickDate(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(border: Border.all(color: AppTheme.grey300), borderRadius: BorderRadius.circular(6), color: Colors.white),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AppTheme.grey600),
                                    const SizedBox(width: 8),
                                    Text(_endDate != null ? DateFormat('MMM dd, yyyy').format(_endDate!) : 'Select Date', style: GoogleFonts.poppins(fontSize: 13, color: _endDate != null ? AppTheme.grey900 : AppTheme.grey500)),
                                    if (_endDate != null) ...[
                                      const Spacer(),
                                      InkWell(onTap: () => setState(() => _endDate = null), child: const Icon(Icons.close, size: 14)),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isValidated && _canSubmit && _startDate != null && !_isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                    : const Text('Submit Data', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(_fmt.format(count), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
      ],
    );
  }
}

