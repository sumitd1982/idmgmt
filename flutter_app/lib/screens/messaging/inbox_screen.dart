// ============================================================
// Messaging / Inbox Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────
final inboxProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final resp = await ApiService().get('/messaging');
  return (resp['data'] as List<dynamic>?) ?? [];
});

// ── Screen ────────────────────────────────────────────────────
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _filter = 'Active'; // Active | Closed

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isParent = authState.valueOrNull?.role == 'parent';
    final inboxAsync = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(
             title: const Text('Inbox & Queries'),
             bottom: PreferredSize(
               preferredSize: const Size.fromHeight(48),
               child: Container(
                 alignment: Alignment.centerLeft,
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: Row(
                   children: [
                     _FilterChip('Active', _filter == 'Active', () => setState(() => _filter = 'Active')),
                     const SizedBox(width: 8),
                     _FilterChip('Closed', _filter == 'Closed', () => setState(() => _filter = 'Closed')),
                   ],
                 ),
               ),
             ),
           ),
      body: inboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
        data: (threads) {
          final filtered = threads.where((t) {
            if (_filter == 'Active') return t['status'] != 'closed';
            return t['status'] == 'closed';
          }).toList();

          if (filtered.isEmpty) {
            return _EmptyState(isParent: isParent);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final val = filtered[i];
              return _ThreadCard(
                thread: val,
                isParent: isParent,
                onTap: () => context.push('/messaging/${val['id']}'),
              );
            },
          );
        },
      ),
      floatingActionButton: isParent
          ? FloatingActionButton.extended(
              onPressed: () => _showNewQueryDialog(context),
              icon: const Icon(Icons.edit),
              label: const Text('New Query'),
            )
          : null,
    );
  }

  void _showNewQueryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _NewQueryDialog(),
    ).then((val) {
      if (val == true) {
        ref.invalidate(inboxProvider);
      }
    });
  }
}

// ── New Query Dialog (For Parents) ────────────────────────────
class _NewQueryDialog extends ConsumerStatefulWidget {
  const _NewQueryDialog();

  @override
  ConsumerState<_NewQueryDialog> createState() => _NewQueryDialogState();
}

class _NewQueryDialogState extends ConsumerState<_NewQueryDialog> {
  final _formKey = GlobalKey<FormState>();
  
  List<dynamic> _students = [];
  Map<String, dynamic>? _selectedStudent;
  
  List<dynamic> _employees = [];
  String? _selectedEmployeeId;
  
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final resp = await ApiService().get('/parent/students');
      if (!mounted) return;
      setState(() {
        _students = (resp['data'] as List<dynamic>?) ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadEmployees(String schoolId, String? branchId) async {
    try {
      setState(() => _employees = []);
      final resp = await ApiService().get('/employees', params: {
        'school_id': schoolId,
        if (branchId != null) 'branch_id': branchId,
      });
      if (!mounted) return;
      setState(() {
        _employees = (resp['data'] as List<dynamic>?) ?? [];
      });
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a recipient / teacher')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'school_id':   _selectedStudent!['school_id'],
        'student_id':  _selectedStudent!['id'],
        'employee_id': _selectedEmployeeId,
        'subject':     _subjectCtrl.text.trim(),
        'message':     _msgCtrl.text.trim(),
      };
      await ApiService().post('/messaging', body: body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Query'),
      content: _loading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Student Selection
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(labelText: 'Select Student (Child)'),
                  items: _students.map((s) => DropdownMenuItem(
                    value: s as Map<String, dynamic>,
                    child: Text('${s['first_name']} ${s['last_name']} (${s['class_name']}${s['section']})'),
                  )).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedStudent = v;
                      _selectedEmployeeId = null;
                    });
                    if (v != null) {
                      _loadEmployees(v['school_id'], v['branch_id']);
                    }
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Teacher / Employee Selection
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Send To'),
                  value: _selectedEmployeeId,
                  items: _employees.map((e) => DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text('${e['first_name']} ${e['last_name']} (${e['role_name']})'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedEmployeeId = v),
                  validator: (v) => v == null ? 'Required' : null,
                  disabledHint: const Text('Select a student first'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject / Category'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Your Message'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: Teachers generally reply during school office hours (8AM - 4PM).',
                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _submit, child: _saving ? const SizedBox(width:16, height:16, child:CircularProgressIndicator(strokeWidth: 2)) : const Text('Send')),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
class _ThreadCard extends StatelessWidget {
  final Map<String, dynamic> thread;
  final bool isParent;
  final VoidCallback onTap;

  const _ThreadCard({required this.thread, required this.isParent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(thread['updated_at']).toLocal();
    final timeStr = DateFormat('MMM d, h:mm a').format(dt);
    
    // Determine the name to show
    final otherName = isParent 
       ? 'Teacher: ${thread['emp_first']} ${thread['emp_last']}'
       : 'Parent: ${thread['parent_name']} (${thread['student_first']})';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey200),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: const Icon(Icons.forum_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread['subject'] ?? 'No Subject',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(timeStr, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(otherName, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800)),
                      const Spacer(),
                      if (thread['status'] == 'resolved')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.statusGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('Resolved', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.statusGreen, fontWeight: FontWeight.w600)),
                        )
                      else if (thread['status'] == 'closed')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.grey200, borderRadius: BorderRadius.circular(4)),
                          child: Text('Closed', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey700, fontWeight: FontWeight.w600)),
                        )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? Colors.white : AppTheme.grey800)),
      backgroundColor: selected ? AppTheme.primary : AppTheme.grey100,
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? AppTheme.primary : AppTheme.grey300)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isParent;
  const _EmptyState({required this.isParent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppTheme.grey300),
          const SizedBox(height: 16),
          Text(
            isParent ? 'No active queries' : 'No queries assigned to you',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }
}
