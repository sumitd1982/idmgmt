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
  return resp['data'] as List<dynamic>;
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
  String? _studentId; // In a full app, fetch parent's students
  String? _subject;
  String? _employeeId; // In a full app, map teachers to students
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _saving = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a recipient / teacher')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Hardcoded student/school for demo, in real app derive from Parent profile
      final body = {
        'school_id':   'TODO_GET_SCHOOL_ID',
        'student_id':  'TODO_GET_CHILD_ID',
        'employee_id': _employeeId,
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
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // MOCK Teacher Selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Send To'),
                items: const [
                  DropdownMenuItem(value: 'EMP_123', child: Text('Class Teacher')),
                  DropdownMenuItem(value: 'EMP_456', child: Text('Transport Admin')),
                ],
                onChanged: (v) => _employeeId = v,
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
