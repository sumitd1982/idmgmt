// ============================================================
// ID Template Designer Screen — Full drag-and-drop canvas
// ============================================================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'id_template_list_screen.dart' show IdTemplate;

// ── Constants ─────────────────────────────────────────────────
// Card is 85.6 x 54.0 mm. At 7.55 px/mm → 646 x 408 logical px
const double kCardW = 646.0;
const double kCardH = 408.0;

// ── Element Model ─────────────────────────────────────────────
class TemplateElement {
  final String id;
  String side;          // 'front' | 'back'
  String elementType;   // 'data_field'|'photo'|'logo'|'qr_code'|'barcode'|'static_text'|'shape'|'background_image'
  String? fieldSource;  // 'student'|'school'|'employee'|'custom'
  String? fieldKey;
  String? label;
  String? staticContent;
  double xPct;
  double yPct;
  double wPct;
  double hPct;
  double rotationDeg;
  int zIndex;
  // Typography
  double fontSize;
  String fontWeight;
  String fontColor;
  String textAlign;
  bool fontItalic;
  // Appearance
  String? bgColor;
  String? borderColor;
  double borderWidth;
  double borderRadius;
  double opacity;
  // Image
  String? imageUrl;
  String objectFit;
  // Shape
  String? shapeType;
  String? fillColor;
  int sortOrder;

  TemplateElement({
    required this.id,
    required this.side,
    required this.elementType,
    this.fieldSource,
    this.fieldKey,
    this.label,
    this.staticContent,
    this.xPct       = 5,
    this.yPct       = 5,
    this.wPct       = 30,
    this.hPct       = 15,
    this.rotationDeg = 0,
    this.zIndex      = 1,
    this.fontSize    = 10,
    this.fontWeight  = 'normal',
    this.fontColor   = '#1A237E',
    this.textAlign   = 'left',
    this.fontItalic  = false,
    this.bgColor,
    this.borderColor,
    this.borderWidth  = 0,
    this.borderRadius = 0,
    this.opacity      = 1.0,
    this.imageUrl,
    this.objectFit    = 'cover',
    this.shapeType,
    this.fillColor,
    this.sortOrder    = 0,
  });

  factory TemplateElement.fromJson(Map<String, dynamic> j) => TemplateElement(
        id:            j['id'] as String,
        side:          j['side'] as String? ?? 'front',
        elementType:   j['elementType'] as String,
        fieldSource:   j['fieldSource'] as String?,
        fieldKey:      j['fieldKey'] as String?,
        label:         j['label'] as String?,
        staticContent: j['staticContent'] as String?,
        xPct:          (j['xPct'] as num?)?.toDouble() ?? 5,
        yPct:          (j['yPct'] as num?)?.toDouble() ?? 5,
        wPct:          (j['wPct'] as num?)?.toDouble() ?? 30,
        hPct:          (j['hPct'] as num?)?.toDouble() ?? 15,
        rotationDeg:   (j['rotationDeg'] as num?)?.toDouble() ?? 0,
        zIndex:        (j['zIndex'] as num?)?.toInt() ?? 1,
        fontSize:      (j['fontSize'] as num?)?.toDouble() ?? 10,
        fontWeight:    j['fontWeight'] as String? ?? 'normal',
        fontColor:     j['fontColor'] as String? ?? '#1A237E',
        textAlign:     j['textAlign'] as String? ?? 'left',
        fontItalic:    j['fontItalic'] as bool? ?? false,
        bgColor:       j['bgColor'] as String?,
        borderColor:   j['borderColor'] as String?,
        borderWidth:   (j['borderWidth'] as num?)?.toDouble() ?? 0,
        borderRadius:  (j['borderRadius'] as num?)?.toDouble() ?? 0,
        opacity:       (j['opacity'] as num?)?.toDouble() ?? 1.0,
        imageUrl:      j['imageUrl'] as String?,
        objectFit:     j['objectFit'] as String? ?? 'cover',
        shapeType:     j['shapeType'] as String?,
        fillColor:     j['fillColor'] as String?,
        sortOrder:     (j['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'side':          side,
        'elementType':   elementType,
        'fieldSource':   fieldSource,
        'fieldKey':      fieldKey,
        'label':         label,
        'staticContent': staticContent,
        'xPct':          xPct,
        'yPct':          yPct,
        'wPct':          wPct,
        'hPct':          hPct,
        'rotationDeg':   rotationDeg,
        'zIndex':        zIndex,
        'fontSize':      fontSize,
        'fontWeight':    fontWeight,
        'fontColor':     fontColor,
        'textAlign':     textAlign,
        'fontItalic':    fontItalic,
        'bgColor':       bgColor,
        'borderColor':   borderColor,
        'borderWidth':   borderWidth,
        'borderRadius':  borderRadius,
        'opacity':       opacity,
        'imageUrl':      imageUrl,
        'objectFit':     objectFit,
        'shapeType':     shapeType,
        'fillColor':     fillColor,
        'sortOrder':     sortOrder,
      };

  TemplateElement copyWith({
    String? side,
    String? elementType,
    String? fieldSource,
    String? fieldKey,
    String? label,
    String? staticContent,
    double? xPct,
    double? yPct,
    double? wPct,
    double? hPct,
    double? rotationDeg,
    int? zIndex,
    double? fontSize,
    String? fontWeight,
    String? fontColor,
    String? textAlign,
    bool? fontItalic,
    String? bgColor,
    String? borderColor,
    double? borderWidth,
    double? borderRadius,
    double? opacity,
    String? imageUrl,
    String? objectFit,
    String? shapeType,
    String? fillColor,
    int? sortOrder,
  }) => TemplateElement(
        id:            id,
        side:          side          ?? this.side,
        elementType:   elementType   ?? this.elementType,
        fieldSource:   fieldSource   ?? this.fieldSource,
        fieldKey:      fieldKey      ?? this.fieldKey,
        label:         label         ?? this.label,
        staticContent: staticContent ?? this.staticContent,
        xPct:          xPct          ?? this.xPct,
        yPct:          yPct          ?? this.yPct,
        wPct:          wPct          ?? this.wPct,
        hPct:          hPct          ?? this.hPct,
        rotationDeg:   rotationDeg   ?? this.rotationDeg,
        zIndex:        zIndex        ?? this.zIndex,
        fontSize:      fontSize      ?? this.fontSize,
        fontWeight:    fontWeight    ?? this.fontWeight,
        fontColor:     fontColor     ?? this.fontColor,
        textAlign:     textAlign     ?? this.textAlign,
        fontItalic:    fontItalic    ?? this.fontItalic,
        bgColor:       bgColor       ?? this.bgColor,
        borderColor:   borderColor   ?? this.borderColor,
        borderWidth:   borderWidth   ?? this.borderWidth,
        borderRadius:  borderRadius  ?? this.borderRadius,
        opacity:       opacity       ?? this.opacity,
        imageUrl:      imageUrl      ?? this.imageUrl,
        objectFit:     objectFit     ?? this.objectFit,
        shapeType:     shapeType     ?? this.shapeType,
        fillColor:     fillColor     ?? this.fillColor,
        sortOrder:     sortOrder     ?? this.sortOrder,
      );
}

// ── Designer State ────────────────────────────────────────────
class DesignerState {
  final String? templateId;
  final String templateName;
  final String templateType;
  final String status;
  final String currentSide;
  final List<TemplateElement> elements;
  final String? selectedElementId;
  final bool isDirty;
  final bool isSaving;
  final bool isLoading;
  final String? error;
  final double zoom;
  final String? schoolId;
  // Workflow audit
  final DateTime? submittedAt;
  final DateTime? checkedAt;
  final DateTime? approvedAt;
  final String? checkNotes;
  final String? approvalNotes;

  const DesignerState({
    this.templateId,
    this.templateName = 'New Template',
    this.templateType = 'student',
    this.status       = 'draft',
    this.currentSide  = 'front',
    this.elements     = const [],
    this.selectedElementId,
    this.isDirty      = false,
    this.isSaving     = false,
    this.isLoading    = false,
    this.error,
    this.zoom         = 1.0,
    this.schoolId,
    this.submittedAt,
    this.checkedAt,
    this.approvedAt,
    this.checkNotes,
    this.approvalNotes,
  });

  DesignerState copyWith({
    String? templateId,
    String? templateName,
    String? templateType,
    String? status,
    String? currentSide,
    List<TemplateElement>? elements,
    String? selectedElementId,
    bool? isDirty,
    bool? isSaving,
    bool? isLoading,
    String? error,
    double? zoom,
    String? schoolId,
    bool clearSelected = false,
    DateTime? submittedAt,
    DateTime? checkedAt,
    DateTime? approvedAt,
    String? checkNotes,
    String? approvalNotes,
  }) => DesignerState(
        templateId:         templateId         ?? this.templateId,
        templateName:       templateName       ?? this.templateName,
        templateType:       templateType       ?? this.templateType,
        status:             status             ?? this.status,
        currentSide:        currentSide        ?? this.currentSide,
        elements:           elements           ?? this.elements,
        selectedElementId:  clearSelected ? null : (selectedElementId ?? this.selectedElementId),
        isDirty:            isDirty            ?? this.isDirty,
        isSaving:           isSaving           ?? this.isSaving,
        isLoading:          isLoading          ?? this.isLoading,
        error:              error,
        zoom:               zoom               ?? this.zoom,
        schoolId:           schoolId           ?? this.schoolId,
        submittedAt:        submittedAt        ?? this.submittedAt,
        checkedAt:          checkedAt          ?? this.checkedAt,
        approvedAt:         approvedAt         ?? this.approvedAt,
        checkNotes:         checkNotes         ?? this.checkNotes,
        approvalNotes:      approvalNotes      ?? this.approvalNotes,
      );

  List<TemplateElement> get sideElements =>
      elements.where((e) => e.side == currentSide).toList()
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  TemplateElement? get selectedElement =>
      selectedElementId == null
          ? null
          : elements.where((e) => e.id == selectedElementId).firstOrNull;
}

// ── Notifier ──────────────────────────────────────────────────
class DesignerNotifier extends StateNotifier<DesignerState> {
  Timer? _autoSaveTimer;

  DesignerNotifier() : super(const DesignerState());

  void init(String? templateId, String? schoolId) {
    if (templateId != null) {
      _loadTemplate(templateId);
    } else {
      state = state.copyWith(schoolId: schoolId);
    }
  }

  Future<void> _loadTemplate(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      final resp = await ApiService().get('/id-templates/$id');
      final data = resp['data'] as Map<String, dynamic>;
      final tmpl = IdTemplate.fromJson(data);
      final elems = (data['elements'] as List? ?? [])
          .map((e) => TemplateElement.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        templateId:    tmpl.id,
        templateName:  tmpl.name,
        templateType:  tmpl.templateType,
        status:        tmpl.status,
        elements:      elems,
        isLoading:     false,
        isDirty:       false,
        schoolId:      tmpl.schoolId,
        submittedAt:   tmpl.submittedAt,
        checkedAt:     tmpl.checkedAt,
        approvedAt:    tmpl.approvedAt,
        checkNotes:    tmpl.checkNotes,
        approvalNotes: tmpl.approvalNotes,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setTemplateName(String name) =>
      state = state.copyWith(templateName: name, isDirty: true);

  void setSide(String side) =>
      state = state.copyWith(currentSide: side, clearSelected: true);

  void setZoom(double z) =>
      state = state.copyWith(zoom: z.clamp(0.3, 3.0));

  void selectElement(String? id) =>
      state = state.copyWith(selectedElementId: id);

  void deselectAll() =>
      state = state.copyWith(clearSelected: true);

  void addElement(TemplateElement element) {
    final updated = [...state.elements, element];
    state = state.copyWith(elements: updated, selectedElementId: element.id, isDirty: true);
    _scheduleAutoSave();
  }

  void updateElement(String id, TemplateElement Function(TemplateElement) updater) {
    final updated = state.elements.map((e) => e.id == id ? updater(e) : e).toList();
    state = state.copyWith(elements: updated, isDirty: true);
    _scheduleAutoSave();
  }

  void deleteElement(String id) {
    final updated = state.elements.where((e) => e.id != id).toList();
    state = state.copyWith(
      elements: updated,
      isDirty:  true,
      clearSelected: state.selectedElementId == id,
    );
    _scheduleAutoSave();
  }

  void bringForward(String id) {
    updateElement(id, (e) => e.copyWith(zIndex: e.zIndex + 1));
  }

  void sendBack(String id) {
    final el = state.elements.firstWhere((e) => e.id == id);
    if (el.zIndex > 1) updateElement(id, (e) => e.copyWith(zIndex: e.zIndex - 1));
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 30), () {
      if (state.isDirty && state.templateId != null) save();
    });
  }

  Future<bool> save() async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true);
    try {
      final body = {
        'name':          state.templateName,
        'template_type': state.templateType,
        'school_id':     state.schoolId ?? '',
        'elements':      state.elements.map((e) => e.toJson()).toList(),
      };

      if (state.templateId != null) {
        await ApiService().put('/id-templates/${state.templateId}', body: body);
      } else {
        final resp = await ApiService().post('/id-templates', body: body);
        final newId = resp['data']?['id'] as String?;
        state = state.copyWith(templateId: newId);
      }
      state = state.copyWith(isSaving: false, isDirty: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<void> submitForCheck() async {
    if (state.templateId == null) {
      final saved = await save();
      if (!saved) return;
    }
    try {
      await ApiService().post('/id-templates/${state.templateId}/submit');
      state = state.copyWith(status: 'pending_check');
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> performWorkflowAction(String action, bool approved, String? notes) async {
    if (state.templateId == null) return;
    try {
      await ApiService().post(
        '/id-templates/${state.templateId}/$action',
        body: {'approved': approved, 'notes': notes},
      );
      await _loadTemplate(state.templateId!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

// ── Unique provider per templateId ───────────────────────────
final designerProvider = StateNotifierProvider.family.autoDispose<DesignerNotifier, DesignerState, String?>(
  (ref, id) => DesignerNotifier()..init(id, null),
);

// ── Field library definition ──────────────────────────────────
class _LibraryField {
  final String label;
  final String elementType;
  final String? fieldSource;
  final String? fieldKey;
  final String? shapeType;
  final String? staticContent;
  final IconData icon;

  const _LibraryField({
    required this.label,
    required this.elementType,
    this.fieldSource,
    this.fieldKey,
    this.shapeType,
    this.staticContent,
    required this.icon,
  });
}

class _LibrarySection {
  final String title;
  final IconData icon;
  final List<_LibraryField> fields;
  bool expanded;
  _LibrarySection({
    required this.title,
    required this.icon,
    required this.fields,
    this.expanded = false,
  });
}

List<_LibrarySection> _buildLibrary() => [
      _LibrarySection(
        title: 'Student Fields', icon: Icons.person_outline, expanded: true,
        fields: [
          _LibraryField(label: 'First Name',    elementType: 'data_field', fieldSource: 'student', fieldKey: 'first_name',    icon: Icons.abc),
          _LibraryField(label: 'Last Name',     elementType: 'data_field', fieldSource: 'student', fieldKey: 'last_name',     icon: Icons.abc),
          _LibraryField(label: 'Full Name',     elementType: 'data_field', fieldSource: 'student', fieldKey: 'full_name',     icon: Icons.person),
          _LibraryField(label: 'Student ID',    elementType: 'data_field', fieldSource: 'student', fieldKey: 'student_id',    icon: Icons.badge_outlined),
          _LibraryField(label: 'Class',         elementType: 'data_field', fieldSource: 'student', fieldKey: 'class_name',    icon: Icons.class_outlined),
          _LibraryField(label: 'Section',       elementType: 'data_field', fieldSource: 'student', fieldKey: 'section',       icon: Icons.group_outlined),
          _LibraryField(label: 'Roll No.',      elementType: 'data_field', fieldSource: 'student', fieldKey: 'roll_number',   icon: Icons.numbers),
          _LibraryField(label: 'Date of Birth', elementType: 'data_field', fieldSource: 'student', fieldKey: 'date_of_birth', icon: Icons.cake_outlined),
          _LibraryField(label: 'Gender',        elementType: 'data_field', fieldSource: 'student', fieldKey: 'gender',        icon: Icons.wc),
          _LibraryField(label: 'Blood Group',   elementType: 'data_field', fieldSource: 'student', fieldKey: 'blood_group',   icon: Icons.favorite_border),
          _LibraryField(label: 'Aadhaar',       elementType: 'data_field', fieldSource: 'student', fieldKey: 'aadhaar',       icon: Icons.fingerprint),
          _LibraryField(label: 'Address',       elementType: 'data_field', fieldSource: 'student', fieldKey: 'address',       icon: Icons.home_outlined),
          _LibraryField(label: 'City',          elementType: 'data_field', fieldSource: 'student', fieldKey: 'city',          icon: Icons.location_city),
          _LibraryField(label: 'Admission No.', elementType: 'data_field', fieldSource: 'student', fieldKey: 'admission_no',  icon: Icons.confirmation_number_outlined),
        ],
      ),
      _LibrarySection(
        title: 'School Fields', icon: Icons.school_outlined,
        fields: [
          _LibraryField(label: 'School Name',  elementType: 'data_field', fieldSource: 'school', fieldKey: 'school_name',   icon: Icons.school),
          _LibraryField(label: 'School Code',  elementType: 'data_field', fieldSource: 'school', fieldKey: 'school_code',   icon: Icons.numbers),
          _LibraryField(label: 'Branch Name',  elementType: 'data_field', fieldSource: 'school', fieldKey: 'branch_name',   icon: Icons.account_tree_outlined),
          _LibraryField(label: 'Principal',    elementType: 'data_field', fieldSource: 'school', fieldKey: 'principal',     icon: Icons.manage_accounts),
          _LibraryField(label: 'Phone',        elementType: 'data_field', fieldSource: 'school', fieldKey: 'phone',         icon: Icons.phone_outlined),
          _LibraryField(label: 'Email',        elementType: 'data_field', fieldSource: 'school', fieldKey: 'email',         icon: Icons.email_outlined),
          _LibraryField(label: 'Affiliation',  elementType: 'data_field', fieldSource: 'school', fieldKey: 'affiliation',   icon: Icons.verified_outlined),
        ],
      ),
      _LibrarySection(
        title: 'Employee Fields', icon: Icons.work_outline,
        fields: [
          _LibraryField(label: 'Full Name',    elementType: 'data_field', fieldSource: 'employee', fieldKey: 'full_name',    icon: Icons.person),
          _LibraryField(label: 'Employee ID',  elementType: 'data_field', fieldSource: 'employee', fieldKey: 'employee_id',  icon: Icons.badge_outlined),
          _LibraryField(label: 'Designation',  elementType: 'data_field', fieldSource: 'employee', fieldKey: 'designation',  icon: Icons.work),
          _LibraryField(label: 'Department',   elementType: 'data_field', fieldSource: 'employee', fieldKey: 'department',   icon: Icons.business_outlined),
          _LibraryField(label: 'Branch',       elementType: 'data_field', fieldSource: 'employee', fieldKey: 'branch_name',  icon: Icons.account_tree_outlined),
        ],
      ),
      _LibrarySection(
        title: 'Media', icon: Icons.image_outlined,
        fields: [
          _LibraryField(label: 'Photo',             elementType: 'photo',            icon: Icons.portrait),
          _LibraryField(label: 'School Logo',       elementType: 'logo',             icon: Icons.school),
          _LibraryField(label: 'Background (Front)', elementType: 'background_image', icon: Icons.wallpaper),
          _LibraryField(label: 'Background (Back)',  elementType: 'background_image', icon: Icons.wallpaper),
        ],
      ),
      _LibrarySection(
        title: 'Special', icon: Icons.qr_code,
        fields: [
          _LibraryField(label: 'QR Code', elementType: 'qr_code', icon: Icons.qr_code),
          _LibraryField(label: 'Barcode',  elementType: 'barcode', icon: Icons.view_week_outlined),
        ],
      ),
      _LibrarySection(
        title: 'Shapes', icon: Icons.category_outlined,
        fields: [
          _LibraryField(label: 'Rectangle', elementType: 'shape', shapeType: 'rect',   icon: Icons.crop_square),
          _LibraryField(label: 'Circle',    elementType: 'shape', shapeType: 'circle', icon: Icons.circle_outlined),
          _LibraryField(label: 'Line',      elementType: 'shape', shapeType: 'line',   icon: Icons.horizontal_rule),
        ],
      ),
      _LibrarySection(
        title: 'Custom Text', icon: Icons.text_fields,
        fields: [
          _LibraryField(label: 'Custom Text',         elementType: 'static_text', staticContent: 'Custom text here',         icon: Icons.text_fields),
          _LibraryField(label: 'Terms & Conditions',  elementType: 'static_text', staticContent: 'If found, please return.', icon: Icons.article_outlined),
        ],
      ),
    ];

// ── Color parsing ─────────────────────────────────────────────
Color _parseColor(String? hex, [Color fallback = Colors.black]) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final s = hex.replaceAll('#', '');
    if (s.length == 6) return Color(int.parse('FF$s', radix: 16));
    if (s.length == 8) return Color(int.parse(s, radix: 16));
  } catch (_) {}
  return fallback;
}

String _colorToHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}';

// ── Screen ────────────────────────────────────────────────────
class IdTemplateDesignerScreen extends ConsumerStatefulWidget {
  final String? templateId;
  const IdTemplateDesignerScreen({super.key, this.templateId});

  @override
  ConsumerState<IdTemplateDesignerScreen> createState() => _IdTemplateDesignerScreenState();
}

class _IdTemplateDesignerScreenState extends ConsumerState<IdTemplateDesignerScreen>
    with TickerProviderStateMixin {
  late final List<_LibrarySection> _library;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _library  = _buildLibrary();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(designerProvider(widget.templateId));
    final notifier = ref.read(designerProvider(widget.templateId).notifier);

    // Sync name controller
    if (_nameCtrl.text != state.templateName) {
      _nameCtrl.value = _nameCtrl.value.copyWith(text: state.templateName);
    }

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.grey100,
      appBar: _buildAppBar(context, state, notifier),
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.delete &&
              state.selectedElementId != null) {
            notifier.deleteElement(state.selectedElementId!);
          }
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            notifier.deselectAll();
          }
        },
        child: LayoutBuilder(builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 900;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Element Library
                SizedBox(
                  width: 220,
                  child: _ElementLibrary(
                    library: _library,
                    side:    state.currentSide,
                    onAdd:   (field) => _addElement(notifier, state, field),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Center: Canvas
                Expanded(
                  child: _CanvasArea(
                    state:    state,
                    notifier: notifier,
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right: Properties
                SizedBox(
                  width: 260,
                  child: _PropertiesPanel(state: state, notifier: notifier),
                ),
              ],
            );
          }
          // Narrow: just canvas with bottom sheet
          return _CanvasArea(state: state, notifier: notifier);
        }),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, DesignerState state, DesignerNotifier notifier) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.grey900,
      elevation: 1,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (state.isDirty) {
            _showUnsavedDialog(context, state, notifier);
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
      title: SizedBox(
        width: 240,
        child: TextField(
          controller: _nameCtrl,
          onChanged: notifier.setTemplateName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.grey900),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
          ),
        ),
      ),
      actions: [
        // Status chip
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor(state.status).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel(state.status),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _statusColor(state.status),
            ),
          ),
        ),
        // Unsaved indicator
        if (state.isDirty)
          Tooltip(
            message: 'Unsaved changes',
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppTheme.warning, shape: BoxShape.circle),
            ),
          ),
        // Workflow button
        if (['draft','rejected'].contains(state.status))
          TextButton.icon(
            onPressed: () => _showWorkflowDialog(context, state, notifier),
            icon: const Icon(Icons.send, size: 14),
            label: Text('Submit', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.info),
          ),
        if (state.status == 'pending_check')
          TextButton.icon(
            onPressed: () => _showWorkflowDialog(context, state, notifier),
            icon: const Icon(Icons.rate_review, size: 14),
            label: Text('Check', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
          ),
        if (state.status == 'pending_approval')
          TextButton.icon(
            onPressed: () => _showWorkflowDialog(context, state, notifier),
            icon: const Icon(Icons.approval, size: 14),
            label: Text('Approve', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.info),
          ),
        if (state.status == 'approved')
          TextButton.icon(
            onPressed: () => notifier.performWorkflowAction('activate', true, null),
            icon: const Icon(Icons.play_circle, size: 14),
            label: Text('Activate', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.success),
          ),
        // Save button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: state.isSaving
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await notifier.save();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Saved successfully' : 'Save failed', style: GoogleFonts.poppins()),
                        backgroundColor: ok ? AppTheme.success : AppTheme.error,
                      ));
                    }
                  },
                  icon:  const Icon(Icons.save, size: 14),
                  label: Text('Save', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
        ),
      ],
    );
  }

  void _addElement(DesignerNotifier notifier, DesignerState state, _LibraryField field) {
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    double w = 30, h = 10;
    if (field.elementType == 'photo')            { w = 15; h = 25; }
    if (field.elementType == 'logo')             { w = 12; h = 12; }
    if (field.elementType == 'qr_code')          { w = 18; h = 18; }
    if (field.elementType == 'barcode')          { w = 40; h = 10; }
    if (field.elementType == 'background_image') { w = 100; h = 100; }
    if (field.shapeType == 'circle')             { w = 20; h = 20; }
    if (field.shapeType == 'line')               { w = 60; h = 2; }

    final el = TemplateElement(
      id:            id,
      side:          state.currentSide,
      elementType:   field.elementType,
      fieldSource:   field.fieldSource,
      fieldKey:      field.fieldKey,
      label:         field.label,
      staticContent: field.staticContent,
      xPct:          5,
      yPct:          5,
      wPct:          w,
      hPct:          h,
      zIndex:        field.elementType == 'background_image' ? 0 : (state.elements.length + 1),
      shapeType:     field.shapeType,
      fillColor:     field.shapeType != null ? '#1A237E' : null,
      fontSize:      field.elementType == 'data_field' ? 10 : 12,
      fontColor:     '#1A237E',
      bgColor:       field.elementType == 'photo' ? '#E3F2FD' : null,
    );
    notifier.addElement(el);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'draft':             return AppTheme.grey600;
      case 'pending_check':     return AppTheme.warning;
      case 'pending_approval':  return AppTheme.info;
      case 'approved':          return const Color(0xFF00897B);
      case 'rejected':          return AppTheme.error;
      case 'active':            return AppTheme.success;
      default:                  return AppTheme.grey600;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'draft':             return 'Draft';
      case 'pending_check':     return 'Pending Check';
      case 'pending_approval':  return 'Pending Approval';
      case 'approved':          return 'Approved';
      case 'rejected':          return 'Rejected';
      case 'active':            return 'Active';
      default:                  return s;
    }
  }

  Future<void> _showUnsavedDialog(BuildContext ctx, DesignerState state, DesignerNotifier notifier) async {
    final result = await showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unsaved Changes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('You have unsaved changes. Save before leaving?', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop('discard'),  child: Text('Discard', style: GoogleFonts.poppins(color: AppTheme.error))),
          TextButton(onPressed: () => Navigator.of(dCtx).pop('cancel'),   child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(onPressed: () => Navigator.of(dCtx).pop('save'), child: Text('Save', style: GoogleFonts.poppins())),
        ],
      ),
    );
    if (result == 'save') {
      await notifier.save();
      if (ctx.mounted) Navigator.of(ctx).maybePop();
    } else if (result == 'discard') {
      if (ctx.mounted) Navigator.of(ctx).maybePop();
    }
  }

  Future<void> _showWorkflowDialog(BuildContext ctx, DesignerState state, DesignerNotifier notifier) async {
    await showDialog(
      context: ctx,
      builder: (_) => IdTemplateWorkflowDialog(state: state, notifier: notifier),
    );
  }
}

// ── Element Library ───────────────────────────────────────────
class _ElementLibrary extends StatefulWidget {
  final List<_LibrarySection> library;
  final String side;
  final void Function(_LibraryField) onAdd;

  const _ElementLibrary({
    required this.library,
    required this.side,
    required this.onAdd,
  });

  @override
  State<_ElementLibrary> createState() => _ElementLibraryState();
}

class _ElementLibraryState extends State<_ElementLibrary> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppTheme.grey50,
            child: Row(
              children: [
                const Icon(Icons.widgets_outlined, size: 15, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Elements', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.library.length,
              itemBuilder: (ctx, i) {
                final section = widget.library[i];
                return _LibrarySectionWidget(
                  section:  section,
                  onToggle: () => setState(() => section.expanded = !section.expanded),
                  onAdd:    widget.onAdd,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySectionWidget extends StatelessWidget {
  final _LibrarySection section;
  final VoidCallback onToggle;
  final void Function(_LibraryField) onAdd;
  const _LibrarySectionWidget({required this.section, required this.onToggle, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(section.icon, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(section.title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.grey800))),
                Icon(section.expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppTheme.grey600),
              ],
            ),
          ),
        ),
        if (section.expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Wrap(
              spacing: 4, runSpacing: 4,
              children: section.fields.map((f) => _LibraryChip(field: f, onAdd: onAdd)).toList(),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _LibraryChip extends StatelessWidget {
  final _LibraryField field;
  final void Function(_LibraryField) onAdd;
  const _LibraryChip({required this.field, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Click to add ${field.label}',
      child: GestureDetector(
        onTap: () => onAdd(field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(field.icon, size: 10, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text(field.label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Canvas Area ───────────────────────────────────────────────
class _CanvasArea extends ConsumerStatefulWidget {
  final DesignerState state;
  final DesignerNotifier notifier;
  const _CanvasArea({required this.state, required this.notifier});

  @override
  ConsumerState<_CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends ConsumerState<_CanvasArea> {
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state    = widget.state;
    final notifier = widget.notifier;

    return Container(
      color: AppTheme.grey200,
      child: Column(
        children: [
          // Tab bar (Front/Back) + Zoom controls
          Container(
            height: 44,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _SideTab(label: 'Front', active: state.currentSide == 'front', onTap: () => notifier.setSide('front')),
                const SizedBox(width: 4),
                _SideTab(label: 'Back',  active: state.currentSide == 'back',  onTap: () => notifier.setSide('back')),
                const Spacer(),
                // Zoom controls
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 18),
                  onPressed: () => notifier.setZoom(state.zoom - 0.1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(state.zoom * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 18),
                  onPressed: () => notifier.setZoom(state.zoom + 0.1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                IconButton(
                  icon: const Icon(Icons.fit_screen, size: 16),
                  onPressed: () {
                    notifier.setZoom(1.0);
                    _transformController.value = Matrix4.identity();
                  },
                  tooltip: 'Reset zoom',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          // Canvas
          Expanded(
            child: GestureDetector(
              onTap: () => notifier.deselectAll(),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.3,
                maxScale: 3.0,
                constrained: false,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: _CardCanvas(state: state, notifier: notifier),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SideTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:        active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.grey600,
          ),
        ),
      ),
    );
  }
}

// ── Card Canvas ───────────────────────────────────────────────
class _CardCanvas extends StatelessWidget {
  final DesignerState state;
  final DesignerNotifier notifier;
  const _CardCanvas({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  kCardW,
      height: kCardH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background (z=0)
            ...state.sideElements
                .where((e) => e.elementType == 'background_image')
                .map((e) => _CanvasElement(element: e, state: state, notifier: notifier)),
            // All other elements
            ...state.sideElements
                .where((e) => e.elementType != 'background_image')
                .map((e) => _CanvasElement(element: e, state: state, notifier: notifier)),
            // Empty card placeholder
            if (state.sideElements.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_box_outlined, size: 48, color: AppTheme.grey300),
                    const SizedBox(height: 8),
                    Text(
                      'Click elements on the left to add them here',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey300),
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

// ── Individual Canvas Element ─────────────────────────────────
class _CanvasElement extends StatefulWidget {
  final TemplateElement element;
  final DesignerState state;
  final DesignerNotifier notifier;
  const _CanvasElement({required this.element, required this.state, required this.notifier});

  @override
  State<_CanvasElement> createState() => _CanvasElementState();
}

class _CanvasElementState extends State<_CanvasElement> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final el       = widget.element;
    final notifier = widget.notifier;
    final isSelected = widget.state.selectedElementId == el.id;

    final left   = el.xPct / 100 * kCardW;
    final top    = el.yPct / 100 * kCardH;
    final width  = el.wPct / 100 * kCardW;
    final height = el.hPct / 100 * kCardH;

    return Positioned(
      left:   left,
      top:    top,
      width:  width,
      height: height,
      child: Transform.rotate(
        angle:  el.rotationDeg * math.pi / 180,
        child: MouseRegion(
          onEnter:  (_) => setState(() => _hovered = true),
          onExit:   (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: () {
              notifier.selectElement(el.id);
            },
            onPanUpdate: (details) {
              if (['draft','rejected'].contains(widget.state.status)) {
                notifier.updateElement(el.id, (e) => e.copyWith(
                  xPct: (e.xPct + details.delta.dx / kCardW * 100).clamp(0.0, 100 - e.wPct),
                  yPct: (e.yPct + details.delta.dy / kCardH * 100).clamp(0.0, 100 - e.hPct),
                ));
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The element itself
                Opacity(
                  opacity: el.opacity,
                  child: _renderElement(el, width, height),
                ),

                // Selection / hover border
                if (isSelected || _hovered)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? AppTheme.info : AppTheme.grey300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                // Delete button on hover/selected
                if (isSelected)
                  Positioned(
                    top: -12,
                    right: -12,
                    child: GestureDetector(
                      onTap: () => notifier.deleteElement(el.id),
                      child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),

                // Resize handles (8 anchors) — only when selected and editable
                if (isSelected && ['draft','rejected'].contains(widget.state.status))
                  ..._buildResizeHandles(el),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderElement(TemplateElement el, double w, double h) {
    final bgC      = el.bgColor   != null ? _parseColor(el.bgColor)   : Colors.transparent;
    final bordC    = el.borderColor != null ? _parseColor(el.borderColor) : Colors.transparent;
    final fontC    = _parseColor(el.fontColor, const Color(0xFF1A237E));
    final fillC    = el.fillColor  != null ? _parseColor(el.fillColor)  : AppTheme.primary;

    switch (el.elementType) {
      case 'data_field':
        final displayText = el.label != null && el.label!.isNotEmpty
            ? '${el.label}: ${_fieldPreview(el.fieldKey)}'
            : _fieldPreview(el.fieldKey);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:        bgC,
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       el.borderWidth > 0 ? Border.all(color: bordC, width: el.borderWidth) : null,
          ),
          child: Text(
            displayText,
            style: GoogleFonts.poppins(
              fontSize:   el.fontSize,
              fontWeight: el.fontWeight == 'bold' ? FontWeight.w700
                        : el.fontWeight == 'semibold' ? FontWeight.w600
                        : FontWeight.w400,
              color:      fontC,
              fontStyle:  el.fontItalic ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: el.textAlign == 'center' ? TextAlign.center
                      : el.textAlign == 'right'  ? TextAlign.right
                      : TextAlign.left,
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'photo':
        return Container(
          decoration: BoxDecoration(
            color:        bgC == Colors.transparent ? const Color(0xFFE3F2FD) : bgC,
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       Border.all(color: bordC == Colors.transparent ? AppTheme.grey300 : bordC, width: el.borderWidth > 0 ? el.borderWidth : 1),
          ),
          child: const Center(
            child: Icon(Icons.person, size: 36, color: AppTheme.grey300),
          ),
        );

      case 'logo':
        return Container(
          decoration: BoxDecoration(
            color:        const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       Border.all(color: AppTheme.grey300),
          ),
          child: const Center(
            child: Icon(Icons.school, size: 28, color: AppTheme.primary),
          ),
        );

      case 'qr_code':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       Border.all(color: AppTheme.grey200),
          ),
          child: QrImageView(data: 'PREVIEW', version: QrVersions.auto),
        );

      case 'barcode':
        return Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       Border.all(color: AppTheme.grey200),
          ),
          child: Center(
            child: CustomPaint(
              size: Size(w - 12, h - 12),
              painter: _BarcodePainter(),
            ),
          ),
        );

      case 'static_text':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:        bgC,
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       el.borderWidth > 0 ? Border.all(color: bordC, width: el.borderWidth) : null,
          ),
          child: Text(
            el.staticContent ?? 'Static text',
            style: GoogleFonts.poppins(
              fontSize:  el.fontSize,
              fontWeight: el.fontWeight == 'bold' ? FontWeight.w700 : FontWeight.w400,
              color:      fontC,
              fontStyle:  el.fontItalic ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: el.textAlign == 'center' ? TextAlign.center : TextAlign.left,
            overflow: TextOverflow.ellipsis,
            maxLines: 4,
          ),
        );

      case 'shape':
        switch (el.shapeType) {
          case 'circle':
            return Container(
              decoration: BoxDecoration(
                color:  fillC,
                shape:  BoxShape.circle,
                border: el.borderWidth > 0 ? Border.all(color: bordC, width: el.borderWidth) : null,
              ),
            );
          case 'line':
            return Center(
              child: Container(
                height: math.max(el.borderWidth, 2),
                color: fillC,
              ),
            );
          default: // rect
            return Container(
              decoration: BoxDecoration(
                color:        fillC.withOpacity(0.15),
                borderRadius: BorderRadius.circular(el.borderRadius),
                border:       Border.all(color: fillC, width: el.borderWidth > 0 ? el.borderWidth : 1.5),
              ),
            );
        }

      case 'background_image':
        return Container(
          width:  double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(Icons.wallpaper, size: 40, color: Colors.white.withOpacity(0.3)),
          ),
        );

      default:
        return Container(
          decoration: BoxDecoration(
            color:        bgC,
            borderRadius: BorderRadius.circular(el.borderRadius),
            border:       Border.all(color: AppTheme.grey300),
          ),
          child: Center(child: Text(el.elementType, style: GoogleFonts.poppins(fontSize: 9))),
        );
    }
  }

  String _fieldPreview(String? key) {
    const previews = {
      'first_name':   'Arjun',
      'last_name':    'Kumar',
      'full_name':    'Arjun Kumar',
      'student_id':   'STU1015',
      'class_name':   'Class 5',
      'section':      'Section A',
      'roll_number':  'Roll: 15',
      'date_of_birth':'01/01/2014',
      'gender':       'Male',
      'blood_group':  'B+',
      'aadhaar':      'XXXX XXXX 1234',
      'address':      '123 School St',
      'city':         'New Delhi',
      'school_name':  'Green Valley School',
      'school_code':  'GVS001',
      'branch_name':  'Main Branch',
      'principal':    'Dr. R. Sharma',
      'phone':        '+91 98765 43210',
      'email':        'info@school.edu',
      'affiliation':  'CBSE',
      'employee_id':  'EMP001',
      'designation':  'Teacher',
      'department':   'Science',
      'admission_no': 'ADM2024001',
    };
    return previews[key] ?? (key ?? 'Value');
  }

  List<Widget> _buildResizeHandles(TemplateElement el) {
    final handles = <_ResizeHandle>[
      _ResizeHandle(anchor: 'nw', cursor: SystemMouseCursors.resizeUpLeftDownRight),
      _ResizeHandle(anchor: 'n',  cursor: SystemMouseCursors.resizeUpDown),
      _ResizeHandle(anchor: 'ne', cursor: SystemMouseCursors.resizeUpRightDownLeft),
      _ResizeHandle(anchor: 'e',  cursor: SystemMouseCursors.resizeLeftRight),
      _ResizeHandle(anchor: 'se', cursor: SystemMouseCursors.resizeUpLeftDownRight),
      _ResizeHandle(anchor: 's',  cursor: SystemMouseCursors.resizeUpDown),
      _ResizeHandle(anchor: 'sw', cursor: SystemMouseCursors.resizeUpRightDownLeft),
      _ResizeHandle(anchor: 'w',  cursor: SystemMouseCursors.resizeLeftRight),
    ];

    return handles.map((h) {
      double? left, top, right, bottom;
      const s = 10.0, half = 5.0;
      switch (h.anchor) {
        case 'nw': left = -half; top = -half; break;
        case 'n':  left = (el.wPct / 100 * kCardW / 2) - half; top = -half; break;
        case 'ne': right = -half; top = -half; break;
        case 'e':  right = -half; top = (el.hPct / 100 * kCardH / 2) - half; break;
        case 'se': right = -half; bottom = -half; break;
        case 's':  left = (el.wPct / 100 * kCardW / 2) - half; bottom = -half; break;
        case 'sw': left = -half; bottom = -half; break;
        case 'w':  left = -half; top = (el.hPct / 100 * kCardH / 2) - half; break;
      }

      return Positioned(
        left: left, top: top, right: right, bottom: bottom,
        width: s, height: s,
        child: MouseRegion(
          cursor: h.cursor,
          child: GestureDetector(
            onPanUpdate: (details) {
              final dx = details.delta.dx / kCardW * 100;
              final dy = details.delta.dy / kCardH * 100;
              widget.notifier.updateElement(el.id, (e) {
                double nx = e.xPct, ny = e.yPct, nw = e.wPct, nh = e.hPct;
                switch (h.anchor) {
                  case 'nw': nx += dx; ny += dy; nw -= dx; nh -= dy; break;
                  case 'n':  ny += dy; nh -= dy; break;
                  case 'ne': nw += dx; ny += dy; nh -= dy; break;
                  case 'e':  nw += dx; break;
                  case 'se': nw += dx; nh += dy; break;
                  case 's':  nh += dy; break;
                  case 'sw': nx += dx; nw -= dx; nh += dy; break;
                  case 'w':  nx += dx; nw -= dx; break;
                }
                return e.copyWith(
                  xPct: nx.clamp(0.0, 99.0),
                  yPct: ny.clamp(0.0, 99.0),
                  wPct: nw.clamp(3.0, 100.0),
                  hPct: nh.clamp(2.0, 100.0),
                );
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color:  Colors.white,
                border: Border.all(color: AppTheme.info, width: 1.5),
                shape:  BoxShape.rectangle,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _ResizeHandle {
  final String anchor;
  final MouseCursor cursor;
  const _ResizeHandle({required this.anchor, required this.cursor});
}

// ── Barcode Painter ───────────────────────────────────────────
class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final rng = math.Random(42);
    double x = 0;
    while (x < size.width) {
      final w = 1.0 + rng.nextDouble() * 2;
      if (rng.nextBool()) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + rng.nextDouble();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Properties Panel ──────────────────────────────────────────
class _PropertiesPanel extends ConsumerWidget {
  final DesignerState state;
  final DesignerNotifier notifier;
  const _PropertiesPanel({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = state.selectedElement;
    final canEdit = ['draft', 'rejected'].contains(state.status);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppTheme.grey50,
            child: Row(
              children: [
                const Icon(Icons.tune, size: 15, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Properties', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: el == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 36, color: AppTheme.grey300),
                        const SizedBox(height: 8),
                        Text('Select an element to\nedit its properties',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PropsSection(title: 'Element', children: [
                          _PropRow(
                            label: 'Type',
                            child: Text(
                              el.elementType.replaceAll('_', ' '),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                            ),
                          ),
                          _PropRow(
                            label: 'Side',
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: el.side,
                                isDense: true,
                                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800),
                                items: ['front', 'back'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(side: v)) : null,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        _PropsSection(title: 'Position & Size', children: [
                          _NumInput(label: 'X (%)',  value: el.xPct,  onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(xPct: v)) : null),
                          _NumInput(label: 'Y (%)',  value: el.yPct,  onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(yPct: v)) : null),
                          _NumInput(label: 'W (%)',  value: el.wPct,  onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(wPct: v)) : null),
                          _NumInput(label: 'H (%)',  value: el.hPct,  onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(hPct: v)) : null),
                        ]),
                        const SizedBox(height: 10),
                        _PropsSection(title: 'Rotation', children: [
                          _SliderInput(
                            label: 'Angle',
                            value: el.rotationDeg,
                            min: -180, max: 180,
                            onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(rotationDeg: v)) : null,
                          ),
                        ]),
                        if (['data_field', 'static_text'].contains(el.elementType)) ...[
                          const SizedBox(height: 10),
                          _PropsSection(title: 'Typography', children: [
                            _NumInput(label: 'Font Size', value: el.fontSize, onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(fontSize: v)) : null),
                            _PropRow(
                              label: 'Weight',
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: el.fontWeight,
                                  isDense: true,
                                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800),
                                  items: ['normal','semibold','bold'].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                                  onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(fontWeight: v)) : null,
                                ),
                              ),
                            ),
                            _PropRow(
                              label: 'Color',
                              child: _ColorPickerButton(
                                color: _parseColor(el.fontColor, AppTheme.primary),
                                enabled: canEdit,
                                onChanged: (c) => notifier.updateElement(el.id, (e) => e.copyWith(fontColor: _colorToHex(c))),
                              ),
                            ),
                            _PropRow(
                              label: 'Align',
                              child: Row(
                                children: [
                                  _AlignBtn(icon: Icons.format_align_left,   value: 'left',   current: el.textAlign, enabled: canEdit, onTap: () => notifier.updateElement(el.id, (e) => e.copyWith(textAlign: 'left'))),
                                  _AlignBtn(icon: Icons.format_align_center, value: 'center', current: el.textAlign, enabled: canEdit, onTap: () => notifier.updateElement(el.id, (e) => e.copyWith(textAlign: 'center'))),
                                  _AlignBtn(icon: Icons.format_align_right,  value: 'right',  current: el.textAlign, enabled: canEdit, onTap: () => notifier.updateElement(el.id, (e) => e.copyWith(textAlign: 'right'))),
                                ],
                              ),
                            ),
                            _PropRow(
                              label: 'Italic',
                              child: Switch(
                                value: el.fontItalic,
                                onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(fontItalic: v)) : null,
                                activeColor: AppTheme.primary,
                              ),
                            ),
                          ]),
                          if (el.elementType == 'static_text') ...[
                            const SizedBox(height: 10),
                            _PropsSection(title: 'Content', children: [
                              _TextAreaInput(
                                label: 'Text',
                                value: el.staticContent ?? '',
                                enabled: canEdit,
                                onChanged: (v) => notifier.updateElement(el.id, (e) => e.copyWith(staticContent: v)),
                              ),
                            ]),
                          ],
                        ],
                        if (['photo', 'logo', 'background_image'].contains(el.elementType)) ...[
                          const SizedBox(height: 10),
                          _PropsSection(title: 'Image', children: [
                            _PropRow(
                              label: 'Fit',
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: el.objectFit,
                                  isDense: true,
                                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800),
                                  items: ['cover','contain','fill'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                  onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(objectFit: v)) : null,
                                ),
                              ),
                            ),
                          ]),
                        ],
                        if (el.elementType == 'shape') ...[
                          const SizedBox(height: 10),
                          _PropsSection(title: 'Shape', children: [
                            _PropRow(
                              label: 'Fill',
                              child: _ColorPickerButton(
                                color: _parseColor(el.fillColor, AppTheme.primary),
                                enabled: canEdit,
                                onChanged: (c) => notifier.updateElement(el.id, (e) => e.copyWith(fillColor: _colorToHex(c))),
                              ),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 10),
                        _PropsSection(title: 'Appearance', children: [
                          _PropRow(
                            label: 'BG Color',
                            child: _ColorPickerButton(
                              color: _parseColor(el.bgColor, Colors.transparent),
                              enabled: canEdit,
                              showTransparent: true,
                              onChanged: (c) => notifier.updateElement(el.id, (e) => e.copyWith(bgColor: c.alpha < 10 ? null : _colorToHex(c))),
                            ),
                          ),
                          _SliderInput(
                            label: 'Opacity',
                            value: el.opacity * 100,
                            min: 0, max: 100,
                            onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(opacity: v / 100)) : null,
                          ),
                          _NumInput(label: 'Border W', value: el.borderWidth, onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(borderWidth: v)) : null),
                          _NumInput(label: 'Radius',   value: el.borderRadius, onChanged: canEdit ? (v) => notifier.updateElement(el.id, (e) => e.copyWith(borderRadius: v)) : null),
                          if (el.borderWidth > 0)
                            _PropRow(
                              label: 'Border Color',
                              child: _ColorPickerButton(
                                color: _parseColor(el.borderColor, Colors.black),
                                enabled: canEdit,
                                onChanged: (c) => notifier.updateElement(el.id, (e) => e.copyWith(borderColor: _colorToHex(c))),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        _PropsSection(title: 'Layer Order', children: [
                          _PropRow(
                            label: 'Z-Index: ${el.zIndex}',
                            child: Row(
                              children: [
                                _ZBtn(icon: Icons.arrow_downward, tooltip: 'Send back',    onTap: canEdit ? () => notifier.sendBack(el.id) : null),
                                const SizedBox(width: 4),
                                _ZBtn(icon: Icons.arrow_upward,   tooltip: 'Bring forward', onTap: canEdit ? () => notifier.bringForward(el.id) : null),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        if (canEdit)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => notifier.deleteElement(el.id),
                              icon:  const Icon(Icons.delete_outline, size: 14, color: AppTheme.error),
                              label: Text('Remove Element', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.error),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Property UI helpers ───────────────────────────────────────
class _PropsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PropsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.grey600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
}

class _PropRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _PropRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NumInput extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  const _NumInput({required this.label, required this.value, this.onChanged});

  @override
  State<_NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<_NumInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(_NumInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value - widget.value).abs() > 0.05) {
      _ctrl.text = widget.value.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PropRow(
      label: widget.label,
      child: SizedBox(
        height: 28,
        child: TextField(
          controller: _ctrl,
          enabled: widget.onChanged != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.poppins(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final d = double.tryParse(v);
            if (d != null) widget.onChanged?.call(d);
          },
        ),
      ),
    );
  }
}

class _SliderInput extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final ValueChanged<double>? onChanged;
  const _SliderInput({required this.label, required this.value, required this.min, required this.max, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _PropRow(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                trackHeight: 2,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                activeColor: AppTheme.primary,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(value.round().toString(), style: GoogleFonts.poppins(fontSize: 10), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _TextAreaInput extends StatefulWidget {
  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _TextAreaInput({required this.label, required this.value, required this.enabled, required this.onChanged});

  @override
  State<_TextAreaInput> createState() => _TextAreaInputState();
}

class _TextAreaInputState extends State<_TextAreaInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
        const SizedBox(height: 4),
        TextField(
          controller: _ctrl,
          enabled: widget.enabled,
          maxLines: 3,
          style: GoogleFonts.poppins(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

class _AlignBtn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String current;
  final bool enabled;
  final VoidCallback onTap;
  const _AlignBtn({required this.icon, required this.value, required this.current, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color:        active ? AppTheme.primary : AppTheme.grey100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: active ? Colors.white : AppTheme.grey600),
      ),
    );
  }
}

class _ZBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _ZBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:  AppTheme.grey100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.grey300),
          ),
          child: Icon(icon, size: 14, color: onTap != null ? AppTheme.grey700 : AppTheme.grey300),
        ),
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  final Color color;
  final bool enabled;
  final bool showTransparent;
  final ValueChanged<Color> onChanged;
  const _ColorPickerButton({
    required this.color,
    required this.enabled,
    required this.onChanged,
    this.showTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => _openPicker(context) : null,
      child: Container(
        width: 32, height: 22,
        decoration: BoxDecoration(
          color:  color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: color.alpha < 10
            ? const Center(child: Icon(Icons.block, size: 12, color: AppTheme.grey300))
            : null,
      ),
    );
  }

  void _openPicker(BuildContext context) {
    Color temp = color;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pick Color', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: _SimpleColorGrid(
              current: temp,
              onChanged: (c) { temp = c; },
            ),
          ),
        ),
        actions: [
          if (showTransparent)
            TextButton(
              onPressed: () {
                onChanged(Colors.transparent);
                Navigator.of(context).pop();
              },
              child: Text('Transparent', style: GoogleFonts.poppins(color: AppTheme.grey600)),
            ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              onChanged(temp);
              Navigator.of(context).pop();
            },
            child: Text('Apply', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

class _SimpleColorGrid extends StatefulWidget {
  final Color current;
  final ValueChanged<Color> onChanged;
  const _SimpleColorGrid({required this.current, required this.onChanged});

  @override
  State<_SimpleColorGrid> createState() => _SimpleColorGridState();
}

class _SimpleColorGridState extends State<_SimpleColorGrid> {
  late Color _selected;

  static const _colors = [
    Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3F51B5), Color(0xFF7986CB),
    Color(0xFF00BCD4), Color(0xFF0097A7), Color(0xFF006064), Color(0xFF80DEEA),
    Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFFA5D6A7),
    Color(0xFFFF6F00), Color(0xFFF57F17), Color(0xFFFFC107), Color(0xFFFFECB3),
    Color(0xFFC62828), Color(0xFFD32F2F), Color(0xFFEF5350), Color(0xFFFFCDD2),
    Color(0xFF37474F), Color(0xFF455A64), Color(0xFF78909C), Color(0xFFCFD8DC),
    Color(0xFF212121), Color(0xFF424242), Color(0xFF757575), Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _colors.map((c) {
        final isSel = _selected.value == c.value;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = c);
            widget.onChanged(c);
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? Colors.black54 : (c == Colors.white ? AppTheme.grey300 : Colors.transparent),
                width: isSel ? 3 : 1,
              ),
            ),
            child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Workflow Dialog ───────────────────────────────────────────
class IdTemplateWorkflowDialog extends StatefulWidget {
  final DesignerState state;
  final DesignerNotifier notifier;
  const IdTemplateWorkflowDialog({super.key, required this.state, required this.notifier});

  @override
  State<IdTemplateWorkflowDialog> createState() => _IdTemplateWorkflowDialogState();
}

class _IdTemplateWorkflowDialogState extends State<IdTemplateWorkflowDialog> {
  final _notesCtrl  = TextEditingController();
  bool _approving   = true;
  bool _isLoading   = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.status;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_tree, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _dialogTitle(status),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workflow pipeline
            _WorkflowAuditTrail(state: widget.state),
            const SizedBox(height: 16),

            // Action for check/approve
            if (status == 'pending_check' || status == 'pending_approval') ...[
              Text('Decision', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DecisionChip(
                      label: 'Approve',
                      icon:  Icons.check_circle_outline,
                      color: AppTheme.success,
                      selected: _approving,
                      onTap: () => setState(() => _approving = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecisionChip(
                      label: 'Reject',
                      icon:  Icons.cancel_outlined,
                      color: AppTheme.error,
                      selected: !_approving,
                      onTap: () => setState(() => _approving = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Notes
            Text('Notes (optional)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Add notes or comments…',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey300),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _actionColor(status),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_actionLabel(status), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final notes = _notesCtrl.text.trim();

    switch (widget.state.status) {
      case 'draft':
      case 'rejected':
        await widget.notifier.submitForCheck();
        break;
      case 'pending_check':
        await widget.notifier.performWorkflowAction('check', _approving, notes.isEmpty ? null : notes);
        break;
      case 'pending_approval':
        await widget.notifier.performWorkflowAction('approve', _approving, notes.isEmpty ? null : notes);
        break;
    }

    if (mounted) Navigator.of(context).pop();
  }

  String _dialogTitle(String status) {
    switch (status) {
      case 'draft':
      case 'rejected':          return 'Submit for Review';
      case 'pending_check':     return 'Check Template';
      case 'pending_approval':  return 'Approve Template';
      default:                  return 'Workflow Action';
    }
  }

  String _actionLabel(String status) {
    switch (status) {
      case 'draft':
      case 'rejected':          return 'Submit';
      case 'pending_check':     return _approving ? 'Send to Approval' : 'Reject';
      case 'pending_approval':  return _approving ? 'Approve' : 'Reject';
      default:                  return 'Confirm';
    }
  }

  Color _actionColor(String status) {
    if (!_approving) return AppTheme.error;
    switch (status) {
      case 'draft':
      case 'rejected':          return AppTheme.info;
      case 'pending_check':     return AppTheme.warning;
      case 'pending_approval':  return AppTheme.success;
      default:                  return AppTheme.primary;
    }
  }
}

class _DecisionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _DecisionChip({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:        selected ? color.withOpacity(0.12) : AppTheme.grey50,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: selected ? color : AppTheme.grey300, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppTheme.grey600),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.grey600)),
          ],
        ),
      ),
    );
  }
}

class _WorkflowAuditTrail extends StatelessWidget {
  final DesignerState state;
  const _WorkflowAuditTrail({required this.state});

  @override
  Widget build(BuildContext context) {
    final events = <(String, String?, DateTime?)>[];

    events.add(('Created', 'Created by maker', null));
    if (state.submittedAt != null) {
      events.add(('Submitted', 'Submitted for check', state.submittedAt));
    }
    if (state.checkedAt != null) {
      final note = state.checkNotes?.isNotEmpty == true ? state.checkNotes : null;
      events.add(('Checked', note ?? (state.status == 'rejected' ? 'Rejected at check' : 'Passed check'), state.checkedAt));
    }
    if (state.approvedAt != null) {
      final note = state.approvalNotes?.isNotEmpty == true ? state.approvalNotes : null;
      events.add(('Approved', note ?? 'Template approved', state.approvedAt));
    }

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Audit Trail', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.grey600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ...events.map((ev) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4, right: 8),
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ev.$1, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.grey800)),
                    if (ev.$2 != null)
                      Text(ev.$2!, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600)),
                    if (ev.$3 != null)
                      Text(_formatDt(ev.$3!), style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey300)),
                  ],
                ),
              ),
            ],
          ),
        )),
        const Divider(height: 1),
      ],
    );
  }

  String _formatDt(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month-1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}

