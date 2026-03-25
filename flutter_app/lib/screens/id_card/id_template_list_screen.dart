// ============================================================
// ID Template List Screen
// ============================================================
import 'dart:async';
import 'dart:math' as math;
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

  /// Creates a new draft template from a sample preset and returns the new template ID.
  Future<String?> createFromSample(_SampleTemplate sample, String? schoolId) async {
    try {
      final elements = _buildSampleElements(sample.layoutStyle, sample.templateType, primaryColor: sample.primaryColor);
      final body = <String, dynamic>{
        'name':           sample.name,
        'template_type':  sample.templateType,
        'card_width_mm':  sample.widthMm,
        'card_height_mm': sample.heightMm,
        'elements':       elements,
        if (schoolId != null) 'school_id': schoolId,
      };
      final resp = await ApiService().post('/id-templates', body: body);
      final newId = (resp['data'] as Map<String, dynamic>?)?['id'] as String?;
      await load();
      return newId;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
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
class IdTemplateListScreen extends ConsumerStatefulWidget {
  const IdTemplateListScreen({super.key});

  @override
  ConsumerState<IdTemplateListScreen> createState() => _IdTemplateListScreenState();
}

class _IdTemplateListScreenState extends ConsumerState<IdTemplateListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabIndex != _tabController.index) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(_templateListProvider);
    final notifier = ref.read(_templateListProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                final sid = state.selectedSchoolId;
                context.go('/id-templates/new${sid != null ? '?schoolId=$sid' : ''}');
              },
              icon:  const Icon(Icons.add),
              label: Text('New Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: AppTheme.accent,
            )
          : null,
      body: Column(
        children: [
          // ── Tab Bar ─────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.grey600,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'My Templates'),
                Tab(text: 'Sample Gallery'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── My Templates ────────────────────────────
                Column(
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
                // ── Sample Gallery ──────────────────────────
                _SampleGallery(notifier: notifier, schoolId: state.selectedSchoolId),
              ],
            ),
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

// ══════════════════════════════════════════════════════════════
// SAMPLE GALLERY — 40 pre-built templates
// ══════════════════════════════════════════════════════════════

// ── Sample Template Model ─────────────────────────────────────
class _SampleTemplate {
  final String id;
  final String name;
  final String templateType; // 'student' | 'teacher'
  final double widthMm;
  final double heightMm;
  final Color primaryColor;
  final Color accentColor;
  final String layoutStyle;

  const _SampleTemplate({
    required this.id,
    required this.name,
    required this.templateType,
    required this.widthMm,
    required this.heightMm,
    required this.primaryColor,
    required this.accentColor,
    required this.layoutStyle,
  });

  bool get isHorizontal => widthMm > heightMm;
  String get orientationLabel => isHorizontal ? 'Horizontal' : 'Vertical';
}

// ── 40 Sample Templates ───────────────────────────────────────
// Layout styles: h_left_photo | h_top_strip | h_diagonal | h_split
//                v_top_photo  | v_centered  | v_header
const _kSamples = <_SampleTemplate>[
  // ── Student Horizontal (10) ──────────────────────────────
  _SampleTemplate(id:'sh1', name:'Classic Blue',     templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF1565C0), accentColor:Color(0xFF42A5F5), layoutStyle:'h_left_photo'),
  _SampleTemplate(id:'sh2', name:'Emerald Modern',   templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF00695C), accentColor:Color(0xFF4DB6AC), layoutStyle:'h_top_strip'),
  _SampleTemplate(id:'sh3', name:'Royal Purple',     templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF4527A0), accentColor:Color(0xFF9575CD), layoutStyle:'h_diagonal'),
  _SampleTemplate(id:'sh4', name:'Crimson Pro',      templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFFC62828), accentColor:Color(0xFFEF9A9A), layoutStyle:'h_split'),
  _SampleTemplate(id:'sh5', name:'Dark Navy',        templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF0D47A1), accentColor:Color(0xFF90CAF9), layoutStyle:'h_left_photo'),
  _SampleTemplate(id:'sh6', name:'Forest Green',     templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF1B5E20), accentColor:Color(0xFF81C784), layoutStyle:'h_top_strip'),
  _SampleTemplate(id:'sh7', name:'Amber Glow',       templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFFE65100), accentColor:Color(0xFFFFCC80), layoutStyle:'h_diagonal'),
  _SampleTemplate(id:'sh8', name:'Slate Gray',       templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF37474F), accentColor:Color(0xFF90A4AE), layoutStyle:'h_split'),
  _SampleTemplate(id:'sh9', name:'Pink Blossom',     templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF880E4F), accentColor:Color(0xFFF48FB1), layoutStyle:'h_left_photo'),
  _SampleTemplate(id:'sh10',name:'Ocean Teal',       templateType:'student', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF006064), accentColor:Color(0xFF4DD0E1), layoutStyle:'h_top_strip'),
  // ── Student Vertical (10) ────────────────────────────────
  _SampleTemplate(id:'sv1', name:'Portrait Blue',    templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF1565C0), accentColor:Color(0xFF42A5F5), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'sv2', name:'Purple Elegance',  templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF4527A0), accentColor:Color(0xFF9575CD), layoutStyle:'v_centered'),
  _SampleTemplate(id:'sv3', name:'Red Professional', templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFFC62828), accentColor:Color(0xFFEF9A9A), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'sv4', name:'Gold Premium',     templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF4E342E), accentColor:Color(0xFFFFD54F), layoutStyle:'v_header'),
  _SampleTemplate(id:'sv5', name:'Teal Portrait',    templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF006064), accentColor:Color(0xFF4DD0E1), layoutStyle:'v_centered'),
  _SampleTemplate(id:'sv6', name:'Sunset Orange',    templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFFBF360C), accentColor:Color(0xFFFF8A65), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'sv7', name:'Navy Formal',      templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF0D47A1), accentColor:Color(0xFF90CAF9), layoutStyle:'v_header'),
  _SampleTemplate(id:'sv8', name:'Emerald Portrait', templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF1B5E20), accentColor:Color(0xFF81C784), layoutStyle:'v_centered'),
  _SampleTemplate(id:'sv9', name:'Crimson Vertical', templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF880E4F), accentColor:Color(0xFFF48FB1), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'sv10',name:'Slate Minimal',    templateType:'student', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF37474F), accentColor:Color(0xFF90A4AE), layoutStyle:'v_header'),
  // ── Teacher Horizontal (10) ──────────────────────────────
  _SampleTemplate(id:'th1', name:'Faculty Blue',     templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF1565C0), accentColor:Color(0xFF42A5F5), layoutStyle:'h_split'),
  _SampleTemplate(id:'th2', name:'Faculty Green',    templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF00695C), accentColor:Color(0xFF4DB6AC), layoutStyle:'h_left_photo'),
  _SampleTemplate(id:'th3', name:'Faculty Maroon',   templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF880E4F), accentColor:Color(0xFFF48FB1), layoutStyle:'h_top_strip'),
  _SampleTemplate(id:'th4', name:'Faculty Gold',     templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF4E342E), accentColor:Color(0xFFFFD54F), layoutStyle:'h_diagonal'),
  _SampleTemplate(id:'th5', name:'Faculty Navy',     templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF0D47A1), accentColor:Color(0xFF90CAF9), layoutStyle:'h_split'),
  _SampleTemplate(id:'th6', name:'Faculty Teal',     templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF006064), accentColor:Color(0xFF4DD0E1), layoutStyle:'h_left_photo'),
  _SampleTemplate(id:'th7', name:'Faculty Gray',     templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF37474F), accentColor:Color(0xFF90A4AE), layoutStyle:'h_top_strip'),
  _SampleTemplate(id:'th8', name:'Faculty Red',      templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFFC62828), accentColor:Color(0xFFEF9A9A), layoutStyle:'h_diagonal'),
  _SampleTemplate(id:'th9', name:'Faculty Purple',   templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF4527A0), accentColor:Color(0xFF9575CD), layoutStyle:'h_split'),
  _SampleTemplate(id:'th10',name:'Faculty Forest',   templateType:'teacher', widthMm:85.6, heightMm:54.0, primaryColor:Color(0xFF1B5E20), accentColor:Color(0xFF81C784), layoutStyle:'h_left_photo'),
  // ── Teacher Vertical (10) ────────────────────────────────
  _SampleTemplate(id:'tv1', name:'Staff Blue',       templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF1565C0), accentColor:Color(0xFF42A5F5), layoutStyle:'v_header'),
  _SampleTemplate(id:'tv2', name:'Staff Green',      templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF00695C), accentColor:Color(0xFF4DB6AC), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'tv3', name:'Staff Maroon',     templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF880E4F), accentColor:Color(0xFFF48FB1), layoutStyle:'v_centered'),
  _SampleTemplate(id:'tv4', name:'Staff Gold',       templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF4E342E), accentColor:Color(0xFFFFD54F), layoutStyle:'v_header'),
  _SampleTemplate(id:'tv5', name:'Staff Navy',       templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF0D47A1), accentColor:Color(0xFF90CAF9), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'tv6', name:'Staff Teal',       templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF006064), accentColor:Color(0xFF4DD0E1), layoutStyle:'v_centered'),
  _SampleTemplate(id:'tv7', name:'Staff Gray',       templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF37474F), accentColor:Color(0xFF90A4AE), layoutStyle:'v_header'),
  _SampleTemplate(id:'tv8', name:'Staff Red',        templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFFC62828), accentColor:Color(0xFFEF9A9A), layoutStyle:'v_top_photo'),
  _SampleTemplate(id:'tv9', name:'Staff Purple',     templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF4527A0), accentColor:Color(0xFF9575CD), layoutStyle:'v_centered'),
  _SampleTemplate(id:'tv10',name:'Staff Forest',     templateType:'teacher', widthMm:54.0, heightMm:85.6, primaryColor:Color(0xFF1B5E20), accentColor:Color(0xFF81C784), layoutStyle:'v_header'),
];

// ── Build elements for a sample layout ───────────────────────
List<Map<String, dynamic>> _buildSampleElements(String layoutStyle, String templateType, {Color? primaryColor}) {
  final isTeacher = templateType == 'teacher';
  final hex = primaryColor != null ? _hexC(primaryColor) : _hexC(AppTheme.primary);
  final nameSrc   = isTeacher ? 'employee' : 'student';
  final nameKey   = 'full_name';
  final idKey     = isTeacher ? 'employee_id' : 'roll_number';
  final classKey  = isTeacher ? 'designation' : 'class_name';
  final deptKey   = isTeacher ? 'department'  : 'section';

  Map<String, dynamic> el(Map<String, dynamic> overrides) {
    final base = <String, dynamic>{
      'side': 'front', 'elementType': 'data_field',
      'xPct': 5.0, 'yPct': 5.0, 'wPct': 30.0, 'hPct': 10.0,
      'zIndex': 1, 'sortOrder': 0, 'fontSize': 10.0,
      'fontWeight': 'normal', 'fontColor': '#263238',
      'textAlign': 'left', 'fontItalic': false,
      'borderWidth': 0.0, 'borderRadius': 0.0, 'opacity': 1.0,
      'objectFit': 'cover', 'rotationDeg': 0.0,
    };
    base.addAll(overrides);
    return base;
  }

  switch (layoutStyle) {
    // ── Horizontal: photo on left, info on right ─────────
    case 'h_left_photo': return [
      el({'elementType':'shape',    'shapeType':'rectangle', 'fillColor':'#${hex}', 'xPct':0,'yPct':0,'wPct':33,'hPct':100, 'zIndex':0}),
      el({'elementType':'photo',    'xPct':3,'yPct':10,'wPct':26,'hPct':80, 'zIndex':2, 'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name', 'label':'School','xPct':35,'yPct':5,'wPct':60,'hPct':12, 'zIndex':2, 'fontWeight':'bold','fontColor':'#FFFFFF','fontSize':9.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey, 'label':'Name','xPct':35,'yPct':22,'wPct':60,'hPct':13, 'zIndex':2, 'fontWeight':'bold','fontColor':'#1A237E','fontSize':12.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':35,'yPct':38,'wPct':42,'hPct':10, 'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,   'label':isTeacher?'Emp ID':'Roll No','xPct':35,'yPct':50,'wPct':42,'hPct':10, 'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':deptKey, 'label':isTeacher?'Dept':'Section','xPct':35,'yPct':62,'wPct':42,'hPct':10, 'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'qr_code',  'xPct':76,'yPct':60,'wPct':21,'hPct':34, 'zIndex':2}),
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#${hex}40','xPct':33,'yPct':90,'wPct':67,'hPct':10, 'zIndex':1}),
    ];
    // ── Horizontal: coloured header strip ────────────────
    case 'h_top_strip': return [
      el({'elementType':'shape',    'shapeType':'rectangle','fillColor':'#FFFFFF','xPct':0,'yPct':0,'wPct':100,'hPct':100,'zIndex':0}),
      el({'elementType':'shape',    'shapeType':'rectangle','fillColor':'#${hex}','xPct':0,'yPct':0,'wPct':100,'hPct':35,'zIndex':1}),
      el({'elementType':'logo',     'xPct':3,'yPct':5,'wPct':14,'hPct':25, 'zIndex':3}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name','label':'School','xPct':20,'yPct':7,'wPct':77,'hPct':13,'zIndex':3,'fontWeight':'bold','fontColor':'#FFFFFF','fontSize':10.0}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'affiliation','label':'Affiliation','xPct':20,'yPct':22,'wPct':77,'hPct':9,'zIndex':3,'fontColor':'#E3F2FD','fontSize':8.0}),
      el({'elementType':'photo',    'xPct':3,'yPct':12,'wPct':22,'hPct':80,'zIndex':4,'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey,'label':'Name','xPct':28,'yPct':40,'wPct':68,'hPct':13,'zIndex':3,'fontWeight':'bold','fontColor':'#1A237E','fontSize':12.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':28,'yPct':56,'wPct':45,'hPct':10,'zIndex':3,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,'label':isTeacher?'Emp ID':'Roll No','xPct':28,'yPct':68,'wPct':45,'hPct':10,'zIndex':3,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'qr_code',  'xPct':76,'yPct':56,'wPct':21,'hPct':37,'zIndex':3}),
    ];
    // ── Horizontal: diagonal colour split ────────────────
    case 'h_diagonal': return [
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#FFFFFF','xPct':0,'yPct':0,'wPct':100,'hPct':100,'zIndex':0}),
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#${hex}','xPct':0,'yPct':0,'wPct':45,'hPct':100,'zIndex':1}),
      el({'elementType':'photo',   'xPct':28,'yPct':8,'wPct':25,'hPct':82,'zIndex':3,'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name','label':'School','xPct':57,'yPct':7,'wPct':40,'hPct':12,'zIndex':3,'fontWeight':'bold','fontSize':9.0,'fontColor':'#1A237E'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey,'label':'Name','xPct':57,'yPct':25,'wPct':40,'hPct':13,'zIndex':3,'fontWeight':'bold','fontSize':12.0,'fontColor':'#263238'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':57,'yPct':42,'wPct':40,'hPct':10,'zIndex':3,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,'label':isTeacher?'Emp ID':'Roll No','xPct':57,'yPct':55,'wPct':40,'hPct':10,'zIndex':3,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'logo',    'xPct':5,'yPct':5,'wPct':18,'hPct':22,'zIndex':3}),
      el({'elementType':'qr_code', 'xPct':57,'yPct':68,'wPct':18,'hPct':28,'zIndex':3}),
    ];
    // ── Horizontal: left panel + right content ────────────
    case 'h_split': return [
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#${hex}','xPct':0,'yPct':0,'wPct':34,'hPct':100,'zIndex':0}),
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#FFFFFF','xPct':34,'yPct':0,'wPct':66,'hPct':100,'zIndex':0}),
      el({'elementType':'logo',    'xPct':4,'yPct':5,'wPct':26,'hPct':18,'zIndex':2}),
      el({'elementType':'photo',   'xPct':4,'yPct':26,'wPct':26,'hPct':52,'zIndex':2,'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'branch_name','label':'Branch','xPct':4,'yPct':80,'wPct':26,'hPct':14,'zIndex':2,'fontColor':'#FFFFFF','fontSize':8.0,'textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name','label':'School','xPct':37,'yPct':6,'wPct':60,'hPct':13,'zIndex':2,'fontWeight':'bold','fontSize':10.0,'fontColor':'#1A237E'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey,'label':'Name','xPct':37,'yPct':24,'wPct':60,'hPct':13,'zIndex':2,'fontWeight':'bold','fontSize':12.0,'fontColor':'#263238'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':37,'yPct':41,'wPct':58,'hPct':10,'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,'label':isTeacher?'Emp ID':'Roll No','xPct':37,'yPct':54,'wPct':58,'hPct':10,'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A'}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'affiliation','label':'Affiliation','xPct':37,'yPct':67,'wPct':58,'hPct':9,'zIndex':2,'fontSize':8.0,'fontColor':'#78909C'}),
      el({'elementType':'qr_code', 'xPct':76,'yPct':60,'wPct':20,'hPct':32,'zIndex':2}),
    ];
    // ── Vertical: coloured top, photo at boundary ─────────
    case 'v_top_photo': return [
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#FFFFFF','xPct':0,'yPct':0,'wPct':100,'hPct':100,'zIndex':0}),
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#${hex}','xPct':0,'yPct':0,'wPct':100,'hPct':40,'zIndex':1}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name','label':'School','xPct':8,'yPct':5,'wPct':84,'hPct':12,'zIndex':2,'fontWeight':'bold','fontColor':'#FFFFFF','fontSize':10.0,'textAlign':'center'}),
      el({'elementType':'logo',     'xPct':38,'yPct':18,'wPct':24,'hPct':18,'zIndex':2}),
      el({'elementType':'photo',    'xPct':22,'yPct':24,'wPct':56,'hPct':38,'zIndex':3,'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey,'label':'Name','xPct':8,'yPct':65,'wPct':84,'hPct':11,'zIndex':2,'fontWeight':'bold','fontColor':'#263238','fontSize':11.0,'textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':8,'yPct':78,'wPct':84,'hPct':9,'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A','textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,'label':isTeacher?'Emp ID':'Roll No','xPct':8,'yPct':89,'wPct':84,'hPct':9,'zIndex':2,'fontSize':9.0,'fontColor':'#78909C','textAlign':'center'}),
    ];
    // ── Vertical: full-colour background ─────────────────
    case 'v_centered': return [
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#${hex}','xPct':0,'yPct':0,'wPct':100,'hPct':100,'zIndex':0}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name','label':'School','xPct':8,'yPct':4,'wPct':84,'hPct':11,'zIndex':2,'fontWeight':'bold','fontColor':'#FFFFFF','fontSize':10.0,'textAlign':'center'}),
      el({'elementType':'photo',    'xPct':20,'yPct':18,'wPct':60,'hPct':38,'zIndex':3,'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey,'label':'Name','xPct':8,'yPct':59,'wPct':84,'hPct':12,'zIndex':2,'fontWeight':'bold','fontColor':'#FFFFFF','fontSize':12.0,'textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':8,'yPct':73,'wPct':84,'hPct':10,'zIndex':2,'fontSize':9.0,'fontColor':'#E3F2FD','textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,'label':isTeacher?'Emp ID':'Roll No','xPct':8,'yPct':85,'wPct':84,'hPct':9,'zIndex':2,'fontSize':9.0,'fontColor':'#B0BEC5','textAlign':'center'}),
      el({'elementType':'qr_code',  'xPct':78,'yPct':83,'wPct':18,'hPct':14,'zIndex':2}),
    ];
    // ── Vertical: header strip + white body ───────────────
    case 'v_header': return [
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#FFFFFF','xPct':0,'yPct':0,'wPct':100,'hPct':100,'zIndex':0}),
      el({'elementType':'shape','shapeType':'rectangle','fillColor':'#${hex}','xPct':0,'yPct':0,'wPct':100,'hPct':38,'zIndex':1}),
      el({'elementType':'data_field','fieldSource':'school','fieldKey':'school_name','label':'School','xPct':8,'yPct':4,'wPct':84,'hPct':12,'zIndex':2,'fontWeight':'bold','fontColor':'#FFFFFF','fontSize':10.0,'textAlign':'center'}),
      el({'elementType':'logo',     'xPct':36,'yPct':17,'wPct':28,'hPct':20,'zIndex':2}),
      el({'elementType':'photo',    'xPct':20,'yPct':26,'wPct':60,'hPct':38,'zIndex':3,'borderRadius':4.0}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':nameKey,'label':'Name','xPct':8,'yPct':67,'wPct':84,'hPct':12,'zIndex':2,'fontWeight':'bold','fontColor':'#263238','fontSize':11.0,'textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':classKey,'label':isTeacher?'Designation':'Class','xPct':8,'yPct':81,'wPct':84,'hPct':9,'zIndex':2,'fontSize':9.0,'fontColor':'#546E7A','textAlign':'center'}),
      el({'elementType':'data_field','fieldSource':nameSrc,'fieldKey':idKey,'label':isTeacher?'Emp ID':'Roll No','xPct':8,'yPct':92,'wPct':84,'hPct':7,'zIndex':2,'fontSize':8.5,'fontColor':'#78909C','textAlign':'center'}),
    ];
    default: return [];
  }
}

/// Convert a Color to a 6-char hex string (no alpha, no #).
String _hexC(Color c) {
  return '${c.red.toRadixString(16).padLeft(2,'0')}'
         '${c.green.toRadixString(16).padLeft(2,'0')}'
         '${c.blue.toRadixString(16).padLeft(2,'0')}';
}

// ── Sample Card Painter ───────────────────────────────────────
class _SampleCardPainter extends CustomPainter {
  final _SampleTemplate s;
  _SampleCardPainter(this.s);

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;
    final p = s.primaryColor;
    final a = s.accentColor;

    // Clip to card shape
    canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h), const Radius.circular(6)));

    switch (s.layoutStyle) {
      case 'h_left_photo': _hLeftPhoto(canvas, w, h, p, a); break;
      case 'h_top_strip':  _hTopStrip(canvas, w, h, p, a);  break;
      case 'h_diagonal':   _hDiagonal(canvas, w, h, p, a);  break;
      case 'h_split':      _hSplit(canvas, w, h, p, a);     break;
      case 'v_top_photo':  _vTopPhoto(canvas, w, h, p, a);  break;
      case 'v_centered':   _vCentered(canvas, w, h, p, a);  break;
      case 'v_header':     _vHeader(canvas, w, h, p, a);    break;
      default:             _hLeftPhoto(canvas, w, h, p, a);
    }
  }

  // ── h_left_photo ─────────────────────────────────────────
  void _hLeftPhoto(Canvas c, double w, double h, Color p, Color a) {
    c.drawRect(Rect.fromLTWH(0,0,w,h), _fill(p));
    c.drawRect(Rect.fromLTWH(w*.33,0,w*.67,h), _fill(Colors.white));
    c.drawRect(Rect.fromLTWH(w*.33,0,w*.67,h*.04), _fill(a));
    _photo(c, w*.165, h*.5, h*.28, Colors.white.withOpacity(.9), p);
    _tLine(c, Rect.fromLTWH(w*.36,h*.08,w*.56,h*.10), a, bold:true);
    _tLine(c, Rect.fromLTWH(w*.36,h*.24,w*.52,h*.11), p, bold:true);
    _tLine(c, Rect.fromLTWH(w*.36,h*.40,w*.36,h*.07), Colors.grey.shade400);
    _tLine(c, Rect.fromLTWH(w*.36,h*.52,w*.30,h*.07), Colors.grey.shade400);
    _tLine(c, Rect.fromLTWH(w*.36,h*.64,w*.40,h*.07), Colors.grey.shade400);
    _qr(c, Rect.fromLTWH(w*.78,h*.58,w*.18,h*.34), Colors.grey.shade300);
    c.drawRect(Rect.fromLTWH(w*.33,h*.90,w*.67,h*.10), _fill(p.withOpacity(.15)));
  }

  // ── h_top_strip ──────────────────────────────────────────
  void _hTopStrip(Canvas c, double w, double h, Color p, Color a) {
    c.drawRect(Rect.fromLTWH(0,0,w,h), _fill(Colors.white));
    c.drawRect(Rect.fromLTWH(0,0,w,h*.35), _fill(p));
    _logo(c, Rect.fromLTWH(w*.04,h*.06,w*.12,h*.22));
    _tLine(c, Rect.fromLTWH(w*.20,h*.09,w*.74,h*.11), Colors.white, bold:true);
    _tLine(c, Rect.fromLTWH(w*.20,h*.22,w*.60,h*.08), Colors.white.withOpacity(.7));
    _photo(c, w*.13, h*.5, h*.30, p.withOpacity(.15), a);
    _tLine(c, Rect.fromLTWH(w*.30,h*.42,w*.54,h*.12), p, bold:true);
    _tLine(c, Rect.fromLTWH(w*.30,h*.58,w*.36,h*.08), Colors.grey.shade400);
    _tLine(c, Rect.fromLTWH(w*.30,h*.70,w*.30,h*.08), Colors.grey.shade400);
    _qr(c, Rect.fromLTWH(w*.76,h*.56,w*.20,h*.36), Colors.grey.shade300);
  }

  // ── h_diagonal ───────────────────────────────────────────
  void _hDiagonal(Canvas c, double w, double h, Color p, Color a) {
    c.drawRect(Rect.fromLTWH(0,0,w,h), _fill(Colors.white));
    final path = Path()..moveTo(0,0)..lineTo(w*.50,0)..lineTo(w*.32,h)..lineTo(0,h)..close();
    c.drawPath(path, _fill(p));
    _logo(c, Rect.fromLTWH(w*.06,h*.08,w*.16,h*.22));
    _photo(c, w*.30, h*.5, h*.32, Colors.white.withOpacity(.9), a);
    _tLine(c, Rect.fromLTWH(w*.55,h*.08,w*.40,h*.11), p, bold:true);
    _tLine(c, Rect.fromLTWH(w*.55,h*.26,w*.40,h*.12), Colors.grey.shade800, bold:true);
    _tLine(c, Rect.fromLTWH(w*.55,h*.43,w*.32,h*.08), Colors.grey.shade400);
    _tLine(c, Rect.fromLTWH(w*.55,h*.55,w*.26,h*.08), Colors.grey.shade400);
    _qr(c, Rect.fromLTWH(w*.76,h*.65,w*.20,h*.30), Colors.grey.shade300);
  }

  // ── h_split ──────────────────────────────────────────────
  void _hSplit(Canvas c, double w, double h, Color p, Color a) {
    c.drawRect(Rect.fromLTWH(0,0,w*.34,h), _fill(p));
    c.drawRect(Rect.fromLTWH(w*.34,0,w*.66,h), _fill(Colors.white));
    _logo(c, Rect.fromLTWH(w*.05,h*.05,w*.24,h*.18));
    _photo(c, w*.17, h*.56, h*.30, Colors.white.withOpacity(.9), a);
    _tLine(c, Rect.fromLTWH(w*.05,h*.82,w*.24,h*.10), Colors.white.withOpacity(.7));
    _tLine(c, Rect.fromLTWH(w*.37,h*.08,w*.58,h*.12), p, bold:true);
    _tLine(c, Rect.fromLTWH(w*.37,h*.26,w*.56,h*.13), Colors.grey.shade800, bold:true);
    _tLine(c, Rect.fromLTWH(w*.37,h*.44,w*.40,h*.09), Colors.grey.shade400);
    _tLine(c, Rect.fromLTWH(w*.37,h*.56,w*.34,h*.09), Colors.grey.shade400);
    _tLine(c, Rect.fromLTWH(w*.37,h*.68,w*.50,h*.09), Colors.grey.shade300);
    _qr(c, Rect.fromLTWH(w*.77,h*.60,w*.19,h*.32), Colors.grey.shade300);
  }

  // ── v_top_photo ──────────────────────────────────────────
  void _vTopPhoto(Canvas c, double w, double h, Color p, Color a) {
    c.drawRect(Rect.fromLTWH(0,0,w,h), _fill(Colors.white));
    c.drawRect(Rect.fromLTWH(0,0,w,h*.40), _fill(p));
    _tLine(c, Rect.fromLTWH(w*.10,h*.05,w*.80,h*.10), Colors.white, bold:true, center:true);
    _logo(c, Rect.fromLTWH(w*.37,h*.17,w*.26,h*.16));
    _photo(c, w*.50, h*.38, w*.26, Colors.white, a);
    _tLine(c, Rect.fromLTWH(w*.10,h*.65,w*.80,h*.10), p, bold:true, center:true);
    _tLine(c, Rect.fromLTWH(w*.15,h*.78,w*.70,h*.08), Colors.grey.shade500, center:true);
    _tLine(c, Rect.fromLTWH(w*.20,h*.88,w*.60,h*.08), Colors.grey.shade400, center:true);
  }

  // ── v_centered ───────────────────────────────────────────
  void _vCentered(Canvas c, double w, double h, Color p, Color a) {
    final grad = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [p, Color.lerp(p, Colors.black, .35)!],
    );
    c.drawRect(Rect.fromLTWH(0,0,w,h),
        Paint()..shader = grad.createShader(Rect.fromLTWH(0,0,w,h)));
    _tLine(c, Rect.fromLTWH(w*.08,h*.04,w*.84,h*.09), Colors.white, bold:true, center:true);
    _photo(c, w*.50, h*.32, w*.26, Colors.white.withOpacity(.9), a);
    _tLine(c, Rect.fromLTWH(w*.08,h*.58,w*.84,h*.10), Colors.white, bold:true, center:true);
    _tLine(c, Rect.fromLTWH(w*.12,h*.71,w*.76,h*.08), Colors.white.withOpacity(.75), center:true);
    _tLine(c, Rect.fromLTWH(w*.16,h*.82,w*.68,h*.08), Colors.white.withOpacity(.60), center:true);
    _qr(c, Rect.fromLTWH(w*.74,h*.83,w*.20,h*.13), Colors.white.withOpacity(.4));
  }

  // ── v_header ─────────────────────────────────────────────
  void _vHeader(Canvas c, double w, double h, Color p, Color a) {
    c.drawRect(Rect.fromLTWH(0,0,w,h), _fill(Colors.white));
    c.drawRect(Rect.fromLTWH(0,0,w,h*.36), _fill(p));
    _tLine(c, Rect.fromLTWH(w*.08,h*.04,w*.84,h*.10), Colors.white, bold:true, center:true);
    _logo(c, Rect.fromLTWH(w*.36,h*.16,w*.28,h*.18));
    _photo(c, w*.50, h*.37, w*.27, Colors.white, a);
    _tLine(c, Rect.fromLTWH(w*.08,h*.66,w*.84,h*.10), p, bold:true, center:true);
    _tLine(c, Rect.fromLTWH(w*.12,h*.79,w*.76,h*.08), Colors.grey.shade500, center:true);
    _tLine(c, Rect.fromLTWH(w*.16,h*.90,w*.68,h*.07), Colors.grey.shade400, center:true);
  }

  // ── Helpers ──────────────────────────────────────────────
  Paint _fill(Color c) => Paint()..color = c;

  void _tLine(Canvas c, Rect r, Color col, {bool bold = false, bool center = false}) {
    final h  = r.height * (bold ? 0.9 : 0.75);
    final dy = r.top + (r.height - h) / 2;
    final dx = center ? r.left + (r.width - r.width * .85) / 2 : r.left;
    final cw = center ? r.width * .85 : r.width;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(dx, dy, cw, h), Radius.circular(h / 2)),
      _fill(col),
    );
  }

  void _photo(Canvas c, double cx, double cy, double r, Color bg, Color ico) {
    c.drawCircle(Offset(cx, cy), r + 2, _fill(bg));
    c.drawCircle(Offset(cx, cy), r, _fill(ico.withOpacity(.4)));
    // Head
    c.drawCircle(Offset(cx, cy - r * .22), r * .30, _fill(bg));
    // Body arc
    final bodyRect = Rect.fromCenter(
        center: Offset(cx, cy + r * .28), width: r * 1.1, height: r * .8);
    c.drawArc(bodyRect, math.pi, math.pi, false, _fill(bg));
  }

  void _logo(Canvas c, Rect r) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.width * .12)),
      _fill(Colors.white.withOpacity(.25)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(r.width * .1), Radius.circular(r.width * .08)),
      Paint()..color = Colors.white.withOpacity(.5)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }

  void _qr(Canvas c, Rect r, Color col) {
    final cell = r.width / 5;
    final paint = _fill(col);
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height),
        Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = cell * .15);
    void sq(double gx, double gy, double gs) =>
        c.drawRect(Rect.fromLTWH(r.left + gx * cell, r.top + gy * cell, gs * cell, gs * cell), paint);
    sq(.2,.2,1.2); sq(3.6,.2,1.2); sq(.2,3.6,1.2);
    sq(2.0,2.0,.8); sq(3.0,2.0,.8); sq(2.0,3.5,.8); sq(3.5,3.5,1.0);
  }

  @override
  bool shouldRepaint(_SampleCardPainter old) => old.s.id != s.id;
}

// ── Sample Card Widget ────────────────────────────────────────
class _SampleCard extends StatefulWidget {
  final _SampleTemplate sample;
  final _TemplateListNotifier notifier;
  final String? schoolId;
  const _SampleCard({required this.sample, required this.notifier, this.schoolId});

  @override
  State<_SampleCard> createState() => _SampleCardState();
}

class _SampleCardState extends State<_SampleCard> {
  bool _loading = false;

  Future<void> _useTemplate() async {
    setState(() => _loading = true);
    final newId = await widget.notifier.createFromSample(widget.sample, widget.schoolId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (newId != null) {
      context.go('/id-templates/$newId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create template', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s          = widget.sample;
    final isH        = s.isHorizontal;
    // Card preview aspect ratio
    final previewAspect = isH ? (85.6 / 54.0) : (54.0 / 85.6);

    return Card(
      elevation: 2,
      shadowColor: s.primaryColor.withOpacity(.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Preview ─────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: previewAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(
                      painter: _SampleCardPainter(s),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Info row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(s.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.grey900),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _badge(s.templateType == 'student' ? 'Student' : 'Teacher',
                    s.templateType == 'student' ? AppTheme.info : AppTheme.accent),
                const SizedBox(width: 5),
                _badge(s.orientationLabel, AppTheme.grey600),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Use button ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: _loading ? null : _useTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: s.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                child: _loading
                    ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Use Template',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── Sample Gallery Widget ─────────────────────────────────────
class _SampleGallery extends StatefulWidget {
  final _TemplateListNotifier notifier;
  final String? schoolId;
  const _SampleGallery({required this.notifier, this.schoolId});

  @override
  State<_SampleGallery> createState() => _SampleGalleryState();
}

class _SampleGalleryState extends State<_SampleGallery> {
  String _typeFilter   = ''; // '' | 'student' | 'teacher'
  String _orientFilter = ''; // '' | 'h' | 'v'

  List<_SampleTemplate> get _filtered => _kSamples.where((s) {
        if (_typeFilter.isNotEmpty && s.templateType != _typeFilter) return false;
        if (_orientFilter == 'h' && !s.isHorizontal) return false;
        if (_orientFilter == 'v' &&  s.isHorizontal) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final samples = _filtered;
    return Column(
      children: [
        // ── Filter bar ─────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All',      '',         _typeFilter,   (v) => setState(() => _typeFilter = v)),
                _chip('Student',  'student',  _typeFilter,   (v) => setState(() => _typeFilter = v)),
                _chip('Teacher',  'teacher',  _typeFilter,   (v) => setState(() => _typeFilter = v)),
                const SizedBox(width: 10),
                const SizedBox(height: 20, child: VerticalDivider(width: 1, color: AppTheme.grey300)),
                const SizedBox(width: 10),
                _chip('All',       '',  _orientFilter, (v) => setState(() => _orientFilter = v)),
                _chip('Horizontal','h', _orientFilter, (v) => setState(() => _orientFilter = v)),
                _chip('Vertical',  'v', _orientFilter, (v) => setState(() => _orientFilter = v)),
                const SizedBox(width: 16),
                Text('${samples.length} templates',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
              ],
            ),
          ),
        ),
        // ── Grid ───────────────────────────────────────
        Expanded(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 1100 ? 5
                       : constraints.maxWidth > 800  ? 4
                       : constraints.maxWidth > 550  ? 3
                       : 2;
            return GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .72,
              ),
              itemCount: samples.length,
              itemBuilder: (_, i) => _SampleCard(
                sample:   samples[i],
                notifier: widget.notifier,
                schoolId: widget.schoolId,
              ),
            );
          }),
        ),
      ],
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
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppTheme.grey700)),
        ),
      ),
    );
  }
}
