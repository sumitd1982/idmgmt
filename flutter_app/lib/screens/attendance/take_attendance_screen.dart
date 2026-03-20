// ============================================================
// Take Attendance Screen (Staff / Teachers)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────
class AttStudent {
  final String id;
  final String name;
  final String? className;
  final String? section;
  String status; // 'present', 'absent', 'late', 'excused'
  String remarks;

  AttStudent({
    required this.id,
    required this.name,
    this.className,
    this.section,
    this.status = 'present',
    this.remarks = '',
  });

  factory AttStudent.fromJson(Map<String, dynamic> j) => AttStudent(
        id:        j['id'] ?? j['student_id'],
        name:      '${j['first_name']} ${j['last_name']} (ID: ${j['student_id']})',
        className: j['class_name'],
        section:   j['section'],
        status:    j['status'] ?? 'present',
        remarks:   j['remarks'] ?? '',
      );
}

// ── Providers ─────────────────────────────────────────────────
final _assignedModulesProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    // In a real scenario, this would filter modules by the logged-in user's roles.
    // E.g., only return tracking modules they are assigned to.
    final res = await ApiService().get('/attendance/modules');
    return (res['data'] as List<dynamic>?)?.where((m) => m['is_active'] == 1 || m['is_active'] == true).toList() ?? [];
  } catch (_) { return []; }
});

// ── Screen ────────────────────────────────────────────────────
class TakeAttendanceScreen extends ConsumerStatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  ConsumerState<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends ConsumerState<TakeAttendanceScreen> {
  String? _selectedModuleId;
  DateTime _selectedDate = DateTime.now();
  List<AttStudent> _students = [];
  bool _loadingStudents = false;
  bool _saving = false;

  Future<void> _loadStudents() async {
    if (_selectedModuleId == null) return;
    setState(() => _loadingStudents = true);
    try {
      // 1. Fetch the students for this module
      // Note: for daily_class, the API should fetch from students table directly.
      // For custom modules, fetch from /attendance/modules/:id/students.
      // We will assume the backend handles returning the correct roster based on module type via history or direct pull.
      
      // Let's first check if there is history for today
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final histRes = await ApiService().get('/attendance/history', params: {
        'module_id': _selectedModuleId,
        'date':      dateStr
      });
      
      final history = histRes['data'] as List<dynamic>? ?? [];
      
      if (history.isNotEmpty) {
        // Load from history
        // The history route currently doesn't join first_name/last_name of the student, 
        // but for now we expect the backend to return full student details.
        // Assuming backend gets updated to return full student details.
        setState(() {
          _students = history.map((e) => AttStudent.fromJson(e)).toList();
          _loadingStudents = false;
        });
      } else {
        // No history today. Load fresh roster.
        final rosterRes = await ApiService().get('/attendance/modules/$_selectedModuleId/students');
        setState(() {
          _students = (rosterRes['data'] as List<dynamic>?)?.map((e) => AttStudent.fromJson(e)).toList() ?? [];
          _loadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStudents = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading roster: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_selectedModuleId == null || _students.isEmpty) return;
    setState(() => _saving = true);
    try {
      final records = _students.map((s) => {
        'student_id': s.id,
        'status':     s.status,
        'remarks':    s.remarks,
      }).toList();

      await ApiService().post('/attendance/record', body: {
        'module_id': _selectedModuleId,
        'date':      DateFormat('yyyy-MM-dd').format(_selectedDate),
        'records':   records
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully!'), backgroundColor: AppTheme.statusGreen),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var s in _students) {
        s.status = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(_assignedModulesProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Take Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Toolbar filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 16, runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Module Selector
                SizedBox(
                  width: 300,
                  child: modulesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading modules: $e'),
                    data: (modules) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Select Module / Class'),
                      value: _selectedModuleId,
                      items: modules.map((m) => DropdownMenuItem<String>(
                        value: m['id'], 
                        child: Text('${m['name']} (${m['type']})'),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _selectedModuleId = v);
                        _loadStudents();
                      },
                    ),
                  ),
                ),
                // Date Selector
                SizedBox(
                  width: 200,
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate:  DateTime.now(),
                      );
                      if (d != null) {
                        setState(() => _selectedDate = d);
                        _loadStudents();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                          const Icon(Icons.calendar_today, size: 16, color: AppTheme.grey600),
                        ],
                      ),
                    ),
                  ),
                ),
                // Quick actions
                if (_students.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () => _markAll('present'), 
                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.statusGreen), 
                    label: const Text('Mark All Present')
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _markAll('absent'), 
                    icon: const Icon(Icons.cancel_outlined, color: AppTheme.error), 
                    label: const Text('Mark All Absent')
                  ),
                ]
              ],
            ),
          ),
          
          // Roster
          Expanded(
            child: _selectedModuleId == null 
              ? const Center(child: Text('Please select a module to take attendance.'))
              : _loadingStudents 
                  ? const Center(child: CircularProgressIndicator())
                  : _students.isEmpty 
                      ? const Center(child: Text('No students found for this module.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final s = _students[i];
                            return _StudentAttRow(
                              student: s,
                              onStatusChanged: (v) => setState(() => s.status = v),
                              onRemarksChanged: (v) => s.remarks = v,
                            );
                          },
                        ),
          ),
        ],
      ),
      bottomNavigationBar: _students.isEmpty ? null : SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Submit Attendance'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentAttRow extends StatelessWidget {
  final AttStudent student;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onRemarksChanged;

  const _StudentAttRow({
    required this.student, 
    required this.onStatusChanged, 
    required this.onRemarksChanged
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch(student.status) {
      case 'present': statusColor = AppTheme.statusGreen; break;
      case 'absent':  statusColor = AppTheme.error; break;
      case 'late':    statusColor = AppTheme.accent; break;
      default:        statusColor = AppTheme.grey600;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      color: statusColor.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withOpacity(0.2),
              child: Text(student.name[0], style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (student.className != null) 
                    Text('${student.className} ${student.section ?? ''}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
                ],
              ),
            ),
            
            // Segmented Control for Status
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'present', label: Text('Present')),
                ButtonSegment(value: 'late',    label: Text('Late')),
                ButtonSegment(value: 'absent',  label: Text('Absent')),
              ],
              selected: {student.status},
              onSelectionChanged: (set) => onStatusChanged(set.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(GoogleFonts.poppins(fontSize: 11)),
              ),
            ),
            
            const SizedBox(width: 16),
            // Remarks
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: student.remarks,
                onChanged: onRemarksChanged,
                decoration: const InputDecoration(
                  hintText: 'Remarks (optional)',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: GoogleFonts.poppins(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
