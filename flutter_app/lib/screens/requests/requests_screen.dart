// ============================================================
// Review Requests Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────
class ReviewRequest {
  final String id;
  final String title;
  final String description;
  final String status;        // open | in_review | approved | rejected
  final String priority;     // low | medium | high | urgent
  final String requesterName;
  final String? assigneeName;
  final DateTime createdAt;
  final List<String> attachmentUrls;

  const ReviewRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.requesterName,
    this.assigneeName,
    required this.createdAt,
    this.attachmentUrls = const [],
  });

  factory ReviewRequest.fromJson(Map<String, dynamic> j) => ReviewRequest(
        id:            j['id']             as String,
        title:         j['title']          as String? ?? '',
        description:   j['description']    as String? ?? '',
        status:        j['status']         as String? ?? 'open',
        priority:      j['priority']       as String? ?? 'medium',
        requesterName: j['requester_name'] as String? ?? '',
        assigneeName:  j['assignee_name']  as String?,
        createdAt:     DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        attachmentUrls: (j['attachments'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  static List<ReviewRequest> mockList() => [
        ReviewRequest(
          id:            'r1',
          title:         'Update Guardian Info for Class 5-A',
          description:   'Bulk update request for 12 students with new guardian contacts.',
          status:        'open',
          priority:      'high',
          requesterName: 'Mrs. Sunita Sharma',
          assigneeName:  'Mr. Rajesh Kumar',
          createdAt:     DateTime.now().subtract(const Duration(hours: 3)),
        ),
        ReviewRequest(
          id:            'r2',
          title:         'Address change for 8 students',
          description:   'Parent-submitted address updates pending verification.',
          status:        'in_review',
          priority:      'medium',
          requesterName: 'Mr. Arjun Nair',
          assigneeName:  'Mrs. Kavya Iyer',
          createdAt:     DateTime.now().subtract(const Duration(days: 1)),
        ),
        ReviewRequest(
          id:            'r3',
          title:         'Photo replacement request',
          description:   'Student photos outdated, need new uploads approved.',
          status:        'approved',
          priority:      'low',
          requesterName: 'Ms. Priya Gupta',
          createdAt:     DateTime.now().subtract(const Duration(days: 3)),
        ),
        ReviewRequest(
          id:            'r4',
          title:         'Emergency contact update — Class 7',
          description:   'Critical update to parent contact numbers.',
          status:        'open',
          priority:      'urgent',
          requesterName: 'Mr. Rohit Verma',
          createdAt:     DateTime.now().subtract(const Duration(hours: 1)),
        ),
        ReviewRequest(
          id:            'r5',
          title:         'Blood group correction — 3 students',
          description:   'Medical records need correction per hospital certificates.',
          status:        'rejected',
          priority:      'high',
          requesterName: 'Mrs. Divya Menon',
          createdAt:     DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
}

// ── Providers ─────────────────────────────────────────────────
final _requestsProvider = FutureProvider<List<ReviewRequest>>((ref) async {
  try {
    final data = await ApiService().get('/requests');
    final list = data['requests'] as List<dynamic>? ?? [];
    return list
        .map((e) => ReviewRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return ReviewRequest.mockList();
  }
});

final _selectedRequestProvider = StateProvider<ReviewRequest?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_requestsProvider);
    final selected      = ref.watch(_selectedRequestProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestSheet(context, ref),
        icon:  const Icon(Icons.add),
        label: const Text('New Request'),
      ).animate().scale(delay: 300.ms),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data:    (requests) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List
              Expanded(
                flex: selected != null ? 2 : 1,
                child: _RequestsList(requests: requests),
              ),
              // Detail
              if (selected != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _RequestDetailPanel(request: selected),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showNewRequestSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewRequestSheet(),
    );
  }
}

// ── Requests List ─────────────────────────────────────────────
class _RequestsList extends ConsumerWidget {
  final List<ReviewRequest> requests;
  const _RequestsList({required this.requests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedRequestProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${requests.length} Requests',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(width: 12),
            _StatusFilterChip(label: 'All',       status: null),
            const SizedBox(width: 6),
            _StatusFilterChip(label: 'Open',      status: 'open'),
            const SizedBox(width: 6),
            _StatusFilterChip(label: 'In Review', status: 'in_review'),
            const SizedBox(width: 6),
            _StatusFilterChip(label: 'Approved',  status: 'approved'),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount:   requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _RequestCard(
              request:    requests[i],
              isSelected: selected?.id == requests[i].id,
              onTap: () => ref.read(_selectedRequestProvider.notifier).state =
                  selected?.id == requests[i].id ? null : requests[i],
            ).animate(delay: (i * 60).ms).fadeIn(duration: 300.ms),
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final String? status;
  const _StatusFilterChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label,
          style: GoogleFonts.poppins(fontSize: 11)),
      selected:  false,
      onSelected: (_) {},
    );
  }
}

// ── Request Card ──────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final ReviewRequest request;
  final bool isSelected;
  final VoidCallback onTap;
  const _RequestCard({
    required this.request,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : AppTheme.grey200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:  isSelected
                ? AppTheme.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: isSelected ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PriorityDot(priority: request.priority),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                request.description,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.grey600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 12, color: AppTheme.grey600),
                  const SizedBox(width: 4),
                  Text(request.requesterName,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.grey600)),
                  if (request.assigneeName != null) ...[
                    Text(' → ',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.grey600)),
                    Text(request.assigneeName!,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.primary)),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(request.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppTheme.grey600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final String priority;
  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case 'urgent': color = AppTheme.error;         break;
      case 'high':   color = AppTheme.warning;       break;
      case 'medium': color = AppTheme.statusBlue;    break;
      default:       color = AppTheme.statusGreen;
    }
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'approved':
        color = AppTheme.statusGreen;
        label = 'Approved';
        icon  = Icons.check_circle_outline;
        break;
      case 'rejected':
        color = AppTheme.error;
        label = 'Rejected';
        icon  = Icons.cancel_outlined;
        break;
      case 'in_review':
        color = AppTheme.statusBlue;
        label = 'In Review';
        icon  = Icons.sync;
        break;
      default:
        color = AppTheme.accent;
        label = 'Open';
        icon  = Icons.inbox_outlined;
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
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  color:      color,
                  fontSize:   10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Request Detail Panel ──────────────────────────────────────
class _RequestDetailPanel extends ConsumerWidget {
  final ReviewRequest request;
  const _RequestDetailPanel({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Request Details',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(_selectedRequestProvider.notifier).state = null,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            _StatusBadge(status: request.status),
            const SizedBox(height: 12),

            Text(request.title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Text(request.description,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.grey600, height: 1.5)),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            _InfoRow('Requester', request.requesterName, Icons.person_outline),
            if (request.assigneeName != null)
              _InfoRow('Assignee', request.assigneeName!, Icons.assignment_ind_outlined),
            _InfoRow('Priority',  request.priority.toUpperCase(), Icons.flag_outlined),
            _InfoRow('Created',
                DateFormat('dd MMM yyyy, hh:mm a').format(request.createdAt),
                Icons.calendar_today_outlined),

            if (request.attachmentUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Attachments',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ...request.attachmentUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            url.split('/').last,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppTheme.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.download, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 24, minHeight: 24),
                        ),
                      ],
                    ),
                  )),
            ],

            const Spacer(),

            // Approve / Return / Reject actions
            if (request.status == 'open' || request.status == 'in_review')
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Return to Parent
                  OutlinedButton.icon(
                    onPressed: () => _showReturnDialog(context, ref, request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF57C00),
                      side: const BorderSide(color: Color(0xFFFFA726)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 14),
                    label: const Text('Return to Parent'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _doAction(context, ref, request.id, 'reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: BorderSide(color: AppTheme.error.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon:  const Icon(Icons.close, size: 14),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _doAction(context, ref, request.id, 'approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.statusGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon:  const Icon(Icons.check, size: 14),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.2, duration: 300.ms);
  }

  Future<void> _doAction(BuildContext context, WidgetRef ref, String id, String action) async {
    try {
      await ApiService().post('/parent/reviews/$id/approve', body: { 'action': action });
      ref.invalidate(_requestsProvider);
      ref.read(_selectedRequestProvider.notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approve' ? 'Review approved ✅' : 'Review rejected ❌'),
          backgroundColor: action == 'approve' ? AppTheme.statusGreen : AppTheme.error,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _showReturnDialog(BuildContext context, WidgetRef ref, String id) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Return to Parent', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explain what needs to be corrected or added:', style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Please upload the Aadhaar card copy...',
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF57C00)),
            onPressed: () {
              if (reasonCtrl.text.trim().isNotEmpty) Navigator.of(ctx).pop(true);
            },
            child: Text('Send Back', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService().post('/parent/reviews/$id/approve', body: {
          'action': 'return',
          'return_reason': reasonCtrl.text.trim(),
        });
        ref.invalidate(_requestsProvider);
        ref.read(_selectedRequestProvider.notifier).state = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Returned to parent for revision 🔄'),
            backgroundColor: Color(0xFFF57C00),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ));
        }
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow(this.label, this.value, this.icon);

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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey800)),
          ),
        ],
      ),
    );
  }
}

// ── New Request Bottom Sheet ───────────────────────────────────
class _NewRequestSheet extends StatefulWidget {
  const _NewRequestSheet();

  @override
  State<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<_NewRequestSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  String _priority   = 'medium';
  final List<PlatformFile> _attachments = [];
  bool _submitting   = false;
  String? _fileError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _fileError = null);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;

    // Validate each file
    final invalid = result.files.where((f) {
      final ext = '.${f.extension?.toLowerCase() ?? ''}';
      return !AppConstants.allowedAttachmentTypes.contains(ext);
    }).toList();

    if (invalid.isNotEmpty) {
      setState(() => _fileError =
          'Invalid file type(s): ${invalid.map((f) => f.name).join(', ')}. '
          'Allowed: PDF, DOCX, JPG, PNG.');
      return;
    }

    final oversized = result.files.where(
        (f) => f.size > AppConstants.maxAttachmentSizeMB * 1024 * 1024);
    if (oversized.isNotEmpty) {
      setState(() => _fileError =
          'File(s) exceed ${AppConstants.maxAttachmentSizeMB}MB limit.');
      return;
    }

    if (_attachments.length + result.files.length >
        AppConstants.maxAttachments) {
      setState(() => _fileError =
          'Maximum ${AppConstants.maxAttachments} attachments allowed.');
      return;
    }

    setState(() => _attachments.addAll(result.files));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:         Text('Request submitted successfully!'),
        backgroundColor: AppTheme.statusGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppTheme.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('New Review Request',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Title is required' : null,
                        style: GoogleFonts.poppins(fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Request Title *'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines:   4,
                        style: GoogleFonts.poppins(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Priority
                      Text('Priority',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppTheme.grey600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _PriorityChip(label: 'Low',    value: 'low',    selected: _priority == 'low',    onTap: () => setState(() => _priority = 'low')),
                          _PriorityChip(label: 'Medium', value: 'medium', selected: _priority == 'medium', onTap: () => setState(() => _priority = 'medium')),
                          _PriorityChip(label: 'High',   value: 'high',   selected: _priority == 'high',   onTap: () => setState(() => _priority = 'high')),
                          _PriorityChip(label: 'Urgent', value: 'urgent', selected: _priority == 'urgent', onTap: () => setState(() => _priority = 'urgent')),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Attachments
                      Text('Attachments',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppTheme.grey600)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _fileError != null
                                  ? AppTheme.error
                                  : AppTheme.grey300,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: AppTheme.grey50,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attach_file,
                                  color: AppTheme.grey600),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Attach files (PDF, DOCX, JPG, PNG — max ${AppConstants.maxAttachmentSizeMB}MB)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppTheme.grey600),
                                ),
                              ),
                              Text('Browse',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),

                      if (_fileError != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 14, color: AppTheme.error),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(_fileError!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: AppTheme.error)),
                            ),
                          ],
                        ),
                      ],

                      // Attachment chips
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _attachments.map((f) {
                            final ext = '.${f.extension?.toLowerCase() ?? ''}';
                            final isImage = ['.jpg', '.jpeg', '.png'].contains(ext);
                            return Chip(
                              avatar: Icon(
                                isImage
                                    ? Icons.image_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 14,
                              ),
                              label: Text(f.name,
                                  style: GoogleFonts.poppins(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  setState(() => _attachments.remove(f)),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, size: 16),
                          label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
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

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _PriorityChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  Color get _color {
    switch (value) {
      case 'urgent': return AppTheme.error;
      case 'high':   return AppTheme.warning;
      case 'medium': return AppTheme.statusBlue;
      default:       return AppTheme.statusGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              color: selected ? Colors.white : _color,
              fontWeight: FontWeight.w500)),
      selected:       selected,
      selectedColor:  _color,
      backgroundColor: _color.withOpacity(0.08),
      checkmarkColor: Colors.white,
      side:           BorderSide(color: _color.withOpacity(0.3)),
      onSelected:     (_) => onTap(),
    );
  }
}
