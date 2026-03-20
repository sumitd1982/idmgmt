// ============================================================
// ID Template List Screen
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_provider.dart';

// ── Models ────────────────────────────────────────────────────
class IdTemplate {
  final String id;
  final String schoolId;
  final String? branchId;
  final String name;
  final String templateType;
  final String status;
  final double cardWidthMm;
  final double cardHeightMm;
  final String createdBy;
  final String? submittedBy;
  final String? checkedBy;
  final String? approvedBy;
  final DateTime? submittedAt;
  final DateTime? checkedAt;
  final DateTime? approvedAt;
  final String? checkNotes;
  final String? approvalNotes;
  final int version;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IdTemplate({
    required this.id,
    required this.schoolId,
    this.branchId,
    required this.name,
    required this.templateType,
    required this.status,
    required this.cardWidthMm,
    required this.cardHeightMm,
    required this.createdBy,
    this.submittedBy,
    this.checkedBy,
    this.approvedBy,
    this.submittedAt,
    this.checkedAt,
    this.approvedAt,
    this.checkNotes,
    this.approvalNotes,
    required this.version,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IdTemplate.fromJson(Map<String, dynamic> j) => IdTemplate(
        id:            j['id'] as String,
        schoolId:      j['schoolId'] as String,
        branchId:      j['branchId'] as String?,
        name:          j['name'] as String,
        templateType:  j['templateType'] as String,
        status:        j['status'] as String,
        cardWidthMm:   (j['cardWidthMm'] as num?)?.toDouble() ?? 85.6,
        cardHeightMm:  (j['cardHeightMm'] as num?)?.toDouble() ?? 54.0,
        createdBy:     j['createdBy'] as String,
        submittedBy:   j['submittedBy'] as String?,
        checkedBy:     j['checkedBy'] as String?,
        approvedBy:    j['approvedBy'] as String?,
        submittedAt:   j['submittedAt'] != null ? DateTime.tryParse(j['submittedAt'] as String) : null,
        checkedAt:     j['checkedAt']   != null ? DateTime.tryParse(j['checkedAt'] as String) : null,
        approvedAt:    j['approvedAt']  != null ? DateTime.tryParse(j['approvedAt'] as String) : null,
        checkNotes:    j['checkNotes']  as String?,
        approvalNotes: j['approvalNotes'] as String?,
        version:       (j['version'] as num?)?.toInt() ?? 1,
        isActive:      j['isActive'] as bool? ?? true,
        createdAt:     DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt:     DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ── Status helpers ────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status) {
    case 'draft':             return AppTheme.grey600;
    case 'pending_check':     return AppTheme.warning;
    case 'pending_approval':  return AppTheme.info;
    case 'approved':          return const Color(0xFF00897B);
    case 'rejected':          return AppTheme.error;
    case 'active':            return AppTheme.success;
    default:                  return AppTheme.grey600;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'draft':             return 'Draft';
    case 'pending_check':     return 'Pending Check';
    case 'pending_approval':  return 'Pending Approval';
    case 'approved':          return 'Approved';
    case 'rejected':          return 'Rejected';
    case 'active':            return 'Active';
    default:                  return status;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'draft':             return Icons.edit_outlined;
    case 'pending_check':     return Icons.rate_review_outlined;
    case 'pending_approval':  return Icons.approval_outlined;
    case 'approved':          return Icons.check_circle_outline;
    case 'rejected':          return Icons.cancel_outlined;
    case 'active':            return Icons.play_circle_outline;
    default:                  return Icons.help_outline;
  }
}

// ── Providers ─────────────────────────────────────────────────
class _TemplateListState {
  final List<IdTemplate> templates;
  final bool isLoading;
  final String? error;
  final String typeFilter;   // '' | 'student' | 'teacher'
  final String statusFilter; // '' | 'draft' | 'pending_check' | etc.
  final String search;
  final String? selectedSchoolId;

  const _TemplateListState({
    this.templates = const [],
    this.isLoading = false,
    this.error,
    this.typeFilter   = '',
    this.statusFilter = '',
    this.search       = '',
    this.selectedSchoolId,
  });

  _TemplateListState copyWith({
    List<IdTemplate>? templates,
    bool? isLoading,
    String? error,
    String? typeFilter,
    String? statusFilter,
    String? search,
    String? selectedSchoolId,
  }) => _TemplateListState(
        templates:    templates    ?? this.templates,
        isLoading:    isLoading    ?? this.isLoading,
        error:        error,
        typeFilter:   typeFilter   ?? this.typeFilter,
        statusFilter: statusFilter ?? this.statusFilter,
        search:       search       ?? this.search,
        selectedSchoolId: selectedSchoolId ?? this.selectedSchoolId,
      );
}

class _TemplateListNotifier extends StateNotifier<_TemplateListState> {
  _TemplateListNotifier() : super(const _TemplateListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (state.typeFilter.isNotEmpty)   params['template_type'] = state.typeFilter;
      if (state.statusFilter.isNotEmpty) params['status']        = state.statusFilter;
      if (state.search.isNotEmpty)       params['search']        = state.search;
      if (state.selectedSchoolId != null) params['school_id']    = state.selectedSchoolId;

      final resp = await ApiService().get('/id-templates', params: params);
      final list = resp['data'] as List?;
      final data = (list ?? []).map((e) => IdTemplate.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(templates: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setTypeFilter(String f) {
    state = state.copyWith(typeFilter: f);
    load();
  }

  void setStatusFilter(String f) {
    state = state.copyWith(statusFilter: f);
    load();
  }

  void setSearch(String s) {
    state = state.copyWith(search: s);
    load();
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await ApiService().delete('/id-templates/$id');
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> duplicateTemplate(String id) async {
    try {
      await ApiService().post('/id-templates/$id/duplicate');
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> activateTemplate(String id) async {
    try {
      await ApiService().post('/id-templates/$id/activate');
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  void setSchoolFilter(String? id) {
    state = state.copyWith(selectedSchoolId: id);
    load();
  }
}

final _templateListProvider =
    StateNotifierProvider.autoDispose<_TemplateListNotifier, _TemplateListState>(
  (ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final notifier = _TemplateListNotifier();
    if (user?.role != 'super_admin') {
      notifier.setSchoolFilter(user?.employee?.schoolId);
    }
    return notifier..load();
  },
);

// ── Screen ────────────────────────────────────────────────────
class IdTemplateListScreen extends ConsumerWidget {
  const IdTemplateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(_templateListProvider);
    final notifier = ref.read(_templateListProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final sid = state.selectedSchoolId;
          context.go('/id-templates/new${sid != null ? '?schoolId=$sid' : ''}');
        },
        icon:  const Icon(Icons.add),
        label: Text('New Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.accent,
      ),
      body: Column(
        children: [
          _FilterBar(state: state, notifier: notifier),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _ErrorState(error: state.error!, onRetry: notifier.load)
                    : state.templates.isEmpty
                        ? _EmptyState(onNew: () => context.go('/id-templates/new'))
                        : _TemplateGrid(state: state, notifier: notifier),
          ),
        ],
      ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────
class _FilterBar extends StatefulWidget {
  final _TemplateListState state;
  final _TemplateListNotifier notifier;
  const _FilterBar({required this.state, required this.notifier});

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.state.search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => widget.notifier.setSearch(v));
              },
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search templates…',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.grey600),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Type + status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All Types', '', widget.state.typeFilter, (v) => widget.notifier.setTypeFilter(v)),
                _chip('Student',   'student', widget.state.typeFilter, (v) => widget.notifier.setTypeFilter(v)),
                _chip('Teacher',   'teacher', widget.state.typeFilter, (v) => widget.notifier.setTypeFilter(v)),
                const SizedBox(width: 12),
                const SizedBox(height: 24, child: VerticalDivider(width: 1, color: AppTheme.grey300)),
                const SizedBox(width: 12),
                _chip('All Status', '',                widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
                _chip('Draft',             'draft',              widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
                _chip('Pending Check',     'pending_check',      widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
                _chip('Pending Approval',  'pending_approval',   widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
                _chip('Approved',          'approved',           widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
                _chip('Active',            'active',             widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
                _chip('Rejected',          'rejected',           widget.state.statusFilter, (v) => widget.notifier.setStatusFilter(v)),
              ],
            ),
          ),
          // School selector for SuperAdmin
          Consumer(builder: (ctx, ref, _) {
            final user = ref.watch(authNotifierProvider).valueOrNull;
            if (user?.role != 'super_admin') return const SizedBox.shrink();
            final schoolsAsync = ref.watch(allSchoolsProvider);

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                   Text('School: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                   const SizedBox(width: 8),
                   Expanded(
                     child: schoolsAsync.when(
                       data: (schools) => DropdownButton<String>(
                         value: widget.state.selectedSchoolId,
                         hint: const Text('Select school to filter/create'),
                         isExpanded: true,
                         underline: Container(height: 1, color: AppTheme.grey300),
                         style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey900),
                         items: [
                           const DropdownMenuItem(value: null, child: Text('All Schools')),
                           ...schools.map((s) => DropdownMenuItem(
                             value: s['id'] as String,
                             child: Text(s['name'] as String),
                           )),
                         ],
                         onChanged: widget.notifier.setSchoolFilter,
                       ),
                       loading: () => const LinearProgressIndicator(),
                       error:   (_, __) => const Text('Error loading schools'),
                     ),
                   ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => onTap(selected ? '' : value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.grey100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppTheme.primary : AppTheme.grey300),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppTheme.grey700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Template Grid ─────────────────────────────────────────────
class _TemplateGrid extends StatelessWidget {
  final _TemplateListState state;
  final _TemplateListNotifier notifier;
  const _TemplateGrid({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth > 1100 ? 4
                 : constraints.maxWidth > 750  ? 3
                 : constraints.maxWidth > 500  ? 2
                 : 1;
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: state.templates.length,
        itemBuilder: (_, i) => _TemplateCard(
          template: state.templates[i],
          notifier: notifier,
        ).animate().fadeIn(delay: (i * 40).ms, duration: 300.ms).slideY(begin: 0.05, end: 0),
      );
    });
  }
}

// ── Template Card ─────────────────────────────────────────────
class _TemplateCard extends StatelessWidget {
  final IdTemplate template;
  final _TemplateListNotifier notifier;
  const _TemplateCard({required this.template, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final statusC = _statusColor(template.status);

    return Card(
      elevation: 2,
      shadowColor: AppTheme.primary.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/id-templates/${template.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card preview icon
                  Container(
                    width: 42, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.badge, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.grey900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Type badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: template.templateType == 'student'
                                    ? AppTheme.info.withOpacity(0.12)
                                    : AppTheme.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                template.templateType == 'student' ? 'Student' : 'Teacher',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: template.templateType == 'student' ? AppTheme.info : AppTheme.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: statusC.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(template.status), size: 10, color: statusC),
                                  const SizedBox(width: 3),
                                  Text(
                                    _statusLabel(template.status),
                                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusC),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Workflow pipeline
              _WorkflowPipeline(status: template.status),

              const Spacer(),

              // Bottom row: date + actions
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 11, color: AppTheme.grey600),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(template.createdAt),
                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600),
                  ),
                  Text(
                    '  v${template.version}',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600),
                  ),
                  const Spacer(),
                  // Actions
                  _ActionMenu(template: template, notifier: notifier),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Workflow Pipeline indicator ───────────────────────────────
class _WorkflowPipeline extends StatelessWidget {
  final String status;
  const _WorkflowPipeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Draft',    'draft'),
      ('Check',    'pending_check'),
      ('Approval', 'pending_approval'),
      ('Active',   'active'),
    ];

    final order = ['draft', 'pending_check', 'pending_approval', 'approved', 'active'];
    final currentIdx = order.indexOf(status);

    return Row(
      children: stages.asMap().entries.map((entry) {
        final idx   = entry.key;
        final stage = entry.value;
        final stageIdx = order.indexOf(stage.$2);
        final isDone    = currentIdx > stageIdx;
        final isCurrent = currentIdx == stageIdx ||
            (status == 'approved' && stage.$2 == 'pending_approval') ||
            (status == 'rejected' && stageIdx <= currentIdx);
        final isRejected = status == 'rejected';

        Color dotColor;
        if (isRejected && stageIdx == currentIdx) {
          dotColor = AppTheme.error;
        } else if (isDone || (status == 'active' && stageIdx <= 3)) {
          dotColor = AppTheme.success;
        } else if (isCurrent) {
          dotColor = _statusColor(status);
        } else {
          dotColor = AppTheme.grey300;
        }

        return Expanded(
          child: Row(
            children: [
              if (idx > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? AppTheme.success : AppTheme.grey200,
                  ),
                ),
              Column(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(stage.$1,
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      color: isCurrent || isDone ? AppTheme.grey800 : AppTheme.grey300,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              if (idx < stages.length - 1) Expanded(child: Container()),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Action Menu ───────────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final IdTemplate template;
  final _TemplateListNotifier notifier;
  const _ActionMenu({required this.template, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.grey600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (action) async {
        switch (action) {
          case 'edit':
            context.go('/id-templates/${template.id}');
            break;
          case 'duplicate':
            await notifier.duplicateTemplate(template.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Template duplicated', style: GoogleFonts.poppins())),
              );
            }
            break;
          case 'activate':
            await notifier.activateTemplate(template.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Template activated', style: GoogleFonts.poppins())),
              );
            }
            break;
          case 'delete':
            final confirm = await _confirmDelete(context);
            if (confirm == true) await notifier.deleteTemplate(template.id);
            break;
        }
      },
      itemBuilder: (_) => [
        if (['draft', 'rejected'].contains(template.status))
          PopupMenuItem(
            value: 'edit',
            child: _menuItem(Icons.edit_outlined, 'Edit', AppTheme.grey800),
          ),
        PopupMenuItem(
          value: 'duplicate',
          child: _menuItem(Icons.copy_outlined, 'Duplicate', AppTheme.grey800),
        ),
        if (template.status == 'approved')
          PopupMenuItem(
            value: 'activate',
            child: _menuItem(Icons.play_circle_outline, 'Activate', AppTheme.success),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(Icons.delete_outline, 'Delete', AppTheme.error),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label, Color color) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: color)),
        ],
      );

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Template?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text(
            'This will permanently delete "${template.name}". This cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: Text('Delete', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
}

// ── Empty State ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_outlined, size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text('No Templates Yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.grey800)),
          const SizedBox(height: 8),
          Text('Create your first ID card template to get started.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: Text('Create Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ── Error State ───────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text('Failed to load templates', style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.grey800)),
          const SizedBox(height: 4),
          Text(error, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text('Retry', style: GoogleFonts.poppins())),
        ],
      ),
    );
  }
}
